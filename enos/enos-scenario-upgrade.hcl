# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: BUSL-1.1

scenario "upgrade" {
  matrix {
    arch            = global.archs
    artifact_source = global.artifact_sources
    artifact_type   = global.artifact_types
    backend         = global.backends
    config_mode     = global.config_modes
    consul_version  = global.consul_versions
    distro          = global.distros
    edition         = global.editions
    // This reads the VERSION file, strips any pre-release metadata, and selects only initial
    // versions that are less than our current version. A VERSION file containing 1.17.0-beta2 would
    // render: semverconstraint(v, "<1.17.0-0")
    initial_version = [for v in global.upgrade_initial_versions : v if semverconstraint(v, "<${join("-", [split("-", chomp(file("../version/VERSION")))[0], "0"])}")]
    seal            = global.seals


    # Our local builder always creates bundles
    exclude {
      artifact_source = ["local"]
      artifact_type   = ["package"]
    }

    # Don't upgrade from super-ancient versions in CI because there are known reliability issues
    # in those versions that have already been fixed.
    exclude {
      initial_version = [for e in matrix.initial_version : e if semverconstraint(e, "<1.11.0-0")]
    }

    # FIPS 140-2 editions were not supported until 1.11.x, even though there are 1.10.x binaries
    # published.
    exclude {
      edition         = ["ent.fips1402", "ent.hsm.fips1402"]
      initial_version = [for e in matrix.initial_version : e if semverconstraint(e, "<1.11.0-0")]
    }

    # HSM and FIPS 140-2 are only supported on amd64
    exclude {
      arch    = ["arm64"]
      edition = ["ent.fips1402", "ent.hsm", "ent.hsm.fips1402"]
    }

    # PKCS#11 can only be used with hsm editions
    exclude {
      seal    = ["pkcs11"]
      edition = [for e in matrix.edition : e if !strcontains(e, "hsm")]
    }
  }

  terraform_cli = terraform_cli.default
  terraform     = terraform.default
  providers = [
    provider.aws.default,
    provider.enos.ubuntu,
    provider.enos.rhel
  ]

  locals {
    artifact_path = matrix.artifact_source != "artifactory" ? abspath(var.vault_artifact_path) : null
    enos_provider = {
      rhel   = provider.enos.rhel
      ubuntu = provider.enos.ubuntu
    }
    manage_service    = matrix.artifact_type == "bundle"
    vault_install_dir = matrix.artifact_type == "bundle" ? var.vault_install_dir : global.vault_install_dir_packages[matrix.distro]
  }

  step "build_vault" {
    description = global.description.build_vault
    module      = "build_${matrix.artifact_source}"

    variables {
      build_tags           = var.vault_local_build_tags != null ? var.vault_local_build_tags : global.build_tags[matrix.edition]
      artifact_path        = local.artifact_path
      goarch               = matrix.arch
      goos                 = "linux"
      artifactory_host     = matrix.artifact_source == "artifactory" ? var.artifactory_host : null
      artifactory_repo     = matrix.artifact_source == "artifactory" ? var.artifactory_repo : null
      artifactory_username = matrix.artifact_source == "artifactory" ? var.artifactory_username : null
      artifactory_token    = matrix.artifact_source == "artifactory" ? var.artifactory_token : null
      arch                 = matrix.artifact_source == "artifactory" ? matrix.arch : null
      product_version      = var.vault_product_version
      artifact_type        = matrix.artifact_type
      distro               = matrix.artifact_source == "artifactory" ? matrix.distro : null
      edition              = matrix.artifact_source == "artifactory" ? matrix.edition : null
      revision             = var.vault_revision
    }
  }

  step "ec2_info" {
    description = global.description.ec2_info
    module      = module.ec2_info
  }

  step "create_vpc" {
    description = global.description.create_vpc
    module      = module.create_vpc

    variables {
      common_tags = global.tags
    }
  }

  // This step reads the contents of the backend license if we're using a Consul backend and
  // the edition is "ent".
  step "read_backend_license" {
    description = global.description.read_backend_license
    skip_step   = matrix.backend == "raft" || var.backend_edition == "ce"
    module      = module.read_license

    variables {
      file_name = global.backend_license_path
    }
  }

  step "read_vault_license" {
    description = global.description.read_vault_license
    skip_step   = matrix.edition == "ce"
    module      = module.read_license

    variables {
      file_name = global.vault_license_path
    }
  }

  step "create_seal_key" {
    description = global.description.create_seal_key
    module      = "seal_${matrix.seal}"
    depends_on  = [step.create_vpc]

    providers = {
      enos = provider.enos.ubuntu
    }

    variables {
      cluster_id  = step.create_vpc.id
      common_tags = global.tags
    }
  }

  step "create_vault_cluster_targets" {
    description = global.description.create_vault_cluster_targets
    module      = module.target_ec2_instances
    depends_on  = [step.create_vpc]

    providers = {
      enos = local.enos_provider[matrix.distro]
    }

    variables {
      ami_id          = step.ec2_info.ami_ids[matrix.arch][matrix.distro][global.distro_version[matrix.distro]]
      cluster_tag_key = global.vault_tag_key
      common_tags     = global.tags
      seal_key_names  = step.create_seal_key.resource_names
      vpc_id          = step.create_vpc.id
    }
  }

  step "create_vault_cluster_backend_targets" {
    description = global.description.create_vault_cluster_targets
    module      = matrix.backend == "consul" ? module.target_ec2_instances : module.target_ec2_shim
    depends_on  = [step.create_vpc]

    providers = {
      enos = provider.enos.ubuntu
    }

    variables {
      ami_id          = step.ec2_info.ami_ids["arm64"]["ubuntu"]["22.04"]
      cluster_tag_key = global.backend_tag_key
      common_tags     = global.tags
      seal_key_names  = step.create_seal_key.resource_names
      vpc_id          = step.create_vpc.id
    }
  }

  step "create_backend_cluster" {
    description = global.description.create_backend_cluster
    module      = "backend_${matrix.backend}"
    depends_on = [
      step.create_vault_cluster_backend_targets,
    ]

    providers = {
      enos = provider.enos.ubuntu
    }

    verifies = [
      // verified in modules
      quality.consul_can_start,
      quality.consul_can_be_configured,
      quality.consul_can_autojoin_with_aws,
      quality.consul_can_elect_leader,
      // verified in enos_consul_start resource
      quality.consul_cli_validate_validates_configuration,
      quality.consul_systemd_unit_is_valid,
      quality.consul_notifies_systemd,
      quality.consul_has_min_x_healthy_nodes,
      quality.consul_has_min_x_voters,
      quality.consul_api_agent_host_returns_host_info,
      quality.consul_api_health_node_returns_node_health,
      quality.consul_api_operator_raft_configuration_returns_raft_configuration,
    ]

    variables {
      cluster_name    = step.create_vault_cluster_backend_targets.cluster_name
      cluster_tag_key = global.backend_tag_key
      license         = (matrix.backend == "consul" && var.backend_edition == "ent") ? step.read_backend_license.license : null
      release = {
        edition = var.backend_edition
        version = matrix.consul_version
      }
      target_hosts = step.create_vault_cluster_backend_targets.hosts
    }
  }

  step "create_vault_cluster" {
    description = global.description.create_vault_cluster
    module      = module.vault_cluster
    depends_on = [
      step.create_backend_cluster,
      step.build_vault,
      step.create_vault_cluster_targets
    ]

    providers = {
      enos = local.enos_provider[matrix.distro]
    }

    verifies = [
      // verified in modules
      quality.vault_can_install_artifact_bundle,
      quality.vault_can_install_artifact_deb,
      quality.vault_can_install_artifact_rpm,
      quality.vault_can_start,
      quality.vault_can_be_configured_with_env_variables,
      quality.vault_can_be_configured_with_config_file,
      quality.vault_can_initialize,
      quality.vault_can_autojoin_with_aws,
      quality.vault_can_use_log_auditor,
      quality.vault_can_use_syslog_auditor,
      quality.vault_can_use_socket_auditor,
      quality.vault_can_use_consul_storage,
      quality.vault_can_use_raft_storage,
      quality.vault_can_modify_log_level,
      quality.vault_requires_license_for_enterprise_editions,
      // verified in enos_vault_start resource
      quality.vault_systemd_unit_is_valid,
      quality.vault_notifies_systemd,
      quality.vault_cli_status_exits_with_correct_code,
      quality.vault_api_sys_seal_status_api_matches_health,
      quality.vault_api_sys_health_returns_correct_status,
      quality.vault_api_sys_config_returns_config,
      quality.vault_api_sys_ha_status_returns_ha_status,
      quality.vault_api_sys_host_info_returns_host_info,
      quality.vault_api_sys_storage_raft_configuration_returns_configuration,
      quality.vault_api_sys_storage_raft_autopilot_configuration_returns_autopilot_configuration,
      quality.vault_api_sys_storage_raft_autopilot_state_returns_autopilot_state,
      quality.vault_api_sys_replication_status_returns_replication_status,
    ]

    variables {
      backend_cluster_name    = step.create_vault_cluster_backend_targets.cluster_name
      backend_cluster_tag_key = global.backend_tag_key
      cluster_name            = step.create_vault_cluster_targets.cluster_name
      config_mode             = matrix.config_mode
      consul_license          = (matrix.backend == "consul" && var.backend_edition == "ent") ? step.read_backend_license.license : null
      consul_release = matrix.backend == "consul" ? {
        edition = var.backend_edition
        version = matrix.consul_version
      } : null
      enable_audit_devices = var.vault_enable_audit_devices
      install_dir          = local.vault_install_dir
      license              = matrix.edition != "ce" ? step.read_vault_license.license : null
      packages             = concat(global.packages, global.distro_packages[matrix.distro])
      release = {
        edition = matrix.edition
        version = matrix.initial_version
      }
      seal_attributes = step.create_seal_key.attributes
      seal_type       = matrix.seal
      storage_backend = matrix.backend
      target_hosts    = step.create_vault_cluster_targets.hosts
    }
  }

  step "get_local_metadata" {
    description = global.description.get_local_metadata
    skip_step   = matrix.artifact_source != "local"
    module      = module.get_local_metadata
  }

  // Wait for our cluster to elect a leader
  step "wait_for_leader" {
    description = global.description.wait_for_cluster_to_have_leader
    module      = module.vault_wait_for_leader
    depends_on  = [step.create_vault_cluster]

    providers = {
      enos = local.enos_provider[matrix.distro]
    }

    verifies = [
      quality.vault_can_elect_leader_after_unseal,
      quality.vault_api_sys_leader_returns_leader,
    ]

    variables {
      timeout           = 120 # seconds
      vault_hosts       = step.create_vault_cluster_targets.hosts
      vault_install_dir = local.vault_install_dir
      vault_root_token  = step.create_vault_cluster.root_token
    }
  }

  step "get_vault_cluster_ips" {
    description = global.description.get_vault_cluster_ip_addresses
    module      = module.vault_get_cluster_ips
    depends_on  = [step.create_vault_cluster]

    providers = {
      enos = local.enos_provider[matrix.distro]
    }

    verifies = [
      quality.vault_api_sys_ha_status_returns_ha_status,
      quality.vault_api_sys_leader_returns_leader,
      quality.vault_cli_operator_members_contains_members,
    ]

    variables {
      vault_hosts       = step.create_vault_cluster_targets.hosts
      vault_install_dir = local.vault_install_dir
      vault_root_token  = step.create_vault_cluster.root_token
    }
  }

  step "verify_write_test_data" {
    description = global.description.verify_write_test_data
    module      = module.vault_verify_write_data
    depends_on = [
      step.create_vault_cluster,
      step.get_vault_cluster_ips,
    ]

    providers = {
      enos = local.enos_provider[matrix.distro]
    }

    verifies = [
      quality.vault_can_mount_auth,
      quality.vault_can_write_auth_user_policies,
      quality.vault_can_mount_kv,
      quality.vault_can_write_kv_data,
    ]

    variables {
      leader_public_ip  = step.get_vault_cluster_ips.leader_public_ip
      leader_private_ip = step.get_vault_cluster_ips.leader_private_ip
      vault_instances   = step.create_vault_cluster_targets.hosts
      vault_install_dir = local.vault_install_dir
      vault_root_token  = step.create_vault_cluster.root_token
    }
  }

  # This step upgrades the Vault cluster to the var.vault_product_version
  # by getting a bundle or package of that version from the matrix.artifact_source
  step "upgrade_vault" {
    description = <<-EOF
      Perform an in-place upgrade of the Vault Cluster nodes by first installing a new version
      of Vault on the cluster node machines and restarting the service.
    EOF
    module      = module.vault_upgrade
    depends_on = [
      step.create_vault_cluster,
      step.verify_write_test_data,
    ]

    providers = {
      enos = local.enos_provider[matrix.distro]
    }

    verifies = [
      quality.vault_can_restart,
      quality.vault_can_upgrade_in_place,
    ]

    variables {
      vault_api_addr            = "http://localhost:8200"
      vault_instances           = step.create_vault_cluster_targets.hosts
      vault_local_artifact_path = local.artifact_path
      vault_artifactory_release = matrix.artifact_source == "artifactory" ? step.build_vault.vault_artifactory_release : null
      vault_install_dir         = local.vault_install_dir
      vault_unseal_keys         = matrix.seal == "shamir" ? step.create_vault_cluster.unseal_keys_hex : null
      vault_seal_type           = matrix.seal
    }
  }

  // Wait for our upgraded cluster to elect a leader
  step "wait_for_leader_after_upgrade" {
    description = global.description.wait_for_cluster_to_have_leader
    module      = module.vault_wait_for_leader
    depends_on = [
      step.create_vault_cluster,
      step.upgrade_vault,
    ]

    providers = {
      enos = local.enos_provider[matrix.distro]
    }

    verifies = [
      quality.vault_can_elect_leader_after_unseal,
      quality.vault_api_sys_leader_returns_leader,
    ]

    variables {
      timeout           = 120 # seconds
      vault_hosts       = step.create_vault_cluster_targets.hosts
      vault_install_dir = local.vault_install_dir
      vault_root_token  = step.create_vault_cluster.root_token
    }
  }

  step "get_leader_ip_for_step_down" {
    description = global.description.get_vault_cluster_ip_addresses
    module      = module.vault_get_cluster_ips
    depends_on  = [step.wait_for_leader_after_upgrade]

    providers = {
      enos = local.enos_provider[matrix.distro]
    }

    verifies = [
      quality.vault_api_sys_ha_status_returns_ha_status,
      quality.vault_api_sys_leader_returns_leader,
      quality.vault_cli_operator_members_contains_members,
    ]

    variables {
      vault_hosts       = step.create_vault_cluster_targets.hosts
      vault_install_dir = local.vault_install_dir
      vault_root_token  = step.create_vault_cluster.root_token
    }
  }

  // Force a step down to trigger a new leader election
  step "vault_leader_step_down" {
    description = global.description.vault_leader_step_down
    module      = module.vault_step_down
    depends_on  = [step.get_leader_ip_for_step_down]

    providers = {
      enos = local.enos_provider[matrix.distro]
    }

    verifies = [
      quality.vault_cli_operator_step_down_steps_down,
      quality.vault_api_sys_step_down_steps_down,
    ]

    variables {
      vault_install_dir = local.vault_install_dir
      leader_host       = step.get_leader_ip_for_step_down.leader_host
      vault_root_token  = step.create_vault_cluster.root_token
    }
  }

  // Wait for our cluster to elect a leader
  step "wait_for_leader_after_stepdown" {
    description = global.description.wait_for_cluster_to_have_leader
    module      = module.vault_wait_for_leader
    depends_on  = [step.vault_leader_step_down]

    providers = {
      enos = local.enos_provider[matrix.distro]
    }

    verifies = [
      quality.vault_can_elect_leader_after_unseal,
      quality.vault_api_sys_leader_returns_leader,
    ]

    variables {
      timeout           = 120 # seconds
      vault_hosts       = step.create_vault_cluster_targets.hosts
      vault_install_dir = local.vault_install_dir
      vault_root_token  = step.create_vault_cluster.root_token
    }
  }

  step "get_updated_vault_cluster_ips" {
    description = global.description.get_vault_cluster_ip_addresses
    module      = module.vault_get_cluster_ips
    depends_on = [
      step.wait_for_leader_after_stepdown,
    ]

    providers = {
      enos = local.enos_provider[matrix.distro]
    }

    verifies = [
      quality.vault_api_sys_ha_status_returns_ha_status,
      quality.vault_api_sys_leader_returns_leader,
      quality.vault_cli_operator_members_contains_members,
    ]

    variables {
      vault_hosts       = step.create_vault_cluster_targets.hosts
      vault_install_dir = local.vault_install_dir
      vault_root_token  = step.create_vault_cluster.root_token
    }
  }

  step "verify_vault_version" {
    description = global.description.verify_vault_version
    module      = module.vault_verify_version
    depends_on = [
      step.get_updated_vault_cluster_ips,
    ]

    providers = {
      enos = local.enos_provider[matrix.distro]
    }

    verifies = [
      quality.vault_has_expected_build_date,
      quality.vault_has_expected_edition,
      quality.vault_has_expected_version,
    ]

    variables {
      vault_instances       = step.create_vault_cluster_targets.hosts
      vault_edition         = matrix.edition
      vault_install_dir     = local.vault_install_dir
      vault_product_version = matrix.artifact_source == "local" ? step.get_local_metadata.version : var.vault_product_version
      vault_revision        = matrix.artifact_source == "local" ? step.get_local_metadata.revision : var.vault_revision
      vault_build_date      = matrix.artifact_source == "local" ? step.get_local_metadata.build_date : var.vault_build_date
      vault_root_token      = step.create_vault_cluster.root_token
    }
  }

  step "verify_vault_unsealed" {
    description = global.description.verify_vault_unsealed
    module      = module.vault_verify_unsealed
    depends_on = [
      step.get_updated_vault_cluster_ips,
    ]

    providers = {
      enos = local.enos_provider[matrix.distro]
    }

    verifies = [
      quality.vault_can_unseal_with_shamir,
      quality.vault_can_unseal_with_awskms,
      quality.vault_can_unseal_with_pkcs11,
    ]

    variables {
      vault_instances   = step.create_vault_cluster_targets.hosts
      vault_install_dir = local.vault_install_dir
    }
  }

  step "verify_read_test_data" {
    description = global.description.verify_write_test_data
    module      = module.vault_verify_read_data
    depends_on = [
      step.get_updated_vault_cluster_ips,
      step.verify_write_test_data,
      step.verify_vault_unsealed
    ]

    providers = {
      enos = local.enos_provider[matrix.distro]
    }

    verifies = [
      quality.vault_can_mount_auth,
      quality.vault_can_write_auth_user_policies,
      quality.vault_can_mount_kv,
      quality.vault_can_write_kv_data,
    ]

    variables {
      node_public_ips   = step.get_updated_vault_cluster_ips.follower_public_ips
      vault_install_dir = local.vault_install_dir
    }
  }

  step "verify_raft_auto_join_voter" {
    description = global.description.verify_all_nodes_are_raft_voters
    skip_step   = matrix.backend != "raft"
    module      = module.vault_verify_raft_auto_join_voter
    depends_on = [
      step.get_updated_vault_cluster_ips,
    ]

    providers = {
      enos = local.enos_provider[matrix.distro]
    }

    verifies = quality.vault_all_nodes_are_raft_voters

    variables {
      vault_install_dir = local.vault_install_dir
      vault_instances   = step.create_vault_cluster_targets.hosts
      vault_root_token  = step.create_vault_cluster.root_token
    }
  }

  step "verify_replication" {
    description = global.description.verify_replication_status
    module      = module.vault_verify_replication
    depends_on = [
      step.get_updated_vault_cluster_ips,
    ]

    providers = {
      enos = local.enos_provider[matrix.distro]
    }

    verifies = [
      quality.vault_replication_is_not_enabled_for_ce,
      quality.vault_dr_replication_status_is_available_ent,
      quality.vault_pr_replication_status_is_available_ent,
    ]

    variables {
      vault_edition     = matrix.edition
      vault_install_dir = local.vault_install_dir
      vault_instances   = step.create_vault_cluster_targets.hosts
    }
  }

  step "verify_ui" {
    description = global.description.verify_ui
    module      = module.vault_verify_ui
    depends_on = [
      step.get_updated_vault_cluster_ips,
    ]

    providers = {
      enos = local.enos_provider[matrix.distro]
    }

    verifies = quality.vault_ui_is_available

    variables {
      vault_instances = step.create_vault_cluster_targets.hosts
    }
  }

  output "audit_device_file_path" {
    description = "The file path for the file audit device, if enabled"
    value       = step.create_vault_cluster.audit_device_file_path
  }

  output "cluster_name" {
    description = "The Vault cluster name"
    value       = step.create_vault_cluster.cluster_name
  }

  output "hosts" {
    description = "The Vault cluster target hosts"
    value       = step.create_vault_cluster.target_hosts
  }

  output "private_ips" {
    description = "The Vault cluster private IPs"
    value       = step.create_vault_cluster.private_ips
  }

  output "public_ips" {
    description = "The Vault cluster public IPs"
    value       = step.create_vault_cluster.public_ips
  }

  output "root_token" {
    description = "The Vault cluster root token"
    value       = step.create_vault_cluster.root_token
  }

  output "recovery_key_shares" {
    description = "The Vault cluster recovery key shares"
    value       = step.create_vault_cluster.recovery_key_shares
  }

  output "recovery_keys_b64" {
    description = "The Vault cluster recovery keys b64"
    value       = step.create_vault_cluster.recovery_keys_b64
  }

  output "recovery_keys_hex" {
    description = "The Vault cluster recovery keys hex"
    value       = step.create_vault_cluster.recovery_keys_hex
  }

  output "seal_name" {
    description = "The Vault cluster seal attributes"
    value       = step.create_seal_key.attributes
  }

  output "unseal_keys_b64" {
    description = "The Vault cluster unseal keys"
    value       = step.create_vault_cluster.unseal_keys_b64
  }

  output "unseal_keys_hex" {
    description = "The Vault cluster unseal keys hex"
    value       = step.create_vault_cluster.unseal_keys_hex
  }
}

# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: BUSL-1.1

scenario "replication" {
  description = <<-EOF
    The replication scenario configures performance replication between two Vault clusters and
    performs various verification.

    After establishing performance replication we simulate a catastrophic failure whereby the
    primary leader and follower as ungracefully removed from the cluster, forcing a leader
    election in the primary cluster and for the secondary cluster to recover replication.
  EOF

  matrix {
    arch              = global.archs
    artifact_source   = global.artifact_sources
    artifact_type     = global.artifact_types
    config_mode       = global.config_modes
    consul_version    = global.consul_versions
    distro            = global.distros
    edition           = global.enterprise_editions
    primary_backend   = global.backends
    primary_seal      = global.seals
    secondary_backend = global.backends
    secondary_seal    = global.seals

    # Our local builder always creates bundles
    exclude {
      artifact_source = ["local"]
      artifact_type   = ["package"]
    }

    # HSM and FIPS 140-2 are only supported on amd64
    exclude {
      arch    = ["arm64"]
      edition = ["ent.fips1402", "ent.hsm", "ent.hsm.fips1402"]
    }

    # PKCS#11 can only be used on ent.hsm and ent.hsm.fips1402.
    exclude {
      primary_seal = ["pkcs11"]
      edition      = [for e in matrix.edition : e if !strcontains(e, "hsm")]
    }

    exclude {
      secondary_seal = ["pkcs11"]
      edition        = [for e in matrix.edition : e if !strcontains(e, "hsm")]
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
    skip_step   = (matrix.primary_backend == "raft" && matrix.secondary_backend == "raft") || var.backend_edition == "ce"
    module      = module.read_license

    variables {
      file_name = global.backend_license_path
    }
  }

  step "read_vault_license" {
    description = global.description.read_vault_license
    module      = module.read_license

    variables {
      file_name = abspath(joinpath(path.root, "./support/vault.hclic"))
    }
  }

  step "create_primary_seal_key" {
    description = global.description.create_seal_key
    module      = "seal_${matrix.primary_seal}"
    depends_on  = [step.create_vpc]

    providers = {
      enos = provider.enos.ubuntu
    }

    variables {
      cluster_id   = step.create_vpc.id
      cluster_meta = "primary"
      common_tags  = global.tags
    }
  }

  step "create_secondary_seal_key" {
    description = global.description.create_seal_key
    module      = "seal_${matrix.secondary_seal}"
    depends_on  = [step.create_vpc]

    providers = {
      enos = provider.enos.ubuntu
    }

    variables {
      cluster_id      = step.create_vpc.id
      cluster_meta    = "secondary"
      common_tags     = global.tags
      other_resources = step.create_primary_seal_key.resource_names
    }
  }

  # Create all of our instances for both primary and secondary clusters
  step "create_primary_cluster_targets" {
    description = global.description.create_vault_cluster_targets
    module      = module.target_ec2_instances
    depends_on = [
      step.create_vpc,
    ]

    providers = {
      enos = local.enos_provider[matrix.distro]
    }

    variables {
      ami_id          = step.ec2_info.ami_ids[matrix.arch][matrix.distro][global.distro_version[matrix.distro]]
      cluster_tag_key = global.vault_tag_key
      common_tags     = global.tags
      seal_key_names  = step.create_primary_seal_key.resource_names
      vpc_id          = step.create_vpc.id
    }
  }

  step "create_primary_cluster_backend_targets" {
    description = global.description.create_vault_cluster_targets
    module      = matrix.primary_backend == "consul" ? module.target_ec2_instances : module.target_ec2_shim
    depends_on = [
      step.create_vpc,
    ]

    providers = {
      enos = provider.enos.ubuntu
    }

    variables {
      ami_id          = step.ec2_info.ami_ids["arm64"]["ubuntu"]["22.04"]
      cluster_tag_key = global.backend_tag_key
      common_tags     = global.tags
      seal_key_names  = step.create_primary_seal_key.resource_names
      vpc_id          = step.create_vpc.id
    }
  }

  step "create_primary_cluster_additional_targets" {
    description = global.description.create_vault_cluster_targets
    module      = module.target_ec2_instances
    depends_on = [
      step.create_vpc,
      step.create_primary_cluster_targets,
    ]

    providers = {
      enos = local.enos_provider[matrix.distro]
    }

    variables {
      ami_id          = step.ec2_info.ami_ids[matrix.arch][matrix.distro][global.distro_version[matrix.distro]]
      cluster_name    = step.create_primary_cluster_targets.cluster_name
      cluster_tag_key = global.vault_tag_key
      common_tags     = global.tags
      seal_key_names  = step.create_primary_seal_key.resource_names
      vpc_id          = step.create_vpc.id
    }
  }

  step "create_secondary_cluster_targets" {
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
      seal_key_names  = step.create_secondary_seal_key.resource_names
      vpc_id          = step.create_vpc.id
    }
  }

  step "create_secondary_cluster_backend_targets" {
    description = global.description.create_vault_cluster_targets
    module      = matrix.secondary_backend == "consul" ? module.target_ec2_instances : module.target_ec2_shim
    depends_on  = [step.create_vpc]

    providers = {
      enos = provider.enos.ubuntu
    }

    variables {
      ami_id          = step.ec2_info.ami_ids["arm64"]["ubuntu"]["22.04"]
      cluster_tag_key = global.backend_tag_key
      common_tags     = global.tags
      seal_key_names  = step.create_secondary_seal_key.resource_names
      vpc_id          = step.create_vpc.id
    }
  }

  step "create_primary_backend_cluster" {
    description = global.description.create_backend_cluster
    module      = "backend_${matrix.primary_backend}"
    depends_on = [
      step.create_primary_cluster_backend_targets,
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
      cluster_name    = step.create_primary_cluster_backend_targets.cluster_name
      cluster_tag_key = global.backend_tag_key
      license         = (matrix.primary_backend == "consul" && var.backend_edition == "ent") ? step.read_backend_license.license : null
      release = {
        edition = var.backend_edition
        version = matrix.consul_version
      }
      target_hosts = step.create_primary_cluster_backend_targets.hosts
    }
  }

  step "create_primary_cluster" {
    description = global.description.create_vault_cluster
    module      = module.vault_cluster
    depends_on = [
      step.create_primary_backend_cluster,
      step.build_vault,
      step.create_primary_cluster_targets
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
      artifactory_release     = matrix.artifact_source == "artifactory" ? step.build_vault.vault_artifactory_release : null
      backend_cluster_name    = step.create_primary_cluster_backend_targets.cluster_name
      backend_cluster_tag_key = global.backend_tag_key
      config_mode             = matrix.config_mode
      consul_license          = (matrix.primary_backend == "consul" && var.backend_edition == "ent") ? step.read_backend_license.license : null
      cluster_name            = step.create_primary_cluster_targets.cluster_name
      consul_release = matrix.primary_backend == "consul" ? {
        edition = var.backend_edition
        version = matrix.consul_version
      } : null
      enable_audit_devices = var.vault_enable_audit_devices
      install_dir          = local.vault_install_dir
      license              = matrix.edition != "ce" ? step.read_vault_license.license : null
      local_artifact_path  = local.artifact_path
      manage_service       = local.manage_service
      packages             = concat(global.packages, global.distro_packages[matrix.distro])
      seal_attributes      = step.create_primary_seal_key.attributes
      seal_type            = matrix.primary_seal
      storage_backend      = matrix.primary_backend
      target_hosts         = step.create_primary_cluster_targets.hosts
    }
  }

  step "get_local_metadata" {
    skip_step = matrix.artifact_source != "local"
    module    = module.get_local_metadata
  }

  step "wait_for_primary_cluster_leader" {
    description = global.description.wait_for_cluster_to_have_leader
    module      = module.vault_wait_for_leader
    depends_on  = [step.create_primary_cluster]

    providers = {
      enos = local.enos_provider[matrix.distro]
    }

    verifies = [
      quality.vault_can_elect_leader_after_unseal,
      quality.vault_api_sys_leader_returns_leader,
    ]

    variables {
      timeout           = 120 # seconds
      vault_hosts       = step.create_primary_cluster_targets.hosts
      vault_install_dir = local.vault_install_dir
      vault_root_token  = step.create_primary_cluster.root_token
    }
  }

  step "create_secondary_backend_cluster" {
    description = global.description.create_backend_cluster
    module      = "backend_${matrix.secondary_backend}"
    depends_on = [
      step.create_secondary_cluster_backend_targets
    ]

    providers = {
      enos = provider.enos.ubuntu
    }

    variables {
      cluster_name    = step.create_secondary_cluster_backend_targets.cluster_name
      cluster_tag_key = global.backend_tag_key
      license         = (matrix.secondary_backend == "consul" && var.backend_edition == "ent") ? step.read_backend_license.license : null
      release = {
        edition = var.backend_edition
        version = matrix.consul_version
      }
      target_hosts = step.create_secondary_cluster_backend_targets.hosts
    }
  }

  step "create_secondary_cluster" {
    module = module.vault_cluster
    depends_on = [
      step.create_secondary_backend_cluster,
      step.build_vault,
      step.create_secondary_cluster_targets
    ]

    providers = {
      enos = local.enos_provider[matrix.distro]
    }

    verifies = [
      // verified in modules
      quality.consul_can_start,
      quality.consul_can_be_configured,
      quality.consul_can_autojoin_with_aws,
      quality.consul_can_elect_leader,
      // verified in enos_consul_start resource
      quality.consul_systemd_unit_is_valid,
      quality.consul_notifies_systemd,
      quality.consul_has_min_x_healthy_nodes,
      quality.consul_has_min_x_voters,
      quality.consul_api_agent_host_returns_host_info,
      quality.consul_api_health_node_returns_node_health,
      quality.consul_api_operator_raft_configuration_returns_raft_configuration,
    ]

    variables {
      artifactory_release     = matrix.artifact_source == "artifactory" ? step.build_vault.vault_artifactory_release : null
      backend_cluster_name    = step.create_secondary_cluster_backend_targets.cluster_name
      backend_cluster_tag_key = global.backend_tag_key
      config_mode             = matrix.config_mode
      consul_license          = (matrix.secondary_backend == "consul" && var.backend_edition == "ent") ? step.read_backend_license.license : null
      cluster_name            = step.create_secondary_cluster_targets.cluster_name
      consul_release = matrix.secondary_backend == "consul" ? {
        edition = var.backend_edition
        version = matrix.consul_version
      } : null
      enable_audit_devices = var.vault_enable_audit_devices
      install_dir          = local.vault_install_dir
      license              = matrix.edition != "ce" ? step.read_vault_license.license : null
      local_artifact_path  = local.artifact_path
      manage_service       = local.manage_service
      packages             = concat(global.packages, global.distro_packages[matrix.distro])
      seal_attributes      = step.create_secondary_seal_key.attributes
      seal_type            = matrix.secondary_seal
      storage_backend      = matrix.secondary_backend
      target_hosts         = step.create_secondary_cluster_targets.hosts
    }
  }

  step "wait_for_secondary_cluster_leader" {
    description = global.description.wait_for_cluster_to_have_leader
    module      = module.vault_wait_for_leader
    depends_on  = [step.create_secondary_cluster]

    providers = {
      enos = local.enos_provider[matrix.distro]
    }

    verifies = [
      quality.vault_can_elect_leader_after_unseal,
      quality.vault_api_sys_leader_returns_leader,
    ]

    variables {
      timeout           = 120 # seconds
      vault_hosts       = step.create_secondary_cluster_targets.hosts
      vault_install_dir = local.vault_install_dir
      vault_root_token  = step.create_secondary_cluster.root_token
    }
  }

  step "verify_that_vault_primary_cluster_is_unsealed" {
    description = global.description.verify_vault_unsealed
    module      = module.vault_verify_unsealed
    depends_on = [
      step.create_primary_cluster,
      step.wait_for_primary_cluster_leader,
    ]

    providers = {
      enos = local.enos_provider[matrix.distro]
    }

    verifies = [
      quality.vault_can_unseal_with_shamir,
      quality.vault_can_unseal_with_awskms,
      quality.vault_can_unseal_with_pkcs11,
      quality.vault_auto_unseals_after_autopilot_upgrade,
    ]

    variables {
      vault_instances   = step.create_primary_cluster_targets.hosts
      vault_install_dir = local.vault_install_dir
    }
  }

  step "verify_that_vault_secondary_cluster_is_unsealed" {
    description = global.description.verify_vault_unsealed
    module      = module.vault_verify_unsealed
    depends_on = [
      step.create_secondary_cluster,
      step.wait_for_secondary_cluster_leader,
    ]

    providers = {
      enos = local.enos_provider[matrix.distro]
    }

    verifies = [
      quality.vault_can_unseal_with_shamir,
      quality.vault_can_unseal_with_awskms,
      quality.vault_can_unseal_with_pkcs11,
      quality.vault_auto_unseals_after_autopilot_upgrade,
    ]

    variables {
      vault_instances   = step.create_secondary_cluster_targets.hosts
      vault_install_dir = local.vault_install_dir
    }
  }

  step "verify_vault_version" {
    description = global.description.verify_vault_version
    module      = module.vault_verify_version
    depends_on = [
      step.create_primary_cluster,
      step.wait_for_primary_cluster_leader,
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
      vault_instances       = step.create_primary_cluster_targets.hosts
      vault_edition         = matrix.edition
      vault_install_dir     = local.vault_install_dir
      vault_product_version = matrix.artifact_source == "local" ? step.get_local_metadata.version : var.vault_product_version
      vault_revision        = matrix.artifact_source == "local" ? step.get_local_metadata.revision : var.vault_revision
      vault_build_date      = matrix.artifact_source == "local" ? step.get_local_metadata.build_date : var.vault_build_date
      vault_root_token      = step.create_primary_cluster.root_token
    }
  }

  step "verify_ui" {
    description = global.description.verify_ui
    module      = module.vault_verify_ui
    depends_on = [
      step.create_primary_cluster,
      step.wait_for_primary_cluster_leader,
    ]

    providers = {
      enos = local.enos_provider[matrix.distro]
    }

    verifies = quality.vault_ui_is_available

    variables {
      vault_instances = step.create_primary_cluster_targets.hosts
    }
  }

  step "get_primary_cluster_ips" {
    description = global.description.get_vault_cluster_ip_addresses
    module      = module.vault_get_cluster_ips
    depends_on  = [step.verify_that_vault_primary_cluster_is_unsealed]

    providers = {
      enos = local.enos_provider[matrix.distro]
    }

    verifies = [
      quality.vault_api_sys_ha_status_returns_ha_status,
      quality.vault_api_sys_leader_returns_leader,
      quality.vault_cli_operator_members_contains_members,
    ]

    variables {
      vault_hosts       = step.create_primary_cluster_targets.hosts
      vault_install_dir = local.vault_install_dir
      vault_root_token  = step.create_primary_cluster.root_token
    }
  }

  step "get_primary_cluster_replication_data" {
    description = <<-EOF
      An arithmetic module that we use to determine various metadata about the the leader and
      follower nodes of the primary cluster so that we can correctly enable performance replication.
    EOF
    module      = module.replication_data
    depends_on  = [step.get_primary_cluster_ips]

    variables {
      follower_hosts = step.get_primary_cluster_ips.follower_hosts
    }
  }

  step "get_secondary_cluster_ips" {
    description = global.description.get_vault_cluster_ip_addresses
    module      = module.vault_get_cluster_ips
    depends_on  = [step.verify_that_vault_secondary_cluster_is_unsealed]

    providers = {
      enos = local.enos_provider[matrix.distro]
    }

    verifies = [
      quality.vault_api_sys_ha_status_returns_ha_status,
      quality.vault_api_sys_leader_returns_leader,
      quality.vault_cli_operator_members_contains_members,
    ]

    variables {
      vault_hosts       = step.create_secondary_cluster_targets.hosts
      vault_install_dir = local.vault_install_dir
      vault_root_token  = step.create_secondary_cluster.root_token
    }
  }

  step "write_test_data_on_primary" {
    description = global.description.verify_write_test_data
    module      = module.vault_verify_write_data
    depends_on  = [step.get_primary_cluster_ips]


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
      leader_public_ip  = step.get_primary_cluster_ips.leader_public_ip
      leader_private_ip = step.get_primary_cluster_ips.leader_private_ip
      vault_instances   = step.create_primary_cluster_targets.hosts
      vault_install_dir = local.vault_install_dir
      vault_root_token  = step.create_primary_cluster.root_token
    }
  }

  step "configure_performance_replication_primary" {
    description = <<-EOF
      Create the necessary superuser auth policy necessary for performance replicaztion, assign it
      to a our previously create test user, and enable performance replication on the primary
      cluster.
    EOF
    module      = module.vault_setup_perf_primary
    depends_on = [
      step.get_primary_cluster_ips,
      step.get_secondary_cluster_ips,
      step.write_test_data_on_primary
    ]

    providers = {
      enos = local.enos_provider[matrix.distro]
    }

    verifies = [
      quality.vault_api_sys_auth_userpass_associates_policy,
      quality.vault_api_sys_policy_writes_superuser_policy,
      quality.vault_api_sys_replication_performance_primary_enable_enables_replication,
      quality.vault_cli_policy_write_writes_policy,
    ]

    variables {
      primary_leader_public_ip  = step.get_primary_cluster_ips.leader_public_ip
      primary_leader_private_ip = step.get_primary_cluster_ips.leader_private_ip
      vault_install_dir         = local.vault_install_dir
      vault_root_token          = step.create_primary_cluster.root_token
    }
  }

  step "generate_secondary_token" {
    description = <<-EOF
      Generate a random token and configure the performance replication primary secondary-token and
      configure the Vault cluster primary replication with the token. Export the wrapping token
      so that secondary clusters can utilize it.
    EOF
    module      = module.generate_secondary_token
    depends_on  = [step.configure_performance_replication_primary]

    verifies = quality.vault_api_sys_replication_performance_primary_secondary_token_configures_token

    providers = {
      enos = local.enos_provider[matrix.distro]
    }

    variables {
      primary_leader_public_ip = step.get_primary_cluster_ips.leader_public_ip
      vault_install_dir        = local.vault_install_dir
      vault_root_token         = step.create_primary_cluster.root_token
    }
  }

  step "configure_performance_replication_secondary" {
    description = <<-EOF
      Enable performance replication on the secondary cluster with the wrapping token created by
      the primary cluster.
    EOF
    module      = module.vault_setup_perf_secondary
    depends_on  = [step.generate_secondary_token]

    providers = {
      enos = local.enos_provider[matrix.distro]
    }

    verifies = quality.vault_api_sys_replication_performance_secondary_enable_enables_replication

    variables {
      secondary_leader_public_ip  = step.get_secondary_cluster_ips.leader_public_ip
      secondary_leader_private_ip = step.get_secondary_cluster_ips.leader_private_ip
      vault_install_dir           = local.vault_install_dir
      vault_root_token            = step.create_secondary_cluster.root_token
      wrapping_token              = step.generate_secondary_token.secondary_token
    }
  }

  step "unseal_secondary_followers" {
    description = <<-EOF
      After replication is enabled the secondary cluster followers need to be unsealed.
      Secondary unseal keys are passed differently depending primary and secondary seal
      type combinations. See the guide for more information:
        https://developer.hashicorp.com/vault/docs/enterprise/replication#seals
    EOF
    module      = module.vault_unseal_nodes
    depends_on = [
      step.create_primary_cluster,
      step.create_secondary_cluster,
      step.get_secondary_cluster_ips,
      step.configure_performance_replication_secondary
    ]

    providers = {
      enos = local.enos_provider[matrix.distro]
    }

    variables {
      follower_public_ips = step.get_secondary_cluster_ips.follower_public_ips
      vault_install_dir   = local.vault_install_dir
      vault_unseal_keys   = matrix.primary_seal == "shamir" ? step.create_primary_cluster.unseal_keys_hex : step.create_primary_cluster.recovery_keys_hex
      vault_seal_type     = matrix.primary_seal == "shamir" ? matrix.primary_seal : matrix.secondary_seal
    }
  }

  step "verify_secondary_cluster_is_unsealed_after_enabling_replication" {
    description = global.description.verify_vault_unsealed
    module      = module.vault_verify_unsealed
    depends_on = [
      step.unseal_secondary_followers
    ]

    providers = {
      enos = local.enos_provider[matrix.distro]
    }

    verifies = [
      quality.vault_can_unseal_with_shamir,
      quality.vault_can_unseal_with_awskms,
      quality.vault_can_unseal_with_pkcs11,
      quality.vault_auto_unseals_after_autopilot_upgrade,
    ]

    variables {
      vault_instances   = step.create_secondary_cluster_targets.hosts
      vault_install_dir = local.vault_install_dir
    }
  }

  step "verify_performance_replication" {
    description = <<-EOF
      Verify that the performance replication status meets our expectations after enabling replication
      and ensuring that all secondary nodes are unsealed.
    EOF
    module      = module.vault_verify_performance_replication
    depends_on  = [step.verify_secondary_cluster_is_unsealed_after_enabling_replication]

    providers = {
      enos = local.enos_provider[matrix.distro]
    }

    verifies = [
      quality.vault_api_sys_replication_performance_status_returns_status,
      quality.vault_api_sys_replication_performance_status_state_is_not_idle,
      quality.vault_api_sys_replication_performance_status_connection_status_is_connected,
      quality.vault_api_sys_replication_performance_status_secondary_cluster_address_is_correct,
      quality.vault_api_sys_replication_performance_status_known_primary_cluster_addrs_is_correct,
    ]

    variables {
      primary_leader_public_ip    = step.get_primary_cluster_ips.leader_public_ip
      primary_leader_private_ip   = step.get_primary_cluster_ips.leader_private_ip
      secondary_leader_public_ip  = step.get_secondary_cluster_ips.leader_public_ip
      secondary_leader_private_ip = step.get_secondary_cluster_ips.leader_private_ip
      vault_install_dir           = local.vault_install_dir
    }
  }

  step "verify_replicated_data" {
    description = global.description.verify_read_test_data
    module      = module.vault_verify_read_data
    depends_on = [
      step.verify_performance_replication,
      step.get_secondary_cluster_ips,
      step.write_test_data_on_primary
    ]

    providers = {
      enos = local.enos_provider[matrix.distro]
    }

    verifies = quality.vault_can_read_kv_data

    variables {
      node_public_ips   = step.get_secondary_cluster_ips.follower_public_ips
      vault_install_dir = local.vault_install_dir
    }
  }

  step "add_additional_nodes_to_primary_cluster" {
    description = <<-EOF
      Add additional nodes the Vault Cluster to prepare for our catostrophic failure simulation.
      These nodes will use a different storage storage_node_prefix
    EOF
    module      = module.vault_cluster
    depends_on = [
      step.create_vpc,
      step.create_primary_backend_cluster,
      step.create_primary_cluster,
      step.verify_replicated_data,
      step.create_primary_cluster_additional_targets
    ]

    providers = {
      enos = local.enos_provider[matrix.distro]
    }

    verifies = [
      // unique to this invocation of the module
      quality.vault_can_add_nodes_to_previously_initialized_cluster,
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
      artifactory_release     = matrix.artifact_source == "artifactory" ? step.build_vault.vault_artifactory_release : null
      backend_cluster_name    = step.create_primary_cluster_backend_targets.cluster_name
      backend_cluster_tag_key = global.backend_tag_key
      cluster_name            = step.create_primary_cluster_targets.cluster_name
      config_mode             = matrix.config_mode
      consul_license          = (matrix.primary_backend == "consul" && var.backend_edition == "ent") ? step.read_backend_license.license : null
      consul_release = matrix.primary_backend == "consul" ? {
        edition = var.backend_edition
        version = matrix.consul_version
      } : null
      enable_audit_devices = var.vault_enable_audit_devices
      force_unseal         = matrix.primary_seal == "shamir"
      // Don't init when adding nodes into the cluster.
      initialize_cluster  = false
      install_dir         = local.vault_install_dir
      license             = matrix.edition != "ce" ? step.read_vault_license.license : null
      local_artifact_path = local.artifact_path
      manage_service      = local.manage_service
      packages            = concat(global.packages, global.distro_packages[matrix.distro])
      root_token          = step.create_primary_cluster.root_token
      seal_attributes     = step.create_primary_seal_key.attributes
      seal_type           = matrix.primary_seal
      shamir_unseal_keys  = matrix.primary_seal == "shamir" ? step.create_primary_cluster.unseal_keys_hex : null
      storage_backend     = matrix.primary_backend
      storage_node_prefix = "newprimary_node"
      target_hosts        = step.create_primary_cluster_additional_targets.hosts
    }
  }

  step "verify_additional_primary_nodes_are_unsealed" {
    description = global.description.verify_vault_unsealed
    module      = module.vault_verify_unsealed
    depends_on  = [step.add_additional_nodes_to_primary_cluster]

    providers = {
      enos = local.enos_provider[matrix.distro]
    }

    verifies = [
      quality.vault_can_unseal_with_shamir,
      quality.vault_can_unseal_with_awskms,
      quality.vault_can_unseal_with_pkcs11,
      quality.vault_auto_unseals_after_autopilot_upgrade,
    ]

    variables {
      vault_instances   = step.create_primary_cluster_additional_targets.hosts
      vault_install_dir = local.vault_install_dir
    }
  }

  step "verify_raft_auto_join_voter" {
    description = global.description.verify_all_nodes_are_raft_voters
    skip_step   = matrix.primary_backend != "raft"
    module      = module.vault_verify_raft_auto_join_voter
    depends_on = [
      step.add_additional_nodes_to_primary_cluster,
      step.create_primary_cluster,
      step.verify_additional_primary_nodes_are_unsealed
    ]

    providers = {
      enos = local.enos_provider[matrix.distro]
    }

    verifies = quality.vault_all_nodes_are_raft_voters

    variables {
      vault_instances   = step.create_primary_cluster_additional_targets.hosts
      vault_install_dir = local.vault_install_dir
      vault_root_token  = step.create_primary_cluster.root_token
    }
  }

  step "remove_primary_follower_1" {
    description = <<-EOF
      Simulate a catostrophic failure by forcefully removing the a follower node from the Vault
      Cluster.
    EOF
    module      = module.shutdown_node
    depends_on = [
      step.get_primary_cluster_replication_data,
      step.verify_additional_primary_nodes_are_unsealed
    ]

    providers = {
      enos = local.enos_provider[matrix.distro]
    }

    variables {
      node_public_ip = step.get_primary_cluster_replication_data.follower_public_ip_1
    }
  }

  step "remove_primary_leader" {
    description = <<-EOF
      Simulate a catostrophic failure by forcefully removing the the primary leader node from the
      Vault Cluster without allowing a graceful shutdown.
    EOF
    module      = module.shutdown_node
    depends_on = [
      step.get_primary_cluster_ips,
      step.remove_primary_follower_1
    ]

    providers = {
      enos = local.enos_provider[matrix.distro]
    }

    variables {
      node_public_ip = step.get_primary_cluster_ips.leader_public_ip
    }
  }

  step "get_remaining_hosts_replication_data" {
    description = <<-EOF
      An arithmetic module that we use to determine various metadata about the the leader and
      follower nodes of the primary cluster so that we can correctly enable performance replication.

      We execute this again to determine information about our hosts after having forced the leader
      and a follower from the cluster.
    EOF

    module = module.replication_data
    depends_on = [
      step.get_primary_cluster_ips,
      step.remove_primary_leader,
    ]

    variables {
      added_hosts           = step.create_primary_cluster_additional_targets.hosts
      added_hosts_count     = var.vault_instance_count
      initial_hosts         = step.create_primary_cluster_targets.hosts
      initial_hosts_count   = var.vault_instance_count
      removed_follower_host = step.get_primary_cluster_replication_data.follower_host_1
      removed_primary_host  = step.get_primary_cluster_ips.leader_host
    }
  }

  step "wait_for_leader_in_remaining_hosts" {
    description = global.description.wait_for_cluster_to_have_leader
    module      = module.vault_wait_for_leader
    depends_on = [
      step.remove_primary_leader,
      step.get_remaining_hosts_replication_data,
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
      vault_install_dir = local.vault_install_dir
      vault_root_token  = step.create_primary_cluster.root_token
      vault_hosts       = step.get_remaining_hosts_replication_data.remaining_hosts
    }
  }

  step "get_updated_primary_cluster_ips" {
    description = global.description.get_vault_cluster_ip_addresses
    module      = module.vault_get_cluster_ips
    depends_on = [
      step.get_remaining_hosts_replication_data,
      step.wait_for_leader_in_remaining_hosts,
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
      vault_hosts          = step.get_remaining_hosts_replication_data.remaining_hosts
      vault_install_dir    = local.vault_install_dir
      vault_instance_count = step.get_remaining_hosts_replication_data.remaining_hosts_count
      vault_root_token     = step.create_primary_cluster.root_token
    }
  }

  step "verify_updated_performance_replication" {
    description = <<-EOF
      Verify that the performance replication status meets our expectations after the new leader
      election.
    EOF

    module = module.vault_verify_performance_replication
    depends_on = [
      step.get_remaining_hosts_replication_data,
      step.wait_for_leader_in_remaining_hosts,
      step.get_updated_primary_cluster_ips,
    ]

    providers = {
      enos = local.enos_provider[matrix.distro]
    }

    verifies = [
      quality.vault_api_sys_replication_performance_status_returns_status,
      quality.vault_api_sys_replication_performance_status_state_is_not_idle,
      quality.vault_api_sys_replication_performance_status_connection_status_is_connected,
      quality.vault_api_sys_replication_performance_status_secondary_cluster_address_is_correct,
      quality.vault_api_sys_replication_performance_status_known_primary_cluster_addrs_is_correct,
    ]

    variables {
      primary_leader_public_ip    = step.get_updated_primary_cluster_ips.leader_public_ip
      primary_leader_private_ip   = step.get_updated_primary_cluster_ips.leader_private_ip
      secondary_leader_public_ip  = step.get_secondary_cluster_ips.leader_public_ip
      secondary_leader_private_ip = step.get_secondary_cluster_ips.leader_private_ip
      vault_install_dir           = local.vault_install_dir
    }
  }

  output "audit_device_file_path" {
    description = "The file path for the file audit device, if enabled"
    value       = step.create_primary_cluster.audit_device_file_path
  }

  output "primary_cluster_hosts" {
    description = "The Vault primary cluster target hosts"
    value       = step.create_primary_cluster_targets.hosts
  }

  output "primary_cluster_additional_hosts" {
    description = "The Vault added new node on primary cluster target hosts"
    value       = step.create_primary_cluster_additional_targets.hosts
  }

  output "primary_cluster_root_token" {
    description = "The Vault primary cluster root token"
    value       = step.create_primary_cluster.root_token
  }

  output "primary_cluster_unseal_keys_b64" {
    description = "The Vault primary cluster unseal keys"
    value       = step.create_primary_cluster.unseal_keys_b64
  }

  output "primary_cluster_unseal_keys_hex" {
    description = "The Vault primary cluster unseal keys hex"
    value       = step.create_primary_cluster.unseal_keys_hex
  }

  output "primary_cluster_recovery_key_shares" {
    description = "The Vault primary cluster recovery key shares"
    value       = step.create_primary_cluster.recovery_key_shares
  }

  output "primary_cluster_recovery_keys_b64" {
    description = "The Vault primary cluster recovery keys b64"
    value       = step.create_primary_cluster.recovery_keys_b64
  }

  output "primary_cluster_recovery_keys_hex" {
    description = "The Vault primary cluster recovery keys hex"
    value       = step.create_primary_cluster.recovery_keys_hex
  }

  output "secondary_cluster_hosts" {
    description = "The Vault secondary cluster public IPs"
    value       = step.create_secondary_cluster_targets.hosts
  }

  output "secondary_cluster_root_token" {
    description = "The Vault secondary cluster root token"
    value       = step.create_secondary_cluster.root_token
  }

  output "performance_secondary_token" {
    description = "The performance secondary replication token"
    value       = step.generate_secondary_token.secondary_token
  }

  output "remaining_hosts" {
    description = "The Vault cluster primary hosts after removing the leader and follower"
    value       = step.get_remaining_hosts_replication_data.remaining_hosts
  }

  output "initial_primary_replication_status" {
    description = "The Vault primary cluster performance replication status"
    value       = step.verify_performance_replication.primary_replication_status
  }

  output "initial_known_primary_cluster_addresses" {
    description = "The Vault secondary cluster performance replication status"
    value       = step.verify_performance_replication.known_primary_cluster_addrs
  }

  output "initial_secondary_performance_replication_status" {
    description = "The Vault secondary cluster performance replication status"
    value       = step.verify_performance_replication.secondary_replication_status
  }

  output "intial_primary_replication_data_secondaries" {
    description = "The Vault primary cluster secondaries connection status"
    value       = step.verify_performance_replication.primary_replication_data_secondaries
  }

  output "initial_secondary_replication_data_primaries" {
    description = "The Vault  secondary cluster primaries connection status"
    value       = step.verify_performance_replication.secondary_replication_data_primaries
  }

  output "updated_primary_replication_status" {
    description = "The Vault updated primary cluster performance replication status"
    value       = step.verify_updated_performance_replication.primary_replication_status
  }

  output "updated_known_primary_cluster_addresses" {
    description = "The Vault secondary cluster performance replication status"
    value       = step.verify_updated_performance_replication.known_primary_cluster_addrs
  }

  output "updated_secondary_replication_status" {
    description = "The Vault updated secondary cluster performance replication status"
    value       = step.verify_updated_performance_replication.secondary_replication_status
  }

  output "updated_primary_replication_data_secondaries" {
    description = "The Vault updated primary cluster secondaries connection status"
    value       = step.verify_updated_performance_replication.primary_replication_data_secondaries
  }

  output "updated_secondary_replication_data_primaries" {
    description = "The Vault updated secondary cluster primaries connection status"
    value       = step.verify_updated_performance_replication.secondary_replication_data_primaries
  }
}

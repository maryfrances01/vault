# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: BUSL-1.1

scenario "ui" {
  description = <<-EOF
    The UI scenario is designed to create a new cluster and run the existing Ember test suite
    against a live Vault cluster instead of a binary in dev mode.
  EOF
  matrix {
    backend = global.backends
    edition = ["ce", "ent"]
  }

  terraform_cli = terraform_cli.default
  terraform     = terraform.default
  providers = [
    provider.aws.default,
    provider.enos.ubuntu
  ]

  locals {
    arch                 = "amd64"
    artifact_type        = "bundle"
    backend_license_path = abspath(var.backend_license_path != null ? var.backend_license_path : joinpath(path.root, "./support/consul.hclic"))
    backend_tag_key      = "VaultStorage"
    build_tags = {
      "ce"  = ["ui"]
      "ent" = ["ui", "enterprise", "ent"]
    }
    bundle_path    = abspath(var.vault_artifact_path)
    distro         = "ubuntu"
    consul_version = "1.17.0"
    seal           = "awskms"
    tags = merge({
      "Project Name" : var.project_name
      "Project" : "Enos",
      "Environment" : "ci"
    }, var.tags)
    vault_install_dir_packages = {
      rhel   = "/bin"
      ubuntu = "/usr/bin"
    }
    vault_install_dir  = var.vault_install_dir
    vault_license_path = abspath(var.vault_license_path != null ? var.vault_license_path : joinpath(path.root, "./support/vault.hclic"))
    vault_tag_key      = "Type" // enos_vault_start expects Type as the tag key
    ui_test_filter     = var.ui_test_filter != null && try(trimspace(var.ui_test_filter), "") != "" ? var.ui_test_filter : (matrix.edition == "ce") ? "!enterprise" : null
  }

  step "build_vault" {
    description = global.description.build_vault
    module      = module.build_local

    variables {
      build_tags      = var.vault_local_build_tags != null ? var.vault_local_build_tags : local.build_tags[matrix.edition]
      bundle_path     = local.bundle_path
      goarch          = local.arch
      goos            = "linux"
      product_version = var.vault_product_version
      artifact_type   = local.artifact_type
      revision        = var.vault_revision
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
      common_tags = local.tags
    }
  }

  // This step reads the contents of the backend license if we're using a Consul backend and
  // the edition is "ent".
  step "read_backend_license" {
    description = global.description.read_backend_license
    skip_step   = matrix.backend == "raft" || var.backend_edition == "ce"
    module      = module.read_license

    variables {
      file_name = local.backend_license_path
    }
  }
  // TODO: vault enterprise requires a license
  // TODO: vault CE does not require a license

  step "read_vault_license" {
    description = global.description.read_vault_license
    skip_step   = matrix.edition == "ce"
    module      = module.read_license

    variables {
      file_name = local.vault_license_path
    }
  }

  step "create_seal_key" {
    description = global.description.create_seal_key
    module      = "seal_${local.seal}"

    variables {
      cluster_id  = step.create_vpc.cluster_id
      common_tags = global.tags
    }
  }

  step "create_vault_cluster_targets" {
    description = global.description.create_vault_cluster_targets
    module      = module.target_ec2_instances
    depends_on  = [step.create_vpc]

    providers = {
      enos = provider.enos.ubuntu
    }

    variables {
      ami_id          = step.ec2_info.ami_ids[local.arch][local.distro][var.ubuntu_distro_version]
      cluster_tag_key = local.vault_tag_key
      common_tags     = local.tags
      seal_names      = step.create_seal_key.resource_names
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
      cluster_tag_key = local.backend_tag_key
      common_tags     = local.tags
      seal_names      = step.create_seal_key.resource_names
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
      cluster_tag_key = local.backend_tag_key
      license         = (matrix.backend == "consul" && var.backend_edition == "ent") ? step.read_backend_license.license : null
      release = {
        edition = var.backend_edition
        version = local.consul_version
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
      enos = provider.enos.ubuntu
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
      backend_cluster_tag_key = local.backend_tag_key
      cluster_name            = step.create_vault_cluster_targets.cluster_name
      consul_license          = (matrix.backend == "consul" && var.backend_edition == "ent") ? step.read_backend_license.license : null
      consul_release = matrix.backend == "consul" ? {
        edition = var.backend_edition
        version = local.consul_version
      } : null
      enable_audit_devices = var.vault_enable_audit_devices
      install_dir          = local.vault_install_dir
      license              = matrix.edition != "ce" ? step.read_vault_license.license : null
      local_artifact_path  = local.bundle_path
      packages             = global.distro_packages["ubuntu"]
      seal_name            = step.create_seal_key.resource_name
      seal_type            = local.seal
      storage_backend      = matrix.backend
      target_hosts         = step.create_vault_cluster_targets.hosts
    }
  }

  // Wait for our cluster to elect a leader
  step "wait_for_leader" {
    description = global.description.wait_for_cluster_to_have_leader
    module      = module.vault_wait_for_leader
    depends_on  = [step.create_vault_cluster]

    providers = {
      enos = provider.enos.ubuntu
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

  step "test_ui" {
    description = <<-EOF
      Verify that the Vault Web UI test suite can run against a live cluster with the compiled
      assets.
    EOF
    module      = module.vault_test_ui
    depends_on  = [step.wait_for_leader]

    verifies = quality.vault_web_ui_test_suite_works_with_live_cluster_and_assets

    variables {
      vault_addr               = step.create_vault_cluster_targets.hosts[0].public_ip
      vault_root_token         = step.create_vault_cluster.root_token
      vault_unseal_keys        = step.create_vault_cluster.recovery_keys_b64
      vault_recovery_threshold = step.create_vault_cluster.recovery_threshold
      ui_test_filter           = local.ui_test_filter
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

  output "root_token" {
    description = "The Vault cluster root token"
    value       = step.create_vault_cluster.root_token
  }

  output "seal_name" {
    description = "The Vault cluster seal key name"
    value       = step.create_seal_key.resource_name
  }

  output "ui_test_environment" {
    value       = step.test_ui.ui_test_environment
    description = "The environment variables that are required in order to run the test:enos yarn target"
  }

  output "ui_test_stderr" {
    description = "The stderr of the ui tests that ran"
    value       = step.test_ui.ui_test_stderr
  }

  output "ui_test_stdout" {
    description = "The stdout of the ui tests that ran"
    value       = step.test_ui.ui_test_stdout
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

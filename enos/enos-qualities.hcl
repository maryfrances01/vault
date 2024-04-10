# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: BUSL-1.1

quality "consul_api_agent_host_returns_host_info" {
  description = "The /v1/agent/host returns host info for each node in the cluster"
}

quality "consul_api_health_node_returns_node_health" {
  description = "The /v1/health/node/<node> returns node info for each node in the cluster"
}

quality "consul_api_operator_raft_configuration_returns_raft_configuration" {
  description = "The /v1/operator/raft/configuarition returns raft info for the cluster"
}

quality "consul_can_autojoin_with_aws" {
  description = "The Consul cluster is able to auto-join with AWS"
}

quality "consul_can_be_configured" {
  description = "Consul is able to start when configured primarily with environment variables"
}

quality "consul_can_elect_leader" {
  description = "The Consul cluster is able to elect a leader"
}

quality "consul_can_start" {
  description = "The Consul service is able to start up given our baseline configuration"
}

quality "consul_cli_validate_validates_configuration" {
  description = "The 'consul validate' CLI command validates the consul configuration"
}

quality "consul_has_min_x_healthy_nodes" {
  description = "Ensures that the Consul cluster has the correct minimum of healthy nodes"
}

quality "consul_has_min_x_voters" {
  description = "The Consul cluster has the correct minimum of voters"
}

quality "consul_systemd_unit_is_valid" {
  description = "The consul.service systemd unit can be used to start the service"
}

quality "consul_notifies_systemd" {
  description = "consul.service notifies systemd when the service is active"
}

quality "vault_agent_can_autoauth_with_approle" {
  description = <<-EOF
    Vault Agent can utilize tha approle auth method to to auto auth via a roles and secrets from file.
  EOF
}

quality "vault_agent_logs_with_the_correct_template_contents" {
  description = "Vault Agent is able to use templates to create log output"
}

quality "vault_all_nodes_are_raft_voters" {
  description = "All nodes in the cluster are healthy and can vote"
}

quality "vault_api_sys_auth_userpass_associates_policy" {
  description = "The v1/sys/auth/userpass/users/<user> associates a policy with a user"
}

quality "vault_api_sys_config_returns_config" {
  description = "v1/sys/config/sanitized API returns configuration that reflects our expectations"
}

quality "vault_api_sys_ha_status_returns_ha_status" {
  description = "v1/sys/ha-status API returns the ha status"
}

quality "vault_api_sys_health_returns_correct_status" {
  description = "The v1/sys/health API returns the correct codes depending on the replication and seal status of the cluster"
}

quality "vault_api_sys_host_info_returns_host_info" {
  description = "v1/sys/host-info returns the host info for each node in the cluster"
}

quality "vault_api_sys_leader_returns_leader" {
  description = "v1/sys/leader returns the leader info"
}

quality "vault_api_sys_metrics_vault_core_replication_write_undo_logs_is_enabled" {
  description = "The v1/sys/metrics Gauges[vault.core.replication.write_undo_logs] is enabled"
}

quality "vault_api_sys_policy_writes_superuser_policy" {
  description = "The v1/sys/policy can write a superuser policy"
}

quality "vault_api_sys_quotas_lease_count_default_max_leases_is_correct" {
  description = "The v1/sys/quotas/lease-count/default max_leases is set to 300,000 by default"
}

quality "vault_api_sys_replication_performance_primary_enable_enables_replication" {
  description = "The v1/sys/replication/performance/primary/enable enables performance replication"
}

quality "vault_api_sys_replication_performance_primary_secondary_token_configures_token" {
  description = "The v1/sys/replication/performance/primary/secondary-token configures the replication token"
}

quality "vault_api_sys_replication_performance_secondary_enable_enables_replication" {
  description = "The v1/sys/replication/performance/secondary/enable enables performance replication"
}

quality "vault_api_sys_replication_performance_status_connection_status_is_connected" {
  description = "The v1/sys/replication/performance/status connection_status is correct "
}

quality "vault_api_sys_replication_performance_status_known_primary_cluster_addrs_is_correct" {
  description = "The v1/sys/replication/performance/status known_primary_cluster_address is the primary cluster leader"
}

quality "vault_api_sys_replication_performance_status_returns_status" {
  description = "The v1/sys/replication/performance/status returns the performance replication status"
}

quality "vault_api_sys_replication_performance_status_secondary_cluster_address_is_correct" {
  description = "The v1/sys/replication/performance/status {primaries,secondaries}[*].cluster_address is correct"
}

quality "vault_api_sys_replication_performance_status_state_is_not_idle" {
  description = "The v1/sys/replication/performance/status state is not idle"
}

quality "vault_api_sys_replication_status_returns_replication_status" {
  description = "v1/sys/replication/statusl returns the replication status of the cluster"
}

quality "vault_api_sys_seal_status_api_matches_health" {
  description = "The v1/sys/seal-status api and v1/sys/health api agree on the health of the node and cluster"
}

quality "vault_api_sys_sealwrap_rewrap_entries_processed_eq_entries_succeeded_post_rewrap" {
  description = "The v1/sys/sealwrap/rewrap entries.processed equals entries.succeeded after the rewrap has completed"
}

quality "vault_api_sys_sealwrap_rewrap_entries_processed_is_gt_zero_post_rewrap" {
  description = "The v1/sys/sealwrap/rewrap entries.processed is greater than one entry after the rewrap has completed"
}

quality "vault_api_sys_sealwrap_rewrap_is_running_false_post_rewrap" {
  description = "The v1/sys/sealwrap/rewrap is_running is set to false after a rewrap has completed"
}

quality "vault_api_sys_sealwrap_rewrap_no_entries_fail_during_rewrap" {
  description = "The v1/sys/sealwrap/rewrap entries.failed is 0 after the rewrap has completed"
}

quality "vault_api_sys_step_down_steps_down" {
  description = "The v1/sys/step-down API forces the cluster leader to step down"
}

quality "vault_api_sys_storage_raft_autopilot_configuration_returns_autopilot_configuration" {
  description = "v1/sys/storage/raft/autopilot/configuration returns the autopilot configuration of the cluster"
}

quality "vault_api_sys_storage_raft_autopilot_state_returns_autopilot_state" {
  description = "v1/sys/storage/raft/autopilot/state returns the autopilot state of the cluster"
}

quality "vault_api_sys_storage_raft_autopilot_upgrade_info_status_matches_expectation" {
  description = "v1/sys/storage/raft/autopilot/state upgrade_info.status matches our expected state"
}

quality "vault_api_sys_storage_raft_autopilot_upgrade_info_target_version_matches_candidate_version" {
  description = <<-EOF
    v1/sys/storage/raft/autopilot/state upgrade_info.target_version matches the the candidate version
  EOF
}

quality "vault_api_sys_storage_raft_configuration_returns_configuration" {
  description = "v1/sys/storage/raft/configuration returns the raft configuration of the cluster"
}

quality "vault_api_sys_storage_raft_remove_peer_removes_peer" {
  description = "The v1/sys/storage/raft/remove-peer API removes the desired node"
}

quality "vault_auto_unseals_after_autopilot_upgrade" {
  description = "Vault is able to auto-unseal after upgrading the cluster with autopilot"
}

quality "vault_can_add_nodes_to_previously_initialized_cluster" {
  description = "Vault can sucessfully provision nodes into an existing cluster"
}

quality "vault_can_autojoin_with_aws" {
  description = "Vault is to auto-join using AWS tag discovery"
}

quality "vault_can_be_configured_with_env_variables" {
  description = "Vault is able to start when configured primarily with environment variables"
}

quality "vault_can_be_configured_with_config_file" {
  description = "Vault is able to start when configured primarily with a configuration file"
}

quality "vault_can_disable_multiseal" {
  description = <<-EOF
    The Vault Cluster can start with 'enable_multiseal' and be configured with multiple auto-unseal
    methods.
  EOF
}

quality "vault_can_elect_leader_after_unseal" {
  description = "Vault is able to perform a leader election after it is unsealed"
}

quality "vault_can_elect_leader_after_step_down" {
  description = "Vault is able to perform a leader election after a forced step down"
}

quality "vault_can_enable_approle_auth" {
  description = "Vault can enable the approle auth method"
}

quality "vault_can_enable_audit_devices" {
  description = "Vault can enable audit devices"
}

quality "vault_can_enable_multiseal" {
  description = <<-EOF
    The Vault Cluster can start with 'enable_multiseal' and be configured with multiple auto-unseal
    methods.
  EOF
}

quality "vault_can_initialize" {
  description = "Vault is able to initialize with the configuration"
}

quality "vault_can_install_artifact_bundle" {
  description = "Vault can be installed from an zip archive"
}

quality "vault_can_install_artifact_deb" {
  description = "Vault can be installed from a deb package"
}

quality "vault_can_install_artifact_rpm" {
  description = "Vault can be installed from a rpm package"
}

quality "vault_can_modify_log_level" {
  description = "Vault can modify its log level"
}

quality "vault_can_mount_auth" {
  description = "Vault is able to mount the auth engine"
}

quality "vault_can_mount_kv" {
  description = "Vault is able to mount the kv engine"
}

quality "vault_can_read_kv_data" {
  description = "Vault is able to read kv data"
}

quality "vault_can_restart" {
  description = "Vault is able to restart with existing configuration"
}

quality "vault_can_start" {
  description = "Vault is able to start with the configuration"
}

quality "vault_can_upgrade_in_place" {
  description = <<-EOF
    Vault is able to start with an existing data and configuration created by a previous version
  EOF
}

quality "vault_can_use_consul_storage" {
  description = "Vault can operate using Consul for storage"
}

quality "vault_can_use_raft_storage" {
  description = "Vault can operate using integrated Raft storage"
}

quality "vault_can_unseal_with_awskms" {
  description = "Vault is able to unseal with the awskms seal"
}

quality "vault_can_unseal_with_shamir" {
  description = "Vault is able to unseal with the shamir seal"
}

quality "vault_can_unseal_with_pkcs11" {
  description = "Vault is able to unseal with the pkcs11 seal"
}

quality "vault_can_use_log_auditor" {
  description = "Vault can enable and audit to a logfile"
}

quality "vault_can_use_socket_auditor" {
  description = "Vault can enable and audit to a socket listener"
}

quality "vault_can_use_syslog_auditor" {
  description = "Vault can enable and audit to syslog"
}

quality "vault_can_write_auth_user_policies" {
  description = "Vault can create auth user policies with the root token"
}

quality "vault_can_write_kv_data" {
  description = "Vault is able to write kv data"
}

quality "vault_cli_can_access_vault_through_proxy" {
  description = <<-EOF
    The Vault CLI can access tokens through the vault proxy without VAULT_TOKEN set
  EOF
}

quality "vault_cli_operator_raft_remove_peer_removes_peer" {
  description = "Vault CLI command 'vault operator remove-peer' removes the desired node"
}

quality "vault_cli_operator_members_contains_members" {
  description = "Vault CLI command 'vault operator members' returns the expected list of members"
}

quality "vault_cli_operator_step_down_steps_down" {
  description = "Vault CLI command 'vault operator step-down' forces the cluster leader to step down"
}

quality "vault_cli_policy_write_writes_policy" {
  description = "Vault CLI command 'vault policy write' can write a policy"
}

quality "vault_cli_status_exits_with_correct_code" {
  description = "Vault CLI command 'vault status' exits with the correct code depending on expected seal status"
}

quality "vault_dr_replication_status_is_available_ent" {
  description = "DR replication is available on Enterprise"
}

quality "vault_elects_new_leader_after_autopilot_upgrade" {
  description = <<-EOF
    Vault is able to electe a new leader after upgrading the cluster with autopilot
  EOF
}

quality "vault_has_expected_build_date" {
  description = "Vault's reported build date matches our expectations"
}

quality "vault_has_expected_edition" {
  description = "Vault's reported edition matches our expectations"
}

quality "vault_has_expected_seal_type" {
  description = "Vault's reported seal type matches our expectations"
}

quality "vault_has_expected_version" {
  description = "Vault's reported version matches our expectations"
}

quality "vault_notifies_systemd" {
  description = "vault.service notifies systemd when the service is active"
}

quality "vault_proxy_can_autoauth_with_approle" {
  description = <<-EOF
    Vault Proxy can utilize tha approle auth method to to auto auth via a roles and secrets from file.
  EOF
}

quality "vault_pr_replication_status_is_available_ent" {
  description = "PR replication is available on Enterprise"
}

quality "vault_replication_is_not_enabled_for_ce" {
  description = "Replication is not enabled for CE editions"
}

quality "vault_requires_license_for_enterprise_editions" {
  description = "Vault Enterprise requires a license in order to start"
}

quality "vault_systemd_unit_is_valid" {
  description = "The vault.service systemd unit can be used to start the service"
}

quality "vault_ui_is_available" {
  description = "The Vault UI assets are available"
}

quality "vault_web_ui_test_suite_works_with_live_cluster_and_assets" {
  description = <<-EOF
    The Vault Web UI test suite is able to run against a live Vault server with the static assets
  EOF
}

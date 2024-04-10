# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: BUSL-1.1

globals {
  description = {
    build_vault = <<-EOF
      Determine which Vault artifact we want to use for the scenario. Depending on the
      'artifact_source' variant it will either build Vault from the local branch, fetch a candidate
      build from Artifactory, or use a local artifact.
    EOF

    create_backend_cluster = <<-EOF
      Create the storage backend cluster if necessary. When configured to use Consul it will
      install, configure, and start the Consul cluster and wait for it to become healthy. When using
      integrated raft storage this step is a no-op.
    EOF

    create_seal_key = <<-EOF
      Create a seal key infrastructure for Vaults auto-unseal functionality. Depending on the 'seal'
      variant this step will perform different actions. When using 'shamir' the step is a no-op.
      When using 'pkcs11' the step will create a SoftHSM slot and associated token which can be
      distributed to target nodes. When using 'awskms' a new AWSKMS key will be created with the
      necessary security groups and policies for Vault target nodes to access it.
    EOF

    create_vault_cluster = <<-EOF
      Create the the Vault cluster. Here we'll install, configure, start, and unseal Vault.
    EOF

    create_vault_cluster_backend_targets = <<-EOF
      Create the target machines that we'll install Consul onto when using Consul storage. We'll
      also handle creating instance profiles that allow for discovery via the retry_join
      functionality in Consul. The security group firewall rules will automatically include the
      host external IP address of the machine executing Enos, in addition to all of the required
      ports for Consul to function.
    EOF

    create_vault_cluster_targets = <<-EOF
      Create the target machines that we'll install Vault onto. We'll also handle creating instance
      profiles that allow auto-unseal and discovery via the retry_join functionality in Vault. The
      security group firewall rules will automatically include the host external IP address of the
      machine executing Enos, in addition to all of the required ports for Vault and Consul to
      function together.
    EOF

    create_vpc = <<-EOF
      Create an AWS VPC, default subnet, security group, and internet gateway for target
      infrastructure.
    EOF

    ec2_info = <<-EOF
      Query the AWS Ec2 service to determines metadata we'll use later in our run when creating
      infrastructure for the Vault cluster. This metadata includes AMI IDs, Ec2 Regions, and Ec2
      Availability Zones.
    EOF

    enable_multiseal = <<-EOF
      Configure the Vault Cluster with 'enable_multiseal' and up to three auto-unseal methods
      via individual 'seal' stanzas.
    EOF

    get_local_metadata = <<-EOF
      Several vault quality verification expect the scenario to be configued with Vault metadata,
      via variables, that the candidate artifact should embed. When we test scenarios locally,
      adding this metadata can be quite burdensome. This step resolves that by loading the expected
      metadata from Git automatically when using the artifact_source:local variant. Subsequent steps
      then choose whether or not to use the local or external metadata when performing verification.
    EOF

    get_vault_cluster_ip_addresses = <<-EOF
      Determine the current Vault cluster leader and the public and private IP addresses of both
      the current leader and all followers.
    EOF

    read_backend_license = <<-EOF
      Ensure a Consul Enterprise license is present on disk, and read its contents, when deploying
      the scenario with Consul Enterprise as the storage backend. Must have the 'backend:consul'
      and 'backend_edition:ent' variants.
    EOF

    read_vault_license = <<-EOF
      Ensure a Vault Enterprise license is present on disk when deploying the scenario with Vault
      Enterprise. Must have the 'edition' variant to be set to any enterprise edition.
    EOF

    shutdown_nodes = <<-EOF
      Shut down the nodes to ensure that they are no longer operating software as part of the
      cluster.
    EOF

    start_vault_agent = <<-EOF
      Create an agent approle in the auth engine, generate a Vault Agent configuration file, and
      start the Vault agent.
    EOF

    stop_vault = <<-EOF
      Stop the vault cluster by stopping the vault service via systemctl.
    EOF

    vault_leader_step_down = <<-EOF
      Force the Vault cluster leader to step down and for the cluster to perform a new leader
      election.
    EOF

    verify_agent_output = <<-EOF
      Verify that the Vault Agent logs the appropriate content.
    EOF

    verify_all_nodes_are_raft_voters = <<-EOF
      When configured to use integrated raft storage, verify that all nodes in the cluster are
      currently raft voters.
    EOF

    verify_autopilot_idle_state = <<-EOF
      Wait for the Autopilot to upgrade the entire cluster and report the target version of the
      candidate version. Ensure that the cluster reaches an upgrade state of "await-server-removal".
    EOF

    verify_read_test_data = <<-EOF
      Verify that we are able to read test data we've written in prior steps. This includes:
        - Auth user policies
        - Kv data
    EOF

    verify_replication_status = <<-EOF
      Verify that the default replication status is correct depending on the edition of Vault that
      been deployed. When testing a Community Edition of Vault we'll ensure that replication is not
      enabled. When testing any Enterprise edition of Vault we'll ensure that Performance and
      Disaster Recovery replication are available.
    EOF

    verify_seal_rewrap_entries_processed_eq_entries_succeeded_post_rewrap = <<-EOF
      Verify that /sys/sealwrap/rewrap entries.processed is greater than zero after rewrap."
    EOF

    verify_seal_rewrap_entries_processed_is_gt_zero_post_rewrap = <<-EOF
      Verify that /sys/sealwrap/rewrap entries.processed is greater than zero after rewrap."
    EOF

    verify_seal_rewrap_is_running_false_post_rewrap = <<-EOF
      Verify that /sys/sealwrap/rewrap reports is_running is false after rewrap"
    EOF

    verify_seal_rewrap_no_entries_fail_during_rewrap = <<-EOF
      Verify that /sys/sealwrap/rewrap entries.failed is zero after rewrap."
    EOF

    verify_seal_type = <<-EOF
      Verify that /sys/seal-status reports the correct seal type."
    EOF

    verify_write_test_data = <<-EOF
      Verify that vault is capable mounting engines and writing data to them. These currently include:
        - Mount the auth engine
        - Mount the kv engine
        - Write auth user policies
        - Write kv data
    EOF

    verify_ui = <<-EOF
      Verify that Vault Web UI is available at the expected listen port.
    EOF

    verify_vault_unsealed = <<-EOF
      Verify that the Vault cluster has successfully unsealed.
    EOF

    verify_vault_version = <<-EOF
      Verify that the Vault cluster has the correct embedded version metadata. This metadata includes
      the Vault version, edition, build date, and any special prerelease metadata.
    EOF

    wait_for_cluster_to_have_leader = <<-EOF
      Wait for a leader election to occur before we proceed with any further quality verification
    EOF

    wait_for_seal_rewrap = <<-EOF
      Wait for the Vault cluster seal rewrap process to complete
    EOF
  }
}

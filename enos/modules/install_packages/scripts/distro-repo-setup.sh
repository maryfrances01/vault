#!/usr/bin/env bash
# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: BUSL-1.1

set -e

fail() {
  echo "$1" 1>&2
  exit 1
}

[[ -z "$DISTRO" ]] && fail "DISTRO env variable has not been set"
[[ -z "$RETRY_INTERVAL" ]] && fail "RETRY_INTERVAL env variable has not been set"
[[ -z "$TIMEOUT_SECONDS" ]] && fail "TIMEOUT_SECONDS env variable has not been set"

# SLES configures the default repositories using SUSEConnect, which is wrapped but a startup
# systemd unit called guestregister.service. This oneshot service needs to complete before
# any other repo or package steps are completed. It's very unreliable so we have to handle it
# ourselves here.
#
# Check if the guestregister.service has reached the correct "inactive" state that we need.
# If it hasn't and the service isn't in some kind of active state, restart the service so that
# we can get another registration attempt.
guestregister_service_healthy() {
  local active_state
  local failed_state

  # systemctl returns non-zero exit codes. We rely on output here because all states don't have
  # their own exit code.
  set +e
  active_state=$(sudo systemctl is-active guestregister.service)
  failed_state=$(sudo systemctl is-failed guestregister.service)
  set -e

  case "$active_state" in
    active|activating|deactivating)
      return 1
    ;;
    *)
      if [ "$active_state" == "inactive" ] && [ "$failed_state" == "inactive" ]; then
        # The oneshot has completed and hasn't "failed"
        return 0
      fi

      # Our service is stopped and failed, restart it and hope it works the next time
      sudo systemctl restart --wait guestregister.service
    ;;
  esac
}

ensure_zypper_guestregister_service() {
  local health_output
  if ! health_output=$(guestregister_service_healthy); then
    echo "the guestregister.service failed to reach a healthy state: ${health_output}" 1>&2
    return 1
  fi

  # Make sure Zypper has repositories.
  if ! lr_output=$(zypper lr); then
    echo "The guestregister.service failed. Unable to SUSEConnect and thus have no Zypper repositories: ${lr_output}: ${health_output}." 1>&2
    return 1
  fi

  return 0
}

setup_repos() {
  # If we don't have any repos on the list for this distro, no action needed.
  if [ ${#DISTRO_REPOS[@]} -lt 1 ]; then
    echo "DISTRO_REPOS is empty; No repos required for the packages for this Linux distro."
    return 0
  fi

  # Wait for cloud-init to finish so it doesn't race with any of our package installations.
  # Note: Amazon Linux 2 throws Python 2.7 errors when running `cloud-init status` as
  # non-root user (known bug).
  sudo cloud-init status --wait

  case $DISTRO in
    sles)
      # Update our repo metadata and service metadata
      sudo zypper --gpg-auto-import-keys --non-interactive ref
      sudo zypper --gpg-auto-import-keys --non-interactive refs

      # Add each repo
      for repo in ${DISTRO_REPOS}; do
        sudo zypper --gpg-auto-import-keys --non-interactive addrepo "${repo}"
      done
    ;;
    rhel)
      for repo in ${DISTRO_REPOS}; do
        sudo rm -r /var/cache/dnf
        sudo dnf install -y "${repo}"
        sudo dnf update -y --refresh
      done
    ;;
    *)
      return 0
    ;;
  esac
}

begin_time=$(date +%s)
end_time=$((begin_time + TIMEOUT_SECONDS))
while [ "$(date +%s)" -lt "$end_time" ]; do
  if [ "$DISTRO" == "sles" ]; then
    # Make sure Zypper has repositories before we configure additional repositories
    if ! ensure_zypper_guestregister_service; then
      sleep "$RETRY_INTERVAL"
      continue
    fi
  fi

  if setup_repos; then
    exit 0
  fi

  sleep "$RETRY_INTERVAL"
done

fail "Timed out waiting for distro repos to be set up"

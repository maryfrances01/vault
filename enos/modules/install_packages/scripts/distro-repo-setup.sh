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

retry() {
  local retries=$1
  shift
  local count=0

  until "$@"; do
    exit=$?
    wait=$((2 ** count))
    count=$((count + 1))
    if [ "$count" -lt "$retries" ]; then
      sleep "$wait"
    else
      return "$exit"
    fi
  done

  return 0
}

ensure_zypper_guestregister_service() {
  # Occasionally, but often enough to cause issues, the SLES provided guestregister.service will
  # fail to properly enroll the instance with SUSEConnet and we'll be left without default repos.

  # Until this is resolved upstream we'll need to be defensive and ensure that the service is
  # hasn't failed.
  if sudo systemctl is-failed guestregister.service; then
    retry 2 sudo systemctl restart guestregister.service
  fi

  # Make sure Zypper has repositories.
  if ! output=$(zypper lr); then
    fail "The guestregister.service failed. Unable to SUSEConnet and thus have no Zypper repositories: ${output}."
  fi
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
  if [ "$DISTRO" == sles ]; then
    # Make sure Zypper has repositories before we configure additional repositories
    ensure_zypper_guestregister_service
  fi

  if setup_repos; then
    exit 0
  fi

  sleep "$RETRY_INTERVAL"
done

fail "Timed out waiting for distro repos to install"

#!/bin/bash
# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: BUSL-1.1

function fail() {
  echo "$1" 1>&2
  exit 1
}

[[ -z "$EXPECTED_STATE" ]] && fail "EXPECTED_STAE env variable has not been set"
[[ -z "$VAULT_ADDR" ]] && fail "VAULT_ADDR env variable has not been set"
[[ -z "$VAULT_INSTALL_DIR" ]] && fail "VAULT_INSTALL_DIR env variable has not been set"
[[ -z "$VAULT_TOKEN" ]] && fail "VAULT_TOKEN env variable has not been set"

binpath=${VAULT_INSTALL_DIR}/vault
test -x "$binpath" || fail "unable to locate vault binary at $binpath"

count=0
retries=5
while :; do
  state=$($binpath read sys/metrics -format=json | jq -r '.data.Gauges[] | select(.Name == "vault.core.replication.write_undo_logs")')
  target_undo_logs_status="$(jq -r '.Value' <<< "$state")"

  if [ "$target_undo_logs_status" == "$EXPECTED_STATE" ]; then
    exit 0
  fi

  wait=$((2 ** count))
  count=$((count + 1))
  if [ "$count" -lt "$retries" ]; then
    echo "Waiting for vault.core.replication.write_undo_logs to have Value: \"${EXPECTED_STATE}\""
    echo "$state"
    sleep "$wait"
  else
    fail "Timed out waiting for vault.core.replication.write_undo_logs to have Value: \"${EXPECTED_STATE}\""
  fi
done

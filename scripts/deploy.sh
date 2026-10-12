#!/usr/bin/env bash
set -euo pipefail
source "$(dirname -- "$0")/common.sh"
ARCHIVE="$ROOT/cache/hadoop-$HADOOP_VERSION.tar.gz"
if [[ ! -f "$ARCHIVE" ]]; then
  curl -fL --retry 3 --connect-timeout 15 --max-time 1200 "https://archive.apache.org/dist/hadoop/common/hadoop-$HADOOP_VERSION/hadoop-$HADOOP_VERSION.tar.gz" -o "$ARCHIVE.part"
  printf '%s  %s\n' "$HADOOP_SHA512" "$ARCHIVE.part" | sha512sum -c -
  mv "$ARCHIVE.part" "$ARCHIVE"
fi
printf '%s  %s\n' "$HADOOP_SHA512" "$ARCHIVE" | sha512sum -c -
for ip in "${ALL_IPS[@]}"; do
  run_node "$ip" sudo -n true
  if [[ "$ip" != "$CONTROL_IP" ]]; then
    run_node "$ip" mkdir -p "$REMOTE_PROJECT/cache"
    if ! run_node "$ip" test -f "$REMOTE_PROJECT/cache/hadoop-$HADOOP_VERSION.tar.gz"; then
      scp "${SSH_OPTIONS[@]}" "$ARCHIVE" "$SSH_USER@$ip:$REMOTE_PROJECT/cache/"
    fi
  fi
done
# Independent node provisioning runs concurrently; all failures are collected.
pids=()
for ip in "${ALL_IPS[@]}"; do
  node_archive="$REMOTE_PROJECT/cache/hadoop-$HADOOP_VERSION.tar.gz"
  [[ "$ip" != "$CONTROL_IP" ]] || node_archive="$ARCHIVE"
  run_node "$ip" sudo -n bash -s -- "$ip" "$NAMENODE_IP" "$SECONDARY_IP" "$HADOOP_VERSION" "$HADOOP_SHA512" "$node_archive" "${DATANODE_IPS[@]}" < "$ROOT/scripts/node-setup.sh" > "$ROOT/logs/setup-$ip.log" 2>&1 &
  pids+=("$!")
done
failed=0
for pid in "${pids[@]}"; do wait "$pid" || failed=1; done
if [[ $failed -ne 0 ]]; then
  tail -n 30 "$ROOT"/logs/setup-*.log >&2
  exit 1
fi
# Running services retain the existing configuration until explicitly restarted.
run_node "$NAMENODE_IP" sudo -n bash -s < "$ROOT/scripts/format-if-empty.sh"
bash "$ROOT/scripts/cluster.sh" start
bash "$ROOT/scripts/verify.sh"

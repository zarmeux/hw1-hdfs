#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
source "$ROOT/cluster.env"
[[ ! -f "$ROOT/cluster.local.env" ]] || source "$ROOT/cluster.local.env"
for ip in "$CONTROL_IP" "$NAMENODE_IP" "$SECONDARY_IP" "${DATANODE_IPS[@]}"; do
  python3 -c 'import ipaddress,sys; ipaddress.IPv4Address(sys.argv[1])' "$ip"
done
[[ ${#DATANODE_IPS[@]} -eq 3 ]] || { echo 'Exactly three DataNodes are required.' >&2; exit 1; }
[[ $(printf '%s\n' "${DATANODE_IPS[@]}" | sort -u | wc -l) -eq 3 ]] || { echo 'DataNode IPs must be distinct.' >&2; exit 1; }
[[ "$NAMENODE_IP" != "$SECONDARY_IP" ]] || { echo 'Place SecondaryNameNode on another host.' >&2; exit 1; }
[[ "$SSH_USER" =~ ^[a-z_][a-z0-9_-]*$ && "$REMOTE_PROJECT" =~ ^/[a-zA-Z0-9_./-]+$ ]] || exit 1
[[ "$HADOOP_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ && "$HADOOP_SHA512" =~ ^[a-f0-9]{128}$ ]] || exit 1
hostname -I | tr ' ' '\n' | grep -qxF "$CONTROL_IP" || { echo 'Run this script on the configured control node.' >&2; exit 1; }
mapfile -t ALL_IPS < <(printf '%s\n' "$NAMENODE_IP" "$SECONDARY_IP" "${DATANODE_IPS[@]}" | sort -u)
mkdir -p "$ROOT/cache" "$ROOT/logs"
SSH_OPTIONS=(-i "$SSH_KEY" -o IdentitiesOnly=yes -o BatchMode=yes -o ConnectTimeout=15 -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile="$ROOT/cache/known_hosts")
run_node() {
  local ip=$1 command_line
  shift
  if [[ "$ip" == "$CONTROL_IP" ]]; then
    "$@"
  else
    printf -v command_line '%q ' "$@"
    ssh "${SSH_OPTIONS[@]}" "$SSH_USER@$ip" "$command_line"
  fi
}
hdfs_command() { run_node "$NAMENODE_IP" sudo -n -u hadoop env HADOOP_CONF_DIR=/etc/hadoop /opt/hadoop/bin/hdfs "$@"; }

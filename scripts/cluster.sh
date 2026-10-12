#!/usr/bin/env bash
set -euo pipefail
source "$(dirname -- "$0")/common.sh"
action=${1:-status}
case "$action" in
  start)
    run_node "$NAMENODE_IP" sudo -n systemctl enable --now hadoop-namenode
    ready=0
    for ((attempt=0; attempt<18; attempt++)); do
      if run_node "$NAMENODE_IP" sudo -n -u hadoop timeout 10 env HADOOP_CONF_DIR=/etc/hadoop /opt/hadoop/bin/hdfs dfsadmin -safemode get > "$ROOT/logs/nn-startup-check.log" 2>&1; then ready=1; break; fi
      sleep 2
    done
    [[ $ready -eq 1 ]] || { echo 'NameNode RPC did not become ready.' >&2; exit 1; }
    for ip in "${DATANODE_IPS[@]}"; do run_node "$ip" sudo -n systemctl enable --now hadoop-datanode; done
    run_node "$SECONDARY_IP" sudo -n systemctl enable --now hadoop-secondarynamenode
    ;;
  stop)
    run_node "$SECONDARY_IP" sudo -n systemctl stop hadoop-secondarynamenode
    for ip in "${DATANODE_IPS[@]}"; do run_node "$ip" sudo -n systemctl stop hadoop-datanode; done
    run_node "$NAMENODE_IP" sudo -n systemctl stop hadoop-namenode
    ;;
  status)
    run_node "$NAMENODE_IP" systemctl is-active hadoop-namenode
    for ip in "${DATANODE_IPS[@]}"; do printf '%s: ' "$ip"; run_node "$ip" systemctl is-active hadoop-datanode; done
    run_node "$SECONDARY_IP" systemctl is-active hadoop-secondarynamenode
    ;;
  *) echo 'Usage: cluster.sh start|stop|status' >&2; exit 2 ;;
esac

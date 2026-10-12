#!/usr/bin/env bash
set -euo pipefail
source "$(dirname -- "$0")/common.sh"
echo 'Waiting for three live DataNodes and safe mode OFF (up to 180 s)...'
healthy=0
for ((attempt=0; attempt<36; attempt++)); do
  if curl -fsS --max-time 5 "http://$NAMENODE_IP:9870/jmx?qry=Hadoop:service=NameNode,name=FSNamesystemState" > "$ROOT/cache/nn-state.json"; then
    if python3 - "$ROOT/cache/nn-state.json" <<'PY'
import json,sys
b=json.load(open(sys.argv[1]))['beans'][0]
sys.exit(0 if b['NumLiveDataNodes']==3 and b['NumDeadDataNodes']==0 and b.get('NumStaleDataNodes',0)==0 else 1)
PY
    then
      if hdfs_command dfsadmin -safemode get | grep -q 'Safe mode is OFF'; then healthy=1; break; fi
    fi
  fi
  sleep 5
done
[[ $healthy -eq 1 ]] || { echo 'Cluster did not become healthy.' >&2; exit 1; }
bash "$ROOT/scripts/cluster.sh" status
hdfs_command dfsadmin -report
# A unique path makes verification repeatable without overwriting user data.
probe="/hw1-check/check-$(date -u +%Y%m%dT%H%M%SZ)-$RANDOM.txt"
hdfs_command dfs -mkdir -p /hw1-check
printf 'HDFS homework 1: write/read/replication verification\n' | hdfs_command dfs -put - "$probe"
run_node "$NAMENODE_IP" sudo -n -u hadoop timeout 120 env HADOOP_CONF_DIR=/etc/hadoop /opt/hadoop/bin/hdfs dfs -setrep -w 3 "$probe"
actual=$(hdfs_command dfs -cat "$probe")
[[ "$actual" == 'HDFS homework 1: write/read/replication verification' ]]
hdfs_command fsck "$probe" -files -blocks -locations | tee "$ROOT/logs/fsck-latest.txt"
grep -q 'Live_repl=3' "$ROOT/logs/fsck-latest.txt"
grep -q 'Status: HEALTHY' "$ROOT/logs/fsck-latest.txt"
echo 'Checking all HDFS files...'
hdfs_command fsck / -files -blocks | tee "$ROOT/logs/fsck-all-latest.txt"
grep -q 'Status: HEALTHY' "$ROOT/logs/fsck-all-latest.txt"
# Confirm that SecondaryNameNode actually generated a checkpoint.
checkpoint=0
for ((attempt=0; attempt<18; attempt++)); do
  if run_node "$SECONDARY_IP" sudo -n find /var/lib/hadoop-hdfs/secondary/current -maxdepth 1 -name 'fsimage_[0-9]*' ! -name '*.md5' -type f -size +0c 2>/dev/null | grep -q fsimage_; then checkpoint=1; break; fi
  sleep 5
done
[[ $checkpoint -eq 1 ]] || { echo 'No SecondaryNameNode checkpoint found.' >&2; exit 1; }
echo 'HDFS logs: ERROR/FATAL lines (empty output is expected on a healthy deployment)'
log_errors=0
for ip in "${ALL_IPS[@]}"; do
  if run_node "$ip" sudo -n bash -c 'grep -EH "(^|[[:space:]])(ERROR|FATAL)([[:space:]]|$)" /var/log/hadoop-hdfs/*.log 2>/dev/null'; then log_errors=1; fi
done
[[ $log_errors -eq 0 ]] || { echo 'Inspect the error lines above.' >&2; exit 1; }
printf 'VERIFY_OK\nProbe retained for inspection: %s\n' "$probe"

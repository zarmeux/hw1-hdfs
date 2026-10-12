#!/usr/bin/env bash
# Check the deployed cluster without restarting services or writing to HDFS.
set -euo pipefail
export LC_ALL=C
source "$(dirname -- "$0")/common.sh"
printf 'HDFS review: %s\n' "$(date -u +%FT%TZ)"
check_service() {
  local ip=$1 role=$2
  [[ $(run_node "$ip" systemctl is-active "hadoop-$role") == active ]]
  [[ $(run_node "$ip" systemctl is-enabled "hadoop-$role") == enabled ]]
  printf 'SERVICE_OK %s %s active/enabled\n' "$ip" "$role"
}
check_service "$NAMENODE_IP" namenode
check_service "$SECONDARY_IP" secondarynamenode
for ip in "${DATANODE_IPS[@]}"; do check_service "$ip" datanode; done
curl -fsS --max-time 10 "http://$NAMENODE_IP:9870/jmx?qry=Hadoop:service=NameNode,name=FSNamesystemState" > "$ROOT/cache/review-namenode.json"
python3 - "$ROOT/cache/review-namenode.json" <<'PY'
import json,sys
b=json.load(open(sys.argv[1]))['beans'][0]
expected={'NumLiveDataNodes':3,'NumInServiceLiveDataNodes':3,'NumDeadDataNodes':0,
          'NumStaleDataNodes':0,'VolumeFailuresTotal':0,'UnderReplicatedBlocks':0,
          'PendingReplicationBlocks':0}
for key,value in expected.items():
    actual=b.get(key)
    if actual!=value:
        raise SystemExit(f'CHECK_FAILED {key}: expected={value}, actual={actual}')
    print(f'METRIC_OK {key}={actual}')
PY
hdfs_command dfsadmin -safemode get | tee "$ROOT/logs/review-safemode.txt"
grep -q 'Safe mode is OFF' "$ROOT/logs/review-safemode.txt"
hdfs_command fsck / -files -blocks > "$ROOT/logs/review-fsck.txt"
grep -q 'Status: HEALTHY' "$ROOT/logs/review-fsck.txt"
echo 'FSCK_OK / HEALTHY'
hdfs_command fsck /hw1-check -files -blocks -locations > "$ROOT/logs/review-replicas.txt"
grep -q 'Live_repl=3' "$ROOT/logs/review-replicas.txt"
grep -q 'Status: HEALTHY' "$ROOT/logs/review-replicas.txt"
echo 'REPLICATION_OK /hw1-check Live_repl=3'
run_node "$SECONDARY_IP" sudo -n find /var/lib/hadoop-hdfs/secondary/current -maxdepth 1 -type f -name 'fsimage_[0-9]*' ! -name '*.md5' -size +0c > "$ROOT/logs/review-checkpoint.txt"
[[ -s "$ROOT/logs/review-checkpoint.txt" ]]
echo 'CHECKPOINT_OK SecondaryNameNode fsimage exists'
echo 'REVIEW_OK'

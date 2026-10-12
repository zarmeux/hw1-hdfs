#!/usr/bin/env bash
set -euo pipefail
name_dir=/var/lib/hadoop-hdfs/namenode
if [[ -f "$name_dir/current/VERSION" ]]; then
  echo 'NameNode already formatted; keeping its namespace.'
elif [[ -z $(find "$name_dir" -mindepth 1 -print -quit) ]]; then
  sudo -n -u hadoop env HADOOP_CONF_DIR=/etc/hadoop /opt/hadoop/bin/hdfs namenode -format -nonInteractive -clusterid hw1-hdfs
else
  echo 'NameNode directory is nonempty but has no VERSION. Refusing to format.' >&2
  exit 1
fi

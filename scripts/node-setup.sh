#!/usr/bin/env bash
# Invoked as root by deploy.sh; never formats storage.
set -euo pipefail
NODE_IP=$1 NN_IP=$2 SNN_IP=$3 VERSION=$4 EXPECTED_SHA=$5 ARCHIVE=$6
shift 6
DN_IPS=("$@")
[[ $EUID -eq 0 ]] || { echo 'Root privileges required.' >&2; exit 1; }
for file in /etc/hadoop/core-site.xml /etc/hadoop/hdfs-site.xml; do
  if [[ -e "$file" && ! -e /etc/hadoop/.hw1-managed ]]; then
    echo "Unmanaged configuration found: $file. Refusing to overwrite." >&2; exit 1
  fi
done
if [[ -e /opt/hadoop && ! -e /etc/hadoop/.hw1-managed ]]; then
  echo 'An unmanaged Hadoop installation already exists.' >&2; exit 1
fi
printf '%s  %s\n' "$EXPECTED_SHA" "$ARCHIVE" | sha512sum -c -
# Ubuntu may resolve its own hostname to 127.0.1.1 even when a service address
# contains an IP. Hadoop RPC canonicalizes names, so keep the own hostname
# exclusively on the private address; preserve localhost and other mappings.
python3 - "$NODE_IP" <<'PY'
import pathlib, shutil, socket, sys
p=pathlib.Path('/etc/hosts')
if not pathlib.Path('/etc/hosts.hw1-backup').exists():
    shutil.copy2(p, '/etc/hosts.hw1-backup')
host=socket.gethostname().split('.')[0]
aliases={host}
mapped=set()
lines=[]
for line in p.read_text().splitlines():
    body, sep, comment=line.partition('#')
    fields=body.split()
    if fields and fields[0]==sys.argv[1]:
        mapped.update(fields[1:])
    if fields and fields[0]=='127.0.1.1':
        own=[a for a in fields[1:] if a==host or a.startswith(host+'.')]
        aliases.update(own)
        if own:
            other=[a for a in fields[1:] if a not in own]
            if other:
                lines.append('127.0.1.1\t'+' '.join(other)+((' #'+comment) if sep else ''))
            elif sep:
                lines.append('#'+comment)
            continue
    lines.append(line)
missing=aliases-mapped
if missing:
    lines.append(sys.argv[1]+'\t'+' '.join(sorted(missing)))
p.write_text('\n'.join(lines)+'\n')
PY
export DEBIAN_FRONTEND=noninteractive
if ! dpkg-query -W -f='${Status}' openjdk-11-jdk-headless 2>/dev/null | grep -q 'install ok installed'; then
  apt-get update -qq
  apt-get install -y -qq openjdk-11-jdk-headless
fi
JAVA_HOME=$(find /usr/lib/jvm -maxdepth 1 -type d -name 'java-11-openjdk-*' | sort | head -n 1)
[[ -x "$JAVA_HOME/bin/java" ]] || { echo 'Java 11 not found.' >&2; exit 1; }
if ! id hadoop >/dev/null 2>&1; then
  useradd --system --create-home --home-dir /home/hadoop --shell /bin/bash hadoop
fi
if [[ ! -x "/opt/hadoop-$VERSION/bin/hdfs" ]]; then
  tar -xzf "$ARCHIVE" -C /opt --no-same-owner
fi
ln -sfn "/opt/hadoop-$VERSION" /opt/hadoop
install -d -m 0755 /etc/hadoop
cp -r --update=none "/opt/hadoop-$VERSION/etc/hadoop/." /etc/hadoop/
touch /etc/hadoop/.hw1-managed
install -d -o hadoop -g hadoop -m 0750 /var/lib/hadoop-hdfs /var/lib/hadoop-hdfs/namenode /var/lib/hadoop-hdfs/datanode /var/lib/hadoop-hdfs/secondary /var/lib/hadoop-hdfs/tmp /var/log/hadoop-hdfs
cat > /etc/hadoop/hadoop-env.sh <<EOF
export JAVA_HOME=$JAVA_HOME
export HADOOP_HOME=/opt/hadoop
export HADOOP_CONF_DIR=/etc/hadoop
export HADOOP_LOG_DIR=/var/log/hadoop-hdfs
export HADOOP_HEAPSIZE_MAX=512m
export HDFS_NAMENODE_OPTS="-Xmx768m"
export HDFS_DATANODE_OPTS="-Xmx512m"
export HDFS_SECONDARYNAMENODE_OPTS="-Xmx512m"
EOF
cat > /etc/hadoop/core-site.xml <<EOF
<?xml version="1.0"?>
<configuration>
  <property><name>fs.defaultFS</name><value>hdfs://$NN_IP:9000</value></property>
  <property><name>hadoop.tmp.dir</name><value>/var/lib/hadoop-hdfs/tmp</value></property>
</configuration>
EOF
cat > /etc/hadoop/hdfs-site.xml <<EOF
<?xml version="1.0"?>
<configuration>
  <property><name>dfs.replication</name><value>3</value></property>
  <property><name>dfs.namenode.rpc-address</name><value>$NN_IP:9000</value></property>
  <property><name>dfs.namenode.rpc-bind-host</name><value>$NN_IP</value></property>
  <property><name>dfs.namenode.http-address</name><value>$NN_IP:9870</value></property>
  <property><name>dfs.namenode.http-bind-host</name><value>$NN_IP</value></property>
  <property><name>dfs.namenode.secondary.http-address</name><value>$SNN_IP:9868</value></property>
  <property><name>dfs.namenode.name.dir</name><value>file:///var/lib/hadoop-hdfs/namenode</value></property>
  <property><name>dfs.datanode.data.dir</name><value>file:///var/lib/hadoop-hdfs/datanode</value></property>
  <property><name>dfs.namenode.checkpoint.dir</name><value>file:///var/lib/hadoop-hdfs/secondary</value></property>
  <property><name>dfs.namenode.checkpoint.edits.dir</name><value>file:///var/lib/hadoop-hdfs/secondary</value></property>
  <property><name>dfs.namenode.checkpoint.period</name><value>60</value></property>
  <property><name>dfs.datanode.address</name><value>$NODE_IP:9866</value></property>
  <property><name>dfs.datanode.ipc.address</name><value>$NODE_IP:9867</value></property>
  <property><name>dfs.datanode.http.address</name><value>$NODE_IP:9864</value></property>
  <property><name>dfs.datanode.hostname</name><value>$NODE_IP</value></property>
  <property><name>dfs.hosts</name><value>/etc/hadoop/dfs-hosts</value></property>
</configuration>
EOF
printf '%s\n' "${DN_IPS[@]}" > /etc/hadoop/workers
cp /etc/hadoop/workers /etc/hadoop/dfs-hosts
cat > /etc/profile.d/hadoop.sh <<EOF
export JAVA_HOME=$JAVA_HOME
export HADOOP_HOME=/opt/hadoop
export HADOOP_CONF_DIR=/etc/hadoop
export PATH=\$PATH:/opt/hadoop/bin:/opt/hadoop/sbin
EOF
for role in namenode datanode secondarynamenode; do
  cat > "/etc/systemd/system/hadoop-$role.service" <<EOF
[Unit]
Description=HDFS $role
Wants=network-online.target
After=network-online.target
[Service]
Type=simple
User=hadoop
Group=hadoop
Environment=JAVA_HOME=$JAVA_HOME
Environment=HADOOP_HOME=/opt/hadoop
Environment=HADOOP_CONF_DIR=/etc/hadoop
Environment=HADOOP_LOG_DIR=/var/log/hadoop-hdfs
ExecStart=/opt/hadoop/bin/hdfs $role
StandardOutput=append:/var/log/hadoop-hdfs/$role.log
StandardError=inherit
Restart=on-failure
RestartSec=5
TimeoutStopSec=60
KillSignal=SIGTERM
UMask=0027
[Install]
WantedBy=multi-user.target
EOF
done
systemctl daemon-reload
echo "SETUP_OK $NODE_IP"

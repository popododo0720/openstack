#!/bin/bash
set -e
VMINSERT_URL="http://192.168.0.60:8480/insert/0/prometheus/api/v1/write"

if [ -f /etc/debian_version ]; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq
    apt-get install -y -qq gpg wget
    mkdir -p /etc/apt/keyrings/
    wget -qO- https://apt.grafana.com/gpg.key | gpg --dearmor > /etc/apt/keyrings/grafana.gpg
    echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" > /etc/apt/sources.list.d/grafana.list
    apt-get update -qq && apt-get install -y -qq alloy
elif [ -f /etc/redhat-release ]; then
    cat > /etc/yum.repos.d/grafana.repo << 'REPO'
[grafana]
name=Grafana
baseurl=https://rpm.grafana.com
gpgcheck=1
gpgkey=https://rpm.grafana.com/gpg.key
sslverify=1
REPO
    dnf install -y alloy || yum install -y alloy
fi

mkdir -p /etc/alloy
cat > /etc/alloy/config.alloy << 'ALLOY'
prometheus.exporter.unix "default" {
  enable_collectors = ["cpu","diskstats","filesystem","loadavg","meminfo","netdev","netstat","os","uname","vmstat","time"]
}

prometheus.exporter.process "default" {
  track_children    = true
  track_threads     = true
  gather_smaps      = true
  recheck_on_scrape = true
  matcher {
    name    = "{{.Comm}}"
    cmdline = [".+"]
  }
}

prometheus.scrape "node" {
  targets         = prometheus.exporter.unix.default.targets
  forward_to      = [prometheus.relabel.add_labels.receiver]
  scrape_interval = "60s"
}

prometheus.scrape "process" {
  targets         = prometheus.exporter.process.default.targets
  forward_to      = [prometheus.relabel.add_labels.receiver]
  scrape_interval = "60s"
}

prometheus.relabel "add_labels" {
  forward_to = [prometheus.remote_write.default.receiver]
  rule {
    target_label = "vm_name"
    replacement  = env("HOSTNAME")
  }
  rule {
    target_label = "job"
    replacement  = "alloy-vm"
  }
}

prometheus.remote_write "default" {
  endpoint {
    url = "VMINSERT_PLACEHOLDER"
  }
}
ALLOY

sed -i "s|VMINSERT_PLACEHOLDER|${VMINSERT_URL}|" /etc/alloy/config.alloy

mkdir -p /etc/systemd/system/alloy.service.d
echo -e "[Service]\nUser=root\nGroup=root" > /etc/systemd/system/alloy.service.d/override.conf
systemctl daemon-reload
systemctl enable alloy && systemctl start alloy

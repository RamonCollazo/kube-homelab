#!/usr/bin/env bash
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "run this as root" >&2
  exit 1
fi

HERE="$(dirname "$(readlink -f "$0")")"

SOPS_VERSION=v3.13.3
curl -fsSL "https://github.com/getsops/sops/releases/download/${SOPS_VERSION}/sops-${SOPS_VERSION}.linux.amd64" \
  -o /usr/local/bin/sops
chmod 755 /usr/local/bin/sops
/usr/local/bin/sops --version

install -d -m 0755 /etc/docker
install -m 0644 "$HERE/host/docker-daemon.json" /etc/docker/daemon.json

install -m 0644 "$HERE/host/52unattended-upgrades-local" \
  /etc/apt/apt.conf.d/52unattended-upgrades-local

install -d -m 0755 /etc/systemd/journald.conf.d
install -m 0644 "$HERE/host/journald-size.conf" /etc/systemd/journald.conf.d/size.conf

install -m 0644 "$HERE/greencloud-deploy.service" /etc/systemd/system/
install -m 0644 "$HERE/greencloud-deploy.timer" /etc/systemd/system/

systemctl restart systemd-journald
systemctl daemon-reload
systemctl enable --now greencloud-deploy.timer
systemctl restart docker

echo "bootstrap complete"

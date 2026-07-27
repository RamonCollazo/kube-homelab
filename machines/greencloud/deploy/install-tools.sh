#!/usr/bin/env bash
set -euo pipefail

SOPS_VERSION=v3.13.3

curl -fsSL "https://github.com/getsops/sops/releases/download/${SOPS_VERSION}/sops-${SOPS_VERSION}.linux.amd64" \
  -o /usr/local/bin/sops
chmod 755 /usr/local/bin/sops
/usr/local/bin/sops --version

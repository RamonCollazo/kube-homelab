#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$(readlink -f "$0")")"

docker network inspect edge >/dev/null 2>&1 || docker network create edge

for app in apps/*/; do
  [ -f "${app}docker-compose.yaml" ] || continue
  echo "converging ${app%/}"
  if [ -f "${app}secrets.env" ]; then
    (cd "$app" && sops exec-env secrets.env 'docker compose up -d --remove-orphans')
  else
    (cd "$app" && docker compose up -d --remove-orphans)
  fi
done

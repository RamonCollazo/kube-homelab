#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$(readlink -f "$0")")"

if [ -z "${GREENCLOUD_SECRETS_LOADED:-}" ]; then
  if [ ! -f secrets.env ]; then
    echo "missing $(pwd)/secrets.env" >&2
    exit 1
  fi
  export GREENCLOUD_SECRETS_LOADED=1
  exec sops exec-env secrets.env "$0"
fi

docker network inspect edge >/dev/null 2>&1 || docker network create edge

for app in apps/*/; do
  [ -f "${app}docker-compose.yaml" ] || continue
  echo "converging ${app%/}"
  (cd "$app" && docker compose up -d --remove-orphans)
done

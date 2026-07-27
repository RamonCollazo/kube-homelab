#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$(readlink -f "$0")")"

if [ ! -f .env ]; then
  echo "missing $(pwd)/.env, copy .env.example and fill it in" >&2
  exit 1
fi

docker network inspect edge >/dev/null 2>&1 || docker network create edge

for app in apps/*/; do
  [ -f "${app}docker-compose.yaml" ] || continue
  echo "converging ${app%/}"
  (cd "$app" && docker compose --env-file ../../.env up -d --remove-orphans)
done

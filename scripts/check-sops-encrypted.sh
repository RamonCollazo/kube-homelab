#!/usr/bin/env bash
set -euo pipefail

status=0
for f in "$@"; do
  [ -f "$f" ] || continue
  if ! grep -q 'ENC\[AES256_GCM' "$f"; then
    echo "$f is not SOPS-encrypted, refusing to commit" >&2
    status=1
  fi
done
exit "$status"

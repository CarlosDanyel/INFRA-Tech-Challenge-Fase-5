#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/docker-public-config.sh
for port in 18080 18081 18082; do
  if [ -f "/tmp/fiapx-$port.pid" ]; then kill "$(cat "/tmp/fiapx-$port.pid")" 2>/dev/null || true; rm "/tmp/fiapx-$port.pid"; fi
done
docker compose down

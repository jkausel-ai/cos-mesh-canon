#!/usr/bin/env bash
# cos-canon-refresh.sh — Hourly canon refresh for persistent nodes (Hermes VPS)
# Deploys to: /root/.local/bin/cos-canon-refresh.sh
# Cron entry:  0 * * * * /bin/bash /root/.local/bin/cos-canon-refresh.sh
#
# Pulls latest nodes.json + topology doc. Logs drift to /root/.local/log/cos-canon.log.
# Safe to run hourly — idempotent, lightweight (~5KB download per fire).

set -euo pipefail

LOG="/root/.local/log/cos-canon.log"
CANON_DIR="/root/.claudeos/cos-mesh-canon"
BASE="https://raw.githubusercontent.com/jkausel-ai/cos-mesh-canon/main"

mkdir -p "$CANON_DIR" "$(dirname "$LOG")"
ts() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }

# Pull latest
set +e
curl -sS --max-time 15 "$BASE/nodes.json" -o "$CANON_DIR/nodes.json.new"
RC_N=$?
curl -sS --max-time 15 "$BASE/COS-MESH-TOPOLOGY-v2.md" -o "$CANON_DIR/COS-MESH-TOPOLOGY-v2.md.new"
RC_T=$?
set -e

if [ $RC_N -ne 0 ] || [ $RC_T -ne 0 ]; then
  echo "[$(ts)] canon refresh FAILED (nodes.json rc=$RC_N, topology rc=$RC_T)" >> "$LOG"
  exit 1
fi

# Compare + swap
CHANGED=0
if [ -f "$CANON_DIR/nodes.json" ]; then
  if ! cmp -s "$CANON_DIR/nodes.json" "$CANON_DIR/nodes.json.new"; then
    CHANGED=1
    echo "[$(ts)] nodes.json UPDATED" >> "$LOG"
  fi
fi
mv -f "$CANON_DIR/nodes.json.new" "$CANON_DIR/nodes.json"
mv -f "$CANON_DIR/COS-MESH-TOPOLOGY-v2.md.new" "$CANON_DIR/COS-MESH-TOPOLOGY-v2.md"

if [ $CHANGED -eq 0 ]; then
  echo "[$(ts)] canon refresh OK (no changes)" >> "$LOG"
fi

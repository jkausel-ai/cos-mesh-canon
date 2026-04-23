#!/usr/bin/env bash
# cos-hub-rollcall.sh — COS Hub (PMBP) machine rollcall to CF mesh
# Sends a rollcall status message on machine boot or on-demand
# Called by launchd on login: ~/Library/LaunchAgents/co.cochalet.hub-rollcall.plist
# Also callable manually: bash ~/.local/bin/cos-hub-rollcall.sh

set -euo pipefail

MESH_URL="https://cos-mesh-v2.jkausel.workers.dev"
ENV_FILE="$HOME/.config/cos-mesh/hub.env"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "ERROR: $ENV_FILE not found" >&2
  exit 1
fi

source "$ENV_FILE"

if [[ -z "${COS_MESH_API_KEY:-}" ]]; then
  echo "ERROR: COS_MESH_API_KEY not set in $ENV_FILE" >&2
  exit 1
fi

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
HOSTNAME_VAL=$(hostname)

BODY="Machine: ${COS_MESH_NODE_ID} | Host: ${HOSTNAME_VAL} | Callsign: ${COS_MESH_CALLSIGN} | Boot rollcall: ${TIMESTAMP} | Agents available: [em1, cmo, codex-hermes-oncall, codex-cochalet-app]"

RESPONSE=$(curl -s -X POST "${MESH_URL}/msg" \
  -H "Content-Type: application/json" \
  -H "X-API-Key: ${COS_MESH_API_KEY}" \
  -d "{
    \"to_node\": \"hermes\",
    \"msg_type\": \"status\",
    \"priority\": \"P2\",
    \"subject\": \"ROLLCALL: ${COS_MESH_NODE_ID} online — ${COS_MESH_CALLSIGN}\",
    \"body\": \"${BODY}\"
  }" 2>/dev/null)

MSG_ID=$(echo "$RESPONSE" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('msg_id','ERROR')[:8])" 2>/dev/null || echo "ERROR")
STATUS=$(echo "$RESPONSE" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('status','ERROR'))" 2>/dev/null || echo "ERROR")

echo "$(date -u +"%Y-%m-%dT%H:%M:%SZ") hub rollcall: ${STATUS} msg=${MSG_ID}" >> "$HOME/.local/log/cos-hub-rollcall.log" 2>/dev/null || true
echo "ROLLCALL ${STATUS} msg=${MSG_ID}"

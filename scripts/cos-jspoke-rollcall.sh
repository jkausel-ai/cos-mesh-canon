#!/usr/bin/env bash
# cos-jspoke-rollcall.sh — COS J-Spoke (JNMBP) machine rollcall to CF mesh
# Deploy to JNMBP: copy to ~/.local/bin/cos-jspoke-rollcall.sh
# LaunchAgent on JNMBP: ~/Library/LaunchAgents/co.cochalet.jspoke-rollcall.plist
#
# Credentials needed on JNMBP:
#   ~/.config/cos-mesh/j-spoke.env containing:
#     COS_MESH_NODE_ID=j-spoke
#     COS_MESH_URL=https://cos-mesh-v2.jkausel.workers.dev
#     COS_MESH_API_KEY=6075d82b-c183-4713-a711-37367b6d1e11
#     COS_MESH_CALLSIGN=COS-JSPOKE-JNMBP-01

set -euo pipefail

MESH_URL="https://cos-mesh-v2.jkausel.workers.dev"
ENV_FILE="${HOME}/.config/cos-mesh/j-spoke.env"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "ERROR: $ENV_FILE not found. Create it with j-spoke credentials." >&2
  exit 1
fi

source "$ENV_FILE"

if [[ -z "${COS_MESH_API_KEY:-}" ]]; then
  echo "ERROR: COS_MESH_API_KEY not set" >&2
  exit 1
fi

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
HOSTNAME_VAL=$(hostname)

BODY="Machine: ${COS_MESH_NODE_ID} | Host: ${HOSTNAME_VAL} | Callsign: ${COS_MESH_CALLSIGN} | Boot rollcall: ${TIMESTAMP} | Prior callsigns: BOREAL-DEED-65, T3-NUOVO-CEDAR-COMPASS-11"

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

mkdir -p "${HOME}/.local/log"
echo "$(date -u +"%Y-%m-%dT%H:%M:%SZ") j-spoke rollcall: ${STATUS} msg=${MSG_ID}" >> "${HOME}/.local/log/cos-jspoke-rollcall.log" 2>/dev/null || true
echo "ROLLCALL ${STATUS} msg=${MSG_ID}"

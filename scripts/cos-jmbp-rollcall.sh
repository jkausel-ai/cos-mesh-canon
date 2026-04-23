#!/usr/bin/env bash
# cos-jmbp-rollcall.sh — COS JMBP (Jesse's MacBook Pro) machine rollcall to CF mesh
# Deploy to JMBP: copy to ~/.local/bin/cos-jmbp-rollcall.sh
# LaunchAgent on JMBP: ~/Library/LaunchAgents/co.cochalet.jmbp-rollcall.plist
#
# Credentials needed on JMBP:
#   ~/.config/cos-mesh/jmbp.env containing:
#     COS_MESH_NODE_ID=jmbp
#     COS_MESH_URL=https://cos-mesh-v2.jkausel.workers.dev
#     COS_MESH_API_KEY=6d325d8c-ad76-4bc6-b3c5-7138942330ad
#     COS_MESH_CALLSIGN=EM2-JMBP-NUOVO-01

set -euo pipefail

MESH_URL="https://cos-mesh-v2.jkausel.workers.dev"
ENV_FILE="${HOME}/.config/cos-mesh/jmbp.env"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "ERROR: $ENV_FILE not found. Create it with jmbp credentials." >&2
  exit 1
fi

source "$ENV_FILE"

if [[ -z "${COS_MESH_API_KEY:-}" ]]; then
  echo "ERROR: COS_MESH_API_KEY not set" >&2
  exit 1
fi

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
HOSTNAME_VAL=$(hostname)

BODY="Machine: ${COS_MESH_NODE_ID} | Host: ${HOSTNAME_VAL} | Callsign: ${COS_MESH_CALLSIGN} | Boot rollcall: ${TIMESTAMP} | Nuovo Spoke (Jesse's MBP)"

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
echo "$(date -u +"%Y-%m-%dT%H:%M:%SZ") jmbp rollcall: ${STATUS} msg=${MSG_ID}" >> "${HOME}/.local/log/cos-jmbp-rollcall.log" 2>/dev/null || true
echo "ROLLCALL ${STATUS} msg=${MSG_ID}"

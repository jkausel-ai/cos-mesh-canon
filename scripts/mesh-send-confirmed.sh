#!/usr/bin/env bash
# mesh-send-confirmed.sh — cos-mesh POST with delivery confirmation
#
# Usage:
#   mesh-send-confirmed.sh <from_node> <to_node> <msg_type> <priority> <subject> <body>
#
# Example:
#   mesh-send-confirmed.sh em1 cmo directive P1 "test" "hello"
#
# What it does:
#   1. POSTs /msg from <from_node>'s key → captures msg_id
#   2. Waits 30s for Worker delivery cycle
#   3. Polls target's /inbox (requires target's key at ~/.config/cos-mesh/<to_node>.env)
#   4. Returns: DELIVERED | PENDING | UNCONFIRMED + msg_id + diagnostic
#
# Secrets discipline:
#   - Never prints keys, ever
#   - Reads keys from ~/.config/cos-mesh/<node>.env
#   - If target key is missing, returns UNCONFIRMED without attempting target-side verify

set -uo pipefail

MESH_URL="${COS_MESH_URL:-https://cos-mesh-v2.jkausel.workers.dev}"
CONFIG_DIR="${HOME}/.config/cos-mesh"

err() { echo "ERR: $*" >&2; exit 2; }

[[ $# -ge 6 ]] || err "usage: $0 <from_node> <to_node> <msg_type> <priority> <subject> <body>"

FROM="$1"; TO="$2"; TYPE="$3"; PRI="$4"; SUBJ="$5"; BODY="$6"

FROM_ENV="${CONFIG_DIR}/${FROM}.env"
TO_ENV="${CONFIG_DIR}/${TO}.env"

[[ -f "$FROM_ENV" ]] || err "missing sender env: $FROM_ENV"
source "$FROM_ENV"

# Step 1 — POST the message, capture msg_id
PAYLOAD=$(python3 -c "
import json, os
print(json.dumps({
  'to_node': '$TO',
  'msg_type': '$TYPE',
  'priority': '$PRI',
  'subject': os.environ.get('SUBJ_ENV', ''),
  'body': os.environ.get('BODY_ENV', '')
}))" SUBJ_ENV="$SUBJ" BODY_ENV="$BODY")

RESP=$(curl -sS -m 10 -X POST "${MESH_URL}/msg" \
  -H "Content-Type: application/json" \
  -H "X-API-Key: $COS_MESH_API_KEY" \
  -d "$PAYLOAD")

MSG_ID=$(echo "$RESP" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('msg_id',''))" 2>/dev/null)
POST_STATUS=$(echo "$RESP" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('status',''))" 2>/dev/null)

if [[ -z "$MSG_ID" ]]; then
  echo "FAIL: POST did not return msg_id"
  echo "$RESP" | head -c 500
  exit 1
fi

echo "POSTED: msg_id=${MSG_ID} status=${POST_STATUS}"

# Step 2 — Wait for Worker delivery window
SLEEP_SEC="${MESH_CONFIRM_SLEEP:-30}"
echo "Waiting ${SLEEP_SEC}s for delivery..."
sleep "$SLEEP_SEC"

# Step 3 — Try target-side verification
if [[ ! -f "$TO_ENV" ]]; then
  echo "UNCONFIRMED: target env $TO_ENV not available locally. msg_id=${MSG_ID}"
  echo "Options:"
  echo "  (a) ask target to run: curl -H 'X-API-Key: \$KEY' '${MESH_URL}/inbox' | grep ${MSG_ID:0:8}"
  echo "  (b) trust the 201 queueing confirmation"
  exit 0
fi

TARGET_KEY=$(python3 -c "
import os
with open('$TO_ENV') as f:
    for line in f:
        if line.startswith('COS_MESH_API_KEY='):
            print(line.split('=',1)[1].strip())
            break
")

[[ -n "$TARGET_KEY" ]] || err "could not read target key from $TO_ENV"

# Step 4 — Poll target inbox for the msg_id
INBOX=$(curl -sS -m 15 -H "X-API-Key: $TARGET_KEY" "${MESH_URL}/inbox?limit=100")

RESULT=$(echo "$INBOX" | python3 -c "
import json, sys
target_id = '$MSG_ID'
try:
    d = json.load(sys.stdin)
except Exception as e:
    print(f'PARSE_ERR: {e}')
    sys.exit(0)

msgs = d.get('messages', [])
hit = [m for m in msgs if m.get('msg_id') == target_id]

if not hit:
    print('NOT_FOUND: msg_id not in target inbox')
    sys.exit(0)

m = hit[0]
delivered = m.get('delivered_at')
acked = m.get('acked_at')

if acked:
    print(f'ACKED: delivered={delivered} acked={acked}')
elif delivered:
    print(f'DELIVERED: delivered={delivered} (target has not ACKed yet)')
else:
    print(f'QUEUED: msg in target inbox but no delivered_at yet')
")

echo "RESULT: $RESULT"
echo "msg_id: $MSG_ID"

# Exit codes:
#   0 = DELIVERED or ACKED (success)
#   1 = NOT_FOUND (silent drop, real problem)
#   2 = usage/config error
case "$RESULT" in
  ACKED*|DELIVERED*|QUEUED*) exit 0 ;;
  NOT_FOUND*) exit 1 ;;
  *) exit 0 ;;  # UNCONFIRMED / PARSE_ERR — soft fail
esac

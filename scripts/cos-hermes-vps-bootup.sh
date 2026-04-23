#!/usr/bin/env bash
# cos-hermes-vps-bootup.sh — COS Hermes VPS automated bootup
# Runs via systemd on every VPS reboot AND can be invoked manually.
# Deploy to VPS: /root/.local/bin/cos-hermes-vps-bootup.sh
# systemd unit:  /etc/systemd/system/cos-hermes-bootup.service
# Manual run:    ssh hermes-vps 'bash /root/.local/bin/cos-hermes-vps-bootup.sh'
#
# What it does (non-interactive, safe for headless):
#   1. Credential auth check → mesh reachable?
#   2. Topology v2 assertion logged (canonical facts)
#   3. Routing sanity grep (find residual hub-as-coordinator refs)
#   4. System health snapshot
#   5. Inbox unread count
#   6. Rollcall to em1 (CONDUCTOR) — NOT hub
#   7. Structured log to /root/.local/log/hermes-bootup.log
#
# What it does NOT do (left to interactive Claude/Codex session via SKILL.md):
#   - Full consensus register reasoning
#   - Dispatch any pending work
#   - Make authority decisions
#   - ACK inbox messages

set -euo pipefail

LOG_DIR="/root/.local/log"
LOG="${LOG_DIR}/hermes-bootup.log"
MESH_URL="https://cos-mesh-v2.jkausel.workers.dev"
CRED_FILE="/root/.claudeos/secrets/cos-mesh-credentials.json"

mkdir -p "$LOG_DIR"

ts()   { date -u +"%Y-%m-%dT%H:%M:%SZ"; }
log()  { echo "[$(ts)] $*" | tee -a "$LOG"; }
fail() { log "FAIL: $*"; exit 1; }

log "════════════════════════════════════════════════════════"
log "HERMES VPS BOOTUP — $(hostname) — $(ts)"
log "════════════════════════════════════════════════════════"

# ───── STEP 1: CREDENTIAL + AUTH ─────
[[ -f "$CRED_FILE" ]] || fail "missing credentials at $CRED_FILE"

NODE_ID=$(python3 -c "import json; print(json.load(open('$CRED_FILE'))['node_id'])")
KEY=$(python3 -c "import json; print(json.load(open('$CRED_FILE'))['api_key'])")
[[ "$NODE_ID" == "hermes" ]] || fail "wrong node_id '$NODE_ID' — expected 'hermes'"

AUTH_TEST=$(curl -sS -o /tmp/hermes-auth.json -w '%{http_code}' \
  -H "X-API-Key: $KEY" "${MESH_URL}/inbox?limit=1")
[[ "$AUTH_TEST" == "200" ]] || fail "mesh auth failed (HTTP $AUTH_TEST)"
log "STEP 1 ✓ credential + mesh auth OK (node=$NODE_ID)"

# ───── STEP 2: TOPOLOGY v2 ASSERTION (log canon) ─────
log "STEP 2 ✓ topology v2 canon:"
log "        Layer 1 INFRA:  hub, macmini, j-spoke, jmbp"
log "        Layer 2 AGENTS: em1(CONDUCTOR), hermes(EXECUTOR,this), codex-hermes-oncall(BUILDER), cmo, codex-cochalet-app"
log "        Rollcalls/status/heartbeat/consensus route to em1 — NEVER hub"

# ───── STEP 3: ROUTING SANITY GREP (source-code only — skip node_modules, venv, source maps, vcs) ─────
# Wrapped end-to-end so any grep/awk non-zero can't kill the script under pipefail.
# Temporarily disable pipefail for this block since grep | grep -v chains are inherently "may exit non-zero".
set +o pipefail
SAMPLE_FILE="/tmp/hermes-bootup-hubrefs.$$"
grep -rln \
  --include='*.py' --include='*.sh' --include='*.json' --include='*.env' \
  --include='*.yaml' --include='*.yml' --include='*.toml' --include='*.ini' \
  --exclude-dir=node_modules --exclude-dir=.git --exclude-dir=__pycache__ \
  --exclude-dir=dist --exclude-dir=build --exclude-dir=.venv --exclude-dir=venv \
  --exclude-dir='venv.bak.*' \
  -e '"to_node"[[:space:]]*:[[:space:]]*"hub"' \
  -e "'to_node'[[:space:]]*:[[:space:]]*'hub'" \
  -e 'to_node=hub' \
  -e 'mesh-send\.sh[[:space:]]\+hub[[:space:]]' \
  -e 'hub.*consensus.*coordinat' \
  -e 'coordinat.*hub' \
  /root/scripts/ /root/.claudeos/ /root/hermes-cochalet/ /root/src/ 2>/dev/null \
  | grep -v 'cos-mesh-hub-credentials' \
  | grep -v '/venv.bak' \
  | grep -v '/site-packages/gymnasium' \
  | grep -v '/deer-flow/' \
  | grep -v '/index-cache/' \
  > "$SAMPLE_FILE" 2>/dev/null
set -o pipefail

HUB_REFS=$(wc -l < "$SAMPLE_FILE" 2>/dev/null || echo 0)
HUB_REFS=${HUB_REFS:-0}
if [[ "$HUB_REFS" -gt 0 ]]; then
  log "STEP 3 ⚠ $HUB_REFS residual hub-as-authority refs found in source code:"
  while IFS= read -r f; do
    log "        $f"
  done < "$SAMPLE_FILE"
else
  log "STEP 3 ✓ no residual hub-as-authority refs in source code"
fi
rm -f "$SAMPLE_FILE" 2>/dev/null || true

# ───── STEP 4: SYSTEM HEALTH SNAPSHOT (defensive — pipefail-safe) ─────
set +o pipefail
UPTIME=$(uptime 2>/dev/null | sed 's/^ *//' | tr -d '\n' || echo "unknown")
LOAD=$(awk '{print $1,$2,$3}' /proc/loadavg 2>/dev/null | tr -d '\n' || echo "unknown")
MEM=$(free -h 2>/dev/null | awk '/^Mem:/{print $3 "/" $2}' | tr -d '\n' || echo "unknown")
DISK=$(df -h / 2>/dev/null | awk 'NR==2{print $5 " used " $4 " free"}' | tr -d '\n' || echo "unknown")
# pgrep -fc can output count AND exit non-zero — use head/tr to dedupe and strip newlines
GATEWAY_PIDS=$(pgrep -fc 'hermes gateway' 2>/dev/null | head -1 | tr -d '\n')
GATEWAY_PIDS=${GATEWAY_PIDS:-0}
HERMES_PIDS=$(pgrep -fc 'hermes-agent' 2>/dev/null | head -1 | tr -d '\n')
HERMES_PIDS=${HERMES_PIDS:-0}
set -o pipefail
log "STEP 4 ✓ health: load=$LOAD mem=$MEM disk=$DISK gateway_procs=$GATEWAY_PIDS hermes_agent_procs=$HERMES_PIDS"
log "        uptime: $UPTIME"

# ───── STEP 5: INBOX UNREAD COUNT (defensive — pipefail-safe) ─────
set +o pipefail
INBOX_SUMMARY=$(curl -sS -H "X-API-Key: $KEY" "${MESH_URL}/inbox?limit=50" 2>/dev/null \
  | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    msgs = d.get('messages', [])
    unread = [m for m in msgs if not m.get('acked_at')]
    p0 = sum(1 for m in unread if m.get('priority')=='P0')
    p1 = sum(1 for m in unread if m.get('priority')=='P1')
    p2 = sum(1 for m in unread if m.get('priority')=='P2')
    print(f'total={len(msgs)} unread={len(unread)} P0={p0} P1={p1} P2={p2}')
except Exception as e:
    print(f'parse_err={e}')
" 2>/dev/null || echo "inbox_fetch_err")
set -o pipefail
log "STEP 5 ✓ inbox: $INBOX_SUMMARY"

# ───── STEP 6: ROLLCALL TO em1 (NOT hub) ─────
ROLLCALL_TS=$(ts)
# Build body — strip all whitespace/newlines defensively to keep JSON valid
ROLLCALL_BODY=$(printf 'Node:hermes Callsign:ALPINE-HERMES-01 Role:EXECUTOR Topology:v2 Routing:%s_refs Load:%s Mem:%s Disk:%s Gateway:%s Hermes:%s Inbox:%s Boot:%s' \
  "$HUB_REFS" "$LOAD" "$MEM" "$DISK" "$GATEWAY_PIDS" "$HERMES_PIDS" "$INBOX_SUMMARY" "$ROLLCALL_TS" \
  | tr -d '\n' | tr -s ' ')
# Use jq if available, else python, to build JSON payload safely (auto-escapes special chars)
if command -v jq >/dev/null 2>&1; then
  PAYLOAD=$(jq -nc \
    --arg to "em1" --arg type "status" --arg pri "P2" \
    --arg subj "ROLLCALL: hermes VPS online — ALPINE-HERMES-01" \
    --arg body "$ROLLCALL_BODY" \
    '{to_node:$to, msg_type:$type, priority:$pri, subject:$subj, body:$body}')
else
  PAYLOAD=$(python3 -c "
import json, os
print(json.dumps({
    'to_node': 'em1',
    'msg_type': 'status',
    'priority': 'P2',
    'subject': 'ROLLCALL: hermes VPS online — ALPINE-HERMES-01',
    'body': os.environ.get('ROLLCALL_BODY','')
}))" ROLLCALL_BODY="$ROLLCALL_BODY")
fi
ROLLCALL_RESP=$(curl -sS -X POST "${MESH_URL}/msg" \
  -H "Content-Type: application/json" \
  -H "X-API-Key: $KEY" \
  -d "$PAYLOAD")
MSG_ID=$(echo "$ROLLCALL_RESP" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    if 'msg_id' in d:
        print(d['msg_id'][:8])
    else:
        print('ERR:' + str(d)[:60])
except Exception as e:
    print('PARSE_ERR:' + str(e)[:40])
" 2>/dev/null || echo "EXEC_ERR")
log "STEP 6 ✓ rollcall sent to em1 (msg=$MSG_ID)"
log "        raw_response: ${ROLLCALL_RESP:0:200}"

log "════════════════════════════════════════════════════════"
log "HERMES VPS BOOT COMPLETE — $(ts)"
log "════════════════════════════════════════════════════════"
echo ""

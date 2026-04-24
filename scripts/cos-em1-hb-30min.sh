#!/usr/bin/env bash
# cos-em1-hb-30min.sh — em1 low-token HB daemon, 30-min cadence
# Runs via launchd (co.cochalet.em1-hb-30min.plist), fires even when no em1 Claude Code session is open.
#
# What it does:
#   1. POST /hb (keeps em1 ACTIVE on mesh registry)
#   2. Poll em1 inbox → check for new P0/P1 activity since last run
#   3. If new activity: fire compact HB status msg to codex-hermes-oncall + hub + hermes
#   4. Log to ~/.local/log/em1-hb.log + write "needs-attention" marker if new P0
#
# Abort: launchctl unload ~/Library/LaunchAgents/co.cochalet.em1-hb-30min.plist

set -uo pipefail
# Note: no -e so network hiccups don't kill the whole run

LOG_DIR="${HOME}/.local/log"
STATE_DIR="${HOME}/.local/state/em1-hb"
LOG="${LOG_DIR}/em1-hb.log"
LAST_SEEN_FILE="${STATE_DIR}/last-seen-msg-id.txt"
ATTENTION_FILE="${STATE_DIR}/needs-attention.txt"
ENV_FILE="${HOME}/.config/cos-mesh/em1.env"

mkdir -p "$LOG_DIR" "$STATE_DIR"
ts() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }
log() { echo "[$(ts)] $*" >> "$LOG"; }

if [[ ! -f "$ENV_FILE" ]]; then
  log "FAIL: missing $ENV_FILE"
  exit 1
fi
source "$ENV_FILE"

# --- 1. /hb daemon ping — keeps em1 ACTIVE on registry ---
HB_RESP=$(curl -sS -m 10 -X POST -H "X-API-Key: $COS_MESH_API_KEY" \
  -H "Content-Type: application/json" \
  -d "{\"current_task\":\"em1-hb-30min-$(date -u +%s)\",\"version\":\"em1-canon@v1.4.0\"}" \
  "$COS_MESH_URL/hb" 2>&1)
log "HB POST: $HB_RESP"

# --- 2. Poll em1 inbox (to tempfile, avoids stdin collision) ---
INBOX_FILE="${STATE_DIR}/inbox-snapshot.json"
curl -sS -m 15 -H "X-API-Key: $COS_MESH_API_KEY" \
  "$COS_MESH_URL/inbox?limit=50" > "$INBOX_FILE" 2>/dev/null

# --- 3. Detect new activity since last run ---
LAST_SEEN="nothing"
[[ -f "$LAST_SEEN_FILE" ]] && LAST_SEEN=$(cat "$LAST_SEEN_FILE")

NEW_ACTIVITY=$(python3 - "$INBOX_FILE" "$LAST_SEEN" <<'PY' 2>/dev/null
import json, sys
inbox_path = sys.argv[1]
last_seen = sys.argv[2]
try:
    d = json.load(open(inbox_path))
except Exception:
    print("parse_err")
    sys.exit(0)

msgs = d.get('messages', [])
unread = [m for m in msgs if not m.get('acked_at')]
unread.sort(key=lambda x: x.get('created_at', ''))

if not unread:
    print("none")
    sys.exit(0)

newest_id = unread[-1].get('msg_id', '')
if newest_id == last_seen:
    print("none")
else:
    p0 = sum(1 for m in unread if m.get('priority') == 'P0')
    p1 = sum(1 for m in unread if m.get('priority') == 'P1')
    p2 = sum(1 for m in unread if m.get('priority') == 'P2')
    senders = sorted(set(m.get('from_node', '') for m in unread))
    print(f"new|newest={newest_id}|total={len(unread)}|p0={p0}|p1={p1}|p2={p2}|senders={','.join(senders)}")
PY
)

log "Inbox poll: $NEW_ACTIVITY"

# --- 4. If new activity: update last-seen, fire HB to peers, flag attention if P0 ---
if [[ "$NEW_ACTIVITY" == new\|* ]]; then
  NEWEST=$(echo "$NEW_ACTIVITY" | cut -d'|' -f2 | cut -d'=' -f2)
  P0=$(echo "$NEW_ACTIVITY" | grep -oE 'p0=[0-9]+' | cut -d'=' -f2)
  TOTAL=$(echo "$NEW_ACTIVITY" | grep -oE 'total=[0-9]+' | cut -d'=' -f2)

  # Update last-seen marker
  echo "$NEWEST" > "$LAST_SEEN_FILE"

  # If P0s present, write attention flag
  if [[ "${P0:-0}" -gt 0 ]]; then
    echo "$(ts) | P0 count=$P0 total_unread=$TOTAL newest=$NEWEST" > "$ATTENTION_FILE"
    log "ATTENTION: $P0 P0 messages in inbox — see $ATTENTION_FILE"
  fi

  # Fire compact HB to peer agents (only on change, not every cycle — saves tokens)
  HB_BODY="em1 HB @ $(ts) | inbox $TOTAL unread (P0=$P0) | canon v1.4.0 | on-demand, ping when gate ships"
  for target in codex-hermes-oncall hub hermes; do
    curl -sS -m 10 -X POST "$COS_MESH_URL/msg" \
      -H "Content-Type: application/json" \
      -H "X-API-Key: $COS_MESH_API_KEY" \
      -d "{\"to_node\":\"$target\",\"msg_type\":\"status\",\"priority\":\"P3\",\"subject\":\"[em1 HB] 30min — $TOTAL unread (P0=$P0)\",\"body\":\"$HB_BODY\"}" \
      > /dev/null 2>&1
  done
  log "Compact HB fanned to codex-hermes-oncall + hub + hermes (TOTAL=$TOTAL, P0=$P0)"
else
  log "No new activity (no HB fanout — token-saver)"
fi

# --- 5. Done ---
log "Cycle complete"
echo "" >> "$LOG"  # blank line between cycles

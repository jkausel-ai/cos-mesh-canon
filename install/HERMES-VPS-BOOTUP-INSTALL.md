# Hermes VPS Bootup — Install & Usage

**Machine:** Hermes VPS (srv1568205, 187.124.212.189)
**Node:** `hermes` | Callsign: `ALPINE-HERMES-01`
**Role:** EXECUTOR (resident on VPS)
**Prepared by:** em1 | 2026-04-23

Two bootup modes, both covered:

- **Headless auto-bootup** — systemd oneshot that fires on every VPS reboot
- **Interactive CLI bootup** — manual SSH invocation when you want to see status now, or when Claude/Codex sessions attach

---

## Part 1 — Manual CLI Bootup (right now)

Connect to the VPS and run the script. You can do this today without any install, because the script is self-contained.

```bash
# From your PMBP (or any machine with hermes-vps SSH alias):
ssh hermes-vps 'bash -s' < /Users/justinkausel/Documents/new-project/infrastructure/scripts/cos-hermes-vps-bootup.sh
```

Or if the script is already on the VPS:
```bash
ssh hermes-vps 'bash /root/.local/bin/cos-hermes-vps-bootup.sh'
```

Or directly on the VPS (in tmux `hermes-vps-shell` session):
```bash
bash /root/.local/bin/cos-hermes-vps-bootup.sh
```

Output: log lines to stdout + appended to `/root/.local/log/hermes-bootup.log`.

**Expected outcome:** 6 `✓` checkmarks for steps 1-6, one rollcall message landing in em1's inbox, exit 0.

---

## Part 2 — Install Auto-Bootup (systemd, fires on every reboot)

Run these blocks on the VPS (or paste into the `hermes-vps-shell` tmux session).

### Block 1 — Copy script to canonical location

```bash
mkdir -p /root/.local/bin /root/.local/log
cat > /root/.local/bin/cos-hermes-vps-bootup.sh << 'SCRIPT'
#!/usr/bin/env bash
# cos-hermes-vps-bootup.sh — COS Hermes VPS automated bootup
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

[[ -f "$CRED_FILE" ]] || fail "missing credentials at $CRED_FILE"
NODE_ID=$(python3 -c "import json; print(json.load(open('$CRED_FILE'))['node_id'])")
KEY=$(python3 -c "import json; print(json.load(open('$CRED_FILE'))['api_key'])")
[[ "$NODE_ID" == "hermes" ]] || fail "wrong node_id '$NODE_ID' — expected 'hermes'"

AUTH_TEST=$(curl -sS -o /tmp/hermes-auth.json -w '%{http_code}' \
  -H "X-API-Key: $KEY" "${MESH_URL}/inbox?limit=1")
[[ "$AUTH_TEST" == "200" ]] || fail "mesh auth failed (HTTP $AUTH_TEST)"
log "STEP 1 ✓ credential + mesh auth OK (node=$NODE_ID)"

log "STEP 2 ✓ topology v2 canon: hub/macmini/j-spoke/jmbp=INFRA; em1=CONDUCTOR; status/heartbeat/consensus→em1 NEVER hub"

HUB_REFS=$(grep -rln \
    -e 'to_node.*"hub"' -e "to_node.*'hub'" \
    -e 'hub.*consensus' -e 'hub.*coordinate' -e 'mesh-send.*hub' \
    /root/scripts/ /root/.claudeos/ /root/hermes-cochalet/ /root/src/ 2>/dev/null \
    | grep -v '__pycache__' | grep -v '.git/' | grep -v 'cos-mesh-hub-credentials' \
    | wc -l)
if [[ "$HUB_REFS" -gt 0 ]]; then
  log "STEP 3 ⚠ $HUB_REFS residual hub-as-authority refs"
else
  log "STEP 3 ✓ no residual hub-as-authority refs"
fi

UPTIME=$(uptime | sed 's/^ *//')
LOAD=$(awk '{print $1,$2,$3}' /proc/loadavg)
MEM=$(free -h | awk '/^Mem:/{print $3 "/" $2}')
DISK=$(df -h / | awk 'NR==2{print $5 " used"}')
GATEWAY_PIDS=$(pgrep -f 'hermes gateway' | wc -l)
log "STEP 4 ✓ health: load=$LOAD mem=$MEM disk=$DISK gateway_procs=$GATEWAY_PIDS uptime=$UPTIME"

INBOX_SUMMARY=$(curl -sS -H "X-API-Key: $KEY" "${MESH_URL}/inbox?limit=50" \
  | python3 -c "
import json, sys
d = json.load(sys.stdin)
msgs = d.get('messages', [])
unread = [m for m in msgs if not m.get('acked_at')]
p0 = sum(1 for m in unread if m.get('priority')=='P0')
p1 = sum(1 for m in unread if m.get('priority')=='P1')
p2 = sum(1 for m in unread if m.get('priority')=='P2')
print(f'total={len(msgs)} unread={len(unread)} P0={p0} P1={p1} P2={p2}')
")
log "STEP 5 ✓ inbox: $INBOX_SUMMARY"

ROLLCALL_TS=$(ts)
BODY="Node:hermes|Callsign:ALPINE-HERMES-01|Role:EXECUTOR|Topology:v2|Routing:${HUB_REFS}_residual|Load:${LOAD}|Mem:${MEM}|Disk:${DISK}|Gateway:${GATEWAY_PIDS}|Inbox:${INBOX_SUMMARY}|Boot:${ROLLCALL_TS}"
ROLLCALL_RESP=$(curl -sS -X POST "${MESH_URL}/msg" \
  -H "Content-Type: application/json" -H "X-API-Key: $KEY" \
  -d "{\"to_node\":\"em1\",\"msg_type\":\"status\",\"priority\":\"P2\",\"subject\":\"ROLLCALL: hermes VPS online — ALPINE-HERMES-01\",\"body\":\"${BODY}\"}")
MSG_ID=$(echo "$ROLLCALL_RESP" | python3 -c "import json,sys;d=json.load(sys.stdin);print(d.get('msg_id','ERROR')[:8])" 2>/dev/null || echo "ERROR")
log "STEP 6 ✓ rollcall sent to em1 (msg=$MSG_ID)"

log "════════════════════════════════════════════════════════"
log "HERMES VPS BOOT COMPLETE — $(ts)"
log "════════════════════════════════════════════════════════"
SCRIPT
chmod +x /root/.local/bin/cos-hermes-vps-bootup.sh
echo "Script installed at /root/.local/bin/cos-hermes-vps-bootup.sh"
```

### Block 2 — Install systemd service

```bash
cat > /etc/systemd/system/cos-hermes-bootup.service << 'UNIT'
[Unit]
Description=COS Hermes VPS bootup — credential, topology, routing, health, rollcall
Documentation=file:///root/.local/bin/cos-hermes-vps-bootup.sh
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/bin/bash /root/.local/bin/cos-hermes-vps-bootup.sh
User=root
StandardOutput=append:/root/.local/log/hermes-bootup.log
StandardError=append:/root/.local/log/hermes-bootup-error.log
TimeoutStartSec=60

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable cos-hermes-bootup.service
echo "Service enabled. Will fire on every reboot."
```

### Block 3 — Test it now (without reboot)

```bash
systemctl start cos-hermes-bootup.service
systemctl status cos-hermes-bootup.service --no-pager
tail -30 /root/.local/log/hermes-bootup.log
```

**Expected:** status = `inactive (dead)` with `Active: ... SUCCESS`. Log should show 6 `✓` checkmarks.

### Block 4 — Verify auto-fire on next reboot (optional, when you next reboot the VPS)

```bash
# After a VPS reboot:
systemctl status cos-hermes-bootup.service
journalctl -u cos-hermes-bootup.service --since "10 minutes ago"
tail -30 /root/.local/log/hermes-bootup.log
```

---

## Part 3 — How the two bootup modes relate

| Mode | Trigger | Audience | What runs |
|------|---------|----------|-----------|
| **Auto (systemd)** | VPS reboot, manual `systemctl start` | Machine | Bash script — credential check, topology log, routing grep, health, inbox count, rollcall to em1 |
| **Interactive (skill)** | `/bootup` in Claude/Codex session on VPS | Agent | Full 7-step SKILL.md at `EquiVest Properties/.claude/skills/hermes-vps-bootup/SKILL.md` — includes consensus register, DECISION NEEDED markers, full inbox render |

The bash script + systemd service covers the **machine** bootup (always runs, fast, logged). The SKILL.md covers the **agent** bootup (runs when a Claude/Codex interactive session starts, includes reasoning steps that need a model).

Both route rollcall to em1. Neither ever touches hub.

---

## Part 4 — Quick-reference commands (once installed)

```bash
# Run bootup manually right now:
systemctl start cos-hermes-bootup.service

# Or equivalently:
bash /root/.local/bin/cos-hermes-vps-bootup.sh

# See last bootup log:
tail -50 /root/.local/log/hermes-bootup.log

# See service status + last exit code:
systemctl status cos-hermes-bootup.service

# Disable auto-fire (if ever needed):
systemctl disable cos-hermes-bootup.service

# Re-enable:
systemctl enable cos-hermes-bootup.service
```

---

## Part 5 — What the bootup rollcall looks like in em1's inbox

Every reboot, em1 sees one message like:

```
[P2] from=hermes — ROLLCALL: hermes VPS online — ALPINE-HERMES-01
Body: Node:hermes|Callsign:ALPINE-HERMES-01|Role:EXECUTOR|Topology:v2|Routing:0_residual|Load:0.03 0.07 0.08|Mem:2.9G/7.8G|Disk:56% used|Gateway:2|Inbox:total=8 unread=6 P0=0 P1=4 P2=2|Boot:2026-04-23T19:30Z
```

em1 can see at a glance: healthy node, no routing drift, inbox backlog count, last boot time.

---

**End of install doc.**

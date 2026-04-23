# j-spoke Rollcall — JNMBP Install Instructions

**Machine:** JNMBP (Justin's Nouveau MacBook Pro)  
**Node:** `j-spoke` | Callsign: `COS-JSPOKE-JNMBP-01`  
**Prepared by:** em1 | 2026-04-23  

Run these 4 blocks in Terminal on JNMBP. Each is copy-paste-ready.

---

## Block 1 — Create credentials file

```bash
mkdir -p ~/.config/cos-mesh
chmod 700 ~/.config/cos-mesh
cat > ~/.config/cos-mesh/j-spoke.env << 'EOF'
COS_MESH_NODE_ID=j-spoke
COS_MESH_URL=https://cos-mesh-v2.jkausel.workers.dev
COS_MESH_API_KEY=6075d82b-c183-4713-a711-37367b6d1e11
COS_MESH_CALLSIGN=COS-JSPOKE-JNMBP-01
EOF
chmod 600 ~/.config/cos-mesh/j-spoke.env
echo "Credentials written"
```

## Block 2 — Install rollcall script

```bash
mkdir -p ~/.local/bin ~/.local/log
cat > ~/.local/bin/cos-jspoke-rollcall.sh << 'SCRIPT'
#!/usr/bin/env bash
# cos-jspoke-rollcall.sh — COS J-Spoke (JNMBP) machine rollcall to CF mesh
set -euo pipefail

MESH_URL="https://cos-mesh-v2.jkausel.workers.dev"
ENV_FILE="${HOME}/.config/cos-mesh/j-spoke.env"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "ERROR: $ENV_FILE not found." >&2
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
SCRIPT
chmod +x ~/.local/bin/cos-jspoke-rollcall.sh
echo "Script installed"
```

## Block 3 — Install launchd agent (runs on every boot/login)

```bash
cat > ~/Library/LaunchAgents/co.cochalet.jspoke-rollcall.plist << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>co.cochalet.jspoke-rollcall</string>

    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>/Users/justinkausel/.local/bin/cos-jspoke-rollcall.sh</string>
    </array>

    <key>RunAtLoad</key>
    <true/>

    <key>StandardOutPath</key>
    <string>/Users/justinkausel/.local/log/cos-jspoke-rollcall.log</string>

    <key>StandardErrorPath</key>
    <string>/Users/justinkausel/.local/log/cos-jspoke-rollcall-error.log</string>

    <key>EnvironmentVariables</key>
    <dict>
        <key>HOME</key>
        <string>/Users/justinkausel</string>
        <key>PATH</key>
        <string>/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
    </dict>
</dict>
</plist>
PLIST
echo "LaunchAgent plist written"
```

## Block 4 — Load the agent and test it

```bash
# Load the launchd agent
launchctl load ~/Library/LaunchAgents/co.cochalet.jspoke-rollcall.plist

# Run it once manually to verify
bash ~/.local/bin/cos-jspoke-rollcall.sh

# Check the log
cat ~/.local/log/cos-jspoke-rollcall.log
```

**Expected output:** `ROLLCALL PENDING msg=XXXXXXXX`  
If you see `AUTH_INVALID`, let em1/PMBP know — the node may need re-registration.

---

## Verification

After running all 4 blocks, confirm to Justin/PMBP:
- `ROLLCALL PENDING` or `ROLLCALL DELIVERED` seen ✅  
- Log file exists at `~/.local/log/cos-jspoke-rollcall.log` ✅  
- LaunchAgent will fire automatically on every JNMBP boot from now on ✅  

Node `j-spoke` (COS-JSPOKE-JNMBP-01) is now fully enrolled in the COS mesh two-layer topology.

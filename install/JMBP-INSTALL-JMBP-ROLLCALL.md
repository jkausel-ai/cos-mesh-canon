# jmbp Rollcall — JMBP Install Instructions (Jesse's MacBook Pro)

**Machine:** JMBP (Jesse's MacBook Pro) — Nuovo Spoke  
**Node:** `jmbp` | Callsign: `EM2-JMBP-NUOVO-01`  
**Prepared by:** em1 | 2026-04-23  

Run these 4 blocks in Terminal on JMBP (Jesse's machine).

---

## Block 1 — Create credentials file

```bash
mkdir -p ~/.config/cos-mesh
chmod 700 ~/.config/cos-mesh
cat > ~/.config/cos-mesh/jmbp.env << 'EOF'
COS_MESH_NODE_ID=jmbp
COS_MESH_URL=https://cos-mesh-v2.jkausel.workers.dev
COS_MESH_API_KEY=6d325d8c-ad76-4bc6-b3c5-7138942330ad
COS_MESH_CALLSIGN=EM2-JMBP-NUOVO-01
EOF
chmod 600 ~/.config/cos-mesh/jmbp.env
echo "Credentials written"
```

## Block 2 — Install rollcall script

```bash
mkdir -p ~/.local/bin ~/.local/log
cat > ~/.local/bin/cos-jmbp-rollcall.sh << 'SCRIPT'
#!/usr/bin/env bash
# cos-jmbp-rollcall.sh — COS JMBP (Jesse's MacBook Pro) rollcall to CF mesh
set -euo pipefail

MESH_URL="https://cos-mesh-v2.jkausel.workers.dev"
ENV_FILE="${HOME}/.config/cos-mesh/jmbp.env"

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
SCRIPT
chmod +x ~/.local/bin/cos-jmbp-rollcall.sh
echo "Script installed"
```

## Block 3 — Install launchd agent (runs on every boot/login)

> **Note:** Replace `jesse` in `ProgramArguments` and log paths with the actual macOS username on this machine.

```bash
# Get your username first
echo "Your username is: $(whoami)"

# Install the plist (update USERNAME below if not 'jesse')
USERNAME=$(whoami)
cat > ~/Library/LaunchAgents/co.cochalet.jmbp-rollcall.plist << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>co.cochalet.jmbp-rollcall</string>

    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>/Users/${USERNAME}/.local/bin/cos-jmbp-rollcall.sh</string>
    </array>

    <key>RunAtLoad</key>
    <true/>

    <key>StandardOutPath</key>
    <string>/Users/${USERNAME}/.local/log/cos-jmbp-rollcall.log</string>

    <key>StandardErrorPath</key>
    <string>/Users/${USERNAME}/.local/log/cos-jmbp-rollcall-error.log</string>

    <key>EnvironmentVariables</key>
    <dict>
        <key>HOME</key>
        <string>/Users/${USERNAME}</string>
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
launchctl load ~/Library/LaunchAgents/co.cochalet.jmbp-rollcall.plist

# Run it once manually to verify
bash ~/.local/bin/cos-jmbp-rollcall.sh

# Check the log
cat ~/.local/log/cos-jmbp-rollcall.log
```

**Expected output:** `ROLLCALL PENDING msg=XXXXXXXX`  
If you see `AUTH_INVALID`, contact Justin — the node may need re-registration on PMBP.

---

## Also: Update the Bootup Skill credentials

The JMBP bootup skill (`.claude/skills/bootup/SKILL.md`) has been updated to use the new API key. When running `/bootup` on JMBP, Step 1 will now write the correct key. If Step 1 finds an existing `~/.claudeos/secrets/cos-mesh-credentials.json` with the old key (`78ba0ae4`), delete it first:

```bash
rm -f ~/.claudeos/secrets/cos-mesh-credentials.json
```

Then re-run `/bootup` — it will recreate the file with the correct key `6d325d8c`.

---

## Verification

After running all 4 blocks:
- `ROLLCALL PENDING` or `ROLLCALL DELIVERED` ✅
- Log at `~/.local/log/cos-jmbp-rollcall.log` ✅
- LaunchAgent fires on every JMBP boot from now on ✅
- Node `jmbp` (EM2-JMBP-NUOVO-01) enrolled in COS mesh two-layer topology ✅

---
name: bootdown
description: Close a COS Prime SPOKE session cleanly — canon flush, inbox sweep, heartbeat final-ping, open-thread capture, mesh sign-off, session-close markdown to ~/.claudeos/bootdowns/. Symmetric counterpart to /bootup. Run as the LAST thing each session, before terminal close.
when-to-use: |
  - User says "bootdown", "sign off", "close session", "wrap up", "end of day", "EOD"
  - Session is wrapping and there are decisions/findings/open threads that need to persist across sessions
  - Context pressure > 80% and a clean handoff is preferred over compaction loss
  - Before switching nodes (pmbp → jnmbp) or before a long idle window
  - After a /sdd-auto run completes and the session has no remaining work
---

# Bootdown Skill

**Part of:** ClaudeOS v5 — COS Prime client projects
**Version:** 1.0.0
**Last Updated:** 2026-04-17
**Lineage:** Ported from `hooks-v4.1/cortex-bootdown.sh` (Leap #4 Persistent Session Brain). v5 modernization swaps `cortex.db` → `hermes_memory.db` + PARA daily notes.

---

## Purpose

`/bootdown` is the symmetric close to `/bootup`. Where `/bootup` verifies identity, logs into the mesh, runs AKU preflight, anchors a UHDD callsign, and handshakes into MASTERCLASS mode — `/bootdown` reverses each step: flushes canon, sweeps the inbox, pings a final heartbeat, captures open threads, signs off the mesh, and writes a resumable session-close markdown.

Output is a single file at `~/.claudeos/bootdowns/bootdown-<YYYY-MM-DD>-<topic>.md` (hardlinked to `~/.claudeos/session-comms/latest-bootdown.md`) so the next session can resume in one read.

**Key principle:** Every open thread must land on disk before the terminal closes. Compaction destroys return values. Bootdown is the durability layer.

---

## Invocation

**Primary:**
- `/bootdown [topic]` — close the current session with an optional topic slug (default: `session`)
- `/bootdown eod` — end-of-day convenience alias
- Natural: "bootdown", "sign off", "wrap up this session"

**Auto-triggers (advisory only — still requires user confirm):**
- Session guardian hits Red zone (>85% context)
- User fires `/check-inbox` and queue is empty at end of session
- `/sdd-auto` reports PROMOTE phase complete with no follow-on work

---

## Inputs / Args

| Arg | Required | Default | Notes |
|-----|----------|---------|-------|
| `topic` | no | `session` | Freeform string, slugified to `[a-z0-9_]`. Keeps filename scannable. |
| `--node` | no | `$HOSTNAME` | Override for cross-node bootdown (pmbp/jnmbp/hermes). |
| `--client` | no | `$CLAUDEOS_BUSINESS_ID` | Client scope (one of 9 COS Prime clients). |
| `--skip-mesh` | no | false | Skip mesh sign-off (offline mode). |

**Env expected:** `CLAUDEOS_BUSINESS_ID`, `HOME`, `HOSTNAME`. Writes under `$HOME/.claudeos/`.

---

## Outputs Contract

**Primary artifact:** `~/.claudeos/bootdowns/bootdown-<date>-<topic>.md`

**Required sections (order matters — mirrors /bootup reverse):**
1. Header — generated timestamp, session_id, node_id, client_id, duration
2. Session Metrics — events, files touched, decisions, findings, skills used
3. Decisions Made
4. Key Findings
5. Open Threads (Resume These) — explicit continuation points
6. User Directives (Active) — last 10, session-scoped + 7d recent
7. Files Modified (unique)
8. Skills Used
9. Cross-Session Context (48h, other sessions)
10. Canon State — hermes_memory.db totals (tier/thesis_version breakdown)
11. Mesh Sign-Off — final heartbeat + ack confirmations
12. Resume Instructions — one-read recovery path for next session

**Hardlink:** Duplicate at `~/.claudeos/session-comms/latest-bootdown.md` for `/bootup` discovery.

**Stdout:** One-line summary: `Bootdown written: <path> | Events:N Decisions:N Findings:N Threads:N`

---

## Protocol (Step-by-Step)

Each step is the reverse of a `/bootup` step.

### Step 1 — Canon Flush (reverses bootup: canon load)
- Query `hermes_memory.db` for any facts created/modified this session with `status='pending'` or missing `tier`.
- If found: print count, AskUserQuestion to promote or drop. Do NOT auto-promote.
- Snapshot current canon totals: `SELECT COUNT(*), tier, thesis_version FROM facts GROUP BY tier, thesis_version;`
- Write snapshot to bootdown header.

### Step 2 — Inbox Sweep (reverses bootup: inbox check)
- Call `/check-inbox` programmatically (or re-invoke skill). Capture unread P0/P1/P2 counts.
- Flag any CMD22 violations (unacked >24h) as open threads.
- Do NOT auto-ack. Unread P0s block sign-off — surface to user first.

### Step 3 — Session Teardown Ping (Mesh Topology v2 — em1 node)

Load em1 credentials and send session teardown to `hermes`. Use `msg_type: status` — the only valid types on this Worker are: `directive`, `result`, `handshake`, `ack`, `question`, `status`, `blocked`, `consensus_req`, `consensus_vote`, `heartbeat`, `recover`.

```bash
source ~/.config/cos-mesh/em1.env

TEARDOWN_TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
SESSION_UDD="${SESSION_UDD:-ALPINE-EM1-PMBP-$(date -u +%Y%m%d)-A}"
BOOTDOWN_PATH="$HOME/.claudeos/bootdowns/bootdown-$(date -u +%Y-%m-%d)-${1:-session}.md"

curl -s -X POST "https://cos-mesh-v2.jkausel.workers.dev/msg" \
  -H "Content-Type: application/json" \
  -H "X-API-Key: ${COS_MESH_API_KEY}" \
  -d "{
    \"to_node\": \"hermes\",
    \"msg_type\": \"status\",
    \"priority\": \"P2\",
    \"subject\": \"TEARDOWN: em1 session close — UDD: ${SESSION_UDD}\",
    \"body\": \"Agent: em1 | Role: CONDUCTOR | UDD: ${SESSION_UDD} | Host: hub (PMBP) | Closed: ${TEARDOWN_TS} | Bootdown: ${BOOTDOWN_PATH}\"
  }"
```

- If mesh unreachable: mark `mesh_sync=stale` in bootdown, continue.
- **Canon:** `/msg` is the single mesh route. `msg_type` must be one of the valid types above. Never use `type:session_close` — that field doesn't exist on the v2 Worker.

### Step 4 — Open-Thread Capture (reverses bootup: session handshake)
- Scan this session's transcript for: unresolved TODOs, AskUserQuestion with no user response, partial agent outputs, dispatched-but-unreported swarm tasks.
- For each, write one line under "Open Threads": `- [domain] <one-sentence continuation prompt>`
- Also pull from `hermes_memory.db` where `event_type='open_thread' AND session_id=<current>`.

### Step 5 — PARA Daily Note Append (v5 addition — no v4.1 equivalent)
- Append a dated bullet to today's PARA daily note under `Projects/EquiVest/daily/<date>.md`:
  - `- [HH:MM] Session close: <topic> — <decisions_count> decisions, <threads_count> open threads. See bootdown-<date>-<topic>.md`
- If daily note doesn't exist, create from skeleton. Never overwrite existing bullets.

### Step 6 — Mesh Sign-Off (reverses bootup: UHDD callsign anchor)
- Send structured sign-off message via `POST /msg` with `type=session_signoff`:
  ```json
  {
    "type": "session_signoff",
    "from": "<node_id>",
    "callsign": "<session_callsign>",
    "session_id": "<session_id>",
    "uhdd_release": true,
    "summary": "<one-line session summary>",
    "bootdown_path": "~/.claudeos/bootdowns/bootdown-<date>-<topic>.md"
  }
  ```
- Retire the session callsign (release UHDD lease — server-side on ack).
- If `--skip-mesh` or mesh unreachable: log `mesh_signoff=skipped`, proceed.
- **Audit trail:** All sign-offs land in mesh inbox — queryable via `/check-inbox --type=session_signoff --window=7d` for fleet health checks.

### Step 7 — Write Bootdown Markdown
- Render full document per "Outputs Contract" above.
- Write to `~/.claudeos/bootdowns/bootdown-<date>-<topic>.md`.
- Hardlink (or copy) to `~/.claudeos/session-comms/latest-bootdown.md`.
- Print one-line stdout summary.

### Step 8 — Optional: TG OPS Notification
- If `TG_OPS_BOT_TOKEN` env var set: POST one-line summary to OPS channel.
- Silent fail — do not block sign-off on telegram reachability.

---

## Example Output Skeleton

```markdown
# Bootdown: hermes-v2-alignment-deploy
**Generated:** 2026-04-17 18:42:11
**Session:** sess_20260417_093014
**Node:** pmbp | **Client:** cochalet
**Duration:** 9h 12m

---

## Session Metrics
| Metric | Value |
|--------|-------|
| Total events | 247 |
| Files modified | 18 |
| Decisions made | 11 |
| Findings captured | 23 |
| Skills used | 7 |

## Decisions Made
- Promote 5 V2 skills to ACTIVE (skill-router v2.3.0)
- Hold deploy lock until fresh Opus session

## Key Findings
- Regression suite needs 30-50 gold traces before DP5 blocking
- model_router.py only clean copy was the fork

## Open Threads (Resume These)
- [fork] Push feat/hermes-agent-maturity to main — needs GitHub Secrets first
- [canon] 3 facts pending tier assignment in hermes_memory.db
- [mesh] CMD22 violation: msg_id=abc123 unacked since 2026-04-16T08:12

## User Directives (Active)
- Four Nevers enforcement on all public copy
- No VPS direct edits — route via CI/CD

## Canon State (hermes_memory.db)
| Tier | V1 | V2 | Evergreen |
|------|-----|-----|-----------|
| canon | 12 | 32 | 27 |
| draft | 3 | 8 | 0 |

## Mesh Sign-Off
- Final heartbeat ack: 2026-04-17T18:42:09Z (node=pmbp)
- Callsign retired: COS-HUB-PMBP-0417A
- mesh_sync: ok

## Resume Instructions
1. Read this file first
2. CLAUDE.md auto-loads via system-reminder
3. Check Open Threads — pick one, run `/bootup [topic]`
4. Run `/status` for full fleet state
```

---

## Failure Modes

| Failure | Behavior |
|---------|----------|
| `hermes_memory.db` missing/locked | Log warning, write bootdown with `canon_state=unavailable`. Do not block. |
| Mesh unreachable | Mark `mesh_sync=stale`, continue. User sees warning in stdout. |
| Unread P0 in inbox | Pause at Step 2. AskUserQuestion to ack/triage before continuing. |
| Disk write fails | Fall back to `/tmp/bootdown-<date>.md`, print path, exit 1. |
| Hardlink fails | Copy instead. Log which was used. |
| Transcript scan empty | Still write file with `open_threads: none captured`. Not an error. |

---

## Integration Points

- **/bootup** — reads `~/.claudeos/session-comms/latest-bootdown.md` on start. Bootdown MUST write this path.
- **/check-inbox** — called in Step 2. Read-only, no state change.
- **/sdd-auto** — if last command was `/sdd-auto` with PROMOTE complete, bootdown auto-includes the promotion summary.
- **para-memory-files** — Step 5 appends to PARA daily note. Uses the skill's conventions for path/format.
- **hermes_memory.db** — read-only queries only. No writes. No migrations.

---

## Canon Compliance

- Never use "timeshare" in any output or prompt
- Never lead with price
- Never say "Engine Room"
- Never expose DSCR/NOI jargon in user-facing summaries (internal metrics section is fine)
- Fleet references use "COS Prime client projects" — never "CoChalet client projects"

---

## Maintenance

- **Weekly:** Verify bootdown files are being written (no silent failures)
- **Monthly:** Review open-thread capture accuracy — are we missing patterns?
- **Quarterly:** Re-sync with `/bootup` if bootup's protocol changes
- **Per-client:** Verify `CLAUDEOS_BUSINESS_ID` scoping works for all 9 clients

---

**End of Bootdown Skill Documentation**

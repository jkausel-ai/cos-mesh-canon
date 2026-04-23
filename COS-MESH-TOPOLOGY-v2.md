# COS Mesh Network Topology v2.0 — MASTER REGISTRY
**Status:** PRODUCTION (promoted 2026-04-23T21:00Z)  
**Node count:** 12 (11 ACTIVE + 1 DEPRECATED)  
**Date:** 2026-04-23 (updated as nodes register)  
**Author:** em1 / COS Prime CONDUCTOR  
**Supersedes:** SDD `docs/plans/2026-04-10-mesh-coordination-protocol-sdd.md` (architecture sections)  
**Worker:** `https://cos-mesh-v2.jkausel.workers.dev`  
**Bootstrap key:** stored in `/root/.claudeos/secrets/cos-mesh-bootstrap-key` (Hermes VPS only)

## ⚠️ ALWAYS CONSULT THIS FILE for node identity + routing, NOT the `/nodes` endpoint status field.
- `/nodes` status=DEAD/STALE means "no heartbeat daemon running" — does NOT mean unreachable.
- All 11 registered nodes accept `/msg` POST regardless of status.
- Session agents (em1, cmo, jmbp, jnmbp, codex-*) show DEAD/STALE as default between sessions — that's correct.
- Only persistent daemons show ACTIVE (hermes gateway, macmini cron).

## Nuovo peer routing (jmbp, jnmbp)
Nuovo spokes talk to: **em1 (CONDUCTOR), hermes (EXECUTOR), cmo (when CMO work)**. 
Nuovo spokes do NOT talk to: macmini (CoChalet infra), hub (machine node), other Nuovo (cross-peer). 
All outbound mesh from Nuovo → em1 (default) unless explicitly directed.

---

## 1. TWO-LAYER ARCHITECTURE

The COS mesh has two distinct layers. Every entity registers a node. Every node has a UDD callsign.

```
LAYER 1 — MACHINES (physical hosts, persistent, server-role)
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│    hub      │    │  macmini    │    │  j-spoke    │
│  PMBP host  │    │ Mac Mini    │    │ JNMBP (Nuovo)  │
│ COS-HUB-    │    │ GRANITE-    │    │ COS-JSPOKE- │
│  PMBP-01    │    │  CORE-12    │    │  JNMBP-01   │
└──────┬──────┘    └──────┬──────┘    └──────┬──────┘
       │                  │                  │
LAYER 2 — AGENTS (sessions/processes running ON machines, spoke-role)
       │                  │                  │
   ┌───┴────────┐    ┌────┴───┐         (future)
   │  em1       │    │hermes  │
   │  cmo       │    │VPS     │
   │  codex-    │    └────────┘
   │  hermes-   │
   │  oncall    │
   │  codex-    │
   │  cochalet- │
   │  app       │
   └────────────┘
```

---

## 2. NODE REGISTRY (complete, as of 2026-04-23)

### Layer 1: Machine Nodes

| node_id | Callsign | Host | Role | Status | Notes |
|---------|----------|------|------|--------|-------|
| `hub` | `COS-HUB-PMBP-01` | PMBP (Personal MacBook Pro) | hub | REGISTERED | Heartbeat: send on machine boot / launchd |
| `macmini` | `GRANITE-CORE-12` | Mac Mini | server | **ACTIVE** ✅ | Heartbeat every ~5min from daemon |
| `jnmbp` | `EM1-JSPOKE-JNMBP-01` | JNMBP (Justin's Nouveau MacBook Pro) | spoke | REGISTERED | Single node for machine rollcall + agent sessions (CODEX dev, Claude Code); key ..b2d66a |
| `jmbp` | `EM2-JMBP-NUOVO-01` | JMBP (Jesse's MacBook Pro) | spoke | REGISTERED | Single node for machine + agent sessions (Nuovo Spoke); key ..3330ad |
| ~~`j-spoke`~~ | ~~`COS-JSPOKE-JNMBP-01`~~ | ~~JNMBP~~ | ~~server~~ | **DEPRECATED** — consolidated into `jnmbp` on 2026-04-23. Do not use. |

### Layer 2: Agent Nodes

| node_id | Callsign | Host | Agent Type | Authority | Status | Notes |
|---------|----------|------|-----------|-----------|--------|-------|
| `hermes` | `ALPINE-HERMES-01` | VPS | Hermes pipeline | EXECUTOR | **ACTIVE** ✅ | Heartbeat from cron |
| `codex-hermes-oncall` | `CODEX-HERMES-ONCALL-01` | PMBP (CODEX) | CODEX | BUILDER | **ACTIVE** ✅ | Heartbeat from launchd |
| `em1` | `ALPINE-EM1-01` | PMBP | Claude Code | CONDUCTOR | REGISTERED | Heartbeat: session boot/teardown |
| `cmo` | `ALPINE-CMO-01` | PMBP | Claude Code | CMO | REGISTERED | Heartbeat: session boot/teardown |
| `codex-cochalet-app` | `CODEX-COCHALET-APP-01` | PMBP (CODEX GPT 5.5) | CODEX | app-layer BUILDER | REGISTERED | Heartbeat: TBD |
| `codex-local` | `CODEX-LOCAL-PMBP-01` | PMBP (Claude Code) | Claude Code | local BUILDER | REGISTERED | Claude Code session, CoChalet COS scope; key ..494415 |
| `sevp-jspoke` | `SEVP-JSPOKE-JNMBP-01` | JNMBP | Sales Executive VP persona | MAOS desk operator | REGISTERED | Drives MAOS Sales Enablement desk (first agentized per CMO). Persona agent, not sub-process. Key ..bb8f9c8c |

> **Note:** `jnmbp` and `jmbp` are listed under Layer 1 Machines. They double as agent-session identities — one node per machine for Nuovo spokes (unlike PMBP which hosts multiple distinct agents em1/cmo/codex-*).

---

## 3. AUTHORITY HIERARCHY (from SDD v1.0, unchanged)

| Priority | Role | Nodes | Authority |
|----------|------|-------|-----------|
| 0 | **HUMAN** | Justin | Overrides everything |
| 1 | **CONDUCTOR** | `em1` (active session) | Final agent authority. Breaks ties. |
| 2 | **EXECUTOR** | `hermes` | Production authority. Owns running pipeline. |
| 3 | **BUILDER** | `codex-hermes-oncall`, `codex-cochalet-app` | Build/code authority. |
| 4 | **CMO** | `cmo` | Marketing authority. Approvals lane. |
| — | **INFRA** | `hub`, `macmini`, `j-spoke` | No authority. Relay + host services only. |

---

## 4. UDD ROLLCALL PROTOCOL

Every entity — machine AND agent — MUST perform a rollcall on activation.

### 4.1 Machine Rollcall (on boot)

When a machine starts (boot, restart, wake from sleep):

```bash
# Send rollcall to mesh
curl -s -X POST "https://cos-mesh-v2.jkausel.workers.dev/msg" \
  -H "Content-Type: application/json" \
  -H "X-API-Key: <machine-api-key>" \
  -d '{
    "to_node": "em1",
    "msg_type": "status",
    "priority": "P2",
    "subject": "ROLLCALL: <node_id> online — <callsign>",
    "body": "Machine: <node_id> | Host: <hostname> | Callsign: <callsign> | Boot time: <ISO timestamp> | Agents active: [list]"
  }'
```

**Frequency:** on boot only. Machines do NOT send continuous heartbeats (that's for agent daemons).

### 4.2 Agent Session Rollcall (on session start)

When a Claude Code or CODEX session starts:

```bash
# Step 1: Send rollcall
curl -s -X POST "https://cos-mesh-v2.jkausel.workers.dev/msg" \
  -H "Content-Type: application/json" \
  -H "X-API-Key: <agent-api-key>" \
  -d '{
    "to_node": "em1",
    "msg_type": "handshake",
    "priority": "P2",
    "subject": "ROLLCALL: <node_id> session open — UDD: <session-callsign>",
    "body": "Agent: <node_id> | Role: <role> | UDD: <session-callsign> | Host: <machine-node-id> | Session: <session_id> | Started: <ISO timestamp>"
  }'
```

**Session callsign format:** `<BASE-CALLSIGN>-<YYYYMMDD>-<session-suffix>`  
Example: `ALPINE-CMO-PMBP-20260423-A`

### 4.3 Agent Session Teardown

When a Claude Code or CODEX session ends (or `/bootdown` is called):

```bash
curl -s -X POST "https://cos-mesh-v2.jkausel.workers.dev/msg" \
  -H "Content-Type: application/json" \
  -H "X-API-Key: <agent-api-key>" \
  -d '{
    "to_node": "em1",
    "msg_type": "status",
    "priority": "P2",
    "subject": "TEARDOWN: <node_id> session close — UDD: <session-callsign>",
    "body": "Agent: <node_id> | UDD: <session-callsign> | Closed: <ISO timestamp> | Open threads: <N>"
  }'
```

### 4.4 Persistent Daemon Heartbeat (hermes, macmini, codex-hermes-oncall)

Daemons that run continuously send heartbeats on their own schedule:
- `hermes`: every 5 minutes (cron)
- `macmini`: ~5 minutes (existing daemon)
- `codex-hermes-oncall`: every 15 minutes (launchd proxy)

---

## 5. CREDENTIAL REGISTRY

### On Hermes VPS (`/root/.claudeos/secrets/`)

| File | node_id | Key (last 8) |
|------|---------|-------------|
| `cos-mesh-credentials.json` | `hermes` | `..cde1d1` |
| `cos-mesh-cmo-credentials.json` | `cmo` | `..07a63` |
| `cos-mesh-hub-credentials.json` | `hub` | `..385f9f` |
| `cos-mesh-em1-credentials.json` | `em1` | `..cc901` |
| `cos-mesh-codex-hermes-oncall.json` | `codex-hermes-oncall` | `..81e19` |
| `cos-mesh-codex-cochalet-app.json` | `codex-cochalet-app` | `..bdc4` ← **UPDATE NEEDED** |
| `cos-mesh-j-spoke-credentials.json` | `j-spoke` | `..367b6d` ← **CREATE NEEDED** |
| `cos-mesh-bootstrap-key` | n/a | bootstrap key |

### On PMBP / Local (`~/.config/codex-hermes-oncall/mesh.env`)

```
COS_MESH_NODE_ID=codex-hermes-oncall
COS_MESH_URL=https://cos-mesh-v2.jkausel.workers.dev
COS_MESH_API_KEY=ebadf7b2-99f7-43f2-862a-471a0fe81e19
```

Additional files needed on PMBP for other agents (stored securely, 0600):
- `~/.config/cos-mesh/em1.env` — em1 credentials
- `~/.config/cos-mesh/cmo.env` — cmo credentials
- `~/.config/cos-mesh/hub.env` — hub machine credentials
- `~/.config/cos-mesh/j-spoke.env` — j-spoke machine credentials (for JNMBP)

### On JNMBP (j-spoke)

- `~/.config/cos-mesh/j-spoke.env` — j-spoke machine credentials

---

## 6. ROUTING RULES

| From → To | Allowed | Path | Notes |
|-----------|---------|------|-------|
| Any agent → `hermes` | ✅ | Direct | Primary reporting channel |
| `hermes` → any agent | ✅ | Direct | Dispatcher |
| `em1` → any | ✅ | Direct | CONDUCTOR authority |
| `cmo` → `hermes` | ✅ | Direct | CMO approvals |
| `codex-hermes-oncall` → any | ✅ | Direct | oncall reporting |
| Machine → `hermes` | ✅ | Direct | Rollcall only |
| Machine → Machine | ⚠️ | Avoid | No machine-to-machine messaging |
| Any → `macmini` | ⚠️ | Via hermes | macmini is a relay, not a decision node |

---

## 7. GAPS NOT YET IMPLEMENTED (from SDD v1.0)

These are designed but not built. P1 backlog:

| Gap | Priority | Owner | ETA |
|-----|----------|-------|-----|
| Heartbeat daemon for `hub` machine (launchd on PMBP boot) | P1 | OPS | next session |
| Heartbeat daemon for `j-spoke` machine (launchd on JNMBP boot) | P1 | OPS | next session |
| Session rollcall in `/bootup` skill (Claude Code agents) | P1 | EM1 | next session |
| Session teardown in `/bootdown` skill (Claude Code agents) | P1 | EM1 | next session |
| ACK demand / TTL enforcement (`mesh-demand-reply.py`) | P2 | CODEX | later |
| Consensus protocol (`mesh-consensus.py`) | P2 | CODEX | later |
| Link recovery (`mesh-recovery.py`) | P2 | HERMES | later |
| `/hb` heartbeat endpoint separate from `/msg` inbox | P2 | infra | later |

---

## 8. VERIFICATION CHECKLIST

Run before PRODUCTION promotion:

- [ ] `/nodes` returns 8 nodes (3 machine + 5 agent)
- [ ] `hub`, `macmini`, `j-spoke` all visible as infrastructure layer
- [ ] `hermes`, `codex-hermes-oncall`, `em1`, `cmo`, `codex-cochalet-app` as agent layer
- [ ] Direct send test: `codex-hermes-oncall` → `cmo` → DELIVERED
- [ ] Direct send test: `hermes` → `em1` → DELIVERED
- [ ] Direct send test: `cmo` → `hermes` → DELIVERED
- [ ] All credential files updated on Hermes VPS
- [ ] New j-spoke and codex-cochalet-app keys stored securely
- [ ] MEMORY.md updated with new key fingerprints

---

*STAGING — DO NOT USE IN PRODUCTION UNTIL VERIFY PASSES*  
*Promote by removing -STAGING from filename and updating org_chart_bootups.md*

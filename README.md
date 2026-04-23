# cos-mesh-canon

**Canonical source of truth for the COS Prime mesh: topology, node registry, bootup protocols, and routing rules.**

- **Worker (mesh endpoint):** `https://cos-mesh-v2.jkausel.workers.dev`
- **Authority:** `em1` (CONDUCTOR) + Justin (HUMAN override)
- **Canon source (this repo):** `https://raw.githubusercontent.com/jkausel-ai/cos-mesh-canon/main/`

---

## Why this repo exists

The COS Prime mesh is a multi-machine, multi-agent coordination system. Before this repo, the topology doc + bootup skills lived only on one user's OneDrive. Machines without OneDrive mount (future minimal VMs, contributors) couldn't access the canon.

This repo gives every node an **unauthenticated HTTPS read** of the master registry and bootup protocols, plus a **machine-readable `nodes.json`** sidecar so scripts don't have to parse Markdown.

---

## Repo layout

```
cos-mesh-canon/
├── COS-MESH-TOPOLOGY-v2.md         Master registry (human-readable, canon)
├── nodes.json                      Machine-readable node registry sidecar
├── CHANGELOG.md                    Version history
├── README.md                       This file
│
├── skills/                         Agent-session bootup skills (Claude Code / CODEX)
│   ├── bootup/SKILL.md                   Nuovo spoke bootup (JMBP, JNMBP)
│   ├── hermes-vps-bootup/SKILL.md        Headless VPS bootup (Hermes)
│   └── bootdown/SKILL.md                 Session close protocol
│
├── scripts/                        Headless bootup + rollcall scripts
│   ├── cos-hermes-vps-bootup.sh          Hermes VPS automated bootup (systemd)
│   ├── cos-hermes-bootup.service         systemd oneshot unit
│   ├── cos-hub-rollcall.sh               PMBP machine rollcall (launchd)
│   ├── cos-jmbp-rollcall.sh              JMBP machine rollcall (launchd)
│   └── cos-jspoke-rollcall.sh            JNMBP legacy (deprecated — use jnmbp-rollcall)
│
└── install/                        Machine-specific install guides
    ├── HERMES-VPS-BOOTUP-INSTALL.md
    ├── JMBP-INSTALL-JMBP-ROLLCALL.md
    └── JNMBP-INSTALL-JSPOKE-ROLLCALL.md
```

---

## "I'm a new node, what do I do?"

1. **Identify your node type:**
   - Nuovo spoke (agent session on JMBP/JNMBP) → use `skills/bootup/SKILL.md`
   - Hermes VPS (headless Linux executor) → use `skills/hermes-vps-bootup/SKILL.md`
   - PMBP machine (launchd rollcall) → use `scripts/cos-hub-rollcall.sh` + the matching install doc
   - Other PMBP agent (Claude Code, CODEX) → get credentials from `em1` via Justin, use the canonical API structure

2. **Pull canon on every bootup:**
   ```bash
   curl -sS https://raw.githubusercontent.com/jkausel-ai/cos-mesh-canon/main/nodes.json \
     > /tmp/cos-mesh-nodes.json
   # assert your node_id is in the registry
   python3 -c "import json,sys; d=json.load(open('/tmp/cos-mesh-nodes.json')); \
     print('OK' if any(n['node_id']=='<YOUR_NODE_ID>' for n in d['nodes']) else 'MISSING')"
   ```

3. **Know your routing:**
   - Agent status / heartbeat / consensus → `em1`
   - Marketing approvals → `cmo`
   - Build / infra work → `codex-hermes-oncall`
   - Machine-to-machine: **FORBIDDEN** — route via `em1`
   - Nuovo spokes (`jmbp`, `jnmbp`) MUST NOT route to `macmini` (CoChalet infra, not your domain)

---

## `nodes.json` — machine-readable schema

```json
{
  "schema_version": "cos-mesh-canon.v1",
  "generated_at": "2026-04-23T...Z",
  "worker_url": "https://cos-mesh-v2.jkausel.workers.dev",
  "authority_hierarchy": [ ... ],
  "routing_canon": { ... },
  "total_nodes": 11,
  "active_nodes": ["em1", "hermes", ...],
  "nodes": [
    {
      "node_id": "em1",
      "callsign": "ALPINE-EM1-01",
      "role": "spoke",
      "layer": "Layer 2",
      "authority": "CONDUCTOR",
      "deprecated": false,
      "mesh_status": "DEAD",
      "registered_at": "2026-04-22T...Z",
      "last_hb": null,
      "notes": null
    }
  ]
}
```

**Important:** `mesh_status: "DEAD"` does NOT mean unreachable. It means "no heartbeat daemon running". Session agents (`em1`, `cmo`, `jmbp`, `jnmbp`, `codex-*`) show DEAD/STALE as default between sessions — that's correct. The `/msg` endpoint accepts POSTs to any registered node regardless of status.

---

## Who can edit this repo?

- **em1 (CONDUCTOR)** — topology changes, node registrations, routing rules
- **Justin (HUMAN)** — overrides, final authority
- **Other agents** — propose via PR; em1 approves

All commits reference a mesh decision msg_id where applicable.

---

## Refreshing canon on a live node

Nodes should pull canon on every bootup (per their bootup skill/script). Persistent daemons (Hermes VPS) should refresh hourly via cron.

```bash
# Example: refresh canon on Hermes VPS
cd /root/cos-mesh-canon && git pull --ff-only origin main
```

If a node's local canon disagrees with remote canon, the node must STOP and alert em1 — never run with stale topology under version mismatch.

---

## Version pinning

Node bootup scripts MAY pin a specific canon version via git tag:

```bash
git clone --branch v1.0 https://github.com/jkausel-ai/cos-mesh-canon /root/cos-mesh-canon
```

Tag cadence: patch on node changes, minor on routing changes, major on architecture changes (e.g., adding a third layer).

---

## Authority hierarchy (summary)

```
0. HUMAN (Justin)         — Overrides everything
1. CONDUCTOR (em1)        — Consensus coordinator, breaks ties
2. EXECUTOR (hermes)      — Production authority, owns pipeline
3. BUILDER (codex-*)      — Build/code authority
4. CMO (cmo)              — Marketing approvals
99. INFRA (hub, macmini, j-spoke, jmbp, jnmbp) — Host services, no authority
```

Full detail in `COS-MESH-TOPOLOGY-v2.md`.

---

## License

Internal — COS Prime client projects. Public for canonical read access; no commercial use.

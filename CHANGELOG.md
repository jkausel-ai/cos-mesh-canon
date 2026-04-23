# Changelog

All notable changes to the COS Prime mesh canon. Follows [semver](https://semver.org/).

## [1.0.0] — 2026-04-23 — Initial publish

### Added
- `COS-MESH-TOPOLOGY-v2.md` master registry (PRODUCTION status)
- `nodes.json` machine-readable sidecar (schema v1)
- `README.md` entry point + new-node onboarding guide
- `skills/bootup/SKILL.md` — Nuovo spoke bootup protocol (JMBP/JNMBP)
- `skills/hermes-vps-bootup/SKILL.md` — Headless VPS bootup (7-step protocol with topology v2 assertion + routing sanity grep)
- `skills/bootdown/SKILL.md` — Session close protocol
- `scripts/cos-hermes-vps-bootup.sh` — Round 4 tested (all 6 steps clean, rollcall msg `02cf1deb`)
- `scripts/cos-hermes-bootup.service` — systemd oneshot unit
- `scripts/cos-hub-rollcall.sh` — PMBP machine rollcall (launchd)
- `scripts/cos-jmbp-rollcall.sh` — JMBP machine rollcall
- `scripts/cos-jspoke-rollcall.sh` — JNMBP legacy (deprecated marker)
- `install/HERMES-VPS-BOOTUP-INSTALL.md` — 4-block install guide
- `install/JMBP-INSTALL-JMBP-ROLLCALL.md` — Jesse's MBP install
- `install/JNMBP-INSTALL-JSPOKE-ROLLCALL.md` — Justin's Nouveau MBP install

### Node registry at publish
- **11 total nodes** (10 active, 1 deprecated)
- **Layer 1 Nuovo spokes:** `jmbp` (Jesse MBP), `jnmbp` (Justin Nouveau MBP)
- **Layer 1 INFRA:** `hub` (PMBP machine), `macmini` (Mac Mini)
- **Layer 1 DEPRECATED:** `j-spoke` (consolidated into `jnmbp` 2026-04-23)
- **Layer 2 Agents:** `em1` (CONDUCTOR), `hermes` (EXECUTOR), `cmo`, `codex-hermes-oncall` (BUILDER), `codex-cochalet-app` (BUILDER), `codex-local` (BUILDER)

### Canon clarifications codified
- `mesh_status: DEAD/STALE` ≠ unreachable. It means "no heartbeat daemon running". Session agents show DEAD by default.
- All registered nodes accept `/msg` POST regardless of mesh_status.
- Nuovo spokes MUST NOT route to `macmini` (CoChalet infra, cross-domain).
- One-node-per-machine rule applies to Nuovo spokes only. PMBP (HUB) hosts multiple distinct agents.
- Machine-to-machine messaging is FORBIDDEN — route via `em1`.

### Routing corrections applied today
- Hermes VPS code patched to route `status/startup/heartbeat` reports to `em1`, not `hub` (6 files across CODEX Hermes session)
- Hub inbox cleared of 991 stale messages (ACK loop)
- `codex-local` node registered for Claude Code CODEX session on PMBP
- `jnmbp` re-registered (prior archive) with fresh key after 8-day gap

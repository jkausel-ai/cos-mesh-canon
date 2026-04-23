# Changelog

All notable changes to the COS Prime mesh canon. Follows [semver](https://semver.org/).

## [1.1.0] — 2026-04-23

### Added
- **STEP 1.5: Canon refresh** added to all bootup skills (Nuovo bootup, Hermes VPS bootup). On every boot, pull fresh `nodes.json` from GitHub and verify own node_id is in the registry.
- **`scripts/cos-canon-refresh.sh`** — Hourly refresh script for persistent nodes (Hermes VPS). Pulls latest nodes.json + topology, logs drift.

### Changed
- `scripts/cos-hermes-vps-bootup.sh` — Added STEP 1.5 canon refresh block (between auth check and topology assertion)
- `skills/bootup/SKILL.md` — Added STEP 1.5 canon refresh instructions
- `skills/hermes-vps-bootup/SKILL.md` — Added STEP 1.5 + updated topology reference from OneDrive path to GitHub URL

## [1.0.0] — 2026-04-23 — Initial publish

### Added
- `COS-MESH-TOPOLOGY-v2.md` master registry (PRODUCTION status)
- `nodes.json` machine-readable sidecar (schema v1)
- `README.md` entry point + new-node onboarding guide
- `skills/bootup/SKILL.md` — Nuovo spoke bootup protocol (JMBP/JNMBP)
- `skills/hermes-vps-bootup/SKILL.md` — Headless VPS bootup (7-step protocol)
- `skills/bootdown/SKILL.md` — Session close protocol
- `scripts/cos-hermes-vps-bootup.sh` — Round 4 tested
- `scripts/cos-hermes-bootup.service` — systemd oneshot unit
- `scripts/cos-hub-rollcall.sh`, `cos-jmbp-rollcall.sh`, `cos-jspoke-rollcall.sh`
- `install/HERMES-VPS-BOOTUP-INSTALL.md`, `JMBP-INSTALL-JMBP-ROLLCALL.md`, `JNMBP-INSTALL-JSPOKE-ROLLCALL.md`

### Node registry at v1.0.0 publish
- 11 total nodes (10 active, 1 deprecated: `j-spoke`)

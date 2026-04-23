# Changelog

All notable changes to the COS Prime mesh canon. Follows [semver](https://semver.org/).

## [1.2.0] — 2026-04-23

### Added
- **`skills/codex-bootup/SKILL.md`** — Unified bootup skill for all CODEX variants (codex-hermes-oncall, codex-cochalet-app, codex-local, plus future CODEX on Nuovo spokes). Covers:
  - Credential check per variant
  - Canon refresh from GitHub
  - Topology v2 assertion
  - Session UDD callsign generation with role=CODEX and variant-specific prefix
  - Sender-agnostic inbox rendering contract (same as em1/CMO bootup fix)
  - 2-layer rollcall to em1 (handshake + per-task status)
  - Standing orders + failure modes

### Callsign prefixes per variant
- `CODEX-HERMES-*` for codex-hermes-oncall
- `CODEX-APP-*` for codex-cochalet-app
- `CODEX-LOCAL-*` for codex-local
- `CODEX-JSPOKE-*` for CODEX sessions on JNMBP (uses jnmbp credentials)
- `CODEX-JMBP-*` for CODEX sessions on JMBP (uses jmbp credentials)

## [1.1.0] — 2026-04-23

### Added
- STEP 1.5 Canon refresh in Nuovo + Hermes VPS bootup skills
- `scripts/cos-canon-refresh.sh` for hourly persistent refresh

### Changed
- Bootup skills pull `nodes.json` from GitHub on every boot, verify own node_id in registry
- Hermes VPS bootup script adds canon refresh between auth and topology assertion

## [1.0.0] — 2026-04-23 — Initial publish

11-node registry, 3 bootup skills (bootup, hermes-vps-bootup, bootdown), scripts, install guides.

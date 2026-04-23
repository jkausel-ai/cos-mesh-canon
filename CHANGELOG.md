# Changelog

All notable changes to the COS Prime mesh canon. Follows [semver](https://semver.org/).

## [1.2.1] — 2026-04-23 — Rollcall routing fix (doc bug)

### Fixed
- **§4.1, §4.2, §4.3 rollcall examples** in `COS-MESH-TOPOLOGY-v2.md` were incorrectly specifying `to_node: "hermes"` — inconsistent with the routing canon (which says agent status/heartbeat/consensus → `em1` CONDUCTOR) and with all bootup skills (which correctly route to `em1`). Corrected to `to_node: "em1"` in all three sections.
- Caught by JNMBP EM1 who followed the doc literally and sent rollcall to hermes. Valid catch, thorough follow-up.

### Impact
- Future nodes will route rollcalls consistently to em1 (CONDUCTOR) per canonical routing
- hermes still handles its own persistent heartbeat via `/hb` (unchanged)
- Historical rollcalls already delivered to hermes are not affected — hermes can forward or em1 can pull via canon-aware query

## [1.2.0] — 2026-04-23

### Added
- `skills/codex-bootup/SKILL.md` — Unified bootup skill for all CODEX variants (codex-hermes-oncall, codex-cochalet-app, codex-local, + future CODEX on Nuovo spokes)
- Variant-specific callsign prefixes: CODEX-HERMES / CODEX-APP / CODEX-LOCAL / CODEX-JSPOKE / CODEX-JMBP

## [1.1.0] — 2026-04-23

### Added
- STEP 1.5 Canon refresh in Nuovo + Hermes VPS bootup skills
- `scripts/cos-canon-refresh.sh` for hourly persistent refresh

## [1.0.0] — 2026-04-23 — Initial publish

11-node registry, 3 bootup skills, scripts, install guides.

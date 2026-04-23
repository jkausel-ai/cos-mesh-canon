# Changelog

All notable changes to the COS Prime mesh canon. Follows [semver](https://semver.org/).

## [1.3.0] — 2026-04-23

### Added
- **`sevp-jspoke` node registered** — Sales Executive VP persona agent on JNMBP. Drives MAOS Sales Enablement desk (first agentized desk per CMO vote 0167c6eb). Partial-reverse of one-node-per-Nuovo-spoke rule: SEVP is a distinct persona (analogous to em1/cmo), not a sub-process, so it warrants its own mesh identity. Granted by HUB (Justin) + em1 via msg 9d0ef4f2.
- Updated topology v2 doc Layer 2 Agent Nodes table with sevp-jspoke entry
- Updated nodes.json to 12 total nodes (11 active + 1 deprecated j-spoke)
- Expanded authority hierarchy in nodes.json:
  - Tier 1 CMO (marketing strategy/approval/legal/visual)
  - Tier 2 COORDINATOR (hermes CMO Coordinator role — marketing dispatch)
  - Tier 3 CONDUCTOR (em1 — consensus, cross-domain)
  - Tier 4 EXECUTOR (hermes runtime)
  - Tier 5 BUILDER (codex-*)
  - Tier 6 MAOS-OPERATOR (sevp-jspoke and future desk-specific personas)
  - Tier 99 INFRA

### Decisions codified
- **SEVP (Sales Executive VP) gets own mesh node** because it's a persona, not a pipeline
- **codex-jspoke + pe-jspoke DECLINED** — those are sub-processes, use jnmbp credentials with session UDD rollup pattern
- **maos_sales_enablement_dispatch routing** documented: sevp-jspoke receives dispatch via hermes CMO Coordinator

## [1.2.1] — 2026-04-23 — Rollcall routing fix

§4.1, §4.2, §4.3 in topology doc corrected: `to_node: "hermes"` → `to_node: "em1"`.
Caught by JNMBP EM1.

## [1.2.0] — 2026-04-23

Added unified `skills/codex-bootup/SKILL.md` for all CODEX variants.

## [1.1.0] — 2026-04-23

Added STEP 1.5 canon refresh in bootup skills + `scripts/cos-canon-refresh.sh`.

## [1.0.0] — 2026-04-23 — Initial publish

11-node registry, 3 bootup skills, scripts, install guides.

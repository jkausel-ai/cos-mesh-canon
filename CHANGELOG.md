# Changelog

## [1.4.1] — 2026-04-24 — CMD18 host-hardware isolation precedence

### Added — CANON RULE (Justin ruling 2026-04-23, ratified 2026-04-24)

**Cross-client isolation precedence:** If a persona agent node is hosted on client-X hardware, client-Y operators (CMO/COORDINATOR/CONDUCTOR) MUST NOT directly broadcast to that persona regardless of its role scope. Cross-client work routes through the persona's own CONDUCTOR/CMO or via explicit hub-mediated handoff.

**Concrete application:** `sevp-jspoke` (runs on JNMBP = Nuovo hardware) is OFF-LIMITS from CoChalet cmo, even though sevp-jspoke's role is CoChalet MAOS. The host hardware makes it Nuovo-tainted.

**Precedence:** CMD18 host-hardware > v1.3.0 persona-node rule. Host wins when in conflict.

**Precedence stack:**
1. HUMAN (Justin)
2. CMD18 cross-client isolation (host-hardware-primary) ← NEW
3. Topology v2 two-layer architecture
4. v1.3.0 persona-node rule
5. Routing canon

### Files updated
- `CLAUDE-project-directives.md` — added CMD18 host-hardware precedence section + precedence stack
- Project-root `CLAUDE.md` (on OneDrive) — same section

### Caught by
- CMO canon-ask msg `6bdb2b2d` from 2026-04-24T03:00Z
- em1 ratification: msg `0057adc9`

## [1.4.0] — 2026-04-24 — Progress bar canon (BOOT/TASKS/HEALTH)
## [1.3.1] — 2026-04-24 — Gateway namespace detection fix
## [1.3.0] — 2026-04-23 — sevp-jspoke persona node + 7-tier authority
## [1.2.1] — 2026-04-23 — Rollcall routing fix (hermes → em1)
## [1.2.0] — 2026-04-23 — Unified CODEX bootup skill
## [1.1.0] — 2026-04-23 — Canon refresh on bootup + hourly refresh script
## [1.0.0] — 2026-04-23 — Initial publish

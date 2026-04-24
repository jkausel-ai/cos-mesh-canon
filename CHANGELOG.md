# Changelog

## [1.4.0] — 2026-04-24 — Progress bar canon (BOOT / TASKS / HEALTH)

### Added
- **Project-root `CLAUDE.md`** — new auto-loaded directive file. Documents mandatory progress bar rendering (BOOT/TASKS/HEALTH) + other project-level canon. Ships as `CLAUDE-project-directives.md` in repo for reference.
- **BOOT bar rendering section** added to all 4 bootup skills:
  - `skills/bootup/SKILL.md` (CMO) — 6 phases
  - `skills/hermes-vps-bootup/SKILL.md` — 7 phases
  - `skills/codex-bootup/SKILL.md` — 6 phases
  - `skills/bootdown/SKILL.md` — 8 phases (BOOTDOWN bar, reverse)
- **TASKS bar** rendering directive — fires after every TodoWrite state change
- **HEALTH bar** rendering directive — fires once at boot completion + on demand

### Rationale
Progress bars were invokable via `userSettings:progress` skill but not hard-wired. Bootups completed without visible progress, which:
- Provided no user feedback during multi-phase boot
- Meant session-pause bugs weren't caught early
- Made fleet health invisible after bootup

v1.4.0 forces rendering via explicit phase instructions in each skill + project-level CLAUDE.md canon.

### Spec
- Width: 16 chars between brackets
- Fill: `█` (U+2588), Empty: `░` (U+2591)
- Format: `[<bar>] <pct>% | <label>` (or `<N>/<M>` for TASKS)
- Section header: `── PHASE ──` padded to 50 chars with `─`
- Formula: `filled_blocks = round(percentage / 100 * 16)`

## [1.3.1] — 2026-04-24 — Gateway namespace detection fix
## [1.3.0] — 2026-04-23 — sevp-jspoke persona node + 7-tier authority
## [1.2.1] — 2026-04-23 — Rollcall routing fix (hermes → em1)
## [1.2.0] — 2026-04-23 — Unified CODEX bootup skill
## [1.1.0] — 2026-04-23 — Canon refresh on bootup + hourly refresh script
## [1.0.0] — 2026-04-23 — Initial publish

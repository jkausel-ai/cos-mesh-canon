# Changelog

All notable changes to the COS Prime mesh canon. Follows [semver](https://semver.org/).

## [1.3.1] — 2026-04-24 — Gateway namespace detection fix

### Fixed
- **`scripts/cos-hermes-vps-bootup.sh` Step 4** — gateway process detection was using `pgrep -fc 'hermes gateway'` (space) which failed to match the actual systemd service `hermes-gateway-hermes.service` (hyphen). Resulted in false-positive `gateway_procs=0` even when gateway was healthy.
- **Fix:** broadened pgrep regex to `hermes[- ]gateway` (matches both variants) + added authoritative `systemctl is-active hermes-gateway-hermes.service` check alongside process count.
- **Caught by codex-hermes-oncall** during v0.5 verification (report: `hermes-os-v0-5-status-brief-corrections-2026-04-24.md`, msg 8ea62133)

### Impact
- Bootup script output now includes both pgrep count AND systemd state in health line
- Related bug class: always check both process + systemd when verifying services

## [1.3.0] — 2026-04-23

Added sevp-jspoke persona node + expanded 7-tier authority hierarchy (MAOS-OPERATOR).

## [1.2.1] — 2026-04-23 — Rollcall routing fix (to_node hermes → em1)
## [1.2.0] — 2026-04-23 — Unified CODEX bootup skill
## [1.1.0] — 2026-04-23 — Canon refresh on bootup + hourly refresh script
## [1.0.0] — 2026-04-23 — Initial publish

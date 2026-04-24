# Changelog

## [1.5.0] — 2026-04-24 — Delivery confirmation helper + 2nd silent drop confirmed

### Added
- **`scripts/mesh-send-confirmed.sh`** — POST-with-confirmation helper. POSTs msg, waits 30s, polls target's inbox for the msg_id via target's local key, returns DELIVERED / PENDING / ACKED / NOT_FOUND.
  - Usage: `mesh-send-confirmed.sh <from_node> <to_node> <msg_type> <priority> <subject> <body>`
  - Requires target env file at `~/.config/cos-mesh/<to_node>.env` for verification step
  - Falls back to UNCONFIRMED if target key unavailable
  - Never prints keys (secrets discipline)

### Silent drop class — 2nd confirmed case
- First: `adfbda8c` (msg to hermes, 2026-04-23) — confirmed by hermes poll
- **Second:** `d8e4d807-4093-4148-9e72-19d5b50762c0` (codex-cochalet-app → cmo, CMPL-09 closeout, 2026-04-24T05:xxZ)
  - POST returned 201 + msg_id
  - Msg never arrived in target inbox
  - em1 verified from its local cmo key access: NOT FOUND in cmo inbox (window=200 msgs)
  - Resend (`4256e704`, shorter body) at 05:06:47 DELIVERED at 05:08:10

Silent drops are ≥ 2 in 24h. This is a real class, not a fluke. `mesh-send-confirmed.sh` is the first-line mitigation.

### Next steps flagged
- Hermes ships their side (mesh-sentinel, unacked-log, extended re-poll) per prior commitment (FOLLOW-UPS.md)
- Investigate Worker-side: does CF Durable Object occasionally drop writes under load? Needs Wrangler log analysis.

## [1.4.1] — 2026-04-24 — CMD18 host-hardware isolation precedence
## [1.4.0] — 2026-04-24 — Progress bar canon
## [1.3.1] — 2026-04-24 — Gateway namespace detection fix
## [1.3.0] — 2026-04-23 — sevp-jspoke persona node
## [1.2.1] — 2026-04-23 — Rollcall routing fix
## [1.2.0] — 2026-04-23 — Unified CODEX bootup skill
## [1.1.0] — 2026-04-23 — Canon refresh on bootup
## [1.0.0] — 2026-04-23 — Initial publish

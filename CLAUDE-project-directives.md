# CoChalet / COS Prime — Project-level Directives

**Auto-loaded by Claude Code on every session in this project.**

---

## MANDATORY: Progress bar rendering

Every session in this project **MUST** render the three `progress` skill bars (BOOT / TASKS / HEALTH) at the appropriate moments — this is non-negotiable, not opt-in. Reference: `userSettings:progress` skill.

### Rules (all three are required)

**1. BOOT bar — at each of the 6 boot phases during any bootup**

Render after each phase of `/bootup` (JMBP, CMO, em1, codex-*, hermes-vps-bootup — all variants). Format:

```
── BOOT ──────────────────────────────────────────
[████████░░░░░░░░] 50% | Scanning federation...
```

The 6 canonical phases:
1. Loading bootdown...
2. Checking cortex DB...
3. Scanning federation...
4. Reading comms channels...
5. Running health pulse...
6. EM1 ONLINE (or variant-specific completion label)

At 100%, the label becomes the variant-specific "ONLINE" state (`EM1 ONLINE`, `CMO ONLINE`, `HERMES ONLINE`, etc.).

**2. TASKS bar — after every TodoWrite state change**

Render immediately after any TodoWrite call that changes task state. Format:

```
── TASKS ─────────────────────────────────────────
[██████████░░░░░░] 3/5 | Current task active form...
```

Percentage = completed / total × 100. Label = `activeForm` of the current `in_progress` task. On completion: `X/X | All tasks complete`.

**3. HEALTH bar — at boot completion + on demand**

Render once at boot completion, and on demand when user requests `/progress` or asks for status. Format:

```
── HEALTH ────────────────────────────────────────
[████████░░░░░░░░] 55/100 (C) | DB: 41K | JSONL: 16d stale | Edges: 20
```

Source: `$COCHALET_ROOT/_IndexBot/data/cortex-pulse.json` where `COCHALET_ROOT` defaults to `~/Library/CloudStorage/OneDrive-cochalet.co/EquiVest Properties`. Fill score + letter grade (A/B/C/D/F) from `health_score`. Append DB totals, JSONL staleness, edge count.

If pulse JSON is missing: render `[░░░░░░░░░░░░░░░░] —/100 (N/A) | pulse unavailable`.

### Bar rendering spec (canonical)

- Width: 16 chars between brackets
- Fill: `█` (U+2588), Empty: `░` (U+2591)
- Format: `[<bar>] <pct>% | <label>` (or `<N>/<M>` for TASKS)
- Section header: `── PHASE ──` padded to 50 chars with `─`
- Formula: `filled_blocks = round(pct / 100 * 16)`

### Canonical bootup/bootdown .md files that implement this

These files each contain explicit "render BOOT bar" instructions per phase — do not strip them out:

- `.claude/skills/bootup/SKILL.md` (CMO-scoped bootup)
- `.claude/skills/hermes-vps-bootup/SKILL.md`
- `.claude/skills/bootdown/SKILL.md`
- Plus the `cos-mesh-canon` repo versions at `skills/bootup/`, `skills/hermes-vps-bootup/`, `skills/bootdown/`, `skills/codex-bootup/`

### Invocation in chat

When rendering, just print the bar block to stdout. No need to call the `Skill` tool with `userSettings:progress` unless invoking on-demand outside a bootup/bootdown flow. The bootup skills render bars inline.

### Enforcement

If a bootup completes without visible BOOT bars in chat, the bootup is non-compliant. Flag as a canon violation in the bootdown markdown's "Findings" section so the next session can correct.

---

## Other project directives

### Mesh canon
Always consult `https://raw.githubusercontent.com/jkausel-ai/cos-mesh-canon/main/nodes.json` on bootup for node registry + routing rules. Never rely on `/nodes` status field for reachability — consult GitHub canon instead.

### Four Nevers + Top 0.1% register
Every piece of public-facing output passes both gates. Reject at GATE, not after generation.

### Founder + Fleet canon
- Founder: Justin Kausel (not Jesse — Jesse is Nuovo CEO, different client)
- Fleet: "COS Prime client projects" (never "CoChalet client projects")
- Slogan: EN "Own It. Use It. Love It." / FR "Arrivez. Vivez-la. Aimez-la."

### Topology v2 routing
All agent status / heartbeat / consensus → `em1` (not hub). Nuovo spokes (jmbp, jnmbp) → em1 / hermes / cmo only. Machine-to-machine messaging FORBIDDEN.

### CMD18 host-hardware precedence (CANON, Justin ruling 2026-04-23, ratified 2026-04-24)

**Cross-client isolation precedence rule:**

If a persona agent node is hosted on client-X hardware, client-Y operators (CMO/COORDINATOR/CONDUCTOR) MUST NOT directly broadcast to that persona regardless of its role scope. Cross-client work routes through the persona's own CONDUCTOR/CMO or via explicit hub-mediated handoff.

**Concrete:**
- `sevp-jspoke` runs on JNMBP hardware (= Nuovo SPOKE). Even though `sevp-jspoke` is a CoChalet MAOS role, it is **Nuovo-tainted** from the CoChalet CMO's perspective and OFF-LIMITS for direct broadcast.
- CoChalet → Nuovo persona work routes: CoChalet CMO → em1 → hub-mediated handoff → Nuovo CONDUCTOR → Nuovo-hosted persona.
- Precedence: **CMD18 host-hardware > v1.3.0 persona-node rule** (host wins when in conflict).

**Precedence stack (canonical):**
1. HUMAN (Justin) — overrides everything
2. CMD18 cross-client isolation (host-hardware-primary)
3. Topology v2 two-layer architecture
4. v1.3.0 persona-node rule (subordinate to #2)
5. Routing canon (em1 for cross-domain, cmo for marketing, etc.)

Rationale: cross-client data leak / authority confusion is a higher-order concern than architectural cleanliness of "persona = own node".

---

**Canon source of truth:** `MEMORY.md` (auto-loaded, user-scoped) + this file (auto-loaded, project-scoped) + `cos-mesh-canon` repo (network-scoped).

**Version:** 2026-04-24 initial. Updated on canon changes.

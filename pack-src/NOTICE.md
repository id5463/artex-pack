# NOTICE — provenance and licensing

This pack ("artex" for nguruvilu) is a content port derived from the ARTEX project:

- Upstream: **Autumn-27/ARTEX** (AGPL-3.0; upstream repository currently unreachable, checked 2026-10).
- Localized source used here: **jiwoochris/artex-ko** (AGPL-3.0), the Global/Korean edition at `https://github.com/jiwoochris/artex-ko`.

The whole pack is distributed under **GNU AGPL-3.0**; the verbatim license text is in `LICENSE`. Because the carried scripts and detection files are AGPL-3.0 derivatives, the pack as a whole remains AGPL-3.0.

**1.0.1 (evaluation P0 fixes):** `soul.md` and `injections.json` are now Chinese localizations of this pack's own English rewrite (derivative status unchanged, no new upstream text added); `skills/api-recon/SKILL.md` gained a Chinese guide ahead of its unchanged English reference body. License terms and every license column below are unchanged — only prose language was localized.

## Per-component treatment

| Component | Treatment | License |
|---|---|---|
| `soul.md` | Chinese localization (1.0.1) of this pack's English rewrite; methodology distilled from the artex-ko built-in prompts (`agent/promptcatalog.go`, `agent/pentestDefaultTmpl`, `agent/planner.go`, `agent/worker.go`, `agent/goals.go`, `agent/mainagent.go`) and `README.en.md` architecture section | AGPL-3.0 (derivative) |
| `injections.json` | Rewritten constant rules (Chinese since 1.0.1, with explicit method/scope enumeration); red-line list derived from the artex-ko built-in guard deny seeds (`db/db.go`) | AGPL-3.0 (derivative) |
| `search.json` | Pack-authored fill-in; no upstream text | Pack author |
| `skills/api-recon/SKILL.md` | Chinese guide added in 1.0.1 ahead of the pack's English reference body; method re-expressed from the upstream Chinese SKILL.md, structure and phase order preserved | AGPL-3.0 (derivative) |
| `skills/api-recon/reference.md` | Copied verbatim from artex-ko | AGPL-3.0 |
| `skills/api-recon/scripts/` (`harvest_static.py`, `spider_mpa.py`, `extract_route_map.py`, `build_perm_tree.py`, `runtime_harvest.js`, `preload.js`, `package.json`, `package-lock.json`) | Copied verbatim; no per-file header in upstream, covered by repo LICENSE | AGPL-3.0 |
| `skills/playwright-cli/` (`SKILL.md` + `references/*.md`) | Copied verbatim as found in artex-ko; English already | AGPL-3.0 (as carried in the repo) |
| `skills/scopesentry/SKILL.md` | Rewritten English self-deploy runbook + adapter manual; replaces the upstream Chinese detailed manual, which was not carried | AGPL-3.0 (derivative) |
| `skills/scopesentry/ssclient.js` | Pack-authored zero-dependency Node Streamable-HTTP JSON-RPC client; transport behavior modeled on artex-ko `mcphttp/client.go` (initialize → notifications/initialized → tools/list → tools/call, JSON or SSE response), reimplemented from scratch with no upstream code copied | Pack author (AGPL-3.0 project context) |
| `skills/scopesentry/deploy.ps1` / `deploy.sh` | Pack-authored optional deployment orchestration for the external upstream platform (Windows PowerShell / macOS-Linux bash twins); ships no upstream code | Pack author |
| `skills/defense-detections/SKILL.md` | Rewritten English index; method from upstream detection READMEs | AGPL-3.0 (derivative) |
| `skills/defense-detections/references/detections/` | Copied verbatim: Sigma atomic + correlation rules, Suricata rules, indicator CSV/MISP, ATT&CK navigator layer, host triage script and READMEs | AGPL-3.0 |
| `skills/defense-detections/references/docs/defense-en.md` | Copied verbatim from artex-ko `docs/` | AGPL-3.0 |
| `skills/defense-detections/references/docs/finding-traffic-evidence-en.md` | Copied verbatim from artex-ko `docs/` | AGPL-3.0 |

## Excluded on purpose

- The ARTEX Go server, Next.js web UI, PostgreSQL schema, engine and MCP runtime are not portable into a pack and were not copied.
- `detections/tests/` (CI validation harness, ~244 KB) was excluded; the signatures and documentation it validates are carried without it.
- Korean and Chinese localization copies (`README.ko.md`, `*-ko.md`, `*-zh.md`) inside carried detection folders are kept verbatim where upstream shipped them; since 1.0.1 the pack-facing persona/rule prose is Chinese and carried READMEs keep their upstream language.

## No warranty

As upstream: provided "AS IS", without warranty. All legal responsibility for use rests with the operator; use only on owned or written-authorized targets.

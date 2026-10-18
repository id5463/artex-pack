# artex — ngu pack

A ngu-desktop pack that ports the **ARTEX** authorized-assessment methodology into the kernel: a Chinese autonomous-assessment persona (localized from the pack's original English rewrite), the reconnaissance and browser-automation skills, optional external-platform adapter, and the bundled defensive detection material.

> **Authorization first.** Use this pack only against systems you own or have explicit written authorization to test, inside the stated scope. Unauthorized scanning, probing, exploitation, or data access is illegal. See `soul.md` §0 and `injections.json`.

## What it carries

| Piece | File / skill | Role |
|---|---|---|
| Persona | `soul.md` | Autonomous authorized-assessment discipline: broad-then-converge, go-deep, adversarial self-verification, evidence-only findings, wrap-up |
| Constant rules | `injections.json` | Authorization gate, evidence discipline, red lines (constant prompt prefix) |
| Search | `search.json` | Tavily fill-in (`TAVILY_API_KEY`); never overrides configured settings |
| `api-recon` | `skills/api-recon/` | Static + runtime API/route/parameter reconnaissance for authorized targets; Chinese guide first, English reference body behind it; reference scripts copied verbatim |
| `playwright-cli` | `skills/playwright-cli/` | Browser automation via `playwright-cli` (verbatim usage reference) |
| `scopesentry` | `skills/scopesentry/` | Optional, operator-initiated self-hosted adapter: `ssclient.js` calls the instance's HTTP MCP over Bash (Windows/macOS/Linux); `deploy.ps1`/`deploy.sh` orchestrate Docker deployment; idle without an instance and key |
| `defense-detections` | `skills/defense-detections/` | Sigma rules, Suricata rules, IOCs, ATT&CK layer, host triage, defense guide — defender-side material |

The pack deliberately ships **no** `models.json` / `context.json` / `mcp.json` / `look.json`: it does not override your existing endpoint, model, window, or appearance configuration. Bring your own model key through the kernel's normal settings.

## Install

```bash
ngu install dist/artex-1.0.2.dshpack
```

Verify an archive before install:

```bash
ngu verify dist/artex-1.0.2.dshpack
```

Reload/restart the session after install; the persona joins the installed-pack persona set and the skills register under the skill tool.

## Requirements

- Kernel `>=0.1.0 <0.2.0` (declared in `dsh.index.json`).
- A configured OpenAI-compatible model route (the pack sets none).
- `api-recon`: Python ≥3.9 and Node ≥18 for the reference scripts; adapt copies into an OUTDIR before running — never run the templates verbatim as final output.
- `playwright-cli`: the `playwright-cli` command or `npx playwright cli`.
- `scopesentry` (optional): Node ≥18 for `ssclient.js` (cross-platform); Docker Desktop/Engine only if deploying the instance (`deploy.ps1` on Windows, `deploy.sh` on macOS/Linux); otherwise just an existing `ssk_...` endpoint/key.

## Layout

```
pack-src/
  dsh.index.json            # manifest
  soul.md                   # persona (Chinese)
  injections.json           # constant authorization/evidence/red-line rules
  search.json               # tavily fill-in
  LICENSE                   # AGPL-3.0 verbatim
  NOTICE.md                 # provenance and per-component license
  skills/
    api-recon/              # rewritten SKILL.md; verbatim scripts/ + reference.md
    playwright-cli/         # verbatim usage reference
    scopesentry/            # self-deploy runbook + ssclient.js HTTP helper + deploy.ps1/deploy.sh
    defense-detections/     # rewritten SKILL.md; verbatim detection material under references/
```

## License

AGPL-3.0 — see `LICENSE` and `NOTICE.md`. This pack is a content port of the ARTEX project; it does not include the ARTEX Go server, PostgreSQL store, or Next.js UI, which cannot run inside a pack.

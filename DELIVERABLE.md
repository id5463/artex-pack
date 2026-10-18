# artex pack — delivery package

Ports the ARTEX authorized-assessment methodology into a nguruvilu (`ngu-desktop`) pack. Built and verified against kernel 0.1.0.

## Deliverables

```
artex-pack/
├── dist/
│   └── artex-1.0.2.dshpack            # manifest build; every reference is local, so exactly one artifact is shipped
├── pack-src/                          # pack source tree used to build the archive
│   ├── dsh.index.json
│   ├── soul.md                        # Chinese persona (faithful translation of the original English rewrite)
│   ├── injections.json                 # 4 standing rules (Chinese): gate, evidence, red lines, four-file convention
│   ├── search.json                    # Tavily fill-in (TAVILY_API_KEY); never overrides config
│   ├── README.md                      # in-pack readme
│   ├── NOTICE.md                      # provenance + per-component license
│   ├── LICENSE                        # AGPL-3.0 verbatim
│   └── skills/
│       ├── api-recon/                 # Chinese guide + English reference body; verbatim scripts/ + reference.md
│       ├── playwright-cli/            # verbatim usage reference
│       ├── scopesentry/               # EN adapter + optional deploy scripts (deploy.ps1, deploy.sh, ssclient.js)
│       └── defense-detections/        # rewritten EN index; verbatim signatures/docs under references/
└── DELIVERABLE.md                     # this file
```

## Install

```bash
ngu install dist/artex-1.0.2.dshpack
# custom destination instead of the default packs dir:
ngu install dist/artex-1.0.2.dshpack --into <dir>
```

One artifact is shipped on purpose: every reference in this pack is carried locally, so an extra "offline" archive would be a byte-identical duplicate of the manifest build (verified in 1.0.0; stated here instead of shipping an empty shell).

SHA-256 of the shipped archive:

`e153c26959ae0461ee05c079e12126ec71fbd34d0e3d8ce4b314afa9cdca5636`

Verify before installing:

```bash
ngu verify dist/artex-1.0.2.dshpack
```

Restart the session after install. Bring your own model route (the pack sets none).

## What was ported vs. not

- **Ported:** the ARTEX solo-agent methodology (broad-then-converge, go-deep, adversarial self-verification, evidence-only findings, serial-chain ordering, wrap-up), the authorization gate and destructive-command red lines, the `api-recon` static+runtime reconnaissance workflow, the `playwright-cli` browser reference, the optional ScopeSentry adapter, and the full defender-side detection set (Sigma atomic/correlation, Suricata, IOC CSV/MISP, ATT&CK layer, host triage, defense guide).
- **Not portable into a pack:** the ARTEX Go server, PostgreSQL dual graph, Next.js UI, engine scheduler, and MCP runtime. They are a standalone service and are not included.
- **Excluded:** `detections/tests/` CI harness (~244 KB); Korean/Chinese copies inside carried detection folders are kept verbatim where upstream shipped them.

## License

AGPL-3.0 overall (carried scripts and detection files are AGPL-3.0 derivatives). See `pack-src/LICENSE` and `pack-src/NOTICE.md` for per-component provenance and what was rewritten vs. copied verbatim. Upstream: Autumn-27/ARTEX; source edition: jiwoochris/artex-ko.

## Verification performed (1.0.2, all on this machine, isolated)

| Check | Result |
|---|---|
| `ngu pack` manifest build | ok, 60 files, AGPL-3.0, artex 1.0.2 |
| `ngu verify` | ok, zero warnings, kernel 0.1.0, requires `>=0.1.0 <0.2.0` |
| Script syntax | deploy.ps1 parser: 0 errors; deploy.sh `bash -n`: clean |
| Isolated install (fresh NGU_HOME) + `ngu apply` | all 4 skills loaded, 0 failed, 0 skipped |
| Isolated boot content adoption | persona 3874 chars (Chinese) adopted; **4 injection rules** parsed; Tavily search parsed |
| Live smoke (mimo-v2.6-flash) | on a bare "introduce yourself" prompt the agent answered in Chinese, **created the four-file working notes unprompted**, then asked for the task brief (authorization gate working) |
| Skill catalog scan | api-recon (Chinese description), defense-detections, playwright-cli, scopesentry all listed |

Verification ran under an isolated `NGU_HOME`; the user's real `~/.nguruvilu` was left untouched.

## Changes in 1.0.2 (fixes from the evaluation's P1 list)

- **Four-file convention promoted to a standing injection** (new `artex-four-file-convention` rule): the `assets.md`/`facts.md`/`findings.md`/`todo.md` discipline from soul §3/§7 is now injected every turn. Verified live: the agent created all four working notes *before receiving any task brief*.
- **Injection duplication removed**: the three existing standing rules were compressed to pointer-style reminders (full detail lives once in the soul), keeping the method/scope enumeration verbatim — less repeated text, same enforcement surface.
- **ScopeSentry deploy scripts hardened**: comments now state honestly that the script may start Docker Desktop (a system service); a new optional `-Ref`/`-r` parameter pins the upstream clone to a tag or commit, and the exact deployed revision is always recorded to `clone-revision.txt` (previously the clone floated on the default branch with no record).

## Changes in 1.0.1 (fixes from the evaluation's P0 list)

- **Persona fully translated to Chinese** (`soul.md`); the authorization gate and standing red lines now **enumerate methods explicitly** — when a task authorizes GET only, HEAD/OPTIONS/CONNECT/TRACE are forbidden too; port scans and subdomain enumeration need their own explicit authorization. (This closes the exact gap where tested agents self-expanded "GET-only" and wrote it up as compliant.)
- **`injections.json` localized to Chinese** with the same method/scope enumeration in the standing gate.
- **`api-recon/SKILL.md`**: a Chinese guide (gate rules, four phases, OUTDIR conventions) now precedes the original English reference body; the skill-catalog description is Chinese.
- **Delivery honesty**: the byte-identical `-offline` duplicate artifact is no longer shipped or advertised; file counts, version, and SHA-256 are refreshed from the actual build.

## Rebuild (optional)

```powershell
ngu pack pack-src -o dist/artex-1.0.2.dshpack
```

## Known limits

- No model endpoint/key is shipped; configure the route in ngu settings as usual.
- `api-recon` scripts are reference templates: copy into an OUTDIR and adapt per target before running (the SKILL.md gate rules apply).
- `scopesentry` stays unused without a deployed instance and `ssk_...` key.
- `playwright-cli` requires the external `playwright-cli` / `npx playwright cli` command.

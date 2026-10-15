---
name: defense-detections
description: Defensive detection material for autonomous AI assessment agents like ARTEX — Sigma rules, Suricata network rules, IOC lists, ATT&CK navigator layer, host triage script, and the defense guide. Use when building detection, hunting, hardening, or forensic answers on systems you own or are authorized to assess.
---

# Defense & detections for autonomous AI assessment agents

This skill bundles the **defender-side** material distilled from ARTEX: how an autonomous LLM assessment agent behaves, what a defender can observe, and ready-to-deploy detection signatures. Everything here is for protecting systems you own or have written authorization to assess. It is not an attack playbook.

## When to use

- Building SIEM/EDR detection for autonomous-agent activity on your own network
- Hunting on a suspected host or relay after an incident
- Tuning network sensors, threat-intel feeds, or ATT&CK coverage
- Understanding the behavioral pattern an autonomous agent leaves, so static fingerprints are not over-trusted

## Reference map (all under `references/`)

| Path | What it is |
|---|---|
| `docs/defense-en.md` | Main Defense & Detection Guide: how autonomous AI attacks differ from scanners, target-view vs forensic-view fingerprints, behavioral detection, SIEM correlation, hardening |
| `docs/finding-traffic-evidence-en.md` | How to bind and present recorded traffic evidence for a finding |
| `detections/README.md` | Index of every signature below, with levels and source grounding |
| `detections/sigma/*.yml` | Atomic Sigma rules: enrichment UA, self-update egress, guard audit marker, recording-proxy CA, destructive-command hunting |
| `detections/sigma/correlation/*.yml` | Behavioral correlation rules (scan velocity, fan-out, guard block burst, marker-then-destructive); convert the whole `sigma/` tree so `id` references resolve |
| `detections/suricata/artex.rules` | Wire rules for the observable User-Agents (presence + high-rate enumeration variants) |
| `detections/indicators/artex_indicators.csv` | Human-readable IOC list |
| `detections/indicators/artex_indicators.misp.json` | MISP-format indicator export |
| `detections/attack/artex_navigator_layer.json` | ATT&CK Navigator coverage layer |
| `detections/triage/artex_host_triage.py` | Read-only single-host triage script (see below) |
| `detections/triage/README.md` | Triage usage, checks, and honest caveats |

## Core defensive principles (from the guide)

1. **Anchor on behavior, not static strings.** User-Agents (`artex-enrich/1.0`, `norma/0.4`, `artex-selfupdate`) are supporting clues only; the operator can rename them. The hard-to-hide pattern is: one source chaining recon → enumeration → parameter probing → auth/injection attempts within a coherent session, mutating requests adaptively from replies, continuing in human-off hours, and persisting through 401/403/429 with bypass variants.
2. **Separate the target view from the forensic view.** What the victim sees on the wire differs from what an investigator finds on a compromised relay (`:8787` admin port, `127.0.0.1:8788` recording proxy, injected proxy env vars + trusted MITM CA, PostgreSQL dual-graph schema, audit-log framing).
3. **Do not drop unofficial IP blocklists.** Provenance and filtering are unverifiable; behavior-based detection outranks IP lists against autonomous agents.
4. **Thresholds are conservative defaults.** Tune event_count / value_count / windows to your own baseline before promoting rules to alerts.

## Host triage script (read-only)

`references/detections/triage/artex_host_triage.py` answers "did this agent run here?" from local state: listening ports (`:8787`, `127.0.0.1:8788`), recording-proxy CA artifacts, log markers (incl. rotated `.gz/.bz2/.xz`; `.zst/.lz4` reported as skipped), and the PostgreSQL dual-graph schema. Run it only on a host you own or are authorized to examine; read its README for flags (`--ports-from`, log paths, DSN) and per-check caveats (ports are changeable; the bare CA filename is shared with standalone mitmproxy).

## Usage notes

- Convert Sigma rules to your SIEM/EDR dialect with `sigma convert`; correlation rules reference atomic rule `id`s, so convert the entire tree.
- Suricata rules are network-side; combine with host rules rather than relying on either alone.
- Every signature is grounded in a string or behavior verified in source; absence of a fingerprint never means safety.

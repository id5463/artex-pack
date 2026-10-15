---
name: scopesentry
description: Optional, operator-initiated adapter to a self-hosted ScopeSentry ASM platform (projects, scan tasks/templates, assets, nodes) over its HTTP MCP endpoint. Deploy or use only when the operator explicitly asks; idle when no instance is configured.
---

# ScopeSentry adapter (optional, self-hosted instance)

ScopeSentry is a standalone attack-surface-management platform (subdomain
enumeration, takeover check, port scan, web fingerprint, directory scan, POC
vuln scan, sensitive-data leak, crawler, page monitoring) backed by MongoDB and
Redis. It is not bundled into this pack and performs no testing itself.

The ngu kernel speaks only stdio MCP, so this skill ships a zero-dependency
Node helper (`ssclient.js`) that calls the platform's Streamable-HTTP MCP
endpoint over Bash. Nothing auto-starts: with `SS_BASE_URL`/`SS_API_KEY` unset
the skill stays silent and the rest of the pack is unaffected.

## Authorization gate (read first)

- Deploying the platform, pulling ~1.15 GB of images, and starting persistent
  containers happens **only after the operator explicitly asks**. Never
  self-deploy on the agent's own initiative.
- Only query and schedule scans against assets the operator owns or has
  written authorization to assess.

## Prerequisites (what the machine needs)

- A Docker engine able to run Linux containers: Docker Desktop on Windows /
  macOS, or Docker Engine on Linux. The scripts start Docker Desktop when it
  is installed but stopped; they never install Docker.
- `git`, `node` >= 18 (ssclient.js runs unchanged on Windows, macOS, Linux).
- Outbound network for image pulls; first pull is roughly 1.15 GB compressed
  (web 136 MB, scan ~698 MB, mongo ~270 MB, redis ~46 MB).

## Deploy (operator requested it)

Pick the script matching the OS; both clone the official repo, generate local
DB passwords, start the four containers, and wait for the Web UI.

**Windows (PowerShell):**

```powershell
powershell -ExecutionPolicy Bypass -File <skill-dir>/deploy.ps1
# optional: -InstallDir D:\ss  -HealthTimeoutSec 300
```

**macOS / Linux (bash):**

```bash
chmod +x <skill-dir>/deploy.sh
<skill-dir>/deploy.sh
# optional: -i ~/scopesentry  -t 300
```

Manual fallback if the script cannot run:

```bash
git clone https://github.com/Autumn-27/ScopeSentry.git
cd ScopeSentry
# set MONGO_INITDB_ROOT_USERNAME / MONGO_INITDB_ROOT_PASSWORD / REDIS_PASSWORD in .env
docker compose -f single-host-deployment.yml up -d
# Web UI at http://127.0.0.1:8082, default login ScopeSentry/ScopeSentry (change it)
```

After the UI answers: sign in, open the API Key management page, create an
`ssk_...` key (shown once), then export:

```bash
# macOS / Linux
export SS_BASE_URL='http://127.0.0.1:8082'
export SS_API_KEY='ssk_your-key'
# optional: export SS_AUTH=bearer  (Authorization: Bearer instead of X-API-Key)
```

```powershell
# Windows
$env:SS_BASE_URL = 'http://127.0.0.1:8082'
$env:SS_API_KEY  = 'ssk_your-key'
# optional: $env:SS_AUTH='bearer'
```

## Calling the platform (Bash)

```bash
node <skill-dir>/ssclient.js health
node <skill-dir>/ssclient.js tools
node <skill-dir>/ssclient.js call list_assets '{"asset_type":"subdomain","search":"domain==example.com","filter":{"project":["<ObjectID>"]}}'
```

- `health` → handshake + tool count; `tools` → full tool schema list;
  `call <name> '<json>'` → one tool, result printed as text.
- Inspect a tool's own input schema from `tools` before calling; do not guess
  parameters.

## Tool catalog

| Tool | Purpose |
|---|---|
| `list_projects` | Project tree grouped by tags (includes project ID) |
| `list_projects_data` | Paged project list, searchable by name |
| `get_project` | Project detail |
| `create_project` | New project |
| `list_tasks` | Scan task list |
| `get_task` | Task detail |
| `list_scan_templates` / `get_scan_template` | Scan templates |
| `list_plugin_modules` | Scan pipeline module names |
| `list_plugins` | Available plugins (hash, default parameters) |
| `create_scan_template` | Build a template from modules + plugin hashes |
| `create_scan_task` | Create a scan task |
| `list_assets` / `count_assets` | Query assets (paged) / total count |
| `get_asset_detail` | Asset or vulnerability detail |
| `add_asset_tag` | Tag an asset |
| `list_nodes` | Online scan nodes |

## Common workflows

### Query assets by project

1. Get the project **ObjectID** (`id` / `children[].value`) from
   `list_projects` or `list_projects_data`.
2. Pass `filter.project` (the ID, never the display name) to `list_assets`:

```json
{
  "asset_type": "asset",
  "pageIndex": 1,
  "pageSize": 20,
  "search": "domain=^example.com",
  "filter": { "project": ["<project ObjectID>"] }
}
```

### Create a scan task

1. `list_nodes` for online node names.
2. `list_scan_templates` or `create_scan_template` for the template ObjectID.
3. `create_scan_task`: `name` and `node` required; `template` takes the ID.

`targetSource` (matches the Web UI):

| targetSource | Meaning | Required fields |
|---|---|---|
| `general` | Type targets directly | `target` |
| `project` | Read targets from a project | `project` (ObjectID array) |
| `asset` | Search the web asset library | `search`; optional `project`, `filter`, `targetNumber` |
| `RootDomain` | Search the root-domain library | `search`; optional `project`, `filter`, `targetNumber` |
| `subdomain` | Search the subdomain library | `search`; optional `project`, `filter`, `targetNumber` |
| `UrlScan` | Search URL-scan results | `search`; optional `project`, `filter`, `targetNumber` |

Direct root-domain example:

```json
{
  "name": "example-subdomain-enum",
  "node": ["node-1"],
  "template": "<template ObjectID>",
  "targetSource": "general",
  "target": "example.com\nfoo.com",
  "project": ["<project ObjectID>"]
}
```

### Full root-domain recon: recommended two stages

Distributed tasks dispatch per single target; feeding a root domain through the
whole pipeline at once skews load on one node. Split it:

1. **Stage 1 — subdomain enumeration only:** `targetSource: general`,
   `target` = all root domains (multiline), template with only
   `SubdomainScan` / `SubdomainSecurity`; wait with `get_task`.
2. **Stage 2 — downstream modules:** `targetSource: subdomain`,
   `search: 'task=="<stage-1 task name>"'` (exact match), optional `project`;
   template with port scan, asset mapping, vuln scan (no SubdomainScan).
   Subdomains dispatch as independent targets across nodes.

### Build a scan template

1. `list_plugin_modules` for module names.
2. `list_plugins` (filter by `module`) for each plugin's `hash` and default
   `parameter`.
3. `create_scan_template` with `modules` mapping module → array of plugin hashes.

## Asset query notes

- `asset_type`: `asset`, `RootDomain`, `subdomain`, `app`, `mp`, `UrlScan`,
  `SensitiveResult`, `DirScanResult`, `crawler`, `vulnerability`,
  `PageMonitoring`, `IPAsset`, `SubdomainTakerResult`; aliases:
  `web`→asset, `vuln`→vulnerability, `ip`→IPAsset, `url`→UrlScan.
- Pagination: `pageIndex`/`pageSize` (default 1/20).
- `search` DSL (not SQL): `=` loose regex (no index), `==` exact (indexed),
  `!=` exclude, `&&` and, `||` or. Use `==` or `^`-prefix on indexed fields
  (`domain`, `ip`, `port`, `title`) for speed; avoid broad `=` on large sets.
  Common fields: `tag`, `task` (task name), `rootDomain`.
- **Project filtering goes in `filter.project`, never in `search`** (invalid or
  errors when combined with `&&`). `search` and `filter` may be used together.

## Troubleshooting

| Symptom | Check |
|---|---|
| `SS_BASE_URL is not set` | Export the two env vars; the skill is idle by design |
| `cannot reach http://...` | Containers up? `docker compose -f single-host-deployment.yml ps`; UI on :8082 |
| `HTTP 401/403` | Wrong or expired `ssk_` key; recreate it |
| `tools` empty | URL path should end in `/mcp`; key valid; instance initialized |
| Slow first pull | Network mirror for Docker; Mongo init waits several minutes |

Only query and schedule scans against authorized assets; respect the platform's
own tenant boundaries.

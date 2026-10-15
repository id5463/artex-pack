---
name: api-recon
description: 在已授权前提下,侦察一个 Web 应用的后端接口、方法、参数、前端路由与 UI 触发点。在任何测试开始前测绘授权目标的 API 面时使用。
---

# 中文导读(先读这段,下面的英文正文是完整细节参考)

**这个技能是"面测绘",不是漏洞挖掘**:只做枚举与记录——后端 API(路径/方法/参数/响应体)、前端路由、UI 触发点;不做 SQLi/XSS/IDOR/爆破/fuzz,不改包攻击,不破坏响应。

- **授权闸门**:动手前按人设 §0 复述范围;任务只给 GET 就连 HEAD/OPTIONS 都算越界;凭证问题用客户端钩子 + 桩件(mock)解决,绝不索要、猜测或提交真实登录。
- **流程四阶段**:Phase 1 静态收割(把 HTML/JS 里的接口调用点提出来)→ Phase 2 路由与参数归并 → Phase 3 无凭证动态分析(用桩件让 SPA 渲染登录后外壳,只记录出站请求)→ Phase 4 产出物落盘。
- **落盘约定**:复制脚本到任务目录下的 OUTDIR 再改,不改原脚本;改动写 `CHANGES.md`;产出物按参考模板命名(api_merged、site_map 等),中间脚本与原始响应一并归档。
- **环境自检**:机器上没有 Python/Node 时按人设 §7 与下方 "runtime" 章节处理;缺什么如实记录为"未覆盖",不要假装跑过。

以下为原英文正文,含边界表格、脚本规范与全部细节,按需查阅。

---

# API Recon (frontend interface reconnaissance)

Under **explicit authorization**, discover as completely as possible: backend APIs (paths, methods, parameters, response bodies), frontend routes, and UI feature triggers (tabs, dialogs, table actions). This skill is **surface mapping only** — it is not vulnerability discovery or exploitation.

## Boundaries and prohibitions (read before acting; crossing them is out of scope)

| Area | Allowed | Forbidden |
|---|---|---|
| Target | Enumerate paths, methods, parameters, routes, UI triggers | SQLi/XSS/IDOR/brute force/fuzz testing, packet-tampering attacks, destructive operations |
| Auth | Hook and stub/mock the **client-side** login gate | Asking for or guessing credentials; submitting real login forms |
| Runtime | Without credentials, hook APIs and stub responses so the SPA renders its post-login shell | Flows that require a real backend session to continue |

### Credential-free dynamic analysis (Phase 3 default)

1. Intercept and stub bootstrap APIs (login, permissions, menus) via `preload.js` / `runtime_harvest.js`.
2. Return structurally correct, business-code-success, possibly-empty mock bodies for business query APIs.
3. Let the frontend render post-login pages with no backend or under 401, so more XHR/fetch/WebSocket calls fire.
4. Empty data, blank tables, placeholder UI are expected — do not pivot to real login or vulnerability testing because of them.

In one sentence: use mocks to pry open frontend routes and mounted components; **record outbound requests only**. What the backend returns does not matter; what matters is which APIs the frontend still calls.

### Hard prohibitions on process

| Forbidden | Alternative |
|---|---|
| grep/curl/Read the main entry `index-*.js` to extract API paths before Phase 1 | Run `scripts/harvest_static.py` (copied into OUTDIR first) |
| Hand-writing replacement extraction scripts instead of harvesting | Modify the copied harvest script in OUTDIR and rerun |
| Repeating a failing grep/command ≥2 times | Change strategy: read tool logs, adjust harvest, consult reference.md |
| Running the original `scripts/` directly as final result | Copy to OUTDIR, adapt to the target, record changes in CHANGES.md |
| Real usernames/passwords, OTP, OAuth auth | Stub/mock as above |
| Skipping stubs to "get real data" and do IDOR/injection tests | Record outbound only; this is recon |
| Deleting, exporting sensitive data, bulk writes | Coverage clicking included |
| Claiming all pages/APIs are captured without runtime + dynamic enumeration | See Definition of Done or state limitations |
| Claiming all parameters are known without the trigger matrix + diff | Phase 3b matrix + Phase 5 diff |
| Inferring required/optional from one runtime sample | Multi-sample diff or validation rules / error inference |

## Two-layer model and run modes

| Layer | Produces | Ceiling |
|---|---|---|
| Static (JS bundle) | Full endpoint paths, route drafts, payload-field candidates | No HTTP method; parameters need Phase 1b; misses runtime-concatenated URLs |
| Runtime (live session) | Method + body + response + dynamic URL + WS/SSE; multi-sample diff completes parameters | A page must actually render to call; one sample cannot fix required/optional |

| Mode | Engine | Fits |
|---|---|---|
| depth | `runtime_harvest.js` (Puppeteer) | API inventory, METHOD/params/response bodies, WS/SSE, reproducible batch runs |
| coverage | browser + `preload.js` | Click tabs/dialogs/tables; deeper feature-point coverage |
| both | depth first, then coverage | Most complete; longest |

**Parameter methodology** (no universal script): paths come from harvest/regex; parameters come from anchor-window expansion + UI binding chains + multi-sample diff + error inference (grep recipes in [reference.md](reference.md), section J).

## Definition of Done

All required before claiming recon complete:

- [ ] Static: Phase 1 harvest produced `api_static.txt`, `routes.txt`, `js/`
- [ ] Runtime: at least depth or coverage; coverage/both require hook active + dynamic enumeration loop
- [ ] Shell entry: business paths do not redirect to `/login` (mind hash routing)
- [ ] Parameters: coverage/both completed the trigger matrix + `param_samples.json`; Phase 5 merged `params_merged.json`
- [ ] Depth (if module pages are blank): Phase 4 permission-tree reconstruction rerun until module-level APIs appear (not only locale/bootstrap)
- [ ] Delivery: Phase 5 outputs complete; log every discovered service and endpoint asset in your working notes

## Scripts and gates

`scripts/` are reference templates only; **never run the originals verbatim as the final result.**

Rule: read first → adapt to target → write into OUTDIR (e.g. `recon/`) → record `CHANGES.md`; if a template does not fit, rewrite from the methodology and borrow only its structure.

| Gate | When | Reference script → OUTDIR copy | Common required edits |
|---|---|---|---|
| A (static) | After Phase 0, before the **first** harvest/spider run | `harvest_static.py` / `spider_mpa.py` | Default regex works for most sites; change endpoint regex, webpack/Vite `publicPath`, MPA exclude/cookie only when manifest/dialect mismatch |
| B (runtime) | After Phase 2, before depth/coverage | `runtime_harvest.js` / `preload.js` + `config.json` | Cookie/localStorage keys, neutralize success values, stubs, login regex, API prefix, hash/history |

**Mandatory SPA order** (do not swap; phase numbering outranks "explore then script"):

| Step | Must | Forbidden |
|---|---|---|
| After Phase 0 | Next Bash = `python3 OUTDIR/harvest_static.py <URL> OUTDIR` | curl/grep/Read the main entry `index-*.js` (usually >500KB) |
| Gate A | Copy script → small optional edit → **run immediately** | Hand-extract APIs before deciding to harvest |
| Before Phase 1 done | Verify output with `wc -l`; on 404 adjust harvest and retry | Hand-written extract scripts; repeated greps of undownloaded URLs |
| From Phase 1b | grep only `OUTDIR/js/*.js` | Using the main bundle instead of harvest |

- Copy `harvest_static.py` → (optional) edit regex → **run immediately**
- curl the main bundle → grep repeatedly → write a throwaway extract → harvest last: wrong order
- MPA: after Phase 0 the next Bash = `python3 OUTDIR/spider_mpa.py ...`

## Tool and output constraints

| Constraint | Detail |
|---|---|
| Large files | Never Read/grep `index-*.js` >100KB into context; batch-process with OUTDIR scripts |
| grep output | Always pipe to `head -20` or `-m 5`; keep only path summaries in chat, never paste bundle fragments |
| Verification | Use `wc -l`, `ls \| wc -l`; do not Read whole directories |
| Regex probing | Optional, ≤1 time, only ≤50KB chunks or HTML; formal static results come from harvest |
| Reference | Recipes/templates/troubleshooting in [reference.md](reference.md); do not inline it |

## Execution roadmap

```
Phase 0 classify + OUTDIR
  → Gate A → Phase 1 harvest (★ run immediately ★)
  → Phase 1b parameter reverse-engineering
  → Phase 2 auth three gates → config.json
  → Gate B → Phase 3 runtime + parameter matrix
  → Phase 4 permission tree (when needed) → rerun Phase 3
  → Phase 5 merge report + log all discovered assets
```

Check off in order; do not enter the next phase before the previous one is done.

1. [ ] **Phase 0**: classify SPA/MPA; create OUTDIR → see Phase 0 below
2. [ ] **Gate A + Phase 1**: copy script → **immediately** harvest → verify with `wc -l` → Phase 1 below
3. [ ] **Phase 1b**: anchor windows + binding layer → `param_candidates.json` → Phase 1b below
4. [ ] **Phase 2**: three auth gates → `config.json` → Phase 2 below
5. [ ] **Gate B**: adjust runtime scripts → Phase 3 below
6. [ ] **Phase 3**: depth / coverage / both; confirm shell entry; trigger matrix → `param_samples.json`
7. [ ] **Phase 4** (if needed): permission tree → patch stubs → rerun Phase 3 → Phase 4 below
8. [ ] **Phase 5**: merge outputs + report + log assets → Phase 5 below

## Phase 0 — Classify

Fetch the entry HTML, **create OUTDIR** (do not modify the skill's own `scripts/`):

- **SPA**: empty shell + `<div id=app>` + chunks → Phases 1–5
- **MPA**: SSR + `<form>`, no endpoint bundle → after Gate A:

```bash
python3 recon/spider_mpa.py <BASE_URL> <OUTDIR> [--cookie "session=..."] [--max 300] [--depth 5] [--exclude "logout|delete|destroy"]
```

Outputs `forms.txt`, `links.txt`, `api_inline.txt`. For a SPA with ≈0 forms, switch to Phase 1.

## Phase 1 — Static

Follow [Scripts and gates](#scripts-and-gates) · [Tool and output constraints](#tool-and-output-constraints).

```bash
python3 recon/harvest_static.py <BASE_URL> <OUTDIR>
```

Harvest: parse HTML scripts → webpack/Vite manifest → download all lazy chunks → produce `js/`, `api_static.txt`, `routes.txt`, `chunkmap.txt`.

```bash
wc -l OUTDIR/api_static.txt OUTDIR/routes.txt
ls OUTDIR/js | wc -l
```

- Chunk count vs manifest: on 404 adjust harvest and retry; do not hand-curl chunks one by one
- `api_static.txt` too few → relax the endpoint regex inside OUTDIR and rerun (see reference)

### Phase 1b — Parameter reverse-engineering

Paths come from Phase 1; parameter fields need separate recon. Follow grep rules in [Tool and output constraints](#tool-and-output-constraints).

**Completion standard:** for important APIs answer: field name, transport location, type inference, required/optional, sample value, confidence.

#### 1b.0 — Transport shape

| Shape | Where parameters live | Static priority |
|---|---|---|
| REST JSON | body + query | `(params\|data\|body)\s*:\s*\{\}` next to the path anchor |
| GraphQL | `variables` | gql templates, `$page: Int` |
| Classic form | urlencoded | `<form>`, `FormData` |
| File upload | multipart | `FormData.append` |
| Path parameter | `/user/:id` | Route table + `useParams` / `$route.params` |
| Encrypted/signed | wrapped in `sign`/`data` | Hook encryption-function inputs (reference §D) |

Output: annotate each API with `transport: query|json|form|graphql|encrypted`.

#### 1b.1 — Anchor-window expansion

Using a known path as anchor, widen the window to find the payload object:

```bash
grep -n '"/api/user/list"' OUTDIR/js/*.js | head -20
grep -rhoaE '.{0,120}("/api[^"]+").{0,200}' OUTDIR/js/*.js | head -20
grep -rhoaE '(params|data|body|payload)\s*:\s*\{' OUTDIR/js/*.js | head -20
```

| Wrapper | Parameter clue |
|---|---|
| axios instance | `data` / `params` |
| Unified request | Interceptors inject global fields |
| OpenAPI client | Generated method signatures |
| React Query / SWR | Hook second argument |
| Vue composable | Composable argument |

Type residue: `yup`/`zod`/rules, `Form.Item name=`, embedded Swagger.

→ `param_candidates.json`: `{ path, fields[], source: "static-callsite", confidence }`

#### 1b.2 — Binding layer

```
Form field → onFinish/handleSubmit → transform → API payload
```

| Binding source | Technique |
|---|---|
| Form submit | Follow submit → transform → API |
| Table search | `getFieldsValue()` → `params` |
| Route | `:id` / `?tab=` |
| Interceptor | Global `tenantId`, pagination, sign |
| Enum select | `options` → API enum values |

In DevTools, walk the call stack upward from `fetch`/`XHR.send` to the packet-building function.

#### 1b.3 — Three payload questions (≠ Phase 2 auth gates)

| Question | Answer |
|---|---|
| **Assembly** | Where payload builds, transform traces |
| **Validation** | required, pattern, enum |
| **Transport** | path / query / body / multipart / headers |

While reading the Phase 2 interceptor gate, also capture globally injected fields (Authorization, `X-Tenant-Id`, sign).

#### 1b.4 — Bridge to Phase 3

Candidate fields come from static/binding layers; required/optional/conditional dependency must be settled by the Phase 3 parameter matrix + diff + Phase 5 error inference.

## Phase 2 — Three auth gates

Grep in `OUTDIR/js/` (with `head`), write conclusions into `config.json` (recipes in reference):

| Gate | Question | Keywords |
|---|---|---|
| **Render gate** | How is "logged in" judged? | `isLogin`, `getToken`, Cookie/localStorage |
| **Interceptor gate** | What triggers `/login` redirect? | `response_code`, `errno`, axios interceptor |
| **Content gate** | Where do menus/permissions come from? | `menu`, `permission`, `role`, `acl`, `routes` |

Never treat a localStorage key name as a credential — confirm it from the chunk/request chain.

**Exit = Gate B**: land conclusions in `config.json`, and adapt `OUTDIR/runtime_harvest.js` / `preload.js`.

### Phase 2b — API observation (optional)

Use OUTDIR `preload.js` to confirm session key names, Authorization, nested API URLs:

| Setting | Output |
|---|---|
| `recordDetail: true` | `__API_RECON_DETAIL__` |
| `observe.xhrHeaders: true` | Header observation |
| `extractUrlsFromResponse: true` | Sub-APIs inside responses |
| `observe.storageReads/cookieReads: true` | Backfill config |
| `neutralizeVueRouter: true` | `__API_RECON_ROUTES__` |

Each coverage round exports: `__API_RECON_LOG__`, `__API_RECON_DETAIL__`, `__API_RECON_ROUTES__`, `__API_RECON_OBSERVE__`.

## Phase 3 — Runtime

Gate B must be passed; follow [Boundaries and prohibitions](#boundaries-and-prohibitions-read-before-acting-crossing-them-is-out-of-scope) · credential-free mock strategy.

Set `config.json` `"runtimeMode": "depth" | "coverage" | "both"` (template in reference).

### Hook and stub (shared by depth + coverage)

| Layer | Scope | Purpose |
|---|---|---|
| L1 precise | auth/permission/bootstrap stubs | Pass first-screen auth |
| L2 negative patch | All JSON responses | Unauthenticated code → success |
| L3 fallback | `/api` etc. not hit by L1 | Empty success body, pry open UI |

- **depth**: fake auth + `forward` rewrites business code + `stubs`; traverse `routes` (hash/history); output `runtime_api.json`
- **coverage**: inject `preload.js` at document-start (CDP `addScriptToEvaluateOnNewDocument` or userscript)

Verify: `window.__API_RECON_PRELOAD__` exists; business paths do not return to `/login`.

```bash
cd recon && npm install
node runtime_harvest.js config.json
```

### 3b — Coverage dynamic enumeration (required)

1. Main nav/sidebar — click each item, wait 1–3s for network
2. Tabs — `role=tab`, `.ant-tabs-tab`
3. Tables — first-row view/edit/detail
4. Toolbars — export, filter, new (**avoid irreversible delete**)
5. On entering each module — merge API/route
6. SPA — controlled `pushState` for uncovered paths in `routes.txt` (forbidden for MPA)

**Parameter trigger matrix (required):** record each module once per operation type; **diff multiple samples**:

| Operation | Usually added parameters |
|---|---|
| List first screen | Pagination + default filters |
| Click search | keyword, filter |
| Advanced filter | More optional fields |
| Create/edit | Full entity |
| Bulk/export/sort | `ids[]`, `exportType`, `sortField` |

Under stubs, outbound body/headers are still real — trust the request. Recording → `scan_raw.json`, `param_samples.json`, `api_detail.json`.

- **Vue**: `neutralizeVueRouter: true` + document-start preload
- **React**: `routes.txt` + sidebar clicks + `pushState`
- **both**: 3a depth first, then 3b coverage

## Phase 4 — Permission-tree reconstruction

**Trigger:** module pages blank / every route returns only bootstrap (e.g. locale) → content gate not passed.

| Symptom | Meaning |
|---|---|
| Shell entry succeeded | Render + interceptor gates passed |
| Sidebar items missing / click blank | Stub shape or incomplete permission codes |
| Every route calls the same few APIs | `v-if permission` not passed |
| `routes.txt` far fewer than bundle | Must complete from the auth module |

```bash
grep -rhoaE '"/api[^"]*(permission|perm|role|menu|acl)[^"]*"' OUTDIR/js/*.js | sort -u | head -30
grep -rhoaE 'userRouteAuth|getResultTree|routeMap|routeLink|menuList|authList' OUTDIR/js/*.js | head -20
```

Typical chain: `role_permissions` (flat codes) + `permissions/all` (tree) → `getResultTree` → `userRouteAuth[CODE].url`.

```bash
python3 recon/extract_route_map.py recon/js recon/
python3 recon/build_perm_tree.py recon/js recon/ --config recon/config.json
```

Intermediate outputs: `route_map.json`, `userRouteAuth.json`, `permissions_tree.json`, `*_stub.json`, `perm_codes_all.txt`.

Stub check: outer `response_code` matches the interceptor gate; flat codes align with the tree; `routes` cover every link in `route_map`. After updating `config.json`, **rerun Phase 3**. Large SPAs may tune `waitUntil`, `routeTimeout`, `perRouteMs` (reference §A3/J).

## Phase 5 — Merge and report

### Output table

| File | Phase | Content |
|---|---|---|
| `js/`, `api_static.txt`, `routes.txt`, `chunkmap.txt` | 1 | Static bundle and paths |
| `param_candidates.json` | 1b | Static parameter-field candidates |
| `config.json` | 2 | Three gates + runtime config |
| `runtime_api.json` | 3a | Depth detailed recording (incl. WS/SSE) |
| `param_samples.json`, `scan_raw.json`, `api_detail.json` | 3b | Multi-sample, click logs, detail |
| `route_map.json` etc. | 4 | Permission-tree intermediates (if run) |
| `params_merged.json` | 5 | Merged parameter fields + confidence |
| `api_merged.txt` | 5 | `METHOD /path [params] [static|runtime|both]` |
| `site_map.json` | 5 | Routes, APIs, params, feature points, limitations |
| Working notes | 5 | Log every service and endpoint asset found |

### 5b — Parameter merge

Diff from `param_samples.json`; no universal merge script. Confidence rules in reference §J7 (high/medium/low/to-trigger).

### 5c — Error inference

Within authorization, send incomplete requests and read 400s (**parameter recon, not vulnerability testing**): `field 'x' is required`, enum errors, etc. Mind the `data` wrapper, `variables`, `bizData` before encryption.

The report must state: runtimeMode, static/runtime API counts, parameter confidence, uncovered modules, CHANGES.md summary vs the reference scripts.

Suggested `site_map.json` shape:

```json
{
  "site": "https://example.com",
  "runtimeMode": "both",
  "appType": "vue-spa",
  "routeGuardStrategy": ["nav-neutralize", "L1-auth", "L2-patch", "forward"],
  "apisFromStatic": [],
  "apisFromRuntime": [],
  "apis": [],
  "params": [{ "method": "POST", "path": "/api/user/list", "transport": "json", "fields": [] }],
  "frontendRoutes": [],
  "routesVerifiedByClick": [],
  "featuresTriggered": [],
  "limitations": ""
}
```

More fields and grep recipes in [reference.md](reference.md).

## General notes

- Framework-agnostic: webpack/Vite/Angular lazy loading works the same way
- Transport: REST/JSON, GraphQL, WebSocket, SSE; gRPC-web out of scope
- SSR: client fetch recordable; RSC/Server Actions not fully enumerable
- Blind spots: JSVMP, WASM, HMAC/mTLS strict checks → static + state the limitation
- Parameter blind spots: conditional linkage, hidden params, WASM packet building → `to-trigger` / `unreachable`
- Static is the safety net: when runtime is blocked, static still enumerates endpoints

## Additional resources

- Grep recipes, `config.json` template, troubleshooting, hooks, parameter reverse-engineering §J, site_map template: **[reference.md](reference.md)**
- Reference script paths: see [Scripts and gates](#scripts-and-gates)

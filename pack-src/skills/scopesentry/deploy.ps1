# deploy.ps1 — optional, agent-assisted single-host deployment of ScopeSentry.
#
# Run ONLY when the operator explicitly asks to deploy ScopeSentry. This script
# starts Docker (if installed but stopped), clones the official repository,
# writes local credentials, brings up the four containers, and waits for the
# Web UI. It never touches anything outside its own install directory.
#
# Prerequisites the script cannot provide: Docker Desktop installed and able to
# run Linux containers, git, an outbound network connection for image pulls.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File deploy.ps1
#   powershell -ExecutionPolicy Bypass -File deploy.ps1 -InstallDir D:\ss

param(
    [string]$InstallDir = "$env:USERPROFILE\scopesentry",
    [int]$HealthTimeoutSec = 300
)

$ErrorActionPreference = 'Stop'

function Say($m) { Write-Host "[scopesentry-deploy] $m" }

# 1. Docker engine: try once to start Docker Desktop if the CLI exists but the
#    daemon answers nothing. We do not install Docker.
function Test-Docker {
    try { docker info --format '{{.ServerVersion}}' 2>$null | Out-Null; return $true }
    catch { return $false }
}

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    throw "Docker CLI not found. Install Docker Desktop first, then rerun."
}

if (-not (Test-Docker)) {
    $dd = "$env:ProgramFiles\Docker\Docker\Docker Desktop.exe"
    if (Test-Path $dd) {
        Say "Docker engine stopped; launching Docker Desktop, waiting up to 90s..."
        Start-Process $dd | Out-Null
        $deadline = (Get-Date).AddSeconds(90)
        while ((Get-Date) -lt $deadline) {
            Start-Sleep -Seconds 5
            if (Test-Docker) { break }
        }
    }
}

if (-not (Test-Docker)) {
    throw "Docker engine is not reachable. Start Docker Desktop manually and wait for it to finish starting, then rerun."
}
Say "Docker engine OK."

# 2. Repository: clone once, pull updates afterwards.
$repo = Join-Path $InstallDir 'ScopeSentry'
if (-not (Test-Path $repo)) {
    New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
    Say "Cloning https://github.com/Autumn-27/ScopeSentry into $repo ..."
    git clone https://github.com/Autumn-27/ScopeSentry.git $repo
} else {
    Say "Reusing existing checkout at $repo (git pull)."
    Push-Location $repo; git pull; Pop-Location
}

# 3. Local credentials: write .env once, never overwrite an existing one.
$envFile = Join-Path $repo '.env'
if (-not (Test-Path $envFile)) {
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    function New-Pw {
        $b = New-Object byte[] 24; $rng.GetBytes($b)
        return ([Convert]::ToBase64String($b)).Replace('+','').Replace('/','').Replace('=','')
    }
    $mongoUser = 'root'
    $mongoPass = New-Pw
    $redisPass = New-Pw
    @"
MONGO_INITDB_ROOT_USERNAME=$mongoUser
MONGO_INITDB_ROOT_PASSWORD=$mongoPass
REDIS_PASSWORD=$redisPass
"@ | Set-Content -Path $envFile -Encoding ascii
    Say "Wrote $envFile with generated passwords (existing values are never overwritten)."
} else {
    Say "$envFile exists; keeping it."
}

# 4. Bring up the four containers (web, scan, mongo, redis).
$compose = Join-Path $repo 'single-host-deployment.yml'
if (-not (Test-Path $compose)) { throw "Missing $compose" }
Say "Starting containers (first pull downloads ~1.15 GB; this can take a while)..."
docker compose -f $compose up -d
if ($LASTEXITCODE -ne 0) { docker-compose -f $compose up -d }

# 5. Wait for the Web UI. MongoDB initialization with bundled data is slow.
Say "Waiting for http://127.0.0.1:8082 (MongoDB init may take minutes)..."
$deadline = (Get-Date).AddSeconds($HealthTimeoutSec)
$ready = $false
while ((Get-Date) -lt $deadline) {
    try {
        $r = Invoke-WebRequest -Uri 'http://127.0.0.1:8082' -UseBasicParsing -TimeoutSec 5
        if ($r.StatusCode -lt 500) { $ready = $true; break }
    } catch { Start-Sleep -Seconds 10 }
}

if (-not $ready) {
    Say "Web UI did not answer within ${HealthTimeoutSec}s. Check: docker compose -f `"$compose`" logs."
    exit 1
}

Say "Web UI reachable at http://127.0.0.1:8082 (default login ScopeSentry / ScopeSentry; change it)."
Say "NEXT: sign in, open the API Key page, create an ssk_... key, then set:"
Say "  `$env:SS_BASE_URL='http://127.0.0.1:8082'"
Say "  `$env:SS_API_KEY='ssk_...'"
Say "Verify with: node <skill-dir>/ssclient.js health"

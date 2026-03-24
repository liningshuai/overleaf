Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-EnvValue {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Key
  )

  $line = Get-Content ".env" | Where-Object { $_ -match "^\s*$Key=" } | Select-Object -First 1
  if (-not $line) {
    throw "Cannot find '$Key' in .env"
  }
  return ($line -split "=", 2)[1].Trim()
}

$adminEmail = Get-EnvValue -Key "OVERLEAF_ADMIN_EMAIL"
$adminPassword = Get-EnvValue -Key "OVERLEAF_ADMIN_PASSWORD"
$siteUrl = Get-EnvValue -Key "OVERLEAF_SITE_URL"

Write-Host "Starting Overleaf stack..."
docker compose up -d --build

Write-Host "Ensuring Mongo replica set is initialized..."
$mongoReady = $false
for ($i = 0; $i -lt 60; $i += 1) {
  try {
    docker compose exec -T mongo mongosh --quiet --eval "try { rs.status().ok } catch (e) { rs.initiate({_id:'overleaf',members:[{_id:0,host:'mongo:27017'}]}); }" | Out-Null
    if ($LASTEXITCODE -eq 0) {
      $mongoReady = $true
      break
    }
  } catch {
    # Keep waiting until mongod accepts commands
  }
  Start-Sleep -Seconds 3
}

if (-not $mongoReady) {
  throw "Mongo did not become ready in time. Check logs with: docker compose logs -f mongo"
}

Write-Host "Waiting for Mongo PRIMARY election..."
$mongoPrimary = $false
for ($i = 0; $i -lt 60; $i += 1) {
  try {
    $state = docker compose exec -T mongo mongosh --quiet --eval "try { rs.status().members.find(m => m.self).stateStr } catch (e) { '' }"
    if ($LASTEXITCODE -eq 0 -and $state -match "PRIMARY") {
      $mongoPrimary = $true
      break
    }
  } catch {
    # Keep waiting
  }
  Start-Sleep -Seconds 2
}

if (-not $mongoPrimary) {
  throw "Mongo replica set did not elect PRIMARY in time. Check logs with: docker compose logs -f mongo"
}

Write-Host "Waiting for Overleaf service to become ready..."
$ready = $false
for ($attempt = 0; $attempt -lt 120; $attempt += 1) {
  try {
    $resp = Invoke-WebRequest -Uri "$siteUrl/login" -UseBasicParsing -TimeoutSec 5
    if ($resp.StatusCode -ge 200 -and $resp.StatusCode -lt 500) {
      $ready = $true
      break
    }
  } catch {
    # Continue waiting
  }
  Start-Sleep -Seconds 5
}

if (-not $ready) {
  throw "Overleaf did not become ready in time. Check logs with: docker compose logs -f sharelatex"
}

Write-Host "Checking existing admin users..."
$adminCountRaw = docker compose exec -T mongo mongosh --quiet --eval "db.getSiblingDB('sharelatex').users.countDocuments({isAdmin:true})"
$adminCount = [int]($adminCountRaw.Trim())

if ($adminCount -eq 0) {
  Write-Host "Creating first admin account via Launchpad: $adminEmail"
  $tmpDir = Join-Path $PWD ".tmp"
  New-Item -ItemType Directory -Force -Path $tmpDir | Out-Null
  $cookieFile = Join-Path $tmpDir "setup-cookies.txt"
  $launchpadHtml = Join-Path $tmpDir "launchpad.html"

  if (Test-Path $cookieFile) {
    Remove-Item $cookieFile -Force
  }

  curl.exe -s -c $cookieFile "$siteUrl/launchpad" -o $launchpadHtml | Out-Null
  $content = Get-Content $launchpadHtml -Raw
  $csrf = ([regex]::Match($content, 'name="ol-csrfToken" content="([^"]+)"')).Groups[1].Value
  if (-not $csrf) {
    throw "Cannot extract Launchpad CSRF token. Open $siteUrl/launchpad manually and check status."
  }

  $registerResponse = curl.exe -s -w "`n%{http_code}" `
    -b $cookieFile `
    -c $cookieFile `
    -H "X-CSRF-Token: $csrf" `
    -H "Content-Type: application/x-www-form-urlencoded" `
    --data-urlencode "_csrf=$csrf" `
    --data-urlencode "email=$adminEmail" `
    --data-urlencode "password=$adminPassword" `
    "$siteUrl/launchpad/register_admin"

  $responseParts = $registerResponse -split "`n"
  $statusCode = $responseParts[-1].Trim()
  $responseBody = ($responseParts[0..($responseParts.Length - 2)] -join "`n").Trim()

  if ($statusCode -ne "200") {
    throw "Launchpad admin creation failed (HTTP $statusCode). Body: $responseBody"
  }
  if ($responseBody -notmatch "redir") {
    throw "Launchpad admin creation returned unexpected response: $responseBody"
  }

  if (Test-Path $launchpadHtml) {
    Remove-Item $launchpadHtml -Force
  }
  if (Test-Path $cookieFile) {
    Remove-Item $cookieFile -Force
  }
} else {
  Write-Host "At least one admin already exists; skip bootstrap account creation."
}

$tmpLaunchpad = Join-Path $PWD ".tmp\\launchpad.html"
$tmpCookies = Join-Path $PWD ".tmp\\setup-cookies.txt"
if (Test-Path $tmpLaunchpad) {
  Remove-Item $tmpLaunchpad -Force
}
if (Test-Path $tmpCookies) {
  Remove-Item $tmpCookies -Force
}

$adminReadyRaw = docker compose exec -T mongo mongosh --quiet --eval "db.getSiblingDB('sharelatex').users.countDocuments({email:'$adminEmail',isAdmin:true})"
$adminReadyCount = [int]($adminReadyRaw.Trim())
if ($adminReadyCount -lt 1) {
  throw "Admin account '$adminEmail' was not found after setup."
}

Write-Host ""
Write-Host "Overleaf is ready at: $siteUrl"
Write-Host "Admin email: $adminEmail"
Write-Host "Admin password: $adminPassword"

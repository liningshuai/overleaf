param(
  [string]$BackupDir = ".\backup",
  [switch]$SkipStart
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-EnvValueFromFile {
  param(
    [Parameter(Mandatory = $true)]
    [string]$FilePath,
    [Parameter(Mandatory = $true)]
    [string]$Key
  )

  if (-not (Test-Path $FilePath)) {
    return $null
  }

  $line = Get-Content $FilePath | Where-Object { $_ -match "^\s*$Key=" } | Select-Object -First 1
  if (-not $line) {
    return $null
  }

  return ($line -split "=", 2)[1].Trim()
}

function Invoke-CheckedCommand {
  param(
    [Parameter(Mandatory = $true)]
    [scriptblock]$Command,
    [Parameter(Mandatory = $true)]
    [string]$FailureMessage
  )

  & $Command
  if ($LASTEXITCODE -ne 0) {
    throw $FailureMessage
  }
}

if (-not (Test-Path $BackupDir)) {
  throw "Backup directory not found: $BackupDir"
}

$resolvedBackupDir = (Resolve-Path $BackupDir).Path
$envBackupPath = Join-Path $resolvedBackupDir ".env.backup"

if (-not (Test-Path ".env") -and (Test-Path $envBackupPath)) {
  Copy-Item $envBackupPath ".env"
  Write-Host "Restored .env.backup to .env. Review OVERLEAF_SITE_URL before exposing the service."
}

$projectName = Get-EnvValueFromFile -FilePath ".env" -Key "COMPOSE_PROJECT_NAME"
if (-not $projectName) {
  $projectName = Get-EnvValueFromFile -FilePath $envBackupPath -Key "COMPOSE_PROJECT_NAME"
}
if (-not $projectName) {
  $projectName = "overleaf20"
}

$volumeKeys = @(
  "overleaf_data",
  "overleaf_logs",
  "mongo_data",
  "redis_data"
)

Write-Host "Stopping Docker Compose stack before restore..."
Invoke-CheckedCommand -Command { docker compose down } -FailureMessage "Failed to stop the Docker Compose stack."

foreach ($volumeKey in $volumeKeys) {
  $volumeName = "$projectName`_$volumeKey"
  $archivePath = Join-Path $resolvedBackupDir "${volumeName}.tgz"

  if (-not (Test-Path $archivePath)) {
    throw "Backup archive not found: $archivePath"
  }

  Write-Host "Restoring volume: $volumeName"
  Invoke-CheckedCommand -Command { docker volume create $volumeName } -FailureMessage "Failed to create Docker volume: $volumeName"
  Invoke-CheckedCommand `
    -Command {
      docker run --rm `
        -v "${volumeName}:/volume" `
        -v "${resolvedBackupDir}:/backup" `
        alpine sh -c "find /volume -mindepth 1 -maxdepth 1 -exec rm -rf {} + && tar xzf /backup/${volumeName}.tgz -C /volume"
    } `
    -FailureMessage "Failed to restore volume: $volumeName"
}

if (-not $SkipStart) {
  Write-Host "Starting Docker Compose stack..."
  Invoke-CheckedCommand -Command { docker compose up -d --build } -FailureMessage "Failed to start the Docker Compose stack."
}

Write-Host ""
Write-Host "Restore completed."
Write-Host "If you changed OVERLEAF_SITE_URL, restart again with: docker compose down ; docker compose up -d --build"

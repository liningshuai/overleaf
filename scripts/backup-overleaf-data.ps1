param(
  [string]$OutputDir = ".\backup",
  [switch]$StopStack
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-EnvValue {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Key
  )

  if (-not (Test-Path ".env")) {
    return $null
  }

  $line = Get-Content ".env" | Where-Object { $_ -match "^\s*$Key=" } | Select-Object -First 1
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

$projectName = Get-EnvValue -Key "COMPOSE_PROJECT_NAME"
if (-not $projectName) {
  $projectName = "overleaf20"
}

$volumeKeys = @(
  "overleaf_data",
  "overleaf_logs",
  "mongo_data",
  "redis_data"
)

$resolvedOutputDir = (New-Item -ItemType Directory -Path $OutputDir -Force).FullName

if ($StopStack) {
  Write-Host "Stopping Docker Compose stack for a consistent backup..."
  Invoke-CheckedCommand -Command { docker compose down } -FailureMessage "Failed to stop the Docker Compose stack."
}

foreach ($volumeKey in $volumeKeys) {
  $volumeName = "$projectName`_$volumeKey"
  $volumeExists = docker volume ls --format "{{.Name}}" | Where-Object { $_ -eq $volumeName }
  if (-not $volumeExists) {
    throw "Docker volume not found: $volumeName"
  }

  Write-Host "Backing up volume: $volumeName"
  Invoke-CheckedCommand `
    -Command {
      docker run --rm `
        -v "${volumeName}:/volume:ro" `
        -v "${resolvedOutputDir}:/backup" `
        alpine sh -c "cd /volume && tar czf /backup/${volumeName}.tgz ."
    } `
    -FailureMessage "Failed to back up volume: $volumeName"
}

if (Test-Path ".env") {
  Copy-Item ".env" (Join-Path $resolvedOutputDir ".env.backup") -Force
}

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
@(
  "Created: $timestamp"
  "Compose project name: $projectName"
  "Volumes:"
  ($volumeKeys | ForEach-Object { " - $projectName`_$_" })
) | Set-Content (Join-Path $resolvedOutputDir "backup-info.txt")

Write-Host ""
Write-Host "Backup completed."
Write-Host "Output directory: $resolvedOutputDir"
Write-Host "Copy this folder to the new computer before restoring."

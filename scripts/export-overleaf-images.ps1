param(
  [string]$OutputFile = ".\backup\overleaf-images.tar"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Assert-ImageExists {
  param(
    [Parameter(Mandatory = $true)]
    [string]$ImageName
  )

  $imageId = docker image inspect $ImageName --format "{{.Id}}" 2>$null
  if ($LASTEXITCODE -ne 0 -or -not $imageId) {
    throw "Docker image not found locally: $ImageName"
  }
}

$images = @(
  "local/sharelatex:texlive2025-environ",
  "mongo:8.0",
  "redis:7.2",
  "alpine:latest"
)

foreach ($image in $images) {
  Assert-ImageExists -ImageName $image
}

$parentDir = Split-Path -Parent $OutputFile
if ($parentDir) {
  New-Item -ItemType Directory -Force -Path $parentDir | Out-Null
}

$resolvedOutputPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputFile)

Write-Host "Exporting Docker images to: $resolvedOutputPath"
docker save -o $resolvedOutputPath $images

if ($LASTEXITCODE -ne 0) {
  throw "Failed to export Docker images."
}

Write-Host ""
Write-Host "Image export completed."
Write-Host "Copy this file to the new computer:"
Write-Host " - $resolvedOutputPath"

param(
  [string]$InputFile = ".\backup\overleaf-images.tar"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not (Test-Path $InputFile)) {
  throw "Image archive not found: $InputFile"
}

$resolvedInputPath = (Resolve-Path $InputFile).Path

Write-Host "Importing Docker images from: $resolvedInputPath"
docker load -i $resolvedInputPath

if ($LASTEXITCODE -ne 0) {
  throw "Failed to import Docker images."
}

Write-Host ""
Write-Host "Image import completed."

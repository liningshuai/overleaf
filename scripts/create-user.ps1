param(
  [Parameter(Mandatory = $true)]
  [string]$Email,

  [switch]$Admin
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scriptPath = "/overleaf/services/web/modules/server-ce-scripts/scripts/create-user.mjs"

Write-Host "Creating user: $Email"

if ($Admin) {
  $output = docker compose exec -T -w /overleaf/services/web sharelatex node $scriptPath --email="$Email" --admin 2>&1
} else {
  $output = docker compose exec -T -w /overleaf/services/web sharelatex node $scriptPath --email="$Email" 2>&1
}

if ($LASTEXITCODE -ne 0) {
  $output | ForEach-Object { Write-Host $_ }
  throw "Failed to create user: $Email"
}

$textOutput = ($output | Out-String -Width 4096)
$activationLink = $null
$setPasswordMatches = [regex]::Matches($textOutput, "Set password:\s*(https?://\S+)")
if ($setPasswordMatches.Count -gt 0) {
  $activationLink = $setPasswordMatches[$setPasswordMatches.Count - 1].Groups[1].Value
} else {
  $activationMatches = [regex]::Matches($textOutput, "https?://\\S+/user/activate\\?token=\\S+")
  if ($activationMatches.Count -gt 0) {
    $activationLink = $activationMatches[$activationMatches.Count - 1].Value
  }
}

if ($activationLink) {
  $activationLink = ($activationLink -replace "\\r.*$", "")
  $activationLink = ($activationLink -replace "\\n.*$", "")
  $activationLink = ($activationLink -replace "\"".*$", "")
  Write-Host "Activation link: $activationLink"
} else {
  Write-Host "Could not automatically extract activation link."
  $output | ForEach-Object { Write-Host $_ }
}

Write-Host ""
Write-Host "Copy the generated activation link and send it to the user."

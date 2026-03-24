param(
  [Parameter(Mandatory = $true)]
  [string]$FilePath,

  [switch]$Admin
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not (Test-Path $FilePath)) {
  throw "File not found: $FilePath"
}

$emails = Get-Content $FilePath |
  ForEach-Object { $_.Trim() } |
  Where-Object { $_ -and -not $_.StartsWith("#") }

if (-not $emails -or $emails.Count -eq 0) {
  throw "No valid emails found in: $FilePath"
}

$failed = @()

foreach ($email in $emails) {
  try {
    if ($Admin) {
      .\scripts\create-user.ps1 -Email $email -Admin
    } else {
      .\scripts\create-user.ps1 -Email $email
    }
    Write-Host "----------------------------------------"
  } catch {
    Write-Host "Failed: $email"
    Write-Host $_.Exception.Message
    Write-Host "----------------------------------------"
    $failed += $email
  }
}

if ($failed.Count -gt 0) {
  Write-Host ""
  Write-Host "Completed with failures for:"
  $failed | ForEach-Object { Write-Host " - $_" }
  exit 1
}

Write-Host ""
Write-Host "All users created successfully."

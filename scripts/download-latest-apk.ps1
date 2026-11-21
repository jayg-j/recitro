# Download arm64 release APK from the latest successful GitHub Actions run (requires gh auth).
param(
  [string]$OutDir = ""
)

$ErrorActionPreference = "Stop"
$root = if ($OutDir) { $OutDir } else { Split-Path -Parent $MyInvocation.MyCommand.Path | Split-Path -Parent }
$dest = Join-Path $root "build\app\outputs\flutter-apk"
New-Item -ItemType Directory -Force -Path $dest | Out-Null

$gh = Get-Command gh -ErrorAction SilentlyContinue
if (-not $gh) {
  Write-Host "Install GitHub CLI, then: gh auth login" -ForegroundColor Yellow
  Write-Host "Or download manually: https://github.com/jayg-j/recitro/actions" -ForegroundColor Yellow
  exit 1
}

$runId = gh run list --repo jayg-j/recitro --workflow build-apk.yml --limit 1 --json databaseId,conclusion -q '.[0] | select(.databaseId) | .databaseId'
if (-not $runId) { Write-Error "No workflow runs found." }

Write-Host "Downloading artifacts from run $runId..." -ForegroundColor Cyan
Push-Location $dest
gh run download $runId --repo jayg-j/recitro --name recitro-release-apk
Pop-Location

Get-ChildItem $dest -Filter "*release*.apk" | ForEach-Object {
  Write-Host "APK: $($_.FullName) ($([math]::Round($_.Length/1MB,1)) MB)" -ForegroundColor Green
}
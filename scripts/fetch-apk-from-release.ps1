# Download latest prerelease arm64 APK from GitHub Releases into dist/ (no gh required).
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path | Split-Path -Parent
$destDir = Join-Path $root "dist"
New-Item -ItemType Directory -Force -Path $destDir | Out-Null

$releases = Invoke-RestMethod -Uri "https://api.github.com/repos/jayg-j/recitro/releases"
$rel = $releases | Where-Object { $_.prerelease -eq $true -and $_.tag_name -like "apk-*" } | Select-Object -First 1
if (-not $rel) {
  Write-Host "No APK release yet. Open: https://github.com/jayg-j/recitro/actions" -ForegroundColor Yellow
  exit 1
}

$asset = $rel.assets | Where-Object { $_.name -match "arm64-v8a-release" } | Select-Object -First 1
if (-not $asset) {
  $asset = $rel.assets | Select-Object -First 1
}

$out = Join-Path $destDir "recitro-latest-arm64.apk"
Write-Host "Downloading $($asset.name) from $($rel.tag_name)..." -ForegroundColor Cyan
Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $out -UseBasicParsing

Write-Host "Saved: $out ($([math]::Round((Get-Item $out).Length/1MB,1)) MB)" -ForegroundColor Green
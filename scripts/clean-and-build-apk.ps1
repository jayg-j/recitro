# Delete old APK/build output and produce a fresh arm64 APK for phones.
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path | Split-Path -Parent
Set-Location $root

$flutter = if ($env:FLUTTER_ROOT) { Join-Path $env:FLUTTER_ROOT "bin\flutter.bat" } else { "C:\Users\Jay\develop\flutter\bin\flutter.bat" }

Write-Host "Removing old build output..." -ForegroundColor Cyan
Remove-Item -Recurse -Force -ErrorAction SilentlyContinue @(
  "$root\build",
  "$root\dist",
  "$root\android\app\build",
  "$root\android\.gradle"
)

& $flutter clean
& $flutter pub get

Write-Host "Building release APK (split per ABI)..." -ForegroundColor Cyan
& $flutter build apk --release
if ($LASTEXITCODE -ne 0) {
  Write-Host "Release failed; trying debug APK..." -ForegroundColor Yellow
  & $flutter build apk --debug
}
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$apkDir = Join-Path $root "build\app\outputs\flutter-apk"
$src = Get-ChildItem $apkDir -Filter "*arm64*.apk" | Sort-Object Length -Descending | Select-Object -First 1
if (-not $src) {
  $src = Get-ChildItem $apkDir -Filter "*.apk" | Select-Object -First 1
}
if (-not $src) { Write-Error "No APK in $apkDir" }

New-Item -ItemType Directory -Force -Path "$root\dist" | Out-Null
$dest = Join-Path $root "dist\recitro-latest-arm64.apk"
Copy-Item $src.FullName $dest -Force

Write-Host ""
Write-Host "New APK: $dest ($([math]::Round((Get-Item $dest).Length/1MB,1)) MB)" -ForegroundColor Green
Write-Host "Install: adb install -r `"$dest`""
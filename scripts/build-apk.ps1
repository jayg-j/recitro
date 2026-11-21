# Build release APKs (arm64 for phones, x86_64 for emulator when split-per-abi is on).
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path | Split-Path -Parent
Set-Location $root

$flutter = if ($env:FLUTTER_ROOT) { Join-Path $env:FLUTTER_ROOT "bin\flutter.bat" } else { "C:\Users\Jay\develop\flutter\bin\flutter.bat" }
if (-not (Test-Path $flutter)) {
  Write-Error "Flutter not found. Set FLUTTER_ROOT or install Flutter."
}

Write-Host "Building release APK..." -ForegroundColor Cyan
& $flutter build apk --release
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$out = Join-Path $root "build\app\outputs\flutter-apk"
Write-Host ""
Write-Host "Output folder:" -ForegroundColor Green
Get-ChildItem $out -Filter "*.apk" | ForEach-Object {
  Write-Host ("  {0} ({1:N1} MB)" -f $_.Name, ($_.Length / 1MB))
}
Write-Host ""
Write-Host "Install on phone: copy app-arm64-v8a-release.apk to the device, or:" -ForegroundColor Yellow
Write-Host "  adb install -r build\app\outputs\flutter-apk\app-arm64-v8a-release.apk"
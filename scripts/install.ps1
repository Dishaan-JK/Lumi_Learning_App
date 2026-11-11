$ErrorActionPreference = 'Stop'
$repository = if ($env:LUMI_RELEASE_REPOSITORY) { $env:LUMI_RELEASE_REPOSITORY } else { 'Dishaan-JK/Lumi_Learning_App' }
if (-not [Environment]::Is64BitOperatingSystem -or $env:PROCESSOR_ARCHITECTURE -ne 'AMD64') {
  throw 'Lumi currently supports Windows on x64.'
}
$asset = 'lumi-windows-x64.exe'
$installDir = if ($env:LUMI_INSTALL_DIR) { $env:LUMI_INSTALL_DIR } else { Join-Path $env:LOCALAPPDATA 'Programs\Lumi' }
$executable = Join-Path $installDir $asset
New-Item -ItemType Directory -Force -Path $installDir | Out-Null
$url = "https://github.com/$repository/releases/latest/download/$asset"
Write-Host "Downloading Lumi for Windows from $repository..."
Invoke-WebRequest -Uri $url -OutFile $executable
Write-Host "Installed at $executable"
Write-Host 'Launching Lumi...'
& $executable

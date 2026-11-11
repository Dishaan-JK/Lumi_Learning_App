$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$dataRoot = Join-Path $env:LOCALAPPDATA 'Lumi'
$runtimeRoot = Join-Path $dataRoot 'runtime'
$nodeState = Join-Path $runtimeRoot 'node-version.txt'
$dartState = Join-Path $runtimeRoot 'dart-version.txt'
$webRevisionFile = Join-Path $runtimeRoot 'web-revision.txt'
$setupMarker = Join-Path $runtimeRoot 'first-run-complete'
$webRoot = Join-Path $projectRoot 'lumi-web\dist'

New-Item -ItemType Directory -Force -Path $runtimeRoot | Out-Null
if ($env:PROCESSOR_ARCHITECTURE -match 'ARM64') { $assetArch = 'arm64' }
elseif ($env:PROCESSOR_ARCHITECTURE -match 'AMD64') { $assetArch = 'x64' }
else { throw "Lumi does not have a bundled runtime for $env:PROCESSOR_ARCHITECTURE." }

function Get-NodeRelease {
  try {
    $release = Invoke-RestMethod -Uri 'https://nodejs.org/dist/index.json' -TimeoutSec 15 |
      Where-Object { $_.lts -and $_.version -match '^v\d+\.' } |
      Select-Object -First 1
    if ($release) { return $release.version.TrimStart('v') }
  } catch { Write-Host 'Could not check nodejs.org; using the installed Lumi Node.js runtime if available.' }
  if (Test-Path $nodeState) { return (Get-Content $nodeState -Raw).Trim() }
  return $null
}

function Get-DartRelease {
  try {
    $release = Invoke-RestMethod -Uri 'https://storage.googleapis.com/dart-archive/channels/stable/release/latest/VERSION' -TimeoutSec 15
    if ($release.version) { return [string]$release.version }
  } catch { Write-Host 'Could not check dart.dev; using the installed Lumi Dart runtime if available.' }
  if (Test-Path $dartState) { return (Get-Content $dartState -Raw).Trim() }
  return $null
}

$nodeVersion = Get-NodeRelease
if (-not $nodeVersion -or [version]$nodeVersion -lt [version]'22.0') { throw "Node.js 22 or newer is required. Could not find a supported runtime." }
$nodeHome = Join-Path $runtimeRoot "node-v$nodeVersion"
$nodeExe = Join-Path $nodeHome 'node.exe'
if (-not (Test-Path $nodeExe)) {
  $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("lumi-node-" + [guid]::NewGuid())
  $archive = Join-Path $tempRoot 'node.zip'
  New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null
  try {
    $nodeFile = "node-v$nodeVersion-win-$assetArch.zip"
    $nodeUrl = "https://nodejs.org/dist/v$nodeVersion/$nodeFile"
    Write-Host "Downloading Node.js $nodeVersion for Windows $assetArch..."
    Invoke-WebRequest -Uri $nodeUrl -OutFile $archive
    Expand-Archive -LiteralPath $archive -DestinationPath $tempRoot -Force
    $extracted = Join-Path $tempRoot "node-v$nodeVersion-win-$assetArch"
    Remove-Item -LiteralPath $nodeHome -Recurse -Force -ErrorAction SilentlyContinue
    Move-Item -LiteralPath $extracted -Destination $nodeHome -Force
  } finally { Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue }
}
Set-Content -LiteralPath $nodeState -Value $nodeVersion -NoNewline

$dartVersion = Get-DartRelease
if (-not $dartVersion -or [version]$dartVersion -lt [version]'3.12.0') { throw 'Dart 3.12 or newer is required. Could not find a supported runtime.' }
$dartHome = Join-Path $runtimeRoot 'dart-sdk'
$dartExe = Join-Path $dartHome 'bin\dart.exe'
$installedDart = $null
if (Test-Path $dartExe) {
  $versionText = (& $dartExe --version 2>&1 | Out-String)
  if ($versionText -match 'version:\s*(\d+\.\d+\.\d+)') { $installedDart = $Matches[1] }
}
if ($installedDart -ne $dartVersion) {
  $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("lumi-dart-" + [guid]::NewGuid())
  $archive = Join-Path $tempRoot 'dart.zip'
  New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null
  try {
    $dartFile = "dartsdk-windows-$assetArch-release.zip"
    $dartUrl = "https://storage.googleapis.com/dart-archive/channels/stable/release/$dartVersion/sdk/$dartFile"
    Write-Host "Downloading Dart $dartVersion for Windows $assetArch..."
    Invoke-WebRequest -Uri $dartUrl -OutFile $archive
    Expand-Archive -LiteralPath $archive -DestinationPath $tempRoot -Force
    Remove-Item -LiteralPath $dartHome -Recurse -Force -ErrorAction SilentlyContinue
    Move-Item -LiteralPath (Join-Path $tempRoot 'dart-sdk') -Destination $dartHome -Force
  } finally { Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue }
}
Set-Content -LiteralPath $dartState -Value $dartVersion -NoNewline

$remoteWebRevision = $null
try {
  $remoteWebRevision = (Invoke-RestMethod -Uri 'https://api.github.com/repos/Dishaan-JK/Lumi_Learning_App/commits/React_v' -TimeoutSec 15).sha
} catch { Write-Host 'Could not check for a newer React web bundle; using the saved bundle if available.' }
$installedWebRevision = if (Test-Path $webRevisionFile) { (Get-Content $webRevisionFile -Raw).Trim() } else { $null }
$webMissing = -not (Test-Path (Join-Path $webRoot 'index.html'))
$webStale = $remoteWebRevision -and $installedWebRevision -and ($remoteWebRevision -ne $installedWebRevision)
if ($webMissing -and (Test-Path (Join-Path $projectRoot 'dist\index.html'))) {
  $distRoot = Join-Path $projectRoot 'dist'
  New-Item -ItemType Directory -Force -Path $webRoot | Out-Null
  Copy-Item -Path (Join-Path $distRoot '*') -Destination $webRoot -Recurse -Force
}
elseif ($webMissing -or $webStale) {
  $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("lumi-web-" + [guid]::NewGuid())
  $archive = Join-Path $tempRoot 'source.zip'
  New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null
  try {
    Write-Host 'Updating the React web app...'
    Invoke-WebRequest -Uri 'https://github.com/Dishaan-JK/Lumi_Learning_App/archive/refs/heads/React_v.zip' -OutFile $archive
    Expand-Archive -LiteralPath $archive -DestinationPath $tempRoot -Force
    $sourceRoot = Get-ChildItem -LiteralPath $tempRoot -Directory | Select-Object -First 1
    $latestDist = Join-Path $sourceRoot.FullName 'dist'
    if (-not (Test-Path (Join-Path $latestDist 'index.html'))) { throw 'The downloaded React bundle did not contain dist/index.html.' }
    Remove-Item -LiteralPath (Join-Path $projectRoot 'lumi-web') -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Force -Path $webRoot | Out-Null
    Copy-Item -Path (Join-Path $latestDist '*') -Destination $webRoot -Recurse -Force
  } finally { Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue }
}
if ($remoteWebRevision) { Set-Content -LiteralPath $webRevisionFile -Value $remoteWebRevision -NoNewline }

$env:PATH = "$($nodeHome);$(Join-Path $dartHome 'bin');$env:PATH"
$env:LUMI_DART_EXECUTABLE = $dartExe
$env:LUMI_RUNTIME_HOME = $runtimeRoot
$env:LUMI_SETUP_MARKER = $setupMarker
$env:LUMI_WEB_DIR = $webRoot
if (-not (Test-Path $setupMarker)) { $env:LUMI_PROMPT_OPEN = '1' }

$binRoot = Join-Path $dataRoot 'bin'
$lumiCommand = Join-Path $binRoot 'lumi.cmd'
New-Item -ItemType Directory -Force -Path $binRoot | Out-Null
if (-not (Test-Path $lumiCommand) -or (Select-String -LiteralPath $lumiCommand -Pattern 'managed by Lumi' -Quiet -ErrorAction SilentlyContinue)) {
  $escapedProjectRoot = $projectRoot.Replace('%', '%%')
  @"
@echo off
rem managed by Lumi
call "$escapedProjectRoot\Lumi.bat" %*
"@ | Set-Content -LiteralPath $lumiCommand -Encoding Ascii
} else {
  Write-Warning "A different '$lumiCommand' already exists; leaving it unchanged."
}

$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
$pathEntries = @($userPath -split ';' | Where-Object { $_ })
if ($pathEntries -notcontains $binRoot) {
  $newUserPath = (@($pathEntries) + $binRoot) -join ';'
  [Environment]::SetEnvironmentVariable('Path', $newUserPath, 'User')
  try {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class LumiEnvironmentBroadcast {
  [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
  public static extern IntPtr SendMessageTimeout(IntPtr hWnd, uint message, UIntPtr wParam, string lParam, uint flags, uint timeout, out UIntPtr result);
}
'@ -ErrorAction SilentlyContinue
    $broadcastResult = [UIntPtr]::Zero
    [void][LumiEnvironmentBroadcast]::SendMessageTimeout([IntPtr]0xffff, 0x001A, [UIntPtr]::Zero, 'Environment', 0x0002, 5000, [ref]$broadcastResult)
  } catch { Write-Host 'The lumi command is on your user PATH. If this Command Prompt was already open, open a new one.' }
}
$env:PATH = "$binRoot;$env:PATH"

& $nodeExe (Join-Path $projectRoot 'scripts\launch-lumi.mjs') @args
exit $LASTEXITCODE

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$dataRoot = Join-Path $env:LOCALAPPDATA 'Lumi'
$runtimeRoot = Join-Path $dataRoot 'runtime'
$nodeState = Join-Path $runtimeRoot 'node-version.txt'
$dartState = Join-Path $runtimeRoot 'dart-version.txt'
$webRoot = Join-Path $projectRoot 'dist'

$banner = @'
  _     _   _ __  __ ___
 | |   | | | |  \/  |_ _|
 | |   | | | | |\/| || |
 | |___| |_| | |  | || |
 |_____|\___/|_|  |_|___|
'@
Write-Host $banner -ForegroundColor Green
Write-Host "`n  Lumi setup  |  OS: Windows $env:PROCESSOR_ARCHITECTURE"
Write-Host "  Checking runtimes and packages, then starting Lumi.`n"

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

function Test-Node($path) {
  if (-not $path) { return $false }
  try {
    $v = (& $path --version 2>$null | Out-String).Trim().TrimStart('v')
    return $LASTEXITCODE -eq 0 -and [version]$v -ge [version]'22.0'
  } catch { return $false }
}
function Test-Dart($path) {
  if (-not $path) { return $false }
  try {
    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try { $text = (& $path --version 2>&1 | Out-String); $exitCode = $LASTEXITCODE }
    finally { $ErrorActionPreference = $previousPreference }
    return $exitCode -eq 0 -and $text -match 'version:\s*(\d+\.\d+\.\d+)' -and [version]$Matches[1] -ge [version]'3.12.0'
  } catch { return $false }
}
$nodeCommand = Get-Command node.exe -ErrorAction SilentlyContinue
$npmCommand = Get-Command npm.cmd -ErrorAction SilentlyContinue
$systemNode = if ($nodeCommand) { $nodeCommand.Source } else { $null }
$privateNode = $null
if (Test-Path $nodeState) {
  $savedNodeVersion = (Get-Content $nodeState -Raw).Trim()
  $privateNode = Join-Path $runtimeRoot "node-v$savedNodeVersion\node.exe"
}
if ($npmCommand -and (Test-Node $systemNode)) {
  $nodeExe = $systemNode
  Write-Host "Using installed Node.js and npm."
} elseif ((Test-Node $privateNode) -and (Test-Path (Join-Path (Split-Path $privateNode) 'npm.cmd'))) {
  $nodeExe = $privateNode
  $env:PATH = "$(Split-Path $nodeExe);$env:PATH"
  Write-Host "Using Lumi's private Node.js."
} else {
  $nodeVersion = Get-NodeRelease
  if (-not $nodeVersion -or [version]$nodeVersion -lt [version]'22.0') { throw "Node.js 22 or newer is required. Could not find a supported runtime." }
  $nodeHome = Join-Path $runtimeRoot "node-v$nodeVersion"
  $nodeExe = Join-Path $nodeHome 'node.exe'
  if (-not (Test-Node $nodeExe)) {
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
  $env:PATH = "$nodeHome;$env:PATH"
}

$dartCommand = Get-Command dart.exe, dart.bat, dart.cmd -ErrorAction SilentlyContinue | Select-Object -First 1
$systemDart = if ($dartCommand) { $dartCommand.Source } else { $null }
if ($systemDart -match '[\\/]flutter[\\/]bin[\\/]dart\.(bat|cmd)$') {
  $cachedDart = Join-Path (Split-Path $systemDart) 'cache\dart-sdk\bin\dart.exe'
  if (Test-Path $cachedDart) { $systemDart = $cachedDart }
}
$privateDart = Join-Path $runtimeRoot 'dart-sdk\bin\dart.exe'
if (Test-Dart $systemDart) {
  $dartExe = $systemDart
  Write-Host "Using installed Dart: $dartExe"
} elseif (Test-Dart $privateDart) {
  $dartExe = $privateDart
  Write-Host "Using Lumi's private Dart SDK."
} else {
  $dartVersion = Get-DartRelease
  if (-not $dartVersion -or [version]$dartVersion -lt [version]'3.12.0') { throw 'Dart 3.12 or newer is required. Could not find a supported runtime.' }
  $dartHome = Join-Path $runtimeRoot 'dart-sdk'
  $dartExe = Join-Path $dartHome 'bin\dart.exe'
  $installedDart = $null
  if (Test-Path $dartExe) {
    $versionText = (& $dartExe --version 2>&1 | Out-String)
    if ($versionText -match 'version:\s*(\d+\.\d+\.\d+)') { $installedDart = $Matches[1] }
  }
  if (-not (Test-Dart $dartExe)) {
    $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("lumi-dart-" + [guid]::NewGuid())
    $archive = Join-Path $tempRoot 'dart.zip'
    New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null
    try {
      $dartFile = "dartsdk-windows-$assetArch-release.zip"
      $dartUrl = "https://storage.googleapis.com/dart-archive/channels/stable/release/$dartVersion/sdk/$dartFile"
      Write-Host "Downloading Dart $dartVersion for Windows $assetArch..."
      Invoke-WebRequest -Uri $dartUrl -OutFile $archive
      Expand-Archive -LiteralPath $archive -DestinationPath $tempRoot -Force
      if (-not (Test-Dart (Join-Path $tempRoot 'dart-sdk\bin\dart.exe'))) { throw 'Downloaded Dart SDK is unusable or older than 3.12.' }
      Remove-Item -LiteralPath $dartHome -Recurse -Force -ErrorAction SilentlyContinue
      Move-Item -LiteralPath (Join-Path $tempRoot 'dart-sdk') -Destination $dartHome -Force
    } finally { Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue }
  }
  Set-Content -LiteralPath $dartState -Value $dartVersion -NoNewline
}

# Keep the frontend and backend from the same downloaded project snapshot.
if (-not (Test-Path (Join-Path $webRoot 'index.html'))) {
  throw 'The React bundle is missing. Download and extract the complete Lumi project again.'
}

$env:LUMI_DART_EXECUTABLE = $dartExe
$env:LUMI_RUNTIME_HOME = $runtimeRoot
$env:LUMI_WEB_DIR = $webRoot

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

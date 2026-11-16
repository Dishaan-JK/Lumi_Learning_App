
$ErrorActionPreference = 'Stop'

# Enable TLS 1.2 for Windows PowerShell 5.1
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$dataRoot = Join-Path $env:LOCALAPPDATA 'Lumi'
$runtimeRoot = Join-Path $dataRoot 'runtime'
$nodeState = Join-Path $runtimeRoot 'node-version.txt'
$dartState = Join-Path $runtimeRoot 'dart-version.txt'
$webRoot = Join-Path $projectRoot 'dist'
$commandName = if ($args.Count -gt 0) { ([string]$args[0]).ToLowerInvariant() } else { 'start' }

if ($commandName -in @('help', '--help', '-h', '/?')) {
    @'
Lumi commands

  lumi                 Start Lumi
  lumi install         Install or repair Lumi's runtimes and packages, then start it
  lumi uninstall-packages
                       Remove Lumi-managed runtimes and downloaded project packages
                       System-wide Node.js and Dart installations are not removed
  lumi factory-reset   Delete Lumi workspace data and settings, then start clean
                       Requires typing RESET; Lumi must be closed first
  lumi help            Show this help
'@ | Write-Host
    exit 0
}

if ($commandName -eq 'uninstall-packages') {
    Write-Host 'This removes Lumi-managed runtimes and downloaded project packages. System-wide Node.js and Dart installations are left alone.'
    if ((Read-Host 'Type REMOVE to continue') -cne 'REMOVE') {
        Write-Host 'Cancelled.'
        exit 1
    }

    $removePaths = @(
        $runtimeRoot,
        (Join-Path $projectRoot 'node_modules'),
        (Join-Path $projectRoot 'backend\.dart_tool')
    )
    foreach ($path in $removePaths) {
        if (Test-Path -LiteralPath $path) {
            Remove-Item -LiteralPath $path -Recurse -Force
            Write-Host "Removed $path"
        }
    }
    Write-Host 'Lumi remains installed. Run "lumi install" to download runtimes and packages again.' -ForegroundColor Green
    exit 0
}

if ($commandName -eq 'factory-reset') {
    $accountData = [IO.Path]::GetFullPath($dataRoot)
    $legacyData = [IO.Path]::GetFullPath((Join-Path $projectRoot 'backend\.data'))
    $customData = if ($env:LUMI_DATA_DIR) { [IO.Path]::GetFullPath($env:LUMI_DATA_DIR) } else { $null }
    if ($customData -and $customData -ne $legacyData) {
        $projectPath = [IO.Path]::GetFullPath($projectRoot).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
        $projectDataPath = $customData.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
        if (
            $customData -eq [IO.Path]::GetPathRoot($customData) -or
            $customData -eq $projectPath.TrimEnd([IO.Path]::DirectorySeparatorChar) -or
            $customData.StartsWith($projectPath, [StringComparison]::OrdinalIgnoreCase) -or
            $projectPath.StartsWith($projectDataPath, [StringComparison]::OrdinalIgnoreCase)
        ) {
            throw "Refusing to factory-reset the unsafe LUMI_DATA_DIR path '$customData'. Choose a dedicated Lumi data folder outside the project and user/system folders."
        }
    }
    $targets = @($accountData, $legacyData)
    if ($customData -and $customData -ne $accountData -and $customData -ne $legacyData) {
        $targets += $customData
    }

    Write-Host 'Factory reset removes Lumi workspace files, settings, provider configuration, and browser-local UI state.' -ForegroundColor Yellow
    Write-Host 'It keeps Lumi, its private runtimes, and the command-line launcher.'
    Write-Host "Data locations: $($targets -join ', ')"
    if ((Read-Host 'Type RESET to permanently delete this Lumi data') -cne 'RESET') {
        Write-Host 'Cancelled.'
        exit 1
    }

    $portsToCheck = @(8080, 5173)
    if ($env:LUMI_BACKEND_URL) { try { $portsToCheck += ([Uri]$env:LUMI_BACKEND_URL).Port } catch { } }
    if ($env:LUMI_FRONTEND_PORT) { try { $portsToCheck += [int]$env:LUMI_FRONTEND_PORT } catch { } }
    foreach ($port in @($portsToCheck | Sort-Object -Unique)) {
        $client = New-Object System.Net.Sockets.TcpClient
        try {
            $pending = $client.BeginConnect('127.0.0.1', [int]$port, $null, $null)
            if ($pending.AsyncWaitHandle.WaitOne(250)) {
                try {
                    $client.EndConnect($pending)
                    throw "A local service is using port $port. Close Lumi and run the factory reset again. No data was deleted."
                }
                catch [System.Net.Sockets.SocketException] { }
            }
        }
        finally { $client.Close() }
    }

    foreach ($target in $targets) {
        if (-not (Test-Path -LiteralPath $target)) { continue }
        if ($target -eq $accountData) {
            Get-ChildItem -LiteralPath $target -Force |
                Where-Object { $_.Name -notin @('runtime', 'bin') } |
                Remove-Item -Recurse -Force
        }
        else {
            Remove-Item -LiteralPath $target -Recurse -Force
        }
        Write-Host "Reset $target"
    }
    $env:LUMI_FACTORY_RESET = '1'
    Write-Host 'Lumi data reset. Starting Lumi with a clean browser state...' -ForegroundColor Green
}
elseif ($commandName -notin @('start', 'install')) {
    throw 'Usage: lumi [install | uninstall-packages | factory-reset]'
}

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

if ($env:PROCESSOR_ARCHITECTURE -match 'ARM64') {
    $assetArch = 'arm64'
}
elseif ($env:PROCESSOR_ARCHITECTURE -match 'AMD64') {
    $assetArch = 'x64'
}
else {
    throw "Lumi does not have a bundled runtime for $env:PROCESSOR_ARCHITECTURE."
}

# ---------------------------------------------------------
# NODE.JS RELEASE DETECTION
# ---------------------------------------------------------

function Get-NodeRelease {

    # First try nodejs.org
    try {

        Write-Host "Checking latest Node.js LTS release..."

        $releaseData = Invoke-RestMethod `
            -Uri 'https://nodejs.org/dist/index.json' `
            -TimeoutSec 30 `
            -ErrorAction Stop

        $release = $releaseData |
            Where-Object {
                $_.lts -and
                $_.version -match '^v\d+\.\d+\.\d+$'
            } |
            Select-Object -First 1

        if ($release) {

            $version = ([string]$release.version).TrimStart('v')

            $parsedVersion = $null

            if (
                [version]::TryParse($version, [ref]$parsedVersion) -and
                $parsedVersion -ge [version]'22.0'
            ) {

                Write-Host "Found Node.js release: $version" -ForegroundColor Green

                return $version
            }
        }

        Write-Warning "Could not find a valid Node.js 22+ LTS release."

    }
    catch {

        Write-Warning "Could not connect to nodejs.org: $($_.Exception.Message)"

    }

    # Second try installed Node.js
    try {

        $nodeCommand = Get-Command node.exe -ErrorAction SilentlyContinue

        if ($nodeCommand) {

            $installedVersion = (
                & $nodeCommand.Source --version 2>$null |
                Out-String
            ).Trim().TrimStart('v')

            $parsedInstalled = $null

            if (
                [version]::TryParse($installedVersion, [ref]$parsedInstalled) -and
                $parsedInstalled -ge [version]'22.0'
            ) {

                Write-Host "Using installed Node.js $installedVersion"

                return $installedVersion
            }
        }

    }
    catch {

        Write-Warning "Could not detect installed Node.js."

    }

    # Third try Lumi cached version
    if (Test-Path $nodeState) {

        try {

            $cachedVersion = (Get-Content $nodeState -Raw).Trim()

            $parsedCached = $null

            if (
                [version]::TryParse($cachedVersion, [ref]$parsedCached) -and
                $parsedCached -ge [version]'22.0'
            ) {

                Write-Host "Using cached Node.js version: $cachedVersion"

                return $cachedVersion
            }

            Write-Warning "Cached Node.js version is invalid or too old."

        }
        catch {

            Write-Warning "Could not read Lumi's cached Node.js version."

        }
    }

    return $null
}

# ---------------------------------------------------------
# DART RELEASE DETECTION
# ---------------------------------------------------------

function Get-DartRelease {

    try {

        Write-Host "Checking latest Dart stable release..."

        $release = Invoke-RestMethod `
            -Uri 'https://storage.googleapis.com/dart-archive/channels/stable/release/latest/VERSION' `
            -TimeoutSec 30 `
            -ErrorAction Stop

        if ($release.version) {

            $version = ([string]$release.version).Trim()

            $parsedVersion = $null

            if ([version]::TryParse($version, [ref]$parsedVersion)) {

                return $version

            }
        }

    }
    catch {

        Write-Warning "Could not connect to Dart archive: $($_.Exception.Message)"

    }

    if (Test-Path $dartState) {

        $cachedVersion = (Get-Content $dartState -Raw).Trim()

        $parsedVersion = $null

        if ([version]::TryParse($cachedVersion, [ref]$parsedVersion)) {

            return $cachedVersion

        }
    }

    return $null
}

# ---------------------------------------------------------
# NODE.JS VALIDATION
# ---------------------------------------------------------

function Test-Node($path) {

    if (-not $path -or -not (Test-Path $path)) {
        return $false
    }

    try {

        $v = (
            & $path --version 2>$null |
            Out-String
        ).Trim().TrimStart('v')

        $parsed = $null

        return (
            $LASTEXITCODE -eq 0 -and
            [version]::TryParse($v, [ref]$parsed) -and
            $parsed -ge [version]'22.0'
        )

    }
    catch {

        return $false

    }
}

# ---------------------------------------------------------
# DART VALIDATION
# ---------------------------------------------------------

function Test-Dart($path) {

    if (-not $path -or -not (Test-Path $path)) {
        return $false
    }

    try {

        $previousPreference = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'

        try {

            $text = (& $path --version 2>&1 | Out-String)
            $exitCode = $LASTEXITCODE

        }
        finally {

            $ErrorActionPreference = $previousPreference

        }

        if (
            $exitCode -eq 0 -and
            $text -match 'version:\s*(\d+\.\d+\.\d+)'
        ) {

            $parsed = [version]$Matches[1]

            return $parsed -ge [version]'3.12.0'

        }

        return $false

    }
    catch {

        return $false

    }
}

# ---------------------------------------------------------
# FIND NODE.JS
# ---------------------------------------------------------

$nodeCommand = Get-Command node.exe -ErrorAction SilentlyContinue
$npmCommand = Get-Command npm.cmd -ErrorAction SilentlyContinue

$systemNode = if ($nodeCommand) {
    $nodeCommand.Source
} else {
    $null
}

$privateNode = $null

if (Test-Path $nodeState) {

    $savedNodeVersion = (Get-Content $nodeState -Raw).Trim()

    $privateNode = Join-Path $runtimeRoot "node-v$savedNodeVersion\node.exe"

}

if ($npmCommand -and (Test-Node $systemNode)) {

    $nodeExe = $systemNode

    Write-Host "Using installed Node.js and npm." -ForegroundColor Green

}
elseif (
    (Test-Node $privateNode) -and
    (Test-Path (Join-Path (Split-Path $privateNode) 'npm.cmd'))
) {

    $nodeExe = $privateNode

    $env:PATH = "$(Split-Path $nodeExe);$env:PATH"

    Write-Host "Using Lumi's private Node.js." -ForegroundColor Green

}
else {

    # Get a valid Node.js version
    $nodeVersionValues = @(Get-NodeRelease)

    $nodeVersion = if ($nodeVersionValues.Count -gt 0) {
        [string]$nodeVersionValues[0]
    } else {
        $null
    }

    $parsedNodeVersion = $null

    if (
        -not $nodeVersion -or
        -not [version]::TryParse($nodeVersion, [ref]$parsedNodeVersion) -or
        $parsedNodeVersion -lt [version]'22.0'
    ) {

        throw @"
Node.js 22 or newer is required.

Lumi could not find a valid Node.js installation or download a release.

Please install Node.js 22 or newer from:
https://nodejs.org/en/download

Then restart PowerShell and run Lumi again.
"@

    }

    $nodeHome = Join-Path $runtimeRoot "node-v$nodeVersion"

    $nodeExe = Join-Path $nodeHome 'node.exe'

    if (-not (Test-Node $nodeExe)) {

        $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("lumi-node-" + [guid]::NewGuid())

        $archive = Join-Path $tempRoot 'node.zip'

        New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null

        try {

            $nodeFile = "node-v$nodeVersion-win-$assetArch.zip"

            $nodeUrl = "https://nodejs.org/dist/v$nodeVersion/$nodeFile"

            Write-Host "Downloading Node.js $nodeVersion for Windows $assetArch..." -ForegroundColor Cyan

            Invoke-WebRequest `
                -Uri $nodeUrl `
                -OutFile $archive `
                -UseBasicParsing `
                -TimeoutSec 180

            Expand-Archive -LiteralPath $archive -DestinationPath $tempRoot -Force

            $extracted = Join-Path $tempRoot "node-v$nodeVersion-win-$assetArch"

            if (-not (Test-Path (Join-Path $extracted 'node.exe'))) {

                throw "Downloaded Node.js archive does not contain node.exe."

            }

            Remove-Item -LiteralPath $nodeHome -Recurse -Force -ErrorAction SilentlyContinue

            Move-Item -LiteralPath $extracted -Destination $nodeHome -Force

        }
        finally {

            Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue

        }

    }

    if (-not (Test-Node $nodeExe)) {

        throw "Downloaded Node.js failed validation."

    }

    Set-Content -LiteralPath $nodeState -Value $nodeVersion -NoNewline

    $env:PATH = "$nodeHome;$env:PATH"

    Write-Host "Node.js $nodeVersion installed successfully." -ForegroundColor Green

}

# ---------------------------------------------------------
# FIND / INSTALL DART
# ---------------------------------------------------------

$dartCommand = Get-Command dart.exe, dart.bat, dart.cmd -ErrorAction SilentlyContinue |
    Select-Object -First 1

$systemDart = if ($dartCommand) {
    $dartCommand.Source
} else {
    $null
}

if ($systemDart -match '[\\/]flutter[\\/]bin[\\/]dart\.(bat|cmd)$') {

    $cachedDart = Join-Path (Split-Path $systemDart) 'cache\dart-sdk\bin\dart.exe'

    if (Test-Path $cachedDart) {
        $systemDart = $cachedDart
    }

}

$privateDart = Join-Path $runtimeRoot 'dart-sdk\bin\dart.exe'

if (Test-Dart $systemDart) {

    $dartExe = $systemDart

    Write-Host "Using installed Dart: $dartExe" -ForegroundColor Green

}
elseif (Test-Dart $privateDart) {

    $dartExe = $privateDart

    Write-Host "Using Lumi's private Dart SDK." -ForegroundColor Green

}
else {

    $dartVersionValues = @(Get-DartRelease)

    $dartVersion = if ($dartVersionValues.Count -gt 0) {
        [string]$dartVersionValues[0]
    } else {
        $null
    }

    $parsedDartVersion = $null

    if (
        -not $dartVersion -or
        -not [version]::TryParse($dartVersion, [ref]$parsedDartVersion) -or
        $parsedDartVersion -lt [version]'3.12.0'
    ) {

        throw "Dart 3.12 or newer is required. No valid version was returned by dart.dev or found in Lumi's cache at '$dartState'."

    }

    $dartHome = Join-Path $runtimeRoot 'dart-sdk'

    $dartExe = Join-Path $dartHome 'bin\dart.exe'

    if (-not (Test-Dart $dartExe)) {

        $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("lumi-dart-" + [guid]::NewGuid())

        $archive = Join-Path $tempRoot 'dart.zip'

        New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null

        try {

            $dartFile = "dartsdk-windows-$assetArch-release.zip"

            $dartUrl = "https://storage.googleapis.com/dart-archive/channels/stable/release/$dartVersion/sdk/$dartFile"

            Write-Host "Downloading Dart $dartVersion for Windows $assetArch..." -ForegroundColor Cyan

            Invoke-WebRequest `
                -Uri $dartUrl `
                -OutFile $archive `
                -UseBasicParsing `
                -TimeoutSec 180

            Expand-Archive -LiteralPath $archive -DestinationPath $tempRoot -Force

            if (-not (Test-Dart (Join-Path $tempRoot 'dart-sdk\bin\dart.exe'))) {

                throw 'Downloaded Dart SDK is unusable or older than 3.12.'

            }

            Remove-Item -LiteralPath $dartHome -Recurse -Force -ErrorAction SilentlyContinue

            Move-Item -LiteralPath (Join-Path $tempRoot 'dart-sdk') -Destination $dartHome -Force

        }
        finally {

            Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue

        }

    }

    Set-Content -LiteralPath $dartState -Value $dartVersion -NoNewline

}

# ---------------------------------------------------------
# VERIFY FRONTEND
# ---------------------------------------------------------

if (-not (Test-Path (Join-Path $webRoot 'index.html'))) {

    throw 'The React bundle is missing. Download and extract the complete Lumi project again.'

}

# ---------------------------------------------------------
# CONFIGURE LUMI ENVIRONMENT
# ---------------------------------------------------------

$env:LUMI_DART_EXECUTABLE = $dartExe
$env:LUMI_RUNTIME_HOME = $runtimeRoot
$env:LUMI_WEB_DIR = $webRoot

# ---------------------------------------------------------
# CREATE LUMI COMMAND
# ---------------------------------------------------------

$binRoot = Join-Path $dataRoot 'bin'

$lumiCommand = Join-Path $binRoot 'lumi.cmd'

New-Item -ItemType Directory -Force -Path $binRoot | Out-Null

if (
    -not (Test-Path $lumiCommand) -or
    (Select-String -LiteralPath $lumiCommand -Pattern 'managed by Lumi' -Quiet -ErrorAction SilentlyContinue)
) {

    $escapedProjectRoot = $projectRoot.Replace('%', '%%')

    @"
@echo off
rem managed by Lumi
call "$escapedProjectRoot\Lumi.bat" %*
"@ | Set-Content -LiteralPath $lumiCommand -Encoding Ascii

}
else {

    Write-Warning "A different '$lumiCommand' already exists; leaving it unchanged."

}

# ---------------------------------------------------------
# ADD LUMI TO USER PATH
# ---------------------------------------------------------

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
    public static extern IntPtr SendMessageTimeout(
        IntPtr hWnd,
        uint message,
        UIntPtr wParam,
        string lParam,
        uint flags,
        uint timeout,
        out UIntPtr result
    );
}
'@ -ErrorAction SilentlyContinue

        $broadcastResult = [UIntPtr]::Zero

        [void][LumiEnvironmentBroadcast]::SendMessageTimeout(
            [IntPtr]0xffff,
            0x001A,
            [UIntPtr]::Zero,
            'Environment',
            0x0002,
            5000,
            [ref]$broadcastResult
        )

    }
    catch {

        Write-Host 'The lumi command is on your user PATH. Open a new terminal if necessary.'

    }

}

$env:PATH = "$binRoot;$env:PATH"

# ---------------------------------------------------------
# START LUMI
# ---------------------------------------------------------

Write-Host "`nStarting Lumi..." -ForegroundColor Green

& $nodeExe (Join-Path $projectRoot 'scripts\launch-lumi.mjs') @args

exit $LASTEXITCODE

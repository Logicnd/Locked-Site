#!/usr/bin/env pwsh
<#
setup-and-run.ps1
Attempts to install Node.js (via winget or choco), loads .env into environment,
runs `npm install`, and starts the server with `node server.js`.

Run in PowerShell as admin if you want the installer to run automatically.
#>

$ErrorActionPreference = 'Stop'

$cwd = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $cwd

Write-Host "Working directory: $cwd"

# Load .env (simple parser)
if (Test-Path .env) {
  Write-Host "Loading .env into environment"
  Get-Content .env | ForEach-Object {
    $line = $_.Trim()
    if ($line -eq '' -or $line.StartsWith('#')) { return }
    $parts = $line -split '=',2
    if ($parts.Count -ne 2) { return }
    $name = $parts[0].Trim()
    $value = $parts[1].Trim()
    if ($name -ne '') { Set-Item -Path Env:$name -Value $value }
  }
}

function Command-Exists($cmd) {
  return $null -ne (Get-Command $cmd -ErrorAction SilentlyContinue)
}


function Try-Install-Node {
  # Attempt a portable Node download into .node (no admin required)
  $nodeDir = Join-Path $cwd '.node'
  if (Test-Path $nodeDir) { return }
  Write-Host "Attempting portable Node download (no admin)..."
  $arch = if ($env:PROCESSOR_ARCHITECTURE -match '64') { 'x64' } else { 'x86' }
  try {
    $channels = @('latest-v24.x','latest-v20.x','latest-v18.x')
    $zipName = $null
    $zipUrl = $null
    foreach ($ch in $channels) {
      $indexUrl = "https://nodejs.org/dist/$ch/"
      Write-Host "Checking $indexUrl"
      try { $resp = Invoke-WebRequest -Uri $indexUrl -UseBasicParsing -ErrorAction Stop } catch { continue }
      # find a zip matching node-v*.win-<arch>.zip or node-v* -win-<arch>.zip
      $pattern = "node-v[0-9]+\.[0-9]+\.[0-9]+-win-$arch\.zip"
      $m = Select-String -InputObject $resp.Content -Pattern $pattern -AllMatches | Select-Object -First 1
      if ($m) {
        $zipName = ($m.Matches[0].Value)
        $zipUrl = $indexUrl + $zipName
        break
      }
    }
    if (-not $zipUrl) { Write-Warning "Could not find a Node zip for $arch on known channels"; return }
    $zipPath = Join-Path $cwd $zipName
    Write-Host "Downloading $zipUrl ..."
    Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath -UseBasicParsing -ErrorAction Stop
    Write-Host "Extracting $zipName ..."
    Expand-Archive -Path $zipPath -DestinationPath $cwd -Force
    # Extracted folder like node-v20.xx.x-win-x64
    $extracted = Join-Path $cwd ([IO.Path]::GetFileNameWithoutExtension($zipName))
    if (Test-Path $extracted) {
      Rename-Item -Path $extracted -NewName '.node' -Force
    } else {
      Write-Warning "Unexpected archive structure; looking for node.exe inside extracted files."
      # try find node.exe
      $found = Get-ChildItem -Path $cwd -Recurse -Filter node.exe -ErrorAction SilentlyContinue | Select-Object -First 1
      if ($found) {
        $parent = Split-Path $found.FullName -Parent
        Move-Item -Path $parent -Destination $nodeDir -Force
      }
    }
    Remove-Item $zipPath -Force
    Write-Host "Portable Node installed to $nodeDir"
  } catch {
    Write-Warning "Portable Node install failed: $_"
  }
}

if (-not (Command-Exists node)) {
  Write-Host "Node not found. Attempting portable install (no admin)..."
  Try-Install-Node
  # add portable node to PATH for this session if present
  $nodeBin = Join-Path $cwd '.node'
  if (Test-Path (Join-Path $nodeBin 'node.exe')) {
    $env:PATH = "$nodeBin;$env:PATH"
  }
}

if (-not (Command-Exists node)) {
  Write-Error "Node.js not found after attempted install. Please install Node.js and re-run this script."
  exit 1
}

Write-Host "Node version:" (node -v)
if (Command-Exists npm) { Write-Host "npm version:" (npm -v) }

if (Test-Path package.json) {
  Write-Host "Installing dependencies (npm install)..."
  npm install
}

Write-Host "Starting server (node server.js). Press Ctrl+C to stop."
node server.js
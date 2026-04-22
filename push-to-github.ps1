#!/usr/bin/env pwsh
<#
push-to-github.ps1
Downloads a portable Git for Windows (no admin), sets it up for the session,
then initializes the repo, commits all files, adds the remote, and pushes.

Usage:
- Set environment variable GITHUB_REPO (e.g. Logicnd/Locked-Site) or pass repo as first arg
- Optional: set GITHUB_TOKEN to a Personal Access Token to enable non-interactive push.

This script performs network downloads and will prompt if push requires credentials
#>

param(
  [string]$Repo = $env:GITHUB_REPO,
  [string]$Branch = 'main'
)

$ErrorActionPreference = 'Stop'
$cwd = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $cwd

if (-not $Repo) {
  Write-Error "No repository specified. Set GITHUB_REPO or pass repo as first argument (owner/name)."
  exit 1
}

function Command-Exists($cmd) { return $null -ne (Get-Command $cmd -ErrorAction SilentlyContinue) }

function Install-Portable-Git {
  $gitDir = Join-Path $cwd '.gitbin'
  if (Test-Path $gitDir) { return $gitDir }
  Write-Host "Downloading portable Git for Windows..."
  $api = 'https://api.github.com/repos/git-for-windows/git/releases/latest'
  try {
    $resp = Invoke-RestMethod -Uri $api -ErrorAction Stop
    $asset = $resp.assets | Where-Object { $_.name -match 'PortableGit' -and $_.name -like '*.zip' } | Select-Object -First 1
    if (-not $asset) { $asset = $resp.assets | Where-Object { $_.name -match 'MinGit' -and $_.name -like '*.zip' } | Select-Object -First 1 }
    if (-not $asset) { $asset = $resp.assets | Where-Object { $_.name -match 'PortableGit' } | Select-Object -First 1 }
    if (-not $asset) { Write-Warning "Could not find PortableGit asset on latest release."; return $null }
    $url = $asset.browser_download_url
    $zipPath = Join-Path $cwd $asset.name
    Invoke-WebRequest -Uri $url -OutFile $zipPath -UseBasicParsing -ErrorAction Stop
    Expand-Archive -Path $zipPath -DestinationPath $cwd -Force
    # Find extracted folder (PortableGit) or check for MinGit extracted files (cmd/git.exe)
    $extracted = Get-ChildItem -Path $cwd -Directory | Where-Object { $_.Name -like 'PortableGit*' } | Select-Object -First 1
    if ($extracted) {
      Rename-Item -Path $extracted.FullName -NewName '.gitbin' -Force
    } else {
      # if MinGit extracts top-level folders (cmd, usr, etc), move them into .gitbin
      if (Test-Path (Join-Path $cwd 'cmd\git.exe')) {
        New-Item -Path (Join-Path $cwd '.gitbin') -ItemType Directory -Force | Out-Null
        Get-ChildItem -Path $cwd | Where-Object { $_.Name -notin '.gitbin', (Split-Path -Leaf $zipPath) } | ForEach-Object {
          Move-Item -Path $_.FullName -Destination (Join-Path $cwd '.gitbin') -Force
        }
      } else {
        Write-Warning "Portable Git extraction failed."; return $null
      }
    }
    Remove-Item $zipPath -Force
    return Join-Path $cwd '.gitbin'
  } catch {
    Write-Warning "Portable Git install failed: $_"
    return $null
  }
}

$gitbin = $null
if (-not (Command-Exists git)) {
  $gitbin = Install-Portable-Git
  if ($gitbin) { $env:PATH = (Join-Path $gitbin 'cmd') + ';' + $env:PATH }
}

if (-not (Command-Exists git)) {
  Write-Error "git is not available and portable install failed. Please install Git and re-run."
  exit 1
}

Write-Host "Using git:" (git --version)

if (-not (Test-Path .git)) { git init }
git add .
try { git commit -m "Initial commit: Locked Site - minimal password-protected site" } catch { Write-Host "No changes to commit or commit failed: $_" }
git branch -M $Branch

$remoteUrl = "https://github.com/$Repo.git"
if ($env:GITHUB_TOKEN) {
  $token = $env:GITHUB_TOKEN
  # embed token for non-interactive push
  $authUrl = $remoteUrl -replace 'https://', "https://$token@"
  git remote remove origin 2>$null | Out-Null
  git remote add origin $authUrl
} else {
  git remote remove origin 2>$null | Out-Null
  git remote add origin $remoteUrl
}

Write-Host "Pushing to $Repo on branch $Branch..."
try {
  git push -u origin $Branch
  Write-Host "Push succeeded."
} catch {
  Write-Warning ("Push may have failed or requires authentication: " + $_)
}

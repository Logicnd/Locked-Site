#!/usr/bin/env pwsh
<#
push-to-github-run.ps1
Lightweight runner: if GITHUB_TOKEN is set, push the current repo to the given remote.
This assumes git is available (or .gitbin was added to PATH by setup scripts).
#>

param(
  [string]$Repo = $env:GITHUB_REPO,
  [string]$Branch = 'main'
)

if (-not $Repo) { Write-Error "Provide repo as owner/name or set GITHUB_REPO"; exit 1 }

function Command-Exists($cmd) { return $null -ne (Get-Command $cmd -ErrorAction SilentlyContinue) }
if (-not (Command-Exists git)) { Write-Error "git not found in PATH. Run setup-and-run.ps1 or install Git."; exit 1 }

if (-not (Test-Path .git)) { Write-Host "No .git found - initializing and committing"; git init; git add .; git commit -m "Initial commit" -q }

$remoteUrl = "https://github.com/$Repo.git"
if ($env:GITHUB_TOKEN) {
  $token = $env:GITHUB_TOKEN
  $authUrl = $remoteUrl -replace 'https://', "https://$token@"
  try { git remote remove origin 2>$null } catch { }
  git remote add origin $authUrl
  git push -u origin $Branch
  Write-Host "Pushed to $Repo"
} else {
  try { git remote remove origin 2>$null } catch { }
  git remote add origin $remoteUrl
  Write-Host "Added remote $remoteUrl. To push interactively run: git push -u origin $Branch"
}

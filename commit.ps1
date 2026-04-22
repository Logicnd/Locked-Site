param(
  [string]$Message = "Reset to simple static site"
)

function Command-Exists($cmd) { return $null -ne (Get-Command $cmd -ErrorAction SilentlyContinue) }
if (-not (Command-Exists git)) {
  Write-Error "git not found in PATH. Install Git or place a portable Git binary in .gitbin and add to PATH."
  exit 1
}

git add -A
try {
  git commit -m $Message
} catch {
  Write-Host "Nothing to commit or commit failed: $_"
}

try {
  git push -u origin main
} catch {
  Write-Warning "Push failed or requires authentication. Run 'git push' interactively if needed."
}

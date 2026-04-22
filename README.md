# Locked Site

Minimal password-protected site for local testing.

Usage

- Copy or edit `.env` to set `LOCKED_SITE_PASSWORD`, `SESSION_SECRET`, and `LOG_SALT`.
- Run the prepared helper to install a no-admin portable Node and start the server:

```powershell
.\setup-and-run.ps1
```

Or, to push to GitHub non-interactively, set `GITHUB_TOKEN` (repo scope) and run:

```powershell
$env:GITHUB_TOKEN = 'ghp_...'
$env:PATH = (Join-Path $PWD '.gitbin\cmd') + ';' + $env:PATH
.\push-to-github-run.ps1 Logicnd/Locked-Site
```

Notes
- Access logs are anonymized (hashed IDs) in `access_log.json`.
- Session store is in-memory (not for production).

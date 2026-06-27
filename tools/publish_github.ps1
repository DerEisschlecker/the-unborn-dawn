# Publishes this project to GitHub (run once after: gh auth login)
$ErrorActionPreference = "Stop"
$env:Path = "C:\Program Files\Git\cmd;C:\Program Files\GitHub CLI;" + $env:Path
Set-Location (Join-Path $PSScriptRoot "..")

gh auth status | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Nicht bei GitHub angemeldet. Starte Anmeldung..."
    gh auth login --hostname github.com --git-protocol https --web
}

$repoName = "the-unborn-dawn"
$remote = git remote get-url origin 2>$null
if (-not $remote) {
    gh repo create $repoName --public --source=. --remote=origin --description "Last Light - post-apocalyptic survival game (Godot 4.6)" --push
} else {
    git push -u origin main
}

Write-Host "Fertig. Repository:" (gh repo view --json url -q .url)

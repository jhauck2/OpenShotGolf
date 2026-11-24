<#
.SYNOPSIS
    Installs git hooks for Heckle Golf Simulator.
#>
$RepoRoot = if ($PSScriptRoot) { (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) } else { (Get-Location).Path }
$sourceHook = Join-Path $RepoRoot "scripts\hooks\pre-commit"
$targetHook = Join-Path $RepoRoot ".git\hooks\pre-commit"

if (Test-Path (Join-Path $RepoRoot ".git")) {
    $hooksDir = Join-Path $RepoRoot ".git\hooks"
    if (-not (Test-Path $hooksDir)) {
        New-Item -ItemType Directory -Path $hooksDir -Force | Out-Null
    }
    Copy-Item -Path $sourceHook -Destination $targetHook -Force
    Write-Host "[InstallHooks] Installed pre-commit hook to $targetHook" -ForegroundColor Green
} else {
    Write-Warning "[InstallHooks] Not a git repository or .git directory not found."
}

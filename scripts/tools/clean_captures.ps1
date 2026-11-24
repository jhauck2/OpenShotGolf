<#
.SYNOPSIS
    Cleans up verification capture files and terminates lingering background Godot instances.
.DESCRIPTION
    Deletes all temporary verification artifacts (screenshots, MP4 videos, GIFs, HTML viewers,
    and temporary AVIs) created during feature approval reviews so they never linger or clutter disk space.
    Also ensures no runaway or orphaned Godot game instances or Python helper servers continue
    running in the background.

    Runs automatically via the Git pre-commit hook or directly when a feature is approved.

.PARAMETER Quiet
    Suppress informational output for silent execution (e.g. within pre-commit hooks).

.PARAMETER KeepVideos
    If specified, keeps video files and only removes screenshots and temporary AVIs.

.EXAMPLE
    .\clean_captures.ps1

.EXAMPLE
    .\clean_captures.ps1 -Quiet
#>

[CmdletBinding()]
param(
    [Parameter()]
    [switch]$Quiet,

    [Parameter()]
    [switch]$KeepVideos,

    [Parameter()]
    [switch]$SkipProcessCheck
)

$ErrorActionPreference = "SilentlyContinue"

# Repo Root
$RepoRoot = if ($PSScriptRoot) { (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) } else { (Get-Location).Path }

# 1. Terminate Lingering Godot & Child Helper Processes
$killedProcesses = 0
if (-not $SkipProcessCheck) {
    # Check for Godot game instances (exclude editor instances unless they match test capture args)
    try {
        $godotProcs = Get-CimInstance Win32_Process -Filter "Name LIKE '%godot%'" -ErrorAction SilentlyContinue
        foreach ($proc in $godotProcs) {
            $cmd = $proc.CommandLine
            $isEditor = ($cmd -match '(\s--editor|\s-e\b)') -and ($cmd -notmatch '--screenshot|--write-movie|--shot')
            if (-not $isEditor) {
                # This is a game instance or automated capture instance
                Stop-Process -Id $proc.ProcessId -Force -ErrorAction SilentlyContinue
                $killedProcesses++
                if (-not $Quiet) {
                    Write-Host "[CleanCaptures] Terminated background Godot instance (PID $($proc.ProcessId))" -ForegroundColor Yellow
                }
            }
        }
    } catch {}

    # Check for orphaned python helper servers (pose & putting camera servers)
    try {
        $pyProcs = Get-CimInstance Win32_Process -Filter "Name LIKE '%python%'" -ErrorAction SilentlyContinue
        foreach ($proc in $pyProcs) {
            $cmd = $proc.CommandLine
            if ($cmd -match 'pose_server\.py|putting_camera_server\.py') {
                Stop-Process -Id $proc.ProcessId -Force -ErrorAction SilentlyContinue
                $killedProcesses++
                if (-not $Quiet) {
                    Write-Host "[CleanCaptures] Terminated orphaned helper server (PID $($proc.ProcessId))" -ForegroundColor Yellow
                }
            }
        }
    } catch {}
}

# 2. Clean Up Capture Directory & Root Verification Files
$capturesDir = Join-Path $RepoRoot "captures"
$deletedCount = 0
$freedBytes = 0

if (Test-Path $capturesDir) {
    $filters = if ($KeepVideos) {
        @("*.png", "*.jpg", "*.gif", "*.avi", "*.wav", "*.html", "temp_*")
    } else {
        @("*.*")
    }

    foreach ($filter in $filters) {
        $files = Get-ChildItem -Path $capturesDir -Filter $filter -File -Recurse -ErrorAction SilentlyContinue
        foreach ($f in $files) {
            $freedBytes += $f.Length
            Remove-Item -Path $f.FullName -Force -ErrorAction SilentlyContinue
            $deletedCount++
        }
    }
}

# Clean root stray capture files
$rootStrayPatterns = @("temp_recording_*.avi", "test_*.png", "test_*.mp4", "test_*.avi", "test_*.gif")
foreach ($pattern in $rootStrayPatterns) {
    $strays = Get-ChildItem -Path $RepoRoot -Filter $pattern -File -ErrorAction SilentlyContinue
    foreach ($s in $strays) {
        $freedBytes += $s.Length
        Remove-Item -Path $s.FullName -Force -ErrorAction SilentlyContinue
        $deletedCount++
    }
}

if (-not $Quiet) {
    $freedMB = [math]::Round($freedBytes / 1MB, 2)
    Write-Host "[CleanCaptures] Cleanup complete." -ForegroundColor Green
    Write-Host "  Deleted review files:    $deletedCount ($freedMB MB freed)" -ForegroundColor Gray
    Write-Host "  Terminated processes:    $killedProcesses" -ForegroundColor Gray
}

exit 0

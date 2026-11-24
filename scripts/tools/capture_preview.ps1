<#
.SYNOPSIS
    Automated visual capture tool for Heckle Golf Simulator.
.DESCRIPTION
    Launches the Godot application (or a specific scene) to capture high-quality
    screenshots, video recordings (.avi/.mp4), and animated GIFs for feature
    approvals, UI/UX visual validation, and release reviews.

.PARAMETER Scene
    Optional Godot scene path (e.g. "res://UI/MainMenu/main_menu.tscn" or "res://UI/SettingsMenu/settings_menu.tscn").
    Defaults to the project's main scene.

.PARAMETER Screenshot
    File path for the output PNG screenshot (e.g. "captures/main_menu.png").

.PARAMETER Video
    File path for the output video recording (e.g. "captures/feature_flow.mp4" or "captures/run.avi").

.PARAMETER Gif
    File path for an animated GIF recording (e.g. "captures/preview.gif").

.PARAMETER DelaySeconds
    Delay in seconds before capturing the screenshot or triggering interactions (default: 2.0).

.PARAMETER DurationSeconds
    Total recording duration in seconds before auto-quitting (default: 3.0 for video, 0.0 for screenshots).

.PARAMETER Click
    Optional button text, name, or node path to simulate clicking before screenshot (e.g. "SETTINGS" or "Settings;Audio").

.PARAMETER ClickDelay
    Delay in seconds between simulated clicks (default: 0.5).

.PARAMETER Resolution
    Window resolution for capture (default: "1280x720").

.PARAMETER FixedFps
    Recording framerate for video capture (default: 30).

.PARAMETER Interactive
    If specified, launches the game in windowed mode and leaves it open for manual testing.

.PARAMETER OutputDir
    Base directory for outputs if relative paths are passed (default: "captures").

.PARAMETER GodotBin
    Explicit path to Godot executable (optional).

.EXAMPLE
    .\capture_preview.ps1 -Screenshot "captures/main_menu.png" -DelaySeconds 2.0

.EXAMPLE
    .\capture_preview.ps1 -Scene "res://UI/SettingsMenu/settings_menu.tscn" -Screenshot "captures/settings.png" -Click "Audio"

.EXAMPLE
    .\capture_preview.ps1 -Video "captures/intro.mp4" -Gif "captures/intro.gif" -DurationSeconds 4.0

.EXAMPLE
    .\capture_preview.ps1 -Scene "res://Courses/Range/range.tscn" -Shot "wedge" -Video "captures/range_wedge_shot.mp4" -Gif "captures/range_wedge_shot.gif"
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$Scene = "",

    [Parameter()]
    [string]$Screenshot = "",

    [Parameter()]
    [string]$Video = "",

    [Parameter()]
    [string]$Gif = "",

    [Parameter()]
    [double]$DelaySeconds = 2.0,

    [Parameter()]
    [double]$DurationSeconds = 0.0,

    [Parameter()]
    [string]$Click = "",

    [Parameter()]
    [double]$ClickDelay = 0.5,

    [Parameter()]
    [string]$Shot = "",

    [Parameter()]
    [switch]$WaitForRest,

    [Parameter()]
    [string]$Resolution = "1280x720",

    [Parameter()]
    [int]$FixedFps = 30,

    [Parameter()]
    [switch]$Interactive,

    [Parameter()]
    [string]$OutputDir = "captures",

    [Parameter()]
    [string]$ExtraArgs = "",

    [Parameter()]
    [string]$GodotBin = ""
)

$ErrorActionPreference = "Stop"

# Locate Repo Root
$RepoRoot = if ($PSScriptRoot) { (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) } else { (Get-Location).Path }
$buildHelpers = Join-Path $RepoRoot "scripts\build_helpers.ps1"
if (Test-Path $buildHelpers) {
    . $buildHelpers
}

# Locate Godot
$godotExe = $GodotBin
if (-not $godotExe -or -not (Test-Path $godotExe)) {
    if (Get-Command Find-GodotExecutable -ErrorAction SilentlyContinue) {
        $godotExe = Find-GodotExecutable
    }
}

if (-not $godotExe -or -not (Test-Path $godotExe)) {
    Write-Error "[CapturePreview] Godot Mono executable not found. Please set -GodotBin or ensure Godot is installed."
    exit 1
}

if (Get-Command Configure-DotNet -ErrorAction SilentlyContinue) {
    Configure-DotNet
}

# Ensure Output Directory
$fullOutputDir = if ([System.IO.Path]::IsPathRooted($OutputDir)) { $OutputDir } else { Join-Path $RepoRoot $OutputDir }
if (-not (Test-Path $fullOutputDir)) {
    New-Item -ItemType Directory -Path $fullOutputDir -Force | Out-Null
}

function Resolve-CapturePath([string]$PathStr, [string]$DefaultName, [string]$DefaultExt) {
    if (-not $PathStr) { return "" }
    $p = $PathStr
    if (-not [System.IO.Path]::HasExtension($p)) {
        $p = "$p.$DefaultExt"
    }
    if ([System.IO.Path]::IsPathRooted($p)) {
        $fullPath = [System.IO.Path]::GetFullPath($p)
    } else {
        $cleanRel = $p.TrimStart(".\/").Replace("\", "/")
        $cleanOut = $OutputDir.TrimStart(".\/").TrimEnd("\/").Replace("\", "/")
        if ($cleanRel.StartsWith($cleanOut, [System.StringComparison]::OrdinalIgnoreCase)) {
            $fullPath = [System.IO.Path]::GetFullPath((Join-Path $RepoRoot $p))
        } else {
            $fullPath = [System.IO.Path]::GetFullPath((Join-Path $fullOutputDir $p))
        }
    }
    $parent = Split-Path -Parent $fullPath
    if ($parent -and -not (Test-Path $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    return $fullPath
}

$screenshotPath = Resolve-CapturePath $Screenshot "screenshot" "png"
$videoPath = Resolve-CapturePath $Video "capture" "mp4"
$gifPath = Resolve-CapturePath $Gif "capture" "gif"

# Handle Interactive Mode
if ($Interactive) {
    Write-Host "[CapturePreview] Launching Godot interactively..." -ForegroundColor Cyan
    $argsList = @("--path", $RepoRoot, "--resolution", $Resolution)
    if ($Scene) { $argsList += $Scene }
    Start-Process -FilePath $godotExe -ArgumentList $argsList
    Write-Host "[CapturePreview] Godot window started. Press F12 in-game anytime to take a manual screenshot." -ForegroundColor Green
    exit 0
}

# If no target specified, default to a screenshot
if (-not $screenshotPath -and -not $videoPath -and -not $gifPath) {
    $screenshotPath = Join-Path $fullOutputDir "screenshot.png"
}

# Determine Video Recording Requirements
$recordingRequired = [bool]($videoPath -or $gifPath)
$tempAviPath = ""
if ($recordingRequired) {
    if ($DurationSeconds -le 0.0 -and -not $Shot -and -not $WaitForRest) {
        $DurationSeconds = 3.0
    }
    if ($videoPath -and $videoPath.ToLower().EndsWith(".avi") -and -not $gifPath) {
        $tempAviPath = $videoPath
    } else {
        $tempAviPath = Join-Path $fullOutputDir "temp_recording_$([System.Guid]::NewGuid().ToString('N').Substring(0,8)).avi"
    }
}

# Build Godot Arguments
$godotArgs = @("--path", $RepoRoot, "--resolution", $Resolution)

if ($recordingRequired) {
    $godotArgs += @("--write-movie", $tempAviPath, "--fixed-fps", "$FixedFps")
}

if ($Scene) {
    $godotArgs += $Scene
}

# User Arguments (after --)
$userArgs = @()
if ($screenshotPath) {
    $userArgs += "--screenshot=$screenshotPath"
}
if ($DelaySeconds -gt 0) {
    $userArgs += "--delay=$DelaySeconds"
}
if ($DurationSeconds -gt 0) {
    $userArgs += "--duration=$DurationSeconds"
}
if ($Click) {
    $userArgs += "--click=$Click"
    $userArgs += "--click-delay=$ClickDelay"
}
if ($Shot) {
    $userArgs += "--shot=$Shot"
}
if ($WaitForRest -or $Shot) {
    $userArgs += "--wait-for-rest"
}
if ($ExtraArgs) {
    $userArgs += $ExtraArgs.Split(" ")
}

$finalArgList = @()
$finalArgList += $godotArgs
if ($userArgs.Count -gt 0) {
    $finalArgList += "--"
    $finalArgList += $userArgs
}

Write-Host "[CapturePreview] Running Godot capture sequence..." -ForegroundColor Cyan
Write-Host "  Scene:      $(if ($Scene) { $Scene } else { 'Default Main Scene' })" -ForegroundColor Gray
Write-Host "  Resolution: $Resolution" -ForegroundColor Gray
if ($screenshotPath) { Write-Host "  Screenshot: $screenshotPath (Delay: ${DelaySeconds}s)" -ForegroundColor Gray }
if ($recordingRequired) { Write-Host "  Recording:  $DurationSeconds seconds @ $FixedFps FPS" -ForegroundColor Gray }
if ($Click) { Write-Host "  Click:      $Click" -ForegroundColor Gray }

$maxWaitSeconds = [math]::Max(35, [int]($DelaySeconds + $DurationSeconds + 25))
if ($recordingRequired -and ($Shot -or $WaitForRest)) {
    $maxWaitSeconds = [math]::Max(180, [int]($DelaySeconds + $DurationSeconds + 150))
}
Write-Host "  Watchdog:   Max timeout ${maxWaitSeconds}s" -ForegroundColor Gray

$process = Start-Process -FilePath $godotExe -ArgumentList $finalArgList -PassThru -NoNewWindow
$exited = $process.WaitForExit($maxWaitSeconds * 1000)

if (-not $exited) {
    Write-Warning "[CapturePreview] WATCHDOG FIRED: Godot process (PID $($process.Id)) exceeded $maxWaitSeconds seconds! Force terminating runaway process..."
    Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
    $exitCode = -1
} else {
    $exitCode = $process.ExitCode
}

# Post-capture cleanup: ensure any spawned child helper servers (e.g. pose/putting python servers) are terminated
try {
    $helperProcs = Get-CimInstance Win32_Process -Filter "Name LIKE '%python%'" -ErrorAction SilentlyContinue
    foreach ($p in $helperProcs) {
        if ($p.CommandLine -match 'pose_server\.py|putting_camera_server\.py') {
            Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue
        }
    }
} catch {}

if ($exitCode -ne 0) {
    Write-Warning "[CapturePreview] Godot process exited with code $exitCode."
}

# Process Video / GIF Conversions
$converterScript = Join-Path $RepoRoot "scripts\tools\convert_capture.py"
if ($recordingRequired -and (Test-Path $tempAviPath)) {
    Write-Host "[CapturePreview] Processing video recordings..." -ForegroundColor Cyan
    $pyArgs = @($converterScript, "--input", $tempAviPath)

    $needsConversion = $false
    $htmlPath = if ($videoPath) { [System.IO.Path]::ChangeExtension($videoPath, ".html") } else { "" }
    if ($videoPath -and $videoPath.ToLower().EndsWith(".mp4")) {
        $pyArgs += @("--mp4", $videoPath)
        if ($htmlPath) {
            $pyArgs += @("--html", $htmlPath)
        }
        $needsConversion = $true
    }
    if ($gifPath) {
        $pyArgs += @("--gif", $gifPath)
        $needsConversion = $true
    }

    if ($needsConversion) {
        if ($tempAviPath -ne $videoPath) {
            $pyArgs += "--remove-source"
        }
        & python @pyArgs
    }
}

# Generate Report & Verify Output Files
Write-Host ""
Write-Host "=================================================================" -ForegroundColor Green
Write-Host "                  VISUAL CAPTURE SUMMARY                         " -ForegroundColor Green
Write-Host "=================================================================" -ForegroundColor Green

$results = @()
if ($screenshotPath -and (Test-Path $screenshotPath)) {
    $item = Get-Item $screenshotPath
    $forwardSlashPath = $screenshotPath.Replace("\", "/")
    $results += [PSCustomObject]@{
        Type = "Screenshot"
        Path = $screenshotPath
        Size = "$([math]::Round($item.Length / 1KB, 1)) KB"
        Markdown = "![$($item.Name)](file:///$forwardSlashPath)"
    }
}

if ($videoPath -and (Test-Path $videoPath)) {
    $item = Get-Item $videoPath
    $forwardSlashPath = $videoPath.Replace("\", "/")
    $results += [PSCustomObject]@{
        Type = "Video"
        Path = $videoPath
        Size = "$([math]::Round($item.Length / 1KB, 1)) KB"
        Markdown = "[$($item.Name)](file:///$forwardSlashPath)"
    }
}

if ($htmlPath -and (Test-Path $htmlPath)) {
    $item = Get-Item $htmlPath
    $forwardSlashPath = $htmlPath.Replace("\", "/")
    $results += [PSCustomObject]@{
        Type = "HTML Viewer"
        Path = $htmlPath
        Size = "$([math]::Round($item.Length / 1KB, 1)) KB"
        Markdown = "[$($item.Name)](file:///$forwardSlashPath)"
    }
}

if ($gifPath -and (Test-Path $gifPath)) {
    $item = Get-Item $gifPath
    $forwardSlashPath = $gifPath.Replace("\", "/")
    $results += [PSCustomObject]@{
        Type = "GIF Animation"
        Path = $gifPath
        Size = "$([math]::Round($item.Length / 1KB, 1)) KB"
        Markdown = "![$($item.Name)](file:///$forwardSlashPath)"
    }
}

if ($results.Count -gt 0) {
    $results | Format-Table -Property Type, Size, Path -AutoSize
    Write-Host ""
    Write-Host "Markdown snippet for direct presentation:" -ForegroundColor Yellow
    foreach ($r in $results) {
        Write-Host "  $($r.Markdown)" -ForegroundColor White
    }
} else {
    Write-Error "[CapturePreview] No output capture files were produced."
    exit 1
}

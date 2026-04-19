param(
    [string]$ProjectPath = (Join-Path $PSScriptRoot ".."),
    [int]$DebounceMs = 500,
    [switch]$DryRun,
    [switch]$RunOnce
)

$ErrorActionPreference = "Stop"
$projectRoot = (Resolve-Path $ProjectPath).Path
$relaunchScript = Join-Path $PSScriptRoot "relaunch-love.ps1"
$watchedExtensions = @(
    ".lua",
    ".png",
    ".jpg",
    ".jpeg",
    ".ogg",
    ".wav",
    ".mp3",
    ".ttf",
    ".otf",
    ".json",
    ".txt",
    ".frag",
    ".vert",
    ".glsl"
)

function Should-WatchPath {
    param([string]$Path)

    if (-not $Path) {
        return $false
    }

    $extension = [System.IO.Path]::GetExtension($Path).ToLowerInvariant()

    if ($watchedExtensions -notcontains $extension) {
        return $false
    }

    foreach ($ignoredSegment in @("\.git\", "\dist\", "\build\", "\tmp\", "\temp\")) {
        if ($Path.Contains($ignoredSegment)) {
            return $false
        }
    }

    return $true
}

function Invoke-Relaunch {
    $arguments = @{
        ProjectPath = $projectRoot
        DryRun      = $DryRun
    }

    & $relaunchScript @arguments
}

Write-Host "Watching $projectRoot"
Invoke-Relaunch

if ($RunOnce) {
    return
}

$watcher = New-Object System.IO.FileSystemWatcher
$watcher.Path = $projectRoot
$watcher.Filter = "*.*"
$watcher.IncludeSubdirectories = $true
$watcher.NotifyFilter = [System.IO.NotifyFilters]"FileName, LastWrite, CreationTime, Size, DirectoryName"

$pendingRestart = $false
$lastChangeAt = Get-Date

try {
    while ($true) {
        $change = $watcher.WaitForChanged([System.IO.WatcherChangeTypes]::All, 200)

        if (-not $change.TimedOut) {
            $changedPath = Join-Path $projectRoot $change.Name

            if (Should-WatchPath $changedPath) {
                $pendingRestart = $true
                $lastChangeAt = Get-Date
                Write-Host "Change detected: $($change.Name)"
            }
        }

        if ($pendingRestart) {
            $elapsed = ((Get-Date) - $lastChangeAt).TotalMilliseconds

            if ($elapsed -ge $DebounceMs) {
                $pendingRestart = $false
                Write-Host "Relaunching LÖVE..."
                Invoke-Relaunch
            }
        }
    }
}
finally {
    $watcher.Dispose()
}

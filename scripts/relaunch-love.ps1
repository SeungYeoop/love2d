param(
    [string]$ProjectPath = (Join-Path $PSScriptRoot ".."),
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

function Resolve-LoveExecutable {
    $candidates = @()
    if ($env:ProgramFiles)        { $candidates += Join-Path $env:ProgramFiles        "LOVE\love.exe" }
    if (${env:ProgramFiles(x86)}) { $candidates += Join-Path ${env:ProgramFiles(x86)} "LOVE\love.exe" }
    foreach ($c in ($candidates | Select-Object -Unique)) {
        if ($c -and (Test-Path $c)) { return (Resolve-Path $c).Path }
    }
    throw "love.exe not found. Install LÖVE or add it to PATH."
}

$projectRoot   = (Resolve-Path $ProjectPath).Path
$loveExe       = Resolve-LoveExecutable
$tempDirectory = Join-Path $projectRoot "tmp"
$pidFile       = Join-Path $tempDirectory "love.pid"

# LÖVE는 비-ASCII 경로를 읽지 못한다 — 게임 파일만 ASCII 경로로 미러한다.
$safeRoot    = "C:\love2drun"
$excludeDirs = @(".git", "tmp", ".vscode", "scripts", "prompts")
$excludeExts = @(".md", ".cmd", ".ps1", ".pid", ".gitignore", ".gitkeep")

if (-not (Test-Path $safeRoot)) { New-Item -ItemType Directory -Path $safeRoot | Out-Null }

Get-ChildItem -Path $projectRoot -Recurse -File | Where-Object {
    $rel      = $_.FullName.Substring($projectRoot.Length).TrimStart('\', '/')
    $topLevel = ($rel -split '[/\\]')[0]
    ($excludeDirs -notcontains $topLevel) -and
    ($excludeExts -notcontains $_.Extension.ToLower())
} | ForEach-Object {
    $rel     = $_.FullName.Substring($projectRoot.Length).TrimStart('\', '/')
    $dest    = Join-Path $safeRoot $rel
    $destDir = Split-Path $dest -Parent
    if (-not (Test-Path $destDir)) { New-Item -ItemType Directory -Path $destDir -Force | Out-Null }
    Copy-Item $_.FullName -Destination $dest -Force
}

# PID 파일로 이전 프로세스 종료
$previousPid    = $null
$trackedProcess = $null

if (-not (Test-Path $tempDirectory)) { New-Item -ItemType Directory -Path $tempDirectory | Out-Null }

if (Test-Path $pidFile) {
    $pidText = Get-Content $pidFile -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($pidText) { $previousPid = $pidText.Trim() }
    if ($previousPid) { $trackedProcess = Get-Process -Id $previousPid -ErrorAction SilentlyContinue }
}

if ($DryRun) {
    [PSCustomObject]@{
        ProjectPath      = $projectRoot
        SafePath         = $safeRoot
        LoveExecutable   = $loveExe
        PidFile          = $pidFile
        PreviousProcess  = $previousPid
        ProcessIsRunning = [bool]$trackedProcess
    }
    return
}

if ($trackedProcess) {
    Stop-Process -Id $trackedProcess.Id -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 150
}

if (Test-Path $pidFile) { Remove-Item -Path $pidFile -Force -ErrorAction SilentlyContinue }

$process = Start-Process -FilePath $loveExe -ArgumentList @($safeRoot) -WorkingDirectory $safeRoot -PassThru
Set-Content -Path $pidFile -Value $process.Id -Encoding ascii
Write-Host "LÖVE relaunched → $safeRoot"

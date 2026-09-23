param(
    [Parameter(Mandatory=$true)][string]$PackageDir,
    [Parameter(Mandatory=$true)][string]$PreviousPackageDir,
    [string]$ModsDir = (Join-Path $env:APPDATA 'Balatro\Mods')
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$targetMod = Join-Path (Resolve-Path -LiteralPath $ModsDir).Path 'TenYearsNineGrid'
$previousRelease = (Resolve-Path -LiteralPath $PreviousPackageDir).Path
$sourceMod = (Resolve-Path -LiteralPath $PackageDir).Path
$metadata = Get-Content -LiteralPath (Join-Path $sourceMod 'json.json') -Raw | ConvertFrom-Json
if ($metadata.id -ne 'ten_years_nine_grid' -or $metadata.version -ne '0.7.0') { throw 'Unexpected package identity/version.' }
if (Get-Process -Name Balatro -ErrorAction SilentlyContinue) { throw 'Balatro is running. No files changed. Save and exit the game first.' }
$files = @('assets.lua','birth_ui.lua','calendar.lua','calendar_data.lua','chart_patterns.lua','pattern_matcher.lua','pattern_jokers.lua','presets.lua','config.lua','cycles.lua','fortunes.lua','json.json','main.lua','natal_jokers.lua','packs.lua','resume.lua','rules.lua')
foreach ($scale in @(1,2)) { foreach ($atlas in @('deck','fortune','natal','patterns','legacy_booster')) { $files += "assets/${scale}x/$atlas.png" } }
if ((Get-ChildItem -LiteralPath $sourceMod -File -Recurse).Count -ne $files.Count) { throw 'Package contains unexpected files.' }
if (Test-Path -LiteralPath (Join-Path $targetMod '.lovelyignore')) { throw 'Mod was explicitly disabled; refusing to override that flag.' }
foreach ($name in $files) {
    $source = Join-Path $sourceMod $name
    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw "Missing source file: $name" }
    $target = Join-Path $targetMod $name
    $old = Join-Path $previousRelease $name
    if (Test-Path -LiteralPath $target) {
        if (-not (Test-Path -LiteralPath $old)) { throw "Unexpected existing file; preserve it: $name" }
        if ((Get-FileHash -LiteralPath $target).Hash -ne (Get-FileHash -LiteralPath $old).Hash) { throw "Existing file changed outside this task: $name" }
    }
}
$backup = Join-Path $projectRoot ('backups\installed-before-0.7-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
if (Test-Path -LiteralPath $backup) { throw 'Backup already exists.' }
New-Item -ItemType Directory -Path (Split-Path -Parent $backup) -Force | Out-Null
Copy-Item -LiteralPath $targetMod -Destination $backup -Recurse
if (Get-Process -Name Balatro -ErrorAction SilentlyContinue) { throw 'Game started during preparation; old files left in place.' }
foreach ($name in $files) {
    $target = Join-Path $targetMod $name
    New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $sourceMod $name) -Destination $target -Force
    if ((Get-FileHash -LiteralPath $target).Hash -ne (Get-FileHash -LiteralPath (Join-Path $sourceMod $name)).Hash) { throw "Installed hash mismatch: $name" }
}
Write-Output "INSTALLED 0.7.0: $targetMod"
Write-Output "BACKUP: $backup"
Write-Output 'All27 runtime files including10 PNGs verified. No game launch, save modification or other mod changes.'

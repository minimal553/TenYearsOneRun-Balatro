$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$sourceMod = Join-Path $projectRoot 'mod\TenYearsNineGrid'
$releaseRoot = Join-Path $projectRoot 'release'
$buildId = Get-Date -Format 'yyyyMMdd-HHmmss'
$stageRoot = Join-Path $releaseRoot ('stage-' + $buildId)
$stageMod = Join-Path $stageRoot 'TenYearsNineGrid'
$modVersion = (Get-Content -LiteralPath (Join-Path $sourceMod 'json.json') -Raw | ConvertFrom-Json).version
$zipPath = Join-Path $releaseRoot ('TenYearsNineGrid-' + $modVersion + '-' + $buildId + '.zip')
if (Test-Path -LiteralPath $stageRoot) { throw 'Build destination already exists.' }
New-Item -ItemType Directory -Path $stageMod -Force | Out-Null
$runtimeFiles = @('assets.lua','birth_ui.lua','calendar.lua','calendar_data.lua','chart_patterns.lua','pattern_matcher.lua','pattern_jokers.lua','presets.lua','config.lua','cycles.lua','fortunes.lua','json.json','main.lua','natal_jokers.lua','packs.lua','resume.lua','rules.lua')
foreach ($scale in @(1,2)) { foreach ($atlas in @('deck','fortune','natal','patterns','legacy_booster')) { $runtimeFiles += "assets/${scale}x/$atlas.png" } }
foreach ($name in $runtimeFiles) {
    New-Item -ItemType Directory -Path (Split-Path -Parent (Join-Path $stageMod $name)) -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $sourceMod $name) -Destination (Join-Path $stageMod $name)
}
$packageReadme = (Get-Content -LiteralPath (Join-Path $projectRoot 'README.md') -Raw).Replace('](mod/TenYearsNineGrid/','](TenYearsNineGrid/')
[IO.File]::WriteAllText((Join-Path $stageRoot 'README.md'), $packageReadme, [Text.UTF8Encoding]::new($false))
Copy-Item -LiteralPath (Join-Path $projectRoot 'KNOWN-ISSUES.md') -Destination (Join-Path $stageRoot 'KNOWN-ISSUES.md')
Copy-Item -LiteralPath (Join-Path $projectRoot 'VERIFICATION.md') -Destination (Join-Path $stageRoot 'VERIFICATION.md')
Copy-Item -LiteralPath (Join-Path $projectRoot 'CHANGELOG.md') -Destination (Join-Path $stageRoot 'CHANGELOG.md')
Copy-Item -LiteralPath (Join-Path $projectRoot 'README.en.md') -Destination (Join-Path $stageRoot 'README.en.md')
$stageDocs = Join-Path $stageRoot 'docs'
New-Item -ItemType Directory -Path $stageDocs -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $projectRoot 'docs\PATTERN-RULES.md') -Destination $stageDocs
foreach ($doc in @('ASSETS.md','DEVELOPMENT.md','runtime-files.sha256','images')) {
    Copy-Item -LiteralPath (Join-Path (Join-Path $projectRoot 'docs') $doc) -Destination (Join-Path $stageDocs $doc) -Recurse
}
Compress-Archive -LiteralPath $stageMod,(Join-Path $stageRoot 'README.md'),(Join-Path $stageRoot 'README.en.md'),(Join-Path $stageRoot 'KNOWN-ISSUES.md'),(Join-Path $stageRoot 'VERIFICATION.md'),(Join-Path $stageRoot 'CHANGELOG.md'),$stageDocs -DestinationPath $zipPath
$verifyRoot = Join-Path $releaseRoot ('verify-' + $buildId)
Expand-Archive -LiteralPath $zipPath -DestinationPath $verifyRoot
$verifiedMod = Join-Path $verifyRoot 'TenYearsNineGrid'
foreach ($name in $runtimeFiles) {
    $sourceHash = (Get-FileHash -LiteralPath (Join-Path $sourceMod $name) -Algorithm SHA256).Hash
    $zipHash = (Get-FileHash -LiteralPath (Join-Path $verifiedMod $name) -Algorithm SHA256).Hash
    if ($sourceHash -ne $zipHash) { throw "ZIP content mismatch: $name" }
}
if ((Get-ChildItem -LiteralPath $verifiedMod -File -Recurse).Count -ne $runtimeFiles.Count) { throw 'Unexpected packaged files.' }
$previousTarget = $env:TYG_TEST_MOD_DIR
try {
    $env:TYG_TEST_MOD_DIR = $verifiedMod
    foreach ($test in @('test_birth_ui.lua','test_presets.lua','test_matching.lua','test_mod.lua','test_cycles.lua','test_natal_fortunes.lua','test_reward_versions.lua','test_resume.lua','test_patterns.lua','test_pattern_jokers.lua','test_pattern_start.lua')) {
        & python -S (Join-Path $projectRoot 'tests\run_lua_tests.py') $test
        if ($LASTEXITCODE -ne 0) { throw "Extracted-package test failed: $test" }
    }
    & python -S -B (Join-Path $projectRoot 'tests\test_native_input_contract.py') --mod $verifiedMod
    if ($LASTEXITCODE -ne 0) { throw 'Extracted-package native input contract failed.' }
    & python -S -B (Join-Path $projectRoot 'tests\test_native_gift_contract.py') --mod $verifiedMod
    if ($LASTEXITCODE -ne 0) { throw 'Extracted-package native gift contract failed.' }
    & node (Join-Path $projectRoot 'tests\test_assets.cjs')
    if ($LASTEXITCODE -ne 0) { throw 'Extracted-package asset validation failed.' }
} finally { $env:TYG_TEST_MOD_DIR = $previousTarget }
Get-FileHash -LiteralPath $zipPath -Algorithm SHA256
Write-Output "ZIP: $zipPath"
Write-Output "Verified package: $verifiedMod"

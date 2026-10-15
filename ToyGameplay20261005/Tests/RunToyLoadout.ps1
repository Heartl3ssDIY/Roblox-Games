$ErrorActionPreference = 'Stop'
$toyRoot = Split-Path -Parent $PSScriptRoot
$toySourcePath = Join-Path $toyRoot 'After\PlaygroundEconomyService.luau'
$toySource = [IO.File]::ReadAllText($toySourcePath)
$toyCatalog = [IO.File]::ReadAllText((Join-Path $toyRoot 'After\PlaygroundCatalog.luau'))
$toyTemplate = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'ToyLoadout.template.luau'))
$toyRunner = Join-Path $PSScriptRoot 'ToyLoadout.generated.luau'
[IO.File]::WriteAllText($toyRunner, $toyTemplate.Replace('-- CATALOG_SOURCE', $toyCatalog).Replace('-- ECONOMY_SOURCE', $toySource), [Text.UTF8Encoding]::new($false))
$toyTools = 'C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\AttackTiming20260926\tools\luau-0.740'
& (Join-Path $toyTools 'luau-compile.exe') --null $toySourcePath $toyRunner
if ($LASTEXITCODE -ne 0) { throw 'Toy compilation failed' }
$toyOutput = @(& (Join-Path $toyTools 'luau.exe') $toyRunner 2>&1)
$toyExit = $LASTEXITCODE
$toyOutput | ForEach-Object { Write-Output $_ }
if ($toyExit -ne 0) { throw 'Toy loadout checks failed' }
$toyChecks = @($toyOutput | Select-Object -Skip 1 | Where-Object { $_ -like 'PASS *' } | ForEach-Object { $_.Substring(5) })
$toyReport = [ordered]@{
    passed = $true
    checkCount = $toyChecks.Count
    checks = $toyChecks
    sourceSHA256 = (Get-FileHash -LiteralPath $toySourcePath -Algorithm SHA256).Hash
    execution = 'Local Luau CLI using candidate catalog, complete candidate Economy source, isolated in-memory player/profile and data-store adapter'
    externalDataStoreCalls = 0
    studioMutations = 0
    playStartedOrStopped = $false
}
[IO.File]::WriteAllText((Join-Path $PSScriptRoot 'ToyLoadout-Validation.json'), ($toyReport | ConvertTo-Json -Depth 10), [Text.UTF8Encoding]::new($false))

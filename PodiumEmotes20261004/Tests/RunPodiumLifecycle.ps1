$ErrorActionPreference = 'Stop'
$podiumRoot = Split-Path -Parent $PSScriptRoot
$podiumSourcePath = Join-Path $podiumRoot 'PlaygroundPodiumController.client.luau'
$podiumSource = [IO.File]::ReadAllText($podiumSourcePath)
$podiumRuntimeIndex = $podiumSource.IndexOf('local gui = script.Parent')
if ($podiumRuntimeIndex -lt 0) { throw 'Podium runtime boundary missing' }
$podiumTemplate = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'PodiumLifecycle.template.luau'))
$podiumRunner = Join-Path $PSScriptRoot 'PodiumLifecycle.generated.luau'
[IO.File]::WriteAllText($podiumRunner, $podiumTemplate.Replace('-- RUNTIME_SOURCE', $podiumSource.Substring($podiumRuntimeIndex)), [Text.UTF8Encoding]::new($false))
$podiumTools = 'C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\AttackTiming20260926\tools\luau-0.740'
& (Join-Path $podiumTools 'luau-compile.exe') --null $podiumSourcePath $podiumRunner
if ($LASTEXITCODE -ne 0) { throw 'Podium compilation failed' }
$podiumOutput = @(& (Join-Path $podiumTools 'luau.exe') $podiumRunner 2>&1)
$podiumExit = $LASTEXITCODE
$podiumOutput | ForEach-Object { Write-Output $_ }
if ($podiumExit -ne 0) { throw 'Podium lifecycle checks failed' }
$podiumChecks = @($podiumOutput | Select-Object -Skip 1 | Where-Object { $_ -like 'PASS *' } | ForEach-Object { $_.Substring(5) })
$podiumReport = [ordered]@{
    passed = $true
    checkCount = $podiumChecks.Count
    checks = $podiumChecks
    sourceSHA256 = (Get-FileHash -LiteralPath $podiumSourcePath -Algorithm SHA256).Hash
    execution = 'Local Luau CLI with mocked avatar loading and UI nodes; native pose/geometry covered by separate rig harness'
    actualAvatarRequests = 0
    studioMutations = 0
    playStarted = $false
}
[IO.File]::WriteAllText((Join-Path $PSScriptRoot 'PodiumLifecycle-Validation.json'), ($podiumReport | ConvertTo-Json -Depth 10), [Text.UTF8Encoding]::new($false))

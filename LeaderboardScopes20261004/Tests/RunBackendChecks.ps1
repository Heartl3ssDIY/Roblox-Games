$ErrorActionPreference = 'Stop'
$leaderboardRoot = Split-Path -Parent $PSScriptRoot
$leaderboardSourcePath = Join-Path $leaderboardRoot 'PlaygroundLeaderboardService.luau'
$leaderboardTemplatePath = Join-Path $PSScriptRoot 'BackendChecks.template.luau'
$leaderboardRunnerPath = Join-Path $PSScriptRoot 'BackendChecks.generated.luau'
$leaderboardTools = 'C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\AttackTiming20260926\tools\luau-0.740'
$leaderboardSource = [IO.File]::ReadAllText($leaderboardSourcePath)
$leaderboardTemplate = [IO.File]::ReadAllText($leaderboardTemplatePath)
[IO.File]::WriteAllText($leaderboardRunnerPath, $leaderboardTemplate.Replace('-- SERVICE_SOURCE', $leaderboardSource), [Text.UTF8Encoding]::new($false))
& (Join-Path $leaderboardTools 'luau-compile.exe') --null $leaderboardSourcePath $leaderboardRunnerPath
if ($LASTEXITCODE -ne 0) { throw 'Leaderboard compilation failed' }
$leaderboardOutput = @(& (Join-Path $leaderboardTools 'luau.exe') $leaderboardRunnerPath 2>&1)
$leaderboardExit = $LASTEXITCODE
$leaderboardOutput | ForEach-Object { Write-Output $_ }
if ($leaderboardExit -ne 0) { throw 'Leaderboard backend checks failed' }
$leaderboardChecks = @($leaderboardOutput | Select-Object -Skip 1 | Where-Object { $_ -like 'PASS *' } | ForEach-Object { $_.Substring(5) })
$leaderboardReport = [ordered]@{
    passed = $true
    checkCount = $leaderboardChecks.Count
    checks = $leaderboardChecks
    sourceSHA256 = (Get-FileHash -LiteralPath $leaderboardSourcePath -Algorithm SHA256).Hash
    execution = 'Local Luau CLI with deterministic mock services'
    liveDataStoreReads = 0
    liveDataStoreWrites = 0
    studioMutations = 0
    playStarted = $false
}
[IO.File]::WriteAllText((Join-Path $PSScriptRoot 'Backend-Validation.json'), ($leaderboardReport | ConvertTo-Json -Depth 10), [Text.UTF8Encoding]::new($false))

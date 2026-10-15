param(
    [string]$Compiler = 'C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\AttackTiming20260926\tools\luau-0.740\luau-compile.exe'
)

$ErrorActionPreference = 'Stop'
$integrationRoot = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path -LiteralPath $Compiler -PathType Leaf)) {
    throw "Luau compiler is missing: $Compiler"
}
$sources = Get-ChildItem -LiteralPath (Join-Path $integrationRoot 'After'), $PSScriptRoot -Filter '*.luau' -File
$results = foreach ($source in $sources) {
    $output = & $Compiler --null $source.FullName 2>&1
    $compileExit = $LASTEXITCODE
    [pscustomobject]@{
        Name = $source.Name
        Path = $source.FullName
        ExitCode = $compileExit
        Output = $output -join "`n"
    }
}
$report = [pscustomobject]@{
    VerifiedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
    PlayStarted = $false
    Sources = @($results)
    Passed = @($results | Where-Object ExitCode -eq 0).Count
    Failed = @($results | Where-Object ExitCode -ne 0).Count
}
$report | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $integrationRoot 'Source-Compile-Verification.json') -Encoding utf8
$report | Select-Object Passed, Failed, PlayStarted | ConvertTo-Json
if ($report.Failed -gt 0) {
    $results | Where-Object ExitCode -ne 0 | Format-List Name, Output
    throw 'Luau source compilation failed.'
}

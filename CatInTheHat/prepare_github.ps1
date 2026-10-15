$ErrorActionPreference = 'Stop'
$catSource = 'C:/Users/sandt/Documents/Local Projects/Roblox UI Assets/Btns/CatInTheHat'
$catStage = Join-Path $catSource 'GitHubUpload'
$catFolders = @('base', 'horror', 'source', 'source/horror', 'references', 'archive')
foreach ($catFolder in $catFolders) {
    New-Item -ItemType Directory -Path (Join-Path $catStage $catFolder) -Force | Out-Null
}
$baseFiles = @('CatInTheHat_Base.blend','CatInTheHat_Base.fbx','CatInTheHat_Base.glb','Cat_SurfaceNormal.png','CatInTheHat_ThreeQuarter.png','CatInTheHat_Front.png','CatInTheHat_Back.png','README.md','Model_Parts.json','Export_Check.json','Apply_Default_Colours.luau')
foreach ($catFile in $baseFiles) {
    Copy-Item -LiteralPath (Join-Path $catSource $catFile) -Destination (Join-Path (Join-Path $catStage 'base') $catFile)
}
$horrorFiles = @('CatInTheHat_Horror.blend','CatInTheHat_Horror.fbx','CatInTheHat_Horror.glb','Cat_SurfaceNormal.png','CatInTheHat_Horror_Studio.png','CatInTheHat_Horror_Portrait.png','README.md','Horror_Model_Parts.json','Horror_Export_Check.json')
foreach ($catFile in $horrorFiles) {
    Copy-Item -LiteralPath (Join-Path (Join-Path $catSource 'Horror') $catFile) -Destination (Join-Path (Join-Path $catStage 'horror') $catFile)
}
$buildFiles = @('build_cat.py','build_details.py','build_accessories.py','refine_cat.py','polish_cat.py','finish_exports.py','final_check.py','check_glb_scale.py','make_horror_variant.py')
foreach ($catFile in $buildFiles) {
    Copy-Item -LiteralPath (Join-Path $catSource $catFile) -Destination (Join-Path (Join-Path $catStage 'source') $catFile)
}
foreach ($catFile in @('export_horror.py','render_portrait.py')) {
    Copy-Item -LiteralPath (Join-Path (Join-Path $catSource 'Horror') $catFile) -Destination (Join-Path (Join-Path $catStage 'source/horror') $catFile)
}
Copy-Item -LiteralPath (Join-Path (Join-Path $catSource 'Horror') 'Before_Horror.blend') -Destination (Join-Path (Join-Path $catStage 'archive') 'Before_Horror.blend')
$references = @{
    'C:/Users/sandt/AppData/Local/Temp/codex-clipboard-1f31e222-b05e-4325-a0d2-4cedb74d5cb6.png' = '01-outfits.png'
    'C:/Users/sandt/AppData/Local/Temp/codex-clipboard-47854e07-daed-45a0-a0e6-a19de2282999.png' = '02-full-body.png'
    'C:/Users/sandt/AppData/Local/Temp/codex-clipboard-0f519dc4-bfe3-4019-8e01-54f74afc430c.png' = '03-film-pose.png'
    'C:/Users/sandt/AppData/Local/Temp/codex-clipboard-59f734fb-2aff-423c-970a-d84779a3c4e7.png' = '04-costume-front-back.png'
    'C:/Users/sandt/AppData/Local/Temp/codex-clipboard-ca1087be-8b27-4373-8912-bef88fe67a55.png' = '05-avatar-proportions.png'
}
foreach ($catRef in $references.GetEnumerator()) {
    if (Test-Path -LiteralPath $catRef.Key) {
        Copy-Item -LiteralPath $catRef.Key -Destination (Join-Path (Join-Path $catStage 'references') $catRef.Value)
    }
}
$catInventory = Get-ChildItem -LiteralPath $catStage -Recurse -File | ForEach-Object {
    [PSCustomObject]@{
        path = $_.FullName.Substring($catStage.Length + 1).Replace('\','/')
        bytes = $_.Length
        sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    }
}
$catInventory | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $catStage 'FILES.json') -Encoding utf8
[PSCustomObject]@{Folder=$catStage; Files=$catInventory.Count; TotalBytes=($catInventory | Measure-Object bytes -Sum).Sum; LargestBytes=($catInventory | Measure-Object bytes -Maximum).Maximum} | ConvertTo-Json

from pathlib import Path
folder=Path(__file__).resolve().parent
(folder/'After').mkdir(exist_ok=True)
source=(folder/'Before/PlaygroundEmotes.client.luau').read_text(encoding='utf-8')
latest=(folder.parent/'GameplayRepair20261005/After/PlaygroundEmotes.client.luau').read_text(encoding='utf-8')
assert source.rstrip()==latest.rstrip(), 'Live motion differs from latest approved repair; inspect before merging'
helper=(folder/'CatalogEmotePlayback.luau').read_text(encoding='utf-8')
source=source.replace('local beforeAnimation =',helper+'\n\nlocal beforeAnimation =',1)
source=source.replace('local now = workspace:GetServerTimeNow()\n\tanimatePracticeBots(now)', 'local now = workspace:GetServerTimeNow()\n\tupdateCatalogEmote(now)\n\tanimatePracticeBots(now)',1)
source=source.replace('if animateDodge(record, player, character, humanoid, now) then continue end', 'if player == Players.LocalPlayer and catalogEmote and catalogEmote.character == character then continue end\n\t\tif animateDodge(record, player, character, humanoid, now) then continue end',1)
source=source.replace('script.Destroying:Connect(function()\n', 'script.Destroying:Connect(function()\n\tstopCatalogEmote("Dance stopped")\n\tcleanRetiredEmotes(true)\n',1)
(folder/'After/PlaygroundEmotes.client.luau').write_text(source,encoding='utf-8')
print('Playback client candidate prepared with prior motion functions unchanged')

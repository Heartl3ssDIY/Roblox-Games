from pathlib import Path

root = Path(__file__).resolve().parent
read = lambda path: (root / path).read_text(encoding='utf-8').strip()
quote = lambda text: '[========[' + text + ']========]'
source = '''local gui=game.StarterGui.DuckDuckGooseHUD
assert(gui.Controller.Source==EXPECTED,"Controller changed; refresh snapshot")
local result=(function()
BUILDER
end)()
local module=Instance.new("ModuleScript")
module.Name="Guidance"
module.Sandboxed=false
module.Capabilities=gui.Controller.Capabilities
module.Source=GUIDANCE
module.Parent=gui
gui.Controller.Source=CONTROLLER
return result
'''
source = source.replace('EXPECTED', quote(read('Before/Controller.luau')))
source = source.replace('BUILDER', read('UI/Build.luau'))
source = source.replace('GUIDANCE', quote(read('UI/Guidance.luau')))
source = source.replace('CONTROLLER', quote(read('UI/Controller.luau')))
(root / 'UI/Install.luau').write_text(source, encoding='utf-8')

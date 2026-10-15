from pathlib import Path
import json
root=Path(__file__).resolve().parents[1]
prefix=(root/'Tests/WheelMockEnvironment.luau').read_text()
controller=(root/'After/EmoteWheel.Controller.client.luau').read_text()
checks=(root/'Tests/WheelBehaviorChecks.luau').read_text()
module='local ok,result=xpcall(function()\n'+prefix+'\n'+controller+'\n'+checks+'\nend,debug.traceback)\nreturn {passed=ok,result=result}\n'
literal='[====['+module+']====]'
harness='''assert(not game:GetService("RunService"):IsRunning(),"Edit only")
local fixture=Instance.new("ModuleScript") fixture.Name="EmoteWheelNativeChecks20261005"
fixture.Capabilities=game.StarterGui.PlaygroundShell.Controller.Capabilities
fixture.Sandboxed=game.StarterGui.PlaygroundShell.Controller.Sandboxed
fixture.Source=__SOURCE__ fixture.Parent=game.ServerStorage
local ok,result=xpcall(function()return require(fixture)end,debug.traceback)
fixture:Destroy()
return {passed=ok,result=result,fixtureCleaned=game.ServerStorage:FindFirstChild("EmoteWheelNativeChecks20261005")==nil}
'''.replace('__SOURCE__',literal)
(root/'Tests/WheelNativeChecks.generated.luau').write_text(harness)
print(json.dumps({'controllerLength':len(controller),'harnessLength':len(harness)}))

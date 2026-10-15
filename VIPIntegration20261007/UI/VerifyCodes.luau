local gui = game.StarterGui.PlaygroundSessionControls:Clone()
gui.Name = "CodeUIVerification"
for _, child in ipairs(gui:GetChildren()) do if child:IsA("BaseScript") then child.Enabled = false end end
gui.Enabled = true
gui.Dock.Visible = true
gui.Parent = game.ServerStorage
local original = gui.CodeController
local source = original.Source
source = source:gsub('local remote = ReplicatedStorage:FindFirstChild%("PlaygroundShopRequest"%)', "local remote = fakeRemote", 1)
local prefix = [[
local replies = { response = {ok=false,message="Invalid or expired code."}, delay=0, error=false }
local calls = {}
local fakeRemote = {
 IsA=function(_,class) return class=="RemoteFunction" end,
 InvokeServer=function(_,action,payload)
  table.insert(calls,{action=action,code=payload.code})
  if replies.delay > 0 then task.wait(replies.delay) end
  if replies.error then error("offline") end
  return replies.response
 end,
}
]]
local module = Instance.new("ModuleScript")
module.Name = "VerifyCodes"
module.Source = prefix .. source .. [[
return {submit=submit,calls=calls,replies=replies,teardown=function()
 alive=false
 serial+=1
 if worker then pcall(task.cancel,worker) end
 for _, connection in ipairs(connections) do connection:Disconnect() end
end}
]]
module.Sandboxed = original.Sandboxed
module.Capabilities = original.Capabilities
module.Parent = gui
local ok, result = pcall(function()
 local test = require(module)
 local codes = gui.Dock.Body.Codes
 local input, button, status = codes.Input.Value,codes.Redeem,codes.Status
 local count=0
 local function check(condition,message) assert(condition,message) count+=1 end
 input.Text=""
 test.submit()
 check(#test.calls==0 and status.Text=="Enter your reward code first.","Empty input sent")
 input.Text="abc!"
 test.submit()
 check(#test.calls==0,"Invalid input sent")
 input.Text=string.rep("A",33)
 test.submit()
 check(#test.calls==0,"Overlong input sent")
 input.Text="  beta-test_1  "
 test.submit()
 task.wait()
 check(#test.calls==1 and test.calls[1].action=="RedeemCode" and test.calls[1].code=="beta-test_1","Wrong payload")
 check(status.Text=="Invalid or expired code." and input.Text~="","Failed response lost")
 test.replies.response={ok=true,message="Beta Tester granted."}
 input.Text="BETA"
 test.submit()
 task.wait()
 check(status.Text=="Beta Tester granted." and input.Text=="","Success not reflected")
 test.replies.error=true
 input.Text="BETA"
 test.submit()
 task.wait()
 check(status.Text=="Could not check your code. Try again." and button.Active and input.TextEditable,"Network failure stuck UI")
 test.replies.error=false
 test.replies.delay=0.05
 input.Text="BETA"
 local before=#test.calls
 test.submit()
 check(not button.Active and not input.TextEditable and button.Label.Text=="WAIT...","No pending state")
 test.submit()
 check(#test.calls==before+1,"Duplicate request")
 task.wait(0.06)
 check(button.Active and input.TextEditable,"Pending state not cleared")
 input.Text=string.rep("x",80)
 task.wait()
 check(#input.Text<=64,"Input cap missing")
 gui.Dock.Visible=false
 before=#test.calls
 test.submit()
 check(#test.calls==before,"Hidden form sent")
 test.teardown()
 return {checks=count,payload="RedeemCode {code=text}",serverMessages=true,duplicateRequestsBlocked=true}
end)
gui:Destroy()
assert(ok,result)
return result

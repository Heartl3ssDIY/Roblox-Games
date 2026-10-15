assert(not game:GetService("RunService"):IsRunning())
local starter = game:GetService("StarterGui")
local part = Instance.new("Part")
part.Name = "SessionModalNativeQA20261009"
part.Size = Vector3.new(1, 1, 1)
part.CFrame = CFrame.new(0, -20000, 0)
part.Anchored = true
part.CanCollide = false
part.CanTouch = false
part.CanQuery = false
part.Transparency = 1
part.Parent = workspace
local checks = 0
local rows = {}
local function check(condition, message) checks += 1 assert(condition, message) end
local function rectangle(object)
	return {x=object.AbsolutePosition.X,y=object.AbsolutePosition.Y,width=object.AbsoluteSize.X,height=object.AbsoluteSize.Y}
end
local function within(object, width, height)
	local r = rectangle(object)
	return r.x >= -0.01 and r.y >= -0.01 and r.x+r.width <= width+0.01 and r.y+r.height <= height+0.01
end
local ok, failure = pcall(function()
	for _, size in {Vector2.new(272, 262),Vector2.new(292,262),Vector2.new(384,262),Vector2.new(320,548),Vector2.new(764,348),Vector2.new(768,960),Vector2.new(1920,1080)} do
		local surface = Instance.new("SurfaceGui")
		surface.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
		surface.CanvasSize = size
		surface.Parent = part
		local root = Instance.new("Frame")
		root.Size = UDim2.fromScale(1, 1)
		root.BackgroundTransparency = 1
		root.Parent = surface
		local objects = {}
		for _, record in {
			{ starter.PlaygroundSessionControls.Dock, "Settings" },
			{ starter.PlaygroundSessionControls.SpectatePanel, "Spectate" },
			{ starter.PlaygroundEmoteWheel.Panel, "Emotes" },
		} do
			local object = record[1]:Clone()
			object.Visible = true
			object.Parent = root
			objects[record[2]] = object
		end
		local emotes = objects.Emotes
		for _, child in emotes.Wheel:GetChildren() do if child:IsA("GuiButton") then child.Visible=true end end
		emotes.StopButton.Visible = true
		task.wait(0.1)
		for name, object in pairs(objects) do check(within(object,size.X,size.Y),name.." exceeds usable screen "..tostring(size)) end
		local settings = objects.Settings
		check(settings.Close.AbsoluteSize.X >= 44 and settings.Close.AbsoluteSize.Y >= 44,"Settings close target shrank")
		local body = settings.Body
		check(body.AbsoluteCanvasSize.Y >= 316, "Settings code entry cannot scroll")
		check(body.Codes.Redeem.Position.Y.Offset + body.Codes.Redeem.Size.Y.Offset <= body.Codes.Size.Y.Offset, "Redeem outside code group")
		check(body.Codes.Position.Y.Offset + body.Codes.Size.Y.Offset <= body.AbsoluteCanvasSize.Y,"Code entry outside settings canvas")
		check(body.AFK.AbsoluteSize.X <= body.AbsoluteSize.X and body.Visibility.AbsoluteSize.X <= body.AbsoluteSize.X,"Settings rows spill horizontally")
		local spectate = objects.Spectate
		for _, name in {"Previous","Next","Exit"} do
			local b=spectate[name]
			check(b.AbsoluteSize.X>=44 and b.AbsoluteSize.Y>=44,name.." spectate target too small")
			local p=spectate.AbsolutePosition local r=rectangle(b)
			check(r.x>=p.X and r.x+r.width<=p.X+spectate.AbsoluteSize.X+.01,name.." spectate target outside panel")
		end
		for index=1,8 do
			local button=emotes.Wheel["Slot"..index]
			check(button.AbsoluteSize.X>=44 and button.AbsoluteSize.Y>=44,"Emote slot is too small for touch")
		end
		local footer = emotes.ShopButton
		check(footer.AbsoluteSize.Y >= 44,"Emote shop target too small")
		check(footer.AbsolutePosition.Y+footer.AbsoluteSize.Y-emotes.AbsolutePosition.Y<=emotes.AbsoluteCanvasSize.Y+.01,"Emote shop outside scrollable canvas")
		local scrollMax = math.max(0, emotes.AbsoluteCanvasSize.Y-emotes.AbsoluteWindowSize.Y)
		emotes.CanvasPosition = Vector2.new(0,scrollMax)
		task.wait(.05)
		check(footer.AbsolutePosition.Y+footer.AbsoluteSize.Y<=emotes.AbsolutePosition.Y+emotes.AbsoluteSize.Y+.01,"Emote shop cannot be scrolled into view")
		table.insert(rows,{usable=tostring(size),settings=rectangle(settings),spectate=rectangle(spectate),emotes=rectangle(emotes),emoteSlot=tostring(emotes.Wheel.Slot1.AbsoluteSize),scrollMax=scrollMax})
		surface:Destroy()
	end
	local backup = game:GetService("ServerStorage").PhoneHudModalBackup20261009
	for _, name in {"PlaygroundSessionControls","PlaygroundEmoteWheel"} do
		check(starter[name].Controller.Source==backup[name].Controller.Source,name.." controller source changed in modal repair")
		check(starter[name].Controller.Capabilities==backup[name].Controller.Capabilities,name.." capabilities changed in modal repair")
	end
end)
part:Destroy()
assert(ok, failure)
return {ok=true,checks=checks,viewports=rows}


return function(ui)
	local report = { checks = {}, warnings = {}, scenarios = {} }
	local function check(name, condition, detail)
		table.insert(report.checks, { name = name, passed = condition == true, detail = detail })
	end
	local function rect(item)
		return { x = item.AbsolutePosition.X, y = item.AbsolutePosition.Y, w = item.AbsoluteSize.X, h = item.AbsoluteSize.Y }
	end
	local function overlaps(a,b)
		return a.x < b.x+b.w-0.5 and a.x+a.w > b.x+0.5 and a.y < b.y+b.h-0.5 and a.y+a.h > b.y+0.5
	end
	local function within(a,b)
		return a.x >= b.x-0.5 and a.y >= b.y-0.5 and a.x+a.w <= b.x+b.w+0.5 and a.y+a.h <= b.y+b.h+0.5
	end
	local fixture = Instance.new("Part")
	fixture.Name, fixture.Anchored, fixture.CanCollide = "SchoolUIQA20261011", true, false
	fixture.Position = Vector3.new(-41000,-16000,0)
	fixture.Parent = workspace
	local ok, failure = xpcall(function()
		for _, device in ipairs({
			{568,320,0,58,0,0}, {667,375,0,58,0,0}, {844,390,44,58,44,21},
			{896,414,44,58,44,21}, {1024,768,0,58,0,20}, {1180,820,0,58,0,20},
			{1366,1024,0,58,0,20}, {390,844,0,94,0,34},
		}) do
			local width,height,left,top,right,bottom = table.unpack(device)
			local prefix = tostring(width).."x"..tostring(height)..": "
			local portrait = height > width
			local surface = Instance.new("SurfaceGui")
			surface.SizingMode, surface.CanvasSize, surface.Parent = Enum.SurfaceGuiSizingMode.FixedSize, Vector2.new(width,height), fixture
			local host = Instance.new("Frame")
			host.Name, host.BackgroundTransparency = "SafeArea", 1
			host.Position, host.Size = UDim2.fromOffset(left,top), UDim2.new(1,-left-right,1,-top-bottom)
			host.Parent = surface
			local nodes, lobby = {}, {}
			local function add(key, source, isLobby)
				local object = source:Clone()
				for _, child in ipairs(object:GetDescendants()) do
					if child:IsA("LuaSourceContainer") then child:Destroy()
					elseif child:IsA("UIScale") and child.Name == "ResponsiveHudScale" then
						child.Scale = child:GetAttribute(math.min(width,height)<=600 and "PhoneScale" or "TabletScale") or 1
					end
				end
				object.Name, object.Visible, object.Parent = key, true, host
				nodes[key] = object
				if isLobby then table.insert(lobby,key) end
				return object
			end
			add("Level", ui.PlaygroundShell.CompactLevelPanel,true)
			add("Wallet", ui.PlaygroundShell.Wallet,true)
			add("Dock", portrait and ui.PlaygroundShell.PortraitDock or ui.PlaygroundShell.CompactDock,true)
			add("Settings", ui.PlaygroundSessionControls[portrait and "PortraitToggle" or "CompactToggle"],true)
			add("Spectate", ui.PlaygroundSessionControls[portrait and "PortraitSpectate" or "CompactSpectate"],true)
			add("Emotes", ui.PlaygroundEmoteWheel[portrait and "PortraitEmoteToggle" or "CompactEmoteToggle"],true)
			add("Timer", ui.PlaygroundIntermissionHUD[portrait and "Portrait" or "Compact"],true)
			add("Boosts", ui.PlaygroundFishingHUD[portrait and "PortraitDock" or "CompactDock"],true)
			add("Toys", ui.PlaygroundToyHotbar.Bar,true)
			add("Sprint",ui.HideAndSeekHUD.MobileSprint)
			add("Swing",ui.PlaygroundBatControls.Swing)
			add("RoundSettings",ui.PlaygroundSessionControls[portrait and "PortraitRoundToggle" or "CompactRoundToggle"])
			add("RoundHeader",ui.HideAndSeekHUD[portrait and "PortraitHeader" or "CompactHeader"])
			add("RoundBoosts",ui.PlaygroundFishingHUD.RoundDock)
			task.wait(.12)
			local safe = rect(host)
			local scenario = { width=width,height=height,safe=safe,rects={} }
			for key, object in pairs(nodes) do
				local box = rect(object)
				scenario.rects[key] = box
				check(prefix..key.." stays within safe area",within(box,safe))
			end
			for index,first in ipairs(lobby) do
				for other=index+1,#lobby do
					local second=lobby[other]
					check(prefix..first.." does not overlap "..second,not overlaps(rect(nodes[first]),rect(nodes[second])))
				end
			end
			local joystick = { x=0,y=height-140,w=144,h=140 }
			local jump = { x=width-130,y=height-128,w=130,h=128 }
			for _, key in ipairs({"Dock","Toys","Sprint","Swing"}) do
				check(prefix..key.." clears joystick",not overlaps(rect(nodes[key]),joystick))
				check(prefix..key.." clears jump",not overlaps(rect(nodes[key]),jump))
			end
			for _, pair in ipairs({{"Sprint","Swing"},{"RoundSettings","RoundHeader"},{"RoundBoosts","RoundHeader"},{"RoundBoosts","Sprint"}}) do
				check(prefix..pair[1].." clears "..pair[2],not overlaps(rect(nodes[pair[1]]),rect(nodes[pair[2]])))
			end
			for _, key in ipairs({"Level","Wallet","Timer"}) do
				local labels = {}
				for _, child in ipairs(nodes[key]:GetChildren()) do
					if child:IsA("TextLabel") and child.Visible then
						check(prefix..key.." label "..child.Name.." fits card",within(rect(child),rect(nodes[key])))
						check(prefix..key.." label "..child.Name.." scales",child.TextScaled)
						table.insert(labels,child)
					end
				end
				for index, first in ipairs(labels) do
					for other=index+1,#labels do
						check(prefix..key.." text "..first.Name.." clears "..labels[other].Name,not overlaps(rect(first),rect(labels[other])))
					end
				end
			end
			for _, key in ipairs({"Dock","Settings","Spectate","Emotes","Sprint","Swing"}) do
				check(prefix..key.." has usable 44px target",nodes[key].AbsoluteSize.Y>=43.9)
			end
			for _, key in ipairs({"Level","Wallet","Timer","Dock"}) do
				local hasSkin, hasFallback = false, nodes[key].BackgroundTransparency < 1
				for _, item in ipairs(nodes[key]:GetDescendants()) do
					if item:IsA("ImageLabel") and item.Name == "ReusableSkin" then
						hasSkin = true
						check(prefix..key.." artwork has positive geometry",item.AbsoluteSize.X>0 and item.AbsoluteSize.Y>0)
					elseif item:IsA("Frame") and (item.Name == "Fallback" or item:GetAttribute("BackgroundFallbackFor")) then hasFallback = true end
				end
				check(prefix..key.." has authored artwork",hasSkin)
				if not hasFallback then table.insert(report.warnings,prefix..key.." has no authored fallback background") end
			end
			table.insert(report.scenarios,scenario)
			surface:Destroy()
		end
	end,debug.traceback)
	fixture:Destroy()
	report.error = ok and nil or failure
	report.passed = ok
	for _, item in ipairs(report.checks) do if not item.passed then report.passed=false end end
	report.checkCount = #report.checks
	return report
end

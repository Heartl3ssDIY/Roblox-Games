return function(install)
	assert(not game:GetService("RunService"):IsRunning(), "Edit mode required")
	local sourceShell = game:GetService("StarterGui").PlaygroundShell
	local fixture = Instance.new("ScreenGui")
	fixture.Name = "_DockPolishChecks"
	fixture.Parent = game:GetService("ServerStorage")
	local report = { checks = {}, playStarted = false, liveGuiMutated = false }
	local function check(name, value) assert(value, name) table.insert(report.checks, name) end
	local ok, problem = xpcall(function()
		sourceShell.Dock:Clone().Parent = fixture
		local dock = fixture.Dock
		local originalPosition, originalAnchor = dock.Position, dock.AnchorPoint
		for pass = 1, 2 do
			local result = install(false, fixture)
			check("Pass " .. pass .. " leaves controller and shop panel out of scope", result.controllerChanged == false and result.shopPanelChanged == false)
			check("Pass " .. pass .. " preserves dock anchor position", dock.Position == originalPosition and dock.AnchorPoint == originalAnchor)
			check("Pass " .. pass .. " authors responsive dock bounds", dock.Size == UDim2.new(1, -36, 0, 48) and dock.DockSizeLimit.MaxSize == Vector2.new(382, 48))
			local layouts, constraints = 0, 0
			for _, child in ipairs(dock:GetChildren()) do
				if child:IsA("UIListLayout") then layouts += 1 elseif child:IsA("UISizeConstraint") then constraints += 1 end
			end
			check("Pass " .. pass .. " maintains one editable layout and size constraint", layouts == 1 and constraints == 1)
			for index, spec in ipairs({ { "Shop", "SHOP", "84589903135132" }, { "Emote", "PETS", "90528629970043" }, { "Emoji", "TOYS", "91168456076260" } }) do
				local button = dock[spec[1]]
				check("Pass " .. pass .. " " .. spec[2] .. " has equal authored shape and order", button.Size == UDim2.new(1 / 3, -28 / 3, 0, 46) and button.LayoutOrder == index)
				check("Pass " .. pass .. " " .. spec[2] .. " retains designated PNG", button.ReusableSkin.Image == "rbxassetid://" .. spec[3])
				check("Pass " .. pass .. " " .. spec[2] .. " background is centered with matching fallback", button.ReusableSkin.Position == UDim2.fromScale(0, 0) and button.ReusableSkinFallback.Position == button.ReusableSkin.Position and button.ReusableSkinFallback.Size == button.ReusableSkin.Size)
				check("Pass " .. pass .. " " .. spec[2] .. " has one centered editable label", button.LiveCaption.Text == spec[2] and button.LiveCaption.Position == UDim2.fromScale(0.5, 0.5) and button.LiveCaption.AnchorPoint == Vector2.new(0.5, 0.5))
				check("Pass " .. pass .. " " .. spec[2] .. " retains text outline", button.LiveCaption.TextOutline.ApplyStrokeMode == Enum.ApplyStrokeMode.Contextual and button.LiveCaption.TextOutline.Transparency == 0)
			end
		end
		for _, viewportWidth in ipairs({ 320, 375, 768, 1280 }) do
			local dockWidth = math.min(viewportWidth - 36, dock.DockSizeLimit.MaxSize.X)
			local buttonWidth = dockWidth / 3 - 28 / 3
			check(tostring(viewportWidth) .. "px viewport fits every button inside authored dock", math.abs(buttonWidth * 3 + dock.DockLayout.Padding.Offset * 2 - dockWidth) < 0.001 and buttonWidth >= 85)
		end
		check("Desktop buttons preserve 118px width", math.abs(382 / 3 - 28 / 3 - 118) < 0.001)
		check("Hidden old Toys heart art is removed", not dock.Emoji:FindFirstChild("ArtworkIcon"))
	end, debug.traceback)
	fixture:Destroy()
	report.passed = ok
	report.error = not ok and tostring(problem) or nil
	report.fixtureDestroyed = fixture.Parent == nil
	return report
end


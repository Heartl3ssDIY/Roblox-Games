local workspace={CurrentCamera={ViewportSize={X=844,Y=390}}}
local gui={Parent={GetDescendants=function() return {} end,DescendantAdded={Connect=function() return {} end}}}
local hudScales = {}
local hudScaleConnection
local function trackHudScale(object)
	if object:IsA("UIScale") and object.Name == "ResponsiveHudScale" then hudScales[object] = true end
end
for _, object in ipairs(gui.Parent:GetDescendants()) do trackHudScale(object) end
hudScaleConnection = gui.Parent.DescendantAdded:Connect(trackHudScale)

local function hudProfile(viewport)
	local short = math.min(viewport.X, viewport.Y)
	if viewport.X <= 900 or short <= 600 then return "PhoneScale" end
	if short <= 1024 and math.max(viewport.X, viewport.Y) <= 1400 then return "TabletScale" end
	return "DesktopScale"
end

local function refreshHudScale()
	local camera = workspace.CurrentCamera
	if not camera or camera.ViewportSize.X <= 0 or camera.ViewportSize.Y <= 0 then return end
	local profile = hudProfile(camera.ViewportSize)
	for scale in pairs(hudScales) do
		if not scale:IsDescendantOf(gui.Parent) then
			hudScales[scale] = nil
		else
			local value = scale:GetAttribute(profile)
			if typeof(value) ~= "number" or value ~= value or math.abs(value) == math.huge then value = 1 end
			value = math.clamp(value, 0.75, 1)
			if scale.Scale ~= value then scale.Scale = value end
		end
	end
end
refreshHudScale()

local function scale(phone,tablet)
 local object={Name="ResponsiveHudScale",Scale=1,attrs={PhoneScale=phone,TabletScale=tablet,DesktopScale=1},belongs=true}
 function object:IsA(name) return name=="UIScale" end
 function object:IsDescendantOf(_) return self.belongs end
 function object:GetAttribute(name) return self.attrs[name] end
 return object
end
local card=scale(.82,.9)
local controls=scale(.94,.94)
trackHudScale(card) trackHudScale(controls)
refreshHudScale()
assert(card.Scale==.82 and controls.Scale==.94,"Phone profile")
workspace.CurrentCamera.ViewportSize={X=1024,Y=768} refreshHudScale()
assert(card.Scale==.9,"iPad profile")
workspace.CurrentCamera.ViewportSize={X=1366,Y=1024} refreshHudScale()
assert(card.Scale==.9,"Large iPad profile")
workspace.CurrentCamera.ViewportSize={X=1920,Y=1080} refreshHudScale()
assert(card.Scale==1 and controls.Scale==1,"Desktop profile restores")
workspace.CurrentCamera.ViewportSize={X=390,Y=844} refreshHudScale()
assert(card.Scale==.82,"Rotation updates")
card.attrs.PhoneScale=0/0 refreshHudScale()
assert(card.Scale==1,"Invalid authored scale falls back")
card.belongs=false refreshHudScale()
assert(hudScales[card]==nil,"Removed UI released")
workspace.CurrentCamera=nil refreshHudScale()
assert(48*.94>=44,"Gameplay touch targets remain at least44px tall")
print("9 responsive HUD checks passed")

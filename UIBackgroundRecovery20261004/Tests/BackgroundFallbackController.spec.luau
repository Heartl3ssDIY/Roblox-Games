local checks = 0
local function check(value, message)
	assert(value, message)
	checks += 1
end
local function signal()
	local result = { slots = {} }
	function result:Connect(callback)
		local slot = { callback = callback, connected = true }
		table.insert(self.slots, slot)
		return { Disconnect = function() slot.connected = false end }
	end
	function result:Fire(...)
		for _, slot in ipairs(table.clone(self.slots)) do if slot.connected then slot.callback(...) end end
	end
	return result
end
local function color(r, g, b)
	return { R = r, G = g, B = b, Lerp = function(self, other, t)
		return color(self.R + (other.R - self.R) * t, self.G + (other.G - self.G) * t, self.B + (other.B - self.B) * t)
	end }
end
local Color3 = { new = color, fromRGB = function(r,g,b) return color(r/255,g/255,b/255) end }
local methods = {}
local layoutWrites = 0
local function object(class, name, parent)
	local props = { Name = name, ClassName = class, Parent = parent, Visible = true, Image = "", IsLoaded = false, ImageTransparency = 0, ImageColor3 = color(1,1,1), BackgroundColor3 = color(1,1,1), BackgroundTransparency = 0, Position = "authored-position", Size = "authored-size", AnchorPoint = "authored-anchor" }
	local value = { _props=props, _children={}, _attrs={}, _signals={}, AttributeChanged=signal(), AncestryChanged=signal(), DescendantAdded=signal(), Destroying=signal() }
	setmetatable(value,{
		__index=function(self,key) return methods[key] or self._props[key] end,
		__newindex=function(self,key,data)
			if key=="Position" or key=="Size" or key=="AnchorPoint" or key=="Rotation" or key=="LayoutOrder" or key=="ZIndex" then layoutWrites+=1 end
			local changed = self._props[key] ~= data
			self._props[key]=data
			if changed and self._signals[key] then self._signals[key]:Fire() end
		end
	})
	if parent then table.insert(parent._children,value) end
	return value
end
function methods:IsA(name) return self.ClassName==name or name=="GuiObject" and (self.ClassName=="Frame" or self.ClassName=="ImageLabel") end
function methods:FindFirstChild(name) for _,v in ipairs(self._children) do if v.Name==name then return v end end end
function methods:GetDescendants()
	local values={}
	local function collect(node) for _,child in ipairs(node._children) do table.insert(values,child);collect(child) end end
	collect(self)
	return values
end
function methods:IsDescendantOf(parent)
	local current=self.Parent
	while current do if current==parent then return true end;current=current.Parent end
	return false
end
function methods:GetAttribute(name) return self._attrs[name] end
function methods:SetAttribute(name,value) self._attrs[name]=value;self.AttributeChanged:Fire(name) end
function methods:GetPropertyChangedSignal(property)
	if not self._signals[property] then self._signals[property]=signal() end
	return self._signals[property]
end
local gui=object("ScreenGui","Test")
local script=object("LocalScript","BackgroundFallbackController",gui)
local task={ defer=function(callback) callback() end }
local Instance={new=function() error("Runtime must not create UI instances") end}
local function card(name, parent)
	local host=object("Frame",name,parent)
	local skin=object("ImageLabel","ReusableSkin",host)
	skin.Image="rbxassetid://117403446558356"
	local fallback=object("Frame","ReusableSkinFallback",host)
	fallback:SetAttribute("BackgroundFallbackFor","ReusableSkin")
	fallback:SetAttribute("FallbackFaceColor",Color3.fromRGB(255,249,224))
	fallback:SetAttribute("FallbackInkColor",Color3.fromRGB(31,38,60))
	local edge=object("Frame","Edge",fallback)
	local face=object("Frame","Face",edge)
	return host,skin,fallback,edge,face
end
local host,skin,fallback,edge,face=card("InitialCard",gui)
local original=skin.Image
local function runController()
local gui = script.Parent
local records = {}
local connections = {}
local alive = true
local white = Color3.new(1, 1, 1)
local palettes = {
	Blue = Color3.fromRGB(42, 160, 235),
	Gold = Color3.fromRGB(255, 205, 57),
	Cream = Color3.fromRGB(255, 249, 224),
	Green = Color3.fromRGB(94, 203, 162),
	Red = Color3.fromRGB(255, 105, 120),
	Pink = Color3.fromRGB(255, 153, 166),
	Silver = Color3.fromRGB(176, 188, 206),
	Black = Color3.fromRGB(61, 69, 86),
	Orange = Color3.fromRGB(255, 153, 66),
	Mud = Color3.fromRGB(168, 108, 59),
	Purple = Color3.fromRGB(175, 124, 229),
}
local imagePalettes = {
	["90528629970043"] = "Blue", ["84589903135132"] = "Gold",
	["80217215544210"] = "Cream", ["117403446558356"] = "Cream",
	["78972575698291"] = "Green", ["96220174131051"] = "Red",
	["91168456076260"] = "Silver", ["137398265947826"] = "Black",
	["70427716988197"] = "Orange", ["98268172973975"] = "Mud",
	["109174047078490"] = "Purple",
}

local function connect(bucket, signal, callback)
	table.insert(bucket, signal:Connect(callback))
end

local function release(skin)
	local record = records[skin]
	if not record then return end
	records[skin] = nil
	if record.fallback.Parent then record.fallback.Visible = false end
	for _, connection in ipairs(record.connections) do connection:Disconnect() end
end

local function tint(color, imageColor)
	return Color3.new(color.R * imageColor.R, color.G * imageColor.G, color.B * imageColor.B)
end

local function faceColor(skin, fallback)
	local image = skin.Image
	local id = string.match(image, "^rbxassetid://(%d+)") or string.match(image, "[?&]id=(%d+)")
	local palette = id and imagePalettes[id]
	if palette then return palettes[palette] end
	for name, color in pairs(palettes) do
		if image ~= "" and skin:GetAttribute(name .. "Image") == image then return color end
	end
	return fallback:GetAttribute("FallbackFaceColor") or palettes.Cream
end

local function bind(skin)
	if not alive or records[skin] or not (skin:IsA("ImageLabel") or skin:IsA("ImageButton")) then return end
	local parent = skin.Parent
	local fallback = parent and parent:FindFirstChild(skin.Name .. "Fallback")
	if not fallback or not fallback:IsA("Frame") or fallback:GetAttribute("BackgroundFallbackFor") ~= skin.Name then return end
	local edge = fallback:FindFirstChild("Edge")
	local face = edge and edge:FindFirstChild("Face")
	if not edge or not face then return end
	local record = { connections = {}, fallback = fallback }
	records[skin] = record
	local function refresh()
		if not alive or records[skin] ~= record or skin.Parent ~= fallback.Parent then return end
		local transparency = math.clamp(skin.ImageTransparency, 0, 1)
		fallback.Visible = skin.Visible and skin.Image ~= "" and not skin.IsLoaded and transparency < 1
		fallback.BackgroundTransparency = transparency
		edge.BackgroundTransparency = transparency
		face.BackgroundTransparency = transparency
		fallback.BackgroundColor3 = tint(fallback:GetAttribute("FallbackInkColor") or Color3.fromRGB(31, 38, 60), skin.ImageColor3)
		local color = faceColor(skin, fallback)
		edge.BackgroundColor3 = tint(color:Lerp(white, 0.72), skin.ImageColor3)
		face.BackgroundColor3 = tint(color, skin.ImageColor3)
	end
	record.refresh = refresh
	for _, property in ipairs({ "IsLoaded", "Image", "ImageTransparency", "ImageColor3", "Visible" }) do
		connect(record.connections, skin:GetPropertyChangedSignal(property), refresh)
	end
	connect(record.connections, skin.AttributeChanged, refresh)
	connect(record.connections, fallback.AttributeChanged, refresh)
	connect(record.connections, skin.AncestryChanged, function()
		if not skin:IsDescendantOf(gui) or skin.Parent ~= fallback.Parent then release(skin) end
	end)
	connect(record.connections, fallback.AncestryChanged, function()
		if not fallback:IsDescendantOf(gui) or fallback.Parent ~= skin.Parent then release(skin) end
	end)
	refresh()
end

connect(connections, gui.DescendantAdded, function(descendant)
	task.defer(function()
		if not alive or not descendant:IsDescendantOf(gui) then return end
		bind(descendant)
		if descendant:IsA("Frame") then
			local name = descendant:GetAttribute("BackgroundFallbackFor")
			local parent = descendant.Parent
			local skin = typeof(name) == "string" and parent and parent:FindFirstChild(name)
			if skin then bind(skin) end
		end
	end)
end)
connect(connections, script.Destroying, function()
	alive = false
	for skin in pairs(records) do release(skin) end
	for _, connection in ipairs(connections) do connection:Disconnect() end
end)
for _, descendant in ipairs(gui:GetDescendants()) do bind(descendant) end

end
runController()
check(fallback.Visible,"Unloaded PNG needs fallback")
check(skin.Image==original,"Must preserve image URI")
check(layoutWrites==0,"Startup changed authored layout")
skin.IsLoaded=true
check(not fallback.Visible,"Loaded PNG must immediately hide fallback")
skin.IsLoaded=false
check(fallback.Visible,"Failed replacement PNG must restore fallback")
skin.ImageTransparency=0.4
check(fallback.Visible,"Partially faded background stays visible")
check(fallback.BackgroundTransparency==0.4 and edge.BackgroundTransparency==0.4 and face.BackgroundTransparency==0.4,"Every native layer follows fade")
skin.ImageTransparency=1
check(not fallback.Visible,"Fully faded image cannot leave solid background")
skin.ImageTransparency=0
skin.Visible=false
check(not fallback.Visible,"Hidden skin hides fallback")
skin.Visible=true
check(fallback.Visible,"Visible unloaded skin restores fallback")
skin.Image=""
check(not fallback.Visible,"Intentionally blank image has no fallback")
skin.Image="rbxassetid://84589903135132"
check(math.abs(face.BackgroundColor3.R-1)<1e-9 and math.abs(face.BackgroundColor3.G-205/255)<1e-9,"Selected gold tab color")
skin.Image="rbxassetid://90528629970043"
check(math.abs(face.BackgroundColor3.R-42/255)<1e-9 and math.abs(face.BackgroundColor3.B-235/255)<1e-9,"Unselected blue tab color")
skin.ImageColor3=color(.5,.8,.9)
check(math.abs(face.BackgroundColor3.R-(42/255*.5))<1e-9,"Face follows image tint")
check(math.abs(fallback.BackgroundColor3.R-(31/255*.5))<1e-9,"Border follows image tint")
skin.Image="https://www.roblox.com/asset/?id=84589903135132"
check(math.abs(face.BackgroundColor3.R-.5)<1e-9,"HTTPS asset format keeps correct palette")
skin:SetAttribute("PurpleImage","rbxassetid://123")
skin.Image="rbxassetid://123"
check(math.abs(face.BackgroundColor3.R-(175/255*.5))<1e-9,"Authored dynamic image palettes supported")
skin.Image="rbxassetid://999"
fallback:SetAttribute("FallbackFaceColor",color(.2,.3,.4))
check(math.abs(face.BackgroundColor3.R-.1)<1e-9,"Unrecognized art retains authored palette and tint")
local host2,skin2,fallback2,edge2,face2=card("ClonedCard",gui)
for _,v in ipairs(host2:GetDescendants()) do gui.DescendantAdded:Fire(v) end
check(fallback2.Visible,"Runtime cloned editable template binds")
skin2.IsLoaded=true
check(not fallback2.Visible,"Cloned template recovers to PNG")
skin2.IsLoaded=false
check(fallback2.Visible,"Cloned template can fail again")
skin2.Parent=nil
skin2.AncestryChanged:Fire()
check(not fallback2.Visible,"Removed image must hide orphan fallback")
skin2.IsLoaded=true;skin2.IsLoaded=false
check(not fallback2.Visible,"Removed image signals disconnected")
local untouched=object("ImageLabel","Icon",gui)
untouched.Image="rbxassetid://12345"
gui.DescendantAdded:Fire(untouched)
check(untouched.Image=="rbxassetid://12345","Unmanaged icons unchanged")
check(layoutWrites==0,"Runtime must never overwrite layout geometry")
script.Destroying:Fire()
check(not fallback.Visible,"Destroying controller releases fallback")
skin.IsLoaded=true;skin.IsLoaded=false
check(not fallback.Visible,"Destroyed controller callbacks disconnected")
check(layoutWrites==0,"Cleanup must not alter authored layouts")
print("PASS "..checks.." background fallback lifecycle checks")

assert(not game:GetService("RunService"):IsRunning(),"Edit only")
local folder=Instance.new("Folder")folder.Name="EmoteWheelBindings20261005"folder.Parent=game.ServerStorage
local function install()
local StarterGui = folder
assert(not StarterGui:FindFirstChild("PlaygroundEmoteWheel"), "PlaygroundEmoteWheel already exists; preserve the authored UI and controller before rebuilding")

local skins = {
	Panel = "https://www.roblox.com/asset/?id=117403446558356&version=1",
	Cream = "rbxassetid://80217215544210",
	Gold = "rbxassetid://84589903135132",
	Blue = "https://www.roblox.com/asset/?id=90528629970043&version=1",
	Purple = "rbxassetid://109174047078490",
	Disabled = "rbxassetid://101720017581430",
	Selected = "rbxassetid://85788093672458",
}
local ink = Color3.fromRGB(24, 30, 51)
local cream = Color3.fromRGB(255, 249, 229)

local function label(parent, name, text, position, size, maximum, minimum)
	local object = Instance.new("TextLabel")
	object.Name = name
	object.BackgroundTransparency = 1
	object.BorderSizePixel = 0
	object.Position = position
	object.Size = size
	object.Text = text
	object.Font = Enum.Font.FredokaOne
	object.TextColor3 = cream
	object.TextScaled = true
	object.TextWrapped = true
	object.TextXAlignment = Enum.TextXAlignment.Center
	object.TextYAlignment = Enum.TextYAlignment.Center
	object.TextStrokeTransparency = 1
	object.ZIndex = 7
	object.Parent = parent
	local limit = Instance.new("UITextSizeConstraint")
	limit.Name = "TextSizeLimit"
	limit.MinTextSize = minimum or 9
	limit.MaxTextSize = maximum or 22
	limit.Parent = object
	local stroke = Instance.new("UIStroke")
	stroke.Name = "TextOutline"
	stroke.Color = ink
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	stroke.StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize
	stroke.BorderStrokePosition = Enum.BorderStrokePosition.Outer
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Thickness = 0.085
	stroke.Parent = object
	return object
end

local function skin(parent, image, name)
	local imageLabel = Instance.new("ImageLabel")
	imageLabel.Name = name or "ReusableSkin"
	imageLabel.BackgroundTransparency = 1
	imageLabel.BorderSizePixel = 0
	imageLabel.Size = UDim2.fromScale(1, 1)
	imageLabel.Image = image
	imageLabel.ScaleType = Enum.ScaleType.Slice
	imageLabel.SliceCenter = Rect.new(88, 88, 424, 232)
	imageLabel.SliceScale = 0.25
	imageLabel.ZIndex = parent.ZIndex
	imageLabel:SetAttribute("DefaultImage", image)
	imageLabel.Parent = parent
	return imageLabel
end

local function button(parent, name, text, position, size, image)
	local object = Instance.new("TextButton")
	object.Name = name
	object.BackgroundTransparency = 1
	object.BorderSizePixel = 0
	object.Position = position
	object.Size = size
	object.Text = text
	object.TextTransparency = 1
	object.TextStrokeTransparency = 1
	object.AutoButtonColor = false
	object.Selectable = true
	object.Active = true
	object.ZIndex = 6
	object:SetAttribute("NormalImage", image)
	object:SetAttribute("SelectedImage", skins.Gold)
	object:SetAttribute("DisabledImage", skins.Disabled)
	object.Parent = parent
	local hitSize = Instance.new("UISizeConstraint")
	hitSize.Name = "MinimumHitSize"
	hitSize.MinSize = Vector2.new(30, 26)
	hitSize.Parent = object
	skin(object, image)
	local caption = label(object, "LiveCaption", text, UDim2.fromScale(0.1, 0.18), UDim2.fromScale(0.8, 0.58), 21, 9)
	caption.ZIndex = 8
	return object
end

local gui = Instance.new("ScreenGui")
gui.Name = "PlaygroundEmoteWheel"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.DisplayOrder = 45
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Enabled = true
gui:SetAttribute("AuthoredUIVersion", 1)
gui:SetAttribute("SlotsPerPage", 8)
gui:SetAttribute("ToggleKeyboard", "Period")
gui:SetAttribute("ToggleGamepad", "DPadDown")
gui:SetAttribute("UsesOriginalEmoteThumbnails", true)

local backdrop = Instance.new("TextButton")
backdrop.Name = "Backdrop"
backdrop.Size = UDim2.fromScale(1, 1)
backdrop.BackgroundColor3 = ink
backdrop.BackgroundTransparency = 0.35
backdrop.BorderSizePixel = 0
backdrop.Text = ""
backdrop.AutoButtonColor = false
backdrop.Active = true
backdrop.Modal = true
backdrop.Selectable = false
backdrop.Visible = false
backdrop.ZIndex = 1
backdrop.Parent = gui

local toggle = button(gui, "Toggle", "EMOTES  [ . ]", UDim2.new(1, -18, 1, -160), UDim2.fromOffset(140, 38), skins.Purple)
toggle.AnchorPoint = Vector2.new(1, 1)
toggle.ZIndex = 10
toggle.ReusableSkin.ZIndex = 10
toggle.LiveCaption.ZIndex = 11
toggle:SetAttribute("PlacementNote", "12px above the authored 130px toy hotbar; independent of the existing dock")

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.BackgroundTransparency = 1
panel.BorderSizePixel = 0
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Size = UDim2.fromScale(0.94, 0.92)
panel.Visible = false
panel.Active = true
panel.ZIndex = 3
panel.Parent = gui
skin(panel, skins.Panel)
local aspect = Instance.new("UIAspectRatioConstraint")
aspect.Name = "PanelAspect"
aspect.AspectRatio = 0.96
aspect.AspectType = Enum.AspectType.FitWithinMaxSize
aspect.DominantAxis = Enum.DominantAxis.Width
aspect.Parent = panel
local sizeLimit = Instance.new("UISizeConstraint")
sizeLimit.Name = "SizeLimit"
sizeLimit.MinSize = Vector2.new(270, 281.25)
sizeLimit.MaxSize = Vector2.new(650, 680)
sizeLimit.Parent = panel
label(panel, "Title", "YOUR EMOTES", UDim2.fromScale(0.08, 0.025), UDim2.fromScale(0.72, 0.065), 34, 16)
local close = button(panel, "Close", "X", UDim2.fromScale(0.87, 0.027), UDim2.fromScale(0.085, 0.060), skins.Purple)

local wheel = Instance.new("Frame")
wheel.Name = "Wheel"
wheel.BackgroundTransparency = 1
wheel.BorderSizePixel = 0
wheel.AnchorPoint = Vector2.new(0.5, 0.5)
wheel.Position = UDim2.fromScale(0.5, 0.415)
wheel.Size = UDim2.fromScale(0.94, 0.640)
wheel.ZIndex = 4
wheel.Parent = panel
local wheelAspect = Instance.new("UIAspectRatioConstraint")
wheelAspect.Name = "WheelAspect"
wheelAspect.AspectRatio = 1
wheelAspect.AspectType = Enum.AspectType.FitWithinMaxSize
wheelAspect.DominantAxis = Enum.DominantAxis.Width
wheelAspect.Parent = wheel

local templates = Instance.new("Folder")
templates.Name = "Templates"
templates.Parent = gui
local slot = Instance.new("ImageButton")
slot.Name = "EmoteSlot"
slot.AnchorPoint = Vector2.new(0.5, 0.5)
slot.Size = UDim2.fromScale(0.245, 0.245)
slot.BackgroundTransparency = 1
slot.BorderSizePixel = 0
slot.Image = ""
slot.AutoButtonColor = false
slot.Active = true
slot.Selectable = true
slot.Visible = false
slot.ZIndex = 5
slot:SetAttribute("NormalImage", skins.Cream)
slot:SetAttribute("SelectedImage", skins.Gold)
slot:SetAttribute("DisabledImage", skins.Disabled)
slot:SetAttribute("ContentSource", "Owned emote catalog entries")
slot.Parent = templates
skin(slot, skins.Cream)
local thumbnail = Instance.new("ImageLabel")
thumbnail.Name = "Thumbnail"
thumbnail.AnchorPoint = Vector2.new(0.5, 0)
thumbnail.Position = UDim2.fromScale(0.5, 0.065)
thumbnail.Size = UDim2.fromScale(0.72, 0.405)
thumbnail.BackgroundTransparency = 1
thumbnail.BorderSizePixel = 0
thumbnail.Image = ""
thumbnail.ScaleType = Enum.ScaleType.Fit
thumbnail.ZIndex = 6
thumbnail.Parent = slot
label(slot, "ItemName", "EMPTY", UDim2.fromScale(0.015, 0.475), UDim2.fromScale(0.97, 0.335), 17, 7)
label(slot, "State", "", UDim2.fromScale(0.08, 0.82), UDim2.fromScale(0.84, 0.16), 11, 7)
local selected = Instance.new("ImageLabel")
selected.Name = "Selected"
selected.AnchorPoint = Vector2.new(1, 0)
selected.Position = UDim2.fromScale(0.96, 0.025)
selected.Size = UDim2.fromScale(0.19, 0.19)
selected.BackgroundTransparency = 1
selected.BorderSizePixel = 0
selected.Image = skins.Selected
selected.ScaleType = Enum.ScaleType.Fit
selected.Visible = false
selected.ZIndex = 9
selected.Parent = slot

local slots = {}
for index = 1, 8 do
	local angle = -math.pi * 0.5 + (index - 1) * math.pi * 0.25
	local clone = slot:Clone()
	clone.Name = "Slot" .. index
	clone.Position = UDim2.fromScale(0.5 + math.cos(angle) * 0.357, 0.5 + math.sin(angle) * 0.357)
	clone.LayoutOrder = index
	clone.Visible = true
	clone:SetAttribute("SlotIndex", index)
	clone.Parent = wheel
	slots[index] = clone
end

local hint = label(panel, "Hint", "CHOOSE AN\nEMOTE", UDim2.fromScale(0.37, 0.342), UDim2.fromScale(0.26, 0.085), 20, 8)
hint:SetAttribute("DefaultText", "CHOOSE AN\nEMOTE")
local stop = button(panel, "StopButton", "STOP", UDim2.fromScale(0.42, 0.448), UDim2.fromScale(0.16, 0.048), skins.Purple)
stop.Visible = false
stop.Active = false
stop.Selectable = false
stop:SetAttribute("RequiresServerStopEndpoint", true)

label(panel, "Status", "Loading your emotes...", UDim2.fromScale(0.075, 0.741), UDim2.fromScale(0.85, 0.038), 18, 9)
local previous = button(panel, "Previous", "<", UDim2.fromScale(0.22, 0.790), UDim2.fromScale(0.12, 0.074), skins.Blue)
label(panel, "PageLabel", "1 / 1", UDim2.fromScale(0.36, 0.794), UDim2.fromScale(0.28, 0.064), 20, 10)
local nextButton = button(panel, "Next", ">", UDim2.fromScale(0.66, 0.790), UDim2.fromScale(0.12, 0.074), skins.Blue)
local shop = button(panel, "ShopButton", "EMOTE SHOP", UDim2.fromScale(0.25, 0.894), UDim2.fromScale(0.50, 0.070), skins.Gold)
for index, object in ipairs(slots) do
	object.NextSelectionLeft = slots[(index - 2) % 8 + 1]
	object.NextSelectionRight = slots[index % 8 + 1]
	object.NextSelectionUp = close
	object.NextSelectionDown = shop
end
previous.NextSelectionRight = nextButton
nextButton.NextSelectionLeft = previous
previous.NextSelectionDown = shop
nextButton.NextSelectionDown = shop
shop.NextSelectionUp = slots[5]
close.NextSelectionDown = slots[1]
gui.Parent = StarterGui

return { path = gui:GetFullName(), slots = 8, version = 1, closed = not panel.Visible, stopAvailable = false }

end
install()
local item=Instance.new("ModuleScript")item.Name="Checks"
item.Capabilities=game.StarterGui.PlaygroundToyHotbar.Controller.Capabilities item.Sandboxed=game.StarterGui.PlaygroundToyHotbar.Controller.Sandboxed
item.Source=[====[local passed,result=xpcall(function()
local gui=script.Parent:WaitForChild("PlaygroundEmoteWheel")
local panel=gui.Panel
local toggle=gui.Toggle
local clock=100
local os={clock=function()return clock end}
local player={attrs={PCEmoteAction="E03"},GetAttribute=function(self,key)return self.attrs[key]end}
local UserInputService={TouchEnabled=false}
local function gamepadActive()return false end
local playing=false
local function isPlaying()return playing end
local alive,ready,busy=true,true,false
local page,pageCount=1,1
local notice,noticeUntil="",0
local dances,slots={},{}
local catalog={Items={}}
local owned,equipped={},{Emote="E05"}
for i=1,10 do
 local id="E"..string.format("%02d",i)
 table.insert(catalog.Items,{id=id,name="Dance "..i,slot="Emote",playable=true,available=true,thumbnail="rbxassetid://1"})owned[id]=true
end
for i=1,8 do local button=panel.Wheel:FindFirstChild("Slot"..i)table.insert(slots,{button=button,selected=button:WaitForChild("Selected"),generation=0,imageStatus=""})end
local authored={}
for _,obj in ipairs(gui:GetDescendants())do if obj:IsA("GuiObject")then authored[obj]={obj.Position,obj.Size}end end
local render
local function buttonState(button, enabled, selected)
	button.Active = enabled
	button.Selectable = enabled
	local skin = button:FindFirstChild("ReusableSkin")
	local attribute = not enabled and "DisabledImage" or selected and "SelectedImage" or "NormalImage"
	local image = button:GetAttribute(attribute)
	if skin and typeof(image) == "string" then skin.Image = image end
end


local function imageState(record)
	if not record.item then return end
	if record.button.Thumbnail.IsLoaded then
		record.imageStatus = ""
	else
		if panel.Visible and not record.imageStartedAt then record.imageStartedAt = os.clock() end
		record.imageStatus = record.imageStartedAt and os.clock() - record.imageStartedAt >= 8 and "IMAGE UNAVAILABLE" or "LOADING IMAGE"
	end
end

local function setImage(record, item)
	if record.item == item then imageState(record) return end
	record.item = item
	record.imageStartedAt = nil
	record.imageStatus = ""
	local thumbnail = record.button.Thumbnail
	thumbnail.Image = item and item.thumbnail or ""
	thumbnail.Visible = item ~= nil
	if not item then return end
	imageState(record)
end


render = function()
	if not alive then return end
	dances = {}
	for _, item in ipairs(catalog.Items) do
		if item.slot == "Emote" and item.playable == true and item.available ~= false and owned[item.id] == true then
			table.insert(dances, item)
		end
	end
	pageCount = math.max(1, math.ceil(#dances / 8))
	page = math.clamp(page, 1, pageCount)
	local active = isPlaying() and player:GetAttribute("PCEmoteAction") or ""
	for index, record in ipairs(slots) do
		local item = dances[(page - 1) * 8 + index]
		setImage(record, item)
		local button = record.button
		button.Visible = item ~= nil
		buttonState(button, item ~= nil and ready and not busy, item ~= nil and (active == item.id or record.hovered == true))
		button.ItemName.Text = item and item.name or ""
		record.selected.Visible = item ~= nil and (active == item.id or record.hovered == true)
		button.State.Text = item and (active == item.id and "PLAYING" or record.imageStatus ~= "" and record.imageStatus or equipped.Emote == item.id and "PODIUM EMOTE" or "") or ""
	end
	panel.PageLabel.Text = tostring(page) .. " / " .. tostring(pageCount)
	buttonState(panel.Previous, not busy and page > 1)
	buttonState(panel.Next, not busy and page < pageCount)
	buttonState(panel.StopButton, not busy and isPlaying())
	panel.StopButton.Visible = isPlaying()
	if notice ~= "" and os.clock() < noticeUntil then panel.Status.Text = notice
	elseif busy then panel.Status.Text = "Loading..."
	elseif not ready then panel.Status.Text = "Your emotes are getting ready."
	elseif #dances == 0 then panel.Status.Text = "No emotes yet. Unlock dances in the shop."
	else panel.Status.Text = tostring(#dances) .. " owned • Move or jump to stop" end
	panel.Hint.Text = gamepadActive() and "A TO PLAY\nB TO CLOSE" or UserInputService.TouchEnabled and "TAP A\nDANCE" or "CLICK OR 1–8\nTO DANCE"
	local caption = toggle:FindFirstChild("LiveCaption")
	if caption then caption.Text = gamepadActive() and "EMOTES [D-PAD]" or UserInputService.TouchEnabled and "EMOTES" or "EMOTES [ . ]" end
end


local checks=0
local function check(value,message)assert(value,message)checks+=1 end
render()
check(typeof(slots[1].button.Selected)=="boolean" and slots[1].selected:IsA("ImageLabel"),"Native Selected collision bypassed by cached child")
check(panel.PageLabel.Text=="1 / 2" and slots[8].button.ItemName.Text=="Dance 8","Actual native UI binds eight card labels")
check(slots[5].button.State.Text=="LOADING IMAGE" or slots[5].button.State.Text=="PODIUM EMOTE","Native thumbnail state renders without service dependency")
check(panel.Next.Active and not panel.Previous.Active,"Native pagination interactability")
playing=true render()
check(slots[3].selected.Visible and slots[3].button.State.Text=="PLAYING","Active emote selection uses authored native child")
check(panel.StopButton.Visible and panel.StopButton.Active,"Native Stop UI state")
page=2 render()
check(slots[1].button.Visible and slots[2].button.Visible and not slots[3].button.Visible,"Last page hides empty slots")
check(slots[1].button.ItemName.Text=="Dance 9" and panel.PageLabel.Text=="2 / 2","Native second page maps correct items")
busy=true render()check(not slots[1].button.Active and not panel.StopButton.Active,"Busy state disables conflicting controls")
busy=false ready=false render()check(not slots[1].button.Active,"Profile loading disables playback")
for obj,state in pairs(authored)do check(obj.Position==state[1] and obj.Size==state[2],"Authored layout unchanged: "..obj.Name)end
return{passed=true,checks=checks}
end,debug.traceback)
return{passed=passed,result=result}
]====] item.Parent=folder
local ok,result=xpcall(function()return require(item)end,debug.traceback)
folder:Destroy()
return {passed=ok,result=result,fixtureCleaned=game.ServerStorage:FindFirstChild("EmoteWheelBindings20261005")==nil}

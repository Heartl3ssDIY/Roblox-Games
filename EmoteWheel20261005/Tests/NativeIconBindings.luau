assert(not game:GetService("RunService"):IsRunning(),"Edit only")
local fixture=Instance.new("Folder") fixture.Name="_ItemIconInstallerChecks" fixture.Parent=game.ServerStorage
local shell=game.StarterGui.PlaygroundShell:Clone() shell.Parent=fixture
local hotbar=game.StarterGui.PlaygroundToyHotbar:Clone() hotbar.Parent=fixture
for _,obj in ipairs(fixture:GetDescendants()) do if obj:IsA("BaseScript") then obj.Enabled=false end end
local boxes={}
local ok,result=xpcall(function()
local function install(starterGui)
	local shell = assert(starterGui:FindFirstChild("PlaygroundShell"), "PlaygroundShell missing")
	local hotbar = assert(starterGui:FindFirstChild("PlaygroundToyHotbar"), "PlaygroundToyHotbar missing")
	local cards = shell.ShopPanel.Cards
	local templates = shell:FindFirstChild("Templates")
	local targets = {}
	for _, child in ipairs(cards:GetChildren()) do
		if child:IsA("Frame") and child:FindFirstChild("Preview") and child:FindFirstChild("Action") then table.insert(targets, child) end
	end
	local template = templates and templates:FindFirstChild("ItemCard")
	if template then table.insert(targets, template) end
	for index = 1, 4 do table.insert(targets, assert(hotbar.Bar.Slots:FindFirstChild("Slot" .. tostring(index)))) end
	local created = 0
	for _, host in ipairs(targets) do
		local preview = assert(host:FindFirstChild("Preview"), "Preview missing")
		local thumbnail = host:FindFirstChild("Thumbnail")
		if not thumbnail then
			thumbnail = Instance.new("ImageLabel")
			thumbnail.Name = "Thumbnail"
			thumbnail.AnchorPoint = preview.AnchorPoint
			thumbnail.Position = preview.Position
			thumbnail.Size = preview.Size
			thumbnail.Rotation = preview.Rotation
			thumbnail.ZIndex = preview.ZIndex
			thumbnail.LayoutOrder = preview.LayoutOrder
			thumbnail.BackgroundTransparency = 1
			thumbnail.BorderSizePixel = 0
			thumbnail.ScaleType = Enum.ScaleType.Fit
			thumbnail.ImageColor3 = Color3.new(1, 1, 1)
			thumbnail.Visible = false
			thumbnail:SetAttribute("Purpose", "Original supplied item PNG; image bound from catalog.thumbnail")
			thumbnail.Parent = host
			created += 1
		end
		assert(thumbnail:IsA("ImageLabel"), "Thumbnail must be an editable ImageLabel")
		preview.Visible = false
	end
	return { created = created, targets = #targets }
end

local rectangles={}
for _,obj in ipairs(fixture:GetDescendants()) do if obj:IsA("GuiObject") then rectangles[obj]={obj.Position,obj.Size,obj.AnchorPoint,obj.Rotation} end end
local installed=install(fixture)
assert(installed.created==4 and installed.targets==17,"4 toy thumbnails and 13 existing shop/template thumbnails")
for obj,r in pairs(rectangles) do assert(obj.Position==r[1] and obj.Size==r[2] and obj.AnchorPoint==r[3] and obj.Rotation==r[4],"Existing geometry preserved: "..obj:GetFullName()) end
for i=1,4 do
 local slot=hotbar.Bar.Slots["Slot"..i]
 assert(slot.Thumbnail.Position==slot.Preview.Position and slot.Thumbnail.Size==slot.Preview.Size,"New thumbnail matches Preview")
 assert(slot.Thumbnail.BackgroundTransparency==1 and slot.Thumbnail.BorderSizePixel==0 and slot.Thumbnail.ScaleType==Enum.ScaleType.Fit,"No extra panel or image distortion")
end
assert(install(fixture).created==0,"Installer idempotent")
local function run(source,live)
 local box=live:Clone() box.Name="_IconBindingChecks" box.Enabled=false box.Parent=game.ServerStorage table.insert(boxes,box)
 local copy=fixture:Clone() copy.Name="Fixture" copy.Parent=box
 local module=Instance.new("ModuleScript") module.Name="Checks" module.Source=source module.Parent=box
 local report=require(module)
 report.exactCapabilities=box.Capabilities==live.Capabilities
 report.capabilities=tostring(box.Capabilities)
 return report
end
local shop=run([========[
local count=0 local checks={}
local function check(value,message) assert(value,message) count+=1 table.insert(checks,message) end
local alive=true local delays={}
local task={delay=function(_,callback)table.insert(delays,callback)end}
local function itemThumbnail(item)
	if not item then return "" end
	if typeof(item.thumbnail) == "string" and item.thumbnail ~= "" then return item.thumbnail end
	local id = item.catalogId
	if item.slot == "Emote" and typeof(id) == "number" and id == id and id > 0 and id < math.huge and id % 1 == 0 then
		return "rbxthumb://type=Asset&id=" .. string.format("%.0f", id) .. "&w=420&h=420"
	end
	return ""
end

local function refreshThumbnail(record)
	if not alive or not record.card.Parent then return end
	local thumbnail = record.card.Thumbnail
	local status = record.card.ThumbnailStatus
	status.Visible = thumbnail.Visible and (thumbnail.Image == "" or not thumbnail.IsLoaded)
	status.Text = (thumbnail.Image == "" or record.thumbnailTimedOut) and "Preview unavailable" or "Loading preview..."
end

local function renderPreview(record, item)
	local id = item and item.id or nil
	local image = itemThumbnail(item)
	if record.previewId == id and record.card.Thumbnail.Image == image then return end
	record.previewId = id
	record.previewToken = (record.previewToken or 0) + 1
	local token = record.previewToken
	record.thumbnailTimedOut = false
	record.card.Preview.Visible = false
	record.card.Thumbnail.Image = image
	record.card.Thumbnail.Visible = item ~= nil
	refreshThumbnail(record)
	if item and image ~= "" and not record.card.Thumbnail.IsLoaded then
		task.delay(8, function()
			if alive and record.previewToken == token and record.card.Parent and record.card.Thumbnail.Image == image then
				record.thumbnailTimedOut = true
				refreshThumbnail(record)
			end
		end)
	end
end


local card=script.Parent.Fixture.PlaygroundShell.ShopPanel.Cards.Slot01
local original={card.Position,card.Size,card.Preview.Position,card.Preview.Size}
local record={card=card}
local function make(id,slot,image) return {id=id,slot=slot,thumbnail=image} end
for _,item in ipairs({make("B01","Bat","rbxassetid://103030924200276"),make("P01","Pet","rbxassetid://1"),make("M01","Gear","rbxassetid://2"),make("E01","Emote","rbxthumb://type=Asset&id=3360689775&w=420&h=420")}) do
 renderPreview(record,item)
 check(card.Thumbnail.Visible and card.Thumbnail.Image==item.thumbnail and not card.Preview.Visible,"Catalog PNG/thumbnail used for "..item.slot)
end
check(itemThumbnail({slot="Emote",catalogId=3360689775})=="rbxthumb://type=Asset&id=3360689775&w=420&h=420","Emote catalog thumbnail fallback retained")
check(itemThumbnail({slot="Bat",catalogId=123})=="","Model ID is never treated as emote thumbnail")
check(itemThumbnail({slot="Emote",catalogId=0/0})=="" and itemThumbnail({slot="Emote",catalogId=-1})=="","Invalid thumbnail IDs stay empty")
renderPreview(record,make("X01","Bat","rbxassetid://3"))
local old=delays[#delays]
renderPreview(record,make("X02","Pet","rbxassetid://4"))
old()
check(not record.thumbnailTimedOut,"Old page timeout cannot affect current item")
delays[#delays]()
check(record.thumbnailTimedOut and card.ThumbnailStatus.Text=="Preview unavailable","Timeout produces bounded unavailable state")
renderPreview(record,make("X03","Gear",""))
check(card.Thumbnail.Visible and card.ThumbnailStatus.Visible and card.ThumbnailStatus.Text=="Preview unavailable","Missing PNG has honest unavailable state")
renderPreview(record,nil)
check(not card.Thumbnail.Visible and not card.ThumbnailStatus.Visible and not card.Preview.Visible and card.Thumbnail.Image=="","Empty card clears old PNG and status")
renderPreview(record,make("X04","Bat","rbxassetid://5"))
local old=delays[#delays]
alive=false old()
check(not record.thumbnailTimedOut,"Destroy cancels pending timeout writes")
check(card.Position==original[1] and card.Size==original[2] and card.Preview.Position==original[3] and card.Preview.Size==original[4],"Binding preserves authored geometry")
alive=true
local fake={card={Parent=true,Thumbnail={Visible=true,Image="rbxassetid://1",IsLoaded=false},ThumbnailStatus={}},thumbnailTimedOut=true}
refreshThumbnail(fake) check(fake.card.ThumbnailStatus.Visible,"Failed image status remains visible")
fake.card.Thumbnail.IsLoaded=true refreshThumbnail(fake) check(not fake.card.ThumbnailStatus.Visible,"Late successful PNG hides timeout status")
return {passed=count,checks=checks}
]========],game.StarterGui.PlaygroundShell.Controller)
local toys=run([========[
local count=0 local checks={}
local function check(value,message) assert(value,message) count+=1 table.insert(checks,message) end
local alive=true local delays={}
local task={delay=function(_,callback)table.insert(delays,callback)end}
local catalog={ById={M01={thumbnail="rbxassetid://1"},M02={thumbnail="rbxassetid://2"},M03={}}}
local function refreshThumbnail(record)
	if not alive or not record.button.Parent then return end
	local thumbnail = record.button.Thumbnail
	local note = record.button.PreviewNote
	note.Visible = thumbnail.Visible and (thumbnail.Image == "" or not thumbnail.IsLoaded)
	note.Text = (thumbnail.Image == "" or record.thumbnailTimedOut) and "NO PREVIEW" or "LOADING..."
end

local function preview(record, id)
	local item = catalog.ById[id]
	local image = item and typeof(item.thumbnail) == "string" and item.thumbnail or ""
	if record.id == id and record.button.Thumbnail.Image == image then return end
	record.id = id
	record.generation += 1
	local generation = record.generation
	record.thumbnailTimedOut = false
	record.button.Preview.Visible = false
	record.button.Thumbnail.Image = image
	record.button.Thumbnail.Visible = id ~= ""
	refreshThumbnail(record)
	if id ~= "" and image ~= "" and not record.button.Thumbnail.IsLoaded then
		task.delay(8, function()
			if alive and generation == record.generation and record.button.Parent and record.button.Thumbnail.Image == image then
				record.thumbnailTimedOut = true
				refreshThumbnail(record)
			end
		end)
	end
end


local button=script.Parent.Fixture.PlaygroundToyHotbar.Bar.Slots.Slot1
local record={button=button,generation=0}
local original={button.Position,button.Size,button.Preview.Position,button.Preview.Size}
preview(record,"M01")
check(button.Thumbnail.Image==catalog.ById.M01.thumbnail and button.Thumbnail.Visible and not button.Preview.Visible,"Toy uses supplied PNG")
local old=delays[#delays]
preview(record,"M02") old()
check(not record.thumbnailTimedOut,"Old loadout timeout cannot affect selected replacement")
delays[#delays]()
check(record.thumbnailTimedOut and button.PreviewNote.Text=="NO PREVIEW","Toy loading state is bounded")
preview(record,"M03")
check(button.PreviewNote.Visible and button.PreviewNote.Text=="NO PREVIEW","Missing toy image is explicit")
preview(record,"")
check(not button.Thumbnail.Visible and not button.PreviewNote.Visible and button.Thumbnail.Image=="","Empty slot clears stale PNG")
preview(record,"M01") local old=delays[#delays] alive=false old()
check(not record.thumbnailTimedOut,"Destroyed hotbar ignores old image callbacks")
check(button.Position==original[1] and button.Size==original[2] and button.Preview.Position==original[3] and button.Preview.Size==original[4],"Toy binding preserves authored geometry")
alive=true
local fake={button={Parent=true,Thumbnail={Visible=true,Image="rbxassetid://1",IsLoaded=false},PreviewNote={}},thumbnailTimedOut=true}
refreshThumbnail(fake) check(fake.button.PreviewNote.Visible,"Failed toy image remains explicit")
fake.button.Thumbnail.IsLoaded=true refreshThumbnail(fake) check(not fake.button.PreviewNote.Visible,"Late toy PNG hides timeout status")
return {passed=count,checks=checks}
]========],game.StarterGui.PlaygroundToyHotbar.Controller)
return {installerTargets=installed.targets,created=installed.created,installerChecks=11,shell=shop,toy=toys}
end,debug.traceback)
for _,box in ipairs(boxes) do box:Destroy() end
fixture:Destroy()
assert(ok,result)
return game:GetService("HttpService"):JSONEncode(result)

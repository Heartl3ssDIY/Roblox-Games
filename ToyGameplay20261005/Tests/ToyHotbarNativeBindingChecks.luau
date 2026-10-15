local gui=script.Parent:WaitForChild("TestGui")
local bar=gui.Bar
local character=script.Parent.TestCharacter
local catalog=require(game.ReplicatedStorage.PlaygroundCatalog)
local attrs={PCDataReady=true,PCToyEmberUntil=0}
local player={Character=character}
function player:GetAttribute(k)return attrs[k]end
local alive,pending=true,false
local notice,noticeUntil="",0
local activeIndex,activeId=3,"M10"
local modal,backpackVisible=false,true
local UserInputService={TouchEnabled=false}
local function usable()return not attrs.MDParticipating end
local function inRound()return attrs.MDParticipating==true end
local function modalOpen()return modal end
local function showNativeBackpack(show)backpackVisible=show end
local function cooldownEndsAt(id)return attrs["PCToyCooldown_"..id]or 0 end
local slots={}
for index,id in ipairs({"M01","M05","M10","M15"})do slots[index]={button=bar.Slots["Slot"..index],id=id}end
local refresh

refresh = function()
	if not alive then return end
	local hasToy = false
	for _, record in ipairs(slots) do if record.id ~= "" then hasToy = true break end end
	local available = usable()
	bar.Visible = hasToy and player:GetAttribute("PCDataReady") == true and not inRound() and not modalOpen()
	showNativeBackpack(not (hasToy and player:GetAttribute("PCDataReady") == true and not inRound() and gui.Enabled))
	local now = workspace:GetServerTimeNow()
	local remaining = math.max(0, cooldownEndsAt(activeId) - now)
	local item = catalog.ById[activeId]
	local actionPending = item and item.toyActionPending == true
	local character = player.Character
	local heldTool = character and character:FindFirstChildOfClass("Tool")
	local heldId = heldTool and heldTool:GetAttribute("CatalogId")
	for index, record in ipairs(slots) do
		local selected = index == activeIndex and record.id ~= ""
		local selectionTag = record.button:FindFirstChild("Selected")
		selectionTag.Visible = selected
		selectionTag.Text = selected and heldId == record.id and "HELD" or "READY"
		record.button.Key.TextColor3 = selected and Color3.fromRGB(255, 215, 74) or Color3.fromRGB(255, 249, 224)
		record.button.Active = available and not pending and record.id ~= ""
		record.button.Selectable = record.button.Active
		record.button.ReusableSkin.ImageColor3 = record.id == "" and Color3.fromRGB(155, 155, 155) or Color3.new(1, 1, 1)
	end
	bar.Use.Active = available and not pending and activeId ~= "" and remaining <= 0 and not actionPending
	bar.Use.Selectable = bar.Use.Active
	local label = pending and "WAIT..." or actionPending and "SOON" or remaining > 0 and string.format("%.1fs", remaining) or "USE"
	bar.Use.Text = label
	bar.Use.LiveCaption.Text = label
	bar.Use.ReusableSkin.ImageColor3 = bar.Use.Active and Color3.new(1, 1, 1) or Color3.fromRGB(165, 165, 165)
	bar.Status.Text = now < noticeUntil and notice or not available and "Respawning..." or activeId == "" and "Select a toy" or actionPending and "Action coming soon" or UserInputService.TouchEnabled and "Tap a slot, then USE" or "1–4 select • click to use"
	local ember = tonumber(player:GetAttribute("PCToyEmberUntil")) or 0
	gui.Crosshair.Visible = bar.Visible and available and (activeId == "M10" or activeId == "M07" and ember > now)
end


local report={checks={}}
local function check(n,v)assert(v,n)table.insert(report.checks,n)end
refresh()
check("Real native buttons bind without Selected-property collision",bar.Slots.Slot3:FindFirstChild("Selected").Visible)
check("Held marker uses actual Tool catalog ID",bar.Slots.Slot3:FindFirstChild("Selected").Text=="HELD")
check("Other markers are hidden",not bar.Slots.Slot1:FindFirstChild("Selected").Visible)
check("Available toy has active USE button",bar.Use.Active and bar.Use.LiveCaption.Text=="USE")
check("Custom bar suppresses native Backpack",bar.Visible and not backpackVisible)
modal=true refresh()
check("Modal hides custom bar but preserves Backpack suppression",not bar.Visible and not backpackVisible)
modal=false attrs.PCToyCooldown_M10=workspace:GetServerTimeNow()+1 refresh()
check("Authoritative cooldown disables USE",not bar.Use.Active and bar.Use.LiveCaption.Text:find("s")~=nil)
attrs.PCToyCooldown_M10=0 pending=true refresh()
check("Pending request disables native slot controls",not bar.Slots.Slot1.Active and bar.Use.LiveCaption.Text=="WAIT...")
pending=false activeIndex=4 activeId="M09"slots[4].id="M09"refresh()
check("Pending toy action shows SOON without disabling slot selection",bar.Use.LiveCaption.Text=="SOON"and not bar.Use.Active and bar.Slots.Slot4.Active)
check("Unheld selection is labelled READY",bar.Slots.Slot4:FindFirstChild("Selected").Text=="READY")
attrs.MDParticipating=true refresh()
check("Round hides bar and restores native Backpack",not bar.Visible and backpackVisible and not gui.Crosshair.Visible)
report.passed=true return report


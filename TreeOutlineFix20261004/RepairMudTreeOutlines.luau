assert(not game:GetService("RunService"):IsRunning(), "Keep Play stopped")
local scenery = workspace["Stuck in the Mud"].Scenery
local storage = game:GetService("ServerStorage")
assert(not storage:FindFirstChild("TreeOutlineFix20261004"), "Tree outline fix already has a backup")
local crowns = {}
for _, part in ipairs(scenery:GetChildren()) do
 if part:IsA("BasePart") and part.Name == "TreeCrownGreen" then table.insert(crowns, part) end
end
table.sort(crowns, function(a, b) return a.Position.X == b.Position.X and a.Position.Z < b.Position.Z or a.Position.X < b.Position.X end)
assert(#crowns == 14, "Expected the 14 authored Mud trees")
local used, plans = {}, {}
for index, crown in ipairs(crowns) do
 local parts = {}
 for _, name in ipairs({ "TreeTrunkInk", "TreeTrunkBrown", "TreeCrownInk", "TreeCrownGreen", "TreeCrownLight" }) do
  local best, distance
  for _, part in ipairs(scenery:GetChildren()) do
   if part:IsA("BasePart") and part.Name == name then
    local delta = part.Position - crown.Position
    local horizontal = Vector2.new(delta.X, delta.Z).Magnitude
    if not distance or horizontal < distance then best, distance = part, horizontal end
   end
  end
  assert(best and distance <= 5.1 and not used[best], "Ambiguous tree part: " .. name)
  used[best] = true
  table.insert(parts, best)
 end
 table.insert(plans, { name = string.format("Tree%02d", index), crown = crown, parts = parts })
end
local backup = Instance.new("Folder")
backup.Name = "TreeOutlineFix20261004"
backup:SetAttribute("Purpose", "Original Mud trees before replacing solid canopy shells with silhouette outlines")
backup.Parent = storage
local report = { trees = 0, hiddenShells = 0, outlines = 0, preservedParts = 0, playStarted = false, before = {} }
for _, plan in ipairs(plans) do
 local saved = Instance.new("Folder")
 saved.Name = plan.name
 saved.Parent = backup
 local tree = Instance.new("Model")
 tree.Name = plan.name
 tree:SetAttribute("TreeOutlineFix", "20261004")
 tree.Parent = scenery
 local link = Instance.new("ObjectValue")
 link.Name = "RepairedTree"
 link.Value = tree
 link.Parent = saved
 local ink
 for _, part in ipairs(plan.parts) do
  local original = part:Clone()
  original.Parent = saved
  table.insert(report.before, { tree = tree.Name, part = part.Name, size = { part.Size.X, part.Size.Y, part.Size.Z }, cframe = { part.CFrame:GetComponents() }, transparency = part.Transparency, color = { part.Color.R, part.Color.G, part.Color.B }, canCollide = part.CanCollide, canTouch = part.CanTouch, canQuery = part.CanQuery })
  part.Parent = tree
  if part.Name == "TreeCrownInk" then
   ink = part
   part.Transparency = 1
   part.CanCollide = false
   part.CanQuery = false
   part.CanTouch = false
   part:SetAttribute("PCOutlineShellReplaced", true)
   report.hiddenShells += 1
  end
  assert(part.CFrame == original.CFrame and part.Size == original.Size and part.Color == original.Color, "Tree art moved or resized")
  report.preservedParts += 1
 end
 tree.PrimaryPart = plan.crown
 local outline = Instance.new("Highlight")
 outline.Name = "TreeOutline"
 outline.Adornee = tree
 outline.FillTransparency = 1
 outline.OutlineTransparency = 0
 outline.OutlineColor = ink.Color
 outline.DepthMode = Enum.HighlightDepthMode.Occluded
 outline.Parent = tree
 report.trees += 1
 report.outlines += 1
end
return report

local module=Instance.new("ModuleScript")
module.Name="VIPShopVerification"
module.Source="local ReplicatedStorage=game:GetService(\"ReplicatedStorage\")\nlocal alive=true\nlocal gameLabels={All=\"total\"}\nlocal function itemThumbnail(item)\n\tif not item then return \"\" end\n\tif typeof(item.thumbnail) == \"string\" and item.thumbnail ~= \"\" then return item.thumbnail end\n\tlocal id = item.catalogId\n\tif item.slot == \"Emote\" and typeof(id) == \"number\" and id == id and id > 0 and id < math.huge and id % 1 == 0 then\n\t\treturn \"rbxthumb://type=Asset&id=\" .. string.format(\"%.0f\", id) .. \"&w=420&h=420\"\n\tend\n\treturn \"\"\nend\n\nlocal function clearModelPreview(record)\n\tif record.previewModel then record.previewModel:Destroy() record.previewModel = nil end\n\tif record.previewCamera then record.previewCamera:Destroy() record.previewCamera = nil end\n\trecord.card.Preview.CurrentCamera = nil\nend\n\nlocal function frameModelPreview(record)\n\tif not record.previewModel or not record.previewCamera then return end\n\tlocal viewport = record.card.Preview\n\tlocal bounds, size = record.previewModel:GetBoundingBox()\n\tlocal radius = math.max(0.1, size.Magnitude * 0.5)\n\tlocal aspect = math.max(0.1, viewport.AbsoluteSize.X / math.max(1, viewport.AbsoluteSize.Y))\n\tlocal halfFov = math.rad(record.previewCamera.FieldOfView * 0.5)\n\tlocal limitingFov = math.min(halfFov, math.atan(math.tan(halfFov) * aspect))\n\tlocal distance = radius / math.sin(limitingFov) * 1.08\n\tlocal center = bounds.Position\n\trecord.previewCamera.CFrame = CFrame.lookAt(center + Vector3.new(0, 0.15, -1).Unit * distance, center)\nend\n\nlocal function buildModelPreview(record, item)\n\tlocal assets = ReplicatedStorage:FindFirstChild(\"PlaygroundCosmeticAssets\")\n\tlocal template = assets and assets:FindFirstChild(item.id)\n\tif not template or not template:IsA(\"Model\") then return false end\n\tlocal viewport = record.card.Preview\n\tlocal world = viewport:FindFirstChild(\"World\")\n\tif not world then return false end\n\tlocal ok = pcall(function()\n\t\tworld:ClearAllChildren()\n\t\tlocal model = template:Clone()\n\t\trecord.previewModel = model\n\t\tmodel.Name = \"ItemModel\"\n\t\tfor _, object in ipairs(model:GetDescendants()) do\n\t\t\tif object:IsA(\"BaseScript\") or object:IsA(\"ObjectValue\") or object:IsA(\"Highlight\") then\n\t\t\t\tobject:Destroy()\n\t\t\telseif object:IsA(\"BasePart\") then\n\t\t\t\tobject.Anchored = true\n\t\t\t\tobject.CanCollide = false\n\t\t\t\tobject.CanTouch = false\n\t\t\t\tobject.CanQuery = false\n\t\t\tend\n\t\tend\n\t\tmodel:PivotTo(CFrame.identity)\n\t\tmodel.Parent = world\n\t\tlocal camera = Instance.new(\"Camera\")\n\t\tcamera.Name = \"PreviewCamera\"\n\t\tcamera.FieldOfView = 35\n\t\tcamera.Parent = viewport\n\t\trecord.previewCamera = camera\n\t\tviewport.CurrentCamera = camera\n\t\tframeModelPreview(record)\n\tend)\n\tif not ok then clearModelPreview(record) end\n\treturn ok\nend\n\nlocal function refreshThumbnail(record)\n\tif not alive or not record.card.Parent then return end\n\tlocal thumbnail = record.card.Thumbnail\n\tlocal status = record.card.ThumbnailStatus\n\tstatus.Visible = thumbnail.Visible and (thumbnail.Image == \"\" or not thumbnail.IsLoaded)\n\tstatus.Text = (thumbnail.Image == \"\" or record.thumbnailTimedOut) and \"Preview unavailable\" or \"Loading preview...\"\nend\n\nlocal function renderPreview(record, item)\n\tlocal id = item and item.id or nil\n\tlocal image = itemThumbnail(item)\n\tif record.previewId == id and record.card.Thumbnail.Image == image and (image ~= \"\" or record.previewModel or not item) then return end\n\tclearModelPreview(record)\n\trecord.previewId = id\n\trecord.previewToken = (record.previewToken or 0) + 1\n\tlocal token = record.previewToken\n\trecord.thumbnailTimedOut = false\n\tlocal modelReady = item and image == \"\" and buildModelPreview(record, item) or false\n\trecord.card.Preview.Visible = modelReady\n\trecord.card.Thumbnail.Image = image\n\trecord.card.Thumbnail.Visible = item ~= nil and not modelReady\n\trefreshThumbnail(record)\n\tif item and image ~= \"\" and not record.card.Thumbnail.IsLoaded then\n\t\ttask.delay(8, function()\n\t\t\tif alive and record.previewToken == token and record.card.Parent and record.card.Thumbnail.Image == image then\n\t\t\t\trecord.thumbnailTimedOut = true\n\t\t\t\trefreshThumbnail(record)\n\t\t\tend\n\t\tend)\n\tend\nend\n\nlocal function requirement(item, unlock)\n\tlocal rule = item.unlock or { kind = \"Coins\", amount = item.price or 0 }\n\tif rule.kind == \"Starter\" then return \"Starter reward\", \"FREE\" end\n\tif rule.kind == \"VIP\" then return \"Included with VIP\", \"VIP EXCLUSIVE\" end\n\tif rule.kind == \"BetaTester\" then return \"Beta Tester reward\", \"BETA TESTER\" end\n\tif rule.kind == \"Coins\" then return tostring(item.price or rule.amount or 0) .. \" coins\", item.category end\n\tlocal progress = unlock and unlock.progress or 0\n\tlocal target = rule.amount or 0\n\tif rule.kind == \"Level\" then return \"Level \" .. tostring(target), tostring(math.min(progress, target)) .. \" / \" .. tostring(target) end\n\treturn tostring(target) .. \" \" .. (gameLabels[rule.gameId] or \"total\") .. \" wins\", tostring(math.min(progress, target)) .. \" / \" .. tostring(target)\nend\n\n\nreturn {render=renderPreview,clear=clearModelPreview,frame=frameModelPreview,requirement=requirement}"
local original=game.StarterGui.PlaygroundShell.Controller
module.Sandboxed=original.Sandboxed module.Capabilities=original.Capabilities
module.Parent=game.ServerStorage
local holder=Instance.new("ScreenGui")
holder.Name="VIPShopTest"
holder.Parent=game.StarterGui
local ok,result=pcall(function()
 local test=require(module)
 local count=0 local function check(v,m) assert(v,m) count+=1 end
 local price,label=test.requirement({unlock={kind="VIP",amount=0}})
 check(price=="Included with VIP" and label=="VIP EXCLUSIVE","VIP labeled as wins")
 price,label=test.requirement({unlock={kind="BetaTester",amount=0}})
 check(price=="Beta Tester reward" and label=="BETA TESTER","Beta label wrong")
 local template=game.ReplicatedStorage.PlaygroundCosmeticAssets:FindFirstChild("P36")
 check(template~=nil,"P36 missing")
 local card=game.StarterGui.PlaygroundShell.ShopPanel.Cards.Slot01:Clone()
 card.Parent=holder
 local record={card=card}
 test.render(record,{id="P36",slot="Pet",category="Pets",thumbnail=""})
 check(record.previewModel~=nil and card.Preview.Visible,"P36 model preview failed")
 check(not card.Thumbnail.Visible and not card.ThumbnailStatus.Visible,"Empty-thumbnail message covers model")
 check(card.Preview.CurrentCamera==record.previewCamera,"Camera missing")
 local bones=0
 for _,x in ipairs(record.previewModel:GetDescendants()) do
  if x:IsA("Bone") then bones+=1 end
  check(not x:IsA("BaseScript") and not x:IsA("ObjectValue"),"Unsafe preview content")
 end
 check(bones>=14,"Rig bones lost")
 local first=record.previewModel
 test.render(record,{id="P36",slot="Pet",category="Pets",thumbnail=""})
 check(record.previewModel==first,"Preview rebuilt unnecessarily")
 test.render(record,{id="Other",slot="Pet",thumbnail="rbxassetid://123"})
 check(record.previewModel==nil and card.Thumbnail.Visible and not card.Preview.Visible,"PNG preference regressed")
 check(first.Parent==nil,"Old preview leaked")
 test.render(record,nil)
 check(not card.Thumbnail.Visible and not card.Preview.Visible,"Empty slot remained visible")
 return {checks=count,bones=bones,preview="Native skinned model",labels="VIP/Beta explicit"}
end)
holder:Destroy()
module:Destroy()
assert(ok,result)
return result

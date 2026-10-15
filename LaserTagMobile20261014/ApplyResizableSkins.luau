local m=game.StarterGui.MudHUD.Main
local function skin(image,id,key,scale)
 image.Image=id image:SetAttribute("DefaultImage",id) image:SetAttribute("AssetKey",key)
 image.ScaleType=Enum.ScaleType.Slice image.SliceCenter=Rect.new(88,88,424,232) image.SliceScale=scale
end
for _,header in {m.Top,m.CompactTop,m.PortraitTop} do
 skin(header.ReusableSkin,"rbxassetid://80217215544210","PNG/07-Resizable-Skins/cream-normal.png",0.15)
 header:SetAttribute("UISkinAssetKey","PNG/07-Resizable-Skins/cream-normal.png")
 header.Lives.ZIndex=8
end
skin(m.MobileSprint.ReusableSkin,"https://www.roblox.com/asset/?id=90528629970043&version=1","PNG/07-Resizable-Skins/blue-normal.png",0.15)
m.MobileSprint:SetAttribute("UISkinAssetKey","PNG/07-Resizable-Skins/blue-normal.png")
return true

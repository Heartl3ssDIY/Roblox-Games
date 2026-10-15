local b=script.Parent
local caption=b.EquipCaption
for _,property in {"Text","FontFace","TextSize","TextColor3","TextStrokeColor3","TextStrokeTransparency","TextScaled","TextWrapped"} do
 local function sync() caption[property]=b[property] end
 b:GetPropertyChangedSignal(property):Connect(sync)
 sync()
end
b.TextTransparency=1
task.spawn(function() pcall(function() game:GetService("ContentProvider"):PreloadAsync({b.EquipArtwork}) end) end)


local selected=game:GetService("Selection"):Get()
local settings={
 ["ParcelSmall_Body"]={185,141,87,"SmoothPlastic","Body",true},
 ["ParcelSmall_TopFlaps"]={202,159,104,"SmoothPlastic","TopFlaps",true},
 ["ParcelSmall_PackingTape"]={217,182,118,"SmoothPlastic","PackingTape",false},
 ["ParcelSmall_TapeJoin"]={171,135,79,"SmoothPlastic","TapeJoin",false},
 ["ParcelSmall_ShippingLabels"]={243,239,225,"SmoothPlastic","ShippingLabels",false},
 ["ParcelSmall_ShippingInk"]={54,46,36,"SmoothPlastic","ShippingInk",false},
 ["ParcelSmall_HandlingMarks"]={54,46,36,"SmoothPlastic","HandlingMarks",false},
 ["ParcelMedium_Body"]={185,141,87,"SmoothPlastic","Body",true},
 ["ParcelMedium_TopFlaps"]={202,159,104,"SmoothPlastic","TopFlaps",true},
 ["ParcelMedium_PackingTape"]={217,182,118,"SmoothPlastic","PackingTape",false},
 ["ParcelMedium_TapeJoin"]={171,135,79,"SmoothPlastic","TapeJoin",false},
 ["ParcelMedium_ShippingLabels"]={243,239,225,"SmoothPlastic","ShippingLabels",false},
 ["ParcelMedium_ShippingInk"]={54,46,36,"SmoothPlastic","ShippingInk",false},
 ["ParcelMedium_HandlingMarks"]={54,46,36,"SmoothPlastic","HandlingMarks",false},
 ["ParcelLarge_Body"]={185,141,87,"SmoothPlastic","Body",true},
 ["ParcelLarge_TopFlaps"]={202,159,104,"SmoothPlastic","TopFlaps",true},
 ["ParcelLarge_PackingTape"]={217,182,118,"SmoothPlastic","PackingTape",false},
 ["ParcelLarge_TapeJoin"]={171,135,79,"SmoothPlastic","TapeJoin",false},
 ["ParcelLarge_ShippingLabels"]={243,239,225,"SmoothPlastic","ShippingLabels",false},
 ["ParcelLarge_ShippingInk"]={54,46,36,"SmoothPlastic","ShippingInk",false},
 ["ParcelLarge_HandlingMarks"]={54,46,36,"SmoothPlastic","HandlingMarks",false},
 ["ParcelFragile_Body"]={185,141,87,"SmoothPlastic","Body",true},
 ["ParcelFragile_TopFlaps"]={202,159,104,"SmoothPlastic","TopFlaps",true},
 ["ParcelFragile_PackingTape"]={217,182,118,"SmoothPlastic","PackingTape",false},
 ["ParcelFragile_TapeJoin"]={171,135,79,"SmoothPlastic","TapeJoin",false},
 ["ParcelFragile_ShippingLabels"]={243,239,225,"SmoothPlastic","ShippingLabels",false},
 ["ParcelFragile_ShippingInk"]={54,46,36,"SmoothPlastic","ShippingInk",false},
 ["ParcelFragile_HandlingMarks"]={54,46,36,"SmoothPlastic","HandlingMarks",false},
 ["ParcelFragile_FragileSticker"]={215,48,41,"SmoothPlastic","FragileSticker",false},
 ["ParcelFragile_FragilePrint"]={250,243,226,"SmoothPlastic","FragilePrint",false},
 ["ParcelFragile_Outline"]={215,48,41,"SmoothPlastic","Outline",false},
 ["ParcelGold_Body"]={224,162,43,"Metal","Body",true},
 ["ParcelGold_TopFlaps"]={242,193,71,"Metal","TopFlaps",true},
 ["ParcelGold_PackingTape"]={217,182,118,"SmoothPlastic","PackingTape",false},
 ["ParcelGold_TapeJoin"]={171,135,79,"SmoothPlastic","TapeJoin",false},
 ["ParcelGold_ShippingLabels"]={243,239,225,"SmoothPlastic","ShippingLabels",false},
 ["ParcelGold_ShippingInk"]={54,46,36,"SmoothPlastic","ShippingInk",false},
 ["ParcelGold_HandlingMarks"]={54,46,36,"SmoothPlastic","HandlingMarks",false},
 ["ParcelGold_GlowBorder"]={255,194,34,"Neon","GlowBorder",false},
 ["ParcelRainbow_Body"]={168,99,214,"Metal","Body",true},
 ["ParcelRainbow_TopFlaps"]={196,135,232,"Metal","TopFlaps",true},
 ["ParcelRainbow_PackingTape"]={217,182,118,"SmoothPlastic","PackingTape",false},
 ["ParcelRainbow_TapeJoin"]={171,135,79,"SmoothPlastic","TapeJoin",false},
 ["ParcelRainbow_ShippingLabels"]={243,239,225,"SmoothPlastic","ShippingLabels",false},
 ["ParcelRainbow_ShippingInk"]={54,46,36,"SmoothPlastic","ShippingInk",false},
 ["ParcelRainbow_HandlingMarks"]={54,46,36,"SmoothPlastic","HandlingMarks",false},
 ["ParcelRainbow_GlowBorder"]={255,62,86,"Neon","GlowBorder",false},
 ["ParcelRainbow_GlowBorder.001"]={255,157,48,"Neon","GlowBorder",false},
 ["ParcelRainbow_GlowBorder.002"]={251,233,66,"Neon","GlowBorder",false},
 ["ParcelRainbow_GlowBorder.003"]={78,227,137,"Neon","GlowBorder",false},
 ["ParcelRainbow_GlowBorder.004"]={51,183,255,"Neon","GlowBorder",false},
 ["ParcelRainbow_GlowBorder.005"]={196,84,253,"Neon","GlowBorder",false},
}
for _,model in selected do
 if not model:IsA("Model") then continue end
 local body
 for _,p in model:GetDescendants() do
  local s=settings[p.Name]
  if p:IsA("MeshPart") and s and s[5]=="Body" then body=p break end
 end
 if not body then continue end
 game:GetService("ChangeHistoryService"):SetWaypoint("Before parcel setup")
 model.PrimaryPart=body
 for _,p in model:GetDescendants() do
  local s=settings[p.Name]
  if not (p:IsA("MeshPart") and s) then continue end
  local textured=s[6] and (p.TextureID~="" or p:FindFirstChildOfClass("SurfaceAppearance"))
  p.Color=textured and Color3.new(1,1,1) or Color3.fromRGB(s[1],s[2],s[3]);p.Material=Enum.Material[s[4]]
  p.Reflectance=s[4]=="Metal" and 0.035 or 0
  if not s[6] then p.TextureID="" end
  p.CanCollide=p==body;p.CanQuery=p==body;p.CanTouch=p==body
  p.Massless=p~=body;p.Anchored=p==body
  if p==body then
   p.CollisionFidelity=Enum.CollisionFidelity.Box
   p.CustomPhysicalProperties=PhysicalProperties.new(0.55,0.65,0.12,100,100)
  else
   local motor=p:FindFirstChild("ParcelJoint") or Instance.new("Motor6D")
   motor.Name="ParcelJoint";motor.Part0=body;motor.Part1=p
   motor.C0=body.CFrame:ToObjectSpace(p.CFrame);motor.Parent=p
  end
 end
 model:SetAttribute("PhysicsReady",true)
 game:GetService("ChangeHistoryService"):SetWaypoint("Parcel setup complete")
end
print("Parcel assemblies prepared. Unanchor the Body when releasing a box into physics.")

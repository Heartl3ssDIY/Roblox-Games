local selection=game:GetService("Selection"):Get()
local colours={
 ["Dell_Body"]={47,51,57},
 ["Dell_Deck"]={62,66,72},
 ["Dell_Feet"]={29,30,32},
 ["Dell_KeyboardWell"]={8,10,13},
 ["Dell_Keycaps"]={29,31,35},
 ["Dell_KeyLegends"]={204,208,214},
 ["Dell_TrackpadSeam"]={8,10,13},
 ["Dell_Trackpad"]={62,66,72},
 ["Dell_TrackpadSeam.001"]={62,66,73},
 ["Dell_SpeakerGrilles"]={8,10,13},
 ["Dell_Ports"]={8,10,13},
 ["Dell_PortContacts"]={186,193,203},
 ["Dell_CoolingVents"]={8,10,13},
 ["Dell_Hinges"]={62,66,73},
 ["Dell_Lid"]={47,51,57},
 ["Dell_Bezel"]={8,10,13},
 ["Dell_Screen"]={0,0,0},
 ["Dell_Webcam"]={62,66,73},
 ["Dell_WebcamLens"]={8,10,13},
 ["Dell_WebcamLens.001"]={62,66,73},
 ["Dell_FrontBrand"]={186,193,203},
 ["Dell_LidLogo"]={186,193,203},
 ["Dell_Badge"]={37,125,207},
 ["Dell_BadgeLegend"]={204,208,214},
 ["HP_Body"]={155,165,175},
 ["HP_Deck"]={185,194,201},
 ["HP_Feet"]={29,30,32},
 ["HP_KeyboardWell"]={8,10,13},
 ["HP_Keycaps"]={29,31,35},
 ["HP_KeyLegends"]={204,208,214},
 ["HP_TrackpadSeam"]={62,66,73},
 ["HP_Trackpad"]={185,194,201},
 ["HP_SpeakerGrilles"]={8,10,13},
 ["HP_Ports"]={8,10,13},
 ["HP_PortContacts"]={186,193,203},
 ["HP_CoolingVents"]={8,10,13},
 ["HP_Hinges"]={62,66,73},
 ["HP_Lid"]={155,165,175},
 ["HP_Bezel"]={8,10,13},
 ["HP_Screen"]={0,0,0},
 ["HP_Webcam"]={62,66,73},
 ["HP_WebcamLens"]={8,10,13},
 ["HP_WebcamLens.001"]={62,66,73},
 ["HP_FrontBrand"]={186,193,203},
 ["HP_LidLogo"]={186,193,203},
 ["MacBook_Body"]={190,194,199},
 ["MacBook_Deck"]={211,215,220},
 ["MacBook_Feet"]={29,30,32},
 ["MacBook_KeyboardWell"]={8,10,13},
 ["MacBook_Keycaps"]={29,31,35},
 ["MacBook_KeyLegends"]={204,208,214},
 ["MacBook_TrackpadSeam"]={62,66,73},
 ["MacBook_Trackpad"]={211,215,220},
 ["MacBook_SpeakerGrilles"]={62,66,73},
 ["MacBook_Ports"]={8,10,13},
 ["MacBook_PortContacts"]={186,193,203},
 ["MacBook_CoolingVents"]={8,10,13},
 ["MacBook_Hinges"]={62,66,73},
 ["MacBook_Lid"]={190,194,199},
 ["MacBook_Bezel"]={8,10,13},
 ["MacBook_Screen"]={0,0,0},
 ["MacBook_CameraHousing"]={8,10,13},
 ["MacBook_Webcam"]={62,66,73},
 ["MacBook_WebcamLens"]={8,10,13},
 ["MacBook_WebcamLens.001"]={62,66,73},
 ["MacBook_LidLogo"]={62,66,73},
 ["MacBook_OpeningNotch"]={62,66,73},
}
local parts={}
for _,model in selection do
 for _,part in model:GetDescendants() do
  if part:IsA("MeshPart") and colours[part.Name] then parts[part]=colours[part.Name] end
 end
end
assert(next(parts),"Select an imported Dell, HP or MacBook model")
game:GetService("ChangeHistoryService"):SetWaypoint("Before laptop colours")
local count=0
for part,rgb in parts do
 part.Color=Color3.fromRGB(table.unpack(rgb))
 part.Material=Enum.Material.SmoothPlastic
 part.Reflectance=0
 part.TextureID=""
 part.Anchored=true
 part.CanCollide=false
 part.CanQuery=false
 count+=1
end
game:GetService("ChangeHistoryService"):SetWaypoint("Laptop colours applied")
print("Recoloured "..count.." laptop parts")

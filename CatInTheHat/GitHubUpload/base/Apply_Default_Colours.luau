-- Select the imported Cat model, then run this in the Studio Command Bar.
-- Restores the default solid colours. Edit the RGB values to recolour it.
local selected = game:GetService("Selection"):Get()
assert(#selected == 1 and selected[1]:IsA("Model"), "Select the imported Cat model first")
local model = selected[1]
local colors = {
    ["Body_BlackFur"] = Color3.fromRGB(22, 25, 30),
    ["Body_WhiteBib"] = Color3.fromRGB(236, 234, 225),
    ["LeftEar_Inner"] = Color3.fromRGB(124, 115, 115),
    ["RightEar_Inner"] = Color3.fromRGB(124, 115, 115),
    ["LeftEye_Socket"] = Color3.fromRGB(124, 115, 115),
    ["LeftEye_White"] = Color3.fromRGB(243, 237, 223),
    ["LeftEye_Iris"] = Color3.fromRGB(118, 82, 44),
    ["LeftEye_Pupil"] = Color3.fromRGB(20, 22, 25),
    ["LeftEye_Catchlight"] = Color3.fromRGB(247, 245, 237),
    ["LeftEye_UpperLid"] = Color3.fromRGB(236, 234, 225),
    ["LeftEye_LowerLid"] = Color3.fromRGB(236, 234, 225),
    ["LeftEyebrow"] = Color3.fromRGB(22, 25, 30),
    ["RightEye_Socket"] = Color3.fromRGB(124, 115, 115),
    ["RightEye_White"] = Color3.fromRGB(243, 237, 223),
    ["RightEye_Iris"] = Color3.fromRGB(118, 82, 44),
    ["RightEye_Pupil"] = Color3.fromRGB(20, 22, 25),
    ["RightEye_Catchlight"] = Color3.fromRGB(247, 245, 237),
    ["RightEye_UpperLid"] = Color3.fromRGB(236, 234, 225),
    ["RightEye_LowerLid"] = Color3.fromRGB(236, 234, 225),
    ["RightEyebrow"] = Color3.fromRGB(22, 25, 30),
    ["Nose_Rose"] = Color3.fromRGB(142, 68, 69),
    ["LeftNostril"] = Color3.fromRGB(62, 20, 29),
    ["RightNostril"] = Color3.fromRGB(62, 20, 29),
    ["Muzzle_CenterLine"] = Color3.fromRGB(142, 68, 69),
    ["Smile_Opening"] = Color3.fromRGB(62, 20, 29),
    ["Smile_UpperTeeth"] = Color3.fromRGB(239, 235, 223),
    ["Smile_LowerLip"] = Color3.fromRGB(236, 234, 225),
    ["LeftWhiskerRoot_0"] = Color3.fromRGB(124, 115, 115),
    ["LeftWhiskers"] = Color3.fromRGB(124, 115, 115),
    ["LeftWhiskerRoot_1"] = Color3.fromRGB(124, 115, 115),
    ["LeftWhiskerRoot_2"] = Color3.fromRGB(124, 115, 115),
    ["RightWhiskerRoot_0"] = Color3.fromRGB(124, 115, 115),
    ["RightWhiskers"] = Color3.fromRGB(124, 115, 115),
    ["RightWhiskerRoot_1"] = Color3.fromRGB(124, 115, 115),
    ["RightWhiskerRoot_2"] = Color3.fromRGB(124, 115, 115),
    ["Head_BlackFur"] = Color3.fromRGB(22, 25, 30),
    ["Face_WhiteFur"] = Color3.fromRGB(236, 234, 225),
    ["Hat_Band_1_Red"] = Color3.fromRGB(153, 8, 22),
    ["Hat_Band_2_White"] = Color3.fromRGB(247, 243, 231),
    ["Hat_Band_3_Red"] = Color3.fromRGB(153, 8, 22),
    ["Hat_Band_4_White"] = Color3.fromRGB(247, 243, 231),
    ["Hat_Band_5_Red"] = Color3.fromRGB(153, 8, 22),
    ["Hat_Brim_White"] = Color3.fromRGB(247, 243, 231),
    ["Hat_Brim_RolledEdge"] = Color3.fromRGB(247, 243, 231),
    ["Bow_LeftLoop"] = Color3.fromRGB(164, 10, 27),
    ["Bow_RightLoop"] = Color3.fromRGB(164, 10, 27),
    ["Bow_CenterKnot"] = Color3.fromRGB(164, 10, 27),
    ["Bow_LeftRibbon"] = Color3.fromRGB(164, 10, 27),
    ["Bow_RightRibbon"] = Color3.fromRGB(164, 10, 27),
    ["LeftGlove_Cuff"] = Color3.fromRGB(247, 245, 237),
    ["LeftGlove_Stitch_-1"] = Color3.fromRGB(214, 211, 202),
    ["LeftGlove_Stitch_0"] = Color3.fromRGB(214, 211, 202),
    ["LeftGlove_Stitch_1"] = Color3.fromRGB(214, 211, 202),
    ["RightGlove_Cuff"] = Color3.fromRGB(247, 245, 237),
    ["RightGlove_Stitch_-1"] = Color3.fromRGB(214, 211, 202),
    ["RightGlove_Stitch_0"] = Color3.fromRGB(214, 211, 202),
    ["RightGlove_Stitch_1"] = Color3.fromRGB(214, 211, 202),
    ["LeftGlove_White"] = Color3.fromRGB(247, 245, 237),
    ["RightGlove_White"] = Color3.fromRGB(247, 245, 237),
    ["Tail_Black"] = Color3.fromRGB(22, 25, 30),
    ["Tail_WhiteTip"] = Color3.fromRGB(236, 234, 225),
    ["Tail_WhiteTufts"] = Color3.fromRGB(236, 234, 225),
}
for _, part in model:GetDescendants() do
    if part:IsA("MeshPart") and colors[part.Name] then
        part.Color = colors[part.Name]
        part.TextureID = ""
        local surface = part:FindFirstChildOfClass("SurfaceAppearance")
        if surface then surface.ColorMap = ""; surface.Color = Color3.new(1, 1, 1) end
    end
end
print("Applied Cat palette to", model:GetFullName())

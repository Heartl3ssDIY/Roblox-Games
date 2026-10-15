-- Does not set attributes, geometry, fonts, text sizes, images, or button bounds.
-- Text objects: TextStrokeTransparency=1. Reuses one contextual TextOutline UIStroke
-- and removes duplicate contextual strokes; border strokes are retained.
-- TextOutline: Name, ApplyStrokeMode, LineJoinMode, StrokeSizingMode, Thickness,
-- Transparency, Color and Enabled. Color comes from the existing TextStrokeColor3.
-- Continue border strokes: Thickness=2, Transparency=.08, LineJoinMode=Round.
-- Templates.Card.Edge: Thickness=1.2, Transparency=.20, LineJoinMode=Round.
-- ViewportFrames: Ambient=(165,174,191), LightColor=(255,247,235).

local function textSize(object)
    if object.TextScaled then
        local limit = object:FindFirstChildOfClass("UITextSizeConstraint")
        if limit then return limit.MaxTextSize end
    end
    return object.TextSize
end

local function textStyle(object)
    local size = textSize(object)
    if size <= 17 then return 0.75, 0.30 end
    if object.Name == "Header" or object.Name == "Title" or object.Name == "UnitName"
        or object.Name == "Question" or object.Name == "Fallback" then
        return 1.5, 0.12
    end
    return 1, 0.20
end

local function softenBorder(button, report)
    if not button then return end
    for _, child in ipairs(button:GetChildren()) do
        if child:IsA("UIStroke") and child.ApplyStrokeMode == Enum.ApplyStrokeMode.Border then
            child.Thickness = 2
            child.Transparency = 0.08
            child.LineJoinMode = Enum.LineJoinMode.Round
            report.buttonBorders += 1
        end
    end
end

return function(gui)
    assert(typeof(gui) == "Instance" and gui:IsA("ScreenGui") and gui.Name == "PackRevealGui",
        "Expected the existing PackRevealGui ScreenGui")

    local report = { textOutlines = 0, buttonBorders = 0, cardEdges = 0, viewports = 0, removedDuplicates = 0 }
    local descendants = gui:GetDescendants()
    for _, object in ipairs(descendants) do
        if object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox") then
            local chosen
            for _, child in ipairs(object:GetChildren()) do
                if child:IsA("UIStroke") and child.Name == "TextOutline" then
                    chosen = child
                    break
                end
            end
            if not chosen then
                for _, child in ipairs(object:GetChildren()) do
                    if child:IsA("UIStroke") and child.ApplyStrokeMode == Enum.ApplyStrokeMode.Contextual then
                        chosen = child
                        break
                    end
                end
            end
            if not chosen then
                chosen = Instance.new("UIStroke")
                chosen.Parent = object
            end
            for _, child in ipairs(object:GetChildren()) do
                if child:IsA("UIStroke") and child ~= chosen
                    and child.ApplyStrokeMode == Enum.ApplyStrokeMode.Contextual then
                    child:Destroy()
                    report.removedDuplicates += 1
                end
            end
            local thickness, transparency = textStyle(object)
            chosen.Name = "TextOutline"
            chosen.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
            chosen.LineJoinMode = Enum.LineJoinMode.Round
            chosen.StrokeSizingMode = Enum.StrokeSizingMode.FixedSize
            chosen.Thickness = thickness
            chosen.Transparency = transparency
            chosen.Color = object.TextStrokeColor3
            chosen.Enabled = true
            object.TextStrokeTransparency = 1
            report.textOutlines += 1
        elseif object:IsA("ViewportFrame") then
            object.Ambient = Color3.fromRGB(165, 174, 191)
            object.LightColor = Color3.fromRGB(255, 247, 235)
            report.viewports += 1
        end
    end

    for _, name in ipairs({ "Landscape", "Portrait", "CompactLandscape" }) do
        local layout = gui:FindFirstChild(name)
        if layout then
            local rewards = layout:FindFirstChild("Rewards")
            local showcase = layout:FindFirstChild("Showcase")
            softenBorder(rewards and rewards:FindFirstChild("Continue"), report)
            softenBorder(showcase and showcase:FindFirstChild("Continue"), report)
        end
    end

    local templates = gui:FindFirstChild("Templates")
    local card = templates and templates:FindFirstChild("Card")
    local edge = card and card:FindFirstChild("Edge")
    if edge and edge:IsA("UIStroke") then
        edge.Thickness = 1.2
        edge.Transparency = 0.20
        edge.LineJoinMode = Enum.LineJoinMode.Round
        report.cardEdges += 1
    end
    return report
end

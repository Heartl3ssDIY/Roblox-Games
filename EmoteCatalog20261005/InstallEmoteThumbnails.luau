local function install(shell, backup)
	assert(not game:GetService("RunService"):IsRunning(), "Use Edit mode")
	local shop = shell:WaitForChild("ShopPanel")
	if backup then
		local storage = game:GetService("ServerStorage")
		if not storage:FindFirstChild("EmoteShopUIBackup20261005") then
			local folder = Instance.new("Folder")
			folder.Name = "EmoteShopUIBackup20261005"
			local copy = shop:Clone()
			copy.Parent = folder
			shell.Templates.ItemCard:Clone().Parent = folder
			folder.Parent = storage
		end
	end
	local cards = { shell.Templates.ItemCard }
	for _, card in ipairs(shop.Cards:GetChildren()) do
		if card:IsA("Frame") and card:FindFirstChild("Preview") and card:FindFirstChild("Action") then table.insert(cards, card) end
	end
	for _, card in ipairs(cards) do
		local preview = card.Preview
		local thumbnail = card:FindFirstChild("Thumbnail")
		if not thumbnail then
			thumbnail = Instance.new("ImageLabel")
			thumbnail.Name = "Thumbnail"
			thumbnail.AnchorPoint = preview.AnchorPoint
			thumbnail.Position = preview.Position
			thumbnail.Size = preview.Size
			thumbnail.Rotation = preview.Rotation
			thumbnail.ZIndex = preview.ZIndex
			thumbnail.BackgroundTransparency = 1
			thumbnail.BorderSizePixel = 0
			thumbnail.Image = ""
			thumbnail.ScaleType = Enum.ScaleType.Fit
			thumbnail.Visible = false
			thumbnail:SetAttribute("EmoteThumbnail", true)
			thumbnail.Parent = card
		end
		if not card:FindFirstChild("ThumbnailStatus") then
			local status = card.Category:Clone()
			status.Name = "ThumbnailStatus"
			status.AnchorPoint = preview.AnchorPoint
			status.Position = preview.Position
			status.Size = preview.Size
			status.Rotation = preview.Rotation
			status.ZIndex = preview.ZIndex + 1
			status.BackgroundTransparency = 1
			status.BorderSizePixel = 0
			status.Text = "Loading preview..."
			status.TextColor3 = Color3.fromRGB(255, 255, 248)
			status.TextStrokeTransparency = 1
			status.TextXAlignment = Enum.TextXAlignment.Center
			status.TextYAlignment = Enum.TextYAlignment.Center
			status.TextScaled = true
			status.TextWrapped = true
			status.Visible = false
			local limit = status:FindFirstChildOfClass("UITextSizeConstraint")
			if limit then limit.MinTextSize = 10 limit.MaxTextSize = 16 end
			local stroke = status:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
				stroke.Color = Color3.fromRGB(27, 45, 61)
				stroke.Thickness = 1.5
				stroke.Transparency = 0
			end
			status.Parent = card
		end
	end
	return { cards = #cards, thumbnails = #cards, templateIncluded = true }
end

return install(game:GetService("StarterGui"):WaitForChild("PlaygroundShell"), true)

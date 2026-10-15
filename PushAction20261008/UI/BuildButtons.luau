return function(starterGui)
	local tagPanel = assert(starterGui:FindFirstChild("TagHUD")).SprintPanel
	local bulldogPanel = assert(starterGui:FindFirstChild("BritishBulldogHUD")).MovementControls
	assert(not tagPanel:FindFirstChild("Push") and not bulldogPanel:FindFirstChild("Push"), "Push buttons already exist")
	local template = assert(starterGui:FindFirstChild("PlaygroundBatControls")).Swing
	local pushGui = assert(starterGui:FindFirstChild("PlaygroundPushControls"))
	local function make(parent, position, size)
		local button = template:Clone()
		button.Name = "Push"
		button:SetAttribute("MobileBatAction", nil)
		button:SetAttribute("PlaygroundPushAction", true)
		button.AnchorPoint = Vector2.zero
		button.Position = position
		button.Size = size
		button.ZIndex = 5
		button.Fallback.ZIndex = 5
		button.ReusableSkin.ZIndex = 6
		button.Caption.ZIndex = 7
		button.Hint.ZIndex = 7
		button.Caption.Text = "PUSH"
		button.Caption.UITextSizeConstraint.MaxTextSize = 21
		button.Hint.Text = "[Q]"
		button.Visible = false
		button.Active = false
		button.Interactable = false
		button.Selectable = false
		button.Parent = parent
		return button
	end
	local mobile = make(pushGui, UDim2.new(1, -140, 0.5, 0), UDim2.fromOffset(104, 68))
	mobile.Name = "MobilePush"
	mobile.AnchorPoint = Vector2.new(1, 0.5)
	mobile.Caption.UITextSizeConstraint.MaxTextSize = 23
	return {
		Tag = make(tagPanel, UDim2.fromOffset(186, 68), UDim2.fromOffset(94, 48)),
		Bulldog = make(bulldogPanel, UDim2.new(0.56, 0, 0, 60), UDim2.new(0.25, 0, 0, 48)),
		Mobile = mobile,
	}
end

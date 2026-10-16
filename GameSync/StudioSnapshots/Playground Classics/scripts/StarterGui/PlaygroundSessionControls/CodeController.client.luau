local ReplicatedStorage = game:GetService("ReplicatedStorage")
local gui = script.Parent
local dock = gui:WaitForChild("Dock")
local section = dock:WaitForChild("Body"):WaitForChild("Codes")
local input = section.Input.Value
local redeem = section.Redeem
local status = section.Status
local busy = false
local alive = true
local serial = 0
local worker
local connections = {}

local function connect(signal, callback)
	local connection = signal:Connect(callback)
	table.insert(connections, connection)
end

for _, fallback in ipairs(gui:GetDescendants()) do
	if fallback.Name == "ArtFallback" and fallback:IsA("Frame") then
		local skin = fallback.Parent:FindFirstChild("ReusableSkin")
		if skin and skin:IsA("ImageLabel") then
			local function updateFallback() fallback.Visible = not skin.IsLoaded end
			connect(skin:GetPropertyChangedSignal("IsLoaded"), updateFallback)
			connect(skin:GetPropertyChangedSignal("Image"), updateFallback)
			updateFallback()
		end
	end
end

local function buttonState()
	redeem.Active = not busy
	redeem.Interactable = not busy
	redeem.Selectable = not busy
	redeem.Label.Text = busy and "WAIT..." or "REDEEM"
	redeem.ReusableSkin.ImageTransparency = busy and 0.4 or 0
	input.TextEditable = not busy
end

local function submit()
	if busy or not alive or not gui.Enabled or not dock.Visible then return end
	local code = input.Text:match("^%s*(.-)%s*$") or ""
	if #code == 0 then status.Text = "Enter your reward code first." return end
	if #code > 32 or not code:match("^[%w_%-]+$") then
		status.Text = "Use up to 32 letters, numbers, - or _."
		return
	end
	local remote = ReplicatedStorage:FindFirstChild("PlaygroundShopRequest")
	if not remote or not remote:IsA("RemoteFunction") then status.Text = "Codes are getting ready. Try again." return end
	busy = true
	serial += 1
	local requestSerial = serial
	status.Text = "Checking your code..."
	buttonState()
	worker = task.spawn(function()
		local ok, response = pcall(remote.InvokeServer, remote, "RedeemCode", { code = code })
		if not alive or serial ~= requestSerial then return end
		worker = nil
		busy = false
		if ok and typeof(response) == "table" then
			status.Text = typeof(response.message) == "string" and response.message or "Please try again."
			if response.ok == true then input.Text = "" end
		else
			status.Text = "Could not check your code. Try again."
		end
		buttonState()
	end)
	task.delay(12, function()
		if not alive or not busy or serial ~= requestSerial then return end
		serial += 1
		busy = false
		if worker then pcall(task.cancel, worker) worker = nil end
		status.Text = "Still waiting for the server. Try again."
		buttonState()
	end)
end

connect(redeem.Activated, submit)
connect(input.FocusLost, function(enterPressed) if enterPressed then submit() end end)
connect(input:GetPropertyChangedSignal("Text"), function()
	if #input.Text > 64 then input.Text = input.Text:sub(1, 64) end
end)
connect(dock:GetPropertyChangedSignal("Visible"), function()
	if not dock.Visible then input:ReleaseFocus(false) end
end)
connect(script.Destroying, function()
	alive = false
	serial += 1
	if worker then pcall(task.cancel, worker) end
	for _, connection in ipairs(connections) do connection:Disconnect() end
end)
buttonState()

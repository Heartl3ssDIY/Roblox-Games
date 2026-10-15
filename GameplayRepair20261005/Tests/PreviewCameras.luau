local results={}
local function exercise(framePreview)
 local button=Instance.new("Frame")
 local viewport=Instance.new("ViewportFrame")
 viewport.Name="Preview" viewport.Parent=button
 viewport:SetAttribute("PreviewFieldOfView",32)
 local world=Instance.new("WorldModel") world.Parent=viewport
 local model=Instance.new("Model") model.Parent=world
 local record={button=button,card=button,model=model,radius=2}
 framePreview(record)
 local first=viewport:FindFirstChild("PreviewCamera")
 assert(first and first:IsA("Camera"),"missing local camera recreated")
 assert(first.FieldOfView==32,"authored FOV retained")
 assert(viewport.CurrentCamera==first,"viewport bound")
 assert(first.CFrame.Position.Magnitude>2,"model framed")
 framePreview(record)
 assert(viewport.CurrentCamera==first,"reuse existing camera")
 first:Destroy()
 framePreview(record)
 assert(viewport.CurrentCamera and viewport.CurrentCamera~=first,"deleted camera repaired")
 button:Destroy()
 return 6
end

do
local function framePreview(record)
	if not record.model or not record.model.Parent then return end
	local viewport = record.card.Preview
	local camera = viewport:FindFirstChild("PreviewCamera")
	if not camera or not camera:IsA("Camera") then
		camera = Instance.new("Camera")
		camera.Name = "PreviewCamera"
		camera.FieldOfView = viewport:GetAttribute("PreviewFieldOfView") or 35
		camera.Parent = viewport
	end
	local aspect = math.max(0.2, viewport.AbsoluteSize.X / math.max(1, viewport.AbsoluteSize.Y))
	local angle = math.rad(camera.FieldOfView * 0.5)
	local radius = record.radius
	local distance = radius / math.sin(math.min(angle, math.atan(math.tan(angle) * aspect))) * 1.12
	local direction = Vector3.new(0.5, 0.2, -1).Unit
	camera.CFrame = CFrame.lookAt(direction * distance, Vector3.zero)
	viewport.CurrentCamera = camera
end
results[1]=exercise(framePreview)
end

do
local function framePreview(record)
	if not record.model or not record.model.Parent then return end
	local viewport = record.button.Preview
	local camera = viewport:FindFirstChild("PreviewCamera")
	if not camera or not camera:IsA("Camera") then
		camera = Instance.new("Camera")
		camera.Name = "PreviewCamera"
		camera.FieldOfView = viewport:GetAttribute("PreviewFieldOfView") or 35
		camera.Parent = viewport
	end
	local aspect = math.max(0.2, viewport.AbsoluteSize.X / math.max(1, viewport.AbsoluteSize.Y))
	local angle = math.rad(camera.FieldOfView * 0.5)
	local distance = record.radius / math.sin(math.min(angle, math.atan(math.tan(angle) * aspect))) * 1.1
	camera.CFrame = CFrame.lookAt(Vector3.new(0.5, 0.2, -1).Unit * distance, Vector3.zero)
	viewport.CurrentCamera = camera
end
results[2]=exercise(framePreview)
end
return results

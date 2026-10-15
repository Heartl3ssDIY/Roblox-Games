-- The generated version embeds the asset manifest and both interaction scripts above this line.
local Selection = game:GetService("Selection")
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local manifest = HttpService:JSONDecode(MANIFEST_JSON)
local records = {}
for _, r in manifest do records[r.id] = r end
local selected = Selection:Get()
assert(#selected > 0, "Select the imported school model in Explorer first.")
local jobs, seen = {}, {}
for _, container in selected do
    assert(container:IsA("Model") or container:IsA("Folder"), "Select the whole imported Model, not one MeshPart.")
    assert(not container:GetAttribute("SchoolPrepared"), "This model has already been prepared.")
    local byAsset = {}
    for _, p in container:GetDescendants() do
        if p:IsA("BasePart") then
            local id = p.Name:match("^(SA%d%d)_")
            if id and records[id] then
                byAsset[id] = byAsset[id] or {}
                assert(not byAsset[id][p.Name], "Duplicate asset copies selected together. Prepare each imported copy separately.")
                byAsset[id][p.Name] = p
                assert(not seen[p], "Selection overlaps. Select only each top-level imported model.")
                seen[p] = true
            end
        end
    end
    for id, found in byAsset do
        local origin, xmark, ymark = found[id.."_REF_O"], found[id.."_REF_X"], found[id.."_REF_Y"]
        assert(origin and xmark and ymark, "Missing setup markers. Reimport with Merge Meshes OFF.")
        local x, y = xmark.Position - origin.Position, ymark.Position - origin.Position
        assert(x.Magnitude > .001 and y.Magnitude > .001, "Setup markers are too close together.")
        assert(math.abs(x.Magnitude/y.Magnitude - 1) < .02, "Use uniform scale on imported models.")
        for _, body in records[id].bodies do
            local count = 0
            for name in found do if name:match("^(SA%d%d_B%d%d)_M") == body.id then count += 1 end end
            assert(count > 0, "Missing imported body: "..body.label)
        end
        table.insert(jobs, {id=id, found=found, container=container, origin=origin, x=x.Unit, y=y.Unit, scale=x.Magnitude/.1})
    end
end
assert(#jobs > 0, "No school asset meshes found in the selection.")
game:GetService("ChangeHistoryService"):SetWaypoint("Before preparing school props")
local result = {}
for _, job in jobs do
    local record, found = records[job.id], job.found
    local frame = CFrame.fromMatrix(job.origin.Position, job.x, job.x:Cross(job.y).Unit, -job.y)
    local scale = job.scale
    local function localVector(v) return Vector3.new(v[1], v[3], -v[2]) end
    local function point(v) return frame:PointToWorldSpace(localVector(v)*scale) end
    local asset = Instance.new("Model");asset.Name = record.name;asset:SetAttribute("SchoolPrepared", true);asset.Parent = job.container
    local models, colliders = {}, {}
    for _, body in record.bodies do
        local model = Instance.new("Model");model.Name = body.label;model.Parent = asset
        local loose = body.label == "Pen" or body.label == "Pencil" or body.label == "Whiteboard marker" or body.label == "Whiteboard eraser" or body.asset == "Black pencil - pink eraser" or body.asset == "Black retractable pen"
        model:SetAttribute("BodyId", body.id);model:SetAttribute("InteractionKind", body.kind);model:SetAttribute("InitialAnchored", not loose)
        model:SetAttribute("OpenAngle", body.angle);models[body.id] = model;colliders[body.id] = {}
        for i, box in body.collision do
            local p = Instance.new("Part");p.Name = i == 1 and "PhysicsRoot" or "CollisionShape"
            p.Size = Vector3.new(math.max(.025,box.size[1]*scale),math.max(.025,box.size[3]*scale),math.max(.025,box.size[2]*scale))
            p.CFrame = CFrame.new(point(box.center))*frame.Rotation;p.Transparency = 1;p.Anchored = true
            p.CanCollide = true;p.CanTouch = false;p.CanQuery = false;p.CastShadow = false
            p.CustomPhysicalProperties = PhysicalProperties.new(.5, .5, .15, 1, 1)
            p:SetAttribute("SchoolCollider", true);p.Parent = model;table.insert(colliders[body.id],p)
            if i == 1 then model.PrimaryPart = p end
        end
        for name, p in found do
            if name:match("^(SA%d%d_B%d%d)_M") == body.id then
                p.Anchored = true;p.CanCollide = false;p.CanTouch = false;p.CanQuery = true;p.Massless = true;p.Parent = model
                p.Color = Color3.new(1,1,1)
                if p:IsA("MeshPart") then p.DoubleSided = true end
            end
        end
        local root = model.PrimaryPart
        for _, p in model:GetDescendants() do
            if p:IsA("BasePart") and p ~= root then
                local w = Instance.new("WeldConstraint");w.Name = "SchoolRigidWeld";w.Part0 = root;w.Part1 = p;w.Parent = root
                p.Anchored = false
            end
        end
        if body.kind == "pickup" or body.kind == "hinge" then
            local prompt = Instance.new("ProximityPrompt");prompt.Name = "SchoolInteractionPrompt"
            prompt.ObjectText = body.label;prompt.ActionText = body.kind == "pickup" and "Pick up" or "Open"
            prompt.KeyboardKeyCode = Enum.KeyCode.E;prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
            prompt.MaxActivationDistance = 8;prompt.HoldDuration = .15;prompt.RequiresLineOfSight = true;prompt.Parent = root
        end
    end
    for _, body in record.bodies do
        if body.kind == "hinge" then
            local model = models[body.id];local root = model.PrimaryPart;local base = models[job.id.."_B01"]
            assert(base and base.PrimaryPart, "Hinge base missing: "..body.label)
            local axis = frame:VectorToWorldSpace(localVector(body.axis)).Unit
            local other = math.abs(axis:Dot(Vector3.yAxis)) < .95 and Vector3.yAxis or Vector3.zAxis
            local secondary = (other - axis*other:Dot(axis)).Unit
            local world = CFrame.fromMatrix(point(body.pivot), axis, secondary, axis:Cross(secondary))
            local a0 = Instance.new("Attachment");a0.Name="SchoolHingeBase";a0.CFrame=base.PrimaryPart.CFrame:ToObjectSpace(world);a0.Parent=base.PrimaryPart
            local a1 = Instance.new("Attachment");a1.Name="SchoolHingeMoving";a1.CFrame=root.CFrame:ToObjectSpace(world);a1.Parent=root
            local h=Instance.new("HingeConstraint");h.Name="SchoolHinge";h.Attachment0=a0;h.Attachment1=a1;h.ActuatorType=Enum.ActuatorType.Servo
            h.AngularSpeed=2;h.ServoMaxTorque=10000;h.TargetAngle=0;h.LimitsEnabled=true;h.LowerAngle=math.min(0,body.angle);h.UpperAngle=math.max(0,body.angle);h.Parent=model
            root.Anchored=false
            for _, cp in colliders[body.id] do
                for _, bp in colliders[job.id.."_B01"] do
                    local nc=Instance.new("NoCollisionConstraint");nc.Part0=cp;nc.Part1=bp;nc.Parent=model
                end
            end
        end
    end
    for _, model in models do
        local kind=model:GetAttribute("InteractionKind")
        if kind=="pickup" or kind=="hinge" then CollectionService:AddTag(model,"SchoolInteractive") end
    end
    for name, p in found do if name:find("_REF_",1,true) then p:Destroy() end end
    job.container:SetAttribute("SchoolPrepared",true);table.insert(result,asset)
end
local rep=game:GetService("ReplicatedStorage")
if not rep:FindFirstChild("SchoolPropDrop") then local r=Instance.new("RemoteEvent");r.Name="SchoolPropDrop";r.Parent=rep end
local service=game:GetService("ServerScriptService")
if not service:FindFirstChild("SchoolInteraction") then local s=Instance.new("Script");s.Name="SchoolInteraction";s.Source=SERVER_SOURCE;s.Parent=service end
local starter=game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")
if not starter:FindFirstChild("SchoolInteraction") then local s=Instance.new("LocalScript");s.Name="SchoolInteraction";s.Source=CLIENT_SOURCE;s.Parent=starter end
Selection:Set(result)
game:GetService("ChangeHistoryService"):SetWaypoint("School props prepared")
print("Prepared "..#jobs.." school assets. Play: E/tap to pick up or open; Q/Drop to release.")

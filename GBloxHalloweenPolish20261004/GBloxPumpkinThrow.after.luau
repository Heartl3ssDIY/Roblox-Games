local Throw = {}

local function finite(value)
 return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function handFor(data)
 if not data or not data.character or not data.character.Parent or not data.root or not data.root.Parent
  or not data.root:IsDescendantOf(data.character) then return nil end
 for _, name in {"RightHand", "Right Arm"} do
  local hand = data.character:FindFirstChild(name)
  if hand and hand:IsA("BasePart") then return hand end
 end
 return nil
end

local function partsFor(model)
 if not model or not model.Parent then return nil end
 if model:IsA("BasePart") then return {model} end
 if not model:IsA("Model") then return nil end
 local parts = {}
 for _, object in model:GetDescendants() do
  if object:IsA("BasePart") then table.insert(parts, object) end
 end
 return #parts > 0 and parts or nil
end

local function currentFrame(state)
 return state.model:IsA("Model") and state.model:GetPivot() or state.model.CFrame
end

local function valid(state)
 local data = state.data
 return state.model.Parent and state.character.Parent and data.character == state.character
  and data.root == state.root and state.root.Parent and state.root:IsDescendantOf(state.character)
  and state.hand.Parent and state.hand:IsDescendantOf(state.character)
  and not data.recovering and (not data.status or data.status == "Running")
  and (not data.humanoid or data.humanoid.Health > 0)
end

function Throw.CanHold(data)
 return handFor(data) ~= nil
end

function Throw.Begin(model, data, now, holdSeconds)
 local hand = handFor(data)
 local parts = partsFor(model)
 if not hand or not parts or not finite(now) then return nil, "The pumpkin cannot be held yet." end
 holdSeconds = finite(holdSeconds) and math.clamp(holdSeconds, 0.15, 1) or 0.4
 local carrier = parts[1]
 local initialFrame = model:IsA("Model") and model:GetPivot() or model.CFrame
 for _, object in model:GetDescendants() do
  if object:IsA("JointInstance") or object:IsA("WeldConstraint") then object:Destroy() end
 end
 for _, part in parts do
  part.Anchored = true
  part.Massless = true
  part.CanCollide = false
  part.CanTouch = false
  part.CanQuery = false
  part.CastShadow = false
 end
 if model:IsA("Model") then
  carrier.PivotOffset = carrier.CFrame:ToObjectSpace(initialFrame)
  model.PrimaryPart = carrier
 else
  carrier.PivotOffset = CFrame.identity
 end
 local grip = hand:FindFirstChild("RightGripAttachment")
 local holdFrame = grip and grip:IsA("Attachment") and grip.WorldCFrame * CFrame.new(0, 0, -0.65)
  or hand.CFrame * CFrame.new(0, -hand.Size.Y * 0.5, -0.65)
 if model:IsA("Model") then model:PivotTo(holdFrame)
 else carrier.CFrame = holdFrame end
 local bodyWelds = {}
 for _, part in parts do
  if part ~= carrier then
   local weld = Instance.new("WeldConstraint")
   weld.Name = "PumpkinBodyWeld"
   weld.Part0 = carrier
   weld.Part1 = part
   weld.Parent = part
   table.insert(bodyWelds, weld)
  end
 end
 local holdWeld = Instance.new("Weld")
 holdWeld.Name = "PumpkinHandHold"
 holdWeld.Part0 = hand
 holdWeld.Part1 = carrier
 holdWeld.C0 = hand.CFrame:ToObjectSpace(carrier.CFrame)
 holdWeld.C1 = CFrame.identity
 holdWeld.Parent = carrier
 for _, part in parts do part.Anchored = false end
 return {
  model = model, data = data, character = data.character, root = data.root, hand = hand,
  parts = parts, holdWeld = holdWeld, bodyWelds = bodyWelds, baseC0 = holdWeld.C0,
  startedAt = now, releaseAt = now + holdSeconds, phase = "Holding", lastFrame = holdFrame,
 }
end

function Throw.Release(state)
 if not state or state.phase == "Cancelled" then return nil end
 if state.phase == "Released" then return state.lastFrame.Position end
 if state.model.Parent then state.lastFrame = currentFrame(state) end
 if state.holdWeld then state.holdWeld:Destroy() state.holdWeld = nil end
 for _, weld in state.bodyWelds do weld:Destroy() end
 state.bodyWelds = {}
 for _, part in state.parts do
  if part.Parent then part.Anchored = true end
 end
 if state.model.Parent then
  if state.model:IsA("Model") then state.model:PivotTo(state.lastFrame)
  else state.model.CFrame = state.lastFrame end
 end
 state.phase = "Released"
 return state.lastFrame.Position
end

function Throw.Clear(state)
 if not state or state.phase == "Cancelled" then return end
 Throw.Release(state)
 state.phase = "Cancelled"
end

function Throw.Update(state, now)
 if not state or state.phase == "Cancelled" then return "Cancelled", nil end
 if state.phase == "Released" then return "Released", state.lastFrame.Position end
 if not finite(now) or not valid(state) then
  Throw.Clear(state)
  return "Cancelled", nil
 end
 if now >= state.releaseAt then return "Released", Throw.Release(state) end
 local alpha = math.clamp((now - state.startedAt) / (state.releaseAt - state.startedAt), 0, 1)
 state.holdWeld.C0 = state.baseC0 * CFrame.new(0, 0, math.sin(alpha * math.pi) * 0.35)
 state.lastFrame = currentFrame(state)
 return "Holding", state.lastFrame.Position
end

return Throw

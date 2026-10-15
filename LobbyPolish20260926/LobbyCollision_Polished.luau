local Collision = {}
function Collision.apply(root)
 assert(root and root:IsA("Model"), "Lobby root is required")
 local visuals = root:FindFirstChild("Visuals")
 local colliders = root:FindFirstChild("Collision")
 assert(visuals and colliders, "Lobby Visuals and Collision folders are required")
 local visualCount, collisionCount = 0, 0
 for _, part in ipairs(visuals:GetDescendants()) do
  if part:IsA("BasePart") then
   part.Anchored = true
   part.CanCollide = false
   part.CanTouch = false
   part.CanQuery = false
   visualCount += 1
  end
 end
 for _, part in ipairs(colliders:GetDescendants()) do
  if part:IsA("BasePart") then
   part.Anchored = true
   part.CanCollide = part:GetAttribute("LobbyNoCollision") ~= true
   part.CanTouch = false
   part.CanQuery = part.CanCollide
   part.Transparency = 1
   collisionCount += 1
  end
 end
 return visualCount, collisionCount
end
return Collision
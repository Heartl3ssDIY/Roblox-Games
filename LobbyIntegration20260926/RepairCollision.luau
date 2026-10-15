local root = assert(workspace:FindFirstChild("Lobby_MainModeZone"), "Lobby missing")
local Collision = require(game.ReplicatedStorage:WaitForChild("LobbyCollision"))
local visual, solid = Collision.apply(root)
print(string.format("ACU lobby collision: %d decorative meshes, %d solid proxies", visual, solid))

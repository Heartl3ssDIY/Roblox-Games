local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("LobbyConfig"))
local Collision = require(ReplicatedStorage:WaitForChild("LobbyCollision"))
Collision.apply(workspace:WaitForChild(Config.RootName))

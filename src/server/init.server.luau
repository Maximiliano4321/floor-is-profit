local Players = game:GetService("Players")

-- Leave Roblox's normal spawn on. Turning it off leaves Play with no
-- character, and the camera stays frozen because it has nothing to follow.
Players.CharacterAutoLoads = true
Players.RespawnTime = 2.5

local Remotes = require(script:WaitForChild("Remotes"))
local Cash = require(script:WaitForChild("Cash"))
local Products = require(script:WaitForChild("Products"))
local Tower = require(script:WaitForChild("Tower"))
local RoundLoop = require(script:WaitForChild("RoundLoop"))
local DevCommands = require(script:WaitForChild("DevCommands"))

local remotes = Remotes.create()
Tower.prepareLighting()
-- Floors and the floor-1 spawn exist before we touch the player.
RoundLoop.start(remotes)

local function onPlayer(player: Player)
	Cash.setup(player)
	Products.setup(player)
	RoundLoop.onPlayer(player)
end

Players.PlayerAdded:Connect(onPlayer)
for _, player in Players:GetPlayers() do
	onPlayer(player)
end

Players.PlayerRemoving:Connect(function(player)
	RoundLoop.onPlayerRemoving(player)
	Cash.save(player)
	Cash.release(player)
end)

Cash.start()
local extrasOk, extrasErr = pcall(function()
	Products.bind(remotes)
	DevCommands.bind(remotes)
end)
if not extrasOk then
	warn("[Floor is Profit] Dev controls did not bind: ", extrasErr)
end

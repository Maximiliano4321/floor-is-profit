local Players = game:GetService("Players")

-- Stop the character from spawning into an empty world. The tower is built
-- before CharacterAutoLoads is turned back on.
Players.CharacterAutoLoads = false
Players.RespawnTime = 2.5

local Remotes = require(script:WaitForChild("Remotes"))
local Cash = require(script:WaitForChild("Cash"))
local Products = require(script:WaitForChild("Products"))
local Tower = require(script:WaitForChild("Tower"))
local RoundLoop = require(script:WaitForChild("RoundLoop"))
local DevCommands = require(script:WaitForChild("DevCommands"))

local remotes = Remotes.create()
Tower.prepareLighting()

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

-- Floors exist before chat, DataStore, or the round loop can fail.
RoundLoop.start(remotes)
Cash.start()
local extrasOk, extrasErr = pcall(function()
	Products.bind(remotes)
	DevCommands.bind(remotes)
end)
if not extrasOk then
	warn("[Floor is Profit] Dev controls did not bind: ", extrasErr)
end

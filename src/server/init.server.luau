local Players = game:GetService("Players")

local Remotes = require(script:WaitForChild("Remotes"))
local Cash = require(script:WaitForChild("Cash"))
local Products = require(script:WaitForChild("Products"))
local Tower = require(script:WaitForChild("Tower"))
local RoundLoop = require(script:WaitForChild("RoundLoop"))
local DevCommands = require(script:WaitForChild("DevCommands"))

Players.CharacterAutoLoads = true
Players.RespawnTime = 2.5

local remotes = Remotes.create()
Tower.prepareLighting()
Cash.start()
Products.bind(remotes)
DevCommands.bind(remotes)

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

RoundLoop.start(remotes)

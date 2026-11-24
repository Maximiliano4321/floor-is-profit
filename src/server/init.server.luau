local Players = game:GetService("Players")

-- Leave Roblox's normal spawn on. Turning it off leaves Play with no
-- character, and the camera stays frozen because it has nothing to follow.
Players.CharacterAutoLoads = true
Players.RespawnTime = 2.5

-- The gameplay builder parents its model only after modules load. These
-- eight parts are in Workspace first, around the spawn, so Play is never
-- an empty baseplate if that builder fails.
local function showStartupFloors()
	local center = Vector3.zero
	local spawn = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
	if spawn and spawn:IsA("BasePart") then
		center = Vector3.new(spawn.Position.X, 0, spawn.Position.Z)
	end
	local existing = workspace:FindFirstChild("Tower")
	if existing then
		existing:Destroy()
	end

	local colors = {
		Color3.fromRGB(255, 20, 40),
		Color3.fromRGB(255, 95, 0),
		Color3.fromRGB(255, 230, 0),
		Color3.fromRGB(20, 255, 70),
		Color3.fromRGB(0, 255, 230),
		Color3.fromRGB(30, 90, 255),
		Color3.fromRGB(200, 30, 255),
		Color3.fromRGB(255, 200, 0),
	}
	local tower = Instance.new("Model")
	tower.Name = "Tower"
	tower:SetAttribute("CenterX", center.X)
	tower:SetAttribute("CenterZ", center.Z)
	local size = Vector3.new(80, 1.5, 80)
	for index = 1, 8 do
		local top = 10 + (index - 1) * 9
		local part = Instance.new("Part")
		part.Name = "Floor" .. tostring(index)
		part.Anchored = true
		part.CanCollide = index == 1
		part.Material = Enum.Material.Neon
		part.Color = colors[index]
		part.Transparency = 0
		part.Size = size
		part.Position = Vector3.new(center.X, top - (size.Y / 2), center.Z)
		part.Parent = tower
	end
	tower.Parent = workspace
end

showStartupFloors()

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

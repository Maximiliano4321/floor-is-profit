-- Studio stubs. These are not Marketplace purchases.
-- Second Life: the next fall puts you back on the floor and keeps round cash.
-- 2x Next Floor: the next floor payout is doubled, then the charge is spent.
-- Survivor trail: a ribbon while you are alive this round.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Products = {}

local remotes = nil
local lastGrant: { [string]: number } = {}

local function toast(player: Player, message: string)
	if remotes then
		remotes.Toast:FireClient(player, message)
	end
end

local function clearTrail(character: Model)
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return
	end
	for _, name in { "SurvivorTrail", "SurvivorTrailA0", "SurvivorTrailA1" } do
		local child = hrp:FindFirstChild(name)
		if child then
			child:Destroy()
		end
	end
end

local function attachTrail(character: Model)
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp or not hrp:IsA("BasePart") then
		return
	end
	if hrp:FindFirstChild("SurvivorTrail") then
		return
	end

	local top = Instance.new("Attachment")
	top.Name = "SurvivorTrailA0"
	top.Position = Vector3.new(0, 1.1, 0)
	top.Parent = hrp

	local bottom = Instance.new("Attachment")
	bottom.Name = "SurvivorTrailA1"
	bottom.Position = Vector3.new(0, -2.6, 0)
	bottom.Parent = hrp

	local trail = Instance.new("Trail")
	trail.Name = "SurvivorTrail"
	trail.Attachment0 = top
	trail.Attachment1 = bottom
	trail.Lifetime = 1.05
	trail.MinLength = 0.05
	trail.FaceCamera = true
	trail.LightEmission = 0.85
	trail.LightInfluence = 0.15
	trail.Color = ColorSequence.new(Color3.fromRGB(255, 226, 110), Color3.fromRGB(255, 255, 255))
	trail.WidthScale = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(1, 0.15),
	})
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.Parent = hrp
end

function Products.bind(remoteBundle)
	remotes = remoteBundle
end

function Products.setup(player: Player)
	if player:GetAttribute("SecondLifeCharges") == nil then
		player:SetAttribute("SecondLifeCharges", 0)
	end
	if player:GetAttribute("DoubleNext") == nil then
		player:SetAttribute("DoubleNext", false)
	end
	if player:GetAttribute("TrailOn") == nil then
		player:SetAttribute("TrailOn", false)
	end
end

function Products.syncTrail(player: Player)
	local character = player.Character
	if not character then
		return
	end
	local show = player:GetAttribute("TrailOn") == true and player:GetAttribute("Alive") == true
	if show then
		attachTrail(character)
	else
		clearTrail(character)
	end
end

function Products.hasSecondLife(player: Player): boolean
	return (player:GetAttribute("SecondLifeCharges") or 0) > 0
end

function Products.consumeSecondLife(player: Player): boolean
	local charges = math.floor(player:GetAttribute("SecondLifeCharges") or 0)
	if charges <= 0 then
		return false
	end
	player:SetAttribute("SecondLifeCharges", charges - 1)
	return true
end

function Products.takeDouble(player: Player): boolean
	if player:GetAttribute("DoubleNext") ~= true then
		return false
	end
	player:SetAttribute("DoubleNext", false)
	return true
end

function Products.grant(player: Player, productId: string): (boolean, string)
	local key = tostring(player.UserId) .. ":" .. productId
	local now = os.clock()
	local previous = lastGrant[key]
	if previous and now - previous < 0.4 then
		return false, ""
	end
	lastGrant[key] = now

	local message: string
	local ok = true

	if productId == Config.Products.SecondLife then
		local charges = math.floor(player:GetAttribute("SecondLifeCharges") or 0)
		if charges >= Config.SecondLifeCap then
			ok = false
			message = "Second Life is full (" .. tostring(Config.SecondLifeCap) .. ")."
		else
			player:SetAttribute("SecondLifeCharges", charges + 1)
			message = "Second Life armed. Your next fall puts you back on the floor."
		end
	elseif productId == Config.Products.DoubleNext then
		if player:GetAttribute("DoubleNext") == true then
			ok = false
			message = "2x Next Floor is already armed."
		else
			player:SetAttribute("DoubleNext", true)
			message = "2x Next Floor armed. Your next payout is doubled."
		end
	elseif productId == Config.Products.SurvivorTrail then
		local enabled = player:GetAttribute("TrailOn") ~= true
		player:SetAttribute("TrailOn", enabled)
		Products.syncTrail(player)
		message = if enabled then "Survivor trail on." else "Survivor trail off."
	else
		ok = false
		message = "Unknown product."
	end

	if message ~= "" then
		toast(player, message)
		print(string.format("[Floor is Profit] %s %s — %s", player.Name, productId, message))
	end
	return ok, message
end

function Products.clearGrantHistory(player: Player)
	local prefix = tostring(player.UserId) .. ":"
	for key in lastGrant do
		if string.sub(key, 1, #prefix) == prefix then
			lastGrant[key] = nil
		end
	end
end

return Products

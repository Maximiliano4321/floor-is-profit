-- Lifetime cash lives on the leaderboard. Round cash is the amount a fall takes back.

local Cash = {}

local function cashValue(player: Player): IntValue
	local stats = player:FindFirstChild("leaderstats")
	if not stats then
		stats = Instance.new("Folder")
		stats.Name = "leaderstats"
		stats.Parent = player
	end

	local cash = stats:FindFirstChild("Cash")
	if not cash then
		cash = Instance.new("IntValue")
		cash.Name = "Cash"
		cash.Value = 0
		cash.Parent = stats
	end

	return cash :: IntValue
end

function Cash.setup(player: Player)
	cashValue(player)
	if player:GetAttribute("RoundCash") == nil then
		player:SetAttribute("RoundCash", 0)
	end
end

function Cash.addPayout(player: Player, amount: number)
	amount = math.floor(amount)
	if amount == 0 then
		return
	end
	local cash = cashValue(player)
	cash.Value += amount
	local roundCash = math.floor(player:GetAttribute("RoundCash") or 0) + amount
	player:SetAttribute("RoundCash", roundCash)
end

function Cash.addBonus(player: Player, amount: number)
	amount = math.floor(amount)
	if amount == 0 then
		return
	end
	local cash = cashValue(player)
	cash.Value += amount
end

-- Removes this round's payouts from lifetime cash. Previous rounds stay.
function Cash.loseRound(player: Player): number
	local roundCash = math.floor(player:GetAttribute("RoundCash") or 0)
	player:SetAttribute("RoundCash", 0)
	if roundCash <= 0 then
		return 0
	end
	local cash = cashValue(player)
	cash.Value = math.max(0, cash.Value - roundCash)
	return roundCash
end

function Cash.clearRound(player: Player)
	player:SetAttribute("RoundCash", 0)
end

return Cash

-- Lifetime cash lives on the leaderboard and in a DataStore.
-- Round cash is only an attribute. A fall removes that round from lifetime cash.
-- The number written to the store is the lifetime total after that removal.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Cash = {}

local STORE_NAME = "FloorIsProfitCash"
local KEY_PREFIX = "u"

type Session = {
	loaded: boolean,
	dirty: boolean,
}

local sessions: { [Player]: Session } = {}
local busy: { [Player]: boolean } = {}
local store: GlobalDataStore? = nil
local storeFailed = false
local warnedApi = false
local started = false

local function warnApi(err: any)
	if warnedApi then
		return
	end
	warnedApi = true
	warn("[Floor is Profit] DataStore did not save. In Studio, turn on Game Settings > Security > Enable Studio Access to API Services. Cash still works for this session. " .. tostring(err))
end

local function apiDisabled(err: any): boolean
	local text = string.lower(tostring(err))
	return string.find(text, "studio access", 1, true) ~= nil
		or string.find(text, "api services", 1, true) ~= nil
		or string.find(text, "403", 1, true) ~= nil
end

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

local function markDirty(player: Player)
	local session = sessions[player]
	if session then
		session.dirty = true
	end
end

local function getStore(): GlobalDataStore?
	if store or storeFailed then
		return store
	end
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok and result then
		store = result
		return store
	end
	if apiDisabled(result) then
		storeFailed = true
	end
	warnApi(result)
	return nil
end

local function keyFor(player: Player): string
	return KEY_PREFIX .. tostring(player.UserId)
end

local function writeAmount(player: Player, amount: number): boolean
	local dataStore = getStore()
	if not dataStore or player.UserId <= 0 then
		return false
	end
	for attempt = 1, 3 do
		local ok, err = pcall(function()
			dataStore:UpdateAsync(keyFor(player), function()
				return amount
			end)
		end)
		if ok then
			return true
		end
		if apiDisabled(err) then
			warnApi(err)
			return false
		end
		if attempt == 3 then
			warn("[Floor is Profit] Cash save failed for " .. player.Name .. ": " .. tostring(err))
		else
			task.wait(attempt)
		end
	end
	return false
end

function Cash.setup(player: Player)
	local cash = cashValue(player)
	cash.Value = 0
	player:SetAttribute("RoundCash", 0)
	sessions[player] = {
		loaded = false,
		dirty = false,
	}

	if player.UserId <= 0 then
		return
	end

	task.spawn(function()
		local dataStore = getStore()
		if not dataStore then
			return
		end
		local saved = 0
		local ok = false
		local err = nil
		for attempt = 1, 3 do
			ok, err = pcall(function()
				local value = dataStore:GetAsync(keyFor(player))
				if type(value) == "number" then
					saved = math.max(0, math.floor(value))
				end
			end)
			if ok or apiDisabled(err) then
				break
			end
			if attempt < 3 then
				task.wait(attempt)
			end
		end

		local session = sessions[player]
		if not session or player.Parent == nil then
			return
		end
		if not ok then
			warnApi(err)
			return
		end

		local earnedWhileLoading = math.max(0, cash.Value)
		cash.Value = saved + earnedWhileLoading
		session.loaded = true
		session.dirty = earnedWhileLoading > 0
	end)
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
	markDirty(player)
end

function Cash.addBonus(player: Player, amount: number)
	amount = math.floor(amount)
	if amount == 0 then
		return
	end
	local cash = cashValue(player)
	cash.Value += amount
	markDirty(player)
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
	markDirty(player)
	return roundCash
end

function Cash.clearRound(player: Player)
	player:SetAttribute("RoundCash", 0)
end

function Cash.save(player: Player): boolean
	while busy[player] do
		task.wait(0.1)
	end
	local session = sessions[player]
	if not session or not session.loaded or not session.dirty then
		return false
	end
	busy[player] = true
	local amount = math.max(0, math.floor(cashValue(player).Value))
	session.dirty = false
	local saved = writeAmount(player, amount)
	busy[player] = nil
	local current = sessions[player]
	if not saved then
		if current then
			current.dirty = true
		end
		return false
	end
	if current and current.dirty then
		task.spawn(function()
			Cash.save(player)
		end)
	end
	return true
end

function Cash.release(player: Player)
	sessions[player] = nil
	busy[player] = nil
end

function Cash.start()
	if started then
		return
	end
	started = true

	task.spawn(function()
		while true do
			task.wait(30)
			for _, player in Players:GetPlayers() do
				local session = sessions[player]
				if session and session.loaded and session.dirty then
					Cash.save(player)
				end
			end
		end
	end)

	game:BindToClose(function()
		local left = 0
		for _, player in Players:GetPlayers() do
			left += 1
			task.spawn(function()
				Cash.save(player)
				left -= 1
			end)
		end
		local deadline = os.clock() + (if RunService:IsStudio() then 3 else 20)
		while left > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

return Cash

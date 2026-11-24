-- Server-owned round. Pay the floor people are standing on, warn, drop it,
-- then move up. Falling removes only this round's cash. The top floor
-- splits the jackpot.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Cash = require(script.Parent:WaitForChild("Cash"))
local Products = require(script.Parent:WaitForChild("Products"))
local Tower = require(script.Parent:WaitForChild("Tower"))

local RoundLoop = {}

local remotes = nil
local started = false
local hooked: { [Player]: boolean } = {}
local desired: { [Player]: string } = {}
local busy: { [Player]: boolean } = {}

local state = {
	phase = "waiting",
	floor = 1,
	dropping = false,
	penalties = false,
	skip = false,
}

local lastSnapshot = nil
local towerNumber = 1
local towerStartedAt = 0

local function countAlive(): number
	local total = 0
	for _, player in Players:GetPlayers() do
		if player:GetAttribute("Alive") == true then
			total += 1
		end
	end
	return total
end

local function characterParts(player: Player): (Model?, Humanoid?, BasePart?)
	local character = player.Character
	if not character then
		return nil, nil, nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid:IsA("Humanoid") and hrp and hrp:IsA("BasePart") then
		return character, humanoid, hrp
	end
	return character, nil, nil
end

local function applyHumanoid(humanoid: Humanoid)
	humanoid.UseJumpPower = false
	humanoid.JumpHeight = Config.JumpHeight
	humanoid.WalkSpeed = Config.WalkSpeed
	humanoid.AutoJumpEnabled = false
	humanoid.JumpPower = math.sqrt(2 * workspace.Gravity * Config.JumpHeight)
end

local function footHeight(humanoid: Humanoid, hrp: BasePart): number
	local hip = humanoid.HipHeight
	if hip < 0.5 then
		hip = 2.5
	end
	return hrp.Position.Y - hip
end

local function broadcast(phase: string, floorIndex: number, duration: number, message: string)
	state.phase = phase
	local snapshot = {
		phase = phase,
		floor = floorIndex,
		floorCount = Config.FloorCount,
		endsAt = workspace:GetServerTimeNow() + duration,
		payout = Config.payoutFor(floorIndex, towerNumber),
		jackpot = Config.Jackpot,
		tower = towerNumber,
		startedAt = towerStartedAt,
		message = message,
		alive = countAlive(),
		color = Tower.colorOf(floorIndex),
	}
	lastSnapshot = snapshot
	if remotes then
		remotes.RoundState:FireAllClients(snapshot)
	end
end

local function sendSnapshot(player: Player)
	if remotes and lastSnapshot then
		remotes.RoundState:FireClient(player, lastSnapshot)
	end
end

local function toast(player: Player, message: string)
	if remotes then
		remotes.Toast:FireClient(player, message)
	end
end

local function cashPopup(player: Player, kind: string, amount: number)
	if remotes then
		remotes.CashEvent:FireClient(player, kind, amount)
	end
end

local function standCFrame(player: Player, floorIndex: number): CFrame
	local slot = player.UserId % 6
	local angle = (slot / 6) * math.pi * 2
	local top = Config.topY(floorIndex)
	local spot = Tower.getAnchor()
	return CFrame.new(spot.X + math.cos(angle) * 6, top + 4, spot.Z + math.sin(angle) * 6)
end

local function spectatorCFrame(): CFrame
	local spot = Tower.getAnchor()
	return CFrame.lookAt(spot + Vector3.new(78, 52, 0), spot + Vector3.new(0, 36, 0))
end

local function applyDesired(player: Player): boolean
	local what = desired[player]
	local character, humanoid, hrp = characterParts(player)
	if not what or not character or not humanoid or not hrp or humanoid.Health <= 0 then
		return false
	end

	applyHumanoid(humanoid)
	local cf = spectatorCFrame()
	local group = Config.Groups.Climber
	if what ~= "spectator" then
		local index = tonumber(string.match(what, "^floor:(%d+)$"))
		if not index then
			return false
		end
		cf = standCFrame(player, index)
	end

	hrp.AssemblyLinearVelocity = Vector3.zero
	hrp.AssemblyAngularVelocity = Vector3.zero
	character:PivotTo(cf)
	Tower.applyGroup(character, group)

	task.defer(function()
		if hrp.Parent and desired[player] == what and humanoid.Health > 0 then
			hrp.AssemblyLinearVelocity = Vector3.zero
			hrp.AssemblyAngularVelocity = Vector3.zero
			character:PivotTo(cf)
		end
	end)
	return true
end

local function placeOnFloor(player: Player, floorIndex: number): boolean
	desired[player] = "floor:" .. tostring(floorIndex)
	-- Do not call LoadCharacter here. Auto-load owns spawning. This only
	-- moves a character that already exists onto the floor.
	local character, humanoid = characterParts(player)
	if not character or not humanoid or humanoid.Health <= 0 then
		return false
	end
	return applyDesired(player)
end

local function placeSpectator(player: Player)
	desired[player] = "spectator"
	local _, humanoid = characterParts(player)
	if humanoid and humanoid.Health > 0 then
		applyDesired(player)
	end
end

local function safeFloor(): number
	if state.dropping then
		return math.clamp(state.floor + 1, 1, Config.FloorCount)
	end
	return math.clamp(state.floor, 1, Config.FloorCount)
end

local function eliminate(player: Player)
	if not state.penalties then
		return
	end
	if busy[player] or player:GetAttribute("Alive") ~= true then
		return
	end

	busy[player] = true
	local destination = safeFloor()
	if Products.hasSecondLife(player) then
		desired[player] = "floor:" .. tostring(destination)
		local saved = applyDesired(player)
		if saved then
			Products.consumeSecondLife(player)
			Products.syncTrail(player)
			busy[player] = nil
			toast(player, "Second Life! Back on the floor. Round cash kept.")
			print(string.format("[Floor is Profit] %s used Second Life on floor %d", player.Name, destination))
			return
		end
	end

	player:SetAttribute("Alive", false)
	player:SetAttribute("Eliminated", true)
	local lost = Cash.loseRound(player)
	Products.syncTrail(player)
	placeSpectator(player)

	cashPopup(player, "loss", lost)
	Tower.playFall(player)
	if lost > 0 then
		toast(player, "Lost " .. Config.formatCash(lost) .. " from this round. Lifetime cash stays on the leaderboard.")
	else
		toast(player, "You fell. You're out until the next tower. Lifetime cash stays.")
	end

	local _, humanoid = characterParts(player)
	if humanoid and humanoid.Health > 0 then
		humanoid.Health = 0
	end
	busy[player] = nil
	print(string.format("[Floor is Profit] %s fell (lost %d)", player.Name, lost))
end

local function onCharacter(player: Player, character: Model)
	task.defer(function()
		if character.Parent == nil then
			return
		end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid:IsA("Humanoid") then
			applyHumanoid(humanoid)
		end
		if not character:GetAttribute("FPGroupHooked") then
			character:SetAttribute("FPGroupHooked", true)
			character.DescendantAdded:Connect(function(descendant)
				if descendant:IsA("BasePart") then
					local group = character:GetAttribute("FPGroup")
					if type(group) == "string" then
						descendant.CollisionGroup = group
					end
				end
			end)
		end
		applyDesired(player)
		Products.syncTrail(player)
	end)
end

function RoundLoop.onPlayer(player: Player)
	if hooked[player] then
		return
	end
	hooked[player] = true
	player:SetAttribute("Alive", false)
	player:SetAttribute("Eliminated", false)
	desired[player] = if state.phase == "waiting" then "floor:1" else "spectator"

	player.CharacterAdded:Connect(function(character)
		onCharacter(player, character)
	end)
	if player.Character then
		onCharacter(player, player.Character)
	end
	sendSnapshot(player)
end

function RoundLoop.onPlayerRemoving(player: Player)
	hooked[player] = nil
	desired[player] = nil
	busy[player] = nil
	Products.clearGrantHistory(player)
end

function RoundLoop.requestSkip(): boolean
	if state.phase ~= "countdown" then
		return false
	end
	state.skip = true
	return true
end

local function hold(phase: string, floorIndex: number, duration: number, message: string): boolean
	broadcast(phase, floorIndex, duration, message)
	print(string.format("[Floor is Profit] %s floor %d (%.1fs) %s", phase, floorIndex, duration, message))
	local elapsed = 0
	while elapsed < duration - 0.001 do
		if phase == "countdown" and state.skip then
			state.skip = false
			return true
		end
		if state.penalties and countAlive() == 0 then
			return false
		end
		local step = math.min(0.1, duration - elapsed)
		task.wait(step)
		elapsed += step
	end
	return true
end

local function standingOn(player: Player, floorIndex: number): boolean
	local _, _, hrp = characterParts(player)
	if not hrp then
		return false
	end
	if not Tower.withinColumn(hrp.Position) then
		return false
	end
	local top = Config.topY(floorIndex)
	local y = hrp.Position.Y
	return y >= top + 0.5 and y < top + Config.FloorSpacing - 0.5
end

local function survived(player: Player, destination: number): boolean
	local _, _, hrp = characterParts(player)
	if not hrp then
		return false
	end
	if not Tower.withinColumn(hrp.Position) then
		return false
	end
	return hrp.Position.Y >= Config.topY(destination) + 0.5
end

local function payFloor(floorIndex: number)
	local payout = Config.payoutFor(floorIndex, towerNumber)
	if payout <= 0 then
		return
	end
	for _, player in Players:GetPlayers() do
		if player:GetAttribute("Alive") == true and standingOn(player, floorIndex) then
			local doubled = Products.takeDouble(player)
			local amount = payout * (if doubled then 2 else 1)
			Cash.addPayout(player, amount)
			cashPopup(player, if doubled then "double" else "pay", amount)
			print(string.format("[Floor is Profit] paid %s %d", player.Name, amount))
		end
	end
	Tower.celebratePay(floorIndex)
end

local function splitJackpot()
	local winners = {}
	for _, player in Players:GetPlayers() do
		if player:GetAttribute("Alive") == true and survived(player, Config.FloorCount) then
			table.insert(winners, player)
		end
	end
	if #winners == 0 then
		return false
	end

	local base = math.floor(Config.Jackpot / #winners)
	local extra = Config.Jackpot - (base * #winners)
	for index, player in winners do
		local share = base + (if index <= extra then 1 else 0)
		if share > 0 then
			Cash.addBonus(player, share)
			cashPopup(player, "jackpot", share)
			toast(player, "Jackpot " .. Config.formatCash(share) .. ". Lifetime cash keeps it.")
		end
	end
	Tower.playWin()
	print(string.format("[Floor is Profit] jackpot split among %d", #winners))
	return true
end

local function updatePassage()
	local destination = state.floor + 1
	if state.floor >= Config.FloorCount then
		destination = Config.FloorCount + 1
	end

	for _, player in Players:GetPlayers() do
		if player:GetAttribute("Alive") ~= true then
			continue
		end
		local character, humanoid, hrp = characterParts(player)
		if not character or not humanoid or not hrp then
			continue
		end

		local group = Config.Groups.Climber
		if destination <= Config.FloorCount then
			local feet = footHeight(humanoid, hrp)
			-- Switch only once the feet are clearly above the thin pad, so the
			-- body is not inside it when the pad becomes solid.
			if feet >= Config.topY(destination) + 0.6 then
				group = Config.Groups.Landed
			end
		end
		Tower.applyGroup(character, group)
	end
end

local function updateFalls()
	if not state.penalties then
		return
	end

	for _, player in Players:GetPlayers() do
		if state.phase == "countdown" and player:GetAttribute("Eliminated") ~= true and player:GetAttribute("Alive") ~= true then
			if not busy[player] then
				busy[player] = true
				task.spawn(function()
					local placed = placeOnFloor(player, state.floor)
					if placed and state.phase == "countdown" and player:GetAttribute("Eliminated") ~= true then
						player:SetAttribute("Alive", true)
						Products.syncTrail(player)
					end
					busy[player] = nil
				end)
			end
		end

		if player:GetAttribute("Alive") ~= true then
			continue
		end
		local _, humanoid, hrp = characterParts(player)
		if not humanoid or not hrp then
			continue
		end

		if hrp.Position.Y < Config.KillY then
			eliminate(player)
			continue
		end

		local floorTop = Config.topY(safeFloor())
		if not Tower.withinColumn(hrp.Position) and footHeight(humanoid, hrp) < floorTop - 2 then
			eliminate(player)
		end
	end
end

local function onKillTouch(hit: BasePart)
	local model = hit:FindFirstAncestorOfClass("Model")
	if not model then
		return
	end
	local player = Players:GetPlayerFromCharacter(model)
	if not player then
		return
	end
	local _, _, hrp = characterParts(player)
	if hrp and hrp.Position.Y > Config.KillY + 15 then
		return
	end
	if state.penalties then
		eliminate(player)
	end
end

local function settleOpening()
	local deadline = os.clock() + 8
	repeat
		local settled = false
		for _, player in Players:GetPlayers() do
			if player:GetAttribute("Eliminated") == true then
				continue
			end
			if player:GetAttribute("Alive") ~= true then
				if placeOnFloor(player, 1) then
					player:SetAttribute("Alive", true)
					Products.syncTrail(player)
				end
			end
			if player:GetAttribute("Alive") == true and standingOn(player, 1) then
				settled = true
			end
		end
		if settled or #Players:GetPlayers() == 0 then
			break
		end
		task.wait(0.1)
	until os.clock() >= deadline
end

local towerReady = false

local function runRound()
	state.skip = false
	state.dropping = false
	state.penalties = false
	state.floor = 1
	Tower.setTowerNumber(towerNumber)

	if towerReady then
		towerReady = false
	else
		Tower.build(onKillTouch)
	end

	while #Players:GetPlayers() == 0 do
		task.wait(0.5)
	end

	for _, player in Players:GetPlayers() do
		player:SetAttribute("Eliminated", false)
		player:SetAttribute("Alive", false)
		Cash.clearRound(player)
		desired[player] = "floor:1"
	end

	broadcast("waiting", 1, 8, "Stand here. This floor pays, then it falls.")
	settleOpening()

	if countAlive() == 0 then
		broadcast("waiting", 1, 2, "Waiting for a character.")
		task.wait(2)
		return
	end

	towerStartedAt = workspace:GetServerTimeNow()

	local reachedTop = false
	for floorIndex = 1, Config.FloorCount - 1 do
		if countAlive() == 0 then
			break
		end

		state.floor = floorIndex
		state.dropping = false
		Tower.setActive(floorIndex, "countdown")

		local countdown = Config.countdownFor(floorIndex)
		local payout = Config.payoutFor(floorIndex, towerNumber)
		local message = if floorIndex == 1
			then "Stand here. This floor pays, then it falls."
			else "This floor pays " .. Config.formatCash(payout) .. ", then it drops."

		state.penalties = true
		if not hold("countdown", floorIndex, countdown, message) then
			break
		end
		if countAlive() == 0 then
			break
		end

		payFloor(floorIndex)
		hold("pay", floorIndex, Config.PayHold, "Cash in. Get ready to jump.")

		Tower.setActive(floorIndex, "warn")
		hold("warn", floorIndex, Config.WarnSeconds, "JUMP UP")
		if countAlive() == 0 then
			break
		end

		state.dropping = true
		Tower.drop(floorIndex)
		hold("drop", floorIndex, Config.LandingDelay, "Floor down. Land on the next one.")

		local destination = floorIndex + 1
		for _, player in Players:GetPlayers() do
			if player:GetAttribute("Alive") == true and not survived(player, destination) then
				eliminate(player)
			end
		end

		state.dropping = false
		state.floor = destination
		if destination >= Config.FloorCount and countAlive() > 0 then
			reachedTop = true
		end
	end

	state.penalties = false
	state.dropping = false

	if reachedTop then
		Tower.setActive(Config.FloorCount, "jackpot")
		local awarded = splitJackpot()
		local message = if awarded
			then "Top floor splits the jackpot."
			else "Nobody held the top floor."
		hold("jackpot", Config.FloorCount, Config.JackpotCelebrate, message)
	else
		broadcast("intermission", state.floor, Config.Intermission, "Everyone fell. Lifetime cash is safe.")
		print("[Floor is Profit] round ended with no jackpot")
		task.wait(Config.Intermission)
	end

	for _, player in Players:GetPlayers() do
		if player:GetAttribute("Alive") == true then
			Cash.clearRound(player)
		end
		player:SetAttribute("Alive", false)
	end

	if reachedTop then
		towerNumber += 1
		Tower.setTowerNumber(towerNumber)
		broadcast("intermission", 1, Config.Intermission, "Next tower.")
		task.wait(Config.Intermission)
	end
end

function RoundLoop.start(remoteBundle)
	if started then
		return
	end
	started = true
	remotes = remoteBundle
	Tower.registerGroups()

	local built, buildErr = pcall(function()
		Tower.build(onKillTouch)
	end)
	if built then
		towerReady = true
	else
		warn("[Floor is Profit] tower build failed: ", buildErr)
	end

	RunService.PreSimulation:Connect(updatePassage)
	RunService.Heartbeat:Connect(updateFalls)

	print("[Floor is Profit] Opening floor pays in about 4s, then drops. Later floors wait 30s, pay, then drop.")

	task.spawn(function()
		while true do
			local ok, err = pcall(runRound)
			if not ok then
				warn("[Floor is Profit] round error: ", err)
				state.penalties = false
				task.wait(2)
			end
		end
	end)
end

return RoundLoop

-- Tuning for Floor is Profit.
-- Floor 1 pays and drops quickly so spawn, cash, the drop, and the jump
-- all happen in the opening seconds. Later floors wait 30 seconds, pay,
-- warn, then drop.

local Config = {
	FloorCount = 8,
	FloorSize = Vector3.new(40, 1.8, 40),
	PadThickness = 0.3,
	-- Extra landing surface around the pad. Narrow enough that a player
	-- standing on it is still inside the column that counts as on the floor.
	LipWidth = 2,
	LipThickness = 0.35,
	-- Studs from one floor's top surface to the next floor's top surface.
	-- JumpHeight has to clear this. Players jump straight up through the
	-- next floor; it only becomes solid once their feet are above it.
	FloorSpacing = 9,
	FirstTopY = 10,
	JumpHeight = 13,
	WalkSpeed = 18,

	OpeningCountdown = 3.5,
	LaterCountdown = 30,
	PayHold = 0.7,
	WarnSeconds = 2.7,
	DropDuration = 0.85,
	LandingDelay = 1.1,

	JackpotCelebrate = 5,
	Intermission = 4,

	Jackpot = 20000,
	Payouts = { 500, 800, 1200, 1800, 2500, 3500, 5000 },

	KillY = -30,
	SecondLifeCap = 5,
	ColumnMargin = 2.5,

	FloorColors = {
		Color3.fromRGB(255, 20, 40),
		Color3.fromRGB(255, 95, 0),
		Color3.fromRGB(255, 230, 0),
		Color3.fromRGB(20, 255, 70),
		Color3.fromRGB(0, 255, 230),
		Color3.fromRGB(30, 90, 255),
		Color3.fromRGB(200, 30, 255),
		Color3.fromRGB(255, 200, 0),
	},

	Products = {
		SecondLife = "SecondLife",
		DoubleNext = "DoubleNext",
		SurvivorTrail = "SurvivorTrail",
	},

	Groups = {
		Climber = "FP_Climber",
		Landed = "FP_Landed",
		Ground = "FP_Ground",
		Step = "FP_Step",
		Ghost = "FP_Ghost",
	},
}

function Config.topY(floorIndex: number): number
	return Config.FirstTopY + (floorIndex - 1) * Config.FloorSpacing
end

function Config.payoutFor(floorIndex: number, towerNumber: number?): number
	local base = Config.Payouts[floorIndex] or 0
	local tower = if type(towerNumber) == "number" then math.floor(towerNumber) else 1
	if tower < 1 then
		tower = 1
	end
	return base * tower
end

function Config.countdownFor(floorIndex: number): number
	if floorIndex <= 1 then
		return Config.OpeningCountdown
	end
	return Config.LaterCountdown
end

function Config.formatCash(amount: number): string
	local negative = amount < 0
	local digits = tostring(math.floor(math.abs(amount)))
	local withCommas = digits:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
	if negative then
		return "-$" .. withCommas
	end
	return "$" .. withCommas
end

return Config

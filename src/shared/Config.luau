-- Tuning for Floor is Profit.
-- Floor 1 pays and drops quickly so spawn, cash, the drop, and the jump
-- all happen in the opening seconds. Later floors wait 30 seconds, pay,
-- warn, then drop.

local Config = {
	FloorCount = 8,
	FloorSize = Vector3.new(40, 1.8, 40),
	PadThickness = 0.3,
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
		Color3.fromRGB(255, 64, 72),
		Color3.fromRGB(255, 138, 32),
		Color3.fromRGB(255, 214, 48),
		Color3.fromRGB(64, 214, 96),
		Color3.fromRGB(32, 206, 204),
		Color3.fromRGB(56, 140, 255),
		Color3.fromRGB(176, 84, 255),
		Color3.fromRGB(255, 196, 48),
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

function Config.payoutFor(floorIndex: number): number
	return Config.Payouts[floorIndex] or 0
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

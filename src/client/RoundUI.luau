-- Round timer, floor, cash at risk, and the jump callout.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local RoundUI = {}

local snapshot = nil
local timerLabel: TextLabel? = nil
local captionLabel: TextLabel? = nil
local floorLabel: TextLabel? = nil
local roundLabel: TextLabel? = nil
local lifetimeLabel: TextLabel? = nil
local jackpotLabel: TextLabel? = nil
local messageLabel: TextLabel? = nil
local toastLabel: TextLabel? = nil
local callout: TextLabel? = nil
local calloutSub: TextLabel? = nil
local calloutBanner: Frame? = nil
local calloutScale: UIScale? = nil
local panelStroke: UIStroke? = nil
local countdownBanner: Frame? = nil
local countdownNumber: TextLabel? = nil
local countdownFloor: TextLabel? = nil
local countdownStroke: UIStroke? = nil
local nextTowerBanner: Frame? = nil
local nextTowerNumber: TextLabel? = nil
local jackpotBanner: Frame? = nil
local jackpotAmount: TextLabel? = nil
local jackpotScale: UIScale? = nil

local function setText(label: TextLabel?, text: string)
	if label then
		label.Text = text
	end
end

local function applySnapshot(value)
	if typeof(value) ~= "table" then
		return
	end
	if type(value.phase) ~= "string" or type(value.floor) ~= "number" then
		return
	end
	snapshot = value
	setText(floorLabel, string.format("FLOOR %d / %d", value.floor, value.floorCount or Config.FloorCount))
	setText(messageLabel, type(value.message) == "string" and value.message or "")
	if type(value.jackpot) == "number" then
		setText(jackpotLabel, "Jackpot  " .. Config.formatCash(value.jackpot))
	end
	if panelStroke and typeof(value.color) == "Color3" then
		panelStroke.Color = value.color
	end
	if floorLabel and typeof(value.color) == "Color3" then
		floorLabel.TextColor3 = value.color
	end
end

local function render()
	local player = Players.LocalPlayer
	local roundCash = math.floor(player:GetAttribute("RoundCash") or 0)
	setText(roundLabel, "This round  " .. Config.formatCash(roundCash))

	local stats = player:FindFirstChild("leaderstats")
	local cash = stats and stats:FindFirstChild("Cash")
	if cash and cash:IsA("IntValue") then
		setText(lifetimeLabel, "Cash  " .. Config.formatCash(cash.Value))
	end

	if not snapshot then
		return
	end

	local remaining = 0
	if type(snapshot.endsAt) == "number" then
		remaining = math.max(0, snapshot.endsAt - workspace:GetServerTimeNow())
	end
	local seconds = tostring(math.max(0, math.ceil(remaining)))
	local phase = snapshot.phase
	local nextTower = phase == "intermission"
		and type(snapshot.message) == "string"
		and string.find(snapshot.message, "Next tower", 1, true) ~= nil

	if phase == "countdown" then
		setText(timerLabel, seconds)
		setText(captionLabel, "Pays in")
	elseif phase == "pay" then
		setText(timerLabel, "PAID")
		setText(captionLabel, "Cash in")
	elseif phase == "warn" then
		setText(timerLabel, "JUMP")
		setText(captionLabel, "UP — floor drops in " .. seconds)
	elseif phase == "drop" then
		setText(timerLabel, "DOWN")
		setText(captionLabel, "Jump")
	elseif phase == "jackpot" then
		setText(timerLabel, "WIN")
		setText(captionLabel, "Top floor")
	elseif phase == "intermission" then
		setText(timerLabel, seconds)
		setText(captionLabel, if nextTower then "Next tower" else "Round over")
	else
		setText(timerLabel, "...")
		setText(captionLabel, "Get ready")
	end

	if countdownBanner and countdownNumber and countdownFloor then
		local showCountdown = phase == "countdown"
		countdownBanner.Visible = showCountdown
		if showCountdown then
			countdownNumber.Text = seconds
			local floorIndex = snapshot.floor or 1
			countdownFloor.Text = string.format("FLOOR %d", floorIndex)
			if countdownStroke and typeof(snapshot.color) == "Color3" then
				countdownStroke.Color = snapshot.color
				countdownNumber.TextColor3 = snapshot.color
			end
		end
	end

	if nextTowerBanner and nextTowerNumber then
		nextTowerBanner.Visible = nextTower
		if nextTower then
			nextTowerNumber.Text = seconds
		end
	end

	if jackpotBanner and jackpotAmount and jackpotScale then
		local showJackpot = phase == "jackpot"
		jackpotBanner.Visible = showJackpot
		if showJackpot then
			local purse = if type(snapshot.jackpot) == "number" then snapshot.jackpot else Config.Jackpot
			jackpotAmount.Text = Config.formatCash(purse)
			jackpotScale.Scale = 1 + math.sin(os.clock() * 5) * 0.04
		end
	end

	local showCallout = phase == "warn" or phase == "drop"
	if callout and calloutBanner and calloutScale then
		calloutBanner.Visible = showCallout
		if phase == "warn" then
			local pulse = math.sin(os.clock() * 14) > 0
			callout.Text = "JUMP UP"
			callout.TextColor3 = if pulse then Color3.fromRGB(255, 255, 255) else Color3.fromRGB(255, 230, 40)
			calloutBanner.BackgroundColor3 = if pulse then Color3.fromRGB(220, 0, 30) else Color3.fromRGB(120, 0, 16)
			setText(calloutSub, "THE FLOOR IS DROPPING")
			calloutScale.Scale = if pulse then 1.08 else 0.96
		elseif phase == "drop" then
			callout.Text = "FALLING"
			callout.TextColor3 = Color3.fromRGB(255, 255, 255)
			calloutBanner.BackgroundColor3 = Color3.fromRGB(180, 60, 0)
			setText(calloutSub, "GET ON THE NEXT FLOOR")
			calloutScale.Scale = 1
		end
	end
end

local function corner(parent: Instance, radius: number)
	local ui = Instance.new("UICorner")
	ui.CornerRadius = UDim.new(0, radius)
	ui.Parent = parent
end

local function label(props): TextLabel
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Font = props.font or Enum.Font.GothamBold
	text.TextSize = props.textSize or 16
	text.TextColor3 = props.color or Color3.new(1, 1, 1)
	text.TextXAlignment = props.align or Enum.TextXAlignment.Center
	text.Text = props.text or ""
	text.Size = props.size or UDim2.new(1, 0, 0, props.textSize or 16)
	text.Position = props.position or UDim2.fromOffset(0, 0)
	text.Parent = props.parent
	return text
end

function RoundUI.start(remoteBundle)
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "RoundUI"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.DisplayOrder = 10
	gui.Parent = player:WaitForChild("PlayerGui")

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0)
	panel.Position = UDim2.new(0.5, 0, 0, 8)
	panel.Size = UDim2.fromOffset(320, 168)
	panel.BackgroundColor3 = Color3.fromRGB(14, 14, 20)
	panel.BackgroundTransparency = 0.22
	panel.Parent = gui
	corner(panel, 12)

	panelStroke = Instance.new("UIStroke")
	panelStroke.Color = Color3.fromRGB(255, 64, 72)
	panelStroke.Thickness = 2
	panelStroke.Parent = panel

	floorLabel = label({
		parent = panel,
		text = "FLOOR 1 / 8",
		textSize = 14,
		color = Color3.fromRGB(255, 90, 96),
		position = UDim2.fromOffset(0, 8),
		size = UDim2.new(1, 0, 0, 18),
	})
	timerLabel = label({
		parent = panel,
		text = "...",
		font = Enum.Font.GothamBlack,
		textSize = 42,
		position = UDim2.fromOffset(0, 26),
		size = UDim2.new(1, 0, 0, 46),
	})
	captionLabel = label({
		parent = panel,
		text = "Get ready",
		textSize = 14,
		color = Color3.fromRGB(210, 210, 220),
		position = UDim2.fromOffset(0, 72),
		size = UDim2.new(1, 0, 0, 16),
	})
	lifetimeLabel = label({
		parent = panel,
		text = "Cash  $0",
		textSize = 16,
		align = Enum.TextXAlignment.Left,
		position = UDim2.fromOffset(16, 96),
		size = UDim2.new(1, -32, 0, 18),
	})
	roundLabel = label({
		parent = panel,
		text = "This round  $0",
		textSize = 16,
		color = Color3.fromRGB(255, 214, 96),
		align = Enum.TextXAlignment.Left,
		position = UDim2.fromOffset(16, 116),
		size = UDim2.new(1, -32, 0, 18),
	})
	jackpotLabel = label({
		parent = panel,
		text = "Jackpot  $20,000",
		textSize = 14,
		color = Color3.fromRGB(255, 196, 80),
		align = Enum.TextXAlignment.Left,
		position = UDim2.fromOffset(16, 138),
		size = UDim2.new(0.55, 0, 0, 18),
	})

	messageLabel = label({
		parent = gui,
		text = "Stand here. This floor pays, then it falls.",
		textSize = 16,
		position = UDim2.new(0.5, -220, 0, 182),
		size = UDim2.fromOffset(440, 22),
	})

	toastLabel = label({
		parent = gui,
		text = "",
		textSize = 15,
		color = Color3.fromRGB(230, 240, 255),
		position = UDim2.new(0.5, -240, 0, 206),
		size = UDim2.fromOffset(480, 48),
	})
	toastLabel.TextWrapped = true
	toastLabel.TextYAlignment = Enum.TextYAlignment.Top

	calloutBanner = Instance.new("Frame")
	calloutBanner.Name = "JumpBanner"
	calloutBanner.AnchorPoint = Vector2.new(0.5, 0.5)
	calloutBanner.Position = UDim2.fromScale(0.5, 0.62)
	calloutBanner.Size = UDim2.fromOffset(640, 150)
	calloutBanner.BackgroundColor3 = Color3.fromRGB(220, 0, 30)
	calloutBanner.BorderSizePixel = 0
	calloutBanner.Visible = false
	calloutBanner.Parent = gui
	corner(calloutBanner, 16)
	local bannerStroke = Instance.new("UIStroke")
	bannerStroke.Thickness = 6
	bannerStroke.Color = Color3.fromRGB(255, 255, 255)
	bannerStroke.Parent = calloutBanner
	calloutScale = Instance.new("UIScale")
	calloutScale.Parent = calloutBanner
	callout = label({
		parent = calloutBanner,
		text = "JUMP UP",
		font = Enum.Font.GothamBlack,
		textSize = 78,
		color = Color3.new(1, 1, 1),
		position = UDim2.fromOffset(0, 18),
		size = UDim2.new(1, 0, 0, 82),
	})
	local calloutTextStroke = Instance.new("UIStroke")
	calloutTextStroke.Thickness = 3
	calloutTextStroke.Color = Color3.fromRGB(40, 0, 0)
	calloutTextStroke.Parent = callout
	calloutSub = label({
		parent = calloutBanner,
		text = "THE FLOOR IS DROPPING",
		font = Enum.Font.GothamBlack,
		textSize = 22,
		color = Color3.new(1, 1, 1),
		position = UDim2.fromOffset(0, 102),
		size = UDim2.new(1, 0, 0, 28),
	})

	countdownBanner = Instance.new("Frame")
	countdownBanner.Name = "Countdown"
	countdownBanner.AnchorPoint = Vector2.new(0.5, 0.5)
	countdownBanner.Position = UDim2.fromScale(0.5, 0.42)
	countdownBanner.Size = UDim2.fromOffset(280, 220)
	countdownBanner.BackgroundColor3 = Color3.fromRGB(8, 8, 12)
	countdownBanner.BackgroundTransparency = 0.12
	countdownBanner.BorderSizePixel = 0
	countdownBanner.Visible = false
	countdownBanner.Parent = gui
	corner(countdownBanner, 20)
	countdownStroke = Instance.new("UIStroke")
	countdownStroke.Thickness = 6
	countdownStroke.Color = Color3.fromRGB(255, 220, 40)
	countdownStroke.Parent = countdownBanner
	countdownFloor = label({
		parent = countdownBanner,
		text = "FLOOR 1",
		font = Enum.Font.GothamBlack,
		textSize = 28,
		color = Color3.new(1, 1, 1),
		position = UDim2.fromOffset(0, 16),
		size = UDim2.new(1, 0, 0, 34),
	})
	countdownNumber = label({
		parent = countdownBanner,
		text = "30",
		font = Enum.Font.GothamBlack,
		textSize = 120,
		color = Color3.fromRGB(255, 220, 40),
		position = UDim2.fromOffset(0, 48),
		size = UDim2.new(1, 0, 0, 120),
	})
	local countdownCaption = label({
		parent = countdownBanner,
		text = "PAYS IN",
		font = Enum.Font.GothamBlack,
		textSize = 20,
		color = Color3.fromRGB(230, 230, 236),
		position = UDim2.fromOffset(0, 172),
		size = UDim2.new(1, 0, 0, 28),
	})
	countdownCaption.Name = "Caption"

	nextTowerBanner = Instance.new("Frame")
	nextTowerBanner.Name = "NextTower"
	nextTowerBanner.AnchorPoint = Vector2.new(0.5, 0.5)
	nextTowerBanner.Position = UDim2.fromScale(0.5, 0.42)
	nextTowerBanner.Size = UDim2.fromOffset(640, 230)
	nextTowerBanner.BackgroundColor3 = Color3.fromRGB(8, 12, 20)
	nextTowerBanner.BorderSizePixel = 0
	nextTowerBanner.Visible = false
	nextTowerBanner.Parent = gui
	corner(nextTowerBanner, 18)
	local nextStroke = Instance.new("UIStroke")
	nextStroke.Thickness = 7
	nextStroke.Color = Color3.fromRGB(80, 190, 255)
	nextStroke.Parent = nextTowerBanner
	local nextTitle = label({
		parent = nextTowerBanner,
		text = "NEXT TOWER",
		font = Enum.Font.GothamBlack,
		textSize = 54,
		color = Color3.fromRGB(140, 220, 255),
		position = UDim2.fromOffset(0, 16),
		size = UDim2.new(1, 0, 0, 64),
	})
	local nextTitleStroke = Instance.new("UIStroke")
	nextTitleStroke.Thickness = 2
	nextTitleStroke.Color = Color3.fromRGB(0, 20, 40)
	nextTitleStroke.Parent = nextTitle
	nextTowerNumber = label({
		parent = nextTowerBanner,
		text = "4",
		font = Enum.Font.GothamBlack,
		textSize = 96,
		color = Color3.new(1, 1, 1),
		position = UDim2.fromOffset(0, 82),
		size = UDim2.new(1, 0, 0, 100),
	})
	label({
		parent = nextTowerBanner,
		text = "NEW TOWER IN",
		font = Enum.Font.GothamBlack,
		textSize = 20,
		color = Color3.fromRGB(190, 220, 240),
		position = UDim2.fromOffset(0, 186),
		size = UDim2.new(1, 0, 0, 28),
	})

	jackpotBanner = Instance.new("Frame")
	jackpotBanner.Name = "JackpotBanner"
	jackpotBanner.AnchorPoint = Vector2.new(0.5, 0.5)
	jackpotBanner.Position = UDim2.fromScale(0.5, 0.4)
	jackpotBanner.Size = UDim2.fromOffset(720, 210)
	jackpotBanner.BackgroundColor3 = Color3.fromRGB(28, 16, 0)
	jackpotBanner.BorderSizePixel = 0
	jackpotBanner.Visible = false
	jackpotBanner.Parent = gui
	corner(jackpotBanner, 18)
	local jackpotStroke = Instance.new("UIStroke")
	jackpotStroke.Thickness = 8
	jackpotStroke.Color = Color3.fromRGB(255, 196, 32)
	jackpotStroke.Parent = jackpotBanner
	jackpotScale = Instance.new("UIScale")
	jackpotScale.Parent = jackpotBanner
	local jackpotTitle = label({
		parent = jackpotBanner,
		text = "JACKPOT",
		font = Enum.Font.GothamBlack,
		textSize = 72,
		color = Color3.fromRGB(255, 214, 48),
		position = UDim2.fromOffset(0, 16),
		size = UDim2.new(1, 0, 0, 78),
	})
	local jackpotTitleStroke = Instance.new("UIStroke")
	jackpotTitleStroke.Thickness = 3
	jackpotTitleStroke.Color = Color3.fromRGB(60, 30, 0)
	jackpotTitleStroke.Parent = jackpotTitle
	jackpotAmount = label({
		parent = jackpotBanner,
		text = Config.formatCash(Config.Jackpot),
		font = Enum.Font.GothamBlack,
		textSize = 54,
		color = Color3.new(1, 1, 1),
		position = UDim2.fromOffset(0, 96),
		size = UDim2.new(1, 0, 0, 60),
	})
	label({
		parent = jackpotBanner,
		text = "TOP FLOOR PAYS",
		font = Enum.Font.GothamBlack,
		textSize = 22,
		color = Color3.fromRGB(255, 220, 140),
		position = UDim2.fromOffset(0, 164),
		size = UDim2.new(1, 0, 0, 28),
	})

	remoteBundle.RoundState.OnClientEvent:Connect(applySnapshot)
	remoteBundle.Toast.OnClientEvent:Connect(function(message)
		if type(message) ~= "string" or toastLabel == nil then
			return
		end
		toastLabel.Text = message
		task.delay(4.5, function()
			if toastLabel and toastLabel.Text == message then
				toastLabel.Text = ""
			end
		end)
	end)

	player:GetAttributeChangedSignal("RoundCash"):Connect(render)
	task.spawn(function()
		local stats = player:WaitForChild("leaderstats", 15)
		if not stats then
			return
		end
		local cash = stats:WaitForChild("Cash", 10)
		if cash and cash:IsA("IntValue") then
			cash.Changed:Connect(render)
			render()
		end
	end)

	RunService.RenderStepped:Connect(render)
end

return RoundUI

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
		setText(captionLabel, "Next tower")
	else
		setText(timerLabel, "...")
		setText(captionLabel, "Get ready")
	end

	local showCallout = phase == "warn" or phase == "drop" or phase == "jackpot"
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
		elseif phase == "jackpot" then
			callout.Text = "JACKPOT"
			callout.TextColor3 = Color3.fromRGB(255, 220, 60)
			calloutBanner.BackgroundColor3 = Color3.fromRGB(40, 24, 0)
			setText(calloutSub, "TOP FLOOR SPLITS IT")
			calloutScale.Scale = 1 + math.sin(os.clock() * 6) * 0.04
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

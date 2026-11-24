-- Big cash number when a floor pays, a jackpot hits, or a fall takes the round back.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local CashPopup = {}

local STYLES = {
	pay = {
		color = Color3.fromRGB(80, 255, 120),
		prefix = "+",
		subtitle = "PAID",
	},
	double = {
		color = Color3.fromRGB(255, 220, 80),
		prefix = "+",
		subtitle = "2X NEXT FLOOR",
	},
	jackpot = {
		color = Color3.fromRGB(255, 196, 64),
		prefix = "+",
		subtitle = "JACKPOT",
	},
}

local layer: Frame? = nil
local shown = 0

local function showFell(amount: number)
	if not layer then
		return
	end
	local lostText = if amount > 0 then "-" .. Config.formatCash(amount) else Config.formatCash(0)

	local frame = Instance.new("Frame")
	frame.Name = "YouFell"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.BackgroundColor3 = Color3.fromRGB(28, 6, 8)
	frame.BorderSizePixel = 0
	frame.Size = UDim2.fromOffset(620, 250)
	frame.Position = UDim2.fromScale(0.5, 0.46)
	frame.ZIndex = 8
	frame.Parent = layer

	local cardCorner = Instance.new("UICorner")
	cardCorner.CornerRadius = UDim.new(0, 20)
	cardCorner.Parent = frame

	local cardStroke = Instance.new("UIStroke")
	cardStroke.Thickness = 8
	cardStroke.Color = Color3.fromRGB(255, 48, 56)
	cardStroke.Parent = frame

	local scale = Instance.new("UIScale")
	scale.Scale = 0.45
	scale.Parent = frame

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, 0, 0, 78)
	title.Position = UDim2.fromOffset(0, 16)
	title.Font = Enum.Font.GothamBlack
	title.TextSize = 68
	title.TextColor3 = Color3.fromRGB(255, 70, 76)
	title.Text = "YOU FELL"
	title.ZIndex = 9
	title.Parent = frame

	local titleStroke = Instance.new("UIStroke")
	titleStroke.Thickness = 3
	titleStroke.Color = Color3.fromRGB(40, 0, 0)
	titleStroke.Parent = title

	local amountLabel = Instance.new("TextLabel")
	amountLabel.BackgroundTransparency = 1
	amountLabel.Position = UDim2.fromOffset(0, 96)
	amountLabel.Size = UDim2.new(1, 0, 0, 78)
	amountLabel.Font = Enum.Font.GothamBlack
	amountLabel.TextSize = 64
	amountLabel.TextColor3 = Color3.new(1, 1, 1)
	amountLabel.Text = lostText
	amountLabel.ZIndex = 9
	amountLabel.Parent = frame

	local amountStroke = Instance.new("UIStroke")
	amountStroke.Thickness = 2
	amountStroke.Color = Color3.fromRGB(0, 0, 0)
	amountStroke.Parent = amountLabel

	local detail = Instance.new("TextLabel")
	detail.BackgroundTransparency = 1
	detail.Position = UDim2.fromOffset(0, 186)
	detail.Size = UDim2.new(1, 0, 0, 40)
	detail.Font = Enum.Font.GothamBlack
	detail.TextSize = 22
	detail.TextColor3 = Color3.fromRGB(255, 190, 190)
	detail.Text = "THIS ROUND ONLY  ·  LIFETIME CASH STAYS"
	detail.ZIndex = 9
	detail.Parent = frame

	TweenService:Create(scale, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Scale = 1,
	}):Play()

	task.delay(2.6, function()
		if not frame.Parent then
			return
		end
		local fadeInfo = TweenInfo.new(0.6)
		TweenService:Create(frame, fadeInfo, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(cardStroke, fadeInfo, { Transparency = 1 }):Play()
		TweenService:Create(title, fadeInfo, { TextTransparency = 1 }):Play()
		TweenService:Create(titleStroke, fadeInfo, { Transparency = 1 }):Play()
		TweenService:Create(amountLabel, fadeInfo, { TextTransparency = 1 }):Play()
		TweenService:Create(amountStroke, fadeInfo, { Transparency = 1 }):Play()
		local fadeDetail = TweenService:Create(detail, fadeInfo, { TextTransparency = 1 })
		fadeDetail:Play()
		fadeDetail.Completed:Once(function()
			frame:Destroy()
		end)
	end)
end

local function popup(kind: string, amount: number)
	if not layer or amount == 0 then
		return
	end
	local style = STYLES[kind] or STYLES.pay
	shown += 1
	local index = shown

	local frame = Instance.new("Frame")
	frame.Name = "CashPopup"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.BackgroundColor3 = Color3.fromRGB(8, 10, 14)
	frame.BackgroundTransparency = 0
	frame.BorderSizePixel = 0
	frame.Size = UDim2.fromOffset(480, 168)
	frame.Position = UDim2.new(0.5, 0, 0.38, (index % 3) * 10)
	frame.ZIndex = 5
	frame.Parent = layer

	local cardCorner = Instance.new("UICorner")
	cardCorner.CornerRadius = UDim.new(0, 18)
	cardCorner.Parent = frame

	local cardStroke = Instance.new("UIStroke")
	cardStroke.Thickness = 5
	cardStroke.Color = style.color
	cardStroke.Parent = frame

	local scale = Instance.new("UIScale")
	scale.Scale = 0.4
	scale.Parent = frame

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, 0, 0, 32)
	title.Position = UDim2.fromOffset(0, 14)
	title.Font = Enum.Font.GothamBlack
	title.TextSize = 22
	title.TextColor3 = style.color
	title.Text = style.subtitle or "CASH"
	title.ZIndex = 6
	title.Parent = frame

	local amountLabel = Instance.new("TextLabel")
	amountLabel.BackgroundTransparency = 1
	amountLabel.Position = UDim2.fromOffset(0, 48)
	amountLabel.Size = UDim2.new(1, 0, 0, 96)
	amountLabel.Font = Enum.Font.GothamBlack
	amountLabel.TextSize = 84
	amountLabel.TextColor3 = style.color
	amountLabel.Text = style.prefix .. Config.formatCash(amount)
	amountLabel.ZIndex = 6
	amountLabel.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.fromRGB(0, 0, 0)
	stroke.Parent = amountLabel

	TweenService:Create(scale, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Scale = 1,
	}):Play()

	task.delay(1.15, function()
		if not frame.Parent then
			return
		end
		local rise = TweenService:Create(frame, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = frame.Position - UDim2.fromOffset(0, 70),
			BackgroundTransparency = 1,
		})
		local fade = TweenService:Create(amountLabel, TweenInfo.new(0.7), {
			TextTransparency = 1,
		})
		local fadeTitle = TweenService:Create(title, TweenInfo.new(0.7), {
			TextTransparency = 1,
		})
		local fadeStroke = TweenService:Create(stroke, TweenInfo.new(0.7), {
			Transparency = 1,
		})
		local fadeCard = TweenService:Create(cardStroke, TweenInfo.new(0.7), {
			Transparency = 1,
		})
		rise:Play()
		fade:Play()
		fadeTitle:Play()
		fadeStroke:Play()
		fadeCard:Play()
		fade.Completed:Once(function()
			frame:Destroy()
		end)
	end)
end

function CashPopup.start(remoteBundle)
	local gui = Instance.new("ScreenGui")
	gui.Name = "CashPopups"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 30
	gui.Parent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")

	layer = Instance.new("Frame")
	layer.Name = "Layer"
	layer.BackgroundTransparency = 1
	layer.Size = UDim2.fromScale(1, 1)
	layer.Parent = gui

	remoteBundle.CashEvent.OnClientEvent:Connect(function(kind, amount)
		if type(kind) ~= "string" or type(amount) ~= "number" then
			return
		end
		local value = math.floor(amount)
		if kind == "loss" then
			showFell(math.max(0, value))
			return
		end
		popup(kind, value)
	end)
end

return CashPopup

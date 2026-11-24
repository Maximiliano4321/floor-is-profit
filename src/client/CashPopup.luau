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
	loss = {
		color = Color3.fromRGB(255, 84, 84),
		prefix = "-",
		subtitle = "THIS ROUND ONLY",
	},
	jackpot = {
		color = Color3.fromRGB(255, 196, 64),
		prefix = "+",
		subtitle = "JACKPOT",
	},
}

local layer: Frame? = nil
local shown = 0

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
		popup(kind, math.floor(amount))
	end)
end

return CashPopup

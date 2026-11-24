-- Studio stubs. These buttons grant the effect directly. They are not purchases.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local ProductButtons = {}

local function corner(parent: Instance)
	local ui = Instance.new("UICorner")
	ui.CornerRadius = UDim.new(0, 8)
	ui.Parent = parent
end

local function makeButton(parent: Instance, text: string, layoutOrder: number): TextButton
	local button = Instance.new("TextButton")
	button.Name = text
	button.LayoutOrder = layoutOrder
	button.Size = UDim2.new(1, 0, 0, 36)
	button.BackgroundColor3 = Color3.fromRGB(28, 30, 40)
	button.AutoButtonColor = true
	button.Font = Enum.Font.GothamBold
	button.TextSize = 14
	button.TextColor3 = Color3.new(1, 1, 1)
	button.Text = text
	button.BorderSizePixel = 0
	button.Parent = parent
	corner(button)
	return button
end

function ProductButtons.start(remoteBundle)
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "DevProducts"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 20
	gui.Parent = player:WaitForChild("PlayerGui")

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(1, 0.5)
	panel.Position = UDim2.new(1, -12, 0.5, 0)
	panel.Size = UDim2.fromOffset(210, 214)
	panel.BackgroundColor3 = Color3.fromRGB(14, 14, 20)
	panel.BackgroundTransparency = 0.15
	panel.Parent = gui
	corner(panel)

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(70, 74, 92)
	stroke.Parent = panel

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 8)
	padding.PaddingBottom = UDim.new(0, 8)
	padding.PaddingLeft = UDim.new(0, 8)
	padding.PaddingRight = UDim.new(0, 8)
	padding.Parent = panel

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = panel

	local header = Instance.new("TextLabel")
	header.BackgroundTransparency = 1
	header.LayoutOrder = 1
	header.Size = UDim2.new(1, 0, 0, 28)
	header.Font = Enum.Font.GothamBold
	header.TextSize = 12
	header.TextColor3 = Color3.fromRGB(180, 186, 205)
	header.Text = "DEV STUBS\nnot real purchases"
	header.TextYAlignment = Enum.TextYAlignment.Center
	header.Parent = panel

	local life = makeButton(panel, "Second Life", 2)
	local double = makeButton(panel, "2x Next Floor", 3)
	local trail = makeButton(panel, "Survivor Trail", 4)
	local skip = makeButton(panel, "Skip wait", 5)
	skip.BackgroundColor3 = Color3.fromRGB(36, 32, 28)
	skip.TextColor3 = Color3.fromRGB(255, 196, 120)

	local function fire(productId: string)
		remoteBundle.ProductRequest:FireServer(productId)
	end

	life.MouseButton1Click:Connect(function()
		fire(Config.Products.SecondLife)
	end)
	double.MouseButton1Click:Connect(function()
		fire(Config.Products.DoubleNext)
	end)
	trail.MouseButton1Click:Connect(function()
		fire(Config.Products.SurvivorTrail)
	end)
	skip.MouseButton1Click:Connect(function()
		fire("Skip")
	end)

	local function paint()
		local charges = math.floor(player:GetAttribute("SecondLifeCharges") or 0)
		local armed = player:GetAttribute("DoubleNext") == true
		local trailOn = player:GetAttribute("TrailOn") == true

		life.Text = if charges > 0 then string.format("Second Life  x%d", charges) else "Second Life"
		life.BackgroundColor3 = if charges > 0 then Color3.fromRGB(24, 64, 40) else Color3.fromRGB(28, 30, 40)

		double.Text = if armed then "2x Next Floor  ARMED" else "2x Next Floor"
		double.BackgroundColor3 = if armed then Color3.fromRGB(64, 52, 18) else Color3.fromRGB(28, 30, 40)

		trail.Text = if trailOn then "Survivor Trail  ON" else "Survivor Trail"
		trail.BackgroundColor3 = if trailOn then Color3.fromRGB(48, 36, 72) else Color3.fromRGB(28, 30, 40)
	end

	for _, attribute in { "SecondLifeCharges", "DoubleNext", "TrailOn" } do
		player:GetAttributeChangedSignal(attribute):Connect(paint)
	end
	paint()
end

return ProductButtons

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

local function followCharacter(character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		local waited = character:WaitForChild("Humanoid", 10)
		if waited and waited:IsA("Humanoid") then
			humanoid = waited
		end
	end
	local camera = workspace.CurrentCamera
	if not humanoid or not camera then
		return
	end
	camera.CameraType = Enum.CameraType.Custom
	camera.CameraSubject = humanoid
end

player.CharacterAdded:Connect(function(character)
	followCharacter(character)
end)
if player.Character then
	task.spawn(followCharacter, player.Character)
end
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	local character = player.Character
	if character then
		followCharacter(character)
	end
end)

local RoundUI = require(script:WaitForChild("RoundUI"))
local CashPopup = require(script:WaitForChild("CashPopup"))
local ProductButtons = require(script:WaitForChild("ProductButtons"))

local folder = ReplicatedStorage:WaitForChild("Remotes")
local remotes = {
	RoundState = folder:WaitForChild("RoundState"),
	CashEvent = folder:WaitForChild("CashEvent"),
	Toast = folder:WaitForChild("Toast"),
	ProductRequest = folder:WaitForChild("ProductRequest"),
}

RoundUI.start(remotes)
CashPopup.start(remotes)
ProductButtons.start(remotes)

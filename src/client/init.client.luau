local ReplicatedStorage = game:GetService("ReplicatedStorage")

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

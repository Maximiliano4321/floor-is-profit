local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = {}

function Remotes.create()
	local existing = ReplicatedStorage:FindFirstChild("Remotes")
	if existing then
		existing:Destroy()
	end

	local folder = Instance.new("Folder")
	folder.Name = "Remotes"
	folder.Parent = ReplicatedStorage

	local function event(name: string): RemoteEvent
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
		return remote
	end

	return {
		RoundState = event("RoundState"),
		CashEvent = event("CashEvent"),
		Toast = event("Toast"),
		ProductRequest = event("ProductRequest"),
	}
end

return Remotes

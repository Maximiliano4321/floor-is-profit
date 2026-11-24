-- Chat commands and the Studio command bar. Buttons come from the client.
-- None of these call MarketplaceService.

local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")

local Products = require(script.Parent:WaitForChild("Products"))
local RoundLoop = require(script.Parent:WaitForChild("RoundLoop"))

local DevCommands = {}

local remotes = nil
local lastCommand: { [string]: number } = {}

local HELP = table.concat({
	"/life — arm Second Life",
	"/double — 2x the next floor payout",
	"/trail — toggle the survivor trail",
	"/skip — skip this floor's wait",
}, "\n")

local COMMANDS = {
	["/secondlife"] = "SecondLife",
	["/life"] = "SecondLife",
	["/double"] = "DoubleNext",
	["/2x"] = "DoubleNext",
	["/x2"] = "DoubleNext",
	["/trail"] = "SurvivorTrail",
	["/skip"] = "skip",
	["/help"] = "help",
}

local function toast(player: Player, message: string)
	if remotes and message ~= "" then
		remotes.Toast:FireClient(player, message)
	end
end

local function handle(player: Player, message: string)
	local token = string.match(message, "^(%S+)")
	if not token then
		return
	end
	local command = COMMANDS[string.lower(token)]
	if not command then
		return
	end

	local key = tostring(player.UserId) .. ":" .. command
	local now = os.clock()
	if lastCommand[key] and now - lastCommand[key] < 0.4 then
		return
	end
	lastCommand[key] = now

	if command == "help" then
		toast(player, HELP)
		return
	end
	if command == "skip" then
		if RoundLoop.requestSkip() then
			toast(player, "Skipping the wait.")
		else
			toast(player, "Skip works during the wait, before the floor pays.")
		end
		return
	end

	Products.grant(player, command)
end

function DevCommands.bind(remoteBundle)
	remotes = remoteBundle

	remoteBundle.ProductRequest.OnServerEvent:Connect(function(player: Player, productId: any)
		if typeof(player) ~= "Instance" or not player:IsA("Player") then
			return
		end
		if type(productId) ~= "string" or #productId > 40 then
			return
		end
		if productId == "Skip" then
			handle(player, "/skip")
			return
		end
		Products.grant(player, productId)
	end)

	local function hookPlayer(player: Player)
		player.Chatted:Connect(function(message)
			handle(player, message)
		end)
	end

	Players.PlayerAdded:Connect(hookPlayer)
	for _, player in Players:GetPlayers() do
		hookPlayer(player)
	end

	if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
		TextChatService.MessageReceived:Connect(function(message)
			local source = message.TextSource
			if not source then
				return
			end
			local player = Players:GetPlayerByUserId(source.UserId)
			if player then
				handle(player, message.Text)
			end
		end)
	end

	local api = {}
	function api.Grant(player: Player, productId: string)
		return Products.grant(player, productId)
	end
	function api.Skip()
		local skipped = RoundLoop.requestSkip()
		print(if skipped
			then "[Floor is Profit] skip accepted"
			else "[Floor is Profit] skip ignored (not in the wait)")
		return skipped
	end
	_G.FloorIsProfit = api
end

return DevCommands

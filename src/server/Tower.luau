-- Builds one bright tower. Each floor has a visible body and a thin pad.
-- The pad you are standing on is solid. The next pad lets climbers pass
-- through it, then catches them once their feet are above it, so a straight
-- jump up lands on the next floor instead of bonking the ceiling.

local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Tower = {}

local floors = {}
local root: Folder? = nil
local visualToken = 0
local beam: Beam? = nil
local beamTop: Attachment? = nil
local beamBottom: Attachment? = nil
local groupsReady = false

local PAY_SOUND = "rbxasset://sounds/electronicpingshort.wav"
local WARN_SOUND = "rbxasset://sounds/button.wav"
local DROP_SOUND = "rbxasset://sounds/uuhhh.wav"
local WIN_SOUND = "rbxasset://sounds/victory.wav"

local function ensureGroup(name: string)
	pcall(function()
		PhysicsService:RegisterCollisionGroup(name)
	end)
end

local function setCollide(a: string, b: string, canCollide: boolean)
	PhysicsService:CollisionGroupSetCollidable(a, b, canCollide)
end

function Tower.registerGroups()
	if groupsReady then
		return
	end
	local groups = Config.Groups
	ensureGroup(groups.Climber)
	ensureGroup(groups.Landed)
	ensureGroup(groups.Ground)
	ensureGroup(groups.Step)
	ensureGroup(groups.Ghost)

	setCollide(groups.Climber, groups.Step, false)
	setCollide(groups.Climber, groups.Ghost, false)
	setCollide(groups.Landed, groups.Ghost, false)
	setCollide(groups.Ground, groups.Ghost, false)
	setCollide(groups.Step, groups.Ghost, false)
	setCollide("Default", groups.Ghost, false)
	groupsReady = true
end

function Tower.applyGroup(character: Model, groupName: string)
	if character:GetAttribute("FPGroup") == groupName then
		local missing = false
		for _, descendant in character:GetDescendants() do
			if descendant:IsA("BasePart") and descendant.CollisionGroup ~= groupName then
				missing = true
				break
			end
		end
		if not missing then
			return
		end
	end

	character:SetAttribute("FPGroup", groupName)
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CollisionGroup = groupName
		end
	end
end

local function playAt(parent: Instance, soundId: string, volume: number)
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = volume
	sound.RollOffMode = Enum.RollOffMode.Linear
	sound.RollOffMinDistance = 18
	sound.RollOffMaxDistance = 420
	sound.Parent = parent
	sound:Play()
	Debris:AddItem(sound, 4)
end

local function clearDefaultMap()
	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate then
		baseplate:Destroy()
	end
	for _, child in workspace:GetChildren() do
		if child:IsA("SpawnLocation") then
			child:Destroy()
		end
	end
end

function Tower.prepareLighting()
	Tower.registerGroups()
	workspace.FallenPartsDestroyHeight = -200

	Lighting.ClockTime = 14.2
	Lighting.Brightness = 2.3
	Lighting.GlobalShadows = true
	Lighting.Ambient = Color3.fromRGB(115, 115, 132)
	Lighting.OutdoorAmbient = Color3.fromRGB(140, 140, 153)
	Lighting.Technology = Enum.Technology.ShadowMap

	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if not atmosphere then
		atmosphere = Instance.new("Atmosphere")
		atmosphere.Parent = Lighting
	end
	atmosphere.Density = 0.18
	atmosphere.Offset = 0.35
	atmosphere.Color = Color3.fromRGB(198, 214, 230)
	atmosphere.Decay = Color3.fromRGB(150, 168, 190)
	atmosphere.Glare = 0
	atmosphere.Haze = 0.25
end

local function clearBeam()
	if beam then
		beam:Destroy()
		beam = nil
	end
	if beamTop then
		beamTop:Destroy()
		beamTop = nil
	end
	if beamBottom then
		beamBottom:Destroy()
		beamBottom = nil
	end
end

local function labelText(index: number, phase: string, current: number): string
	if phase == "warn" and index == current then
		return "JUMP UP"
	end
	if phase == "warn" and index == current + 1 then
		return "LAND HERE"
	end
	if index >= Config.FloorCount then
		return "TOP\n" .. Config.formatCash(Config.Jackpot)
	end
	return string.format("FLOOR %d\n%s", index, Config.formatCash(Config.payoutFor(index)))
end

local function makeLabel(parent: BasePart, text: string)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Label"
	billboard.Size = UDim2.fromOffset(170, 68)
	billboard.StudsOffset = Vector3.new(0, 5.5, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 500
	billboard.Parent = parent

	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.BackgroundColor3 = Color3.fromRGB(12, 12, 16)
	label.BackgroundTransparency = 0.3
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Text = text
	label.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = label

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 4)
	padding.PaddingBottom = UDim.new(0, 4)
	padding.PaddingLeft = UDim.new(0, 6)
	padding.PaddingRight = UDim.new(0, 6)
	padding.Parent = label

	local limit = Instance.new("UITextSizeConstraint")
	limit.MinTextSize = 12
	limit.MaxTextSize = 28
	limit.Parent = label

	return label
end

local function buildSideline(parent: Instance)
	local model = Instance.new("Model")
	model.Name = "Sideline"

	local pad = Instance.new("Part")
	pad.Name = "Pad"
	pad.Anchored = true
	pad.Size = Vector3.new(22, 1, 22)
	pad.Position = Vector3.new(78, 46, 0)
	pad.Color = Color3.fromRGB(28, 30, 40)
	pad.Material = Enum.Material.SmoothPlastic
	pad.TopSurface = Enum.SurfaceType.Smooth
	pad.Parent = model

	local function wall(name: string, size: Vector3, position: Vector3)
		local part = Instance.new("Part")
		part.Name = name
		part.Anchored = true
		part.CanQuery = false
		part.Size = size
		part.Position = position
		part.Color = Color3.fromRGB(180, 200, 230)
		part.Material = Enum.Material.Glass
		part.Transparency = 0.55
		part.Parent = model
	end

	-- Glass box so eliminated players can watch. CanQuery is off so the camera looks through it.
	wall("Far", Vector3.new(1, 8, 22), Vector3.new(89, 50.5, 0))
	wall("Near", Vector3.new(1, 8, 22), Vector3.new(67, 50.5, 0))
	wall("North", Vector3.new(22, 8, 1), Vector3.new(78, 50.5, 11))
	wall("South", Vector3.new(22, 8, 1), Vector3.new(78, 50.5, -11))

	local sign = makeLabel(pad, "OUT THIS ROUND")
	sign.Text = "OUT THIS ROUND"
	model.Parent = parent
end

local function buildKillPlane(parent: Instance)
	local plane = Instance.new("Part")
	plane.Name = "KillPlane"
	plane.Anchored = true
	plane.CanCollide = true
	plane.Size = Vector3.new(600, 2, 600)
	plane.Position = Vector3.new(0, Config.KillY - 8, 0)
	plane.Color = Color3.fromRGB(40, 8, 14)
	plane.Material = Enum.Material.SmoothPlastic
	plane.Transparency = 0.15
	plane.Parent = parent
	return plane
end

local function buildSpine(parent: Instance)
	local top = Config.topY(Config.FloorCount) + 6
	local spine = Instance.new("Part")
	spine.Name = "Spine"
	spine.Anchored = true
	spine.CanCollide = false
	spine.Material = Enum.Material.Neon
	spine.Color = Color3.fromRGB(255, 255, 255)
	spine.Transparency = 0.35
	spine.Size = Vector3.new(0.6, top, 0.6)
	local edge = Config.FloorSize.X / 2 + 3
	spine.Position = Vector3.new(-edge, top / 2, -edge)
	spine.Parent = parent
end

function Tower.withinColumn(position: Vector3): boolean
	local half = Config.FloorSize.X / 2 + Config.ColumnMargin
	return math.abs(position.X) <= half and math.abs(position.Z) <= half
end

function Tower.build(onKillTouch: (BasePart) -> ())
	Tower.registerGroups()
	clearDefaultMap()
	clearBeam()
	visualToken += 1
	table.clear(floors)

	if root then
		root:Destroy()
		root = nil
	end

	local folder = Instance.new("Folder")
	folder.Name = "FloorIsProfit"
	folder.Parent = workspace
	root = folder

	local tower = Instance.new("Model")
	tower.Name = "Tower"
	tower.Parent = folder

	buildSpine(tower)

	for index = 1, Config.FloorCount do
		local color = Config.FloorColors[index]
		local top = Config.topY(index)
		local model = Instance.new("Model")
		model.Name = "Floor" .. tostring(index)
		model:SetAttribute("FloorIndex", index)

		local body = Instance.new("Part")
		body.Name = "Body"
		body.Anchored = true
		body.CanCollide = false
		body.CanQuery = false
		body.Size = Vector3.new(Config.FloorSize.X, Config.FloorSize.Y, Config.FloorSize.Z)
		body.Color = color
		body.Material = Enum.Material.SmoothPlastic
		body.TopSurface = Enum.SurfaceType.Smooth
		body.BottomSurface = Enum.SurfaceType.Smooth
		body.Position = Vector3.new(0, top - (Config.FloorSize.Y / 2), 0)
		body.Parent = model

		local trim = Instance.new("Part")
		trim.Name = "Trim"
		trim.Anchored = true
		trim.CanCollide = false
		trim.CanQuery = false
		trim.Material = Enum.Material.Neon
		trim.Color = color
		trim.Size = Vector3.new(Config.FloorSize.X + 1.4, 0.28, Config.FloorSize.Z + 1.4)
		trim.Position = Vector3.new(0, top - 0.2, 0)
		trim.Parent = model

		local pad = Instance.new("Part")
		pad.Name = "Pad"
		pad.Anchored = true
		pad.CanCollide = index <= 2
		pad.CanQuery = false
		pad.Transparency = 1
		pad.Size = Vector3.new(Config.FloorSize.X, Config.PadThickness, Config.FloorSize.Z)
		pad.Position = Vector3.new(0, top - (Config.PadThickness / 2), 0)
		pad.CollisionGroup = if index == 1
			then Config.Groups.Ground
			elseif index == 2 then Config.Groups.Step
			else Config.Groups.Ghost
		pad.Parent = model

		local light = Instance.new("PointLight")
		light.Name = "Glow"
		light.Color = color
		light.Range = 26
		light.Brightness = if index == 1 then 2 else 0
		light.Enabled = index == 1
		light.Parent = body

		local highlight = Instance.new("Highlight")
		highlight.Name = "Edge"
		highlight.Adornee = body
		highlight.FillColor = color
		highlight.OutlineColor = Color3.new(1, 1, 1)
		highlight.FillTransparency = 1
		highlight.OutlineTransparency = 0.25
		highlight.Parent = body

		local payoutText = labelText(index, "countdown", 1)
		local label = makeLabel(body, payoutText)

		model.PrimaryPart = body
		model.Parent = tower

		floors[index] = {
			index = index,
			model = model,
			body = body,
			trim = trim,
			pad = pad,
			light = light,
			highlight = highlight,
			label = label,
			baseColor = color,
			dropped = false,
		}
	end

	buildSideline(folder)
	local killPlane = buildKillPlane(folder)
	killPlane.Touched:Connect(function(hit)
		if hit and hit:IsA("BasePart") then
			onKillTouch(hit)
		end
	end)
end

function Tower.colorOf(index: number): Color3
	local floor = floors[index]
	if floor then
		return floor.baseColor
	end
	return Color3.new(1, 1, 1)
end

local function paint(floor, color: Color3)
	floor.body.Color = color
	floor.trim.Color = color
	floor.highlight.FillColor = color
end

function Tower.setActive(current: number, phase: string)
	visualToken += 1
	local token = visualToken
	clearBeam()

	for _, floor in floors do
		if floor.dropped then
			continue
		end

		local role = "ghost"
		if floor.index == current then
			role = "ground"
		elseif floor.index == current + 1 then
			role = "step"
		end

		floor.pad.CanCollide = role ~= "ghost"
		if role == "ground" then
			floor.pad.CollisionGroup = Config.Groups.Ground
		elseif role == "step" then
			floor.pad.CollisionGroup = Config.Groups.Step
		else
			floor.pad.CollisionGroup = Config.Groups.Ghost
		end

		local ghost = role == "ghost"
		local warningThis = phase == "warn" and floor.index == current
		floor.body.Transparency = if ghost then 0.4 else 0
		floor.trim.Transparency = if ghost then 0.4 else 0
		floor.body.Material = if ghost then Enum.Material.SmoothPlastic else Enum.Material.Neon
		floor.trim.Material = Enum.Material.Neon
		paint(floor, floor.baseColor)
		floor.light.Enabled = not ghost
		floor.light.Brightness = if role == "ground" then 5 else 3
		floor.light.Range = 40
		floor.label.Text = labelText(floor.index, phase, current)
		floor.label.TextColor3 = Color3.new(1, 1, 1)
		floor.label.BackgroundColor3 = if warningThis then Color3.fromRGB(220, 15, 30) else Color3.fromRGB(8, 8, 12)
		floor.label.BackgroundTransparency = if warningThis then 0 else 0.25
		local billboard = floor.label.Parent
		if billboard and billboard:IsA("BillboardGui") then
			billboard.Size = if warningThis then UDim2.fromOffset(320, 130) else UDim2.fromOffset(180, 72)
		end
		floor.highlight.FillTransparency = 1
		floor.highlight.OutlineTransparency = if ghost then 0.55 else 0
	end

	local currentFloor = floors[current]
	local nextFloor = floors[current + 1]
	if phase == "warn" and currentFloor and nextFloor and not nextFloor.dropped then
		playAt(currentFloor.body, WARN_SOUND, 0.45)

		beamBottom = Instance.new("Attachment")
		beamBottom.Name = "JumpFrom"
		beamBottom.Position = Vector3.new(0, 3.2, 0)
		beamBottom.Parent = currentFloor.body

		beamTop = Instance.new("Attachment")
		beamTop.Name = "JumpTo"
		beamTop.Position = Vector3.new(0, 3.2, 0)
		beamTop.Parent = nextFloor.body

		local jumpBeam = Instance.new("Beam")
		jumpBeam.Name = "JumpBeam"
		jumpBeam.Attachment0 = beamBottom
		jumpBeam.Attachment1 = beamTop
		jumpBeam.FaceCamera = true
		jumpBeam.Width0 = 5
		jumpBeam.Width1 = 5
		jumpBeam.LightEmission = 1
		jumpBeam.LightInfluence = 0
		jumpBeam.Color = ColorSequence.new(Color3.fromRGB(255, 255, 40), Color3.fromRGB(255, 40, 40))
		jumpBeam.Transparency = NumberSequence.new(0)
		jumpBeam.Parent = currentFloor.body
		beam = jumpBeam

		task.spawn(function()
			local on = false
			while visualToken == token do
				on = not on
				if currentFloor.dropped or currentFloor.body.Parent == nil then
					break
				end
				local flash = if on then Color3.new(1, 1, 1) else Color3.fromRGB(255, 0, 30)
				paint(currentFloor, flash)
				currentFloor.label.BackgroundColor3 = if on then Color3.new(1, 1, 1) else Color3.fromRGB(255, 0, 30)
				currentFloor.label.TextColor3 = if on then Color3.fromRGB(180, 0, 20) else Color3.new(1, 1, 1)
				currentFloor.highlight.FillColor = flash
				currentFloor.highlight.FillTransparency = if on then 0.15 else 0.45
				currentFloor.highlight.OutlineColor = Color3.new(1, 1, 1)
				task.wait(0.1)
			end
		end)
	end
end

function Tower.celebratePay(index: number)
	local floor = floors[index]
	if not floor or floor.dropped then
		return
	end
	local gold = Color3.fromRGB(255, 244, 180)
	paint(floor, gold)
	floor.highlight.FillColor = gold
	floor.highlight.FillTransparency = 0.45
	playAt(floor.body, PAY_SOUND, 0.7)
end

function Tower.drop(index: number)
	visualToken += 1
	clearBeam()

	local floor = floors[index]
	if not floor or floor.dropped then
		return
	end
	floor.dropped = true
	floor.pad.CanCollide = false
	floor.pad.CollisionGroup = Config.Groups.Ghost
	floor.light.Enabled = false
	floor.label.Text = ""
	paint(floor, floor.baseColor)
	playAt(floor.body, DROP_SOUND, 0.55)

	local model = floor.model
	task.spawn(function()
		local startPivot = model:GetPivot()
		local duration = Config.DropDuration
		local started = os.clock()
		while model.Parent do
			local alpha = math.clamp((os.clock() - started) / duration, 0, 1)
			local eased = alpha * alpha
			model:PivotTo(startPivot + Vector3.new(0, -42 * eased, 0))
			floor.body.Transparency = eased
			floor.trim.Transparency = eased
			if alpha >= 1 then
				break
			end
			task.wait()
		end
		if model.Parent then
			model:Destroy()
		end
	end)
end

function Tower.playWin()
	local sound = Instance.new("Sound")
	sound.SoundId = WIN_SOUND
	sound.Volume = 0.7
	sound.Parent = SoundService
	sound:Play()
	Debris:AddItem(sound, 5)
end

return Tower

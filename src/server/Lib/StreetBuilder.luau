--!strict
-- Greybox Skid Row (GDD M0 step 4, §3.2, §21.3). Builds Workspace.Street when the place file
-- doesn't already contain one, so a fresh place is playable straight from the repo. Replace it
-- with an art pass in the place file later: services only depend on the names below.
--
-- Street
--   Plots/Plot_<n>  (Model, attrs PlotId, OwnerUserId)
--     Base          (PrimaryPart; attachments HouseAnchor, Slot1..SlotN, Nameplate, CarPad, HeliPad)
--     ClaimPad      (ProximityPrompt "ClaimPrompt")
--   Stage           (Platform, Podium, Jumbotron w/ SurfaceGui, RescueKiosk, CameraSpot attachments)
--   Road, Spawn

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)

local StreetBuilder = {}

local GREY = Color3.fromRGB(150, 150, 150)
local ROAD = Color3.fromRGB(60, 60, 66)

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in props do
		(p :: any)[k] = v
	end
	return p
end

local function attach(parent: BasePart, name: string, offset: Vector3): Attachment
	local a = Instance.new("Attachment")
	a.Name = name
	a.Position = offset
	a.Parent = parent
	return a
end

local function label(parent: Instance, text: string, size: UDim2): TextLabel
	local t = Instance.new("TextLabel")
	t.Name = "Text"
	t.Size = size
	t.BackgroundTransparency = 1
	t.TextScaled = true
	t.Font = Enum.Font.GothamBold
	t.TextColor3 = Color3.new(1, 1, 1)
	t.TextStrokeTransparency = 0.4
	t.Text = text
	t.Parent = parent
	return t
end

local function buildPlot(plotId: number, cframe: CFrame): Model
	local m = Config.Map
	local model = Instance.new("Model")
	model.Name = `Plot_{plotId}`
	model:SetAttribute("PlotId", plotId)
	model:SetAttribute("OwnerUserId", 0)

	-- Local space: -Z faces the road.
	local base = part({
		Name = "Base",
		Size = Vector3.new(m.PlotSize, 1, m.PlotSize),
		CFrame = cframe,
		Color = Color3.fromRGB(110, 140, 95),
		Material = Enum.Material.Grass,
	})
	base.Parent = model
	model.PrimaryPart = base

	local half = m.PlotSize / 2
	attach(base, "HouseAnchor", Vector3.new(0, 0.5, half * 0.45))
	-- Property slots: two rows of four across the front half of the plot.
	for i = 1, m.PropertySlotCount do
		local col = (i - 1) % 4
		local row = math.floor((i - 1) / 4)
		local x = (col - 1.5) * (m.PlotSize / 4.5)
		local z = -half * 0.15 - row * (m.PlotSize / 4.5)
		attach(base, `Slot{i}`, Vector3.new(x, 0.5, z))
	end
	attach(base, "CarPad", Vector3.new(half * 0.75, 0.5, half * 0.2))
	attach(base, "HeliPad", Vector3.new(-half * 0.75, 0.5, half * 0.6))
	local nameplate = attach(base, "Nameplate", Vector3.new(0, 14, -half + 3))

	local gui = Instance.new("BillboardGui")
	gui.Name = "NameplateGui"
	gui.Size = UDim2.fromScale(14, 4)
	gui.MaxDistance = 250
	gui.AlwaysOnTop = false
	gui.Adornee = nameplate
	label(gui, `Plot {plotId}\nFOR RENT`, UDim2.fromScale(1, 1))
	gui.Parent = base

	local pad = part({
		Name = "ClaimPad",
		Size = Vector3.new(8, 0.4, 8),
		CFrame = cframe * CFrame.new(0, 0.7, -half + 6),
		Color = Color3.fromRGB(240, 200, 60),
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ClaimPrompt"
	prompt.ActionText = "Claim plot"
	prompt.ObjectText = `Plot {plotId}`
	prompt.HoldDuration = 0.25
	prompt.MaxActivationDistance = m.ClaimPromptDistance
	prompt.RequiresLineOfSight = false
	prompt.Parent = pad
	pad.Parent = model

	return model
end

local function buildStage(parent: Instance)
	local m = Config.Map
	local stage = Instance.new("Model")
	stage.Name = "Stage"

	local platform = part({
		Name = "Platform",
		Size = m.StageSize,
		CFrame = CFrame.new(0, m.StageSize.Y / 2, 0),
		Color = Color3.fromRGB(120, 30, 30),
		Material = Enum.Material.WoodPlanks,
	})
	platform.Parent = stage
	stage.PrimaryPart = platform

	local top = m.StageSize.Y
	part({
		Name = "Podium",
		Size = Vector3.new(4, 4, 2),
		CFrame = CFrame.new(0, top + 2, 0),
		Color = Color3.fromRGB(200, 170, 90),
		Material = Enum.Material.Wood,
	}).Parent =
		stage

	-- Jumbotron stands on the stage and faces both rows (two-sided SurfaceGui).
	local jumbo = part({
		Name = "Jumbotron",
		Size = m.JumbotronSize,
		CFrame = CFrame.new(0, top + m.JumbotronSize.Y / 2 + 6, m.StageSize.Z / 2 - 1),
		Color = Color3.fromRGB(20, 20, 24),
	})
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local sg = Instance.new("SurfaceGui")
		sg.Name = `Screen{face.Name}`
		sg.Face = face
		sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		sg.PixelsPerStud = 25
		label(sg, "BANKRUPT STREET\nNo auction live", UDim2.fromScale(1, 1)).TextColor3 = Color3.fromRGB(255, 215, 90)
		sg.Parent = jumbo
	end
	jumbo.Parent = stage

	part({
		Name = "RescueKiosk",
		Size = Vector3.new(4, 6, 4),
		CFrame = CFrame.new(m.StageSize.X / 2 + 5, 3, 0),
		Color = Color3.fromRGB(60, 160, 90),
	}).Parent =
		stage

	-- Spectator camera spots on each side of the stage.
	attach(platform, "CameraSpotFront", Vector3.new(0, 12, -m.RoadHalfWidth))
	attach(platform, "CameraSpotBack", Vector3.new(0, 12, m.RoadHalfWidth))
	attach(platform, "CameraSpotTop", Vector3.new(0, 40, 0))

	stage.Parent = parent
end

-- Plot n's CFrame: plots alternate rows (odd = -Z side, even = +Z side), facing the road.
function StreetBuilder.plotCFrame(plotId: number, plotCount: number): CFrame
	local m = Config.Map
	local perRow = math.ceil(plotCount / 2)
	local index = math.floor((plotId - 1) / 2) -- 0-based position in its row
	local side = if plotId % 2 == 1 then -1 else 1
	local x = (index - (perRow - 1) / 2) * m.PlotSpacing
	local z = side * (m.RoadHalfWidth + m.PlotSize / 2)
	local pos = Vector3.new(x, 0.5, z)
	return CFrame.lookAt(pos, Vector3.new(x, 0.5, 0))
end

function StreetBuilder.build(): Model
	local m = Config.Map
	local street = Instance.new("Model")
	street.Name = "Street"
	street:SetAttribute("StreetId", Config.StreetIds[1])

	local perRow = math.ceil(Config.PlotCount / 2)
	local length = perRow * m.PlotSpacing + m.SpawnOffsetX * 2 + 20
	part({
		Name = "Road",
		Size = Vector3.new(length, 1, m.RoadHalfWidth * 2),
		CFrame = CFrame.new(0, 0, 0),
		Color = ROAD,
		Material = Enum.Material.Asphalt,
	}).Parent =
		street
	-- Sidewalk/ground under the plots.
	part({
		Name = "Ground",
		Size = Vector3.new(length, 1, (m.RoadHalfWidth + m.PlotSize + 10) * 2),
		CFrame = CFrame.new(0, -0.5, 0),
		Color = GREY,
		Material = Enum.Material.Concrete,
	}).Parent =
		street

	local plots = Instance.new("Folder")
	plots.Name = "Plots"
	for id = 1, Config.PlotCount do
		buildPlot(id, StreetBuilder.plotCFrame(id, Config.PlotCount)).Parent = plots
	end
	plots.Parent = street

	buildStage(street)

	local spawnX = (perRow - 1) / 2 * m.PlotSpacing + m.SpawnOffsetX
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.CFrame = CFrame.new(spawnX, 1, 0)
	spawn.Color = Color3.fromRGB(230, 230, 230)
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.Parent = street

	street.PrimaryPart = street:FindFirstChild("Road") :: BasePart
	return street
end

return StreetBuilder

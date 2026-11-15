--!strict
-- Plots (GDD §3.2, M1 item 5). One plot per player per session; leaving frees it. Progress is
-- saved on the account, not the plot, so on join the player is given the first free plot and
-- their house and properties are rebuilt on it. The street has PlotCount = MaxPlayersPerStreet
-- plots, so a free plot always exists; the claim prompt stays as a fallback.
--
-- There is deliberately no "release plot" request: players without a plot skip rent (§6.3),
-- so letting them drop it on purpose would dodge rent.
--
-- Replicated state:  Plot model attr OwnerUserId (0 = free); Player attr PlotId (0 = none).
-- Built visuals go in Plot_<n>.Built (cleared on release); House/Property services fill it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Enums = require(Shared.Enums)
local Types = require(Shared.Types)
local Lib = script.Parent.Parent.Lib
local Signal = require(Lib.Signal)
local StreetBuilder = require(Lib.StreetBuilder)
local Net = require(script.Parent.Net)
local ProfileManager = require(script.Parent.ProfileManager)

local PlotService = {}

-- Fired after a player gets a plot (player, plotId) / loses it (player, plotId).
PlotService.assigned = Signal.new() :: Signal.Signal<Player, number>
PlotService.released = Signal.new() :: Signal.Signal<Player, number>

local plots: { [number]: Model } = {}
local ownerOf: { [number]: Player } = {} -- plotId -> player
local plotOf: { [Player]: number } = {} -- player -> plotId

local function setNameplate(plot: Model, text: string)
	local base = plot:FindFirstChild("Base")
	local gui = base and base:FindFirstChild("NameplateGui")
	local textLabel = gui and gui:FindFirstChild("Text")
	if textLabel and textLabel:IsA("TextLabel") then
		textLabel.Text = text
	end
end

local function setPromptEnabled(plot: Model, enabled: boolean)
	local pad = plot:FindFirstChild("ClaimPad")
	local prompt = pad and pad:FindFirstChild("ClaimPrompt")
	if prompt and prompt:IsA("ProximityPrompt") then
		prompt.Enabled = enabled
	end
end

local function refreshPlot(plotId: number)
	local plot = plots[plotId]
	local owner = ownerOf[plotId]
	if owner then
		local profile = ProfileManager.get(owner)
		local house = if profile then Config.HouseDisplayNames[profile.houseLevel] else ""
		setNameplate(plot, `{owner.DisplayName}\n{house}`)
		setPromptEnabled(plot, false)
	else
		setNameplate(plot, `Plot {plotId}\nFOR RENT`)
		setPromptEnabled(plot, true)
	end
end

local function builtFolder(plot: Model): Folder
	local folder = plot:FindFirstChild("Built")
	if folder and folder:IsA("Folder") then
		return folder
	end
	local f = Instance.new("Folder")
	f.Name = "Built"
	f.Parent = plot
	return f
end

local function base(plot: Model): BasePart
	return plot:FindFirstChild("Base") :: BasePart
end

-- Put the character on its plot, on the road side, facing the house.
local function spawnOnPlot(player: Player)
	local plotId = plotOf[player]
	local character = player.Character
	if not plotId or not character then
		return
	end
	local pad = plots[plotId]:FindFirstChild("ClaimPad") :: BasePart?
	local anchor = PlotService.anchorCFrame(plotId, "HouseAnchor")
	if pad and anchor then
		local pos = pad.Position + Vector3.new(0, 4, 0)
		character:PivotTo(CFrame.lookAt(pos, Vector3.new(anchor.Position.X, pos.Y, anchor.Position.Z)))
	end
end

-- Public API -----------------------------------------------------------------------------

function PlotService.getPlotId(player: Player): number?
	return plotOf[player]
end

function PlotService.getPlot(plotId: number): Model?
	return plots[plotId]
end

function PlotService.getBuilt(player: Player): Folder?
	local plotId = plotOf[player]
	return if plotId then builtFolder(plots[plotId]) else nil
end

-- World CFrame of a named attachment on a plot's Base (HouseAnchor, Slot1..8, CarPad, ...).
function PlotService.anchorCFrame(plotId: number, name: string): CFrame?
	local plot = plots[plotId]
	local att = plot and base(plot):FindFirstChild(name)
	if att and att:IsA("Attachment") then
		return att.WorldCFrame
	end
	return nil
end

-- Re-render the nameplate (call after a house change).
function PlotService.refreshFor(player: Player)
	local plotId = plotOf[player]
	if plotId then
		refreshPlot(plotId)
	end
end

function PlotService.claim(player: Player, plotId: number): Types.NetResult
	if not ProfileManager.get(player) then
		return Net.fail(Enums.Error.NotLoaded, "Still loading your data.")
	end
	local plot = plots[plotId]
	if not plot then
		return Net.fail(Enums.Error.BadRequest, "That plot doesn't exist.")
	end
	if plotOf[player] then
		return Net.fail(Enums.Error.AlreadyHasPlot, "You already have a plot.")
	end
	if ownerOf[plotId] then
		return Net.fail(Enums.Error.Occupied, "Someone already lives here.")
	end
	-- No yields between the checks above and these writes, so two claims can't both win.
	ownerOf[plotId] = player
	plotOf[player] = plotId
	plot:SetAttribute("OwnerUserId", player.UserId)
	player:SetAttribute("PlotId", plotId)
	refreshPlot(plotId)
	print(`[PlotService] {player.Name} claimed plot {plotId}`)
	spawnOnPlot(player)
	PlotService.assigned:fire(player, plotId)
	return Net.ok({ plotId = plotId })
end

function PlotService.release(player: Player): boolean
	local plotId = plotOf[player]
	if not plotId then
		return false
	end
	plotOf[player] = nil
	ownerOf[plotId] = nil
	local plot = plots[plotId]
	plot:SetAttribute("OwnerUserId", 0)
	builtFolder(plot):ClearAllChildren()
	if player.Parent then
		player:SetAttribute("PlotId", 0)
	end
	refreshPlot(plotId)
	print(`[PlotService] {player.Name} released plot {plotId}`)
	PlotService.released:fire(player, plotId)
	return true
end

-- Give the player the lowest-numbered free plot, if any.
function PlotService.assignFree(player: Player): number?
	if plotOf[player] then
		return plotOf[player]
	end
	for id = 1, Config.PlotCount do
		if plots[id] and not ownerOf[id] then
			if PlotService.claim(player, id).ok then
				return id
			end
		end
	end
	return nil
end

local function withinReach(player: Player, plot: Model): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local pad = plot:FindFirstChild("ClaimPad")
	if not (root and root:IsA("BasePart") and pad and pad:IsA("BasePart")) then
		return false
	end
	return (root.Position - pad.Position).Magnitude <= Config.MaxInteractDistance
end

function PlotService.Init(_self: any)
	local street = Workspace:FindFirstChild("Street")
	if not street then
		street = StreetBuilder.build()
		street.Parent = Workspace
		print("[PlotService] built greybox street")
	end
	assert(street, "no street")
	-- Only the street's spawn is used.
	for _, d in Workspace:GetDescendants() do
		if d:IsA("SpawnLocation") and not d:IsDescendantOf(street) then
			d.Enabled = false
		end
	end

	local folder = street:FindFirstChild("Plots")
	assert(folder, "Street.Plots missing")
	for _, plot in folder:GetChildren() do
		local id = plot:GetAttribute("PlotId")
		if plot:IsA("Model") and type(id) == "number" then
			plots[id] = plot
		end
	end
	local count = 0
	for id, plot in plots do
		count += 1
		plot:SetAttribute("OwnerUserId", 0)
		builtFolder(plot)
		refreshPlot(id)
		local pad = plot:FindFirstChild("ClaimPad")
		local prompt = pad and pad:FindFirstChild("ClaimPrompt")
		if prompt and prompt:IsA("ProximityPrompt") then
			prompt.Triggered:Connect(function(player)
				local result = PlotService.claim(player, id)
				if not result.ok then
					Net.push(player, Enums.Push.Notice, result.message)
				end
			end)
		end
	end
	if count ~= Config.PlotCount then
		warn(`[PlotService] street has {count} plots, Config.PlotCount is {Config.PlotCount}`)
	end

	Net.register("ClaimPlot", function(player, payload)
		local plotId = payload.plotId
		if type(plotId) ~= "number" or not plots[plotId] then
			return Net.fail(Enums.Error.BadRequest, "Bad plot.")
		end
		if plotOf[player] then
			return Net.fail(Enums.Error.AlreadyHasPlot, "You already have a plot.")
		end
		if not withinReach(player, plots[plotId]) then
			return Net.fail(Enums.Error.TooFar, "Walk up to the plot to claim it.")
		end
		return PlotService.claim(player, plotId)
	end)
end

function PlotService.Start(_self: any)
	local function onPlayerAdded(player: Player)
		player:SetAttribute("PlotId", 0)
		player.CharacterAdded:Connect(function()
			-- Wait a frame so the default spawn placement doesn't override ours.
			task.defer(spawnOnPlot, player)
		end)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		if player:GetAttribute("PlotId") == nil then
			onPlayerAdded(player)
		end
	end
	Players.PlayerRemoving:Connect(function(player)
		PlotService.release(player)
	end)
	ProfileManager.onLoaded(function(player)
		if plotOf[player] then
			-- Reloaded (Studio debug relog): rebuild what's on the plot.
			refreshPlot(plotOf[player])
			PlotService.assigned:fire(player, plotOf[player])
		elseif not PlotService.assignFree(player) then
			Net.push(player, Enums.Push.Notice, "The street is full. Claim a plot when one frees up.")
		end
	end)
end

return PlotService

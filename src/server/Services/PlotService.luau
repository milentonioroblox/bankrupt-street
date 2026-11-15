--!strict
-- Plot claiming (GDD §3.2). One plot per player per session; leaving frees it. Progress is
-- saved on the account, not the plot. Ownership replicates as attributes:
--   Plot model:  OwnerUserId (0 = free)
--   Player:      PlotId (0 = none)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Enums = require(Shared.Enums)
local Types = require(Shared.Types)
local StreetBuilder = require(script.Parent.Parent.Lib.StreetBuilder)
local Net = require(script.Parent.Net)
local ProfileManager = require(script.Parent.ProfileManager)

local PlotService = {}

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

function PlotService.getPlotId(player: Player): number?
	return plotOf[player]
end

function PlotService.getPlot(plotId: number): Model?
	return plots[plotId]
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
	return Net.ok({ plotId = plotId })
end

function PlotService.release(player: Player): boolean
	local plotId = plotOf[player]
	if not plotId then
		return false
	end
	plotOf[player] = nil
	ownerOf[plotId] = nil
	plots[plotId]:SetAttribute("OwnerUserId", 0)
	if player.Parent then
		player:SetAttribute("PlotId", 0)
	end
	refreshPlot(plotId)
	print(`[PlotService] {player.Name} released plot {plotId}`)
	return true
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
	Net.register("ReleasePlot", function(player)
		if not PlotService.release(player) then
			return Net.fail(Enums.Error.NoPlot, "You don't have a plot.")
		end
		return Net.ok(nil)
	end)
end

function PlotService.Start(_self: any)
	local function onPlayerAdded(player: Player)
		player:SetAttribute("PlotId", 0)
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
	-- House name on the nameplate comes from the profile; refresh when it loads.
	ProfileManager.onLoaded(function(player)
		local plotId = plotOf[player]
		if plotId then
			refreshPlot(plotId)
		end
	end)
end

return PlotService

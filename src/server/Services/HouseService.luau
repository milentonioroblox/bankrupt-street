--!strict
-- House levels (GDD §4, M1 item 7). Upgrades are sequential: the server charges
-- HouseUpgradeCost[level + 1] from spendable cash and only if houseLevel == target - 1.
-- All 10 levels work; each has a distinct greybox silhouette (Lib/Greybox).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Enums = require(Shared.Enums)
local Types = require(Shared.Types)
local Greybox = require(script.Parent.Parent.Lib.Greybox)
local EconomyService = require(script.Parent.EconomyService)
local Net = require(script.Parent.Net)
local PlotService = require(script.Parent.PlotService)
local ProfileManager = require(script.Parent.ProfileManager)

local HouseService = {}

function HouseService.render(player: Player)
	local profile = ProfileManager.get(player)
	local plotId = PlotService.getPlotId(player)
	local built = PlotService.getBuilt(player)
	if not (profile and plotId and built) then
		return
	end
	local old = built:FindFirstChild("House")
	if old then
		old:Destroy()
	end
	local anchor = PlotService.anchorCFrame(plotId, "HouseAnchor")
	if anchor then
		local model = Greybox.house(profile.houseLevel, anchor)
		model:SetAttribute("HouseLevel", profile.houseLevel)
		model.Parent = built
	end
	PlotService.refreshFor(player)
end

-- Set the level directly (debug /sethouse, later bankruptcy and deeds). Rebuilds the plot.
function HouseService.setLevel(player: Player, level: number): boolean
	local profile = ProfileManager.get(player)
	if not profile or level % 1 ~= 0 or level < 1 or level > Config.MaxHouseLevel then
		return false
	end
	profile.houseLevel = level
	HouseService.render(player)
	ProfileManager.push(player)
	return true
end

function HouseService.upgrade(player: Player): Types.NetResult
	local profile = ProfileManager.get(player)
	if not profile then
		return Net.fail(Enums.Error.NotLoaded, "Still loading your data.")
	end
	if not PlotService.getPlotId(player) then
		return Net.fail(Enums.Error.NoPlot, "Claim a plot first.")
	end
	local target = profile.houseLevel + 1
	if target > Config.MaxHouseLevel then
		return Net.fail(Enums.Error.Max, "You already own the top house.")
	end
	local cost = Config.HouseUpgradeCost[target]
	if not EconomyService.spend(player, cost, "upgrade_house") then
		return Net.fail(Enums.Error.CannotAfford, "Not enough cash.")
	end
	profile.houseLevel = target
	print(`[HouseService] {player.Name} upgraded to {Config.HouseDisplayNames[target]} for ${cost}`)
	HouseService.render(player)
	ProfileManager.push(player)
	ProfileManager.save(player, "upgrade_house")
	return Net.ok({ newLevel = target, cash = profile.cash })
end

function HouseService.Init(_self: any)
	Net.register("UpgradeHouse", function(player)
		return HouseService.upgrade(player)
	end, Config.RateLimit.Shop)
end

function HouseService.Start(_self: any)
	PlotService.assigned:connect(function(player)
		HouseService.render(player)
	end)
end

return HouseService

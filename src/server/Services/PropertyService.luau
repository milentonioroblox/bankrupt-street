--!strict
-- Income properties: buy, place, sell, slots (GDD §5.1, §5.4, §17.4, M1 item 7).
--
-- Buy:   catalog id must exist, street tier >= minStreet, house level >= minHouse, a free slot
--        (HousePropertySlots[houseLevel]), and spendable cash >= cost. Price comes from Config,
--        never from the client.
-- Place: move to another slot on your own plot; swaps if the target slot is taken. Free.
-- Sell:  floor(cost * SellBackRatio) back; refused while boundUntil > now (auction bind) or when
--        co-owned (Heist; needs 100% consent, not built yet).

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Enums = require(Shared.Enums)
local Formulas = require(Shared.Formulas)
local Types = require(Shared.Types)
local Greybox = require(script.Parent.Parent.Lib.Greybox)
local EconomyService = require(script.Parent.EconomyService)
local Net = require(script.Parent.Net)
local PlotService = require(script.Parent.PlotService)
local ProfileManager = require(script.Parent.ProfileManager)

local PropertyService = {}

local function slotsMax(profile: Types.Profile): number
	return Config.HousePropertySlots[profile.houseLevel] or 0
end

local function usedSlots(profile: Types.Profile): { [number]: Types.PropertyInstance }
	local used = {}
	for _, inst in profile.properties do
		used[inst.slotIndex] = inst
	end
	return used
end

local function findInstance(profile: Types.Profile, instanceId: string): (Types.PropertyInstance?, number?)
	for i, inst in profile.properties do
		if inst.instanceId == instanceId then
			return inst, i
		end
	end
	return nil, nil
end

-- Rebuild every property model on the player's plot from the profile.
function PropertyService.render(player: Player)
	local profile = ProfileManager.get(player)
	local plotId = PlotService.getPlotId(player)
	local built = PlotService.getBuilt(player)
	if not (profile and plotId and built) then
		return
	end
	for _, child in built:GetChildren() do
		if child:GetAttribute("InstanceId") then
			child:Destroy()
		end
	end
	for _, inst in profile.properties do
		local def = Config.PropertiesById[inst.propertyId]
		local anchor = PlotService.anchorCFrame(plotId, `Slot{inst.slotIndex}`)
		if def and anchor then
			local model = Greybox.property(def.id, def.type, def.cost, anchor)
			model:SetAttribute("InstanceId", inst.instanceId)
			model:SetAttribute("PropertyId", def.id)
			model.Parent = built
		end
	end
end

-- Repair a loaded profile: drop unknown catalog ids, and move properties with a bad or
-- duplicate slot (or beyond the current slot count) into a free slot or the overflow list.
local function normalize(player: Player, profile: Types.Profile)
	local max = slotsMax(profile)
	local kept: { Types.PropertyInstance } = {}
	local used: { [number]: boolean } = {}
	local homeless: { Types.PropertyInstance } = {}
	for _, inst in profile.properties do
		if not Config.PropertiesById[inst.propertyId] then
			warn(`[PropertyService] {player.UserId}: dropping unknown property {inst.propertyId}`)
		elseif
			type(inst.slotIndex) == "number"
			and inst.slotIndex >= 1
			and inst.slotIndex <= max
			and not used[inst.slotIndex]
		then
			used[inst.slotIndex] = true
			table.insert(kept, inst)
		else
			table.insert(homeless, inst)
		end
	end
	for _, inst in homeless do
		local slot = Formulas.firstFreeSlot(used, max)
		if slot then
			inst.slotIndex = slot
			used[slot] = true
			table.insert(kept, inst)
		else
			table.insert(profile.pendingProperties, inst)
			warn(`[PropertyService] {player.UserId}: {inst.propertyId} moved to overflow (no slot)`)
		end
	end
	profile.properties = kept
end

function PropertyService.buy(player: Player, propertyId: any, slotIndex: any): Types.NetResult
	local profile = ProfileManager.get(player)
	if not profile then
		return Net.fail(Enums.Error.NotLoaded, "Still loading your data.")
	end
	if type(propertyId) ~= "string" then
		return Net.fail(Enums.Error.BadRequest, "Bad property.")
	end
	local def = Config.PropertiesById[propertyId]
	if not def then
		return Net.fail(Enums.Error.BadRequest, "Bad property.")
	end
	if not PlotService.getPlotId(player) then
		return Net.fail(Enums.Error.NoPlot, "Claim a plot first.")
	end
	if profile.streetTier < def.minStreet then
		return Net.fail(Enums.Error.Locked, `Unlocks on {Config.StreetNames[def.minStreet]}.`)
	end
	if profile.houseLevel < def.minHouse then
		return Net.fail(Enums.Error.Locked, `Needs a {Config.HouseDisplayNames[def.minHouse]}.`)
	end
	local max = slotsMax(profile)
	local used = usedSlots(profile)
	local slot: number?
	if slotIndex == nil then
		slot = Formulas.firstFreeSlot(used, max)
	elseif
		type(slotIndex) == "number"
		and slotIndex >= 1
		and slotIndex <= max
		and slotIndex % 1 == 0
		and not used[slotIndex]
	then
		slot = slotIndex
	end
	if not slot then
		return Net.fail(Enums.Error.NoSlot, `No free slot ({#profile.properties}/{max}). Upgrade your house for more.`)
	end
	if not EconomyService.spend(player, def.cost, "buy_property") then
		return Net.fail(Enums.Error.CannotAfford, "Not enough cash.")
	end
	local now = os.time()
	local inst: Types.PropertyInstance = {
		instanceId = HttpService:GenerateGUID(false),
		propertyId = def.id,
		ownerUserIds = { player.UserId },
		shares = { 1.0 },
		slotIndex = slot,
		acquiredAt = now,
		acquiredHow = Enums.AcquiredHow.Bought,
		boundUntil = 0,
		history = { { userId = player.UserId, displayName = player.DisplayName, at = now, reason = "bought" } },
	}
	table.insert(profile.properties, inst)
	PropertyService.render(player)
	ProfileManager.push(player)
	ProfileManager.save(player, "buy_property")
	return Net.ok({ instance = inst })
end

function PropertyService.sell(player: Player, instanceId: any): Types.NetResult
	local profile = ProfileManager.get(player)
	if not profile then
		return Net.fail(Enums.Error.NotLoaded, "Still loading your data.")
	end
	if type(instanceId) ~= "string" then
		return Net.fail(Enums.Error.BadRequest, "Bad property.")
	end
	local inst, index = findInstance(profile, instanceId)
	if not inst or not index then
		return Net.fail(Enums.Error.NotFound, "You don't own that.")
	end
	if inst.boundUntil > os.time() then
		return Net.fail(Enums.Error.Bound, "Won at auction: can't sell it yet.")
	end
	if #inst.ownerUserIds > 1 then
		return Net.fail(Enums.Error.NeedConsent, "All co-owners must agree to sell.")
	end
	local def = Config.PropertiesById[inst.propertyId]
	local price = if def then Formulas.sellPrice(def.cost, Config.SellBackRatio) else 0
	table.remove(profile.properties, index)
	if price > 0 then
		EconomyService.grant(player, price, "sell_property", false)
	end
	PropertyService.render(player)
	ProfileManager.push(player)
	ProfileManager.save(player, "sell_property")
	return Net.ok({ cash = profile.cash, price = price })
end

function PropertyService.place(player: Player, instanceId: any, slotIndex: any): Types.NetResult
	local profile = ProfileManager.get(player)
	if not profile then
		return Net.fail(Enums.Error.NotLoaded, "Still loading your data.")
	end
	if type(instanceId) ~= "string" or type(slotIndex) ~= "number" or slotIndex % 1 ~= 0 then
		return Net.fail(Enums.Error.BadRequest, "Bad request.")
	end
	if slotIndex < 1 or slotIndex > slotsMax(profile) then
		return Net.fail(Enums.Error.NoSlot, "That slot isn't unlocked.")
	end
	local inst = findInstance(profile, instanceId)
	if not inst then
		return Net.fail(Enums.Error.NotFound, "You don't own that.")
	end
	local other = usedSlots(profile)[slotIndex]
	if other and other ~= inst then
		other.slotIndex = inst.slotIndex -- swap
	end
	inst.slotIndex = slotIndex
	PropertyService.render(player)
	ProfileManager.push(player)
	return Net.ok({})
end

-- Debug/admin: grant a property for free into a free slot (GDD §23 /giveprop).
function PropertyService.give(player: Player, propertyId: string): boolean
	local profile = ProfileManager.get(player)
	local def = Config.PropertiesById[propertyId]
	if not (profile and def) then
		return false
	end
	local slot = Formulas.firstFreeSlot(usedSlots(profile), slotsMax(profile))
	if not slot then
		return false
	end
	local now = os.time()
	table.insert(profile.properties, {
		instanceId = HttpService:GenerateGUID(false),
		propertyId = def.id,
		ownerUserIds = { player.UserId },
		shares = { 1.0 },
		slotIndex = slot,
		acquiredAt = now,
		acquiredHow = Enums.AcquiredHow.Admin,
		boundUntil = 0,
		history = { { userId = player.UserId, displayName = player.DisplayName, at = now, reason = "admin" } },
	})
	PropertyService.render(player)
	ProfileManager.push(player)
	return true
end

function PropertyService.Init(_self: any)
	Net.register("BuyProperty", function(player, payload)
		return PropertyService.buy(player, payload.propertyId, payload.slotIndex)
	end, Config.RateLimit.Shop)
	Net.register("SellProperty", function(player, payload)
		return PropertyService.sell(player, payload.instanceId)
	end, Config.RateLimit.Shop)
	Net.register("PlaceProperty", function(player, payload)
		return PropertyService.place(player, payload.instanceId, payload.slotIndex)
	end)
end

function PropertyService.Start(_self: any)
	ProfileManager.onLoaded(function(player, profile)
		normalize(player, profile)
		-- The plot may already be assigned (callbacks run in any order); draw the repaired list.
		PropertyService.render(player)
		ProfileManager.push(player)
	end)
	PlotService.assigned:connect(function(player)
		PropertyService.render(player)
	end)
end

return PropertyService

--!strict
-- Income rates for a profile (GDD §5.2, §5.3, v1.1 §1). Shared by IncomeService (payouts),
-- ProfileManager (HUD slice) and later RentService, so every caller agrees on the numbers.
--
--   effectiveIncomePerMinute =
--       sum(baseIncomePerMinute) * streetIncomeMultiplier * (1 + 0.15 * rebirthCount)
--       * (comebackActive and 2 or 1) * (evictionNightActive and 2 or 1)
--   offline = base * street * rebirth * OfflineIncomeRate * (VIP and 2 or 1)   -- no comeback/events

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Formulas = require(Shared.Formulas)
local Types = require(Shared.Types)

local IncomeMath = {}

-- Raw catalog sum: what rent taxes (GDD §6.2).
function IncomeMath.basePerMinute(profile: Types.Profile): number
	local total = 0
	for _, inst in profile.properties do
		local def = Config.PropertiesById[inst.propertyId]
		if def then
			total += def.incomePerMinute
		end
	end
	return total
end

function IncomeMath.comebackActive(profile: Types.Profile, now: number): boolean
	return profile.comebackBoostUntil > now
end

-- Online rate. `eventMultiplier` is the Eviction Night reward multiplier (1 when inactive).
function IncomeMath.effectivePerMinute(profile: Types.Profile, now: number, eventMultiplier: number?): number
	return Formulas.incomePerMinute({
		baseIncomePerMinute = IncomeMath.basePerMinute(profile),
		streetIncomeMultiplier = Config.StreetIncomeMultiplier[profile.streetTier] or 1,
		rebirthCount = profile.rebirthCount,
		rebirthBonusPerRebirth = Config.RebirthIncomeBonusPerRebirth,
		comebackMultiplier = if IncomeMath.comebackActive(profile, now) then Config.ComebackIncomeMultiplier else 1,
		eventRewardMultiplier = eventMultiplier or 1,
	})
end

-- Cash earned while away for `elapsedSeconds` (capped).
function IncomeMath.offlineCash(profile: Types.Profile, elapsedSeconds: number): number
	local rate = Formulas.incomePerMinute({
		baseIncomePerMinute = IncomeMath.basePerMinute(profile),
		streetIncomeMultiplier = Config.StreetIncomeMultiplier[profile.streetTier] or 1,
		rebirthCount = profile.rebirthCount,
		rebirthBonusPerRebirth = Config.RebirthIncomeBonusPerRebirth,
		comebackMultiplier = 1,
		eventRewardMultiplier = 1,
	})
	local vip = if profile.gamepassesCached.VIPLandlord then Config.VIPOfflineIncomeMultiplier else 1
	return Formulas.offlineCash(rate, elapsedSeconds, Config.OfflineIncomeCapSeconds, Config.OfflineIncomeRate, vip)
end

return IncomeMath

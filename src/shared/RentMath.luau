--!strict
-- Rent for a profile-shaped table (GDD §6.2, §13.5, v1.1 §2), shared so the server's charge and
-- the client's "next rent" / rent-safety projection always agree.
--
--   raw  = sum(baseIncomePerMinute) * (RentIntervalSeconds / 60) * RentToIncomeRatio + HouseRent[level]
--   rent = max(MinRent, floor(raw * StreetRentMultiplier * (eviction 2) * (crash 3)))
--
-- Rent taxes the raw catalog income, before comeback/rebirth/street boosts.

local Config = require(script.Parent.Config)
local Formulas = require(script.Parent.Formulas)

local RentMath = {}

export type Holdings = {
	houseLevel: number,
	streetTier: number,
	properties: { { propertyId: string } },
}

function RentMath.baseIncomePerMinute(h: Holdings): number
	local total = 0
	for _, inst in h.properties do
		local def = Config.PropertiesById[inst.propertyId]
		if def then
			total += def.incomePerMinute
		end
	end
	return total
end

function RentMath.rent(h: Holdings, crash: boolean, evictionNight: boolean): number
	return Formulas.rent({
		baseIncomePerMinute = RentMath.baseIncomePerMinute(h),
		cycleMinutes = Config.RentIntervalSeconds / 60,
		rentToIncomeRatio = Config.RentToIncomeRatio,
		houseRent = Config.HouseRent[h.houseLevel] or 0,
		streetRentMultiplier = Config.StreetRentMultiplier[h.streetTier] or 1,
		evictionMultiplier = if evictionNight then Config.EvictionNight.RentMultiplier else 1,
		crashMultiplier = if crash then Config.CrashRentMultiplier else 1,
		minRent = Config.MinRent,
	})
end

-- Is a rent tick at time `t` inside the crash window (start, end]? The window's last second is
-- the crash rent tick, so a 300s window with 300s rent covers exactly one tick (v1.1 §2).
function RentMath.inCrashWindow(t: number, startAt: number, endAt: number): boolean
	return t > startAt and t <= endAt
end

return RentMath

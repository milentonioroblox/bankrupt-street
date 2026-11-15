--!strict
-- Pure economy formulas (GDD §13.5). No DataStore, no Players, no Config reads:
-- every input is passed in, so Formulas.spec can test them with fixed numbers.

local Formulas = {}

export type RentArgs = {
	baseIncomePerMinute: number, -- raw catalog sum, before boosts
	cycleMinutes: number,
	rentToIncomeRatio: number,
	houseRent: number,
	streetRentMultiplier: number,
	evictionMultiplier: number, -- 1 when inactive
	crashMultiplier: number, -- 1 when inactive
	minRent: number,
}

function Formulas.rent(a: RentArgs): number
	local raw = a.baseIncomePerMinute * a.cycleMinutes * a.rentToIncomeRatio + a.houseRent
	local rent = math.floor(raw * a.streetRentMultiplier * a.evictionMultiplier * a.crashMultiplier)
	return math.max(a.minRent, rent)
end

export type IncomeArgs = {
	baseIncomePerMinute: number,
	streetIncomeMultiplier: number,
	rebirthCount: number,
	rebirthBonusPerRebirth: number,
	comebackMultiplier: number, -- 1 when inactive
	eventRewardMultiplier: number, -- 1 when inactive
}

function Formulas.incomePerMinute(a: IncomeArgs): number
	return a.baseIncomePerMinute
		* a.streetIncomeMultiplier
		* (1 + a.rebirthBonusPerRebirth * a.rebirthCount)
		* a.comebackMultiplier
		* a.eventRewardMultiplier
end

function Formulas.fairValue(houseStepCost: number, propertyCosts: { number }): number
	local total = houseStepCost
	for _, c in propertyCosts do
		total += c
	end
	return total
end

function Formulas.minBid(fairValue: number, minBidRatio: number, minBidFloor: number): number
	return math.max(minBidFloor, math.floor(fairValue * minBidRatio))
end

function Formulas.bidIncrement(currentBid: number, ratio: number, floorPerStreet: number, streetTier: number): number
	return math.max(floorPerStreet * streetTier, math.ceil(currentBid * ratio))
end

function Formulas.rescueCost(overdueRent: number, feeRatio: number): number
	-- round before ceil so float error (750 * 1.1 = 825.0000001) doesn't add a dollar
	return math.ceil(math.floor(overdueRent * (1 + feeRatio) * 1e6 + 0.5) / 1e6)
end

function Formulas.maxRescuerShare(rescueCost: number, maxShare: number): number
	return math.floor(rescueCost * maxShare)
end

function Formulas.offlineCash(
	incomePerMinute: number,
	elapsedSeconds: number,
	capSeconds: number,
	rate: number,
	vipMultiplier: number
): number
	local elapsed = math.clamp(elapsedSeconds, 0, capSeconds)
	return math.floor(incomePerMinute / 60 * elapsed * rate * vipMultiplier)
end

-- v1.1: bankruptcy drops the house by `drop` levels instead of resetting to 1.
function Formulas.houseLevelAfterBankruptcy(level: number, drop: number): number
	return math.max(1, level - drop)
end

-- Is `x` a finite, non-negative whole number? Use on every client-supplied amount.
function Formulas.isValidAmount(x: any): boolean
	return type(x) == "number" and x == x and x >= 0 and x < math.huge and math.floor(x) == x
end

return Formulas

--!strict
-- Pure economy formulas (GDD §13.5). No DataStore, no Players, no Config reads:
-- every input is passed in, so Formulas.spec can test them with fixed numbers.

local Formulas = {}

-- Money values are whole dollars computed from float ratios (0.35, 0.05, 1.10...). Binary floats
-- land a hair under or over the true value (750 * 1.1 = 825.0000000000001), so floor/ceil get a
-- small tolerance instead of losing or adding a dollar.
local EPSILON = 1e-6

function Formulas.floorMoney(x: number): number
	return math.floor(x + EPSILON)
end

function Formulas.ceilMoney(x: number): number
	return math.ceil(x - EPSILON)
end

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
	local rent = Formulas.floorMoney(raw * a.streetRentMultiplier * a.evictionMultiplier * a.crashMultiplier)
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
	return math.max(minBidFloor, Formulas.floorMoney(fairValue * minBidRatio))
end

function Formulas.bidIncrement(currentBid: number, ratio: number, floorPerStreet: number, streetTier: number): number
	return math.max(floorPerStreet * streetTier, Formulas.ceilMoney(currentBid * ratio))
end

function Formulas.rescueCost(overdueRent: number, feeRatio: number): number
	return Formulas.ceilMoney(overdueRent * (1 + feeRatio))
end

function Formulas.maxRescuerShare(rescueCost: number, maxShare: number): number
	return Formulas.floorMoney(rescueCost * maxShare)
end

function Formulas.offlineCash(
	incomePerMinute: number,
	elapsedSeconds: number,
	capSeconds: number,
	rate: number,
	vipMultiplier: number
): number
	local elapsed = math.clamp(elapsedSeconds, 0, capSeconds)
	return Formulas.floorMoney(incomePerMinute / 60 * elapsed * rate * vipMultiplier)
end

-- v1.1: bankruptcy drops the house by `drop` levels instead of resetting to 1.
function Formulas.houseLevelAfterBankruptcy(level: number, drop: number): number
	return math.max(1, level - drop)
end

-- Session lock decision for ProfileManager (GDD §17.2), kept pure so the spec can test it.
--   "free"  no lock, or a released one -> take it
--   "mine"  this server already holds it -> refresh it
--   "stale" another server's heartbeat is older than the TTL -> steal it
--   "held"  another live server holds it -> wait, then give up
export type LockDecision = "free" | "mine" | "stale" | "held"

function Formulas.lockDecision(
	lock: { token: string, heartbeatAt: number }?,
	now: number,
	myToken: string,
	ttlSeconds: number
): LockDecision
	if lock == nil or type(lock) ~= "table" or type(lock.token) ~= "string" then
		return "free"
	end
	if lock.token == myToken then
		return "mine"
	end
	local heartbeatAt = if type(lock.heartbeatAt) == "number" then lock.heartbeatAt else 0
	if now - heartbeatAt >= ttlSeconds then
		return "stale"
	end
	return "held"
end

-- Is `x` a finite, non-negative whole number? Use on every client-supplied amount.
function Formulas.isValidAmount(x: any): boolean
	return type(x) == "number" and x == x and x >= 0 and x < math.huge and math.floor(x) == x
end

return Formulas

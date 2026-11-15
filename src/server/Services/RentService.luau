--!strict
-- Rent (GDD §6, §13.5, v1.1 §1–2).
--
--   rent = max(MinRent, floor(
--       (sum(baseIncomePerMinute) * cycleMinutes * RentToIncomeRatio + HouseRent[level])
--       * StreetRentMultiplier * (evictionNight 2) * (crashTick 3)))          -- Shared/RentMath
--
-- Ticks every RentIntervalSeconds from server start, for the whole street at once (one pass,
-- no yields). Per player with a loaded profile and a plot (§6.3):
--   1. rentFreeUntil > now                      -> waived
--   2. spendable >= rent                        -> paid
--   3. Crash Insurance charge, not used today   -> insurance covers the shortfall, cash -> 0
--   4. otherwise                                -> failed: RentService.failed fires (auction)
--
-- v1.1 §1: leaving during a crash warning or crash window charges that crash's rent on the way
-- out. If they can't pay, `failed` fires with inAbsentia = true.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Enums = require(Shared.Enums)
local RentMath = require(Shared.RentMath)
local Types = require(Shared.Types)
local ServerEpoch = require(script.Parent.Parent.Lib.ServerEpoch)
local Signal = require(script.Parent.Parent.Lib.Signal)
local AnalyticsService = require(script.Parent.AnalyticsService)
local CrashService = require(script.Parent.CrashService)
local EconomyService = require(script.Parent.EconomyService)
local Net = require(script.Parent.Net)
local PlotService = require(script.Parent.PlotService)
local ProfileManager = require(script.Parent.ProfileManager)

local RentService = {}

export type Failure = {
	userId: number,
	player: Player?,
	overdue: number, -- the rent they couldn't pay
	crash: boolean,
	inAbsentia: boolean,
	profile: Types.Profile, -- live reference (in absentia: the profile as it was saved on leave)
}

-- Fired once per missed rent. AuctionService (next M1 chunk) turns it into an estate auction.
RentService.failed = Signal.new() :: Signal.Signal<Failure>

local nextRentAt = 0

-- Eviction Night (M3, EventService). Off until then.
function RentService.evictionNightActive(): boolean
	return false
end

function RentService.rentFor(profile: Types.Profile, crash: boolean): number
	return RentMath.rent(profile, crash, RentService.evictionNightActive())
end

local function utcDate(t: number): string
	return os.date("!%Y-%m-%d", t) :: string
end

-- Charge one player for one tick. Returns the status. `onLeave`: charged while leaving (v1.1 §1),
-- so a failure is an auction in absentia. The profile is still in its session at that point.
local function charge(player: Player, profile: Types.Profile, tickAt: number, crash: boolean, onLeave: boolean?): string
	local rent = RentService.rentFor(profile, crash)
	local result: string
	if profile.rentFreeUntil > tickAt then
		result = Enums.RentStatus.Waived
	elseif EconomyService.spendable(profile) >= rent then
		EconomyService.spend(player, rent, "rent")
		result = Enums.RentStatus.Paid
	elseif profile.insuranceCharges > 0 and profile.insuranceUsedUTCDate ~= utcDate(tickAt) then
		-- Pay what they can; insurance covers the rest (GDD §6.3 step 4, §14.2).
		local paid = math.max(0, EconomyService.spendable(profile))
		if paid > 0 then
			EconomyService.spend(player, paid, "rent")
		end
		profile.insuranceCharges -= 1
		profile.insuranceUsedUTCDate = utcDate(tickAt)
		AnalyticsService.event("insurance_used", { rent = rent, paid = paid }, player)
		ProfileManager.save(player, "insurance_used")
		result = Enums.RentStatus.Insured
	else
		result = Enums.RentStatus.Failed
	end
	AnalyticsService.event(if result == Enums.RentStatus.Failed then "rent_failed" else "rent_paid", {
		rent = rent,
		status = result,
		crash = crash,
		cash = profile.cash,
		onLeave = onLeave == true,
	}, player)
	Net.push(player, Enums.Push.Rent, { status = result, amount = rent, crash = crash })
	ProfileManager.push(player)
	if result == Enums.RentStatus.Failed then
		RentService.failed:fire({
			userId = player.UserId,
			player = if onLeave then nil else player,
			overdue = rent,
			crash = crash,
			inAbsentia = onLeave == true,
			profile = profile,
		})
	end
	return result
end

-- One street-wide collection (simultaneous: computed and applied in one pass).
function RentService.collect(tickAt: number): { [string]: number }
	local crash = CrashService.isCrashTick(tickAt)
	local counts = {}
	for _, player in Players:GetPlayers() do
		local profile = ProfileManager.get(player)
		if profile and PlotService.getPlotId(player) then
			if crash and profile.crashRentPrepaidUntil >= tickAt then
				continue -- already paid this crash's rent when they left during it
			end
			local status = charge(player, profile, tickAt, crash)
			counts[status] = (counts[status] or 0) + 1
		end
	end
	return counts
end

local function onLeaving(player: Player, profile: Types.Profile)
	if not Config.ChargeRentOnLeaveDuringCrash or ProfileManager.shuttingDown then
		return
	end
	if not PlotService.getPlotId(player) then
		return
	end
	local _, windowEnd = CrashService.pendingWindow()
	if not windowEnd or profile.crashRentPrepaidUntil >= windowEnd then
		return
	end
	-- Charge the crash tick at the end of this window now, and remember it so a rejoin (here or
	-- on another server) isn't charged for it again.
	local status = charge(player, profile, windowEnd, true, true)
	profile.crashRentPrepaidUntil = windowEnd
	print(`[RentService] {player.Name} left during a crash: {status}`)
end

-- Debug (/forcerent): collect now, as if a tick happened at this second.
function RentService.forceCollect(): { [string]: number }
	return RentService.collect(os.time())
end

function RentService.nextRentAt(): number
	return nextRentAt
end

function RentService.Init(_self: any)
	nextRentAt = ServerEpoch + Config.RentIntervalSeconds
	ReplicatedStorage:SetAttribute("RentNextAt", nextRentAt)
end

function RentService.Start(_self: any)
	ProfileManager.onLeaving(onLeaving)
	RentService.failed:connect(function(f: Failure)
		-- Until AuctionService lands, a missed rent is only reported.
		if f.player then
			Net.push(f.player, Enums.Push.Notice, `You couldn't pay ${f.overdue} rent!`)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(0.5)
			while os.time() >= nextRentAt do
				local tickAt = nextRentAt
				nextRentAt += Config.RentIntervalSeconds
				ReplicatedStorage:SetAttribute("RentNextAt", nextRentAt)
				local counts = RentService.collect(tickAt)
				print(`[RentService] tick {tickAt} crash={CrashService.isCrashTick(tickAt)}`, counts)
			end
		end
	end)
end

return RentService

--!strict
-- Formula checks from GDD Appendix C, using the v1.0 numbers passed in explicitly
-- (so tuning Config never breaks these), plus v1.1 cases. In Studio the server runs this on
-- start (DebugService, Config.RunFormulaSpecInStudio); or from the command bar:
-- require(game.ReplicatedStorage.Shared["Formulas.spec"])()

local Formulas = require(script.Parent.Formulas)

return function(): (number, number)
	local passed, failed = 0, 0
	local function check(name: string, got: any, want: any)
		if got == want then
			passed += 1
		else
			failed += 1
			warn(`[Formulas.spec] FAIL {name}: got {got}, want {want}`)
		end
	end

	local base = {
		baseIncomePerMinute = 60,
		cycleMinutes = 10,
		rentToIncomeRatio = 0.35,
		houseRent = 40,
		streetRentMultiplier = 1,
		evictionMultiplier = 1,
		crashMultiplier = 1,
		minRent = 10,
	}
	check("rent plain", Formulas.rent(base), 250)

	local crash = table.clone(base)
	crash.crashMultiplier = 3
	check("rent crash", Formulas.rent(crash), 750)

	local both = table.clone(crash)
	both.evictionMultiplier = 2
	check("rent eviction+crash", Formulas.rent(both), 1500)

	local tiny = table.clone(base)
	tiny.baseIncomePerMinute = 0
	tiny.houseRent = 0
	check("rent min", Formulas.rent(tiny), 10)

	local fv = Formulas.fairValue(4000, { 2000 })
	check("fair value", fv, 6000)
	check("min bid", Formulas.minBid(fv, 0.40, 25), 2400)
	check("min bid floor", Formulas.minBid(10, 0.40, 25), 25)
	check("increment", Formulas.bidIncrement(2400, 0.05, 50, 1), 120)
	check("increment floor", Formulas.bidIncrement(100, 0.05, 50, 1), 50)

	local rc = Formulas.rescueCost(750, 0.10)
	check("rescue cost", rc, 825)
	check("rescuer share", Formulas.maxRescuerShare(rc, 0.75), 618)

	check("offline 8h", Formulas.offlineCash(60, 28800, 28800, 1, 1), 28800)
	check("offline vip", Formulas.offlineCash(60, 28800, 28800, 1, 2), 57600)
	check("offline capped", Formulas.offlineCash(60, 99999, 28800, 1, 1), 28800)
	check("offline negative", Formulas.offlineCash(60, -5, 28800, 1, 1), 0)

	check("bankrupt drop", Formulas.houseLevelAfterBankruptcy(7, 3), 4)
	check("bankrupt drop floor", Formulas.houseLevelAfterBankruptcy(2, 3), 1)

	-- v1.1: 5-minute rent cycle, Skid Row, Street Stall + Food Cart on a Tent (HouseRent 5)
	local v11 = table.clone(base)
	v11.cycleMinutes = 5
	v11.baseIncomePerMinute = 8 + 15
	v11.houseRent = 5
	check("rent v1.1 tent", Formulas.rent(v11), 45) -- 23*5*0.35 = 40.25 + 5 = 45.25 -> 45
	local v11b = table.clone(v11)
	v11b.baseIncomePerMinute = 8
	v11b.houseRent = 0
	check("rent v1.1 float edge", Formulas.rent(v11b), 14) -- 8*5*0.35 must not floor to 13
	check("offline v1.1 half rate", Formulas.offlineCash(60, 28800, 28800, 0.5, 1), 14400)
	check("offline v1.1 half rate vip", Formulas.offlineCash(60, 28800, 28800, 0.5, 2), 28800)

	-- session lock (GDD §17.2)
	check("lock free", Formulas.lockDecision(nil, 1000, "me", 90), "free")
	check("lock mine", Formulas.lockDecision({ token = "me", heartbeatAt = 1 }, 1000, "me", 90), "mine")
	check("lock held", Formulas.lockDecision({ token = "other", heartbeatAt = 950 }, 1000, "me", 90), "held")
	check("lock stale", Formulas.lockDecision({ token = "other", heartbeatAt = 910 }, 1000, "me", 90), "stale")

	check("sell price", Formulas.sellPrice(50, 0.40), 20)
	check("sell price corner", Formulas.sellPrice(2000, 0.40), 800)
	check("free slot first", Formulas.firstFreeSlot({}, 2), 1)
	check("free slot gap", Formulas.firstFreeSlot({ [1] = true, [3] = true }, 3), 2)
	check("free slot full", Formulas.firstFreeSlot({ [1] = true, [2] = true }, 2), nil)

	-- RentMath with the live Config (v1.1: 5-minute cycle). Update if Config is retuned.
	local RentMath = require(script.Parent.RentMath)
	local shopStudio = { houseLevel = 4, streetTier = 1, properties = { { propertyId = "shop_corner" } } }
	check("rentmath studio+shop", RentMath.rent(shopStudio, false, false), 145) -- 60*5*0.35 + 40
	check("rentmath crash", RentMath.rent(shopStudio, true, false), 435)
	check("rentmath crash+eviction", RentMath.rent(shopStudio, true, true), 870)
	check("rentmath empty box", RentMath.rent({ houseLevel = 1, streetTier = 1, properties = {} }, false, false), 10)
	check("crash window start excluded", RentMath.inCrashWindow(1200, 1200, 1500), false)
	check("crash window end included", RentMath.inCrashWindow(1500, 1200, 1500), true)
	check("crash window after", RentMath.inCrashWindow(1800, 1200, 1500), false)

	check("valid amount", Formulas.isValidAmount(5), true)
	check("invalid neg", Formulas.isValidAmount(-1), false)
	check("invalid nan", Formulas.isValidAmount(0 / 0), false)
	check("invalid inf", Formulas.isValidAmount(math.huge), false)
	check("invalid frac", Formulas.isValidAmount(1.5), false)
	check("invalid str", Formulas.isValidAmount("5"), false)

	print(`[Formulas.spec] {passed} passed, {failed} failed`)
	return passed, failed
end

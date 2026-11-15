--!strict
-- Formula checks from GDD Appendix C, using the v1.0 numbers passed in explicitly
-- (so tuning Config never breaks these). Run in Studio: the server runs them on start
-- (see DebugService) or call require(ReplicatedStorage.Shared["Formulas.spec"])().

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

	check("valid amount", Formulas.isValidAmount(5), true)
	check("invalid neg", Formulas.isValidAmount(-1), false)
	check("invalid nan", Formulas.isValidAmount(0 / 0), false)
	check("invalid inf", Formulas.isValidAmount(math.huge), false)
	check("invalid frac", Formulas.isValidAmount(1.5), false)
	check("invalid str", Formulas.isValidAmount("5"), false)

	print(`[Formulas.spec] {passed} passed, {failed} failed`)
	return passed, failed
end

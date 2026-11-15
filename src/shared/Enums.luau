--!strict
-- String enums shared by server and client (GDD §21). House and street ids/names live in Config
-- (HouseIds, StreetIds) because they are tuned alongside their numbers.

local Enums = {}

-- GDD §7.1 auction state machine.
Enums.AuctionState = table.freeze({
	Idle = "Idle",
	Queued = "Queued",
	RescueWindow = "RescueWindow",
	LiveBidding = "LiveBidding",
	SoftClose = "SoftClose",
	Settled = "Settled",
	CancelledRescue = "CancelledRescue",
	CancelledOwnerPay = "CancelledOwnerPay",
	CancelledNoBids = "CancelledNoBids",
})

Enums.AuctionKind = table.freeze({
	Bankruptcy = "Bankruptcy",
	Golden = "Golden",
	BankForeclosure = "BankForeclosure", -- v1.1
})

-- PropertyInstance.acquiredHow
Enums.AcquiredHow = table.freeze({
	Bought = "bought",
	Auction = "auction",
	Heist = "heist",
	Reward = "reward",
	Admin = "admin",
})

Enums.PropertyType = table.freeze({
	Stall = "Stall",
	Shop = "Shop",
	Apartment = "Apartment",
})

-- StatePush message kinds (server -> client).
Enums.Push = table.freeze({
	State = "State",
	Notice = "Notice",
})

-- Error codes used in NetResult.code (Appendix B).
Enums.Error = table.freeze({
	BadRequest = "bad_request",
	Unknown = "unknown",
	RateLimited = "rate_limited",
	ServerError = "server_error",
	NotLoaded = "not_loaded",
	Occupied = "occupied",
	AlreadyHasPlot = "already_has_plot",
	NoPlot = "no_plot",
	TooFar = "too_far",
	CannotAfford = "cannot_afford",
})

return table.freeze(Enums)

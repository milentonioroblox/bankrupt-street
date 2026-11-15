--!strict
-- STARTING DESIGN VALUES, not live data. Tune after playtests.
-- Source: docs/GDD.md Appendix A, with overrides from docs/GDD-v1.1-changes.md (marked "v1.1").
-- Systems must read every number from here; no magic numbers in services.

local Config = {}

Config.SchemaVersion = 1
Config.MaxPlayersPerStreet = 8 -- v1.1 (was 12)
Config.PlotCount = 8 -- v1.1 (was 12)
Config.MaxInteractDistance = 24
Config.MaxPlotNameLength = 24
Config.AutosaveSeconds = 60
Config.SessionLockTTL = 90
Config.SessionLockHeartbeat = 30
Config.SessionLockWaitSeconds = 10
Config.SessionLockRetrySeconds = 1
-- Studio only: a lock left by a crashed/killed playtest is stolen at once instead of after the TTL.
Config.SessionLockStealInStudio = true
Config.DataStoreName = "PlayerData_v1"
Config.DataStoreKeyPrefix = "player:"
Config.ProfileSaveMinIntervalSeconds = 6 -- DataStore allows one write per key per 6s
Config.ProfileLoadAttempts = 3
Config.ProfileSaveAttempts = 5
Config.CloseSaveTimeoutSeconds = 25 -- BindToClose budget is 30s
-- Studio only: use an in-memory store when DataStores are unavailable (unpublished place or
-- "Enable Studio Access to API Services" off). Data then lives only for that playtest.
Config.UseMockStoreInStudio = true

Config.StartingCash = 150 -- v1.1 (was 75)
Config.IncomeTickSeconds = 1
Config.SellBackRatio = 0.40
Config.OfflineIncomeCapSeconds = 8 * 3600
Config.OfflineIncomeRate = 0.5 -- v1.1 (new)
Config.VIPOfflineIncomeMultiplier = 2.0

Config.RentIntervalSeconds = 300 -- v1.1 (was 600)
Config.RentWarningSeconds = 30
Config.RentToIncomeRatio = 0.35
Config.MinRent = 10

Config.CrashIntervalSeconds = 1200 -- v1.1 (was 3600)
Config.CrashWindowSeconds = 300 -- v1.1 (was 600): exactly one rent tick
Config.CrashWarningSeconds = 60
Config.CrashRentMultiplier = 3
Config.ChargeRentOnLeaveDuringCrash = true -- v1.1 (new)

Config.ComebackIncomeMultiplier = 2.0
Config.ComebackDurationSeconds = 900 -- v1.1 (was 600)
Config.FallenTagUntilHouseLevel = 5
Config.BankruptcyHouseLevelDrop = 3 -- v1.1 (new; v1.0 reset to level 1)

Config.RescueWindowSeconds = 10
Config.AuctionDurationSeconds = 60
Config.LawyerPassExtraSeconds = 15
Config.SoftCloseWindowSeconds = 5
Config.SoftCloseExtensionSeconds = 5
Config.MaxSoftCloseExtensions = 3
Config.MinBidRatio = 0.40
Config.MinBidFloor = 25
Config.BidIncrementRatio = 0.05
Config.BidIncrementFloorPerStreet = 50 -- multiplied by streetTier
Config.AssetBindSeconds = 2 * 3600
Config.DeedToCashRatioIfAlreadyHigher = 0.30
Config.AuctionPayoutToBankruptRatio = 0
Config.RescueFeeRatio = 0.10
Config.MaxRescuers = 4
Config.MaxSharePerRescuer = 0.75
Config.MaxRescuesPerPlayerPerUTCDay = 3
Config.MaxRescueActionsPerRescuerPerUTCDay = 8
Config.MinRescuerPresenceSeconds = 120
Config.MaxPairRescueOrWinPerUTCDay = 2
Config.MaxPairRescueOrWinPerUTCWeek = 5
Config.NewAccountMaxBid = 5000
Config.NewAccountAgeDaysForBidCap = 7
Config.AuctionGapSeconds = 5
Config.BankForeclosureIdleSeconds = 300 -- v1.1 (new)

Config.NpcBidders = { -- v1.1 (new)
	Enabled = true,
	MaxRealPlayers = 4, -- NPCs bid only while fewer real players than this are present
	MinFairValueRatio = 0.45,
	MaxFairValueRatio = 0.85,
}

Config.InsuranceMaxUsePerUTCDay = 1

Config.RebirthIncomeBonusPerRebirth = 0.15
Config.StreetStartHouseLevel = { 1, 3, 4, 5, 6 }
Config.RebirthGrant = { 0, 2000, 15000, 75000, 300000 }
Config.MinPlayersForPercentile = 200
Config.BillionaireRowFallbackLifetimeEarnings = 50000000
Config.RebirthRequirements = {
	[2] = { minHouseLevel = 5, minLifetimeEarnings = 25000 },
	[3] = { minHouseLevel = 7, minLifetimeEarnings = 250000 },
	[4] = { minHouseLevel = 8, minLifetimeEarnings = 2000000 },
	[5] = { minHouseLevel = 10, minLifetimeEarnings = 20000000, topPercentile = 0.01 },
}

Config.StreetRentMultiplier = { 1.00, 1.15, 1.35, 1.60, 2.00 }
Config.StreetIncomeMultiplier = { 1.00, 1.10, 1.25, 1.45, 1.75 }

-- v1.1: levels 2-5 cheaper (was 250, 1000, 4000, 15000)
Config.HouseUpgradeCost = { 0, 150, 600, 2500, 10000, 50000, 200000, 800000, 3000000, 12000000 }
Config.HouseRent = { 0, 5, 15, 40, 100, 250, 800, 2500, 8000, 25000 }
-- v1.1: more early slots (was 1, 1, 2, 2, 3, 3, 4, 5, 6, 8)
Config.HousePropertySlots = { 2, 3, 3, 4, 4, 5, 5, 6, 7, 8 }
Config.HouseDisplayNames = {
	"Cardboard Box",
	"Tent",
	"Trailer",
	"Studio",
	"Row House",
	"Townhouse",
	"Villa",
	"Penthouse Tower",
	"Private Island Portal",
	"Billionaire Estate",
}
Config.HouseIds = {
	"CardboardBox",
	"Tent",
	"Trailer",
	"Studio",
	"RowHouse",
	"Townhouse",
	"Villa",
	"PenthouseTower",
	"PrivateIslandPortal",
	"BillionaireEstate",
}
Config.MaxHouseLevel = 10

Config.StreetNames = { "Skid Row", "Suburb Lane", "Downtown", "Ocean Drive", "Billionaire Row" }
Config.StreetIds = { "SkidRow", "SuburbLane", "Downtown", "OceanDrive", "BillionaireRow" }

Config.GoldenAuctionIntervalSeconds = 7200
Config.GoldenAuctionDurationSeconds = 60
Config.GoldenAuctionWarningSeconds = 120

-- Weekday convention: Sunday = 1 ... Saturday = 7 (os.date("*t").wday).
Config.EvictionNight = {
	Timezone = "America/New_York",
	Start = { weekday = 6, hour = 20, minute = 0 }, -- Friday 20:00
	Stop = { weekday = 1, hour = 23, minute = 0 }, -- Sunday 23:00
	PrimeSaturday = { startHour = 20, endHour = 22 },
	RentMultiplier = 2.0,
	RewardMultiplier = 2.0,
}

Config.TaxRaidIntervalSeconds = 1800
Config.TaxRaidWarningSeconds = 90
Config.TaxRaidPayWindowSeconds = 90
Config.TaxRaidRentFraction = 0.5

Config.HeistMinMembers = 3
Config.HeistMaxMembers = 4
Config.HeistMinHouseLevel = 7
Config.MaxHeistBidsPerUTCDay = 5

Config.StreakSaveCashPerDayPerStreet = 500
Config.StreakSaveCashCap = 25000
Config.StreakSaveWindowHours = 24
Config.DailyCashDay1PerStreet = 250
Config.RentFreeDurationSeconds = 24 * 3600
Config.AuctionBoostRebateRatio = 0.20
Config.AuctionBoostDurationSeconds = 24 * 3600
Config.Day14FallbackCash = 5000
Config.Day28FallbackCash = 15000
Config.Day5SkinFallbackPerStreet = 500

Config.MysteryDeedOdds = {
	{ level = 3, chance = 0.40 },
	{ level = 4, chance = 0.30 },
	{ level = 5, chance = 0.18 },
	{ level = 6, chance = 0.08 },
	{ level = 7, chance = 0.04 },
}

Config.LandlordSpinOdds = {
	{ id = "cash_small", chance = 0.35 },
	{ id = "cash_med", chance = 0.20 },
	{ id = "furniture_common", chance = 0.20 },
	{ id = "furniture_rare", chance = 0.10 },
	{ id = "auction_boost", chance = 0.07 },
	{ id = "insurance", chance = 0.05 },
	{ id = "stall_street", chance = 0.025 },
	{ id = "deed_studio", chance = 0.005 },
}

Config.SpinCashSmallPerStreet = 100
Config.SpinCashMedPerStreet = 400

Config.HallServerBoardSize = 20
Config.HallWorldTickerSize = 10
Config.HallMaxGlobalEntries = 5000
Config.LeaderboardUpdateSeconds = 60

Config.NewAccountClusterAgeDays = 3
Config.RateLimit = {
	Bid = { max = 4, window = 2 },
	Rescue = { max = 2, window = 2 },
	Shop = { max = 2, window = 1 },
	Default = { max = 5, window = 1 },
}

Config.SuggestedRobux = { -- suggestions only, not data
	CrashInsurance1 = 79,
	CrashInsurance5 = 299,
	LawyerPass1 = 39,
	LawyerPass5 = 129,
	StreakSave = 49,
	VIPLandlord = 399,
	PrivateStreet = 199,
	HouseSkin_NeonSign = 99,
	HouseSkin_MarbleFacade = 199,
	HouseSkin_GoldTrim = 399,
	Car_Beater = 99,
	Car_Sports = 249,
	Car_Limo = 399,
	Heli_News = 349,
	Heli_Gold = 799,
}
Config.StreakSaveIneligibleFallbackCash = 1000

export type PropertyDef = {
	id: string,
	name: string,
	type: string,
	cost: number,
	incomePerMinute: number,
	minHouse: number,
	minStreet: number,
}

Config.Properties = {
	{
		id = "stall_street",
		name = "Street Stall",
		type = "Stall",
		cost = 50,
		incomePerMinute = 8,
		minHouse = 1,
		minStreet = 1,
	},
	{
		id = "stall_food",
		name = "Food Cart",
		type = "Stall",
		cost = 200,
		incomePerMinute = 15,
		minHouse = 2,
		minStreet = 1,
	},
	{
		id = "stall_kiosk",
		name = "Kiosk",
		type = "Stall",
		cost = 600,
		incomePerMinute = 30,
		minHouse = 3,
		minStreet = 1,
	},
	{
		id = "shop_corner",
		name = "Corner Shop",
		type = "Shop",
		cost = 2000,
		incomePerMinute = 60,
		minHouse = 4,
		minStreet = 1,
	},
	{
		id = "apt_studio",
		name = "Studio Apartment",
		type = "Apartment",
		cost = 5000,
		incomePerMinute = 80,
		minHouse = 4,
		minStreet = 2,
	},
	{
		id = "shop_boutique",
		name = "Boutique",
		type = "Shop",
		cost = 8000,
		incomePerMinute = 120,
		minHouse = 5,
		minStreet = 2,
	},
	{
		id = "apt_building",
		name = "Apartment Building",
		type = "Apartment",
		cost = 25000,
		incomePerMinute = 200,
		minHouse = 6,
		minStreet = 2,
	},
	{
		id = "shop_luxury",
		name = "Luxury Store",
		type = "Shop",
		cost = 30000,
		incomePerMinute = 250,
		minHouse = 6,
		minStreet = 2,
	},
	{
		id = "apt_tower",
		name = "Apartment Tower",
		type = "Apartment",
		cost = 120000,
		incomePerMinute = 500,
		minHouse = 8,
		minStreet = 3,
	},
	{
		id = "shop_mall",
		name = "Street Mall",
		type = "Shop",
		cost = 400000,
		incomePerMinute = 800,
		minHouse = 8,
		minStreet = 4,
	},
	{
		id = "apt_resort",
		name = "Island Resort",
		type = "Apartment",
		cost = 1500000,
		incomePerMinute = 2000,
		minHouse = 9,
		minStreet = 4,
	},
	{
		id = "shop_hq",
		name = "Corporate HQ",
		type = "Shop",
		cost = 6000000,
		incomePerMinute = 5000,
		minHouse = 10,
		minStreet = 5,
	},
} :: { PropertyDef }

local propertiesById: { [string]: PropertyDef } = {}
for _, p in Config.Properties do
	propertiesById[p.id] = p
end
Config.PropertiesById = propertiesById

-- Studio/admin debug commands (GDD §23). Group rank gate for live servers; 0 disables.
Config.AdminGroupId = 0
Config.AdminMinRank = 254
Config.RunFormulaSpecInStudio = true

-- Greybox street layout (GDD §3.2, §21.3). Studs. Plots sit in two facing rows along the X axis
-- with the auction stage in the middle of the road, so every plot can see the stage.
Config.Map = {
	PlotSize = 44,
	PlotSpacing = 56, -- centre to centre along a row
	RoadHalfWidth = 34, -- road centre to the front edge of each plot row
	PropertySlotCount = 8, -- Slot1..Slot8 attachments per plot (max HousePropertySlots)
	ClaimPromptDistance = 12,
	StageSize = Vector3.new(28, 3, 18),
	JumbotronSize = Vector3.new(24, 12, 1),
	SpawnOffsetX = 40, -- spawn sits this far past the last plot, on the road
}

return Config

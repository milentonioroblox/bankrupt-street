--!strict
-- Player profile schema v1 (GDD §17.3): the default profile, load-time reconcile/migration,
-- and the copy that gets written to the DataStore.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Types = require(Shared.Types)
local TableUtil = require(script.Parent.TableUtil)

local ProfileSchema = {}

function ProfileSchema.default(userId: number, now: number): Types.Profile
	return {
		schemaVersion = Config.SchemaVersion,
		userId = userId,
		createdAt = now,
		lastSeenAt = now,
		cash = Config.StartingCash,
		reservedCash = 0,
		houseLevel = 1,
		streetTier = 1,
		rebirthCount = 0,
		rebirthIncomeMultiplier = 1.0,
		properties = {},
		pendingDeeds = {},
		pendingProperties = {},
		cosmeticsOwned = {},
		cosmeticsEquipped = { houseSkin = "", car = "", heli = "" },
		insuranceCharges = 0,
		insuranceUsedUTCDate = "",
		lawyerPasses = 0,
		auctionBoostExpiresAt = 0,
		rentFreeUntil = 0,
		comebackBoostUntil = 0,
		crashRentPrepaidUntil = 0,
		fallenMillionaire = false,
		houseHistory = {},
		streak = { count = 0, lastClaimUTCDate = "", longest = 0, claimed14 = false, claimed28 = false },
		lifetimeEarnings = 0,
		lifetimeSpentCash = 0,
		lifetimeBankruptcies = 0,
		lifetimeAuctionsWon = 0,
		lifetimeRescuesReceived = 0,
		gamepassesCached = { VIPLandlord = false, PrivateStreet = false },
		receiptIds = {},
		settings = { nameplateShowCash = false, music = true, sfx = true, reduceMotion = false },
		integrity = {
			rescuesReceivedUTCDate = "",
			rescuesReceivedToday = 0,
			rescueActionsUTCDate = "",
			rescueActionsToday = 0,
			heistUTCDate = "",
			heistToday = 0,
			pairEvents = {},
		},
	}
end

-- Turn whatever was stored (nil for a new player) into a valid current-schema profile.
-- Returns the profile and whether this is a brand-new player.
function ProfileSchema.load(stored: any, userId: number, now: number): (Types.Profile, boolean)
	if type(stored) ~= "table" then
		return ProfileSchema.default(userId, now), true
	end
	local version = if type(stored.schemaVersion) == "number" then stored.schemaVersion else 0
	if version > Config.SchemaVersion then
		-- Written by a newer server build: never downgrade it.
		error(`profile {userId} has schemaVersion {version} > {Config.SchemaVersion}`)
	end
	-- Future migrations go here: if version < 2 then ... end
	local fixed = TableUtil.reconcile(stored, ProfileSchema.default(userId, now) :: any)
	if #fixed > 0 then
		warn(`[ProfileSchema] {userId}: reset bad fields {table.concat(fixed, ", ")}`)
	end
	local profile = stored :: Types.Profile
	profile.schemaVersion = Config.SchemaVersion
	profile.userId = userId
	-- Escrow never survives a session (GDD §17.3).
	profile.reservedCash = 0
	profile.cash = math.max(0, math.floor(profile.cash))
	return profile, false
end

-- What gets written to the DataStore.
function ProfileSchema.serialize(profile: Types.Profile, now: number): Types.Profile
	local copy = TableUtil.deepCopy(profile)
	copy.reservedCash = 0
	copy.lastSeenAt = now
	return copy
end

return ProfileSchema

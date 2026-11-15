--!strict
-- Shared type aliases (GDD §17.3–17.4). Profile schema v1.

export type HistoryEntry = { userId: number, displayName: string, at: number, reason: string }

export type PropertyInstance = {
	instanceId: string,
	propertyId: string,
	ownerUserIds: { number },
	shares: { number },
	slotIndex: number,
	acquiredAt: number,
	acquiredHow: string,
	boundUntil: number,
	history: { HistoryEntry },
}

export type Profile = {
	schemaVersion: number,
	userId: number,
	createdAt: number,
	lastSeenAt: number,
	cash: number,
	reservedCash: number, -- live auction escrow; always saved as 0 (GDD §17.3)
	houseLevel: number,
	streetTier: number,
	rebirthCount: number,
	rebirthIncomeMultiplier: number,
	properties: { PropertyInstance },
	pendingDeeds: { any },
	pendingProperties: { PropertyInstance },
	cosmeticsOwned: { string },
	cosmeticsEquipped: { houseSkin: string, car: string, heli: string },
	insuranceCharges: number,
	insuranceUsedUTCDate: string,
	lawyerPasses: number,
	auctionBoostExpiresAt: number,
	rentFreeUntil: number,
	comebackBoostUntil: number,
	fallenMillionaire: boolean,
	houseHistory: { HistoryEntry },
	streak: { count: number, lastClaimUTCDate: string, longest: number, claimed14: boolean, claimed28: boolean },
	lifetimeEarnings: number,
	lifetimeSpentCash: number,
	lifetimeBankruptcies: number,
	lifetimeAuctionsWon: number,
	lifetimeRescuesReceived: number,
	gamepassesCached: { VIPLandlord: boolean, PrivateStreet: boolean },
	receiptIds: { [string]: boolean },
	settings: { nameplateShowCash: boolean, music: boolean, sfx: boolean, reduceMotion: boolean },
	integrity: { [string]: any },
}

-- Session lock stored next to the profile in the same DataStore key, so the lock and the data
-- are always written together by one UpdateAsync (no split-brain between two stores).
export type SessionLock = { token: string, jobId: string, placeId: number, heartbeatAt: number }

export type StoredRecord = { profile: Profile, lock: SessionLock? }

export type NetResult = { ok: boolean, code: string?, message: string?, data: any? }

-- Public slice of the profile pushed to its owner only (never other players' cash).
export type StateSlice = {
	cash: number,
	spendable: number,
	houseLevel: number,
	houseName: string,
	streetTier: number,
}

-- A ModuleScript must return exactly one value.
return {}

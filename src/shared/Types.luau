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
	houseLevel: number,
	streetTier: number,
	rebirthCount: number,
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

-- Session lock stored next to the profile in the same DataStore key.
export type SessionLock = { jobId: string, placeId: number, heartbeatAt: number }

export type StoredRecord = { profile: Profile, lock: SessionLock? }

export type NetResult = { ok: boolean, code: string?, message: string?, data: any? }

return nil

--!strict
-- Player profiles: load, session lock, autosave, release (GDD §17.2, v1.1 §6).
--
-- Each DataStore key `player:{userId}` holds { profile, lock }. The lock is written by the same
-- UpdateAsync as the profile, so a server can only save while it still owns the lock:
--   * join:   take the lock if it is free, ours, or stale (heartbeat older than SessionLockTTL);
--             if another live server holds it, retry for SessionLockWaitSeconds, then kick.
--   * every SessionLockHeartbeat seconds (and on demand): write the profile + refresh heartbeat.
--   * leave / shutdown: final write that clears the lock.
--   * if a save finds someone else's lock, this session lost ownership: stop saving and kick.
-- In Studio without DataStore access, an in-memory MockStore is used instead.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Enums = require(Shared.Enums)
local Formulas = require(Shared.Formulas)
local Types = require(Shared.Types)
local Lib = script.Parent.Parent.Lib
local IncomeMath = require(Lib.IncomeMath)
local MockStore = require(Lib.MockStore)
local ProfileSchema = require(Lib.ProfileSchema)
local Net = require(script.Parent.Net)

type Session = {
	player: Player,
	userId: number,
	key: string,
	profile: Types.Profile,
	isNew: boolean,
	saving: boolean,
	dirty: boolean,
	wantRelease: boolean,
	closed: boolean, -- released or lost; no more writes
	lastWriteAt: number,
}

local ProfileManager = {}

-- One token per server instance. game.JobId is "" in Studio, so it can't tell playtests apart.
local serverToken = HttpService:GenerateGUID(false)
local store: any = nil
ProfileManager.usingMockStore = false

local sessions: { [Player]: Session } = {}
local loadedCallbacks: { (Player, Types.Profile) -> () } = {}

local function keyFor(userId: number): string
	return Config.DataStoreKeyPrefix .. tostring(userId)
end

local function newLock(now: number): Types.SessionLock
	return { token = serverToken, jobId = game.JobId, placeId = game.PlaceId, heartbeatAt = now }
end

local function openStore()
	local ok, result = pcall(function()
		local ds = DataStoreService:GetDataStore(Config.DataStoreName)
		ds:GetAsync("__probe") -- throws if the place is unpublished or API access is off
		return ds
	end)
	if ok then
		store = result
		return
	end
	if RunService:IsStudio() and Config.UseMockStoreInStudio then
		warn(
			`[ProfileManager] DataStore unavailable ({result}). Using in-memory MockStore: data lasts this playtest only.`
		)
		store = MockStore.new()
		ProfileManager.usingMockStore = true
		return
	end
	-- Live server: a failed probe is most likely transient; keep using the real store.
	warn(`[ProfileManager] DataStore probe failed: {result}`)
	store = DataStoreService:GetDataStore(Config.DataStoreName)
end

-- Take the lock and read the profile. Returns (profile, isNew) or (nil, errorCode).
local function acquire(userId: number): (Types.Profile?, boolean | string)
	local key = keyFor(userId)
	local deadline = os.clock() + Config.SessionLockWaitSeconds
	local failures = 0
	while true do
		local outcome: string = "error"
		local loaded: Types.Profile? = nil
		local isNew = false
		local ok, err = pcall(function()
			store:UpdateAsync(key, function(old: any)
				local now = os.time()
				local record = if type(old) == "table" then old else nil
				local decision = Formulas.lockDecision(record and record.lock, now, serverToken, Config.SessionLockTTL)
				if decision == "held" and RunService:IsStudio() and Config.SessionLockStealInStudio then
					decision = "stale"
				end
				if decision == "held" then
					outcome = "held"
					return nil -- cancel the write
				end
				if decision == "stale" then
					warn(`[ProfileManager] {userId}: stealing stale lock from {record.lock.jobId}`)
				end
				local profile, fresh = ProfileSchema.load(record and record.profile, userId, now)
				outcome, loaded, isNew = "ok", profile, fresh
				return { profile = ProfileSchema.serialize(profile, profile.lastSeenAt), lock = newLock(now) }, {
					userId,
				}
			end)
		end)
		if ok and outcome == "ok" and loaded then
			return loaded, isNew
		end
		if ok and outcome == "held" then
			if os.clock() >= deadline then
				return nil, "locked"
			end
		else
			failures += 1
			warn(`[ProfileManager] {userId}: load failed ({failures}/{Config.ProfileLoadAttempts}): {err}`)
			if failures >= Config.ProfileLoadAttempts then
				return nil, "load_failed"
			end
		end
		task.wait(Config.SessionLockRetrySeconds * (failures + 1))
	end
end

-- One UpdateAsync. Returns false on a DataStore error (retryable).
local function write(s: Session): boolean
	local release = s.wantRelease
	local lost = false
	local ok, err = pcall(function()
		store:UpdateAsync(s.key, function(old: any)
			local now = os.time()
			local record = if type(old) == "table" then old else nil
			local lock = record and record.lock
			if type(lock) ~= "table" or lock.token ~= serverToken then
				lost = true
				return nil
			end
			return {
				profile = ProfileSchema.serialize(s.profile, now),
				lock = if release then nil else newLock(now),
			}, { s.userId }
		end)
	end)
	s.lastWriteAt = os.clock()
	if not ok then
		warn(`[ProfileManager] {s.userId}: save failed: {err}`)
		return false
	end
	if lost then
		s.closed = true
		warn(`[ProfileManager] {s.userId}: session lock lost; stopped saving`)
		if s.player.Parent == Players then
			s.player:Kick("Your data was opened in another server. Please rejoin.")
		end
	elseif release then
		s.closed = true
	end
	return true
end

-- Save until nothing is pending. Only one flush runs per session; others wait for it.
local function flush(s: Session)
	if s.saving then
		while s.saving do
			task.wait(0.1)
		end
		return
	end
	s.saving = true
	local failures = 0
	while s.dirty and not s.closed do
		s.dirty = false
		local waitFor = s.lastWriteAt + Config.ProfileSaveMinIntervalSeconds - os.clock()
		if waitFor > 0 then
			task.wait(waitFor)
		end
		if not write(s) then
			failures += 1
			if failures >= Config.ProfileSaveAttempts then
				warn(`[ProfileManager] {s.userId}: giving up after {failures} failed saves`)
				break
			end
			s.dirty = true
			task.wait(failures)
		end
	end
	s.saving = false
end

local function release(s: Session)
	s.wantRelease = true
	s.dirty = true
	flush(s)
	if not s.closed then
		-- flush gave up or another flush was mid-write without the release flag; finish it.
		s.dirty = true
		flush(s)
	end
end

local function publicSlice(profile: Types.Profile): Types.StateSlice
	local now = os.time()
	local props: { Types.PropertyView } = {}
	for _, inst in profile.properties do
		table.insert(props, {
			instanceId = inst.instanceId,
			propertyId = inst.propertyId,
			slotIndex = inst.slotIndex,
			boundUntil = inst.boundUntil,
		})
	end
	return {
		serverTime = now,
		cash = profile.cash,
		spendable = profile.cash - profile.reservedCash,
		incomePerMinute = IncomeMath.effectivePerMinute(profile, now),
		houseLevel = profile.houseLevel,
		houseName = Config.HouseDisplayNames[profile.houseLevel] or "?",
		streetTier = profile.streetTier,
		slotsUsed = #profile.properties,
		slotsMax = Config.HousePropertySlots[profile.houseLevel] or 0,
		properties = props,
		comebackUntil = profile.comebackBoostUntil,
	}
end

local function onPlayerAdded(player: Player)
	local profile, info = acquire(player.UserId)
	if not profile then
		warn(`[ProfileManager] {player.UserId}: could not load ({info})`)
		if player.Parent == Players then
			if info == "locked" then
				player:Kick("Your data is still open in another server. Please rejoin in a minute.")
			else
				player:Kick("We couldn't load your data. Please rejoin.")
			end
		end
		return
	end
	local s: Session = {
		player = player,
		userId = player.UserId,
		key = keyFor(player.UserId),
		profile = profile,
		isNew = info == true,
		saving = false,
		dirty = false,
		wantRelease = false,
		closed = false,
		lastWriteAt = os.clock(),
	}
	if player.Parent ~= Players then
		-- Left while loading: hand the lock straight back.
		release(s)
		return
	end
	sessions[player] = s
	print(`[ProfileManager] {player.Name} loaded ({if s.isNew then "new" else "returning"}), cash {profile.cash}`)
	ProfileManager.push(player)
	for _, cb in loadedCallbacks do
		task.spawn(cb, player, profile)
	end
end

local function onPlayerRemoving(player: Player)
	local s = sessions[player]
	if not s then
		return
	end
	release(s)
	sessions[player] = nil
	print(`[ProfileManager] {player.Name} saved and released, cash {s.profile.cash}`)
end

-- Public API -----------------------------------------------------------------------------

function ProfileManager.get(player: Player): Types.Profile?
	local s = sessions[player]
	return if s and not s.closed then s.profile else nil
end

-- Yield until the player's profile is loaded (or they leave). Returns nil if it never loads.
function ProfileManager.waitFor(player: Player, timeout: number?): Types.Profile?
	local deadline = os.clock() + (timeout or 30)
	while player.Parent == Players and os.clock() < deadline do
		local p = ProfileManager.get(player)
		if p then
			return p
		end
		task.wait(0.1)
	end
	return nil
end

function ProfileManager.onLoaded(cb: (Player, Types.Profile) -> ())
	table.insert(loadedCallbacks, cb)
	for player, s in sessions do
		task.spawn(cb, player, s.profile)
	end
end

-- Request a save soon (coalesced, respects the per-key write limit). Call after purchases,
-- settlements, rebirth, insurance use, streak claims (GDD §17.2 step 5).
function ProfileManager.save(player: Player, _reason: string?)
	local s = sessions[player]
	if s and not s.closed then
		s.dirty = true
		task.spawn(flush, s)
	end
end

-- Same as save, but yields until the write finished.
function ProfileManager.saveNow(player: Player)
	local s = sessions[player]
	if s and not s.closed then
		s.dirty = true
		flush(s)
	end
end

function ProfileManager.push(player: Player)
	local profile = ProfileManager.get(player)
	if profile then
		Net.push(player, Enums.Push.State, publicSlice(profile))
	end
end

-- Studio-only: simulate leaving and rejoining in one playtest (release the lock and save, then
-- load the key again from the store). Returns the cash before and after.
function ProfileManager.debugRelog(player: Player): (number?, number?)
	assert(RunService:IsStudio(), "debugRelog is Studio only")
	local s = sessions[player]
	if not s then
		return nil, nil
	end
	local before = s.profile.cash
	release(s)
	sessions[player] = nil
	onPlayerAdded(player)
	local after = ProfileManager.get(player)
	return before, after and after.cash
end

function ProfileManager.Init(_self: any)
	openStore()
	Net.register("GetState", function(player)
		local profile = ProfileManager.get(player)
		if not profile then
			return Net.fail(Enums.Error.NotLoaded, "Still loading your data.")
		end
		return Net.ok(publicSlice(profile))
	end)
end

function ProfileManager.Start(_self: any)
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	game:BindToClose(function()
		local pending = 0
		for _, s in sessions do
			pending += 1
			task.spawn(function()
				release(s)
				pending -= 1
			end)
		end
		local deadline = os.clock() + Config.CloseSaveTimeoutSeconds
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
		if pending > 0 then
			warn(`[ProfileManager] shutdown: {pending} profiles not released in time`)
		end
	end)

	-- Heartbeat + autosave: one loop at the shorter interval keeps the lock fresh (TTL 90s) and
	-- never lets unsaved progress get older than AutosaveSeconds.
	local interval = math.min(Config.AutosaveSeconds, Config.SessionLockHeartbeat)
	task.spawn(function()
		while true do
			task.wait(interval)
			for player in sessions do
				ProfileManager.save(player, "autosave")
			end
		end
	end)
end

return ProfileManager

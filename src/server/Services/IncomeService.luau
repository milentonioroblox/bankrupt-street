--!strict
-- Income (GDD §5.2–5.3, §13.5, v1.1 §1).
--
--   effectiveIncomePerMinute =
--       sum(baseIncomePerMinute) * streetIncomeMultiplier * (1 + 0.15 * rebirthCount)
--       * (comebackActive and 2 or 1) * (evictionNightActive and 2 or 1)
--   cashAddedThisTick = effectiveIncomePerMinute / 60 * IncomeTickSeconds
--
-- Profiles hold whole dollars, so each player's fractional remainder is carried in memory
-- between ticks (at most $1 is lost when they leave).
--
-- Offline (on load): base * street * rebirth * OfflineIncomeRate (0.5, v1.1) * VIP 2x,
-- for min(now - lastSeenAt, 8h). No comeback, crash or Eviction Night offline.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Enums = require(Shared.Enums)
local IncomeMath = require(script.Parent.Parent.Lib.IncomeMath)
local EconomyService = require(script.Parent.EconomyService)
local Net = require(script.Parent.Net)
local ProfileManager = require(script.Parent.ProfileManager)

local IncomeService = {}

local carry: { [Player]: number } = {}

-- Eviction Night reward multiplier; EventService (M3) will own this.
function IncomeService.eventRewardMultiplier(): number
	return 1
end

local function tick()
	local now = os.time()
	local eventMult = IncomeService.eventRewardMultiplier()
	for _, player in Players:GetPlayers() do
		local profile = ProfileManager.get(player)
		if profile then
			local perMinute = IncomeMath.effectivePerMinute(profile, now, eventMult)
			if perMinute > 0 then
				local total = (carry[player] or 0) + perMinute / 60 * Config.IncomeTickSeconds
				local whole = math.floor(total)
				carry[player] = total - whole
				if whole > 0 then
					EconomyService.grant(player, whole, "income")
				end
			end
		end
	end
end

local function grantOffline(player: Player)
	local profile = ProfileManager.get(player)
	if not profile then
		return
	end
	local elapsed = os.time() - profile.lastSeenAt
	local amount = IncomeMath.offlineCash(profile, elapsed)
	if amount <= 0 then
		return
	end
	EconomyService.grant(player, amount, "offline")
	print(`[IncomeService] {player.Name}: ${amount} offline income for {elapsed}s`)
	if elapsed >= Config.OfflineIncomeNoticeMinSeconds then
		Net.push(player, Enums.Push.OfflineIncome, {
			amount = amount,
			seconds = math.min(elapsed, Config.OfflineIncomeCapSeconds),
		})
	end
end

function IncomeService.Start(_self: any)
	ProfileManager.onLoaded(function(player, profile)
		carry[player] = 0
		-- A brand-new profile has lastSeenAt = now, so it earns nothing here.
		if profile.lastSeenAt > 0 then
			grantOffline(player)
		end
		-- Don't pay the same offline stretch twice (e.g. a Studio debug relog).
		profile.lastSeenAt = os.time()
	end)
	Players.PlayerRemoving:Connect(function(player)
		carry[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(Config.IncomeTickSeconds)
			tick()
		end
	end)
end

return IncomeService

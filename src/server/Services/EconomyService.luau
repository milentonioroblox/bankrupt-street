--!strict
-- The only place cash changes (GDD §15.1: server-authoritative). M0 has grant/spend; M1 adds
-- income ticks, purchases and escrow on top of these.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Formulas = require(Shared.Formulas)
local Types = require(Shared.Types)
local ProfileManager = require(script.Parent.ProfileManager)

local EconomyService = {}

function EconomyService.spendable(profile: Types.Profile): number
	return profile.cash - profile.reservedCash
end

-- Add whole-dollar cash. Counts toward lifetime earnings unless `countAsEarnings` is false.
function EconomyService.grant(player: Player, amount: number, _reason: string, countAsEarnings: boolean?): boolean
	local profile = ProfileManager.get(player)
	if not profile or not Formulas.isValidAmount(amount) then
		return false
	end
	profile.cash += amount
	if countAsEarnings ~= false then
		profile.lifetimeEarnings += amount
	end
	ProfileManager.push(player)
	return true
end

-- Spend from spendable cash. Returns false (and changes nothing) if they can't afford it.
function EconomyService.spend(player: Player, amount: number, _reason: string): boolean
	local profile = ProfileManager.get(player)
	if not profile or not Formulas.isValidAmount(amount) then
		return false
	end
	if EconomyService.spendable(profile) < amount then
		return false
	end
	profile.cash -= amount
	profile.lifetimeSpentCash += amount
	ProfileManager.push(player)
	return true
end

-- Debug/admin only: set cash to an exact value.
function EconomyService.setCash(player: Player, amount: number): boolean
	local profile = ProfileManager.get(player)
	if not profile or not Formulas.isValidAmount(amount) then
		return false
	end
	profile.cash = amount
	ProfileManager.push(player)
	return true
end

return EconomyService

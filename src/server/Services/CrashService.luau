--!strict
-- Market Crash schedule (GDD §6.1, §6.4, v1.1 §2).
--
-- Server-relative, not wall clock: crash k starts at serverStart + k * CrashIntervalSeconds and
-- lasts CrashWindowSeconds. CrashWarningSeconds before it, the street is warned. Rent ticks inside
-- (start, end] are charged x CrashRentMultiplier; with v1.1 values that is exactly one tick, the
-- one at the end of the window. Crashes run even on an empty street.
--
-- Replicated on ReplicatedStorage attributes:
--   CrashPhase    "none" | "warning" | "live"
--   CrashStartAt  start of the current or next window (os.time)
--   CrashEndAt    end of that window

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Enums = require(Shared.Enums)
local RentMath = require(Shared.RentMath)
local ServerEpoch = require(script.Parent.Parent.Lib.ServerEpoch)
local Signal = require(script.Parent.Parent.Lib.Signal)
local AnalyticsService = require(script.Parent.AnalyticsService)

local CrashService = {}

-- (newPhase, oldPhase)
CrashService.phaseChanged = Signal.new() :: Signal.Signal<string, string>

local phase: string = Enums.CrashPhase.None
local nextStart = 0 -- next scheduled window start
local windowStart = 0 -- current or next window (what clients see)
local windowEnd = 0
local recent: { { startAt: number, endAt: number } } = {} -- windows that may still own a rent tick

local function publish()
	ReplicatedStorage:SetAttribute("CrashPhase", phase)
	ReplicatedStorage:SetAttribute("CrashStartAt", windowStart)
	ReplicatedStorage:SetAttribute("CrashEndAt", windowEnd)
end

local function setPhase(new: string)
	if new == phase then
		return
	end
	local old = phase
	phase = new
	publish()
	print(`[CrashService] {old} -> {new} (window {windowStart}..{windowEnd})`)
	if new == Enums.CrashPhase.Live then
		AnalyticsService.event("crash_start", { endsAt = windowEnd })
	elseif old == Enums.CrashPhase.Live then
		AnalyticsService.event("crash_end", {})
	end
	CrashService.phaseChanged:fire(new, old)
end

local function openWindow(startAt: number, endAt: number)
	windowStart, windowEnd = startAt, endAt
	table.insert(recent, { startAt = startAt, endAt = endAt })
	if #recent > 4 then
		table.remove(recent, 1)
	end
	publish()
end

local function step()
	local now = os.time()
	if phase == Enums.CrashPhase.Live then
		if now >= windowEnd then
			setPhase(Enums.CrashPhase.None)
		end
		return
	end
	if now >= nextStart then
		openWindow(nextStart, nextStart + Config.CrashWindowSeconds)
		nextStart += Config.CrashIntervalSeconds
		setPhase(Enums.CrashPhase.Live)
	elseif now >= nextStart - Config.CrashWarningSeconds then
		if windowStart ~= nextStart then
			windowStart, windowEnd = nextStart, nextStart + Config.CrashWindowSeconds
			publish()
		end
		setPhase(Enums.CrashPhase.Warning)
	elseif windowStart ~= nextStart and phase == Enums.CrashPhase.None then
		windowStart, windowEnd = nextStart, nextStart + Config.CrashWindowSeconds
		publish()
	end
end

-- Is a rent tick at time `t` a crash tick?
function CrashService.isCrashTick(t: number): boolean
	for _, w in recent do
		if RentMath.inCrashWindow(t, w.startAt, w.endAt) then
			return true
		end
	end
	return false
end

function CrashService.phase(): string
	return phase
end

-- The window a player leaving now would owe crash rent for (warning or live), else nil.
function CrashService.pendingWindow(): (number?, number?)
	if phase == Enums.CrashPhase.Warning or phase == Enums.CrashPhase.Live then
		return windowStart, windowEnd
	end
	return nil, nil
end

-- Debug (/forcecrash): start a crash window now. The regular schedule is unchanged.
function CrashService.force(seconds: number?)
	local now = os.time()
	openWindow(now, now + (seconds or Config.CrashWindowSeconds))
	setPhase(Enums.CrashPhase.Live)
end

function CrashService.Init(_self: any)
	nextStart = ServerEpoch + Config.CrashIntervalSeconds
	windowStart, windowEnd = nextStart, nextStart + Config.CrashWindowSeconds
	publish()
end

function CrashService.Start(_self: any)
	task.spawn(function()
		while true do
			step()
			task.wait(0.5)
		end
	end)
end

return CrashService

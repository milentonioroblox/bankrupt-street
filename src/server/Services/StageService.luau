--!strict
-- Stage jumbotron (GDD §3.2 "rent clock and crash clock as world UI above the stage", §6.4).
-- Shows the street clocks while no auction is live; the stage clock goes red in a crash warning
-- and the window. AuctionService takes the screen over with StageService.setOverride later.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Enums = require(Shared.Enums)
local CrashService = require(script.Parent.CrashService)
local RentService = require(script.Parent.RentService)

local StageService = {}

local GOLD = Color3.fromRGB(255, 215, 90)
local RED = Color3.fromRGB(255, 70, 60)

local override: (() -> (string, Color3))? = nil

local function clock(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

local function screens(): { TextLabel }
	local out = {}
	local street = Workspace:FindFirstChild("Street")
	local jumbo = street and street:FindFirstChild("Stage") and street.Stage:FindFirstChild("Jumbotron")
	if jumbo then
		for _, sg in jumbo:GetChildren() do
			local t = sg:FindFirstChild("Text")
			if sg:IsA("SurfaceGui") and t and t:IsA("TextLabel") then
				table.insert(out, t)
			end
		end
	end
	return out
end

-- While set, `fn` decides the jumbotron text (auction view). Pass nil to go back to the clocks.
function StageService.setOverride(fn: (() -> (string, Color3))?)
	override = fn
end

local function clocksView(): (string, Color3)
	local now = os.time()
	local rentIn = clock(RentService.nextRentAt() - now)
	local phase = CrashService.phase()
	local startAt = ReplicatedStorage:GetAttribute("CrashStartAt") :: number? or now
	local endAt = ReplicatedStorage:GetAttribute("CrashEndAt") :: number? or now
	if phase == Enums.CrashPhase.Live then
		return `MARKET CRASH\nRENT ×{Config.CrashRentMultiplier} · {clock(endAt - now)}`, RED
	elseif phase == Enums.CrashPhase.Warning then
		return `CRASH IN {clock(startAt - now)}\nNEXT RENT {rentIn}`, RED
	end
	return `NEXT RENT {rentIn}\nCRASH IN {clock(startAt - now)}`, GOLD
end

function StageService.Start(_self: any)
	task.spawn(function()
		while true do
			local text, color = (override or clocksView)()
			for _, label in screens() do
				label.Text = text
				label.TextColor3 = color
			end
			task.wait(1)
		end
	end)
end

return StageService

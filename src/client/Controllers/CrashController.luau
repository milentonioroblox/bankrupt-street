--!strict
-- Market Crash presentation on the client (GDD §6.4): darker sky in the warning, red ambient in
-- the window, back to normal after with "Markets stabilize." Local-only Lighting changes.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Enums = require(Shared.Enums)
local HUDController = require(script.Parent.HUDController)

local CrashController = {}

local correction: ColorCorrectionEffect
local defaults: { Ambient: Color3, OutdoorAmbient: Color3, Brightness: number }

local LOOKS = {
	[Enums.CrashPhase.None] = { tint = Color3.new(1, 1, 1), brightness = 0, saturation = 0, dim = 0 },
	[Enums.CrashPhase.Warning] = {
		tint = Color3.fromRGB(235, 220, 220),
		brightness = -0.05,
		saturation = -0.2,
		dim = 0.2,
	},
	[Enums.CrashPhase.Live] = {
		tint = Color3.fromRGB(255, 160, 150),
		brightness = -0.08,
		saturation = -0.3,
		dim = 0.35,
	},
}

local function apply(phase: string)
	local look = LOOKS[phase] or LOOKS[Enums.CrashPhase.None]
	local info = TweenInfo.new(2, Enum.EasingStyle.Sine)
	TweenService:Create(correction, info, {
		TintColor = look.tint,
		Brightness = look.brightness,
		Saturation = look.saturation,
	}):Play()
	TweenService:Create(Lighting, info, {
		Brightness = defaults.Brightness * (1 - look.dim),
		OutdoorAmbient = defaults.OutdoorAmbient:Lerp(Color3.fromRGB(120, 30, 30), look.dim),
	}):Play()
end

function CrashController.Init(_self: any)
	correction = Instance.new("ColorCorrectionEffect")
	correction.Name = "CrashTint"
	correction.Parent = Lighting
	defaults = {
		Ambient = Lighting.Ambient,
		OutdoorAmbient = Lighting.OutdoorAmbient,
		Brightness = Lighting.Brightness,
	}
end

function CrashController.Start(_self: any)
	local last = ReplicatedStorage:GetAttribute("CrashPhase") or Enums.CrashPhase.None
	apply(last)
	ReplicatedStorage:GetAttributeChangedSignal("CrashPhase"):Connect(function()
		local phase = ReplicatedStorage:GetAttribute("CrashPhase")
		apply(phase)
		if phase == Enums.CrashPhase.Warning then
			HUDController.notice(`Market Crash in {Config.CrashWarningSeconds} seconds! Keep cash for rent.`)
		elseif phase == Enums.CrashPhase.Live then
			HUDController.notice(`MARKET CRASH — RENT ×{Config.CrashRentMultiplier}`)
		elseif last == Enums.CrashPhase.Live then
			HUDController.notice("Markets stabilize.")
		end
		last = phase
	end)
end

return CrashController

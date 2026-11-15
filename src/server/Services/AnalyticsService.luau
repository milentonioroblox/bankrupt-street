--!strict
-- Analytics events (GDD §18). For now: print in Studio, so playtests show the event stream.
-- The full event list and AnalyticsService (Roblox) wiring come with M1 item 14.

local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local AnalyticsService = {}

function AnalyticsService.event(name: string, data: { [string]: any }, player: Player?)
	if RunService:IsStudio() then
		local who = if player then ` {player.Name}` else ""
		local ok, json = pcall(HttpService.JSONEncode, HttpService, data)
		print(`[Analytics] {name}{who} {if ok then json else "?"}`)
	end
end

return AnalyticsService

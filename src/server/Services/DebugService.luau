--!strict
-- Debug commands (GDD §22 work order, §23). Studio, or group rank >= Config.AdminMinRank when
-- Config.AdminGroupId is set. Every command is logged.
--
-- Chat:  /givecash n   /setcash n   /save   /profile
-- Studio test hook: ServerStorage.DebugHook (BindableFunction), so command-bar / MCP scripts
-- can drive the live services: DebugHook:Invoke("givecash", userId, 500)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local TextChatService = game:GetService("TextChatService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local EconomyService = require(script.Parent.EconomyService)
local PlotService = require(script.Parent.PlotService)
local ProfileManager = require(script.Parent.ProfileManager)

local DebugService = {}

local adminCache: { [Player]: boolean } = {}

local function isAdmin(player: Player): boolean
	if RunService:IsStudio() then
		return true
	end
	if Config.AdminGroupId == 0 then
		return false
	end
	local cached = adminCache[player]
	if cached == nil then
		local ok, rank = pcall(player.GetRankInGroup, player, Config.AdminGroupId)
		cached = ok and rank >= Config.AdminMinRank
		adminCache[player] = cached
	end
	return cached == true
end

type Command = (player: Player, args: { string }) -> string

local commands: { [string]: Command } = {
	givecash = function(player, args)
		local n = tonumber(args[1])
		if not n or not EconomyService.grant(player, math.floor(n), "debug", false) then
			return "usage: /givecash <whole number>"
		end
		return `gave ${math.floor(n)}`
	end,
	setcash = function(player, args)
		local n = tonumber(args[1])
		if not n or not EconomyService.setCash(player, math.floor(n)) then
			return "usage: /setcash <whole number>"
		end
		return `cash set to ${math.floor(n)}`
	end,
	save = function(player)
		ProfileManager.saveNow(player)
		return "saved"
	end,
	profile = function(player)
		local p = ProfileManager.get(player)
		if not p then
			return "no profile"
		end
		return `cash={p.cash} house={p.houseLevel} street={p.streetTier} plot={PlotService.getPlotId(player) or 0}`
	end,
}

function DebugService.run(player: Player, name: string, args: { string }): string
	if not isAdmin(player) then
		return "not allowed"
	end
	local cmd = commands[string.lower(name)]
	if not cmd then
		return `unknown command {name}`
	end
	local result = cmd(player, args)
	print(`[Debug] {player.Name} ({player.UserId}) /{name} {table.concat(args, " ")} -> {result}`)
	return result
end

local function onChat(player: Player, text: string)
	if string.sub(text, 1, 1) ~= "/" then
		return
	end
	local words = string.split(string.sub(text, 2), " ")
	local name = table.remove(words, 1)
	if name and commands[string.lower(name)] then
		DebugService.run(player, name, words)
	end
end

function DebugService.Init(_self: any)
	if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
		local folder = Instance.new("Folder")
		folder.Name = "DebugCommands"
		for name in commands do
			local c = Instance.new("TextChatCommand")
			c.Name = `Debug_{name}`
			c.PrimaryAlias = `/{name}`
			c.Triggered:Connect(function(source: TextSource, text: string)
				local player = Players:GetPlayerByUserId(source.UserId)
				if player then
					onChat(player, text)
				end
			end)
			c.Parent = folder
		end
		folder.Parent = TextChatService
	else
		Players.PlayerAdded:Connect(function(player)
			player.Chatted:Connect(function(text)
				onChat(player, text)
			end)
		end)
	end

	if RunService:IsStudio() then
		local hook = Instance.new("BindableFunction")
		hook.Name = "DebugHook"
		hook.OnInvoke = function(action: string, userId: number, ...: any): any
			local player = Players:GetPlayerByUserId(userId)
			if action == "relog" then
				assert(player, "no player")
				return ProfileManager.debugRelog(player)
			elseif action == "claim" then
				assert(player, "no player")
				return PlotService.claim(player, (...))
			elseif action == "release" then
				assert(player, "no player")
				return PlotService.release(player)
			elseif action == "state" then
				local p = player and ProfileManager.get(player)
				return {
					cash = p and p.cash,
					plotId = player and PlotService.getPlotId(player),
					mock = ProfileManager.usingMockStore,
				}
			end
			assert(player, "no player")
			return DebugService.run(player, action, { ... })
		end
		hook.Parent = ServerStorage
	end
end

function DebugService.Start(_self: any)
	Players.PlayerRemoving:Connect(function(player)
		adminCache[player] = nil
	end)
	if RunService:IsStudio() and Config.RunFormulaSpecInStudio then
		local _, failed = require(Shared["Formulas.spec"])()
		if failed > 0 then
			warn(`[Debug] Formulas.spec: {failed} FAILED`)
		end
	end
end

return DebugService

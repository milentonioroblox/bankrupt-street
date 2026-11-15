--!strict
-- Single inbound dispatcher (GDD §21.2). Every client request goes through here:
-- rate limit -> payload must be a table -> handler. Handlers return a NetResult.
-- Remotes are created at require time so other services can register in their Init.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Types = require(Shared.Types)

type Handler = (player: Player, payload: { [any]: any }) -> Types.NetResult
type Limit = { max: number, window: number }

local Net = {}

local folder = Instance.new("Folder")
folder.Name = Remotes.FolderName
local request = Instance.new("RemoteFunction")
request.Name = Remotes.Request
request.Parent = folder
local statePush = Instance.new("RemoteEvent")
statePush.Name = Remotes.StatePush
statePush.Parent = folder
folder.Parent = ReplicatedStorage

local handlers: { [string]: { fn: Handler, limit: Limit } } = {}
local hits: { [Player]: { [string]: { number } } } = {}

function Net.fail(code: string, message: string): Types.NetResult
	return { ok = false, code = code, message = message }
end

function Net.ok(data: any?): Types.NetResult
	return { ok = true, data = data }
end

function Net.register(name: string, fn: Handler, limit: Limit?)
	assert(handlers[name] == nil, `Net: duplicate handler {name}`)
	handlers[name] = { fn = fn, limit = limit or Config.RateLimit.Default }
end

function Net.push(player: Player, kind: string, data: any)
	statePush:FireClient(player, kind, data)
end

function Net.pushAll(kind: string, data: any)
	statePush:FireAllClients(kind, data)
end

local function allowed(player: Player, name: string, limit: Limit): boolean
	local now = os.clock()
	local byName = hits[player]
	if not byName then
		byName = {}
		hits[player] = byName
	end
	local list = byName[name] or {}
	local kept = {}
	for _, t in list do
		if now - t < limit.window then
			table.insert(kept, t)
		end
	end
	if #kept >= limit.max then
		byName[name] = kept
		return false
	end
	table.insert(kept, now)
	byName[name] = kept
	return true
end

request.OnServerInvoke = function(player: Player, name: any, payload: any): Types.NetResult
	if type(name) ~= "string" then
		return Net.fail("bad_request", "Bad request.")
	end
	local entry = handlers[name]
	if not entry then
		return Net.fail("unknown", "Unknown request.")
	end
	if not allowed(player, name, entry.limit) then
		return Net.fail("rate_limited", "Slow down.")
	end
	if payload == nil then
		payload = {}
	elseif type(payload) ~= "table" then
		return Net.fail("bad_request", "Bad request.")
	end
	local ok, result = pcall(entry.fn, player, payload)
	if not ok then
		warn(`[Net] {name} from {player.UserId} errored: {result}`)
		return Net.fail("server_error", "Something went wrong.")
	end
	return result
end

Players.PlayerRemoving:Connect(function(player)
	hits[player] = nil
end)

return Net

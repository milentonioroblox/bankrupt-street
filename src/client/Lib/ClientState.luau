--!strict
-- Client-side view of the server state, plus request helper. Controllers read `ClientState.state`
-- and listen to `changed`; the server is always the source of truth.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Enums = require(Shared.Enums)
local Remotes = require(Shared.Remotes)
local Types = require(Shared.Types)

local folder = ReplicatedStorage:WaitForChild(Remotes.FolderName)
local request = folder:WaitForChild(Remotes.Request) :: RemoteFunction
local statePush = folder:WaitForChild(Remotes.StatePush) :: RemoteEvent

local ClientState = {}

ClientState.state = nil :: Types.StateSlice?
ClientState.receivedAt = 0 -- os.clock() when `state` arrived (for the predicted ticker)

local changed = Instance.new("BindableEvent")
local pushed = Instance.new("BindableEvent")
ClientState.changed = changed.Event -- ()
ClientState.pushed = pushed.Event -- (kind: string, data: any) for non-State pushes

function ClientState.request(name: string, payload: { [string]: any }?): Types.NetResult
	local ok, result = pcall(request.InvokeServer, request, name, payload or {})
	if not ok or type(result) ~= "table" then
		return { ok = false, code = "network", message = "Couldn't reach the server." }
	end
	return result
end

local function setState(s: Types.StateSlice)
	ClientState.state = s
	ClientState.receivedAt = os.clock()
	changed:Fire()
end

statePush.OnClientEvent:Connect(function(kind: string, data: any)
	if kind == Enums.Push.State then
		setState(data)
	else
		pushed:Fire(kind, data)
	end
end)

-- In case the first push arrived before anyone listened.
task.spawn(function()
	local result = ClientState.request(Remotes.GetState)
	if result.ok and ClientState.state == nil then
		setState(result.data)
	end
end)

function ClientState.money(n: number): string
	local s = tostring(math.floor(n))
	local formatted = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return "$" .. (formatted:gsub("^,", ""))
end

return ClientState

--!strict
-- M0 greybox HUD: cash, house and plot readout plus short notices. Replaced by the ForgeGUI
-- HUD in M1. The server is the source of truth; this only displays what StatePush sends.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Enums = require(Shared.Enums)
local Remotes = require(Shared.Remotes)
local Types = require(Shared.Types)

local HUDController = {}

local player = Players.LocalPlayer
local state: Types.StateSlice? = nil
local statusLabel: TextLabel
local noticeLabel: TextLabel
local noticeSerial = 0

local function money(n: number): string
	local s = tostring(math.floor(n))
	local formatted = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return "$" .. formatted:gsub("^,", "")
end

local function render()
	local plotId = player:GetAttribute("PlotId")
	local plotText = if type(plotId) == "number" and plotId > 0 then `Plot {plotId}` else "No plot: walk to a gold pad"
	if state then
		statusLabel.Text = `{money(state.cash)}   ·   {state.houseName}   ·   {plotText}`
	else
		statusLabel.Text = "Loading..."
	end
end

local function notice(text: string)
	noticeSerial += 1
	local serial = noticeSerial
	noticeLabel.Text = text
	noticeLabel.Visible = true
	task.delay(3, function()
		if serial == noticeSerial then
			noticeLabel.Visible = false
		end
	end)
end

local function makeLabel(parent: Instance, name: string, y: number, height: number): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.AnchorPoint = Vector2.new(0.5, 0)
	l.Position = UDim2.new(0.5, 0, 0, y)
	l.Size = UDim2.new(0, 520, 0, height)
	l.BackgroundColor3 = Color3.fromRGB(25, 20, 18)
	l.BackgroundTransparency = 0.25
	l.TextColor3 = Color3.fromRGB(255, 230, 160)
	l.Font = Enum.Font.GothamBold
	l.TextScaled = true
	l.Text = ""
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = l
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 10)
	pad.PaddingRight = UDim.new(0, 10)
	pad.PaddingTop = UDim.new(0, 4)
	pad.PaddingBottom = UDim.new(0, 4)
	pad.Parent = l
	l.Parent = parent
	return l
end

function HUDController.Init(_self: any)
	local gui = Instance.new("ScreenGui")
	gui.Name = "HUD"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	statusLabel = makeLabel(gui, "Status", 8, 36)
	noticeLabel = makeLabel(gui, "Notice", 52, 28)
	noticeLabel.Visible = false
	gui.Parent = player:WaitForChild("PlayerGui")
	render()
end

function HUDController.Start(_self: any)
	local folder = ReplicatedStorage:WaitForChild(Remotes.FolderName)
	local statePush = folder:WaitForChild(Remotes.StatePush) :: RemoteEvent
	local request = folder:WaitForChild(Remotes.Request) :: RemoteFunction

	statePush.OnClientEvent:Connect(function(kind: string, data: any)
		if kind == Enums.Push.State then
			state = data
			render()
		elseif kind == Enums.Push.Notice and type(data) == "string" then
			notice(data)
		end
	end)
	player:GetAttributeChangedSignal("PlotId"):Connect(render)

	-- In case the first push arrived before we connected.
	local result = request:InvokeServer(Remotes.GetState, {})
	if type(result) == "table" and result.ok and state == nil then
		state = result.data
		render()
	end
end

return HUDController

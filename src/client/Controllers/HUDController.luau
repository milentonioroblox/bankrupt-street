--!strict
-- Greybox HUD (GDD §16 `HUD`, `OfflineIncomeModal`): spendable cash with a predicted ticker,
-- income/min, house and plot, short notices, and the "while you were away" modal.
-- Replaced by the ForgeGUI HUD later; the server value always wins on each push.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Enums = require(Shared.Enums)
local ClientState = require(script.Parent.Parent.Lib.ClientState)

local HUDController = {}

local player = Players.LocalPlayer
local money = ClientState.money
local cashLabel: TextLabel
local infoLabel: TextLabel
local noticeLabel: TextLabel
local modal: Frame
local modalText: TextLabel
local noticeSerial = 0

local function panel(parent: Instance, name: string, pos: UDim2, size: UDim2): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.AnchorPoint = Vector2.new(0.5, 0)
	l.Position = pos
	l.Size = size
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

-- Spendable cash the server will have credited by now (income keeps flowing between pushes).
local function predictedCash(): number?
	local s = ClientState.state
	if not s then
		return nil
	end
	local elapsed = os.clock() - ClientState.receivedAt
	return s.spendable + s.incomePerMinute / 60 * math.min(elapsed, 5)
end

local function renderInfo()
	local s = ClientState.state
	local plotId = player:GetAttribute("PlotId")
	local plotText = if type(plotId) == "number" and plotId > 0 then `Plot {plotId}` else "No plot"
	if not s then
		infoLabel.Text = "Loading..."
		return
	end
	local rate = s.incomePerMinute
	local rateText = if rate % 1 == 0 then tostring(rate) else string.format("%.1f", rate)
	local boost = if s.comebackUntil > s.serverTime then "   ·   2× COMEBACK" else ""
	infoLabel.Text =
		`+${rateText}/min   ·   {s.houseName}   ·   {plotText}   ·   {s.slotsUsed}/{s.slotsMax} slots{boost}`
end

function HUDController.notice(text: string)
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

local function showOffline(amount: number, seconds: number)
	local h = math.floor(seconds / 3600)
	local m = math.floor(seconds % 3600 / 60)
	local away = if h > 0 then `{h}h {m}m` else `{m}m`
	modalText.Text = `While you were away ({away}):\n{money(amount)}`
	modal.Visible = true
end

function HUDController.Init(_self: any)
	local gui = Instance.new("ScreenGui")
	gui.Name = "HUD"
	gui.ResetOnSpawn = false
	cashLabel = panel(gui, "Cash", UDim2.new(0.5, 0, 0, 8), UDim2.new(0, 260, 0, 44))
	cashLabel.TextColor3 = Color3.fromRGB(140, 230, 120)
	infoLabel = panel(gui, "Info", UDim2.new(0.5, 0, 0, 56), UDim2.new(0, 560, 0, 26))
	noticeLabel = panel(gui, "Notice", UDim2.new(0.5, 0, 0, 90), UDim2.new(0, 520, 0, 28))
	noticeLabel.Visible = false

	modal = Instance.new("Frame")
	modal.Name = "OfflineIncomeModal"
	modal.AnchorPoint = Vector2.new(0.5, 0.5)
	modal.Position = UDim2.fromScale(0.5, 0.45)
	modal.Size = UDim2.new(0, 360, 0, 170)
	modal.BackgroundColor3 = Color3.fromRGB(30, 24, 20)
	modal.Visible = false
	Instance.new("UICorner").Parent = modal
	modalText = panel(modal, "Text", UDim2.new(0.5, 0, 0, 12), UDim2.new(1, -24, 0, 90))
	modalText.BackgroundTransparency = 1
	local ok = Instance.new("TextButton")
	ok.Name = "Ok"
	ok.AnchorPoint = Vector2.new(0.5, 1)
	ok.Position = UDim2.new(0.5, 0, 1, -12)
	ok.Size = UDim2.new(0, 140, 0, 40)
	ok.BackgroundColor3 = Color3.fromRGB(212, 175, 55)
	ok.Font = Enum.Font.GothamBold
	ok.TextScaled = true
	ok.Text = "Nice"
	Instance.new("UICorner").Parent = ok
	ok.Parent = modal
	ok.Activated:Connect(function()
		modal.Visible = false
	end)
	modal.Parent = gui

	gui.Parent = player:WaitForChild("PlayerGui")
	renderInfo()
end

function HUDController.Start(_self: any)
	ClientState.changed:Connect(renderInfo)
	player:GetAttributeChangedSignal("PlotId"):Connect(renderInfo)
	ClientState.pushed:Connect(function(kind: string, data: any)
		if kind == Enums.Push.Notice and type(data) == "string" then
			HUDController.notice(data)
		elseif kind == Enums.Push.OfflineIncome and type(data) == "table" then
			showOffline(data.amount, data.seconds)
		end
	end)
	RunService.RenderStepped:Connect(function()
		local cash = predictedCash()
		cashLabel.Text = if cash then money(cash) else "..."
	end)
end

return HUDController

--!strict
-- Greybox shop (GDD §16 `UpgradeHouse`, `PropertyShop`, plus selling owned properties).
-- Prices shown come from the shared Config; the server re-checks everything on each request.
-- Toggle with the SHOP button or the B key. Replaced by ForgeGUI screens later.
--
-- Rent safety (v1.1 §4): if a purchase would leave the player unable to pay the next rent
-- (spendable after the purchase + income until the tick < rent with the new holdings), ask
-- "You won't be able to pay rent in M:SS" with Confirm / Cancel first.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Formulas = require(Shared.Formulas)
local Remotes = require(Shared.Remotes)
local ClientState = require(script.Parent.Parent.Lib.ClientState)
local HUDController = require(script.Parent.HUDController)

local ShopController = {}

local player = Players.LocalPlayer
local money = ClientState.money
local panelFrame: Frame
local list: ScrollingFrame
local confirmFrame: Frame
local confirmText: TextLabel
local confirmAction: (() -> ())? = nil
local busy = false

local DARK = Color3.fromRGB(30, 24, 20)
local ROW = Color3.fromRGB(48, 40, 34)
local GOLD = Color3.fromRGB(212, 175, 55)
local GREEN = Color3.fromRGB(90, 170, 90)
local RED = Color3.fromRGB(170, 70, 60)
local GREY = Color3.fromRGB(90, 90, 90)

local function corner(parent: Instance)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 6)
	c.Parent = parent
end

local function text(parent: Instance, s: string, pos: UDim2, size: UDim2, align: Enum.TextXAlignment?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Position = pos
	l.Size = size
	l.Font = Enum.Font.GothamMedium
	l.TextColor3 = Color3.fromRGB(240, 230, 210)
	l.TextScaled = true
	l.TextXAlignment = align or Enum.TextXAlignment.Left
	l.Text = s
	l.Parent = parent
	return l
end

-- Buttons whose enabled state depends on cash; refreshed in place on every state push so the
-- list isn't rebuilt (rebuilding under the mouse would swallow clicks).
local refreshers: { () -> () } = {}

local function button(parent: Instance, s: string, color: Color3, enabled: () -> boolean, onClick: () -> ()): TextButton
	local b = Instance.new("TextButton")
	b.Name = "Action"
	b.AnchorPoint = Vector2.new(1, 0.5)
	b.Position = UDim2.new(1, -8, 0.5, 0)
	b.Size = UDim2.new(0, 120, 0, 30)
	b.Font = Enum.Font.GothamBold
	b.TextColor3 = Color3.new(1, 1, 1)
	b.TextScaled = true
	b.Text = s
	corner(b)
	local function refresh()
		local on = enabled()
		b.BackgroundColor3 = if on then color else GREY
		b.AutoButtonColor = on
	end
	refresh()
	table.insert(refreshers, refresh)
	b.Parent = parent
	b.Activated:Connect(function()
		if enabled() and not busy then
			onClick()
		end
	end)
	return b
end

local function never(): boolean
	return false
end

local function row(order: number, height: number?, name: string?): Frame
	local f = Instance.new("Frame")
	f.Name = name or `Row{order}`
	f.LayoutOrder = order
	f.Size = UDim2.new(1, -8, 0, height or 44)
	f.BackgroundColor3 = ROW
	corner(f)
	f.Parent = list
	return f
end

local function header(order: number, s: string)
	local f = row(order, 26)
	f.BackgroundTransparency = 1
	text(f, s, UDim2.new(0, 4, 0, 0), UDim2.new(1, -8, 1, 0)).TextColor3 = GOLD
end

local function send(name: string, payload: { [string]: any }?, okText: string?)
	busy = true
	local result = ClientState.request(name, payload)
	busy = false
	if result.ok then
		if okText then
			HUDController.notice(okText)
		end
	else
		HUDController.notice(result.message or "Couldn't do that.")
	end
end

-- Ask before a purchase that would leave the player short at the next rent tick.
-- `holdings` is what they'd own afterwards; `cost` what it takes from spendable cash.
local function withRentCheck(cost: number, holdings: any, go: () -> ())
	local s = ClientState.state
	if not s then
		return
	end
	local rent, secondsLeft = ClientState.projectedRent(holdings)
	local expected = s.spendable - cost + s.incomePerMinute / 60 * secondsLeft
	if expected >= rent then
		go()
		return
	end
	confirmText.Text = `You won't be able to pay rent in {ClientState.clock(secondsLeft)}.\n`
		.. `Rent will be {money(rent)}; you'd have about {money(math.max(0, expected))}.`
	confirmAction = go
	confirmFrame.Visible = true
end

-- What the list's rows depend on. Cash isn't part of it: cash only changes button states.
local function structureKey(): string
	local s = ClientState.state
	if not s then
		return ""
	end
	local ids = {}
	for _, inst in s.properties do
		table.insert(ids, `{inst.instanceId}@{inst.slotIndex}:{inst.boundUntil > s.serverTime}`)
	end
	table.sort(ids)
	return `{s.houseLevel}|{s.streetTier}|{s.slotsMax}|{table.concat(ids, ",")}`
end
local renderedKey = ""

local function canAfford(cost: number): () -> boolean
	return function()
		local now = ClientState.state
		return now ~= nil and now.spendable >= cost
	end
end

local function always(): boolean
	return true
end

local function render()
	for _, child in list:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	table.clear(refreshers)
	renderedKey = structureKey()
	local s = ClientState.state
	if not s then
		return
	end
	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end

	-- House upgrade
	header(nextOrder(), `HOUSE: {s.houseName} (level {s.houseLevel})`)
	local target = s.houseLevel + 1
	local f = row(nextOrder(), nil, "HouseUpgrade")
	if target > Config.MaxHouseLevel then
		text(f, "Top of the street.", UDim2.new(0, 10, 0, 6), UDim2.new(1, -150, 1, -12))
	else
		local cost = Config.HouseUpgradeCost[target]
		local slots = Config.HousePropertySlots[target]
		text(
			f,
			`Upgrade to {Config.HouseDisplayNames[target]}   {money(cost)}   ({slots} slots)`,
			UDim2.new(0, 10, 0, 6),
			UDim2.new(1, -150, 1, -12)
		)
		button(f, "UPGRADE", GOLD, canAfford(cost), function()
			local after = { houseLevel = target, streetTier = s.streetTier, properties = s.properties }
			withRentCheck(cost, after, function()
				send(Remotes.UpgradeHouse, {}, `Moved up to {Config.HouseDisplayNames[target]}!`)
			end)
		end)
	end

	-- Property catalog for this street
	header(nextOrder(), `PROPERTIES   ({s.slotsUsed}/{s.slotsMax} slots used)`)
	for _, def in Config.Properties do
		if def.minStreet <= s.streetTier then
			local r = row(nextOrder(), nil, `Buy_{def.id}`)
			text(
				r,
				`{def.name}   {money(def.cost)}   +${def.incomePerMinute}/min`,
				UDim2.new(0, 10, 0, 6),
				UDim2.new(1, -150, 1, -12)
			)
			if s.houseLevel < def.minHouse then
				button(r, `Needs {Config.HouseDisplayNames[def.minHouse]}`, GREY, never, function() end)
			elseif s.slotsUsed >= s.slotsMax then
				button(r, "No slot", GREY, never, function() end)
			else
				button(r, "BUY", GREEN, canAfford(def.cost), function()
					local props = table.clone(s.properties) :: { any }
					table.insert(props, { propertyId = def.id })
					local after = { houseLevel = s.houseLevel, streetTier = s.streetTier, properties = props }
					withRentCheck(def.cost, after, function()
						send(Remotes.BuyProperty, { propertyId = def.id }, `Bought a {def.name}.`)
					end)
				end)
			end
		end
	end

	-- Owned
	if #s.properties > 0 then
		header(nextOrder(), "YOUR PROPERTIES")
		local owned = table.clone(s.properties)
		table.sort(owned, function(a, b)
			return a.slotIndex < b.slotIndex
		end)
		for _, inst in owned do
			local def = Config.PropertiesById[inst.propertyId]
			if def then
				local r = row(nextOrder(), nil, `Owned_{inst.slotIndex}`)
				text(r, `Slot {inst.slotIndex}: {def.name}`, UDim2.new(0, 10, 0, 6), UDim2.new(1, -150, 1, -12))
				local price = Formulas.sellPrice(def.cost, Config.SellBackRatio)
				local bound = inst.boundUntil > s.serverTime
				button(
					r,
					if bound then "Bound" else `Sell {money(price)}`,
					RED,
					if bound then never else always,
					function()
						send(Remotes.SellProperty, { instanceId = inst.instanceId }, `Sold for {money(price)}.`)
					end
				)
			end
		end
	end
end

local function toggle()
	panelFrame.Visible = not panelFrame.Visible
	if panelFrame.Visible then
		render()
	end
end

function ShopController.Init(_self: any)
	local gui = Instance.new("ScreenGui")
	gui.Name = "Shop"
	gui.ResetOnSpawn = false

	local open = Instance.new("TextButton")
	open.Name = "OpenShop"
	open.AnchorPoint = Vector2.new(0, 1)
	open.Position = UDim2.new(0, 16, 1, -16)
	open.Size = UDim2.new(0, 120, 0, 48)
	open.BackgroundColor3 = GOLD
	open.Font = Enum.Font.GothamBold
	open.TextScaled = true
	open.Text = "SHOP"
	corner(open)
	open.Activated:Connect(toggle)
	open.Parent = gui

	panelFrame = Instance.new("Frame")
	panelFrame.Name = "Panel"
	panelFrame.AnchorPoint = Vector2.new(0, 1)
	panelFrame.Position = UDim2.new(0, 16, 1, -76)
	panelFrame.Size = UDim2.new(0, 520, 0.6, 0)
	panelFrame.BackgroundColor3 = DARK
	panelFrame.BackgroundTransparency = 0.05
	panelFrame.Visible = false
	corner(panelFrame)
	panelFrame.Parent = gui

	list = Instance.new("ScrollingFrame")
	list.Name = "List"
	list.Position = UDim2.new(0, 8, 0, 8)
	list.Size = UDim2.new(1, -16, 1, -16)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list
	list.Parent = panelFrame

	confirmFrame = Instance.new("Frame")
	confirmFrame.Name = "RentWarning"
	confirmFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	confirmFrame.Position = UDim2.fromScale(0.5, 0.45)
	confirmFrame.Size = UDim2.new(0, 420, 0, 180)
	confirmFrame.BackgroundColor3 = DARK
	confirmFrame.Visible = false
	confirmFrame.ZIndex = 5
	corner(confirmFrame)
	confirmText = text(confirmFrame, "", UDim2.new(0, 16, 0, 14), UDim2.new(1, -32, 0, 90), Enum.TextXAlignment.Center)
	confirmText.TextColor3 = Color3.fromRGB(255, 140, 120)
	local function choice(name: string, label: string, color: Color3, x: number, onClick: () -> ())
		local b = Instance.new("TextButton")
		b.Name = name
		b.AnchorPoint = Vector2.new(0.5, 1)
		b.Position = UDim2.new(x, 0, 1, -14)
		b.Size = UDim2.new(0, 150, 0, 40)
		b.BackgroundColor3 = color
		b.Font = Enum.Font.GothamBold
		b.TextColor3 = Color3.new(1, 1, 1)
		b.TextScaled = true
		b.Text = label
		corner(b)
		b.Parent = confirmFrame
		b.Activated:Connect(onClick)
	end
	choice("Confirm", "Buy anyway", RED, 0.28, function()
		confirmFrame.Visible = false
		local go = confirmAction
		confirmAction = nil
		if go then
			go()
		end
	end)
	choice("Cancel", "Cancel", GREY, 0.72, function()
		confirmFrame.Visible = false
		confirmAction = nil
	end)
	confirmFrame.Parent = gui

	gui.Parent = player:WaitForChild("PlayerGui")
end

function ShopController.Start(_self: any)
	ClientState.changed:Connect(function()
		if not panelFrame.Visible then
			return
		end
		if structureKey() ~= renderedKey then
			render()
		else
			for _, refresh in refreshers do
				refresh()
			end
		end
	end)
	ContextActionService:BindAction("ToggleShop", function(_, state)
		if state == Enum.UserInputState.Begin then
			toggle()
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.B)
end

return ShopController

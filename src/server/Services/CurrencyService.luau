--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Economy = require(ReplicatedStorage.Shared.Config.Economy)

local CurrencyService = {}

function CurrencyService:Start()
	local function onPlayer(player: Player)
		local stats = Instance.new("Folder")
		stats.Name = "leaderstats"
		local cash = Instance.new("IntValue")
		cash.Name = Economy.CurrencyName
		cash.Value = Economy.StartingCash
		cash.Parent = stats
		stats.Parent = player
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, p in Players:GetPlayers() do
		onPlayer(p)
	end
end

function CurrencyService:Add(player: Player, amount: number)
	local stats = player:FindFirstChild("leaderstats")
	local cash = stats and stats:FindFirstChild(Economy.CurrencyName) :: IntValue?
	if cash then
		cash.Value += amount
	end
end

return CurrencyService

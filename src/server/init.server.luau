--!strict
-- Server entry point: loads every module in Services and calls :Init() then :Start().
local services = {}
for _, module in script.Services:GetChildren() do
	if module:IsA("ModuleScript") then
		table.insert(services, require(module) :: any)
	end
end
for _, s in services do
	if s.Init then
		s:Init()
	end
end
for _, s in services do
	if s.Start then
		task.spawn(s.Start, s)
	end
end

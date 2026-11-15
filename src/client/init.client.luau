--!strict
-- Client entry point: loads every module in Controllers and calls :Init() then :Start().
local controllers = {}
for _, module in script.Controllers:GetChildren() do
	if module:IsA("ModuleScript") then
		table.insert(controllers, require(module) :: any)
	end
end
for _, c in controllers do
	if c.Init then c:Init() end
end
for _, c in controllers do
	if c.Start then task.spawn(c.Start, c) end
end

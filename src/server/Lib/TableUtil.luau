--!strict
-- Small table helpers used by profile code.

local TableUtil = {}

function TableUtil.deepCopy<T>(value: T): T
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	for k, v in value :: any do
		out[TableUtil.deepCopy(k)] = TableUtil.deepCopy(v)
	end
	return (out :: any) :: T
end

-- Fill keys missing from `target` (or holding the wrong type) with copies from `template`.
-- Recurses into dictionary tables; array defaults (empty lists) are only copied when missing.
-- Keys in `target` that the template doesn't know are kept (forward compatibility).
function TableUtil.reconcile(target: { [any]: any }, template: { [any]: any }): { string }
	local fixed = {}
	for k, default in template do
		local current = target[k]
		if current == nil or type(current) ~= type(default) then
			if current ~= nil then
				table.insert(fixed, tostring(k))
			end
			target[k] = TableUtil.deepCopy(default)
		elseif type(default) == "table" and next(default) ~= nil and #default == 0 then
			for _, sub in TableUtil.reconcile(current, default) do
				table.insert(fixed, `{k}.{sub}`)
			end
		end
	end
	return fixed
end

return TableUtil

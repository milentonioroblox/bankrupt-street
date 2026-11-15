--!strict
-- In-memory stand-in for a GlobalDataStore (Studio only, GDD M0 "Studio mock store fallback").
-- Implements the two calls ProfileManager uses, with the same semantics: UpdateAsync's
-- transform may return nil to cancel the write. Values are deep-copied in and out so callers
-- can't mutate the "stored" data by reference, just like a real DataStore.

local TableUtil = require(script.Parent.TableUtil)

local MockStore = {}
MockStore.__index = MockStore

export type MockStore = typeof(setmetatable({} :: { data: { [string]: any } }, MockStore))

function MockStore.new(): MockStore
	return setmetatable({ data = {} }, MockStore)
end

function MockStore.GetAsync(self: MockStore, key: string): any
	task.wait() -- real calls yield; keep callers honest
	return TableUtil.deepCopy(self.data[key])
end

function MockStore.UpdateAsync(self: MockStore, key: string, transform: (any, any) -> any): any
	task.wait()
	local new = transform(TableUtil.deepCopy(self.data[key]), nil)
	if new == nil then
		return nil
	end
	self.data[key] = TableUtil.deepCopy(new)
	return TableUtil.deepCopy(new)
end

return MockStore

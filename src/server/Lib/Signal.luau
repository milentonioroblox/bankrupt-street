--!strict
-- Minimal signal so services can react to each other without require cycles.

local Signal = {}
Signal.__index = Signal

export type Signal<T...> = {
	connect: (self: Signal<T...>, fn: (T...) -> ()) -> (),
	fire: (self: Signal<T...>, T...) -> (),
}

function Signal.new<T...>(): Signal<T...>
	local self = setmetatable({ handlers = {} :: { (T...) -> () } }, Signal)
	return self :: any
end

function Signal.connect(self: any, fn)
	table.insert(self.handlers, fn)
end

function Signal.fire(self: any, ...)
	for _, fn in self.handlers do
		task.spawn(fn, ...)
	end
end

return Signal

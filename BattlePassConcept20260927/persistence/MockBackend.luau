-- Memory-only DataStore stand-in. Studio defaults to this backend so testing
-- cannot accidentally read or write the production game's save records.
local Schema = require(script.Parent.ProfileSchema)

local MockBackend = {}
MockBackend.__index = MockBackend

function MockBackend.new()
	return setmetatable({values = {}, failures = 0, afterCommitFailures = 0}, MockBackend)
end

function MockBackend:UpdateAsync(key, transform)
	if self.failures > 0 then
		self.failures -= 1
		error("simulated DataStore failure")
	end
	local current = Schema.copy(self.values[key])
	local nextValue = transform(current)
	if nextValue == nil then return nil end
	self.values[key] = Schema.copy(nextValue)
	if self.afterCommitFailures > 0 then
		self.afterCommitFailures -= 1
		error("simulated ambiguous committed write")
	end
	return Schema.copy(nextValue)
end

return MockBackend

local Players = {}
local now = 10
local os = { clock = function() return now end }
local request = {}
local calls = 0
local result = { GetSnapshot = function(_, player, scope)
	calls += 1
	return {scope=scope, boards={MostWins={entries={}}}}
end }
		local requests = {}
		local scopes = { global = true, server = true, region = true }
		request.OnServerInvoke = function(player, scope)
			if player.Parent ~= Players or type(scope) ~= "string" or not scopes[scope] then
				return { state = "unavailable", status = "INVALID REQUEST" }
			end
			local now = os.clock()
			local rate = requests[player]
			if not rate or now - rate.started >= 5 then
				rate = { started = now, count = 0 }
				requests[player] = rate
			end
			if rate.count >= 10 then
				return { scope = scope, state = "loading", status = "PLEASE WAIT", retryAfter = 5 }
			end
			rate.count += 1
			local succeeded, snapshot = pcall(result.GetSnapshot, result, player, scope)
			if succeeded then return snapshot end
			warn("Leaderboard request failed: " .. tostring(snapshot))
			return { scope = scope, state = "unavailable", status = "RANKINGS UNAVAILABLE", retryAfter = 10 }
		end

local player = {Parent=Players}
assert(request.OnServerInvoke(player, {}).state == "unavailable")
assert(request.OnServerInvoke(player, "country").state == "unavailable")
assert(request.OnServerInvoke({Parent={}}, "global").state == "unavailable")
assert(calls == 0, "Invalid request reached service")
for n=1,10 do assert(request.OnServerInvoke(player, n%2==0 and "region" or "server").boards) end
assert(calls == 10)
assert(request.OnServerInvoke(player, "global").status == "PLEASE WAIT")
local other={Parent=Players}
assert(request.OnServerInvoke(other,"global").boards, "One player throttled another")
now=15
assert(request.OnServerInvoke(player,"global").boards,"Throttle did not reset")
print("PASS remote validation, isolated throttle, burst limit, and reset")


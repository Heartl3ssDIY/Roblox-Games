local ServerScriptService = game:GetService("ServerScriptService")
local Admin = require(ServerScriptService:FindFirstChild("PlaygroundAdminService"))
local checks = {}
local function check(name, condition)
 assert(condition, name)
 table.insert(checks, name)
end
local function actor(id)
 return { UserId = id, GetAttribute = function() return "Spectator" end }
end
local values = { AdminUserId = 234567890, ExtraAdminUserIds = "345678901, 456789012" }
local config = { GetAttribute = function(_, name) return values[name] end }
local calls = { rounds = 0, practices = {}, stops = 0 }
local service = {
 active = false,
 phase = "Waiting",
 state = { GetAttribute = function(_, name) return name == "Mode" and "Waiting" or nil end },
 StartRound = function(self)
  calls.rounds += 1
  return true
 end,
 StartPractice = function(self, player, role)
  table.insert(calls.practices, { actor = player, role = role })
  return true
 end,
 StopRound = function(self)
  calls.stops += 1
  self.active = false
  return true
 end,
}
local allowed, denied = actor(234567890), actor(987654321)
local public = Admin.new(service, config, false)
check("configured_admin_allowed", public:IsAuthorized(allowed))
check("extra_admin_allowed", public:IsAuthorized(actor(345678901)))
check("unlisted_public_user_denied", not public:IsAuthorized(denied))
check("studio_test_user_allowed_without_config", Admin.new(service, config, true):IsAuthorized(denied))
if game.CreatorType == Enum.CreatorType.User then
 check("experience_user_owner_allowed", public:IsAuthorized(actor(game.CreatorId)))
end
for _, action in ipairs({ "StartRound", "PracticeRunner", "PracticeBulldog", "StopRound" }) do
 local response = public:Handle(denied, action)
 check("unauthorized_" .. action .. "_denied", response.ok == false)
end
check("unauthorized_commands_do_not_call_service", calls.rounds == 0 and #calls.practices == 0 and calls.stops == 0)
for _, action in ipairs({ 123, {}, "RunAnything" }) do
 local response = public:Handle(allowed, action)
 check("malformed_or_unknown_action_rejected_" .. typeof(action), response.ok == false)
end
check("invalid_commands_do_not_call_service", calls.rounds == 0 and #calls.practices == 0 and calls.stops == 0)
check("status_allowed", public:Handle(allowed, "GetStatus").ok == true)
check("status_does_not_consume_mutation_cooldown", public:Handle(allowed, "StartRound").ok == true and calls.rounds == 1)
check("immediate_mutation_rate_limited", public:Handle(allowed, "StartRound").ok == false and calls.rounds == 1)
check("immediate_status_rate_limited", public:Handle(allowed, "GetStatus").ok == false)
public.lastRequest[allowed] = nil
service.active = true
check("start_during_active_round_rejected", public:Handle(allowed, "PracticeRunner").ok == false and #calls.practices == 0)
public.lastRequest[allowed] = nil
check("stop_allowed_during_active_round", public:Handle(allowed, "StopRound").ok == true and calls.stops == 1 and not service.active)
public.lastRequest[allowed] = nil
check("runner_practice_started", public:Handle(allowed, "PracticeRunner").ok == true)
check("runner_practice_uses_authenticated_caller_and_fixed_role", calls.practices[1].actor == allowed and calls.practices[1].role == "Runner")
public.lastRequest[allowed] = nil
check("bulldog_practice_started", public:Handle(allowed, "PracticeBulldog").ok == true)
check("bulldog_practice_uses_authenticated_caller_and_fixed_role", calls.practices[2].actor == allowed and calls.practices[2].role == "Bulldog")
public.lastRequest[allowed] = nil
public.busy = true
check("concurrent_mutation_rejected", public:Handle(allowed, "StartRound").ok == false and calls.rounds == 1)
public.busy = false
public.lastRequest[allowed] = nil
service.StartRound = function() error("Deliberate fixture failure") end
local failed = public:Handle(allowed, "StartRound")
check("service_error_returned_as_failure", failed.ok == false)
check("busy_lock_cleared_after_error", public.busy == false)
public.lastRequest[allowed] = nil
service.StartRound = function() return false, "Not enough ready players" end
local minimum = public:Handle(allowed, "StartRound")
check("single_player_normal_round_points_to_practice", minimum.ok == false and string.find(minimum.message, "test alone", 1, true) ~= nil)
public:Destroy()
check("destroy_clears_rate_records", next(public.lastRequest) == nil and next(public.lastStatus) == nil)
return { passed = #checks, checks = checks, publishedAuthorizationFixture = true, liveServiceMutated = false }


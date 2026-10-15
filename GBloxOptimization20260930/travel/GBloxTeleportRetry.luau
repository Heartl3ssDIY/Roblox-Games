local Retry = {}

function Retry.new(deps)
 local active = {}
 local limit = deps.AttemptLimit or 3
 local function report(kind, context, detail)
  if deps.Report then deps.Report(kind, context.player, context.placeId, context.attempt, tostring(detail or "")) end
 end
 local function finish(context, message)
  if active[context.player] ~= context then return end
  active[context.player] = nil
  context.phase = "Failed"
  report("Failed", context, message)
  context.failed(context.player, message)
 end
 local function present(context)
  if active[context.player] ~= context then return false end
  if deps.IsPresent(context.player) then return true end
  active[context.player] = nil
  return false
 end
 local invoke
 local function failedAttempt(context, result, message, options)
  if not present(context) or context.phase == "RetryWaiting" then return end
  report("AttemptFailed", context, tostring(result or "RequestError") .. ": " .. tostring(message))
  local retryable = result == nil or result == "Failure" or result == "Flooded"
  if not retryable or context.attempt >= limit then
   finish(context, "Could not connect to the match. Please try again.")
   return
  end
  context.phase = "RetryWaiting"
  if context.retrying then context.retrying(context.player, context.attempt + 1) end
  deps.Delay(result == "Flooded" and 15 or 2 * context.attempt, function()
   if not present(context) or context.phase ~= "RetryWaiting" then return end
   local payload = table.clone(options:GetTeleportData() or {})
   context.attempt += 1
   payload.GBloxTravelAttempt = context.attempt
   local nextOptions = deps.CopyOptions(options, payload)
   invoke({context}, nextOptions)
  end)
 end
 invoke = function(contexts, options)
  local members = {}
  for _, context in contexts do
   if present(context) then
    context.phase = "Calling"
    table.insert(members, context.player)
   end
  end
  if #members == 0 then return end
  local ok, result = pcall(deps.Teleport, contexts[1].placeId, members, options)
  for _, context in contexts do
   if present(context) and context.phase == "Calling" then
    if ok then
     context.phase = "InFlight"
     report("Initiated", context)
    else
     failedAttempt(context, nil, result, options)
    end
   end
  end
 end
 local controller = {}
 function controller:Start(placeId, members, options, callbacks)
  if #members == 0 then return false end
  for _, player in members do if active[player] then return false end end
  local requestId = deps.NewId()
  local contexts = {}
  local payload = table.clone(options:GetTeleportData() or {})
  payload.GBloxTravelRequestId = requestId
  payload.GBloxTravelAttempt = 1
  options = deps.CopyOptions(options, payload)
  for _, player in members do
   local context = {player = player, placeId = placeId, requestId = requestId, attempt = 1,
    phase = "Preparing", failed = callbacks.Failed, retrying = callbacks.Retrying}
   active[player] = context
   table.insert(contexts, context)
  end
  deps.Spawn(function()
   if options.ShouldReserveServer then
    local code
    for attempt = 1, limit do
     local anyPresent = false
     for _, context in contexts do if present(context) then anyPresent = true break end end
     if not anyPresent then return end
     local ok, result = pcall(deps.Reserve, placeId)
     if ok and type(result) == "string" and result ~= "" then code = result break end
     for _, context in contexts do report("ReserveFailed", context, result) end
     if attempt < limit then deps.Wait(2 * attempt) end
    end
    if not code then
     for _, context in contexts do finish(context, "Could not open a match server. Please try again.") end
     return
    end
    options.ShouldReserveServer = false
    options.ReservedServerAccessCode = code
   end
   invoke(contexts, options)
  end)
  return true
 end
 function controller:Failed(player, result, message, placeId, options)
  local context = active[player]
  if not context or context.placeId ~= placeId or not options then return end
  local payload = options:GetTeleportData()
  if type(payload) ~= "table" or payload.GBloxTravelRequestId ~= context.requestId
   or payload.GBloxTravelAttempt ~= context.attempt then return end
  failedAttempt(context, result, message, options)
 end
 function controller:Remove(player)
  active[player] = nil
 end
 function controller:IsPending(player)
  return active[player] ~= nil
 end
 return controller
end

return Retry

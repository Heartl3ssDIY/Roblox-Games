local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local gui = script.Parent
local scopes = { global = true, server = true, region = true }
local records = {}
local connections = {}
local cache = {}
local alive = true
local inFlight
local lastRequestAt = -math.huge
local requestSerial = 0
local lastRemote
local clock = os.clock

local function connect(signal, callback)
 local connection = signal:Connect(callback)
 table.insert(connections, connection)
 return connection
end

local function finite(value)
 return typeof(value) == "number" and value == value and math.abs(value) < math.huge
end

local function label(value, fallback)
 return typeof(value) == "string" and value ~= "" and value or fallback
end

local function pollSeconds(scope, state, retryAfter)
 if state == "loading" then
  return finite(retryAfter) and math.clamp(retryAfter, 5, 60) or 5
 end
 if state == "unavailable" then return 60 end
 if state == "stale" then return 30 end
 return scope == "server" and 10 or 60
end

local function setSelected(record)
 for name, button in pairs(record.buttons) do
  local selected = name == record.scope
  button:SetAttribute("Selected", selected)
  button.ReusableSkin.Image = selected and "rbxassetid://84589903135132" or "https://www.roblox.com/asset/?id=90528629970043&version=1"
 end
end

local function scopeHeading(record, region)
 local heading = record.scope == "region" and label(region, "REGION") or string.upper(record.scope)
 record.display.Header.Subtitle.Text = string.upper(heading) .. " · TOP 10"
end

local function clearRows(record)
 for _, row in ipairs(record.rows) do row.Visible = false end
 record.hasEntries = false
end

local function loading(record)
 clearRows(record)
 record.dataScope = nil
 record.display.Empty.Visible = true
 local name = record.scope == "region" and "regional" or record.scope
 record.display.Empty.Text = "Loading " .. name .. " rankings..."
 record.display.Status.Text = "Loading..."
 scopeHeading(record)
end

local function restoreWorld(record)
 if record.worldConnection then record.worldConnection:Disconnect() record.worldConnection = nil end
 if record.world and record.world.Parent then record.world.Enabled = record.worldEnabled end
 record.world = nil
end

local function showLocal(record)
 local face = record.display.Adornee
 local visible = alive and gui.Enabled and record.ready and face and face:IsDescendantOf(workspace)
 record.display.Enabled = visible == true
 if record.world and record.world.Parent then
  if visible then record.world.Enabled = false else record.world.Enabled = record.worldEnabled end
 end
end

local function bindWorld(record)
 local lobby = workspace:FindFirstChild("Playground Lobby")
 local boards = lobby and lobby:FindFirstChild("Leaderboards")
 local board = boards and boards:FindFirstChild(record.id)
 local face = board and board:FindFirstChild("Face")
 local world = face and face:FindFirstChild("Display")
 if world ~= record.world then
  restoreWorld(record)
  if world and world:IsA("SurfaceGui") then
   record.world = world
   record.worldEnabled = world.Enabled
   record.worldConnection = world:GetPropertyChangedSignal("Enabled"):Connect(function()
    if alive and record.ready and gui.Enabled and record.display.Enabled and world.Enabled then world.Enabled = false end
   end)
  end
 end
 if face and face:IsA("BasePart") and record.display.Adornee ~= face then record.display.Adornee = face end
 showLocal(record)
end

local function validBoard(data)
 return typeof(data) == "table" and typeof(data.entries) == "table"
  and (data.state == nil or data.state == "loading" or data.state == "ready" or data.state == "stale" or data.state == "unavailable")
end

local function publishPodium(record, reply)
 if gui:GetAttribute("PodiumBoard") ~= record.id or gui:GetAttribute("PodiumScope") ~= record.scope then return end
 local data = reply.boards[record.id]
 if not validBoard(data) then return end
 local entries = {}
 for index = 1, 3 do
  local entry = data.entries[index]
  if entry then entries[index] = entry end
 end
 local packet = { board = record.id, scope = record.scope, region = reply.region, state = data.state or reply.state or "ready", status = data.status or reply.status, entries = entries }
 gui:SetAttribute("PodiumSnapshot", HttpService:JSONEncode(packet))
end

local function render(record, reply, receivedAt)
 local data = reply.boards[record.id]
 if not validBoard(data) then return false end
 local count = 0
 for index, row in ipairs(record.rows) do
  local entry = data.entries[index]
  local valid = typeof(entry) == "table" and finite(entry.userId)
   and typeof(entry.name) == "string" and typeof(entry.value) == "string"
  row.Visible = valid
  if valid then
   count += 1
   row.Rank.Text = tostring(index)
   row.PlayerName.Text = label(entry.name, "Player")
   row.Value.Text = entry.value
   row.Avatar.Image = typeof(entry.image) == "string" and entry.image or ""
   row.Avatar.Placeholder.Visible = row.Avatar.Image == ""
  end
 end
 record.hasEntries = count > 0
 record.dataScope = record.scope
 record.state = data.state or reply.state or "ready"
 record.display.Empty.Visible = count == 0
 record.display.Empty.Text = label(data.emptyText, record.state == "loading" and "Loading rankings..." or "No scores yet.")
 record.display.Status.Text = label(data.status, label(reply.status, ""))
 scopeHeading(record, reply.region)
 record.nextRefresh = receivedAt + pollSeconds(record.scope, record.state, data.retryAfter or reply.retryAfter)
 record.ready = true
 record.lastReply = reply
 publishPodium(record, reply)
 showLocal(record)
 return true
end

local function showFailure(record, message)
 record.display.Status.Text = message
 if not record.hasEntries or record.dataScope ~= record.scope then
  clearRows(record)
  record.display.Empty.Visible = true
  record.display.Empty.Text = "Couldn't load these rankings. Try again shortly."
 end
 record.state = "error"
 record.nextRefresh = clock() + 15
 local previous = record.dataScope == record.scope and record.lastReply
 local data = previous and previous.boards[record.id]
 local failedReply = { region = previous and previous.region, boards = {
  [record.id] = { state = record.hasEntries and "stale" or "unavailable", status = message, entries = data and data.entries or {} },
 } }
 record.lastReply = failedReply
 publishPodium(record, failedReply)
end

local function selectScope(record, scope)
 if not alive or not scopes[scope] then return end
 gui:SetAttribute("PodiumBoard", record.id)
 gui:SetAttribute("PodiumScope", scope)
 if record.scope == scope then
  if record.lastReply and record.dataScope == scope then publishPodium(record, record.lastReply) end
  if record.state == "error" then record.nextRefresh = clock() end
  return
 end
 record.scope = scope
 record.version += 1
 record.state = "loading"
 record.nextRefresh = 0
 setSelected(record)
 loading(record)
 publishPodium(record, { boards = { [record.id] = { state = "loading", entries = {} } } })
 local cached = cache[scope]
 if cached and clock() < cached.expiresAt then
  render(record, cached.reply, cached.receivedAt)
 end
end

local function failRequest(request, message)
 for record, version in pairs(request.targets) do
  if record.version == version and record.scope == request.scope then showFailure(record, message) end
 end
end

local function cancelRequest(request)
 if not request then return end
 request.expired = true
 if request.thread and coroutine.status(request.thread) ~= "dead" then pcall(task.cancel, request.thread) end
end

local function beginRequest(remote, scope, now)
 requestSerial += 1
 local request = { serial = requestSerial, scope = scope, startedAt = now, targets = {}, remote = remote }
 for _, record in ipairs(records) do
  if record.scope == scope then request.targets[record] = record.version end
 end
 inFlight = request
 lastRequestAt = now
 request.thread = task.spawn(function()
  local ok, reply = pcall(function() return remote:InvokeServer(scope) end)
  if not alive or inFlight ~= request then return end
  inFlight = nil
  if request.expired then return end
  if not ok or typeof(reply) ~= "table" or reply.scope ~= scope or typeof(reply.boards) ~= "table" then
   failRequest(request, "Refresh unavailable. Please try again.")
   return
  end
  local receivedAt = clock()
  local interval = pollSeconds(scope, reply.state, reply.retryAfter)
  local hasValidBoard = false
  for _, record in ipairs(records) do
   local data = reply.boards[record.id]
   if validBoard(data) then
    hasValidBoard = true
    interval = math.min(interval, pollSeconds(scope, data.state or reply.state, data.retryAfter or reply.retryAfter))
   end
  end
  if hasValidBoard then cache[scope] = { reply = reply, receivedAt = receivedAt, expiresAt = receivedAt + interval } end
  for record, version in pairs(request.targets) do
   if record.version == version and record.scope == scope then
    if not render(record, reply, receivedAt) then showFailure(record, "These rankings are temporarily unavailable.") end
   end
  end
 end)
end

local function tick()
 if not alive then return end
 local now = clock()
 for _, record in ipairs(records) do bindWorld(record) end
 local remote = ReplicatedStorage:FindFirstChild("PlaygroundLeaderboardRequest")
 if not remote or not remote:IsA("RemoteFunction") then
  if inFlight then
   local removed = inFlight
   cancelRequest(removed)
   inFlight = nil
   failRequest(removed, "Connection interrupted. Rankings will retry when available.")
  end
  lastRemote = nil
  return
 end
 if remote ~= lastRemote then
  lastRemote = remote
  cancelRequest(inFlight)
  inFlight = nil
  requestSerial += 1
  for _, record in ipairs(records) do record.nextRefresh = 0 end
 end
 if inFlight then
  if now - inFlight.startedAt >= 12 then
   local timedOut = inFlight
   cancelRequest(timedOut)
   inFlight = nil
   failRequest(timedOut, "Refresh is taking too long. Please try again.")
  end
  return
 end
 if now - lastRequestAt < 1.05 then return end
 local candidate
 for _, record in ipairs(records) do
  if now >= record.nextRefresh and (not candidate or record.nextRefresh < candidate.nextRefresh) then candidate = record end
 end
 if candidate then beginRequest(remote, candidate.scope, now) end
end

for _, id in ipairs({ "MostWins", "HighestLevel" }) do
 local display = gui:WaitForChild(id)
 local record = { id = id, display = display, scope = "global", version = 0, nextRefresh = 0,
  buttons = {}, rows = {}, ready = false, hasEntries = false, state = "loading" }
 for index = 1, 10 do record.rows[index] = display.Body:WaitForChild(string.format("Row%02d", index)) end
 for _, scope in ipairs({ "global", "server", "region" }) do
  local button = display.ScopeTabs:WaitForChild(scope)
  record.buttons[scope] = button
  connect(button.Activated, function() selectScope(record, scope) end)
  connect(button.MouseEnter, function() button.ReusableSkin.ImageColor3 = Color3.new(0.94, 0.94, 0.94) end)
  connect(button.MouseLeave, function() button.ReusableSkin.ImageColor3 = Color3.new(1, 1, 1) end)
 end
 table.insert(records, record)
 setSelected(record)
 loading(record)
 bindWorld(record)
end

local function cleanup()
 if not alive then return end
 alive = false
 cancelRequest(inFlight)
 inFlight = nil
 table.clear(cache)
 for _, connection in ipairs(connections) do connection:Disconnect() end
 table.clear(connections)
 for _, record in ipairs(records) do
  record.version += 1
  record.display.Enabled = false
  restoreWorld(record)
 end
end

connect(gui:GetPropertyChangedSignal("Enabled"), function()
 for _, record in ipairs(records) do showLocal(record) end
end)
connect(gui.Destroying, cleanup)
connect(script.Destroying, cleanup)
local elapsed = 0
connect(RunService.Heartbeat, function(delta)
 elapsed += delta
 if elapsed >= 0.2 then elapsed = 0 tick() end
end)
tick()






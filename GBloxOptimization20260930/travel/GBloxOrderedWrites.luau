local OrderedWrites = {}

function OrderedWrites.new(deps)
 local successful = setmetatable({}, {__mode = "k"})
 local jobs = {}
 local controller = {}
 function controller:Submit(profile, metric, userId, value, ascending)
  local key = tostring(userId) .. ":" .. metric
  local job = jobs[key]
  local cache = successful[profile]
  if not job and cache and cache[metric] == value then return end
  local desired = {profile = profile, value = value, ascending = ascending}
  if job then job.desired = desired return end
  job = {desired = desired}
  jobs[key] = job
  deps.Spawn(function()
   while jobs[key] == job do
    local nextWrite = job.desired
    local saved = successful[nextWrite.profile]
    if not saved or saved[metric] ~= nextWrite.value then
     local ok, message = pcall(deps.Write, metric, userId, nextWrite.value, nextWrite.ascending)
     if not ok then
      jobs[key] = nil
      if deps.Warn then deps.Warn(metric, userId, message) end
      return
     end
     saved = successful[nextWrite.profile] or {}
     successful[nextWrite.profile] = saved
     saved[metric] = nextWrite.value
    end
    if job.desired == nextWrite then
     jobs[key] = nil
     return
    end
   end
  end)
 end
 return controller
end

return OrderedWrites

-- Server-side profile lifecycle. `backend` is a DataStore or a mock with
-- UpdateAsync(key, transform). All writes are one versioned record per user.
local Schema = require(script.Parent.ProfileSchema)

local Store = {}
Store.__index = Store

function Store.new(backend, options)
	assert(backend and type(backend.UpdateAsync) == "function", "UpdateAsync backend required")
	options = options or {}
	assert(type(options.jobId) == "string" and #options.jobId > 0, "unique jobId required")
	return setmetatable({
		backend = backend,
		jobId = options.jobId,
		clock = options.clock or os.time,
		sleep = options.sleep or task.wait,
		leaseSeconds = options.leaseSeconds or 180,
		maxAttempts = options.maxAttempts or 5,
		entries = {},
		onChanged = options.onChanged,
	}, Store)
end

local function userKey(userId)
	assert(type(userId) == "number" and userId > 0 and userId == math.floor(userId), "invalid UserId")
	return "user:" .. tostring(userId)
end

function Store:_updateWithRetry(key, transform)
	local lastError
	for attempt = 1, self.maxAttempts do
		local ok, value = pcall(function() return self.backend:UpdateAsync(key, transform) end)
		if ok then return true, value end
		lastError = tostring(value)
		if attempt < self.maxAttempts then self.sleep(math.min(8, 0.5 * 2 ^ (attempt - 1))) end
	end
	return false, lastError or "DataStore unavailable"
end

function Store:load(userId)
	local existing = self.entries[userId]
	if existing and existing.closing then
		for _ = 1, 120 do
			if self.entries[userId] ~= existing then break end
			self.sleep(0.25)
		end
		if self.entries[userId] == existing then return false, "previous session still closing" end
		existing = self.entries[userId]
	end
	if existing then return true, self:snapshot(userId) end
	local key = userKey(userId)
	local now = self.clock()
	local deniedReason
	local ok, value = self:_updateWithRetry(key, function(previous)
		local profile, reason = Schema.normalize(previous, now)
		if not profile then deniedReason = reason; return nil end
		local owner = profile.session
		if owner and owner.jobId ~= self.jobId and owner.leaseUntil > now then
			deniedReason = "profile active in another server"
			return nil
		end
		profile.revision += 1
		profile.updatedAt = now
		profile.session = {jobId = self.jobId, leaseUntil = now + self.leaseSeconds}
		return profile
	end)
	if not ok then return false, "load failed: " .. tostring(value) end
	if value == nil then return false, deniedReason or "load cancelled" end
	local profile, reason = Schema.normalize(value, now)
	if not profile then return false, reason end
	self.entries[userId] = {
		profile = profile,
		persistedRevision = profile.revision,
		serial = 0,
		dirty = false,
		saving = false,
		mutating = false,
		closing = false,
		uncertainWrite = nil,
	}
	return true, self:snapshot(userId)
end

function Store:_reconcileUncertain(userId, entry)
	local pending = entry.uncertainWrite
	if not pending then return true end
	local conflict
	local ok, value = self:_updateWithRetry(userKey(userId), function(previous)
		local stored, reason = Schema.normalize(previous, self.clock())
		if not stored then conflict = reason; return nil end
		if stored.lastWriteId == pending.writeId then return stored end
		if stored.revision == pending.expectedRevision and stored.session and stored.session.jobId == self.jobId then
			return stored
		end
		conflict = "uncertain write conflict"
		return nil
	end)
	if not ok then return false, "write reconciliation failed: " .. tostring(value) end
	if not value then return false, conflict or "write reconciliation cancelled" end
	if value.lastWriteId == pending.writeId then
		entry.persistedRevision = value.revision
		entry.profile.revision = value.revision
		entry.profile.session = Schema.copy(value.session)
		if entry.serial == pending.serial then entry.dirty = false end
		if pending.release then
			self.entries[userId] = nil
			return true, "released"
		end
	end
	entry.uncertainWrite = nil
	return true
end

function Store:isReady(userId)
	local entry = self.entries[userId]
	return entry ~= nil and not entry.closing
end

function Store:snapshot(userId)
	local entry = self.entries[userId]
	if not entry then return nil end
	local snapshot = Schema.clientSnapshot(entry.profile)
	snapshot.profileVersion = entry.serial
	return snapshot
end

function Store:mutate(userId, operation)
	local entry = self.entries[userId]
	if not entry or entry.closing then return false, "profile unavailable" end
	if entry.mutating then return false, "profile busy" end
	entry.mutating = true
	local proposed = Schema.copy(entry.profile)
	local ok, changed, result = pcall(operation, proposed)
	if not ok then
		entry.mutating = false
		return false, "profile action failed: " .. tostring(changed)
	end
	if changed == "unchanged" then
		entry.mutating = false
		return true, result
	end
	if changed ~= true then
		entry.mutating = false
		return false, result or "action rejected"
	end
	local normalized, reason = Schema.normalize(proposed, self.clock())
	if not normalized then
		entry.mutating = false
		return false, reason
	end
	-- Keep the persisted revision until save succeeds; serial tracks local edits.
	normalized.revision = entry.persistedRevision
	normalized.session = Schema.copy(entry.profile.session)
	entry.profile = normalized
	entry.serial += 1
	entry.dirty = true
	entry.mutating = false
	if self.onChanged then self.onChanged(userId, self:snapshot(userId)) end
	return true, result
end

function Store:save(userId, release)
	local entry = self.entries[userId]
	if not entry then return false, "profile unavailable" end
	if entry.saving then return false, "save already running" end
	if entry.mutating then return false, "profile busy" end
	entry.saving = true
	local reconciled, reconciliation = self:_reconcileUncertain(userId, entry)
	if not reconciled then entry.saving = false; return false, reconciliation end
	if reconciliation == "released" then entry.saving = false; return true, "released" end
	local now = self.clock()
	local owner = entry.profile.session
	if not owner or owner.jobId ~= self.jobId then entry.saving = false; return false, "session lost" end
	if not release and not entry.dirty and owner.leaseUntil - now > self.leaseSeconds / 2 then
		entry.saving = false
		return true, "unchanged"
	end
	local serial = entry.serial
	local expectedRevision = entry.persistedRevision
	local snapshot = Schema.copy(entry.profile)
	local conflict
	local key = userKey(userId)
	local writeId = self.jobId .. ":" .. tostring(expectedRevision) .. ":" .. tostring(serial) .. ":" .. tostring(release == true)
	local ok, value = self:_updateWithRetry(key, function(previous)
		local stored, reason = Schema.normalize(previous, now)
		if not stored then conflict = reason; return nil end
		-- A transport error can arrive after the DataStore has committed. The
		-- same write token makes retries return that commit, not conflict.
		if stored.lastWriteId == writeId then return stored end
		if not stored.session or stored.session.jobId ~= self.jobId then
			conflict = "session lost"
			return nil
		end
		if stored.revision ~= expectedRevision then
			conflict = "revision conflict"
			return nil
		end
		local nextProfile = Schema.copy(snapshot)
		nextProfile.revision = stored.revision + 1
		nextProfile.updatedAt = now
		nextProfile.lastWriteId = writeId
		if release then nextProfile.session = nil else nextProfile.session = {jobId = self.jobId, leaseUntil = now + self.leaseSeconds} end
		return nextProfile
	end)
	entry.saving = false
	if not ok then
		entry.uncertainWrite = {
			writeId = writeId, expectedRevision = expectedRevision,
			serial = serial, release = release == true,
		}
		return false, "save failed: " .. tostring(value)
	end
	if value == nil then return false, conflict or "save cancelled" end
	entry.persistedRevision = value.revision
	entry.profile.revision = value.revision
	entry.profile.session = Schema.copy(value.session)
	if entry.serial == serial then entry.dirty = false end
	if release then self.entries[userId] = nil end
	return true, value.revision
end

function Store:close(userId)
	local entry = self.entries[userId]
	if not entry then return true end
	entry.closing = true
	-- PlayerRemoving may race an autosave. Wait for that UpdateAsync before
	-- releasing the session; retain this entry for shutdown retry on failure.
	for _ = 1, 40 do
		if entry.saving or entry.mutating then
			self.sleep(0.25)
		else
			local ok, reason = self:save(userId, true)
			if ok then return true, reason end
			if reason ~= "save already running" and reason ~= "profile busy" then return false, reason end
		end
	end
	return false, "save busy during close"
end

function Store:saveAll(release)
	local failures = {}
	for userId, entry in pairs(self.entries) do
		if release == true or not entry.closing then
			local ok, reason = self:save(userId, release == true)
			if not ok then failures[userId] = reason end
		end
	end
	return next(failures) == nil, failures
end

return Store





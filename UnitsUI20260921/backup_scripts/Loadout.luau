--!strict
-- Loadout: single client-side source of truth for the player's equipped units.
-- Both LobbyMenuClient and ArenaMatchClient require this same module, so any
-- equip/unequip is visible everywhere. Fires Changed when the list updates.
-- (Not persisted yet — resets on rejoin until save data exists.)

local Loadout = {}

local MAX = 4
local equipped: { string } = { "Yumcha", "Goku", "Krillen", "Tein" }  -- default 4 equipped

-- BindableEvent so scripts can react to changes (e.g. rebuild the bar/grid).
local changed = Instance.new("BindableEvent")
Loadout.Changed = changed.Event

Loadout.MAX = MAX

function Loadout.getAll(): { string }
	-- return a copy so callers can't mutate internal state directly
	local copy = {}
	for i, id in ipairs(equipped) do copy[i] = id end
	return copy
end

function Loadout.count(): number
	return #equipped
end

function Loadout.isEquipped(id: string): boolean
	for _, e in ipairs(equipped) do
		if e == id then return true end
	end
	return false
end

function Loadout.isFull(): boolean
	return #equipped >= MAX
end

-- Returns true if the change happened.
function Loadout.equip(id: string): boolean
	if Loadout.isEquipped(id) then return false end
	if #equipped >= MAX then return false end
	table.insert(equipped, id)
	changed:Fire()
	return true
end

function Loadout.unequip(id: string): boolean
	for i, e in ipairs(equipped) do
		if e == id then
			table.remove(equipped, i)
			changed:Fire()
			return true
		end
	end
	return false
end

-- Convenience: flip a unit's equipped state. Returns the new state (true=now equipped).
-- Swap: replace `equippedId` (currently equipped) with `newId` (not equipped).
function Loadout.swap(equippedId: string, newId: string): boolean
	if not Loadout.isEquipped(equippedId) then return false end
	if Loadout.isEquipped(newId) then return false end
	for i, e in ipairs(equipped) do
		if e == equippedId then
			equipped[i] = newId
			changed:Fire()
			return true
		end
	end
	return false
end

function Loadout.toggle(id: string): boolean
	if Loadout.isEquipped(id) then
		Loadout.unequip(id)
		return false
	else
		Loadout.equip(id)
		return Loadout.isEquipped(id)
	end
end

return Loadout

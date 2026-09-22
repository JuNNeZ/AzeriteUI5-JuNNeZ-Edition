--[[

	The MIT License (MIT)

	Copyright (c) 2026 Jonas "JuNNeZ" Andersen

--]]
-- Settings changed during combat, held until it ends.
--
-- The panel's footer has said this for a long time:
--
--     Settings that move or rebuild frames wait until you leave combat.
--
-- Nothing did. The write went straight through, and the notice was a label
-- rather than a mechanism. This is the mechanism.
--
-- Every write from a page of the *addon's* settings is held while the player is
-- in combat: the value you chose is remembered here, the control goes on
-- showing it, the row is marked, and the write happens on PLAYER_REGEN_ENABLED.
-- Which settings would actually taint is not knowable from an option table - the
-- setter is a closure that may reach anything - so nothing tries to guess, and
-- everything waits.
--
-- The window's own settings are the exception. Theme, opacity and panel scale
-- touch nothing the game protects, and holding them would be a lie in the other
-- direction: you would pick a theme mid-fight and watch nothing happen.
--
-- The queue does not survive a reload. Nothing here writes to the database,
-- because a held value is a change the player has not committed to anything yet.
local _, ns = ...

local Kit = ns.OptionsKit
if (not Kit) then return end

-- Lua API
local ipairs = ipairs
local pcall = pcall
local table_concat = table.concat
local table_wipe = table.wipe or wipe
local tostring, type = tostring, type

-- GLOBALS: CreateFrame, InCombatLockdown

local Combat = {}
Kit.Combat = Combat

-- In the order they were made, because one setting can depend on another and
-- the player made them in that order for a reason.
local queue = {}

-- key -> the entry in `queue`, so the same setting changed twice replaces its
-- own pending value instead of queueing a second write. A slider dragged across
-- its range is one pending value, not forty.
local pending = {}

-- `extra` is the argument a setting takes beyond its path: a multiselect's
-- value key, where one path carries a toggle per key. Without it, turning two
-- of them on in combat would be one queued change that overwrote the other.
local Key = function(path, extra)
	if (type(path) ~= "table" or #path == 0) then return end

	local key = table_concat(path, "\001")
	if (extra ~= nil) then key = key .. "\001" .. tostring(extra) end
	return key
end
Combat.Key = Key

local Copy = function(path)
	local out = {}
	for i = 1, #path do out[i] = path[i] end
	return out
end

--------------------------------------------------------------------------
-- Asking
--------------------------------------------------------------------------
Combat.IsLocked = function()
	return InCombatLockdown() and true or false
end

-- Whether a write against this option table has to wait. The table is the
-- question, not the setting: the panel's own Settings tab is drawn from
-- PanelOptions and changes only how this window is painted.
Combat.ShouldQueue = function(self, options)
	if (not InCombatLockdown()) then return false end
	if (Kit.PanelOptions and options == Kit.PanelOptions.GetTable()) then return false end
	return true
end

-- The entry waiting for this setting, if there is one. Callers read `.value`
-- only when `.hasValue` is set: an execute action is queued with nothing to
-- show, and a value of `false` is a value.
Combat.Peek = function(self, path, extra)
	local key = Key(path, extra)
	return key and pending[key] or nil
end

Combat.Count = function(self)
	return #queue
end

-- What is waiting, in order, for anything that wants to list it.
Combat.Entries = function(self)
	return queue
end

--------------------------------------------------------------------------
-- Queueing
--------------------------------------------------------------------------
-- `value` is what the control should keep showing until the write happens, and
-- `apply` is the write itself. Returns true when the change was held, so the
-- caller can say so.
Combat.Queue = function(self, path, label, value, hasValue, apply, extra)
	if (type(apply) ~= "function") then return false end

	local key = Key(path, extra)
	if (not key) then return false end

	local entry = pending[key]
	if (not entry) then
		entry = { key = key, path = Copy(path), extra = extra }
		pending[key] = entry
		queue[#queue + 1] = entry
	end

	entry.label = label
	entry.value = value
	entry.hasValue = hasValue and true or false
	entry.apply = apply

	return true
end

Combat.Clear = function(self)
	table_wipe(pending)
	for i = #queue, 1, -1 do queue[i] = nil end
end

--------------------------------------------------------------------------
-- Applying
--------------------------------------------------------------------------
-- Taken and cleared before anything is applied, so a setter that refreshes the
-- panel mid-flush sees a queue that matches what has already been written
-- rather than pending values for settings that are no longer pending.
--
-- Every write is its own pcall: one option page throwing must not strand the
-- changes queued behind it.
Combat.Flush = function(self)
	if (#queue == 0) then return 0, 0 end

	local entries = {}
	for i, entry in ipairs(queue) do entries[i] = entry end
	self:Clear()

	local applied, failed = 0, 0
	for _, entry in ipairs(entries) do
		local ok, err = pcall(entry.apply)
		if (ok) then
			applied = applied + 1
		else
			failed = failed + 1
			ns:Print("A setting held for combat could not be applied:",
				tostring(entry.label or entry.key), "-", tostring(err))
		end
	end

	local Panel = Kit.Panel
	if (Panel and Panel.OnCombatFlushed) then
		Panel:OnCombatFlushed(applied, failed)
	end

	return applied, failed
end

--------------------------------------------------------------------------
-- The event
--------------------------------------------------------------------------
-- Its own frame, not the panel's. A change queued and then closed away still
-- has to happen, so this has to outlive the window being shut.
local watcher = CreateFrame("Frame")
watcher:RegisterEvent("PLAYER_REGEN_ENABLED")
watcher:SetScript("OnEvent", function()
	Combat:Flush()
end)

-- Kept for the harness, which has no events to fire.
Combat.watcher = watcher

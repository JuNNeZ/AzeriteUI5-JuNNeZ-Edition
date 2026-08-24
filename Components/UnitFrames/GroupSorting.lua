--[[

	Shared ordering for the group frame families.

	Four user facing modes, spelled the same way everywhere so the options read the
	same on every frame family, but applied through two very different mechanisms:

	- Party, Raid (25) and Raid (40) are real secure group headers. Blizzard sorts
	  them from the groupBy / groupingOrder / sortMethod attributes, and it does so
	  from its own roster event, which means the sorting keeps working inside
	  combat. We only write the attributes, and that write has to wait for combat.
	- Raid (5) is not a header at all. Its five buttons are fed by per button unit
	  drivers, so the order is whatever token list we hand them, and it can only be
	  rebuilt out of combat.

	On "ROLE": the header attribute for TANK / HEALER / DAMAGER is ASSIGNEDROLE, not
	ROLE. ROLE is the main tank / main assist flag, so pairing it with a
	TANK,HEALER,DAMAGER ordering - as the raid frames did for years - matches nothing
	and silently leaves the roster in index order.

--]]
local _, ns = ...

-- Lua API
local ipairs = ipairs
local math_huge = math.huge
local table_concat = table.concat
local table_insert = table.insert
local table_sort = table.sort
local type = type

-- GLOBALS: CLASS_SORT_ORDER, UnitClass, UnitExists, UnitGroupRolesAssigned, UnitIsUnit, UnitName

local MAX_RAID_UNITS = 40
local MAX_PARTY_UNITS = 4

local GROUP_ORDER = "1,2,3,4,5,6,7,8"
local ROLE_ORDER = "TANK,HEALER,DAMAGER,NONE"

-- Only reached if the client has not handed us CLASS_SORT_ORDER, which it always
-- has so far - SecureGroupHeaders.lua itself unpacks that global.
local FALLBACK_CLASS_ORDER = "DEATHKNIGHT,DEMONHUNTER,DRUID,EVOKER,HUNTER,MAGE,MONK,PALADIN,PRIEST,ROGUE,SHAMAN,WARLOCK,WARRIOR"

local GroupSorting = {}
ns.GroupSorting = GroupSorting

local GetClassOrder = function()
	if (type(CLASS_SORT_ORDER) == "table" and #CLASS_SORT_ORDER > 0) then
		return table_concat(CLASS_SORT_ORDER, ",")
	end
	return FALLBACK_CLASS_ORDER
end

-- Rank lookups are cached per order string. Sorting a 40 player roster would
-- otherwise rebuild the same table on every comparison pass.
local rankCache = {}
local GetRankTable = function(order)
	local cached = rankCache[order]
	if (cached) then return cached end

	local ranks = {}
	local position = 1
	for token in string.gmatch(order, "[^,]+") do
		ranks[string.upper(token)] = position
		position = position + 1
	end

	rankCache[order] = ranks
	return ranks
end

local isValidMode = {
	GROUP = true,
	CLASS = true,
	ROLE = true,
	NAME = true
}

GroupSorting.SanitizeMode = function(mode, fallback)
	if (type(mode) == "string" and isValidMode[mode]) then
		return mode
	end
	return fallback or "GROUP"
end

GroupSorting.SanitizeDirection = function(direction)
	return (direction == "DESC") and "DESC" or "ASC"
end

-- Real secure group headers
--------------------------------------------
-- Writes the four attributes Blizzard sorts from. Callers own the combat check;
-- every attribute write reruns SecureGroupHeader_Update, which lays out protected
-- children and cannot do that in combat from a tainted call.
GroupSorting.ApplyToHeader = function(header, mode, direction)
	if (not header or not header.SetAttribute) then return end

	mode = GroupSorting.SanitizeMode(mode)

	if (mode == "CLASS") then
		header:SetAttribute("groupBy", "CLASS")
		header:SetAttribute("groupingOrder", GetClassOrder())
		header:SetAttribute("sortMethod", "NAME")

	elseif (mode == "ROLE") then
		header:SetAttribute("groupBy", "ASSIGNEDROLE")
		header:SetAttribute("groupingOrder", ROLE_ORDER)
		header:SetAttribute("sortMethod", "NAME")

	elseif (mode == "NAME") then
		-- No grouping at all, so the name sort applies across the whole roster
		-- instead of only within each group.
		header:SetAttribute("groupBy", nil)
		header:SetAttribute("groupingOrder", GROUP_ORDER)
		header:SetAttribute("sortMethod", "NAME")

	else
		header:SetAttribute("groupBy", "GROUP")
		header:SetAttribute("groupingOrder", GROUP_ORDER)
		header:SetAttribute("sortMethod", "INDEX")
	end

	header:SetAttribute("sortDir", GroupSorting.SanitizeDirection(direction))
end

-- Unit driver frames
--------------------------------------------
local GetSortKeys = function(unit, index, mode)
	local name = UnitName(unit)
	if (not ns.API.IsSafeString(name)) then
		name = ""
	end

	if (mode == "CLASS") then
		local _, class = UnitClass(unit)
		local rank = ns.API.IsSafeString(class) and GetRankTable(GetClassOrder())[class] or nil
		return rank or math_huge, name, index
	end

	if (mode == "ROLE") then
		local role = UnitGroupRolesAssigned(unit)
		local rank = ns.API.IsSafeString(role) and GetRankTable(ROLE_ORDER)[role] or nil
		return rank or math_huge, name, index
	end

	if (mode == "NAME") then
		return 0, name, index
	end

	-- GROUP on these frames means roster order. They only ever draw five units, and
	-- any group small enough to fit them sits in one subgroup anyway, so ordering by
	-- subgroup would buy nothing and would move frames around on a default profile.
	return 0, "", index
end

-- table.sort is not stable, so the roster index is always the final tie break.
-- Without it, two members sharing a sort key could swap places between updates.
-- Exposed because the party header needs the same ordering for its name list,
-- which is the one branch of SecureGroupHeader_Update that ignores groupBy.
local SortEntries
SortEntries = function(entries, mode, direction)
	for _, entry in ipairs(entries) do
		entry.rank, entry.name, entry.index = GetSortKeys(entry.unit, entry.index, mode)
	end

	table_sort(entries, function(a, b)
		if (a.rank ~= b.rank) then return a.rank < b.rank end
		if (a.name ~= b.name) then return a.name < b.name end
		return a.index < b.index
	end)

	if (GroupSorting.SanitizeDirection(direction) == "DESC") then
		local reversed = {}
		for i = #entries, 1, -1 do
			table_insert(reversed, entries[i])
		end
		return reversed
	end

	return entries
end

GroupSorting.SortEntries = function(entries, mode, direction)
	return SortEntries(entries, mode, direction)
end

--[[
	Orders the raid tokens for a unit driver frame.

	Returns an array of `count` raid indexes. Slots past the end of the roster are
	padded with indexes that do not exist, which is deliberate: RegisterUnitWatch
	hides those buttons, and keeping the padding last keeps the visible frames
	contiguous from the anchor.
]]
GroupSorting.GetRaidUnitOrder = function(mode, direction, count, includePlayer)
	local entries = {}
	local playerIndex

	for i = 1, MAX_RAID_UNITS do
		local unit = "raid"..i
		if (UnitExists(unit)) then
			if (UnitIsUnit(unit, "player")) then
				playerIndex = i
				if (includePlayer) then
					table_insert(entries, { unit = unit, index = i })
				end
			else
				table_insert(entries, { unit = unit, index = i })
			end
		end
	end

	local order, used = {}, {}
	for _, entry in ipairs(SortEntries(entries, mode, direction)) do
		if (#order >= count) then break end
		table_insert(order, entry.index)
		used[entry.index] = true
	end

	local candidate = 1
	while (#order < count and candidate <= MAX_RAID_UNITS) do
		if (not used[candidate] and not (candidate == playerIndex and not includePlayer)) then
			table_insert(order, candidate)
			used[candidate] = true
		end
		candidate = candidate + 1
	end

	return order
end

--[[
	Orders the party tokens for a unit driver frame.

	Returns an array of `count` unit tokens. "player" is a token here rather than an
	index because the party tokens never cover the player at all - party1 is the
	first member other than you.
]]
GroupSorting.GetPartyUnitOrder = function(mode, direction, count, includePlayer)
	local entries = {}

	if (includePlayer) then
		table_insert(entries, { unit = "player", index = 0 })
	end

	for i = 1, MAX_PARTY_UNITS do
		local unit = "party"..i
		if (UnitExists(unit)) then
			table_insert(entries, { unit = unit, index = i })
		end
	end

	local order, used = {}, {}
	for _, entry in ipairs(SortEntries(entries, mode, direction)) do
		if (#order >= count) then break end
		table_insert(order, entry.unit)
		used[entry.unit] = true
	end

	-- Pad with the tokens nothing claimed. party5 never exists, which is exactly
	-- what a surplus button should be pointed at.
	local candidate = 1
	while (#order < count) do
		local unit = "party"..candidate
		if (not used[unit]) then
			table_insert(order, unit)
			used[unit] = true
		end
		candidate = candidate + 1
	end

	return order
end

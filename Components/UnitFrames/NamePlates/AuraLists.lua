--[[

	The MIT License (MIT)

	Copyright (c) 2026 Jonas "JuNNeZ" Andersen

--]]
-- The nameplate aura picker's data (Options/Kit/AuraPicker.lua; Docs/Nameplate Aura Picker Plan - 2026-11-21.md).
--
-- Two things, both kept out of the plate code:
-- * Editing the two lists the Aura filters settings already hold, by spell ID: profile.auraOnceSpells
--   (one comma-separated string for the profile) and profile.auraHighlights[GetAuraHighlightKey()] (one per
--   specialization). The picker writes the same strings the input fields do, so profiles, import/export and
--   Settings.lua's ParseSpellIDs are unchanged. Nothing is written without a call from a click.
-- * "Seen on your targets": debuff spell IDs read off enemy nameplates, only out of combat and only where the
--   spell ID and its source are readable (never secret). Kept per specialization in the NamePlates
--   namespace's db.global.auraSeen, newest first and capped. UNIT_AURA is not even registered in combat.
local _, ns = ...

local NP = ns.NamePlatesPrivate
if (not NP) then return end

-- Lua API
local ipairs = ipairs
local pcall = pcall
local string_find = string.find
local string_gmatch = string.gmatch
local table_concat = table.concat
local table_insert = table.insert
local table_remove = table.remove
local tonumber = tonumber
local type = type

local IsSecretValue = NP.IsSecretValue or function() return false end

local AuraLists = {}
NP.AuraLists = AuraLists

-- The plates' own limits (Settings.lua, GetNamePlateAuraConfig): IDs past them are ignored there, so the
-- picker refuses to add more instead of storing what would never show.
AuraLists.HighlightLimit = 16
AuraLists.GetOnceLimit = function()
	return ns.PlayerAuraContainers and ns.PlayerAuraContainers.NamePlateOnceSlots or 8
end
-- How many spells "Seen on your targets" keeps per specialization.
AuraLists.SeenLimit = 40

local GetModule = function()
	return ns.GetModule and ns:GetModule("NamePlates", true)
end

local GetProfile = function()
	local module = GetModule()
	return module and module.db and module.db.profile
end

local GetKey = function()
	return NP.GetAuraHighlightKey and NP.GetAuraHighlightKey() or "NONE"
end
AuraLists.GetKey = GetKey

--------------------------------------------------------------------------
-- The two lists
--------------------------------------------------------------------------
-- Every ID in the text, in order, once each, with no limit: what is stored is never dropped here.
local Parse = function(text)
	local list, set = {}, {}
	if (type(text) == "string") then
		for id in string_gmatch(text, "%d+") do
			id = tonumber(id)
			if (id and id > 0 and not set[id]) then
				set[id] = true
				list[#list + 1] = id
			end
		end
	end
	return list, set
end
AuraLists.Parse = Parse

local Join = function(list)
	return table_concat(list, ", ")
end
AuraLists.Join = Join

local listeners = {}

-- Called with the kind ("once", "highlight" or "seen") after anything here changed.
AuraLists.AddListener = function(self, fn)
	if (type(fn) == "function") then listeners[#listeners + 1] = fn end
end

local Notify = function(kind)
	for _, fn in ipairs(listeners) do fn(kind) end
end

AuraLists.GetText = function(self, kind)
	local profile = GetProfile()
	if (not profile) then return "" end
	if (kind == "once") then
		return type(profile.auraOnceSpells) == "string" and profile.auraOnceSpells or ""
	end
	local all = profile.auraHighlights
	return type(all) == "table" and type(all[GetKey()]) == "string" and all[GetKey()] or ""
end

-- Stores a list's text as the input fields do (Options/OptionsPages/Nameplates.lua) and applies it.
AuraLists.SetText = function(self, kind, text)
	local module = GetModule()
	local profile = module and module.db and module.db.profile
	if (not profile) then return false end
	text = type(text) == "string" and text:gsub("^%s+", ""):gsub("%s+$", "") or ""
	if (kind == "once") then
		profile.auraOnceSpells = text
	else
		local all = profile.auraHighlights
		if (type(all) ~= "table") then all = {}; profile.auraHighlights = all end
		all[GetKey()] = (text ~= "") and text or nil
	end
	if (module.UpdateSettings) then module:UpdateSettings() end
	Notify(kind)
	return true
end

AuraLists.GetList = function(self, kind)
	return Parse(self:GetText(kind))
end

AuraLists.GetLimit = function(self, kind)
	return (kind == "once") and AuraLists.GetOnceLimit() or AuraLists.HighlightLimit
end

AuraLists.IsListed = function(self, kind, spellID)
	local _, set = self:GetList(kind)
	return set[spellID] and true or false
end

-- Adds or removes one ID, keeping the order of the rest. Returns false and "limit" when the list is full.
AuraLists.SetListed = function(self, kind, spellID, listed)
	spellID = tonumber(spellID)
	if (not spellID or spellID <= 0) then return false, "invalid" end
	local list, set = self:GetList(kind)
	if (listed) then
		if (set[spellID]) then return true end
		if (#list >= self:GetLimit(kind)) then return false, "limit" end
		list[#list + 1] = spellID
	else
		if (not set[spellID]) then return true end
		for index = #list, 1, -1 do
			if (list[index] == spellID) then table_remove(list, index) end
		end
	end
	return self:SetText(kind, Join(list))
end

-- One spell with several rank IDs (Forever): on adds `addID` unless a rank is already listed; off removes
-- every rank in one write. Returns false and "limit" when the list is full.
AuraLists.SetListedRanks = function(self, kind, ids, listed, addID)
	if (type(ids) ~= "table" or #ids == 0) then return false, "invalid" end
	local list, set = self:GetList(kind)
	local present = false
	for _, id in ipairs(ids) do
		if (set[id]) then present = true break end
	end
	if (listed) then
		if (present) then return true end
		return self:SetListed(kind, addID or ids[#ids], true)
	end
	if (not present) then return true end
	local drop = {}
	for _, id in ipairs(ids) do drop[id] = true end
	for index = #list, 1, -1 do
		if (drop[list[index]]) then table_remove(list, index) end
	end
	return self:SetText(kind, Join(list))
end

--------------------------------------------------------------------------
-- Seen on your targets
--------------------------------------------------------------------------
local GetSeenStore = function(create)
	local module = GetModule()
	local global = module and module.db and module.db.global
	if (type(global) ~= "table") then return end
	local all = global.auraSeen
	if (type(all) ~= "table") then
		if (not create) then return end
		all = {}
		global.auraSeen = all
	end
	local key = GetKey()
	local list = all[key]
	if (type(list) ~= "table") then
		if (not create) then return end
		list = {}
		all[key] = list
	end
	return list
end

-- This specialization's seen debuffs, newest first: { id = spellID, class = "DEATHKNIGHT" or nil, own = true or nil }.
AuraLists.GetSeen = function(self)
	return GetSeenStore(false) or {}
end

-- Readable or nothing: a secret answer is no answer.
local Readable = function(value)
	if (IsSecretValue(value)) then return nil end
	return value
end

-- A table we may walk: not secret itself and not flagged so its reads give secrets. Forever 1.60.1 hands
-- UNIT_AURA a secret addedAuras even out of combat, and ipairs on it raises (BugSack 2026-11-22).
local IsReadableTable = function(value)
	if (type(value) ~= "table" or IsSecretValue(value)) then return false end
	if (type(issecrettable) == "function" and issecrettable(value)) then return false end
	return true
end

-- One debuff, from an aura data table. Only when every field used is readable.
local Record = function(aura)
	if (not IsReadableTable(aura)) then return false end
	local spellID = Readable(aura.spellId)
	if (type(spellID) ~= "number" or spellID <= 0) then return false end
	if (Readable(aura.isHarmful) ~= true) then return false end
	-- From a player or a player's pet only: the mobs' own debuffs on each other are no choice to make.
	if (Readable(aura.isFromPlayerOrPlayerPet) ~= true) then return false end
	local source = Readable(aura.sourceUnit)
	local class, own
	if (type(source) == "string" and source ~= "") then
		if (UnitIsUnit and (Readable(UnitIsUnit(source, "player")) or Readable(UnitIsUnit(source, "pet")))) then
			own = true
		end
		if (UnitIsPlayer and Readable(UnitIsPlayer(source)) == true and UnitClass) then
			local _, token = UnitClass(source)
			class = Readable(token)
			if (type(class) ~= "string") then class = nil end
		end
	end
	local list = GetSeenStore(true)
	if (not list) then return false end
	local found
	for index, entry in ipairs(list) do
		if (type(entry) == "table" and entry.id == spellID) then
			found = index
			break
		end
	end
	local entry = found and list[found] or { id = spellID }
	entry.class = class or entry.class
	entry.own = own or entry.own
	if (found ~= 1) then
		if (found) then table_remove(list, found) end
		table_insert(list, 1, entry)
		for index = #list, AuraLists.SeenLimit + 1, -1 do list[index] = nil end
		return true
	end
	return false
end
AuraLists.Record = Record

local IsNamePlateUnit = function(unit)
	return type(unit) == "string" and not IsSecretValue(unit) and string_find(unit, "^nameplate%d+$") ~= nil
end

local IsHarvesting = function()
	if (InCombatLockdown and InCombatLockdown()) then return false end
	local profile = GetProfile()
	return profile and profile.enabled ~= false and profile.showAuras ~= false and true or false
end

-- Only enemies: debuffs on friends are the group's, not choices for an enemy plate.
local IsEnemy = function(unit)
	if (not UnitCanAttack) then return false end
	return Readable(UnitCanAttack("player", unit)) == true
end

local changed

-- Whether the game would hand this aura index back as secret. Asking first matters: on a tainted path
-- GetAuraDataByIndex raises on a secret aura instead of returning one (BugSack 2026-11-22, Forever).
local IsIndexSecret = function(unit, index)
	local secrets = C_Secrets
	if (type(secrets) ~= "table") then return false end
	if (type(secrets.ShouldUnitAuraIndexBeSecret) == "function") then
		local ok, secret = pcall(secrets.ShouldUnitAuraIndexBeSecret, unit, index, "HARMFUL")
		return (not ok) or IsSecretValue(secret) or secret == true
	end
	return false
end

local HarvestUnit = function(unit, updateInfo)
	if (not IsHarvesting() or not IsNamePlateUnit(unit) or not IsEnemy(unit)) then return end
	if (type(updateInfo) == "table") then
		-- A secret update means secret auras: nothing here is ours to read.
		if (not IsReadableTable(updateInfo)) then return end
		local full = updateInfo.isFullUpdate
		if (IsSecretValue(full)) then return end
		if (not full) then
			local added = updateInfo.addedAuras
			if (not IsReadableTable(added)) then return end
			for _, aura in ipairs(added) do
				if (Record(aura)) then changed = true end
			end
			return
		end
	end
	local get = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
	if (not get) then return end
	for index = 1, 40 do
		if (IsIndexSecret(unit, index)) then break end
		local ok, aura = pcall(get, unit, index, "HARMFUL")
		if (not ok or not aura) then break end
		if (Record(aura)) then changed = true end
	end
end
AuraLists.HarvestUnit = HarvestUnit

-- One notice per burst of aura events, for the picker's list.
local notifyPending
local FlushChanged = function()
	notifyPending = nil
	if (changed) then
		changed = nil
		Notify("seen")
	end
end

local ScheduleNotify = function()
	if (not changed or notifyPending) then return end
	notifyPending = true
	if (C_Timer and C_Timer.After) then C_Timer.After(.5, FlushChanged) else FlushChanged() end
end

if (type(CreateFrame) == "function") then
	local watcher = CreateFrame("Frame")
	local Listen = function(on)
		if (on) then
			watcher:RegisterEvent("UNIT_AURA")
		elseif (watcher.UnregisterEvent) then
			watcher:UnregisterEvent("UNIT_AURA")
		end
	end
	watcher:RegisterEvent("PLAYER_REGEN_DISABLED")
	watcher:RegisterEvent("PLAYER_REGEN_ENABLED")
	watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
	watcher:RegisterEvent("NAME_PLATE_UNIT_ADDED")
	watcher:SetScript("OnEvent", function(_, event, unit, updateInfo)
		if (event == "PLAYER_REGEN_DISABLED") then
			Listen(false)
		elseif (event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_ENTERING_WORLD") then
			Listen(not (InCombatLockdown and InCombatLockdown()))
		elseif (event == "NAME_PLATE_UNIT_ADDED") then
			HarvestUnit(unit)
			ScheduleNotify()
		elseif (event == "UNIT_AURA") then
			HarvestUnit(unit, updateInfo)
			ScheduleNotify()
		end
	end)
	AuraLists.watcher = watcher
end

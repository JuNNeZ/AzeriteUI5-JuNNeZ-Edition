--[[

	The MIT License (MIT)

	Copyright (c) 2026 Lars Norberg
	Copyright (c) 2026 Jonas "JuNNeZ" Andersen (JuNNeZ Edition modifications)

	Permission is hereby granted, free of charge, to any person obtaining a copy
	of this software and associated documentation files (the "Software"), to deal
	in the Software without restriction, including without limitation the rights
	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	copies of the Software, and to permit persons to whom the Software is
	furnished to do so, subject to the following conditions:

	The above copyright notice and this permission notice shall be included in all
	copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
	SOFTWARE.

--]]
--[[
	The player's interrupt: which spell it is, and whether it is ready. One answer for every
	castbar that colours itself by it, the target's and every nameplate's.

	Until 2026-09 this was worked out twice (Docs/Nameplates Overhaul Plan.md, Phase 5): the
	plates had a per-class resolver with its own cooldown timer, the target castbar a priority
	list in AuraData.lua and the spell's cooldown. NameplateInterruptDB.lua, which enemy casts
	can be interrupted at all, is a different question and stays where it is.

	Readiness is read the way that still answers in combat. C_Spell.GetSpellCooldown is secret
	while cooldowns are restricted; GetSpellCooldownDuration is not, and its duration object's
	IsZero carries no secret flag (Blizzard_APIDocumentationGenerated, 12.1.0). Clear cooldown
	values come next, and last an estimate: the interrupt was seen cast, so it is out for its
	known cooldown.
]]
local _, ns = ...

local API = ns.API

-- Lua API
local GetTime = GetTime
local next = next
local pairs = pairs
local type = type
local unpack = unpack

local SPELL_BANK_PLAYER = (Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player) or 0
local SPELL_BANK_PET = (Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Pet) or 1

local IsSecretValue = function(value)
	return (issecretvalue and issecretvalue(value)) and true or false
end

-- Per class, the first known spell wins. A spec without an interrupt knows none of its class's
-- list (a Holy Paladin no Rebuke, a Restoration Druid no Skull Bash), so no spec table is needed.
-- Pet spells count: the pet's spellbook is asked too.
local RETAIL_SPELLS = {
	DEATHKNIGHT = { 47528 }, -- Mind Freeze
	DEMONHUNTER = { 183752 }, -- Disrupt
	DRUID = { 106839, 78675 }, -- Skull Bash, Solar Beam
	EVOKER = { 351338 }, -- Quell
	HUNTER = { 147362, 187707 }, -- Counter Shot, Muzzle
	MAGE = { 2139 }, -- Counterspell
	MONK = { 116705 }, -- Spear Hand Strike
	PALADIN = { 96231, 31935 }, -- Rebuke, Avenger's Shield
	PRIEST = { 15487 }, -- Silence
	ROGUE = { 1766 }, -- Kick
	SHAMAN = { 57994 }, -- Wind Shear
	WARLOCK = { 132409, 119910, 19647, 89766 }, -- Spell Lock (sacrificed, commanded, Felhunter), Axe Toss
	WARRIOR = { 6552 } -- Pummel
}

-- Forever: classic content, where spells are ranked. Highest rank first, so the one on the bar is
-- the one whose cooldown is read. Unverified in game.
local FOREVER_SPELLS = {
	MAGE = { 2139 }, -- Counterspell
	PRIEST = { 15487 }, -- Silence (talent)
	ROGUE = { 1769, 1768, 1767, 1766 }, -- Kick
	SHAMAN = { 10414, 10413, 10412, 8046, 8045, 8044, 8042 }, -- Earth Shock
	WARLOCK = { 19647, 19244 }, -- Spell Lock (Felhunter)
	WARRIOR = { 6554, 6552 } -- Pummel
}

local IsSpellKnownAnywhere

-- A spell that is known but cannot be cast right now. The sacrificed Spell Lock is only there
-- while Grimoire of Sacrifice is on the player.
local REQUIRES = {
	[132409] = function()
		return C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID and C_UnitAuras.GetPlayerAuraBySpellID(196099) ~= nil
	end
}

local GetSpecID = function()
	return PlayerUtil and PlayerUtil.GetCurrentSpecID and PlayerUtil.GetCurrentSpecID() or nil
end

-- Base cooldowns in seconds, for the estimate only. A function gets the spec.
local RETAIL_COOLDOWNS = {
	[6552] = 15, [96231] = 15, [31935] = 15, [147362] = 24, [187707] = 15, [1766] = 15, [15487] = 45,
	[47528] = 15, [116705] = 15, [106839] = 15, [78675] = 60, [183752] = 15,
	[119910] = 24, [132409] = 24, [19647] = 24, [89766] = 30,
	[57994] = function(specID) return (specID == 264) and 30 or 12 end, -- Wind Shear, Restoration
	[2139] = function() return IsSpellKnownAnywhere(382297) and 20 or 25 end, -- Counterspell, Quick Witted
	[351338] = function(specID) -- Quell, Interwoven Threads
		return (specID == 1473 and IsSpellKnownAnywhere(412713)) and 18 or 20
	end
}
local FOREVER_COOLDOWNS = {
	[2139] = 30, [15487] = 45, [19647] = 24, [19244] = 24,
	[6552] = 10, [6554] = 10, [1766] = 10, [1767] = 10, [1768] = 10, [1769] = 10,
	[8042] = 6, [8044] = 6, [8045] = 6, [8046] = 6, [10412] = 6, [10413] = 6, [10414] = 6
}

IsSpellKnownAnywhere = function(spellID)
	if (type(spellID) ~= "number") then
		return false
	end
	local spellBook = C_SpellBook
	if (spellBook and spellBook.IsSpellKnownOrInSpellBook) then
		local okPlayer, knownPlayer = API.TryCall(spellBook.IsSpellKnownOrInSpellBook, spellID)
		if (okPlayer and knownPlayer == true) then
			return true
		end
		local okPet, knownPet = API.TryCall(spellBook.IsSpellKnownOrInSpellBook, spellID, SPELL_BANK_PET)
		if (okPet and knownPet == true) then
			return true
		end
	end
	if (spellBook and spellBook.IsSpellKnown) then
		local okPlayer, knownPlayer = API.TryCall(spellBook.IsSpellKnown, spellID, SPELL_BANK_PLAYER)
		if (okPlayer and knownPlayer == true) then
			return true
		end
		local okPet, knownPet = API.TryCall(spellBook.IsSpellKnown, spellID, SPELL_BANK_PET)
		if (okPet and knownPet == true) then
			return true
		end
	end
	if (type(IsSpellKnown) == "function") then
		local ok, knownLegacy = API.TryCall(IsSpellKnown, spellID)
		if (ok and knownLegacy == true) then
			return true
		end
	end
	return false
end

local GetClassFile = function()
	local classFile = UnitClassBase and UnitClassBase("player")
	if (type(classFile) ~= "string" or classFile == "") then
		local _, fallbackClass = UnitClass("player")
		classFile = fallbackClass
	end
	return classFile
end

local GetSpellLists = function()
	if (ns.IsForever) then
		return FOREVER_SPELLS, FOREVER_COOLDOWNS
	end
	return RETAIL_SPELLS, RETAIL_COOLDOWNS
end

-- The known spells of the class's list, in order. Rebuilt when spells, spec or pet change, since a
-- known-check per castbar refresh adds up over a pull.
local known
local knownSet = {}

local RefreshKnownSpells = function()
	known = {}
	for spellID in pairs(knownSet) do
		knownSet[spellID] = nil
	end
	local spells = GetSpellLists()
	local list = spells[GetClassFile()]
	if (type(list) ~= "table") then
		return known
	end
	for index = 1, #list do
		local spellID = list[index]
		if (IsSpellKnownAnywhere(spellID)) then
			known[#known + 1] = spellID
			knownSet[spellID] = true
		end
	end
	return known
end

local GetPrimarySpell = function()
	local list = known or RefreshKnownSpells()
	for index = 1, #list do
		local spellID = list[index]
		local requirement = REQUIRES[spellID]
		if (not requirement or requirement()) then
			return spellID
		end
	end
	return nil
end

-- What the spell is right now: talents and forms can swap one spell for another.
local ResolveOverride = function(spellID)
	if (not C_Spell or not C_Spell.GetOverrideSpell) then
		return spellID
	end
	local resolved, seen = spellID, {}
	for _ = 1, 5 do
		if (seen[resolved]) then
			break
		end
		seen[resolved] = true
		local ok, override = API.TryCall(C_Spell.GetOverrideSpell, resolved)
		if (not ok or type(override) ~= "number" or IsSecretValue(override) or override <= 0 or override == resolved) then
			break
		end
		resolved = override
	end
	return resolved
end

local ReadyFromDuration = function(spellID)
	if (not C_Spell or not C_Spell.GetSpellCooldownDuration) then
		return nil
	end
	-- ignoreGCD: the global cooldown after any other cast is not the interrupt being out.
	local ok, duration = API.TryCall(C_Spell.GetSpellCooldownDuration, spellID, true)
	if (not ok or not duration or not duration.IsZero) then
		return nil
	end
	local okZero, isZero = API.TryCall(duration.IsZero, duration)
	if (okZero and type(isZero) == "boolean" and not IsSecretValue(isZero)) then
		return isZero
	end
	return nil
end

local ReadyFromTimes = function(startTime, duration)
	if (type(startTime) ~= "number" or type(duration) ~= "number" or IsSecretValue(startTime) or IsSecretValue(duration)) then
		return nil
	end
	if (startTime <= 0 or duration <= 0) then
		return true
	end
	return (startTime + duration) <= GetTime()
end

local ReadyFromCooldown = function(spellID)
	if (C_Spell and C_Spell.GetSpellCooldown) then
		local ok, info = API.TryCall(C_Spell.GetSpellCooldown, spellID)
		if (ok and type(info) == "table") then
			local ready = ReadyFromTimes(info.startTime, info.duration)
			if (ready ~= nil) then
				return ready
			end
		end
	end
	if (type(GetSpellCooldown) == "function") then
		local ok, startTime, duration = API.TryCall(GetSpellCooldown, spellID)
		if (ok) then
			return ReadyFromTimes(startTime, duration)
		end
	end
	return nil
end

-- The estimate: when each interrupt was last seen cast, and for how long it is then out.
local availableAt = {}

local GetCooldownEstimate = function(spellID)
	local _, cooldowns = GetSpellLists()
	local cooldown = cooldowns[spellID]
	if (type(cooldown) == "function") then
		cooldown = cooldown(GetSpecID())
	end
	return type(cooldown) == "number" and cooldown or 0
end

local listener = CreateFrame("Frame")
listener:RegisterEvent("PLAYER_LOGIN")
listener:RegisterEvent("PLAYER_ENTERING_WORLD")
listener:RegisterEvent("SPELLS_CHANGED")
listener:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
listener:RegisterEvent("TRAIT_CONFIG_UPDATED")
listener:RegisterUnitEvent("UNIT_PET", "player")
-- A pet casts its own interrupt, so the pet's casts count too.
listener:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "pet")
listener:SetScript("OnEvent", function(_, event, unit, _, spellID)
	if (event == "UNIT_SPELLCAST_SUCCEEDED") then
		if (type(spellID) ~= "number" or IsSecretValue(spellID)) then
			return
		end
		if (not known) then
			RefreshKnownSpells()
		end
		if (knownSet[spellID]) then
			availableAt[spellID] = GetTime() + GetCooldownEstimate(spellID)
		end
		return
	end
	RefreshKnownSpells()
end)

--[[
	API.GetPrimaryInterrupt()

	Returns the player's primary interrupt spell ID and whether it is ready now (a boolean), or
	nothing when the player has no interrupt. Whenever there is a spell, readiness has an answer:
	the duration object's, clear cooldown values', or the estimate's.
]]
API.GetPrimaryInterrupt = function()
	local spellID = GetPrimarySpell()
	if (not spellID) then
		return nil, nil
	end
	local queryID = ResolveOverride(spellID)
	local ready = ReadyFromDuration(queryID)
	if (ready == nil) then
		ready = ReadyFromCooldown(queryID)
	end
	if (ready == nil) then
		ready = GetTime() >= (availableAt[spellID] or 0)
	end
	return spellID, ready
end

-- Whether the player or their pet knows a spell, however the client asks. Shared with ExecuteRange.lua.
API.IsSpellKnownAnywhere = IsSpellKnownAnywhere

-- Every interrupt spell of the current client's lists, for tooling and tests.
API.GetInterruptSpellLists = function()
	local spells = GetSpellLists()
	local copy = {}
	for classFile, list in next, spells do
		copy[classFile] = { unpack(list) }
	end
	return copy
end

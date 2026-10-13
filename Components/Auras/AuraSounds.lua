--[[

	The MIT License (MIT)

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
local _, ns = ...

--[[
	Aura sounds: a sound when an aura is added to, stacks up on, or falls off a unit.

	12.1 lets the client do this for us. C_UnitAuras.AddAuraSound(trigger, info) takes
	a unit token, a spell ID and a sound file, and the client plays the sound itself
	whenever that aura changes, in combat and in restricted content alike; no aura data
	ever reaches addon code. Only the registration is restricted (HasRestrictions,
	untainted arguments), so registrations happen while nothing is restricted, and a
	change made during a fight, an encounter or a key waits until it ends.

	Six slots under /az -> Aura Sounds. The sounds come from
	LibSharedMedia, which DBM, BigWigs, WeakAuras and SharedMedia packs fill.
]]

local AuraSounds = ns:NewModule("AuraSounds", "LibMoreEvents-1.0")
local LSM = LibStub("LibSharedMedia-3.0", true)

local SLOTS = 6
AuraSounds.Slots = SLOTS

local UNITS = { player = true, target = true, focus = true }
AuraSounds.Units = { "player", "target", "focus" }

-- Setting value -> Enum.UnitAuraSoundTrigger field.
local TRIGGERS = { added = "Added", stacks = "ApplicationsIncreased", removed = "Removed" }
AuraSounds.Triggers = { "added", "stacks", "removed" }

local defaults = { profile = { enabled = true } }
for slot = 1, SLOTS do
	defaults.profile["sound" .. slot .. "Spell"] = ""
	defaults.profile["sound" .. slot .. "Unit"] = "player"
	defaults.profile["sound" .. slot .. "Trigger"] = "added"
	defaults.profile["sound" .. slot .. "Sound"] = "None"
end
AuraSounds.defaults = defaults

AuraSounds.GetDefaults = function(self)
	return defaults
end

local IsSecret = function(value)
	return type(issecretvalue) == "function" and issecretvalue(value) or false
end

-- Whether the client offers the API at all (Retail 12.1 and later).
AuraSounds.IsAvailable = function(self)
	return C_UnitAuras and type(C_UnitAuras.AddAuraSound) == "function"
		and type(C_UnitAuras.RemoveAuraSound) == "function"
		and Enum and Enum.UnitAuraSoundTrigger and true or false
end

-- Registration waits while the client restricts addons: in combat, in an encounter,
-- in a key or in a PvP match, the set Decursive waits for too. Not "Map": it stays on
-- in open-world zones, and waiting for it left every slot waiting (2026-10-13 retest).
-- A registration the game still refuses is retried by Apply.
AuraSounds.IsRestricted = function(self)
	if (InCombatLockdown()) then return true end
	local restricted = C_RestrictedActions and C_RestrictedActions.IsAddOnRestrictionActive
	local types = Enum and Enum.AddOnRestrictionType
	if (type(restricted) ~= "function" or type(types) ~= "table") then return false end
	for _, key in ipairs({ "Combat", "Encounter", "ChallengeMode", "PvPMatch" }) do
		local value = types[key]
		if (value ~= nil) then
			local ok, active = pcall(restricted, value)
			if (not ok or IsSecret(active) or active) then return true end
		end
	end
	return false
end

-- The game matches the aura's own spell ID, which is not always the ID of the spell
-- that applies it (Blur casts 198589 and applies 212800). Three sources, in order:
-- these known pairs, the links Blizzard's Cooldown Manager holds for the player's own
-- spells (BuildCooldownLinks), and otherwise the spell's own ID, which is the usual case.
local KNOWN_AURAS = {
	[115203] = { 120954 }, -- Fortifying Brew
	[198589] = { 212800 } -- Blur
}

-- The Common auras list on each slot. Every ID was checked against the aura lists other
-- addons ship (AzeriteUI's own, DBM) on 2026-10-13. A preset with several IDs matches any
-- of them; `trigger` also sets When.
local LUST = "2825, 32182, 80353, 264667, 390386"
local SATED = "57724, 57723, 80354, 95809, 264689, 390435"
AuraSounds.Presets = {
	{ key = "lust", spells = LUST, name = "Bloodlust / Heroism / Time Warp" },
	{ key = "sated", spells = SATED, name = "Bloodlust ready again (Sated fades)", trigger = "removed" },
	{ key = "1044", spells = "1044", name = "Blessing of Freedom" },
	{ key = "1022", spells = "1022", name = "Blessing of Protection" },
	{ key = "6940", spells = "6940", name = "Blessing of Sacrifice" },
	{ key = "204018", spells = "204018", name = "Blessing of Spellwarding" },
	{ key = "10060", spells = "10060", name = "Power Infusion" },
	{ key = "33206", spells = "33206", name = "Pain Suppression" },
	{ key = "47788", spells = "47788", name = "Guardian Spirit" },
	{ key = "102342", spells = "102342", name = "Ironbark" },
	{ key = "116849", spells = "116849", name = "Life Cocoon" },
	{ key = "357170", spells = "357170", name = "Time Dilation" },
	{ key = "29166", spells = "29166", name = "Innervate" },
	{ key = "642", spells = "642", name = "Divine Shield" },
	{ key = "498", spells = "498", name = "Divine Protection" },
	{ key = "31884", spells = "31884", name = "Avenging Wrath" },
	{ key = "45438", spells = "45438", name = "Ice Block" },
	{ key = "186265", spells = "186265", name = "Aspect of the Turtle" },
	{ key = "871", spells = "871", name = "Shield Wall" },
	{ key = "61336", spells = "61336", name = "Survival Instincts" },
	{ key = "22812", spells = "22812", name = "Barkskin" },
	{ key = "48792", spells = "48792", name = "Icebound Fortitude" },
	{ key = "48707", spells = "48707", name = "Anti-Magic Shell" },
	{ key = "5277", spells = "5277", name = "Evasion" },
	{ key = "31224", spells = "31224", name = "Cloak of Shadows" },
	{ key = "104773", spells = "104773", name = "Unending Resolve" },
	{ key = "47585", spells = "47585", name = "Dispersion" },
	{ key = "108271", spells = "108271", name = "Astral Shift" },
	{ key = "120954", spells = "120954", name = "Fortifying Brew" },
	{ key = "212800", spells = "212800", name = "Blur" },
	{ key = "363916", spells = "363916", name = "Obsidian Scales" }
}

local SpellName = function(spellID)
	local name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spellID)
	if (IsSecret(name) or type(name) ~= "string" or name == "") then return end
	return name
end
AuraSounds.SpellName = SpellName

-- The aura IDs Blizzard's Cooldown Manager links to the player's spells, rebuilt on each
-- registration pass (always out of combat). A spell it marks as its own aura maps to itself.
AuraSounds.BuildCooldownLinks = function(self)
	local links = {}
	self.cooldownLinks = links
	local viewer = C_CooldownViewer
	if (not viewer or type(viewer.GetCooldownViewerCategorySet) ~= "function"
		or type(viewer.GetCooldownViewerCooldownInfo) ~= "function") then
		return links
	end
	for category = 0, 8 do
		local ok, ids = pcall(viewer.GetCooldownViewerCategorySet, category, true)
		if (ok and type(ids) == "table") then
			for _, cooldownID in ipairs(ids) do
				local okInfo, info = pcall(viewer.GetCooldownViewerCooldownInfo, cooldownID)
				local spellID = okInfo and type(info) == "table" and info.spellID
				if (type(spellID) == "number" and not IsSecret(spellID) and type(info.linkedSpellIDs) == "table") then
					local auras = {}
					if (info.selfAura == true) then auras[#auras + 1] = spellID end
					for _, linked in ipairs(info.linkedSpellIDs) do
						if (type(linked) == "number" and not IsSecret(linked)) then auras[#auras + 1] = linked end
					end
					if (#auras > 0) then
						links[spellID] = auras
						local override = info.overrideSpellID
						if (type(override) == "number" and not IsSecret(override)) then links[override] = auras end
					end
				end
			end
		end
	end
	return links
end

-- One typed word as a spell ID: a number, a name on the Common auras list (in the
-- client's language or English), or a name the client knows.
local ResolveWord = function(word)
	local spellID = tonumber(word)
	if (not spellID) then
		local lower = word:lower()
		for _, preset in ipairs(AuraSounds.Presets) do
			local id = tonumber(preset.spells)
			if (id) then
				local name = SpellName(id)
				if ((name and name:lower() == lower) or preset.name:lower() == lower) then
					spellID = id
					break
				end
			end
		end
	end
	if (not spellID and C_Spell and C_Spell.GetSpellIDForSpellIdentifier) then
		local ok, id = pcall(C_Spell.GetSpellIDForSpellIdentifier, word)
		if (ok and not IsSecret(id) and type(id) == "number") then spellID = id end
	end
	if (spellID and spellID > 0 and spellID == math.floor(spellID)) then
		return spellID
	end
end

--- The aura IDs for what the player typed: names or IDs, separated by commas. Returns
--- a list of aura IDs without duplicates, and a list of the words it could not resolve.
AuraSounds.ResolveAuras = function(self, text)
	local auras, unknown, seen = {}, {}, {}
	if (type(text) ~= "string") then return auras, unknown end
	local links = self.cooldownLinks or {}
	for word in text:gmatch("[^,;]+") do
		word = word:match("^%s*(.-)%s*$")
		if (word ~= "") then
			local spellID = ResolveWord(word)
			if (spellID) then
				for _, auraID in ipairs(KNOWN_AURAS[spellID] or links[spellID] or { spellID }) do
					if (not seen[auraID]) then
						seen[auraID] = true
						auras[#auras + 1] = auraID
					end
				end
			else
				unknown[#unknown + 1] = word
			end
		end
	end
	return auras, unknown
end

-- The first aura ID for what the player typed, or nil when any of it is unknown.
AuraSounds.ResolveSpell = function(self, text)
	local auras, unknown = self:ResolveAuras(text)
	if (#unknown == 0 and #auras > 0) then return auras[1] end
end

-- The preset whose spells a slot holds, for the Common auras dropdown.
AuraSounds.GetPreset = function(self, text)
	if (type(text) ~= "string") then return end
	text = text:match("^%s*(.-)%s*$")
	for _, preset in ipairs(self.Presets) do
		if (preset.spells == text) then return preset end
	end
	-- A typed name: the preset with the same single aura ("Blessing of Freedom" is 1044).
	local auras, unknown = self:ResolveAuras(text)
	if (#auras ~= 1 or #unknown > 0) then return end
	for _, preset in ipairs(self.Presets) do
		if (tonumber(preset.spells) == auras[1]) then return preset end
	end
end

-- The sounds LibSharedMedia knows, as select values.
AuraSounds.GetSoundChoices = function(self)
	local values = { None = NONE or "None" }
	if (LSM) then
		for _, name in ipairs(LSM:List("sound") or {}) do
			values[name] = name
		end
	end
	return values
end

-- The registration info for one slot: the trigger and one info table per aura ID.
-- When the slot cannot be registered, returns nil and why: "empty", "spell" (with the
-- unknown words), "sound" or "unit".
AuraSounds.BuildSlot = function(self, slot)
	local db = self.db and self.db.profile
	if (not db) then return nil, nil, "empty" end
	local text = db["sound" .. slot .. "Spell"]
	if (type(text) ~= "string" or text:match("^%s*$")) then return nil, nil, "empty" end
	local auras, unknown = self:ResolveAuras(text)
	if (#auras == 0 or #unknown > 0) then return nil, nil, "spell", unknown end
	local unit = db["sound" .. slot .. "Unit"]
	local trigger = TRIGGERS[db["sound" .. slot .. "Trigger"]]
	if (not UNITS[unit] or not trigger) then return nil, nil, "unit" end
	local soundName = db["sound" .. slot .. "Sound"]
	if (not soundName or soundName == "None") then return nil, nil, "sound" end

	local file = LSM and LSM:Fetch("sound", soundName, true)
	if (type(file) ~= "number" and type(file) ~= "string") then return nil, nil, "sound" end
	local infos = {}
	for _, auraID in ipairs(auras) do
		local info = { unitToken = unit, spellID = auraID, outputChannel = "Master" }
		if (type(file) == "number") then
			info.soundFileID = file
		else
			info.soundFileName = file
		end
		infos[#infos + 1] = info
	end
	return Enum.UnitAuraSoundTrigger[trigger], infos
end

AuraSounds.UnregisterAll = function(self)
	for index, soundID in ipairs(self.registered) do
		pcall(C_UnitAuras.RemoveAuraSound, soundID)
		self.registered[index] = nil
	end
end

-- Removes every registration and adds the current slots again. Waits while the
-- client restricts addons, and runs once the restriction lifts.
AuraSounds.Apply = function(self)
	if (not self:IsAvailable()) then return end
	if (self:IsRestricted()) then
		self.pending = true
		self.status = { waiting = true }
		self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnEvent")
		if (ns.API.IsEventAvailable("ADDON_RESTRICTION_STATE_CHANGED")) then
			self:RegisterEvent("ADDON_RESTRICTION_STATE_CHANGED", "OnEvent")
		end
		return
	end
	self.pending = nil

	self:UnregisterAll()
	-- What happened to each slot, for the options page (GetSlotStatus).
	self.status = {}
	if (not self.db.profile.enabled) then return end
	self:BuildCooldownLinks()
	local failed = false
	for slot = 1, SLOTS do
		local trigger, infos, reason, unknown = self:BuildSlot(slot)
		if (trigger ~= nil) then
			-- The first aura the game turns down decides the status; the rest still register.
			local entry = { state = "ok", auras = {} }
			for _, info in ipairs(infos) do
				local ok, soundID = pcall(C_UnitAuras.AddAuraSound, trigger, info)
				if (ok and type(soundID) == "number" and not IsSecret(soundID)) then
					self.registered[#self.registered + 1] = soundID
					entry.auras[#entry.auras + 1] = info.spellID
				elseif (entry.state == "ok") then
					entry.state = ok and "refused" or "error"
					entry.spellID = info.spellID
					entry.message = (not ok) and tostring(soundID) or nil
					failed = failed or not ok
				end
			end
			self.status[slot] = entry
		else
			self.status[slot] = { state = reason, unknown = unknown }
		end
	end
	-- A restriction the check above does not know of can still refuse the call: try again
	-- after the next fight or zone change, and say so on the slot meanwhile.
	-- 2026-10-13 retest: a slot refused at login waited for the fight to end, and the
	-- sound then came at the end of combat. A short timer retries too, a few times.
	self.retry = failed or nil
	if (not failed) then
		self.retryCount = nil
		return
	end
	self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnEvent")
	self:RegisterEvent("ZONE_CHANGED_NEW_AREA", "OnEvent")
	self.retryCount = (self.retryCount or 0) + 1
	if (self.retryCount <= 12 and C_Timer and C_Timer.After) then
		C_Timer.After(5, function()
			if (self.retry and not self.pending and not self:IsRestricted()) then self:Apply() end
		end)
	end
end

--- What the last registration pass did with a slot, as one line for the options page.
AuraSounds.GetSlotStatus = function(self, slot, L)
	local status = self.status or {}
	if (status.waiting) then return L["Waiting until combat or the encounter ends."] end
	if (not self.db.profile.enabled) then return "" end
	local entry = status[slot]
	if (not entry or entry.state == "empty") then return "" end
	if (entry.state == "spell") then
		if (entry.unknown and #entry.unknown > 0) then
			return string.format(L["Unknown spell: %s"], table.concat(entry.unknown, ", "))
		end
		return L["Spell not found."]
	end
	if (entry.state == "sound") then return L["Choose a sound."] end
	if (entry.state == "unit") then return "" end
	if (entry.state == "ok") then
		local names = {}
		for _, auraID in ipairs(entry.auras) do
			names[#names + 1] = string.format("%s (%d)", SpellName(auraID) or "?", auraID)
		end
		return string.format(L["Registered: %s."], table.concat(names, ", "))
	end
	local name = SpellName(entry.spellID) or "?"
	if (entry.state == "refused") then return string.format(L["The game returned no registration for %s (%d)."], name, entry.spellID) end
	return string.format(L["The game refused it: %s"], entry.message or "?")
end

AuraSounds.UpdateSettings = function(self)
	self:Apply()
end

-- Plays a slot's sound once, so the player hears what they picked.
AuraSounds.PreviewSlot = function(self, slot)
	local db = self.db and self.db.profile
	local name = db and db["sound" .. slot .. "Sound"]
	if (not LSM or not name or name == "None") then return end
	local file = LSM:Fetch("sound", name, true)
	if (file) then PlaySoundFile(file, "Master") end
end

AuraSounds.OnEvent = function(self, event)
	if (event == "PLAYER_ENTERING_WORLD") then
		self:UnregisterEvent("PLAYER_ENTERING_WORLD", "OnEvent")
		self:Apply()
		return
	end
	-- The client answers "not restricted" to every type while it dispatches this event,
	-- so look again on the next frame.
	if (event == "ADDON_RESTRICTION_STATE_CHANGED" and C_Timer and C_Timer.After) then
		C_Timer.After(0, function() self:OnEvent("RESTRICTION_SETTLED") end)
		return
	end
	if (self.retry and not self.pending) then
		if (self:IsRestricted()) then return end
		self:UnregisterEvent("PLAYER_REGEN_ENABLED", "OnEvent")
		self:UnregisterEvent("ZONE_CHANGED_NEW_AREA", "OnEvent")
		self:Apply()
		return
	end
	if (not self.pending or self:IsRestricted()) then return end
	self:UnregisterEvent("PLAYER_REGEN_ENABLED", "OnEvent")
	if (ns.API.IsEventAvailable("ADDON_RESTRICTION_STATE_CHANGED")) then
		self:UnregisterEvent("ADDON_RESTRICTION_STATE_CHANGED", "OnEvent")
	end
	self:Apply()
end

AuraSounds.OnInitialize = function(self)
	self.db = ns.db:RegisterNamespace(self:GetName(), defaults)
	self.registered = {}
end

AuraSounds.OnEnable = function(self)
	if (not self:IsAvailable()) then return end
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEvent")
	-- A media pack that loads after us can register a sound a slot already names.
	-- Packs register dozens at load, so only a sound some slot is waiting for counts.
	if (LSM) then
		LSM.RegisterCallback(self, "LibSharedMedia_Registered", function(_, mediaType, key)
			if (mediaType ~= "sound" or not self.db.profile.enabled) then return end
			for slot = 1, SLOTS do
				if (self.db.profile["sound" .. slot .. "Sound"] == key) then
					self:Apply()
					return
				end
			end
		end)
	end
end

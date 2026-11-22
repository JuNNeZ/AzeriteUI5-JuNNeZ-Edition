--[[

	The MIT License (MIT)

	Copyright (c) 2026 Jonas "JuNNeZ" Andersen

--]]
-- The nameplate aura picker's suggestions (Options/Kit/AuraPicker.lua; Docs/Nameplate Aura Picker Plan -
-- 2026-11-21.md, steps 2 and 3): per specialization on Retail and per class on Forever, the debuffs worth a
-- gold border or "Only once", each with the spell that grants it, so the picker can sort the ones you have
-- talented first. Source and procedure: Tools/AuraSuggestions/README.md.
--
-- Data, not guesses: every row was checked against Retail's own spell tables (wago.tools, build
-- 12.1.5.70961): the aura ID carries that name and applies an aura to an enemy, and the granting spell is
-- offered to that specialization (a talent node whose conditions allow it, a specialization spell or a class
-- ability). A granting ID of 0 means every player of the specialization has it. Rows the tables showed as
-- gone (Festering Wound, Stellar Flare, Serpent Sting, Living Bomb, ...) were left out. Forever has its own
-- table further down, checked on product wowf. Regenerate from the checked lists, not by hand.
local _, ns = ...

local NP = ns.NamePlatesPrivate
if (not NP) then return end

-- Lua API
local ipairs = ipairs
local next = next
local table_sort = table.sort
local type = type

local AuraSuggestions = {}
NP.AuraSuggestions = AuraSuggestions

local RETAIL = {
	-- Retail 12.1.5.70961. { aura spell ID, granting spell ID (0: every player of the spec has it), recommended }
	[250] = { class = "DEATHKNIGHT", -- Blood Deathknight
		{ 55078, 0, "once" }, -- Blood Plague
		{ 434765, 439843, "highlight" }, -- Reaper's Mark <- Reaper's Mark
	},
	[251] = { class = "DEATHKNIGHT", -- Frost Deathknight
		{ 55095, 0, "once" }, -- Frost Fever
		{ 51714, 0, nil }, -- Razorice
		{ 434765, 439843, "highlight" }, -- Reaper's Mark <- Reaper's Mark
	},
	[252] = { class = "DEATHKNIGHT", -- Unholy Deathknight
		{ 191587, 0, "once" }, -- Virulent Plague
		{ 1240996, 77575, "once" }, -- Dread Plague <- Outbreak
		{ 1241521, 343294, nil }, -- Soul Reaper <- Soul Reaper
	},
	[1480] = { class = "DEMONHUNTER", -- Devourer Demonhunter
		{ 1246168, 1246167, nil }, -- The Hunt <- The Hunt
	},
	[577] = { class = "DEMONHUNTER", -- Havoc Demonhunter
		{ 391191, 391189, "once" }, -- Burning Wound <- Burning Wound
		{ 320338, 258860, "highlight" }, -- Essence Break <- Essence Break
		{ 204598, 0, nil }, -- Sigil of Flame
		{ 370969, 370965, nil }, -- The Hunt <- The Hunt
	},
	[581] = { class = "DEMONHUNTER", -- Vengeance Demonhunter
		{ 207771, 0, "highlight" }, -- Fiery Brand
		{ 247456, 389958, nil }, -- Frailty <- Frailty
		{ 204598, 0, nil }, -- Sigil of Flame
		{ 207407, 207407, nil }, -- Soul Carver <- Soul Carver
	},
	[102] = { class = "DRUID", -- Balance Druid
		{ 164812, 0, "once" }, -- Moonfire
		{ 164815, 0, "once" }, -- Sunfire
	},
	[103] = { class = "DRUID", -- Feral Druid
		{ 155722, 1822, "once" }, -- Rake <- Rake
		{ 1079, 1079, "once" }, -- Rip <- Rip
		{ 405233, 77758, nil }, -- Thrash <- Thrash
		{ 155625, 155580, nil }, -- Moonfire <- Lunar Inspiration
		{ 274838, 274837, nil }, -- Feral Frenzy <- Feral Frenzy
	},
	[104] = { class = "DRUID", -- Guardian Druid
		{ 192090, 0, nil }, -- Thrash
		{ 164812, 0, "once" }, -- Moonfire
	},
	[105] = { class = "DRUID", -- Restoration Druid
		{ 164812, 0, "once" }, -- Moonfire
		{ 164815, 93402, "once" }, -- Sunfire <- Sunfire
	},
	[1473] = { class = "EVOKER", -- Augmentation Evoker
		{ 357209, 0, nil }, -- Fire Breath
	},
	[1467] = { class = "EVOKER", -- Devastation Evoker
		{ 357209, 0, "once" }, -- Fire Breath
	},
	[1468] = { class = "EVOKER", -- Preservation Evoker
		{ 357209, 0, nil }, -- Fire Breath
	},
	[253] = { class = "HUNTER", -- Beast Mastery Hunter
		{ 217200, 217200, nil }, -- Barbed Shot <- Barbed Shot
		{ 257284, 0, "highlight" }, -- Hunter's Mark
	},
	[254] = { class = "HUNTER", -- Marksmanship Hunter
		{ 257284, 0, "highlight" }, -- Hunter's Mark
		{ 212431, 212431, nil }, -- Explosive Shot <- Explosive Shot
	},
	[255] = { class = "HUNTER", -- Survival Hunter
		{ 269747, 259495, nil }, -- Wildfire Bomb <- Wildfire Bomb
		{ 257284, 0, "highlight" }, -- Hunter's Mark
	},
	[62] = { class = "MAGE", -- Arcane Mage
		{ 210824, 321507, "highlight" }, -- Touch of the Magi <- Touch of the Magi
		{ 114923, 444483, nil }, -- Nether Tempest <- Controlled Instincts
	},
	[63] = { class = "MAGE", -- Fire Mage
		{ 12654, 0, "once" }, -- Ignite
		{ 468655, 431044, nil }, -- Frostfire Bolt <- Frostfire Bolt
	},
	[64] = { class = "MAGE", -- Frost Mage
		{ 228358, 0, "highlight" }, -- Winter's Chill
		{ 468655, 431044, nil }, -- Frostfire Bolt <- Frostfire Bolt
	},
	[268] = { class = "MONK", -- Brewmaster Monk
		{ 123725, 115181, "once" }, -- Breath of Fire <- Breath of Fire
		{ 121253, 0, nil }, -- Keg Smash
	},
	[270] = { class = "MONK", -- Mistweaver Monk
	},
	[269] = { class = "MONK", -- Windwalker Monk
		{ 228287, 0, "once" }, -- Mark of the Crane
	},
	[65] = { class = "PALADIN", -- Holy Paladin
	},
	[66] = { class = "PALADIN", -- Protection Paladin
	},
	[70] = { class = "PALADIN", -- Retribution Paladin
		{ 197277, 0, nil }, -- Judgment
		{ 383346, 383344, "once" }, -- Expurgation <- Expurgation
		{ 403695, 255937, nil }, -- Truth's Wake <- Wake of Ashes
	},
	[256] = { class = "PRIEST", -- Discipline Priest
		{ 589, 0, "once" }, -- Shadow Word: Pain
		{ 204213, 1250218, "once" }, -- Purge the Wicked <- Purge the Wicked
	},
	[257] = { class = "PRIEST", -- Holy Priest
		{ 589, 0, "once" }, -- Shadow Word: Pain
		{ 14914, 14914, nil }, -- Holy Fire <- Holy Fire
	},
	[258] = { class = "PRIEST", -- Shadow Priest
		{ 589, 0, "once" }, -- Shadow Word: Pain
		{ 34914, 0, "once" }, -- Vampiric Touch
		{ 335467, 335467, nil }, -- Shadow Word: Madness <- Shadow Word: Madness
	},
	[259] = { class = "ROGUE", -- Assassination Rogue
		{ 703, 0, "once" }, -- Garrote
		{ 1943, 0, "once" }, -- Rupture
		{ 2818, 2823, nil }, -- Deadly Poison <- Deadly Poison
		{ 360194, 360194, "highlight" }, -- Deathmark <- Deathmark
		{ 385627, 385627, nil }, -- Kingsbane <- Kingsbane
		{ 383414, 381664, nil }, -- Amplifying Poison <- Amplifying Poison
	},
	[260] = { class = "ROGUE", -- Outlaw Rogue
	},
	[261] = { class = "ROGUE", -- Subtlety Rogue
		{ 316220, 0, nil }, -- Find Weakness
		{ 426593, 426591, nil }, -- Goremaw's Bite <- Goremaw's Bite
	},
	[262] = { class = "SHAMAN", -- Elemental Shaman
		{ 188389, 0, "once" }, -- Flame Shock
		{ 197209, 210689, nil }, -- Lightning Rod <- Lightning Rod
	},
	[263] = { class = "SHAMAN", -- Enhancement Shaman
		{ 188389, 0, "once" }, -- Flame Shock
		{ 334168, 334046, nil }, -- Lashing Flames <- Lashing Flames
	},
	[264] = { class = "SHAMAN", -- Restoration Shaman
		{ 188389, 0, "once" }, -- Flame Shock
	},
	[265] = { class = "WARLOCK", -- Affliction Warlock
		{ 980, 0, "once" }, -- Agony
		{ 146739, 0, "once" }, -- Corruption
		{ 1259790, 1259790, "once" }, -- Unstable Affliction <- Unstable Affliction
		{ 63106, 63106, nil }, -- Siphon Life <- Siphon Life
		{ 48181, 48181, "highlight" }, -- Haunt <- Haunt
		{ 205179, 205179, nil }, -- Phantom Singularity <- Phantom Singularity
		{ 386997, 386997, nil }, -- Soul Rot <- Soul Rot
		{ 27243, 27243, nil }, -- Seed of Corruption <- Seed of Corruption
		{ 445474, 445465, "once" }, -- Wither <- Wither
	},
	[266] = { class = "WARLOCK", -- Demonology Warlock
		{ 146739, 0, "once" }, -- Corruption
		{ 460553, 460551, nil }, -- Doom <- Doom
	},
	[267] = { class = "WARLOCK", -- Destruction Warlock
		{ 157736, 0, "once" }, -- Immolate
		{ 445474, 445465, "once" }, -- Wither <- Wither
		{ 80240, 80240, "highlight" }, -- Havoc <- Havoc
		{ 265931, 0, nil }, -- Conflagrate
		{ 196414, 196412, nil }, -- Eradication <- Eradication
	},
	[71] = { class = "WARRIOR", -- Arms Warrior
		{ 262115, 0, "once" }, -- Deep Wounds
		{ 388539, 772, "once" }, -- Rend <- Rend
		{ 208086, 167105, "highlight" }, -- Colossus Smash <- Colossus Smash
		{ 397364, 384318, nil }, -- Thunderous Roar <- Thunderous Roar
		{ 376080, 376079, nil }, -- Champion's Spear <- Champion's Spear
	},
	[72] = { class = "WARRIOR", -- Fury Warrior
		{ 385060, 385059, nil }, -- Odyn's Fury <- Odyn's Fury
		{ 397364, 384318, nil }, -- Thunderous Roar <- Thunderous Roar
		{ 376080, 376079, nil }, -- Champion's Spear <- Champion's Spear
	},
	[73] = { class = "WARRIOR", -- Protection Warrior
		{ 262115, 0, nil }, -- Deep Wounds
		{ 388539, 394062, nil }, -- Rend <- Rend
		{ 1160, 1160, "highlight" }, -- Demoralizing Shout <- Demoralizing Shout
		{ 397364, 384318, nil }, -- Thunderous Roar <- Thunderous Roar
	},
}

-- Debuffs that help the whole group, from whichever class brings them.
local GROUP = {
	{ 113746, "MONK" }, -- Mystic Touch
	{ 1490, "DEMONHUNTER" }, -- Chaos Brand
	{ 257284, "HUNTER" }, -- Hunter's Mark
}

-- Forever (product wowf, build 1.60.1.71037), per class: the client has no specializations, and highlights
-- are kept per class there (Visibility.lua, GetAuraHighlightKey). Every rank's aura ID, lowest first, then
-- the granting spells when they differ (nil: the ranks themselves), then the recommendation. Checked the same
-- way: each ID carries the name and applies an aura to an enemy, reached from a spell the class learns
-- normally (not the "not normally learned" rune spells). The Judgements, Shadow Vulnerability and Shadow
-- Weaving are applied by procs and were checked ID by ID. Left out: Deep Wound, Ignite, Faerie Fire (Feral)
-- and Curse of Shadow (not in this build as class spells) and Deadly Poison (from the poison items).
local FOREVER = {
	DRUID = {
		{ { 8921, 8924, 8925, 8926, 8927, 8928, 8929, 9833, 9834, 9835 }, nil, "once" }, -- Moonfire
		{ { 5570, 24974, 24975, 24976, 24977 }, nil, "once" }, -- Insect Swarm
		{ { 1822, 1823, 1824, 9904 }, nil, "once" }, -- Rake
		{ { 1079, 9492, 9493, 9752, 9894, 9896 }, nil, "once" }, -- Rip
		{ { 1328617, 1328616, 414644, 1235826, 1235827 }, nil, nil }, -- Lacerate
		{ { 9007, 9824, 9826 }, nil, nil }, -- Pounce Bleed
	},
	HUNTER = {
		{ { 1978, 13549, 13550, 13551, 13552, 13553, 13554, 13555, 25295 }, nil, "once" }, -- Serpent Sting
		{ { 1130, 14323, 14324, 14325 }, nil, "highlight" }, -- Hunter's Mark
		{ { 13797, 14298, 14299, 14300, 14301 }, nil, nil }, -- Immolation Trap
		{ { 3043 }, nil, nil }, -- Scorpid Sting
	},
	MAGE = {
		{ { 11366, 12505, 12522, 12523, 12524, 12525, 12526, 18809 }, nil, nil }, -- Pyroblast
	},
	PRIEST = {
		{ { 589, 594, 970, 992, 2767, 10892, 10893, 10894 }, nil, "once" }, -- Shadow Word: Pain
		{ { 2944, 19276, 19277, 19278, 19279, 19280 }, nil, "once" }, -- Devouring Plague
		{ { 14914, 15262, 15263, 15264, 15265, 15266, 15267, 15261 }, nil, nil }, -- Holy Fire
		{ { 15286 }, nil, nil }, -- Vampiric Embrace
	},
	ROGUE = {
		{ { 703, 8631, 8632, 8633, 11289, 11290 }, nil, "once" }, -- Garrote
		{ { 1943, 8639, 8640, 11273, 11274, 11275 }, nil, "once" }, -- Rupture
		{ { 16511 }, nil, nil }, -- Hemorrhage
		{ { 1316709, 1325756, 1325757, 1325758 }, nil, "highlight" }, -- Death Mark
	},
	SHAMAN = {
		{ { 8050, 8052, 8053, 10447, 10448, 29228 }, nil, "once" }, -- Flame Shock
		{ { 17364 }, nil, "highlight" }, -- Stormstrike
	},
	WARLOCK = {
		{ { 172, 6222, 6223, 7648, 11671, 11672, 25311 }, nil, "once" }, -- Corruption
		{ { 980, 1014, 6217, 11711, 11712, 11713 }, nil, "once" }, -- Bane of Agony
		{ { 348, 707, 1094, 2941, 11665, 11667, 11668, 25309 }, nil, "once" }, -- Immolate
		{ { 18265, 18879, 18880, 18881 }, nil, nil }, -- Siphon Life
		{ { 603 }, nil, "highlight" }, -- Bane of Doom
		{ { 1316697 }, nil, nil }, -- Wrack
	},
	WARRIOR = {
		{ { 772, 6546, 6547, 6548, 11572, 11573, 11574 }, nil, "once" }, -- Rend
		{ { 12294, 21551, 21552, 21553 }, nil, "highlight" }, -- Mortal Strike
	},
}

local FOREVER_GROUP = {
	{ { 7386, 7405, 8380, 11596, 11597 }, "WARRIOR" }, -- Sunder Armor
	{ { 1160, 6190, 11554, 11555, 11556 }, "WARRIOR" }, -- Demoralizing Shout
	{ { 770, 778, 9749, 9907 }, "DRUID" }, -- Faerie Fire
	{ { 8647, 8649, 8650, 11197, 11198 }, "ROGUE" }, -- Expose Armor
	{ { 704, 7658, 7659, 11717 }, "WARLOCK" }, -- Curse of Recklessness
	{ { 440892, 1311676, 1311677, 1311680 }, "WARLOCK" }, -- Curse of the Elements
	{ { 22959 }, "MAGE" }, -- Fire Vulnerability
	{ { 12579 }, "MAGE" }, -- Winter's Chill
	{ { 17794 }, "WARLOCK" }, -- Shadow Vulnerability
	{ { 20186, 20354, 20355 }, "PALADIN" }, -- Judgement of Wisdom
	{ { 20185, 20344, 20345, 20346 }, "PALADIN" }, -- Judgement of Light
	{ { 20188, 20300, 20301, 20302, 20303 }, "PALADIN" }, -- Judgement of the Crusader
	{ { 15258 }, "PRIEST" }, -- Shadow Weaving
	{ { 1130, 14323, 14324, 14325 }, "HUNTER" }, -- Hunter's Mark
}

local IsForeverClient = function()
	return ns.IsForever or ns.IsRetailContent == false
end

-- Whether the player has a spell. 0 (every player of the spec has it) always counts.
local IsKnown = function(spellID)
	if (not spellID or spellID == 0) then return true end
	local spellBook = C_SpellBook
	if (spellBook and spellBook.IsSpellKnown and spellBook.IsSpellKnown(spellID)) then return true end
	if (spellBook and spellBook.IsSpellKnownOrInSpellBook and spellBook.IsSpellKnownOrInSpellBook(spellID)) then return true end
	return type(IsPlayerSpell) == "function" and IsPlayerSpell(spellID) and true or false
end
AuraSuggestions.IsKnown = IsKnown

-- The player's specialization ID, or nil (always nil on Forever).
AuraSuggestions.GetSpecID = function()
	if (IsForeverClient()) then return nil end
	if (type(GetSpecialization) ~= "function" or type(GetSpecializationInfo) ~= "function") then return nil end
	local index = GetSpecialization()
	if (not index) then return nil end
	local specID = GetSpecializationInfo(index)
	return (type(specID) == "number" and specID > 0) and specID or nil
end

local GetPlayerClass = function()
	if (type(UnitClass) ~= "function") then return nil end
	-- Not `UnitClass and UnitClass(...)`: `and` keeps only the first return, the localized name.
	local _, class = UnitClass("player")
	return type(class) == "string" and class or nil
end

-- One Forever row as an entry: the ID shown is the highest rank the player knows when it is their class
-- (one rank at a time is all anyone casts), else the highest; `ids` holds every rank, so a box finds any.
local ForeverEntry = function(row, class, own)
	local ranks, grants = row[1], row[2]
	local known, shown = false, ranks[#ranks]
	if (own) then
		for index = #ranks, 1, -1 do
			if (IsKnown(ranks[index])) then
				known, shown = true, ranks[index]
				break
			end
		end
		if (grants) then
			known = false
			for _, grant in ipairs(grants) do
				if (IsKnown(grant)) then known = true break end
			end
		end
	end
	return { id = shown, ids = ranks, recommend = row[3], class = class, known = known }
end

local RetailEntry = function(row, class, specID)
	return { id = row[1], ids = { row[1] }, grant = row[2], recommend = row[3], class = class, specID = specID,
		known = IsKnown(row[2]) }
end

-- Talented (or learned) first, each half in the table's order.
local SortKnown = function(entries)
	local known, unknown = {}, {}
	for _, entry in ipairs(entries) do
		if (entry.known) then known[#known + 1] = entry else unknown[#unknown + 1] = entry end
	end
	for _, entry in ipairs(unknown) do known[#known + 1] = entry end
	return known
end

-- One Retail specialization's suggestions: { id, ids, grant, recommend, known, class, specID }.
AuraSuggestions.GetForSpec = function(self, specID)
	local spec = (not IsForeverClient()) and specID and RETAIL[specID]
	local out = {}
	if (spec) then
		for _, row in ipairs(spec) do out[#out + 1] = RetailEntry(row, spec.class, specID) end
	end
	return SortKnown(out)
end

-- One Forever class's suggestions, the player's own when `own`.
AuraSuggestions.GetForClass = function(self, class, own)
	local list = IsForeverClient() and class and FOREVER[class]
	local out = {}
	if (list) then
		for _, row in ipairs(list) do out[#out + 1] = ForeverEntry(row, class, own) end
	end
	return SortKnown(out)
end

-- The player's own suggestions on this client: their specialization's, or on Forever their class's.
AuraSuggestions.GetOwn = function(self)
	if (IsForeverClient()) then return self:GetForClass(GetPlayerClass(), true) end
	return self:GetForSpec(self.GetSpecID())
end

AuraSuggestions.GetGroup = function(self)
	local out = {}
	if (IsForeverClient()) then
		for _, row in ipairs(FOREVER_GROUP) do
			out[#out + 1] = { id = row[1][#row[1]], ids = row[1], class = row[2] }
		end
	else
		for _, row in ipairs(GROUP) do out[#out + 1] = { id = row[1], ids = { row[1] }, class = row[2] } end
	end
	return out
end

-- Every class's suggestions, for "All classes": once per aura and class (per specialization on Retail).
AuraSuggestions.GetAll = function(self)
	local out, seen = {}, {}
	if (IsForeverClient()) then
		for class, list in next, FOREVER do
			for _, row in ipairs(list) do out[#out + 1] = ForeverEntry(row, class, false) end
		end
		return out
	end
	for specID, spec in next, RETAIL do
		for _, row in ipairs(spec) do
			local key = spec.class .. ":" .. row[1]
			if (not seen[key]) then
				seen[key] = true
				out[#out + 1] = RetailEntry(row, spec.class, specID)
			end
		end
	end
	return out
end

-- The class tokens this client's table covers, sorted.
AuraSuggestions.GetClasses = function(self)
	local list, seen = {}, {}
	if (IsForeverClient()) then
		for class in next, FOREVER do list[#list + 1] = class end
	else
		for _, spec in next, RETAIL do
			if (not seen[spec.class]) then
				seen[spec.class] = true
				list[#list + 1] = spec.class
			end
		end
	end
	table_sort(list)
	return list
end

-- The recommended picks the player has: highlight IDs, once IDs. A Retail specialization ID can be given;
-- without one, the player's own.
AuraSuggestions.GetRecommended = function(self, specID)
	local highlight, once = {}, {}
	local entries = specID and self:GetForSpec(specID) or self:GetOwn()
	for _, entry in ipairs(entries) do
		if (entry.known and entry.recommend == "highlight") then
			highlight[#highlight + 1] = entry.id
		elseif (entry.known and entry.recommend == "once") then
			once[#once + 1] = entry.id
		end
	end
	return highlight, once
end

-- For tooling.
AuraSuggestions.Retail = RETAIL
AuraSuggestions.Group = GROUP
AuraSuggestions.Forever = FOREVER
AuraSuggestions.ForeverGroup = FOREVER_GROUP

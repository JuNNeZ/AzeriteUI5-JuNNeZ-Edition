--[[

	The MIT License (MIT)

	Copyright (c) 2026 Lars Norberg

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
local Debugging = ns:NewModule("Debugging", "LibMoreEvents-1.0", "AceConsole-3.0")

-- GLOBALS: EnableAddOn, GetAddOnInfo

-- Lua API
local ipairs = ipairs
local next = next
local pairs = pairs
local print = print
local select = select
local tostring = tostring
local type = type
local math_abs = math.abs
local math_ceil = math.ceil
local math_max = math.max
local math_min = math.min
local string_format = string.format
local string_lower = string.lower
local string_match = string.match
local table_concat = table.concat
local table_insert = table.insert
local table_sort = table.sort
local unpack = unpack
local PrintPlayerOrbDebug
local UpdateTestMenu
local GetRuntimeTestModule
local ApplyRuntimeTestPresentation

local function IsDevMode()
	return (ns and (ns.IsDevelopment or (ns.db and ns.db.global and ns.db.global.enableDevelopmentMode)))
end

local function CanUseRuntimeTestMode()
	return ns and ns.PlayerName == "Junnez"
end

local RUNTIME_TEST_DEFS = {
	{ key = "player", label = "Player Frame", style = "Player", module = "PlayerFrame", count = 1, layout = "single", unit = "player" },
	{ key = "playeralt", label = "Player Alternate", style = "PlayerAlternate", module = "PlayerFrameAlternate", count = 1, layout = "single", unit = "player" },
	{ key = "castbar", label = "Player Castbar", style = "PlayerCastBar", module = "PlayerCastBarFrame", count = 1, layout = "single", unit = "player" },
	{ key = "classpower", label = "Class Power", style = "PlayerClassPower", module = "PlayerClassPowerFrame", count = 1, layout = "single", unit = "player" },
	{ key = "pet", label = "Pet Frame", style = "Pet", module = "PetFrame", count = 1, layout = "single", unit = "player" },
	{ key = "target", label = "Target Frame", style = "Target", module = "TargetFrame", count = 1, layout = "single", unit = "player" },
	{ key = "tot", label = "Target of Target", style = "ToT", module = "ToTFrame", count = 1, layout = "single", unit = "player" },
	{ key = "focus", label = "Focus Frame", style = "Focus", module = "FocusFrame", count = 1, layout = "single", unit = "player" },
	{ key = "boss", label = "Boss Frames", style = "Boss", module = "BossFrames", count = 5, layout = "boss", unit = "player", prefix = "Boss" },
	{ key = "party", label = "Party Frames", style = "Party", module = "PartyFrames", count = 5, layout = "group", unit = "player", prefix = "Party" },
	{ key = "raid5", label = "Raid Frames (5)", style = "Raid5", module = "RaidFrame5", count = 5, layout = "group", unit = "player", prefix = "Raid" },
	{ key = "raid25", label = "Raid Frames (25)", style = "Raid25", module = "RaidFrame25", count = 25, layout = "group", unit = "player", prefix = "Raid", headerPreview = true },
	{ key = "raid40", label = "Raid Frames (40)", style = "Raid40", module = "RaidFrame40", count = 40, layout = "group", unit = "player", prefix = "Raid", headerPreview = true },
	{ key = "arena", label = "Arena Frames", style = "Arena", module = "ArenaFrames", count = 5, layout = "group", unit = "player", prefix = "Arena" },
	{ key = "nameplates", label = "Nameplate Preview", style = "NamePlates", module = "NamePlates", count = 10, layout = "nameplates", unit = "player", prefix = "Nameplate" }
}

local RUNTIME_TEST_PRESETS = {
	{ key = "party5", label = "Party 5", sets = { party = true }, counts = { party = 5 } },
	{ key = "raid10", label = "Raid 10", sets = { raid25 = true }, counts = { raid25 = 10 } },
	{ key = "raid20", label = "Raid 20", sets = { raid25 = true }, counts = { raid25 = 20 } },
	{ key = "raid25", label = "Raid 25", sets = { raid25 = true }, counts = { raid25 = 25 } },
	{ key = "raid40", label = "Raid 40", sets = { raid40 = true }, counts = { raid40 = 40 } },
	{ key = "arena3", label = "Arena 3", sets = { arena = true }, counts = { arena = 3 } },
	{ key = "arena5", label = "Arena 5", sets = { arena = true }, counts = { arena = 5 } },
	{ key = "boss5", label = "Boss 1-5", sets = { boss = true }, counts = { boss = 5 } }
}

local RUNTIME_TEST_CLASS_DISTRIBUTIONS = {
	{ key = "mixed", label = "Mixed" },
	{ key = "healers", label = "All Healers" },
	{ key = "melee", label = "Melee Heavy" },
	{ key = "duplicates", label = "Duplicate Classes" }
}

local RUNTIME_TEST_HEALTH_SCENARIOS = {
	{ key = "full", label = "Full Health" },
	{ key = "mixed", label = "Mixed Damage" },
	{ key = "critical", label = "Critical" },
	{ key = "offline", label = "Offline" },
	{ key = "dead", label = "Dead / Ghost" },
	{ key = "outofrange", label = "Out of Range" },
	{ key = "aggro", label = "Aggro" }
}

local RUNTIME_TEST_AURA_SCENARIOS = {
	{ key = "none", label = "None" },
	{ key = "dispel", label = "Dispellable Debuffs" },
	{ key = "boss", label = "Boss Debuffs" },
	{ key = "mixed", label = "Mixed Debuffs" },
	{ key = "externals", label = "Helpful Externals" },
	{ key = "buffs", label = "Short Buffs" },
	{ key = "priority", label = "Priority Debuff" }
}

local RUNTIME_TEST_CAST_SCENARIOS = {
	{ key = "none", label = "None" },
	{ key = "enemycast", label = "Enemy Cast" },
	{ key = "enemychannel", label = "Enemy Channel" },
	{ key = "interruptible", label = "Interruptible" },
	{ key = "uninterruptible", label = "Uninterruptible" },
	{ key = "playercast", label = "Player Cast" },
	{ key = "bosscast", label = "Boss Cast" }
}

local RUNTIME_TEST_MOUSEOVER_MODES = {
	{ key = "none", label = "None" },
	{ key = "first", label = "First Frame" },
	{ key = "all", label = "All Frames" }
}

local RUNTIME_TEST_NAMEPLATE_PACKS = {
	{ key = "one", label = "1" },
	{ key = "five", label = "5" },
	{ key = "ten", label = "10" }
}

local RUNTIME_TEST_NAMEPLATE_VARIANTS = {
	{ key = "enemy", label = "Enemy" },
	{ key = "friendly", label = "Friendly" },
	{ key = "mixed", label = "Mixed" }
}

local function GetRuntimeTestDefinition(key)
	for _, def in ipairs(RUNTIME_TEST_DEFS) do
		if (def.key == key) then
			return def
		end
	end
end

local function FindRuntimeTestOption(options, key)
	for index, option in ipairs(options) do
		if (option.key == key) then
			return option, index
		end
	end
	return options[1], 1
end

local function GetRuntimeTestOptionLabel(options, key)
	local option = FindRuntimeTestOption(options, key)
	return option and option.label or "Unknown"
end

local function CycleRuntimeTestOption(options, key, step)
	local _, index = FindRuntimeTestOption(options, key)
	local count = #options
	index = index + (step or 1)
	if (index > count) then
		index = 1
	elseif (index < 1) then
		index = count
	end
	return options[index].key
end

local function EnsureRuntimeTestState()
	if (not ns or not ns.db or not ns.db.global) then
		return nil
	end
	local globalDB = ns.db.global
	globalDB.runtimeUnitTestMode = globalDB.runtimeUnitTestMode and true or false
	globalDB.runtimeUnitTestMenuEnabled = globalDB.runtimeUnitTestMenuEnabled and true or false
	if (type(globalDB.runtimeUnitTestSets) ~= "table") then
		globalDB.runtimeUnitTestSets = {}
	end
	if (type(globalDB.runtimeUnitTestCounts) ~= "table") then
		globalDB.runtimeUnitTestCounts = {}
	end
	for _, def in ipairs(RUNTIME_TEST_DEFS) do
		if (globalDB.runtimeUnitTestSets[def.key] == nil) then
			globalDB.runtimeUnitTestSets[def.key] = false
		end
		if (type(globalDB.runtimeUnitTestCounts[def.key]) ~= "number") then
			globalDB.runtimeUnitTestCounts[def.key] = def.count
		end
	end
	globalDB.runtimeUnitTestPreset = globalDB.runtimeUnitTestPreset or RUNTIME_TEST_PRESETS[1].key
	globalDB.runtimeUnitTestClassDistribution = globalDB.runtimeUnitTestClassDistribution or RUNTIME_TEST_CLASS_DISTRIBUTIONS[1].key
	globalDB.runtimeUnitTestHealthScenario = globalDB.runtimeUnitTestHealthScenario or RUNTIME_TEST_HEALTH_SCENARIOS[2].key
	globalDB.runtimeUnitTestAuraScenario = globalDB.runtimeUnitTestAuraScenario or RUNTIME_TEST_AURA_SCENARIOS[1].key
	globalDB.runtimeUnitTestCastScenario = globalDB.runtimeUnitTestCastScenario or RUNTIME_TEST_CAST_SCENARIOS[1].key
	globalDB.runtimeUnitTestMouseoverMode = globalDB.runtimeUnitTestMouseoverMode or RUNTIME_TEST_MOUSEOVER_MODES[1].key
	globalDB.runtimeUnitTestNameplatePack = globalDB.runtimeUnitTestNameplatePack or RUNTIME_TEST_NAMEPLATE_PACKS[1].key
	globalDB.runtimeUnitTestNameplateVariant = globalDB.runtimeUnitTestNameplateVariant or RUNTIME_TEST_NAMEPLATE_VARIANTS[1].key
	globalDB.runtimeUnitTestDebugOverlay = globalDB.runtimeUnitTestDebugOverlay ~= false
	globalDB.runtimeUnitTestShowOnlyOne = globalDB.runtimeUnitTestShowOnlyOne and true or false
	globalDB.runtimeUnitTestHidePrimary = globalDB.runtimeUnitTestHidePrimary and true or false
	globalDB.runtimeUnitTestCompactSpacing = globalDB.runtimeUnitTestCompactSpacing and true or false
	globalDB.runtimeUnitTestLargeSpacing = globalDB.runtimeUnitTestLargeSpacing and true or false
	globalDB.runtimeUnitTestMaxVisible = globalDB.runtimeUnitTestMaxVisible and true or false
	return globalDB
end

local function IsRuntimeTestMode()
	local globalDB = EnsureRuntimeTestState()
	return globalDB and globalDB.runtimeUnitTestMenuEnabled and true or false
end

local function IsRuntimeTestSetEnabled(key)
	local globalDB = EnsureRuntimeTestState()
	return globalDB and globalDB.runtimeUnitTestSets and globalDB.runtimeUnitTestSets[key] and true or false
end

local function HasEnabledRuntimeTestSets()
	for _, def in ipairs(RUNTIME_TEST_DEFS) do
		if (IsRuntimeTestSetEnabled(def.key)) then
			return true
		end
	end
	return false
end

local function SetRuntimeTestSetEnabled(key, enabled)
	local globalDB = EnsureRuntimeTestState()
	if (globalDB and globalDB.runtimeUnitTestSets and GetRuntimeTestDefinition(key)) then
		globalDB.runtimeUnitTestSets[key] = enabled and true or false
	end
end

local function SetAllRuntimeTestSets(enabled)
	for _, def in ipairs(RUNTIME_TEST_DEFS) do
		SetRuntimeTestSetEnabled(def.key, enabled)
	end
end

local function GetRuntimeTestStateValue(key)
	local globalDB = EnsureRuntimeTestState()
	return globalDB and globalDB[key]
end

local function SetRuntimeTestStateValue(key, value)
	local globalDB = EnsureRuntimeTestState()
	if (globalDB) then
		globalDB[key] = value
	end
end

local function GetRuntimeTestFrameCount(def)
	local globalDB = EnsureRuntimeTestState()
	if (not globalDB) then
		return def.count
	end

	local count = globalDB.runtimeUnitTestCounts[def.key] or def.count
	if (def.key == "nameplates") then
		local pack = globalDB.runtimeUnitTestNameplatePack
		if (pack == "five") then
			count = 5
		elseif (pack == "ten") then
			count = 10
		else
			count = 1
		end
	end

	if (globalDB.runtimeUnitTestMaxVisible) then
		count = def.count
	end
	if (globalDB.runtimeUnitTestShowOnlyOne and def.count > 1) then
		count = 1
	end

	return math_max(1, math_min(def.count, count))
end

local function GetRuntimeTestStartIndex(def)
	local globalDB = EnsureRuntimeTestState()
	if (not globalDB or not globalDB.runtimeUnitTestHidePrimary) then
		return 1
	end
	if (globalDB.runtimeUnitTestShowOnlyOne) then
		return 1
	end
	if (def.count > 1) then
		return 2
	end
	return 1
end

local function ApplyRuntimeTestPreset()
	local globalDB = EnsureRuntimeTestState()
	if (not globalDB) then
		return
	end

	for _, def in ipairs(RUNTIME_TEST_DEFS) do
		globalDB.runtimeUnitTestSets[def.key] = false
		globalDB.runtimeUnitTestCounts[def.key] = def.count
	end

	local preset = FindRuntimeTestOption(RUNTIME_TEST_PRESETS, globalDB.runtimeUnitTestPreset)
	if (preset and preset.sets) then
		for key, enabled in pairs(preset.sets) do
			globalDB.runtimeUnitTestSets[key] = enabled and true or false
		end
	end
	if (preset and preset.counts) then
		for key, count in pairs(preset.counts) do
			globalDB.runtimeUnitTestCounts[key] = count
		end
	end
end

local function SetRuntimeTestMode(enabled)
	local globalDB = EnsureRuntimeTestState()
	if (not globalDB) then
		return
	end
	if (enabled and not CanUseRuntimeTestMode()) then
		enabled = false
	end
	globalDB.runtimeUnitTestMenuEnabled = enabled and true or false
	-- Keep the older raid5/arena-only test hook dormant.
	globalDB.runtimeUnitTestMode = false
	if (enabled and not HasEnabledRuntimeTestSets()) then
		ApplyRuntimeTestPreset()
	end
	if (not enabled) then
		globalDB.runtimeUnitTestMenuEnabled = false
	end
	if (Debugging and Debugging.RefreshRuntimeTestPreviews) then
		Debugging:RefreshRuntimeTestPreviews()
	end
end

local function GetRelativePointAnchor(point)
	point = type(point) == "string" and point:upper() or "TOP"
	if (point == "TOP") then
		return "BOTTOM", 0, -1
	elseif (point == "BOTTOM") then
		return "TOP", 0, 1
	elseif (point == "LEFT") then
		return "RIGHT", 1, 0
	elseif (point == "RIGHT") then
		return "LEFT", -1, 0
	elseif (point == "TOPLEFT") then
		return "BOTTOMRIGHT", 1, -1
	elseif (point == "TOPRIGHT") then
		return "BOTTOMLEFT", -1, -1
	elseif (point == "BOTTOMLEFT") then
		return "TOPRIGHT", 1, 1
	elseif (point == "BOTTOMRIGHT") then
		return "TOPLEFT", -1, 1
	end
	return "BOTTOM", 0, -1
end

local function GetPreviewLabel(def, index)
	if (def.count == 1) then
		return def.label
	end
	return string_format("%s %d", def.prefix or def.label, index)
end

local function GetRuntimeTestMetadata(index)
	local distribution = GetRuntimeTestStateValue("runtimeUnitTestClassDistribution")
	local mixedClasses = { "WARRIOR", "PRIEST", "MAGE", "DRUID", "PALADIN", "ROGUE", "HUNTER", "SHAMAN", "WARLOCK", "MONK", "DEATHKNIGHT", "DEMONHUNTER", "EVOKER" }
	local healerClasses = { "PRIEST", "DRUID", "PALADIN", "SHAMAN", "MONK", "EVOKER" }
	local meleeClasses = { "WARRIOR", "PALADIN", "ROGUE", "DEATHKNIGHT", "DEMONHUNTER", "MONK", "SHAMAN" }
	local duplicateClass = { "MAGE" }
	local role = "DAMAGER"
	local classToken = "MAGE"

	if (distribution == "healers") then
		classToken = healerClasses[((index - 1) % #healerClasses) + 1]
		role = "HEALER"
	elseif (distribution == "melee") then
		classToken = meleeClasses[((index - 1) % #meleeClasses) + 1]
		role = (index == 1) and "TANK" or "DAMAGER"
	elseif (distribution == "duplicates") then
		classToken = duplicateClass[1]
		role = "DAMAGER"
	else
		classToken = mixedClasses[((index - 1) % #mixedClasses) + 1]
		local roleCycle = { "TANK", "HEALER", "DAMAGER" }
		role = roleCycle[((index - 1) % #roleCycle) + 1]
	end

	return classToken, role
end

local function GetRuntimeTestHealthState(index)
	local scenario = GetRuntimeTestStateValue("runtimeUnitTestHealthScenario")
	if (scenario == "full") then
		return 100, "Ready", 1
	elseif (scenario == "critical") then
		return 12 + ((index - 1) % 3) * 4, "Critical", 1
	elseif (scenario == "offline") then
		return 0, "Offline", .4
	elseif (scenario == "dead") then
		return 0, "Dead", .55
	elseif (scenario == "outofrange") then
		return 74, "Out of Range", .45
	elseif (scenario == "aggro") then
		return 68, "Aggro", 1
	end

	local values = { 100, 83, 67, 49, 31, 17 }
	local value = values[((index - 1) % #values) + 1]
	local label = (value <= 25 and "Danger") or (value <= 50 and "Wounded") or "Stable"
	return value, label, 1
end

local function IsRuntimeTestMouseoverActive(index)
	local mode = GetRuntimeTestStateValue("runtimeUnitTestMouseoverMode")
	return mode == "all" or (mode == "first" and index == 1)
end

local function GetRuntimeTestAuraData()
	local scenario = GetRuntimeTestStateValue("runtimeUnitTestAuraScenario")
	if (scenario == "dispel") then
		return {
			{ texture = "Interface\\Icons\\Spell_Holy_DispelMagic", color = { .2, .6, 1 }, label = "Magic" },
			{ texture = "Interface\\Icons\\Spell_Nature_RemoveCurse", color = { .6, .2, 1 }, label = "Curse" },
			{ texture = "Interface\\Icons\\Spell_Nature_NullifyPoison", color = { .2, 1, .2 }, label = "Poison" }
		}
	elseif (scenario == "boss") then
		return {
			{ texture = "Interface\\Icons\\Ability_Creature_Cursed_02", color = { 1, .2, .2 }, label = "Boss" },
			{ texture = "Interface\\Icons\\Ability_Druid_InfectedWounds", color = { 1, .6, .1 }, label = "Major" }
		}
	elseif (scenario == "mixed") then
		return {
			{ texture = "Interface\\Icons\\Ability_Creature_Poison_05", color = { .2, 1, .2 }, label = "Poison" },
			{ texture = "Interface\\Icons\\Spell_Shadow_CurseOfTounges", color = { .6, .2, 1 }, label = "Curse" },
			{ texture = "Interface\\Icons\\Spell_Shadow_AbominationExplosion", color = { .8, .8, .2 }, label = "Disease" }
		}
	elseif (scenario == "externals") then
		return {
			{ texture = "Interface\\Icons\\Spell_Holy_GuardianSpirit", color = { 1, 1, 1 }, label = "GS" },
			{ texture = "Interface\\Icons\\INV_Ability_Paladin_BlessedHands", color = { 1, .8, .2 }, label = "BoP" }
		}
	elseif (scenario == "buffs") then
		return {
			{ texture = "Interface\\Icons\\Spell_Holy_PowerWordShield", color = { .4, .8, 1 }, label = "Shield" },
			{ texture = "Interface\\Icons\\Spell_Nature_Rejuvenation", color = { .3, 1, .3 }, label = "HoT" },
			{ texture = "Interface\\Icons\\Spell_Holy_SealOfSacrifice", color = { 1, .9, .3 }, label = "DR" }
		}
	elseif (scenario == "priority") then
		return {
			{ texture = "Interface\\Icons\\Ability_Creature_Disease_02", color = { 1, .15, .15 }, label = "Priority" }
		}
	end
	return {}
end

local function GetRuntimeTestCastData(index)
	local scenario = GetRuntimeTestStateValue("runtimeUnitTestCastScenario")
	if (scenario == "none") then
		return nil
	elseif (scenario == "enemychannel") then
		return { label = "Enemy Channel", texture = "Interface\\Icons\\Spell_Shadow_MindFlay", progress = 28 + (index * 9), reverse = true, color = { .45, .65, 1 } }
	elseif (scenario == "interruptible" or scenario == "interrupt") then
		return { label = "Interruptible", texture = "Interface\\Icons\\Spell_Frost_FrostBolt02", progress = 62, reverse = false, color = { 1, .75, .2 }, notInterruptible = false }
	elseif (scenario == "uninterruptible") then
		return { label = "Uninterruptible", texture = "Interface\\Icons\\Spell_Shadow_ShadowBolt", progress = 62, reverse = false, color = { 1, .35, .35 }, notInterruptible = true }
	elseif (scenario == "playercast") then
		return { label = "Player Cast", texture = "Interface\\Icons\\Spell_Arcane_Arcane01", progress = 54, reverse = false, color = { 1, .8, .2 } }
	elseif (scenario == "bosscast") then
		return { label = "Boss Ability", texture = "Interface\\Icons\\Ability_BossMagmaw_MoltenTantrum", progress = 74, reverse = false, color = { 1, .25, .25 } }
	end
	return { label = "Enemy Cast", texture = "Interface\\Icons\\Spell_Fire_Fireball02", progress = 48 + (index * 7), reverse = false, color = { 1, .55, .2 } }
end

local function ResolveRuntimeTestColor(color, fallbackR, fallbackG, fallbackB)
	if (type(color) == "table") then
		if (color.r and color.g and color.b) then
			return color.r, color.g, color.b
		end
		return color[1] or fallbackR, color[2] or fallbackG, color[3] or fallbackB
	end
	return fallbackR, fallbackG, fallbackB
end

local function GetRuntimeTestModuleProfile(def)
	local module = GetRuntimeTestModule(def)
	return module and module.db and module.db.profile
end

local function GetRuntimeTestClassColor(def, classToken)
	local profile = GetRuntimeTestModuleProfile(def)
	local useBlizzardColors = profile and profile.useBlizzardHealthColors
	if (useBlizzardColors) then
		local blizzClass = (ns.oUF and ns.oUF.colors and ns.oUF.colors.class and ns.oUF.colors.class[classToken]) or (ns.Colors and ns.Colors.blizzclass and ns.Colors.blizzclass[classToken])
		return ResolveRuntimeTestColor(blizzClass, .9, .9, .9)
	end
	local classColor = ns.Colors and ns.Colors.class and ns.Colors.class[classToken]
	return ResolveRuntimeTestColor(classColor, .9, .9, .9)
end

local function GetRuntimeTestHealthColorMode(def, isMouseover)
	local profile = GetRuntimeTestModuleProfile(def)
	local useClassColors = true
	local mouseoverOnly = false
	if (profile and profile.useClassColors == false) then
		useClassColors = false
	end
	if (useClassColors and profile and profile.useClassColorOnMouseoverOnly) then
		mouseoverOnly = true
	end
	return useClassColors and ((not mouseoverOnly) or isMouseover), mouseoverOnly
end

local function ApplyRuntimeTestBarColor(statusBar, r, g, b)
	if (not statusBar) then
		return
	end
	if (statusBar.SetStatusBarColor) then
		statusBar:SetStatusBarColor(r, g, b, 1)
	end
	if (statusBar.GetStatusBarTexture) then
		local texture = statusBar:GetStatusBarTexture()
		if (texture and texture.SetVertexColor) then
			texture:SetVertexColor(r, g, b, 1)
		end
	end
end

local function ApplyRuntimeTestCastbar(castbar, castData)
	if (not castbar) then
		return false
	end
	if (not castData) then
		castbar:Hide()
		return true
	end

	local progress = math_max(0, math_min(100, castData.progress or 0))
	castbar:SetMinMaxValues(0, 100)
	if (castbar.SetReverseFill) then
		castbar:SetReverseFill(castData.reverse and true or false)
	end
	castbar.notInterruptible = castData.notInterruptible and true or false
	castbar:SetValue(progress)
	ApplyRuntimeTestBarColor(castbar, castData.color[1], castData.color[2], castData.color[3])

	if (castbar.Text and castbar.Text.SetText) then
		castbar.Text:SetText(castData.label)
	end
	if (castbar.Time and castbar.Time.SetFormattedText) then
		castbar.Time:SetFormattedText("%.1f", math_max(0, (100 - progress) / 20))
	end
	if (castbar.Delay and castbar.Delay.SetText) then
		castbar.Delay:SetText("")
	end
	if (castbar.SafeZone) then
		castbar.SafeZone:Hide()
	end
	if (castbar.Shield and castbar.Shield.SetShown) then
		castbar.Shield:SetShown(castData.notInterruptible and true or false)
	end

	castbar:Show()
	return true
end

local function GetRuntimeTestNameplateVariant(index)
	local variant = GetRuntimeTestStateValue("runtimeUnitTestNameplateVariant")
	if (variant == "friendly") then
		return "Friendly"
	elseif (variant == "mixed") then
		return (index % 2 == 0) and "Friendly" or "Enemy"
	end
	return "Enemy"
end

local function EnsureRuntimeTestWidgets(frame)
	if (frame.__AzeriteUI_RuntimeTestWidgets) then
		return frame.__AzeriteUI_RuntimeTestWidgets
	end

	local widgets = {}
	local overlay = CreateFrame("Frame", nil, frame)
	overlay:SetAllPoints()
	overlay:SetFrameLevel(frame:GetFrameLevel() + 30)
	widgets.overlay = overlay

	local backdrop = overlay:CreateTexture(nil, "ARTWORK", nil, 1)
	backdrop:SetPoint("TOPLEFT", 2, -2)
	backdrop:SetSize(232, 30)
	backdrop:SetColorTexture(0, 0, 0, .55)
	widgets.backdrop = backdrop

	local label = overlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	label:SetPoint("TOPLEFT", 8, -6)
	label:SetWidth(220)
	label:SetJustifyH("LEFT")
	widgets.label = label

	local state = overlay:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	state:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -2)
	state:SetWidth(220)
	state:SetJustifyH("LEFT")
	widgets.state = state

	local auraFrame = CreateFrame("Frame", nil, overlay)
	auraFrame:SetPoint("TOPRIGHT", -4, -4)
	auraFrame:SetSize(60, 18)
	widgets.auraFrame = auraFrame
	widgets.auras = {}

	local castbar = CreateFrame("StatusBar", nil, overlay)
	castbar:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, -6)
	castbar:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", 0, -6)
	castbar:SetHeight(10)
	castbar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
	castbar:SetMinMaxValues(0, 100)
	castbar:SetFrameLevel(overlay:GetFrameLevel() + 1)
	local castBG = castbar:CreateTexture(nil, "BACKGROUND")
	castBG:SetAllPoints()
	castBG:SetColorTexture(.05, .05, .05, .8)
	local castText = overlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	castText:SetPoint("BOTTOMLEFT", castbar, "TOPLEFT", 0, 2)
	castText:SetJustifyH("LEFT")
	local castIcon = overlay:CreateTexture(nil, "ARTWORK")
	castIcon:SetPoint("RIGHT", castbar, "LEFT", -4, 0)
	castIcon:SetSize(14, 14)
	widgets.castbar = castbar
	widgets.castText = castText
	widgets.castIcon = castIcon

	local classPowerFrame = CreateFrame("Frame", nil, overlay)
	classPowerFrame:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, -24)
	classPowerFrame:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", 0, -24)
	classPowerFrame:SetHeight(10)
	widgets.classPowerFrame = classPowerFrame
	widgets.classPowerPoints = {}
	for pointIndex = 1,6 do
		local point = CreateFrame("StatusBar", nil, classPowerFrame)
		point:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
		point:SetMinMaxValues(0, 1)
		point:SetValue(1)
		point:SetHeight(10)
		point:SetWidth(18)
		if (pointIndex == 1) then
			point:SetPoint("LEFT", classPowerFrame, "LEFT", 0, 0)
		else
			point:SetPoint("LEFT", widgets.classPowerPoints[pointIndex - 1], "RIGHT", 4, 0)
		end
		local bg = point:CreateTexture(nil, "BACKGROUND")
		bg:SetAllPoints()
		bg:SetColorTexture(.05, .05, .05, .8)
		point.bg = bg
		widgets.classPowerPoints[pointIndex] = point
	end

	frame.__AzeriteUI_RuntimeTestWidgets = widgets
	return widgets
end

local function GetRuntimeTestFallbackSize(def)
	if (def.key == "castbar") then
		local config = ns.GetConfig and ns.GetConfig("PlayerCastBar")
		local size = config and config.CastBarSize
		return (size and size[1] or 128) + 16, (size and size[2] or 11) + 16
	elseif (def.key == "classpower") then
		local config = ns.GetConfig and ns.GetConfig("PlayerClassPower")
		local size = config and config.ClassPowerFrameSize
		return size and size[1] or 124, size and size[2] or 32
	elseif (def.key == "party") then
		local config = ns.GetConfig and ns.GetConfig("PartyFrames")
		local size = config and config.UnitSize
		return size and size[1] or 96, size and size[2] or 30
	elseif (def.key == "raid5" or def.key == "raid25" or def.key == "raid40") then
		local config = ns.GetConfig and ns.GetConfig("RaidFrames")
		local size = config and config.UnitSize
		return size and size[1] or 66, size and size[2] or 36
	elseif (def.key == "arena" or def.key == "boss") then
		return 112, 24
	end
	return 112, 24
end

local function CreateRuntimeTestFallbackFrame(def, parent)
	local width, height = GetRuntimeTestFallbackSize(def)
	local frame = CreateFrame("Button", nil, parent, "SecureActionButtonTemplate")
	frame:SetSize(width, height)
	frame:EnableMouse(true)
	if (ns.UnitFrame and ns.UnitFrame.InitializeUnitFrame) then
		ns.UnitFrame.InitializeUnitFrame(frame)
	end
	frame:RegisterForClicks("AnyUp")

	local health = CreateFrame("StatusBar", nil, frame)
	health:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
	health:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
	health:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
	health:SetMinMaxValues(0, 100)
	health:SetValue(100)
	local backdrop = health:CreateTexture(nil, "BACKGROUND")
	backdrop:SetAllPoints()
	backdrop:SetColorTexture(.08, .08, .08, .85)
	health.backdrop = backdrop
	frame.Health = health

	local name = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	name:SetPoint("CENTER", frame, "CENTER", 0, 0)
	name:SetJustifyH("CENTER")
	frame.Name = name

	return frame
end

local function SetupRuntimeTestInteraction(frame, def, index)
	if (not frame) then
		return
	end

	frame.__AzeriteUI_RuntimeTestDef = def
	frame.__AzeriteUI_RuntimeTestIndex = index
	if (frame.__AzeriteUI_RuntimeTestSavedUnit == nil) then
		frame.__AzeriteUI_RuntimeTestSavedUnit = frame.unit
	end
	frame.unit = frame.unit or "player"
	frame:EnableMouse(true)
	if (frame.RegisterForClicks) then
		frame:RegisterForClicks("AnyUp")
	end
	if (frame.SetAttribute) then
		if (frame.__AzeriteUI_RuntimeTestSavedUnitAttribute == nil and frame.GetAttribute) then
			frame.__AzeriteUI_RuntimeTestSavedUnitAttribute = frame:GetAttribute("unit")
		end
		if (frame.__AzeriteUI_RuntimeTestSavedType1Attribute == nil and frame.GetAttribute) then
			frame.__AzeriteUI_RuntimeTestSavedType1Attribute = frame:GetAttribute("*type1") or frame:GetAttribute("type1")
		end
		frame:SetAttribute("unit", frame.unit)
		frame:SetAttribute("*type1", "target")
	end

	-- Keep the synthetic menu state, but let real hover override it.
	if (not frame.__AzeriteUI_RuntimeTestInteractionHooked and frame.HookScript) then
		frame.__AzeriteUI_RuntimeTestInteractionHooked = true
		frame:HookScript("OnEnter", function(self)
			self.__AzeriteUI_RuntimeTestHovered = true
			if (IsRuntimeTestMode() and self.__AzeriteUI_RuntimeTestDef and self.__AzeriteUI_RuntimeTestIndex) then
				ApplyRuntimeTestPresentation(self, self.__AzeriteUI_RuntimeTestDef, self.__AzeriteUI_RuntimeTestIndex)
			end
		end)
		frame:HookScript("OnLeave", function(self)
			self.__AzeriteUI_RuntimeTestHovered = nil
			if (IsRuntimeTestMode() and self.__AzeriteUI_RuntimeTestDef and self.__AzeriteUI_RuntimeTestIndex) then
				ApplyRuntimeTestPresentation(self, self.__AzeriteUI_RuntimeTestDef, self.__AzeriteUI_RuntimeTestIndex)
			end
		end)
	end
end

ApplyRuntimeTestPresentation = function(frame, def, index)
	local classToken, role = GetRuntimeTestMetadata(index)
	local healthPct, stateLabel, alpha = GetRuntimeTestHealthState(index)
	local hovered = (frame and frame.__AzeriteUI_RuntimeTestHovered) and true or IsRuntimeTestMouseoverActive(index)
	local widgets = EnsureRuntimeTestWidgets(frame)
	local classR, classG, classB = GetRuntimeTestClassColor(def, classToken)
	local baseR, baseG, baseB = ResolveRuntimeTestColor(ns.Colors and ns.Colors.green, .1, .9, .1)
	local showClassColors = GetRuntimeTestHealthColorMode(def, hovered)
	local classLabel = (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[classToken]) or classToken
	local previewLabel = GetPreviewLabel(def, index)
	local auraScenarioLabel = GetRuntimeTestOptionLabel(RUNTIME_TEST_AURA_SCENARIOS, GetRuntimeTestStateValue("runtimeUnitTestAuraScenario"))

	if (def.key == "nameplates") then
		local variant = GetRuntimeTestNameplateVariant(index)
		previewLabel = string_format("%s %s", variant, previewLabel)
		if (not hovered) then
			if (variant == "Friendly") then
				baseR, baseG, baseB = .2, .85, .35
			else
				baseR, baseG, baseB = .9, .2, .15
			end
		end
	end

	frame:SetAlpha(alpha or 1)
	if (frame.Name and frame.Name.SetText) then
		frame.Name:SetText(previewLabel)
	end

	if (frame.Health and frame.Health.SetMinMaxValues and frame.Health.SetValue) then
		frame.Health:SetMinMaxValues(0, 100)
		frame.Health:SetValue(healthPct)
		frame.Health.colorClass = false
		frame.Health.colorClassPet = false
		frame.Health.colorReaction = false
		frame.Health.colorHealth = false
		if (showClassColors) then
			ApplyRuntimeTestBarColor(frame.Health, classR, classG, classB)
		else
			ApplyRuntimeTestBarColor(frame.Health, baseR, baseG, baseB)
		end
		if (frame.Health.Preview) then
			if (showClassColors) then
				ApplyRuntimeTestBarColor(frame.Health.Preview, classR * .7, classG * .7, classB * .7)
			else
				ApplyRuntimeTestBarColor(frame.Health.Preview, baseR * .7, baseG * .7, baseB * .7)
			end
		end
	end

	if (widgets) then
		local showOverlay = GetRuntimeTestStateValue("runtimeUnitTestDebugOverlay")
		widgets.overlay:Show()
		widgets.backdrop:SetShown(showOverlay)
		widgets.label:SetText(string_format("%s | %s | %s", previewLabel, role, classLabel))
		widgets.state:SetText(string_format("%s %d%% | %s", stateLabel, healthPct, auraScenarioLabel))
		widgets.label:SetTextColor(classR, classG, classB)
		widgets.label:SetShown(showOverlay)
		widgets.state:SetShown(showOverlay)

		local auraData = GetRuntimeTestAuraData()
		for iconIndex = 1,3 do
			local icon = widgets.auras[iconIndex]
			if (not icon) then
				icon = widgets.auraFrame:CreateTexture(nil, "ARTWORK")
				icon:SetSize(16, 16)
				icon:SetPoint("RIGHT", widgets.auraFrame, "RIGHT", -((iconIndex - 1) * 18), 0)
				widgets.auras[iconIndex] = icon
			end
			local aura = auraData[iconIndex]
			if (aura) then
				icon:SetTexture(aura.texture)
				icon:SetVertexColor(aura.color[1], aura.color[2], aura.color[3], 1)
				icon:Show()
			else
				icon:Hide()
			end
		end
		widgets.auraFrame:SetShown(#auraData > 0)

		local castData = GetRuntimeTestCastData(index)
		local usedNativeCastbar = ApplyRuntimeTestCastbar(frame.Castbar, castData)
		if (castData and not usedNativeCastbar) then
			local progress = math_max(0, math_min(100, castData.progress or 0))
			widgets.castbar:SetMinMaxValues(0, 100)
			if (widgets.castbar.SetReverseFill) then
				widgets.castbar:SetReverseFill(castData.reverse and true or false)
			end
			widgets.castbar:SetValue(progress)
			ApplyRuntimeTestBarColor(widgets.castbar, castData.color[1], castData.color[2], castData.color[3])
			widgets.castText:SetText(castData.label)
			widgets.castIcon:SetTexture(castData.texture)
			widgets.castbar:Show()
			widgets.castText:Show()
			widgets.castIcon:Show()
		else
			widgets.castbar:Hide()
			widgets.castText:Hide()
			widgets.castIcon:Hide()
		end

		local showClassPower = (def.key == "classpower")
		widgets.classPowerFrame:SetShown(showClassPower)
		if (showClassPower) then
			local activePoints = ((index - 1) % 5) + 1
			for pointIndex, point in ipairs(widgets.classPowerPoints) do
				point:SetShown(pointIndex <= 6)
				if (pointIndex <= activePoints) then
					point:SetValue(1)
					ApplyRuntimeTestBarColor(point, classR, classG, classB)
				else
					point:SetValue(.25)
					ApplyRuntimeTestBarColor(point, .18, .18, .18)
				end
			end
		end
	end
end

local function RefreshTargetDebugTestFrames()
	local targetMod = ns and ns.GetModule and ns:GetModule("TargetFrame", true)
	local frame = targetMod and targetMod.frame
	if (not frame) then
		return
	end
	frame.__AzeriteUI_HealthLabSignature = nil
	frame.__AzeriteUI_TargetGUID = nil
	if (frame.PostUpdate) then
		frame:PostUpdate()
	end
	if (frame.Health and frame.Health.ForceUpdate) then
		frame.Health:ForceUpdate()
	end
	if (frame.Castbar and frame.Castbar.ForceUpdate and frame.IsElementEnabled and frame:IsElementEnabled("Castbar")) then
		frame.Castbar:ForceUpdate()
	end
end

GetRuntimeTestModule = function(def)
	return ns and ns.GetModule and ns:GetModule(def.module, true)
end

local function GetRuntimeTestAnchor(def)
	local module = GetRuntimeTestModule(def)
	if (module and module.IsEnabled and module:IsEnabled() and module.frame) then
		return module.frame
	end
	return UIParent
end

local function TryPrepareRuntimeTestModule(def, module)
	if (not module) then
		return false
	end
	if (module.frame) then
		return true
	end
	if (type(module.CreateUnitFrames) ~= "function") then
		return false
	end

	local ok = pcall(module.CreateUnitFrames, module)
	if (not ok) then
		return false
	end

	if (module.frame and module.frame.Hide and module.IsEnabled and not module:IsEnabled()) then
		module.frame:Hide()
	end

	return module.frame and true or false
end

local function ForcePreviewFrameUpdate(frame, label)
	if (not frame) then
		return
	end
	frame:Show()
	frame:SetAlpha(1)
	if (frame.Enable) then
		pcall(frame.Enable, frame)
	end
	if (frame.Update) then
		pcall(frame.Update, frame)
	end
	if (frame.UpdateAllElements) then
		pcall(frame.UpdateAllElements, frame, "RuntimeTest")
	end
	if (frame.PostUpdate) then
		pcall(frame.PostUpdate, frame)
	end
	if (frame.Health and frame.Health.ForceUpdate) then
		pcall(frame.Health.ForceUpdate, frame.Health)
	end
	if (frame.Power and frame.Power.ForceUpdate) then
		pcall(frame.Power.ForceUpdate, frame.Power)
	end
	if (frame.Castbar and frame.Castbar.ForceUpdate) then
		pcall(frame.Castbar.ForceUpdate, frame.Castbar)
	end
	if (frame.Auras and frame.Auras.ForceUpdate) then
		pcall(frame.Auras.ForceUpdate, frame.Auras)
	end
	if (label and frame.Name and frame.Name.SetText) then
		pcall(frame.Name.SetText, frame.Name, label)
	end
end

local function GetOrderedRuntimeTestHeaderChildren(header)
	local children = {}
	local seen = {}

	if (header and header.GetAttribute) then
		for index = 1, 40 do
			local child = header:GetAttribute("child" .. index)
			if (not child) then
				break
			end
			if (not seen[child]) then
				seen[child] = true
				children[#children + 1] = child
			end
		end
	end

	if (#children == 0 and header and header.GetNumChildren) then
		for index = 1, header:GetNumChildren() do
			local child = select(index, header:GetChildren())
			if (child and not seen[child]) then
				seen[child] = true
				children[#children + 1] = child
			end
		end
	end

	table_sort(children, function(a, b)
		local aName = a:GetName() or ""
		local bName = b:GetName() or ""
		local aIndex = tonumber(string_match(aName, "(%d+)$")) or 0
		local bIndex = tonumber(string_match(bName, "(%d+)$")) or 0
		if (aIndex == bIndex) then
			return aName < bName
		end
		return aIndex < bIndex
	end)

	return children
end

local function SyncRuntimeTestHeaderPreview(preview, count)
	if (InCombatLockdown()) then
		return
	end

	local module = preview and preview.module
	local header = preview and preview.header
	if (not module or not header) then
		return
	end

	preview.savedStartingIndex = preview.savedStartingIndex or header:GetAttribute("startingIndex")
	preview.savedShowSolo = preview.savedShowSolo or header:GetAttribute("showSolo")
	preview.savedShowPlayer = preview.savedShowPlayer or header:GetAttribute("showPlayer")
	preview.savedShowParty = preview.savedShowParty or header:GetAttribute("showParty")
	preview.savedShowRaid = preview.savedShowRaid or header:GetAttribute("showRaid")

	header.forceShow = true
	header.forceShowAuras = true
	UnregisterAttributeDriver(header, "state-visibility")
	RegisterAttributeDriver(header, "state-visibility", "show")
	header:SetAttribute("showSolo", true)
	header:SetAttribute("showPlayer", true)
	header:SetAttribute("showParty", true)
	header:SetAttribute("showRaid", true)
	header:SetAttribute("startingIndex", -(count + 1))
	header:Show()

	if (module.ConfigureChildren) then
		module:ConfigureChildren()
	end

	local frames = GetOrderedRuntimeTestHeaderChildren(header)
	for _, frame in ipairs(frames) do
		if (frame.__AzeriteUI_RuntimeTestSavedUnit == nil) then
			frame.__AzeriteUI_RuntimeTestSavedUnit = frame.unit
		end
		frame.unit = "player"
		SetupRuntimeTestInteraction(frame, preview.def, 1)
		if (frame.SetAttribute) then
			frame:SetAttribute("unit", "player")
		end
		UnregisterUnitWatch(frame)
		RegisterUnitWatch(frame, true)
		frame:Show()
	end

	preview.frames = frames
end

Debugging.GetRuntimeTestLayout = function(self, def, frames)
	local module = GetRuntimeTestModule(def)
	local profile = module and module.db and module.db.profile or {}
	local first = frames and frames[1]
	local unitWidth = first and first.GetWidth and first:GetWidth() or 100
	local unitHeight = first and first.GetHeight and first:GetHeight() or 40

	if (def.layout == "single") then
		return {
			point = "CENTER",
			xOffset = 0,
			yOffset = 0,
			unitsPerColumn = 1,
			maxColumns = 1,
			columnSpacing = 0,
			columnAnchorPoint = "LEFT",
			width = unitWidth,
			height = unitHeight
		}
	end

	if (def.layout == "boss") then
		return {
			point = "TOP",
			xOffset = 0,
			yOffset = -12,
			unitsPerColumn = def.count,
			maxColumns = 1,
			columnSpacing = 0,
			columnAnchorPoint = "LEFT"
		}
	end

	if (def.layout == "nameplates") then
		return {
			point = "TOP",
			xOffset = 0,
			yOffset = -18,
			unitsPerColumn = 10,
			maxColumns = 1,
			columnSpacing = 0,
			columnAnchorPoint = "LEFT"
		}
	end

	local spacingScale = 1
	if (GetRuntimeTestStateValue("runtimeUnitTestCompactSpacing")) then
		spacingScale = .5
	elseif (GetRuntimeTestStateValue("runtimeUnitTestLargeSpacing")) then
		spacingScale = 1.75
	end

	return {
		point = profile.point or (def.key == "raid40" and "LEFT" or "TOP"),
		xOffset = (profile.xOffset or 0) * spacingScale,
		yOffset = (profile.yOffset or ((def.key == "raid40") and 0 or -12)) * spacingScale,
		unitsPerColumn = profile.unitsPerColumn or def.count,
		maxColumns = profile.maxColumns or 1,
		columnSpacing = (profile.columnSpacing or 0) * spacingScale,
		columnAnchorPoint = profile.columnAnchorPoint or ((def.key == "raid40" or def.key == "party") and "TOP" or "LEFT")
	}
end

Debugging.GetRuntimeTestContainerSize = function(self, def, frames, layout, count)
	local first = frames and frames[1]
	local unitWidth = first and first.GetWidth and first:GetWidth() or 100
	local unitHeight = first and first.GetHeight and first:GetHeight() or 40
	count = count or (frames and #frames) or def.count
	local unitsPerColumn = layout.unitsPerColumn or count
	local maxColumns = layout.maxColumns or 1
	local point = layout.point or "TOP"
	local xOffset = layout.xOffset or 0
	local yOffset = layout.yOffset or 0
	local columnSpacing = layout.columnSpacing or 0
	local _, xOffsetMult, yOffsetMult = GetRelativePointAnchor(point)
	local xMultiplier = math_abs(xOffsetMult)
	local yMultiplier = math_abs(yOffsetMult)
	local numColumns

	if (unitsPerColumn and count > unitsPerColumn) then
		numColumns = math_min(math_ceil(count / unitsPerColumn), maxColumns)
	else
		unitsPerColumn = count
		numColumns = 1
	end

	local width = xMultiplier * (unitsPerColumn - 1) * unitWidth + ((unitsPerColumn - 1) * (xOffset * xOffsetMult)) + unitWidth
	local height = yMultiplier * (unitsPerColumn - 1) * unitHeight + ((unitsPerColumn - 1) * (yOffset * yOffsetMult)) + unitHeight

	if (numColumns > 1) then
		local _, colxMulti, colyMulti = GetRelativePointAnchor(layout.columnAnchorPoint or "LEFT")
		width = width + ((numColumns - 1) * math_abs(colxMulti) * (width + columnSpacing))
		height = height + ((numColumns - 1) * math_abs(colyMulti) * (height + columnSpacing))
	end

	return math_max(width, unitWidth), math_max(height, unitHeight)
end

Debugging.LayoutRuntimeTestPreview = function(self, preview, frames)
	local def = preview and preview.def
	if (not def or not frames or #frames == 0) then
		return
	end

	local container = preview.container
	local anchor = GetRuntimeTestAnchor(def)
	local layout = self:GetRuntimeTestLayout(def, frames)

	container:ClearAllPoints()
	container:SetScale(anchor and anchor.GetScale and anchor:GetScale() or 1)
	container:SetPoint("CENTER", anchor or UIParent, "CENTER", 0, 0)

	if (def.layout == "single") then
		local frame = frames[1]
		local width = frame:GetWidth()
		local height = frame:GetHeight()
		container:SetSize(math_max(width, 1), math_max(height, 1))
		frame:ClearAllPoints()
		frame:SetPoint("CENTER", container, "CENTER", 0, 0)
		return
	end

	local width, height = self:GetRuntimeTestContainerSize(def, frames, layout, #frames)
	container:SetSize(width, height)

	local point = layout.point or "TOP"
	local relativePoint, xOffsetMult, yOffsetMult = GetRelativePointAnchor(point)
	local xMultiplier = math_abs(xOffsetMult)
	local yMultiplier = math_abs(yOffsetMult)
	local xOffset = layout.xOffset or 0
	local yOffset = layout.yOffset or 0
	local unitsPerColumn = layout.unitsPerColumn or #frames
	local columnSpacing = layout.columnSpacing or 0
	local columnAnchorPoint = layout.columnAnchorPoint
	local columnRelPoint, colxMulti, colyMulti
	if (columnAnchorPoint) then
		columnRelPoint, colxMulti, colyMulti = GetRelativePointAnchor(columnAnchorPoint)
	end

	local currentAnchor = container
	local columnUnitCount = 0

	for buttonNum, frame in ipairs(frames) do
		frame:ClearAllPoints()
		columnUnitCount = columnUnitCount + 1

		if (buttonNum == 1) then
			frame:SetPoint(point, container, point, 0, 0)
		elseif (columnUnitCount > unitsPerColumn) then
			columnUnitCount = 1
			local columnAnchor = frames[buttonNum - unitsPerColumn]
			if (columnAnchorPoint and columnAnchor) then
				frame:SetPoint(columnAnchorPoint, columnAnchor, columnRelPoint, colxMulti * columnSpacing, colyMulti * columnSpacing)
			else
				frame:SetPoint(point, container, point, 0, 0)
			end
		else
			frame:SetPoint(point, currentAnchor, relativePoint, xMultiplier * xOffset, yMultiplier * yOffset)
		end

		currentAnchor = frame
	end
end

Debugging.EnsureRuntimeTestPreview = function(self, def)
	self.RuntimeTestPreviews = self.RuntimeTestPreviews or {}
	local preview = self.RuntimeTestPreviews[def.key]
	if (preview) then
		return preview
	end

	local oUF = ns and ns.oUF
	if (not oUF) then
		return nil
	end

	local module = GetRuntimeTestModule(def)
	if (not module) then
		preview = {
			def = def,
			container = CreateFrame("Frame", nil, UIParent),
			frames = {},
			failed = true,
			unsupported = true
		}
		preview.container:Hide()
		self.RuntimeTestPreviews[def.key] = preview
		return preview
	end

	TryPrepareRuntimeTestModule(def, module)

	preview = {
		def = def,
		container = CreateFrame("Frame", nil, UIParent),
		frames = {},
		failed = false,
		fallback = false
	}
	preview.container:SetFrameStrata("DIALOG")
	preview.container:SetClampedToScreen(true)
	preview.container:Hide()

	if (def.headerPreview) then
		local header = module.GetUnitFrameOrHeader and module:GetUnitFrameOrHeader() or (module.frame and module.frame.content)
		if (header) then
			preview.headerPreview = true
			preview.module = module
			preview.header = header
			preview.container = module.frame or preview.container
			self.RuntimeTestPreviews[def.key] = preview
			return preview
		end
	end

	if (def.key == "nameplates") then
		preview.fallback = true
		for i = 1,def.count do
			preview.frames[#preview.frames + 1] = CreateRuntimeTestFallbackFrame(def, preview.container)
		end
		self.RuntimeTestPreviews[def.key] = preview
		return preview
	end

	for i = 1,def.count do
		local frameName = string_format("%sRuntimeTest%s%d", ns.Prefix or "AzeriteUI", def.key, i)
		local ok, frameOrErr = pcall(function()
			oUF:SetActiveStyle(ns.Prefix .. def.style)
			return ns.UnitFrame.Spawn(def.unit or "player", frameName)
		end)
		if (ok and frameOrErr) then
			local frame = frameOrErr
			frame:SetParent(preview.container)
			preview.frames[#preview.frames + 1] = frame
		else
			preview.failed = true
			preview.error = frameOrErr
			break
		end
	end

	if (preview.failed) then
		for _, frame in ipairs(preview.frames) do
			frame:Hide()
		end
		preview.frames = {}
		preview.failed = false
		preview.fallback = true
		for i = 1,def.count do
			preview.frames[#preview.frames + 1] = CreateRuntimeTestFallbackFrame(def, preview.container)
		end
	end

	self.RuntimeTestPreviews[def.key] = preview
	return preview
end

Debugging.HideRuntimeTestPreview = function(self, key)
	local preview = self.RuntimeTestPreviews and self.RuntimeTestPreviews[key]
	if (not preview) then
		return
	end
	if (preview.headerPreview) then
		local header = preview.header
		local module = preview.module
		for _, frame in ipairs(preview.frames or {}) do
			if (frame.__AzeriteUI_RuntimeTestSavedUnit ~= nil) then
				frame.unit = frame.__AzeriteUI_RuntimeTestSavedUnit
				frame.__AzeriteUI_RuntimeTestSavedUnit = nil
			end
			if (frame.SetAttribute) then
				frame:SetAttribute("unit", frame.__AzeriteUI_RuntimeTestSavedUnitAttribute)
				frame:SetAttribute("*type1", frame.__AzeriteUI_RuntimeTestSavedType1Attribute)
			end
			frame:EnableMouse(true)
			UnregisterUnitWatch(frame)
			RegisterUnitWatch(frame)
		end
		if (header) then
			header.forceShow = nil
			header.forceShowAuras = nil
			if (preview.savedStartingIndex ~= nil) then
				header:SetAttribute("startingIndex", preview.savedStartingIndex)
			else
				header:SetAttribute("startingIndex", 1)
			end
			header:SetAttribute("showSolo", preview.savedShowSolo)
			header:SetAttribute("showPlayer", preview.savedShowPlayer)
			header:SetAttribute("showParty", preview.savedShowParty)
			header:SetAttribute("showRaid", preview.savedShowRaid)
		end
		if (module and module.UpdateHeader) then
			module:UpdateHeader()
		end
		if (module and module.UpdateUnits) then
			module:UpdateUnits()
		end
		return
	end
	for _, frame in ipairs(preview.frames) do
		frame:Hide()
	end
	preview.container:Hide()
end

Debugging.RefreshRuntimeTestPreviews = function(self)
	if (InCombatLockdown()) then
		self.__AzeriteUI_PendingRuntimeTestRefresh = true
		self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnDeferredRuntimeTestRefresh")
		return
	end

	self.__AzeriteUI_PendingRuntimeTestRefresh = nil
	self:UnregisterEvent("PLAYER_REGEN_ENABLED", "OnDeferredRuntimeTestRefresh")

	if (not CanUseRuntimeTestMode()) then
		local globalDB = EnsureRuntimeTestState()
		if (globalDB) then
			globalDB.runtimeUnitTestMenuEnabled = false
			globalDB.runtimeUnitTestMode = false
		end
		for _, def in ipairs(RUNTIME_TEST_DEFS) do
			self:HideRuntimeTestPreview(def.key)
		end
		return
	end

	for _, def in ipairs(RUNTIME_TEST_DEFS) do
		local enabled = IsRuntimeTestMode() and IsRuntimeTestSetEnabled(def.key)
		if (enabled) then
			local preview = self:EnsureRuntimeTestPreview(def)
			if (preview and not preview.failed) then
				if (preview.headerPreview) then
					SyncRuntimeTestHeaderPreview(preview, GetRuntimeTestFrameCount(def))
				end
				local visibleCount = GetRuntimeTestFrameCount(def)
				local startIndex = GetRuntimeTestStartIndex(def)
				local activeFrames = {}
				for frameIndex, frame in ipairs(preview.frames) do
					if (frameIndex >= startIndex and #activeFrames < visibleCount) then
						activeFrames[#activeFrames + 1] = frame
					else
						frame:Hide()
					end
				end
				if (#activeFrames > 0) then
					if (not preview.headerPreview) then
						self:LayoutRuntimeTestPreview(preview, activeFrames)
					end
					preview.container:Show()
					for visibleIndex, frame in ipairs(activeFrames) do
						local sourceIndex = startIndex + visibleIndex - 1
						SetupRuntimeTestInteraction(frame, def, sourceIndex)
						ForcePreviewFrameUpdate(frame, GetPreviewLabel(def, sourceIndex))
						frame:Show()
						ApplyRuntimeTestPresentation(frame, def, sourceIndex)
						if (C_Timer) then
							local queuedFrame = frame
							local queuedDef = def
							local queuedIndex = sourceIndex
							C_Timer.After(0, function()
								if (queuedFrame and queuedFrame:IsShown() and IsRuntimeTestMode() and IsRuntimeTestSetEnabled(queuedDef.key)) then
									ApplyRuntimeTestPresentation(queuedFrame, queuedDef, queuedIndex)
								end
							end)
						end
					end
				else
					preview.container:Hide()
				end
			end
		else
			self:HideRuntimeTestPreview(def.key)
		end
	end
end

Debugging.OnDeferredRuntimeTestRefresh = function(self)
	if (InCombatLockdown()) then
		return
	end
	self:RefreshRuntimeTestPreviews()
	if (self.TestFrame and self.TestFrame:IsShown()) then
		UpdateTestMenu(self)
	end
end

local function PrintTargetFillDebugStatus()
	print("|cff33ff99", "AzeriteUI target fill debug:")
	print("|cfff0f0f0  health:", "curve percent -> fake fill -> mirrored visible art")
	print("|cfff0f0f0  cast:", "live duration percent -> timer fallback -> unit-time fallback")
end

local ADDONS = {

	"Blizzard_AchievementUI",
	"Blizzard_AdventureMap",
	"Blizzard_AlliedRacesUI",
	"Blizzard_AnimaDiversionUI",
	"Blizzard_APIDocumentation",
	"Blizzard_ArchaeologyUI",
	"Blizzard_ArdenwealdGardening",
	"Blizzard_ArenaUI",
	"Blizzard_ArtifactUI",
	"Blizzard_AuctionHouseUI",
	"Blizzard_AuthChallengeUI",
	"Blizzard_AzeriteEssenceUI",
	"Blizzard_AzeriteRespecUI",
	"Blizzard_AzeriteUI",
	"Blizzard_BarbershopUI",
	"Blizzard_BattlefieldMap",
	"Blizzard_BehavioralMessaging",
	"Blizzard_BlackMarketUI",
	"Blizzard_BoostTutorial",
	"Blizzard_Calendar",
	"Blizzard_ChallengesUI",
	"Blizzard_Channels",
	"Blizzard_CharacterCreate",
	"Blizzard_CharacterCustomize",
	"Blizzard_ChromieTimeUI",
	"Blizzard_ClassTalentUI",
	"Blizzard_ClassTrial",
	"Blizzard_ClickBindingUI",
	"Blizzard_ClientSavedVariables",
	"Blizzard_Collections",
	"Blizzard_CombatLog",
	"Blizzard_CombatText",
	"Blizzard_Commentator",
	"Blizzard_Communities",
	"Blizzard_CompactRaidFrames",
	"Blizzard_Console",
	"Blizzard_Contribution",
	"Blizzard_CovenantCallings",
	"Blizzard_CovenantPreviewUI",
	"Blizzard_CovenantRenown",
	"Blizzard_CovenantSanctum",
	"Blizzard_CovenantToasts",
	"Blizzard_CUFProfiles",
	"Blizzard_DeathRecap",
	"Blizzard_DebugTools",
	"Blizzard_Deprecated",
	"Blizzard_EncounterJournal",
	"Blizzard_EventTrace",
	"Blizzard_ExpansionLandingPage",
	"Blizzard_FlightMap",
	"Blizzard_FrameEffects",
	"Blizzard_GarrisonTemplates",
	"Blizzard_GarrisonUI",
	"Blizzard_GenericTraitUI",
	"Blizzard_GMChatUI",
	"Blizzard_GuildBankUI",
	"Blizzard_GuildControlUI",
	"Blizzard_GuildUI",
	"Blizzard_HybridMinimap",
	"Blizzard_InspectUI",
	"Blizzard_IslandsPartyPoseUI",
	"Blizzard_IslandsQueueUI",
	"Blizzard_ItemInteractionUI",
	"Blizzard_ItemSocketingUI",
	"Blizzard_ItemUpgradeUI",
	"Blizzard_Kiosk",
	"Blizzard_LandingSoulbinds",
	"Blizzard_MacroUI",
	"Blizzard_MainlineSettings",
	"Blizzard_MajorFactions",
	"Blizzard_MapCanvas",
	"Blizzard_MawBuffs",
	"Blizzard_MoneyReceipt",
	"Blizzard_MovePad",
	"Blizzard_NamePlates",
	"Blizzard_NewPlayerExperience",
	"Blizzard_NewPlayerExperienceGuide",
	"Blizzard_ObjectiveTracker",
	"Blizzard_ObliterumUI",
	"Blizzard_OrderHallUI",
	"Blizzard_PartyPoseUI",
	"Blizzard_PetBattleUI",
	"Blizzard_PlayerChoice",
	"Blizzard_Professions",
	"Blizzard_ProfessionsCrafterOrders",
	"Blizzard_ProfessionsCustomerOrders",
	"Blizzard_PTRFeedback",
	"Blizzard_PTRFeedbackGlue",
	"Blizzard_PVPMatch",
	"Blizzard_PVPUI",
	"Blizzard_QuestNavigation",
	"Blizzard_RaidUI",
	"Blizzard_RuneforgeUI",
	"Blizzard_ScrappingMachineUI",
	"Blizzard_SecureTransferUI",
	"Blizzard_SelectorUI",
	"Blizzard_Settings",
	"Blizzard_SharedMapDataProviders",
	"Blizzard_SharedTalentUI",
	"Blizzard_SocialUI",
	"Blizzard_Soulbinds",
	"Blizzard_StoreUI",
	"Blizzard_SubscriptionInterstitialUI",
	"Blizzard_TalentUI",
	"Blizzard_TalkingHeadUI",
	"Blizzard_TimeManager",
	"Blizzard_TokenUI",
	"Blizzard_TorghastLevelPicker",
	"Blizzard_TrainerUI",
	"Blizzard_Tutorial",
	"Blizzard_TutorialTemplates",
	"Blizzard_UIFrameManager",
	"Blizzard_UIWidgets",
	"Blizzard_VoidStorageUI",
	"Blizzard_WarfrontsPartyPoseUI",
	"Blizzard_WeeklyRewards",
	"Blizzard_WorldMap",
	"Blizzard_WowTokenUI"

}

Debugging.EnableBlizzardAddOns = function(self)
	local disabled = {}
	for _,addon in next,ADDONS do
		local reason = select(5, GetAddOnInfo(addon))
		if (reason == "DISABLED") then
			EnableAddOn(addon)
			disabled[#disabled + 1] = addon
		end
	end
	local num = #disabled
	if (num == 0) then
		print("|cff33ff99", "No Blizzard addons were disabled.")
	else
		if (num > 1) then
			print("|cff33ff99", string_format("The following %d Blizzard addons were enabled:", #disabled))
		else
			print("|cff33ff99", "The following Blizzard addon was enabled:")
		end
		for _,addon in next,ADDONS do
			print(string_format("|cfff0f0f0%s|r", addon))
		end
		print("|cfff00a0aA /reload is required to apply changes!|r")
	end
end

Debugging.EnableScriptErrors = function(self)
	SetCVar("scriptErrors", 1)
end

Debugging.EnsureDebugCommands = function(self)
	if (self.__AzeriteUI_DebugCommandsRegistered) then
		return
	end
	self:RegisterChatCommand("azdebug", "DebugMenu")
	self:RegisterChatCommand("azdebugkeys", "DebugKeysMenu")
	self:RegisterChatCommand("azdebugtarget", "TargetDebugMenu")
	self:RegisterChatCommand("aztest", "TestModeCommand")
	self:RegisterChatCommand("junnez", "SecretJuNNeZCommand")
	self:RegisterChatCommand("goldpaw", "SecretGoldpawCommand")
	self.__AzeriteUI_DebugCommandsRegistered = true
end

-- Secret JuNNeZ Command - Easter Egg
Debugging.SecretJuNNeZCommand = function(self)
	local playerFrame = ns:GetModule("PlayerFrame", true)
	local targetFrame = ns:GetModule("TargetFrame", true)
	
	-- Create Batman-style KAPOW zoom texture frame
	local centerFrame = CreateFrame("Frame", "JuNNeZCenterTexture", UIParent)
	centerFrame:SetSize(512, 512)
	centerFrame:SetPoint("CENTER")
	centerFrame:SetFrameLevel(250)
	centerFrame:SetScale(0.1)  -- Start tiny
	
	local texture = centerFrame:CreateTexture(nil, "OVERLAY")
	texture:SetAllPoints(centerFrame)
	texture:SetTexture(ns.API.GetMedia("JuNNeZKapow"))
	texture:SetAlpha(1.0)
	
	-- Batman KAPOW! Zoom in effect (0.1 -> 1.8 -> 1.0)
	for i = 1, 15 do
		C_Timer.After(i * 0.04, function()
			local scale = 0.1 + (i / 15) * 1.7  -- Zoom from 0.1 to 1.8
			centerFrame:SetScale(scale)
		end)
	end
	
	-- SNAP to normal size at peak with sound
	C_Timer.After(0.65, function()
		centerFrame:SetScale(1.0)
		if (SOUNDKIT and SOUNDKIT.UI_ACHIEVEMENT_EARNED) then
			C_Sound.PlaySound(SOUNDKIT.UI_ACHIEVEMENT_EARNED)
		end
	end)
	
	-- Hold for effect, then fade out
	C_Timer.After(2.5, function()
		for i = 1, 10 do
			C_Timer.After(i * 0.1, function()
				texture:SetAlpha(1.0 - (i / 10))
			end)
		end
	end)
	
	-- Celebratory messages
	local messages = {
		"|cff00ff00JUNNEZ EDITION ACTIVATED!!!|r",
		"|cffffaa00FEEL THE POWER OF CUSTOM CODE!!!|r",
		"|cffff00ffMAINTENANCE MODE: FULLY ENGAGED!!!|r",
		"|cff00ffffBUG FIXES FLOWING LIKE MANA!!!|r",
		"|cffff7700UPDATED AND MAINTAINED BY JUNNEZ!!!|r",
		"|cffff00ffCHAOS LEVEL: 9000!!!|r",
		"|cff00ffffTHIS IS NOT A DRILL!!!|r",
		"|cffff7700WATCH YOUR SANITY!!!|r"
	}
	
	for i, msg in ipairs(messages) do
		C_Timer.After((i-1) * 0.5, function()
			print(msg)
			C_Sound.PlaySound(SOUNDKIT.RAID_WARNING)
		end)
	end
	
	-- Rainbow color flash for player and target frames
	local colors = {
		{1, 0, 0}, -- Red
		{1, 0.5, 0}, -- Orange
		{1, 1, 0}, -- Yellow
		{0, 1, 0}, -- Green
		{0, 1, 1}, -- Cyan
		{0, 0, 1}, -- Blue
		{1, 0, 1}, -- Magenta
		{0.5, 0, 1}, -- Purple
		{1, 0.5, 0.5}, -- Pink
	}
	
	local flashFrames = {}
	if (playerFrame and playerFrame.frame) then
		table_insert(flashFrames, playerFrame.frame)
	end
	if (targetFrame and targetFrame.frame) then
		table_insert(flashFrames, targetFrame.frame)
	end
	
	-- Create flash animation
	for colorIndex, color in ipairs(colors) do
		C_Timer.After(colorIndex * 0.3, function()
			for _, frame in ipairs(flashFrames) do
				if (frame and frame.Health) then
					local health = frame.Health
					if (health.SetStatusBarColor) then
						health:SetStatusBarColor(unpack(color))
						C_Timer.After(0.15, function()
							if (frame.UpdateHealth) then
								pcall(frame.UpdateHealth, frame)
							end
						end)
					end
				end
			end
		end)
	end
	
	-- UI Scale bounce
	local originalScale = UIParent:GetScale()
	-- Store original health colors before animation
	local origPlayerColor = {1, 0, 0}
	local origTargetColor = {1, 0, 0}
	if (playerFrame and playerFrame.frame and playerFrame.frame.Health) then
		origPlayerColor = {playerFrame.frame.Health:GetStatusBarColor()}
	end
	if (targetFrame and targetFrame.frame and targetFrame.frame.Health) then
		origTargetColor = {targetFrame.frame.Health:GetStatusBarColor()}
	end
	
	for i = 1, 12 do
		C_Timer.After(i * 0.15, function()
			UIParent:SetScale(originalScale * (i % 2 == 0 and 1.03 or 0.97))
			if (i % 2 == 0) then
				C_Sound.PlaySound(SOUNDKIT.RAID_WARNING)
			end
		end)
	end
	C_Timer.After(3.0, function()
		UIParent:SetScale(originalScale)
		-- Restore original health colors AFTER all animations complete
		if (playerFrame and playerFrame.frame and playerFrame.frame.Health) then
			playerFrame.frame.Health:SetStatusBarColor(unpack(origPlayerColor))
			if (playerFrame.frame.UpdateHealth) then
				pcall(playerFrame.frame.UpdateHealth, playerFrame.frame)
			end
		end
		if (targetFrame and targetFrame.frame and targetFrame.frame.Health) then
			targetFrame.frame.Health:SetStatusBarColor(unpack(origTargetColor))
			if (targetFrame.frame.UpdateHealth) then
				pcall(targetFrame.frame.UpdateHealth, targetFrame.frame)
			end
		end
	end)
	
	-- Final message and cleanup
	C_Timer.After(5.0, function()
		local finalMsg = "|cff00ff00THANKS FOR USING THE JUNNEZ EDITION! CHAOS COMPLETE!!!|r"
		print(finalMsg)
		if (centerFrame and centerFrame:IsShown()) then
			centerFrame:Hide()
		end
	end)
	
	-- Frame destruction timer
end

-- Secret Goldpaw Command - Tribute to Original Creator
Debugging.SecretGoldpawCommand = function(self)
	local playerFrame = ns:GetModule("PlayerFrame", true)
	local targetFrame = ns:GetModule("TargetFrame", true)
	
	-- Create Goldpaw-style zoom texture frame (similar to /junnez)
	local centerFrame = CreateFrame("Frame", "GoldpawCenterTexture", UIParent)
	centerFrame:SetSize(512, 512)
	centerFrame:SetPoint("CENTER")
	centerFrame:SetFrameLevel(250)
	centerFrame:SetScale(0.1)  -- Start tiny
	
	local texture = centerFrame:CreateTexture(nil, "OVERLAY")
	texture:SetAllPoints(centerFrame)
	texture:SetTexture(ns.API.GetMedia("GoldpawKapow"))
	texture:SetAlpha(1.0)
	
	-- Goldpaw zoom in effect (0.1 -> 1.8 -> 1.0)
	for i = 1, 15 do
		C_Timer.After(i * 0.04, function()
			local scale = 0.1 + (i / 15) * 1.7  -- Zoom from 0.1 to 1.8
			centerFrame:SetScale(scale)
		end)
	end
	
	-- SNAP to normal size at peak with sound
	C_Timer.After(0.65, function()
		centerFrame:SetScale(1.0)
		if (SOUNDKIT and SOUNDKIT.UI_ACHIEVEMENT_EARNED) then
			C_Sound.PlaySound(SOUNDKIT.UI_ACHIEVEMENT_EARNED)
		end
	end)
	
	-- Hold for effect, then fade out
	C_Timer.After(2.5, function()
		for i = 1, 10 do
			C_Timer.After(i * 0.1, function()
				texture:SetAlpha(1.0 - (i / 10))
			end)
		end
	end)
	
	-- Tribute messages for the original creator
	local messages = {
		"|cffffcc00Goldpaw - Original Creator of AzeriteUI|r",
		"|cffffd700Master of UI design and Lua wizardry!|r",
		"|cfffff569Building beautiful interfaces since forever!|r",
		"|cffffaa00Thank you for this amazing foundation!|r",
		"|cffffff00The legend who started it all!|r"
	}
	
	for i, msg in ipairs(messages) do
		C_Timer.After((i-1) * 0.6, function()
			print(msg)
			C_Sound.PlaySound(SOUNDKIT.ACHIEVEMENT_MENU_OPEN)
		end)
	end
	
	-- Golden glow pulse for player and target frames
	local goldColors = {
		{1, 0.84, 0}, -- Pure Gold
		{1, 0.9, 0.3}, -- Light Gold
		{1, 0.84, 0}, -- Pure Gold
		{1, 0.75, 0}, -- Deep Gold
		{1, 0.84, 0}, -- Pure Gold
		{1, 1, 0.5}, -- Bright Gold
	}
	
	local flashFrames = {}
	if (playerFrame and playerFrame.frame) then
		table_insert(flashFrames, playerFrame.frame)
	end
	if (targetFrame and targetFrame.frame) then
		table_insert(flashFrames, targetFrame.frame)
	end
	
	-- Create golden pulse animation
	for colorIndex, color in ipairs(goldColors) do
		C_Timer.After(colorIndex * 0.4, function()
			for _, frame in ipairs(flashFrames) do
				if (frame and frame.Health) then
					local health = frame.Health
					if (health.SetStatusBarColor) then
						health:SetStatusBarColor(unpack(color))
						C_Timer.After(0.2, function()
							if (frame.UpdateHealth) then
								pcall(frame.UpdateHealth, frame)
							end
						end)
					end
				end
			end
			C_Sound.PlaySound(SOUNDKIT.UI_LEGENDARY_LOOT_TOAST)
		end)
	end
	
	-- Gentle UI glow (subtle scale pulse)
	local originalScale = UIParent:GetScale()
	-- Store original health colors before animation
	local origPlayerColor = {1, 0, 0}
	local origTargetColor = {1, 0, 0}
	if (playerFrame and playerFrame.frame and playerFrame.frame.Health) then
		origPlayerColor = {playerFrame.frame.Health:GetStatusBarColor()}
	end
	if (targetFrame and targetFrame.frame and targetFrame.frame.Health) then
		origTargetColor = {targetFrame.frame.Health:GetStatusBarColor()}
	end
	
	for i = 1, 4 do
		C_Timer.After(i * 0.3, function()
			local scaleMod = 1 + (math.sin(i * 1.5) * 0.01)
			UIParent:SetScale(originalScale * scaleMod)
		end)
	end
	
	-- FIXED: Restore colors and scale AFTER all animations complete (2.4 sec for colors)
	C_Timer.After(3.0, function()
		UIParent:SetScale(originalScale)
		-- Restore original health colors
		if (playerFrame and playerFrame.frame and playerFrame.frame.Health) then
			playerFrame.frame.Health:SetStatusBarColor(unpack(origPlayerColor))
			if (playerFrame.frame.UpdateHealth) then
				pcall(playerFrame.frame.UpdateHealth, playerFrame.frame)
			end
		end
		if (targetFrame and targetFrame.frame and targetFrame.frame.Health) then
			targetFrame.frame.Health:SetStatusBarColor(unpack(origTargetColor))
			if (targetFrame.frame.UpdateHealth) then
				pcall(targetFrame.frame.UpdateHealth, targetFrame.frame)
			end
		end
	end)
	
	-- Final tribute message
	C_Timer.After(3.5, function()
		print("|cffffd700Honoring Goldpaw - The Original Architect!|r")
		C_Sound.PlaySound(SOUNDKIT.RAID_WARNING)
		if (centerFrame and centerFrame:IsShown()) then
			centerFrame:Hide()
		end
	end)
end

Debugging.OnEvent = function(self, event, ...)
	self:EnableScriptErrors()
	self:EnsureDebugCommands()
end

Debugging.OnInitialize = function(self)
	self:EnsureDebugCommands()
	if (ns.db and ns.db.global) then
		EnsureRuntimeTestState()
		ns.db.global.runtimeUnitTestMode = false
		ns.db.global.debugHealth = ns.db.global.debugHealth or false
		ns.db.global.debugHealthChat = ns.db.global.debugHealthChat or false
		ns.db.global.debugHealthPercent = ns.db.global.debugHealthPercent or false
		ns.db.global.debugBars = ns.db.global.debugBars or false
		ns.db.global.debugForceBlizzardRaidBar = ns.db.global.debugForceBlizzardRaidBar or false
		ns.db.global.debugFixes = ns.db.global.debugFixes or false
		ns.db.global.debugAuras = ns.db.global.debugAuras or false
		ns.db.global.debugAurasFilter = ns.db.global.debugAurasFilter or ""
		ns.db.global.debugActionbars = ns.db.global.debugActionbars or false
		ns.db.global.debugActionbarsFilter = ns.db.global.debugActionbarsFilter or ""
		ns.db.global.debugCastbar = ns.db.global.debugCastbar or false
		ns.db.global.debugPower = ns.db.global.debugPower or false
		ns.db.global.debugPowerFilter = ns.db.global.debugPowerFilter or ""
		ns.db.global.debugKeysVerbose = ns.db.global.debugKeysVerbose or false
		if (not ns.db.global.debugHealthFilter or ns.db.global.debugHealthFilter == "") then
			ns.db.global.debugHealthFilter = "Target."
		end
		ns.API.DEBUG_HEALTH = ns.db.global.debugHealth
		ns.API.DEBUG_HEALTH_CHAT = ns.db.global.debugHealthChat
		ns.API.DEBUG_HEALTH_FILTER = ns.db.global.debugHealthFilter
		ns.API.DEBUG_HEALTH_PCT = ns.db.global.debugHealthPercent
		ns.API.DEBUG_AURAS = ns.db.global.debugAuras
		ns.API.DEBUG_AURA_FILTER = ns.db.global.debugAurasFilter
		ns.API.DEBUG_ACTIONBARS = ns.db.global.debugActionbars
		ns.API.DEBUG_ACTIONBARS_FILTER = ns.db.global.debugActionbarsFilter
		ns.API.DEBUG_CASTBAR = ns.db.global.debugCastbar
		ns.API.DEBUG_POWER = ns.db.global.debugPower
		ns.API.DEBUG_POWER_FILTER = ns.db.global.debugPowerFilter
		_G.__AzeriteUI_DEBUG_BARS = ns.db.global.debugBars
		_G.__AzeriteUI_DEBUG_HEALTH_PCT = ns.db.global.debugHealthPercent
		_G.__AzeriteUI_DEBUG_AURAS = ns.db.global.debugAuras
		_G.__AzeriteUI_DEBUG_AURA_FILTER = ns.db.global.debugAurasFilter
		_G.__AzeriteUI_DEBUG_ACTIONBARS = ns.db.global.debugActionbars
		_G.__AzeriteUI_DEBUG_ACTIONBARS_FILTER = ns.db.global.debugActionbarsFilter
		_G.__AzeriteUI_DEBUG_CASTBAR = ns.db.global.debugCastbar
		_G.__AzeriteUI_DEBUG_POWER = ns.db.global.debugPower
		_G.__AzeriteUI_DEBUG_POWER_FILTER = ns.db.global.debugPowerFilter
		_G.__AzeriteUI_DEBUG_KEYS = ns.db.global.debugKeysVerbose
	end
	if (ns.WoW10) then
		self:RegisterEvent("SETTINGS_LOADED", "OnEvent")
	end
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEvent")
	self:RegisterEvent("VARIABLES_LOADED", "OnEvent")
	self:EnableScriptErrors()
end

Debugging.ToggleHealthDebug = function(self)
	ns.API.DEBUG_HEALTH = not ns.API.DEBUG_HEALTH
	if (ns.db and ns.db.global) then
		ns.db.global.debugHealth = ns.API.DEBUG_HEALTH
	end
	local enabled = ns.API.DEBUG_HEALTH
	print("|cff33ff99", "AzeriteUI health debug:", enabled and "ON" or "OFF")

	local oUF = ns.oUF
	if (oUF and oUF.objects) then
		for _, obj in next, oUF.objects do
			local dbg = obj.HealthDebug
			if (dbg) then
				if (enabled) then dbg:Show() else dbg:Hide() end
			end
		end
	end
end

Debugging.ToggleHealthDebugChat = function(self)
	ns.API.DEBUG_HEALTH_CHAT = not ns.API.DEBUG_HEALTH_CHAT
	if (ns.db and ns.db.global) then
		ns.db.global.debugHealthChat = ns.API.DEBUG_HEALTH_CHAT
	end
	print("|cff33ff99", "AzeriteUI health debug chat:", ns.API.DEBUG_HEALTH_CHAT and "ON" or "OFF")
end

local function SafeCall(obj, method, ...)
	if (obj and obj[method]) then
		local ok, a, b, c, d, e = pcall(obj[method], obj, ...)
		if (ok) then
			return a, b, c, d, e
		end
	end
	return nil
end

local function IsSecretValue(value)
	return (issecretvalue and issecretvalue(value)) and true or false
end

local function SecretSafeText(value)
	if (IsSecretValue(value)) then
		return "<secret>"
	end
	local ok, text = pcall(tostring, value)
	if (ok and text ~= nil) then
		return text
	end
	return "<unprintable>"
end

local SafePrintTarget = "chat"

local function SafePrintToDebugLog(...)
	if (not (DLAPI and DLAPI.DebugLog)) then
		return false
	end
	local args = {}
	for i = 1, select("#", ...) do
		args[i] = SecretSafeText(select(i, ...))
	end
	local payload = table_concat(args, " ")
	local ok = pcall(DLAPI.DebugLog, "AzeriteUI", payload)
	return ok and true or false
end

local function SafePrint(...)
	local args = {}
	for i = 1, select("#", ...) do
		args[i] = SecretSafeText(select(i, ...))
	end
	if (SafePrintTarget == "debuglog") then
		if (SafePrintToDebugLog(unpack(args))) then
			return
		end
	elseif (SafePrintTarget == "both") then
		SafePrintToDebugLog(unpack(args))
	end
	print(unpack(args))
end

local function DumpUnitValue(label, value)
	SafePrint("|cfff0f0f0  " .. label .. ":", value, IsSecretValue(value) and "(secret)" or "(clean)")
end

local function ResolveUnitFrame(unit)
	if (IsSecretValue(unit) or type(unit) ~= "string" or unit == "") then
		return nil, nil
	end
	unit = unit:lower()
	if (unit == "target") then
		local mod = ns:GetModule("TargetFrame", true)
		return mod and mod.frame, "TargetFrame"
	end
	if (unit == "player") then
		local mod = ns:GetModule("PlayerFrame", true)
		return mod and mod.frame, "PlayerFrame"
	end
	if (unit == "targettarget" or unit == "tot") then
		local mod = ns:GetModule("ToTFrame", true)
		return mod and mod.frame, "ToTFrame"
	end
	return nil, nil
end

local function DumpElementSnapshot(element, label)
	if (not element) then
		SafePrint("|cfff0f0f0  " .. label .. ":", "missing")
		return
	end
	local value = SafeCall(element, "GetValue")
	local minValue, maxValue = SafeCall(element, "GetMinMaxValues")
	SafePrint("|cfff0f0f0  " .. label .. " safe:",
		"cur", element.safeCur,
		"min", element.safeMin,
		"max", element.safeMax,
		"pct", element.safePercent)
	SafePrint("|cfff0f0f0  " .. label .. " bar:",
		"value", value,
		"min", minValue,
		"max", maxValue,
		"mirrorPct", element.__AzeriteUI_MirrorPercent,
		"texPct", element.__AzeriteUI_TexturePercent)
end

local function SafeUnitBoolCall(func, ...)
	if (type(func) ~= "function") then
		return nil
	end
	local ok, value = pcall(func, ...)
	if (not ok or type(value) ~= "boolean") then
		return nil
	end
	return value
end

local function SafeUnitNumberCall(func, ...)
	if (type(func) ~= "function") then
		return nil
	end
	local ok, value = pcall(func, ...)
	if (not ok or type(value) ~= "number") then
		return nil
	end
	return value
end

local function DumpUnitSnapshot(unit)
	if (IsSecretValue(unit) or type(unit) ~= "string" or unit == "") then
		unit = "target"
	end
	SafePrint("|cff33ff99", "AzeriteUI unit snapshot:", unit)
	if (not UnitExists(unit)) then
		SafePrint("|cfff0f0f0  unit does not exist")
		return
	end

	DumpUnitValue("UnitGUID", UnitGUID(unit))
	SafePrint("|cfff0f0f0  targetInfo:",
		"isPlayer", SafeUnitBoolCall(UnitIsPlayer, unit),
		"playerControlled", SafeUnitBoolCall(UnitPlayerControlled, unit),
		"canAttack", SafeUnitBoolCall(UnitCanAttack, "player", unit),
		"canAssist", SafeUnitBoolCall(UnitCanAssist, "player", unit),
		"isEnemy", SafeUnitBoolCall(UnitIsEnemy, "player", unit),
		"isFriend", SafeUnitBoolCall(UnitIsFriend, "player", unit),
		"reaction", SafeUnitNumberCall(UnitReaction, unit, "player"),
		"tapDenied", SafeUnitBoolCall(UnitIsTapDenied, unit))

	DumpUnitValue("UnitHealth", UnitHealth(unit))
	DumpUnitValue("UnitHealthMax", UnitHealthMax(unit))
	if (UnitHealthPercent) then
		local percent = nil
		pcall(function()
			if (CurveConstants and CurveConstants.ScaleTo100) then
				percent = UnitHealthPercent(unit, true, CurveConstants.ScaleTo100)
			else
				percent = UnitHealthPercent(unit)
			end
		end)
		DumpUnitValue("UnitHealthPercent", percent)
	end

	local powerType = UnitPowerType(unit)
	DumpUnitValue("UnitPower", UnitPower(unit, powerType))
	DumpUnitValue("UnitPowerMax", UnitPowerMax(unit, powerType))
	if (UnitPowerPercent) then
		local powerPercent = nil
		pcall(function()
			if (CurveConstants and CurveConstants.ScaleTo100) then
				powerPercent = UnitPowerPercent(unit, powerType, true, CurveConstants.ScaleTo100)
			else
				powerPercent = UnitPowerPercent(unit, powerType)
			end
		end)
		DumpUnitValue("UnitPowerPercent", powerPercent)
	end

	local frame, frameName = ResolveUnitFrame(unit)
	if (frame and frame.unit == unit) then
		SafePrint("|cfff0f0f0  frame:", frameName, "bound")
		DumpElementSnapshot(frame.Health, "Health")
		DumpElementSnapshot(frame.Power, "Power")
	else
		SafePrint("|cfff0f0f0  frame:", frameName or "n/a", "not bound to unit token")
	end
end

local function DumpPoints(frame, indent)
	if (not frame) then
		return
	end
	local num = SafeCall(frame, "GetNumPoints") or 0
	for i = 1, num do
		local point, relTo, relPoint, x, y = SafeCall(frame, "GetPoint", i)
		local relName = relTo and SafeCall(relTo, "GetName") or tostring(relTo)
		SafePrint("|cfff0f0f0 " .. indent .. "point[" .. i .. "]:", point, relName, relPoint, x, y)
	end
end

local function GetCVarBoolSafe(name)
	if (type(name) ~= "string" or name == "") then
		return nil
	end
	if (C_CVar and C_CVar.GetCVarBool) then
		local ok, value = pcall(C_CVar.GetCVarBool, name)
		if (ok and type(value) == "boolean") then
			return value
		end
	end
	if (GetCVarBool) then
		local ok, value = pcall(GetCVarBool, name)
		if (ok and type(value) == "boolean") then
			return value
		end
	end
	return nil
end

local function GetCVarSafe(name)
	if (type(name) ~= "string" or name == "") then
		return nil
	end
	if (C_CVar and C_CVar.GetCVar) then
		local ok, value = pcall(C_CVar.GetCVar, name)
		if (ok and type(value) == "string") then
			return value
		end
	end
	if (GetCVar) then
		local ok, value = pcall(GetCVar, name)
		if (ok and type(value) == "string") then
			return value
		end
	end
	return nil
end

local function GetActionBarsModule()
	local module = ns:GetModule("ActionBars", true)
	if (module and module.db and module.db.profile) then
		return module
	end
	return nil
end

local function FindActionButtonByName(buttonName)
	if (type(buttonName) ~= "string" or buttonName == "") then
		return nil
	end
	local direct = _G[buttonName]
	if (direct) then
		return direct
	end
	local module = GetActionBarsModule()
	if (not module or not module.buttons) then
		return nil
	end
	for button in pairs(module.buttons) do
		if (button and button.GetName and button:GetName() == buttonName) then
			return button
		end
	end
	return nil
end

local function GetActionCooldownInfoSafe(actionID)
	if (type(actionID) ~= "number") then
		return nil
	end
	if (C_ActionBar and C_ActionBar.GetActionCooldown) then
		local ok, info = pcall(C_ActionBar.GetActionCooldown, actionID)
		if (ok and type(info) == "table") then
			return info
		end
	end
	if (GetActionCooldown) then
		local ok, start, duration, enabled, modRate = pcall(GetActionCooldown, actionID)
		if (ok) then
			return {
				startTime = start,
				duration = duration,
				isEnabled = enabled,
				modRate = modRate
			}
		end
	end
	return nil
end

local function GetActionChargeInfoSafe(actionID)
	if (type(actionID) ~= "number") then
		return nil
	end
	if (C_ActionBar and C_ActionBar.GetActionCharges) then
		local ok, info = pcall(C_ActionBar.GetActionCharges, actionID)
		if (ok and type(info) == "table") then
			return info
		end
	end
	if (GetActionCharges) then
		local ok, charges, maxCharges, startTime, duration, modRate = pcall(GetActionCharges, actionID)
		if (ok) then
			return {
				currentCharges = charges,
				maxCharges = maxCharges,
				cooldownStartTime = startTime,
				cooldownDuration = duration,
				chargeModRate = modRate
			}
		end
	end
	return nil
end

local function PrintDebugKeysHelp()
	print("|cff33ff99", "AzeriteUI /azdebugkeys commands:")
	print("|cfff0f0f0  /azdebugkeys status|r")
	print("|cfff0f0f0  /azdebugkeys bindings|r")
	print("|cfff0f0f0  /azdebugkeys cooldown [buttonName]|r")
	print("|cfff0f0f0  /azdebugkeys holdtest [spellID]|r")
	print("|cfff0f0f0  /azdebugkeys on|off|toggle|r  (verbose)")
	print("|cfff0f0f0  /azdebug keys <subcommand>|r  (same commands via /azdebug)")
end

local function PrintDebugKeysStatus()
	local module = GetActionBarsModule()
	local profile = module and module.db and module.db.profile or nil
	local commandMode = (profile and profile.UseCommandBindingsForHoldCast == true) and true or false
	local clickOnDown = (profile and profile.clickOnDown == true) and true or false
	local cvarKeyDown = GetCVarBoolSafe("ActionButtonUseKeyDown")
	local cvarPressHold = GetCVarBoolSafe("ActionButtonUseKeyHeldSpell")
	local cvarPressHoldRaw = GetCVarSafe("ActionButtonUseKeyHeldSpell")
	local holdApi = (C_Spell and C_Spell.IsPressHoldReleaseSpell) and "yes" or "no"
	local inCombat = (InCombatLockdown and InCombatLockdown()) and "true" or "false"
	local verbose = (ns.db and ns.db.global and ns.db.global.debugKeysVerbose) and "ON" or "OFF"

	print("|cff33ff99", "AzeriteUI key debug status:")
	print("|cfff0f0f0  inCombat:", inCombat)
	print("|cfff0f0f0  bindingMode:", commandMode and "command" or "click-fallback")
	print("|cfff0f0f0  profile.clickOnDown:", tostring(clickOnDown))
	print("|cfff0f0f0  CVar ActionButtonUseKeyDown:", tostring(cvarKeyDown))
	print("|cfff0f0f0  CVar ActionButtonUseKeyHeldSpell:", tostring(cvarPressHold), "raw:", tostring(cvarPressHoldRaw))
	print("|cfff0f0f0  C_Spell.IsPressHoldReleaseSpell:", holdApi)
	print("|cfff0f0f0  verbose:", verbose)

	if (module and module.bars) then
		for index, bar in pairs(module.bars) do
			local enabled = bar and bar.IsEnabled and bar:IsEnabled() and "true" or "false"
			local numButtons = (bar and bar.config and bar.config.numbuttons) or 0
			print("|cfff0f0f0  bar"..tostring(index)..": enabled", enabled, "buttons", tostring(numButtons))
		end
	end
end

local function PrintDebugKeyBindings()
	local module = GetActionBarsModule()
	if (not module or not module.bars) then
		print("|cff33ff99", "AzeriteUI /azdebugkeys:", "ActionBars module unavailable")
		return
	end
	print("|cff33ff99", "AzeriteUI key binding dump:")
	for barIndex, bar in pairs(module.bars) do
		if (bar and bar.buttons and bar.config and bar.config.numbuttons and bar.config.numbuttons > 0) then
			local modeCommand = bar.config.useCommandBindingsForHoldCast and true or false
			print("|cfff0f0f0  bar"..tostring(barIndex)..": mode", modeCommand and "command" or "click")
			for buttonIndex = 1, bar.config.numbuttons do
				local button = bar.buttons[buttonIndex]
				if (button) then
					local target = button.keyBoundTarget
					local key1, key2 = nil, nil
					if (type(target) == "string" and target ~= "") then
						key1, key2 = GetBindingKey(target)
					end
					local route = modeCommand and target or ("CLICK " .. tostring(button:GetName()) .. ":LeftButton")
					print("|cfff0f0f0    ", tostring(button:GetName()), "slot", tostring(button._state_action), "bind", tostring(target), "route", tostring(route), "keys", tostring(key1), tostring(key2))
				end
			end
		end
	end
end

local function PrintDebugKeyCooldown(buttonName)
	local button = FindActionButtonByName(buttonName)
	if (not button) then
		local module = GetActionBarsModule()
		if (module and module.bars and module.bars[1] and module.bars[1].buttons) then
			button = module.bars[1].buttons[1]
		end
	end
	if (not button) then
		print("|cff33ff99", "AzeriteUI /azdebugkeys cooldown:", "button not found")
		return
	end
	local actionID = button._state_action
	local actionType, actionToken, subType = nil, nil, nil
	if (type(actionID) == "number" and actionID > 0 and GetActionInfo) then
		actionType, actionToken, subType = GetActionInfo(actionID)
	end
	local cooldownInfo = (type(actionID) == "number" and actionID > 0) and GetActionCooldownInfoSafe(actionID) or nil
	local chargeInfo = (type(actionID) == "number" and actionID > 0) and GetActionChargeInfoSafe(actionID) or nil

	print("|cff33ff99", "AzeriteUI key cooldown debug:")
	print("|cfff0f0f0  button:", tostring(button:GetName()))
	print("|cfff0f0f0  actionID:", tostring(actionID), "actionType:", tostring(actionType), "token:", tostring(actionToken), "subType:", tostring(subType))
	print("|cfff0f0f0  attrs: useOnKeyDown", SecretSafeText(button:GetAttribute("useOnKeyDown")), "pressAndHoldAction", SecretSafeText(button:GetAttribute("pressAndHoldAction")), "typerelease", SecretSafeText(button:GetAttribute("typerelease")))

	if (cooldownInfo) then
		print("|cfff0f0f0  cooldown:", "start", SecretSafeText(cooldownInfo.startTime), "duration", SecretSafeText(cooldownInfo.duration), "modRate", SecretSafeText(cooldownInfo.modRate), "isEnabled", SecretSafeText(cooldownInfo.isEnabled))
	else
		print("|cfff0f0f0  cooldown:", "nil")
	end
	if (chargeInfo) then
		print("|cfff0f0f0  charges:", "cur", SecretSafeText(chargeInfo.currentCharges), "max", SecretSafeText(chargeInfo.maxCharges), "start", SecretSafeText(chargeInfo.cooldownStartTime), "duration", SecretSafeText(chargeInfo.cooldownDuration), "modRate", SecretSafeText(chargeInfo.chargeModRate))
	else
		print("|cfff0f0f0  charges:", "nil")
	end
end

local function PrintDebugHoldTest(spellIDText)
	if (not (C_Spell and C_Spell.IsPressHoldReleaseSpell)) then
		print("|cff33ff99", "AzeriteUI holdtest:", "C_Spell.IsPressHoldReleaseSpell unavailable")
		return
	end
	local spellID = tonumber(spellIDText or "")
	if (not spellID) then
		print("|cff33ff99", "AzeriteUI holdtest:", "spellID required")
		return
	end
	local ok, result = pcall(C_Spell.IsPressHoldReleaseSpell, spellID)
	print("|cff33ff99", "AzeriteUI holdtest:", "spellID", tostring(spellID), "ok", tostring(ok), "pressHold", SecretSafeText(result))
end

Debugging.DebugKeysMenu = function(self, input)
	if (not IsDevMode()) then
		print("|cff33ff99", "AzeriteUI /azdebugkeys:", "Dev mode is off; limited features may apply.")
	end
	local cmd, rest = (input or ""):match("^(%S+)%s*(.-)$")
	cmd = cmd and string_lower(cmd) or "status"

	if (cmd == "help" or cmd == "?") then
		return PrintDebugKeysHelp()
	end
	if (cmd == "status") then
		return PrintDebugKeysStatus()
	end
	if (cmd == "bindings") then
		return PrintDebugKeyBindings()
	end
	if (cmd == "cooldown") then
		local buttonName = rest and rest:match("^(%S+)") or nil
		return PrintDebugKeyCooldown(buttonName)
	end
	if (cmd == "holdtest") then
		local spellIDText = rest and rest:match("^(%S+)") or nil
		return PrintDebugHoldTest(spellIDText)
	end
	local mode = nil
	if (cmd == "on" or cmd == "off" or cmd == "toggle") then
		mode = cmd
	end
	if (mode) then
		local db = ns and ns.db and ns.db.global
		if (db) then
			local current = db.debugKeysVerbose and true or false
			if (mode == "toggle") then
				db.debugKeysVerbose = not current
			elseif (mode == "on") then
				db.debugKeysVerbose = true
			elseif (mode == "off") then
				db.debugKeysVerbose = false
			end
			_G.__AzeriteUI_DEBUG_KEYS = db.debugKeysVerbose and true or false
		end
		print("|cff33ff99", "AzeriteUI /azdebugkeys verbose:", (db and db.debugKeysVerbose) and "ON" or "OFF")
		return
	end
	PrintDebugKeysHelp()
end

local function DumpTexture(tex, label)
	if (not tex) then
		return
	end
	local name = label or SafeCall(tex, "GetName") or "(texture)"
	local path = SafeCall(tex, "GetTexture")
	local width, height = SafeCall(tex, "GetSize")
	local alpha = SafeCall(tex, "GetAlpha")
	local shown = SafeCall(tex, "IsShown")
	local layer, subLayer = SafeCall(tex, "GetDrawLayer")
	local blend = SafeCall(tex, "GetBlendMode")
	local r, g, b, a = SafeCall(tex, "GetVertexColor")
	local t1, t2, t3, t4 = SafeCall(tex, "GetTexCoord")
	local parent = SafeCall(tex, "GetParent")
	local parentName = parent and SafeCall(parent, "GetName") or nil
	SafePrint("|cfff0f0f0  texture:", name, "path:", path)
	SafePrint("|cfff0f0f0   size:", width, height, "alpha:", alpha, "shown:", shown, "layer:", layer, "sub:", subLayer, "blend:", blend)
	SafePrint("|cfff0f0f0   parent:", parentName, "vertex:", r, g, b, a)
	SafePrint("|cfff0f0f0   texcoord:", t1, t2, t3, t4)
	DumpPoints(tex, "   ")
end

local function DumpBar(bar, labelOverride)
	if (not bar) then
		return
	end
	local label = labelOverride or bar.__AzeriteUI_DebugLabel or "(bar)"
	local growth = SafeCall(bar, "GetGrowth")
	local orient = SafeCall(bar, "GetOrientation")
	local flipped = SafeCall(bar, "IsFlippedHorizontally")
	local reverse = SafeCall(bar, "GetReverseFill")
	local min, max = SafeCall(bar, "GetMinMaxValues")
	local value = SafeCall(bar, "GetValue")
	local r1, r2, r3, r4 = SafeCall(bar, "GetRealTexCoord")
	local secretPercent = SafeCall(bar, "GetSecretPercent")
	local debugData = SafeCall(bar, "GetDebugData")
	local width, height = SafeCall(bar, "GetSize")
	local alpha = SafeCall(bar, "GetAlpha")
	local shown = SafeCall(bar, "IsShown")
	local level = SafeCall(bar, "GetFrameLevel")
	local scale = SafeCall(bar, "GetScale")
	local effScale = SafeCall(bar, "GetEffectiveScale")
	local strata = SafeCall(bar, "GetFrameStrata")
	local parent = SafeCall(bar, "GetParent")
	local parentName = parent and SafeCall(parent, "GetName") or nil
	local tex = SafeCall(bar, "GetStatusBarTexture")
	local colorR, colorG, colorB, colorA = SafeCall(bar, "GetStatusBarColor")
	local expectedOrient = bar.__AzeriteUI_ExpectedOrientation
	local expectedFlip = bar.__AzeriteUI_ExpectedFlipped
	local expectedReverse = bar.__AzeriteUI_ExpectedReverseFill
	SafePrint("|cff33ff99", "AzeriteUI bar dump:", label)
	SafePrint("|cfff0f0f0  growth:", growth, "orientation:", orient, "flipped:", flipped, "reverse:", reverse)
	SafePrint("|cfff0f0f0  min/max/value:", min, max, value, "secretPercent:", secretPercent)
	SafePrint("|cfff0f0f0  texcoord:", r1, r2, r3, r4, "color:", colorR, colorG, colorB, colorA)
	SafePrint("|cfff0f0f0  size:", width, height, "alpha:", alpha, "shown:", shown, "level:", level, "parent:", parentName)
	SafePrint("|cfff0f0f0  scale:", scale, "effectiveScale:", effScale, "strata:", strata)
	SafePrint("|cfff0f0f0  flags:", "useBlizzard", bar.__AzeriteUI_UseBlizzard, "expectedOrient", expectedOrient, "expectedFlip", expectedFlip, "expectedReverse", expectedReverse)
	if (bar.__AzeriteUI_CastFakePath or bar.__AzeriteUI_FakeConfiguredAlpha ~= nil or bar.__AzeriteUI_FakeUseStatusBarAlpha ~= nil or bar.__AzeriteUI_FakeUseManualAlpha ~= nil) then
		SafePrint("|cfff0f0f0  castFake:",
			"path", bar.__AzeriteUI_CastFakePath,
			"percent", bar.__AzeriteUI_CastFakePercent,
			"source", bar.__AzeriteUI_CastCropSource,
			"explicit", bar.__AzeriteUI_CastLastExplicitPercent,
			"invert", bar.__AzeriteUI_FakeInvertPercent,
			"alphaCfg", bar.__AzeriteUI_FakeConfiguredAlpha,
			"useStatusAlpha", bar.__AzeriteUI_FakeUseStatusBarAlpha,
			"useManualAlpha", bar.__AzeriteUI_FakeUseManualAlpha,
			"manualAlpha", bar.__AzeriteUI_FakeAlpha)
	end
	if (bar.__AzeriteUI_TargetFakeSource) then
		SafePrint("|cfff0f0f0  healthFake:",
			"source", bar.__AzeriteUI_TargetFakeSource,
			"targetPctSource", bar.__AzeriteUI_TargetPercentSource,
			"displayPct", bar.__AzeriteUI_TargetDisplayPercent,
			"safePct", bar.safePercent,
			"mirrorPct", bar.__AzeriteUI_MirrorPercent,
			"texPct", bar.__AzeriteUI_TexturePercent,
			"invertPct", _G.__AzeriteUI_DEBUG_TARGET_HEALTH_FORCE_INVERT,
			"noInvertPct", _G.__AzeriteUI_DEBUG_TARGET_HEALTH_FORCE_NOINVERT,
			"rawCurSafe", bar.__AzeriteUI_RawCurSafe,
			"rawMaxSafe", bar.__AzeriteUI_RawMaxSafe)
	end
	DumpPoints(bar, "  ")
	DumpTexture(tex, label .. ".StatusBarTexture")
	DumpTexture(bar.FakeFill, label .. ".FakeFill")
	if (debugData) then
		SafePrint("|cfff0f0f0  lib:", "orient", debugData.barOrientation, "revFill", debugData.barBlizzardReverseFill, "revH", debugData.reversedH, "revV", debugData.reversedV, "proxy", debugData.proxyShown)
		if (debugData.proxyTexCoord) then
			SafePrint("|cfff0f0f0  proxy texcoord:", debugData.proxyTexCoord[1], debugData.proxyTexCoord[2], debugData.proxyTexCoord[3], debugData.proxyTexCoord[4])
		end
		if (debugData.proxySize) then
			SafePrint("|cfff0f0f0  proxy size:", debugData.proxySize[1], debugData.proxySize[2])
		end
	end
end

local function DumpArtTextures(container, label)
	if (not container) then
		return
	end
	DumpTexture(container.Backdrop, label .. ".Backdrop")
	DumpTexture(container.Case, label .. ".Case")
	DumpTexture(container.Shade, label .. ".Shade")
	DumpTexture(container.Border, label .. ".Border")
	DumpTexture(container.Overlay, label .. ".Overlay")
	DumpTexture(container.Gloss, label .. ".Gloss")
end

local function DumpUnitBars(frame, name)
	if (not frame) then
		SafePrint("|cff33ff99", "AzeriteUI bar dump:", name, "not found")
		return
	end
	SafePrint("|cff33ff99", "AzeriteUI bar dump:", name)
	SafePrint("|cfff0f0f0  unit:", frame.unit, "style:", frame.currentStyle)
	local fwidth, fheight = SafeCall(frame, "GetSize")
	local fscale = SafeCall(frame, "GetScale")
	local feff = SafeCall(frame, "GetEffectiveScale")
	local fstrata = SafeCall(frame, "GetFrameStrata")
	local flevel = SafeCall(frame, "GetFrameLevel")
	SafePrint("|cfff0f0f0  size:", fwidth, fheight, "scale:", fscale, "effectiveScale:", feff, "strata:", fstrata, "level:", flevel)
	DumpPoints(frame, "  ")
	if (name == "TargetFrame") then
		local cfg = ns.GetConfig("TargetFrame")
		if (cfg) then
			SafePrint("|cfff0f0f0  config:", "IsFlippedHorizontally", cfg.IsFlippedHorizontally)
			if (frame.currentStyle and cfg[frame.currentStyle]) then
				local styleCfg = cfg[frame.currentStyle]
				SafePrint("|cfff0f0f0  style:", frame.currentStyle, "HealthBarOrientation", styleCfg.HealthBarOrientation, "HealthBarTexture", styleCfg.HealthBarTexture)
			end
		end
	end
	DumpBar(frame.Health)
	if (frame.Health and frame.Health.Percent and frame.Health.Percent.GetText) then
		SafePrint("|cfff0f0f0  healthPercentText:", SafeCall(frame.Health.Percent, "GetText"))
	end
	DumpArtTextures(frame.Health, "Health")
	DumpBar(frame.Health and frame.Health.Preview)
	DumpBar(frame.Castbar)
	DumpBar(frame.HealthPrediction and frame.HealthPrediction.absorbBar, "Target.Absorb")
	DumpBar(frame.Power, "Target.Power")
	DumpArtTextures(frame.Power, "Power")
	DumpBar(frame.ManaOrb, "Player.ManaOrb")
	DumpArtTextures(frame.ManaOrb, "ManaOrb")
end

local function DumpAuraButtonState(button, label)
	if (not button) then
		return
	end

	local icon = button.Icon or button.icon
	local count = button.Count or button.count
	local cooldown = button.Cooldown or button.cd
	local auraInstanceID = button.auraInstanceID
	local spellID = button.auraSpellID or button.spellID
	local unit = button.GetParent and button:GetParent() and button:GetParent().__owner and button:GetParent().__owner.unit or nil
	local resolvedSpellID
	local resolvedName
	if (unit and auraInstanceID and C_UnitAuras and C_UnitAuras.GetAuraDataByAuraInstanceID) then
		local ok, auraData = pcall(C_UnitAuras.GetAuraDataByAuraInstanceID, unit, auraInstanceID)
		if (ok and auraData and not (issecretvalue and issecretvalue(auraData))) then
			resolvedSpellID = auraData.spellId or auraData.spellID
			resolvedName = auraData.name
			if (not spellID) then
				spellID = resolvedSpellID
			end
		end
	end
	local shown = SafeCall(button, "IsShown")
	local visible = SafeCall(button, "IsVisible")
	local alpha = SafeCall(button, "GetAlpha")
	local width, height = SafeCall(button, "GetSize")
	local level = SafeCall(button, "GetFrameLevel")
	local iconTexture = icon and SafeCall(icon, "GetTexture") or nil
	local iconAlpha = icon and SafeCall(icon, "GetAlpha") or nil
	local iconShown = icon and SafeCall(icon, "IsShown") or nil
	local iconDesaturated = icon and SafeCall(icon, "IsDesaturated") or nil
	local iconR, iconG, iconB, iconA
	if (icon) then
		iconR, iconG, iconB, iconA = SafeCall(icon, "GetVertexColor")
	end
	local countText = count and SafeCall(count, "GetText") or nil
	local countShown = count and SafeCall(count, "IsShown") or nil
	local cdShown = cooldown and SafeCall(cooldown, "IsShown") or nil
	local cdStart, cdDuration, cdEnabled
	if (cooldown) then
		cdStart, cdDuration, cdEnabled = SafeCall(cooldown, "GetCooldown")
	end
	local timeLeft = button.timeLeft
	local expiration = button.auraExpirationTime or button.expirationTime
	local duration = button.duration

	SafePrint("|cfff0f0f0", label,
		"shown", shown,
		"visible", visible,
		"alpha", alpha,
		"size", width, height,
		"level", level)
	SafePrint("|cfff0f0f0 ", " aura:",
		"unit", unit,
		"instance", auraInstanceID,
		"spell", spellID,
		"resolvedSpell", resolvedSpellID,
		"name", resolvedName,
		"filter", button.filter,
		"harmful", button.isHarmful,
		"harmfulAura", button.isHarmfulAura,
		"player", button.isPlayer,
		"stealable", button.isStealable)
	SafePrint("|cfff0f0f0 ", " visual:",
		"icon", iconTexture and "yes" or "no",
		"iconShown", iconShown,
		"iconAlpha", iconAlpha,
		"desat", iconDesaturated,
		"vertex", iconR, iconG, iconB, iconA,
		"count", countText,
		"countShown", countShown)
	SafePrint("|cfff0f0f0 ", " timing:",
		"cdShown", cdShown,
		"start", cdStart,
		"duration", cdDuration,
		"enabled", cdEnabled,
		"storedDuration", duration,
		"expires", expiration,
		"timeLeft", timeLeft)
end

local function DumpSecureAuraHeaderChildren(header, label, maxChildren)
	if (not header) then
		SafePrint("|cff33ff99", "AzeriteUI aura snapshot:", label, "header missing")
		return
	end

	local cap = tonumber(maxChildren) or 60
	local dumped = 0
	for i = 1, cap do
		local child = SafeCall(header, "GetAttribute", "child" .. i)
		if (not child) then
			break
		end
		dumped = dumped + 1
		DumpAuraButtonState(child, label .. "[" .. i .. "]")
	end

	SafePrint("|cff33ff99", "AzeriteUI aura snapshot:", label, "children dumped:", dumped)
end

local function DumpPlayerAuraSnapshot()
	local playerFrame = ns:GetModule("PlayerFrame", true)
	local frame = playerFrame and playerFrame.frame
	local auras = frame and frame.Auras
	if (not auras) then
		SafePrint("|cff33ff99", "AzeriteUI aura snapshot:", "playerframe auras not found")
		return
	end

	local maxButtons = tonumber(auras.numTotal) or tonumber(auras.createdButtons) or 40
	if (maxButtons < 1) then
		maxButtons = 40
	elseif (maxButtons > 80) then
		maxButtons = 80
	end

	SafePrint("|cff33ff99", "AzeriteUI aura snapshot: playerframe")
	SafePrint("|cfff0f0f0", "combat", InCombatLockdown and InCombatLockdown(), "unit", frame.unit, "maxButtons", maxButtons)
	SafePrint("|cfff0f0f0", "element:",
		"created", auras.createdButtons,
		"visibleAuras", auras.visibleAuras,
		"visibleBuffs", auras.visibleBuffs,
		"visibleDebuffs", auras.visibleDebuffs,
		"sorting", auras.sortMethod, auras.sortDirection)

	local dumped = 0
	for i = 1, maxButtons do
		local button = auras[i]
		if (button) then
			dumped = dumped + 1
			DumpAuraButtonState(button, "player[" .. i .. "]")
		end
	end

	SafePrint("|cff33ff99", "AzeriteUI aura snapshot: playerframe buttons dumped:", dumped)
end

local function DumpTopRightAuraSnapshot()
	local module = ns:GetModule("Auras", true)
	local buffs = module and module.buffs
	if (not buffs) then
		SafePrint("|cff33ff99", "AzeriteUI aura snapshot:", "top-right buffs header not found")
		return
	end

	local proxy = buffs.proxy
	local consolidation = buffs.consolidation

	SafePrint("|cff33ff99", "AzeriteUI aura snapshot: top-right")
	SafePrint("|cfff0f0f0", "combat", InCombatLockdown and InCombatLockdown(), "numConsolidated", buffs.numConsolidated)
	SafePrint("|cfff0f0f0", "header:",
		"shown", SafeCall(buffs, "IsShown"),
		"alpha", SafeCall(buffs, "GetAlpha"),
		"unit", SafeCall(buffs, "GetAttribute", "unit"),
		"filter", SafeCall(buffs, "GetAttribute", "filter"),
		"point", SafeCall(buffs, "GetAttribute", "point"),
		"xOffset", SafeCall(buffs, "GetAttribute", "xOffset"),
		"wrapAfter", SafeCall(buffs, "GetAttribute", "wrapAfter"))

	if (proxy) then
		SafePrint("|cfff0f0f0", "proxy:",
			"shown", SafeCall(proxy, "IsShown"),
			"alpha", SafeCall(proxy, "GetAlpha"),
			"count", proxy.count and SafeCall(proxy.count, "GetText") or nil,
			"texture", proxy.texture and SafeCall(proxy.texture, "GetTexture") or nil)
	end

	if (consolidation) then
		SafePrint("|cfff0f0f0", "consolidation:",
			"shown", SafeCall(consolidation, "IsShown"),
			"alpha", SafeCall(consolidation, "GetAlpha"),
			"point", SafeCall(consolidation, "GetAttribute", "point"),
			"xOffset", SafeCall(consolidation, "GetAttribute", "xOffset"),
			"wrapAfter", SafeCall(consolidation, "GetAttribute", "wrapAfter"))
	end

	DumpSecureAuraHeaderChildren(buffs, "topright.main", 80)
	DumpSecureAuraHeaderChildren(consolidation, "topright.consolidation", 80)
end

local function DumpAuraSnapshot(scope)
	scope = (type(scope) == "string" and scope:lower()) or "both"
	local previousTarget = SafePrintTarget
	SafePrintTarget = "debuglog"

	local handled = true
	if (scope == "player" or scope == "playerframe") then
		DumpPlayerAuraSnapshot()
	elseif (scope == "topright" or scope == "header" or scope == "buffheader") then
		DumpTopRightAuraSnapshot()
	elseif (scope == "both" or scope == "all" or scope == "") then
		DumpPlayerAuraSnapshot()
		DumpTopRightAuraSnapshot()
	else
		handled = false
		SafePrint("|cff33ff99", "AzeriteUI aura snapshot:", "unknown scope", tostring(scope), "(use player|topright|both)")
	end

	SafePrintTarget = previousTarget

	if (handled) then
		if (DLAPI and DLAPI.DebugLog) then
			print("|cff33ff99", "AzeriteUI aura snapshot:", "written to _debuglog", "scope", scope)
		else
			print("|cff33ff99", "AzeriteUI aura snapshot:", "DLAPI unavailable, printed to chat instead")
		end
	end
end

local function GetUnitFrameModules()
	local mods = {}
	mods[#mods + 1] = ns:GetModule("PlayerFrame", true)
	mods[#mods + 1] = ns:GetModule("TargetFrame", true)
	mods[#mods + 1] = ns:GetModule("ToTFrame", true)
	mods[#mods + 1] = ns:GetModule("PlayerFrameAlternate", true)
	return mods
end

local function PrintScaleStatus()
	local uiScale = SafeCall(UIParent, "GetScale")
	local desired = ns.API.GetEffectiveScale()
	print("|cff33ff99", "AzeriteUI scale status:")
	print("|cfff0f0f0  UIParent scale:", tostring(uiScale), "desired frame scale:", tostring(desired))
	for _, mod in next, GetUnitFrameModules() do
		if (mod and mod.frame) then
			local name = mod.GetName and mod:GetName() or "Unknown"
			local frameScale = SafeCall(mod.frame, "GetScale")
			local eff = SafeCall(mod.frame, "GetEffectiveScale")
			local saved = mod.db and mod.db.profile and mod.db.profile.savedPosition and mod.db.profile.savedPosition.scale or nil
			local anchor = mod.anchor
			local anchorDefault = anchor and anchor.GetDefaultScale and anchor:GetDefaultScale() or nil
			print("|cfff0f0f0  ", name .. ":", "frame", tostring(frameScale), "effective", tostring(eff), "saved", tostring(saved), "anchorDefault", tostring(anchorDefault))
		end
	end
end

local function GetDebugNamePlateFrame(token)
	local unit = type(token) == "string" and token:lower() or ""
	if (unit == "" or unit == "auto") then
		if (UnitExists("target")) then
			unit = "target"
		elseif (UnitExists("softenemy")) then
			unit = "softenemy"
		elseif (UnitExists("softinteract")) then
			unit = "softinteract"
		elseif (UnitExists("mouseover")) then
			unit = "mouseover"
		else
			unit = "nameplate1"
		end
	end

	local frame = nil
	local resolvedUnit = unit
	if (C_NamePlate and C_NamePlate.GetNamePlateForUnit) then
		local plate = C_NamePlate.GetNamePlateForUnit(unit)
		frame = plate and (plate.unitFrame or plate.UnitFrame)
	end

	if (not frame and ns.ActiveNamePlates) then
		for plate in next, ns.ActiveNamePlates do
			if (plate and plate.unit and SafeCall(UnitIsUnit, plate.unit, unit)) then
				frame = plate
				resolvedUnit = plate.unit
				break
			end
		end
	end

	return frame, resolvedUnit
end

local function PrintNamePlateScaleStatus(token)
	local mod = ns:GetModule("NamePlates", true)
	if (not mod or not mod.GetDebugPlateScaleBreakdown) then
		print("|cff33ff99", "AzeriteUI nameplate scale:", "NamePlates module unavailable")
		return
	end

	local frame, resolvedUnit = GetDebugNamePlateFrame(token)
	if (not frame) then
		print("|cff33ff99", "AzeriteUI nameplate scale:", "no matching active plate found for", tostring(token or "auto"))
		return
	end

	local info = mod:GetDebugPlateScaleBreakdown(frame)
	if (not info) then
		print("|cff33ff99", "AzeriteUI nameplate scale:", "unable to inspect plate")
		return
	end

	print("|cff33ff99", "AzeriteUI nameplate scale:")
	SafePrint("|cfff0f0f0  unit:", tostring(resolvedUnit), "frameUnit:", tostring(info.unit))
	SafePrint("|cfff0f0f0  flags:",
		"target", tostring(info.target),
		"softTarget", tostring(info.softTarget),
		"softEnemy", tostring(info.softEnemy),
		"softInteract", tostring(info.softInteract),
		"hostile", tostring(info.hostile),
		"nameOnly", tostring(info.friendlyNameOnly))
	SafePrint("|cfff0f0f0  scale inputs:",
		"base", tostring(info.baseScale),
		"overall", tostring(info.overallScale),
		"relation", tostring(info.relationScale),
		"targetDelta", tostring(info.targetScale),
		"blizzardMode", tostring(info.usingBlizzardGlobalScale))
	SafePrint("|cfff0f0f0  frame:",
		"computed", tostring(info.computedScale),
		"scale", tostring(info.frameScale),
		"effective", tostring(info.frameEffectiveScale))
	SafePrint("|cfff0f0f0  parent:",
		"name", tostring(info.parentName),
		"scale", tostring(info.parentScale),
		"effective", tostring(info.parentEffectiveScale),
		"blizzScale", tostring(info.blizzPlateScale),
		"blizzEffective", tostring(info.blizzPlateEffectiveScale))
	SafePrint("|cfff0f0f0  softFrame:",
		"shown", tostring(info.softTargetFrameShown),
		"scale", tostring(info.softTargetFrameScale),
		"effective", tostring(info.softTargetFrameEffectiveScale),
		"width", tostring(info.softTargetFrameWidth),
		"height", tostring(info.softTargetFrameHeight))
end

local function ResetUnitFrameScales()
	local desired = ns.API.GetEffectiveScale()
	for _, mod in next, GetUnitFrameModules() do
		if (mod and mod.db and mod.db.profile and mod.db.profile.savedPosition) then
			mod.db.profile.savedPosition.scale = desired
			if (mod.UpdatePositionAndScale) then
				mod:UpdatePositionAndScale()
			end
			if (mod.UpdateAnchor) then
				mod:UpdateAnchor()
			end
		end
	end
	print("|cff33ff99", "AzeriteUI unitframe scales reset to:", tostring(desired))
end

local function GetPlayerPowerOffsetProfile()
	local mod = ns:GetModule("PlayerFrame", true)
	local profile = mod and mod.db and mod.db.profile
	if (not profile) then
		return nil, nil
	end
	profile.powerBarOffsetX = tonumber(profile.powerBarOffsetX) or 0
	profile.powerBarOffsetY = tonumber(profile.powerBarOffsetY) or 0
	profile.powerCaseOffsetX = tonumber(profile.powerCaseOffsetX) or 0
	profile.powerCaseOffsetY = tonumber(profile.powerCaseOffsetY) or 0
	return mod, profile
end

local function ApplyPlayerPowerOffsets()
	local mod = ns:GetModule("PlayerFrame", true)
	if (mod and mod.Update) then
		mod:Update()
		return true
	end
	return false
end

local function PrintPlayerPowerOffsets()
	local _, profile = GetPlayerPowerOffsetProfile()
	if (not profile) then
		print("|cff33ff99", "AzeriteUI power offsets:", "PlayerFrame module not available")
		return
	end
	print("|cff33ff99", "AzeriteUI player power offsets:")
	print("|cfff0f0f0  bar:", "x", tostring(profile.powerBarOffsetX), "y", tostring(profile.powerBarOffsetY))
	print("|cfff0f0f0  case:", "x", tostring(profile.powerCaseOffsetX), "y", tostring(profile.powerCaseOffsetY))
end

PrintPlayerOrbDebug = function()
	local mod = ns:GetModule("PlayerFrame", true)
	local frame = mod and mod.frame
	local orb = frame and frame.ManaOrb
	local crystal = frame and frame.Power
	if (not orb) then
		print("|cff33ff99", "AzeriteUI orb debug:", "Player ManaOrb unavailable")
		return
	end

	local tex1, tex2, tex3, tex4 = orb:GetStatusBarTexture()
	local lib = LibStub and LibStub("LibOrb-1.0", true)
	local data = lib and lib.orbs and lib.orbs[orb]
	local native = data and data.nativeStatusBar
	local nativeMin, nativeMax = nil, nil
	local orbText = nil
	if (native and native.GetMinMaxValues) then
		nativeMin, nativeMax = SafeCall(native, "GetMinMaxValues")
	end
	if (orb.Value and orb.Value.GetText) then
		orbText = SafeCall(orb.Value, "GetText")
	end

	print("|cff33ff99", "AzeriteUI player orb debug:")
	SafePrint("|cfff0f0f0  orb:", "shown", SafeCall(orb, "IsShown"), "width", SafeCall(orb, "GetWidth"), "height", SafeCall(orb, "GetHeight"), "alpha", SafeCall(orb, "GetAlpha"))
	SafePrint("|cfff0f0f0  text:", orbText)
	SafePrint("|cfff0f0f0  textures:",
		"t1", tex1 and SafeCall(tex1, "GetTexture"), tex1 and SafeCall(tex1, "IsShown"), tex1 and SafeCall(tex1, "GetAlpha"),
		"t2", tex2 and SafeCall(tex2, "GetTexture"), tex2 and SafeCall(tex2, "IsShown"), tex2 and SafeCall(tex2, "GetAlpha"),
		"t3", tex3 and SafeCall(tex3, "IsShown"), tex3 and SafeCall(tex3, "GetAlpha"),
		"t4", tex4 and SafeCall(tex4, "IsShown"), tex4 and SafeCall(tex4, "GetAlpha"))
	SafePrint("|cfff0f0f0  element:",
		"cur", orb.cur,
		"min", orb.min,
		"max", orb.max,
		"safeCur", orb.safeCur,
		"safeMin", orb.safeMin,
		"safeMax", orb.safeMax,
		"safePct", orb.safePercent)
	SafePrint("|cfff0f0f0  liborb:",
		"barValue", data and data.barValue,
		"barMin", data and data.barMin,
		"barMax", data and data.barMax,
		"barDisplayValue", data and data.barDisplayValue,
		"scrollShown", data and data.scrollframe and SafeCall(data.scrollframe, "IsShown"))
	SafePrint("|cfff0f0f0  native:",
		"value", native and SafeCall(native, "GetValue"),
		"min", nativeMin,
		"max", nativeMax)
	SafePrint("|cfff0f0f0  crystal:",
		"shown", crystal and SafeCall(crystal, "IsShown"),
		"cur", crystal and crystal.cur,
		"safeCur", crystal and crystal.safeCur,
		"safePct", crystal and crystal.safePercent,
		"mirrorPct", crystal and crystal.__AzeriteUI_MirrorPercent,
		"texturePct", crystal and crystal.__AzeriteUI_TexturePercent)
end


local function PrintDebugHelp()
	print("|cff33ff99", "AzeriteUI /azdebug commands:")
	print("|cfff0f0f0  /azdebug|r  (toggle menu)")
	print("|cfff0f0f0  /azdebug status|r")
	print("|cfff0f0f0  /azdebug health [on|off|toggle]|r")
	print("|cfff0f0f0  /azdebug health filter <text>|r  (example: Target.)")
	print("|cfff0f0f0  /azdebug healthchat [on|off|toggle]|r")
	print("|cfff0f0f0  /azdebug bars [on|off|toggle]|r")
	print("|cfff0f0f0  /azdebug fixes [on|off|toggle]|r")
	print("|cfff0f0f0  /azdebug dump target|r")
	print("|cfff0f0f0  /azdebug dump player|r")
	print("|cfff0f0f0  /azdebug dump tot|r")
	print("|cfff0f0f0  /azdebug dump all|r")
	print("|cfff0f0f0  /azdebug aurasnapshot [player|topright|both]|r")
	print("|cfff0f0f0  /azdebug nameplates [unit]|r")
	print("|cfff0f0f0  /azdebug snapshot [unit]|r")
	print("|cfff0f0f0  /azdebug blizzard enable|r")
	print("|cfff0f0f0  /azdebug scale|r  (print scale status)")
	print("|cfff0f0f0  /azdebug scale nameplates [unit]|r")
	print("|cfff0f0f0  /azdebug scale reset|r")
	print("|cfff0f0f0  /azdebug keys <subcommand>|r")
	print("|cfff0f0f0  /azdebug raidbar status|r")
	print("|cfff0f0f0  /azdebug raidbar [on|off|toggle]|r")
	print("|cfff0f0f0  /azdebug scripterrors|r")
	print("|cfff0f0f0  /azdebug secrettest [unit]|r")
	print("|cfff0f0f0  /aztest|r  (toggle unit test menu, Junnez only)")
	print("|cfff0f0f0  /aztest status|r")
	print("|cfff0f0f0  /aztest on|off|toggle|r")
	print("|cfff0f0f0  /aztest <set> on|off|toggle|r")
	print("|cfff0f0f0  /aztest list|r")
end

local function PrintNamePlateCastDebug(token)
	token = type(token) == "string" and token:lower() or nil
	if (token == "" or token == "all") then
		token = nil
	end

	local function IsSecretDebugValue(value)
		return (type(issecretvalue) == "function" and issecretvalue(value)) and true or false
	end

	local function SafeDebugString(value)
		if (IsSecretDebugValue(value)) then
			return "<secret>"
		end
		return tostring(value)
	end

	print("|cff33ff99", "AzeriteUI nameplate cast debug:")
	local found = false
	for frame in next, ns.ActiveNamePlates do
		local unit = frame and frame.unit
		if (type(unit) == "string" and ((not token) or unit:lower() == token)) then
			found = true
			local castbar = frame.Castbar
			local castName, _, _, _, _, _, castID, castNotInterruptible, castSpellID = UnitCastingInfo(unit)
			local channelName, _, _, _, _, _, channelNotInterruptible, channelSpellID = UnitChannelInfo(unit)
			local rawSource = "none"
			local rawName = nil
			local rawSpellID = nil
			local rawNotInterruptible = nil
			local eventNotInterruptible = castbar and castbar.__AzeriteUI_EventNotInterruptible
			local blizzProtected = nil
			if (type(castName) == "string" and (not IsSecretDebugValue(castName)) and castName ~= "") then
				rawSource = "cast"
				rawName = castName
				rawSpellID = castSpellID
				rawNotInterruptible = castNotInterruptible
			elseif (type(channelName) == "string" and (not IsSecretDebugValue(channelName)) and channelName ~= "") then
				rawSource = "channel"
				rawName = channelName
				rawSpellID = channelSpellID
				rawNotInterruptible = channelNotInterruptible
			elseif (type(castName) == "string" and IsSecretDebugValue(castName)) then
				rawSource = "cast"
				rawName = castName
				rawSpellID = castSpellID
				rawNotInterruptible = castNotInterruptible
			elseif (type(channelName) == "string" and IsSecretDebugValue(channelName)) then
				rawSource = "channel"
				rawName = channelName
				rawSpellID = channelSpellID
				rawNotInterruptible = channelNotInterruptible
			end

			if (ns and ns.ActiveNamePlates and frame and frame.unit and C_NamePlate and C_NamePlate.GetNamePlateForUnit) then
				local okPlate, plate = pcall(C_NamePlate.GetNamePlateForUnit, frame.unit, issecurefunc and issecurefunc())
				local unitFrame = okPlate and plate and (plate.UnitFrame or plate.unitFrame)
				local blizzardCastbar = unitFrame and (unitFrame.castBar or unitFrame.CastBar or unitFrame.castbar or unitFrame.Castbar or unitFrame.CastingBarFrame)
				local blizzardActive = blizzardCastbar and (blizzardCastbar.casting or blizzardCastbar.channeling or blizzardCastbar.empowering)
				local blizzardLocked = blizzardCastbar and blizzardCastbar.notInterruptible
				if (blizzardActive and type(blizzardLocked) == "boolean" and (not IsSecretDebugValue(blizzardLocked)) and blizzardLocked) then
					blizzProtected = true
				else
					blizzProtected = false
				end
			end

			print("|cfff0f0f0", string_format(
				"%s shown=%s canAttack=%s casting=%s channeling=%s spell=%s castID=%s source=%s rawName=%s rawNotInterruptible=%s castbarFlag=%s eventFlag=%s blizzProtected=%s",
				unit,
				SafeDebugString(frame and frame.IsShown and frame:IsShown()),
				SafeDebugString(frame and frame.canAttack),
				SafeDebugString(castbar and castbar.casting),
				SafeDebugString(castbar and castbar.channeling),
				SafeDebugString(rawSpellID),
				SafeDebugString(castID),
				SafeDebugString(rawSource),
				SafeDebugString(rawName),
				SafeDebugString(rawNotInterruptible),
				SafeDebugString(castbar and castbar.notInterruptible),
				SafeDebugString(eventNotInterruptible),
				SafeDebugString(blizzProtected)))
		end
	end
	if (not found) then
		print("|cfff0f0f0", token and ("no active nameplate matched " .. token) or "no active nameplates")
	end
end

local function ParseOnOffToggle(token)
	if (not token or token == "") then
		return "toggle"
	end
	token = token:lower()
	if (token == "on" or token == "off" or token == "toggle") then
		return token
	end
	return nil
end

local function SetDebugFlag(flag, value)
	if (value == "toggle") then
		return not flag
	end
	if (value == "on") then
		return true
	end
	if (value == "off") then
		return false
	end
	return flag
end

Debugging.TestModeCommand = function(self, input)
	if (not CanUseRuntimeTestMode()) then
		print("|cff33ff99", "AzeriteUI /aztest:", "restricted to the maintainer character")
		return
	end

	if (not input or input == "") then
		return self:ToggleTestMenu()
	end

	local cmd, rest = input:match("^(%S+)%s*(.-)$")
	cmd = cmd and cmd:lower() or "status"

	if (cmd == "menu") then
		return self:ToggleTestMenu()
	end

	if (cmd == "status") then
		print("|cff33ff99", "AzeriteUI unit test mode:", IsRuntimeTestMode() and "ON" or "OFF")
		print("|cfff0f0f0  preset:", GetRuntimeTestOptionLabel(RUNTIME_TEST_PRESETS, GetRuntimeTestStateValue("runtimeUnitTestPreset")))
		print("|cfff0f0f0  nameplates:", GetRuntimeTestOptionLabel(RUNTIME_TEST_NAMEPLATE_PACKS, GetRuntimeTestStateValue("runtimeUnitTestNameplatePack")), "/", GetRuntimeTestOptionLabel(RUNTIME_TEST_NAMEPLATE_VARIANTS, GetRuntimeTestStateValue("runtimeUnitTestNameplateVariant")))
		print("|cfff0f0f0  distribution:", GetRuntimeTestOptionLabel(RUNTIME_TEST_CLASS_DISTRIBUTIONS, GetRuntimeTestStateValue("runtimeUnitTestClassDistribution")))
		print("|cfff0f0f0  health:", GetRuntimeTestOptionLabel(RUNTIME_TEST_HEALTH_SCENARIOS, GetRuntimeTestStateValue("runtimeUnitTestHealthScenario")))
		print("|cfff0f0f0  auras:", GetRuntimeTestOptionLabel(RUNTIME_TEST_AURA_SCENARIOS, GetRuntimeTestStateValue("runtimeUnitTestAuraScenario")))
		print("|cfff0f0f0  cast:", GetRuntimeTestOptionLabel(RUNTIME_TEST_CAST_SCENARIOS, GetRuntimeTestStateValue("runtimeUnitTestCastScenario")))
		print("|cfff0f0f0  mouseover:", GetRuntimeTestOptionLabel(RUNTIME_TEST_MOUSEOVER_MODES, GetRuntimeTestStateValue("runtimeUnitTestMouseoverMode")))
		for _, def in ipairs(RUNTIME_TEST_DEFS) do
			local count = GetRuntimeTestFrameCount(def)
			print("|cfff0f0f0  ", def.key .. ":", IsRuntimeTestSetEnabled(def.key) and "ON" or "OFF", "count:", count)
		end
		return
	end

	if (cmd == "list") then
		print("|cff33ff99", "AzeriteUI /aztest sets:")
		for _, def in ipairs(RUNTIME_TEST_DEFS) do
			print("|cfff0f0f0  ", def.key, "-", def.label)
		end
		return
	end

	local mode = ParseOnOffToggle(cmd)
	if (mode) then
		SetRuntimeTestMode(SetDebugFlag(IsRuntimeTestMode(), mode))
		print("|cff33ff99", "AzeriteUI unit test mode:", IsRuntimeTestMode() and "ON" or "OFF")
		self:RefreshRuntimeTestPreviews()
		return
	end

	local def = GetRuntimeTestDefinition(cmd)
	local setMode = ParseOnOffToggle(rest)
	if (def and setMode) then
		SetRuntimeTestSetEnabled(def.key, SetDebugFlag(IsRuntimeTestSetEnabled(def.key), setMode))
		if (not IsRuntimeTestMode()) then
			SetRuntimeTestMode(true)
		else
			self:RefreshRuntimeTestPreviews()
		end
		print("|cff33ff99", "AzeriteUI unit test set:", def.label, IsRuntimeTestSetEnabled(def.key) and "ON" or "OFF")
		return
	end

	print("|cff33ff99", "AzeriteUI /aztest commands:")
	print("|cfff0f0f0  /aztest|r")
	print("|cfff0f0f0  /aztest status|r")
	print("|cfff0f0f0  /aztest on|off|toggle|r")
	print("|cfff0f0f0  /aztest <set> on|off|toggle|r")
	print("|cfff0f0f0  /aztest list|r")
end

UpdateTestMenu = function(self)
	local frame = self.TestFrame
	if (not frame) then
		return
	end
	frame.MasterToggle:SetChecked(IsRuntimeTestMode())
	for key, button in pairs(frame.SetToggles) do
		button:SetChecked(IsRuntimeTestSetEnabled(key))
	end
	for _, control in ipairs(frame.CycleControls or {}) do
		control.button:SetText(GetRuntimeTestOptionLabel(control.options, GetRuntimeTestStateValue(control.stateKey)))
	end
	for _, control in ipairs(frame.BoolControls or {}) do
		control.button:SetChecked(GetRuntimeTestStateValue(control.stateKey) and true or false)
	end
end

Debugging.ToggleTestMenu = function(self)
	if (not CanUseRuntimeTestMode()) then
		print("|cff33ff99", "AzeriteUI /aztest:", "restricted to the maintainer character")
		return
	end

	local frame = self.TestFrame
	local created = false
	if (not frame) then
		frame = CreateFrame("Frame", "AzeriteUI_TestMenu", UIParent, "BasicFrameTemplateWithInset")
		frame:SetSize(660, 760)
		frame:SetPoint("CENTER", UIParent, "CENTER", 350, 60)
		frame:SetFrameStrata("DIALOG")
		frame:SetClampedToScreen(true)
		frame:SetMovable(true)
		frame:EnableMouse(true)
		frame:RegisterForDrag("LeftButton")
		frame:SetScript("OnDragStart", function(f) f:StartMoving() end)
		frame:SetScript("OnDragStop", function(f) f:StopMovingOrSizing() end)
		frame.TitleText:SetText("AzeriteUI Unit Test Lab")

		local subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		subtitle:SetPoint("TOPLEFT", 14, -32)
		subtitle:SetText("Maintainer-only preview lab for Junnez")

		local hint = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		hint:SetPoint("TOPLEFT", 14, -50)
		hint:SetText("Left-click cycles forward. Right-click cycles backward.")

		local master = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
		master:SetPoint("TOPLEFT", 14, -72)
		master.Text:SetText("Enable Unit Test Mode")
		master:SetScript("OnClick", function(btn)
			SetRuntimeTestMode(btn:GetChecked() and true or false)
			self:RefreshRuntimeTestPreviews()
			UpdateTestMenu(self)
		end)
		frame.MasterToggle = master

		local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
		scroll:SetPoint("TOPLEFT", 10, -102)
		scroll:SetPoint("BOTTOMRIGHT", -28, 44)

		local content = CreateFrame("Frame", nil, scroll)
		content:SetSize(600, 1200)
		scroll:SetScrollChild(content)

		frame.Scroll = scroll
		frame.ScrollChild = content
		frame.CycleControls = {}
		frame.BoolControls = {}
		frame.SetToggles = {}

		local y = -8
		local function AddSectionHeader(text)
			local band = content:CreateTexture(nil, "BACKGROUND")
			band:SetPoint("TOPLEFT", 12, y + 6)
			band:SetSize(564, 18)
			band:SetColorTexture(.08, .08, .08, .75)

			local line = content:CreateTexture(nil, "ARTWORK")
			line:SetPoint("TOPLEFT", 12, y - 14)
			line:SetPoint("TOPRIGHT", -12, y - 14)
			line:SetHeight(1)
			line:SetColorTexture(.35, .35, .35, .6)

			local label = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
			label:SetPoint("TOPLEFT", 18, y + 2)
			label:SetTextColor(1, .82, .18)
			label:SetText(text)
			y = y - 28
			return label
		end

		local function AddDescription(text)
			local label = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
			label:SetPoint("TOPLEFT", 24, y)
			label:SetWidth(548)
			label:SetJustifyH("LEFT")
			label:SetText(text)
			y = y - 28
		end

		local function AddCycleRow(labelText, stateKey, options, onChange, description)
			local label = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
			label:SetPoint("TOPLEFT", 20, y - 2)
			label:SetWidth(214)
			label:SetJustifyH("LEFT")
			label:SetText(labelText)

			local button = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
			button:SetSize(230, 22)
			button:SetPoint("TOPLEFT", 256, y)
			button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
			button:SetScript("OnClick", function(_, mouseButton)
				local step = mouseButton == "RightButton" and -1 or 1
				local nextKey = CycleRuntimeTestOption(options, GetRuntimeTestStateValue(stateKey), step)
				SetRuntimeTestStateValue(stateKey, nextKey)
				if (onChange) then
					onChange(nextKey)
				end
				self:RefreshRuntimeTestPreviews()
				UpdateTestMenu(self)
			end)
			table_insert(frame.CycleControls, { button = button, stateKey = stateKey, options = options })
			y = y - 26
			if (description) then
				AddDescription(description)
			end
		end

		local function AddCheckRow(labelText, stateKey, description, onChange)
			local button = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
			button:SetPoint("TOPLEFT", 12, y)
			button.Text:SetText(labelText)
			button:SetScript("OnClick", function(btn)
				SetRuntimeTestStateValue(stateKey, btn:GetChecked() and true or false)
				if (onChange) then
					onChange(btn:GetChecked() and true or false)
				end
				self:RefreshRuntimeTestPreviews()
				UpdateTestMenu(self)
			end)
			table_insert(frame.BoolControls, { button = button, stateKey = stateKey })
			y = y - 24
			if (description) then
				AddDescription(description)
			end
		end

		local function AddActionRow(buttons)
			local x = 16
			for _, data in ipairs(buttons) do
				local button = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
				button:SetSize(data.width or 110, 22)
				button:SetPoint("TOPLEFT", x, y)
				button:SetText(data.label)
				button:SetScript("OnClick", data.onClick)
				x = x + (data.width or 110) + 8
			end
			y = y - 30
		end

		AddSectionHeader("Quick Actions")
		AddDescription("Use presets to populate the most common testing rosters fast, then layer scenarios and stress toggles on top.")
		AddActionRow({
			{
				label = "Enable All",
				width = 100,
				onClick = function()
					SetAllRuntimeTestSets(true)
					SetRuntimeTestMode(true)
					self:RefreshRuntimeTestPreviews()
					UpdateTestMenu(self)
				end
			},
			{
				label = "Groups Only",
				width = 110,
				onClick = function()
					SetAllRuntimeTestSets(false)
					for _, key in ipairs({ "boss", "party", "raid5", "raid25", "raid40", "arena", "nameplates" }) do
						SetRuntimeTestSetEnabled(key, true)
					end
					SetRuntimeTestMode(true)
					self:RefreshRuntimeTestPreviews()
					UpdateTestMenu(self)
				end
			},
			{
				label = "Clear All",
				width = 100,
				onClick = function()
					SetAllRuntimeTestSets(false)
					SetRuntimeTestMode(false)
					self:RefreshRuntimeTestPreviews()
					UpdateTestMenu(self)
				end
			},
		})
		AddActionRow({
			{
				label = "Apply Preset",
				width = 110,
				onClick = function()
					ApplyRuntimeTestPreset()
					SetRuntimeTestMode(true)
					self:RefreshRuntimeTestPreviews()
					UpdateTestMenu(self)
				end
			},
			{
				label = "Reset State",
				width = 110,
				onClick = function()
					local globalDB = EnsureRuntimeTestState()
					if (globalDB) then
						globalDB.runtimeUnitTestMenuEnabled = false
						globalDB.runtimeUnitTestPreset = RUNTIME_TEST_PRESETS[1].key
						globalDB.runtimeUnitTestClassDistribution = RUNTIME_TEST_CLASS_DISTRIBUTIONS[1].key
						globalDB.runtimeUnitTestHealthScenario = RUNTIME_TEST_HEALTH_SCENARIOS[2].key
						globalDB.runtimeUnitTestAuraScenario = RUNTIME_TEST_AURA_SCENARIOS[1].key
						globalDB.runtimeUnitTestCastScenario = RUNTIME_TEST_CAST_SCENARIOS[1].key
						globalDB.runtimeUnitTestMouseoverMode = RUNTIME_TEST_MOUSEOVER_MODES[1].key
						globalDB.runtimeUnitTestNameplatePack = RUNTIME_TEST_NAMEPLATE_PACKS[1].key
						globalDB.runtimeUnitTestNameplateVariant = RUNTIME_TEST_NAMEPLATE_VARIANTS[1].key
						globalDB.runtimeUnitTestDebugOverlay = true
						globalDB.runtimeUnitTestShowOnlyOne = false
						globalDB.runtimeUnitTestHidePrimary = false
						globalDB.runtimeUnitTestCompactSpacing = false
						globalDB.runtimeUnitTestLargeSpacing = false
						globalDB.runtimeUnitTestMaxVisible = false
						ApplyRuntimeTestPreset()
					end
					self:RefreshRuntimeTestPreviews()
					UpdateTestMenu(self)
				end
			},
			{
				label = "Reload Previews",
				width = 120,
				onClick = function()
					self:RefreshRuntimeTestPreviews()
					UpdateTestMenu(self)
				end
			}
		})

		AddSectionHeader("Roster Presets")
		AddCycleRow("Roster Preset", "runtimeUnitTestPreset", RUNTIME_TEST_PRESETS, function()
			ApplyRuntimeTestPreset()
			SetRuntimeTestMode(true)
		end, "Party 5, raid 10/20/25/40, arena 3/5, and boss packs. Presets reset the enabled frame groups and their visible counts.")
		AddCycleRow("Nameplate Pack", "runtimeUnitTestNameplatePack", RUNTIME_TEST_NAMEPLATE_PACKS, function()
		end, "Controls the number of fake nameplates shown when the nameplate preview is enabled.")
		AddCycleRow("Nameplate Side", "runtimeUnitTestNameplateVariant", RUNTIME_TEST_NAMEPLATE_VARIANTS, function()
		end, "Switch the nameplate preview between enemy, friendly, or mixed packs to pressure-test reaction styling.")

		AddSectionHeader("Fake Data")
		AddCycleRow("Role / Class Distribution", "runtimeUnitTestClassDistribution", RUNTIME_TEST_CLASS_DISTRIBUTIONS, nil, "Mixed, all healers, melee-heavy, or duplicate-class rosters for class-color and sorting checks.")
		AddCycleRow("Health / State Scenario", "runtimeUnitTestHealthScenario", RUNTIME_TEST_HEALTH_SCENARIOS, nil, "Apply stable health, danger, offline, dead, out-of-range, or aggro states across the visible preview frames.")
		AddCycleRow("Aura / Debuff Scenario", "runtimeUnitTestAuraScenario", RUNTIME_TEST_AURA_SCENARIOS, nil, "Show dispellables, boss debuffs, mixed harmful effects, or helpful externals in the preview overlay.")
		AddCycleRow("Cast / Castbar Scenario", "runtimeUnitTestCastScenario", RUNTIME_TEST_CAST_SCENARIOS, nil, "Adds a fake castbar preview under the frame set for enemy casts, channels, locked casts, player casts, or boss abilities.")
		AddCycleRow("Mouseover Simulation", "runtimeUnitTestMouseoverMode", RUNTIME_TEST_MOUSEOVER_MODES, nil, "Force none, the first frame, or all visible frames into a simulated mouseover state.")

		AddSectionHeader("Layout Stress")
		AddCheckRow("Show Only One Unit", "runtimeUnitTestShowOnlyOne", "Collapse multi-unit previews down to a single unit so you can inspect edge spacing and header behavior.")
		AddCheckRow("Hide Primary Slot", "runtimeUnitTestHidePrimary", "Skip the first visible slot in multi-unit previews to mimic hidden player / missing lead slots.")
		AddCheckRow("Compact Spacing", "runtimeUnitTestCompactSpacing", "Halves the group growth offsets and spacing to pressure-test dense layouts.")
		AddCheckRow("Large Spacing", "runtimeUnitTestLargeSpacing", "Expands the group growth offsets and spacing to expose anchoring drift and overlap.")
		AddCheckRow("Max Visible", "runtimeUnitTestMaxVisible", "Forces enabled multi-unit sets to show their maximum supported count instead of the preset count.")

		AddSectionHeader("Frame Sets")
		AddDescription("Mix and match the exact frame families you want active in the lab. Presets give you a starting point, but these toggles remain fully manual.")
		local function AddSetGroup(defs)
			for _, def in ipairs(defs) do
				local btn = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
				btn:SetPoint("TOPLEFT", 12, y)
				btn.Text:SetText(def.label .. " (" .. def.key .. ")")
				btn:SetScript("OnClick", function(button)
					SetRuntimeTestSetEnabled(def.key, button:GetChecked() and true or false)
					if (button:GetChecked() and not IsRuntimeTestMode()) then
						SetRuntimeTestMode(true)
					else
						self:RefreshRuntimeTestPreviews()
					end
					UpdateTestMenu(self)
				end)
				frame.SetToggles[def.key] = btn
				y = y - 24
			end
			y = y - 8
		end

		AddSectionHeader("Single Frames")
		AddSetGroup({
			GetRuntimeTestDefinition("player"),
			GetRuntimeTestDefinition("playeralt"),
			GetRuntimeTestDefinition("castbar"),
			GetRuntimeTestDefinition("classpower"),
			GetRuntimeTestDefinition("pet"),
			GetRuntimeTestDefinition("target"),
			GetRuntimeTestDefinition("tot"),
			GetRuntimeTestDefinition("focus")
		})

		AddSectionHeader("Group Frames")
		AddSetGroup({
			GetRuntimeTestDefinition("boss"),
			GetRuntimeTestDefinition("party"),
			GetRuntimeTestDefinition("raid5"),
			GetRuntimeTestDefinition("raid25"),
			GetRuntimeTestDefinition("raid40"),
			GetRuntimeTestDefinition("arena")
		})

		AddSectionHeader("Special")
		AddSetGroup({
			GetRuntimeTestDefinition("nameplates")
		})

		AddSectionHeader("Overlay")
		AddCheckRow("Show Debug Overlay", "runtimeUnitTestDebugOverlay", "Displays role, class, state, health percentage, fake aura markers, and fake cast labels on the preview frames.")

		local footer = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		footer:SetPoint("TOPLEFT", 16, y)
		footer:SetWidth(560)
		footer:SetJustifyH("LEFT")
		footer:SetText("These previews are addon-side lab frames built from AzeriteUI styles. They are meant to test layout, colors, auras, cast visuals, spacing, and interaction logic without requiring real Blizzard roster units.")
		y = y - 40
		content:SetHeight(math_abs(y) + 40)

		local close = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
		close:SetSize(80, 22)
		close:SetPoint("BOTTOMRIGHT", -12, 12)
		close:SetText("Close")
		close:SetScript("OnClick", function() frame:Hide() end)

		self.TestFrame = frame
		created = true
	end

	if (created) then
		UpdateTestMenu(self)
		frame:Show()
		return
	end

	if (frame:IsShown()) then
		frame:Hide()
	else
		UpdateTestMenu(self)
		frame:Show()
	end
end

local function UpdateDebugMenu(self)
	local frame = self.DebugFrame
	if (not frame) then
		return
	end
	local filter = ns.API.DEBUG_HEALTH_FILTER
	if (not filter or filter == "") then
		filter = "Target."
		ns.API.DEBUG_HEALTH_FILTER = filter
		if (ns.db and ns.db.global) then
			ns.db.global.debugHealthFilter = filter
		end
	end
	frame.HealthToggle:SetChecked(ns.API.DEBUG_HEALTH and true or false)
	frame.HealthChatToggle:SetChecked(ns.API.DEBUG_HEALTH_CHAT and true or false)
	if (frame.BarsToggle) then
		frame.BarsToggle:SetChecked(_G.__AzeriteUI_DEBUG_BARS and true or false)
	end
	frame.FixesToggle:SetChecked((ns.db and ns.db.global and ns.db.global.debugFixes) and true or false)
	if (frame.KeyVerboseToggle) then
		frame.KeyVerboseToggle:SetChecked((ns.db and ns.db.global and ns.db.global.debugKeysVerbose) and true or false)
	end
	frame.FilterEdit:SetText(filter)
	if (frame.RaidBarStatus) then
		local forced = (ns.db and ns.db.global and ns.db.global.debugForceBlizzardRaidBar) and true or false
		local setting = (ns:GetModule("UnitFrames", true) and ns:GetModule("UnitFrames", true).db and ns:GetModule("UnitFrames", true).db.profile and ns:GetModule("UnitFrames", true).db.profile.showBlizzardRaidBar) and true or false
		local devMode = IsDevMode()
		frame.RaidBarStatus:SetText(string_format("Saved /az toggle: %s    Solo force-show: %s", setting and "|cff70ff70ON|r" or "|cffff7070OFF|r", forced and "|cff70ff70ON|r" or "|cffff7070OFF|r"))
		if (frame.RaidBarHint) then
			frame.RaidBarHint:SetText(devMode and "Use the buttons below for solo testing. /reload is still the safe refresh if Blizzard hid the bar earlier this session." or "Enable Dev Mode to use the solo force-show controls.")
		end
		if (frame.RaidBarOnButton and frame.RaidBarOffButton and frame.RaidBarToggleButton) then
			frame.RaidBarOnButton:SetEnabled(devMode)
			frame.RaidBarOffButton:SetEnabled(devMode)
			frame.RaidBarToggleButton:SetEnabled(devMode)
		end
	end
end

Debugging.ToggleDebugMenu = function(self)
	local frame = self.DebugFrame
	local created = false
	if (not frame) then
		frame = CreateFrame("Frame", "AzeriteUI_DebugMenu", UIParent, "BasicFrameTemplateWithInset")
		frame:SetSize(620, 840)
		frame:SetPoint("CENTER", UIParent, "CENTER", 0, 110)
		frame:SetFrameStrata("DIALOG")
		frame:SetClampedToScreen(true)
		frame:SetMovable(true)
		frame:EnableMouse(true)
		frame:RegisterForDrag("LeftButton")
		frame:SetScript("OnDragStart", function(f) f:StartMoving() end)
		frame:SetScript("OnDragStop", function(f) f:StopMovingOrSizing() end)
		frame.TitleText:SetText("AzeriteUI Debug")
		if (frame.NineSlice and frame.NineSlice.SetVertexColor) then
			frame.NineSlice:SetVertexColor(.78, .82, .90)
		end
		if (frame.Bg) then
			frame.Bg:SetColorTexture(.04, .05, .07, .96)
		end
		if (frame.Inset and frame.Inset.Bg) then
			frame.Inset.Bg:SetColorTexture(.07, .08, .11, .92)
		end

		local subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		subtitle:SetPoint("TOPLEFT", 16, -34)
		subtitle:SetText("Focused debug controls for health, dumps, utilities, and the Blizzard raid utility bar.")

		local function CreatePanel(parent, title, point, relPoint, x, y, width, height)
			local panel = CreateFrame("Frame", nil, parent, BackdropTemplateMixin and "BackdropTemplate")
			panel:SetPoint(point, parent, relPoint, x, y)
			panel:SetSize(width, height)
			if (panel.SetBackdrop) then
				panel:SetBackdrop({
					bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
					edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
					tile = true,
					tileSize = 8,
					edgeSize = 8,
					insets = { left = 2, right = 2, top = 2, bottom = 2 }
				})
				panel:SetBackdropColor(.09, .10, .14, .92)
				panel:SetBackdropBorderColor(.22, .26, .34, .95)
			end
			local label = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
			label:SetPoint("TOPLEFT", 12, -10)
			label:SetText(title)
			local accent = panel:CreateTexture(nil, "ARTWORK")
			accent:SetPoint("TOPLEFT", 12, -32)
			accent:SetPoint("TOPRIGHT", -12, -32)
			accent:SetHeight(1)
			accent:SetColorTexture(.26, .52, .84, .65)
			return panel
		end

		local function AddTooltip(widget, text)
			if (not text) then
				return
			end
			widget:SetScript("OnEnter", function(control)
				GameTooltip:SetOwner(control, "ANCHOR_RIGHT")
				GameTooltip:ClearLines()
				GameTooltip:AddLine(text, 1, 1, 1, true)
				GameTooltip:Show()
			end)
			widget:SetScript("OnLeave", function()
				GameTooltip:Hide()
			end)
		end

		local function AddCheckButton(parent, label, x, y, onClick, tooltip)
			local btn = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
			btn:SetPoint("TOPLEFT", x, y)
			btn.text:SetText(label)
			btn:SetScript("OnClick", onClick)
			AddTooltip(btn, tooltip)
			return btn
		end

		local function AddButton(parent, text, width, x, y, onClick, tooltip)
			local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
			btn:SetSize(width, 24)
			btn:SetPoint("TOPLEFT", x, y)
			btn:SetText(text)
			btn:SetScript("OnClick", onClick)
			AddTooltip(btn, tooltip)
			return btn
		end

		local leftPanel = CreatePanel(frame, "Flags", "TOPLEFT", "TOPLEFT", 12, -58, 286, 216)
		local rightPanel = CreatePanel(frame, "Raid Utility Bar", "TOPRIGHT", "TOPRIGHT", -12, -58, 310, 216)
		local lowerLeftPanel = CreatePanel(frame, "Dumps & Repairs", "TOPLEFT", "TOPLEFT", 12, -282, 286, 200)
		local lowerRightPanel = CreatePanel(frame, "Utilities", "TOPRIGHT", "TOPRIGHT", -12, -282, 310, 200)
		local bottomPanel = CreatePanel(frame, "Inspect & Snapshots", "TOPLEFT", "TOPLEFT", 12, -490, 596, 250)

		frame.HealthToggle = AddCheckButton(leftPanel, "Health debug", 12, -44, function()
			self:ToggleHealthDebug()
			UpdateDebugMenu(self)
			local pf = ns:GetModule("PlayerFrame", true)
			if pf and pf.Update then pf:Update() end
			local tf = ns:GetModule("TargetFrame", true)
			if tf and tf.Update then tf:Update() end
		end, "Show health debug overlay text on unitframes.")
		frame.HealthChatToggle = AddCheckButton(leftPanel, "Health debug chat", 12, -70, function()
			self:ToggleHealthDebugChat()
			UpdateDebugMenu(self)
			local pf = ns:GetModule("PlayerFrame", true)
			if pf and pf.Update then pf:Update() end
			local tf = ns:GetModule("TargetFrame", true)
			if tf and tf.Update then tf:Update() end
		end, "Print health/statusbar debug output to chat.")
		frame.BarsToggle = AddCheckButton(leftPanel, "Statusbar/orb debug", 12, -96, function()
			self:ToggleBarsDebug()
			UpdateDebugMenu(self)
		end, "Enable verbose bar/orb debug output in chat.")
		frame.FixesToggle = AddCheckButton(leftPanel, "FixBlizzardBugs debug", 12, -122, function()
			self:ToggleFixesDebug()
			UpdateDebugMenu(self)
			local pf = ns:GetModule("PlayerFrame", true)
			if pf and pf.Update then pf:Update() end
			local tf = ns:GetModule("TargetFrame", true)
			if tf and tf.Update then tf:Update() end
		end, "Enable FixBlizzardBugs debug counters in chat.")

		local filterTitle = leftPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		filterTitle:SetPoint("TOPLEFT", 12, -158)
		filterTitle:SetText("Health filter prefix")
		local filterDesc = leftPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		filterDesc:SetPoint("TOPLEFT", 12, -174)
		filterDesc:SetWidth(248)
		filterDesc:SetJustifyH("LEFT")
		filterDesc:SetText("Restrict health debug output to frame names that begin with this text.")

		frame.FilterEdit = CreateFrame("EditBox", nil, leftPanel, "InputBoxTemplate")
		frame.FilterEdit:SetSize(134, 20)
		frame.FilterEdit:SetPoint("TOPLEFT", 12, -196)
		frame.FilterEdit:SetAutoFocus(false)
		local currentFilter = ns.API.DEBUG_HEALTH_FILTER
		if (not currentFilter or currentFilter == "") then
			currentFilter = "Target."
		end
		frame.FilterEdit:SetText(currentFilter)
		frame.FilterEdit:SetScript("OnEnterPressed", function(edit)
			local text = edit:GetText()
			if (not text or text == "") then
				text = "Target."
			end
			ns.API.DEBUG_HEALTH_FILTER = text
			if (ns.db and ns.db.global) then
				ns.db.global.debugHealthFilter = text
			end
			edit:ClearFocus()
		end)
		AddButton(leftPanel, "Set", 54, 154, -196, function()
			local text = frame.FilterEdit:GetText()
			if (not text or text == "") then
				text = "Target."
			end
			ns.API.DEBUG_HEALTH_FILTER = text
			if (ns.db and ns.db.global) then
				ns.db.global.debugHealthFilter = text
			end
			frame.FilterEdit:SetText(text)
		end)
		AddButton(leftPanel, "Reset", 62, 214, -196, function()
			local text = "Target."
			ns.API.DEBUG_HEALTH_FILTER = text
			if (ns.db and ns.db.global) then
				ns.db.global.debugHealthFilter = text
			end
			frame.FilterEdit:SetText(text)
		end)

		local raidLead = rightPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		raidLead:SetPoint("TOPLEFT", 12, -44)
		raidLead:SetWidth(286)
		raidLead:SetJustifyH("LEFT")
		raidLead:SetText("The saved /az toggle controls the normal Blizzard raid utility bar behavior. The controls below add a dev-only solo force-show override for testing ready check and world markers.")
		frame.RaidBarStatus = rightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		frame.RaidBarStatus:SetPoint("TOPLEFT", 12, -88)
		frame.RaidBarStatus:SetWidth(286)
		frame.RaidBarStatus:SetJustifyH("LEFT")
		frame.RaidBarHint = rightPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		frame.RaidBarHint:SetPoint("TOPLEFT", 12, -110)
		frame.RaidBarHint:SetWidth(286)
		frame.RaidBarHint:SetJustifyH("LEFT")
		frame.RaidBarOnButton = AddButton(rightPanel, "Force On", 84, 12, -148, function()
			self:DebugMenu("raidbar on")
			UpdateDebugMenu(self)
		end, "Dev-only: force-show the Blizzard raid utility bar even while solo.")
		frame.RaidBarOffButton = AddButton(rightPanel, "Force Off", 84, 104, -148, function()
			self:DebugMenu("raidbar off")
			UpdateDebugMenu(self)
		end, "Disable the solo force-show override and return to normal behavior.")
		frame.RaidBarToggleButton = AddButton(rightPanel, "Toggle", 84, 196, -148, function()
			self:DebugMenu("raidbar toggle")
			UpdateDebugMenu(self)
		end, "Flip the solo force-show override.")
		AddButton(rightPanel, "Print Status", 104, 12, -178, function()
			self:DebugMenu("raidbar status")
		end, "Print the raidbar force-show state to chat.")
		AddButton(rightPanel, "Open /az", 84, 124, -178, function()
			local options = ns:GetModule("Options", true)
			if (options and options.OpenOptionsMenu) then
				options:OpenOptionsMenu()
			end
		end, "Open the main AzeriteUI options menu.")

		local dumpTarget = AddButton(lowerLeftPanel, "Dump Target Bars", 122, 12, -44, function()
			local targetFrame = ns:GetModule("TargetFrame", true)
			DumpUnitBars(targetFrame and targetFrame.frame, "TargetFrame")
		end)
		local dumpPlayer = AddButton(lowerLeftPanel, "Dump Player Bars", 122, 146, -44, function()
			local playerFrame = ns:GetModule("PlayerFrame", true)
			DumpUnitBars(playerFrame and playerFrame.frame, "PlayerFrame")
		end)
		local dumpToT = AddButton(lowerLeftPanel, "Dump ToT Bars", 122, 12, -74, function()
			local totFrame = ns:GetModule("ToTFrame", true)
			DumpUnitBars(totFrame and totFrame.frame, "ToTFrame")
		end)
		local dumpAll = AddButton(lowerLeftPanel, "Dump All Bars", 122, 146, -74, function()
			local targetFrame = ns:GetModule("TargetFrame", true)
			local playerFrame = ns:GetModule("PlayerFrame", true)
			local totFrame = ns:GetModule("ToTFrame", true)
			DumpUnitBars(targetFrame and targetFrame.frame, "TargetFrame")
			DumpUnitBars(playerFrame and playerFrame.frame, "PlayerFrame")
			DumpUnitBars(totFrame and totFrame.frame, "ToTFrame")
		end)
		local dumpHint = lowerLeftPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		dumpHint:SetPoint("TOPLEFT", 12, -108)
		dumpHint:SetWidth(258)
		dumpHint:SetJustifyH("LEFT")
		dumpHint:SetText("Repair buttons reattach the movement modules for health and castbar handles if a live frame lost them during testing.")

		local function ReattachMovementModules(unit)
			local mod = ns:GetModule(unit, true)
			if (mod and mod.frame) then
				if (mod.frame.Health and mod.frame.Health.AttachMovementModule) then
					mod.frame.Health:AttachMovementModule()
					print("|cff33ff99", unit .. " Healthbar movement module reattached.")
				end
				if (mod.frame.Castbar and mod.frame.Castbar.AttachMovementModule) then
					mod.frame.Castbar:AttachMovementModule()
					print("|cff33ff99", unit .. " Castbar movement module reattached.")
				end
			else
				print("|cff33ff99", unit .. " frame not found.")
			end
		end
		AddButton(lowerLeftPanel, "Reattach Player Bars", 122, 12, -144, function()
			ReattachMovementModules("PlayerFrame")
		end)
		AddButton(lowerLeftPanel, "Reattach Target Bars", 122, 146, -144, function()
			ReattachMovementModules("TargetFrame")
		end)

		AddButton(lowerRightPanel, "Print Status", 96, 12, -44, function()
			Debugging.DebugMenu(self, "status")
		end)
		AddButton(lowerRightPanel, "Help", 70, 116, -44, function()
			PrintDebugHelp()
		end)
		AddButton(lowerRightPanel, "Enable Blizzard AddOns", 152, 146, -44, function()
			self:EnableBlizzardAddOns()
		end)
		AddButton(lowerRightPanel, "Enable Script Errors", 152, 12, -74, function()
			self:EnableScriptErrors()
			print("|cff33ff99", "AzeriteUI script errors:", "ENABLED (CVar scriptErrors=1)")
		end)
		AddButton(lowerRightPanel, "Scale Status", 96, 172, -74, function()
			PrintScaleStatus()
		end)
		AddButton(lowerRightPanel, "Reset UnitFrame Scales", 152, 12, -104, function()
			ResetUnitFrameScales()
		end)

		local secretLabel = lowerRightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		secretLabel:SetPoint("TOPLEFT", 12, -146)
		secretLabel:SetText("Secret test unit")
		frame.SecretEdit = CreateFrame("EditBox", nil, lowerRightPanel, "InputBoxTemplate")
		frame.SecretEdit:SetSize(120, 20)
		frame.SecretEdit:SetPoint("TOPLEFT", 12, -166)
		frame.SecretEdit:SetAutoFocus(false)
		frame.SecretEdit:SetText("player")
		AddButton(lowerRightPanel, "Run Secret Test", 120, 140, -164, function()
			local unit = frame.SecretEdit:GetText()
			self:SecretValueTest(unit)
		end)

		local inspectLead = bottomPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		inspectLead:SetPoint("TOPLEFT", 12, -42)
		inspectLead:SetWidth(572)
		inspectLead:SetJustifyH("LEFT")
		inspectLead:SetText("These controls cover the remaining /azdebug inspection commands that need a unit token or a focused one-shot action.")

		local nameplateLabel = bottomPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		nameplateLabel:SetPoint("TOPLEFT", 12, -68)
		nameplateLabel:SetText("Nameplate unit")
		frame.NameplateUnitEdit = CreateFrame("EditBox", nil, bottomPanel, "InputBoxTemplate")
		frame.NameplateUnitEdit:SetSize(110, 20)
		frame.NameplateUnitEdit:SetPoint("LEFT", nameplateLabel, "RIGHT", 10, 0)
		frame.NameplateUnitEdit:SetAutoFocus(false)
		frame.NameplateUnitEdit:SetText("auto")
		AddButton(bottomPanel, "Cast Debug", 96, 252, -66, function()
			local token = frame.NameplateUnitEdit:GetText()
			if (not token or token == "" or token:lower() == "auto") then
				self:DebugMenu("nameplates")
			else
				self:DebugMenu("nameplates " .. token)
			end
		end, "Run /azdebug nameplates [unit]. Use auto or leave blank to inspect all active nameplates.")
		AddButton(bottomPanel, "Scale Debug", 96, 356, -66, function()
			local token = frame.NameplateUnitEdit:GetText()
			if (not token or token == "") then
				token = "auto"
			end
			self:DebugMenu("scale nameplates " .. token)
		end, "Run /azdebug scale nameplates [unit].")

		local snapshotLabel = bottomPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		snapshotLabel:SetPoint("TOPLEFT", 12, -98)
		snapshotLabel:SetText("Snapshot unit")
		frame.SnapshotUnitEdit = CreateFrame("EditBox", nil, bottomPanel, "InputBoxTemplate")
		frame.SnapshotUnitEdit:SetSize(110, 20)
		frame.SnapshotUnitEdit:SetPoint("LEFT", snapshotLabel, "RIGHT", 18, 0)
		frame.SnapshotUnitEdit:SetAutoFocus(false)
		frame.SnapshotUnitEdit:SetText("target")
		AddButton(bottomPanel, "Snapshot", 96, 252, -96, function()
			local unit = frame.SnapshotUnitEdit:GetText()
			if (not unit or unit == "") then
				unit = "target"
			end
			self:DebugMenu("snapshot " .. unit)
		end, "Run /azdebug snapshot [unit].")
		AddButton(bottomPanel, "Target Debug Menu", 130, 356, -96, function()
			self:ToggleTargetDebugMenu()
		end, "Open the dedicated target fill debug popup.")
		AddButton(bottomPanel, "Nameplate Scale Auto", 130, 448, -66, function()
			self:DebugMenu("scale nameplates auto")
		end, "Run /azdebug scale nameplates auto.")
		AddButton(bottomPanel, "All Nameplates", 130, 448, -96, function()
			self:DebugMenu("nameplates")
		end, "Run /azdebug nameplates with no unit filter.")

		local keyLead = bottomPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		keyLead:SetPoint("TOPLEFT", 12, -144)
		keyLead:SetText("Key debug")
		frame.KeyVerboseToggle = AddCheckButton(bottomPanel, "Verbose", 86, -140, function()
			self:DebugKeysMenu("toggle")
			UpdateDebugMenu(self)
		end, "Toggle /azdebug keys verbose output.")
		AddButton(bottomPanel, "Status", 84, 180, -138, function()
			self:DebugKeysMenu("status")
		end, "Run /azdebug keys status.")
		AddButton(bottomPanel, "Bindings", 84, 272, -138, function()
			self:DebugKeysMenu("bindings")
		end, "Run /azdebug keys bindings.")

		local keyButtonLabel = bottomPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		keyButtonLabel:SetPoint("TOPLEFT", 12, -184)
		keyButtonLabel:SetText("Button")
		frame.KeyButtonEdit = CreateFrame("EditBox", nil, bottomPanel, "InputBoxTemplate")
		frame.KeyButtonEdit:SetSize(106, 20)
		frame.KeyButtonEdit:SetPoint("LEFT", keyButtonLabel, "RIGHT", 8, 0)
		frame.KeyButtonEdit:SetAutoFocus(false)
		frame.KeyButtonEdit:SetText("")
		AddButton(bottomPanel, "Cooldown", 84, 180, -182, function()
			local buttonName = frame.KeyButtonEdit:GetText()
			if (buttonName and buttonName ~= "") then
				self:DebugKeysMenu("cooldown " .. buttonName)
			else
				self:DebugKeysMenu("cooldown")
			end
		end, "Run /azdebug keys cooldown [buttonName].")

		local holdLabel = bottomPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		holdLabel:SetPoint("TOPLEFT", 280, -184)
		holdLabel:SetText("SpellID")
		frame.HoldSpellEdit = CreateFrame("EditBox", nil, bottomPanel, "InputBoxTemplate")
		frame.HoldSpellEdit:SetSize(88, 20)
		frame.HoldSpellEdit:SetPoint("LEFT", holdLabel, "RIGHT", 8, 0)
		frame.HoldSpellEdit:SetAutoFocus(false)
		frame.HoldSpellEdit:SetText("")
		AddButton(bottomPanel, "Hold Test", 84, 468, -182, function()
			local spellID = frame.HoldSpellEdit:GetText()
			if (spellID and spellID ~= "") then
				self:DebugKeysMenu("holdtest " .. spellID)
			else
				self:DebugKeysMenu("holdtest")
			end
		end, "Run /azdebug keys holdtest [spellID].")

		local close = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
		close:SetSize(88, 24)
		close:SetPoint("BOTTOMRIGHT", -12, 12)
		close:SetText("Close")
		close:SetScript("OnClick", function() frame:Hide() end)

		self.DebugFrame = frame
		created = true
	end

	if (created) then
		UpdateDebugMenu(self)
		frame:Show()
		return
	end

	if (frame:IsShown()) then
		frame:Hide()
	else
		UpdateDebugMenu(self)
		frame:Show()
	end
end

local function UpdateTargetDebugMenu(self)
	return
end

Debugging.ToggleTargetDebugMenu = function(self)
	local frame = self.TargetDebugFrame
	local created = false
	if (not frame) then
		frame = CreateFrame("Frame", "AzeriteUI_TargetDebugMenu", UIParent, "BasicFrameTemplateWithInset")
		frame:SetSize(520, 240)
		frame:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
		frame:SetFrameStrata("DIALOG")
		frame:SetClampedToScreen(true)
		frame:SetMovable(true)
		frame:EnableMouse(true)
		frame:RegisterForDrag("LeftButton")
		frame:SetScript("OnDragStart", function(f) f:StartMoving() end)
		frame:SetScript("OnDragStop", function(f) f:StopMovingOrSizing() end)
		frame.TitleText:SetText("AzeriteUI Target Debug")
		local actionsY = -52
		local actionsHeader = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
		actionsHeader:SetPoint("TOPLEFT", 12, actionsY)
		actionsHeader:SetText("Actions")
		actionsY = actionsY - 26

		local statusBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
		statusBtn:SetSize(120, 22)
		statusBtn:SetPoint("TOPLEFT", 12, actionsY)
		statusBtn:SetText("Print Status")
		statusBtn:SetScript("OnClick", function()
			self:TargetDebugMenu("status")
		end)

		local refreshBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
		refreshBtn:SetSize(120, 22)
		refreshBtn:SetPoint("LEFT", statusBtn, "RIGHT", 8, 0)
		refreshBtn:SetText("Force Refresh")
		refreshBtn:SetScript("OnClick", function()
			RefreshTargetDebugTestFrames()
			print("|cff33ff99", "AzeriteUI target fill debug:", "target frame refreshed")
		end)

		local dumpBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
		dumpBtn:SetSize(120, 22)
		dumpBtn:SetPoint("LEFT", refreshBtn, "RIGHT", 8, 0)
		dumpBtn:SetText("Dump Target")
		dumpBtn:SetScript("OnClick", function()
			self:DebugMenu("dump target")
		end)

		local snapshotBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
		snapshotBtn:SetSize(120, 22)
		snapshotBtn:SetPoint("TOPLEFT", 12, actionsY - 28)
		snapshotBtn:SetText("Snapshot Target")
		snapshotBtn:SetScript("OnClick", function()
			self:DebugMenu("snapshot target")
		end)

		local secretBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
		secretBtn:SetSize(120, 22)
		secretBtn:SetPoint("LEFT", snapshotBtn, "RIGHT", 8, 0)
		secretBtn:SetText("Secret Test")
		secretBtn:SetScript("OnClick", function()
			self:SecretValueTest("target")
		end)

		local helpBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
		helpBtn:SetSize(120, 22)
		helpBtn:SetPoint("LEFT", secretBtn, "RIGHT", 8, 0)
		helpBtn:SetText("Print Help")
		helpBtn:SetScript("OnClick", function()
			self:TargetDebugMenu("help")
		end)

		local close = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
		close:SetSize(80, 22)
		close:SetPoint("BOTTOMRIGHT", -12, 12)
		close:SetText("Close")
		close:SetScript("OnClick", function() frame:Hide() end)

		self.TargetDebugFrame = frame
		created = true
	end

	if (created) then
		UpdateTargetDebugMenu(self)
		frame:Show()
		return
	end

	if (frame:IsShown()) then
		frame:Hide()
	else
		UpdateTargetDebugMenu(self)
		frame:Show()
	end
end

Debugging.TargetDebugMenu = function(self, input)
	if (not IsDevMode()) then
		print("|cff33ff99", "AzeriteUI /azdebugtarget:", "Dev mode is off; limited features may apply.")
	end
	if (not input or input == "") then
		return self:ToggleTargetDebugMenu()
	end
	local cmd, rest = input:match("^(%S+)%s*(.-)$")
	cmd = cmd and cmd:lower() or "status"
	if (cmd == "menu") then
		return self:ToggleTargetDebugMenu()
	end
	if (cmd == "help" or cmd == "?") then
		print("|cff33ff99", "AzeriteUI /azdebugtarget commands:")
		print("|cfff0f0f0  /azdebugtarget|r  (toggle menu)")
		print("|cfff0f0f0  /azdebugtarget status|r")
		print("|cfff0f0f0  /azdebugtarget dump|snapshot|refresh|secrettest|r")
		return
	end
	if (cmd == "status") then
		return PrintTargetFillDebugStatus()
	end
	if (cmd == "dump") then
		return self:DebugMenu("dump target")
	end
	if (cmd == "snapshot") then
		return self:DebugMenu("snapshot target")
	end
	if (cmd == "refresh") then
		RefreshTargetDebugTestFrames()
		print("|cff33ff99", "AzeriteUI target fill debug:", "target frame refreshed")
		return
	end
	if (cmd == "secrettest") then
		return self:SecretValueTest("target")
	end
	return self:TargetDebugMenu("help")
end

Debugging.DebugMenu = function(self, input)
	if (not IsDevMode()) then
		print("|cff33ff99", "AzeriteUI /azdebug:", "Dev mode is off; limited features may apply.")
	end
	if (not input or input == "") then
		return self:ToggleDebugMenu()
	end
	local cmd, rest = input:match("^(%S+)%s*(.-)$")
	cmd = cmd and cmd:lower() or "status"
	if (cmd == "menu") then
		return self:ToggleDebugMenu()
	end
	if (cmd == "help" or cmd == "?") then
		return PrintDebugHelp()
	end
	if (cmd == "status") then
		local filter = ns.API.DEBUG_HEALTH_FILTER
		if (not filter or filter == "") then
			filter = "Target."
		end
		print("|cff33ff99", "AzeriteUI debug status:")
		print("|cfff0f0f0  health:", ns.API.DEBUG_HEALTH and "ON" or "OFF", "filter:", filter)
		print("|cfff0f0f0  healthchat:", ns.API.DEBUG_HEALTH_CHAT and "ON" or "OFF")
		print("|cfff0f0f0  bars:", (_G.__AzeriteUI_DEBUG_BARS and "ON" or "OFF"))
		print("|cfff0f0f0  raidbar force:", (ns.db and ns.db.global and ns.db.global.debugForceBlizzardRaidBar) and "ON" or "OFF")
		print("|cfff0f0f0  fixes:", (ns.db and ns.db.global and ns.db.global.debugFixes) and "ON" or "OFF")
		return
	end
	if (cmd == "raidbar") then
		if (not IsDevMode()) then
			print("|cff33ff99", "AzeriteUI /azdebug raidbar:", "Dev mode is required for solo force-show.")
			return
		end
		if (rest == nil or rest == "" or rest == "status") then
			print("|cff33ff99", "AzeriteUI debug raidbar force:", (ns.db and ns.db.global and ns.db.global.debugForceBlizzardRaidBar) and "ON" or "OFF")
			return
		end
		local mode = ParseOnOffToggle(rest)
		if (not mode) then
			return PrintDebugHelp()
		end
		if (ns.db and ns.db.global) then
			ns.db.global.debugForceBlizzardRaidBar = SetDebugFlag(ns.db.global.debugForceBlizzardRaidBar, mode)
		end
		if (ns.WoW12BlizzardQuarantine and ns.WoW12BlizzardQuarantine.ApplyCompactFrames) then
			ns.WoW12BlizzardQuarantine.ApplyCompactFrames()
		end
		print("|cff33ff99", "AzeriteUI debug raidbar force:", (ns.db and ns.db.global and ns.db.global.debugForceBlizzardRaidBar) and "ON" or "OFF")
		print("|cff33ff99", "Tip:", "Use /reload if Blizzard already hid the bar earlier this session.")
		return
	end
	if (cmd == "keys") then
		return self:DebugKeysMenu(rest)
	end
	if (cmd == "health") then
		local sub, arg = rest:match("^(%S+)%s*(.-)$")
		sub = sub and sub:lower()
		if (sub == "filter") then
			if (arg and arg ~= "") then
				ns.API.DEBUG_HEALTH_FILTER = arg
				if (ns.db and ns.db.global) then
					ns.db.global.debugHealthFilter = arg
				end
				print("|cff33ff99", "AzeriteUI health debug filter:", arg)
			else
				print("|cff33ff99", "AzeriteUI health debug filter:", ns.API.DEBUG_HEALTH_FILTER or "Target.")
			end
			return
		end
		local mode = ParseOnOffToggle(sub)
		if (not mode) then
			return PrintDebugHelp()
		end
		ns.API.DEBUG_HEALTH = SetDebugFlag(ns.API.DEBUG_HEALTH, mode)
		if (ns.db and ns.db.global) then
			ns.db.global.debugHealth = ns.API.DEBUG_HEALTH
		end
		print("|cff33ff99", "AzeriteUI health debug:", ns.API.DEBUG_HEALTH and "ON" or "OFF")
		local oUF = ns.oUF
		if (oUF and oUF.objects) then
			for _, obj in next, oUF.objects do
				local dbg = obj.HealthDebug
				if (dbg) then
					if (ns.API.DEBUG_HEALTH) then dbg:Show() else dbg:Hide() end
				end
			end
		end
		return
	end
	if (cmd == "healthchat") then
		local mode = ParseOnOffToggle(rest)
		if (not mode) then
			return PrintDebugHelp()
		end
		ns.API.DEBUG_HEALTH_CHAT = SetDebugFlag(ns.API.DEBUG_HEALTH_CHAT, mode)
		if (ns.db and ns.db.global) then
			ns.db.global.debugHealthChat = ns.API.DEBUG_HEALTH_CHAT
		end
		print("|cff33ff99", "AzeriteUI health debug chat:", ns.API.DEBUG_HEALTH_CHAT and "ON" or "OFF")
		return
	end
	if (cmd == "bars") then
		local mode = ParseOnOffToggle(rest)
		if (not mode) then
			return PrintDebugHelp()
		end
		_G.__AzeriteUI_DEBUG_BARS = SetDebugFlag(_G.__AzeriteUI_DEBUG_BARS and true or false, mode)
		if (ns.db and ns.db.global) then
			ns.db.global.debugBars = _G.__AzeriteUI_DEBUG_BARS and true or false
		end
		print("|cff33ff99", "AzeriteUI statusbar/orb debug:", _G.__AzeriteUI_DEBUG_BARS and "ON" or "OFF")
		print("|cff33ff99", "Tip:", "Reproduce damage/retarget; logs will appear in chat.")
		return
	end
	if (cmd == "fixes") then
		local mode = ParseOnOffToggle(rest)
		if (not mode) then
			return PrintDebugHelp()
		end
		if (ns.db and ns.db.global) then
			ns.db.global.debugFixes = SetDebugFlag(ns.db.global.debugFixes, mode)
			print("|cff33ff99", "AzeriteUI FixBlizzardBugs debug:", ns.db.global.debugFixes and "ON" or "OFF")
		end
		return
	end
	if (cmd == "dump") then
		local sub = rest:match("^(%S+)")
		if (sub and sub:lower() == "target") then
			local targetFrame = ns:GetModule("TargetFrame", true)
			return DumpUnitBars(targetFrame and targetFrame.frame, "TargetFrame")
		end
		if (sub and sub:lower() == "player") then
			local playerFrame = ns:GetModule("PlayerFrame", true)
			return DumpUnitBars(playerFrame and playerFrame.frame, "PlayerFrame")
		end
		if (sub and (sub:lower() == "tot" or sub:lower() == "targetoftarget")) then
			local totFrame = ns:GetModule("ToTFrame", true)
			return DumpUnitBars(totFrame and totFrame.frame, "ToTFrame")
		end
		if (sub and sub:lower() == "all") then
			local targetFrame = ns:GetModule("TargetFrame", true)
			local playerFrame = ns:GetModule("PlayerFrame", true)
			local totFrame = ns:GetModule("ToTFrame", true)
			DumpUnitBars(targetFrame and targetFrame.frame, "TargetFrame")
			DumpUnitBars(playerFrame and playerFrame.frame, "PlayerFrame")
			return DumpUnitBars(totFrame and totFrame.frame, "ToTFrame")
		end
		return PrintDebugHelp()
	end
	if (cmd == "aurasnapshot" or cmd == "auras") then
		local sub = rest:match("^(%S+)") or "both"
		return DumpAuraSnapshot(sub)
	end
	if (cmd == "nameplates" or cmd == "nameplate") then
		local unit = rest:match("^(%S+)")
		return PrintNamePlateCastDebug(unit)
	end
	if (cmd == "snapshot") then
		local unit = rest:match("^(%S+)")
		return DumpUnitSnapshot(unit)
	end
	if (cmd == "blizzard") then
		local sub = rest:match("^(%S+)")
		if (sub and sub:lower() == "enable") then
			return self:EnableBlizzardAddOns()
		end
		return PrintDebugHelp()
	end
	if (cmd == "scale") then
		local sub, arg = rest:match("^(%S+)%s*(.-)$")
		sub = sub and sub:lower()
		if (sub and sub:lower() == "reset") then
			return ResetUnitFrameScales()
		end
		if (sub == "nameplates" or sub == "nameplate") then
			local token = (arg and arg ~= "") and arg or "auto"
			return PrintNamePlateScaleStatus(token)
		end
		return PrintScaleStatus()
	end
	if (cmd == "scripterrors") then
		self:EnableScriptErrors()
		print("|cff33ff99", "AzeriteUI script errors:", "ENABLED (CVar scriptErrors=1)")
		return
	end
	if (cmd == "secrettest") then
		return self:SecretValueTest(rest)
	end

	PrintDebugHelp()
end

Debugging.ToggleBarsDebug = function(self)
	local current = _G.__AzeriteUI_DEBUG_BARS and true or false
	_G.__AzeriteUI_DEBUG_BARS = not current
	if (ns.db and ns.db.global) then
		ns.db.global.debugBars = _G.__AzeriteUI_DEBUG_BARS
	end
	print("|cff33ff99", "AzeriteUI statusbar/orb debug:", _G.__AzeriteUI_DEBUG_BARS and "ON" or "OFF")
	print("|cff33ff99", "Tip:", "Reproduce damage/retarget; logs will appear in chat.")
end

Debugging.ToggleFixesDebug = function(self)
	if (not IsDevMode()) then
		print("|cff33ff99", "AzeriteUI FixBlizzardBugs debug:", "Dev mode only")
		return
	end
	if (ns.db and ns.db.global) then
		ns.db.global.debugFixes = not ns.db.global.debugFixes
		print("|cff33ff99", "AzeriteUI FixBlizzardBugs debug:", ns.db.global.debugFixes and "ON" or "OFF")
	end
end

Debugging.SecretValueTest = function(self, input)
	if (not IsDevMode()) then
		print("|cff33ff99", "AzeriteUI secret test:", "Dev mode only")
		return
	end
	local unit = (type(input) == "string" and input ~= "" and input) or "target"
	if (not UnitExists(unit)) then
		print("|cff33ff99", "AzeriteUI secret test:", "unit unavailable:", tostring(unit))
		return
	end
	local health = UnitHealth and UnitHealth(unit)
	local maxHealth = UnitHealthMax and UnitHealthMax(unit)
	local powerType = UnitPowerType and select(1, UnitPowerType(unit)) or 0
	local power = UnitPower and UnitPower(unit, powerType)
	local maxPower = UnitPowerMax and UnitPowerMax(unit, powerType)
	print("|cff33ff99", "AzeriteUI secret test:", unit)
	print("|cfff0f0f0  health:", tostring(health), "max:", tostring(maxHealth), "secret:", tostring(issecretvalue and issecretvalue(health) or false))
	print("|cfff0f0f0  power:", tostring(power), "max:", tostring(maxPower), "type:", tostring(powerType), "secret:", tostring(issecretvalue and issecretvalue(power) or false))
end

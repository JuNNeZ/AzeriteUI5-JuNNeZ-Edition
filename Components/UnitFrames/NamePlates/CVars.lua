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
-- Nameplates, 3 of 10: the console variables the driver owns, the zone's alpha among them.
-- Loaded after Classification.lua; see Settings.lua for how these files share their locals.
local _, ns = ...

local NP = ns.NamePlatesPrivate
if (not NP) then return end

local API = ns.API
local ipairs = ipairs
local next = next
local select = select
local tostring = tostring
local unpack = unpack

local NamePlatesMod = NP.NamePlatesMod
local GLOBAL_NAMEPLATE_BLIZZARD_SCALE_DEFAULT = NP.GLOBAL_NAMEPLATE_BLIZZARD_SCALE_DEFAULT
local NAMEPLATE_MAX_DISTANCE_DEFAULT = NP.NAMEPLATE_MAX_DISTANCE_DEFAULT
local GLOBAL_NAMEPLATE_SELECTED_SCALE_NEUTRAL = NP.GLOBAL_NAMEPLATE_SELECTED_SCALE_NEUTRAL
local GLOBAL_NAMEPLATE_MIN_SCALE = NP.GLOBAL_NAMEPLATE_MIN_SCALE
local GLOBAL_NAMEPLATE_MAX_SCALE = NP.GLOBAL_NAMEPLATE_MAX_SCALE
local GLOBAL_NAMEPLATE_LARGER_SCALE = NP.GLOBAL_NAMEPLATE_LARGER_SCALE
local IsFriendlyPlayerNameOnlyEnabled = NP.IsFriendlyPlayerNameOnlyEnabled
local IsUsingBlizzardGlobalScale = NP.IsUsingBlizzardGlobalScale
local GetBlizzardNamePlateGlobalScale = NP.GetBlizzardNamePlateGlobalScale
local GetNamePlateMaxDistanceSetting = NP.GetNamePlateMaxDistanceSetting
local GetCurrentContentType = NP.GetCurrentContentType
local GetContentSetting = NP.GetContentSetting

local cvars

-- Whether the client has a console variable at all. Blizzard's own settings ask this way
-- (Blizzard_SettingsDefinitions_Frame/Nameplates.lua, `if C_CVar.GetCVar(name) then`), and Platynator
-- asks C_CVar.GetCVarInfo before each write. Retail 12 dropped a dozen nameplate CVars this module wrote.
local CVarExists = function(name)
	if (type(name) ~= "string" or name == "") then
		return false
	end
	if (C_CVar and C_CVar.GetCVar) then
		return C_CVar.GetCVar(name) ~= nil
	end
	if (type(GetCVar) == "function") then
		return GetCVar(name) ~= nil
	end
	return false
end

local SetCVarIfSupported = function(name, value)
	if (not name or value == nil or not CVarExists(name)) then
		return
	end
	local stringValue = tostring(value)
	if (C_CVar and C_CVar.SetCVar) then
		if (API.TryCall(C_CVar.SetCVar, name, stringValue)) then
			return
		end
	end
	if (type(SetCVar) == "function") then
		API.SafeCall("NamePlates.SetCVar." .. tostring(name), SetCVar, name, stringValue)
	end
end

local GetCVarBoolIfSupported = function(name, defaultValue)
	if (not name) then
		return defaultValue
	end
	if (C_CVar and C_CVar.GetCVarBool) then
		local value = C_CVar.GetCVarBool(name)
		if (type(value) == "boolean") then
			return value
		end
	end
	if (type(GetCVarBool) == "function") then
		local value = GetCVarBool(name)
		if (value ~= nil) then
			return value and true or false
		end
	end
	return defaultValue
end

local ApplyFriendlyNameOnlyCVars = function()
	local enabled = IsFriendlyPlayerNameOnlyEnabled()
	SetCVarIfSupported("nameplateShowOnlyNameForFriendlyPlayerUnits", enabled and "1" or "0")
	SetCVarIfSupported("nameplateUseClassColorForFriendlyPlayerUnitNames", enabled and "1" or "0")
	-- Keep all nameplates at stable, readable scale regardless of distance.
	SetCVarIfSupported("nameplateMinScale", tostring(GLOBAL_NAMEPLATE_MIN_SCALE))
	SetCVarIfSupported("nameplateMaxScale", tostring(GLOBAL_NAMEPLATE_MAX_SCALE))
	SetCVarIfSupported("nameplateLargerScale", tostring(GLOBAL_NAMEPLATE_LARGER_SCALE))
	-- Neutralize Blizzard target scaling; we apply target scaling ourselves per relation.
	SetCVarIfSupported("nameplateSelectedScale", tostring(GLOBAL_NAMEPLATE_SELECTED_SCALE_NEUTRAL))
end

-- Alpha that depends on where you are: the current content's settings (Content settings; their
-- defaults are the values this used to hardcode per zone). It belongs in the driver's CVars: applied
-- on its own it was overwritten by the next driver refresh.
local GetZoneAlphaCVars = function()
	local contentType = GetCurrentContentType()
	return GetContentSetting(contentType, "minAlpha"), GetContentSetting(contentType, "occludedAlpha")
end

-- The Position setting as the game's nameplateOtherAtBase: 0 over the head, 2 at the feet (1 is both,
-- which Plater offers; Plater_OptionsPanel.lua). Forced to 0 with no way to change it until 2026-09-25.
local GetPlatePositionCVarValue = function()
	local profile = NamePlatesMod.db and NamePlatesMod.db.profile
	return (profile and profile.platePosition == "feet") and 2 or 0
end

local GetDriverCVars = function()
	local values = {}
	for key, value in next, cvars do
		values[key] = value
	end
	if (IsUsingBlizzardGlobalScale()) then
		values["nameplateGlobalScale"] = GetBlizzardNamePlateGlobalScale()
	else
		values["nameplateGlobalScale"] = GLOBAL_NAMEPLATE_BLIZZARD_SCALE_DEFAULT
	end
	local distance = GetNamePlateMaxDistanceSetting()
	values["nameplateMaxDistance"] = distance
	-- Other players' plates have a distance of their own (default 60), which Maximum distance never reached.
	values["nameplatePlayerMaxDistance"] = distance
	values["nameplateOtherAtBase"] = GetPlatePositionCVarValue()
	values["nameplateMinAlpha"], values["nameplateOccludedAlphaMult"] = GetZoneAlphaCVars()
	-- Only the ones this client has: oUF writes the table as it is (Libs/oUF/ouf.lua, updateDriver).
	for key in next, values do
		if (not CVarExists(key)) then
			values[key] = nil
		end
	end
	return values
end

local ApplyNamePlateDriverSettings = function(self)
	local driver = self and self.namePlateDriver
	if (not driver) then
		return
	end
	if (InCombatLockdown()) then
		self.pendingDriverRefresh = true
		return
	end

	local db = ns.GetConfig("NamePlates")
	if (driver.SetSize) then
		driver:SetSize(unpack(db.Size))
	end
	if (driver.SetCVars) then
		driver:SetCVars(GetDriverCVars())
	end

	self.pendingDriverRefresh = nil
end

-- What the driver writes, less any the client does not have (GetDriverCVars). Retail 12.1 and Forever
-- 1.60.1 have neither the insets, nameplateResourceOnTarget, clampTargetNameplateToScreen, nor the
-- global, larger, horizontal and vertical scales; they stay for a client that does.
cvars = {
	-- If these are enabled the GameTooltip will become protected,
	-- and all sort of taints and bugs will occur.
	-- This happens on specs that can dispel when hovering over nameplate auras.
	-- We create our own auras anyway, so we don't need these.
	["nameplateShowDebuffsOnFriendly"] = 0,
	["nameplateResourceOnTarget"] = 0, -- Don't show this crap.

	["nameplateLargeTopInset"] = .1, -- default .1, diabolic .15
	["nameplateOtherTopInset"] = .1, -- default .08, diabolic .15
	["nameplateLargeBottomInset"] = .04, -- default .15, diabolic .15
	["nameplateOtherBottomInset"] = .04, -- default .1, diabolic .15
	["nameplateClassResourceTopInset"] = 0,
	-- nameplateOtherAtBase is the Position setting: see GetPlatePositionCVarValue.

	-- new CVar July 14th 2020. Wohoo! Thanks torhaala for telling me! :)
	-- *has no effect in retail. probably for the classics only.
	["clampTargetNameplateToScreen"] = 1,

	-- Nameplate scale
	["nameplateGlobalScale"] = GLOBAL_NAMEPLATE_BLIZZARD_SCALE_DEFAULT,
	["nameplateLargerScale"] = GLOBAL_NAMEPLATE_LARGER_SCALE,
	["NamePlateHorizontalScale"] = 1,
	["NamePlateVerticalScale"] = 1,

	-- The max distance to show nameplates.
	-- *this value can be set by the user, and all other values are relative to this one.
	["nameplateMaxDistance"] = NAMEPLATE_MAX_DISTANCE_DEFAULT,

	-- The maximum distance from the camera (not char) where plates will still have max scale
	["nameplateMaxScaleDistance"] = 10,

	-- The distance from the max distance that nameplates will reach their minimum scale.
	["nameplateMinScaleDistance"] = 5,

	["nameplateMaxScale"] = GLOBAL_NAMEPLATE_MAX_SCALE, -- The max scale of nameplates.
	["nameplateMinScale"] = GLOBAL_NAMEPLATE_MIN_SCALE, -- Keep readable non-target plate scale.
	["nameplateSelectedScale"] = GLOBAL_NAMEPLATE_SELECTED_SCALE_NEUTRAL, -- Neutralized; target scaling handled in frame math.
	-- Neutralized too. Blizzard's plate runs on under ours, and for a type ticked under Simplified in its
	-- Options (friendly NPCs and friendly players among them) it has the engine scale the whole plate,
	-- ours with it, by this (C_NamePlateManager.SetNamePlateSimplified; registry default .3). The size
	-- sliders decide instead.
	["nameplateSimplifiedScale"] = 1,

	-- The distance from the camera that nameplates will reach their maximum alpha.
	["nameplateMaxAlphaDistance"] = 10,

	-- The distance from the max distance that nameplates will reach their minimum alpha.
	["nameplateMinAlphaDistance"] = 5,

	["nameplateMaxAlpha"] = 1, -- The max alpha of nameplates.
	-- nameplateMinAlpha and nameplateOccludedAlphaMult depend on the zone: see GetZoneAlphaCVars.
	["nameplateSelectedAlpha"] = 1, -- Alpha multiplier of targeted nameplate

	-- The max distance to show the target nameplate when the target is behind the camera.
	["nameplateTargetBehindMaxDistance"] = 15, -- 15

}

-- Blizzard's "stacking nameplates" option, passed through as it is: AzeriteUI stores nothing and
-- never sets it on its own. One bitfield CVar with a bit per kind of plate, the bits being
-- Enum.NamePlateStackType values (Blizzard_SettingsDefinitions_Frame/Nameplates.lua reads them the
-- same way). A write in combat waits for it to end, like the driver's CVars.
local STACKING_CVAR = "nameplateStackingTypes"
local STACKING_FALLBACK_BITS = { enemy = 1, friendly = 2 }

local GetStackingBit = function(kind)
	local types = Enum and Enum.NamePlateStackType
	if (kind == "enemy") then
		return types and types.Enemy or STACKING_FALLBACK_BITS.enemy
	elseif (kind == "friendly") then
		return types and types.Friendly or STACKING_FALLBACK_BITS.friendly
	end
end

local IsNamePlateStackingSupported = function()
	return (C_CVar and C_CVar.GetCVarBitfield and C_CVar.SetCVarBitfield and C_CVar.GetCVar
		and C_CVar.GetCVar(STACKING_CVAR) ~= nil) and true or false
end

-- nil where the client has no such setting.
local GetNamePlateStacking = function(kind)
	local index = GetStackingBit(kind)
	if (not index or not IsNamePlateStackingSupported()) then
		return nil
	end
	local ok, value = API.TryCall(C_CVar.GetCVarBitfield, STACKING_CVAR, index)
	if (not ok or type(value) ~= "boolean") then
		return nil
	end
	return value
end

local SetNamePlateStacking = function(self, kind, enabled)
	local index = GetStackingBit(kind)
	if (not index or not IsNamePlateStackingSupported()) then
		return
	end
	if (InCombatLockdown()) then
		self.pendingStacking = self.pendingStacking or {}
		self.pendingStacking[kind] = enabled and true or false
		return
	end
	-- Guarded and reported: the client refuses a CVar it flags secure, and that cannot be known here.
	API.SafeCall("NamePlates.SetCVarBitfield." .. kind, C_CVar.SetCVarBitfield, STACKING_CVAR, index, enabled and true or false)
end

local ApplyPendingNamePlateStacking = function(self)
	local pending = self.pendingStacking
	if (not pending or InCombatLockdown()) then
		return
	end
	self.pendingStacking = nil
	for kind, enabled in next, pending do
		SetNamePlateStacking(self, kind, enabled)
	end
end

-- Blizzard's settings for which nameplates show, each by the first of its names the client has: Retail
-- 12.1 and Forever 1.60.1 renamed the friendly two (Blizzard_SettingsDefinitions_Frame/Nameplates.lua).
-- The plates follow them (Visibility.lua), and the options page passes them through as it does stacking:
-- AzeriteUI stores nothing and never sets them on its own. A write in combat waits for it to end.
local VISIBILITY_CVARS = {
	showAll = { "nameplateShowAll" },
	enemies = { "nameplateShowEnemies" },
	friendlyPlayers = { "nameplateShowFriendlyPlayers", "nameplateShowFriends" },
	friendlyNPCs = { "nameplateShowFriendlyNpcs", "nameplateShowFriendlyNPCs" }
}

-- nil where the client has none of its names.
local GetVisibilityCVarName = function(kind)
	local names = VISIBILITY_CVARS[kind]
	if (not names) then
		return nil
	end
	for _, name in ipairs(names) do
		if (CVarExists(name)) then
			return name
		end
	end
	return nil
end

-- Whether Blizzard's setting shows that kind of plate. A setting the client does not have hides nothing.
local IsShownByBlizzard = function(kind)
	local name = GetVisibilityCVarName(kind)
	if (not name) then
		return true
	end
	return GetCVarBoolIfSupported(name, true)
end

local SetVisibilitySetting = function(self, kind, enabled)
	local name = GetVisibilityCVarName(kind)
	if (not name) then
		return
	end
	if (InCombatLockdown()) then
		self.pendingVisibility = self.pendingVisibility or {}
		self.pendingVisibility[kind] = enabled and true or false
		return
	end
	-- Guarded and reported, as stacking is. CVAR_UPDATE lays the plates out again (Module.lua).
	API.SafeCall("NamePlates.SetCVar." .. name, C_CVar.SetCVar, name, enabled and "1" or "0")
end

local ApplyPendingNamePlateVisibility = function(self)
	local pending = self.pendingVisibility
	if (not pending or InCombatLockdown()) then
		return
	end
	self.pendingVisibility = nil
	for kind, enabled in next, pending do
		SetVisibilitySetting(self, kind, enabled)
	end
end

-- CVAR_UPDATE names a CVar the way the client registered it, and that is not ours to guess
-- (nameplateShowFriendlyNpcs was nameplateShowFriendlyNPCs), so these compare in lower case.
local LowerCaseSet = function(...)
	local set = {}
	for index = 1, select("#", ...) do
		set[(select(index, ...)):lower()] = true
	end
	return set
end
local VISIBILITY_CVAR_SET = {}
for _, names in next, VISIBILITY_CVARS do
	for _, name in ipairs(names) do
		VISIBILITY_CVAR_SET[name:lower()] = true
	end
end
-- What "Use Blizzard overall scale" follows (Settings.lua, GetBlizzardOverallScale).
local BLIZZARD_SCALE_CVAR_SET = LowerCaseSet("nameplateSize", "nameplateGlobalScale")
-- What Blizzard's driver answers by resizing every plate to its own size (Blizzard_NamePlates.lua,
-- OnEvent's optionCVars and the CVarCallbackRegistry callbacks, all ending in UpdateNamePlateSize).
local BLIZZARD_PLATE_SIZE_CVAR_SET = LowerCaseSet("nameplateSize", "nameplateStyle", "nameplateAuraScale", "nameplateDebuffPadding")

local IsInCVarSet = function(set, name)
	return (type(name) == "string" and set[name:lower()]) and true or false
end

local IsVisibilityManagedCVar = function(name)
	return IsInCVarSet(VISIBILITY_CVAR_SET, name)
end

local IsBlizzardScaleCVar = function(name)
	return IsInCVarSet(BLIZZARD_SCALE_CVAR_SET, name)
end

local IsBlizzardPlateSizeCVar = function(name)
	return IsInCVarSet(BLIZZARD_PLATE_SIZE_CVAR_SET, name)
end

NP.CVarExists = CVarExists
NP.GetCVarBoolIfSupported = GetCVarBoolIfSupported
NP.IsShownByBlizzard = IsShownByBlizzard
NP.ApplyFriendlyNameOnlyCVars = ApplyFriendlyNameOnlyCVars
NP.GetDriverCVars = GetDriverCVars
NP.ApplyNamePlateDriverSettings = ApplyNamePlateDriverSettings
NP.IsVisibilityManagedCVar = IsVisibilityManagedCVar
NP.IsBlizzardScaleCVar = IsBlizzardScaleCVar
NP.IsBlizzardPlateSizeCVar = IsBlizzardPlateSizeCVar
NP.ApplyPendingNamePlateStacking = ApplyPendingNamePlateStacking
NP.ApplyPendingNamePlateVisibility = ApplyPendingNamePlateVisibility

-- For the options page, which reads and writes the game's own setting through these.
NamePlatesMod.IsShownSettingSupported = function(self, kind)
	return GetVisibilityCVarName(kind) ~= nil
end
-- nil where the client has no such setting.
NamePlatesMod.GetShownSetting = function(self, kind)
	if (self.pendingVisibility and self.pendingVisibility[kind] ~= nil) then
		return self.pendingVisibility[kind]
	end
	local name = GetVisibilityCVarName(kind)
	if (not name) then
		return nil
	end
	return GetCVarBoolIfSupported(name, nil)
end
NamePlatesMod.SetShownSetting = function(self, kind, enabled)
	SetVisibilitySetting(self, kind, enabled)
end
NamePlatesMod.IsStackingSupported = function(self)
	return IsNamePlateStackingSupported()
end
NamePlatesMod.GetStacking = function(self, kind)
	if (self.pendingStacking and self.pendingStacking[kind] ~= nil) then
		return self.pendingStacking[kind]
	end
	return GetNamePlateStacking(kind)
end
NamePlatesMod.SetStacking = function(self, kind, enabled)
	SetNamePlateStacking(self, kind, enabled)
end

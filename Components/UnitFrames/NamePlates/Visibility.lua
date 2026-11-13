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
-- Nameplates, 4 of 10: the widget container, the anchors, and the object, hidden and name-only visual states.
-- Loaded after CVars.lua; see Settings.lua for how these files share their locals.
local _, ns = ...

local NP = ns.NamePlatesPrivate
if (not NP) then return end

local API = ns.API
local math_abs = math.abs
local unpack = unpack

local NamePlatesMod = NP.NamePlatesMod
local FRIENDLY_NAME_ONLY_FONT_SCALE_DEFAULT = NP.FRIENDLY_NAME_ONLY_FONT_SCALE_DEFAULT
local FRIENDLY_NAME_ONLY_NAME_OFFSET_Y = NP.FRIENDLY_NAME_ONLY_NAME_OFFSET_Y
local NAMEPLATE_CASTBAR_BASELINE_OFFSET = NP.NAMEPLATE_CASTBAR_BASELINE_OFFSET
local IsSecretValue = NP.IsSecretValue
local IsSafeUnitToken = NP.IsSafeUnitToken
local SafeUnitMatches = NP.SafeUnitMatches
local GetCVarBoolIfSupported = NP.GetCVarBoolIfSupported
local ShouldUseFriendlyPlayerNameOnly = NP.ShouldUseFriendlyPlayerNameOnly
local GetValidatedProfileScale = NP.GetValidatedProfileScale
local IsHostileNamePlate = NP.IsHostileNamePlate
local GetNamePlateCastBarOffsetSetting = NP.GetNamePlateCastBarOffsetSetting
local GetTargetLikeNameLift = NP.GetTargetLikeNameLift
local GetNamePlateAuraConfig = NP.GetNamePlateAuraConfig
local GetNamePlateAuraConfigVersion = NP.GetNamePlateAuraConfigVersion
local IsShownByBlizzard = NP.IsShownByBlizzard

local UpdateNamePlateWidgetContainer = function(self, shouldShow)
	local container = self and self.WidgetContainer
	if (not container) then
		return
	end

	-- WoW 12 secret-value safety:
	-- do not reparent or reanchor Blizzard's nameplate widget container.
	-- Writing addon-owned layout state onto this frame taints later widget
	-- layout passes, which can rethrow from Blizzard_SharedXML/LayoutFrame.
	if (shouldShow) then
		if (container.SetIgnoreParentAlpha) then
			container:SetIgnoreParentAlpha(false)
		end
		if (container.SetAlpha) then
			container:SetAlpha(1)
		end
		if (container.Show) then
			container:Show()
		end
	else
		if (container.SetIgnoreParentAlpha) then
			container:SetIgnoreParentAlpha(false)
		end
		if (container.Hide) then
			container:Hide()
		end
	end
end

local GetNamePlateWidgetLift = function(self)
	if (not self or self.isPRD or self.isObjectPlate or self.isPlayerUnit) then
		return 0
	end
	if (not (NamePlatesMod and NamePlatesMod.db and NamePlatesMod.db.profile and NamePlatesMod.db.profile.showBlizzardWidgets)) then
		return 0
	end

	local container = self.WidgetContainer
	if (not container or not container.IsShown or not container:IsShown()) then
		return 0
	end

	local numWidgetsShowing = container.numWidgetsShowing
	if (numWidgetsShowing == nil) then
		numWidgetsShowing = container.shownWidgetCount
	end
	if (IsSecretValue(numWidgetsShowing)) then
		return 0
	end
	if (type(numWidgetsShowing) ~= "number" or numWidgetsShowing <= 0) then
		return 0
	end

	local db = ns.GetConfig("NamePlates")
	local widgetPosition = db and db.WidgetPosition
	local widgetOffsetY = widgetPosition and widgetPosition[3]
	if (type(widgetOffsetY) ~= "number") then
		return 0
	end

	return math_abs(widgetOffsetY)
end

local AnchorStandardNamePlateHealthBar = function(self)
	if (not self or not self.Health) then
		return
	end
	local db = ns.GetConfig("NamePlates")
	local point, x, y = unpack(db.HealthBarPosition)
	self.Health:ClearAllPoints()
	self.Health:SetPoint(point, x, y + GetNamePlateWidgetLift(self))
end

local SetNameColorForUnit = function(self, db)
	if (not self or not self.Name) then
		return
	end
	if (ShouldUseFriendlyPlayerNameOnly(self)) then
		local unit = self.unit
		-- NPCs have classes too (an innkeeper can be a warrior), so a name-only NPC takes its reaction
		-- colour, as Blizzard's name-only NPCs do. Its title follows the name's colour.
		if (self.isFriendlyAssistableNPC) then
			local reaction = IsSafeUnitToken(unit) and UnitReaction("player", unit) or nil
			local colors = self.colors and self.colors.reaction
			local color = (type(reaction) == "number" and not IsSecretValue(reaction) and colors) and colors[reaction] or nil
			local r, g, b
			if (type(color) == "table" and type(color[1]) == "number") then
				r, g, b = color[1], color[2], color[3]
			else
				r, g, b = db.NameColor[1], db.NameColor[2], db.NameColor[3]
			end
			if (self.NameTitle) then
				self.NameTitle:SetTextColor(r, g, b, .8)
			end
			return self.Name:SetTextColor(r, g, b, 1)
		end
		if (IsSafeUnitToken(unit)) then
			local _, class = UnitClass(unit)
			if (IsSecretValue(class)) then
				-- PvP: as Health_UpdateColor (Elements.lua), C_ClassColor takes the secret class and
				-- SetTextColor takes the colour it hands back.
				local color = C_ClassColor and C_ClassColor.GetClassColor and C_ClassColor.GetClassColor(class)
				if (type(color) == "table") then
					return self.Name:SetTextColor(color.r, color.g, color.b, 1)
				end
			elseif (type(class) == "string" and self.colors and self.colors.class and self.colors.class[class]) then
				local color = self.colors.class[class]
				return self.Name:SetTextColor(color[1], color[2], color[3], 1)
			end
		end
	end
	self.Name:SetTextColor(unpack(db.NameColor))
end

local AnchorStandardNamePlateCastBar = function(self)
	if (not self or not self.Castbar or not self.Health) then
		return
	end
	self.Castbar:ClearAllPoints()
	local offset = -1 + NAMEPLATE_CASTBAR_BASELINE_OFFSET + GetNamePlateCastBarOffsetSetting()
	if (ns.ThemeEngine) then offset = ns.ThemeEngine:GetNameplateCastOffset(offset) end
	self.Castbar:SetPoint("TOP", self.Health, "BOTTOM", 0, offset)
end

local AnchorStandardNamePlateName = function(self)
	if (not self or not self.Name) then
		return
	end
	-- Name-only plates keep the anchor ApplyFriendlyNameOnlyNameAnchor gave them.
	-- Overwriting it here is what floated those names back up in 5.3.19.
	if (ShouldUseFriendlyPlayerNameOnly(self)) then
		return
	end
	local db = ns.GetConfig("NamePlates")
	local point, x, y = unpack(db.NamePosition)
	self.Name:ClearAllPoints()
	self.Name:SetPoint(point, x, y + GetTargetLikeNameLift(self) + GetNamePlateWidgetLift(self))
end

-- Friendly NPCs, friendly players or minions only for your target (off by default). Neither client has
-- such a setting: the engine makes a plate by the game's setting for the kind, and with it off a hard
-- target gets none, only its name in the world. So the game's setting stays on, every plate of the kind
-- is made, and the ones that are not the target or the soft target are hidden here. Minions are players'
-- pets, totems and guardians on either side (NamePlate_Classify, isMinion); a friendly one is also hidden
-- by the friendly players switch, as it was before minions had their own.
local TARGET_ONLY_KEYS = {
	friendlyNPCs = "friendlyNPCsTargetOnly",
	friendlyPlayers = "friendlyPlayersTargetOnly",
	minions = "minionsTargetOnly"
}
-- The game's settings each switch needs on (CVars.lua, VISIBILITY_CVARS).
local TARGET_ONLY_NEEDS = {
	friendlyNPCs = { "friendlyNPCs" },
	friendlyPlayers = { "friendlyPlayers" },
	minions = { "friendlyMinions", "enemyMinions" }
}

local IsTargetOnly = function(kind)
	local profile = NamePlatesMod and NamePlatesMod.db and NamePlatesMod.db.profile
	return (profile and profile[TARGET_ONLY_KEYS[kind]]) and true or false
end

local IsSelected = function(self)
	return (self.isTarget or self.isSoftTarget) and true or false
end

local IsHiddenMinion = function(self)
	return (self.isMinion and IsTargetOnly("minions") and not IsSelected(self)) and true or false
end

-- A dead NPC. Retail drops a plate when its unit dies; Forever keeps it, and Blizzard's own plate only
-- greys it (CompactUnitFrame.lua:656, 863), so ours drew an empty bar reading "Dead" over the corpse
-- (FixLog 2026-10-16). Players keep theirs. A secret answer counts as alive.
local IsDeadNPC = function(self)
	local unit = self and self.unit
	if (not self or self.isPlayerUnit or not UnitIsDead or not IsSafeUnitToken(unit)) then
		return false
	end
	local dead = UnitIsDead(unit)
	return ((not IsSecretValue(dead)) and dead == true) and true or false
end

local ShouldShowNamePlateForBlizzardVisibility = function(self)
	if (not self or self.isPRD) then
		return true
	end

	if (IsDeadNPC(self)) then
		return false
	end

	if ((not IsShownByBlizzard("showAll")) and (not self.inCombat)) then
		return false
	end

	if (IsHostileNamePlate(self)) then
		return IsShownByBlizzard("enemies") and not IsHiddenMinion(self)
	end

	if (self.isFriendlyAssistableNPC) then
		-- With friendly NPC plates off, the engine still gives one a plate for its widgets or as a soft
		-- target, and Blizzard's own plate shows it (Blizzard_NamePlateUnitFrame.lua,
		-- UpdateWidgetsOnlyMode). Its setting stands on its own since Retail 12; before, it also needed
		-- the friendly one.
		if (self.nameplateShowsWidgetsOnly or self.isTarget or self.isSoftTarget) then
			return true
		end
		return IsShownByBlizzard("friendlyNPCs") and not IsTargetOnly("friendlyNPCs")
	end

	if (IsHiddenMinion(self) or (IsTargetOnly("friendlyPlayers") and not IsSelected(self))) then
		return false
	end
	return IsShownByBlizzard("friendlyPlayers")
end

--[[
	The combat filter (Phase 7, off by default): enemies in combat with no one in your group fade, so
	the pull you are in stands out. Out of combat a plate is left to the content's own alpha. Never the
	target, focus, mouseover or soft target, the personal display or an object.

	"No one in your group" is the threat table: UnitThreatSituation(member, unit) answers for anyone on
	it, and is generally not secret (SecretPredicatesDocumentation.lua, SecretWhenUnitThreatStateRestricted).
	A secret answer counts as fighting you, so a plate only fades on a clear answer.
]]
local COMBAT_FILTER_ALPHA_DEFAULT = .35
local PARTY_UNITS, PARTY_PETS, RAID_UNITS, RAID_PETS = {}, {}, {}, {}
for index = 1, 4 do
	PARTY_UNITS[index], PARTY_PETS[index] = "party" .. index, "partypet" .. index
end
for index = 1, 40 do
	RAID_UNITS[index], RAID_PETS[index] = "raid" .. index, "raidpet" .. index
end

local IsOnThreatTable = function(member, unit)
	if (not UnitExists(member)) then
		return false
	end
	local status = UnitThreatSituation(member, unit)
	if (IsSecretValue(status)) then
		return true
	end
	return type(status) == "number"
end

local IsOnGroupThreatTable = function(unit, units, pets, count)
	for index = 1, count do
		if (IsOnThreatTable(units[index], unit) or IsOnThreatTable(pets[index], unit)) then
			return true
		end
	end
	return false
end

-- True when the plate's unit is an enemy in combat whom nobody in your group is fighting.
local IsFightingSomeoneElse = function(self)
	local unit = self and self.unit
	if (not IsSafeUnitToken(unit) or self.isPRD or self.isObjectPlate or not IsHostileNamePlate(self)) then
		return false
	end
	local inCombat = UnitAffectingCombat(unit)
	if (IsSecretValue(inCombat) or inCombat ~= true) then
		return false
	end
	if (IsOnThreatTable("player", unit) or IsOnThreatTable("pet", unit)) then
		return false
	end
	if (IsInRaid and IsInRaid()) then
		local count = GetNumGroupMembers and GetNumGroupMembers() or 0
		return not IsOnGroupThreatTable(unit, RAID_UNITS, RAID_PETS, count < 40 and count or 40)
	elseif (IsInGroup and IsInGroup()) then
		local count = GetNumSubgroupMembers and GetNumSubgroupMembers() or 0
		return not IsOnGroupThreatTable(unit, PARTY_UNITS, PARTY_PETS, count < 4 and count or 4)
	end
	return true
end

-- True when the plate's unit has you or your pet on its threat table. A secret answer counts
-- as yes, so a marker is never hidden on a guess. For the execute marker's combat switch.
local IsFightingYou = function(self)
	local unit = self and self.unit
	if (not IsSafeUnitToken(unit)) then
		return false
	end
	return IsOnThreatTable("player", unit) or IsOnThreatTable("pet", unit)
end

--[[
	Tank mode (2026-11-07). Threat colours for whoever is tanking: a mob you hold (status 3) is quiet,
	one you hold while someone is about to pull it (2) warns, and one you do not hold is loud, unless
	another group tank holds it. A mob fighting your group with you not on its threat table at all
	(the one hitting your healer) counts as lost. "auto" needs a group and one of: the Tank role
	(UnitGroupRolesAssigned), a Retail tank spec, Bear Form (5), Dire Bear Form (8) or Defensive
	Stance (18). A secret threat answer leaves the plate to the ordinary colours.
]]
-- Form IDs from Forever's SpellShapeshiftForm table (wago.tools wowf 1.60.1.70862): 5 Bear Form, 8 Dire
-- Bear Form, 18 Defensive Stance.
local TANK_FORMS = { [5] = true, [8] = true, [18] = true }

--[[
	Threat roles (2026-11-08). One resolver for tank, healer and DPS mode. Tank wins: the Tank group role,
	a Retail tank spec, a tank form or (Classic content) Righteous Fury. Then the group role decides, then
	a Retail spec, then (Classic content, where the spec role always says damager; ThreatClassic2 notes
	the same) the talent tree with the most points. Anything else is DPS.
]]
local THREAT_ROLE_MODES = { auto = true, tank = true, healer = true, dps = true, off = true }
-- Yesterday's setting, read when the new one was never stored (AceDB keeps only changed values).
local LEGACY_TANK_MODES = { always = "tank", off = "off", auto = "auto" }

-- Forever's talent trees, by the tree's background name (Plater's table, libs/DF/fw.lua) and, should
-- the name be missing, by the tree's place in the classic order. Only classes with a healer or tank tree.
local TALENT_BACKGROUND_ROLES = {
	DruidRestoration = "HEALER", PaladinHoly = "HEALER", PaladinProtection = "TANK",
	PriestDiscipline = "HEALER", PriestHoly = "HEALER", ShamanRestoration = "HEALER"
}
local TALENT_TREE_ROLES = {
	DRUID = { "DAMAGER", "DAMAGER", "HEALER" },
	PALADIN = { "HEALER", "TANK", "DAMAGER" },
	PRIEST = { "HEALER", "HEALER", "DAMAGER" },
	SHAMAN = { "DAMAGER", "DAMAGER", "HEALER" }
}
-- A tree needs this many points before it says anything (Plater uses the same floor).
local TALENT_ROLE_MIN_POINTS = 4
-- Forever IDs checked on wago.tools (wowf 1.60.1.70862); 407627 is the Season of Discovery rune version.
local RIGHTEOUS_FURY = { 25780, 407627 }

local talentRole -- nil: not read since the last talent change; false: no role from the talents
local righteousFury = false -- read out of combat only (Forever restricts aura data in combat)

local IsSafeRole = function(role, wanted)
	return (not IsSecretValue(role)) and role == wanted
end

local GetPlayerClassToken = function()
	if (type(UnitClass) ~= "function") then
		return nil
	end
	local _, class = UnitClass("player")
	if (IsSecretValue(class) or type(class) ~= "string") then
		return nil
	end
	return class
end

-- The role of the talent tree with the most points, or nil. Cached until ResetThreatRoleCache.
local GetTalentTreeRole = function()
	if (talentRole ~= nil) then
		return talentRole or nil
	end
	talentRole = false
	local trees = TALENT_TREE_ROLES[GetPlayerClassToken() or ""]
	local info = C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo
	if (not trees or type(info) ~= "function") then
		return nil
	end
	local bestRole, bestPoints = nil, 0
	for index = 1, #trees do
		local ok, _, _, _, _, _, _, points, background = API.TryCall(info, index)
		if (ok and (not IsSecretValue(points)) and type(points) == "number" and points > bestPoints) then
			local role = (not IsSecretValue(background)) and type(background) == "string" and TALENT_BACKGROUND_ROLES[background]
			bestRole, bestPoints = role or trees[index], points
		end
	end
	if (bestRole and bestPoints >= TALENT_ROLE_MIN_POINTS) then
		talentRole = bestRole
	end
	return talentRole or nil
end

-- Reads Righteous Fury again when the player is out of combat; returns true when it changed.
local UpdateRighteousFury = function()
	if (ns.IsRetailContent or GetPlayerClassToken() ~= "PALADIN") then
		return false
	end
	local inCombat = UnitAffectingCombat and UnitAffectingCombat("player")
	if (IsSecretValue(inCombat) or inCombat == true) then
		return false
	end
	local getAura = C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID
	local found = false
	if (type(getAura) == "function") then
		for _, spellID in ipairs(RIGHTEOUS_FURY) do
			local ok, aura = API.TryCall(getAura, spellID)
			if (ok and aura ~= nil and not IsSecretValue(aura)) then
				found = true
				break
			end
		end
	end
	local changed = found ~= righteousFury
	righteousFury = found
	return changed
end

-- Talents, spec or the class changed: read the talent trees again on the next question.
local ResetThreatRoleCache = function()
	talentRole = nil
end

local GetSpecRole = function()
	if (not ns.IsRetailContent or type(GetSpecialization) ~= "function" or type(GetSpecializationRole) ~= "function") then
		return nil
	end
	local spec = GetSpecialization()
	if (IsSecretValue(spec) or type(spec) ~= "number") then
		return nil
	end
	local role = GetSpecializationRole(spec)
	if (IsSecretValue(role) or type(role) ~= "string") then
		return nil
	end
	return role
end

local IsInTankForm = function()
	if (type(GetShapeshiftFormID) ~= "function") then
		return false
	end
	local form = GetShapeshiftFormID()
	return ((not IsSecretValue(form)) and type(form) == "number" and TANK_FORMS[form]) and true or false
end

-- "tank", "healer" or "dps", whatever the group or the setting.
local GetPlayerThreatRole = function()
	local assigned = type(UnitGroupRolesAssigned) == "function" and UnitGroupRolesAssigned("player") or nil
	if (IsSecretValue(assigned) or type(assigned) ~= "string") then
		assigned = "NONE"
	end
	local specRole = GetSpecRole()
	if (assigned == "TANK" or specRole == "TANK" or IsInTankForm() or righteousFury) then
		return "tank"
	end
	if (assigned == "HEALER") then
		return "healer"
	elseif (assigned == "DAMAGER") then
		return "dps"
	end
	local guess = specRole
	if (not ns.IsRetailContent) then
		guess = GetTalentTreeRole()
	end
	if (guess == "TANK") then
		return "tank"
	elseif (guess == "HEALER") then
		return "healer"
	end
	return "dps"
end

local GetThreatRoleSetting = function()
	local profile = NamePlatesMod and NamePlatesMod.db and NamePlatesMod.db.profile
	if (not profile) then
		return "auto"
	end
	local mode = rawget(profile, "threatRole")
	if (mode == nil) then
		mode = LEGACY_TANK_MODES[rawget(profile, "threatTankMode") or ""] or profile.threatRole
	end
	return THREAT_ROLE_MODES[mode] and mode or "auto"
end

-- Where the threat roles work (threatRoleScope, since 2026-11-08): "group" (party or raid, the
-- default and the behaviour before), "instance" (dungeons and raids: instance types party and raid,
-- solo or not) or "always". Decides where Automatic picks a role, and where the threat percent and
-- the alerts work; a role picked by hand colours plates everywhere.
local THREAT_SCOPES = { group = true, instance = true, always = true }
local IsThreatScopeActive = function()
	local profile = NamePlatesMod and NamePlatesMod.db and NamePlatesMod.db.profile
	local scope = profile and profile.threatRoleScope
	if (not THREAT_SCOPES[scope]) then
		scope = "group"
	end
	if (scope == "always") then
		return true
	elseif (scope == "instance") then
		if (type(IsInInstance) ~= "function") then
			return false
		end
		local inInstance, instanceType = IsInInstance()
		return (inInstance == true and (instanceType == "party" or instanceType == "raid")) and true or false
	end
	return (IsInGroup and IsInGroup()) and true or false
end

-- The threat role in use: "tank", "healer", "dps", or nil for the shared palette.
local GetActiveThreatRole = function()
	local mode = GetThreatRoleSetting()
	if (mode == "off") then
		return nil
	elseif (mode ~= "auto") then
		return mode
	end
	if (not IsThreatScopeActive()) then
		return nil
	end
	return GetPlayerThreatRole()
end

local IsTankModeActive = function()
	return GetActiveThreatRole() == "tank"
end

-- A group member marked as a tank: the Tank role, or the raid's Main Tank assignment (Classic raids).
local IsGroupTank = function(member)
	if (type(UnitGroupRolesAssigned) == "function" and IsSafeRole(UnitGroupRolesAssigned(member), "TANK")) then
		return true
	end
	if (type(GetPartyAssignment) == "function") then
		local ok, assigned = API.TryCall(GetPartyAssignment, "MAINTANK", member)
		if (ok and (not IsSecretValue(assigned)) and assigned) then
			return true
		end
	end
	return false
end

-- True when a group tank other than you is tanking the unit (status 2 or 3 on their side).
local IsHeldByOtherTank = function(unit, units, count)
	for index = 1, count do
		local member = units[index]
		if (UnitExists(member) and not SafeUnitMatches(member, "player")) then
			local status = UnitThreatSituation(member, unit)
			if ((not IsSecretValue(status)) and type(status) == "number" and status >= 2 and IsGroupTank(member)) then
				return true
			end
		end
	end
	return false
end

-- The plate's tank state: nil outside tank mode (or for anything but an enemy NPC, or a secret
-- answer), false for an enemy fighting no one in your group, else "held", "slipping", "cotank" or "lost".
local GetTankThreatState = function(self, status)
	local unit = self and self.unit
	if (not IsSafeUnitToken(unit) or self.isPRD or self.isObjectPlate or not IsHostileNamePlate(self)) then
		return nil
	end
	if (IsSecretValue(status) or IsDeadNPC(self) or not IsTankModeActive()) then
		return nil
	end
	if (status == 3) then
		return "held"
	elseif (status == 2) then
		return "slipping"
	end
	local inRaid = IsInRaid and IsInRaid()
	local inGroup = inRaid or (IsInGroup and IsInGroup())
	local units, pets, count
	if (inRaid) then
		local members = GetNumGroupMembers and GetNumGroupMembers() or 0
		units, pets, count = RAID_UNITS, RAID_PETS, members < 40 and members or 40
	elseif (inGroup) then
		local members = GetNumSubgroupMembers and GetNumSubgroupMembers() or 0
		units, pets, count = PARTY_UNITS, PARTY_PETS, members < 4 and members or 4
	end
	if (status == nil) then
		-- Not on your table: only a mob in combat with your group (or your pet) is lost to you.
		local inCombat = UnitAffectingCombat(unit)
		if (IsSecretValue(inCombat) or inCombat ~= true) then
			return false
		end
		local fightingGroup = IsOnThreatTable("pet", unit)
			or (units and IsOnGroupThreatTable(unit, units, pets, count))
		if (not fightingGroup) then
			return false
		end
	end
	if (units and IsHeldByOtherTank(unit, units, count)) then
		return "cotank"
	end
	return "lost"
end

-- The group's units for the current group, or nil solo.
local GetGroupUnits = function()
	if (IsInRaid and IsInRaid()) then
		local members = GetNumGroupMembers and GetNumGroupMembers() or 0
		return RAID_UNITS, RAID_PETS, members < 40 and members or 40
	elseif (IsInGroup and IsInGroup()) then
		local members = GetNumSubgroupMembers and GetNumSubgroupMembers() or 0
		return PARTY_UNITS, PARTY_PETS, members < 4 and members or 4
	end
end

-- True when a group member other than you, who is not a tank, is tanking the unit (status 2 or 3).
-- Pets are left out: a pet holding a mob is doing its job.
local IsHeldByNonTank = function(unit, units, count)
	for index = 1, count do
		local member = units[index]
		if (UnitExists(member) and not SafeUnitMatches(member, "player")) then
			local status = UnitThreatSituation(member, unit)
			if ((not IsSecretValue(status)) and type(status) == "number" and status >= 2 and not IsGroupTank(member)) then
				return true
			end
		end
	end
	return false
end

-- Your threat on the unit as a share of what pulls it (UnitDetailedThreatSituation's scaled percent,
-- 100 = you pull it), or nil when the client has no answer or a secret one (bosses can be secret).
local GetScaledThreatPercent = function(unit)
	if (type(UnitDetailedThreatSituation) ~= "function") then
		return nil
	end
	local ok, _, _, scaled = API.TryCall(UnitDetailedThreatSituation, "player", unit)
	if (not ok or IsSecretValue(scaled) or type(scaled) ~= "number") then
		return nil
	end
	return scaled
end

--[[
	Tank mode's threat percent (2026-11-08). On a mob you hold (held or slipping): the highest scaled
	threat of anyone else in your group, pets included outside raids, which is how close someone is to
	pulling it from you (100 = they pull it). On a mob you lost: your own, how close you are to taking it
	back. Nil for any other state, solo, or when every answer is secret. A raid asks up to 40 members,
	so Elements.lua asks at most once per TANK_PERCENT_INTERVAL per plate (twice as long in a raid).
]]
local GetTankThreatPercent = function(self, state)
	local unit = self and self.unit
	if (not IsSafeUnitToken(unit) or type(UnitDetailedThreatSituation) ~= "function") then
		return nil
	end
	if (state == "lost") then
		return GetScaledThreatPercent(unit)
	elseif (state ~= "held" and state ~= "slipping") then
		return nil
	end
	local units, pets, count = GetGroupUnits()
	if (not units) then
		return nil
	end
	local withPets = not (IsInRaid and IsInRaid())
	local best
	for index = 1, count do
		for pass = 1, withPets and 2 or 1 do
			local member = (pass == 1) and units[index] or pets[index]
			if (UnitExists(member) and not SafeUnitMatches(member, "player")) then
				local _, _, scaled = UnitDetailedThreatSituation(member, unit)
				if ((not IsSecretValue(scaled)) and type(scaled) == "number" and (not best or scaled > best)) then
					best = scaled
				end
			end
		end
	end
	return best
end

local THREAT_WARN_PERCENT_DEFAULT = 80
local GetThreatWarnPercent = function()
	local profile = NamePlatesMod and NamePlatesMod.db and NamePlatesMod.db.profile
	local value = profile and profile.threatWarnPercent
	if (type(value) ~= "number" or value < 1 or value > 100) then
		return THREAT_WARN_PERCENT_DEFAULT
	end
	return value
end

--[[
	Healer and DPS mode (2026-11-08). The reverse of tank mode: a mob the tank holds is quiet ("safe"),
	your threat reaching the warning share of what pulls it warns ("close"), being above the tank but
	not yet its target warns harder ("pulling", status 1), and a mob on you is loud ("aggro", 2 or 3).
	As a healer, a mob a group member who is not a tank holds has its own colour ("loose"), so you see
	who needs saving. Returns the state and your scaled threat percent (nil when unknown):
	nil outside these modes (or for anything but an enemy NPC, or a secret answer), false for a mob
	you are not fighting.
]]
local GetRoleThreatState = function(self, status)
	local unit = self and self.unit
	if (not IsSafeUnitToken(unit) or self.isPRD or self.isObjectPlate or not IsHostileNamePlate(self)) then
		return nil
	end
	if (IsSecretValue(status) or IsDeadNPC(self)) then
		return nil
	end
	local role = GetActiveThreatRole()
	if (role ~= "healer" and role ~= "dps") then
		return nil
	end
	local percent = (status ~= nil) and GetScaledThreatPercent(unit) or nil
	if (status == 3 or status == 2) then
		return "aggro", percent
	elseif (status == 1) then
		return "pulling", percent
	end
	if (role == "healer") then
		local inCombat = UnitAffectingCombat(unit)
		local units, _, count = GetGroupUnits()
		if (units and (not IsSecretValue(inCombat)) and inCombat == true and IsHeldByNonTank(unit, units, count)) then
			return "loose", percent
		end
	end
	if (status == 0) then
		if (percent and percent >= GetThreatWarnPercent()) then
			return "close", percent
		end
		return "safe", percent
	end
	return false
end

local GetCombatFilterAlpha = function()
	local profile = NamePlatesMod and NamePlatesMod.db and NamePlatesMod.db.profile
	local value = profile and profile.combatFilterAlpha
	if (type(value) ~= "number" or value < 0 or value > 1) then
		return COMBAT_FILTER_ALPHA_DEFAULT
	end
	return value
end

-- A plate's own alpha, in one place: nothing while it is hidden, otherwise UIParent's (mirrored so an
-- Immersion fade reaches the plates, see Style.lua), times the combat filter's fade.
local ApplyNamePlateAlpha = function(self)
	if (not self) then
		return
	end
	local alpha = 0
	if (not self.__AzeriteUI_AlphaHidden) then
		alpha = UIParent:GetAlpha()
		local faded = self.__AzeriteUI_CombatFaded
			and not (self.isTarget or self.isFocus or self.isMouseOver or self.isSoftTarget or self.isPRD or self.isObjectPlate)
		if (faded and not IsSecretValue(alpha)) then
			alpha = alpha * GetCombatFilterAlpha()
		end
	end
	local current = self:GetAlpha()
	if (IsSecretValue(alpha) or IsSecretValue(current) or current ~= alpha) then
		self:SetAlpha(alpha)
	end
end

-- NodeSight (Forever) puts its sparkles on the soft-interact object's plate and, while any sparkles are
-- on and "Keep the game's icons" is not ticked, hides Blizzard's object plates (its Sparkles.lua, Update).
-- It also widens soft interact to every object within 30 yards, so ours would follow the nearest node
-- around with its name and icon. NodeSightDB exists only when NodeSight is loaded.
local IsNodeSightHidingObjectPlates = function()
	local db = _G.NodeSightDB
	if (type(db) ~= "table") then
		return false
	end
	return (db.herbs == true or db.ore == true or db.others == true) and db.gameIcons ~= true
end

local ShouldShowObjectPlateOverlay = function(self)
	if (not self or not self.isObjectPlate or self.isPRD) then
		return false
	end
	if (self.isMouseOver or self.isTarget) then
		return true
	end
	return (self.isSoftTarget and not IsNodeSightHidingObjectPlates()) and true or false
end

-- Whether a shown object plate draws its name, as Blizzard's does (CompactUnitFrame.lua ShouldShowName with
-- displayNameByPlayerNameRules): the game's Names settings (UnitShouldDisplayName), "always show names"
-- (nameplateForceShowUnitName, which Forever does not apply to game objects), or the target with
-- UnitNameFocused. Objects named only with AzeriteUI on (Luciful, FixLog 2026-10-23). A missing or secret
-- answer shows the name, as before. ns.IsRetail is also true on Forever (Core/Client.lua), so Forever is
-- told apart by ns.IsForever. The player's own "Show object names" (profile showObjectNames) names every
-- shown object plate, the game's rules aside: there is no game setting for object names.
local ShouldShowObjectPlateName = function(self)
	local profile = NamePlatesMod and NamePlatesMod.db and NamePlatesMod.db.profile
	if (profile and profile.showObjectNames) then
		return true
	end
	local unit = self and self.unit
	if (type(UnitShouldDisplayName) ~= "function" or not IsSafeUnitToken(unit)) then
		return true
	end
	local shouldDisplay = UnitShouldDisplayName(unit)
	if (IsSecretValue(shouldDisplay) or shouldDisplay == true) then
		return true
	end
	if (GetCVarBoolIfSupported("nameplateForceShowUnitName", false)) then
		local isGameObject = ns.IsForever and UnitIsGameObject and UnitIsGameObject(unit)
		if (IsSecretValue(isGameObject) or isGameObject ~= true) then
			return true
		end
	end
	return (self.isTarget and GetCVarBoolIfSupported("UnitNameFocused", false)) and true or false
end

local ApplyObjectPlateVisualState = function(self)
	if (not self) then
		return
	end

	self:SetIgnoreParentAlpha((self.isSoftTarget and not self.isTarget) and true or false)
	self.__AzeriteUI_AlphaHidden = nil
	ApplyNamePlateAlpha(self)
	if (self.Name) then
		self.Name:SetShown(ShouldShowObjectPlateName(self))
	end
	if (self.Health) then
		self.Health:SetAlpha(0)
		self.Health:Hide()
		if (self.Health.Backdrop) then
			self.Health.Backdrop:Hide()
		end
	end
	if (self.Health and self.Health.Value) then
		self.Health.Value:Hide()
	end
	if (self.HealthPrediction) then
		self.HealthPrediction:SetAlpha(0)
		self.HealthPrediction:Hide()
	end
	if (self.Classification) then self.Classification:Hide() end
	-- The selection outline is the health bar's shape; with no bar it read as an empty one.
	if (self.TargetHighlight) then self.TargetHighlight:Hide() end
	if (self.ThreatIndicator) then self.ThreatIndicator:Hide() end
	if (self.RaidTargetIndicator) then self.RaidTargetIndicator:Hide() end
	if (self.Castbar) then
		self.Castbar:SetAlpha(0)
		self.Castbar:Hide()
		if (self.Castbar.Backdrop) then
			self.Castbar.Backdrop:Hide()
		end
	end
	if (self.WidgetContainer) then
		self.WidgetContainer:SetIgnoreParentAlpha(false)
		self.WidgetContainer:SetAlpha(0)
	end
	if (self.SoftTargetFrame) then
		self.SoftTargetFrame:SetIgnoreParentAlpha(true)
		self.SoftTargetFrame:SetAlpha(1)
	end
end

local ApplyHiddenNamePlateVisualState = function(self)
	if (not self) then
		return
	end

	self:SetIgnoreParentAlpha(false)
	-- Marked, so a UIParent fade mirrored onto the plates cannot bring it back (ApplyNamePlateAlpha).
	self.__AzeriteUI_AlphaHidden = true
	self:SetAlpha(0)
	if (self.Name) then self.Name:Hide() end
	if (self.NameTitle) then self.NameTitle:Hide() end
	if (self.Health) then
		self.Health:Hide()
		if (self.Health.Backdrop) then
			self.Health.Backdrop:Hide()
		end
	end
	if (self.Health and self.Health.Value) then self.Health.Value:Hide() end
	if (self.HealthPrediction) then
		self.HealthPrediction:SetAlpha(0)
		self.HealthPrediction:Hide()
	end
	if (self.Classification) then self.Classification:Hide() end
	if (self.TargetHighlight) then self.TargetHighlight:Hide() end
	if (self.ThreatIndicator) then self.ThreatIndicator:Hide() end
	if (self.RaidTargetIndicator) then self.RaidTargetIndicator:Hide() end
	if (self.Castbar) then
		self.Castbar:Hide()
		if (self.Castbar.Backdrop) then
			self.Castbar.Backdrop:Hide()
		end
	end
	if (self.WidgetContainer) then
		self.WidgetContainer:SetIgnoreParentAlpha(false)
		self.WidgetContainer:SetAlpha(0)
	end
	if (self.SoftTargetFrame) then
		self.SoftTargetFrame:SetIgnoreParentAlpha(false)
		self.SoftTargetFrame:SetAlpha(0)
	end
end

-- The plate's native aura display (PlayerAuraContainers.lua, CreateForNamePlate), built the first
-- time the plate has auras to show. Nil where the client has no aura container; the plate then
-- keeps the oUF element, which is also what the harness and any client without one run.
local EnsureNamePlateNativeAuras = function(self)
	if (self.NativeAuras or self.__AzeriteUI_NoNativeAuras) then
		return self.NativeAuras
	end
	local containers = ns.PlayerAuraContainers
	local create = containers and containers.CreateForNamePlate
	if (not create) then
		self.__AzeriteUI_NoNativeAuras = true
		return nil
	end
	-- Guarded: nothing else builds an aura container under Blizzard's nameplates, and a failure here
	-- would otherwise repeat on every layout of the plate. It is reported, and the plate keeps the element.
	local db = ns.GetConfig("NamePlates")
	local _, native = API.SafeCall("NamePlates.CreateForNamePlate", create, self, {
		width = db.AurasSize[1],
		height = db.AurasSize[2],
		size = db.AuraSize,
		spacing = db.AuraSpacing,
		spacingX = db.AurasSpacingX,
		spacingY = db.AurasSpacingY,
		initialAnchor = db.AurasInitialAnchor,
		growthX = db.AurasGrowthX,
		growthY = db.AurasGrowthY,
		maxAuras = db.AurasNumTotal,
		disableMouse = db.AurasDisableMouse,
		disableCooldown = db.AurasDisableCooldown,
		tooltipAnchor = db.AurasTooltipAnchor
	}, GetNamePlateAuraConfig())
	if (not native) then
		self.__AzeriteUI_NoNativeAuras = true
		return nil
	end
	native.__AzeriteUI_ConfigVersion = GetNamePlateAuraConfigVersion()
	-- Follows the element's frame, which NamePlate_PostUpdatePositions lifts over the name.
	native:SetPoint("CENTER", self.Auras, "CENTER", 0, 0)
	self.NativeAuras = native
	return native
end

-- Auras on or off for this plate. Only one of the two ways of drawing them ever draws: the scanning
-- element would show nothing in combat, when Retail 12.1 gives addon code no aura data, and would
-- double the native row out of it. `rebuild` asks a container that keeps its unit token to read its
-- unit again, which a recycled plate needs.
local SetNamePlateAurasShown = function(self, shown, rebuild)
	local native = shown and EnsureNamePlateNativeAuras(self) or self.NativeAuras
	if (native) then
		if (self:IsElementEnabled("Auras")) then
			self:DisableElement("Auras")
		end
		-- The Aura filters settings, once per change of them.
		if (shown and native.__AzeriteUI_ConfigVersion ~= GetNamePlateAuraConfigVersion()) then
			native.__AzeriteUI_ConfigVersion = GetNamePlateAuraConfigVersion()
			native:Configure(GetNamePlateAuraConfig())
		end
		if (not native:SetDisplayUnit(self.unit) and rebuild and native.displayEnabled) then
			native:ForceUpdate()
		end
		native:SetDisplayEnabled(shown)
		return
	end
	if (shown) then
		if (not self:IsElementEnabled("Auras")) then
			self:EnableElement("Auras")
			if (self.Auras.ForceUpdate) then
				self.Auras:ForceUpdate()
			end
		end
	elseif (self:IsElementEnabled("Auras")) then
		self:DisableElement("Auras")
	end
end

local ApplyFriendlyNameOnlyNameAnchor = function(self, db, enabled)
	if (not self or not self.Name) then
		return
	end
	if (enabled) then
		if (self.__AzeriteUI_NameOnlyAnchorApplied) then
			return
		end
		-- Sit the name on the bottom edge of Blizzard's plate, the point its own
		-- castbar, health bar and name stack upwards from, so the hidden bars
		-- reserve no room and a larger name grows upwards, away from the head.
		local _, x = unpack(db.NamePosition or { "TOP", 0, 16 })
		self.Name:ClearAllPoints()
		self.Name:SetPoint("BOTTOM", self:GetParent() or self, "BOTTOM", x, FRIENDLY_NAME_ONLY_NAME_OFFSET_Y)
		self.__AzeriteUI_NameOnlyAnchorApplied = true
		return
	end
	if (self.NameTitle) then
		self.NameTitle:Hide()
	end
	self.__AzeriteUI_NameOnTitle = nil
	if (self.__AzeriteUI_NameOnlyAnchorApplied) then
		self.Name:ClearAllPoints()
		self.Name:SetPoint(unpack(db.NamePosition))
		self.__AzeriteUI_NameOnlyAnchorApplied = nil
	end
end

-- A friendly NPC's title, such as "Innkeeper". No API returns it: it is the second line of the unit's
-- tooltip (C_TooltipInfo.GetUnit), unless that line is the level line ("Level 80", which every NPC
-- without a title has there) or a pet's owner. A secret line, or tooltip data not loaded yet, gives
-- nothing and is not cached, so the next layout asks again. Cached per NPC ID for the session: false
-- means "has no title".
local LEVEL_TEXT = type(LEVEL) == "string" and LEVEL ~= "" and LEVEL or nil
local OWNER_LINE_TYPE = Enum and Enum.TooltipDataLineType and Enum.TooltipDataLineType.UnitOwner or 16
local npcTitleCache = {}

local ReadTooltipNPCTitle = function(unit)
	local data = C_TooltipInfo.GetUnit(unit)
	if (IsSecretValue(data) or type(data) ~= "table") then
		return nil
	end
	local lines = data.lines
	if (IsSecretValue(lines) or type(lines) ~= "table") then
		return nil
	end
	local line = lines[2]
	if (IsSecretValue(line) or type(line) ~= "table") then
		return nil
	end
	local text, lineType = line.leftText, line.type
	if (IsSecretValue(text) or IsSecretValue(lineType) or type(text) ~= "string") then
		return nil
	end
	if (text == "" or lineType == OWNER_LINE_TYPE or (LEVEL_TEXT and text:find(LEVEL_TEXT, 1, true))) then
		return false
	end
	return text
end

local GetFriendlyNPCTitle = function(self)
	local unit = self and self.unit
	if (not IsSafeUnitToken(unit) or not C_TooltipInfo or type(C_TooltipInfo.GetUnit) ~= "function") then
		return nil
	end
	local npcID = self.npcID
	local cached = npcID and npcTitleCache[npcID]
	if (cached ~= nil) then
		return cached or nil
	end
	local ok, title = API.TryCall(ReadTooltipNPCTitle, unit)
	if (not ok or title == nil) then
		return nil
	end
	if (npcID) then
		npcTitleCache[npcID] = title
	end
	return title or nil
end

-- The title line of a name-only friendly NPC (showFriendlyNPCTitle): on the spot the name-only name
-- would take, with the name moved on top of it. Called after ApplyFriendlyNameOnlyNameAnchor.
local UpdateFriendlyNPCTitle = function(self, db)
	local title = self and self.NameTitle
	if (not title or not self.Name) then
		return
	end
	local profile = NamePlatesMod and NamePlatesMod.db and NamePlatesMod.db.profile
	local text = profile and profile.showFriendlyNPCTitle and self.isFriendlyAssistableNPC and GetFriendlyNPCTitle(self) or nil
	if (not text) then
		title:Hide()
		if (self.__AzeriteUI_NameOnTitle) then
			self.__AzeriteUI_NameOnTitle = nil
			self.__AzeriteUI_NameOnlyAnchorApplied = nil
			ApplyFriendlyNameOnlyNameAnchor(self, db, true)
		end
		return
	end
	local _, x = unpack(db.NamePosition or { "TOP", 0, 16 })
	title:SetText("<" .. text .. ">")
	title:SetScale(self.Name:GetScale())
	title:ClearAllPoints()
	title:SetPoint("BOTTOM", self:GetParent() or self, "BOTTOM", x, FRIENDLY_NAME_ONLY_NAME_OFFSET_Y)
	title:Show()
	if (not self.__AzeriteUI_NameOnTitle) then
		self.Name:ClearAllPoints()
		self.Name:SetPoint("BOTTOM", title, "TOP", 0, 0)
		self.__AzeriteUI_NameOnTitle = true
	end
end

local ApplyFriendlyNameOnlyFontScale = function(self, enabled)
	if (not self or not self.Name) then
		return
	end
	local scale = 1
	if (enabled) then
		local profile = NamePlatesMod and NamePlatesMod.db and NamePlatesMod.db.profile
		scale = GetValidatedProfileScale(profile and profile.friendlyNameOnlyFontScale, FRIENDLY_NAME_ONLY_FONT_SCALE_DEFAULT, false)
	end
	self.Name:SetScale(scale)
end

local ApplyFriendlyNameOnlyVisualState = function(self, enabled)
	if (not self) then
		return
	end

	if (enabled) then
		local db = ns.GetConfig("NamePlates")
		ApplyFriendlyNameOnlyNameAnchor(self, db, true)
		ApplyFriendlyNameOnlyFontScale(self, true)
		SetNamePlateAurasShown(self, false)
		self:SetIgnoreParentAlpha(false)
		if (self.Health) then
			self.Health:SetAlpha(0)
			self.Health:Hide()
			local nativeTexture = self.Health:GetStatusBarTexture()
			if (nativeTexture and nativeTexture.SetAlpha) then
				nativeTexture:SetAlpha(0)
			end
			if (nativeTexture and nativeTexture.Hide) then
				nativeTexture:Hide()
			end
			if (self.Health.Backdrop) then
				self.Health.Backdrop:SetAlpha(0)
				self.Health.Backdrop:Hide()
			end
			if (self.Health.Value) then
				self.Health.Value:Hide()
			end
			if (self.Health.Display) then
				self.Health.Display:SetAlpha(0)
				self.Health.Display:Hide()
			end
			if (self.Health.Preview) then
				self.Health.Preview:SetAlpha(0)
				self.Health.Preview:Hide()
			end
		end
		if (self.HealthPrediction) then
			self.HealthPrediction:SetAlpha(0)
			self.HealthPrediction:Hide()
		end
		if (self.Castbar) then
			self.Castbar:SetAlpha(0)
			self.Castbar:Hide()
			if (self.Castbar.Backdrop) then
				self.Castbar.Backdrop:Hide()
			end
			if (self.Castbar.Text) then
				self.Castbar.Text:Hide()
			end
		end
		if (self.Power) then
			self.Power:SetAlpha(0)
			self.Power:Hide()
			if (self.Power.Backdrop) then
				self.Power.Backdrop:Hide()
			end
		end
		if (self.TargetHighlight) then
			self.TargetHighlight:Hide()
		end
		if (self.ThreatIndicator) then
			self.ThreatIndicator:Hide()
		end
		if (self.Classification) then
			self.Classification:Hide()
		end
		-- The raid marker stays: oUF shows it when the unit has one, and AnchorNamePlateRaidTarget
		-- (Elements.lua) puts it above the name. Hiding it here, after NamePlate_PostUpdate's
		-- ForceUpdate, left every name-only player and NPC without its marker (2026-11-07).
		if (self.Name) then
			self.Name:Show()
		end
		-- Last, and guarded: until 2026-11-07 it ran before the bars were hidden, and its "Font not set"
		-- error (NameTitleFont was a 10 px font FontStyles.xml does not define) left every titled NPC its bar.
		API.SafeCall("NamePlates.UpdateFriendlyNPCTitle", UpdateFriendlyNPCTitle, self, db)
		return
	end
	local db = ns.GetConfig("NamePlates")
	ApplyFriendlyNameOnlyNameAnchor(self, db, false)
	ApplyFriendlyNameOnlyFontScale(self, false)

	if (self.Health) then
		self.Health:SetAlpha(1)
		local nativeTexture = self.Health:GetStatusBarTexture()
		if (nativeTexture and nativeTexture.SetAlpha) then
			nativeTexture:SetAlpha(1)
		end
		if (self.Health.Backdrop) then
			self.Health.Backdrop:SetAlpha(1)
		end
		if (self.Health.Preview) then
			self.Health.Preview:SetAlpha(0)
			self.Health.Preview:Hide()
		end
	end
	if (self.HealthPrediction) then
		self.HealthPrediction:SetAlpha(0)
		self.HealthPrediction:Hide()
	end
	if (self.Castbar) then
		self.Castbar:SetAlpha(1)
		if (self.Castbar.Text) then
			self.Castbar.Text:Show()
		end
	end
	if (self.Power) then
		self.Power:SetAlpha(self.Power.isHidden and 0 or 1)
	end
end

NP.UpdateNamePlateWidgetContainer = UpdateNamePlateWidgetContainer
NP.GetNamePlateWidgetLift = GetNamePlateWidgetLift
NP.AnchorStandardNamePlateHealthBar = AnchorStandardNamePlateHealthBar
NP.SetNameColorForUnit = SetNameColorForUnit
NP.AnchorStandardNamePlateCastBar = AnchorStandardNamePlateCastBar
NP.AnchorStandardNamePlateName = AnchorStandardNamePlateName
NP.ShouldShowNamePlateForBlizzardVisibility = ShouldShowNamePlateForBlizzardVisibility
NP.IsDeadNPC = IsDeadNPC
NP.IsFightingSomeoneElse = IsFightingSomeoneElse
NP.IsFightingYou = IsFightingYou
NP.IsTankModeActive = IsTankModeActive
NP.GetTankThreatState = GetTankThreatState
NP.GetActiveThreatRole = GetActiveThreatRole
NP.IsThreatScopeActive = IsThreatScopeActive
NP.GetRoleThreatState = GetRoleThreatState
NP.GetTankThreatPercent = GetTankThreatPercent
NP.UpdateRighteousFury = UpdateRighteousFury
NP.ResetThreatRoleCache = ResetThreatRoleCache
NP.ApplyNamePlateAlpha = ApplyNamePlateAlpha
NP.ShouldShowObjectPlateOverlay = ShouldShowObjectPlateOverlay
NP.ShouldShowObjectPlateName = ShouldShowObjectPlateName
NP.ApplyObjectPlateVisualState = ApplyObjectPlateVisualState
NP.ApplyHiddenNamePlateVisualState = ApplyHiddenNamePlateVisualState
NP.SetNamePlateAurasShown = SetNamePlateAurasShown
NP.ApplyFriendlyNameOnlyNameAnchor = ApplyFriendlyNameOnlyNameAnchor
NP.ApplyFriendlyNameOnlyFontScale = ApplyFriendlyNameOnlyFontScale
NP.ApplyFriendlyNameOnlyVisualState = ApplyFriendlyNameOnlyVisualState
NP.GetFriendlyNPCTitle = GetFriendlyNPCTitle
NP.UpdateFriendlyNPCTitle = UpdateFriendlyNPCTitle

-- For the options page: the threat role setting as it is read (yesterday's tank mode setting included),
-- and the role the automatic setting would pick for you now, group or not ("tank", "healer", "dps").
NamePlatesMod.GetThreatRoleSetting = function(self)
	return GetThreatRoleSetting()
end
NamePlatesMod.GetDetectedThreatRole = function(self)
	return GetPlayerThreatRole()
end

-- For the options page: friendly NPCs, friendly players or minions ("friendlyNPCs", "friendlyPlayers",
-- "minions") only for your target. Each needs the game's settings for its kind on (TARGET_ONLY_NEEDS), so
-- turning it on turns those on too, as the option says; turning it off leaves them as they are.
NamePlatesMod.GetTargetOnly = function(self, kind)
	return IsTargetOnly(kind)
end
NamePlatesMod.SetTargetOnly = function(self, kind, enabled)
	local key = TARGET_ONLY_KEYS[kind]
	if (not key or not self.db) then
		return
	end
	self.db.profile[key] = enabled and true or false
	if (enabled) then
		for _, needed in ipairs(TARGET_ONLY_NEEDS[kind]) do
			if (self:GetShownSetting(needed) == false) then
				self:SetShownSetting(needed, true)
			end
		end
	end
	self:UpdateSettings()
end

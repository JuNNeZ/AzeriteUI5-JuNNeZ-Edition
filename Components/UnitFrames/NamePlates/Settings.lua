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
-- Nameplates, 1 of 10: the module, its saved settings, the secret-value helpers and the scale maths every plate is sized by.
--
-- The files in Components/UnitFrames/NamePlates/ were one file, Units/NamePlates.lua, until the
-- 2026-09 overhaul split it (Docs/Nameplates Overhaul Plan.md, Phase 4). They load in the order
-- UnitFrames.xml lists them and share their locals through ns.NamePlatesPrivate: each file
-- exports at its end what later files use, and imports at its top what it uses from earlier ones.
local _, ns = ...

local oUF = ns.oUF

local NamePlatesMod = ns:NewModule("NamePlates", "LibMoreEvents-1.0", "AceHook-3.0", "AceTimer-3.0")
local API = ns.API
-- Optimization made by Rui.

-- Lua API
local math_abs = math.abs
local math_ceil = math.ceil
local math_floor = math.floor
local next = next
local select = select
local strsplit = strsplit
local string_gsub = string.gsub
local tostring = tostring
local tonumber = tonumber
local unpack = unpack

-- Addon API
local Colors = ns.Colors

ns.ActiveNamePlates = {}
ns.NamePlates = {}

local defaults = { profile = ns:Merge({
	enabled = true,
	showAuras = true,
	showAurasOnTargetOnly = true,
	-- The kinds of aura a plate shows (Aura filters; PlayerAuraContainers.lua, CreateForNamePlate).
	auraCrowdControl = true,
	auraOwnDebuffs = true,
	auraOwnDebuffsBlizzardOnly = false,
	auraOtherDebuffs = true,
	auraDispellableBuffs = true,
	auraImportantBuffs = true,
	auraOwnBuffs = true,
	-- Enemies fighting someone outside your group fade (Visibility.lua, IsFightingSomeoneElse).
	combatFilter = false,
	combatFilterAlpha = .35,
	-- The execute range on enemy plates (Elements.lua, ExecuteMarker_Update). 0 follows the class.
	executeMarker = false,
	executeThreshold = 0,
	-- Only on enemies you or your pet are fighting (nameplates; the target is chosen by you).
	executeCombatOnly = true,
	-- Show the line only from this much above the threshold (0 = always). Shared with the target.
	executeLead = 0,
	-- Own colours for line and tint, shared with the target; off keeps each frame's own.
	executeCustomColors = false,
	executeLineColor = { 1, 1, 1, .85 },
	executeZoneColor = { 1, .15, .05, .35 },
	showNameAlways = false,
	-- Objects (nodes, chests) name themselves whenever their plate shows, whatever the game's name rules say
	-- (Visibility.lua, ShouldShowObjectPlateName). Off: as Blizzard's plates, since 5.31.4.
	showObjectNames = false,
	-- Forever's UnitName returns a surname instead of a realm as its second result.
	friendlyPlayerNameFormat = "first",
	enemyPlayerNameFormat = "first",
	abbreviateNPCNames = false,
	-- Empty rules inherit the previous global choices; context overrides inherit the defaults.
	nameFormats = {},
	threatColorPreset = "azerite",
	healthValuePlacement = "below",
	hideFriendlyPlayerHealthBar = false,
	-- Friendly plates drawn only for your target and soft target, per kind (Visibility.lua,
	-- ShouldShowNamePlateForBlizzardVisibility). The game's setting for the kind stays on, so the plates exist.
	friendlyNPCsTargetOnly = false,
	friendlyPlayersTargetOnly = false,
	-- Players' pets, totems and guardians, friendly or enemy, only for your target (since 2026-09-26).
	minionsTargetOnly = false,
	-- The game's Friendly NPCs setting follows its Friendly players one, so Shift+V and Ctrl+V switch NPC
	-- plates too, as the Mists key bindings do (CVars.lua, FollowFriendlyPlayers). Off: the game's own keys.
	friendlyNPCsFollowFriendlyPlayers = false,
	friendlyNameOnlyFontScale = 2.5,
	friendlyNameOnlyTargetScale = false,
	showBlizzardWidgets = false,
	useBlizzardGlobalScale = false,
	scale = 2,
	maxDistance = 40, -- before 2026-09 the one distance everywhere; now each content's (contentSettings)
	-- How faint plates get and how far they reach, per kind of content (Content settings). The defaults
	-- are the values that were hardcoded per zone until 2026-09, so nothing moves until a player does.
	-- The distance reaches other players' plates too since 2026-09-25 (nameplatePlayerMaxDistance, which
	-- was left at the game's 60), so PvP content starts at 60 rather than cut enemy players short.
	contentSettings = {
		world = { minAlpha = .4, occludedAlpha = .15, maxDistance = 40 },
		dungeon = { minAlpha = .75, occludedAlpha = .45, maxDistance = 40 },
		mythicplus = { minAlpha = .75, occludedAlpha = .45, maxDistance = 40 },
		raid = { minAlpha = .75, occludedAlpha = .45, maxDistance = 40 },
		battleground = { minAlpha = 1, occludedAlpha = .45, maxDistance = 60 },
		arena = { minAlpha = 1, occludedAlpha = .45, maxDistance = 60 }
	},
	castBarOffsetY = 0,
	-- Enemy castbars (Castbar.lua, NamePlate_UpdateCastTargetVisuals): who the cast is aimed at,
	-- a glow when it is aimed at you, and a glow for casts the game marks important.
	castTargetName = true,
	castTargetedGlow = true,
	castImportantGlow = true,
	-- A mark beside units that belong to one of your active quests (Elements.lua, QuestMarker_Update).
	showQuestMarker = true,
	raidTargetSize = 28,
	-- Over the unit's head or at its feet: the game's nameplateOtherAtBase, written with the driver's CVars.
	platePosition = "head",
	friendlyScale = .8,
	-- 1 until 2026-09-25, when friendly NPCs that cannot be assisted were still drawn at friendlyScale.
	friendlyNPCScale = .8,
	enemyScale = .66,
	friendlyTargetScale = 0,
	enemyTargetScale = .5,
	nameplateTargetScale = 0
}, ns.MovableModulePrototype.defaults) }

local threatColorPresets = {
	deepYellow = {
		[0] = { 150/255, 108/255, 12/255 }
	},
	blueOrange = {
		[0] = { 86/255, 180/255, 233/255 },
		[1] = { 0/255, 114/255, 178/255 },
		[2] = { 230/255, 159/255, 0/255 },
		[3] = { 213/255, 94/255, 0/255 }
	},
	tealPurple = {
		[0] = { 0/255, 158/255, 115/255 },
		[1] = { 86/255, 180/255, 233/255 },
		[2] = { 204/255, 121/255, 167/255 },
		[3] = { 213/255, 94/255, 0/255 }
	},
	highContrast = {
		[0] = { 148/255, 148/255, 148/255 },
		[1] = { 0/255, 114/255, 178/255 },
		[2] = { 204/255, 121/255, 167/255 },
		[3] = { 245/255, 245/255, 245/255 }
	}
}

local GetThreatColor = function(self, status)
	if (type(issecretvalue) == "function" and issecretvalue(status)) then
		return
	end
	local profile = NamePlatesMod and NamePlatesMod.db and NamePlatesMod.db.profile
	local preset = profile and profile.threatColorPreset
	local palette = preset and threatColorPresets[preset]
	if (palette and palette[status]) then
		return palette[status]
	end
	return self.colors and self.colors.threat and self.colors.threat[status]
end

local FRIENDLY_NAME_ONLY_FONT_SCALE_DEFAULT = 2.5
local FRIENDLY_NAME_ONLY_TARGET_SCALE_DEFAULT = 0.5
local FRIENDLY_NAME_ONLY_SCALE_MULTIPLIER = 2
local FRIENDLY_NAME_ONLY_NAME_OFFSET_Y = 0 -- gap above the plate bottom, in scaled name units
local GLOBAL_NAMEPLATE_BASE_SCALE_DEFAULT = 2
local GLOBAL_NAMEPLATE_BLIZZARD_SCALE_DEFAULT = 1.1
local NAMEPLATE_MAX_DISTANCE_MIN = 20
local NAMEPLATE_MAX_DISTANCE_MAX = 60
local NAMEPLATE_MAX_DISTANCE_DEFAULT = 40
local NAMEPLATE_CASTBAR_BASELINE_OFFSET = 8
local NAMEPLATE_CASTBAR_OFFSET_DEFAULT = 0
-- The raid marker's side, in plate units before the plate's own scale. Its icons fill about 85% of
-- that. 64 was the fixed size until 2026-09-24 and stays the top of the option's range.
local NAMEPLATE_RAID_TARGET_SIZE_MIN = 12
local NAMEPLATE_RAID_TARGET_SIZE_MAX = 64
local NAMEPLATE_RAID_TARGET_SIZE_DEFAULT = 28
local FRIENDLY_NAMEPLATE_SCALE_DEFAULT = .8
local FRIENDLY_NPC_NAMEPLATE_SCALE_DEFAULT = .8
local ENEMY_NAMEPLATE_SCALE_DEFAULT = .66
local FRIENDLY_NAMEPLATE_TARGET_SCALE_DEFAULT = 0
local GLOBAL_NAMEPLATE_TARGET_SCALE_DEFAULT = 0
local LEGACY_FRIENDLY_NAMEPLATE_SCALE_DEFAULT = 1.5
local LEGACY_ENEMY_NAMEPLATE_SCALE_DEFAULT = .66
local LEGACY_FRIENDLY_NAMEPLATE_TARGET_SCALE_DEFAULT = 0
local LEGACY_GLOBAL_NAMEPLATE_TARGET_SCALE_DEFAULT = .5
local PROMOTED_FRIENDLY_NAMEPLATE_TARGET_SCALE_DEFAULT = -.65
local PROMOTED_GLOBAL_NAMEPLATE_TARGET_SCALE_DEFAULT = .2
local NAMEPLATE_TARGET_SCALE_MIN = -.95
local NAMEPLATE_TARGET_SCALE_MAX = 4
local GLOBAL_NAMEPLATE_UNIT_SCALE_DEFAULT = 1
local GLOBAL_NAMEPLATE_SELECTED_SCALE_NEUTRAL = 1
local GLOBAL_NAMEPLATE_MIN_SCALE = 1
local GLOBAL_NAMEPLATE_MAX_SCALE = 1
local GLOBAL_NAMEPLATE_LARGER_SCALE = 1

-- Utility Functions
--------------------------------------------
-- Simplify the tagging process a little.
local prefix = function(msg)
	return string_gsub(msg, "*", ns.Prefix)
end

local IsSecretValue = function(value)
	return (type(issecretvalue) == "function" and issecretvalue(value)) and true or false
end

local IsSafeTrue = function(value)
	if (IsSecretValue(value)) then
		return false
	end
	return value and true or false
end

local IsSafeFalse = function(value)
	if (IsSecretValue(value)) then
		return false
	end
	return not value
end

local GetSafeColorByKey = function(colors, key, fallback)
	if (IsSecretValue(key)) then
		return fallback
	end
	if (not colors or key == nil) then
		return fallback
	end
	return colors[key] or fallback
end

local IsSafeUnitToken = function(unit)
	return type(unit) == "string" and (not IsSecretValue(unit)) and unit ~= ""
end

local SafeUnitName = function(unit)
	if (not IsSafeUnitToken(unit)) then
		return nil
	end
	local name = UnitName(unit)
	if (type(name) == "string" and (not IsSecretValue(name)) and name ~= "") then
		return name
	end
	return nil
end

local SafeUnitGUID = function(unit)
	if (not IsSafeUnitToken(unit)) then
		return nil
	end
	local guid = UnitGUID(unit)
	if (type(guid) ~= "string" or IsSecretValue(guid) or guid == "") then
		return nil
	end
	return guid
end

local SafeUnitMatches = function(unit, otherUnit)
	if (not IsSafeUnitToken(unit) or not IsSafeUnitToken(otherUnit)) then
		return false
	end
	local match = UnitIsUnit(unit, otherUnit)
	if (type(match) == "boolean" and not IsSecretValue(match)) then
		return match
	elseif (type(match) == "number" and not IsSecretValue(match)) then
		return match ~= 0
	end
	local guidA = SafeUnitGUID(unit)
	local guidB = SafeUnitGUID(otherUnit)
	return guidA and guidB and guidA == guidB or false
end

local GetOppositeOrientation = function(orientation)
	if (orientation == "UP") then
		return "DOWN"
	elseif (orientation == "DOWN") then
		return "UP"
	elseif (orientation == "LEFT") then
		return "RIGHT"
	end
	return "LEFT"
end

-- How the plate's bars are laid out: the layout's orientation and texture crop. The bars are never
-- reversed or flipped. (A dev-only "flip lab" used to override all of this from profile keys that
-- nothing could set; it went in the 2026-09 overhaul.)
local GetNamePlateBarLayout = function(db)
	local layout = {}
	layout.mainOrientation = db.Orientation or "LEFT"
	layout.absorbOrientation = GetOppositeOrientation(layout.mainOrientation)
	layout.texLeft, layout.texRight, layout.texTop, layout.texBottom = unpack(db.HealthBarTexCoord or { 0, 1, 0, 1 })
	layout.castTexLeft, layout.castTexRight, layout.castTexTop, layout.castTexBottom = unpack(db.CastBarTexCoord or { 0, 1, 0, 1 })
	return layout
end

local IsFriendlyPlayerNameOnlyEnabled = function()
	local profile = NamePlatesMod and NamePlatesMod.db and NamePlatesMod.db.profile
	return profile and profile.hideFriendlyPlayerHealthBar and true or false
end

-- A player as Blizzard's own plates count one: a player, or an NPC the game draws as one, such as a
-- follower dungeon companion (Blizzard_NamePlateUnitFrame.lua, UpdateIsPlayer). False on a secret answer.
local IsPlayerForDisplay = function(unit)
	if (not IsSafeUnitToken(unit)) then
		return false
	end
	local isPlayer = UnitIsPlayer(unit)
	if (IsSecretValue(isPlayer)) then
		return false
	end
	if (isPlayer == true) then
		return true
	end
	if (type(UnitTreatAsPlayerForDisplay) ~= "function") then
		return false
	end
	local treatAsPlayer = UnitTreatAsPlayerForDisplay(unit)
	return (not IsSecretValue(treatAsPlayer)) and treatAsPlayer == true
end

local ShouldUseFriendlyPlayerNameOnly = function(self)
	if (not IsFriendlyPlayerNameOnlyEnabled()) then
		return false
	end
	if (not self or self.isPRD or self.isObjectPlate) then
		return false
	end
	local unit = self.unit
	if (not IsPlayerForDisplay(unit)) then
		return false
	end

	local canAttack = UnitCanAttack("player", unit)
	local canAssist = UnitCanAssist("player", unit)
	local isFriend = UnitIsFriend("player", unit)
	local reaction = UnitReaction("player", unit)
	if (IsSecretValue(canAttack)) then
		canAttack = nil
	end
	if (IsSecretValue(canAssist)) then
		canAssist = nil
	end
	if (IsSecretValue(isFriend)) then
		isFriend = nil
	end
	if (IsSecretValue(reaction)) then
		reaction = nil
	end
	if (canAttack == nil and canAssist == nil and isFriend == nil and type(reaction) == "number") then
		if (reaction <= 4) then
			canAttack = true
		elseif (reaction >= 5) then
			canAssist = true
			isFriend = true
		end
	end
	if (canAttack == true) then
		return false
	end
	if (isFriend == true) then
		return true
	end
	return canAssist == true
end

local GetValidatedProfileScale = function(value, default, allowZero)
	if (type(value) ~= "number") then
		return default
	end
	if (allowZero) then
		if (value < 0) then
			return default
		end
	elseif (value <= 0) then
		return default
	end
	return value
end

local GetValidatedTargetScale = function(value, default)
	if (type(value) ~= "number") then
		return default
	end
	if (value < NAMEPLATE_TARGET_SCALE_MIN or value > NAMEPLATE_TARGET_SCALE_MAX) then
		return default
	end
	return value
end

local GetNamePlateProfileScale = function()
	local profile = NamePlatesMod and NamePlatesMod.db and NamePlatesMod.db.profile
	return GetValidatedProfileScale(profile and profile.scale, GLOBAL_NAMEPLATE_BASE_SCALE_DEFAULT, false)
end

local IsUsingBlizzardGlobalScale = function()
	local profile = NamePlatesMod and NamePlatesMod.db and NamePlatesMod.db.profile
	return profile and profile.useBlizzardGlobalScale and true or false
end

local GetCVarStringSafe = function(name)
	if (type(name) ~= "string" or name == "") then
		return nil
	end
	if (C_CVar and C_CVar.GetCVar) then
		local value = C_CVar.GetCVar(name)
		if (type(value) == "string" and value ~= "") then
			return value
		end
	end
	if (type(GetCVar) == "function") then
		local value = GetCVar(name)
		if (type(value) == "string" and value ~= "") then
			return value
		end
	end
	return nil
end

local GetBlizzardNamePlateGlobalScale = function()
	local value = tonumber(GetCVarStringSafe("nameplateGlobalScale"))
	if (type(value) ~= "number" or value <= 0) then
		return GLOBAL_NAMEPLATE_BLIZZARD_SCALE_DEFAULT
	end
	return value
end

-- What "Use Blizzard overall scale" follows in place of the Overall size slider. Retail 12 and Forever
-- replaced nameplateGlobalScale with nameplateSize, five steps Blizzard_NamePlates turns into scales
-- (NamePlateConstants.NAME_PLATE_SCALES), and Medium is AzeriteUI's own 100%. A client that still has
-- the old CVar keeps what it did; one with neither gets 100%.
local BLIZZARD_NAMEPLATE_SIZE_SCALES = { .75, 1, 1.25, 1.4, 1.6 } -- Enum.NamePlateSize Small (1) to Huge (5)

local GetBlizzardOverallScale = function()
	local size = tonumber(GetCVarStringSafe("nameplateSize"))
	if (size) then
		local scales = NamePlateConstants and NamePlateConstants.NAME_PLATE_SCALES
		local entry = (type(scales) == "table") and scales[size]
		local scale = (type(entry) == "table") and entry.horizontal or BLIZZARD_NAMEPLATE_SIZE_SCALES[size]
		if (type(scale) ~= "number" or scale <= 0) then
			scale = 1
		end
		return GLOBAL_NAMEPLATE_BASE_SCALE_DEFAULT * scale
	end
	if (GetCVarStringSafe("nameplateGlobalScale")) then
		return GetBlizzardNamePlateGlobalScale()
	end
	return GLOBAL_NAMEPLATE_BASE_SCALE_DEFAULT
end

local IsHostileNamePlate = function(self)
	if (not self) then
		return false
	end
	local unit = self.unit
	if (not IsSafeUnitToken(unit)) then
		return false
	end
	local canAttack = UnitCanAttack("player", unit)
	if (not IsSecretValue(canAttack) and canAttack == true) then
		return true
	end
	local reaction = UnitReaction("player", unit)
	if (not IsSecretValue(reaction) and type(reaction) == "number" and reaction <= 4) then
		return true
	end
	return false
end

local GetFriendlyNamePlateScaleSetting = function()
	local profile = NamePlatesMod and NamePlatesMod.db and NamePlatesMod.db.profile
	return GetValidatedProfileScale(profile and profile.friendlyScale, FRIENDLY_NAMEPLATE_SCALE_DEFAULT, false)
end

local GetFriendlyNPCNamePlateScaleSetting = function()
	local profile = NamePlatesMod and NamePlatesMod.db and NamePlatesMod.db.profile
	return GetValidatedProfileScale(profile and profile.friendlyNPCScale, FRIENDLY_NPC_NAMEPLATE_SCALE_DEFAULT, false)
end

local GetEnemyNamePlateScaleSetting = function()
	local profile = NamePlatesMod and NamePlatesMod.db and NamePlatesMod.db.profile
	return GetValidatedProfileScale(profile and profile.enemyScale, ENEMY_NAMEPLATE_SCALE_DEFAULT, false)
end

local GetFriendlyNamePlateTargetScaleSetting = function()
	local profile = NamePlatesMod and NamePlatesMod.db and NamePlatesMod.db.profile
	return GetValidatedTargetScale(profile and profile.friendlyTargetScale, FRIENDLY_NAMEPLATE_TARGET_SCALE_DEFAULT)
end

local GetEnemyNamePlateTargetScaleSetting = function()
	local profile = NamePlatesMod and NamePlatesMod.db and NamePlatesMod.db.profile
	local scale = GetValidatedTargetScale(profile and profile.enemyTargetScale, nil)
	if (scale == nil) then
		-- Backwards compatibility with earlier target-scale key.
		scale = GetValidatedTargetScale(profile and profile.nameplateTargetScale, GLOBAL_NAMEPLATE_TARGET_SCALE_DEFAULT)
	end
	return scale
end

local GetFriendlyNameOnlyTargetScale = function()
	local profile = NamePlatesMod and NamePlatesMod.db and NamePlatesMod.db.profile
	local explicitScale = GetValidatedTargetScale(profile and profile.friendlyNameOnlyTargetScale, nil)
	if (explicitScale ~= nil) then
		return explicitScale
	end
	return GetFriendlyNamePlateTargetScaleSetting()
end

-- The kinds of content, in the order the options list them.
local CONTENT_TYPES = { "world", "dungeon", "mythicplus", "raid", "battleground", "arena" }

-- Which kind of content the player is in. Any other instance - scenarios, delves - counts as a
-- dungeon, which is what every instance that was not PvP got before content had settings.
local GetCurrentContentType = function()
	local isInInstance, instanceType = IsInInstance()
	if (not isInInstance) then
		return "world"
	end
	if (instanceType == "raid") then
		return "raid"
	elseif (instanceType == "pvp") then
		return "battleground"
	elseif (instanceType == "arena") then
		return "arena"
	end
	if (instanceType == "party" and C_ChallengeMode and C_ChallengeMode.IsChallengeModeActive
		and C_ChallengeMode.IsChallengeModeActive()) then
		return "mythicplus"
	end
	return "dungeon"
end

local CONTENT_DEFAULTS = defaults.profile.contentSettings

-- Name contexts are independent of distance/alpha contexts, so adding cities does not change CVars.
local NAME_CONTEXTS = { "default", "city", "world", "dungeon", "mythicplus", "raid", "battleground", "arena" }
local NAME_KINDS = { friendlyPlayer = true, enemyPlayer = true, friendlyNPC = true, enemyNPC = true }
local IsPlayerNameKind = function(kind)
	return kind == "friendlyPlayer" or kind == "enemyPlayer"
end
local IsNameFormat = function(kind, mode)
	return mode == "current" or mode == "full" or mode == "initial"
		or (mode == "first" and ns.IsForever and IsPlayerNameKind(kind))
end
local IsNameContext = function(context)
	for _, key in ipairs(NAME_CONTEXTS) do if (key == context) then return true end end
	return false
end

local ResolveNameContext = function()
	local content = GetCurrentContentType()
	if (content ~= "world") then return content end
	if (not C_Map or not C_Map.GetBestMapForUnit or not C_Map.IsCityMap) then return "world" end
	local mapID = C_Map.GetBestMapForUnit("player")
	-- A city interior may have its own map. Bound the parent walk, including malformed cycles.
	for _ = 1, 8 do
		if (IsSecretValue(mapID) or type(mapID) ~= "number" or mapID <= 0) then break end
		local city = C_Map.IsCityMap(mapID)
		if (not IsSecretValue(city) and city == true) then return "city" end
		if (not C_Map.GetMapInfo) then break end
		local info = C_Map.GetMapInfo(mapID)
		mapID = info and info.parentMapID
	end
	return "world"
end

NamePlatesMod.GetCurrentNameContext = function(self)
	if (not self.nameContext) then self.nameContext = ResolveNameContext() end
	return self.nameContext
end
NamePlatesMod.GetNameContexts = function() return NAME_CONTEXTS end
NamePlatesMod.GetEditedNameContext = function(self) return self.editedNameContext or "default" end
NamePlatesMod.SetEditedNameContext = function(self, context)
	if (IsNameContext(context)) then self.editedNameContext = context end
end
NamePlatesMod.GetNameFormat = function(self, kind, context)
	context = context or self:GetEditedNameContext()
	local profile = self.db and self.db.profile or {}
	local formats = profile.nameFormats
	local rules = type(formats) == "table" and formats[context]
	local mode = type(rules) == "table" and rules[kind]
	if (IsNameFormat(kind, mode)) then return mode end
	if (context ~= "default") then return "inherit" end
	-- Preserve the choices made before the common Retail/Forever controls existed.
	if (ns.IsForever and IsPlayerNameKind(kind)) then
		local old = profile[kind .. "NameFormat"]
		return (old == "full" or old == "initial") and old or "first"
	end
	return (not IsPlayerNameKind(kind) and profile.abbreviateNPCNames) and "initial" or "current"
end
NamePlatesMod.SetNameFormat = function(self, kind, mode)
	local context = self:GetEditedNameContext()
	if (not NAME_KINDS[kind] or not self.db or not self.db.profile) then return end
	if (not IsNameFormat(kind, mode) and not (mode == "inherit" and context ~= "default")) then return end
	local profile = self.db.profile
	if (type(profile.nameFormats) ~= "table") then profile.nameFormats = {} end
	if (type(profile.nameFormats[context]) ~= "table") then profile.nameFormats[context] = {} end
	profile.nameFormats[context][kind] = (mode ~= "inherit") and mode or nil
	self:UpdateSettings()
end

local GetNamePlateDisplayName = function(unit)
	if (not IsSafeUnitToken(unit)) then return nil end
	local name, surname = UnitName(unit)
	if (IsSecretValue(name) or type(name) ~= "string" or name == "") then return nil end
	local isPlayer = UnitIsPlayer(unit)
	if (IsSecretValue(isPlayer)) then return nil end
	local hostile = IsHostileNamePlate({ unit = unit })
	local kind = isPlayer and (hostile and "enemyPlayer" or "friendlyPlayer")
		or (hostile and "enemyNPC" or "friendlyNPC")
	local mode = NamePlatesMod:GetNameFormat(kind, NamePlatesMod:GetCurrentNameContext())
	if (mode == "inherit") then mode = NamePlatesMod:GetNameFormat(kind, "default") end
	if (mode == "current") then return nil end
	-- Only Camelot's second result is a surname. Retail's second result is a realm.
	if (ns.IsForever and isPlayer) then
		if (NameUtil and NameUtil.SplitPlayerNameIntoParts) then
			local first, last = NameUtil.SplitPlayerNameIntoParts(name)
			if (type(first) == "string" and first ~= "" and type(last) == "string" and last ~= "") then
				name, surname = first, last
			end
		end
		if (mode == "first") then return name end
		if (IsSecretValue(surname) or type(surname) ~= "string" or surname == "") then return name end
		if (mode == "initial") then return string.utf8sub(name, 1, 1) .. ". " .. surname end
		return name .. " " .. surname
	end
	return mode == "initial" and API.AbbreviateName(name) or name
end

oUF.Tags.Events[prefix("*:NamePlateName")] = "UNIT_NAME_UPDATE UNIT_FACTION"
oUF.Tags.Methods[prefix("*:NamePlateName")] = function(unit, realUnit)
	local name = GetNamePlateDisplayName(unit)
	if (name ~= nil) then return name end
	return oUF.Tags.Methods[prefix("*:Name")](unit, realUnit, 24)
end

local ClampNumber = function(value, low, high, fallback)
	if (type(value) ~= "number") then
		return fallback
	end
	if (value < low) then
		return low
	elseif (value > high) then
		return high
	end
	return value
end

-- One setting of one kind of content, held to its range: minAlpha, occludedAlpha or maxDistance.
local GetContentSetting = function(contentType, key)
	local fallback = CONTENT_DEFAULTS[contentType] or CONTENT_DEFAULTS.world
	local profile = NamePlatesMod and NamePlatesMod.db and NamePlatesMod.db.profile
	local settings = profile and profile.contentSettings and profile.contentSettings[contentType]
	local value = settings and settings[key]
	if (key == "maxDistance") then
		return ClampNumber(value, NAMEPLATE_MAX_DISTANCE_MIN, NAMEPLATE_MAX_DISTANCE_MAX, fallback.maxDistance)
	end
	return ClampNumber(value, 0, 1, fallback[key])
end

local GetNamePlateMaxDistanceSetting = function()
	return GetContentSetting(GetCurrentContentType(), "maxDistance")
end

local GetNamePlateCastBarOffsetSetting = function()
	local profile = NamePlatesMod and NamePlatesMod.db and NamePlatesMod.db.profile
	local value = profile and profile.castBarOffsetY
	if (type(value) ~= "number") then
		return NAMEPLATE_CASTBAR_OFFSET_DEFAULT
	end
	return value
end

local GetNamePlateRaidTargetSize = function()
	local profile = NamePlatesMod and NamePlatesMod.db and NamePlatesMod.db.profile
	local value = profile and profile.raidTargetSize
	if (type(value) ~= "number") then
		return NAMEPLATE_RAID_TARGET_SIZE_DEFAULT
	end
	if (value < NAMEPLATE_RAID_TARGET_SIZE_MIN) then
		return NAMEPLATE_RAID_TARGET_SIZE_MIN
	end
	if (value > NAMEPLATE_RAID_TARGET_SIZE_MAX) then
		return NAMEPLATE_RAID_TARGET_SIZE_MAX
	end
	return value
end

-- Which kinds of aura the native display shows, from the Aura filters settings. The version moves
-- whenever settings change, so a plate that was not on screen then still catches up when it next
-- shows auras (RefreshActiveNamePlates only reaches the plates on screen).
local auraConfigVersion = 1
local BumpNamePlateAuraConfigVersion = function()
	auraConfigVersion = auraConfigVersion + 1
end
local GetNamePlateAuraConfigVersion = function()
	return auraConfigVersion
end
local GetNamePlateAuraConfig = function()
	local profile = NamePlatesMod and NamePlatesMod.db and NamePlatesMod.db.profile or {}
	local db = ns.GetConfig("NamePlates")
	return {
		maxAuras = db and db.AurasNumTotal or 6,
		showCrowdControl = profile.auraCrowdControl ~= false,
		showOwnDebuffs = profile.auraOwnDebuffs ~= false,
		ownDebuffsBlizzardOnly = profile.auraOwnDebuffsBlizzardOnly == true,
		showOtherDebuffs = profile.auraOtherDebuffs ~= false,
		showDispellableBuffs = profile.auraDispellableBuffs ~= false,
		showImportantBuffs = profile.auraImportantBuffs ~= false,
		showOwnBuffs = profile.auraOwnBuffs ~= false
	}
end

-- The execute marker's threshold as a share of health: the one set by hand, else the class's
-- (Components/UnitFrames/ExecuteRange.lua). 0 means no marker.
local EXECUTE_THRESHOLD_MAX = .5
local GetNamePlateExecuteThreshold = function()
	local profile = NamePlatesMod and NamePlatesMod.db and NamePlatesMod.db.profile
	local custom = profile and profile.executeThreshold
	if (type(custom) == "number" and custom > 0) then
		return (custom > EXECUTE_THRESHOLD_MAX) and EXECUTE_THRESHOLD_MAX or custom
	end
	return ns.API.GetExecuteThreshold and ns.API.GetExecuteThreshold() or 0
end

-- How far above the threshold the line appears, and the player's own colours (nil when the
-- frame keeps its layout colours). The target frame reads the same through ns.NamePlatesPrivate.
local EXECUTE_LEAD_MAX = .2
local GetExecuteMarkerStyle = function()
	local profile = NamePlatesMod and NamePlatesMod.db and NamePlatesMod.db.profile
	local lead = profile and profile.executeLead
	if (type(lead) ~= "number" or lead ~= lead or lead < 0) then lead = 0 end
	if (lead > EXECUTE_LEAD_MAX) then lead = EXECUTE_LEAD_MAX end
	local line, zone
	if (profile and profile.executeCustomColors) then
		line = type(profile.executeLineColor) == "table" and profile.executeLineColor or nil
		zone = type(profile.executeZoneColor) == "table" and profile.executeZoneColor or nil
	end
	return lead, line, zone
end

local executeLeadCurves = {}
-- 1 below threshold + lead, 0 from there up; false without client curves. The answer is
-- secret where health is, and only ever goes to SetAlpha.
local GetExecuteLeadCurve = function(limit)
	local curve = executeLeadCurves[limit]
	if (curve == nil) then
		curve = false
		if (C_CurveUtil and C_CurveUtil.CreateCurve and Enum and Enum.LuaCurveType and Enum.LuaCurveType.Step) then
			curve = C_CurveUtil.CreateCurve()
			curve:SetType(Enum.LuaCurveType.Step)
			curve:AddPoint(0, 1)
			curve:AddPoint(limit, 0)
		end
		executeLeadCurves[limit] = curve
	end
	return curve
end

local GetEffectivePlateScale = function(self)
	local scale = ns.API.GetScale()
	if (IsUsingBlizzardGlobalScale()) then
		scale = scale * GetBlizzardOverallScale()
	else
		scale = scale * GetNamePlateProfileScale()
	end
	local isHostile = IsHostileNamePlate(self)
	local isTargetLike = (self and (self.isTarget or self.isSoftTarget)) and true or false
	local isFriendlyNPC = self and self.isFriendlyAssistableNPC and true or false

	if (isHostile) then
		scale = scale * GetEnemyNamePlateScaleSetting()
	elseif (isFriendlyNPC) then
		scale = scale * GetFriendlyNPCNamePlateScaleSetting()
	else
		scale = scale * GetFriendlyNamePlateScaleSetting()
	end

	if (ShouldUseFriendlyPlayerNameOnly(self)) then
		scale = scale * FRIENDLY_NAME_ONLY_SCALE_MULTIPLIER
		if (isTargetLike) then
			scale = scale * (1 + GetFriendlyNameOnlyTargetScale())
		end
	elseif (isTargetLike) then
		if (isHostile) then
			scale = scale * (1 + GetEnemyNamePlateTargetScaleSetting())
		else
			scale = scale * (1 + GetFriendlyNamePlateTargetScaleSetting())
		end
	end
	return scale
end

local GetTargetLikePlateScaleMultiplier = function(self)
	if (not self or not (self.isTarget or self.isSoftTarget)) then
		return 1
	end
	if (ShouldUseFriendlyPlayerNameOnly(self)) then
		return 1 + GetFriendlyNameOnlyTargetScale()
	end
	if (IsHostileNamePlate(self)) then
		return 1 + GetEnemyNamePlateTargetScaleSetting()
	end
	return 1 + GetFriendlyNamePlateTargetScaleSetting()
end

local GetTargetLikeNameLift = function(self)
	local scaleMultiplier = GetTargetLikePlateScaleMultiplier(self)
	if (scaleMultiplier <= 1) then
		return 0
	end
	local db = ns.GetConfig("NamePlates")
	local healthBarHeight = db and db.HealthBarSize and db.HealthBarSize[2] or 0
	return math_floor((healthBarHeight * (scaleMultiplier - 1) * .5) + .5)
end

NamePlatesMod.GetDebugPlateScaleBreakdown = function(self, frame)
	if (not frame) then
		return nil
	end

	local isHostile = IsHostileNamePlate(frame)
	local overallScale = IsUsingBlizzardGlobalScale() and GetBlizzardOverallScale() or GetNamePlateProfileScale()
	local isFriendlyNPC = frame.isFriendlyAssistableNPC and true or false
	local relationScale = isHostile and GetEnemyNamePlateScaleSetting()
		or isFriendlyNPC and GetFriendlyNPCNamePlateScaleSetting()
		or GetFriendlyNamePlateScaleSetting()
	local targetScale = 0
	local targetLike = (frame.isTarget or frame.isSoftTarget) and true or false
	local friendlyNameOnly = ShouldUseFriendlyPlayerNameOnly(frame) and true or false

	if (friendlyNameOnly) then
		if (targetLike) then
			targetScale = GetFriendlyNameOnlyTargetScale()
		end
	elseif (targetLike) then
		targetScale = isHostile and GetEnemyNamePlateTargetScaleSetting() or GetFriendlyNamePlateTargetScaleSetting()
	end

	local softTargetFrame = frame.SoftTargetFrame
	local blizzPlate = frame.blizzPlate
	local parent = frame.GetParent and frame:GetParent() or nil

	return {
		unit = frame.unit,
		target = frame.isTarget and true or false,
		softTarget = frame.isSoftTarget and true or false,
		softEnemy = frame.isSoftEnemy and true or false,
		softInteract = frame.isSoftInteract and true or false,
		hostile = isHostile and true or false,
		friendlyNPC = isFriendlyNPC,
		friendlyNameOnly = friendlyNameOnly,
		usingBlizzardGlobalScale = IsUsingBlizzardGlobalScale(),
		baseScale = ns.API.GetScale(),
		overallScale = overallScale,
		relationScale = relationScale,
		targetScale = targetScale,
		computedScale = GetEffectivePlateScale(frame),
		frameScale = frame.GetScale and frame:GetScale() or nil,
		frameEffectiveScale = frame.GetEffectiveScale and frame:GetEffectiveScale() or nil,
		parentName = parent and parent.GetName and parent:GetName() or nil,
		parentScale = parent and parent.GetScale and parent:GetScale() or nil,
		parentEffectiveScale = parent and parent.GetEffectiveScale and parent:GetEffectiveScale() or nil,
		blizzPlateScale = blizzPlate and blizzPlate.GetScale and blizzPlate:GetScale() or nil,
		blizzPlateEffectiveScale = blizzPlate and blizzPlate.GetEffectiveScale and blizzPlate:GetEffectiveScale() or nil,
		softTargetFrameShown = softTargetFrame and softTargetFrame.IsShown and softTargetFrame:IsShown() or false,
		softTargetFrameScale = softTargetFrame and softTargetFrame.GetScale and softTargetFrame:GetScale() or nil,
		softTargetFrameEffectiveScale = softTargetFrame and softTargetFrame.GetEffectiveScale and softTargetFrame:GetEffectiveScale() or nil,
		softTargetFrameWidth = softTargetFrame and softTargetFrame.GetWidth and softTargetFrame:GetWidth() or nil,
		softTargetFrameHeight = softTargetFrame and softTargetFrame.GetHeight and softTargetFrame:GetHeight() or nil
	}
end

local ApplyNamePlateScale = function(self)
	if (self and self.SetScale) then
		self:SetScale(GetEffectivePlateScale(self))
	end
end

local NP = {}
ns.NamePlatesPrivate = NP

NP.NamePlatesMod = NamePlatesMod
NP.defaults = defaults
NP.GetThreatColor = GetThreatColor
NP.FRIENDLY_NAME_ONLY_FONT_SCALE_DEFAULT = FRIENDLY_NAME_ONLY_FONT_SCALE_DEFAULT
NP.FRIENDLY_NAME_ONLY_TARGET_SCALE_DEFAULT = FRIENDLY_NAME_ONLY_TARGET_SCALE_DEFAULT
NP.FRIENDLY_NAME_ONLY_NAME_OFFSET_Y = FRIENDLY_NAME_ONLY_NAME_OFFSET_Y
NP.GLOBAL_NAMEPLATE_BLIZZARD_SCALE_DEFAULT = GLOBAL_NAMEPLATE_BLIZZARD_SCALE_DEFAULT
NP.NAMEPLATE_MAX_DISTANCE_DEFAULT = NAMEPLATE_MAX_DISTANCE_DEFAULT
NP.NAMEPLATE_CASTBAR_BASELINE_OFFSET = NAMEPLATE_CASTBAR_BASELINE_OFFSET
NP.NAMEPLATE_CASTBAR_OFFSET_DEFAULT = NAMEPLATE_CASTBAR_OFFSET_DEFAULT
NP.FRIENDLY_NAMEPLATE_SCALE_DEFAULT = FRIENDLY_NAMEPLATE_SCALE_DEFAULT
NP.ENEMY_NAMEPLATE_SCALE_DEFAULT = ENEMY_NAMEPLATE_SCALE_DEFAULT
NP.FRIENDLY_NAMEPLATE_TARGET_SCALE_DEFAULT = FRIENDLY_NAMEPLATE_TARGET_SCALE_DEFAULT
NP.GLOBAL_NAMEPLATE_TARGET_SCALE_DEFAULT = GLOBAL_NAMEPLATE_TARGET_SCALE_DEFAULT
NP.LEGACY_FRIENDLY_NAMEPLATE_SCALE_DEFAULT = LEGACY_FRIENDLY_NAMEPLATE_SCALE_DEFAULT
NP.LEGACY_ENEMY_NAMEPLATE_SCALE_DEFAULT = LEGACY_ENEMY_NAMEPLATE_SCALE_DEFAULT
NP.LEGACY_FRIENDLY_NAMEPLATE_TARGET_SCALE_DEFAULT = LEGACY_FRIENDLY_NAMEPLATE_TARGET_SCALE_DEFAULT
NP.LEGACY_GLOBAL_NAMEPLATE_TARGET_SCALE_DEFAULT = LEGACY_GLOBAL_NAMEPLATE_TARGET_SCALE_DEFAULT
NP.PROMOTED_FRIENDLY_NAMEPLATE_TARGET_SCALE_DEFAULT = PROMOTED_FRIENDLY_NAMEPLATE_TARGET_SCALE_DEFAULT
NP.PROMOTED_GLOBAL_NAMEPLATE_TARGET_SCALE_DEFAULT = PROMOTED_GLOBAL_NAMEPLATE_TARGET_SCALE_DEFAULT
NP.GLOBAL_NAMEPLATE_SELECTED_SCALE_NEUTRAL = GLOBAL_NAMEPLATE_SELECTED_SCALE_NEUTRAL
NP.GLOBAL_NAMEPLATE_MIN_SCALE = GLOBAL_NAMEPLATE_MIN_SCALE
NP.GLOBAL_NAMEPLATE_MAX_SCALE = GLOBAL_NAMEPLATE_MAX_SCALE
NP.GLOBAL_NAMEPLATE_LARGER_SCALE = GLOBAL_NAMEPLATE_LARGER_SCALE
NP.prefix = prefix
NP.IsSecretValue = IsSecretValue
NP.IsSafeTrue = IsSafeTrue
NP.IsSafeFalse = IsSafeFalse
NP.GetSafeColorByKey = GetSafeColorByKey
NP.IsSafeUnitToken = IsSafeUnitToken
NP.SafeUnitMatches = SafeUnitMatches
NP.GetNamePlateBarLayout = GetNamePlateBarLayout
NP.IsFriendlyPlayerNameOnlyEnabled = IsFriendlyPlayerNameOnlyEnabled
NP.IsPlayerForDisplay = IsPlayerForDisplay
NP.ShouldUseFriendlyPlayerNameOnly = ShouldUseFriendlyPlayerNameOnly
NP.GetValidatedProfileScale = GetValidatedProfileScale
NP.IsUsingBlizzardGlobalScale = IsUsingBlizzardGlobalScale
NP.GetBlizzardNamePlateGlobalScale = GetBlizzardNamePlateGlobalScale
NP.IsHostileNamePlate = IsHostileNamePlate
NP.GetNamePlateMaxDistanceSetting = GetNamePlateMaxDistanceSetting
NP.GetNamePlateExecuteThreshold = GetNamePlateExecuteThreshold
NP.GetExecuteMarkerStyle = GetExecuteMarkerStyle
NP.GetExecuteLeadCurve = GetExecuteLeadCurve
NP.CONTENT_TYPES = CONTENT_TYPES
NP.GetCurrentContentType = GetCurrentContentType
NP.ResolveNameContext = ResolveNameContext
NP.GetContentSetting = GetContentSetting
NP.GetNamePlateCastBarOffsetSetting = GetNamePlateCastBarOffsetSetting
NP.GetNamePlateRaidTargetSize = GetNamePlateRaidTargetSize
NP.BumpNamePlateAuraConfigVersion = BumpNamePlateAuraConfigVersion
NP.GetNamePlateAuraConfigVersion = GetNamePlateAuraConfigVersion
NP.GetNamePlateAuraConfig = GetNamePlateAuraConfig
NP.GetTargetLikeNameLift = GetTargetLikeNameLift
NP.ApplyNamePlateScale = ApplyNamePlateScale

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
local oUF = ns.oUF

local NamePlatesMod = ns:NewModule("NamePlates", "LibMoreEvents-1.0", "AceHook-3.0", "AceTimer-3.0")
-- Optimization made by Rui.

-- Lua API
local math_abs = math.abs
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
	showNameAlways = false,
	healthValuePlacement = "below",
	hideFriendlyPlayerHealthBar = false,
	friendlyNameOnlyFontScale = 2.5,
	friendlyNameOnlyTargetScale = false,
	showBlizzardWidgets = false,
	useBlizzardGlobalScale = false,
	scale = 2,
	maxDistance = 40,
	castBarOffsetY = 0,
	friendlyScale = .8,
	friendlyNPCScale = 1,
	enemyScale = .66,
	friendlyTargetScale = 0,
	enemyTargetScale = .5,
	nameplateTargetScale = 0,
	healthFlipLabEnabled = false,
	healthFlipLabDebugMode = false,
	healthLabOrientation = "DEFAULT",
	healthLabFlipTexX = false,
	healthLabFlipTexY = false,
	healthLabReverseFill = false,
	healthLabSetFlippedHorizontally = false,
	healthLabPreviewReverseFill = false,
	healthLabPreviewSetFlippedHorizontally = false,
	healthLabAbsorbUseOppositeOrientation = true,
	healthLabAbsorbReverseFill = false,
	healthLabAbsorbSetFlippedHorizontally = false,
	healthLabCastReverseFill = false,
	healthLabCastSetFlippedHorizontally = false
}, ns.MovableModulePrototype.defaults) }
local FRIENDLY_NAME_ONLY_FONT_SCALE_DEFAULT = 2.5
local FRIENDLY_NAME_ONLY_TARGET_SCALE_DEFAULT = 0.5
local FRIENDLY_NAME_ONLY_SCALE_MULTIPLIER = 2
local FRIENDLY_NAME_ONLY_NAME_OFFSET_Y = 6
local GLOBAL_NAMEPLATE_BASE_SCALE_DEFAULT = 2
local GLOBAL_NAMEPLATE_BLIZZARD_SCALE_DEFAULT = 1.1
local NAMEPLATE_MAX_DISTANCE_MIN = 20
local NAMEPLATE_MAX_DISTANCE_MAX = 60
local NAMEPLATE_MAX_DISTANCE_DEFAULT = 40
local NAMEPLATE_CASTBAR_BASELINE_OFFSET = 8
local NAMEPLATE_CASTBAR_OFFSET_DEFAULT = 0
local FRIENDLY_NAMEPLATE_SCALE_DEFAULT = .8
local FRIENDLY_NPC_NAMEPLATE_SCALE_DEFAULT = 1
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
local cvars

-- Utility Functions
--------------------------------------------
-- Simplify the tagging process a little.
local prefix = function(msg)
	return string_gsub(msg, "*", ns.Prefix)
end

local IsSecretValue = function(value)
	return (type(issecretvalue) == "function" and issecretvalue(value)) and true or false
end

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

local GetGuidType = function(unit)
	if (type(unit) ~= "string" or IsSecretValue(unit) or unit == "") then
		return nil
	end
	local guid = UnitGUID(unit)
	if (type(guid) ~= "string" or IsSecretValue(guid) or guid == "") then
		return nil
	end
	local guidType = guid:match("^([^-]+)-")
	if (guidType and guidType ~= "") then
		return guidType
	end
	return nil
end

local GetGuidAndNpcID = function(unit)
	if (not IsSafeUnitToken(unit)) then
		return nil, nil
	end
	local guid = UnitGUID(unit)
	if (type(guid) ~= "string" or IsSecretValue(guid) or guid == "") then
		return nil, nil
	end
	local guidType = guid:match("^([^-]+)-")
	if (guidType == "Creature" or guidType == "Vehicle" or guidType == "Pet") then
		local _, _, _, _, _, npcID = strsplit("-", guid)
		return guid, npcID
	end
	return guid, nil
end

-- Hotfix exceptions from live diagnostics.
-- These are surgical guards to keep known interactable trainers visible
-- while suppressing known decorative object-like creature plates.
local AlwaysShowFriendlyNPCByID = {
	["229383"] = true -- Treni (Fishing Trainer)
}

local AlwaysHideObjectLikeNPCByID = {
	["223648"] = true, -- Betta (decorative object-like plate)
	["212708"] = true, -- Freysworn Cruton (decorative object-like plate)
	["191909"] = true  -- Tuskarr Beanbag (vehicle/object-like seat)
}

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

local IsNamePlateHealthFlipLabDebugEnabled = function()
	local globalDB = ns and ns.db and ns.db.global
	local profile = NamePlatesMod and NamePlatesMod.db and NamePlatesMod.db.profile
	if (not globalDB or not profile) then
		return false
	end
	if (not globalDB.enableDevelopmentMode) then
		return false
	end
	return profile.healthFlipLabEnabled and profile.healthFlipLabDebugMode and true or false
end

local GetNamePlateHealthLabSettings = function(db)
	local profile = NamePlatesMod and NamePlatesMod.db and NamePlatesMod.db.profile or {}
	local enabled = IsNamePlateHealthFlipLabDebugEnabled()
	local settings = {}

	settings.mainOrientation = db.Orientation or "LEFT"
	if (enabled and profile.healthLabOrientation and profile.healthLabOrientation ~= "DEFAULT") then
		settings.mainOrientation = profile.healthLabOrientation
	end
	settings.absorbOrientation = GetOppositeOrientation(settings.mainOrientation)
	if (enabled and profile.healthLabAbsorbUseOppositeOrientation == false) then
		settings.absorbOrientation = settings.mainOrientation
	end

	local texLeft, texRight, texTop, texBottom = unpack(db.HealthBarTexCoord or { 0, 1, 0, 1 })
	if (enabled and profile.healthLabFlipTexX) then
		texLeft, texRight = texRight, texLeft
	end
	if (enabled and profile.healthLabFlipTexY) then
		texTop, texBottom = texBottom, texTop
	end
	settings.texLeft = texLeft
	settings.texRight = texRight
	settings.texTop = texTop
	settings.texBottom = texBottom

	local castTexLeft, castTexRight, castTexTop, castTexBottom = unpack(db.CastBarTexCoord or { 0, 1, 0, 1 })
	if (enabled and profile.healthLabFlipTexX) then
		castTexLeft, castTexRight = castTexRight, castTexLeft
	end
	if (enabled and profile.healthLabFlipTexY) then
		castTexTop, castTexBottom = castTexBottom, castTexTop
	end
	settings.castTexLeft = castTexLeft
	settings.castTexRight = castTexRight
	settings.castTexTop = castTexTop
	settings.castTexBottom = castTexBottom

	settings.healthReverseFill = false
	if (enabled and type(profile.healthLabReverseFill) == "boolean") then
		settings.healthReverseFill = profile.healthLabReverseFill
	end
	settings.healthSetFlippedHorizontally = false
	if (enabled and type(profile.healthLabSetFlippedHorizontally) == "boolean") then
		settings.healthSetFlippedHorizontally = profile.healthLabSetFlippedHorizontally
	end

	settings.previewReverseFill = settings.healthReverseFill
	if (enabled and type(profile.healthLabPreviewReverseFill) == "boolean") then
		settings.previewReverseFill = profile.healthLabPreviewReverseFill
	end
	settings.previewSetFlippedHorizontally = settings.healthSetFlippedHorizontally
	if (enabled and type(profile.healthLabPreviewSetFlippedHorizontally) == "boolean") then
		settings.previewSetFlippedHorizontally = profile.healthLabPreviewSetFlippedHorizontally
	end

	settings.absorbReverseFill = false
	if (enabled and type(profile.healthLabAbsorbReverseFill) == "boolean") then
		settings.absorbReverseFill = profile.healthLabAbsorbReverseFill
	end
	settings.absorbSetFlippedHorizontally = false
	if (enabled and type(profile.healthLabAbsorbSetFlippedHorizontally) == "boolean") then
		settings.absorbSetFlippedHorizontally = profile.healthLabAbsorbSetFlippedHorizontally
	end

	settings.castReverseFill = false
	if (enabled and type(profile.healthLabCastReverseFill) == "boolean") then
		settings.castReverseFill = profile.healthLabCastReverseFill
	end
	settings.castSetFlippedHorizontally = false
	if (enabled and type(profile.healthLabCastSetFlippedHorizontally) == "boolean") then
		settings.castSetFlippedHorizontally = profile.healthLabCastSetFlippedHorizontally
	end
	return settings
end

local IsFriendlyPlayerNameOnlyEnabled = function()
	local profile = NamePlatesMod and NamePlatesMod.db and NamePlatesMod.db.profile
	return profile and profile.hideFriendlyPlayerHealthBar and true or false
end

local ShouldUseFriendlyPlayerNameOnly = function(self)
	if (not IsFriendlyPlayerNameOnlyEnabled()) then
		return false
	end
	if (not self or self.isPRD or self.isObjectPlate) then
		return false
	end
	local unit = self.unit
	if (not IsSafeUnitToken(unit)) then
		return false
	end
	local isPlayer = UnitIsPlayer(unit)
	if (IsSecretValue(isPlayer)) then
		return false
	end
	if (isPlayer ~= true) then
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

local SetNameColorForUnit = function(self, db)
	if (not self or not self.Name) then
		return
	end
	if (ShouldUseFriendlyPlayerNameOnly(self)) then
		local unit = self.unit
		if (IsSafeUnitToken(unit)) then
			local _, class = UnitClass(unit)
			if (type(class) == "string" and (not IsSecretValue(class)) and self.colors and self.colors.class and self.colors.class[class]) then
				local color = self.colors.class[class]
				return self.Name:SetTextColor(color[1], color[2], color[3], 1)
			end
		end
	end
	self.Name:SetTextColor(unpack(db.NameColor))
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
		local ok, value = pcall(C_CVar.GetCVar, name)
		if (ok and type(value) == "string" and value ~= "") then
			return value
		end
	end
	if (type(GetCVar) == "function") then
		local ok, value = pcall(GetCVar, name)
		if (ok and type(value) == "string" and value ~= "") then
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

local GetNamePlateMaxDistanceSetting = function()
	local profile = NamePlatesMod and NamePlatesMod.db and NamePlatesMod.db.profile
	local value = profile and profile.maxDistance
	if (type(value) ~= "number") then
		return NAMEPLATE_MAX_DISTANCE_DEFAULT
	end
	if (value < NAMEPLATE_MAX_DISTANCE_MIN) then
		return NAMEPLATE_MAX_DISTANCE_MIN
	end
	if (value > NAMEPLATE_MAX_DISTANCE_MAX) then
		return NAMEPLATE_MAX_DISTANCE_MAX
	end
	return value
end

local GetNamePlateCastBarOffsetSetting = function()
	local profile = NamePlatesMod and NamePlatesMod.db and NamePlatesMod.db.profile
	local value = profile and profile.castBarOffsetY
	if (type(value) ~= "number") then
		return NAMEPLATE_CASTBAR_OFFSET_DEFAULT
	end
	return value
end

local GetEffectivePlateScale = function(self)
	local scale = ns.API.GetScale()
	if (IsUsingBlizzardGlobalScale()) then
		scale = scale * GetBlizzardNamePlateGlobalScale()
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
	local overallScale = IsUsingBlizzardGlobalScale() and GetBlizzardNamePlateGlobalScale() or GetNamePlateProfileScale()
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

local SetCVarIfSupported = function(name, value)
	if (not name or value == nil) then
		return
	end
	local stringValue = tostring(value)
	if (C_CVar and C_CVar.SetCVar) then
		local ok = pcall(C_CVar.SetCVar, name, stringValue)
		if (ok) then
			return
		end
	end
	if (type(SetCVar) == "function") then
		pcall(SetCVar, name, stringValue)
	end
end

local GetCVarBoolIfSupported = function(name, defaultValue)
	if (not name) then
		return defaultValue
	end
	if (C_CVar and C_CVar.GetCVarBool) then
		local ok, value = pcall(C_CVar.GetCVarBool, name)
		if (ok and type(value) == "boolean") then
			return value
		end
	end
	if (type(GetCVarBool) == "function") then
		local ok, value = pcall(GetCVarBool, name)
		if (ok and value ~= nil) then
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

local RefreshActiveNamePlateScales = function()
	for plate in next, ns.ActiveNamePlates do
		ApplyNamePlateScale(plate)
		if (plate.PostUpdate) then
			plate:PostUpdate("ForceUpdate", plate.unit)
		end
		if (plate.UpdateAllElements) then
			plate:UpdateAllElements("ForceUpdate")
		end
	end
end

local AnchorStandardNamePlateCastBar = function(self)
	if (not self or not self.Castbar or not self.Health) then
		return
	end
	self.Castbar:ClearAllPoints()
	self.Castbar:SetPoint("TOP", self.Health, "BOTTOM", 0, -1 + NAMEPLATE_CASTBAR_BASELINE_OFFSET + GetNamePlateCastBarOffsetSetting())
end

local AnchorStandardNamePlateName = function(self)
	if (not self or not self.Name) then
		return
	end
	local db = ns.GetConfig("NamePlates")
	local point, x, y = unpack(db.NamePosition)
	self.Name:ClearAllPoints()
	self.Name:SetPoint(point, x, y + GetTargetLikeNameLift(self) + GetNamePlateWidgetLift(self))
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
	values["nameplateMaxDistance"] = GetNamePlateMaxDistanceSetting()
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

local RefreshNamePlateScalingState = function(self)
	if (not self or not self.IsEnabled or not self:IsEnabled()) then
		return
	end
	ApplyFriendlyNameOnlyCVars()
	ApplyNamePlateDriverSettings(self)
	RefreshActiveNamePlateScales()
end

local ShouldShowNamePlateForBlizzardVisibility = function(self)
	if (not self or self.isPRD) then
		return true
	end

	local showAll = GetCVarBoolIfSupported("nameplateShowAll", true)
	if ((not showAll) and (not self.inCombat)) then
		return false
	end

	if (IsHostileNamePlate(self)) then
		return GetCVarBoolIfSupported("nameplateShowEnemies", true)
	end

	if (self.isFriendlyAssistableNPC) then
		return GetCVarBoolIfSupported("nameplateShowFriends", true)
			and GetCVarBoolIfSupported("nameplateShowFriendlyNPCs", true)
	end

	return GetCVarBoolIfSupported("nameplateShowFriends", true)
end

local ShouldShowObjectPlateOverlay = function(self)
	if (not self or not self.isObjectPlate or self.isPRD) then
		return false
	end
	return (self.isSoftTarget or self.isMouseOver or self.isTarget) and true or false
end

local ApplyObjectPlateVisualState = function(self)
	if (not self) then
		return
	end

	self:SetIgnoreParentAlpha((self.isSoftTarget and not self.isTarget) and true or false)
	self:SetAlpha(1)
	if (self.Name) then
		self.Name:Show()
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
		if (self.HealthPrediction.absorbBar) then
			self.HealthPrediction.absorbBar:SetAlpha(0)
			self.HealthPrediction.absorbBar:Hide()
		end
	end
	if (self.Classification) then self.Classification:Hide() end
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
	self:SetAlpha(0)
	if (self.Name) then self.Name:Hide() end
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
		if (self.HealthPrediction.absorbBar) then
			self.HealthPrediction.absorbBar:SetAlpha(0)
			self.HealthPrediction.absorbBar:Hide()
		end
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

local ApplyFriendlyNameOnlyNameAnchor = function(self, db, enabled)
	if (not self or not self.Name) then
		return
	end
	if (enabled) then
		if (self.__AzeriteUI_NameOnlyAnchorApplied) then
			return
		end
		local point, x, y = unpack(db.NamePosition or { "TOP", 0, 16 })
		self.Name:ClearAllPoints()
		self.Name:SetPoint(point, x, FRIENDLY_NAME_ONLY_NAME_OFFSET_Y)
		self.__AzeriteUI_NameOnlyAnchorApplied = true
		return
	end
	if (self.__AzeriteUI_NameOnlyAnchorApplied) then
		self.Name:ClearAllPoints()
		self.Name:SetPoint(unpack(db.NamePosition))
		self.__AzeriteUI_NameOnlyAnchorApplied = nil
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
		if (self:IsElementEnabled("Auras")) then
			self:DisableElement("Auras")
		end
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
			if (self.HealthPrediction.absorbBar) then
				self.HealthPrediction.absorbBar:SetAlpha(0)
				self.HealthPrediction.absorbBar:Hide()
			end
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
		if (self.RaidTargetIndicator) then
			self.RaidTargetIndicator:Hide()
		end
		if (self.Name) then
			self.Name:Show()
		end
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
		if (self.HealthPrediction.absorbBar) then
			self.HealthPrediction.absorbBar:SetAlpha(0)
			self.HealthPrediction.absorbBar:Hide()
		end
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

-- Element Callbacks
--------------------------------------------
-- Forceupdate health prediction on health updates,
-- to assure our smoothed elements are properly aligned.
local Health_PostUpdate = function(element, unit, cur, max)
	local predict = element.__owner.HealthPrediction
	if (predict) then
		predict:ForceUpdate()
	end
end

local Health_UpdateColor = function(self, event, unit)
	if(not unit or self.unit ~= unit) then return end
	local element = self.Health

	local r, g, b, color
	if (element.colorDisconnected and not UnitIsConnected(unit)) then
		color = self.colors.disconnected
	elseif (element.colorTapping and not UnitPlayerControlled(unit) and UnitIsTapDenied(unit)) then
		color = self.colors.tapped
	elseif (element.colorThreat and not UnitPlayerControlled(unit) and UnitThreatSituation("player", unit)) then
		color =  self.colors.threat[UnitThreatSituation("player", unit)]
	elseif ((element.colorClass and UnitIsPlayer(unit)
		or (element.colorClassNPC and not UnitIsPlayer(unit))
		or (element.colorClassPet and UnitPlayerControlled(unit) and not UnitIsPlayer(unit)))
		and not (not self.isPRD and element.colorClassHostileOnly and not UnitCanAttack("player", unit))) then
		local _, class = UnitClass(unit)
		color = self.colors.class[class]
	elseif (element.colorSelection and unitSelectionType(unit, element.considerSelectionInCombatHostile)) then
		color = self.colors.selection[unitSelectionType(unit, element.considerSelectionInCombatHostile)]
	elseif (element.colorReaction and UnitReaction(unit, "player")) then
		color = self.colors.reaction[UnitReaction(unit, "player")]
	elseif (element.colorSmooth) then
		local gradient = element.smoothGradient or (self.colors and self.colors.smooth)
		if (type(gradient) == "table" and gradient[1]) then
			r, g, b = self:ColorGradient(element.cur or 1, element.max or 1, unpack(gradient))
		else
			color = self.colors and self.colors.health
		end
	elseif (element.colorHealth) then
		color = self.colors.health
	end

	if (color) then
		r, g, b = color[1], color[2], color[3]
	end

	if (b) then
		element:SetStatusBarColor(r, g, b)

		local bg = element.bg
		if (bg) then
			local mu = bg.multiplier or 1
			bg:SetVertexColor(r * mu, g * mu, b * mu)
		end
	end

	--[[ Callback: Health:PostUpdateColor(unit, r, g, b)
	Called after the element color has been updated.

	* self - the Health element
	* unit - the unit for which the update has been triggered (string)
	* r    - the red component of the used color (number)[0-1]
	* g    - the green component of the used color (number)[0-1]
	* b    - the blue component of the used color (number)[0-1]
	--]]
	if (element.PostUpdateColor) then
		element:PostUpdateColor(unit, r, g, b)
	end
end

-- Update the health preview color on health color updates.
local Health_PostUpdateColor = function(element, unit, r, g, b)
	local preview = element.Preview
	if (preview and g) then
		preview:SetStatusBarColor(r * .7, g * .7, b * .7)
	end
end

-- Align our custom health prediction texture
-- based on the plugin's provided values.
local HealPredict_PostUpdate = function(element, unit, myIncomingHeal, otherIncomingHeal, absorb, healAbsorb, hasOverAbsorb, hasOverHealAbsorb, curHealth, maxHealth)
	if (ns.API.ShouldSkipPrediction(element, myIncomingHeal, otherIncomingHeal, absorb, healAbsorb, hasOverAbsorb, hasOverHealAbsorb, curHealth, maxHealth)) then
		return
	end

	local safeCur, safeMax = ns.API.GetSafeHealthForPrediction(element, curHealth, maxHealth)
	if (not safeCur or not safeMax) then
		ns.API.HidePrediction(element)
		return
	end
	curHealth, maxHealth = safeCur, safeMax
	myIncomingHeal = tonumber(myIncomingHeal) or 0
	otherIncomingHeal = tonumber(otherIncomingHeal) or 0
	healAbsorb = tonumber(healAbsorb) or 0

	local allIncomingHeal = myIncomingHeal + otherIncomingHeal
	local allNegativeHeals = healAbsorb
	local showPrediction, change

	if ((allIncomingHeal > 0) or (allNegativeHeals > 0)) and (maxHealth > 0) then
		local startPoint = curHealth/maxHealth

		-- Dev switch to test absorbs with normal healing
		--allIncomingHeal, allNegativeHeals = allNegativeHeals, allIncomingHeal

		-- Hide predictions if the change is very small, or if the unit is at max health.
		change = (allIncomingHeal - allNegativeHeals)/maxHealth
		if ((curHealth < maxHealth) and (change > (element.health.predictThreshold or .05))) then
			local endPoint = startPoint + change

			-- Crop heal prediction overflows
			if (endPoint > 1) then
				endPoint = 1
				change = endPoint - startPoint
			end

			-- Crop heal absorb overflows
			if (endPoint < 0) then
				endPoint = 0
				change = -startPoint
			end

			-- This shouldn't happen, but let's do it anyway.
			if (startPoint ~= endPoint) then
				showPrediction = true
			end
		end
	end

	if (showPrediction) then

		local preview = element.preview
		local growth = preview:GetGrowth()
		local _,max = preview:GetMinMaxValues()
		local value = preview:GetValue() / max
		local previewTexture = preview:GetStatusBarTexture()
		local previewWidth, previewHeight = preview:GetSize()
		local left, right, top, bottom = preview:GetTexCoord()
		local isFlipped = preview:IsFlippedHorizontally()

		if (growth == "RIGHT") then

			local texValue, texChange = value, change
			local rangeH

			rangeH = right - left
			texChange = change*value
			texValue = left + value*rangeH

			if (change > 0) then
				element:ClearAllPoints()
				element:SetPoint("BOTTOMLEFT", previewTexture, "BOTTOMRIGHT", 0, 0)
				element:SetSize(change*previewWidth, previewHeight)
				if (isFlipped) then
					element:SetTexCoord(texValue + texChange, texValue, top, bottom)
				else
					element:SetTexCoord(texValue, texValue + texChange, top, bottom)
				end
				element:SetVertexColor(0, .7, 0, .25)
				element:Show()

			elseif (change < 0) then
				element:ClearAllPoints()
				element:SetPoint("BOTTOMRIGHT", previewTexture, "BOTTOMRIGHT", 0, 0)
				element:SetSize((-change)*previewWidth, previewHeight)
				if (isFlipped) then
					element:SetTexCoord(texValue, texValue + texChange, top, bottom)
				else
					element:SetTexCoord(texValue + texChange, texValue, top, bottom)
				end
				element:SetVertexColor(.5, 0, 0, .75)
				element:Show()

			else
				element:Hide()
			end

		elseif (growth == "LEFT") then
			local texValue, texChange = value, change
			local rangeH

			rangeH = right - left
			texChange = change*value
			texValue = left + value*rangeH

			if (change > 0) then
				element:ClearAllPoints()
				element:SetPoint("BOTTOMRIGHT", previewTexture, "BOTTOMLEFT", 0, 0)
				element:SetSize(change*previewWidth, previewHeight)
				if (isFlipped) then
					element:SetTexCoord(texValue, texValue + texChange, top, bottom)
				else
					element:SetTexCoord(texValue + texChange, texValue, top, bottom)
				end
				element:SetVertexColor(0, .7, 0, .25)
				element:Show()

			elseif (change < 0) then
				element:ClearAllPoints()
				element:SetPoint("BOTTOMLEFT", previewTexture, "BOTTOMLEFT", 0, 0)
				element:SetSize((-change)*previewWidth, previewHeight)
				if (isFlipped) then
					element:SetTexCoord(texValue + texChange, texValue, top, bottom)
				else
					element:SetTexCoord(texValue, texValue + texChange, top, bottom)
				end
				element:SetVertexColor(.5, 0, 0, .75)
				element:Show()

			else
				element:Hide()
			end
		end
	else
		element:Hide()
	end

	if (element.absorbBar) then
		if (hasOverAbsorb and curHealth >= maxHealth) then
			absorb = UnitGetTotalAbsorbs(unit)
			if (absorb > maxHealth * .3) then
				absorb = maxHealth * .3
			end
			element.absorbBar:SetValue(absorb)
		end
	end

end

-- Update power bar visibility if a frame
-- is the perrsonal resource display.
-- This callback only handles elements below the health bar.
local Power_PostUpdate = function(element, unit, cur, min, max)
	local self = element.__owner

	unit = unit or self.unit
	if (not unit) then
		return
	end

	local db = ns.GetConfig("NamePlates")
	local shouldShow

	if (self.isPRD) then
		local safeCur = cur
		local safeMax = max
		if (type(safeCur) ~= "number" or (issecretvalue and issecretvalue(safeCur))) then
			safeCur = element.safeCur or element.cur
		end
		if (type(safeMax) ~= "number" or (issecretvalue and issecretvalue(safeMax))) then
			safeMax = element.safeMax or element.max
		end
		if (type(safeCur) ~= "number" or type(safeMax) ~= "number") then
			safeCur, safeMax = nil, nil
		end
		if (safeCur and safeCur == 0) and (safeMax and safeMax == 0) then
			shouldShow = nil
		else
			shouldShow = safeMax and safeMax > 0
		end
	end

	local power = self.Power

	if (shouldShow) then
		if (power.isHidden) then
			power:SetAlpha(1)
			power.isHidden = false

			local cast = self.Castbar
			cast:ClearAllPoints()
			cast:SetPoint(unpack(db.CastBarPositionPlayer))
		end
	else
		if (not power.isHidden) then
			power:SetAlpha(0)
			power.isHidden = true

			local cast = self.Castbar
			cast:ClearAllPoints()
			cast:SetPoint(unpack(db.CastBarPosition))
		end
	end
end

-- Update targeting highlight outline
local TargetHighlight_Update = function(self, event, unit, ...)
	if (unit and unit ~= self.unit) then return end

	local element = self.TargetHighlight
	if (ShouldUseFriendlyPlayerNameOnly(self)) then
		return element:Hide()
	end

	if (self.isFocus or self.isTarget) then
		element:SetVertexColor(unpack(self.isFocus and element.colorFocus or element.colorTarget))
		element:Show()
	elseif (self.isSoftEnemy or self.isSoftInteract) then
		element:SetVertexColor(unpack(self.isSoftEnemy and element.colorSoftEnemy or element.colorSoftInteract))
		element:Show()
	else
		element:Hide()
	end
end

-- Update NPC classification badge for rares, elites and bosses.
local Classification_Update = function(self, event, unit, ...)
	if (unit and unit ~= self.unit) then return end

	local element = self.Classification
	unit = unit or self.unit

	if (UnitIsPlayer(unit) or not UnitCanAttack("player", unit)) then
		return element:Hide()
	end

	local l = UnitEffectiveLevel(unit)
	local c = (l and l < 1) and "worldboss" or UnitClassification(unit)
	if (c == "boss" or c == "worldboss") then
		element:SetTexture(element.bossTexture)
		element:Show()

	elseif (c == "elite") then
		element:SetTexture(element.eliteTexture)
		element:Show()

	elseif (c == "rare" or c == "rareelite") then
		element:SetTexture(element.rareTexture)
		element:Show()
	else
		element:Hide()
	end
end

-- Messy callback that handles positions
-- of elements above the health bar.
local NamePlate_PostUpdatePositions = function(self)
	local db = ns.GetConfig("NamePlates")

	--local aurasEnabled = self:IsElementEnabled("Auras")
	local auras = self.Auras
	local name = self.Name
	local raidTarget = self.RaidTargetIndicator

	-- The PRD has neither name nor auras.
	if (not self.isPRD) then
		AnchorStandardNamePlateHealthBar(self)
		AnchorStandardNamePlateName(self)
		local hasName = ShouldUseFriendlyPlayerNameOnly(self) or NamePlatesMod.db.profile.showNameAlways or (self.isMouseOver or self.isSoftTarget or self.isTarget or self.inCombat) or false
		local nameOffset = hasName and (select(2, name:GetFont()) + auras.spacing + GetTargetLikeNameLift(self) + GetNamePlateWidgetLift(self)) or 0

		if (hasName ~= auras.usingNameOffset or nameOffset ~= auras.nameOffset or auras.usingNameOffset == nil) then
			if (hasName) then
				local point, x, y = unpack(db.AurasPosition)
				auras:ClearAllPoints()
				auras:SetPoint(point, x, y + nameOffset)
			else
				auras:ClearAllPoints()
				auras:SetPoint(unpack(db.AurasPosition))
			end
		end

		local numAuras = 0
		if (ns.IsRetail) then
			numAuras = auras.sortedBuffs and auras.sortedDebuffs and (#auras.sortedBuffs + #auras.sortedDebuffs) or 0
		else
			numAuras = auras.visibleBuffs and auras.visibleDebuffs and (auras.visibleBuffs + auras.visibleDebuffs) or 0
		end

		local numRows = (numAuras > 0) and (math_floor(numAuras / auras.numPerRow)) or 0

		if (numRows ~= auras.numRows or hasName ~= auras.usingNameOffset or nameOffset ~= auras.nameOffset or auras.usingNameOffset == nil) then
			if (hasName or numRows > 0) then
				local auraOffset = (numAuras > 0) and (numRows * (auras.size + auras.spacing)) or 0
				local point, x, y = unpack(db.RaidTargetPosition)
				raidTarget:ClearAllPoints()
				raidTarget:SetPoint(point, x, y + nameOffset + auraOffset)
			else
				raidTarget:ClearAllPoints()
				raidTarget:SetPoint(unpack(db.RaidTargetPosition))
			end
		end

		auras.numRows = numRows
		auras.usingNameOffset = hasName
		auras.nameOffset = nameOffset
	end
end

local NamePlate_ApplyHealthValueLayout = function(self)
	local value = self and self.Health and self.Health.Value
	if (not value) then
		return
	end

	local db = ns.GetConfig("NamePlates")
	local profile = NamePlatesMod and NamePlatesMod.db and NamePlatesMod.db.profile or nil
	local placement = profile and profile.healthValuePlacement or "below"
	local point

	if (placement == "inside") then
		point = db.HealthValuePositionInside or { "CENTER", 0, 0 }
	elseif (placement == "inside-combat" and self.inCombat) then
		point = db.HealthValuePositionInside or { "CENTER", 0, 0 }
	else
		point = db.HealthValuePosition
	end

	value:ClearAllPoints()
	value:SetPoint(unpack(point))
end

local NamePlate_PostUpdateHoverElements = function(self)
	local db = ns.GetConfig("NamePlates")
	SetNameColorForUnit(self, db)

	if (self.isObjectPlate and not self.isPRD) then
		if (ShouldShowObjectPlateOverlay(self)) then
			if (self.Name and self.Name.UpdateTag) then
				pcall(self.Name.UpdateTag, self.Name)
			end
			if (self.Name and self.unit) then
				local nameText = self.Name:GetText()
				local nameIsEmpty = (type(nameText) ~= "string") or (not issecretvalue(nameText) and nameText == "")
				if (nameIsEmpty) then
					local rawName = UnitName(self.unit)
					if (type(rawName) == "string") then
						self.Name:SetText(rawName)
					end
				end
			end
			if (self.Name) then
				self.Name:Show()
			end
		elseif (self.Name) then
			self.Name:Hide()
		end
		if (self.Health and self.Health.Value) then
			self.Health.Value:Hide()
		end
		return
	end

	if (self.isPRD) then
		self.Health.Value:Hide()
		self.Name:Hide()
	else
		if (ShouldUseFriendlyPlayerNameOnly(self)) then
			self.Name:Show()
			if (self.Health and self.Health.Value) then
				self.Health.Value:Hide()
			end
			return
		end

		local showNameAlways = NamePlatesMod.db.profile.showNameAlways

		-- Force tag update to ensure name is always current
		-- This is critical for dungeons where events may not fire reliably
		if (self.Name and self.Name.UpdateTag) then
			pcall(self.Name.UpdateTag, self.Name)
		end

		-- Fallback: if the tag returned empty (secret value filtered out),
		-- try setting the name directly via SetText which handles secrets.
		-- GetText() returns a secret if the fontstring has a secret text aspect,
		-- so we must use issecretvalue() before comparing with == to avoid errors.
		if (self.Name and self.unit) then
			local nameText = self.Name:GetText()
			local nameIsEmpty = (type(nameText) ~= "string") or (not issecretvalue(nameText) and nameText == "")
			if (nameIsEmpty) then
				local rawName = UnitName(self.unit)
				if (type(rawName) == "string") then
					self.Name:SetText(rawName)
				end
			end
		end

		if (self.isMouseOver or self.isTarget or self.isSoftTarget or self.inCombat) then
			local castbar = self.Castbar
			if (castbar and (castbar.casting or castbar.channeling or castbar.empowering)) then
				self.Health.Value:Hide()
			else
				NamePlate_ApplyHealthValueLayout(self)
				self.Health.Value:Show()
			end
			self.Name:Show()
		else
			if (showNameAlways) then
				self.Name:Show()
			else
				self.Name:Hide()
			end
			self.Health.Value:Hide()
		end
	end
end

-- Element proxy for the position updater above.
local Auras_PostUpdate = function(element, unit)
	NamePlate_PostUpdatePositions(element.__owner)
end

local NamePlate_ResetCastbarVisuals = function(element)
	if (not element) then
		return
	end

	local db = ns.GetConfig("NamePlates")
	local baseTextColor = db and db.CastBarNameColor or nil
	local baseBarColor = db and db.CastBarColor or nil

	if (element.Text and type(baseTextColor) == "table") then
		local r, g, b = unpack(baseTextColor)
		element.Text:SetTextColor(r, g, b, 1)
	end

	if (type(baseBarColor) == "table") then
		local r, g, b, a = unpack(baseBarColor)
		element:SetStatusBarColor(r, g, b, a or 1)
		local texture = element.GetStatusBarTexture and element:GetStatusBarTexture()
		if (texture and texture.SetVertexColor) then
			texture:SetVertexColor(r, g, b, a or 1)
		end
	end

end

local ShouldColorNameplateSpellTextByState = function()
	return ns.UnitFrame and ns.UnitFrame.ShouldColorCastSpellTextByState and ns.UnitFrame.ShouldColorCastSpellTextByState() or false
end

local NamePlate_SetCastbarColor = function(element, color)
	if (not element or type(color) ~= "table") then
		return
	end

	local r, g, b, a = unpack(color)
	element:SetStatusBarColor(r, g, b, a or 1)
	local texture = element.GetStatusBarTexture and element:GetStatusBarTexture()
	if (texture and texture.SetVertexColor) then
		texture:SetVertexColor(r, g, b, a or 1)
	end
end

local NamePlate_CreateColorObject = function(color)
	if (type(CreateColor) ~= "function" or type(color) ~= "table") then
		return nil
	end

	return CreateColor(color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1)
end

local NamePlate_GetLiveNotInterruptible = function(element)
	local owner = element and element.__owner
	local unit = owner and owner.unit
	if (type(unit) ~= "string" or unit == "") then
		return nil
	end

	if (element and element.casting and UnitCastingInfo) then
		local castResult = { pcall(UnitCastingInfo, unit) }
		if (castResult[1]) then
			return castResult[9]
		end
	end

	if (element and element.channeling and UnitChannelInfo) then
		local channelResult = { pcall(UnitChannelInfo, unit) }
		if (channelResult[1]) then
			return channelResult[8]
		end
	end

	return nil
end

local NamePlate_ApplyLiveInterruptTextureColor = function(element, liveNotInterruptible, protectedColor, nextColor)
	local texture = element and element.GetStatusBarTexture and element:GetStatusBarTexture()
	if (not texture or type(texture.SetVertexColorFromBoolean) ~= "function") then
		return false
	end

	if (liveNotInterruptible == nil) then
		return false
	end
	if ((not IsSecretValue(liveNotInterruptible)) and type(liveNotInterruptible) ~= "boolean") then
		return false
	end

	local protectedColorObject = NamePlate_CreateColorObject(protectedColor)
	local nextColorObject = NamePlate_CreateColorObject(nextColor)
	if (not protectedColorObject or not nextColorObject) then
		return false
	end

	texture:SetVertexColorFromBoolean(liveNotInterruptible, protectedColorObject, nextColorObject)
	return true
end

local NamePlate_ClearInterruptState = function(element)
	if (not element) then
		return
	end
	element.__AzeriteUI_NotInterruptible = nil
	element.__AzeriteUI_ProbedNotInterruptible = nil
	element.__AzeriteUI_InterruptCastState = nil
	element.__AzeriteUI_LastInterruptColorUpdate = nil
	element.__AzeriteUI_EventNotInterruptible = nil
end

local Castbar_RefreshInterruptVisuals
local NamePlate_UpdateInterruptWatcher

local NamePlate_GetInterruptInfo
do
	local interruptListenerFrame
	local interruptInfoResolver

	local DetermineInterruptInfoResolver = function()
		local playerClass = select(3, UnitClass("player"))

		if (playerClass == 1) then -- Warrior
			return function()
				return { id = 6552, cooldown = 15 }
			end
		elseif (playerClass == 2) then -- Paladin
			return function()
				local specID = PlayerUtil and PlayerUtil.GetCurrentSpecID and PlayerUtil.GetCurrentSpecID() or nil
				local hasRebuke = (specID ~= 65) and C_SpellBook and C_SpellBook.IsSpellKnown and C_SpellBook.IsSpellKnown(96231)
				if (not hasRebuke) then
					return nil
				end
				return { id = 96231, cooldown = 15 }
			end
		elseif (playerClass == 3) then -- Hunter
			return function()
				local specID = PlayerUtil and PlayerUtil.GetCurrentSpecID and PlayerUtil.GetCurrentSpecID() or nil
				local spellID = (specID == 255) and 187707 or 147362
				if (not C_SpellBook or not C_SpellBook.IsSpellKnown or not C_SpellBook.IsSpellKnown(spellID)) then
					return nil
				end
				return { id = spellID, cooldown = (specID == 255) and 15 or 24 }
			end
		elseif (playerClass == 4) then -- Rogue
			return function()
				return { id = 1766, cooldown = 15 }
			end
		elseif (playerClass == 5) then -- Priest
			return function()
				local specID = PlayerUtil and PlayerUtil.GetCurrentSpecID and PlayerUtil.GetCurrentSpecID() or nil
				if (specID ~= 258 or not C_SpellBook or not C_SpellBook.IsSpellKnown or not C_SpellBook.IsSpellKnown(15487)) then
					return nil
				end
				return { id = 15487, cooldown = 45 }
			end
		elseif (playerClass == 6) then -- Death Knight
			return function()
				if (not C_SpellBook or not C_SpellBook.IsSpellKnown or not C_SpellBook.IsSpellKnown(47528)) then
					return nil
				end
				return { id = 47528, cooldown = 15 }
			end
		elseif (playerClass == 7) then -- Shaman
			return function()
				if (not C_SpellBook or not C_SpellBook.IsSpellKnown or not C_SpellBook.IsSpellKnown(57994)) then
					return nil
				end
				local specID = PlayerUtil and PlayerUtil.GetCurrentSpecID and PlayerUtil.GetCurrentSpecID() or nil
				return { id = 57994, cooldown = (specID == 264) and 30 or 12 }
			end
		elseif (playerClass == 8) then -- Mage
			return function()
				local hasQuickWitted = C_SpellBook and C_SpellBook.IsSpellKnown and C_SpellBook.IsSpellKnown(382297)
				return { id = 2139, cooldown = hasQuickWitted and 20 or 25 }
			end
		elseif (playerClass == 9) then -- Warlock
			return function()
				if (C_SpellBook and C_SpellBook.IsSpellKnown and Enum and Enum.SpellBookSpellBank) then
					if (C_SpellBook.IsSpellKnown(89766, Enum.SpellBookSpellBank.Pet)) then
						return { id = 89766, cooldown = 30 }
					end
					if (C_SpellBook.IsSpellKnown(19647, Enum.SpellBookSpellBank.Pet)) then
						return { id = 19647, cooldown = 24 }
					end
				end
				if (C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID and C_SpellBook and C_SpellBook.IsSpellKnownOrInSpellBook) then
					if (C_UnitAuras.GetPlayerAuraBySpellID(196099) ~= nil and C_SpellBook.IsSpellKnownOrInSpellBook(132409)) then
						return { id = 132409, cooldown = 24 }
					end
				end
				return nil
			end
		elseif (playerClass == 10) then -- Monk
			return function()
				local specID = PlayerUtil and PlayerUtil.GetCurrentSpecID and PlayerUtil.GetCurrentSpecID() or nil
				if (specID == 270 or not C_SpellBook or not C_SpellBook.IsSpellKnown or not C_SpellBook.IsSpellKnown(116705)) then
					return nil
				end
				return { id = 116705, cooldown = 15 }
			end
		elseif (playerClass == 11) then -- Druid
			return function()
				local specID = PlayerUtil and PlayerUtil.GetCurrentSpecID and PlayerUtil.GetCurrentSpecID() or nil
				if (specID == 105) then
					return nil
				end
				local spellID = (specID == 102) and 78675 or 106839
				if (not C_SpellBook or not C_SpellBook.IsSpellKnown or not C_SpellBook.IsSpellKnown(spellID)) then
					return nil
				end
				return { id = spellID, cooldown = (specID == 102) and 60 or 15 }
			end
		elseif (playerClass == 12) then -- Demon Hunter
			return function()
				if (not C_SpellBook or not C_SpellBook.IsSpellKnown or not C_SpellBook.IsSpellKnown(183752)) then
					return nil
				end
				return { id = 183752, cooldown = 15 }
			end
		elseif (playerClass == 13) then -- Evoker
			return function()
				local specID = PlayerUtil and PlayerUtil.GetCurrentSpecID and PlayerUtil.GetCurrentSpecID() or nil
				if (specID == 1468 or not C_SpellBook or not C_SpellBook.IsSpellKnown or not C_SpellBook.IsSpellKnown(351338)) then
					return nil
				end
				local hasInterwovenThreads = (specID == 1473) and C_SpellBook.IsSpellKnown(412713)
				return { id = 351338, cooldown = hasInterwovenThreads and 18 or 20 }
			end
		end

		return function()
			return nil
		end
	end

	local GetSpellCooldownEndTime = function(spellID)
		if (type(spellID) ~= "number" or spellID <= 0) then
			return nil
		end

		if (C_Spell and C_Spell.GetSpellCooldown) then
			local okInfo, cooldownInfo = pcall(C_Spell.GetSpellCooldown, spellID)
			if (okInfo and type(cooldownInfo) == "table") then
				local startTime = cooldownInfo.startTime
				local duration = cooldownInfo.duration
				if (type(startTime) == "number" and type(duration) == "number"
					and (not IsSecretValue(startTime)) and (not IsSecretValue(duration))
					and startTime > 0 and duration > 0) then
					return startTime + duration
				end
			end
		end

		if (GetSpellCooldown) then
			local okCooldown, startTime, duration = pcall(GetSpellCooldown, spellID)
			if (okCooldown
				and type(startTime) == "number"
				and type(duration) == "number"
				and (not IsSecretValue(startTime))
				and (not IsSecretValue(duration))
				and startTime > 0
				and duration > 0) then
				return startTime + duration
			end
		end

		return nil
	end

	local EnsureInterruptListenerFrame = function()
		if (interruptListenerFrame) then
			return interruptListenerFrame
		end

		interruptInfoResolver = DetermineInterruptInfoResolver()
		interruptListenerFrame = CreateFrame("Frame")
		interruptListenerFrame.lastInterrupt = 0
		interruptListenerFrame.nextInterruptAvailableAt = 0
		interruptListenerFrame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
		interruptListenerFrame:RegisterUnitEvent("PLAYER_SPECIALIZATION_CHANGED", "player")
		interruptListenerFrame:RegisterEvent("TRAIT_CONFIG_UPDATED")
		interruptListenerFrame:RegisterEvent("PLAYER_LOGIN")
		interruptListenerFrame:SetScript("OnEvent", function(self, event, unit, _, spellID)
			if (event == "UNIT_SPELLCAST_SUCCEEDED") then
				if (unit ~= "player") then
					return
				end

				local interruptInfo = interruptInfoResolver and interruptInfoResolver() or nil
				if (type(interruptInfo) ~= "table" or type(interruptInfo.id) ~= "number" or spellID ~= interruptInfo.id) then
					return
				end

				local now = GetTime()
				self.lastInterrupt = now
				self.nextInterruptAvailableAt = now + (interruptInfo.cooldown or 0)
				return
			end

			interruptInfoResolver = DetermineInterruptInfoResolver()
			local interruptInfo = interruptInfoResolver and interruptInfoResolver() or nil
			local cooldownEndTime = interruptInfo and GetSpellCooldownEndTime(interruptInfo.id) or 0
			self.nextInterruptAvailableAt = cooldownEndTime or 0
			if (self.nextInterruptAvailableAt <= GetTime()) then
				self.lastInterrupt = 0
				self.nextInterruptAvailableAt = 0
			end
		end)

		return interruptListenerFrame
	end

	NamePlate_GetInterruptInfo = function()
		local listener = EnsureInterruptListenerFrame()
		local interruptInfo = interruptInfoResolver and interruptInfoResolver() or nil
		if (type(interruptInfo) ~= "table" or type(interruptInfo.id) ~= "number") then
			return nil
		end

		local now = GetTime()
		local cooldownEndTime = GetSpellCooldownEndTime(interruptInfo.id)
		local nextInterruptAvailableAt = listener and listener.nextInterruptAvailableAt or 0
		if (type(cooldownEndTime) == "number" and cooldownEndTime > nextInterruptAvailableAt) then
			nextInterruptAvailableAt = cooldownEndTime
			if (listener) then
				listener.nextInterruptAvailableAt = cooldownEndTime
			end
		end

		return {
			id = interruptInfo.id,
			ready = not (type(nextInterruptAvailableAt) == "number" and nextInterruptAvailableAt > now),
			nextInterruptAvailableAt = nextInterruptAvailableAt
		}
	end
end

local NamePlate_HandleInterruptWatcherEvent = function(self, event, unit)
	local watchedUnit = self and self.__AzeriteUI_WatchedUnit
	if (type(unit) ~= "string" or unit ~= watchedUnit) then
		return
	end

	local element = self.__castbar
	if (not element) then
		return
	end

	if (event == "UNIT_SPELLCAST_NOT_INTERRUPTIBLE") then
		element.__AzeriteUI_EventNotInterruptible = true
	elseif (event == "UNIT_SPELLCAST_INTERRUPTIBLE") then
		element.__AzeriteUI_EventNotInterruptible = false
	elseif (event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START") then
		element.__AzeriteUI_EventNotInterruptible = nil
	elseif (event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_CHANNEL_STOP" or event == "UNIT_SPELLCAST_INTERRUPTED" or event == "UNIT_SPELLCAST_FAILED") then
		element.__AzeriteUI_EventNotInterruptible = nil
	end

	ns.API.UpdateInterruptCastBarRefresh(element, Castbar_RefreshInterruptVisuals, event)
end

local NamePlate_ClearInterruptWatcher = function(element)
	local watcher = element and element.InterruptWatcher
	if (not watcher) then
		return
	end

	watcher:UnregisterAllEvents()
	watcher.__AzeriteUI_WatchedUnit = nil
end

NamePlate_UpdateInterruptWatcher = function(element, unit)
	if (not element or type(unit) ~= "string" or unit == "" or not unit:match("^nameplate%d+$")) then
		NamePlate_ClearInterruptWatcher(element)
		return
	end

	local watcher = element.InterruptWatcher
	if (not watcher) then
		watcher = CreateFrame("Frame")
		watcher.__castbar = element
		watcher:SetScript("OnEvent", NamePlate_HandleInterruptWatcherEvent)
		element.InterruptWatcher = watcher
	end

	if (watcher.__AzeriteUI_WatchedUnit == unit) then
		return
	end

	watcher:UnregisterAllEvents()
	watcher:RegisterUnitEvent("UNIT_SPELLCAST_START", unit)
	watcher:RegisterUnitEvent("UNIT_SPELLCAST_STOP", unit)
	watcher:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", unit)
	watcher:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", unit)
	watcher:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTIBLE", unit)
	watcher:RegisterUnitEvent("UNIT_SPELLCAST_NOT_INTERRUPTIBLE", unit)
	watcher:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", unit)
	watcher:RegisterUnitEvent("UNIT_SPELLCAST_FAILED", unit)
	watcher.__AzeriteUI_WatchedUnit = unit
end

local NamePlate_GetRawNotInterruptible = function(element)
	local owner = element and element.__owner
	local unit = owner and owner.unit
	if (type(unit) ~= "string" or unit == "") then
		return nil, false
	end

	local rawNotInterruptible
	local sawSecretRaw = false
	if (UnitCastingInfo) then
		local castResult = { pcall(UnitCastingInfo, unit) }
		local okCast = castResult[1]
		local castNotInterruptible = castResult[9]
		if (okCast and type(castNotInterruptible) == "boolean") then
			if (IsSecretValue(castNotInterruptible)) then
				sawSecretRaw = true
			else
				rawNotInterruptible = castNotInterruptible
			end
		end
	end

	if (rawNotInterruptible == nil and UnitChannelInfo) then
		local channelResult = { pcall(UnitChannelInfo, unit) }
		local okChannel = channelResult[1]
		local channelNotInterruptible = channelResult[8]
		if (okChannel and type(channelNotInterruptible) == "boolean") then
			if (IsSecretValue(channelNotInterruptible)) then
				sawSecretRaw = true
			else
				rawNotInterruptible = channelNotInterruptible
			end
		end
	end

	if (type(rawNotInterruptible) == "boolean") then
		return rawNotInterruptible, sawSecretRaw
	end

	local castbarFlag = element and element.notInterruptible
	if ((not sawSecretRaw) and type(castbarFlag) == "boolean" and (not IsSecretValue(castbarFlag))) then
		return castbarFlag, false
	end

	return nil, sawSecretRaw
end

local NamePlate_GetBlizzardProtectedFallback = function(element)
	local owner = element and element.__owner
	local unit = owner and owner.unit
	if (type(unit) ~= "string" or unit == "" or not unit:match("^nameplate%d+$")) then
		return nil
	end
	if (not C_NamePlate or not C_NamePlate.GetNamePlateForUnit) then
		return nil
	end

	local okPlate, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit, issecurefunc and issecurefunc())
	local unitFrame = okPlate and plate and (plate.UnitFrame or plate.unitFrame)
	local blizzardCastbar = unitFrame and (unitFrame.castBar or unitFrame.CastBar or unitFrame.castbar or unitFrame.Castbar or unitFrame.CastingBarFrame)
	local active = blizzardCastbar and (blizzardCastbar.casting or blizzardCastbar.channeling or blizzardCastbar.empowering)
	if (not blizzardCastbar or not active) then
		return nil
	end

	local blizzardLocked = blizzardCastbar.notInterruptible
	if (type(blizzardLocked) == "boolean" and (not IsSecretValue(blizzardLocked)) and blizzardLocked) then
		return true
	end

	return nil
end

local Castbar_RefreshInterruptVisuals = function(element)
	if (not element) then
		return
	end

	local db = ns.GetConfig("NamePlates")
	local baseBarColor = db and db.CastBarColor or nil
	local baseTextColor = db and db.CastBarNameColor or nil

	NamePlate_ResetCastbarVisuals(element)

	local color, state
	local rawNotInterruptible, hasSecretRaw = NamePlate_GetRawNotInterruptible(element)
	local eventNotInterruptible = element.__AzeriteUI_EventNotInterruptible
	local blizzardProtected = NamePlate_GetBlizzardProtectedFallback(element)
	local liveNotInterruptible = NamePlate_GetLiveNotInterruptible(element)
	local dbState = nil
	if ((eventNotInterruptible == nil and rawNotInterruptible == nil and blizzardProtected ~= true) or hasSecretRaw) and ns.NameplateInterruptDB and ns.NameplateInterruptDB.GetFallbackStateForCastbar then
		dbState = ns.NameplateInterruptDB.GetFallbackStateForCastbar(element)
	end

	local interruptInfo = NamePlate_GetInterruptInfo()
	if (interruptInfo and interruptInfo.ready == false) then
		color = Colors.red
		state = "unavailable"
	elseif (interruptInfo and interruptInfo.ready == true) then
		color = { 1, .82, 0, 1 }
		state = "primary-ready"
	else
		color = baseBarColor
		state = "base"
	end

	if (dbState == "protected" or eventNotInterruptible == true or rawNotInterruptible == true or blizzardProtected == true) then
		state = "locked"
	elseif (dbState == "interruptible" or eventNotInterruptible == false or (rawNotInterruptible == false and (not hasSecretRaw))) then
		-- Keep the active red/yellow/base state chosen above.
	end

	if (type(color) == "table") then
		NamePlate_SetCastbarColor(element, color)
	end

	if (state == "locked") then
		NamePlate_SetCastbarColor(element, Colors.gray)
	elseif (type(color) == "table") then
		NamePlate_ApplyLiveInterruptTextureColor(element, liveNotInterruptible, Colors.gray, color)
	end

	if (element.Text) then
		local textColor = baseTextColor
		if (ShouldColorNameplateSpellTextByState()) then
			if (state == "locked") then
				textColor = Colors.gray
			elseif (state == "unavailable") then
				textColor = Colors.red
			elseif (state == "primary-ready") then
				textColor = { 1, .82, 0, 1 }
			end
		end
		if (type(textColor) == "table") then
			element.Text:SetTextColor(textColor[1], textColor[2], textColor[3], textColor[4] or 1)
		end
	end
end

local Castbar_PostCastVisual = function(element, unit)
	element.__AzeriteUI_InterruptCastState = nil
	element.__AzeriteUI_LastInterruptColorUpdate = nil
	NamePlate_UpdateInterruptWatcher(element, unit or (element.__owner and element.__owner.unit))
	ns.API.UpdateInterruptCastBarRefresh(element, Castbar_RefreshInterruptVisuals, "nameplate_postcast")
	NamePlate_PostUpdateHoverElements(element.__owner)
end

local Castbar_PostCastUpdate = function(element, unit)
	NamePlate_UpdateInterruptWatcher(element, unit or (element.__owner and element.__owner.unit))
	ns.API.UpdateInterruptCastBarRefresh(element, Castbar_RefreshInterruptVisuals, "nameplate_update")
	NamePlate_PostUpdateHoverElements(element.__owner)
end

local Castbar_PostUpdate = function(element, unit)
	NamePlate_PostUpdateHoverElements(element.__owner)
end

local Castbar_PostStop = function(element, unit)
	ns.API.ClearInterruptCastBarRefresh(element)
	NamePlate_ClearInterruptState(element)
	NamePlate_ResetCastbarVisuals(element)
	NamePlate_PostUpdateHoverElements(element.__owner)
end

local Castbar_PostFail = function(element, _)
	ns.API.ClearInterruptCastBarRefresh(element)
	NamePlate_ClearInterruptState(element)
	local r, g, b = Colors.red[1], Colors.red[2], Colors.red[3]
	if (element.Text) then
		element.Text:SetTextColor(r, g, b, 1)
	end
	element:SetStatusBarColor(r, g, b, 1)
	local texture = element.GetStatusBarTexture and element:GetStatusBarTexture()
	if (texture and texture.SetVertexColor) then
		texture:SetVertexColor(r, g, b, 1)
	end
	NamePlate_PostUpdateHoverElements(element.__owner)
end

-- Callback that handles positions of elements
-- that change position within their frame.
-- Called on full updates and settings changes.
local NamePlate_PostUpdateElements = function(self, event, unit, ...)
	if (unit and unit ~= self.unit) then return end

	local db = ns.GetConfig("NamePlates")
	local healthLab = GetNamePlateHealthLabSettings(db)
	local showFriendlyPlayerNameOnly = ShouldUseFriendlyPlayerNameOnly(self)

	if (self.isObjectPlate and not self.isPRD) then
		if (self:IsElementEnabled("Auras")) then
			self:DisableElement("Auras")
		end
		if (ShouldShowObjectPlateOverlay(self)) then
			ApplyObjectPlateVisualState(self)
			NamePlate_PostUpdateHoverElements(self)
		else
			ApplyHiddenNamePlateVisualState(self)
		end
		return
	end

	if (not ShouldShowNamePlateForBlizzardVisibility(self)) then
		ApplyHiddenNamePlateVisualState(self)
		return
	end

	if (self:GetAlpha() == 0) then
		self:SetAlpha(1)
	end
	if (self.SoftTargetFrame) then
		self.SoftTargetFrame:SetIgnoreParentAlpha(true)
		self.SoftTargetFrame:SetAlpha(1)
	end
	if (showFriendlyPlayerNameOnly) then
		ApplyFriendlyNameOnlyVisualState(self, true)
		SetNameColorForUnit(self, db)
		NamePlate_PostUpdatePositions(self)
		return
	end

	ApplyFriendlyNameOnlyVisualState(self, false)
	if (self.Health) then
		if (not self.Health:IsShown()) then
			self.Health:Show()
			if (self.Health.Backdrop) then
				self.Health.Backdrop:Show()
			end
		end
	end
	if (self.Castbar and not self.Castbar:IsShown()) then
		self.Castbar:Show()
	end
	local mainOrientation = healthLab.mainOrientation
	local absorbOrientation = healthLab.absorbOrientation
	if (self.isPRD) then
		mainOrientation, absorbOrientation = absorbOrientation, mainOrientation
	end

	self.Health:SetOrientation(mainOrientation)
	self.Health:SetTexCoord(healthLab.texLeft, healthLab.texRight, healthLab.texTop, healthLab.texBottom)
	self.Health:SetReverseFill(healthLab.healthReverseFill)
	self.Health:SetFlippedHorizontally(healthLab.healthSetFlippedHorizontally)
	self.Health.__AzeriteUI_UseProductionNativeFill = true
	self.Health.__AzeriteUI_DebugFlipLabEnabled = IsNamePlateHealthFlipLabDebugEnabled()
	self.Health.__AzeriteUI_FakeTexWidth = nil
	self.Health.__AzeriteUI_FakeTexHeight = nil
	self.Health.__AzeriteUI_FakeReverse = nil
	do
		local nativeTexture = self.Health:GetStatusBarTexture()
		if (nativeTexture and nativeTexture.SetAlpha) then
			nativeTexture:SetAlpha(1)
		end
		if (nativeTexture and nativeTexture.Show) then
			nativeTexture:Show()
		end
	end
	if (self.Health.Display) then
		self.Health.Display:SetAlpha(0)
		self.Health.Display:Hide()
	end
	if (self.Health.Preview) then
		self.Health.Preview:SetOrientation(mainOrientation)
		self.Health.Preview:SetTexCoord(healthLab.texLeft, healthLab.texRight, healthLab.texTop, healthLab.texBottom)
		self.Health.Preview:SetReverseFill(healthLab.previewReverseFill)
		self.Health.Preview:SetFlippedHorizontally(healthLab.previewSetFlippedHorizontally)
	end
	if (self.HealthPrediction and self.HealthPrediction.absorbBar) then
		self.HealthPrediction.absorbBar:SetOrientation(absorbOrientation)
		self.HealthPrediction.absorbBar:SetTexCoord(healthLab.texLeft, healthLab.texRight, healthLab.texTop, healthLab.texBottom)
		if (self.HealthPrediction.absorbBar.SetReverseFill) then
			self.HealthPrediction.absorbBar:SetReverseFill(healthLab.absorbReverseFill)
		end
		self.HealthPrediction.absorbBar:SetFlippedHorizontally(healthLab.absorbSetFlippedHorizontally)
	end
	self.Castbar:SetOrientation(mainOrientation)
	self.Castbar:SetTexCoord(healthLab.castTexLeft, healthLab.castTexRight, healthLab.castTexTop, healthLab.castTexBottom)
	if (self.Castbar.SetReverseFill) then
		self.Castbar:SetReverseFill(healthLab.castReverseFill)
	end
	self.Castbar:SetFlippedHorizontally(healthLab.castSetFlippedHorizontally)

	if (self.isPRD) then
		self:SetIgnoreParentAlpha(false)
		if (self:IsElementEnabled("Auras")) then
			self:DisableElement("Auras")
		end

		self.Castbar:SetSize(unpack(db.HealthBarSize))
		self.Castbar:ClearAllPoints()
		self.Castbar:SetAllPoints(self.Health)
		self.Castbar:SetSparkMap(db.HealthBarSparkMap)
		self.Castbar:SetStatusBarTexture(db.HealthBarTexture)
		self.Castbar:SetTexCoord(healthLab.texLeft, healthLab.texRight, healthLab.texTop, healthLab.texBottom)
		self.Castbar.Backdrop:Hide()
		self.Castbar.Text:ClearAllPoints()
		self.Castbar.Text:SetPoint(unpack(db.CastBarNamePositionPlayer))

	else

		if (NamePlatesMod.db.profile.showAuras and (not NamePlatesMod.db.profile.showAurasOnTargetOnly or self.isTarget)) then
			if (not self:IsElementEnabled("Auras")) then
				self:EnableElement("Auras")
				if (self.Auras.ForceUpdate) then
					self.Auras:ForceUpdate()
				end
			end
		else
			if (self:IsElementEnabled("Auras")) then
				self:DisableElement("Auras")
			end
		end

		if (self.WidgetContainer) then
			if (NamePlatesMod.db.profile.showBlizzardWidgets) then
				UpdateNamePlateWidgetContainer(self, true)

				local widgetFrames = self.WidgetContainer.widgetFrames

				if (widgetFrames) then
					for _, frame in next, widgetFrames do
						if (frame.Label) then
							frame.Label:SetAlpha(0)
						end
					end
				end
			else
				UpdateNamePlateWidgetContainer(self, false)
			end
		end

		if (self.isMouseOver or self.isTarget or self.isSoftTarget or self.inCombat) then
			-- SetIgnoreParentAlpha requires explicit true/false, or it'll bug out.
			self:SetIgnoreParentAlpha(((self.isMouseOver or self.isSoftTarget) and not self.isTarget) and true or false)
		else
			self:SetIgnoreParentAlpha(false)
		end

		self.Castbar:SetSize(unpack(db.CastBarSize))
		AnchorStandardNamePlateCastBar(self)
		self.Castbar:SetSparkMap(db.CastBarSparkMap)
		self.Castbar:SetStatusBarTexture(db.CastBarTexture)
		self.Castbar:SetTexCoord(healthLab.castTexLeft, healthLab.castTexRight, healthLab.castTexTop, healthLab.castTexBottom)
		self.Castbar.Backdrop:Show()
		self.Castbar.Text:ClearAllPoints()
		self.Castbar.Text:SetPoint(unpack(db.CastBarNamePosition))
	end

	SetNameColorForUnit(self, db)
	if (self.Castbar and event ~= "PLAYER_TARGET_CHANGED" and event ~= "PLAYER_SOFT_ENEMY_CHANGED" and event ~= "PLAYER_SOFT_INTERACT_CHANGED") then
		Castbar_PostUpdate(self.Castbar)
	end
	NamePlate_PostUpdatePositions(self)
end

-- This is called on UpdateAllElements,
-- which is called when a frame is shown or its unit changed.
local NamePlate_PostUpdate = function(self, event, unit, ...)
	if (unit and unit ~= self.unit) then return end

	unit = unit or self.unit
	if (self.Castbar) then
		NamePlate_UpdateInterruptWatcher(self.Castbar, unit)
	end

	self.inCombat = InCombatLockdown()
	
	self.isFocus = SafeUnitMatches(unit, "focus")
	self.isTarget = SafeUnitMatches(unit, "target")
	self.isSoftEnemy = SafeUnitMatches(unit, "softenemy")
	self.isSoftInteract = SafeUnitMatches(unit, "softinteract")
	self.isSoftTarget = (self.isSoftEnemy or self.isSoftInteract) and true or nil
	self.nameplateShowsWidgetsOnly = ns.IsRetail and UnitNameplateShowsWidgetsOnly(unit)
	local canAttack = UnitCanAttack("player", unit)
	local canAssist = UnitCanAssist("player", unit)
	local isPlayerUnit = UnitIsPlayer(unit)
	local playerControlled = UnitPlayerControlled(unit)
	local isTrivial = UnitIsTrivial(unit)
	local classification = UnitClassification(unit)
	local creatureType = UnitCreatureType(unit)
	local reaction = UnitReaction("player", unit)
	local guidType = GetGuidType(unit)
	local _, npcID = GetGuidAndNpcID(unit)
	if (issecretvalue and issecretvalue(canAttack)) then
		canAttack = nil
	end
	if (issecretvalue and issecretvalue(canAssist)) then
		canAssist = nil
	end
	if (issecretvalue and issecretvalue(isPlayerUnit)) then
		isPlayerUnit = false
	end
	if (issecretvalue and issecretvalue(playerControlled)) then
		playerControlled = false
	end
	if (issecretvalue and issecretvalue(isTrivial)) then
		isTrivial = false
	end
	if (issecretvalue and issecretvalue(classification)) then
		classification = nil
	end
	if (issecretvalue and issecretvalue(creatureType)) then
		creatureType = nil
	end
	if (issecretvalue and issecretvalue(reaction)) then
		reaction = nil
	end

	-- When canAttack/canAssist are secret (nil after guard), use UnitReaction as fallback.
	-- UnitReaction: 1=Hated..4=Neutral..8=Exalted; <= 4 means hostile/unfriendly.
	if (canAttack == nil and canAssist == nil and type(reaction) == "number") then
		if (reaction <= 4) then
			canAttack = true
		elseif (reaction >= 5) then
			canAssist = true
		end
	end

	self.canAttack = (canAttack == true)
	self.canAssist = (canAssist == true)
	self.isPlayerUnit = isPlayerUnit and true or nil

	local guidLooksLikeObject = (guidType == "GameObject") or (guidType == "AreaTrigger")
	local passiveWorldObjectLike = ((canAttack == false) and (canAssist == false) and (not isPlayerUnit) and (not playerControlled))
	local isCompanionLikeGuidType = (guidType == "Pet") or (guidType == "Creature") or (guidType == "Vehicle")
	local forceShowFriendlyNPC = (type(npcID) == "string") and AlwaysShowFriendlyNPCByID[npcID] and true or false
	local forceHideObjectLikeNPC = (type(npcID) == "string") and AlwaysHideObjectLikeNPCByID[npcID] and true or false
	local suppressObjectLikeNPCByID = forceHideObjectLikeNPC and (not forceShowFriendlyNPC) and true or false
	self.isObjectPlate = (guidLooksLikeObject or suppressObjectLikeNPCByID or (self.nameplateShowsWidgetsOnly and passiveWorldObjectLike and (not isCompanionLikeGuidType)) or (passiveWorldObjectLike and guidType == nil)) and true or nil
	self.isFriendlyAssistableNPC = (not self.isObjectPlate) and (not isPlayerUnit) and (canAttack ~= true) and ((canAssist == true) or forceShowFriendlyNPC) and (not playerControlled)

	local db = ns.GetConfig("NamePlates")
	local healthLab = GetNamePlateHealthLabSettings(db)
	local main, reverse = healthLab.mainOrientation, healthLab.absorbOrientation
	-- Fallback to safe defaults to avoid nil orientations crashing SetOrientation
	if (not main) then main = "LEFT" end
	if (not reverse) then
		reverse = (main == "LEFT") and "RIGHT" or "LEFT"
	end

	if (self.isPRD) then
		main, reverse = reverse, main
		self:DisableElement("RaidTargetIndicator")
	else
		if (self.nameplateShowsWidgetsOnly or self.isObjectPlate) then
			self:DisableElement("RaidTargetIndicator")
			if (self.RaidTargetIndicator) then
				self.RaidTargetIndicator:Hide()
			end
		else
			self:EnableElement("RaidTargetIndicator")
			self.RaidTargetIndicator:ForceUpdate()
		end
	end

	self.Castbar:SetOrientation(main)
	self.Health:SetOrientation(main)
	self.Health.Preview:SetOrientation(main)
	if (self.HealthPrediction.absorbBar) then self.HealthPrediction.absorbBar:SetOrientation(reverse) end

	ApplyNamePlateScale(self)
	Classification_Update(self, event, unit, ...)
	TargetHighlight_Update(self, event, unit, ...)
	NamePlate_PostUpdateElements(self, event, unit, ...)
end

local SoftNamePlate_OnEnter = function(self, ...)
	self.isSoftTarget = true
	ApplyNamePlateScale(self)
	if (self.OnEnter) then
		self:OnEnter(...)
	end
end

local SoftNamePlate_OnLeave = function(self, ...)
	self.isSoftTarget = nil
	ApplyNamePlateScale(self)
	if (self.OnLeave) then
		self:OnLeave(...)
	end
end

local NamePlate_OnEnter = function(self, ...)
	self.isMouseOver = true
	if (self.OnEnter) then
		self:OnEnter(...)
	end
end

local NamePlate_OnLeave = function(self, ...)
	self.isMouseOver = nil
	if (self.OnLeave) then
		self:OnLeave(...)
	end
end

local NamePlate_OnHide = function(self)
	self.inCombat = nil
	self.isFocus = nil
	self.isTarget = nil
	self.isSoftEnemy = nil
	self.isSoftInteract = nil
	self.canAttack = nil
	self.canAssist = nil
	self.isPlayerUnit = nil
	self.isObjectPlate = nil
	self.isFriendlyAssistableNPC = nil
	self.nameplateShowsWidgetsOnly = nil
	if (self.Castbar) then
		ns.API.ClearInterruptCastBarRefresh(self.Castbar)
		NamePlate_ClearInterruptState(self.Castbar)
		NamePlate_ClearInterruptWatcher(self.Castbar)
		NamePlate_ResetCastbarVisuals(self.Castbar)
	end

	if (self.RaidTargetIndicator) then
		self.RaidTargetIndicator:Hide()
	end
	if (self.Name) then
		self.Name:SetText("")
		self.Name:Hide()
	end
end

local NamePlate_OnEvent = function(self, event, unit, ...)
	-- WoW 12 secret-value safety: unit can be secret in some events
	if (issecretvalue(unit)) then
		unit = nil -- Fall back to self.unit
	end
	
	if (unit and unit ~= self.unit) then return end

	unit = unit or self.unit

	if (event == "PLAYER_REGEN_DISABLED") then
		self.inCombat = true
		ApplyNamePlateScale(self)

		NamePlate_PostUpdateElements(self, event, unit, ...)

		return

	elseif (event == "PLAYER_REGEN_ENABLED") then
		self.inCombat = nil
		ApplyNamePlateScale(self)

		NamePlate_PostUpdateElements(self, event, unit, ...)

		return

	elseif (event == "PLAYER_TARGET_CHANGED") then
		self.isTarget = SafeUnitMatches(unit, "target")
		ApplyNamePlateScale(self)

		Classification_Update(self, event, unit, ...)
		TargetHighlight_Update(self, event, unit, ...)
		NamePlate_PostUpdateElements(self, event, unit, ...)

		return
	elseif (event == "PLAYER_SOFT_ENEMY_CHANGED") then
		self.isSoftEnemy = SafeUnitMatches(unit, "softenemy")
		self.isSoftTarget = (self.isSoftEnemy or self.isSoftInteract) and true or nil
		ApplyNamePlateScale(self)

		Classification_Update(self, event, unit, ...)
		TargetHighlight_Update(self, event, unit, ...)
		NamePlate_PostUpdateElements(self, event, unit, ...)

		return
	elseif (event == "PLAYER_SOFT_INTERACT_CHANGED") then
		self.isSoftInteract = SafeUnitMatches(unit, "softinteract")
		self.isSoftTarget = (self.isSoftEnemy or self.isSoftInteract) and true or nil
		ApplyNamePlateScale(self)

		Classification_Update(self, event, unit, ...)
		TargetHighlight_Update(self, event, unit, ...)
		NamePlate_PostUpdateElements(self, event, unit, ...)

		return
	elseif (event == "PLAYER_FOCUS_CHANGED") then
		self.isFocus = SafeUnitMatches(unit, "focus")
		ApplyNamePlateScale(self)

		Classification_Update(self, event, unit, ...)
		TargetHighlight_Update(self, event, unit, ...)
		NamePlate_PostUpdateElements(self, event, unit, ...)

		return
	end

	NamePlate_PostUpdate(self, event, unit, ...)
end

local style = function(self, unit, id)

	local db = ns.GetConfig("NamePlates")
	local healthLab = GetNamePlateHealthLabSettings(db)

	self.colors = ns.Colors

	self:SetPoint("CENTER",0,0)
	self:SetSize(unpack(db.Size))
	ApplyNamePlateScale(self)
	self:SetFrameLevel(self:GetFrameLevel() + 2)

	self:SetScript("OnHide", NamePlate_OnHide)

	-- Overlay for icons and text
	--------------------------------------------
	local overlay = CreateFrame("Frame", nil, self)
	overlay:SetFrameLevel(self:GetFrameLevel() + 7)
	overlay:SetAllPoints()

	self.Overlay = overlay

	-- Health
	--------------------------------------------
	local health = self:CreateBar()
	if (health.SetForceNative) then health:SetForceNative(true) end
	health:SetFrameLevel(health:GetFrameLevel() + 2)
	health:SetPoint(unpack(db.HealthBarPosition))
	health:SetSize(unpack(db.HealthBarSize))
	health:SetStatusBarTexture(db.HealthBarTexture)
	health:SetTexCoord(healthLab.texLeft, healthLab.texRight, healthLab.texTop, healthLab.texBottom)
	health:SetOrientation(healthLab.mainOrientation)
	health:SetReverseFill(healthLab.healthReverseFill)
	health:SetFlippedHorizontally(healthLab.healthSetFlippedHorizontally)
	health:SetSparkMap(db.HealthBarSparkMap)
	health.predictThreshold = .01
	health.colorDisconnected = true
	health.colorTapping = true
	health.colorThreat = true
	health.colorClass = true
	health.colorClassPet = true
	health.colorClassHostileOnly = true
	health.colorHappiness = true
	health.colorReaction = true

	self.Health = health
	self.Health.Override = ns.API.UpdateHealth
	self.Health.PostUpdate = Health_PostUpdate
	self.Health.UpdateColor = Health_UpdateColor
	self.Health.PostUpdateColor = Health_PostUpdateColor
	self.Health.__AzeriteUI_UseProductionNativeFill = true
	self.Health.__AzeriteUI_DebugFlipLabEnabled = IsNamePlateHealthFlipLabDebugEnabled()
	ns.API.BindStatusBarValueMirror(self.Health)

	local healthBackdrop = health:CreateTexture(nil, "BACKGROUND", nil, -1)
	healthBackdrop:SetPoint(unpack(db.HealthBackdropPosition))
	healthBackdrop:SetSize(unpack(db.HealthBackdropSize))
	healthBackdrop:SetTexture(db.HealthBackdropTexture)

	self.Health.Backdrop = healthBackdrop

	local healthOverlay = CreateFrame("Frame", nil, health)
	healthOverlay:SetFrameLevel(overlay:GetFrameLevel())
	healthOverlay:SetAllPoints()

	self.Health.Overlay = healthOverlay

	self.Health.__AzeriteUI_UseProductionNativeFill = true

	local healthPreview = self:CreateBar(nil, health)
	if (healthPreview.SetForceNative) then healthPreview:SetForceNative(true) end
	healthPreview:SetAllPoints(health)
	healthPreview:SetFrameLevel(health:GetFrameLevel() - 1)
	healthPreview:SetStatusBarTexture(db.HealthBarTexture)
	healthPreview:SetSparkTexture("")
	healthPreview:SetAlpha(0)
	healthPreview:Hide()
	healthPreview:DisableSmoothing(true)
	healthPreview:SetOrientation(healthLab.mainOrientation)
	healthPreview:SetTexCoord(healthLab.texLeft, healthLab.texRight, healthLab.texTop, healthLab.texBottom)
	healthPreview:SetReverseFill(healthLab.previewReverseFill)
	healthPreview:SetFlippedHorizontally(healthLab.previewSetFlippedHorizontally)

	self.Health.Preview = healthPreview

	-- Health Prediction
	--------------------------------------------
	local healPredictFrame = CreateFrame("Frame", nil, health)
	healPredictFrame:SetFrameLevel(health:GetFrameLevel() + 2)

	local healPredict = healPredictFrame:CreateTexture(nil, "OVERLAY", nil, 1)
	healPredict:SetTexture(db.HealthBarTexture)
	healPredict.health = health
	healPredict.preview = healthPreview
	healPredict.maxOverflow = 1

	self.HealthPrediction = healPredict
	-- self.HealthPrediction.PostUpdate = HealPredict_PostUpdate -- Temporary rollback: broken white prediction overlay covers nameplate health bars.
	self.HealthPrediction:SetAlpha(0)
	self.HealthPrediction:Hide()

	-- Castbar
	--------------------------------------------
	local castbar = self:CreateBar()
	if (castbar.SetForceNative) then castbar:SetForceNative(true) end
	castbar:SetFrameLevel(self:GetFrameLevel() + 5)
	castbar:SetSize(unpack(db.CastBarSize))
	castbar:SetPoint("TOP", health, "BOTTOM", 0, -1)
	castbar:SetSparkMap(db.CastBarSparkMap)
	castbar:SetStatusBarTexture(db.CastBarTexture)
	castbar:SetStatusBarColor(unpack(db.CastBarColor))
	castbar:SetTexCoord(healthLab.castTexLeft, healthLab.castTexRight, healthLab.castTexTop, healthLab.castTexBottom)
	castbar:SetOrientation(healthLab.mainOrientation)
	if (castbar.SetReverseFill) then
		castbar:SetReverseFill(healthLab.castReverseFill)
	end
	castbar:SetFlippedHorizontally(healthLab.castSetFlippedHorizontally)
	castbar:DisableSmoothing(true)
	castbar.timeToHold = db.CastBarTimeToHoldFailed

	self.Castbar = castbar
	self.Castbar.PostCastStart = Castbar_PostCastVisual
	self.Castbar.PostCastUpdate = Castbar_PostCastUpdate
	self.Castbar.PostCastStop = Castbar_PostStop
	self.Castbar.PostCastFail = Castbar_PostFail
	self.Castbar.PostCastInterrupted = Castbar_PostFail
	self.Castbar.PostCastInterruptible = Castbar_PostCastVisual
	ns.API.AttachScriptSafe(self.Castbar, "OnHide", function(element)
		ns.API.ClearInterruptCastBarRefresh(element)
		NamePlate_ClearInterruptState(element)
		NamePlate_ResetCastbarVisuals(element)
	end)

	local castBackdrop = castbar:CreateTexture(nil, "BACKGROUND", nil, -1)
	castBackdrop:SetSize(unpack(db.CastBarBackdropSize))
	castBackdrop:SetPoint(unpack(db.CastBarBackdropPosition))
	castBackdrop:SetTexture(db.CastBarBackdropTexture)

	self.Castbar.Backdrop = castBackdrop

	local castText = castbar:CreateFontString(nil, "OVERLAY", nil, 1)
	castText:SetPoint(unpack(db.CastBarNamePosition))
	castText:SetJustifyH(db.CastBarNameJustifyH)
	castText:SetJustifyV(db.CastBarNameJustifyV)
	castText:SetFontObject(db.CastBarNameFont)
	castText:SetTextColor(unpack(db.CastBarNameColor))
	if (castText.SetWordWrap) then
		castText:SetWordWrap(false)
	end

	self.Castbar.Text = castText

	-- Health Value
	--------------------------------------------
	local healthValue = healthOverlay:CreateFontString(nil, "OVERLAY", nil, 1)
	healthValue:SetPoint(unpack(db.HealthValuePosition))
	healthValue:SetWidth((db.HealthBarSize and db.HealthBarSize[1] or 92) - 8)
	healthValue:SetFontObject(db.HealthValueFont)
	healthValue:SetTextColor(unpack(db.HealthValueColor))
	healthValue:SetJustifyH(db.HealthValueJustifyH)
	healthValue:SetJustifyV(db.HealthValueJustifyV)
	self:Tag(healthValue, prefix("[*:HealthCurrent]"))

	self.Health.Value = healthValue
	NamePlate_ApplyHealthValueLayout(self)

	-- Health Percentage (disabled for nameplates)

	-- Power
	--------------------------------------------
	local power = CreateFrame("StatusBar", nil, self)
	power:SetFrameLevel(health:GetFrameLevel() + 2)
	power:SetPoint(unpack(db.PowerBarPosition))
	power:SetSize(unpack(db.PowerBarSize))
	power:SetStatusBarTexture(db.PowerBarTexture)
	local ptex = power:GetStatusBarTexture()
	if ptex and ptex.SetTexCoord and db.PowerBarTexCoord then
		ptex:SetTexCoord(unpack(db.PowerBarTexCoord))
	end
	-- Vertical fill; flip for DOWN to keep art static
	if (db.PowerBarOrientation == "DOWN") then
		power:SetOrientation("VERTICAL")
		if ptex and ptex.SetTexCoord then ptex:SetTexCoord(0,1,1,0) end
	else
		power:SetOrientation("VERTICAL")
	end
	power:SetAlpha(0)
	power.isHidden = true
	power.frequentUpdates = true
	power.displayAltPower = true
	power.colorPower = true
	power.safeBarMin = 0
	power.safeBarMax = 1
	power.safeBarValue = 1

	self.Power = power
	self.Power.Override = ns.API.UpdatePower
	self.Power.PostUpdate = Power_PostUpdate
	ns.API.BindStatusBarValueMirror(self.Power)

	local powerBackdrop = power:CreateTexture(nil, "BACKGROUND", nil, -1)
	powerBackdrop:SetPoint(unpack(db.PowerBarBackdropPosition))
	powerBackdrop:SetSize(unpack(db.PowerBarBackdropSize))
	powerBackdrop:SetTexture(db.PowerBarBackdropTexture)

	self.Power.Backdrop = powerBackdrop

	-- Unit Name
	--------------------------------------------
	local name = self:CreateFontString(nil, "OVERLAY", nil, 1)
	name:SetPoint(unpack(db.NamePosition))
	name:SetFontObject(db.NameFont)
	name:SetTextColor(unpack(db.NameColor))
	name:SetJustifyH(db.NameJustifyH)
	name:SetJustifyV(db.NameJustifyV)
	if (name.SetWordWrap) then
		name:SetWordWrap(false)
	end
	--self:Tag(name, prefix("[*:Name(32,nil,nil,true)]"))
	self:Tag(name, prefix("[*:Name(24,nil,nil,nil)]")) -- maxChars, showLevel, showLevelLast, showFull

	self.Name = name

	-- Absorb Bar
	--------------------------------------------
	if (ns.IsRetail) then
		local absorb = self:CreateBar()
		if (absorb.SetForceNative) then absorb:SetForceNative(true) end
		absorb:SetAllPoints(health)
		absorb:SetFrameLevel(health:GetFrameLevel() + 3)
		absorb:SetStatusBarTexture(db.HealthBarTexture)
		absorb:SetStatusBarColor(unpack(db.HealthAbsorbColor))
		absorb:SetTexCoord(healthLab.texLeft, healthLab.texRight, healthLab.texTop, healthLab.texBottom)
		absorb:SetSparkMap(db.HealthBarSparkMap)
		absorb:SetAlpha(0)
		absorb:Hide()
		absorb:SetOrientation(healthLab.absorbOrientation)
		if (absorb.SetReverseFill) then
			absorb:SetReverseFill(healthLab.absorbReverseFill)
		end
		absorb:SetFlippedHorizontally(healthLab.absorbSetFlippedHorizontally)

		-- self.HealthPrediction.absorbBar = absorb -- Temporary rollback: broken absorb overlay covers nameplate health bars.
	end

	-- Target Highlight
	--------------------------------------------
	local targetHighlight = healthOverlay:CreateTexture(nil, "BACKGROUND", nil, -2)
	targetHighlight:SetPoint(unpack(db.TargetHighlightPosition))
	targetHighlight:SetSize(unpack(db.TargetHighlightSize))
	targetHighlight:SetTexture(db.TargetHighlightTexture)
	targetHighlight.colorTarget = db.TargetHighlightTargetColor
	targetHighlight.colorFocus = db.TargetHighlightFocusColor
	targetHighlight.colorSoftEnemy = db.TargetHighlightSoftEnemyColor
	targetHighlight.colorSoftInteract = db.TargetHighlightSoftInteractColor

	self.TargetHighlight = targetHighlight

	-- Raid Target Indicator
	--------------------------------------------
	local raidTarget = self:CreateTexture(nil, "OVERLAY", nil, 1)
	raidTarget:SetSize(unpack(db.RaidTargetSize))
	raidTarget:SetPoint(unpack(db.RaidTargetPosition))
	raidTarget:SetTexture(db.RaidTargetTexture)

	self.RaidTargetIndicator = raidTarget

	-- Classification Badge
	--------------------------------------------
	local classification = healthOverlay:CreateTexture(nil, "OVERLAY", nil, -2)
	classification:SetSize(unpack(db.ClassificationSize))
	classification:SetPoint(unpack(db.ClassificationPosition))
	classification.bossTexture = db.ClassificationIndicatorBossTexture
	classification.eliteTexture = db.ClassificationIndicatorEliteTexture
	classification.rareTexture = db.ClassificationIndicatorRareTexture

	self.Classification = classification

	-- Threat
	--------------------------------------------
	local threatIndicator = health:CreateTexture(nil, "BACKGROUND", nil, -2)
	threatIndicator:SetPoint(unpack(db.ThreatPosition))
	threatIndicator:SetSize(unpack(db.ThreatSize))
	threatIndicator:SetTexture(db.ThreatTexture)

	self.ThreatIndicator = threatIndicator

	-- Auras
	--------------------------------------------
	local auras = CreateFrame("Frame", nil, self)
	auras:SetSize(unpack(db.AurasSize))
	auras:SetPoint(unpack(db.AurasPosition))
	auras.size = db.AuraSize
	auras.spacing = db.AuraSpacing
	auras.numTotal = db.AurasNumTotal
	auras.numPerRow = db.AurasNumPerRow -- for our raid target indicator callback
	auras.disableMouse = db.AurasDisableMouse
	auras.disableCooldown = db.AurasDisableCooldown
	auras.onlyShowPlayer = db.AurasOnlyShowPlayer
	auras.showStealableBuffs = db.AurasShowStealableBuffs
	auras.initialAnchor = db.AurasInitialAnchor
	auras["spacing-x"] = db.AurasSpacingX
	auras["spacing-y"] = db.AurasSpacingY
	auras["growth-x"] = db.AurasGrowthX
	auras["growth-y"] = db.AurasGrowthY
	auras.sortMethod = db.AurasSortMethod
	auras.sortDirection = db.AurasSortDirection
	auras.reanchorIfVisibleChanged = true
	auras.allowCombatUpdates = true
	auras.CustomFilter = ns.AuraFilters.NameplateAuraFilter -- classic
	auras.FilterAura = ns.AuraFilters.NameplateAuraFilter -- retail
	auras.CreateButton = ns.AuraStyles.CreateSmallButton
	auras.PostUpdateButton = ns.AuraStyles.NameplatePostUpdateButton

	if (ns:GetModule("UnitFrames").db.global.disableAuraSorting) then
		auras.PreSetPosition = ns.AuraSorts.Alternate -- only in classic
		auras.SortAuras = ns.AuraSorts.AlternateFuncton -- only in retail
	else
		auras.PreSetPosition = ns.AuraSorts.Default -- only in classic
		auras.SortAuras = ns.AuraSorts.DefaultFunction -- only in retail
	end

	self.Auras = auras
	self.Auras.PostUpdate = Auras_PostUpdate

	self.PostUpdate = NamePlate_PostUpdate
	self.OnEnter = NamePlate_PostUpdateElements
	self.OnLeave = NamePlate_PostUpdateElements
	--self.OnHide = NamePlate_OnHide

	-- Register events to handle additional texture updates.
	self:RegisterEvent("PLAYER_ENTERING_WORLD", NamePlate_OnEvent, true)
	self:RegisterEvent("PLAYER_TARGET_CHANGED", NamePlate_OnEvent, true)
	self:RegisterEvent("PLAYER_FOCUS_CHANGED", NamePlate_OnEvent, true)
	self:RegisterEvent("PLAYER_REGEN_ENABLED", NamePlate_OnEvent, true)
	self:RegisterEvent("PLAYER_REGEN_DISABLED", NamePlate_OnEvent, true)
	self:RegisterEvent("UNIT_CLASSIFICATION_CHANGED", NamePlate_OnEvent)
	self:RegisterEvent("PLAYER_SOFT_ENEMY_CHANGED", NamePlate_OnEvent, true)
	self:RegisterEvent("PLAYER_SOFT_INTERACT_CHANGED", NamePlate_OnEvent, true)

	-- Make our nameplates obey UIParent alpha and fade out when Immersion says so.
	hooksecurefunc(UIParent, "SetAlpha", function() self:SetAlpha(UIParent:GetAlpha()) end)

end

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
	["nameplateOtherAtBase"] = 0, -- Show nameplates above heads or at the base (0 or 2)

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
	["nameplateMaxDistance"] = ns.IsRetail and NAMEPLATE_MAX_DISTANCE_DEFAULT or ns.IsClassic and 20 or 40, -- Wrath and TBC have 41

	-- The maximum distance from the camera (not char) where plates will still have max scale
	["nameplateMaxScaleDistance"] = 10,

	-- The distance from the max distance that nameplates will reach their minimum scale.
	["nameplateMinScaleDistance"] = 5,

	["nameplateMaxScale"] = GLOBAL_NAMEPLATE_MAX_SCALE, -- The max scale of nameplates.
	["nameplateMinScale"] = GLOBAL_NAMEPLATE_MIN_SCALE, -- Keep readable non-target plate scale.
	["nameplateSelectedScale"] = GLOBAL_NAMEPLATE_SELECTED_SCALE_NEUTRAL, -- Neutralized; target scaling handled in frame math.

	-- The distance from the camera that nameplates will reach their maximum alpha.
	["nameplateMaxAlphaDistance"] = 10,

	-- The distance from the max distance that nameplates will reach their minimum alpha.
	["nameplateMinAlphaDistance"] = 5,

	["nameplateMaxAlpha"] = 1, -- The max alpha of nameplates.
	["nameplateMinAlpha"] = .4, -- The minimum alpha of nameplates.
	["nameplateOccludedAlphaMult"] = .15, -- Alpha multiplier of hidden plates
	["nameplateSelectedAlpha"] = 1, -- Alpha multiplier of targeted nameplate

	-- The max distance to show the target nameplate when the target is behind the camera.
	["nameplateTargetBehindMaxDistance"] = 15, -- 15

}

local callback = function(self, event, unit)
	if (event == "PLAYER_TARGET_CHANGED") then
	elseif (event == "NAME_PLATE_UNIT_ADDED") then

		-- Debug helper: Uncomment to see unit properties for debugging
		-- This will help identify properties of units like the Tuskarr Beanbag
		--[[
		local unitName = UnitName(unit)
		if (unitName and string.find(unitName, "Beanbag")) then
			print("DEBUG: " .. unitName)
			print("  CreatureType:", UnitCreatureType(unit) or "nil")
			print("  IsPlayer:", UnitIsPlayer(unit))
			print("  PlayerControlled:", UnitPlayerControlled(unit))
			print("  CanAttack:", UnitCanAttack("player", unit))
			print("  CanAssist:", UnitCanAssist("player", unit))
			print("  FactionGroup:", UnitFactionGroup(unit) or "nil")
			print("  Classification:", UnitClassification(unit) or "nil")
			print("  GUID:", UnitGUID(unit) or "nil")
		end
		--]]

		self.isPRD = SafeUnitMatches(unit, "player")

		if (self.WidgetContainer) then
			if (NamePlatesMod.db.profile.showBlizzardWidgets) then
				UpdateNamePlateWidgetContainer(self, true)

				local widgetFrames = self.WidgetContainer.widgetFrames

				if (widgetFrames) then
					for _, frame in next, widgetFrames do
						if (frame.Label) then
							frame.Label:SetAlpha(0)
						end
					end
				end
			else
				UpdateNamePlateWidgetContainer(self, false)
			end
		end

		if (self.SoftTargetFrame) then
			self.SoftTargetFrame:SetIgnoreParentAlpha(true)
			self.SoftTargetFrame:SetParent(self)
			self.SoftTargetFrame:ClearAllPoints()
			self.SoftTargetFrame:SetPoint("BOTTOM", self.Name, "TOP", 0, 0)
		end

		ns.NamePlates[self] = true
		ns.ActiveNamePlates[self] = true

		if (C_Timer and C_Timer.After) then
			C_Timer.After(0, function()
				if (self and self.unit == unit) then
					NamePlate_PostUpdate(self, "NAME_PLATE_UNIT_ADDED", unit)
				end
			end)
		else
			NamePlate_PostUpdate(self, "NAME_PLATE_UNIT_ADDED", unit)
		end

	elseif (event == "NAME_PLATE_UNIT_REMOVED") then

		if (self.WidgetContainer) then
			if (NamePlatesMod.db.profile.showBlizzardWidgets) then
				UpdateNamePlateWidgetContainer(self, true)
			else
				UpdateNamePlateWidgetContainer(self, false)
			end
		end

		if (self.SoftTargetFrame) then
			self.SoftTargetFrame:SetIgnoreParentAlpha(false)
			if (self.blizzPlate) then
				self.SoftTargetFrame:SetParent(self.blizzPlate)
				self.SoftTargetFrame:ClearAllPoints()
				if (self.blizzPlate.name) then
					self.SoftTargetFrame:SetPoint("BOTTOM", self.blizzPlate.name, "TOP", 0, -8)
				end
			end
		end

		self.isPRD = nil
		self.inCombat = nil
		self.isFocus = nil
		self.isTarget = nil
		self.isSoftEnemy = nil
		self.isSoftInteract = nil
		self.isObjectPlate = nil
		self.nameplateShowsWidgetsOnly = nil

		if (self.RaidTargetIndicator) then
			self.RaidTargetIndicator:Hide()
		end
		if (self.Name) then
			self.Name:SetText("")
			self.Name:Hide()
		end

		ns.ActiveNamePlates[self] = nil
	end
end

local MOUSEOVER
local checkMouseOver = function()
	if (UnitExists("mouseover")) then
		if (MOUSEOVER) then
			if (SafeUnitMatches(MOUSEOVER.unit, "mouseover")) then
				return
			end
			NamePlate_OnLeave(MOUSEOVER)
			MOUSEOVER = nil
		end
		for frame in next,ns.ActiveNamePlates do
			if (SafeUnitMatches(frame.unit, "mouseover")) then
				MOUSEOVER = frame
				return NamePlate_OnEnter(MOUSEOVER)
			end
		end
	elseif (MOUSEOVER) then
		NamePlate_OnLeave(MOUSEOVER)
		MOUSEOVER = nil
	end
end

local SOFTTARGET
local checkSoftTarget = function()
	if (UnitExists("softenemy") or UnitExists("softinteract")) then
		if (SOFTTARGET) then
			local EnemyDead = false
			if (UnitIsDead("softenemy")) then
				EnemyDead = true
			end
			if ((SafeUnitMatches(SOFTTARGET.unit, "softenemy") and not EnemyDead) or SafeUnitMatches(SOFTTARGET.unit, "softinteract")) then
				return
			end
			SoftNamePlate_OnLeave(SOFTTARGET)
			SOFTTARGET = nil
		end
		for frame in next,ns.ActiveNamePlates do
			local EnemyDead = false
			if (UnitIsDead("softenemy")) then
				EnemyDead = true
			end
			if ((SafeUnitMatches(frame.unit, "softenemy") and not EnemyDead) or SafeUnitMatches(frame.unit, "softinteract")) then
				SOFTTARGET = frame
				return SoftNamePlate_OnEnter(SOFTTARGET)
			end
		end
	elseif (SOFTTARGET) then
		SoftNamePlate_OnLeave(SOFTTARGET)
		SOFTTARGET = nil
	end
end

NamePlatesMod.CheckForConflicts = function(self)
	for i,addon in next,{
		"BetterBlizzPlates",
		"ClassicPlatesPlus",
		"Kui_Nameplates",
		"NamePlateKAI",
		"Nameplates",
		"NDui",
		"NeatPlates",
		"Plater",
		"SimplePlates",
		"TidyPlates",
		"TidyPlates_ThreatPlates",
		"TidyPlatesContinued" } do
		if (ns.API.IsAddOnEnabled(addon)) then
			return true
		end
	end
end

NamePlatesMod.HookNamePlates = function(self)
	-- WoW 12+: keep invasive reparent logic disabled, but still apply light
	-- per-instance guards to Blizzard nameplate frames.
	local secretMode = issecretvalue and true or false

	local hiddenParent = self.hiddenBlizzardNamePlateParent
	if (not hiddenParent) then
		hiddenParent = CreateFrame("Frame", nil, UIParent)
		hiddenParent:Hide()
		self.hiddenBlizzardNamePlateParent = hiddenParent
	end

	local hookedBlizzardUFs = self.hookedBlizzardNamePlateUFs
	if (not hookedBlizzardUFs) then
		hookedBlizzardUFs = {}
		self.hookedBlizzardNamePlateUFs = hookedBlizzardUFs
	end

	local modifiedBlizzardUFs = self.modifiedBlizzardNamePlateUFs
	if (not modifiedBlizzardUFs) then
		modifiedBlizzardUFs = {}
		self.modifiedBlizzardNamePlateUFs = modifiedBlizzardUFs
	end

	local issecurefunc = issecure or function() return false end

	local reparentKeys = {
		"HealthBarsContainer",
		"castBar",
		"CastBar",
		"RaidTargetFrame",
		"ClassificationFrame",
		"PlayerLevelDiffFrame",
		"SoftTargetFrame",
		"name",
		"aggroHighlight",
		"aggroHighlightBase",
		"aggroHighlightAdditive"
	}

	local function DisableBlizzardNamePlate(unit)
		if (true) then
			return
		end
		if (not C_NamePlate or not C_NamePlate.GetNamePlateForUnit) then
			return
		end
		local nameplate = C_NamePlate.GetNamePlateForUnit(unit, issecurefunc())
		if (not nameplate or not nameplate.UnitFrame) then
			return
		end
		local UF = nameplate.UnitFrame
		if (UF:IsForbidden()) then
			return
		end

		modifiedBlizzardUFs[unit] = UF

		UF:UnregisterAllEvents()
		if (UF.SetAlpha) then
			UF:SetAlpha(0)
		end
		local auraFrame = UF.AurasFrame
		if (auraFrame) then
			if (auraFrame.UnregisterAllEvents) then
				auraFrame:UnregisterAllEvents()
			end
			if (auraFrame.DebuffListFrame) then
				auraFrame.DebuffListFrame:SetParent(hiddenParent)
			end
			if (auraFrame.BuffListFrame) then
				auraFrame.BuffListFrame:SetParent(hiddenParent)
			end
			if (auraFrame.CrowdControlListFrame) then
				auraFrame.CrowdControlListFrame:SetParent(hiddenParent)
			end
			if (auraFrame.LossOfControlFrame) then
				auraFrame.LossOfControlFrame:SetParent(hiddenParent)
			end
		end

		for _, key in ipairs(reparentKeys) do
			local frame = UF[key]
			if (frame and frame.SetParent) then
				frame:SetParent(hiddenParent)
			end
		end

		local bar = UF.castBar or UF.CastBar or UF.castbar or UF.Castbar or UF.CastingBarFrame
		if (bar) then
			bar.highlightWhenCastTarget = false
			bar.isHighlightedCastTarget = false
			if (bar.CastTargetIndicator) then
				bar.CastTargetIndicator:Hide()
			end
			bar.SetIsHighlightedCastTarget = ns.Noop
			bar.UpdateHighlightWhenCastTarget = ns.Noop
			bar.SetHighlightWhenCastTarget = ns.Noop
		end

		if (not hookedBlizzardUFs[UF]) then
			hookedBlizzardUFs[UF] = true
			local locked = false
			hooksecurefunc(UF, "SetAlpha", function(frame)
				if (locked or frame:IsForbidden()) then
					return
				end
				locked = true
				frame:SetAlpha(0)
				locked = false
			end)
		end
	end

	local function RestoreBlizzardNamePlate(unit)
		if (true) then
			return
		end
		local UF = modifiedBlizzardUFs[unit]
		if (not UF) then
			return
		end
		if (UF:IsForbidden()) then
			modifiedBlizzardUFs[unit] = nil
			return
		end
		for _, key in ipairs(reparentKeys) do
			local frame = UF[key]
			if (frame and frame.SetParent) then
				frame:SetParent(UF)
			end
		end
		local auraFrame = UF.AurasFrame
		if (auraFrame) then
			if (auraFrame.DebuffListFrame) then
				auraFrame.DebuffListFrame:SetParent(auraFrame)
			end
			if (auraFrame.BuffListFrame) then
				auraFrame.BuffListFrame:SetParent(auraFrame)
			end
			if (auraFrame.CrowdControlListFrame) then
				auraFrame.CrowdControlListFrame:SetParent(auraFrame)
			end
			if (auraFrame.LossOfControlFrame) then
				auraFrame.LossOfControlFrame:SetParent(auraFrame)
			end
		end
		modifiedBlizzardUFs[unit] = nil
	end

	local clearClutter = function(frame)
		if (not frame or (frame.IsForbidden and frame:IsForbidden())) then
			return
		end
		local UF = frame.UnitFrame or frame.unitFrame
		if (UF and not (UF.IsForbidden and UF:IsForbidden())) then
			if (not UF.__AzeriteUI_Disabled) then
				UF.__AzeriteUI_Disabled = true
				pcall(function() UF:UnregisterAllEvents() end)
				pcall(function() UF:SetAlpha(0) end)
			end
			local health = UF.healthBar or UF.healthbar or UF.HealthBar
			if (health and health.UnregisterAllEvents) then
				pcall(function() health:UnregisterAllEvents() end)
			end
			local power = UF.manabar or UF.ManaBar
			if (power and power.UnregisterAllEvents) then
				pcall(function() power:UnregisterAllEvents() end)
			end
			local castbar = UF.castBar or UF.CastBar or UF.CastingBarFrame
			if (castbar and castbar.UnregisterAllEvents) then
				pcall(function() castbar:UnregisterAllEvents() end)
			end
			local auras = UF.AurasFrame
			if (auras and not (auras.IsForbidden and auras:IsForbidden())) then
				pcall(function() auras:UnregisterAllEvents() end)
				pcall(function() auras:Hide() end)
			end
		end
		local classNameplateManaBar = frame.classNamePlatePowerBar
		if (classNameplateManaBar) then
			classNameplateManaBar:SetAlpha(0)
			classNameplateManaBar:Hide()
			classNameplateManaBar:UnregisterAllEvents()
		end

		local classNamePlateMechanicFrame = frame.classNamePlateMechanicFrame
		if (classNamePlateMechanicFrame) then
			classNamePlateMechanicFrame:SetAlpha(0)
			classNamePlateMechanicFrame:Hide()
		end

		local personalFriendlyBuffFrame = frame.personalFriendlyBuffFrame
		if (personalFriendlyBuffFrame) then
			personalFriendlyBuffFrame:SetAlpha(0)
			personalFriendlyBuffFrame:Hide()
		end
	end

	local function HideBlizzardNamePlateVisual(unit)
		if (not C_NamePlate or not C_NamePlate.GetNamePlateForUnit or not unit) then
			return
		end

		local plate = C_NamePlate.GetNamePlateForUnit(unit, issecurefunc())
		if (not plate or not plate.UnitFrame or plate.UnitFrame:IsForbidden()) then
			return
		end

		local UF = plate.UnitFrame
		local health = UF.healthBar or UF.healthbar or UF.HealthBar
			or (UF.HealthBarsContainer and UF.HealthBarsContainer.healthBar)
		if (health and health.SetAlpha) then
			pcall(health.SetAlpha, health, 0)
		end

		if (UF.SetAlpha) then
			pcall(UF.SetAlpha, UF, 0)
		end

		if (not hookedBlizzardUFs[UF]) then
			hookedBlizzardUFs[UF] = true
			local locked = false

			if (UF.HookScript) then
				UF:HookScript("OnShow", function(frame)
					if (locked or frame:IsForbidden()) then
						return
					end
					locked = true
					frame:SetAlpha(0)
					locked = false
				end)
			end

			hooksecurefunc(UF, "SetAlpha", function(frame, alpha)
				if (locked or frame:IsForbidden() or alpha == 0) then
					return
				end
				locked = true
				frame:SetAlpha(0)
				locked = false
			end)
		end
	end

	local function PatchBlizzardNamePlate(unit)
		if (not C_NamePlate or not C_NamePlate.GetNamePlateForUnit or not unit) then
			return
		end

		local plate = C_NamePlate.GetNamePlateForUnit(unit, issecurefunc())
		if (not plate or not plate.UnitFrame or plate.UnitFrame:IsForbidden()) then
			return
		end

		clearClutter(plate)
	end

	local function PatchBlizzardNamePlateFrame(plate)
		if (not plate or (plate.IsForbidden and plate:IsForbidden())) then
			return
		end
		local UF = plate.UnitFrame or plate.unitFrame
		if (not UF or (UF.IsForbidden and UF:IsForbidden())) then
			return
		end

		clearClutter(plate)
	end

	if (secretMode) then
		-- WoW12 secret-value mode:
		-- avoid addon-local Blizzard nameplate hooks during protected plate
		-- creation. Only apply a delayed visual hide to the Blizzard plate.
		self.PatchBlizzardNamePlate = nil
		self.PatchBlizzardNamePlateFrame = nil
		self.DisableBlizzardNamePlate = nil
		self.RestoreBlizzardNamePlate = nil
		self.HideBlizzardNamePlateVisual = HideBlizzardNamePlateVisual
	else
		self.PatchBlizzardNamePlate = PatchBlizzardNamePlate
		self.PatchBlizzardNamePlateFrame = PatchBlizzardNamePlateFrame
		self.DisableBlizzardNamePlate = DisableBlizzardNamePlate
		self.RestoreBlizzardNamePlate = RestoreBlizzardNamePlate
		self.HideBlizzardNamePlateVisual = nil
	end

	if (not secretMode) then
		if (NamePlateDriverFrame.UpdateNamePlateSize and not self.__AzeriteUI_NamePlateSizeHooked) then
			self.__AzeriteUI_NamePlateSizeHooked = true
			hooksecurefunc(NamePlateDriverFrame, "UpdateNamePlateSize", function()
				RefreshNamePlateScalingState(self)
			end)
		end

		if (NamePlateDriverFrame.SetupClassNameplateBars) then
			hooksecurefunc(NamePlateDriverFrame, "SetupClassNameplateBars", function(frame)
				if (not frame or frame:IsForbidden()) then return end
				clearClutter(frame)
			end)
		end

		hooksecurefunc(NamePlateDriverFrame, "UpdateNamePlateOptions", function()
			if (InCombatLockdown()) then return end
			local db = ns.GetConfig("NamePlates")
			if (C_NamePlate.SetNamePlateSize) then
				C_NamePlate.SetNamePlateSize(unpack(db.Size))
			elseif (C_NamePlate.SetNamePlateFriendlySize) then
				C_NamePlate.SetNamePlateFriendlySize(unpack(db.Size))
				if (C_NamePlate.SetNamePlateEnemySize) then
					C_NamePlate.SetNamePlateEnemySize(unpack(db.Size))
				end
				if (C_NamePlate.SetNamePlateSelfSize) then
					C_NamePlate.SetNamePlateSelfSize(unpack(db.Size))
				end
			end
			RefreshNamePlateScalingState(self)
		end)
	end

	if (not secretMode and NamePlateDriverFrame and NamePlateDriverFrame.OnNamePlateCreated and not self.__AzeriteUI_NamePlateCreateHooked) then
		self.__AzeriteUI_NamePlateCreateHooked = true
		hooksecurefunc(NamePlateDriverFrame, "OnNamePlateCreated", function(_, plate)
			if (self.PatchBlizzardNamePlateFrame) then
				self.PatchBlizzardNamePlateFrame(plate)
			end
		end)
	end
	if (not secretMode and _G.NamePlateBaseMixin and type(_G.NamePlateBaseMixin.AcquireUnitFrame) == "function" and not self.__AzeriteUI_NamePlateAcquireHooked) then
		self.__AzeriteUI_NamePlateAcquireHooked = true
		hooksecurefunc(_G.NamePlateBaseMixin, "AcquireUnitFrame", function(plate)
			if (plate and self.PatchBlizzardNamePlateFrame) then
				self.PatchBlizzardNamePlateFrame(plate)
			end
		end)
	end
	if (not secretMode and _G.NamePlateUnitFrameMixin and type(_G.NamePlateUnitFrameMixin.OnUnitSet) == "function" and not self.__AzeriteUI_NamePlateUnitSetHooked) then
		self.__AzeriteUI_NamePlateUnitSetHooked = true
		hooksecurefunc(_G.NamePlateUnitFrameMixin, "OnUnitSet", function(UF)
			if (UF and not (UF.IsForbidden and UF:IsForbidden())) then
				local plate = UF:GetParent()
				if (plate and self.PatchBlizzardNamePlateFrame) then
					self.PatchBlizzardNamePlateFrame(plate)
				end
			end
		end)
	end
	if (not secretMode) then
		clearClutter(NamePlateDriverFrame)
	end
end

NamePlatesMod.UpdateSettings = function(self)
	-- Check if the enabled state has changed
	local isCurrentlyEnabled = self:IsEnabled()
	local shouldBeEnabled = self.db.profile.enabled
	ApplyFriendlyNameOnlyCVars()
	
	if (isCurrentlyEnabled ~= shouldBeEnabled) then
		-- Enabled state changed - require a UI reload
		C_UI.Reload()
	else
		ApplyNamePlateDriverSettings(self)
		RefreshActiveNamePlateScales()
	end
end

local IsVisibilityManagedCVar = function(name)
	return name == "nameplateShowAll"
		or name == "nameplateShowEnemies"
		or name == "nameplateShowFriends"
		or name == "nameplateShowFriendlyNPCs"
end

NamePlatesMod.OnEvent = function(self, event, ...)
	if (event == "PLAYER_ENTERING_WORLD") then
		ApplyFriendlyNameOnlyCVars()
		ApplyNamePlateDriverSettings(self)
		RefreshActiveNamePlateScales()
		-- Todo:
		-- Make this a user controllable setting.
		local isInInstance, instanceType = IsInInstance()
		if (isInInstance) then
			if (instanceType == "pvp") then
				SetCVar("nameplateMinAlpha", 1) -- The minimum alpha of nameplates.
			elseif (instanceType == "arena") then
				SetCVar("nameplateMinAlpha", 1) -- The minimum alpha of nameplates.
			else
				SetCVar("nameplateMinAlpha", .75) -- The minimum alpha of nameplates.
			end
			SetCVar("nameplateOccludedAlphaMult", .45) -- Alpha multiplier of hidden plates
		else
			SetCVar("nameplateMinAlpha", .4) -- The minimum alpha of nameplates.
			SetCVar("nameplateOccludedAlphaMult", .15) -- Alpha multiplier of hidden plates
		end
	elseif (event == "UI_SCALE_CHANGED") then
		ApplyNamePlateDriverSettings(self)
		RefreshActiveNamePlateScales()
	elseif (event == "CVAR_UPDATE") then
		local name = ...
		if (name == "nameplateGlobalScale" and IsUsingBlizzardGlobalScale()) then
			ApplyNamePlateDriverSettings(self)
			RefreshActiveNamePlateScales()
		elseif (IsVisibilityManagedCVar(name)) then
			RefreshActiveNamePlateScales()
		end
	elseif (event == "PLAYER_REGEN_ENABLED") then
		if (self.pendingDriverRefresh) then
			ApplyNamePlateDriverSettings(self)
		end
		RefreshActiveNamePlateScales()
	elseif (event == "NAME_PLATE_UNIT_ADDED") then
		local unit = ...
		if (unit == "preview") then
			return
		end
		if (unit and self.PatchBlizzardNamePlate) then
			if (C_Timer) then
				C_Timer.After(0, function() self.PatchBlizzardNamePlate(unit) end)
			else
				self.PatchBlizzardNamePlate(unit)
			end
		end
		if (unit and self.DisableBlizzardNamePlate) then
			if (C_Timer) then
				C_Timer.After(0, function() self.DisableBlizzardNamePlate(unit) end)
			else
				self.DisableBlizzardNamePlate(unit)
			end
		end
		if (unit and self.HideBlizzardNamePlateVisual) then
			if (C_Timer) then
				C_Timer.After(0, function() self.HideBlizzardNamePlateVisual(unit) end)
			else
				self.HideBlizzardNamePlateVisual(unit)
			end
		end
	elseif (event == "NAME_PLATE_UNIT_REMOVED") then
		local unit = ...
		if (unit == "preview") then
			return
		end
		if (unit and self.RestoreBlizzardNamePlate) then
			if (C_Timer) then
				C_Timer.After(0, function() self.RestoreBlizzardNamePlate(unit) end)
			else
				self.RestoreBlizzardNamePlate(unit)
			end
		end
	end
end

NamePlatesMod.OnInitialize = function(self)
	-- Always register the database first so options can access it
	self.db = ns.db:RegisterNamespace("NamePlates", defaults)
	if (self.db and self.db.profile and (not self.db.profile.nameplateScaleModelVersion or self.db.profile.nameplateScaleModelVersion < 2)) then
		if (self.db.profile.friendlyNameOnlyTargetScale == FRIENDLY_NAME_ONLY_TARGET_SCALE_DEFAULT) then
			self.db.profile.friendlyNameOnlyTargetScale = false
		end
		self.db.profile.nameplateScaleModelVersion = 2
	end
	if (self.db and self.db.profile and self.db.profile.nameplateScaleModelVersion < 3) then
		if (self.db.profile.friendlyScale == LEGACY_FRIENDLY_NAMEPLATE_SCALE_DEFAULT) then
			self.db.profile.friendlyScale = FRIENDLY_NAMEPLATE_SCALE_DEFAULT
		end
		if (self.db.profile.enemyScale == LEGACY_ENEMY_NAMEPLATE_SCALE_DEFAULT) then
			self.db.profile.enemyScale = ENEMY_NAMEPLATE_SCALE_DEFAULT
		end
		if (self.db.profile.friendlyTargetScale == LEGACY_FRIENDLY_NAMEPLATE_TARGET_SCALE_DEFAULT) then
			self.db.profile.friendlyTargetScale = FRIENDLY_NAMEPLATE_TARGET_SCALE_DEFAULT
		end
		if (self.db.profile.enemyTargetScale == LEGACY_GLOBAL_NAMEPLATE_TARGET_SCALE_DEFAULT) then
			self.db.profile.enemyTargetScale = GLOBAL_NAMEPLATE_TARGET_SCALE_DEFAULT
		end
		if (self.db.profile.nameplateTargetScale == LEGACY_GLOBAL_NAMEPLATE_TARGET_SCALE_DEFAULT) then
			self.db.profile.nameplateTargetScale = GLOBAL_NAMEPLATE_TARGET_SCALE_DEFAULT
		end
		self.db.profile.nameplateScaleModelVersion = 3
	end
	if (self.db and self.db.profile and self.db.profile.nameplateScaleModelVersion < 4) then
		if (self.db.profile.friendlyTargetScale == PROMOTED_FRIENDLY_NAMEPLATE_TARGET_SCALE_DEFAULT) then
			self.db.profile.friendlyTargetScale = FRIENDLY_NAMEPLATE_TARGET_SCALE_DEFAULT
		end
		if (self.db.profile.enemyTargetScale == PROMOTED_GLOBAL_NAMEPLATE_TARGET_SCALE_DEFAULT) then
			self.db.profile.enemyTargetScale = GLOBAL_NAMEPLATE_TARGET_SCALE_DEFAULT
		end
		if (self.db.profile.nameplateTargetScale == PROMOTED_GLOBAL_NAMEPLATE_TARGET_SCALE_DEFAULT) then
			self.db.profile.nameplateTargetScale = GLOBAL_NAMEPLATE_TARGET_SCALE_DEFAULT
		end
		self.db.profile.nameplateScaleModelVersion = 4
	end
	if (self.db and self.db.profile and self.db.profile.nameplateScaleModelVersion < 5) then
		if (self.db.profile.friendlyScale == 1.95) then
			self.db.profile.friendlyScale = FRIENDLY_NAMEPLATE_SCALE_DEFAULT
		end
		if (self.db.profile.enemyTargetScale == 0) then
			self.db.profile.enemyTargetScale = .5
		end
		self.db.profile.nameplateScaleModelVersion = 5
	end
	if (self.db and self.db.profile and self.db.profile.nameplateScaleModelVersion < 6) then
		if (type(self.db.profile.maxDistance) ~= "number") then
			self.db.profile.maxDistance = NAMEPLATE_MAX_DISTANCE_DEFAULT
		end
		self.db.profile.nameplateScaleModelVersion = 6
	end
	if (self.db and self.db.profile and self.db.profile.nameplateScaleModelVersion < 7) then
		if (type(self.db.profile.castBarOffsetY) ~= "number") then
			self.db.profile.castBarOffsetY = NAMEPLATE_CASTBAR_OFFSET_DEFAULT
		end
		self.db.profile.nameplateScaleModelVersion = 7
	end
	if (self.db and self.db.profile and self.db.profile.nameplateScaleModelVersion < 8) then
		if (self.db.profile.castBarOffsetY == 0) then
			self.db.profile.castBarOffsetY = NAMEPLATE_CASTBAR_OFFSET_DEFAULT
		end
		self.db.profile.nameplateScaleModelVersion = 8
	end
	if (self.db and self.db.profile and self.db.profile.nameplateScaleModelVersion < 9) then
		if (self.db.profile.castBarOffsetY == 0) then
			self.db.profile.castBarOffsetY = NAMEPLATE_CASTBAR_OFFSET_DEFAULT
		end
		self.db.profile.nameplateScaleModelVersion = 9
	end
	if (self.db and self.db.profile and self.db.profile.nameplateScaleModelVersion < 10) then
		if (self.db.profile.castBarOffsetY == 8) then
			self.db.profile.castBarOffsetY = 0
		end
		self.db.profile.nameplateScaleModelVersion = 10
	end
	ApplyFriendlyNameOnlyCVars()
	
	-- Check for conflicts with other nameplate addons
	if (self:CheckForConflicts()) then return self:Disable() end

	-- If custom nameplates are disabled, don't enable the module
	if (not self.db.profile.enabled) then return self:Disable() end

	LoadAddOn("Blizzard_NamePlates")

	self:HookNamePlates()
end

NamePlatesMod.OnEnable = function(self)
	if (ns.NameplateInterruptDB and ns.NameplateInterruptDB.SeedFromPlater) then
		ns.NameplateInterruptDB.SeedFromPlater()
	end

	oUF:RegisterStyle(ns.Prefix.."NamePlates", style)
	oUF:SetActiveStyle(ns.Prefix.."NamePlates")
	local driver = oUF:SpawnNamePlates(ns.Prefix)
	if (driver) then
		driver:SetAddedCallback(callback)
		driver:SetRemovedCallback(callback)
		driver:SetTargetCallback(callback)
		driver:SetCVars(GetDriverCVars())
		self.namePlateDriver = driver
	end
	ApplyNamePlateDriverSettings(self)

	self.mouseTimer = self:ScheduleRepeatingTimer(checkMouseOver, 1/20)
	self.softTimer = self:ScheduleRepeatingTimer(checkSoftTarget, 1/20)

	self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEvent")
	self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnEvent")
	self:RegisterEvent("UI_SCALE_CHANGED", "OnEvent")
	self:RegisterEvent("CVAR_UPDATE", "OnEvent")
	self:RegisterEvent("NAME_PLATE_UNIT_ADDED", "OnEvent")
	self:RegisterEvent("NAME_PLATE_UNIT_REMOVED", "OnEvent")

end

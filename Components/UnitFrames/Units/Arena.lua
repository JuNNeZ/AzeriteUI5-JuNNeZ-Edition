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

local L = LibStub("AceLocale-3.0"):GetLocale((...))

local ArenaFrameMod = ns:NewModule("ArenaFrames", ns.UnitFrameModule, "LibMoreEvents-1.0")

local API = ns.API

-- GLOBALS: C_CreatureInfo, C_PvP, C_TooltipInfo, CreateFrame, InCombatLockdown, Enum, IsInInstance, IsUnitModelReadyForUI, SetPortraitTexture
-- GLOBALS: GetArenaOpponentSpec, GetNumArenaOpponentSpecs, GetNumClasses, GetNumSpecializationsForClassID
-- GLOBALS: GetSpecializationInfoByID, GetSpecializationInfoForClassID, RegisterAttributeDriver, UnregisterAttributeDriver
-- GLOBALS: LOCALIZED_CLASS_NAMES_FEMALE, LOCALIZED_CLASS_NAMES_MALE
-- GLOBALS: UnitClass, UnitFactionGroup, UnitIsConnected, UnitIsUnit, UnitIsVisible, UnitHasVehicleUI, UnitPowerType
-- GLOBALS: canaccessvalue, issecretvalue

-- Lua API
local math_abs = math.abs
local math_max = math.max
local math_min = math.min
local math_ceil = math.ceil
local math_pi = math.pi
local next = next
local select = select
local setmetatable = setmetatable
local string_gsub = string.gsub
local string_match = string.match
local string_upper = string.upper
local tonumber = tonumber
local type = type
local unpack = unpack

local Units = {}

local defaults = { profile = ns:Merge({

	enabled = true,
	useRangeIndicator = false,
	showInBattlegrounds = true,

	point = "TOP", -- anchor point of unitframe, group members within column grow opposite
	xOffset = 0, -- horizontal offset within the same column
	yOffset = -12, -- vertical offset within the same column

	groupBy = "GROUP", -- GROUP, CLASS, ROLE
	groupingOrder = "1,2,3,4,5,6,7,8", -- must match choice in groupBy

	unitsPerColumn = 5, -- maximum units per column
	maxColumns = 1, -- should be 40/unitsPerColumn
	columnSpacing = 10, -- spacing between columns
	columnAnchorPoint = "RIGHT" -- anchor point of column, columns grow opposite

}, ns.MovableModulePrototype.defaults) }

-- Generate module defaults on the fly
-- to recalculate default values relying on
-- changing factors like user interface scale.
ArenaFrameMod.GenerateDefaults = function(self)
	defaults.profile.savedPosition = {
		scale = ns.API.GetEffectiveScale(),
		[1] = "CENTER",
		[2] = 300 * ns.API.GetEffectiveScale(),
		[3] = 0 * ns.API.GetEffectiveScale()
	}
	return defaults
end


-- Utility Functions
--------------------------------------------
-- Simplify the tagging process a little.
local prefix = function(msg)
	return string_gsub(msg, "*", ns.Prefix)
end

local IsRuntimeTestMode = function()
	return (ns.db and ns.db.global and ns.db.global.runtimeUnitTestMode) and true or false
end

local ArenaUnitExistsVisibilityDriver = "[@arena1,exists] show; [@arena2,exists] show; [@arena3,exists] show; [@arena4,exists] show; [@arena5,exists] show; hide"

local HasArenaPrepOpponents = function()
	if (not GetNumArenaOpponentSpecs) then
		return false
	end

	local numOpponents = GetNumArenaOpponentSpecs()
	return (type(numOpponents) == "number" and numOpponents > 0)
end

local ApplyTestUnitDrivers = function(self)
	if (InCombatLockdown()) then
		self.needHeaderUpdate = true
		self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnEvent")
		return
	end

	local header = self:GetUnitFrameOrHeader()
	if (not header) then
		return
	end

	for i = 1, 5 do
		local unitButton = header:GetAttribute("child"..i)
		if (unitButton) then
			UnregisterAttributeDriver(unitButton, "unit")
			RegisterAttributeDriver(unitButton, "unit", IsRuntimeTestMode() and "player" or ("arena"..i))
		end
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

-- Consolidated onto API.CanAccess (Core/API/SecretValues.lua). The old local
-- copy returned true when both probe globals were absent while the Target copy
-- returned true when only issecretvalue was absent, so the two files disagreed
-- about the same value. Both now share the single strict definition.
local IsArenaValueAccessible = API.CanAccess

local ResetArenaOpponentInfo = function(owner)
	if (not owner) then
		return
	end
	owner.__AzeriteUI_ArenaSpecID = nil
	owner.__AzeriteUI_ArenaSpecIcon = nil
	owner.__AzeriteUI_ArenaClassFile = nil
end

local ArenaTooltipSpecIDs

local GetArenaTooltipSpecIDs = function()
	if (ArenaTooltipSpecIDs) then
		return ArenaTooltipSpecIDs
	end

	local lookup = {}
	ArenaTooltipSpecIDs = lookup
	if (type(GetNumClasses) ~= "function" or type(GetNumSpecializationsForClassID) ~= "function" or type(GetSpecializationInfoForClassID) ~= "function") then
		return lookup
	end

	local okClasses, numClasses = API.TryCall(GetNumClasses)
	if (not okClasses or not IsArenaValueAccessible(numClasses) or type(numClasses) ~= "number") then
		return lookup
	end

	local maleGender = Enum and Enum.UnitSex and Enum.UnitSex.Male
	local femaleGender = Enum and Enum.UnitSex and Enum.UnitSex.Female
	for classID = 1, numClasses do
		local classFile
		if (C_CreatureInfo and type(C_CreatureInfo.GetClassInfo) == "function") then
			local okClass, classInfo = API.TryCall(C_CreatureInfo.GetClassInfo, classID)
			if (okClass and type(classInfo) == "table") then
				local okClassFile, value = API.TryCall(function() return classInfo.classFile end)
				if (okClassFile and IsArenaValueAccessible(value) and type(value) == "string") then
					classFile = value
				end
			end
		end

		local classMale = classFile and LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[classFile]
		local classFemale = classFile and LOCALIZED_CLASS_NAMES_FEMALE and LOCALIZED_CLASS_NAMES_FEMALE[classFile]
		if (classMale or classFemale) then
			local okSpecs, numSpecs = API.TryCall(GetNumSpecializationsForClassID, classID)
			if (okSpecs and IsArenaValueAccessible(numSpecs) and type(numSpecs) == "number") then
				for specIndex = 1, numSpecs do
					local function AddSpecName(gender)
						local okSpec, specID, specName = API.TryCall(GetSpecializationInfoForClassID, classID, specIndex, gender)
						if (not okSpec or not IsArenaValueAccessible(specID) or not IsArenaValueAccessible(specName) or type(specID) ~= "number" or type(specName) ~= "string") then
							return
						end
						if (classMale) then
							lookup[specName.." "..classMale] = specID
						end
						if (classFemale) then
							lookup[specName.." "..classFemale] = specID
						end
					end

					AddSpecName(nil)
					if (maleGender) then
						AddSpecName(maleGender)
					end
					if (femaleGender and femaleGender ~= maleGender) then
						AddSpecName(femaleGender)
					end
				end
			end
		end
	end

	return lookup
end

local GetArenaOpponentSpecFromTooltip = function(unit)
	if (type(unit) ~= "string" or not C_TooltipInfo or type(C_TooltipInfo.GetUnit) ~= "function") then
		return nil
	end

	local okTooltip, tooltipData = API.TryCall(C_TooltipInfo.GetUnit, unit)
	if (not okTooltip or not IsArenaValueAccessible(tooltipData) or type(tooltipData) ~= "table") then
		return nil
	end

	local okLines, lines = API.TryCall(function() return tooltipData.lines end)
	if (not okLines or not IsArenaValueAccessible(lines) or type(lines) ~= "table") then
		return nil
	end

	local okCount, lineCount = API.TryCall(function() return #lines end)
	if (not okCount or type(lineCount) ~= "number") then
		return nil
	end

	local lookup = GetArenaTooltipSpecIDs()
	for lineIndex = 1, lineCount do
		local okText, lineText = API.TryCall(function()
			local line = lines[lineIndex]
			if (type(line) == "table") then
				return line.leftText
			end
		end)
		if (okText and IsArenaValueAccessible(lineText) and type(lineText) == "string") then
			local specID = lookup[lineText]
			if (type(specID) == "number" and specID > 0) then
				return specID
			end
		end
	end

	return nil
end

local GetArenaOpponentIndex = function(owner, unit)
	local id = owner and tonumber(owner.id)
	if (not id and type(unit) == "string") then
		id = tonumber(string_match(unit, "^arena(%d+)$"))
	end
	return id
end

local ResolveArenaOpponentInfo = function(owner, unit, suppliedSpecID)
	if (not owner) then
		return nil, nil, nil
	end

	local classFile
	if (type(UnitClass) == "function" and type(unit) == "string") then
		local ok, _, unitClass = API.TryCall(UnitClass, unit)
		if (ok and IsArenaValueAccessible(unitClass) and type(unitClass) == "string" and unitClass ~= "") then
			classFile = unitClass
			owner.__AzeriteUI_ArenaClassFile = unitClass
		end
	end

	local specID = suppliedSpecID
	if (not IsArenaValueAccessible(specID) or type(specID) ~= "number" or specID <= 0) then
		specID = nil
		local id = GetArenaOpponentIndex(owner, unit)
		if (id and type(GetArenaOpponentSpec) == "function") then
			local ok, currentSpecID = API.TryCall(GetArenaOpponentSpec, id)
			if (ok and IsArenaValueAccessible(currentSpecID) and type(currentSpecID) == "number" and currentSpecID > 0) then
				specID = currentSpecID
			end
		end
		if (not specID) then
			specID = GetArenaOpponentSpecFromTooltip(unit)
		end
	end

	if (specID) then
		owner.__AzeriteUI_ArenaSpecID = specID
	else
		specID = owner.__AzeriteUI_ArenaSpecID
	end

	local icon
	if (specID and type(GetSpecializationInfoByID) == "function") then
		local ok, _, _, _, specIcon, _, specClass = API.TryCall(GetSpecializationInfoByID, specID)
		if (ok) then
			if (IsArenaValueAccessible(specIcon) and type(specIcon) == "number" and specIcon > 0) then
				icon = specIcon
				owner.__AzeriteUI_ArenaSpecIcon = specIcon
			end
			if (IsArenaValueAccessible(specClass) and type(specClass) == "string" and specClass ~= "") then
				classFile = classFile or specClass
				owner.__AzeriteUI_ArenaClassFile = classFile
			end
		end
	end

	return specID, icon or owner.__AzeriteUI_ArenaSpecIcon, classFile or owner.__AzeriteUI_ArenaClassFile
end

local GetArenaClassColor = function(element, unit, specID)
	local owner = element and element.__owner
	local colors = owner and owner.colors
	if (not colors or not colors.class) then
		return nil
	end

	local _, _, classFile = ResolveArenaOpponentInfo(owner, unit, specID)

	return classFile and colors.class[classFile] or nil
end

local ApplyArenaClassColor = function(element, unit, specID)
	local color = GetArenaClassColor(element, unit, specID)
	if (not color or type(color.GetRGB) ~= "function") then
		return false
	end

	local r, g, b = color:GetRGB()
	local texture = element:GetStatusBarTexture()
	if (texture) then
		texture:SetVertexColor(r, g, b)
	end
	local preview = element.Preview
	if (preview) then
		preview:SetStatusBarColor(r * .7, g * .7, b * .7)
	end
	return true
end

-- Keep class colors working for arena NPCs/bots that are not classified as ordinary players.
local Health_PostUpdateColor = function(element, unit, color)
	local owner = element.__owner
	if (owner and owner.colors and color == owner.colors.disconnected) then
		return
	end
	ApplyArenaClassColor(element, unit)
end

local Health_PostUpdateArenaPreparation = function(element, event, specID)
	ApplyArenaClassColor(element, nil, specID)
end

local IsArenaMatchContext = function()
	local _, instanceType = IsInInstance()
	if (instanceType == "arena") then
		return true, instanceType
	end
	if (C_PvP and type(C_PvP.IsMatchConsideredArena) == "function") then
		local ok, isArenaMatch = API.TryCall(C_PvP.IsMatchConsideredArena)
		if (ok and IsArenaValueAccessible(isArenaMatch) and isArenaMatch == true) then
			return true, instanceType
		end
	end
	return false, instanceType
end

-- Retail 12.1 throws "Cannot set tex coords when texture has mask" for any
-- SetTexCoord call on a masked texture, and the spec icon is masked at creation.
-- GetNumMaskTextures does not reliably report that mask back, so the flag we set
-- ourselves in SetMask is what is trusted here, with a guarded call as the last resort.
-- Masked textures draw the full image anyway, so the reset only matters on the
-- unmasked fallback path.
local SetSpecIconTexture = function(texture, file)
	texture:SetTexture(file)
	if (texture.azeriteHasMask) then
		return
	end
	if (texture.GetNumMaskTextures and texture:GetNumMaskTextures() > 0) then
		return
	end
	API.TryCall(texture.SetTexCoord, texture, 0, 1, 0, 1)
end

local SpecIcon_Override = function(self, event, unit)
	if (event == "ARENA_OPPONENT_UPDATE" and unit ~= self.unit) then
		return
	end

	local element = self.SpecIcon
	if (not element or not element.icon) then
		return
	end

	if (event == "ARENA_PREP_OPPONENT_SPECIALIZATIONS") then
		ResetArenaOpponentInfo(self)
	end

	local isArenaMatch, instanceType = IsArenaMatchContext()
	element.instanceType = instanceType
	if (not isArenaMatch and not element.showFaction) then
		element:Hide()
		return
	end

	if (element.PreUpdate) then
		element:PreUpdate(unit, event)
	end

	local icon, classFile
	if (isArenaMatch) then
		local _, resolvedIcon, resolvedClassFile = ResolveArenaOpponentInfo(self, self.unit)
		icon, classFile = resolvedIcon, resolvedClassFile
		if (icon) then
			SetSpecIconTexture(element.icon, icon)
		elseif (classFile) then
			element.icon:SetAtlas("classicon-"..classFile, false)
		else
			element:Hide()
			return
		end
	else
		local ok, faction = API.TryCall(UnitFactionGroup, self.unit)
		if (not ok or not IsArenaValueAccessible(faction)) then
			element:Hide()
			return
		elseif (faction == "Horde") then
			icon = [[Interface\Icons\INV_BannerPVP_01]]
		elseif (faction == "Alliance") then
			icon = [[Interface\Icons\INV_BannerPVP_02]]
		else
			element:Hide()
			return
		end
		SetSpecIconTexture(element.icon, icon)
	end

	element:Show()
	if (element.PostUpdate) then
		element:PostUpdate(event)
	end
end

local GetArenaFillTexCoords = function(percent)
	return ns.API.GetReversedHorizontalFillTexCoords(percent)
end

local GetArenaNativeFillTexCoords = function()
	return 0, 1, 0, 1
end

local NormalizeArenaDisplayPercent = function(value)
	if (type(value) ~= "number") then
		return nil
	end
	if (value <= 1) then
		value = value * 100
	end
	if (value < 0) then
		value = 0
	elseif (value > 100) then
		value = 100
	end
	return value
end

local ApplyArenaBarFillRule = function(bar, orientation)
	if (not bar) then
		return
	end
	if (orientation == "LEFT") then
		bar:SetOrientation("HORIZONTAL")
		if (bar.SetReverseFill) then
			bar:SetReverseFill(true)
		end
	elseif (orientation == "RIGHT") then
		bar:SetOrientation("HORIZONTAL")
		if (bar.SetReverseFill) then
			bar:SetReverseFill(false)
		end
	elseif (orientation == "DOWN") then
		bar:SetOrientation("VERTICAL")
		if (bar.SetReverseFill) then
			bar:SetReverseFill(true)
		end
	else
		bar:SetOrientation("VERTICAL")
		if (bar.SetReverseFill) then
			bar:SetReverseFill(false)
		end
	end
end

local UpdateArenaHealthFakeFillFromBar = function(health)
	if (not health) then
		return false
	end
	local fakeFill = health.FakeFill
	if (not fakeFill) then
		return false
	end
	local applied, percent, source = ns.API.UpdateHealthFakeFillFromUnitPercent(health, "arena1")
	if (applied) then
		health.safePercent = NormalizeArenaDisplayPercent(percent)
		health.__AzeriteUI_ArenaFakeSource = (source == "api" and type(health.safePercent) ~= "number") and "api_secret" or source
		return true
	end
	health.__AzeriteUI_ArenaFakeSource = "none"
	health.safePercent = nil
	fakeFill:SetTexCoord(GetArenaFillTexCoords(nil))
	fakeFill:Show()
	return false
end

local HideArenaNativeHealthVisuals = function(health)
	ns.API.HideNativeHealthVisuals(health)
end

local SyncArenaHealthVisualState = function(health)
	if (not health) then
		return false
	end
	HideArenaNativeHealthVisuals(health)
	return UpdateArenaHealthFakeFillFromBar(health)
end

-- Align our custom health prediction texture
-- based on the plugin's provided values.
local HealPredict_PostUpdate = function(element, unit, myIncomingHeal, otherIncomingHeal, absorb, healAbsorb, hasOverAbsorb, hasOverHealAbsorb, curHealth, maxHealth)
	if (myIncomingHeal == nil and element and element.values and element.values.GetIncomingHeals) then
		local _, playerHeal, otherHeal = element.values:GetIncomingHeals()
		local healAbsorbAmount = 0
		if (element.values.GetHealAbsorbs) then
			healAbsorbAmount = select(1, element.values:GetHealAbsorbs()) or 0
		end
		myIncomingHeal = playerHeal
		otherIncomingHeal = otherHeal
		healAbsorb = healAbsorbAmount
		curHealth = UnitHealth(unit)
		maxHealth = UnitHealthMax(unit)
	end
	myIncomingHeal = tonumber(myIncomingHeal) or 0
	otherIncomingHeal = tonumber(otherIncomingHeal) or 0
	healAbsorb = tonumber(healAbsorb) or 0
	curHealth = tonumber(curHealth) or 0
	maxHealth = tonumber(maxHealth) or 1	if (ns.API.ShouldSkipPrediction(element, myIncomingHeal, otherIncomingHeal, absorb, healAbsorb, hasOverAbsorb, hasOverHealAbsorb, curHealth, maxHealth)) then
		return
	end

	local safeCur, safeMax = ns.API.GetSafeHealthForPrediction(element, curHealth, maxHealth)
	if (not safeCur or not safeMax) then
		ns.API.HidePrediction(element)
		return
	end
	curHealth, maxHealth = safeCur, safeMax

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

local Power_PostUpdate = function(element, unit, cur, min, max)

	local shouldShow = UnitIsConnected(unit) and not UnitIsDeadOrGhost(unit)

	if (not shouldShow or cur == 0 or max == 0) then
		element:SetAlpha(0)
	else
		element:SetAlpha(.75)
	end
end

-- Since we can't retrieve power info in the prep phase, hide it
local Power_PostUpdateArenaPreparation = function(element, specID)
	element:SetAlpha(0)
end

local EnsureArenaPortraitFallbackTexture = function(element)
	if (not element) then
		return nil
	end
	if (not element.fallback2DFrame) then
		local parent = element.fallbackParent or element:GetParent() or element
		local frame = CreateFrame("Frame", nil, parent)
		frame:SetAllPoints(element)
		if (element.GetFrameLevel and frame.SetFrameLevel) then
			local level = element:GetFrameLevel()
			if (type(level) == "number") then
				frame:SetFrameLevel(level)
			end
		end
		frame:Hide()
		element.fallback2DFrame = frame
	end
	if (not element.fallback2DTexture) then
		element.fallback2DTexture = element.fallback2DFrame:CreateTexture(nil, "ARTWORK", nil, 0)
		element.fallback2DTexture:SetAllPoints()
		element.fallback2DTexture:SetTexCoord(.1, .9, .1, .9)
	end
	return element.fallback2DTexture
end

local HideArenaPortraitFallback = function(element)
	if (not element) then
		return
	end
	if (element.fallback2DTexture) then
		element.fallback2DTexture:Hide()
	end
	if (element.fallback2DFrame) then
		element.fallback2DFrame:Hide()
	end
	element.__AzeriteUI_Using2DPortraitFallback = nil
end

local ShowArenaPortraitFallback = function(element, unit)
	if (not element) then
		return false
	end
	element:ClearModel()
	local fallback = EnsureArenaPortraitFallbackTexture(element)
	if (not fallback or type(SetPortraitTexture) ~= "function") then
		HideArenaPortraitFallback(element)
		return false
	end

	fallback:SetTexCoord(.1, .9, .1, .9)
	local ok = API.SafeCall("Arena.Portrait.SetPortraitTexture", SetPortraitTexture, fallback, unit)
	if (not ok) then
		HideArenaPortraitFallback(element)
		return false
	end

	fallback:Show()
	element.fallback2DFrame:Show()
	element.__AzeriteUI_Using2DPortraitFallback = true
	return true
end

local ArenaUnitFlagIsTrue = function(api, unit)
	if (type(api) ~= "function") then
		return false
	end
	local ok, value = API.TryCall(api, unit)
	return ok and IsArenaValueAccessible(value) and value == true
end

local TrySetArenaPortraitModel = function(element, unit)
	if (not element or type(unit) ~= "string" or unit == "") then
		return false
	end
	if (not ArenaUnitFlagIsTrue(UnitIsConnected, unit) or not ArenaUnitFlagIsTrue(UnitIsVisible, unit)) then
		return false
	end
	if (type(IsUnitModelReadyForUI) == "function" and not ArenaUnitFlagIsTrue(IsUnitModelReadyForUI, unit)) then
		return false
	end
	if (type(element.CanSetUnit) == "function") then
		local ok, canSetUnit = API.TryCall(element.CanSetUnit, element, unit)
		if (not ok or not IsArenaValueAccessible(canSetUnit) or canSetUnit == false) then
			return false
		end
	end
	if (type(element.SetUnit) ~= "function") then
		return false
	end

	element:SetCamDistanceScale(element.distanceScale or 1)
	element:SetPortraitZoom(1)
	element:SetPosition(element.positionX or 0, element.positionY or 0, element.positionZ or 0)
	element:SetRotation(element.rotation and element.rotation*(2*math_pi)/180 or 0)
	element:ClearModel()

	local ok, success = API.SafeCall("Arena.Portrait.SetUnit", element.SetUnit, element, unit)
	if (not ok or not IsArenaValueAccessible(success) or success == false) then
		element:ClearModel()
		return false
	end
	if (type(element.GetDisplayInfo) == "function" and success ~= true) then
		local okDisplay, displayID = API.TryCall(element.GetDisplayInfo, element)
		if (not okDisplay or not IsArenaValueAccessible(displayID) or type(displayID) ~= "number" or displayID <= 0) then
			element:ClearModel()
			return false
		end
	end
	return true
end

-- PlayerModel:SetUnit requires declassified identity in Retail 12.1, so own the
-- arena portrait update and fall back to a separately layered 2D portrait.
local Portrait_Override = function(self, event, unit)
	if (unit and unit ~= self.unit) then
		return
	end
	unit = self.unit

	local element = self.Portrait
	if (not element or type(unit) ~= "string") then
		return
	end

	element.state = ArenaUnitFlagIsTrue(UnitIsConnected, unit) and ArenaUnitFlagIsTrue(UnitIsVisible, unit)
	if (element.state and TrySetArenaPortraitModel(element, unit)) then
		HideArenaPortraitFallback(element)
	else
		ShowArenaPortraitFallback(element, unit)
	end
	API.RefreshPortraitModelAlpha(element)
end

-- Update targeting highlight outline
local TargetHighlight_Update = function(self, event, unit, ...)
	if (unit and unit ~= self.unit) then return end

	local element = self.TargetHighlight
	unit = unit or self.unit

	if (UnitIsUnit(unit, "focus")) then
		element:SetVertexColor(unpack(element.colorFocus))
		element:Show()
	elseif (UnitIsUnit(unit, "target")) then
		element:SetVertexColor(unpack(element.colorTarget))
		element:Show()
	else
		element:Hide()
	end
end

local UnitFrame_PostUpdate = function(self)
	--TargetHighlight_Update(self)
end

local UnitFrame_OnEvent = function(self, event, unit, ...)
	if (event == "PLAYER_ENTERING_WORLD") then

		if (ns.WoW10) then
			-- Turn off prep frames for solo shuffles
			-- until we can figure out what makes the auras bug out.
			self:SetAttribute("oUF-enableArenaPrep", IsActiveBattlefieldArena() and not C_PvP.IsSoloShuffle())
		end
	end

	UnitFrame_PostUpdate(self)
end

local style = function(self, unit)

	local db = ns.GetConfig("ArenaFrames")

	self:SetSize(unpack(db.UnitSize))
	self:SetFrameLevel(self:GetFrameLevel() + 10)

	-- Apply common scripts and member values.
	ns.UnitFrame.InitializeUnitFrame(self)
	ns.UnitFrames[self] = true -- add to our registry
	Units[self] = true -- add to local registry

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
	health:SetTexCoord(GetArenaNativeFillTexCoords())
	health:DisableSmoothing(true)
	health.__AzeriteUI_UseProductionNativeFill = true
	health.__AzeriteUI_KeepMirrorPercentOnNoSample = false
	health.__AzeriteUI_UseValueMirrorTexCoord = false
	health:SetOrientation("HORIZONTAL")
	health:SetReverseFill(false)
	health:SetFlippedHorizontally(false)
	health.__AzeriteUI_BaseTexCoordLeft = nil
	health.__AzeriteUI_BaseTexCoordRight = nil
	health.__AzeriteUI_BaseTexCoordTop = nil
	health.__AzeriteUI_BaseTexCoordBottom = nil
	health:SetSparkMap(db.HealthBarSparkMap)
	health.predictThreshold = .01
	health.colorDisconnected = true
	health.colorClass = true
	--health.colorClassPet = true
	health.colorReaction = true
	health.colorHealth = true

	self.Health = health
	self.Health.Override = ns.API.UpdateHealth
	self.Health.PostUpdate = Health_PostUpdate
	self.Health.PostUpdateColor = Health_PostUpdateColor
	self.Health.PostUpdateArenaPreparation = Health_PostUpdateArenaPreparation

	local healthOverlay = CreateFrame("Frame", nil, health)
	healthOverlay:SetFrameLevel(overlay:GetFrameLevel() - 1)
	healthOverlay:SetAllPoints()

	self.Health.Overlay = healthOverlay

	local healthBackdrop = health:CreateTexture(nil, "BACKGROUND", nil, -1)
	healthBackdrop:SetPoint(unpack(db.HealthBackdropPosition))
	healthBackdrop:SetSize(unpack(db.HealthBackdropSize))
	healthBackdrop:SetTexture(db.HealthBackdropTexture)
	healthBackdrop:SetVertexColor(unpack(db.HealthBackdropColor))
	healthBackdrop:SetTexCoord(GetArenaFillTexCoords(nil))

	self.Health.Backdrop = healthBackdrop

	local healthPreview = self:CreateBar(nil, health)
	if (healthPreview.SetForceNative) then healthPreview:SetForceNative(true) end
	healthPreview:SetAllPoints(health)
	healthPreview:SetFrameLevel(health:GetFrameLevel() - 1)
	healthPreview:SetStatusBarTexture(db.HealthBarTexture)
	healthPreview.__AzeriteUI_UseValueMirrorTexCoord = false
	healthPreview:SetTexCoord(GetArenaNativeFillTexCoords())
	healthPreview:SetOrientation("HORIZONTAL")
	healthPreview:SetReverseFill(false)
	healthPreview:SetFlippedHorizontally(false)
	healthPreview:SetSparkTexture("")
		healthPreview:SetAlpha(0)
		healthPreview:Hide()
	healthPreview:DisableSmoothing(true)

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
	-- self.HealthPrediction.PostUpdate = HealPredict_PostUpdate -- Temporary rollback: broken white prediction overlay covers arena health bars.
	self.HealthPrediction:SetAlpha(0)
	self.HealthPrediction:Hide()

	-- Cast Overlay
	--------------------------------------------
	local castbar = self:CreateBar()
	castbar:SetAllPoints(health)
	castbar:SetFrameLevel(self:GetFrameLevel() + 5)
	castbar:SetSparkMap(db.HealthBarSparkMap)
	castbar:SetStatusBarTexture(db.HealthBarTexture)
	ApplyArenaBarFillRule(castbar, db.HealthBarOrientation)
	castbar:SetStatusBarColor(unpack(db.HealthCastOverlayColor))
	castbar:DisableSmoothing(true)

	self.Castbar = castbar

	-- Health Value
	--------------------------------------------
	local healthValue = healthOverlay:CreateFontString(nil, "OVERLAY", nil, 1)
	healthValue:SetPoint(unpack(db.HealthValuePosition))
	healthValue:SetFontObject(db.HealthValueFont)
	healthValue:SetTextColor(unpack(db.HealthValueColor))
	healthValue:SetJustifyH(db.HealthValueJustifyH)
	healthValue:SetJustifyV(db.HealthValueJustifyV)
	self:Tag(healthValue, prefix("[*:Health(true,false,true,false)]"))

	self.Health.Value = healthValue

	-- Health Percentage
	--------------------------------------------
	local healthPerc = healthValue:GetParent():CreateFontString(nil, "OVERLAY", nil, 1)
	if (db.HealthPercentagePosition) then
		healthPerc:SetPoint(unpack(db.HealthPercentagePosition))
	else
		healthPerc:SetPoint("LEFT", healthValue, "RIGHT", 18, 0)
	end
	healthPerc:SetFontObject(db.HealthPercentageFont or db.HealthValueFont)
	local healthPercColor = db.HealthPercentageColor or db.HealthValueColor or { 1, 1, 1, 1 }
	healthPerc:SetTextColor(healthPercColor[1], healthPercColor[2], healthPercColor[3], healthPercColor[4] or 1)
	healthPerc:SetJustifyH(db.HealthPercentageJustifyH or "LEFT")
	healthPerc:SetJustifyV(db.HealthPercentageJustifyV or "MIDDLE")
	self:Tag(healthPerc, prefix("[*:HealthPercent]"))
	healthPerc:Hide() -- Hide health percentage

	self.Health.Percent = healthPerc

	-- Power
	--------------------------------------------
	local power = self:CreateBar()
	power:SetFrameLevel(health:GetFrameLevel() + 2)
	power:SetPoint(unpack(db.PowerBarPosition))
	power:SetSize(unpack(db.PowerBarSize))
	power:SetStatusBarTexture(db.PowerBarTexture)
	power:SetOrientation(db.PowerBarOrientation)
	power:SetAlpha(db.PowerBarAlpha)
	power.frequentUpdates = true
	power.colorPower = true

	self.Power = power
	self.Power.Override = ns.API.UpdatePower
	self.Power.PostUpdate = Power_PostUpdate
	self.Power.PostUpdateArenaPreparation = Power_PostUpdateArenaPreparation

	local powerBackdrop = power:CreateTexture(nil, "BACKGROUND", nil, -5)
	powerBackdrop:SetPoint(unpack(db.PowerBackdropPosition))
	powerBackdrop:SetSize(unpack(db.PowerBackdropSize))
	powerBackdrop:SetTexture(db.PowerBackdropTexture)
	powerBackdrop:SetVertexColor(unpack(db.PowerBackdropColor))

	self.Power.Backdrop = powerBackdrop

	-- Portrait
	--------------------------------------------
	local portraitFrame = CreateFrame("Frame", nil, self)
	portraitFrame:SetFrameLevel(self:GetFrameLevel() - 2)
	portraitFrame:SetAllPoints()

	local portrait = CreateFrame("PlayerModel", nil, portraitFrame)
	portrait:SetFrameLevel(portraitFrame:GetFrameLevel())
	portrait:SetPoint(unpack(db.PortraitPosition))
	portrait:SetSize(unpack(db.PortraitSize))
	portrait:SetAlpha(db.PortraitAlpha)
	portrait.distanceScale = db.PortraitDistanceScale
	portrait.positionX = db.PortraitPositionX
	portrait.positionY = db.PortraitPositionY
	portrait.positionZ = db.PortraitPositionZ
	portrait.rotation = db.PortraitRotation
	portrait.showFallback2D = db.PortraitShowFallback2D
	portrait.fallbackParent = portraitFrame
	EnsureArenaPortraitFallbackTexture(portrait)
	HideArenaPortraitFallback(portrait)

	self.Portrait = portrait
	self.Portrait.Override = Portrait_Override
	API.AttachPortraitAlphaFix(self, portrait)

	local portraitBg = portraitFrame:CreateTexture(nil, "BACKGROUND", nil, 0)
	portraitBg:SetPoint(unpack(db.PortraitBackgroundPosition))
	portraitBg:SetSize(unpack(db.PortraitBackgroundSize))
	portraitBg:SetTexture(db.PortraitBackgroundTexture)
	portraitBg:SetVertexColor(unpack(db.PortraitBackgroundColor))

	self.Portrait.Bg = portraitBg

	local portraitOverlayFrame = CreateFrame("Frame", nil, self)
	portraitOverlayFrame:SetFrameLevel(portraitFrame:GetFrameLevel() + 1)
	portraitOverlayFrame:SetAllPoints()

	local portraitShade = portraitOverlayFrame:CreateTexture(nil, "BACKGROUND", nil, -1)
	portraitShade:SetPoint(unpack(db.PortraitShadePosition))
	portraitShade:SetSize(unpack(db.PortraitShadeSize))
	portraitShade:SetTexture(db.PortraitShadeTexture)

	self.Portrait.Shade = portraitShade

	local portraitBorder = portraitOverlayFrame:CreateTexture(nil, "BACKGROUND", nil, 0)
	portraitBorder:SetPoint(unpack(db.PortraitBorderPosition))
	portraitBorder:SetSize(unpack(db.PortraitBorderSize))
	portraitBorder:SetTexture(db.PortraitBorderTexture)
	portraitBorder:SetVertexColor(unpack(db.PortraitBorderColor))

	self.Portrait.Border = portraitBorder

	-- Absorb Bar (Retail)
	--------------------------------------------
	if (ns.IsRetail) then
		local absorb = self:CreateBar()
		absorb:SetAllPoints(health)
		absorb:SetFrameLevel(health:GetFrameLevel() + 3)
		absorb:SetStatusBarTexture(db.HealthBarTexture)
		absorb:SetStatusBarColor(unpack(db.HealthAbsorbColor))
		absorb:SetSparkMap(db.HealthBarSparkMap)
		absorb:SetAlpha(0)
		absorb:Hide()
		ApplyArenaBarFillRule(absorb, db.HealthBarOrientation == "LEFT" and "RIGHT" or db.HealthBarOrientation)

		-- self.HealthPrediction.absorbBar = absorb -- Temporary rollback: broken absorb overlay covers arena health bars.
	end

	-- Readycheck
	--------------------------------------------
	local readyCheckIndicator = overlay:CreateTexture(nil, "OVERLAY", nil, 7)
	readyCheckIndicator:SetSize(unpack(db.ReadyCheckSize))
	readyCheckIndicator:SetPoint(unpack(db.ReadyCheckPosition))
	readyCheckIndicator.readyTexture = db.ReadyCheckReadyTexture
	readyCheckIndicator.notReadyTexture = db.ReadyCheckNotReadyTexture
	readyCheckIndicator.waitingTexture = db.ReadyCheckWaitingTexture

	self.ReadyCheckIndicator = readyCheckIndicator

	-- CombatFeedback Text
	--------------------------------------------
	local feedbackText = overlay:CreateFontString(nil, "OVERLAY")
	feedbackText:SetPoint(db.CombatFeedbackPosition[1], self[db.CombatFeedbackAnchorElement], unpack(db.CombatFeedbackPosition))
	feedbackText:SetFontObject(db.CombatFeedbackFont)
	feedbackText.feedbackFont = db.CombatFeedbackFont
	feedbackText.feedbackFontLarge = db.CombatFeedbackFontLarge
	feedbackText.feedbackFontSmall = db.CombatFeedbackFontSmall

	self.CombatFeedback = feedbackText

	-- Target Highlight
	--------------------------------------------
	--local targetHighlight = healthOverlay:CreateTexture(nil, "BACKGROUND", nil, -2)
	--targetHighlight:SetPoint(unpack(db.TargetHighlightPosition))
	--targetHighlight:SetSize(unpack(db.TargetHighlightSize))
	--targetHighlight:SetTexture(db.TargetHighlightTexture)
	--targetHighlight.colorTarget = db.TargetHighlightTargetColor
	--targetHighlight.colorFocus = db.TargetHighlightFocusColor

	--self.TargetHighlight = targetHighlight

	-- Unit Name
	--------------------------------------------
	local name = overlay:CreateFontString(nil, "OVERLAY", nil, 1)
	name:SetPoint(unpack(db.NamePosition))
	name:SetFontObject(db.NameFont)
	name:SetTextColor(unpack(db.NameColor))
	name:SetJustifyH(db.NameJustifyH)
	name:SetJustifyV(db.NameJustifyV)
	self:Tag(name, prefix("[*:Name(12,nil,nil,true)]"))

	self.Name = name

	-- PvP Specialization Icon
	--------------------------------------------
	local specIconFrame = CreateFrame("Frame", nil, self)
	specIconFrame:SetSize(unpack(db.PvPSpecIconFrameSize))
	specIconFrame:SetPoint(unpack(db.PvPSpecIconFramePosition))
	specIconFrame:SetFrameLevel(portraitOverlayFrame:GetFrameLevel() + 1)
	--specIconFrame.showFaction = true

	local specIconBackdrop = specIconFrame:CreateTexture(nil, "BACKGROUND", nil, -2)
	specIconBackdrop:SetPoint(unpack(db.PvPSpecIconBackdropPosition))
	specIconBackdrop:SetSize(unpack(db.PvPSpecIconBackdropSize))
	specIconBackdrop:SetTexture(db.PvPSpecIconBackdropTexture)
	specIconBackdrop:SetVertexColor(unpack(db.PvPSpecIconBackdropColor))

	local specIcon = specIconFrame:CreateTexture(nil, "BACKGROUND", nil, -1)
	specIcon:SetPoint(unpack(db.PvPSpecIconIconPositon))
	specIcon:SetSize(unpack(db.PvPSpecIconIconSize))
	specIcon:SetMask(db.PvPSpecIconIconMask)
	specIcon.azeriteHasMask = true

	self.SpecIcon = specIconFrame
	self.SpecIcon.icon = specIcon
	self.SpecIcon.Override = SpecIcon_Override

	-- Trinket Icon
	--------------------------------------------
	--[[--
	local trinket = CreateFrame("Frame", nil, self)
	trinket:SetSize(unpack(db.TrinketFrameSize))
	trinket:SetPoint(unpack(db.TrinketFramePosition))
	trinket:SetFrameLevel(portraitOverlayFrame:GetFrameLevel())

	local trinketIcon = trinket:CreateTexture(nil, "BACKGROUND", nil, -2)
	trinketIcon:SetPoint(unpack(db.TrinketIconPositon))
	trinketIcon:SetSize(unpack(db.TrinketIconSize))
	trinketIcon:SetMask(db.TrinketIconMask)

	local b,m = ns.API.GetMedia("blank"), db.TrinketIconMask
	local trinketCooldown = CreateFrame("Cooldown", nil, trinket)
	trinketCooldown:SetFrameLevel(portraitOverlayFrame:GetFrameLevel() + 1)
	trinketCooldown:SetAllPoints(trinketIcon)
	trinketCooldown:SetUseCircularEdge(true)
	trinketCooldown:SetReverse(false)
	trinketCooldown:SetSwipeTexture(m)
	trinketCooldown:SetDrawSwipe(true)
	trinketCooldown:SetBlingTexture(b, 0, 0, 0, 0)
	trinketCooldown:SetDrawBling(false)
	trinketCooldown:SetEdgeTexture(b)
	trinketCooldown:SetDrawEdge(false)
	trinketCooldown:SetHideCountdownNumbers(true)

	ns.Widgets.RegisterCooldown(trinketCooldown)

	hooksecurefunc(trinketCooldown, "SetSwipeTexture", function(c,t) if t ~= m then c:SetSwipeTexture(m) end end)
	hooksecurefunc(trinketCooldown, "SetBlingTexture", function(c,t) if t ~= b then c:SetBlingTexture(b,0,0,0,0) end end)
	hooksecurefunc(trinketCooldown, "SetEdgeTexture", function(c,t) if t ~= b then c:SetEdgeTexture(b) end end)
	hooksecurefunc(trinketCooldown, "SetDrawSwipe", function(c,h) if not h then c:SetDrawSwipe(true) end end)
	hooksecurefunc(trinketCooldown, "SetDrawBling", function(c,h) if h then c:SetDrawBling(false) end end)
	hooksecurefunc(trinketCooldown, "SetDrawEdge", function(c,h) if h then c:SetDrawEdge(false) end end)
	hooksecurefunc(trinketCooldown, "SetHideCountdownNumbers", function(c,h) if not h then c:SetHideCountdownNumbers(true) end end)
	hooksecurefunc(trinketCooldown, "SetCooldown", function(c) c:SetAlpha(.75) end)

	self.Trinket = trinket
	self.Trinket.cc = trinketCooldown
	self.Trinket.icon = trinketIcon
	--]]--

	-- Auras
	--------------------------------------------
	local auras = CreateFrame("Frame", nil, self)
	auras:SetSize(unpack(db.AurasSize))
	auras:SetPoint(unpack(db.AurasPosition))
	auras.size = db.AuraSize
	auras.spacing = db.AuraSpacing
	auras.numBuffs = db.AurasNumBuffs
	auras.numDebuffs = db.AurasNumDebuffs
	auras.numTotal = db.AurasNumTotal
	auras.disableMouse = db.AurasDisableMouse
	auras.disableCooldown = db.AurasDisableCooldown
	auras.onlyShowPlayer = db.AurasOnlyShowPlayer
	auras.showStealableBuffs = db.AurasShowStealableBuffs
	auras.initialAnchor = db.AurasInitialAnchor
	auras["spacing-x"] = db.AurasSpacingX
	auras["spacing-y"] = db.AurasSpacingY
	auras["growth-x"] = db.AurasGrowthX
	auras["growth-y"] = db.AurasGrowthY
	auras.tooltipAnchor = db.AurasTooltipAnchor
	auras.sortMethod = db.AurasSortMethod
	auras.sortDirection = db.AurasSortDirection
	auras.reanchorIfVisibleChanged = true
	auras.allowCombatUpdates = true
	auras.CreateButton = ns.AuraStyles.CreateButton
	auras.PostUpdateButton = ns.AuraStyles.ArenaPostUpdateButton
	auras.CustomFilter = ns.AuraFilters.ArenaAuraFilter -- classic
	auras.FilterAura = ns.AuraFilters.ArenaAuraFilter -- retail
	auras.filter = nil
	auras.buffFilter = nil
	auras.debuffFilter = "PLAYER" -- Debuffs applied by the player

	if (ns:GetModule("UnitFrames").db.global.disableAuraSorting) then
		auras.PreSetPosition = ns.AuraSorts.Alternate -- only in classic
		auras.SortAuras = ns.AuraSorts.AlternateFuncton -- only in retail
	else
		auras.PreSetPosition = ns.AuraSorts.Default -- only in classic
		auras.SortAuras = ns.AuraSorts.DefaultFunction -- only in retail
	end

	self.Auras = auras

	-- Range Opacity
	-----------------------------------------------------------
	self.Range = { outsideAlpha = .6 }

	-- Textures need an update when frame is displayed.
	self.PostUpdate = UnitFrame_PostUpdate

	-- Register events to handle additional texture updates.
	self:RegisterEvent("PLAYER_ENTERING_WORLD", UnitFrame_OnEvent, true)
	self:RegisterEvent("PLAYER_TARGET_CHANGED", UnitFrame_OnEvent, true)

end

-- Fake GroupHeader
---------------------------------------------------
local GroupHeader = {}

GroupHeader.ForAll = function(self, methodOrFunc, ...)
	for frame in next,Units do
		if (type(methodOrFunc) == "string") then
			frame[methodOrFunc](frame, ...)
		else
			methodOrFunc(frame, ...)
		end
	end
end

GroupHeader.Enable = function(self)
	if (InCombatLockdown()) then return end
	for frame in next,Units do
		frame:Enable()
	end
	self:UpdateVisibilityDriver()
	self.enabled = true
end

GroupHeader.Disable = function(self)
	if (InCombatLockdown()) then return end
	for frame in next,Units do
		frame:Disable()
	end
	self:UpdateVisibilityDriver()
	self.enabled = false
end

GroupHeader.IsEnabled = function(self)
	return self.enabled
end

GroupHeader.UpdateVisibilityDriver = function(self)
	if (InCombatLockdown()) then return end

	local isInInstance, instanceType = IsInInstance()
	if (IsRuntimeTestMode()) then
		self.visibility = "show"
	elseif (isInInstance and instanceType == "arena" and HasArenaPrepOpponents()) then
		self.visibility = "show"
	elseif (isInInstance and instanceType == "arena") then
		self.visibility = ArenaUnitExistsVisibilityDriver
	elseif (not isInInstance or (instanceType ~= "arena" and not ArenaFrameMod.db.profile.showInBattlegrounds)) then
		self.visibility = "hide"
	else
		self.visibility = "show"
	end

	UnregisterAttributeDriver(self, "state-visibility")
	RegisterAttributeDriver(self, "state-visibility", self.visibility)

end

-- Sourced from FrameXML\SecureGroupHeaders.lua
-- relativePoint, xMultiplier, yMultiplier = getRelativePointAnchor(point)
-- Given a point return the opposite point and which axes the point depends on.
local getRelativePointAnchor = function(point)
	point = string_upper(point)
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
	else
		return "CENTER", 0, 0
	end
end

-- Sourced from FrameXML\SecureGroupHeaders.lua > configureChildren()
ArenaFrameMod.GetCalculatedHeaderSize = function(self, numDisplayed)

	local config = ns.GetConfig("ArenaFrames")
	local db = self.db.profile

	local header = self:GetUnitFrameOrHeader()
	local unitButtonWidth = config.UnitSize[1]
	local unitButtonHeight = config.UnitSize[2]
	local unitsPerColumn = db.unitsPerColumn
	local point = db.point or "TOP"
	local relativePoint, xOffsetMult, yOffsetMult = getRelativePointAnchor(point)
	local xMultiplier, yMultiplier =  math_abs(xOffsetMult), math_abs(yOffsetMult)
	local xOffset = db.xOffset or 0
	local yOffset = db.yOffset or 0
	local columnSpacing = db.columnSpacing or 0

	local numColumns
	if (unitsPerColumn and numDisplayed > unitsPerColumn) then
		numColumns = math_min(math_ceil(numDisplayed/unitsPerColumn), (db.maxColumns or 1))
	else
		unitsPerColumn = numDisplayed
		numColumns = 1
	end

	local columnAnchorPoint, columnRelPoint, colxMulti, colyMulti
	if (numColumns > 1) then
		columnAnchorPoint = db.columnAnchorPoint
		columnRelPoint, colxMulti, colyMulti = getRelativePointAnchor(columnAnchorPoint)
	end

	local width, height

	if (numDisplayed > 0) then
		width = xMultiplier * (unitsPerColumn - 1) * unitButtonWidth + ((unitsPerColumn - 1) * (xOffset * xOffsetMult)) + unitButtonWidth
		height = yMultiplier * (unitsPerColumn - 1) * unitButtonHeight + ((unitsPerColumn - 1) * (yOffset * yOffsetMult)) + unitButtonHeight

		if (numColumns > 1) then
			width = width + ((numColumns -1) * math_abs(colxMulti) * (width + columnSpacing))
			height = height + ((numColumns -1) * math_abs(colyMulti) * (height + columnSpacing))
		end
	else
		local minWidth = db.minWidth or (yMultiplier * unitButtonWidth)
		local minHeight = db.minHeight or (xMultiplier * unitButtonHeight)

		width = math_max(minWidth, 0.1)
		height = math_max(minHeight, 0.1)
	end

	return width, height
end

-- Sourced from FrameXML\SecureGroupHeaders.lua > configureChildren()
ArenaFrameMod.ConfigureChildren = function(self)
	if (InCombatLockdown()) then return end

	local db = self.db.profile
	local config = ns.GetConfig("ArenaFrames")
	local header = self:GetUnitFrameOrHeader()
	local frame = self:GetFrame()

	local point = db.point or "TOP"
	local relativePoint, xOffsetMult, yOffsetMult = getRelativePointAnchor(point)
	local xMultiplier, yMultiplier =  math_abs(xOffsetMult), math_abs(yOffsetMult)
	local xOffset = db.xOffset or 0
	local yOffset = db.yOffset or 0
	local sortDir = db.sortDir or "ASC"
	local columnSpacing = db.columnSpacing or 0
	local startingIndex = db.startingIndex or 1

	local unitCount = 5

	local numDisplayed = unitCount - (startingIndex - 1)
	local unitsPerColumn = db.unitsPerColumn
	local numColumns
	if (unitsPerColumn and numDisplayed > unitsPerColumn) then
		numColumns = math_min(math_ceil(numDisplayed/unitsPerColumn), (db.maxColumns or 1))
	else
		unitsPerColumn = numDisplayed
		numColumns = 1
	end
	local loopStart = startingIndex
	local loopFinish = math_min((startingIndex - 1) + unitsPerColumn * numColumns, unitCount)
	local step = 1

	numDisplayed = loopFinish - (loopStart - 1)

	if (sortDir == "DESC") then
		loopStart = unitCount - (startingIndex - 1)
		loopFinish = loopStart - (numDisplayed - 1)
		step = -1
	end

	local columnAnchorPoint, columnRelPoint, colxMulti, colyMulti
	if (numColumns > 1) then
		columnAnchorPoint = db.columnAnchorPoint
		columnRelPoint, colxMulti, colyMulti = getRelativePointAnchor(columnAnchorPoint)
	end

	local buttonNum = 0
	local columnNum = 1
	local columnUnitCount = 0
	local currentAnchor = header
	for i = loopStart, loopFinish, step do
		buttonNum = buttonNum + 1
		columnUnitCount = columnUnitCount + 1
		if (columnUnitCount > unitsPerColumn) then
			columnUnitCount = 1
			columnNum = columnNum + 1
		end

		local unitButton = header:GetAttribute("child"..buttonNum)
		unitButton:ClearAllPoints()

		if (buttonNum == 1) then
			unitButton:SetPoint(point, currentAnchor, point, 0, 0)
			if (columnAnchorPoint) then
				unitButton:SetPoint(columnAnchorPoint, currentAnchor, columnAnchorPoint, 0, 0)
			end

		elseif (columnUnitCount == 1) then
			local columnAnchor = header:GetAttribute("child"..(buttonNum - unitsPerColumn))
			unitButton:SetPoint(columnAnchorPoint, columnAnchor, columnRelPoint, colxMulti * columnSpacing, colyMulti * columnSpacing)

		else
			unitButton:SetPoint(point, currentAnchor, relativePoint, xMultiplier * xOffset, yMultiplier * yOffset)
		end

		currentAnchor = unitButton
	end

	header:SetSize(self:GetCalculatedHeaderSize(numDisplayed))
end

ArenaFrameMod.GetHeaderSize = function(self)
	return self:GetCalculatedHeaderSize(5)
end

ArenaFrameMod.CreateUnitFrames = function(self)

	local unit, name = "arena", "Arena"

	oUF:RegisterStyle(ns.Prefix..name, style)
	oUF:SetActiveStyle(ns.Prefix..name)

	self.frame = CreateFrame("Frame", nil, UIParent)
	self.frame.content = CreateFrame("Frame", ns.Prefix.."ArenaEnemyFrames", UIParent, "SecureHandlerStateTemplate")

	-- Embed our custom methods
	for method,func in next,GroupHeader do
		self.frame.content[method] = func
	end

	for i = 1,5 do
		local unitButton = ns.UnitFrame.Spawn(unit..i, ns.Prefix.."UnitFrame"..name..i)

		unitButton:SetParent(self.frame.content)

		-- This severely bugs out in the prep phase in shuffles,
		-- so we're going to disable it and enable on demand.
		unitButton:DisableElement("Auras")

		self.frame.content:SetFrameRef("child"..i, unitButton)
		self.frame.content:SetAttribute("child"..i, unitButton)
	end

	ApplyTestUnitDrivers(self)

	self:UpdateHeader()
end

ArenaFrameMod.UpdateHeader = function(self)
	local header = self:GetUnitFrameOrHeader()
	if (not header) then return end

	if (InCombatLockdown()) then
		self.needHeaderUpdate = true
		self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnEvent")
		return
	end

	local config = ns.GetConfig("ArenaFrames")

	header:UpdateVisibilityDriver()

	header:SetAttribute("unitWidth", config.UnitSize[1])
	header:SetAttribute("unitHeight", config.UnitSize[2])
	header:SetAttribute("point", self.db.profile["point"])
	header:SetAttribute("xOffset", self.db.profile["xOffset"])
	header:SetAttribute("yOffset", self.db.profile["yOffset"])
	header:SetAttribute("groupBy", self.db.profile["groupBy"])
	header:SetAttribute("groupingOrder", self.db.profile["groupingOrder"])
	header:SetAttribute("unitsPerColumn", self.db.profile["unitsPerColumn"])
	header:SetAttribute("maxColumns", self.db.profile["maxColumns"])
	header:SetAttribute("columnSpacing", self.db.profile["columnSpacing"])
	header:SetAttribute("columnAnchorPoint", self.db.profile["columnAnchorPoint"])

	self:GetFrame():SetSize(self:GetHeaderSize())
	self:ConfigureChildren()

	self:UpdateHeaderAnchorPoint() -- update where the group header is anchored to our anchorframe.
	self:UpdateAnchor() -- the general update does this too, but we need it in case nothing but this function has been called.
end

ArenaFrameMod.UpdateHeaderAnchorPoint = function(self)
	local point = "TOPLEFT"
	if (self.db.profile.columnAnchorPoint == "LEFT") then
		if (self.db.profile.point == "TOP") then
			point = "TOPLEFT"
		elseif (self.db.profile.point == "BOTTOM") then
			point = "BOTTOMLEFT"
		end
	elseif (self.db.profile.columnAnchorPoint == "RIGHT") then
		if (self.db.profile.point == "TOP") then
			point = "TOPRIGHT"
		elseif (self.db.profile.point == "BOTTOM") then
			point = "BOTTOMRIGHT"
		end
	elseif (self.db.profile.columnAnchorPoint == "TOP") then
		if (self.db.profile.point == "LEFT") then
			point = "TOPLEFT"
		elseif (self.db.profile.point == "RIGHT") then
			point = "TOPRIGHT"
		end
	elseif (self.db.profile.columnAnchorPoint == "BOTTOM") then
		if (self.db.profile.point == "LEFT") then
			point = "BOTTOMLEFT"
		elseif (self.db.profile.point == "RIGHT") then
			point = "BOTTOMRIGHT"
		end
	end
	local header = self:GetUnitFrameOrHeader()
	header:ClearAllPoints()
	header:SetPoint(point, self:GetFrame(), point)
end

ArenaFrameMod.UpdateUnits = function(self)
	if (not self:GetFrame()) then return end

	for frame in next,Units do
		if (self.db.profile.useRangeIndicator) then
			frame:EnableElement("Range")
		else
			frame:DisableElement("Range")
			frame:SetAlpha(1)
		end

		frame:UpdateAllElements("RefreshUnit")
	end
end

ArenaFrameMod.Update = function(self)
	ApplyTestUnitDrivers(self)
	self:UpdateHeader()
	self:UpdateUnits()
end

ArenaFrameMod.OnEvent = function(self, event, ...)
	if (event == "ARENA_PREP_OPPONENT_SPECIALIZATIONS") then
		for frame in next,Units do
			HideArenaPortraitFallback(frame.Portrait)
			ResetArenaOpponentInfo(frame)
			ResolveArenaOpponentInfo(frame, nil)
			if (frame.SpecIcon and frame.SpecIcon.ForceUpdate) then
				frame.SpecIcon:ForceUpdate()
			end
		end

		if (InCombatLockdown()) then
			self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnEvent")
			return
		end

		self:UpdateHeader()

	elseif (event == "ARENA_OPPONENT_UPDATE") then

		self:UpdateHeader()

		-- Enable and refresh live-only elements when the opponent unit exists.
		local unit, updateReason = ...
		for frame in next,Units do
			if (frame.unit == unit and updateReason == "seen") then
				if (frame.Portrait and frame.Portrait.ForceUpdate) then
					frame.Portrait:Show()
					frame.Portrait:ForceUpdate()
				end
				if (frame.Health and frame.Health.ForceUpdate) then
					frame.Health:ForceUpdate()
				end
				if (frame.SpecIcon and frame.SpecIcon.ForceUpdate) then
					frame.SpecIcon:ForceUpdate()
				end
				if (not frame:IsElementEnabled("Auras")) then
					frame:EnableElement("Auras")
					frame.Auras:ForceUpdate()
				end
			end
		end

	elseif (event == "PLAYER_ENTERING_WORLD") then
		if (InCombatLockdown()) then
			self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnEvent")
			return
		end

		-- Disable the element upon entering world
		-- to avoid shuffle prep phase bugging out.
		for frame in next,Units do
			frame:DisableElement("Auras")
			HideArenaPortraitFallback(frame.Portrait)
		end

		self:UpdateHeader()

	elseif (event == "PLAYER_LEAVING_WORLD") then

		-- Disable the element upon leaving world
		-- to avoid shuffle prep phase bugging out.
		for frame in next,Units do
			frame:DisableElement("Auras")
			HideArenaPortraitFallback(frame.Portrait)
			ResetArenaOpponentInfo(frame)
		end

	elseif (event == "PLAYER_REGEN_ENABLED") then
		if (InCombatLockdown()) then return end

		self:UnregisterEvent("PLAYER_REGEN_ENABLED", "OnEvent")

		if (self.needHeaderUpdate) then
			self.needHeaderUpdate = nil
			self:UpdateHeader()
		end
	end
end

ArenaFrameMod.OnEnable = function(self)

	self:CreateUnitFrames()
	self:CreateAnchor(L["Arena Enemy Frames"])

	ns.MovableModulePrototype.OnEnable(self)

	self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEvent")
	self:RegisterEvent("PLAYER_LEAVING_WORLD", "OnEvent")
	self:RegisterEvent("ARENA_PREP_OPPONENT_SPECIALIZATIONS", "OnEvent")
	self:RegisterEvent("ARENA_OPPONENT_UPDATE", "OnEvent")
end


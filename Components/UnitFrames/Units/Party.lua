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

local PartyFrameMod = ns:NewModule("PartyFrames", ns.UnitFrameModule, "LibMoreEvents-1.0", "AceHook-3.0")

-- Lua API
local ipairs = ipairs
local math_abs = math.abs
local math_ceil = math.ceil
local math_floor = math.floor
local math_max = math.max
local math_min = math.min
local math_pi = math_pi
local next = next
local select = select
local string_gsub = string.gsub
local string_match = string.match
local string_upper = string.upper
local table_concat = table.concat
local table_insert = table.insert
local table_sort = table.sort
local type = type
local unpack = unpack

-- GLOBALS: InCombatLockdown, RegisterAttributeDriver, UnregisterAttributeDriver
-- GLOBALS: UnitGroupRolesAssigned, UnitGUID, UnitIsUnit, SetPortraitTexture
-- GLOBALS: GetNumGroupMembers, GetRaidRosterInfo, UnitInRaid

-- Addon API
local Colors = ns.Colors
local GetMedia = ns.API.GetMedia
local GetFont = ns.API.GetFont

local Units = {}
local TESTMODE --= true
local PARTY_GROUP_BY = "GROUP"
local PARTY_GROUPING_ORDER = "1,2,3,4,5,6,7,8"
local defaults = { profile = ns:Merge({

	enabled = true,

	useInParties = true, -- show in non-raid parties
	useInRaid5 = false, -- show in raid groups of 1-5 players
	useInRaid10 = false, -- show in raid groups of 6-10 players
	useInRaid25 = false, -- show in raid groups of 11-25 players
	useInRaid40 = false, -- show in raid groups of 26-40 players

	showAuras = true,
	showPlayer = false,
	useClassColors = true,
	useBlizzardHealthColors = false,
	useClassColorOnMouseoverOnly = false,
	AuraSize = 30,
	AurasSpacingX = 4,
	AurasSpacingY = 4,
	AurasGrowthX = "RIGHT",
	AurasGrowthY = "DOWN",
	AurasInitialAnchor = "TOPLEFT",
	partyAuraDebuffScale = 100,
	partyAuraUseStockBehavior = true,
	partyAuraShowDispellableDebuffs = true,
	partyAuraOnlyDispellableDebuffs = false,
	partyAuraShowBossAndImportantDebuffs = true,
	partyAuraShowOtherDebuffs = true,
	partyAuraShowHelpfulExternals = true,
	partyAuraShowHelpfulRaidBuffs = true,
	partyAuraShowHelpfulShortBuffs = true,
	partyAuraGlowDispellableDebuffs = true,

	point = "LEFT", -- anchor point of unitframe, group members within column grow opposite
	xOffset = 0, -- horizontal offset within the same column
	yOffset = 0, -- vertical offset within the same column

	groupBy = PARTY_GROUP_BY, -- GROUP, CLASS, ROLE
	groupingOrder = PARTY_GROUPING_ORDER, -- must match choice in groupBy

	unitsPerColumn = 5, -- maximum units per column
	maxColumns = 1, -- should be 5/unitsPerColumn
	columnSpacing = 0, -- spacing between columns
	columnAnchorPoint = "TOP" -- anchor point of column, columns grow opposite

}, ns.MovableModulePrototype.defaults) }

local validHeaderPoints = {
	TOP = true,
	BOTTOM = true,
	LEFT = true,
	RIGHT = true,
	TOPLEFT = true,
	TOPRIGHT = true,
	BOTTOMLEFT = true,
	BOTTOMRIGHT = true
}

local GetSanitizedHeaderProfile = function(profile)
	local db = profile or defaults.profile
	local fallback = defaults.profile

	return {
		point = (type(db.point) == "string" and validHeaderPoints[db.point] and db.point) or fallback.point or "LEFT",
		xOffset = (type(db.xOffset) == "number" and db.xOffset) or fallback.xOffset or 0,
		yOffset = (type(db.yOffset) == "number" and db.yOffset) or fallback.yOffset or 0,
		unitsPerColumn = (type(db.unitsPerColumn) == "number" and db.unitsPerColumn > 0 and db.unitsPerColumn) or fallback.unitsPerColumn or 5,
		maxColumns = (type(db.maxColumns) == "number" and db.maxColumns > 0 and db.maxColumns) or fallback.maxColumns or 1,
		columnSpacing = (type(db.columnSpacing) == "number" and db.columnSpacing) or fallback.columnSpacing or 0,
		columnAnchorPoint = (type(db.columnAnchorPoint) == "string" and validHeaderPoints[db.columnAnchorPoint] and db.columnAnchorPoint) or fallback.columnAnchorPoint or "TOP"
	}
end

local GetActiveGroupFilter = function()
	local defaultFilter = PARTY_GROUPING_ORDER
	if (not IsInRaid() or GetNumGroupMembers() <= 0) then
		return defaultFilter
	end

	local playerRaidIndex = UnitInRaid("player")
	if (not playerRaidIndex) then
		return defaultFilter
	end

	local _, _, subgroup = GetRaidRosterInfo(playerRaidIndex)
	if (type(subgroup) == "number" and subgroup >= 1 and subgroup <= 8) then
		return tostring(subgroup)
	end

	return defaultFilter
end

-- Generate module defaults on the fly
-- to recalculate default values relying on
-- changing factors like user interface scale.
PartyFrameMod.GenerateDefaults = function(self)
	defaults.profile.savedPosition = {
		scale = ns.API.GetEffectiveScale(),
		[1] = "TOPLEFT",
		[2] = 50 * ns.API.GetEffectiveScale(),
		[3] = -42 * ns.API.GetEffectiveScale()
	}
	return defaults
end

-- Utility Functions
--------------------------------------------
-- Simplify the tagging process a little.
local prefix = function(msg)
	return string_gsub(msg, "*", ns.Prefix)
end

local GetPartyAuraProfile = function()
	return PartyFrameMod and PartyFrameMod.db and PartyFrameMod.db.profile or defaults.profile
end

local GetPartyAuraSetting = function(profile, key, fallback)
	if (profile and profile[key] ~= nil) then
		return profile[key]
	end
	return fallback
end

local GetPartyAuraLayoutValue = function(profile, key, fallback)
	local value = GetPartyAuraSetting(profile, key, fallback)
	return (value ~= nil) and value or fallback
end

local GetPartyAuraPerRow = function(config)
	local size = (config and config.AuraSize) or 30
	local spacing = (config and config.AuraSpacing) or 4
	local frameWidth = config and config.AurasSize and config.AurasSize[1]
	if (type(frameWidth) ~= "number" or frameWidth <= 0) then
		return 3
	end
	local denom = size + spacing
	if (denom <= 0) then
		return 3
	end
	return math_max(1, math_floor(((frameWidth + spacing) / denom) + .5))
end

local CreateHealthColors = function(useBlizzardColors)
	local colors = {}
	for key, value in pairs(ns.Colors) do
		colors[key] = value
	end

	local source = useBlizzardColors and oUF.colors or ns.Colors
	colors.health = useBlizzardColors and source.health or ns.Colors.green
	colors.class = source.class
	colors.reaction = source.reaction

	return colors
end

local ApplyHealthColorMode = function(frame, profile)
	if (not frame or not frame.Health) then
		return
	end

	local health = frame.Health
	local useClassColors = not (profile and profile.useClassColors == false)
	local onlyOnMouseover = useClassColors and profile and profile.useClassColorOnMouseoverOnly
	local showClassColors = useClassColors and ((not onlyOnMouseover) or frame.__AzeriteUI_HealthColorMouseOver)
	local useBlizzardColors = useClassColors and profile and profile.useBlizzardHealthColors

	frame.colors = CreateHealthColors(useBlizzardColors)
	health.colorClass = showClassColors and true or false
	health.colorClassPet = showClassColors and true or false
	health.colorReaction = showClassColors and true or false
	health.colorHealth = true

	if (health.ForceUpdate) then
		health:ForceUpdate()
	end
end

local UpdateMouseoverHealthColor = function(frame, profile, isMouseOver)
	frame.__AzeriteUI_HealthColorMouseOver = isMouseOver and true or false
	ApplyHealthColorMode(frame, profile)
end

local ApplyPartyAuraLayout = function(frame)
	if (not frame or not frame.Auras) then
		return
	end

	local config = ns.GetConfig("PartyFrames")
	local profile = GetPartyAuraProfile()
	local auras = frame.Auras
	local auraSize = GetPartyAuraLayoutValue(profile, "AuraSize", config.AuraSize or 30)
	local spacingX = GetPartyAuraLayoutValue(profile, "AurasSpacingX", config.AurasSpacingX or config.AuraSpacing or 4)
	local spacingY = GetPartyAuraLayoutValue(profile, "AurasSpacingY", config.AurasSpacingY or config.AuraSpacing or 4)
	local growthX = GetPartyAuraLayoutValue(profile, "AurasGrowthX", config.AurasGrowthX or "RIGHT")
	local growthY = GetPartyAuraLayoutValue(profile, "AurasGrowthY", config.AurasGrowthY or "DOWN")
	local initialAnchor = GetPartyAuraLayoutValue(profile, "AurasInitialAnchor", config.AurasInitialAnchor or "TOPLEFT")
	local perRow = GetPartyAuraPerRow(config)
	local numTotal = config.AurasNumTotal or 6
	local rows = math_max(1, math_ceil(numTotal / perRow))
	local width = (perRow * auraSize) + ((perRow - 1) * spacingX)
	local height = (rows * auraSize) + ((rows - 1) * spacingY)

	auras:SetSize(width, height)
	auras.size = auraSize
	auras.spacing = config.AuraSpacing or 4
	auras.numTotal = numTotal
	auras.initialAnchor = initialAnchor
	auras.spacingX = spacingX
	auras.spacingY = spacingY
	auras.growthX = growthX
	auras.growthY = growthY
	auras["spacing-x"] = spacingX
	auras["spacing-y"] = spacingY
	auras["growth-x"] = growthX
	auras["growth-y"] = growthY
end

local GetDispellableDebuffColor = function(frame)
	if (not frame or not frame.unit or not frame.PriorityDebuff or not frame.PriorityDebuff.dispelTypes) then
		return nil
	end

	local bestColor
	local bestPriority = -1
	local bestType
	local unit = frame.unit
	local dispelTypes = frame.PriorityDebuff.dispelTypes

	for index = 1, 40 do
		local auraData = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex and C_UnitAuras.GetAuraDataByIndex(unit, index, "HARMFUL")
		if (not auraData) then
			break
		end

		local auraInstanceID = auraData.auraInstanceID
		local dispelName = (issecretvalue and issecretvalue(auraData.dispelName)) and nil or auraData.dispelName
		local canDispelType = dispelName and dispelTypes[dispelName]
		local isRaidPlayerDispellable = false
		if (auraInstanceID and C_UnitAuras and C_UnitAuras.IsAuraFilteredOutByInstanceID) then
			local ok, filtered = pcall(C_UnitAuras.IsAuraFilteredOutByInstanceID, unit, auraInstanceID, "HARMFUL|RAID_PLAYER_DISPELLABLE")
			if (ok and not (issecretvalue and issecretvalue(filtered))) then
				isRaidPlayerDispellable = (filtered == false)
			end
		end

		if (canDispelType or isRaidPlayerDispellable) then
			local priority = 0
			if (dispelName == "Magic") then
				priority = 4
			elseif (dispelName == "Curse") then
				priority = 3
			elseif (dispelName == "Disease") then
				priority = 2
			elseif (dispelName == "Poison") then
				priority = 1
			end
			if (priority > bestPriority) then
				bestPriority = priority
				bestType = dispelName
			end
		end
	end

	if (bestType and Colors.debuff[bestType]) then
		bestColor = Colors.debuff[bestType]
	end

	return bestColor
end

local AuraHighlight_Update = function(self, event, unit, ...)
	if (unit and unit ~= self.unit) then return end

	local element = self.AuraHighlight
	if (not element) then
		return
	end

	local profile = GetPartyAuraProfile()
	if (not GetPartyAuraSetting(profile, "partyAuraGlowDispellableDebuffs", true)) then
		element:Hide()
		return
	end

	local color = GetDispellableDebuffColor(self)
	if (color) then
		element:SetVertexColor(color[1], color[2], color[3], .95)
		element:Show()
	else
		element:Hide()
	end
end

local HasPartyDisplayText = function(value)
	if (value == nil) then
		return false
	end
	if (issecretvalue and issecretvalue(value)) then
		return true
	end
	return (type(value) == "string" and value ~= "")
end

local IsPartyUnitInjured = function(frame)
	local health = frame and frame.Health
	if (not health) then
		return false
	end
	local cur = health.safeCur or health.cur
	local max = health.safeMax or health.max
	if (type(cur) == "number" and type(max) == "number" and max > 0) then
		return cur < max
	end
	local percent = health.safePercent
	return (type(percent) == "number" and percent < 100) and true or false
end

local UpdatePartyHealthTextVisibility = function(frame)
	local health = frame and frame.Health
	if (not health) then
		return
	end
	local healthValue = health.Value
	local healthPercent = health.Percent
	if (not healthValue or not healthPercent) then
		return
	end

	if (healthPercent.UpdateTag) then
		pcall(function() healthPercent:UpdateTag() end)
	end

	local percentText
	pcall(function()
		percentText = healthPercent:GetText()
	end)

	if (IsPartyUnitInjured(frame) and HasPartyDisplayText(percentText)) then
		healthValue:Hide()
		healthPercent:Show()
	else
		healthValue:Show()
		healthPercent:Hide()
	end
end

-- Sourced from FrameXML\SecureGroupHeaders.lua.
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
	end
	return "CENTER", 0, 0
end

local getOrderedHeaderChildren = function(header)
	local children = {}
	local seen = {}

	if (header and header.GetAttribute) then
		local index = 1
		while true do
			local child = header:GetAttribute("child" .. index)
			if (not child) then
				break
			end
			if (not seen[child]) then
				seen[child] = true
				table_insert(children, child)
			end
			index = index + 1
		end
	end

	if (#children == 0) then
		for i = 1, header:GetNumChildren() do
			local child = select(i, header:GetChildren())
			if (child and not seen[child] and (child.unit or (child.GetAttribute and child:GetAttribute("unit")))) then
				seen[child] = true
				table_insert(children, child)
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

-- Element Callbacks
--------------------------------------------
-- Forceupdate health prediction on health updates,
-- to assure our smoothed elements are properly aligned.
local Health_PostUpdate = function(element, unit, cur, max)
	local predict = element.__owner.HealthPrediction
	if (predict) then
		predict:ForceUpdate()
	end
	UpdatePartyHealthTextVisibility(element.__owner)
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
	maxHealth = tonumber(maxHealth) or 1
	if (ns.API.ShouldSkipPrediction(element, myIncomingHeal, otherIncomingHeal, absorb, healAbsorb, hasOverAbsorb, hasOverHealAbsorb, curHealth, maxHealth)) then
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

	local shouldShow = UnitIsConnected(unit) and not UnitIsDeadOrGhost(unit) --[[and element.displayType == Enum.PowerType.Mana]]

	if (not shouldShow or cur == 0 or max == 0) then
		element:SetAlpha(0)
	else
		element:SetAlpha(.75)
	end
end

-- Custom Group Role updater
local GroupRoleIndicator_Override = function(self, event)
	local element = self.GroupRoleIndicator

	--[[ Callback: GroupRoleIndicator:PreUpdate()
	Called before the element has been updated.

	* self - the GroupRoleIndicator element
	--]]
	if (element.PreUpdate) then
		element:PreUpdate()
	end

	local role = UnitGroupRolesAssigned(self.unit)
	if (role and element[role]) then
		element.Icon:SetTexture(element[role])
		element:Show()
	else
		element:Hide()
	end

	--[[ Callback: GroupRoleIndicator:PostUpdate(role)
	Called after the element has been updated.

	* self - the GroupRoleIndicator element
	* role - the role as returned by [UnitGroupRolesAssigned](http://wowprogramming.com/docs/api/UnitGroupRolesAssigned.html)
	--]]
	if (element.PostUpdate) then
		return element:PostUpdate(role)
	end
end

-- Make the portrait look better for offline or invisible units.
local Portrait_PostUpdate = function(element, unit, hasStateChanged)
	if (not element.state) then
		element:ClearModel()
		if (not element.fallback2DTexture) then
			element.fallback2DTexture = element:CreateTexture()
			element.fallback2DTexture:SetDrawLayer("ARTWORK")
			element.fallback2DTexture:SetAllPoints()
			element.fallback2DTexture:SetTexCoord(.1, .9, .1, .9)
		end
		SetPortraitTexture(element.fallback2DTexture, unit)
		element.fallback2DTexture:Show()
	else
		if (element.fallback2DTexture) then
			element.fallback2DTexture:Hide()
		end
		element:SetCamDistanceScale(element.distanceScale or 1)
		element:SetPortraitZoom(1)
		element:SetPosition(element.positionX or 0, element.positionY or 0, element.positionZ or 0)
		element:SetRotation(element.rotation and element.rotation*(2*math_pi)/180 or 0)
		element:ClearModel()
		element:SetUnit(unit)
		element.guid = UnitGUID(unit)
	end
end

-- Update the border color of priority debuffs.
local PriorityDebuff_PostUpdate = function(element, event, isVisible, name, icon, count, debuffType, duration, expirationTime, spellID, isBoss, isCustom)
	if (isVisible) then
		local color = debuffType and Colors.debuff[debuffType] or Colors.debuff.none
		element.border:SetBackdropBorderColor(color[1], color[2], color[3])
	end
end

-- Update targeting highlight outline
local TargetHighlight_Update = function(self, event, unit, ...)
	if (unit and unit ~= self.unit) then return end

	local element = self.TargetHighlight
	unit = unit or self.unit

	if (UnitIsUnit(unit, "target")) then
		element:SetVertexColor(unpack(element.colorTarget))
		element:Show()
	elseif (UnitIsUnit(unit, "focus")) then
		element:SetVertexColor(unpack(element.colorFocus))
		element:Show()
	else
		element:Hide()
	end
end

local UnitFrame_PostUpdate = function(self)
	TargetHighlight_Update(self)
	AuraHighlight_Update(self)
	UpdatePartyHealthTextVisibility(self)
end

local UnitFrame_OnEvent = function(self, event, unit, ...)
	UnitFrame_PostUpdate(self)
end

local style = function(self, unit)

	local db = ns.GetConfig("PartyFrames")

	-- Apply common scripts and member values.
	ns.UnitFrame.InitializeUnitFrame(self)
	ns.UnitFrames[self] = true -- add to global registry
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
	health:SetFrameLevel(health:GetFrameLevel() + 2)
	health:SetPoint(unpack(db.HealthBarPosition))
	health:SetSize(unpack(db.HealthBarSize))
	health:SetStatusBarTexture(db.HealthBarTexture)
	health:SetOrientation(db.HealthBarOrientation)
	health:SetSparkMap(db.HealthBarSparkMap)
	health.predictThreshold = .01
	health.colorDisconnected = true
	health.colorClass = true
	health.colorClassPet = true
	health.colorReaction = true
	health.colorHealth = true

	self.Health = health
	self.Health.Override = ns.API.UpdateHealth
	self.Health.PostUpdate = Health_PostUpdate
	self.Health.PostUpdateColor = Health_PostUpdateColor
	self:HookScript("OnEnter", function(frame)
		UpdateMouseoverHealthColor(frame, PartyFrameMod.db and PartyFrameMod.db.profile or defaults.profile, true)
	end)
	self:HookScript("OnLeave", function(frame)
		UpdateMouseoverHealthColor(frame, PartyFrameMod.db and PartyFrameMod.db.profile or defaults.profile, false)
	end)

	local healthOverlay = CreateFrame("Frame", nil, health)
	healthOverlay:SetFrameLevel(overlay:GetFrameLevel())
	healthOverlay:SetAllPoints()

	self.Health.Overlay = healthOverlay

	local healthBackdrop = health:CreateTexture(nil, "BACKGROUND", nil, -1)
	healthBackdrop:SetPoint(unpack(db.HealthBackdropPosition))
	healthBackdrop:SetSize(unpack(db.HealthBackdropSize))
	healthBackdrop:SetTexture(db.HealthBackdropTexture)
	healthBackdrop:SetVertexColor(unpack(db.HealthBackdropColor))

	self.Health.Backdrop = healthBackdrop

	local healthPreview = self:CreateBar(nil, health)
	healthPreview:SetAllPoints(health)
	healthPreview:SetFrameLevel(health:GetFrameLevel() - 1)
	healthPreview:SetStatusBarTexture(db.HealthBarTexture)
	healthPreview:SetOrientation(db.HealthBarOrientation)
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
	-- self.HealthPrediction.PostUpdate = HealPredict_PostUpdate -- Temporary rollback: broken white prediction overlay covers party-style health bars.
	self.HealthPrediction:SetAlpha(0)
	self.HealthPrediction:Hide()

	-- Cast Overlay
	--------------------------------------------
	local castbar = self:CreateBar()
	castbar:SetAllPoints(health)
	castbar:SetFrameLevel(self:GetFrameLevel() + 5)
	castbar:SetSparkMap(db.HealthBarSparkMap)
	castbar:SetStatusBarTexture(db.HealthBarTexture)
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
	self:Tag(healthValue, prefix("[*:HealthCurrent(false,false,false,true)]"))

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
	healthPerc:Hide()  -- Hidden by default

	self.Health.Percent = healthPerc

	-- Power
	--------------------------------------------
	local power = self:CreateBar()
	power:SetFrameLevel(health:GetFrameLevel() + 2)
	power:SetPoint(unpack(db.PowerBarPosition))
	power:SetSize(unpack(db.PowerBarSize))
	power:SetStatusBarTexture(db.PowerBarTexture)
	power:SetOrientation(db.PowerBarOrientation)
	power.frequentUpdates = true
	power.colorPower = true

	self.Power = power
	self.Power.Override = ns.API.UpdatePower
	self.Power.PostUpdate = Power_PostUpdate

	local powerBackdrop = power:CreateTexture(nil, "BACKGROUND", nil, -2)
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

	self.Portrait = portrait
	self.Portrait.PostUpdate = Portrait_PostUpdate

	local portraitBg = portraitFrame:CreateTexture(nil, "BACKGROUND", nil, 0)
	portraitBg:SetPoint(unpack(db.PortraitBackgroundPosition))
	portraitBg:SetSize(unpack(db.PortraitBackgroundSize))
	portraitBg:SetTexture(db.PortraitBackgroundTexture)
	portraitBg:SetVertexColor(unpack(db.PortraitBackgroundColor))

	self.Portrait.Bg = portraitBg

	local portraitOverlayFrame = CreateFrame("Frame", nil, self)
	portraitOverlayFrame:SetFrameLevel(self:GetFrameLevel() - 1)
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

	-- Priority Debuff
	--------------------------------------------
	local priorityDebuff = CreateFrame("Frame", nil, overlay)
	priorityDebuff:SetSize(40,40)
	priorityDebuff:SetPoint("CENTER", self.Health, "CENTER", 0, 0)
	priorityDebuff.forceShow = nil

	local priorityDebuffIcon = priorityDebuff:CreateTexture(nil, "BACKGROUND", nil, 1)
	priorityDebuffIcon:SetPoint("CENTER")
	priorityDebuffIcon:SetSize(priorityDebuff:GetSize())
	priorityDebuffIcon:SetMask(GetMedia("actionbutton-mask-square"))
	priorityDebuff.icon = priorityDebuffIcon

	local priorityDebuffBorder = CreateFrame("Frame", nil, priorityDebuff, ns.BackdropTemplate)
	priorityDebuffBorder:SetBackdrop({ edgeFile = GetMedia("border-aura"), edgeSize = 12 })
	priorityDebuffBorder:SetBackdropBorderColor(Colors.verydarkgray[1], Colors.verydarkgray[2], Colors.verydarkgray[3])
	priorityDebuffBorder:SetPoint("TOPLEFT", -4, 4)
	priorityDebuffBorder:SetPoint("BOTTOMRIGHT", 4, -4)
	priorityDebuffBorder:SetFrameLevel(priorityDebuff:GetFrameLevel() + 2)
	priorityDebuff.border = priorityDebuffBorder

	local priorityDebuffCount = priorityDebuff.border:CreateFontString(nil, "OVERLAY")
	priorityDebuffCount:SetFontObject(GetFont(14, true))
	priorityDebuffCount:SetTextColor(Colors.offwhite[1], Colors.offwhite[2], Colors.offwhite[3])
	priorityDebuffCount:SetPoint("BOTTOMRIGHT", priorityDebuff, "BOTTOMRIGHT", -2, 3)
	priorityDebuff.count = priorityDebuffCount

	self.PriorityDebuff = priorityDebuff
	self.PriorityDebuff.PostUpdate = PriorityDebuff_PostUpdate

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

		local orientation
		if (db.HealthBarOrientation == "UP") then
			orientation = "DOWN"
		elseif (db.HealthBarOrientation == "DOWN") then
			orientation = "UP"
		elseif (db.HealthBarOrientation == "LEFT") then
			orientation = "RIGHT"
		else
			orientation = "LEFT"
		end
		absorb:SetOrientation(orientation)

		-- self.HealthPrediction.absorbBar = absorb -- Temporary rollback: broken absorb overlay covers party-style health bars.
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

	-- Ressurection Indicator
	--------------------------------------------
	local resurrectIndicator = overlay:CreateTexture(nil, "OVERLAY", nil, 1)
	resurrectIndicator:SetSize(unpack(db.ResurrectIndicatorSize))
	resurrectIndicator:SetPoint(unpack(db.ResurrectIndicatorPosition))
	resurrectIndicator:SetTexture(db.ResurrectIndicatorTexture)

	self.ResurrectIndicator = resurrectIndicator

	-- Group Role
	-----------------------------------------
    local groupRoleIndicator = CreateFrame("Frame", nil, overlay)
	groupRoleIndicator:SetSize(unpack(db.GroupRoleSize))
	groupRoleIndicator:SetPoint(unpack(db.GroupRolePosition))
	groupRoleIndicator.DAMAGER = db.GroupRoleDPSTexture
	groupRoleIndicator.HEALER = db.GroupRoleHealerTexture
	groupRoleIndicator.TANK = db.GroupRoleTankTexture
	--groupRoleIndicator.NONE = groupRoleIndicator.DAMAGER -- fallback

	local groupRoleBackdrop = groupRoleIndicator:CreateTexture(nil, "BACKGROUND", nil, 1)
	groupRoleBackdrop:SetSize(unpack(db.GroupRoleBackdropSize))
	groupRoleBackdrop:SetPoint(unpack(db.GroupRoleBackdropPosition))
	groupRoleBackdrop:SetTexture(db.GroupRoleBackdropTexture)
	groupRoleBackdrop:SetVertexColor(unpack(db.GroupRoleBackdropColor))

	groupRoleIndicator.Backdrop = groupRoleBackdrop

	local groupRoleIcon = groupRoleIndicator:CreateTexture(nil, "ARTWORK", nil, 1)
	groupRoleIcon:SetSize(unpack(db.GroupRoleIconSize))
	groupRoleIcon:SetPoint(unpack(db.GroupRoleIconPositon))

	groupRoleIndicator.Icon = groupRoleIcon

    self.GroupRoleIndicator = groupRoleIndicator
	self.GroupRoleIndicator.Override = GroupRoleIndicator_Override

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
	local targetHighlight = healthOverlay:CreateTexture(nil, "BACKGROUND", nil, -2)
	targetHighlight:SetPoint(unpack(db.TargetHighlightPosition))
	targetHighlight:SetSize(unpack(db.TargetHighlightSize))
	targetHighlight:SetTexture(db.TargetHighlightTexture)
	targetHighlight.colorTarget = db.TargetHighlightTargetColor
	targetHighlight.colorFocus = db.TargetHighlightFocusColor

	self.TargetHighlight = targetHighlight

	local auraHighlight = healthOverlay:CreateTexture(nil, "BACKGROUND", nil, -3)
	auraHighlight:SetPoint(unpack(db.TargetHighlightPosition))
	auraHighlight:SetSize(unpack(db.TargetHighlightSize))
	auraHighlight:SetTexture(db.TargetHighlightTexture)
	auraHighlight:Hide()

	self.AuraHighlight = auraHighlight

	-- Auras
	--------------------------------------------
	local auras = CreateFrame("Frame", nil, self)
	auras:SetPoint(unpack(db.AurasPosition))
	auras.disableMouse = db.AurasDisableMouse
	auras.disableCooldown = db.AurasDisableCooldown
	auras.onlyShowPlayer = db.AurasOnlyShowPlayer
	auras.showStealableBuffs = db.AurasShowStealableBuffs
	auras.tooltipAnchor = db.AurasTooltipAnchor
	auras.sortMethod = db.AurasSortMethod
	auras.sortDirection = db.AurasSortDirection
	auras.reanchorIfVisibleChanged = true
	auras.CreateButton = ns.AuraStyles.CreateButton
	auras.PostUpdateButton = ns.AuraStyles.PartyPostUpdateButton
	auras.CustomFilter = ns.AuraFilters.PartyAuraFilter -- classic
	auras.FilterAura = ns.AuraFilters.PartyAuraFilter -- retail

	if (ns:GetModule("UnitFrames").db.global.disableAuraSorting) then
		auras.PreSetPosition = ns.AuraSorts.Alternate -- only in classic
		auras.SortAuras = ns.AuraSorts.AlternateFuncton -- only in retail
	else
		auras.PreSetPosition = ns.AuraSorts.Default -- only in classic
		auras.SortAuras = ns.AuraSorts.DefaultFunction -- only in retail
	end

	self.Auras = auras
	ApplyPartyAuraLayout(self)

	-- Textures need an update when frame is displayed.
	self.PostUpdate = UnitFrame_PostUpdate

	-- Register events to handle additional texture updates.
	self:RegisterEvent("PLAYER_ENTERING_WORLD", UnitFrame_OnEvent, true)
	self:RegisterEvent("PLAYER_TARGET_CHANGED", UnitFrame_OnEvent, true)
	self:RegisterEvent("UNIT_AURA", UnitFrame_OnEvent)
	self:RegisterEvent("UNIT_CONNECTION", UnitFrame_OnEvent)
	self:RegisterEvent("PLAYER_FLAGS_CHANGED", UnitFrame_OnEvent)

	-- Fix unresponsive alpha on 3D Portrait.
	hooksecurefunc(UIParent, "SetAlpha", function() self.Portrait:SetAlpha(self:GetEffectiveAlpha()) end)
	hooksecurefunc(self, "SetAlpha", function() self.Portrait:SetAlpha(self:GetEffectiveAlpha()) end)

end

-- GroupHeader Template
---------------------------------------------------
local GroupHeader = {}

GroupHeader.ForAll = function(self, methodOrFunc, ...)
	for _, frame in ipairs(getOrderedHeaderChildren(self)) do
		if (type(methodOrFunc) == "string") then
			frame[methodOrFunc](frame, ...)
		else
			methodOrFunc(frame, ...)
		end
	end
end

GroupHeader.Enable = function(self)
	if (InCombatLockdown()) then return end

	self:UpdateVisibilityDriver()
	self.enabled = true
end

GroupHeader.Disable = function(self)
	if (InCombatLockdown()) then return end

	self:UpdateVisibilityDriver()
	self.enabled = false
end

GroupHeader.IsEnabled = function(self)
	return self.enabled
end

GroupHeader.UpdateVisibilityDriver = function(self)
	if (InCombatLockdown()) then return end

	local driver = {}

	local profile = PartyFrameMod.db and PartyFrameMod.db.profile or defaults.profile
	local db = profile or defaults.profile
	if (db.enabled) then
		if (TESTMODE) then
			table_insert(driver, "show")
		end
		table_insert(driver, "[group:party,nogroup:raid]"..(db.useInParties and "show" or "hide"))
		table_insert(driver, "[@raid26,exists]"..(db.useInRaid40 and "show" or "hide"))
		table_insert(driver, "[@raid11,exists]"..(db.useInRaid25 and "show" or "hide"))
		table_insert(driver, "[@raid6,exists]"..(db.useInRaid10 and "show" or "hide"))
		table_insert(driver, "[group:raid]"..(db.useInRaid5 and "show" or "hide"))
	end

	table_insert(driver, "hide")

	self.visibility = table_concat(driver, ";")

	UnregisterAttributeDriver(self, "state-visibility")
	RegisterAttributeDriver(self, "state-visibility", self.visibility)

	-- Ensure grouping attributes are valid before any other SetAttribute calls,
	-- as SecureGroupHeader_Update can run on each call.
	self:SetAttribute("groupBy", PARTY_GROUP_BY)
	self:SetAttribute("groupingOrder", PARTY_GROUPING_ORDER)
	self:SetAttribute("showRaid", db.useInRaid5 or db.useInRaid10 or db.useInRaid25 or db.useInRaid40)
	self:SetAttribute("showParty", db.useInParties)
	if (TESTMODE) then
		self:SetAttribute("showPlayer", true)
	else
		self:SetAttribute("showPlayer", db.showPlayer)
	end

end

PartyFrameMod.GetHeaderAttributes = function(self)
	local db = GetSanitizedHeaderProfile(self.db and self.db.profile or defaults.profile)

	return ns.Prefix.."Party", nil,
	"initial-width", ns.GetConfig("PartyFrames").UnitSize[1],
	"initial-height", ns.GetConfig("PartyFrames").UnitSize[2],
	"oUF-initialConfigFunction", [[
		local header = self:GetParent();
		self:SetWidth(header:GetAttribute("initial-width"));
		self:SetHeight(header:GetAttribute("initial-height"));
		self:SetFrameLevel(self:GetFrameLevel() + 10);
	]],

	--'https://wowprogramming.com/docs/secure_template/Group_Headers.html
	"sortMethod", "INDEX", -- INDEX, NAME -- Member sorting within each group
	"sortDir", "ASC", -- ASC, DESC
	"groupFilter", GetActiveGroupFilter(), -- Local subgroup in raids, full party filter otherwise
	"showSolo", TESTMODE or false, -- show while non-grouped
	"point", db.point, -- Unit anchoring within each column
	"xOffset", db.xOffset,
	"yOffset", db.yOffset,
	"groupBy", PARTY_GROUP_BY, -- fixed to stable group ordering
	"groupingOrder", PARTY_GROUPING_ORDER,
	"unitsPerColumn", db.unitsPerColumn, -- Column setup and growth
	"maxColumns", db.maxColumns,
	"columnSpacing", db.columnSpacing,
	"columnAnchorPoint", db.columnAnchorPoint

end

PartyFrameMod.GetHeaderSize = function(self)
	local profile = self.db and self.db.profile or defaults.profile
	local db = profile or defaults.profile
	local defaultUnits = ((TESTMODE or db.showPlayer) and 5 or 4)
	return self:GetCalculatedHeaderSize(defaultUnits)
end

PartyFrameMod.GetCalculatedHeaderSize = function(self, numDisplayed)
	local config = ns.GetConfig("PartyFrames")
	local db = GetSanitizedHeaderProfile(self.db and self.db.profile or defaults.profile)
	local unitButtonWidth = config.UnitSize[1]
	local unitButtonHeight = config.UnitSize[2]
	local unitsPerColumn = db.unitsPerColumn or 5
	local point = db.point or "LEFT"
	local _, xOffsetMult, yOffsetMult = getRelativePointAnchor(point)
	local xMultiplier, yMultiplier = math_abs(xOffsetMult), math_abs(yOffsetMult)
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

	local columnAnchorPoint, _, colxMulti, colyMulti
	if (numColumns > 1) then
		columnAnchorPoint = db.columnAnchorPoint
		_, colxMulti, colyMulti = getRelativePointAnchor(columnAnchorPoint)
	end

	local width, height
	if (numDisplayed > 0) then
		width = xMultiplier * (unitsPerColumn - 1) * unitButtonWidth + ((unitsPerColumn - 1) * (xOffset * xOffsetMult)) + unitButtonWidth
		height = yMultiplier * (unitsPerColumn - 1) * unitButtonHeight + ((unitsPerColumn - 1) * (yOffset * yOffsetMult)) + unitButtonHeight

		if (numColumns > 1) then
			width = width + ((numColumns - 1) * math_abs(colxMulti) * (width + columnSpacing))
			height = height + ((numColumns - 1) * math_abs(colyMulti) * (height + columnSpacing))
		end
	else
		local minWidth = db.minWidth or unitButtonWidth
		local minHeight = db.minHeight or unitButtonHeight
		width = math_max(minWidth, 0.1)
		height = math_max(minHeight, 0.1)
	end

	return width, height
end

PartyFrameMod.ConfigureChildren = function(self)
	if (InCombatLockdown()) then return end

	local header = self:GetUnitFrameOrHeader()
	if (not header) then return end

	local db = GetSanitizedHeaderProfile(self.db and self.db.profile or defaults.profile)
	local config = ns.GetConfig("PartyFrames")
	local unitWidth = config.UnitSize[1]
	local unitHeight = config.UnitSize[2]
	local buttons = getOrderedHeaderChildren(header)
	local numDisplayed = #buttons

	if (numDisplayed == 0) then
		header:SetSize(self:GetHeaderSize())
		return
	end

	local point = db.point or "LEFT"
	local relativePoint, xOffsetMult, yOffsetMult = getRelativePointAnchor(point)
	local xMultiplier, yMultiplier = math_abs(xOffsetMult), math_abs(yOffsetMult)
	local xOffset = db.xOffset or 0
	local yOffset = db.yOffset or 0
	local sortDir = db.sortDir or "ASC"
	local columnSpacing = db.columnSpacing or 0
	local unitsPerColumn = db.unitsPerColumn or numDisplayed
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

	if (sortDir == "DESC") then
		local reversed = {}
		for i = #buttons, 1, -1 do
			table_insert(reversed, buttons[i])
		end
		buttons = reversed
	end

	local buttonNum = 0
	local columnUnitCount = 0
	local currentAnchor = header
	for _, unitButton in ipairs(buttons) do
		buttonNum = buttonNum + 1
		columnUnitCount = columnUnitCount + 1
		if (columnUnitCount > unitsPerColumn) then
			columnUnitCount = 1
		end

		unitButton:SetSize(unitWidth, unitHeight)
		unitButton:ClearAllPoints()
		if (buttonNum == 1) then
			unitButton:SetPoint(point, currentAnchor, point, 0, 0)
			if (columnAnchorPoint) then
				unitButton:SetPoint(columnAnchorPoint, currentAnchor, columnAnchorPoint, 0, 0)
			end
		elseif (columnUnitCount == 1 and columnAnchorPoint) then
			local columnAnchor = buttons[buttonNum - unitsPerColumn]
			unitButton:SetPoint(columnAnchorPoint, columnAnchor, columnRelPoint, colxMulti * columnSpacing, colyMulti * columnSpacing)
		else
			unitButton:SetPoint(point, currentAnchor, relativePoint, xMultiplier * xOffset, yMultiplier * yOffset)
		end
		currentAnchor = unitButton
	end

	header:SetSize(self:GetCalculatedHeaderSize(numDisplayed))
end

PartyFrameMod.UpdateHeader = function(self)
	local header = self:GetUnitFrameOrHeader()
	if (not header) then return end
	local db = GetSanitizedHeaderProfile(self.db and self.db.profile or defaults.profile)
	local config = ns.GetConfig("PartyFrames")

	if (InCombatLockdown()) then
		self.needHeaderUpdate = true
		self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnEvent")
		return
	end

	header:UpdateVisibilityDriver()
	-- Set secure grouping attributes first, as any SetAttribute call can trigger SecureGroupHeader_Update.
	header:SetAttribute("initial-width", config.UnitSize[1])
	header:SetAttribute("initial-height", config.UnitSize[2])
	header:SetAttribute("groupBy", PARTY_GROUP_BY)
	header:SetAttribute("groupingOrder", PARTY_GROUPING_ORDER)
	header:SetAttribute("groupFilter", GetActiveGroupFilter())
	header:SetAttribute("point", db.point)
	header:SetAttribute("xOffset", db.xOffset)
	header:SetAttribute("yOffset", db.yOffset)
	header:SetAttribute("unitsPerColumn", db.unitsPerColumn)
	header:SetAttribute("maxColumns", db.maxColumns)
	header:SetAttribute("columnSpacing", db.columnSpacing)
	header:SetAttribute("columnAnchorPoint", db.columnAnchorPoint)

	self:GetFrame():SetSize(self:GetHeaderSize())
	self:ConfigureChildren()

	self:UpdateAnchor() -- the general update does this too, but we need it in case nothing but this function has been called.
end

PartyFrameMod.UpdateUnits = function(self)
	if (not self.frame) then return end
	for frame in next,Units do
		ApplyHealthColorMode(frame, self.db.profile)
		ApplyPartyAuraLayout(frame)
		if (self.db.profile.showAuras) then
			frame:EnableElement("Auras")
			frame.Auras:ForceUpdate()
		else
			frame:DisableElement("Auras")
		end
		frame:UpdateAllElements("RefreshUnit")
		AuraHighlight_Update(frame)
	end
end

PartyFrameMod.Update = function(self)
	self:UpdateHeader()
	self:UpdateUnits()
end

PartyFrameMod.OnEvent = function(self, event, ...)
	if (event ~= "PLAYER_REGEN_ENABLED") then
		return
	end
	if (InCombatLockdown()) then
		return
	end
	self:UnregisterEvent("PLAYER_REGEN_ENABLED", "OnEvent")
	if (self.needHeaderUpdate) then
		self.needHeaderUpdate = nil
		self:UpdateHeader()
	end
end

PartyFrameMod.UpdateAnchorAndMouseForLock = function(self)
	if (InCombatLockdown()) then return end

	local manager = ns:GetModule("MovableFramesManager", true)
	local lockOpen = manager and manager:IsMFMFrameOpen()

	if (lockOpen and self.anchor and self.anchor:IsEnabled() and (not self.anchor:IsShown())) then
		self.anchor:Show()
	end
end

PartyFrameMod.DisableBlizzard = function(self)
	local profile = self.db and self.db.profile or defaults.profile
	if (not (profile and profile.enabled)) then
		return
	end

	-- WoW 12.0.0: Don't call oUF:DisableBlizzard - it checks for CompactPartyFrameMember which loads the buggy addon
	-- Note: ns.ClientBuild is the build number (~58135), NOT the TOC version.
	-- ns.ClientVersion is the interface/TOC number (120000+ for WoW 12).
	if (ns.ClientVersion and ns.ClientVersion >= 120000) then
		if (UIParent and UIParent.UnregisterEvent) then
			UIParent:UnregisterEvent("GROUP_ROSTER_UPDATE")
		end
		local quarantine = ns.WoW12BlizzardQuarantine
		if (quarantine and quarantine.ApplyCompactFrames) then
			quarantine.ApplyCompactFrames()
		else
			if (_G.CompactRaidFrameManager_SetSetting) then
				_G.CompactRaidFrameManager_SetSetting("IsShown", "0")
			end
			if (_G.PartyFrame and _G.PartyFrame.UnregisterAllEvents) then
				_G.PartyFrame:UnregisterAllEvents()
			end
			if (_G.PartyFrame and _G.PartyFrame.Hide) then
				_G.PartyFrame:Hide()
			end
			if (_G.PartyFrame and _G.PartyFrame.SetParent) then
				_G.PartyFrame:SetParent(ns.Hider)
			end
		end

		return
	end
	
	oUF:DisableBlizzard("party")
end

PartyFrameMod.CreateUnitFrames = function(self)

	local name = "Party"

	oUF:RegisterStyle(ns.Prefix..name, style)
	oUF:SetActiveStyle(ns.Prefix..name)

	self.frame = oUF:SpawnHeader(self:GetHeaderAttributes())
	self.frame:SetSize(self:GetHeaderSize())

	-- Embed our custom methods
	for method,func in next,GroupHeader do
		self.frame[method] = func
	end

	for _, frame in ipairs({ self.frame:GetChildren() }) do
		ApplyHealthColorMode(frame, self.db and self.db.profile or defaults.profile)
	end

	-- Sometimes some elements are wrong or "get stuck" upon exiting the editmode.
	if (ns.WoW10) then
		if (not self.__hookedExitEditMode) then
			self.__hookedExitEditMode = true
			self:SecureHook(EditModeManagerFrame, "ExitEditMode", "UpdateUnits")
		end
	end

	-- Sometimes when changing group leader, only the group leader is updated,
	-- leaving other units with a lot of wrong information displayed.
	-- Should think that GROUP_ROSTER_UPDATE handled this, but it doesn't.
	-- *Only experienced this is Wrath.But adding it as a general update anyway.
	self:RegisterEvent("PARTY_LEADER_CHANGED", "UpdateUnits")
	self:RegisterEvent("GROUP_ROSTER_UPDATE", "Update")

	-- Sometimes offline coloring remains when a member comes back online. Why?
	-- Not sure if this is something we should force update as the health element
	-- is already registered for this event. Leaving this comment here while I decide.
end

PartyFrameMod.OnEnable = function(self)

	self:DisableBlizzard()
	self:CreateUnitFrames()
	self:CreateAnchor(PARTY)

	if (not self.__hookedMFMPartyAnchorSync) then
		local manager = ns:GetModule("MovableFramesManager", true)
		if (manager) then
			self.__hookedMFMPartyAnchorSync = true
			self:SecureHook(manager, "UpdateMovableFrameAnchors", "UpdateAnchorAndMouseForLock")
			self:SecureHook(manager, "HideMovableFrameAnchors", "UpdateAnchorAndMouseForLock")
		end
	end

	ns.MovableModulePrototype.OnEnable(self)
	self:UpdateAnchorAndMouseForLock()
end



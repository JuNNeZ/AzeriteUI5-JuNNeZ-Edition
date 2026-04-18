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

local RaidFrame25Mod = ns:NewModule("RaidFrame25", ns.UnitFrameModule, "LibMoreEvents-1.0", "AceHook-3.0")

-- GLOBALS: UIParent, Enum
-- GLOBALS: LoadAddOn, InCombatLockdown, RegisterAttributeDriver, UnregisterAttributeDriver
-- GLOBALS: GetRaidRosterInfo, UnitGroupRolesAssigned, UnitHasVehicleUI, UnitInRaid, UnitIsUnit, UnitPowerType
-- GLOBALS: CompactRaidFrameContainer, CompactRaidFrameManager, CompactRaidFrameManager_SetSetting

-- Lua API
local math_abs = math.abs
local math_ceil = math.ceil
local math_max = math.max
local math_min = math.min
local ipairs = ipairs
local next = next
local pairs = pairs
local select = select
local string_gsub = string.gsub
local string_match = string.match
local string_upper = string.upper
local table_concat = table.concat
local table_insert = table.insert
local table_remove = table.remove
local table_sort = table.sort
local type = type
local unpack = unpack

-- Addon API
local Colors = ns.Colors
local GetMedia = ns.API.GetMedia
local GetFont = ns.API.GetFont

local Units = {}

local defaults = { profile = ns:Merge({

	enabled = true,

	useInParties = false, -- show in non-raid parties
	useInRaid5 = false, -- show in raid groups of 1-5 players
	useInRaid10 = true, -- show in raid groups of 6-10 players
	useInRaid25 = true, -- show in raid groups of 11-25 players
	useInRaid40 = false, -- show in raid groups of 26-40 players

	useRangeIndicator = true,
	showPriorityDebuff = true,
	priorityDebuffScale = 100,
	useClassColors = true,
	useBlizzardHealthColors = false,
	useClassColorOnMouseoverOnly = false,

	point = "TOP", -- anchor point of unitframe, group members within column grow opposite
	xOffset = 0, -- horizontal offset within the same column
	yOffset = -12, -- vertical offset within the same column

	groupBy = "ROLE", -- GROUP, CLASS, ROLE
	groupingOrder = "TANK,HEALER,DAMAGER", -- must match choice in groupBy

	unitsPerColumn = 5, -- maximum units per column
	maxColumns = 5, -- should be 25/unitsPerColumn
	columnSpacing = 10, -- spacing between columns
	columnAnchorPoint = "LEFT" -- anchor point of column, columns grow opposite

}, ns.MovableModulePrototype.defaults) }

RaidFrame25Mod.GenerateDefaults = function(self)
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

local validGroupBy = {
	GROUP = true,
	CLASS = true,
	ROLE = true,
	ASSIGNEDROLE = true
}

local GetActiveRaidGroupFilter = function()
	local quarantine = ns.WoW12BlizzardQuarantine
	if (quarantine and quarantine.GetRaidGroupFilter) then
		return quarantine.GetRaidGroupFilter()
	end
	return "1,2,3,4,5,6,7,8"
end

local GetRequiredRaidCapacity = function(db, fallback)
	local source = db or defaults.profile
	fallback = fallback or defaults.profile
	local useInRaid40 = (source.useInRaid40 ~= nil) and source.useInRaid40 or fallback.useInRaid40
	local useInRaid25 = (source.useInRaid25 ~= nil) and source.useInRaid25 or fallback.useInRaid25
	local useInRaid10 = (source.useInRaid10 ~= nil) and source.useInRaid10 or fallback.useInRaid10
	local useInRaid5 = (source.useInRaid5 ~= nil) and source.useInRaid5 or fallback.useInRaid5
	if (useInRaid40 or useInRaid25 or useInRaid10 or useInRaid5) then
		return 40
	end
	return 5
end

local GetSanitizedHeaderProfile = function(profile)
	local db = profile or defaults.profile
	local fallback = defaults.profile
	local unitsPerColumn = (type(db.unitsPerColumn) == "number" and db.unitsPerColumn > 0 and db.unitsPerColumn) or fallback.unitsPerColumn or 5
	local maxColumns = (type(db.maxColumns) == "number" and db.maxColumns > 0 and db.maxColumns) or fallback.maxColumns or 1
	local requiredColumns = math_max(1, math_ceil(GetRequiredRaidCapacity(db, fallback) / unitsPerColumn))
	if (maxColumns < requiredColumns) then
		maxColumns = requiredColumns
	end

	return {
		point = (type(db.point) == "string" and validHeaderPoints[db.point] and db.point) or fallback.point or "TOP",
		xOffset = (type(db.xOffset) == "number" and db.xOffset) or fallback.xOffset or 0,
		yOffset = (type(db.yOffset) == "number" and db.yOffset) or fallback.yOffset or 0,
		groupBy = (type(db.groupBy) == "string" and validGroupBy[db.groupBy] and db.groupBy) or fallback.groupBy or "GROUP",
		groupingOrder = (type(db.groupingOrder) == "string" and db.groupingOrder ~= "" and db.groupingOrder) or fallback.groupingOrder or "1,2,3,4,5,6,7,8",
		unitsPerColumn = unitsPerColumn,
		maxColumns = maxColumns,
		columnSpacing = (type(db.columnSpacing) == "number" and db.columnSpacing) or fallback.columnSpacing or 0,
		columnAnchorPoint = (type(db.columnAnchorPoint) == "string" and validHeaderPoints[db.columnAnchorPoint] and db.columnAnchorPoint) or fallback.columnAnchorPoint or "LEFT"
	}
end

local GetPriorityDebuffSettings = function(profile)
	local db = profile or defaults.profile
	local fallback = defaults.profile
	local scalePercent = (type(db.priorityDebuffScale) == "number" and db.priorityDebuffScale) or fallback.priorityDebuffScale or 100
	if (scalePercent < 25) then
		scalePercent = 25
	elseif (scalePercent > 100) then
		scalePercent = 100
	end

	return {
		enabled = db.showPriorityDebuff ~= false,
		scale = scalePercent / 100
	}
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
	if (not frame) then
		return
	end

	local health = frame.Health
	local useClassColors = not (profile and profile.useClassColors == false)
	local onlyOnMouseover = useClassColors and profile and profile.useClassColorOnMouseoverOnly
	local showClassColors = useClassColors and ((not onlyOnMouseover) or frame.__AzeriteUI_HealthColorMouseOver)
	local useBlizzardColors = useClassColors and profile and profile.useBlizzardHealthColors

	frame.colors = CreateHealthColors(useBlizzardColors)
	if (health) then
		health.colorClass = showClassColors and true or false
		health.colorClassPet = showClassColors and true or false
		health.colorReaction = showClassColors and true or false
		health.colorHealth = true
		if (health.ForceUpdate) then
			health:ForceUpdate()
		end
	end
end

local UpdateMouseoverHealthColor = function(frame, profile, isMouseOver)
	frame.__AzeriteUI_HealthColorMouseOver = isMouseOver and true or false
	ApplyHealthColorMode(frame, profile)
end

local ApplyPriorityDebuffLayout = function(frame, profile)
	if (not frame or not frame.PriorityDebuff) then
		return
	end

	local settings = GetPriorityDebuffSettings(profile)
	local priorityDebuff = frame.PriorityDebuff
	local size = math_max(1, math.floor((40 * settings.scale) + .5))
	local borderInset = math_max(1, math.floor((4 * settings.scale) + .5))
	local borderEdgeSize = math_max(4, math.floor((12 * settings.scale) + .5))
	local fontSize = math_max(8, math.floor((14 * settings.scale) + .5))
	local countOffsetX = -math_max(1, math.floor((2 * settings.scale) + .5))
	local countOffsetY = math_max(1, math.floor((3 * settings.scale) + .5))

	priorityDebuff:SetSize(size, size)

	if (priorityDebuff.icon) then
		priorityDebuff.icon:SetSize(size, size)
	end

	if (priorityDebuff.border) then
		priorityDebuff.border:SetBackdrop({ edgeFile = GetMedia("border-aura"), edgeSize = borderEdgeSize })
		priorityDebuff.border:ClearAllPoints()
		priorityDebuff.border:SetPoint("TOPLEFT", priorityDebuff, "TOPLEFT", -borderInset, borderInset)
		priorityDebuff.border:SetPoint("BOTTOMRIGHT", priorityDebuff, "BOTTOMRIGHT", borderInset, -borderInset)
	end

	if (priorityDebuff.count) then
		priorityDebuff.count:SetFontObject(GetFont(fontSize, true))
		priorityDebuff.count:ClearAllPoints()
		priorityDebuff.count:SetPoint("BOTTOMRIGHT", priorityDebuff, "BOTTOMRIGHT", countOffsetX, countOffsetY)
	end

	if (settings.enabled) then
		if (priorityDebuff.spellID and priorityDebuff.ForceUpdate) then
			priorityDebuff:ForceUpdate()
		end
	else
		priorityDebuff:Hide()
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

local HasHeaderChildUnit = function(child)
	if (not child) then
		return false
	end
	local unit = child.GetAttribute and child:GetAttribute("unit")
	if ((not unit) and not child.GetAttribute) then
		unit = child.unit
	end
	return (type(unit) == "string" and unit ~= "")
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
			if (not seen[child] and HasHeaderChildUnit(child)) then
				seen[child] = true
				table_insert(children, child)
			end
			index = index + 1
		end
	end

	if (#children == 0) then
		for i = 1, header:GetNumChildren() do
			local child = select(i, header:GetChildren())
			if (not seen[child] and HasHeaderChildUnit(child)) then
				seen[child] = true
				table_insert(children, child)
			end
		end
	end

	for i = #children, 1, -1 do
		local child = children[i]
		if (not (child and child.ClearAllPoints and child.SetPoint and HasHeaderChildUnit(child))) then
			table_remove(children, i)
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

local GetButtonRaidSubgroup = function(button)
	if (not button) then
		return nil
	end

	local unit = button.GetAttribute and button:GetAttribute("unit")
	if ((not unit) and not button.GetAttribute) then
		unit = button.unit
	end
	if (type(unit) ~= "string") then
		return nil
	end

	local raidIndex = UnitInRaid and UnitInRaid(unit)
	if (raidIndex and GetRaidRosterInfo) then
		local _, _, subgroup = GetRaidRosterInfo(raidIndex)
		if (type(subgroup) == "number" and subgroup >= 1 and subgroup <= 8) then
			return subgroup
		end
	end

	raidIndex = tonumber(string_match(unit, "^raid(%d+)$"))
	if (raidIndex and raidIndex >= 1 and raidIndex <= 40) then
		return math_ceil(raidIndex / 5)
	end
end

local ConfigureSparseRaidGroups = function(self, header, buttons, db, unitWidth, unitHeight)
	if ((db.point or "TOP") ~= "TOP" or (db.columnAnchorPoint or "LEFT") ~= "LEFT") then
		return false
	end

	local columnSpacing = db.columnSpacing or 0
	local yOffset = db.yOffset or 0
	local rowStep = math_max(1, unitHeight - yOffset)
	local columnStep = math_max(1, unitWidth + columnSpacing)
	local groupSlots = {}
	local maxSubgroup = 1

	for _, unitButton in ipairs(buttons) do
		local subgroup = GetButtonRaidSubgroup(unitButton)
		if (not subgroup) then
			return false
		end
		groupSlots[subgroup] = (groupSlots[subgroup] or 0) + 1
		maxSubgroup = math_max(maxSubgroup, subgroup)

		unitButton:SetSize(unitWidth, unitHeight)
		unitButton:ClearAllPoints()
		unitButton:SetPoint("TOPLEFT", header, "TOPLEFT", (subgroup - 1) * columnStep, -((groupSlots[subgroup] - 1) * rowStep))
	end

	header:SetSize(self:GetCalculatedHeaderSize(maxSubgroup * (db.unitsPerColumn or 5)))
	return true
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

local LeaderIndicator_PostUpdate = function(element, isLeader, isInLFGInstance)

	local name = element.__owner.Name
	local ml = element.__owner.MasterLooterIndicator
	local leader = element.__owner.LeaderIndicator

	-- Move raidtarget to far most left
	local rt = element.__owner.RaidTargetIndicator
	rt:ClearAllPoints()
	rt:SetPoint("RIGHT", isLeader and leader or ml:IsShown() and ml or name, "LEFT")

end

local MasterLooterIndicator_PostUpdate = function(element, isShown)

	local name = element.__owner.Name
	local leader = element.__owner.LeaderIndicator
	local rt = element.__owner.RaidTargetIndicator

	-- Move leader when masterlooter is shown
	leader:ClearAllPoints()
	leader:SetPoint("RIGHT", isShown and element or name, "LEFT")

	-- Move raidtarget to far most left
	rt:ClearAllPoints()
	rt:SetPoint("RIGHT", leader:IsShown() and leader or isShown and element or name, "LEFT")

end

local RaidTargetIndicator_PostUpdate = function(element, index)
	-- nothing actually needed
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

-- Update the border color of priority debuffs.
local PriorityDebuff_PostUpdate = function(element, event, isVisible, name, icon, count, debuffType, duration, expirationTime, spellID, isBoss, isCustom)
	local settings = GetPriorityDebuffSettings(RaidFrame25Mod.db and RaidFrame25Mod.db.profile or defaults.profile)
	if (not settings.enabled) then
		element:Hide()
		return
	end
	if (isVisible) then
		local color = debuffType and Colors.debuff[debuffType] or Colors.debuff.none
		element.border:SetBackdropBorderColor(color[1], color[2], color[3])
	end
end

local UnitFrame_PostUpdate = function(self)
	TargetHighlight_Update(self)
end

local UnitFrame_OnEvent = function(self, event, unit, ...)
	UnitFrame_PostUpdate(self)
end

local style = function(self, unit)

	local db = ns.GetConfig("RaidFrames")

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
		UpdateMouseoverHealthColor(frame, RaidFrame25Mod.db and RaidFrame25Mod.db.profile or defaults.profile, true)
	end)
	self:HookScript("OnLeave", function(frame)
		UpdateMouseoverHealthColor(frame, RaidFrame25Mod.db and RaidFrame25Mod.db.profile or defaults.profile, false)
	end)

	local healthOverlay = CreateFrame("Frame", nil, health)
	healthOverlay:SetFrameLevel(overlay:GetFrameLevel() - 1)
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
	-- self.HealthPrediction.PostUpdate = HealPredict_PostUpdate -- Temporary rollback: broken white prediction overlay covers raid health bars.
	self.HealthPrediction:SetAlpha(0)
	self.HealthPrediction:Hide()

	-- Cast Overlay
	--------------------------------------------
	--local castbar = self:CreateBar()
	--castbar:SetAllPoints(health)
	--castbar:SetFrameLevel(self:GetFrameLevel() + 5)
	--castbar:SetSparkMap(db.HealthBarSparkMap)
	--castbar:SetStatusBarTexture(db.HealthBarTexture)
	--castbar:SetStatusBarColor(unpack(db.HealthCastOverlayColor))
	--castbar:DisableSmoothing(true)

	--self.Castbar = castbar

	-- Health Value
	--------------------------------------------
	--local healthValue = healthOverlay:CreateFontString(nil, "OVERLAY", nil, 1)
	--healthValue:SetPoint(unpack(db.HealthValuePosition))
	--healthValue:SetFontObject(db.HealthValueFont)
	--healthValue:SetTextColor(unpack(db.HealthValueColor))
	--healthValue:SetJustifyH(db.HealthValueJustifyH)
	--healthValue:SetJustifyV(db.HealthValueJustifyV)
	--self:Tag(healthValue, prefix("[*:Health(true,false,false,true)]"))

	--self.Health.Value = healthValue

	-- Player Status
	--------------------------------------------
	local status = healthOverlay:CreateFontString(nil, "OVERLAY", nil, 1)
	status:SetPoint(unpack(db.StatusPosition))
	status:SetFontObject(db.StatusFont)
	status:SetTextColor(unpack(db.StatusColor))
	status:SetJustifyH(db.StatusJustifyH)
	status:SetJustifyV(db.StatusJustifyV)
	self:Tag(status, prefix("[*:DeadOrOffline]"))

	self.Health.Status = status

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
	ApplyPriorityDebuffLayout(self, RaidFrame25Mod.db and RaidFrame25Mod.db.profile or defaults.profile)

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

		-- self.HealthPrediction.absorbBar = absorb -- Temporary rollback: broken absorb overlay covers raid health bars.
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
	local resurrectIndicator = overlay:CreateTexture(nil, "OVERLAY", nil, 6)
	resurrectIndicator:SetSize(unpack(db.ResurrectIndicatorSize))
	resurrectIndicator:SetPoint(unpack(db.ResurrectIndicatorPosition))
	resurrectIndicator:SetTexture(db.ResurrectIndicatorTexture)

	self.ResurrectIndicator = resurrectIndicator

	-- Group Role
	-----------------------------------------
    local groupRoleIndicator = CreateFrame("Frame", nil, healthOverlay)
	groupRoleIndicator:SetSize(unpack(db.GroupRoleSize))
	groupRoleIndicator:SetPoint(unpack(db.GroupRolePosition))
	groupRoleIndicator.HEALER = db.GroupRoleHealerTexture
	groupRoleIndicator.TANK = db.GroupRoleTankTexture

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

	-- Group Number
	--------------------------------------------
	local groupNumber = overlay:CreateFontString(nil, "OVERLAY")
	groupNumber:SetPoint(unpack(db.GroupNumberPlace))
	groupNumber:SetDrawLayer(unpack(db.GroupNumberDrawLayer))
	groupNumber:SetJustifyH(db.GroupNumberJustifyH)
	groupNumber:SetJustifyV(db.GroupNumberJustifyV)
	groupNumber:SetFontObject(db.GroupNumberFont)
	groupNumber:SetTextColor(unpack(db.GroupNumberColor))

	self.GroupNumber = groupNumber

	-- CombatFeedback Text
	--------------------------------------------
	--local feedbackText = overlay:CreateFontString(nil, "OVERLAY")
	--feedbackText:SetPoint(db.CombatFeedbackPosition[1], self[db.CombatFeedbackAnchorElement], unpack(db.CombatFeedbackPosition))
	--feedbackText:SetFontObject(db.CombatFeedbackFont)
	--feedbackText.feedbackFont = db.CombatFeedbackFont
	--feedbackText.feedbackFontLarge = db.CombatFeedbackFontLarge
	--feedbackText.feedbackFontSmall = db.CombatFeedbackFontSmall

	--self.CombatFeedback = feedbackText

	-- Target Highlight
	--------------------------------------------
	local targetHighlight = healthOverlay:CreateTexture(nil, "BACKGROUND", nil, -2)
	targetHighlight:SetPoint(unpack(db.TargetHighlightPosition))
	targetHighlight:SetSize(unpack(db.TargetHighlightSize))
	targetHighlight:SetTexture(db.TargetHighlightTexture)
	targetHighlight.colorTarget = db.TargetHighlightTargetColor
	targetHighlight.colorFocus = db.TargetHighlightFocusColor

	self.TargetHighlight = targetHighlight

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

	-- Leader Indicator
	--------------------------------------------
	local leaderIndicator = overlay:CreateTexture(nil, "OVERLAY", nil, 2)
	leaderIndicator:SetSize(16, 16)
	leaderIndicator:SetPoint("RIGHT", self.Name, "LEFT")

	self.LeaderIndicator = leaderIndicator
	self.LeaderIndicator.PostUpdate = LeaderIndicator_PostUpdate

	-- MasterLooter Indicator
	--------------------------------------------
	local masterLooterIndicator = overlay:CreateTexture(nil, "OVERLAY", nil, 2)
	masterLooterIndicator:SetSize(16, 16)
	masterLooterIndicator:SetPoint("RIGHT", self.Name, "LEFT")

	self.MasterLooterIndicator = masterLooterIndicator
	self.MasterLooterIndicator.PostUpdate = MasterLooterIndicator_PostUpdate

	-- RaidTarget Indicator
	--------------------------------------------
	local raidTargetIndicator = overlay:CreateTexture(nil, "OVERLAY", nil, 2)
	raidTargetIndicator:SetSize(24, 24)
	raidTargetIndicator:SetPoint("RIGHT", self.Name, "LEFT")
	raidTargetIndicator:SetTexture(db.RaidTargetTexture)

	self.RaidTargetIndicator = raidTargetIndicator
	self.RaidTargetIndicator.PostUpdate = RaidTargetIndicator_PostUpdate

	-- Range Opacity
	-----------------------------------------------------------
	self.Range = { outsideAlpha = .6 }

	-- Textures need an update when frame is displayed.
	self.PostUpdate = UnitFrame_PostUpdate

	-- Register events to handle additional texture updates.
	self:RegisterEvent("PLAYER_ENTERING_WORLD", UnitFrame_OnEvent, true)
	self:RegisterEvent("PLAYER_TARGET_CHANGED", UnitFrame_OnEvent, true)

end

-- GroupHeader Template
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

	local profile = RaidFrame25Mod.db and RaidFrame25Mod.db.profile or defaults.profile
	local db = profile or defaults.profile
	local headerProfile = GetSanitizedHeaderProfile(profile)
	if (db.enabled) then
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

	-- Restore secure layout state before any visibility writes can trigger SecureGroupHeader_Update.
	self:SetAttribute("groupBy", headerProfile.groupBy)
	self:SetAttribute("groupingOrder", headerProfile.groupingOrder)
	self:SetAttribute("groupFilter", GetActiveRaidGroupFilter())
	self:SetAttribute("point", headerProfile.point)
	self:SetAttribute("xOffset", headerProfile.xOffset)
	self:SetAttribute("yOffset", headerProfile.yOffset)
	self:SetAttribute("unitsPerColumn", headerProfile.unitsPerColumn)
	self:SetAttribute("maxColumns", headerProfile.maxColumns)
	self:SetAttribute("columnSpacing", headerProfile.columnSpacing)
	self:SetAttribute("columnAnchorPoint", headerProfile.columnAnchorPoint)
	self:SetAttribute("showRaid", db.useInRaid5 or db.useInRaid10 or db.useInRaid25 or db.useInRaid40)
	self:SetAttribute("showParty", db.useInParties)
	self:SetAttribute("showPlayer", true)

end

RaidFrame25Mod.DisableBlizzard = function(self)
	-- WoW 12.0.0: Don't touch CompactRaidFrameManager at all - even checking if it exists loads the buggy addon
	-- Note: ns.ClientBuild is build number (~58135), ns.ClientVersion is TOC version (120000).
	if (ns.ClientVersion and ns.ClientVersion >= 120000) then
		if (UIParent and UIParent.UnregisterEvent) then
			UIParent:UnregisterEvent("GROUP_ROSTER_UPDATE")
		end
		local quarantine = ns.WoW12BlizzardQuarantine
		if (quarantine and quarantine.ApplyCompactFrames) then
			quarantine.ApplyCompactFrames()
		end
		return
	end
	
	UIParent:UnregisterEvent("GROUP_ROSTER_UPDATE")
	-- Old WoW: Disable Blizzard raid frames
	if CompactRaidFrameManager_SetSetting then
		CompactRaidFrameManager_SetSetting("IsShown", "0")
	end
	if CompactRaidFrameContainer then
		CompactRaidFrameContainer:UnregisterAllEvents()
	end
	if CompactRaidFrameManager then
		CompactRaidFrameManager:UnregisterAllEvents()
		CompactRaidFrameManager:SetParent(ns.Hider)
	end
end

RaidFrame25Mod.OnEvent = function(self, event, ...)
	if (event == "PLAYER_ENTERING_WORLD") then
		if (InCombatLockdown()) then
			self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnEvent")
			return
		end
		self:UpdateHeader()
		self:UpdateUnits()
	elseif (event == "PLAYER_REGEN_ENABLED") then
		if (InCombatLockdown()) then return end
		self:UnregisterEvent("PLAYER_REGEN_ENABLED", "OnEvent")
		if (self.needHeaderUpdate) then
			self.needHeaderUpdate = nil
			self:UpdateHeader()
		end
	end
end

RaidFrame25Mod.GetHeaderAttributes = function(self)
	local db = GetSanitizedHeaderProfile(self.db and self.db.profile or defaults.profile)

	return ns.Prefix.."Raid25", nil, nil,
	"initial-width", ns.GetConfig("RaidFrames").UnitSize[1],
	"initial-height", ns.GetConfig("RaidFrames").UnitSize[2],
	"oUF-initialConfigFunction", [[
		local header = self:GetParent();
		self:SetWidth(header:GetAttribute("initial-width"));
		self:SetHeight(header:GetAttribute("initial-height"));
		self:SetFrameLevel(self:GetFrameLevel() + 10);
	]],

	--'https://wowprogramming.com/docs/secure_template/Group_Headers.html
	"sortMethod", "INDEX", -- INDEX, NAME -- Member sorting within each group
	"sortDir", "ASC", -- ASC, DESC
	"groupFilter", GetActiveRaidGroupFilter(), -- Group filter
	"showSolo", false, -- show while non-grouped
	"point", db.point, -- Unit anchoring within each column
	"xOffset", db.xOffset,
	"yOffset", db.yOffset,
	"groupBy", "GROUP", -- db.groupBy, -- ROLE, CLASS, GROUP -- Grouping order and type
	"groupingOrder", "1,2,3,4,5,6,7,8", -- db.groupingOrder,
	"unitsPerColumn", db.unitsPerColumn, -- Column setup and growth
	"maxColumns", db.maxColumns,
	"columnSpacing", db.columnSpacing,
	"columnAnchorPoint", db.columnAnchorPoint

end

RaidFrame25Mod.GetHeaderSize = function(self)
	local profile = self.db and self.db.profile or defaults.profile
	return self:GetCalculatedHeaderSize(GetRequiredRaidCapacity(profile, defaults.profile))
end

RaidFrame25Mod.GetCalculatedHeaderSize = function(self, numDisplayed)
	local config = ns.GetConfig("RaidFrames")
	local db = GetSanitizedHeaderProfile(self.db and self.db.profile or defaults.profile)
	local unitButtonWidth = config.UnitSize[1]
	local unitButtonHeight = config.UnitSize[2]
	local unitsPerColumn = db.unitsPerColumn or 5
	local point = db.point or "TOP"
	local _, xOffsetMult, yOffsetMult = getRelativePointAnchor(point)
	local xMultiplier, yMultiplier = math_abs(xOffsetMult), math_abs(yOffsetMult)
	local xOffset = db.xOffset or 0
	local yOffset = db.yOffset or 0
	local columnSpacing = db.columnSpacing or 0
	local maxColumns = (type(db.maxColumns) == "number" and db.maxColumns > 0 and db.maxColumns) or defaults.profile.maxColumns or 5

	local numColumns
	if (unitsPerColumn and numDisplayed > unitsPerColumn) then
		numColumns = math_min(math_ceil(numDisplayed/unitsPerColumn), maxColumns)
	else
		unitsPerColumn = numDisplayed
		numColumns = 1
	end

	local _, colxMulti, colyMulti
	if (numColumns > 1) then
		_, colxMulti, colyMulti = getRelativePointAnchor(db.columnAnchorPoint)
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
		width = math_max(config.UnitSize[1]*5 + math_abs(db.columnSpacing * 4), 0.1)
		height = math_max(config.UnitSize[2]*5 + math_abs(db.yOffset * 4), 0.1)
	end

	return width, height
end

RaidFrame25Mod.ConfigureChildren = function(self)
	if (InCombatLockdown()) then return end

	local header = self:GetUnitFrameOrHeader()
	if (not header) then return end

	local db = GetSanitizedHeaderProfile(self.db and self.db.profile or defaults.profile)
	local config = ns.GetConfig("RaidFrames")
	local unitWidth = config.UnitSize[1]
	local unitHeight = config.UnitSize[2]
	local buttons = getOrderedHeaderChildren(header)
	local numDisplayed = #buttons

	if (numDisplayed == 0) then
		header:SetSize(self:GetHeaderSize())
		return
	end

	local point = db.point or "TOP"
	local relativePoint, xOffsetMult, yOffsetMult = getRelativePointAnchor(point)
	local xMultiplier, yMultiplier = math_abs(xOffsetMult), math_abs(yOffsetMult)
	local xOffset = db.xOffset or 0
	local yOffset = db.yOffset or 0
	local sortDir = db.sortDir or "ASC"
	local columnSpacing = db.columnSpacing or 0
	local unitsPerColumn = db.unitsPerColumn or numDisplayed
	local maxColumns = (type(db.maxColumns) == "number" and db.maxColumns > 0 and db.maxColumns) or defaults.profile.maxColumns or 5
	local numColumns
	if (unitsPerColumn and numDisplayed > unitsPerColumn) then
		numColumns = math_min(math_ceil(numDisplayed/unitsPerColumn), maxColumns)
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

	if (ConfigureSparseRaidGroups(self, header, buttons, db, unitWidth, unitHeight)) then
		return
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

RaidFrame25Mod.UpdateHeader = function(self)
	local header = self:GetUnitFrameOrHeader()
	if (not header) then return end
	local db = GetSanitizedHeaderProfile(self.db and self.db.profile or defaults.profile)
	local config = ns.GetConfig("RaidFrames")

	if (InCombatLockdown()) then
		self.needHeaderUpdate = true
		self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnEvent")
		return
	end

	header:UpdateVisibilityDriver()
	-- Set secure layout attributes from validated saved values only.
	header:SetAttribute("initial-width", config.UnitSize[1])
	header:SetAttribute("initial-height", config.UnitSize[2])
	header:SetAttribute("groupBy", db.groupBy)
	header:SetAttribute("groupingOrder", db.groupingOrder)
	header:SetAttribute("groupFilter", GetActiveRaidGroupFilter())
	header:SetAttribute("point", db.point)
	header:SetAttribute("xOffset", db.xOffset)
	header:SetAttribute("yOffset", db.yOffset)
	header:SetAttribute("unitsPerColumn", db.unitsPerColumn)
	header:SetAttribute("maxColumns", db.maxColumns)
	header:SetAttribute("columnSpacing", db.columnSpacing)
	header:SetAttribute("columnAnchorPoint", db.columnAnchorPoint)

	self:GetFrame():SetSize(self:GetHeaderSize())
	self:ConfigureChildren()

	self:UpdateHeaderAnchorPoint() -- update where the group header is anchored to our anchorframe.
	self:UpdateAnchor() -- the general update does this too, but we need it in case nothing but this function has been called.
end

RaidFrame25Mod.UpdateHeaderAnchorPoint = function(self)
	local db = GetSanitizedHeaderProfile(self.db and self.db.profile or defaults.profile)
	local point = "TOPLEFT"
	if (db.columnAnchorPoint == "LEFT") then
		if (db.point == "TOP") then
			point = "TOPLEFT"
		elseif (db.point == "BOTTOM") then
			point = "BOTTOMLEFT"
		end
	elseif (db.columnAnchorPoint == "RIGHT") then
		if (db.point == "TOP") then
			point = "TOPRIGHT"
		elseif (db.point == "BOTTOM") then
			point = "BOTTOMRIGHT"
		end
	elseif (db.columnAnchorPoint == "TOP") then
		if (db.point == "LEFT") then
			point = "TOPLEFT"
		elseif (db.point == "RIGHT") then
			point = "TOPRIGHT"
		end
	elseif (db.columnAnchorPoint == "BOTTOM") then
		if (db.point == "LEFT") then
			point = "BOTTOMLEFT"
		elseif (db.point == "RIGHT") then
			point = "BOTTOMRIGHT"
		end
	end
	local header = self:GetUnitFrameOrHeader()
	header:ClearAllPoints()
	header:SetPoint(point, self:GetFrame(), point)
end

RaidFrame25Mod.UpdateUnits = function(self)
	if (not self:GetFrame()) then return end
	for frame in next,Units do
		ApplyHealthColorMode(frame, self.db.profile)
		ApplyPriorityDebuffLayout(frame, self.db.profile)
		if (self.db.profile.useRangeIndicator) then
			frame:EnableElement("Range")
		else
			frame:DisableElement("Range")
			frame:SetAlpha(1)
		end
		frame:UpdateAllElements("RefreshUnit")
	end
end

RaidFrame25Mod.Update = function(self)
	self:UpdateHeader()
	self:UpdateUnits()
end

RaidFrame25Mod.CreateUnitFrames = function(self)

	local name = "Raid25"

	oUF:RegisterStyle(ns.Prefix..name, style)
	oUF:SetActiveStyle(ns.Prefix..name)

	self.frame = CreateFrame("Frame", nil, UIParent)
	self.frame:SetSize(self:GetHeaderSize())

	self.frame.content = oUF:SpawnHeader(self:GetHeaderAttributes())
	self:UpdateHeaderAnchorPoint()

	-- Embed our custom methods
	for method,func in next,GroupHeader do
		self.frame.content[method] = func
	end

	for _, frame in ipairs({ self.frame.content:GetChildren() }) do
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

end

RaidFrame25Mod.OnEnable = function(self)
	-- Don't load Blizzard_CUFProfiles or Blizzard_CompactRaidFrames in WoW 12.0.0
	-- They have buggy secret value handling that causes errors
	-- LoadAddOn("Blizzard_CUFProfiles")
	-- LoadAddOn("Blizzard_CompactRaidFrames")

	-- Leave these enabled for now.
	self:DisableBlizzard()
	self:CreateUnitFrames()
	self:CreateAnchor(RAID .. " (25)") --[[PARTYRAID_LABEL RAID_AND_PARTY]]

	ns.MovableModulePrototype.OnEnable(self)
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEvent")
end


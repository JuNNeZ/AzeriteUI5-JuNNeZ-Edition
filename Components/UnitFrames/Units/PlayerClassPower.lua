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

local ClassPowerMod = ns:NewModule("PlayerClassPowerFrame", ns.UnitFrameModule, "LibMoreEvents-1.0")

-- Lua API
local math_floor = math.floor
local math_abs = math.abs
local next = next
local type = type
local unpack = unpack

-- Addon API
local IsAddOnEnabled = ns.API.IsAddOnEnabled
local noop = ns.Noop

-- Constants
local playerClass = ns.PlayerClass
local SPEC_SHAMAN_ELEMENTAL = _G.SPEC_SHAMAN_ELEMENTAL or 1
local POWER_TYPE_MANA = (Enum and Enum.PowerType and Enum.PowerType.Mana) or 0
local POWER_TYPE_MAELSTROM = (Enum and Enum.PowerType and Enum.PowerType.Maelstrom) or 11

local defaults = { profile = ns:Merge({
	showComboPoints = true,
	showArcaneCharges = ns.IsRetail or nil,
	showChi = ns.IsRetail or nil,
	showHolyPower = ns.IsRetail or nil,
	showMaelstrom = ns.IsRetail or nil,
	showSoulFragments = ns.IsRetail or nil,
	soulFragmentsDisplayMode = "gradient",
	showRunes = ns.IsCata or ns.IsRetail or nil,
	showSoulShards = ns.IsRetail or nil,
	showStagger = ns.IsRetail or nil,
	elementalMaelstromDisplayMode = "crystal_spec",
	elementalSwapBarAnchorMigrated = false,
	defaultAnchorHotfixMigrated = false,
	clickThrough = true
}, ns.MovableModulePrototype.defaults) }

local GetElementalMaelstromDisplayMode = function(db)
	if (not db) then
		return "crystal_spec"
	end
	local mode = db.elementalMaelstromDisplayMode
	if (mode == "crystal_mana" or mode == "classpower") then
		return "crystal_mana"
	end
	return "crystal_spec"
end

local ShouldUseElementalSwapBar = function(db)
	if (not ns.IsRetail or playerClass ~= "SHAMAN") then
		return false
	end
	local currentSpec = (GetSpecialization and GetSpecialization()) or nil
	if (currentSpec == nil) then
		return false
	end
	if (currentSpec ~= SPEC_SHAMAN_ELEMENTAL) then
		return false
	end
	return true
end

local GetElementalSwapBarPowerType = function(db)
	local mode = GetElementalMaelstromDisplayMode(db)
	if (mode == "crystal_mana") then
		return POWER_TYPE_MAELSTROM
	end
	return POWER_TYPE_MANA
end

local ShouldMigratePreviousClassPowerDefault = function(profile)
	if (not profile or playerClass == "SHAMAN") then
		return false
	end
	if (profile.defaultAnchorHotfixMigrated) then
		return false
	end
	local pos = profile.savedPosition
	if (type(pos) ~= "table" or pos[1] ~= "BOTTOMLEFT") then
		return false
	end
	local scale = (type(pos.scale) == "number" and pos.scale > 0) and pos.scale or ns.API.GetEffectiveScale()
	local expectedX = -223 * scale
	local expectedY = -84 * scale
	return type(pos[2]) == "number"
		and type(pos[3]) == "number"
		and math_abs(pos[2] - expectedX) < .01
		and math_abs(pos[3] - expectedY) < .01
end

local ShouldShowElementalSwapBarValue = function()
	local playerFrameMod = ns:GetModule("PlayerFrame", true)
	local profile = playerFrameMod and playerFrameMod.db and playerFrameMod.db.profile
	return (not profile) or (profile.showPowerValue ~= false)
end

local ParseElementalDisplayNumber = function(text)
	if (type(text) ~= "string") then
		return nil
	end
	local ok, parsed = pcall(function()
		text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("%s+", "")
		if (text == "") then
			return nil
		end
		local multiplier = 1
		local suffix = text:sub(-1):lower()
		if (suffix == "k") then
			multiplier = 1000
			text = text:sub(1, -2)
		elseif (suffix == "m") then
			multiplier = 1000000
			text = text:sub(1, -2)
		elseif (suffix == "b") then
			multiplier = 1000000000
			text = text:sub(1, -2)
		elseif (suffix == "t") then
			multiplier = 1000000000000
			text = text:sub(1, -2)
		end
		text = text:gsub(",", "")
		local numeric = tonumber(text)
		if (type(numeric) ~= "number") then
			return nil
		end
		return numeric * multiplier
	end)
	if (ok and type(parsed) == "number") then
		return parsed
	end
	return nil
end

local GetElementalRawPowerPercent = function(unit, displayType)
	local percent = nil
	pcall(function()
		if (UnitPowerPercent) then
			if (CurveConstants and CurveConstants.ScaleTo100) then
				percent = UnitPowerPercent(unit, displayType, true, CurveConstants.ScaleTo100)
			else
				percent = UnitPowerPercent(unit, displayType)
			end
		end
	end)
	return percent
end

local GetElementalFormattedPowerValue = function(unit, displayType, useFull)
	local rawCur = UnitPower(unit, displayType)
	local formatter = useFull and BreakUpLargeNumbers or AbbreviateNumbers
	if (type(formatter) == "function") then
		local ok, formatted = pcall(formatter, rawCur)
		if (ok and formatted ~= nil) then
			local text = tostring(formatted)
			local parsed = ParseElementalDisplayNumber(text)
			if (type(parsed) == "number") then
				return text, parsed
			end
			if (type(rawCur) == "number" and (not issecretvalue or not issecretvalue(rawCur))) then
				return text, rawCur
			end
			return text, nil
		end
	end
	return nil, nil
end

local FormatElementalSwapBarShortValue = function(value)
	if (type(value) ~= "number") then
		return nil
	end
	local rounded = math_floor(value + .5)
	if (type(AbbreviateNumbers) == "function") then
		local ok, formatted = pcall(AbbreviateNumbers, rounded)
		if (ok and formatted ~= nil) then
			return tostring(formatted)
		end
	end
	return tostring(rounded)
end

local ElementalSwapBar_PostUpdate = function(element, unit)
	if (not element) then
		return
	end
	local db = ClassPowerMod and ClassPowerMod.db and ClassPowerMod.db.profile
	if (not ShouldUseElementalSwapBar(db)) then
		element.__AzeriteUI_KeepValueVisible = false
		if (element.Value) then
			element.Value:SetText("")
			element.Value:Hide()
		end
		return element:Hide()
	end

	local powerType = element.displayType
	if (type(powerType) ~= "number") then
		powerType = GetElementalSwapBarPowerType(db)
	end

	local _, token = UnitPowerType(unit or "player", powerType)
	if (type(token) ~= "string" or token == "") then
		token = (powerType == POWER_TYPE_MAELSTROM) and "MAELSTROM" or "MANA"
	end

	local playerFrameConfig = ns.GetConfig("PlayerFrame")
	local colors = playerFrameConfig and playerFrameConfig.PowerOrbColors
	local color = colors and colors[token]
	if (type(color) ~= "table") then
		color = colors and colors.MANA
	end
	if (type(color) == "table") then
		element:SetStatusBarColor(color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1)
	end

	if (element.Value) then
		local showValue = ShouldShowElementalSwapBarValue()
		element.__AzeriteUI_KeepValueVisible = showValue
		if (showValue) then
			element.Value:Show()
		else
			element.Value:Hide()
		end
		local value = element.safeCur or element.cur
		local formatMode = "short"
		local playerFrameMod = ns:GetModule("PlayerFrame", true)
		local playerProfile = playerFrameMod and playerFrameMod.db and playerFrameMod.db.profile
		if (playerProfile and type(playerProfile.PowerValueFormat) == "string") then
			formatMode = playerProfile.PowerValueFormat
		end
		local rawShortText = select(1, GetElementalFormattedPowerValue(unit or "player", powerType, false))
		local rawFullText, rawFullValue = GetElementalFormattedPowerValue(unit or "player", powerType, true)
		local rawPercent = GetElementalRawPowerPercent(unit or "player", powerType)
		local safeRawPercent = (type(rawPercent) == "number" and (not issecretvalue or not issecretvalue(rawPercent))) and rawPercent or nil
		local safeRawValue = (type(rawFullValue) == "number" and (not issecretvalue or not issecretvalue(rawFullValue))) and rawFullValue or nil
		element.__AzeriteUI_DisplayPercent = safeRawPercent
		element.__AzeriteUI_DisplayCur = safeRawValue

		local usedRaw = false
		if (showValue) then
			if (formatMode == "percent") then
				if (rawPercent ~= nil and element.Value.SetFormattedText) then
					usedRaw = pcall(element.Value.SetFormattedText, element.Value, "%d%%", rawPercent)
				end
			elseif (formatMode == "full") then
				if (rawFullText ~= nil and element.Value.SetFormattedText) then
					usedRaw = pcall(element.Value.SetFormattedText, element.Value, "%s", rawFullText)
				end
			elseif (formatMode == "shortpercent") then
				if (rawShortText ~= nil and rawPercent ~= nil and element.Value.SetFormattedText) then
					usedRaw = pcall(element.Value.SetFormattedText, element.Value, "%s |cff888888(|r%d%%|cff888888)|r", rawShortText, rawPercent)
				elseif (rawShortText ~= nil and element.Value.SetFormattedText) then
					usedRaw = pcall(element.Value.SetFormattedText, element.Value, "%s", rawShortText)
				elseif (rawPercent ~= nil and element.Value.SetFormattedText) then
					usedRaw = pcall(element.Value.SetFormattedText, element.Value, "%d%%", rawPercent)
				end
			else
				if (rawShortText ~= nil and element.Value.SetFormattedText) then
					usedRaw = pcall(element.Value.SetFormattedText, element.Value, "%s", rawShortText)
				end
			end
		end
		if (usedRaw) then
			if (element.Value.SetAlpha) then
				element.Value:SetAlpha(1)
			end
			if (type(safeRawPercent) == "number") then
				element.safePercent = safeRawPercent
			end
			if (type(safeRawValue) == "number") then
				element.safeCur = safeRawValue
			end
		elseif (type(value) == "number" and (not issecretvalue or not issecretvalue(value))) then
			local valueText
			if (formatMode == "percent") then
				local percent = element.safePercent
				if (type(percent) == "number") then
					valueText = string.format("%d%%", math_floor(percent + .5))
				end
			elseif (formatMode == "full") then
				local max = element.safeMax or element.max
				local valueFull = (type(BreakUpLargeNumbers) == "function") and BreakUpLargeNumbers(math_floor(value + .5)) or tostring(math_floor(value + .5))
				if (type(max) == "number") then
					local maxFull = (type(BreakUpLargeNumbers) == "function") and BreakUpLargeNumbers(math_floor(max + .5)) or tostring(math_floor(max + .5))
					valueText = valueFull .. " |cff888888/|r " .. maxFull
				else
					valueText = valueFull
				end
			elseif (formatMode == "shortpercent") then
				local short = FormatElementalSwapBarShortValue(value)
				local percent = element.safePercent
				if (short and type(percent) == "number") then
					valueText = short .. " |cff888888(|r" .. string.format("%d%%", math_floor(percent + .5)) .. "|cff888888)|r"
				else
					valueText = short
				end
			else
				valueText = FormatElementalSwapBarShortValue(value)
			end
			element.Value:SetText(valueText or "")
		else
			element.Value:SetText("")
		end
	end

	if (not element:IsShown()) then
		element:Show()
	end
end

local SyncClassPowerClickBlocker = function(classpower, blocker)
	if (not classpower or not blocker) then
		return
	end

	local uiScale = UIParent:GetEffectiveScale() or 1
	local blockerScale = blocker:GetEffectiveScale() or 1
	local scaleRatio = (uiScale > 0 and blockerScale > 0) and (uiScale / blockerScale) or 1
	local left, right, bottom, top = classpower:GetLeft(), classpower:GetRight(), classpower:GetBottom(), classpower:GetTop()
	local minLeft, maxRight, minBottom, maxTop

	local UpdateBounds = function(region)
		if (not region or not region.IsShown or not region:IsShown()) then
			return
		end

		local regionLeft, regionRight = region:GetLeft(), region:GetRight()
		local regionBottom, regionTop = region:GetBottom(), region:GetTop()
		if (type(regionLeft) == "number" and type(regionRight) == "number"
		and type(regionBottom) == "number" and type(regionTop) == "number") then
			minLeft = (not minLeft or regionLeft < minLeft) and regionLeft or minLeft
			maxRight = (not maxRight or regionRight > maxRight) and regionRight or maxRight
			minBottom = (not minBottom or regionBottom < minBottom) and regionBottom or minBottom
			maxTop = (not maxTop or regionTop > maxTop) and regionTop or maxTop
		end
	end

	for i = 1, #classpower do
		local point = classpower[i]
		if (point and point:IsShown()) then
			UpdateBounds(point)
			UpdateBounds(point.case)
			UpdateBounds(point.slot)
		end
	end

	blocker:ClearAllPoints()
	if (minLeft and maxRight and minBottom and maxTop) then
		blocker:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", minLeft * scaleRatio, minBottom * scaleRatio)
		blocker:SetSize((maxRight - minLeft) * scaleRatio, (maxTop - minBottom) * scaleRatio)
	else
		if (type(left) == "number" and type(right) == "number" and type(bottom) == "number" and type(top) == "number") then
			blocker:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left * scaleRatio, bottom * scaleRatio)
			blocker:SetSize((right - left) * scaleRatio, (top - bottom) * scaleRatio)
		else
			blocker:SetAllPoints(classpower)
		end
	end
	blocker:SetFrameStrata("DIALOG")
	blocker:SetFrameLevel(math.max(10, classpower:GetFrameLevel() + 100))
end

local ApplyClassPowerClickThrough = function(self)
	if (not self or not self.frame) then
		return
	end

	local classpower = self.frame.ClassPower
	if (not classpower) then
		return
	end

	if (not classpower.ClickBlocker) then
		local blocker = CreateFrame("Button", nil, UIParent)
		blocker:RegisterForClicks("AnyUp", "AnyDown")
		blocker:SetScript("OnClick", noop)
		blocker:SetScript("OnMouseDown", noop)
		blocker:SetScript("OnMouseUp", noop)
		blocker:SetToplevel(true)
		if (blocker.SetMouseClickEnabled) then
			blocker:SetMouseClickEnabled(true)
		end
		if (blocker.SetPropagateMouseClicks) then
			blocker:SetPropagateMouseClicks(false)
		end
		if (blocker.SetPropagateMouseMotion) then
			blocker:SetPropagateMouseMotion(false)
		end
		SyncClassPowerClickBlocker(classpower, blocker)
		if (not classpower.__AzeriteUI_ClickBlockerHooksSet) then
			hooksecurefunc(classpower, "SetFrameLevel", function(frame)
				SyncClassPowerClickBlocker(frame, frame.ClickBlocker)
			end)
			hooksecurefunc(classpower, "SetFrameStrata", function(frame)
				SyncClassPowerClickBlocker(frame, frame.ClickBlocker)
			end)
			hooksecurefunc(classpower, "SetPoint", function(frame)
				SyncClassPowerClickBlocker(frame, frame.ClickBlocker)
			end)
			hooksecurefunc(classpower, "SetSize", function(frame)
				SyncClassPowerClickBlocker(frame, frame.ClickBlocker)
			end)
			hooksecurefunc(classpower, "SetScale", function(frame)
				SyncClassPowerClickBlocker(frame, frame.ClickBlocker)
			end)
			hooksecurefunc(classpower, "SetParent", function(frame)
				SyncClassPowerClickBlocker(frame, frame.ClickBlocker)
			end)
			classpower:HookScript("OnSizeChanged", function(frame)
				SyncClassPowerClickBlocker(frame, frame.ClickBlocker)
			end)
			classpower:HookScript("OnHide", function(frame)
				local b = frame.ClickBlocker
				if (b) then
					b:Hide()
				end
			end)
			classpower:HookScript("OnShow", function(frame)
				local b = frame.ClickBlocker
				if (b and b.__AzeriteUI_BlockClicks) then
					b:Show()
				end
			end)
			classpower.__AzeriteUI_ClickBlockerHooksSet = true
		end
		local owner = classpower:GetParent()
		if (owner and not classpower.__AzeriteUI_ClickBlockerOwnerHooksSet) then
			local syncFromOwner = function()
				SyncClassPowerClickBlocker(classpower, classpower.ClickBlocker)
			end
			hooksecurefunc(owner, "SetPoint", syncFromOwner)
			hooksecurefunc(owner, "SetSize", syncFromOwner)
			hooksecurefunc(owner, "SetScale", syncFromOwner)
			hooksecurefunc(owner, "SetFrameLevel", syncFromOwner)
			hooksecurefunc(owner, "SetFrameStrata", syncFromOwner)
			owner:HookScript("OnSizeChanged", syncFromOwner)
			owner:HookScript("OnShow", syncFromOwner)
			classpower.__AzeriteUI_ClickBlockerOwnerHooksSet = true
		end
		classpower.ClickBlocker = blocker
	end

	local clickThrough = true
	if (self.db and self.db.profile and self.db.profile.clickThrough == false) then
		clickThrough = false
	end
	local blockClicks = not clickThrough
	local blocker = classpower.ClickBlocker
	blocker.__AzeriteUI_BlockClicks = blockClicks

	blocker:EnableMouse(blockClicks)
	if (blockClicks) then
		SyncClassPowerClickBlocker(classpower, blocker)
	end
	blocker:SetShown(blockClicks and classpower:IsShown())
end

-- Generate module defaults on the fly
-- to recalculate default values relying on
-- changing factors like user interface scale.
ClassPowerMod.GenerateDefaults = function(self)
	local x = -223 * ns.API.GetEffectiveScale()
	local y = -84 * ns.API.GetEffectiveScale()
	local point = "CENTER"
	if (ns.IsRetail and playerClass == "SHAMAN") then
		-- Default near the top-right of the player health bar; still movable through /lock.
		point = "BOTTOMLEFT"
		x = 375 * ns.API.GetEffectiveScale()
		y = 130 * ns.API.GetEffectiveScale()
	end
	defaults.profile.savedPosition = {
		scale = ns.API.GetEffectiveScale(),
		[1] = point,
		[2] = x,
		[3] = y
	}
	return defaults
end

-- Element Callbacks
--------------------------------------------
-- Create a point used for classpowers, stagger and runes.
local ClassPower_CreatePoint = function(element, index)
	local db = ns.GetConfig("PlayerClassPower")

	local point = element:GetParent():CreateBar(nil, element)
	point:SetOrientation(db.ClassPowerPointOrientation)
	point:SetSparkTexture(db.ClassPowerSparkTexture)
	point:SetMinMaxValues(0, 1)
	point:SetValue(1)
	
	-- Move the status bar texture to BACKGROUND layer so text can overlay it
	local statusBarTexture = point:GetStatusBarTexture()
	if (statusBarTexture) then
		statusBarTexture:SetDrawLayer("BACKGROUND", 1)
	end

	local case = point:CreateTexture(nil, "BACKGROUND", nil, -2)
	case:SetPoint("CENTER")
	case:SetVertexColor(unpack(db.ClassPowerCaseColor))
	case:SetDrawLayer("BACKGROUND", 0)

	point.case = case

	local slot = point:CreateTexture(nil, "BACKGROUND", nil, -1)
	slot:SetPoint("TOPLEFT", -db.ClassPowerSlotOffset, db.ClassPowerSlotOffset)
	slot:SetPoint("BOTTOMRIGHT", db.ClassPowerSlotOffset, -db.ClassPowerSlotOffset)
	slot:SetVertexColor(unpack(db.ClassPowerSlotColor))
	slot:SetDrawLayer("BACKGROUND", 0)

	point.slot = slot

	-- Store reference for styling to add labels later
	point.index = index

	return point
end

local ClassPower_PostUpdateColor = function(element, r, g, b)
	-- oUF callback for color updates (not actively used for SoulFragmentsPoints)
end

-- Update classpower layout and textures.
-- *also used for one-time setup of stagger and runes.
local ClassPower_PostUpdate = function(element, cur, max, hasMaxChanged, powerType)
	local isMaelstrom = (powerType == "MAELSTROM")
	if (isMaelstrom) then
		-- ElvUI-style secret-safe behavior:
		-- keep classpower visible and reuse last safe values when payload is unreadable.
		if (type(max) ~= "number") then
			max = element.__AzeriteUI_LastSafeMax or 10
		end
		if (type(cur) ~= "number") then
			cur = element.__AzeriteUI_LastSafeCur or 0
		end
	else
		if (type(cur) ~= "number" or type(max) ~= "number") then
			return
		end
	end

	if (type(cur) == "number") then
		element.__AzeriteUI_LastSafeCur = cur
	end
	if (type(max) == "number") then
		element.__AzeriteUI_LastSafeMax = max
	end


	-- Paladins should never display above 5 holy power points in this layout.
	if (playerClass == "PALADIN") then
		max = 5
		if cur > max then cur = max end
	end

	-- Store original soul fragments value before conversion for display logic.
	local origCur = cur

	-- Keep maelstrom visible at zero so Enhancement doesn't look disabled.
	local hideAtZero = (powerType ~= "MAELSTROM")
	if (type(cur) ~= "number" or (hideAtZero and cur <= 0)) then
		return element:Hide()
	end

	-- Soul Fragments special handling: convert normalized value (0-1 = 0-50 stacks) to 1-10 point display (every 5 stacks = 1 point)
	if (powerType == "SOUL_FRAGMENTS" and max == 1) then
		origCur = math.floor(cur * 50)  -- Store actual soul fragment count (0-50)
		cur = math.ceil(cur * 10)  -- Normalized 0-1 value maps to 0-10 points (1 point = 5 stacks)
		max = 10
	elseif (powerType == "MAELSTROM") then
		if (type(max) ~= "number" or max <= 0) then
			max = 10
		end
		-- Enhancement uses 0-10 aura stacks; Elemental can expose higher max (for example 0-100).
		-- Normalize both to the shared 10-point renderer.
		if (max > 10) then
			cur = math.ceil((cur / max) * 10)
			max = 10
		else
			if (max < 10) then
				max = 10
			end
			if (cur > 10) then
				cur = 10
			end
		end
		if (cur < 0) then
			cur = 0
		end
		origCur = cur
	end

	local style
	if (powerType == "RUNES") then
		-- Death Knight runes (always use Runes layout)
		style = "Runes"
	elseif (powerType == "SOUL_FRAGMENTS") then
		-- Devourer DH soul fragments (10-point system with numbered indicators)
		style = "SoulFragmentsPoints"
	elseif (powerType == "MAELSTROM") then
		-- Enhancement shaman maelstrom weapon stacks use the same 10-point model.
		style = "SoulFragmentsPoints"
	elseif (max >= 6) then
		-- Rogue extended combo points use a dedicated 7-point arc.
		style = (powerType == "COMBO_POINTS" and playerClass == "ROGUE") and "ComboPointsRogue" or "ComboPoints"
	elseif (max == 5) then
		style = playerClass == "MONK" and "Chi" or playerClass == "WARLOCK" and "SoulShards" or "ComboPoints"
	elseif (max == 4) then
		style = "ArcaneCharges"
	elseif (max == 3) then
		style = "Stagger"
	end

	if (not style) then
		return element:Hide()
	end

	local db = ClassPowerMod.db.profile
	local currentSpec = (ns.IsRetail and GetSpecialization and GetSpecialization()) or nil
	if (ns.IsRetail and playerClass == "SHAMAN" and powerType == "MAELSTROM" and currentSpec == SPEC_SHAMAN_ELEMENTAL) then
		-- Elemental now uses a secondary bar instead of class plates.
		if (ShouldUseElementalSwapBar(db)) then
			return element:Hide()
		end
	end

	if (ns.IsRetail) then
		if (playerClass == "MAGE" and powerType == "ARCANE_CHARGES" and not db.showArcaneCharges)
		or (playerClass == "MONK" and powerType == "CHI" and not db.showChi)
		or (playerClass == "PALADIN" and powerType == "HOLY_POWER" and not db.showHolyPower)
		or (playerClass == "SHAMAN" and powerType == "MAELSTROM" and not db.showMaelstrom)
		or (playerClass == "DEMONHUNTER" and powerType == "SOUL_FRAGMENTS" and not db.showSoulFragments)
		or (playerClass == "WARLOCK" and powerType == "SOUL_SHARDS" and not db.showSoulShards)
		or (powerType == "COMBO_POINTS" and not db.showComboPoints) then
			return element:Hide()
		end
	end
	if (not element:IsShown()) then
		element:Show()
	end

	local visiblePointCap = (style == "SoulFragmentsPoints") and 5 or max
	if (type(visiblePointCap) ~= "number") then
		visiblePointCap = 0
	end
	for i = 1, #element do
		local point = element[i]
		if (point) then
			if (i <= visiblePointCap) then
				point:Show()
			else
				point:Hide()
			end
		end
	end

	for i = 1, #element do
		local point = element[i]
		if (point:IsShown()) then
			local value = point:GetValue()
			local _, pmax = point:GetMinMaxValues()
			-- 10-point resource style used by Soul Fragments and Enhancement Maelstrom.
			if (style == "SoulFragmentsPoints") then
				local isMaelstromStyle = (powerType == "MAELSTROM")
				local displayMode = db.soulFragmentsDisplayMode or "gradient"

				-- Backward compatibility with old saved values.
				if (displayMode == "brightness") then
					displayMode = "alpha"
				elseif (displayMode == "color") then
					displayMode = "gradient"
				end

				local lightPrimary = isMaelstromStyle and {170/255, 230/255, 1} or {220/255, 180/255, 255/255}
				local darkPrimary = isMaelstromStyle and {58/255, 122/255, 1} or {100/255, 60/255, 180/255}
				local basePrimary = isMaelstromStyle and {116/255, 188/255, 1} or {156/255, 116/255, 255/255}
				local maelstromPhaseValue
				local maelstromFill
				if (isMaelstromStyle) then
					maelstromPhaseValue = (type(cur) == "number") and cur or 0
					if (maelstromPhaseValue > 5) then
						maelstromPhaseValue = maelstromPhaseValue - 5
					end
					maelstromFill = maelstromPhaseValue - (i - 1)
					if (maelstromFill < 0) then
						maelstromFill = 0
					elseif (maelstromFill > 1) then
						maelstromFill = 1
					end
				end

				if (point.case) then
					point.case:SetAlpha(1)
				end
				if (point.slot) then
					point.slot:SetAlpha(1)
				end

				if (displayMode == "alpha") then
					if (element.goldenGlow and element.goldenGlow:IsShown()) then
						element.goldenGlow:Hide()
					end

					point:SetStatusBarColor(unpack(basePrimary))
					if (isMaelstromStyle) then
						local activeAlpha = (cur <= 5) and 0.5 or 1.0
						point:SetValue(maelstromFill)
						point:SetAlpha((maelstromFill > 0) and (0.3 + ((activeAlpha - 0.3) * maelstromFill)) or 0.3)
					elseif (cur <= 5) then
						point:SetValue((i <= cur) and 1 or 0)
						point:SetAlpha((i <= cur) and 0.5 or 0.3)
					else
						point:SetValue((i <= (cur - 5)) and 1 or 0)
						point:SetAlpha((i <= (cur - 5)) and 1.0 or 0.3)
					end

				elseif (displayMode == "recolor") then
					if (element.goldenGlow and element.goldenGlow:IsShown()) then
						element.goldenGlow:Hide()
					end

					local phaseSwitch = isMaelstromStyle and 5 or 25
					local pointsPerStep = isMaelstromStyle and 1 or 5
					if (isMaelstromStyle) then
						local darkPoints = math.min(math.max(cur - 5, 0), 5)
						if (i <= math.floor(darkPoints)) then
							point:SetStatusBarColor(unpack(darkPrimary))
						else
							point:SetStatusBarColor(unpack(lightPrimary))
						end
						point:SetValue(maelstromFill)
						point:SetAlpha((maelstromFill > 0) and (0.3 + (0.7 * maelstromFill)) or 0.3)
					elseif (origCur <= phaseSwitch) then
						local activePoints = math.min(math.ceil(origCur / pointsPerStep), 5)
						point:SetStatusBarColor(unpack(lightPrimary))
						point:SetValue((i <= activePoints) and 1 or 0)
						point:SetAlpha((i <= activePoints) and 1.0 or 0.3)
					else
						local darkPoints = math.min(math.floor((origCur - phaseSwitch) / pointsPerStep), 5)
						point:SetValue(1)
						point:SetAlpha(1.0)
						if (i <= darkPoints) then
							point:SetStatusBarColor(unpack(darkPrimary))
						else
							point:SetStatusBarColor(unpack(lightPrimary))
						end
					end

				elseif (displayMode == "stacked") then
					if (element.goldenGlow and element.goldenGlow:IsShown()) then
						element.goldenGlow:Hide()
					end

					point:SetStatusBarColor(unpack(basePrimary))

					if (isMaelstromStyle) then
						if (maelstromFill > 0) then
							point:SetValue(maelstromFill)
							point:SetAlpha(0.2 + (0.8 * maelstromFill))
							if (point.case) then
								point.case:SetAlpha(0.2 + (0.8 * maelstromFill))
							end
							if (point.slot) then
								point.slot:SetAlpha(0.2 + (0.8 * maelstromFill))
							end
						else
							point:SetValue(0)
							point:SetAlpha(0.1)
							if (point.case) then
								point.case:SetAlpha(0.35)
							end
							if (point.slot) then
								point.slot:SetAlpha(0.35)
							end
						end
					elseif (cur <= 5) then
						local activePoints = math.max(0, math.min(cur, 5))
						local isActive = (i <= activePoints)
						point:SetValue(isActive and 1 or 0)
						point:SetAlpha(isActive and 1.0 or 0)
						if (point.case) then
							point.case:SetAlpha(isActive and 1.0 or 0)
						end
						if (point.slot) then
							point.slot:SetAlpha(isActive and 1.0 or 0)
						end
					else
						local overflow = math.max(0, math.min(cur - 5, 5))
						local isOverflowActive = (i <= overflow)
						if (isOverflowActive) then
							point:SetValue(1)
							point:SetAlpha(1.0)
							if (point.case) then
								point.case:SetAlpha(1.0)
							end
							if (point.slot) then
								point.slot:SetAlpha(1.0)
							end
						else
							-- Keep inactive overflow points clearly "off".
							point:SetValue(0)
							point:SetAlpha(0.1)
							if (point.case) then
								point.case:SetAlpha(0.35)
							end
							if (point.slot) then
								point.slot:SetAlpha(0.35)
							end
						end
					end

				else -- "gradient"
					local hasVoidMeta = (AuraUtil.FindAuraByName("Void Metamorphosis", "player", "HELPFUL") ~= nil)
					local atCap = isMaelstromStyle and (cur >= 10) or (origCur >= 50)

					-- Golden glow effect disabled for now
					-- if point.goldenGlow then
					--     if i <= cur then
					--         if not point.goldenGlow:IsShown() then
					--             point.goldenGlow:Show()
					--         end
					--         point.goldenGlow:SetBlendMode("ADD")
					--         if isMaelstromStyle then
					--             point.goldenGlow:SetVertexColor(90/255, 210/255, 1, 0.8)
					--         else
					--             point.goldenGlow:SetVertexColor(1, 0.84, 0, 0.8)
					--         end
					--         -- Animate alpha: grows with filled fragments
					--         local maxGlowAlpha = 0.85
					--         local minGlowAlpha = 0.1
					--         local growAlpha = minGlowAlpha + (math.min(cur, 10) * 0.075)
					--         point.goldenGlow:SetAlpha(math.min(growAlpha, maxGlowAlpha))
					--     elseif point.goldenGlow:IsShown() then
					--         point.goldenGlow:Hide()
					--     end
					-- end

					local gradientFactor = (i - 1) / 9
					local r = lightPrimary[1] * (1 - gradientFactor) + darkPrimary[1] * gradientFactor
					local g = lightPrimary[2] * (1 - gradientFactor) + darkPrimary[2] * gradientFactor
					local b = lightPrimary[3] * (1 - gradientFactor) + darkPrimary[3] * gradientFactor

					point:SetStatusBarColor(r, g, b)
					if (isMaelstromStyle) then
						point:SetValue(maelstromFill)
						point:SetAlpha((maelstromFill > 0) and (0.3 + (0.7 * maelstromFill)) or 0.3)
					elseif (cur <= 5) then
						point:SetValue((i <= cur) and 1 or 0)
						point:SetAlpha((i <= cur) and 1.0 or 0.3)
					else
						point:SetValue((i <= (cur - 5)) and 1 or 0)
						point:SetAlpha((i <= (cur - 5)) and 1.0 or 0.3)
					end
				end
			elseif (element.inCombat) then
				point:SetAlpha((cur == max) and 1 or (value < pmax) and .5 or 1)
			else
				point:SetAlpha((cur == max) and 0 or (value < pmax) and .5 or 1)
			end
		end
	end

	if (style ~= element.style) then

		local layoutdb = ns.GetConfig("PlayerClassPower").ClassPowerLayouts[style]
		if (layoutdb) then

			-- Iterate through layout explicitly by index to ensure all points are processed in order
			local maxPoints = (style == "SoulFragmentsPoints") and 5 or 10
			for i = 1, maxPoints do
				local info = layoutdb[i]
				local point = element[i]
				if (point and info) then
					local rotation = info.PointRotation or 0
					local barSize = { unpack(info.Size) }
					local backdropSize = { unpack(info.BackdropSize) }

					point:ClearAllPoints()
					point:SetPoint(unpack(info.Position))
					point:SetSize(unpack(barSize))
					point:SetStatusBarTexture(info.Texture)

					-- Apply custom orientation for soul fragments (left-to-right fill)
					if (info.Orientation) then
						point:SetOrientation(info.Orientation)
					end

					-- Apply default purple fill for soul fragments points.
					if (style == "SoulFragmentsPoints") then
						-- Note: actual color is set dynamically in PostUpdate based on displayMode setting
						-- This is just the default fallback (will be overridden)
						point:SetStatusBarColor(156/255, 116/255, 255/255) -- Default purple fill
					end

					point.case:SetSize(unpack(backdropSize))
					point.case:SetTexture(info.BackdropTexture)
					point.case:SetRotation(rotation)

					point.slot:SetTexture(info.Texture)
					point.slot:SetRotation(rotation)

					-- Keep cap enforcement even on style changes (e.g. Paladin should stay at 5).
					if (i <= visiblePointCap) then
						point:Show()
					else
						point:Hide()
					end
				end
			end

			-- Should be handled by the element,
			-- no idea why I'm adding it here.
			for i = maxPoints + 1, #element do
				element[i]:Hide()
			end
		end

		element.style = style
	end

	if (element.ClickBlocker and element.ClickBlocker.__AzeriteUI_BlockClicks) then
		SyncClassPowerClickBlocker(element, element.ClickBlocker)
	end


end

local Runes_PostUpdate = function(element, runemap, hasVehicle, allReady)
	for i = 1, #element do
		local rune = element[i]
		if (rune:IsShown()) then
			local value = rune:GetValue()
			local _, max = rune:GetMinMaxValues()
			if (element.inCombat) then
				rune:SetAlpha(allReady and 1 or (value < max) and .5 or 1)
			else
				rune:SetAlpha(allReady and 0 or (value < max) and .5 or 1)
			end
		end
	end
end

local Runes_PostUpdateColor = function(element, r, g, b, color, rune)
	if (rune) then
		rune:SetStatusBarColor(r, g, b)
	else
		if (not ns.IsCata) then
			color = element.__owner.colors.power.RUNES
			r, g, b = color[1], color[2], color[3]
		end
		for i = 1, #element do
			local rune = element[i]
			if (ns.IsCata) then
				color = element.__owner.colors.runes[rune.runeType]
				r, g, b = color[1], color[2], color[3]
			end
			rune:SetStatusBarColor(r, g, b)
		end
	end
end

local Stagger_SetStatusBarColor = function(element, r, g, b)
	for i = 1, 3 do
		local point = element[i]
		point:SetStatusBarColor(r, g, b)
	end
end

local Stagger_PostUpdate = function(element, cur, max)

	element[1].min = 0
	element[1].max = max * .3
	element[2].min = element[1].max
	element[2].max = max * .6
	element[3].min = element[2].max
	element[3].max = max

	for i = 1, 3 do
		local point = element[i]
		local value = (cur > point.max) and point.max or (cur < point.min) and point.min or cur

		point:SetMinMaxValues(point.min, point.max)
		point:SetValue(value)

		if (element.inCombat) then
			point:SetAlpha((cur == max) and 1 or (value < point.max) and .5 or 1)
		else
			point:SetAlpha((cur == 0) and 0 or (value < point.max) and .5 or 1)
		end
	end
end

-- Frame Script Handlers
--------------------------------------------
local UnitFrame_OnEvent = function(self, event, ...)
	if (event == "PLAYER_REGEN_DISABLED") then
		local runes = self.Runes
		if (runes and not runes.inCombat) then
			runes.inCombat = true
			runes:ForceUpdate()
		end
		local stagger = self.Stagger
		if (stagger and not stagger.inCombat) then
			stagger.inCombat = true
			stagger:ForceUpdate()
		end
		local classpower = self.ClassPower
		if (classpower and not classpower.inCombat) then
			classpower.inCombat = true
			classpower:ForceUpdate()
		end
		local power = self.Power
		if (power and power.ForceUpdate) then
			power:ForceUpdate()
		end
	elseif (event == "PLAYER_REGEN_ENABLED") then
		local runes = self.Runes
		if (runes and runes.inCombat) then
			runes.inCombat = false
			runes:ForceUpdate()
		end
		local stagger = self.Stagger
		if (stagger and stagger.inCombat) then
			stagger.inCombat = false
			stagger:ForceUpdate()
		end
		local classpower = self.ClassPower
		if (classpower and classpower.inCombat) then
			classpower.inCombat = false
			classpower:ForceUpdate()
		end
		local power = self.Power
		if (power and power.ForceUpdate) then
			power:ForceUpdate()
		end
	end
end

local UnitFrame_OnHide = function(self)
	self.inCombat = nil
end

local style = function(self, unit)

	local db = ns.GetConfig("PlayerClassPower")

	self:SetSize(unpack(db.ClassPowerFrameSize))

	local SCP = IsAddOnEnabled("SimpleClassPower")
	if (not SCP) then

		-- Class Power
		--------------------------------------------
		-- 	Supported class powers:
		-- 	- All     - Combo Points
		-- 	- Mage    - Arcane Charges
		-- 	- Monk    - Chi Orbs
		-- 	- Paladin - Holy Power
		-- 	- Warlock - Soul Shards
		--------------------------------------------
		local classpower = CreateFrame("Frame", nil, self)
		classpower:SetAllPoints(self)

		local maxPoints = 10 -- for fuck's sake

		for i = 1,maxPoints do
			classpower[i] = ClassPower_CreatePoint(classpower)
			-- Attach golden glow to each soul fragment point
			local point = classpower[i]
			-- Golden glow effect disabled for now
			-- local goldenGlow = point:CreateTexture(nil, "BACKGROUND")
			-- goldenGlow:SetSize(32, 32)
			-- goldenGlow:SetPoint("CENTER", point, "CENTER", 0, 0)
			-- goldenGlow:SetTexture("Interface\\GLUES\\Models\\UI_Draenei\\GenericGlow64")
			-- goldenGlow:SetBlendMode("ADD")
			-- goldenGlow:SetVertexColor(1, 0.84, 0, 0.8)
			-- goldenGlow:SetAlpha(0)
			-- goldenGlow:Hide()
			-- point.goldenGlow = goldenGlow
		end
		
		self.ClassPower = classpower
		self.ClassPower.PostUpdate = ClassPower_PostUpdate
		self.ClassPower.PostUpdateColor = ClassPower_PostUpdateColor

		-- Elemental Shaman Secondary Resource Bar
		--------------------------------------------
		if (ns.IsRetail and playerClass == "SHAMAN") then
			local petConfig = ns.GetConfig("PetFrame")
			local elementalBar = self:CreateBar()
			elementalBar:SetFrameLevel(self:GetFrameLevel() + 2)
			elementalBar:SetPoint("CENTER", self, "CENTER", 0, 0)
			elementalBar:SetSize(unpack((petConfig and petConfig.HealthBarSize) or { 112, 11 }))
			elementalBar:SetStatusBarTexture((petConfig and petConfig.HealthBarTexture) or [[Interface\TargetingFrame\UI-StatusBar]])
			elementalBar:SetOrientation((petConfig and petConfig.HealthBarOrientation) or "RIGHT")
			if (elementalBar.SetSparkMap and petConfig and petConfig.HealthBarSparkMap) then
				elementalBar:SetSparkMap(petConfig.HealthBarSparkMap)
			end
			elementalBar.displayAltPower = true
			elementalBar.GetDisplayPower = function(element)
				local profile = ClassPowerMod and ClassPowerMod.db and ClassPowerMod.db.profile
				return GetElementalSwapBarPowerType(profile), 0
			end
			elementalBar.Override = ns.API.UpdatePower
			elementalBar.PostUpdate = ElementalSwapBar_PostUpdate
			ns.API.BindStatusBarValueMirror(elementalBar)

			local powerValue = elementalBar:CreateFontString(nil, "OVERLAY", nil, 1)
			powerValue:SetPoint("CENTER", elementalBar, "CENTER", 0, 0)
			powerValue:SetFontObject((petConfig and petConfig.HealthValueFont) or GameFontNormalSmall)
			local valueColor = (petConfig and petConfig.HealthValueColor) or { 1, 1, 1, .75 }
			powerValue:SetTextColor(valueColor[1] or 1, valueColor[2] or 1, valueColor[3] or 1, valueColor[4] or .75)
			powerValue:SetJustifyH((petConfig and petConfig.HealthValueJustifyH) or "CENTER")
			powerValue:SetJustifyV((petConfig and petConfig.HealthValueJustifyV) or "MIDDLE")
			elementalBar.Value = powerValue
			elementalBar.__AzeriteUI_KeepValueVisible = ShouldShowElementalSwapBarValue()

			local elementalBackdrop = elementalBar:CreateTexture(nil, "BACKGROUND", nil, -1)
			elementalBackdrop:SetPoint(unpack((petConfig and petConfig.HealthBackdropPosition) or { "CENTER", 1, -2 }))
			elementalBackdrop:SetSize(unpack((petConfig and petConfig.HealthBackdropSize) or { 193, 93 }))
			elementalBackdrop:SetTexture((petConfig and petConfig.HealthBackdropTexture) or [[Interface\TargetingFrame\UI-StatusBar]])
			local bdColor = (petConfig and petConfig.HealthBackdropColor) or { .5, .5, .5, 1 }
			elementalBackdrop:SetVertexColor(bdColor[1] or .5, bdColor[2] or .5, bdColor[3] or .5, bdColor[4] or 1)
			elementalBar.Backdrop = elementalBackdrop

			self.Power = elementalBar
			self.Power:Hide()
		end

		-- Monk Stagger
		--------------------------------------------
		if (playerClass == "MONK") then

			local stagger = CreateFrame("Frame", nil, self)
			stagger:SetAllPoints(self)

			stagger.SetValue = noop
			stagger.SetMinMaxValues = noop
			stagger.SetStatusBarColor = Stagger_SetStatusBarColor

			for i = 1,3 do
				stagger[i] = ClassPower_CreatePoint(stagger)
			end

			ClassPower_PostUpdate(stagger, 0, 3)

			self.Stagger = stagger
			self.Stagger.PostUpdate = Stagger_PostUpdate
		end

	end

	-- Death Knight Runes
	--------------------------------------------
	if (playerClass == "DEATHKNIGHT") then

		local runes = CreateFrame("Frame", nil, self)
		runes:SetAllPoints(self)

		runes.sortOrder = "ASC"
		for i = 1,6 do
			runes[i] = ClassPower_CreatePoint(runes)
		end

		ClassPower_PostUpdate(runes, 6, 6)

		self.Runes = runes
		self.Runes.PostUpdate = Runes_PostUpdate
		self.Runes.PostUpdateColor = Runes_PostUpdateColor
	end

	-- Scripts & Events
	--------------------------------------------
	self.OnEvent = UnitFrame_OnEvent
	self.OnHide = UnitFrame_OnHide

	self:RegisterEvent("PLAYER_REGEN_ENABLED", self.OnEvent, true)
	self:RegisterEvent("PLAYER_REGEN_DISABLED", self.OnEvent, true)

end

ClassPowerMod.CreateUnitFrames = function(self)

	local unit, name = "player", "PlayerClassPower"

	oUF:RegisterStyle(ns.Prefix..name, style)
	oUF:SetActiveStyle(ns.Prefix..name)

	self.frame = ns.UnitFrame.Spawn(unit, ns.Prefix.."UnitFrame"..name)
	self.frame:EnableMouse(false)
end

ClassPowerMod.GetLabel = function(self)
	return ns.IsClassic and L["Combo Points"] or L["Class Power"]
end

ClassPowerMod.PostUpdateAnchor = function(self)
	if (not self.anchor) then return end

	self.anchor:SetTitle(self:GetLabel())
end

ClassPowerMod.OnDeferredUpdateEvent = function(self, event)
	if (event ~= "PLAYER_REGEN_ENABLED") then
		return
	end
	if (InCombatLockdown()) then
		return
	end
	self:UnregisterEvent("PLAYER_REGEN_ENABLED", "OnDeferredUpdateEvent")
	self.__AzeriteUI_PendingSettingsUpdate = nil
	self:UpdateSettings()
end

ClassPowerMod.Update = function(self)
	if (InCombatLockdown()) then
		self.__AzeriteUI_PendingSettingsUpdate = true
		self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnDeferredUpdateEvent")
		return
	end
	if (self.__AzeriteUI_PendingSettingsUpdate) then
		self.__AzeriteUI_PendingSettingsUpdate = nil
		self:UnregisterEvent("PLAYER_REGEN_ENABLED", "OnDeferredUpdateEvent")
	end

	if (ns.IsCata or ns.IsRetail) and (playerClass == "DEATHKNIGHT") then
		if (self.db.profile.showRunes) then
			self.frame:EnableElement("Runes")
			self.frame.Runes:ForceUpdate()
		else
			self.frame:DisableElement("Runes")
		end
	end

	if (ns.IsRetail and playerClass == "MONK") then
		if (self.db.profile.showStagger) then
			self.frame:EnableElement("Stagger")
			self.frame.Stagger:ForceUpdate()
		else
			self.frame:DisableElement("Stagger")
		end
	end

	if (ShouldMigratePreviousClassPowerDefault(self.db.profile)) then
		local pos = self.db.profile.savedPosition
		pos[1] = "CENTER"
		self.db.profile.defaultAnchorHotfixMigrated = true
		self:UpdatePositionAndScale()
		self:UpdateAnchor()
	end

	local useElementalSwapBar = ShouldUseElementalSwapBar(self.db.profile)
	if (useElementalSwapBar and self.db.profile and not self.db.profile.elementalSwapBarAnchorMigrated) then
		local scale = ns.API.GetEffectiveScale()
		local pos = self.db.profile.savedPosition
		if (pos) then
			pos[1] = "BOTTOMLEFT"
			pos[2] = 375 * scale
			pos[3] = 130 * scale
		end
		self.db.profile.elementalSwapBarAnchorMigrated = true
		self:UpdatePositionAndScale()
		self:UpdateAnchor()
	end
	if (ns.IsRetail and playerClass == "SHAMAN" and self.frame) then
		local classPowerConfig = ns.GetConfig("PlayerClassPower")
		local petConfig = ns.GetConfig("PetFrame")
		if (useElementalSwapBar) then
			self.frame:SetSize(unpack((petConfig and petConfig.HealthBackdropSize) or { 193, 93 }))
		else
			self.frame:SetSize(unpack((classPowerConfig and classPowerConfig.ClassPowerFrameSize) or { 124, 168 }))
		end
	end
	if (ns.IsRetail and playerClass == "SHAMAN" and self.frame.Power) then
		-- Keep Power element enabled for shaman and gate actual visibility in PostUpdate.
		self.frame:Show()
		self.frame:EnableElement("Power")
		self.frame.Power:ForceUpdate()
		self.frame.Power:Show()

		if (useElementalSwapBar) then
			self.frame:DisableElement("ClassPower")
		else
			self.frame:EnableElement("ClassPower")
			self.frame.ClassPower:ForceUpdate()
		end
	else
		self.frame:DisableElement("Power")
		self.frame:EnableElement("ClassPower")
		self.frame.ClassPower:ForceUpdate()
	end

	ApplyClassPowerClickThrough(self)
	if (ns.IsRetail and playerClass == "SHAMAN") then
		local playerFrameMod = ns:GetModule("PlayerFrame", true)
		local playerFrame = playerFrameMod and playerFrameMod.frame
		if (playerFrame and playerFrame.Power and playerFrame.Power.ForceUpdate) then
			playerFrame.Power:ForceUpdate()
		end
		if (playerFrame and playerFrame.ManaOrb and playerFrame.ManaOrb.ForceUpdate) then
			playerFrame.ManaOrb:ForceUpdate()
		end
	end

end

ClassPowerMod.OnEnable = function(self)

	self:CreateUnitFrames()
	self:CreateAnchor(self:GetLabel())
	ApplyClassPowerClickThrough(self)

	if (ns.IsRetail and playerClass == "SHAMAN") then
		self:RegisterEvent("PLAYER_ENTERING_WORLD", "UpdateSettings")
		self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED", "UpdateSettings")
		self:RegisterEvent("TRAIT_CONFIG_UPDATED", "UpdateSettings")
	end

	ns.MovableModulePrototype.OnEnable(self)
end

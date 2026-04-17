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

if (not ns.IsRetail) then return end

ns.AuraStyles = ns.AuraStyles or {}

-- Addon API
local Colors = ns.Colors
local GetFont = ns.API.GetFont
local GetMedia = ns.API.GetMedia

-- Data
local Spells = ns.AuraData.Spells
local Hidden = ns.AuraData.Hidden
local Priority = ns.AuraData.Priority

local GetAuraSpellID = function(data)
	if (ns.AuraData and ns.AuraData.GetAuraSpellID) then
		return ns.AuraData.GetAuraSpellID(data)
	end
	if (issecretvalue and (issecretvalue(data and data.spellId) or issecretvalue(data and data.spellID))) then
		return nil
	end
	return (data and data.spellId) or (data and data.spellID)
end

local PlayerFrameMod
local GetPlayerAuraProfile = function()
	if (not PlayerFrameMod and ns.GetModule) then
		PlayerFrameMod = ns:GetModule("PlayerFrame", true)
	end
	return PlayerFrameMod and PlayerFrameMod.db and PlayerFrameMod.db.profile or nil
end

local SetAuraBorderColor = function(button, color)
	if (not button or not button.Border or not color) then
		return
	end

	local red, green, blue = color[1], color[2], color[3]
	if (button.__AzeriteUI_AuraBorderRed == red and button.__AzeriteUI_AuraBorderGreen == green and button.__AzeriteUI_AuraBorderBlue == blue) then
		return
	end

	button.__AzeriteUI_AuraBorderRed = red
	button.__AzeriteUI_AuraBorderGreen = green
	button.__AzeriteUI_AuraBorderBlue = blue
	button.Border:SetBackdropBorderColor(red, green, blue)
end

local SetAuraIconState = function(button, desaturated, red, green, blue)
	if (not button or not button.Icon) then
		return
	end

	local icon = button.Icon
	local wantsDesaturated = desaturated and true or false
	if (button.__AzeriteUI_AuraIconDesaturated ~= wantsDesaturated) then
		icon:SetDesaturated(wantsDesaturated)
		button.__AzeriteUI_AuraIconDesaturated = wantsDesaturated
	end

	if (button.__AzeriteUI_AuraIconRed == red and button.__AzeriteUI_AuraIconGreen == green and button.__AzeriteUI_AuraIconBlue == blue) then
		return
	end

	button.__AzeriteUI_AuraIconRed = red
	button.__AzeriteUI_AuraIconGreen = green
	button.__AzeriteUI_AuraIconBlue = blue
	icon:SetVertexColor(red, green, blue)
end

-- Local Functions
--------------------------------------------------
local UpdateTooltip = function(self)
	if (GameTooltip:IsForbidden()) then return end

	if (self.isHarmful) then
		GameTooltip:SetUnitDebuffByAuraInstanceID(self:GetParent().__owner.unit, self.auraInstanceID)
	else
		GameTooltip:SetUnitBuffByAuraInstanceID(self:GetParent().__owner.unit, self.auraInstanceID)
	end
end

local OnEnter = function(self)
	if (GameTooltip:IsForbidden() or not self:IsVisible()) then return end
	-- Avoid parenting GameTooltip to frames with anchoring restrictions,
	-- otherwise it'll inherit said restrictions which will cause issues with
	-- its further positioning, clamping, etc
	GameTooltip:SetOwner(self, self:GetParent().__restricted and "ANCHOR_CURSOR" or self:GetParent().tooltipAnchor)
	self:UpdateTooltip()
end

local OnLeave = function(self)
	if (GameTooltip:IsForbidden()) then return end
	GameTooltip:Hide()
end

-- Aura Creation
--------------------------------------------------
ns.AuraStyles.CreateButton = function(element, position)
	local aura = CreateFrame("Button", element:GetDebugName() .. "Button" .. position, element)
	aura:RegisterForClicks("RightButtonUp")

	local icon = aura:CreateTexture(nil, "BACKGROUND", nil, 1)
	icon:SetAllPoints()
	icon:SetMask(GetMedia("actionbutton-mask-square"))
	aura.Icon = icon

	local border = CreateFrame("Frame", nil, aura, ns.BackdropTemplate)
	border:SetBackdrop({ edgeFile = GetMedia("border-aura"), edgeSize = 12 })
	border:SetBackdropBorderColor(Colors.verydarkgray[1], Colors.verydarkgray[2], Colors.verydarkgray[3])
	border:SetPoint("TOPLEFT", -6, 6)
	border:SetPoint("BOTTOMRIGHT", 6, -6)
	border:SetFrameLevel(aura:GetFrameLevel() + 2)
	aura.Border = border

	local count = aura.Border:CreateFontString(nil, "OVERLAY")
	count:SetFontObject(GetFont(12,true))
	count:SetTextColor(Colors.offwhite[1], Colors.offwhite[2], Colors.offwhite[3])
	count:SetPoint("BOTTOMRIGHT", aura, "BOTTOMRIGHT", -2, 3)
	aura.Count = count

	local time = aura.Border:CreateFontString(nil, "OVERLAY")
	time:SetFontObject(GetFont(14,true))
	time:SetTextColor(Colors.offwhite[1], Colors.offwhite[2], Colors.offwhite[3])
	time:SetPoint("TOPLEFT", aura, "TOPLEFT", -4, 4)
	aura.Time = time

	-- Use a native cooldown frame for aura timers so combat secret values
	-- can still drive Blizzard's internal countdown safely.
	local cooldown = CreateFrame("Cooldown", "$parentCooldown", aura, "CooldownFrameTemplate")
	cooldown:SetAllPoints(aura)
	cooldown:SetDrawEdge(false)
	cooldown:SetDrawBling(false)
	if (cooldown.SetDrawSwipe) then
		cooldown:SetDrawSwipe(true)
	end
	if (cooldown.SetSwipeColor) then
		cooldown:SetSwipeColor(0, 0, 0, 0)
	end
	if (cooldown.SetHideCountdownNumbers) then
		cooldown:SetHideCountdownNumbers(false)
	end
	if (cooldown.SetCountdownAbbrevThreshold) then
		cooldown:SetCountdownAbbrevThreshold(2)
	end
	if (cooldown.SetFrameLevel) then
		cooldown:SetFrameLevel(aura.Border:GetFrameLevel() + 1)
	end

	for i = 1, cooldown:GetNumRegions() do
		local region = select(i, cooldown:GetRegions())
		if (region and region.GetObjectType and region:GetObjectType() == "FontString") then
			region:SetFontObject(GetFont(14,true))
			region:SetTextColor(Colors.offwhite[1], Colors.offwhite[2], Colors.offwhite[3])
			region:ClearAllPoints()
			region:SetPoint("TOPLEFT", aura, "TOPLEFT", -4, 4)
		end
	end

	-- Keep legacy custom timer hidden; native cooldown text handles aura timing.
	aura.Time:Hide()
	aura.Cooldown = ns.Widgets.RegisterCooldown(cooldown)

	-- Replacing oUF's aura tooltips, as they are not secure.
	if (not element.disableMouse) then
		aura.UpdateTooltip = UpdateTooltip
		aura:SetScript("OnEnter", OnEnter)
		aura:SetScript("OnLeave", OnLeave)
	end

	return aura
end

ns.AuraStyles.CreateSmallButton = function(element, position)
	local aura = ns.AuraStyles.CreateButton(element, position)

	aura.Time:SetFontObject(GetFont(12,true))

	return aura
end

ns.AuraStyles.CreateButtonWithBar = function(element, position)
	local aura = ns.AuraStyles.CreateButton(element, position)

	local bar = element.__owner:CreateBar(nil, aura)
	bar:SetPoint("TOP", aura, "BOTTOM", 0, 0)
	bar:SetPoint("LEFT", aura, "LEFT", 1, 0)
	bar:SetPoint("RIGHT", aura, "RIGHT", -1, 0)
	bar:SetHeight(6)
	bar:SetStatusBarTexture(GetMedia("bar-small"))
	bar.bg = bar:CreateTexture(nil, "BACKGROUND", nil, -7)
	bar.bg:SetPoint("TOPLEFT", -1, 1)
	bar.bg:SetPoint("BOTTOMRIGHT", 1, -1)
	bar.bg:SetColorTexture(.05, .05, .05, .85)
	aura.Bar = bar

	aura.Cooldown = ns.Widgets.RegisterCooldown(aura.Cooldown, bar)

	return aura
end

-- Aura PostUpdates
--------------------------------------------------
ns.AuraStyles.PlayerPostUpdateButton = function(element, button, unit, data, position)
	local function SafeBool(v)
		if (issecretvalue and issecretvalue(v)) then return false end
		return not not v
	end
	local function SafeNumber(v)
		if (issecretvalue and issecretvalue(v)) then return nil end
		if (type(v) == "number") then return v end
		return nil
	end
	local function SafeKey(v)
		if (issecretvalue and issecretvalue(v)) then return nil end
		return v
	end
	-- Border Coloring
	local color
	if (button.isHarmful and element.showDebuffType) or (not button.isHarmful and element.showBuffType) or (element.showType) then
		local dispelName = SafeKey(data.dispelName)
		color = (dispelName and Colors.debuff[dispelName]) or Colors.debuff.none
	else
		color = Colors.verydarkgray -- Colors.aura
	end
	if (color) then
		button.Border:SetBackdropBorderColor(color[1], color[2], color[3])
	end

	-- Icon Coloring
	-- Playerframe dim/bright rules should remain stable in combat.
	-- Prefer stable fields produced by AuraFilters over raw payload values.
	local isPlayerAura = SafeBool(data.__AzeriteUI_isPlayerAura)
		or ((button.isPlayer ~= nil) and (button.isPlayer and true or false))
		or SafeBool(data.isPlayerAura)
	local canApplyAura = SafeBool(data.__AzeriteUI_canApplyAura) or SafeBool(data.canApplyAura)
	local isImportantAura = SafeBool(data.__AzeriteUI_isImportant)
		or SafeBool(data.__AzeriteUI_isRaidInCombat)
		or SafeBool(data.__AzeriteUI_isBigDefensive)
		or SafeBool(data.__AzeriteUI_isExternalDefensive)
		or SafeBool(data.__AzeriteUI_isCrowdControl)
		or SafeBool(data.__AzeriteUI_isStealable)
	local isHarmful = (button.isHarmful ~= nil) and (button.isHarmful and true or false) or SafeBool(data.isHarmful)
	local spellId = GetAuraSpellID(data)
	local secretHelpfulFallback = SafeBool(data.__AzeriteUI_secretHelpfulFallback)
	local profile = GetPlayerAuraProfile()
	local useStockBehavior = profile and profile.playerAuraUseStockBehavior
	if (profile and profile.playerAuraAlwaysBright) then
		button.Icon:SetDesaturated(false)
		button.Icon:SetVertexColor(1, 1, 1)
		return
	end
	if (useStockBehavior and InCombatLockdown and InCombatLockdown() and (not isHarmful)) then
		local hasReliableSignal = isPlayerAura or canApplyAura or isImportantAura or (spellId and true or false)
		if (secretHelpfulFallback or (isPlayerAura and not canApplyAura) or (not hasReliableSignal)) then
			button.Icon:SetDesaturated(false)
			button.Icon:SetVertexColor(1, 1, 1)
			return
		end
	end
	if (button.isHarmful)
	or secretHelpfulFallback
	or (not isHarmful and isPlayerAura and canApplyAura)
	or (not isHarmful and isImportantAura)
	or (spellId and Spells[spellId]) then
		button.Icon:SetDesaturated(false)
		button.Icon:SetVertexColor(1, 1, 1)

	elseif (isPlayerAura) then
		button.Icon:SetDesaturated(false)
		button.Icon:SetVertexColor(.3, .3, .3)

	else
		button.Icon:SetDesaturated(true)
		button.Icon:SetVertexColor(.6, .6, .6)
	end

end

ns.AuraStyles.TargetPostUpdateButton = function(element, button, unit, data, position)
	local function SafeBool(v)
		if (issecretvalue and issecretvalue(v)) then return false end
		return not not v
	end
	local function SafeKey(v)
		if (issecretvalue and issecretvalue(v)) then return nil end
		return v
	end

	-- Border Coloring
	local color
	if (UnitCanAttack("player", unit)) then
		if (button.isHarmful) then
			color = Colors.verydarkgray
		else
			local dispelName = SafeKey(data.dispelName)
			color = (dispelName and Colors.debuff[dispelName]) or Colors.verydarkgray
		end
	else
		if (button.isHarmful and element.showDebuffType) or (not button.isHarmful and element.showBuffType) or (element.showType) then
			local dispelName = SafeKey(data.dispelName)
			color = (dispelName and Colors.debuff[dispelName]) or Colors.debuff.none
		else
			color = Colors.verydarkgray
		end
	end
	if (color) then
		SetAuraBorderColor(button, color)
	end

	-- Icon Coloring
	local nameplateShowAll = SafeBool(data.nameplateShowAll)
	local nameplateShowPersonal = SafeBool(data.nameplateShowPersonal)
	local isPlayerAura = (button.isPlayer ~= nil) and (button.isPlayer and true or false) or SafeBool(data.isPlayerAura)
	local canApplyAura = SafeBool(data.canApplyAura)
	local isHarmful = (button.isHarmful ~= nil) and (button.isHarmful and true or false) or SafeBool(data.isHarmful)
	local spellId = GetAuraSpellID(data)
	if (nameplateShowAll or (nameplateShowPersonal and isPlayerAura))
	or (not isHarmful and isPlayerAura and canApplyAura) or (spellId and Spells[spellId]) then
		SetAuraIconState(button, false, 1, 1, 1)

	elseif (isPlayerAura) then
		SetAuraIconState(button, false, .3, .3, .3)

	else
		SetAuraIconState(button, true, .6, .6, .6)
	end

end

ns.AuraStyles.PartyPostUpdateButton = function(element, button, unit, data, position)
	local function SafeBool(v)
		if (issecretvalue and issecretvalue(v)) then return false end
		return not not v
	end
	local function SafeKey(v)
		if (issecretvalue and issecretvalue(v)) then return nil end
		return v
	end

	local isHarmful = button.isHarmful or button.isDebuff or SafeBool(data.isHarmful)
	local owner = element and element.__owner
	local partyModuleProfile = nil
	if (owner and owner.unit and ns.GetModule) then
		local partyModule = ns:GetModule("PartyFrames", true)
		partyModuleProfile = partyModule and partyModule.db and partyModule.db.profile or nil
	end
	local debuffScale = 1
	if (partyModuleProfile and type(partyModuleProfile.partyAuraDebuffScale) == "number") then
		debuffScale = partyModuleProfile.partyAuraDebuffScale / 100
	end
	if (debuffScale < .5) then
		debuffScale = .5
	elseif (debuffScale > 2) then
		debuffScale = 2
	end
	button:SetScale(isHarmful and debuffScale or 1)
	local color
	if (isHarmful and element.showDebuffType) or ((not isHarmful) and element.showBuffType) or (element.showType) then
		local dispelName = SafeKey(data.dispelName)
		color = (dispelName and Colors.debuff[dispelName]) or Colors.debuff.none
	else
		color = Colors.verydarkgray
	end
	if (color) then
		button.Border:SetBackdropBorderColor(color[1], color[2], color[3])
	end

	local isPlayerAura = SafeBool(data.isPlayerAura)
	local canApplyAura = SafeBool(data.canApplyAura)
	local spellId = GetAuraSpellID(data)
	if (isHarmful) or (spellId and Spells[spellId]) or (isPlayerAura and canApplyAura) then
		button.Icon:SetDesaturated(false)
		button.Icon:SetVertexColor(1, 1, 1)
	elseif (isPlayerAura) then
		button.Icon:SetDesaturated(false)
		button.Icon:SetVertexColor(.65, .65, .65)
	else
		button.Icon:SetDesaturated(true)
		button.Icon:SetVertexColor(.6, .6, .6)
	end
end

ns.AuraStyles.NameplatePostUpdateButton = function(element, button, unit, data, position)

	local function SafeKey(v)
		if (issecretvalue and issecretvalue(v)) then return nil end
		return v
	end

	-- Coloring
	local color
	if (button.isHarmful and element.showDebuffType) or (not button.isHarmful and element.showBuffType) or (element.showType) then
		local dispelName = SafeKey(data.dispelName)
		color = (dispelName and Colors.debuff[dispelName]) or Colors.debuff.none
	else
		color = Colors.verydarkgray
	end
	if (color) then
		button.Border:SetBackdropBorderColor(color[1], color[2], color[3])
	end

end

ns.AuraStyles.ArenaPostUpdateButton = function(element, button, unit, data, position)

	local function SafeKey(v)
		if (issecretvalue and issecretvalue(v)) then return nil end
		return v
	end

	-- Coloring
	local color
	local spellId = GetAuraSpellID(data)
	if (button.isHarmful and element.showDebuffType) or (not button.isHarmful and element.showBuffType) or (element.showType) or (spellId and Spells[spellId]) then
		local dispelName = SafeKey(data.dispelName)
		color = (dispelName and Colors.debuff[dispelName]) or Colors.debuff.none
	else
		color = Colors.verydarkgray
	end
	if (color) then
		button.Border:SetBackdropBorderColor(color[1], color[2], color[3])
	end

end

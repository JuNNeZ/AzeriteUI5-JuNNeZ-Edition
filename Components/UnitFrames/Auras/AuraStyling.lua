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

local SetAuraTextureBorderColor = function(self, red, green, blue, alpha)
	local pieces = self and self.__AzeriteUI_BorderPieces
	if (not pieces) then
		return
	end

	-- The Legacy HUD's neutral border is the 3.x grey (ui * .3), not our warm
	-- dark grey. Only our own colour constants are compared, never aura data.
	local neutral = self.__AzeriteUI_LegacyNeutral
	if (neutral and not (issecretvalue and (issecretvalue(red) or issecretvalue(green) or issecretvalue(blue)))
		and red == Colors.verydarkgray[1] and green == Colors.verydarkgray[2] and blue == Colors.verydarkgray[3]) then
		red, green, blue = neutral[1], neutral[2], neutral[3]
	end

	for i = 1, #pieces do
		pieces[i]:SetVertexColor(red or 1, green or 1, blue or 1, alpha or 1)
	end
end

-- Texture coordinates of one backdrop edge segment (0 left, 1 right, 2 top,
-- 3 bottom, 4-7 corners) on a 256x32 sheet, cropped by inset pixels.
local GetEdgeCoords = function(segment, inset, rotated)
	local left, right = segment/8 + inset/256, (segment + 1)/8 - inset/256
	local top, bottom = inset/32, 1 - inset/32
	if (rotated) then
		return { left, bottom, right, bottom, left, top, right, top }
	end
	return { left, top, left, bottom, right, top, right, bottom }
end

local CreateAuraTextureBorder = function(aura)
	-- The Legacy HUD draws the 3.x aura border as 3.x did: the whole sheet at
	-- a 16px edge, 7px outside the icon (callers place the frame 6px outside).
	local legacy = ns.LegacyHUD and ns.LegacyHUD:IsActive()
	local edgeSize = legacy and 16 or 12
	local inset = legacy and 0 or 2
	local outset = legacy and 1 or 0
	local file = GetMedia("border-aura")
	local border = CreateFrame("Frame", nil, aura)
	local pieces = {}

	local createPiece = function(coords)
		local texture = border:CreateTexture(nil, "BORDER")
		texture:SetTexture(file)
		texture:SetTexCoord(
			coords[1], coords[2],
			coords[3], coords[4],
			coords[5], coords[6],
			coords[7], coords[8]
		)
		pieces[#pieces + 1] = texture
		return texture
	end

	local topLeft = createPiece(GetEdgeCoords(4, inset))
	topLeft:SetSize(edgeSize, edgeSize)
	topLeft:SetPoint("TOPLEFT", -outset, outset)

	local topRight = createPiece(GetEdgeCoords(5, inset))
	topRight:SetSize(edgeSize, edgeSize)
	topRight:SetPoint("TOPRIGHT", outset, outset)

	local bottomLeft = createPiece(GetEdgeCoords(6, inset))
	bottomLeft:SetSize(edgeSize, edgeSize)
	bottomLeft:SetPoint("BOTTOMLEFT", -outset, -outset)

	local bottomRight = createPiece(GetEdgeCoords(7, inset))
	bottomRight:SetSize(edgeSize, edgeSize)
	bottomRight:SetPoint("BOTTOMRIGHT", outset, -outset)

	local top = createPiece(GetEdgeCoords(2, inset, true))
	top:SetHeight(edgeSize)
	top:SetPoint("TOPLEFT", topLeft, "TOPRIGHT")
	top:SetPoint("TOPRIGHT", topRight, "TOPLEFT")

	local bottom = createPiece(GetEdgeCoords(3, inset, true))
	bottom:SetHeight(edgeSize)
	bottom:SetPoint("BOTTOMLEFT", bottomLeft, "BOTTOMRIGHT")
	bottom:SetPoint("BOTTOMRIGHT", bottomRight, "BOTTOMLEFT")

	local left = createPiece(GetEdgeCoords(0, inset))
	left:SetWidth(edgeSize)
	left:SetPoint("TOPLEFT", topLeft, "BOTTOMLEFT")
	left:SetPoint("BOTTOMLEFT", bottomLeft, "TOPLEFT")

	local right = createPiece(GetEdgeCoords(1, inset))
	right:SetWidth(edgeSize)
	right:SetPoint("TOPRIGHT", topRight, "BOTTOMRIGHT")
	right:SetPoint("BOTTOMRIGHT", bottomRight, "TOPRIGHT")

	border.__AzeriteUI_BorderPieces = pieces
	border.__AzeriteUI_LegacyNeutral = legacy and { Colors.ui[1] * .3, Colors.ui[2] * .3, Colors.ui[3] * .3 } or nil
	border.SetBackdropBorderColor = SetAuraTextureBorderColor
	return border
end

-- Shared by the Retail custom player-aura containers. The returned frame and
-- all of its regions are created during Blizzard's initializeFrame callback,
-- before CustomAuraButton applies its restricted aura aspects.
ns.AuraStyles.CreateTextureBorder = CreateAuraTextureBorder

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

	local border = CreateAuraTextureBorder(aura)
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
		SetAuraBorderColor(button, color)
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
		SetAuraBorderColor(button, color)
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
		SetAuraBorderColor(button, color)
	end

end

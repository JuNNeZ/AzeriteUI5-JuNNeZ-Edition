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

local Auras = ns:NewModule("Auras", ns.MovableModulePrototype, "LibMoreEvents-1.0", "AceTimer-3.0", "AceHook-3.0", "AceConsole-3.0")
local API = ns.API
local LFF = LibStub("LibFadingFrames-1.0")

-- Lua API
local math_ceil = math.ceil
local string_find = string.find
local string_lower = string.lower
local type = type
local unpack = unpack

-- Addon API
local Colors = ns.Colors
local GetFont = ns.API.GetFont
local GetMedia = ns.API.GetMedia

local AURA_SIZE = 36
local MAX_BUFFS = BUFF_MAX_DISPLAY or 32
local MAX_DEBUFFS = DEBUFF_MAX_DISPLAY or 16
local MAX_PRIVATE_AURAS = 6
local BUFF_GROUP_KEY = "AzeriteUIPlayerBuffs"
local DEBUFF_GROUP_KEY = "AzeriteUIPlayerDebuffs"
local DURATION_WARNING_SECONDS = 10

local warningDurationOptions
if (C_CurveUtil and C_CurveUtil.CreateColorCurve and Enum.LuaCurveType and Enum.DurationTextBindingProperty and Enum.DurationTextBindingProperty.RemainingDuration) then
	-- Reproduce the historical final-10-second warning without reading or
	-- comparing the potentially secret remaining duration in addon code.
	local warningColorCurve = C_CurveUtil.CreateColorCurve()
	warningColorCurve:SetType(Enum.LuaCurveType.Step)
	warningColorCurve:AddPoint(0, { r = Colors.red[1], g = Colors.red[2], b = Colors.red[3], a = .85 })
	warningColorCurve:AddPoint(DURATION_WARNING_SECONDS, { r = Colors.red[1], g = Colors.red[2], b = Colors.red[3], a = 0 })
	warningDurationOptions = {
		textColor = {
			curve = warningColorCurve,
			property = Enum.DurationTextBindingProperty.RemainingDuration
		}
	}
end

local defaults = { profile = ns:Merge({
	enabled = true,
	enableAuraFading = true,
	enableModifier = false,
	modifier = "SHIFT",
	ignoreTarget = false,
	anchorPoint = "TOPRIGHT",
	growthX = "LEFT",
	growthY = "DOWN",
	paddingX = 6,
	paddingY = 12,
	wrapAfter = 8
}, ns.MovableModulePrototype.defaults) }

Auras.GenerateDefaults = function(self)
	defaults.profile.savedPosition = {
		scale = ns.API.GetEffectiveScale(),
		[1] = "TOPRIGHT",
		[2] = -40 * ns.API.GetEffectiveScale(),
		[3] = -40 * ns.API.GetEffectiveScale()
	}
	return defaults
end

local StyleAuraButton = function(button, filter)
	button:SetSize(AURA_SIZE, AURA_SIZE)
	button:SetTooltipAnchorPoint("ANCHOR_BOTTOMLEFT")
	button:SetHideTooltipInCombat(false)

	local contents = CreateFrame("Frame", nil, button)
	contents:SetAllPoints(button)
	button.contents = contents

	local icon = contents:CreateTexture(nil, "BACKGROUND", nil, 1)
	icon:SetAllPoints()
	icon:SetMask(GetMedia("actionbutton-mask-square"))
	icon:SetVertexColor(.75, .75, .75)
	button.icon = icon

	local border = CreateFrame("Frame", nil, contents, ns.BackdropTemplate)
	border:SetBackdrop({ edgeFile = GetMedia("border-aura"), edgeSize = 12 })
	if (filter == "HARMFUL") then
		local color = Colors.debuff.none
		border:SetBackdropBorderColor(color[1], color[2], color[3])
	else
		border:SetBackdropBorderColor(Colors.verydarkgray[1], Colors.verydarkgray[2], Colors.verydarkgray[3])
	end
	border:SetPoint("TOPLEFT", -6, 6)
	border:SetPoint("BOTTOMRIGHT", 6, -6)
	border:SetFrameLevel(contents:GetFrameLevel() + 2)
	button.border = border

	local count = border:CreateFontString(nil, "OVERLAY")
	count:SetFontObject(GetFont(12, true))
	count:SetTextColor(unpack(Colors.offwhite))
	count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 3)
	button.count = count

	local overlay = CreateFrame("Frame", nil, button)
	overlay:SetPoint("TOPLEFT", -6, 6)
	overlay:SetPoint("BOTTOMRIGHT", 6, -6)
	overlay:SetFrameLevel(contents:GetFrameLevel() + 3)
	button.overlay = overlay

	-- Retain Blizzard's native duration carrier, but keep its countdown hidden.
	-- The standalone aura frame historically only showed its centered warning.
	local cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
	cooldown:SetAllPoints(button)
	cooldown:SetDrawEdge(false)
	cooldown:SetDrawBling(false)
	cooldown:SetDrawSwipe(true)
	cooldown:SetSwipeColor(0, 0, 0, 0)
	cooldown:SetHideCountdownNumbers(true)
	cooldown:SetCountdownAbbrevThreshold(2)
	cooldown:SetFrameLevel(border:GetFrameLevel() + 1)
	button.cooldown = cooldown

	local warningTime = overlay:CreateFontString(nil, "OVERLAY")
	warningTime:SetFontObject(GetFont(18, true))
	warningTime:SetTextColor(unpack(Colors.red))
	warningTime:SetPoint("CENTER")
	warningTime:SetJustifyH("CENTER")
	warningTime:SetJustifyV("MIDDLE")
	warningTime:SetWordWrap(false)
	warningTime:SetNonSpaceWrap(false)
	warningTime:SetMaxLines(1)
	warningTime:SetFixedColor(false)
	warningTime:SetAlpha(1)
	button.time = warningTime
	-- Never attach script handlers to CustomAuraButtonTemplate frames. Retail
	-- applies their visibility as a secret value and rejects SetShown(secret)
	-- once an addon handler exists on the button.

	--[[
		The duration bar is drawn inverted: a full-width aura-colored layer with a
		dark "spent" layer growing over it from the right, driven by ElapsedTime.

		A straight RemainingTime bar cannot render a timerless aura correctly.
		Blizzard's ApplyDurationBar hands the bar a zero duration for permanent
		auras with no zero check of its own -- unlike ApplyDurationText directly
		above it, which does `binding:SetEnabled(not auraDuration:IsZero())` --
		so a permanent aura drives the bar to 0 and Devotion Aura or a bonus
		event buff renders as an empty trough. Addons cannot tell the two apart
		per aura: GetAuraDuration and the OnAuraInstance* hooks are all on the
		private mixin, and this file must not attach script handlers to these
		buttons at all.

		Inverting the layers turns that zero into the state we want. Elapsed 0
		means the dark layer has no width, so a timerless aura shows a full
		aura-colored bar, while a timed aura's colored region still recedes from
		the right exactly as before.
	]]
	local bar = CreateFrame("StatusBar", nil, contents)
	bar:SetPoint("TOP", contents, "BOTTOM", 0, 0)
	bar:SetPoint("LEFT", contents, "LEFT", 1, 0)
	bar:SetPoint("RIGHT", contents, "RIGHT", -1, 0)
	bar:SetHeight(4)
	-- "plain" is the solid ChatFrameBackground alias, so the spent layer masks the
	-- colored layer underneath completely. bar-small would let color bleed through
	-- wherever its own alpha is below one, and blank.tga is the transparent asset
	-- used elsewhere to clear a texture.
	bar:SetStatusBarTexture(GetMedia("plain"))
	bar:SetStatusBarColor(.05, .05, .05, 1)
	bar:SetReverseFill(true)
	-- The trough, visible as the one pixel outline around the bar.
	bar.bg = bar:CreateTexture(nil, "BACKGROUND", nil, -7)
	bar.bg:SetPoint("TOPLEFT", -1, 1)
	bar.bg:SetPoint("BOTTOMRIGHT", 1, -1)
	bar.bg:SetColorTexture(.05, .05, .05, .85)
	-- The remaining-time layer, sitting under the spent layer at full width.
	bar.remaining = bar:CreateTexture(nil, "BACKGROUND", nil, -6)
	bar.remaining:SetAllPoints(bar)
	bar.remaining:SetTexture(GetMedia("bar-small"))
	bar.remaining:SetVertexColor(unpack(Colors.aura))
	button.bar = bar

	button:SetIcon(icon)
	button:SetApplicationCount(count)
	button:SetDurationCooldown(cooldown)
	button:SetDurationBar(bar, {
		-- ElapsedTime, not RemainingTime: see the layering note above.
		direction = Enum.StatusBarTimerDirection.ElapsedTime
	})
	if (warningDurationOptions) then
		button:SetDurationText(warningTime, warningDurationOptions)
	end
	button:SetCancelAuraButtons(filter == "HARMFUL" and nil or "RightButtonUp")
end

local GetFlowDirection = function(direction, fallback)
	local directions = AnchorUtil and AnchorUtil.FlowDirection
	return directions and directions[direction] or fallback
end

local GetSortMethod = function()
	local methods = AuraContainerSortMethod
	return methods and (methods.AuraInstanceIDOnly or methods.Default)
end

local GetSortDirection = function()
	local directions = AuraContainerSortDirection
	return directions and directions.Normal
end

local CreateAuraContainer = function(parent, name, unit, filter, groupKey, maxFrameCount)
	local container = CreateFrame("AuraContainer", name, parent, "CustomAuraContainerTemplate, DisableUntrustedLayoutScriptsTemplate")
	local initializeFrame = function(button)
		StyleAuraButton(button, filter)
	end

	container.unit = unit
	container.filter = filter
	container.groupKey = groupKey
	container.maxFrameCount = maxFrameCount
	container:SetUnit(unit)
	container:AddAuraGroup(groupKey, filter, {
		initializeFrame = initializeFrame,
		maxFrameCount = maxFrameCount,
		sortMethod = GetSortMethod(),
		sortDirection = GetSortDirection(),
		layout = {
			elementWidth = AURA_SIZE,
			elementHeight = AURA_SIZE
		}
	})
	return container
end

local AddItemEnchantments = function(container)
	local slots = AuraContainerItemEnchantmentSlot
	if (not slots) then return end

	local options = {
		initializeFrame = function(button)
			StyleAuraButton(button, "HELPFUL")
		end,
		hidePermanent = false
	}
	if (slots.MainHand) then
		container:AddItemEnchantment(slots.MainHand, options)
	end
	if (slots.OffHand) then
		container:AddItemEnchantment(slots.OffHand, options)
	end
end

local CreatePrivateAuraContainer = function(parent, unit)
	-- This row is anchored to a CustomAuraContainer, which gains the
	-- UntrustedLayoutScriptExecution forbidden aspect after AddAuraGroup().
	-- Blizzard explicitly requires dependent addon frames to opt in at creation.
	local container = CreateFrame("Frame", nil, parent, "DisableUntrustedLayoutScriptsTemplate")
	container:SetSize(MAX_PRIVATE_AURAS * AURA_SIZE, AURA_SIZE)
	container.anchors = {}
	container.anchorIDs = {}

	if (not C_UnitAuras or not C_UnitAuras.AddPrivateAuraAnchor) then
		return container
	end

	for index = 1, MAX_PRIVATE_AURAS do
		local anchor = CreateFrame("Frame", nil, container, "DisableUntrustedLayoutScriptsTemplate")
		anchor:SetSize(AURA_SIZE, AURA_SIZE)
		anchor:SetPoint("LEFT", container, "LEFT", (index - 1) * AURA_SIZE, 0)
		container.anchors[index] = anchor

		local ok, anchorID = API.TryCall(C_UnitAuras.AddPrivateAuraAnchor, {
			unitToken = unit,
			auraIndex = index,
			parent = anchor,
			showCooldownFrame = true,
			showCooldownEdge = false,
			showCountdownNumbers = true,
			showDispelIcon = true,
			isContainer = false,
			iconInfo = {
				iconWidth = AURA_SIZE,
				iconHeight = AURA_SIZE,
				iconAnchor = {
					point = "CENTER",
					relativeTo = anchor,
					relativePoint = "CENTER",
					offsetX = 0,
					offsetY = 0
				}
			}
		})
		if (ok and anchorID) then
			container.anchorIDs[index] = anchorID
		end
	end

	return container
end

local CreateUnitAuraGroup = function(self, unit, suffix)
	local group = CreateFrame("Frame", ns.Prefix .. suffix .. "AuraGroup", self.frame, "SecureHandlerShowHideTemplate")
	group:SetAllPoints(self.frame)
	group.unit = unit

	group.buffs = CreateAuraContainer(group, ns.Prefix .. suffix .. "BuffContainer", unit, "HELPFUL", BUFF_GROUP_KEY, MAX_BUFFS)
	group.debuffs = CreateAuraContainer(group, ns.Prefix .. suffix .. "DebuffContainer", unit, "HARMFUL", DEBUFF_GROUP_KEY, MAX_DEBUFFS)
	group.privateAuras = CreatePrivateAuraContainer(group, unit)

	if (unit == "player") then
		AddItemEnchantments(group.buffs)
	end

	self.auraUnitGroups[#self.auraUnitGroups + 1] = group
	return group
end

local GetStackPoints = function(config)
	local horizontal = ""
	if (string_find(config.anchorPoint, "LEFT", 1, true)) then
		horizontal = "LEFT"
	elseif (string_find(config.anchorPoint, "RIGHT", 1, true)) then
		horizontal = "RIGHT"
	end

	if (config.growthY == "DOWN") then
		return "TOP" .. horizontal, "BOTTOM" .. horizontal, -1
	else
		return "BOTTOM" .. horizontal, "TOP" .. horizontal, 1
	end
end

local UpdateContainerLayout = function(container, config)
	local horizontal = GetFlowDirection(config.growthX == "LEFT" and "Left" or "Right")
	local vertical = GetFlowDirection(config.growthY == "DOWN" and "Down" or "Up")
	local maximumLineSize = config.wrapAfter * AURA_SIZE + (config.wrapAfter - 1) * config.paddingX
	local layout = {
		elementSpacing = config.paddingX,
		lineSpacing = config.paddingY,
		groupSpacing = config.paddingX,
		groupLineSpacing = config.paddingY,
		elementWidth = AURA_SIZE,
		elementHeight = AURA_SIZE
	}

	container:SetFlowLayoutAnchorPoint(config.anchorPoint)
	container:SetFlowLayoutGrowthDirection(horizontal, vertical)
	container:SetFlowLayoutMaximumLineSize(maximumLineSize)
	container:SetAuraGroupLayout(container.groupKey, layout)
	container:SetAuraGroupMaxFrameCount(container.groupKey, container.maxFrameCount)

	if (container == container:GetParent().buffs and container.SetItemEnchantmentLayout) then
		container:SetItemEnchantmentLayout({
			elementSpacing = config.paddingX,
			lineSpacing = config.paddingY,
			groupSpacing = config.paddingX,
			groupLineSpacing = config.paddingY,
			elementWidth = AURA_SIZE,
			elementHeight = AURA_SIZE
		})
	end
end

local UpdateUnitGroupLayout = function(group, config)
	UpdateContainerLayout(group.buffs, config)
	UpdateContainerLayout(group.debuffs, config)

	local startPoint, endPoint, direction = GetStackPoints(config)
	group.buffs:ClearAllPoints()
	group.buffs:SetPoint(config.anchorPoint, group, config.anchorPoint)

	group.debuffs:ClearAllPoints()
	group.debuffs:SetPoint(startPoint, group.buffs, endPoint, 0, direction * config.paddingY)

	group.privateAuras:ClearAllPoints()
	group.privateAuras:SetPoint(startPoint, group.debuffs, endPoint, 0, direction * config.paddingY)
end

Auras.CreateAuras = function(self)
	if (self.frame) then return true end
	if (not C_XMLUtil or not C_XMLUtil.GetTemplateInfo or not C_XMLUtil.GetTemplateInfo("CustomAuraContainerTemplate")) then
		return false
	end
	if (not AuraContainerSortMethod or not AuraContainerSortDirection or not AnchorUtil or not AnchorUtil.FlowDirection) then
		return false
	end

	local config = self.db.profile
	local frame = CreateFrame("Frame", ns.Prefix .. "AuraContainerFrame", UIParent, "SecureHandlerStateTemplate")
	frame:SetSize(config.wrapAfter * AURA_SIZE + (config.wrapAfter - 1) * config.paddingX, AURA_SIZE)
	frame:SetPoint(config.savedPosition[1], UIParent, config.savedPosition[1], config.savedPosition[2], config.savedPosition[3])
	frame:SetScale(config.savedPosition.scale)
	self.frame = frame
	self.auraUnitGroups = {}

	self.playerAuras = CreateUnitAuraGroup(self, "player", "Player")
	self.vehicleAuras = CreateUnitAuraGroup(self, "vehicle", "Vehicle")
	self.buffs = self.playerAuras.buffs
	self.debuffs = self.playerAuras.debuffs

	frame:SetFrameRef("playerAuras", self.playerAuras)
	frame:SetFrameRef("vehicleAuras", self.vehicleAuras)
	frame:SetAttribute("_onstate-unit", [[
		local playerAuras = self:GetFrameRef("playerAuras");
		local vehicleAuras = self:GetFrameRef("vehicleAuras");
		if (newstate == "vehicle") then
			playerAuras:Hide();
			vehicleAuras:Show();
		else
			vehicleAuras:Hide();
			playerAuras:Show();
		end
	]])

	RegisterStateDriver(frame, "unit", "[vehicleui]vehicle;player")

	return true
end

local DisableMouseOnAuraFrame = function(frame)
	if (not frame) then return end
	if (frame.EnableMouse) then frame:EnableMouse(false) end
	if (frame.SetMouseClickEnabled) then frame:SetMouseClickEnabled(false) end
	if (frame.SetMouseMotionEnabled) then frame:SetMouseMotionEnabled(false) end
end

local SuppressBlizzardAuraFrame = function(frame)
	if (not frame) then return end
	frame.__AzeriteUIApplyingAlpha = true
	frame:SetAlpha(0)
	frame.__AzeriteUIApplyingAlpha = nil
	DisableMouseOnAuraFrame(frame)

	if (type(frame.auraFrames) == "table") then
		for _, auraFrame in ipairs(frame.auraFrames) do
			DisableMouseOnAuraFrame(auraFrame)
		end
	end

	if (not frame.__AzeriteUIAlphaHooked) then
		hooksecurefunc(frame, "SetAlpha", function(blizzardFrame, alpha)
			if (alpha ~= 0 and not blizzardFrame.__AzeriteUIApplyingAlpha) then
				blizzardFrame.__AzeriteUIApplyingAlpha = true
				blizzardFrame:SetAlpha(0)
				blizzardFrame.__AzeriteUIApplyingAlpha = nil
			end
		end)
		frame.__AzeriteUIAlphaHooked = true
	end
end

Auras.DisableBlizzard = function(self)
	SuppressBlizzardAuraFrame(BuffFrame)
	SuppressBlizzardAuraFrame(DebuffFrame)

	if (EditModeManagerFrame and not self.editModeHooked) then
		self:SecureHook(EditModeManagerFrame, "UpdateLayoutInfo", function()
			SuppressBlizzardAuraFrame(BuffFrame)
			SuppressBlizzardAuraFrame(DebuffFrame)
		end)
		self.editModeHooked = true
	end
end

Auras.UpdateSettings = function(self)
	if (InCombatLockdown()) then
		self.needupdate = true
		return
	end
	if (not self.frame) then return end

	local config = self.db.profile
	local maximumWidth = config.wrapAfter * AURA_SIZE + (config.wrapAfter - 1) * config.paddingX
	local maximumRows = math_ceil(MAX_BUFFS / config.wrapAfter) + math_ceil(MAX_DEBUFFS / config.wrapAfter) + 1
	self.frame:SetSize(maximumWidth, maximumRows * (AURA_SIZE + config.paddingY))

	for _, group in ipairs(self.auraUnitGroups) do
		UpdateUnitGroupLayout(group, config)
	end

	if (config.enabled and config.enableAuraFading) then
		LFF:RegisterFrameForFading(self.frame, "playerauras")
	else
		LFF:UnregisterFrameForFading(self.frame)
		self.frame:SetAlpha(1)
	end

	local visibility
	if (not config.enabled) then
		visibility = "hide"
	elseif (config.enableModifier) then
		local modifier = string_lower(config.modifier or "SHIFT")
		-- Holding the key is an explicit request to see the header, so it is tested
		-- ahead of the target check rather than behind it. Ordered the other way the
		-- key revealed nothing at all whenever a target was selected, which is most of
		-- the time, and made the option look broken.
		visibility = "[petbattle]hide;[mod:" .. modifier .. "]show;hide"
	else
		visibility = config.ignoreTarget and "[petbattle]hide;show" or "[petbattle]hide;[@target,exists]hide;show"
	end

	-- Use the native secure visibility state instead of a custom state snippet.
	-- This keeps target/modifier changes and the /az enabled toggle authoritative.
	UnregisterStateDriver(self.frame, "visibility")
	RegisterStateDriver(self.frame, "visibility", visibility)
	self:UpdateAnchor()
end

Auras.RefreshContainers = function(self)
	for _, group in ipairs(self.auraUnitGroups or {}) do
		group.buffs:UpdateAllAuras()
		group.debuffs:UpdateAllAuras()
	end
end

Auras.RemovePrivateAuraAnchors = function(self)
	if (not C_UnitAuras or not C_UnitAuras.RemovePrivateAuraAnchor) then return end
	for _, group in ipairs(self.auraUnitGroups or {}) do
		for _, anchorID in ipairs(group.privateAuras.anchorIDs or {}) do
			API.SafeCall("Auras.RemovePrivateAuraAnchor", C_UnitAuras.RemovePrivateAuraAnchor, anchorID)
		end
		group.privateAuras.anchorIDs = {}
	end
end

Auras.OnEvent = function(self, event)
	if (event == "PLAYER_REGEN_ENABLED") then
		if (InCombatLockdown()) then return end
		if (self.needupdate) then
			self.needupdate = nil
			self:UpdateSettings()
		end
	elseif (event == "PLAYER_ENTERING_WORLD") then
		self:RefreshContainers()
		self:DisableBlizzard()
	end
end

Auras.Activate = function(self)
	if (self.activated or not self:CreateAuras()) then return false end
	self.activated = true
	self:UnregisterEvent("ADDON_LOADED")

	self:DisableBlizzard()
	self:CreateAnchor(AURAS)
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEvent")
	self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnEvent")

	ns.MovableModulePrototype.OnEnable(self)
	self:UpdateSettings()
	self:RefreshContainers()
	return true
end

Auras.OnBlizzardAuraContainerLoaded = function(self, event, addon)
	if (addon ~= "Blizzard_AuraContainer") then return end
	self:Activate()
end

Auras.OnEnable = function(self)
	if (not self:Activate()) then
		self:RegisterEvent("ADDON_LOADED", "OnBlizzardAuraContainerLoaded")
	end
end

Auras.OnDisable = function(self)
	self:RemovePrivateAuraAnchors()
	if (self.frame) then
		LFF:UnregisterFrameForFading(self.frame)
	end
end

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

ns.PlayerAuraContainers = ns.PlayerAuraContainers or {}

local Colors = ns.Colors
local GetFont = ns.API.GetFont
local GetMedia = ns.API.GetMedia
local unpack = unpack

local HELPFUL_PRIORITY_GROUP = "AzeriteHelpfulPriority"
local HELPFUL_BOSS_GROUP = "AzeriteHelpfulBoss"
local HELPFUL_STEALABLE_GROUP = "AzeriteHelpfulStealable"
local HELPFUL_PERSONAL_GROUP = "AzeriteHelpfulPersonal"
local HELPFUL_NAMEPLATE_GROUP = "AzeriteHelpfulNameplate"
local HELPFUL_SHORT_GROUP = "AzeriteHelpfulShort"
local HARMFUL_GROUP = "AzeriteHarmful"
local HELPFUL_GROUPS = {
	HELPFUL_PRIORITY_GROUP,
	HELPFUL_BOSS_GROUP,
	HELPFUL_STEALABLE_GROUP,
	HELPFUL_PERSONAL_GROUP,
	HELPFUL_NAMEPLATE_GROUP,
	HELPFUL_SHORT_GROUP
}
local BORDER_OVERHANG = 6
local PLAYER_AURA_MAX_DURATION = 300

local AuraSpells = ns.AuraData and ns.AuraData.Spells or {}
local HiddenAuras = ns.AuraData and ns.AuraData.Hidden or {}
local NonPriorityAuras = {}
for spellID in pairs(AuraSpells) do
	NonPriorityAuras[spellID] = true
end
for spellID in pairs(HiddenAuras) do
	NonPriorityAuras[spellID] = true
end

local function SetMouseInputEnabled(frame, enabled)
	frame:EnableMouse(enabled)
	if (frame.SetMouseMotionEnabled) then
		frame:SetMouseMotionEnabled(enabled)
	end
	if (frame.SetMouseClickEnabled) then
		frame:SetMouseClickEnabled(enabled)
	end
end

local function GetFlowDirection(direction, fallback)
	local directions = AnchorUtil and AnchorUtil.FlowDirection
	return directions and directions[direction] or fallback
end

local function GetSortMethod(isHarmful)
	local methods = AuraContainerSortMethod
	if (not methods) then return nil end
	if (isHarmful and methods.UnitFrameDebuff) then
		return methods.UnitFrameDebuff
	end
	return methods.ExpirationOnly or methods.Default
end

local function GetSortDirection()
	local directions = AuraContainerSortDirection
	return directions and directions.Normal
end

local function GetContainerAnchorOffset(anchor)
	local offsetX = 0
	local offsetY = 0
	if (anchor and anchor:find("LEFT", 1, true)) then
		offsetX = BORDER_OVERHANG
	elseif (anchor and anchor:find("RIGHT", 1, true)) then
		offsetX = -BORDER_OVERHANG
	end
	if (anchor and anchor:find("TOP", 1, true)) then
		offsetY = -BORDER_OVERHANG
	elseif (anchor and anchor:find("BOTTOM", 1, true)) then
		offsetY = BORDER_OVERHANG
	end
	return offsetX, offsetY
end

local function StyleDurationCooldown(button, border)
	local cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
	SetMouseInputEnabled(cooldown, false)
	cooldown:SetAllPoints(button)
	cooldown:SetDrawEdge(false)
	cooldown:SetDrawBling(false)
	cooldown:SetDrawSwipe(true)
	cooldown:SetSwipeColor(0, 0, 0, 0)
	cooldown:SetHideCountdownNumbers(false)
	if (cooldown.SetCountdownAbbrevThreshold) then
		cooldown:SetCountdownAbbrevThreshold(2)
	end
	cooldown:SetFrameLevel(border:GetFrameLevel() + 1)

	for index = 1, cooldown:GetNumRegions() do
		local region = select(index, cooldown:GetRegions())
		if (region and region.IsObjectType and region:IsObjectType("FontString")) then
			region:SetFontObject(GetFont(14, true))
			region:SetTextColor(unpack(Colors.offwhite))
			region:ClearAllPoints()
			region:SetPoint("TOPLEFT", button, "TOPLEFT", -4, 4)
		end
	end

	button.Cooldown = cooldown
	button:SetDurationCooldown(cooldown)
end

local function StyleDispelBorder(button, border)
	local style = Enum.CustomAuraButtonDispelTypeTextureStyle
	if (not style or not button.AddDispelTypeTexture) then return end

	for _, texture in ipairs(border.__AzeriteUI_BorderPieces or {}) do
		button:AddDispelTypeTexture(texture, {
			style = style.PreserveAsset,
			showWhenHarmful = true,
			showWithoutDispelType = true
		})
	end
end

local function SetAuraButtonBrightness(button, alwaysBright)
	local icon = button and button.Icon
	if (not icon) then return end

	local subdued = button.__AzeriteUI_Subdued and not alwaysBright
	icon:SetDesaturated(subdued)
	if (subdued) then
		icon:SetVertexColor(.6, .6, .6)
	else
		icon:SetVertexColor(1, 1, 1)
	end
end

local function StyleAuraButton(button, isHarmful, options, subdued, styleState)
	local size = options.size or 36
	button:SetSize(size, size)
	if (options.buttonFrameLevel) then
		button:SetFrameLevel(options.buttonFrameLevel)
	end
	SetMouseInputEnabled(button, not options.disableMouse)
	button:SetTooltipAnchorPoint(options.tooltipAnchor or "ANCHOR_TOPLEFT")
	button:SetHideTooltipInCombat(false)

	local icon = button:CreateTexture(nil, "BACKGROUND", nil, 1)
	icon:SetAllPoints(button)
	local iconMask = button:CreateMaskTexture(nil, "BACKGROUND", nil, 2)
	iconMask:SetAllPoints(button)
	iconMask:SetTexture(GetMedia("actionbutton-mask-square"))
	icon:AddMaskTexture(iconMask)
	button.Icon = icon
	button.IconMask = iconMask
	button:SetIcon(icon)
	button.__AzeriteUI_Subdued = subdued and true or false
	SetAuraButtonBrightness(button, styleState and styleState.alwaysBright)

	local border = ns.AuraStyles.CreateTextureBorder(button)
	SetMouseInputEnabled(border, false)
	border:SetPoint("TOPLEFT", -6, 6)
	border:SetPoint("BOTTOMRIGHT", 6, -6)
	border:SetFrameLevel(button:GetFrameLevel() + 2)
	button.Border = border
	if (isHarmful) then
		StyleDispelBorder(button, border)
	else
		border:SetBackdropBorderColor(unpack(Colors.verydarkgray))
	end

	local count = border:CreateFontString(nil, "OVERLAY")
	count:SetFontObject(GetFont(12, true))
	count:SetTextColor(unpack(Colors.offwhite))
	count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 3)
	button.Count = count
	button:SetApplicationCount(count)

	if (not options.disableCooldown) then
		StyleDurationCooldown(button, border)
	end

	button:SetCancelAuraButtons(isHarmful and nil or "RightButtonUp")
	-- Do not add SetScript/HookScript handlers to CustomAuraButtonTemplate.
	-- Blizzard must be able to pass secret visibility directly to SetShown().
end

local function CreateAuraContainer(parent, unit, options)
	local container = CreateFrame(
		"AuraContainer",
		nil,
		parent,
		"CustomAuraContainerTemplate, DisableUntrustedLayoutScriptsTemplate"
	)
	container:SetFrameLevel(parent:GetFrameLevel())
	SetMouseInputEnabled(container, false)
	local initialAnchor = options.initialAnchor or "BOTTOMLEFT"
	container:SetPoint(initialAnchor, parent, initialAnchor, GetContainerAnchorOffset(initialAnchor))
	container:SetUnit(unit)
	local styleState = {
		alwaysBright = options.alwaysBright and true or false
	}
	container.__AzeriteUI_StyleState = styleState

	local function CreateHelpfulOptions(layoutIndex, candidateFilters, subdued)
		return {
			initializeFrame = function(button)
				StyleAuraButton(button, false, options, subdued, styleState)
			end,
			candidateFilters = candidateFilters,
			maxFrameCount = 0,
			sortMethod = GetSortMethod(false),
			sortDirection = GetSortDirection(),
			layout = {
				elementWidth = options.size,
				elementHeight = options.size,
				layoutIndex = layoutIndex
			}
		}
	end
	local helpfulPriorityOptions = CreateHelpfulOptions(2, {
		includeSpellIDs = AuraSpells,
		excludeSpellIDs = HiddenAuras
	}, false)
	local helpfulBossOptions = CreateHelpfulOptions(3, {
		excludeSpellIDs = NonPriorityAuras,
		isBossOrRoleAura = true
	}, false)
	local helpfulStealableOptions = CreateHelpfulOptions(4, {
		excludeSpellIDs = NonPriorityAuras,
		isBossOrRoleAura = false,
		isStealable = true
	}, false)
	local helpfulPersonalOptions = CreateHelpfulOptions(5, {
		excludeSpellIDs = NonPriorityAuras,
		isBossOrRoleAura = false,
		isStealable = false,
		nameplateShowPersonal = true
	}, false)
	local helpfulNameplateOptions = CreateHelpfulOptions(6, {
		excludeSpellIDs = NonPriorityAuras,
		isBossOrRoleAura = false,
		isStealable = false,
		nameplateShowPersonal = false,
		nameplateShowAll = true
	}, false)
	local helpfulShortOptions = CreateHelpfulOptions(7, {
		excludeSpellIDs = NonPriorityAuras,
		isBossOrRoleAura = false,
		isStealable = false,
		nameplateShowPersonal = false,
		nameplateShowAll = false,
		maxDuration = PLAYER_AURA_MAX_DURATION
	}, true)
	local harmfulOptions = {
		initializeFrame = function(button)
			StyleAuraButton(button, true, options, false, styleState)
		end,
		candidateFilters = {
			excludeSpellIDs = HiddenAuras
		},
		maxFrameCount = 0,
		sortMethod = GetSortMethod(true),
		sortDirection = GetSortDirection(),
		layout = {
			elementWidth = options.size,
			elementHeight = options.size,
			layoutIndex = 1
		}
	}

	container:AddAuraGroup(HARMFUL_GROUP, "HARMFUL", harmfulOptions)
	container:AddAuraGroup(HELPFUL_PRIORITY_GROUP, "HELPFUL", helpfulPriorityOptions)
	container:AddAuraGroup(HELPFUL_BOSS_GROUP, "HELPFUL", helpfulBossOptions)
	container:AddAuraGroup(HELPFUL_STEALABLE_GROUP, "HELPFUL", helpfulStealableOptions)
	container:AddAuraGroup(HELPFUL_PERSONAL_GROUP, "HELPFUL", helpfulPersonalOptions)
	container:AddAuraGroup(HELPFUL_NAMEPLATE_GROUP, "HELPFUL", helpfulNameplateOptions)
	container:AddAuraGroup(HELPFUL_SHORT_GROUP, "HELPFUL", helpfulShortOptions)
	return container
end

local function CreateUnitVisibilityWrapper(parent, visibilityDriver, frameLevel)
	local wrapper = CreateFrame(
		"Frame",
		nil,
		parent,
		"SecureHandlerStateTemplate, DisableUntrustedLayoutScriptsTemplate"
	)
	wrapper:SetFrameLevel(frameLevel)
	SetMouseInputEnabled(wrapper, false)
	wrapper:SetAllPoints(parent)
	RegisterStateDriver(wrapper, "visibility", visibilityDriver)
	return wrapper
end

local function CopyConfiguration(config)
	return {
		size = config.size,
		spacingX = config.spacingX,
		spacingY = config.spacingY,
		initialAnchor = config.initialAnchor,
		growthX = config.growthX,
		growthY = config.growthY,
		maxBuffs = config.maxBuffs,
		maxDebuffs = config.maxDebuffs,
		useStockBehavior = config.useStockBehavior,
		alwaysBright = config.alwaysBright,
		showPriority = config.showPriority,
		showBoss = config.showBoss,
		showStealable = config.showStealable,
		showPersonal = config.showPersonal,
		showNameplate = config.showNameplate,
		showTemporary = config.showTemporary,
		showLong = config.showLong,
		maxDuration = config.maxDuration
	}
end

local function GetConfigurationSignature(config)
	return table.concat({
		tostring(config.size),
		tostring(config.spacingX),
		tostring(config.spacingY),
		tostring(config.initialAnchor),
		tostring(config.growthX),
		tostring(config.growthY),
		tostring(config.maxBuffs),
		tostring(config.maxDebuffs),
		tostring(config.useStockBehavior),
		tostring(config.alwaysBright),
		tostring(config.showPriority),
		tostring(config.showBoss),
		tostring(config.showStealable),
		tostring(config.showPersonal),
		tostring(config.showNameplate),
		tostring(config.showTemporary),
		tostring(config.showLong),
		tostring(config.maxDuration)
	}, ":")
end

local function GetBoolean(value, fallback)
	if (type(value) == "boolean") then
		return value
	end
	return fallback
end

local function UpdateContainerBrightness(container, alwaysBright)
	local styleState = container.__AzeriteUI_StyleState
	if (styleState) then
		styleState.alwaysBright = alwaysBright
	end

	for _, groupKey in ipairs(HELPFUL_GROUPS) do
		local frameCount = container:GetAuraGroupFrameCount(groupKey)
		for frameIndex = 1, frameCount do
			SetAuraButtonBrightness(container:GetAuraGroupFrame(groupKey, frameIndex), alwaysBright)
		end
	end
end

local function ApplyContainerConfiguration(container, config, width)
	local useStockBehavior = GetBoolean(config.useStockBehavior, true)
	local showPriority = useStockBehavior or GetBoolean(config.showPriority, true)
	local showBoss = useStockBehavior or GetBoolean(config.showBoss, true)
	local showStealable = useStockBehavior or GetBoolean(config.showStealable, true)
	local showPersonal = useStockBehavior or GetBoolean(config.showPersonal, true)
	local showNameplate = useStockBehavior or GetBoolean(config.showNameplate, true)
	local showTemporary = useStockBehavior or GetBoolean(config.showTemporary, true)
	local showLong = (not useStockBehavior) and GetBoolean(config.showLong, false)
	local maxDuration = type(config.maxDuration) == "number" and config.maxDuration or PLAYER_AURA_MAX_DURATION
	local shortFilters = {
		excludeSpellIDs = NonPriorityAuras,
		isBossOrRoleAura = false,
		isStealable = false,
		nameplateShowPersonal = false,
		nameplateShowAll = false,
		maxDuration = showLong and nil or maxDuration
	}
	if (showPersonal ~= showTemporary) then
		shortFilters.isFromPlayerOrPlayerPet = showPersonal
	end

	local horizontal = GetFlowDirection(config.growthX == "LEFT" and "Left" or "Right", config.growthX == "LEFT" and -1 or 1)
	local vertical = GetFlowDirection(config.growthY == "DOWN" and "Down" or "Up", config.growthY == "DOWN" and -1 or 1)
	local function CreateLayout(layoutIndex)
		return {
			elementSpacing = config.spacingX,
			lineSpacing = config.spacingY,
			groupSpacing = config.spacingX,
			groupLineSpacing = config.spacingY,
			elementWidth = config.size,
			elementHeight = config.size,
			layoutIndex = layoutIndex
		}
	end
	local harmfulLayout = {
		elementSpacing = config.spacingX,
		lineSpacing = config.spacingY,
		groupSpacing = config.spacingX,
		groupLineSpacing = config.spacingY,
		elementWidth = config.size,
		elementHeight = config.size,
		layoutIndex = 1
	}

	local offsetX, offsetY = GetContainerAnchorOffset(config.initialAnchor)
	container:ClearAllPoints()
	container:SetPoint(config.initialAnchor, container:GetParent(), config.initialAnchor, offsetX, offsetY)
	container:SetFlowLayoutAnchorPoint(config.initialAnchor)
	container:SetFlowLayoutGrowthDirection(horizontal, vertical)
	container:SetFlowLayoutMaximumLineSize(width)
	container:SetAuraGroupLayout(HARMFUL_GROUP, harmfulLayout)
	container:SetAuraGroupMaxFrameCount(HARMFUL_GROUP, config.maxDebuffs)
	for layoutIndex, groupKey in ipairs(HELPFUL_GROUPS) do
		container:SetAuraGroupLayout(groupKey, CreateLayout(layoutIndex + 1))
	end
	container:SetAuraGroupMaxFrameCount(HELPFUL_PRIORITY_GROUP, showPriority and config.maxBuffs or 0)
	container:SetAuraGroupMaxFrameCount(HELPFUL_BOSS_GROUP, showBoss and config.maxBuffs or 0)
	container:SetAuraGroupMaxFrameCount(HELPFUL_STEALABLE_GROUP, showStealable and config.maxBuffs or 0)
	container:SetAuraGroupMaxFrameCount(HELPFUL_PERSONAL_GROUP, showPersonal and config.maxBuffs or 0)
	container:SetAuraGroupMaxFrameCount(HELPFUL_NAMEPLATE_GROUP, showNameplate and config.maxBuffs or 0)
	container:SetAuraGroupCandidateFilters(HELPFUL_SHORT_GROUP, shortFilters)
	container:SetAuraGroupMaxFrameCount(HELPFUL_SHORT_GROUP, (showPersonal or showTemporary) and config.maxBuffs or 0)
	UpdateContainerBrightness(container, GetBoolean(config.alwaysBright, false))
end

local DisplayMixin = {}

function DisplayMixin:Configure(config)
	local signature = GetConfigurationSignature(config)
	if (signature == self.configurationSignature) then return end

	if (InCombatLockdown()) then
		self.pendingConfiguration = CopyConfiguration(config)
		return
	end

	local width = self:GetWidth()
	for _, container in ipairs(self.containers) do
		ApplyContainerConfiguration(container, config, width)
	end
	self.configurationSignature = signature
	self.pendingConfiguration = nil
	self:ForceUpdate()
end

function DisplayMixin:ApplyPendingConfiguration()
	if (self.pendingConfiguration and not InCombatLockdown()) then
		self:Configure(self.pendingConfiguration)
	end
end

function DisplayMixin:SetDisplayEnabled(enabled)
	enabled = enabled and true or false
	self.displayEnabled = enabled
	for _, container in ipairs(self.containers) do
		container:SetEnabled(enabled)
	end

	if (InCombatLockdown()) then
		self.pendingShownState = enabled
		self:SetAlpha(enabled and 1 or 0)
		return
	end

	self.pendingShownState = nil
	self:SetAlpha(1)
	self:SetShown(enabled)
end

function DisplayMixin:ApplyPendingShownState()
	if (self.pendingShownState ~= nil and not InCombatLockdown()) then
		self:SetDisplayEnabled(self.pendingShownState)
	end
end

function DisplayMixin:ForceUpdate()
	for _, container in ipairs(self.containers) do
		container:UpdateAllAuras()
	end
end

local function BuildDisplayConfig(options)
	return {
		size = options.size,
		spacingX = options.spacingX or options.spacing or 0,
		spacingY = options.spacingY or options.spacing or 0,
		initialAnchor = options.initialAnchor or "BOTTOMLEFT",
		growthX = options.growthX or "RIGHT",
		growthY = options.growthY or "UP",
		maxBuffs = options.maxBuffs or 0,
		maxDebuffs = options.maxDebuffs or 0,
		useStockBehavior = options.useStockBehavior,
		alwaysBright = options.alwaysBright,
		showPriority = options.showPriority,
		showBoss = options.showBoss,
		showStealable = options.showStealable,
		showPersonal = options.showPersonal,
		showNameplate = options.showNameplate,
		showTemporary = options.showTemporary,
		showLong = options.showLong,
		maxDuration = options.maxDuration
	}
end

ns.PlayerAuraContainers.Create = function(parent, options)
	if (not C_XMLUtil or not C_XMLUtil.GetTemplateInfo or not C_XMLUtil.GetTemplateInfo("CustomAuraContainerTemplate")) then
		return nil
	end
	if (not AuraContainerSortMethod or not AuraContainerSortDirection or not AnchorUtil) then
		return nil
	end

	-- Keep the native buttons on one bounded player-child level. This is high
	-- enough for aura input to beat the player unit button without promoting the
	-- row above the player's complete child hierarchy.
	local displayFrameLevel = parent:GetFrameLevel() + 1
	options.buttonFrameLevel = displayFrameLevel
	local display = CreateFrame("Frame", nil, parent, "DisableUntrustedLayoutScriptsTemplate")
	SetMouseInputEnabled(display, false)
	display:SetSize(options.width, options.height)
	display:SetFrameLevel(displayFrameLevel)
	local clipFrame = CreateFrame("Frame", nil, display, "DisableUntrustedLayoutScriptsTemplate")
	SetMouseInputEnabled(clipFrame, false)
	clipFrame:SetFrameLevel(display:GetFrameLevel())
	clipFrame:SetPoint("TOPLEFT", display, "TOPLEFT", -BORDER_OVERHANG, BORDER_OVERHANG)
	clipFrame:SetPoint("BOTTOMRIGHT", display, "BOTTOMRIGHT", BORDER_OVERHANG, -BORDER_OVERHANG)
	clipFrame:SetClipsChildren(true)
	display.clipFrame = clipFrame

	display.playerWrapper = CreateUnitVisibilityWrapper(clipFrame, "[vehicleui]hide;show", displayFrameLevel)
	display.vehicleWrapper = CreateUnitVisibilityWrapper(clipFrame, "[vehicleui]show;hide", displayFrameLevel)
	display.playerContainer = CreateAuraContainer(display.playerWrapper, "player", options)
	display.vehicleContainer = CreateAuraContainer(display.vehicleWrapper, "vehicle", options)
	display.containers = { display.playerContainer, display.vehicleContainer }

	Mixin(display, DisplayMixin)
	display:Configure(BuildDisplayConfig(options))
	return display
end

-- Single-unit variant of Create. The player display swaps between a player and a
-- vehicle row behind a state driver; every other unit needs exactly one container,
-- so this reuses all the styling, filtering and layout code without that machinery.
-- Native containers are rendered engine side, which is the only aura path that
-- still returns data while in combat on Retail 12.1.
ns.PlayerAuraContainers.CreateForUnit = function(parent, unit, options)
	if (not C_XMLUtil or not C_XMLUtil.GetTemplateInfo or not C_XMLUtil.GetTemplateInfo("CustomAuraContainerTemplate")) then
		return nil
	end
	if (not AuraContainerSortMethod or not AuraContainerSortDirection or not AnchorUtil) then
		return nil
	end

	local displayFrameLevel = parent:GetFrameLevel() + 1
	options.buttonFrameLevel = displayFrameLevel

	local display = CreateFrame("Frame", nil, parent, "DisableUntrustedLayoutScriptsTemplate")
	SetMouseInputEnabled(display, false)
	display:SetSize(options.width, options.height)
	display:SetFrameLevel(displayFrameLevel)

	local clipFrame = CreateFrame("Frame", nil, display, "DisableUntrustedLayoutScriptsTemplate")
	SetMouseInputEnabled(clipFrame, false)
	clipFrame:SetFrameLevel(display:GetFrameLevel())
	clipFrame:SetPoint("TOPLEFT", display, "TOPLEFT", -BORDER_OVERHANG, BORDER_OVERHANG)
	clipFrame:SetPoint("BOTTOMRIGHT", display, "BOTTOMRIGHT", BORDER_OVERHANG, -BORDER_OVERHANG)
	clipFrame:SetClipsChildren(true)
	display.clipFrame = clipFrame

	display.container = CreateAuraContainer(clipFrame, unit, options)
	display.containers = { display.container }
	display.unit = unit

	Mixin(display, DisplayMixin)
	display:Configure(BuildDisplayConfig(options))
	return display
end

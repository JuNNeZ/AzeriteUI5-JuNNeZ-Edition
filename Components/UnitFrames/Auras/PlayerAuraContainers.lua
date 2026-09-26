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

ns.PlayerAuraContainers = ns.PlayerAuraContainers or {}

local Colors = ns.Colors
local GetFont = ns.API.GetFont
local GetMedia = ns.API.GetMedia
local IsSafeBool = ns.API.IsSafeBool
local TryCall = ns.API.TryCall
local type = type
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

-- Every group key the containers below register, exported so tooling walks the
-- real list instead of keeping its own. Core/Debugging.lua kept a private copy
-- naming a single "AzeriteHelpful" group, which stopped existing when the
-- helpful side was split into six, and its aura snapshot silently dumped only
-- harmful buttons from then on. Do not re-fork this.
ns.PlayerAuraContainers.GroupKeys = {
	HARMFUL_GROUP,
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

-- The countdown's colour as it runs out: white until the last 30 seconds, then yellow at
-- ten, orange at three and red at the end. Blizzard's duration text binding evaluates the
-- curve against the remaining time itself (Blizzard_CustomAuraButton.lua, SetDurationText),
-- so the time, which may be secret, never reaches our code. Built once, shared by every
-- button; nil on a client without colour curves or duration text bindings.
local timerColorOptions
do
	local curveUtil = C_CurveUtil
	local property = Enum.DurationTextBindingProperty and Enum.DurationTextBindingProperty.RemainingDuration
	local linear = Enum.LuaCurveType and Enum.LuaCurveType.Linear
	if (curveUtil and curveUtil.CreateColorCurve and property and linear) then
		local curve = curveUtil.CreateColorCurve()
		curve:SetType(linear)
		local AddPoint = function(seconds, color)
			curve:AddPoint(seconds, { r = color[1], g = color[2], b = color[3], a = 1 })
		end
		AddPoint(0, Colors.quest.red)
		AddPoint(3, Colors.quest.orange)
		AddPoint(10, Colors.quest.yellow)
		AddPoint(30, Colors.offwhite)
		timerColorOptions = { textColor = { curve = curve, property = property } }
	end
end

local function StyleDurationText(button, border)
	local time = border:CreateFontString(nil, "OVERLAY")
	time:SetFontObject(GetFont(14, true))
	time:SetPoint("TOPLEFT", button, "TOPLEFT", -4, 4)
	time:SetJustifyH("LEFT")
	time:SetWordWrap(false)
	time:SetFixedColor(false)

	local ok = TryCall(button.SetDurationText, button, time, timerColorOptions)
	if (not ok) then
		time:Hide()
		return false
	end
	button.Time = time
	return true
end

local function StyleDurationCooldown(button, border)
	if (timerColorOptions and type(button.SetDurationText) == "function" and StyleDurationText(button, border)) then
		return
	end

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

--[[
	Aura buttons and every region parented to them carry Blizzard's
	DenyTaintedAccessWhenAurasAreSecret access restriction, applied by the frame
	provider the moment our initializeFrame callback returns. Wherever aura data
	is secret -- raid instances, most notably -- any method we call on one of
	them from our own tainted code raises a forbidden object error.

	Reading plain fields off the button stays legal, so only the widget we call
	methods on has to be checked. A failing probe counts as "do not touch",
	which is the safe answer either way.
]]
local function AuraDataIsSecret()
	local shouldAurasBeSecret = C_Secrets and C_Secrets.ShouldAurasBeSecret
	if (type(shouldAurasBeSecret) ~= "function") then
		-- No secret system on this build, so nothing enforces the restriction.
		return false
	end

	local ok, isSecret = TryCall(shouldAurasBeSecret)
	if (ok and IsSafeBool(isSecret)) then
		return isSecret
	end
	return true
end

-- actionbutton-spellhighlight-square's solid ring spans 132 of its 256 pixels and the
-- square icon mask shows 54 of 64, so this puts the ring on the icon's edge and lets
-- the glow spill a few pixels past the button.
local PANDEMIC_EDGE_SCALE = (54 / 64) / (132 / 256)

local function SizePandemicEdge(edge, size)
	local edgeSize = size * PANDEMIC_EDGE_SCALE
	edge:SetSize(edgeSize, edgeSize)
end

-- Lights the button's edge for the pandemic window: the last stretch of an aura in
-- which recasting it loses nothing. Blizzard's button works the window out from the
-- aura's base and refresh-extended durations and owns the region's shown state from
-- here on (Blizzard_CustomAuraButton.lua, AddPandemicRegion), so no aura data passes
-- through our code. Auras that cannot be extended never show it.
local function AddPandemicEdge(button, border, size)
	if (type(button.AddPandemicRegion) ~= "function") then return end

	local edge = border:CreateTexture(nil, "ARTWORK")
	edge:SetTexture(GetMedia("actionbutton-spellhighlight-square"))
	edge:SetVertexColor(unpack(Colors.title))
	edge:SetPoint("CENTER", button, "CENTER", 0, 0)
	SizePandemicEdge(edge, size)
	edge:Hide()

	local ok = TryCall(button.AddPandemicRegion, button, edge)
	if (ok) then
		button.PandemicEdge = edge
	end
end

local function CanTouchAuraWidget(widget)
	if (not widget) then return false end

	local canBeAccessed = widget.CanBeAccessedInContext
	if (type(canBeAccessed) ~= "function") then
		-- A build without the per-object query. The global answer is coarser --
		-- it cannot see a restriction that was never applied to this widget --
		-- but it errs in the same direction, which beats assuming access.
		return not AuraDataIsSecret()
	end

	local ok, accessible = TryCall(canBeAccessed, widget)
	return ok and IsSafeBool(accessible) and accessible
end

local function SetAuraButtonBrightness(button, alwaysBright)
	local icon = button and button.Icon
	if (not CanTouchAuraWidget(icon)) then return end

	local subdued = button.__AzeriteUI_Subdued and not alwaysBright
	icon:SetDesaturated(subdued)
	if (subdued) then
		icon:SetVertexColor(.6, .6, .6)
	else
		icon:SetVertexColor(1, 1, 1)
	end
end

local function StyleAuraButton(button, isHarmful, options, subdued, styleState)
	-- Group frame containers size debuffs apart from buffs and change both at runtime,
	-- so they keep the current sizes on the style state. Every other display leaves
	-- those unset and keeps using the size it was created with.
	local stateSize = styleState and (isHarmful and styleState.harmfulSize or styleState.helpfulSize)
	local size = stateSize or options.size or 36
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

	AddPandemicEdge(button, border, size)

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

-- The style state is what every button created from here on reads in
-- initializeFrame, so it has to be updated even where the live buttons below
-- turn out to be untouchable. Where aura data is secret the existing pooled
-- buttons keep the brightness they were created with; that is a cosmetic lag,
-- and the alternative is a forbidden object error on every configuration pass.
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

-- AddAuraGroup and SetAuraGroupFilterString assert on a filter string the client does
-- not understand, so anything built from newer tokens or negation is checked first.
local function IsUsableFilterString(filterString)
	local validate = AuraUtil and AuraUtil.IsValidFilterString
	if (type(validate) ~= "function") then
		return false
	end
	local ok, isValid = TryCall(validate, filterString)
	return ok and isValid == true
end

-- "Player / Self Buffs" means cast by you or your pet and "Other Temporary Buffs" means
-- everything else, which is exactly the PLAYER filter token. The isFromPlayerOrPlayerPet
-- aura field this used to read means cast by any player, so it passed other players'
-- buffs off as yours and kept them out of "other". Both on, or both off, needs no split.
-- A client without negation shows both rather than hiding the other side.
local function GetShortGroupFilterString(showPersonal, showTemporary)
	if (showPersonal and not showTemporary) then
		return "HELPFUL|PLAYER"
	elseif (showTemporary and not showPersonal and IsUsableFilterString("HELPFUL|!PLAYER")) then
		return "HELPFUL|!PLAYER"
	end
	return "HELPFUL"
end

--[[
	Anchors, per-group layouts and the short-buff filter string and candidate
	filters are pure functions of these fields. Everything else in a configuration -- the frame
	counts and the container width -- moves independently, and on the target
	frame it moves constantly: a boss carries AurasSizeBoss and AurasNumTotalBoss
	while everything else carries the plain pair, so swapping between a boss and
	any other target re-entered the whole pass on every retarget.

	That was not merely redundant. SetAuraGroupLayout marks the container dirty
	with no equality check of its own, and SetAuraGroupCandidateFilters runs a
	synchronous UpdateAllAuras every single call, so re-applying an identical
	configuration cost seven dirty layout groups and a full aura re-evaluation
	per container. The counts and the three flow-layout setters all compare
	before they act, so they stay outside the gate where they belong.
]]
local function GetContainerLayoutSignature(config)
	return table.concat({
		tostring(config.size),
		tostring(config.spacingX),
		tostring(config.spacingY),
		tostring(config.initialAnchor),
		tostring(config.growthX),
		tostring(config.growthY),
		tostring(config.useStockBehavior),
		tostring(config.showPersonal),
		tostring(config.showTemporary),
		tostring(config.showLong),
		tostring(config.maxDuration)
	}, ":")
end

local function ApplyContainerLayout(container, config)
	local useStockBehavior = GetBoolean(config.useStockBehavior, true)
	local showPersonal = useStockBehavior or GetBoolean(config.showPersonal, true)
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

	local offsetX, offsetY = GetContainerAnchorOffset(config.initialAnchor)
	container:ClearAllPoints()
	container:SetPoint(config.initialAnchor, container:GetParent(), config.initialAnchor, offsetX, offsetY)
	container:SetFlowLayoutAnchorPoint(config.initialAnchor)
	container:SetFlowLayoutGrowthDirection(horizontal, vertical)
	container:SetAuraGroupLayout(HARMFUL_GROUP, CreateLayout(1))
	for layoutIndex, groupKey in ipairs(HELPFUL_GROUPS) do
		container:SetAuraGroupLayout(groupKey, CreateLayout(layoutIndex + 1))
	end
	-- Compares before it acts.
	container:SetAuraGroupFilterString(HELPFUL_SHORT_GROUP, GetShortGroupFilterString(showPersonal, showTemporary))
	container:SetAuraGroupCandidateFilters(HELPFUL_SHORT_GROUP, shortFilters)
end

local function ApplyContainerConfiguration(container, config, width)
	local layoutSignature = GetContainerLayoutSignature(config)
	if (container.__AzeriteUI_LayoutSignature ~= layoutSignature) then
		ApplyContainerLayout(container, config)
		container.__AzeriteUI_LayoutSignature = layoutSignature
	end

	local useStockBehavior = GetBoolean(config.useStockBehavior, true)
	local showPriority = useStockBehavior or GetBoolean(config.showPriority, true)
	local showBoss = useStockBehavior or GetBoolean(config.showBoss, true)
	local showStealable = useStockBehavior or GetBoolean(config.showStealable, true)
	local showPersonal = useStockBehavior or GetBoolean(config.showPersonal, true)
	local showNameplate = useStockBehavior or GetBoolean(config.showNameplate, true)
	local showTemporary = useStockBehavior or GetBoolean(config.showTemporary, true)

	container:SetFlowLayoutMaximumLineSize(width)
	container:SetAuraGroupMaxFrameCount(HARMFUL_GROUP, config.maxDebuffs)
	container:SetAuraGroupMaxFrameCount(HELPFUL_PRIORITY_GROUP, showPriority and config.maxBuffs or 0)
	container:SetAuraGroupMaxFrameCount(HELPFUL_BOSS_GROUP, showBoss and config.maxBuffs or 0)
	container:SetAuraGroupMaxFrameCount(HELPFUL_STEALABLE_GROUP, showStealable and config.maxBuffs or 0)
	container:SetAuraGroupMaxFrameCount(HELPFUL_PERSONAL_GROUP, showPersonal and config.maxBuffs or 0)
	container:SetAuraGroupMaxFrameCount(HELPFUL_NAMEPLATE_GROUP, showNameplate and config.maxBuffs or 0)
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

--[[
	Party and raid frames.

	The player rows above sort auras by nameplate flags, which say little about a group
	member. These groups sort with AuraUtil.ProcessAura instead, the classification
	Blizzard's own raid frames are built on. The container runs it through its
	ProcessAura policy inside Blizzard's environment, so it keeps working in combat,
	where a Lua scan of C_UnitAuras comes back empty. That is what keeps a Restoration
	Druid's Rejuvenation, Regrowth and Lifebloom on a party frame mid fight: ProcessAura
	files them as Buff (cast by the player, castable on the unit, not a self-buff).

	ProcessAura gives each aura exactly one class, so the ProcessAura groups never share
	an aura. The two token groups stay off the boss groups through isBossOrRoleAura, and
	off the player's own group through a negated PLAYER token while that group shows;
	the raid-flagged group also leaves externals to theirs. PLAYER has to be a token: the
	isFromPlayerOrPlayerPet aura field means cast by any player, which is how Blizzard's
	TargetFrameAuraContainer reads it, and GW2_UI and VuhDo split on the token for the
	same reason. Without negation support an aura can land in two groups, never in none.

	Groups draw in the order listed. The display clips whatever does not fit, so the
	player's own buffs come first and the least specific categories fall off the end.
]]
local GROUP_HELPFUL_OWN = "AzeriteGroupHelpfulOwn"
local GROUP_HARMFUL_DISPEL = "AzeriteGroupHarmfulDispel"
local GROUP_HARMFUL_BOSS = "AzeriteGroupHarmfulBoss"
local GROUP_HELPFUL_BOSS = "AzeriteGroupHelpfulBoss"
local GROUP_HARMFUL_OTHER = "AzeriteGroupHarmfulOther"
local GROUP_HELPFUL_EXTERNAL = "AzeriteGroupHelpfulExternal"
local GROUP_HELPFUL_RAID = "AzeriteGroupHelpfulRaid"

local EXTERNAL_GROUP_FILTER = "HELPFUL|EXTERNAL_DEFENSIVE"
local RAID_GROUP_FILTER = "HELPFUL|RAID_IN_COMBAT"

local GROUP_FRAME_AURA_GROUPS = {
	{ key = GROUP_HELPFUL_OWN, filter = "HELPFUL", isHarmful = false, shownField = "showOwn" },
	{ key = GROUP_HARMFUL_DISPEL, filter = "HARMFUL", isHarmful = true, shownField = "showDispel" },
	{ key = GROUP_HARMFUL_BOSS, filter = "HARMFUL", isHarmful = true, shownField = "showBoss" },
	{ key = GROUP_HELPFUL_BOSS, filter = "HELPFUL", isHarmful = false, shownField = "showBoss" },
	{ key = GROUP_HARMFUL_OTHER, filter = "HARMFUL", isHarmful = true, shownField = "showOther" },
	{ key = GROUP_HELPFUL_EXTERNAL, filter = EXTERNAL_GROUP_FILTER, isHarmful = false, shownField = "showExternal" },
	{ key = GROUP_HELPFUL_RAID, filter = RAID_GROUP_FILTER, isHarmful = false, shownField = "showRaid" }
}

-- Named keys for callers that create only some of the groups, and the ordered list
-- for tooling, for the same reason GroupKeys is exported above.
ns.PlayerAuraContainers.GroupFrameGroup = {
	HelpfulOwn = GROUP_HELPFUL_OWN,
	HarmfulDispel = GROUP_HARMFUL_DISPEL,
	HarmfulBoss = GROUP_HARMFUL_BOSS,
	HelpfulBoss = GROUP_HELPFUL_BOSS,
	HarmfulOther = GROUP_HARMFUL_OTHER,
	HelpfulExternal = GROUP_HELPFUL_EXTERNAL,
	HelpfulRaid = GROUP_HELPFUL_RAID
}
ns.PlayerAuraContainers.GroupFrameKeys = {}
for index, group in ipairs(GROUP_FRAME_AURA_GROUPS) do
	ns.PlayerAuraContainers.GroupFrameKeys[index] = group.key
end

local GROUP_FRAME_CONFIG_FIELDS = {
	"size", "harmfulSize", "spacingX", "spacingY", "initialAnchor", "growthX", "growthY", "maxAuras",
	"showOwn", "ownMaxDuration", "showDispel", "showBoss", "showOther", "otherMaxDuration",
	"onlyDispellable", "showExternal", "showRaid"
}

local function GetProcessedAuraTypes()
	local auraTypes = AuraUtil and AuraUtil.AuraUpdateChangedType
	if (type(auraTypes) ~= "table" or not auraTypes.Buff or not auraTypes.Debuff or not auraTypes.Dispel) then
		return nil
	end
	return auraTypes
end

-- Appends negated tokens to a filter string, if the client understands the result.
local function WithExcludedTokens(filterString, ...)
	local excluded = filterString
	for index = 1, select("#", ...) do
		local token = select(index, ...)
		if (token) then
			excluded = excluded .. "|!" .. token
		end
	end
	if (excluded ~= filterString and IsUsableFilterString(excluded)) then
		return excluded
	end
	return filterString
end

local function GetGroupFilterString(group, config)
	local ownToken = config.showOwn and "PLAYER" or nil
	if (group.key == GROUP_HELPFUL_EXTERNAL) then
		return WithExcludedTokens(EXTERNAL_GROUP_FILTER, ownToken)
	elseif (group.key == GROUP_HELPFUL_RAID) then
		return WithExcludedTokens(RAID_GROUP_FILTER, ownToken, config.showExternal and "EXTERNAL_DEFENSIVE" or nil)
	end
	return group.filter
end

local function GetGroupFrameCandidateFilters(groupKey, config, auraTypes)
	if (groupKey == GROUP_HELPFUL_OWN) then
		return {
			processedAuraType = auraTypes.Buff,
			excludeSpellIDs = HiddenAuras,
			maxDuration = config.ownMaxDuration
		}
	elseif (groupKey == GROUP_HARMFUL_DISPEL) then
		return {
			processedAuraType = auraTypes.Dispel
		}
	elseif (groupKey == GROUP_HARMFUL_BOSS or groupKey == GROUP_HELPFUL_BOSS) then
		-- ProcessAura files boss and role auras as Debuff whichever way they point.
		return {
			processedAuraType = auraTypes.Debuff,
			isBossOrRoleAura = true
		}
	elseif (groupKey == GROUP_HARMFUL_OTHER) then
		return {
			processedAuraType = auraTypes.Debuff,
			isBossOrRoleAura = false,
			maxDuration = config.otherMaxDuration
		}
	end

	-- Externals and raid-flagged buffs. Whose buffs these take is settled in the
	-- filter string, see GetGroupFilterString.
	return {
		excludeSpellIDs = HiddenAuras,
		isBossOrRoleAura = false
	}
end

-- Spell ID sets are static, so they are left out.
local function GetCandidateFilterSignature(filters)
	return table.concat({
		tostring(filters.processedAuraType),
		tostring(filters.maxDuration),
		tostring(filters.isBossOrRoleAura)
	}, ":")
end

local function GetGroupFrameConfigSignature(config)
	local parts = {}
	for index, field in ipairs(GROUP_FRAME_CONFIG_FIELDS) do
		parts[index] = tostring(config[field])
	end
	return table.concat(parts, ":")
end

local function BuildGroupFrameConfig(options)
	local size = options.size or 30
	return {
		size = size,
		harmfulSize = options.harmfulSize or size,
		spacingX = options.spacingX or options.spacing or 0,
		spacingY = options.spacingY or options.spacing or 0,
		initialAnchor = options.initialAnchor or "TOPLEFT",
		growthX = options.growthX or "RIGHT",
		growthY = options.growthY or "DOWN",
		maxAuras = options.maxAuras or 0,
		showOwn = options.showOwn ~= false,
		ownMaxDuration = options.ownMaxDuration,
		showDispel = options.showDispel ~= false,
		showBoss = options.showBoss ~= false,
		showOther = options.showOther ~= false,
		otherMaxDuration = options.otherMaxDuration,
		onlyDispellable = options.onlyDispellable == true,
		showExternal = options.showExternal ~= false,
		showRaid = options.showRaid ~= false
	}
end
ns.PlayerAuraContainers.BuildGroupFrameConfig = BuildGroupFrameConfig

local function ResizeGroupFrames(container, groupKey, size)
	local sizes = container.__AzeriteUI_GroupFrameSizes
	if (sizes[groupKey] == size) then return end
	sizes[groupKey] = size

	-- Pooled buttons carry the same access restriction as the player rows once aura
	-- data is secret, and keep their old size there. New buttons read the size from
	-- the style state either way.
	for frameIndex = 1, container:GetAuraGroupFrameCount(groupKey) do
		local button = container:GetAuraGroupFrame(groupKey, frameIndex)
		if (CanTouchAuraWidget(button)) then
			button:SetSize(size, size)
			if (CanTouchAuraWidget(button.PandemicEdge)) then
				SizePandemicEdge(button.PandemicEdge, size)
			end
		end
	end
end

local function ApplyGroupFrameConfiguration(container, config, width)
	local onlyDispellable = config.onlyDispellable and true or false
	if (container.__AzeriteUI_OnlyDispellable ~= onlyDispellable) then
		container:SetAuraProcessingPolicy(CustomAuraContainerAuraProcessingPolicy.ProcessAura, {
			displayOnlyDispellableDebuffs = onlyDispellable
		})
		container.__AzeriteUI_OnlyDispellable = onlyDispellable
	end

	local styleState = container.__AzeriteUI_StyleState
	styleState.helpfulSize = config.size
	styleState.harmfulSize = config.harmfulSize

	local horizontal = GetFlowDirection(config.growthX == "LEFT" and "Left" or "Right", config.growthX == "LEFT" and -1 or 1)
	local vertical = GetFlowDirection(config.growthY == "DOWN" and "Down" or "Up", config.growthY == "DOWN" and -1 or 1)
	local offsetX, offsetY = GetContainerAnchorOffset(config.initialAnchor)
	container:ClearAllPoints()
	container:SetPoint(config.initialAnchor, container:GetParent(), config.initialAnchor, offsetX, offsetY)
	container:SetFlowLayoutAnchorPoint(config.initialAnchor)
	container:SetFlowLayoutGrowthDirection(horizontal, vertical)
	container:SetFlowLayoutMaximumLineSize(width)

	local auraTypes = GetProcessedAuraTypes()
	for layoutIndex, group in ipairs(GROUP_FRAME_AURA_GROUPS) do
		local groupKey = group.key
		if (container.__AzeriteUI_GroupKeys[groupKey]) then
			local size = group.isHarmful and config.harmfulSize or config.size
			container:SetAuraGroupLayout(groupKey, {
				elementSpacing = config.spacingX,
				lineSpacing = config.spacingY,
				groupSpacing = config.spacingX,
				groupLineSpacing = config.spacingY,
				elementWidth = size,
				elementHeight = size,
				layoutIndex = layoutIndex
			})

			-- Compares before it acts.
			container:SetAuraGroupFilterString(groupKey, GetGroupFilterString(group, config))

			-- Does not compare, and rebuilds the container on every call.
			local filters = GetGroupFrameCandidateFilters(groupKey, config, auraTypes)
			local filterSignature = GetCandidateFilterSignature(filters)
			if (container.__AzeriteUI_FilterSignatures[groupKey] ~= filterSignature) then
				container:SetAuraGroupCandidateFilters(groupKey, filters)
				container.__AzeriteUI_FilterSignatures[groupKey] = filterSignature
			end

			container:SetAuraGroupMaxFrameCount(groupKey, config[group.shownField] and config.maxAuras or 0)
			ResizeGroupFrames(container, groupKey, size)
		end
	end
end

local function CreateGroupAuraContainer(parent, options, config)
	local container = CreateFrame(
		"AuraContainer",
		nil,
		parent,
		"CustomAuraContainerTemplate, DisableUntrustedLayoutScriptsTemplate"
	)
	container:SetFrameLevel(parent:GetFrameLevel())
	SetMouseInputEnabled(container, false)
	container:SetPoint(config.initialAnchor, parent, config.initialAnchor, GetContainerAnchorOffset(config.initialAnchor))

	local styleState = {
		alwaysBright = true,
		helpfulSize = config.size,
		harmfulSize = config.harmfulSize
	}
	container.__AzeriteUI_StyleState = styleState
	container.__AzeriteUI_GroupKeys = {}
	container.__AzeriteUI_FilterSignatures = {}
	container.__AzeriteUI_GroupFrameSizes = {}

	container:SetAuraProcessingPolicy(CustomAuraContainerAuraProcessingPolicy.ProcessAura, {
		displayOnlyDispellableDebuffs = config.onlyDispellable
	})
	container.__AzeriteUI_OnlyDispellable = config.onlyDispellable

	local auraTypes = GetProcessedAuraTypes()
	for layoutIndex, group in ipairs(GROUP_FRAME_AURA_GROUPS) do
		local groupKey = group.key
		if (not options.groupKeys or options.groupKeys[groupKey]) then
			local isHarmful = group.isHarmful
			local size = isHarmful and config.harmfulSize or config.size
			local filters = GetGroupFrameCandidateFilters(groupKey, config, auraTypes)
			container:AddAuraGroup(groupKey, GetGroupFilterString(group, config), {
				initializeFrame = function(button)
					StyleAuraButton(button, isHarmful, options, false, styleState)
				end,
				candidateFilters = filters,
				-- Frame counts come from the first configuration pass.
				maxFrameCount = 0,
				sortMethod = GetSortMethod(isHarmful),
				sortDirection = GetSortDirection(),
				layout = {
					elementWidth = size,
					elementHeight = size,
					layoutIndex = layoutIndex
				}
			})
			container.__AzeriteUI_GroupKeys[groupKey] = true
			container.__AzeriteUI_FilterSignatures[groupKey] = GetCandidateFilterSignature(filters)
			container.__AzeriteUI_GroupFrameSizes[groupKey] = size
		end
	end

	return container
end

local function IsGroupFrameUnitToken(unit)
	if (type(unit) ~= "string") then
		return false
	end
	return unit == "player" or unit == "pet" or unit == "vehicle"
		or unit:match("^party%d$") ~= nil or unit:match("^partypet%d$") ~= nil
		or unit:match("^raid%d+$") ~= nil or unit:match("^raidpet%d+$") ~= nil
end

local GroupDisplayMixin = CreateFromMixins(DisplayMixin)

function GroupDisplayMixin:Configure(config)
	local signature = GetGroupFrameConfigSignature(config)
	if (signature == self.configurationSignature) then return end

	-- Unlike the player rows, nothing in this pass is protected. The display, its clip
	-- frame and the container are plain frames and every container setter is part of
	-- Blizzard's inbound interface, so an option change, or a relayout from a roster
	-- update during a fight, applies at once instead of waiting for combat to end.
	ApplyGroupFrameConfiguration(self.container, config, self:GetWidth())
	self.configurationSignature = signature
	self:ForceUpdate()
end

-- Returns true when the container was pointed at a new unit, which rebuilds it.
function GroupDisplayMixin:SetDisplayUnit(unit)
	if (not IsGroupFrameUnitToken(unit) or unit == self.unit) then
		return false
	end
	self.unit = unit
	self.container:SetUnit(unit)
	self.container:SetEnabled(self.displayEnabled == true)
	return true
end

function GroupDisplayMixin:SetDisplayEnabled(enabled)
	enabled = enabled and true or false
	self.displayEnabled = enabled

	-- An enabled container registers UNIT_AURA for its unit, and a header button is
	-- styled before the header hands it one. Stay disabled until a real unit arrives.
	self.container:SetEnabled(enabled and self.unit ~= nil)

	if (InCombatLockdown()) then
		self.pendingShownState = enabled
		self:SetAlpha(enabled and 1 or 0)
		return
	end

	self.pendingShownState = nil
	self:SetAlpha(1)
	self:SetShown(enabled)
end

-- Party and raid variant of CreateForUnit. Returns nil where the client lacks the
-- container, ProcessAura classification or the filter tokens the groups rely on, and
-- the caller keeps its scanning element in that case.
ns.PlayerAuraContainers.CreateForGroupUnit = function(parent, unit, options)
	if (not C_XMLUtil or not C_XMLUtil.GetTemplateInfo or not C_XMLUtil.GetTemplateInfo("CustomAuraContainerTemplate")) then
		return nil
	end
	if (not AuraContainerSortMethod or not AuraContainerSortDirection or not AnchorUtil) then
		return nil
	end
	local policies = CustomAuraContainerAuraProcessingPolicy
	if (not policies or not policies.ProcessAura or not GetProcessedAuraTypes()
		or not IsUsableFilterString(EXTERNAL_GROUP_FILTER) or not IsUsableFilterString(RAID_GROUP_FILTER)) then
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

	local config = BuildGroupFrameConfig(options)
	display.container = CreateGroupAuraContainer(clipFrame, options, config)
	display.containers = { display.container }

	Mixin(display, GroupDisplayMixin)
	display:SetDisplayUnit(unit)
	display:Configure(config)
	return display
end

-- Called from a group frame's PostUpdate. oUF runs that after every full element
-- update, which is where a header button first learns its unit and where a roster
-- change that handed its token to another player surfaces.
ns.PlayerAuraContainers.UpdateGroupFrameUnit = function(frame, event)
	local native = frame and frame.NativeAuras
	if (not native or not native.SetDisplayUnit) then
		return
	end
	if (native:SetDisplayUnit(frame.unit)) then
		return
	end
	if (event) then
		native:ForceUpdate()
	end
end

--[[
	Nameplates.

	The plates drew their auras through the oUF element, which scans C_UnitAuras from
	Lua, and Retail 12.1 gives addon code no aura data at all in combat: a plate's auras
	went the moment a pull began and did not come back until it ended (FixLog.md,
	2026-08-18 and 2026-09-24). This container is filled engine side and keeps going.
	Plater's 12.x build draws its plate auras the same way.

	What a plate shows is chosen by kind, each kind a group the player can switch off
	(Nameplates options, Aura filters). They draw in this order, and the display clips
	whatever does not fit, so the kinds that matter most come first:

	  crowd control          HARMFUL|CROWD_CONTROL, from anyone
	  your debuffs           HARMFUL|PLAYER; optionally only the ones Blizzard's own
	                         plates show (nameplateShowPersonal)
	  debuffs from others    HARMFUL|!PLAYER, flagged to show on every nameplate
	  buffs you can dispel   HELPFUL|RAID_PLAYER_DISPELLABLE: purge, spellsteal, soothe
	  important buffs        HELPFUL|IMPORTANT, Blizzard's own pick for enemy plates
	  your short buffs       HELPFUL|PLAYER, 30 seconds or less

	Groups do not share an aura, so each leaves out, with a negated token, what an earlier
	group that is switched on already shows. Without negation a group keeps its plain
	filter, where an aura can show twice but never goes missing; debuffs from others cannot
	be told from your own without it, and that group is left out instead.

	Every group creates its first ten buttons up front (FrameCreationBatchSize in
	Blizzard_AuraContainerShared.lua). So a plate builds its container the first time it
	has auras to show rather than when it is styled, and adds a group the first time that
	kind is switched on. A group switched off keeps its buttons and shows none.
]]
local PLATE_OWN_BUFF_MAX_DURATION = 30

local NAMEPLATE_AURA_GROUPS = {
	{
		key = "AzeritePlateCrowdControl", shownField = "showCrowdControl", isHarmful = true,
		filter = "HARMFUL|CROWD_CONTROL|INCLUDE_NAME_PLATE_ONLY",
		candidates = function(config) return { excludeSpellIDs = HiddenAuras } end
	},
	{
		key = "AzeritePlateHarmfulOwn", shownField = "showOwnDebuffs", isHarmful = true,
		filter = "HARMFUL|PLAYER|INCLUDE_NAME_PLATE_ONLY",
		exclude = function(config) return config.showCrowdControl and "CROWD_CONTROL" or nil end,
		candidates = function(config)
			return { excludeSpellIDs = HiddenAuras, nameplateShowPersonal = config.ownDebuffsBlizzardOnly or nil }
		end
	},
	{
		key = "AzeritePlateHarmfulOthers", shownField = "showOtherDebuffs", isHarmful = true,
		filter = "HARMFUL|INCLUDE_NAME_PLATE_ONLY", requiresExclusion = true,
		exclude = function(config) return "PLAYER", config.showCrowdControl and "CROWD_CONTROL" or nil end,
		candidates = function(config) return { excludeSpellIDs = HiddenAuras, nameplateShowAll = true } end
	},
	{
		key = "AzeritePlateHelpfulDispellable", shownField = "showDispellableBuffs", isHarmful = false,
		filter = "HELPFUL|RAID_PLAYER_DISPELLABLE",
		candidates = function(config) return { excludeSpellIDs = HiddenAuras } end
	},
	{
		key = "AzeritePlateHelpfulImportant", shownField = "showImportantBuffs", isHarmful = false,
		filter = "HELPFUL|IMPORTANT",
		exclude = function(config) return config.showDispellableBuffs and "RAID_PLAYER_DISPELLABLE" or nil end,
		candidates = function(config) return { excludeSpellIDs = HiddenAuras } end
	},
	{
		key = "AzeritePlateHelpfulOwn", shownField = "showOwnBuffs", isHarmful = false,
		filter = "HELPFUL|PLAYER",
		exclude = function(config)
			return config.showDispellableBuffs and "RAID_PLAYER_DISPELLABLE" or nil, config.showImportantBuffs and "IMPORTANT" or nil
		end,
		candidates = function(config)
			return { excludeSpellIDs = HiddenAuras, maxDuration = PLATE_OWN_BUFF_MAX_DURATION }
		end
	}
}

local NAMEPLATE_CONFIG_FIELDS = {
	"maxAuras", "showCrowdControl", "showOwnDebuffs", "ownDebuffsBlizzardOnly", "showOtherDebuffs",
	"showDispellableBuffs", "showImportantBuffs", "showOwnBuffs"
}

-- For tooling, as GroupKeys above.
ns.PlayerAuraContainers.NamePlateKeys = {}
for index, group in ipairs(NAMEPLATE_AURA_GROUPS) do
	ns.PlayerAuraContainers.NamePlateKeys[index] = group.key
end

-- Every kind shown unless the settings say otherwise, Blizzard's pick of your debuffs off.
local function BuildNamePlateConfig(settings)
	settings = settings or {}
	return {
		maxAuras = settings.maxAuras or 6,
		showCrowdControl = settings.showCrowdControl ~= false,
		showOwnDebuffs = settings.showOwnDebuffs ~= false,
		ownDebuffsBlizzardOnly = settings.ownDebuffsBlizzardOnly == true,
		showOtherDebuffs = settings.showOtherDebuffs ~= false,
		showDispellableBuffs = settings.showDispellableBuffs ~= false,
		showImportantBuffs = settings.showImportantBuffs ~= false,
		showOwnBuffs = settings.showOwnBuffs ~= false
	}
end
ns.PlayerAuraContainers.BuildNamePlateConfig = BuildNamePlateConfig

-- The group's filter string for this config, or nil when the client cannot express it.
local function GetNamePlateGroupFilter(group, config)
	if (not IsUsableFilterString(group.filter)) then
		return nil
	end
	if (not group.exclude) then
		return group.filter
	end
	local filter = WithExcludedTokens(group.filter, group.exclude(config))
	if (group.requiresExclusion and filter == group.filter) then
		return nil
	end
	return filter
end

-- Spell ID sets are static, so they are left out.
local function GetNamePlateCandidateSignature(filters)
	return tostring(filters.nameplateShowPersonal) .. ":" .. tostring(filters.nameplateShowAll) .. ":" .. tostring(filters.maxDuration)
end

local NamePlateDisplayMixin = {}

-- Applies the kinds `config` switches on. Only what changed reaches the container:
-- SetAuraGroupCandidateFilters rebuilds it on every call, and a group added once stays.
function NamePlateDisplayMixin:Configure(config)
	local parts = {}
	for index, field in ipairs(NAMEPLATE_CONFIG_FIELDS) do
		parts[index] = tostring(config[field])
	end
	local signature = table.concat(parts, ":")
	if (signature == self.configurationSignature) then
		return
	end
	self.configurationSignature = signature

	local container = self.container
	local options = self.options
	local styleState = self.styleState
	local spacingX = options.spacingX or options.spacing or 0
	local spacingY = options.spacingY or options.spacing or 0
	for layoutIndex, group in ipairs(NAMEPLATE_AURA_GROUPS) do
		local filter = config[group.shownField] and GetNamePlateGroupFilter(group, config) or nil
		local added = self.addedGroups[group.key]
		if (filter and not added) then
			local isHarmful = group.isHarmful
			local candidates = group.candidates(config)
			container:AddAuraGroup(group.key, filter, {
				initializeFrame = function(button)
					StyleAuraButton(button, isHarmful, options, false, styleState)
				end,
				candidateFilters = candidates,
				maxFrameCount = config.maxAuras,
				sortMethod = GetSortMethod(isHarmful),
				sortDirection = GetSortDirection(),
				layout = {
					elementSpacing = spacingX,
					lineSpacing = spacingY,
					groupSpacing = spacingX,
					groupLineSpacing = spacingY,
					elementWidth = options.size,
					elementHeight = options.size,
					layoutIndex = layoutIndex
				}
			})
			self.addedGroups[group.key] = { candidates = GetNamePlateCandidateSignature(candidates) }
		elseif (added) then
			if (filter) then
				-- Compares before it acts.
				container:SetAuraGroupFilterString(group.key, filter)
				local candidates = group.candidates(config)
				local candidateSignature = GetNamePlateCandidateSignature(candidates)
				if (candidateSignature ~= added.candidates) then
					container:SetAuraGroupCandidateFilters(group.key, candidates)
					added.candidates = candidateSignature
				end
			end
			container:SetAuraGroupMaxFrameCount(group.key, filter and config.maxAuras or 0)
		end
	end
end

-- Returns true when the container was pointed at a new unit, which rebuilds it.
function NamePlateDisplayMixin:SetDisplayUnit(unit)
	if (type(unit) ~= "string" or unit == "" or unit == self.unit) then
		return false
	end
	self.unit = unit
	self.container:SetUnit(unit)
	return true
end

-- A plate is a plain frame (oUF spawns it from PingableUnitFrameTemplate), so unlike the
-- player and group rows nothing here has to wait for combat to end.
function NamePlateDisplayMixin:SetDisplayEnabled(enabled)
	enabled = (enabled and self.unit ~= nil) and true or false
	if (enabled == self.displayEnabled) then
		return
	end
	self.displayEnabled = enabled
	self.container:SetEnabled(enabled)
	self:SetShown(enabled)
end

function NamePlateDisplayMixin:ForceUpdate()
	self.container:UpdateAllAuras()
end

-- Nameplate variant of CreateForUnit: the kinds above, laid out in one flow and clipped to
-- options.width x options.height, `config` saying which kinds are on (BuildNamePlateConfig).
-- Returns nil where the client lacks the container, and the plate keeps its scanning
-- element in that case.
ns.PlayerAuraContainers.CreateForNamePlate = function(parent, options, config)
	if (not C_XMLUtil or not C_XMLUtil.GetTemplateInfo or not C_XMLUtil.GetTemplateInfo("CustomAuraContainerTemplate")) then
		return nil
	end
	if (not AuraContainerSortMethod or not AuraContainerSortDirection or not AnchorUtil) then
		return nil
	end
	-- Every group is checked before it is added; a client that cannot check them gets none.
	if (not IsUsableFilterString("HARMFUL|PLAYER")) then
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

	local initialAnchor = options.initialAnchor or "BOTTOMLEFT"
	local container = CreateFrame("AuraContainer", nil, clipFrame, "CustomAuraContainerTemplate, DisableUntrustedLayoutScriptsTemplate")
	container:SetFrameLevel(clipFrame:GetFrameLevel())
	SetMouseInputEnabled(container, false)
	container:SetPoint(initialAnchor, clipFrame, initialAnchor, GetContainerAnchorOffset(initialAnchor))
	container:SetFlowLayoutAnchorPoint(initialAnchor)
	container:SetFlowLayoutGrowthDirection(
		GetFlowDirection(options.growthX == "LEFT" and "Left" or "Right", options.growthX == "LEFT" and -1 or 1),
		GetFlowDirection(options.growthY == "DOWN" and "Down" or "Up", options.growthY == "DOWN" and -1 or 1))
	container:SetFlowLayoutMaximumLineSize(options.width)

	display.container = container
	display.containers = { container }
	display.options = options
	-- Nothing on a plate is dimmed.
	display.styleState = { alwaysBright = true }
	container.__AzeriteUI_StyleState = display.styleState
	display.addedGroups = {}

	Mixin(display, NamePlateDisplayMixin)
	display:Configure(config or BuildNamePlateConfig())

	-- Off until the plate says otherwise: an enabled container registers UNIT_AURA for its unit.
	display.displayEnabled = false
	container:SetEnabled(false)
	display:Hide()
	return display
end

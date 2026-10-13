--[[
	TODO 5.1: Player Aura Row -> Always Show Full Brightness, in and out of restricted content.

	Loads the real PlayerAuraContainers.lua against the same fake container as
	player_aura_enchant_harness.lua, with pooled buttons whose icons answer
	CanBeAccessedInContext the way Blizzard's DenyTaintedAccessWhenAurasAreSecret does:
	open outdoors, closed in a raid. Checks that the toggle reaches every pooled icon at
	once outdoors; that in a raid it touches none of them (the forbidden object error of
	5.4.3) while new buttons follow the setting; and that the skipped ones catch up once
	access returns. Cannot cover: whether the client really reopens access on leaving.
	lua Tools/Harness/aura_brightness_harness.lua .
]]
local root = arg and arg[1] or "."
local target = arg and arg[2] or (root .. "/Components/UnitFrames/Auras/PlayerAuraContainers.lua")

local checks, failures = 0, 0
local function check(ok, label, detail)
	checks = checks + 1
	if (not ok) then
		failures = failures + 1
		print("FAIL " .. label .. (detail and (": " .. tostring(detail)) or ""))
	end
end

--------------------------------------------------------------------------------
-- Widgets
--------------------------------------------------------------------------------
local Region = {}
Region.__index = Region
local function NewRegion(kind, parent)
	return setmetatable({ __kind = kind, __parent = parent, __shown = true, __level = 0 }, Region)
end
function Region:SetFrameLevel(level) self.__level = level end
function Region:GetFrameLevel() return self.__level or 0 end
function Region:EnableMouse() end
function Region:SetMouseMotionEnabled() end
function Region:SetMouseClickEnabled() end
function Region:SetPoint() end
function Region:ClearAllPoints() end
function Region:SetAllPoints() end
function Region:SetSize(width, height) self.__width, self.__height = width, height end
function Region:GetWidth() return self.__width or 0 end
function Region:SetClipsChildren() end
function Region:GetParent() return self.__parent end
function Region:SetShown(shown) self.__shown = shown and true or false end
function Region:Show() self.__shown = true end
function Region:Hide() self.__shown = false end
function Region:SetAlpha(alpha) self.__alpha = alpha end
function Region:SetTexture() end
function Region:AddMaskTexture() end
function Region:SetDesaturated() end
function Region:SetVertexColor() end
function Region:SetFontObject() end
function Region:SetTextColor() end
function Region:SetJustifyH() end
function Region:SetWordWrap() end
function Region:SetFixedColor() end
function Region:SetBackdropBorderColor() end
function Region:SetDrawEdge() end
function Region:SetDrawBling() end
function Region:SetDrawSwipe() end
function Region:SetSwipeColor() end
function Region:SetHideCountdownNumbers() end
function Region:SetCountdownAbbrevThreshold() end
function Region:GetNumRegions() return 0 end
function Region:GetRegions() end
function Region:CreateTexture() return NewRegion("Texture", self) end
function Region:CreateMaskTexture() return NewRegion("MaskTexture", self) end
function Region:CreateFontString() return NewRegion("FontString", self) end

-- CustomAuraButtonTemplate, as StyleAuraButton drives it.
local AuraButton = setmetatable({}, { __index = Region })
AuraButton.__index = AuraButton
function AuraButton:SetTooltipAnchorPoint() end
function AuraButton:SetHideTooltipInCombat() end
function AuraButton:SetIcon(icon) self.__icon = icon end
function AuraButton:SetApplicationCount() end
function AuraButton:SetDurationCooldown() end
function AuraButton:AddPandemicRegion() end
function AuraButton:SetCancelAuraButtons(buttons) self.__cancel = buttons end

--------------------------------------------------------------------------------
-- Blizzard_AuraContainer, item enchantments
--------------------------------------------------------------------------------
AuraContainerItemEnchantmentSlot = { MainHand = 0, OffHand = 1, Ranged = 2 }
CustomAuraContainerItemEnchantmentPlacement = { BeforeAuraGroups = 0, AfterAuraGroups = 1 }
AuraContainerSortMethod = { Default = 0, UnitFrameDebuff = 2, ExpirationOnly = 5 }
AuraContainerSortDirection = { Normal = 0, Reverse = 1 }
AnchorUtil = { FlowDirection = { Left = -1, Right = 1, Up = 1, Down = -1 } }
C_XMLUtil = { GetTemplateInfo = function(name) if (name == "CustomAuraContainerTemplate") then return {} end end }
AuraUtil = { IsValidFilterString = function() return true end }
function Mixin(object, ...)
	for i = 1, select("#", ...) do
		for k, v in pairs((select(i, ...))) do object[k] = v end
	end
	return object
end
function CreateFromMixins(...) return Mixin({}, ...) end
function RegisterStateDriver() end

local combat = false
function InCombatLockdown() return combat end

local client = "12.1.5"
local containers = {}

local function IsEnumValue(enum, value)
	for _, v in pairs(enum) do if (v == value) then return true end end
	return false
end
local ENCHANT_OPTIONS = { templateNames = true, initializeFrame = true, hidePermanent = true }
local LAYOUT_OPTIONS = { elementSpacing = true, lineSpacing = true, groupSpacing = true, groupLineSpacing = true,
	forceNewLine = true, elementWidth = true, elementHeight = true, layoutIndex = true, placement = true }

-- A new container is not enabled until SetEnabled(true), as in Blizzard_AuraContainer.lua.
local AuraContainer = setmetatable({}, { __index = Region })
AuraContainer.__index = AuraContainer
function AuraContainer:SetUnit(unit) self.__unit = unit end
function AuraContainer:SetEnabled(enabled) self.__on = enabled end
function AuraContainer:UpdateAllAuras() self.__updates = self.__updates + 1 end
function AuraContainer:SetFlowLayoutAnchorPoint() end
function AuraContainer:SetFlowLayoutGrowthDirection() end
function AuraContainer:SetFlowLayoutMaximumLineSize() end
function AuraContainer:AddAuraGroup(key) self.__groups[key] = true end
function AuraContainer:SetAuraGroupLayout() end
function AuraContainer:SetAuraGroupFilterString() end
function AuraContainer:SetAuraGroupCandidateFilters() end
function AuraContainer:SetAuraGroupMaxFrameCount(key, count) self.__maxCounts[key] = count end
function AuraContainer:GetAuraGroupFrameCount() return 0 end
function AuraContainer:GetAuraGroupFrame() end
-- Blizzard_CustomAuraContainer.lua: ValidateItemEnchantmentSlot, ValidateAddItemEnchantmentOptions,
-- the duplicate-slot assert, then CreateAuraSlotFrame and the caller's initializeFrame.
function AuraContainer:AddItemEnchantment(slot, options)
	assert(IsEnumValue(AuraContainerItemEnchantmentSlot, slot), "itemEnchantmentSlot must be a valid AuraContainerItemEnchantmentSlot.")
	assert(not self.__enchants[slot], "item enchantment already exists with this slot.")
	for k in pairs(options or {}) do assert(ENCHANT_OPTIONS[k], "unknown item enchantment option " .. tostring(k)) end
	assert(options.initializeFrame == nil or type(options.initializeFrame) == "function", "initializeFrame")
	assert(options.hidePermanent == nil or type(options.hidePermanent) == "boolean", "hidePermanent must be a boolean or nil.")
	local button = setmetatable(NewRegion("Button", self), AuraButton)
	if (options.initializeFrame) then options.initializeFrame(button) end
	self.__enchants[slot] = { enabled = true, button = button, hidePermanent = options.hidePermanent }
	self.__enchantCalls = self.__enchantCalls + 1
	return button
end
function AuraContainer:SetItemEnchantmentLayout(layout)
	for k, v in pairs(layout or {}) do
		assert(LAYOUT_OPTIONS[k], "unknown layout option " .. tostring(k))
		if (k == "placement") then
			assert(IsEnumValue(CustomAuraContainerItemEnchantmentPlacement, v), "placement")
		elseif (k == "forceNewLine") then
			assert(type(v) == "boolean", k)
		else
			assert(type(v) == "number", k .. " must be a number.")
		end
	end
	self.__enchantLayout = layout
end
-- 12.1.5 and Forever only.
local function SetItemEnchantmentEnabled(self, slot, enabled)
	assert(IsEnumValue(AuraContainerItemEnchantmentSlot, slot), "itemEnchantmentSlot must be a valid AuraContainerItemEnchantmentSlot.")
	assert(type(enabled) == "boolean", "enabled must be a boolean.")
	local enchant = self.__enchants[slot]
	assert(enchant, "item enchantment was not found with this slot.")
	enchant.enabled = enabled
end

function CreateFrame(kind, _, parent)
	if (kind == "AuraContainer") then
		local container = setmetatable(NewRegion(kind, parent), AuraContainer)
		container.__groups, container.__enchants, container.__maxCounts = {}, {}, {}
		container.__enchantCalls, container.__updates = 0, 0
		if (client ~= "12.1.0") then
			container.SetItemEnchantmentEnabled = SetItemEnchantmentEnabled
		end
		containers[#containers + 1] = container
		return container
	end
	return NewRegion(kind or "Frame", parent)
end

--------------------------------------------------------------------------------
-- The addon side PlayerAuraContainers.lua reads
--------------------------------------------------------------------------------
local ns = {
	Colors = { quest = { red = { 1, 0, 0 }, orange = { 1, .5, 0 }, yellow = { 1, 1, 0 } },
		offwhite = { 1, 1, 1 }, verydarkgray = { .1, .1, .1 }, title = { 1, .8, 0 } },
	API = {
		GetFont = function() return {} end,
		GetMedia = function(name) return name end,
		IsSafeBool = function(value) return type(value) == "boolean" end,
		TryCall = function(func, ...) return pcall(func, ...) end
	},
	AuraData = { Spells = {}, Hidden = {} },
	AuraStyles = { CreateTextureBorder = function(button)
		local border = NewRegion("Frame", button)
		border.__AzeriteUI_BorderPieces = {}
		return border
	end }
}
ns.IsRetail = true
Enum = {}

local chunk = assert(loadfile(target))
chunk("AzeriteUI5_JuNNeZ_Edition", ns)
local Create = ns.PlayerAuraContainers.Create


--------------------------------------------------------------------------------
-- Pooled buttons with access the test controls
--------------------------------------------------------------------------------
local secret = false
function Region:RegisterEvent(event) self.__events = self.__events or {}; self.__events[event] = true end
function Region:UnregisterAllEvents() self.__events = {} end
function Region:SetScript(name, fn) self.__scripts = self.__scripts or {}; self.__scripts[name] = fn end

local errors = 0
local function Icon()
	local icon = NewRegion("Texture")
	icon.CanBeAccessedInContext = function() return not secret end
	icon.SetDesaturated = function(self, value)
		if (secret) then errors = errors + 1; error("calling 'SetDesaturated' on bad self") end
		self.__desaturated = value
	end
	icon.SetVertexColor = function(self, r)
		if (secret) then errors = errors + 1; error("forbidden") end
		self.__r = r
	end
	return icon
end

local function Pool(container, groupKey, count, subdued)
	container.__pool = container.__pool or {}
	container.__pool[groupKey] = {}
	for i = 1, count do
		local button = NewRegion("Button")
		button.Icon, button.__AzeriteUI_Subdued = Icon(), subdued
		-- The button carries the same restriction as its icon.
		button.CanBeAccessedInContext = function() return not secret end
		local setSize = button.SetSize
		button.SetSize = function(self, ...)
			if (secret) then errors = errors + 1; error("calling 'SetSize' on bad self") end
			return setSize(self, ...)
		end
		container.__pool[groupKey][i] = button
	end
	container.GetAuraGroupFrameCount = function(self, key) return self.__pool[key] and #self.__pool[key] or 0 end
	container.GetAuraGroupFrame = function(self, key, i) return self.__pool[key][i] end
end

-- Every frame the module makes from here on, to find its retry frame.
local made = {}
local stubCreateFrame = CreateFrame
CreateFrame = function(...)
	local frame = stubCreateFrame(...)
	made[#made + 1] = frame
	return frame
end

local parent = NewRegion("Frame")
local display = Create(parent, { width = 300, height = 80, size = 36, spacingX = 4, spacingY = 4,
	initialAnchor = "BOTTOMLEFT", growthX = "RIGHT", growthY = "UP", maxBuffs = 16, maxDebuffs = 16 })
display:SetSize(300, 80)
display:SetDisplayEnabled(true)
local container = display.playerContainer
local shortGroup = "AzeriteHelpfulShort"
Pool(container, shortGroup, 3, true)

local function Config(alwaysBright, size)
	return { size = size or 36, spacingX = 4, spacingY = 4, initialAnchor = "BOTTOMLEFT", growthX = "RIGHT", growthY = "UP",
		maxBuffs = 16, maxDebuffs = 16, useStockBehavior = true, alwaysBright = alwaysBright,
		showPriority = true, showBoss = true, showStealable = true, showPersonal = true, showNameplate = true,
		showTemporary = true, showLong = false, maxDuration = 300 }
end
local function AllDim(expect)
	for _, b in ipairs(container.__pool[shortGroup]) do
		if ((b.Icon.__desaturated == true) ~= expect) then return false end
	end
	return true
end

-- Outdoors: the toggle reaches every pooled icon at once, both ways.
display:Configure(Config(false))
check(AllDim(true), "outdoors, off: short buffs are subdued")
display:Configure(Config(true))
check(AllDim(false), "outdoors, on: every pooled icon at full brightness at once")
display:Configure(Config(false))
check(AllDim(true), "outdoors, off again: subdued again at once")

-- In a raid: no error, pooled icons untouched, the setting kept for new buttons.
secret = true
local ok, err = pcall(display.Configure, display, Config(true, 37))
check(ok and errors == 0, "in a raid the toggle raises nothing (5.4.3 error)", err)
check(AllDim(true), "in a raid pooled icons keep their old brightness (the known lag)")
check(container.__AzeriteUI_StyleState.alwaysBright == true, "new buttons will be created bright")

-- Access returns (leaving the raid): the owed value is applied without another change.
local retryFrame
for _, frame in ipairs(made) do
	if (frame.__scripts and frame.__scripts.OnEvent) then retryFrame = frame end
end
check(retryFrame and retryFrame.__events and retryFrame.__events.PLAYER_REGEN_ENABLED
	and retryFrame.__events.ADDON_RESTRICTION_STATE_CHANGED, "a skipped pass waits for access to return")
retryFrame.__scripts.OnEvent(retryFrame, "PLAYER_REGEN_ENABLED")
check(AllDim(true), "still in the raid: the retry touches nothing")
check(errors == 0, "and raises nothing")
secret = false
retryFrame.__scripts.OnEvent(retryFrame, "ZONE_CHANGED_NEW_AREA")
check(AllDim(false), "access back: the pooled icons catch up to full brightness")
check(next(retryFrame.__events) == nil, "nothing owed: the retry stops listening")

-- A later change outdoors applies at once again, with nothing pending.
display:Configure(Config(false, 38))
check(AllDim(true), "outdoors afterwards: applies at once")

print(string.format("Aura brightness (TODO 5.1): %d checks, %d failures (offline only).", checks, failures))
if (failures > 0) then os.exit(1) end

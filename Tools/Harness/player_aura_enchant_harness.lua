--[[
	Weapon enchants in the player aura row (PlayerAuraContainers.lua).

	Temporary weapon enchants are item enchantments, not auras, so the row shows them only through
	Blizzard's AddItemEnchantment. This loads the real PlayerAuraContainers.lua against a fake
	CustomAuraContainer whose item-enchantment methods check their inputs the way
	Blizzard_CustomAuraContainer.lua does, in two shapes:
	  12.1.0          AddItemEnchantment and SetItemEnchantmentLayout only; a slot cannot be removed,
	                  so switching off swaps the row to a second player container without slots.
	  12.1.5/Forever  also SetItemEnchantmentEnabled, so the slots switch off in place.

	Usage, from the addon root:
	  lua Tools/Harness/player_aura_enchant_harness.lua .
	  lua Tools/Harness/player_aura_enchant_harness.lua . <path to a PlayerAuraContainers.lua copy>

	Cannot cover: rendering, the real layout, taint, or whether Blizzard's own refresh shows the
	enchant. Those are owed in game.
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
-- Helpers
--------------------------------------------------------------------------------
local MAIN, OFF = AuraContainerItemEnchantmentSlot.MainHand, AuraContainerItemEnchantmentSlot.OffHand
local HARMFUL_GROUP = "AzeriteHarmful"

-- Created the way Player.lua creates the attached row, then enabled the way its element is.
local function NewDisplay(clientShape, itemEnchantments)
	client = clientShape
	containers = {}
	local parent = NewRegion("Frame")
	local display = Create(parent, {
		width = 300, height = 80, size = 36, spacingX = 4, spacingY = 4,
		initialAnchor = "BOTTOMLEFT", growthX = "RIGHT", growthY = "UP",
		maxBuffs = 16, maxDebuffs = 16, itemEnchantments = itemEnchantments
	})
	display:SetSize(300, 80)
	display:SetDisplayEnabled(true)
	return display
end

-- What ApplyPlayerAuraLayout hands Configure, with the fields under test overridable.
local function Config(overrides)
	local config = {
		size = 36, spacingX = 4, spacingY = 4, initialAnchor = "BOTTOMLEFT", growthX = "RIGHT", growthY = "UP",
		maxBuffs = 16, maxDebuffs = 16, useStockBehavior = true, alwaysBright = false,
		showPriority = true, showBoss = true, showStealable = true, showPersonal = true, showNameplate = true,
		showTemporary = true, showLong = false, maxDuration = 300, showItemEnchantments = true
	}
	for k, v in pairs(overrides or {}) do config[k] = v end
	return config
end

local function EnchantCount(container)
	local n = 0
	for _ in pairs(container.__enchants) do n = n + 1 end
	return n
end

local function Live(container)
	return container.__on == true and container.__shown == true
end

local function Parked(container)
	return container.__on == false and container.__shown == false
end

--------------------------------------------------------------------------------
-- Checks
--------------------------------------------------------------------------------
for _, shape in ipairs({ "12.1.0", "12.1.5" }) do
	local tag = " [" .. shape .. "]"
	local swaps = shape == "12.1.0"

	-- A display created without the capability (the separate debuff row, Player Alternate).
	do
		local display = NewDisplay(shape, nil)
		display:Configure(Config())
		check(display.itemEnchantmentContainer == nil, "no enchant container without the capability" .. tag)
		for _, container in ipairs(containers) do
			check(EnchantCount(container) == 0, "nothing registered without the capability" .. tag)
		end
		display:Configure(Config({ showItemEnchantments = false }))
		check(#containers == 2, "no container swap without the capability" .. tag, #containers)
	end

	-- Creation alone registers nothing: the profile decides, in the first real Configure.
	do
		local display = NewDisplay(shape, true)
		local player, vehicle = display.playerContainer, display.vehicleContainer
		check(display.itemEnchantmentContainer == player, "player container carries the enchants" .. tag)
		check(EnchantCount(player) == 0, "creation registers nothing" .. tag)

		display:Configure(Config())
		check(player.__enchants[MAIN] and player.__enchants[OFF], "main and off hand registered" .. tag)
		check(player.__enchants[AuraContainerItemEnchantmentSlot.Ranged] == nil, "ranged left alone" .. tag)
		check(EnchantCount(vehicle) == 0, "vehicle row never registers enchants" .. tag)
		check(player.__enchants[MAIN] and player.__enchants[MAIN].hidePermanent == false, "hidePermanent matches the header" .. tag)
		local frames = player.__AzeriteUI_ItemEnchantmentFrames
		check(frames and frames.MainHand == player.__enchants[MAIN].button, "frames kept for the snapshot" .. tag)
		local button = player.__enchants[MAIN].button
		check(button.__width == 36 and button.__height == 36, "enchant button styled at the row size" .. tag)
		check(button.__cancel == "RightButtonUp", "enchant button right-click cancels like a buff" .. tag)
		local layout = player.__enchantLayout
		check(layout and layout.layoutIndex == 1.5, "enchants laid out after debuffs, before buffs" .. tag, layout and layout.layoutIndex)
		check(layout and layout.elementWidth == 36 and layout.elementHeight == 36, "enchant layout uses the row size" .. tag)
		check(layout and layout.elementSpacing == 4 and layout.lineSpacing == 4, "enchant layout uses the row spacing" .. tag)
		check(display.playerContainer == player and Live(player), "showing keeps the original container live" .. tag)

		-- Reconfiguring never registers a slot twice (the fake asserts like Blizzard would).
		display:Configure(Config({ alwaysBright = true }))
		check(player.__enchantCalls == 2, "no slot registered twice" .. tag, player.__enchantCalls)

		-- Switching off.
		display:Configure(Config({ showItemEnchantments = false }))
		local plain = display.playerContainer
		if (swaps) then
			check(plain ~= player and plain ~= vehicle, "12.1.0 swaps to another player container" .. tag)
			check(EnchantCount(plain) == 0, "the swapped-in container has no slots" .. tag)
			check(plain.__unit == "player", "the swapped-in container shows the player" .. tag)
			check(Live(plain), "the swapped-in container is enabled and shown" .. tag)
			check(Parked(player), "the container with slots is disabled and hidden" .. tag)
			check(display.containers[1] == plain and display.containers[2] == vehicle, "the display draws from the swapped-in container" .. tag)
			check(plain.__maxCounts[HARMFUL_GROUP] == 16, "the swapped-in container gets the current configuration" .. tag,
				plain.__maxCounts[HARMFUL_GROUP])
		else
			check(plain == player, "slots switch off in place, no swap" .. tag)
			check(player.__enchants[MAIN].enabled == false and player.__enchants[OFF].enabled == false,
				"slots switched off in place" .. tag)
		end

		-- And back on.
		display:Configure(Config({ showItemEnchantments = true }))
		check(display.playerContainer == player and Live(player), "switching back on returns to the container with slots" .. tag)
		check(display.containers[1] == player, "the display draws from the container with slots again" .. tag)
		if (swaps) then
			check(Parked(plain), "the container without slots is parked again" .. tag)
		else
			check(player.__enchants[MAIN].enabled == true, "slots switched back on" .. tag)
		end
		check(player.__enchantCalls == 2, "switching back on registers nothing new" .. tag, player.__enchantCalls)
		check(EnchantCount(plain) == 0 or plain == player, "the container without slots never gets any" .. tag)

		-- Toggling again reuses the two containers.
		for _ = 1, 3 do
			display:Configure(Config({ showItemEnchantments = false }))
			display:Configure(Config({ showItemEnchantments = true }))
		end
		check(#containers == (swaps and 3 or 2), "repeated toggling never builds more containers" .. tag, #containers)
		check(player.__enchantCalls == 2, "repeated toggling registers nothing new" .. tag, player.__enchantCalls)
	end

	-- Switched off while the row itself is disabled: the swapped-in container stays disabled too.
	if (swaps) then
		local display = NewDisplay(shape, true)
		local player = display.playerContainer
		display:Configure(Config())
		display:SetDisplayEnabled(false)
		display:Configure(Config({ showItemEnchantments = false }))
		local plain = display.playerContainer
		check(plain ~= player and plain.__on == false, "a disabled row swaps in a disabled container" .. tag)
		display:SetDisplayEnabled(true)
		check(plain.__on == true, "enabling the row enables the active container" .. tag)
		check(player.__on == false, "enabling the row leaves the parked container off" .. tag)
	end

	-- Show Debuffs Only leaves no buff slots, and weapon enchants are helpful effects.
	do
		local display = NewDisplay(shape, true)
		local player = display.playerContainer
		display:Configure(Config({ maxBuffs = 0 }))
		check(EnchantCount(player) == 0, "Show Debuffs Only registers nothing" .. tag)
		check(display.playerContainer == player and #containers == 2, "Show Debuffs Only from the start swaps nothing" .. tag)

		display:Configure(Config())
		check(EnchantCount(player) == 2, "registered once buffs are allowed" .. tag)
		display:Configure(Config({ maxBuffs = 0 }))
		if (swaps) then
			check(display.playerContainer ~= player and Parked(player), "Show Debuffs Only after showing swaps them out" .. tag)
		else
			check(player.__enchants[MAIN].enabled == false, "Show Debuffs Only switches them off" .. tag)
		end
	end

	-- Switched off from the start: never registered, so nothing to swap.
	do
		local display = NewDisplay(shape, true)
		local player = display.playerContainer
		display:Configure(Config({ showItemEnchantments = false }))
		check(EnchantCount(player) == 0, "off from the start registers nothing" .. tag)
		check(display.playerContainer == player and #containers == 2, "off from the start swaps nothing" .. tag)
	end

	-- Never in combat: Configure defers, and the change lands when combat ends.
	do
		local display = NewDisplay(shape, true)
		local player = display.playerContainer
		combat = true
		display:Configure(Config())
		check(EnchantCount(player) == 0, "nothing registered in combat" .. tag)
		combat = false
		display:ApplyPendingConfiguration()
		check(EnchantCount(player) == 2, "registered once combat ends" .. tag)

		combat = true
		display:Configure(Config({ showItemEnchantments = false }))
		check(display.playerContainer == player and #containers == 2, "nothing swapped or built in combat" .. tag)
		combat = false
		display:ApplyPendingConfiguration()
		if (swaps) then
			check(display.playerContainer ~= player, "the swap lands once combat ends" .. tag)
		else
			check(player.__enchants[MAIN].enabled == false, "switched off once combat ends" .. tag)
		end
	end
end

-- A client without item enchantments at all.
do
	local slots = AuraContainerItemEnchantmentSlot
	AuraContainerItemEnchantmentSlot = nil
	local display = NewDisplay("12.1.0", true)
	local ok, err = pcall(display.Configure, display, Config())
	check(ok, "a client without item enchantments configures cleanly", err)
	check(EnchantCount(display.playerContainer) == 0, "nothing registered without item enchantments")
	display:Configure(Config({ showItemEnchantments = false }))
	check(#containers == 2, "no swap without item enchantments", #containers)
	AuraContainerItemEnchantmentSlot = slots
end

--------------------------------------------------------------------------------
-- Forever: imbues are their own enchant type that the container never shows.
-- A second copy of the file is loaded with Forever's APIs present, since the file
-- decides at load. Secret values are tables here: Lua raises on comparing, adding
-- or joining a table with a number, so any unguarded use of one fails the run.
--------------------------------------------------------------------------------
do
	local SECRET = setmetatable({}, { __tostring = function() return "<secret>" end })
	local function Secret() return setmetatable({}, getmetatable(SECRET)) end
	local secrets = {}
	issecretvalue = function(value) return type(value) == "table" and getmetatable(value) == getmetatable(SECRET) end
	issecrettable = function(value) return secrets[value] == true end

	local now = 1000
	GetTime = function() return now end
	GetInventoryItemTexture = function(_, slot) return "weapon" .. slot end
	INVSLOT_MAINHAND, INVSLOT_OFFHAND, INVSLOT_RANGED = 16, 17, 18
	Enum = { ItemEnchantType = { None = 0, Permanent = 1, Temporary = 2, Imbue = 3 },
		WeaponSlot = { MainHand = 0, OffHand = 1, Ranged = 2 } }

	local weapon = {}       -- weapon slot -> list of WeaponEnchantInfo
	local temporary = {}    -- inventory slot -> TemporaryItemEnchantInfo
	C_Item = { GetWeaponEnchantInfo = function(slot) return weapon[slot] or {} end }
	C_PaperDollInfo = { GetTemporaryEnchantmentInfo = function(slot) return temporary[slot] end }

	-- Frame bits the cells and the event frame use.
	function Region:SetScript(name, fn) self["__" .. name] = fn end
	function Region:RegisterEvent(event) self.__events = self.__events or {}; self.__events[event] = true end
	function Region:RegisterUnitEvent(event) self.__events = self.__events or {}; self.__events[event] = true end
	function Region:UnregisterAllEvents() self.__events = {} end
	function Region:SetText(text) self.__text = text end
	function Region:SetCooldown(start, duration) self.__start, self.__duration = start, duration end
	local setPoint = Region.SetPoint
	function Region:SetPoint(point, relativeTo, relativePoint, x, y)
		self.__x, self.__y = x, y
		return setPoint(self, point, relativeTo, relativePoint, x, y)
	end
	function AuraContainer:SetFlowLayoutMaximumLineSize(size) self.__lineSize = size end

	local foreverNs = {
		Colors = ns.Colors, API = ns.API, AuraData = ns.AuraData, AuraStyles = ns.AuraStyles, IsRetail = true
	}
	assert(loadfile(target))("AzeriteUI5_JuNNeZ_Edition", foreverNs)
	local CreateForever = foreverNs.PlayerAuraContainers.Create

	local function NewForever(itemEnchantments)
		client = "12.1.5"
		containers = {}
		local display = CreateForever(NewRegion("Frame"), {
			width = 300, height = 80, size = 36, spacingX = 4, spacingY = 4,
			initialAnchor = "BOTTOMLEFT", growthX = "RIGHT", growthY = "UP",
			maxBuffs = 16, maxDebuffs = 16, itemEnchantments = itemEnchantments
		})
		display:SetSize(300, 80)
		display:SetDisplayEnabled(true)
		return display
	end
	local function ShownCells(display)
		local n = 0
		for _, cell in ipairs(display.imbueCells or {}) do
			if (cell.__shown) then n = n + 1 end
		end
		return n
	end
	local tag = " [Forever]"

	-- Flametongue on the main hand, an oil the container already shows on the off hand.
	weapon[0] = { { hasEnchant = true, enchantType = 3, timeLeft = 1800000, charges = 0, enchantID = 5, enchantIconID = 1 } }
	weapon[1] = { { hasEnchant = true, enchantType = 2, timeLeft = 600000, charges = 0, enchantID = 9, enchantIconID = 2 } }
	temporary[17] = { enchantID = 9, remainingTimeMs = 600000, chargesRemaining = 0, hasExpirationTime = true }

	local display = NewForever(true)
	local player = display.playerContainer
	display:Configure(Config())
	check(ShownCells(display) == 1, "an imbue the container cannot show gets a cell" .. tag, ShownCells(display))
	local cell = display.imbueCells[1]
	check(cell.inventorySlot == 16, "the cell is the main hand's" .. tag, cell.inventorySlot)
	check(cell.Cooldown.__duration == 1800 and cell.Cooldown.__start == now, "the cell counts down the imbue" .. tag)
	check(cell.__x == 6, "the cell leads the row from its corner" .. tag, cell.__x)
	check(player.__x == 6 + 40, "the container moves along by one slot" .. tag, player.__x)
	check(player.__lineSize == 300 - 40, "the container's line shortens by one slot" .. tag, player.__lineSize)
	check(cell.__OnEnter ~= nil, "the cell has a tooltip" .. tag)

	-- The same oil counted by the container never gets a second cell; a permanent one never shows.
	weapon[1][2] = { hasEnchant = true, enchantType = 1, timeLeft = 0, charges = 0, enchantID = 11, enchantIconID = 3 }
	display:RefreshImbues()
	check(ShownCells(display) == 1, "the container's own enchant and permanent ones are skipped" .. tag)

	-- A ranged imbue: the row's container has no ranged slot, so it is drawn too.
	weapon[2] = { { hasEnchant = true, enchantType = 2, timeLeft = 60000, charges = 3, enchantID = 13, enchantIconID = 4 } }
	display:RefreshImbues()
	check(ShownCells(display) == 2, "a ranged enchant gets a cell" .. tag, ShownCells(display))
	check(display.imbueCells[2].Count.__text == 3, "charges show on the cell" .. tag)
	check(player.__x == 6 + 80, "the container moves along by two slots" .. tag, player.__x)
	weapon[2] = nil

	-- Secret fields and secret tables are skipped, never touched.
	weapon[0] = {
		{ hasEnchant = Secret(), enchantType = 3, timeLeft = 1800000, charges = 0, enchantID = 5, enchantIconID = 1 },
		{ hasEnchant = true, enchantType = Secret(), timeLeft = 1800000, charges = 0, enchantID = 6, enchantIconID = 1 },
		{ hasEnchant = true, enchantType = 3, timeLeft = Secret(), charges = 0, enchantID = 7, enchantIconID = 1 },
		{ hasEnchant = true, enchantType = 3, timeLeft = 1800000, charges = Secret(), enchantID = 8, enchantIconID = 1 },
		{ hasEnchant = true, enchantType = 3, timeLeft = 1800000, charges = 0, enchantID = Secret(), enchantIconID = 1 },
	}
	local secretTable = { hasEnchant = true, enchantType = 3, timeLeft = 1, charges = 0, enchantID = 1 }
	secrets[secretTable] = true
	weapon[0][6] = secretTable
	temporary[17] = { enchantID = Secret(), remainingTimeMs = 1, chargesRemaining = 0, hasExpirationTime = true }
	local ok, err = pcall(display.RefreshImbues, display)
	check(ok, "secret fields raise nothing" .. tag, err)
	-- Only the entry whose only secret is its charges is readable enough to draw. The oil's
	-- container ID is secret now, so the off hand is left to the container: imbues only.
	check(ShownCells(display) == 1, "only fully readable enchants are drawn, no duplicate oil" .. tag, ShownCells(display))
	check(display.imbueCells[1].Count.__text == "", "a secret charge count is left blank" .. tag)

	-- In combat the cells follow at once and the container waits for combat to end.
	temporary[17] = { enchantID = 9, remainingTimeMs = 600000, chargesRemaining = 0, hasExpirationTime = true }
	weapon[0] = {}
	local beforeCombat = player.__x
	combat = true
	display:RefreshImbues()
	check(beforeCombat ~= 6, "the container was moved before combat" .. tag, beforeCombat)
	check(ShownCells(display) == 0, "cells hide in combat" .. tag)
	check(player.__x == beforeCombat, "the container does not move in combat" .. tag, player.__x)
	combat = false
	display.imbueEvents.__OnEvent(display.imbueEvents, "PLAYER_REGEN_ENABLED")
	check(player.__x == 6 and player.__lineSize == 300, "the container moves back when combat ends" .. tag, player.__x)

	-- Recast: the countdown restarts from the new time left.
	weapon[0] = { { hasEnchant = true, enchantType = 3, timeLeft = 1800000, charges = 0, enchantID = 5, enchantIconID = 1 } }
	display:RefreshImbues()
	now = now + 600
	weapon[0][1].timeLeft = 1200000
	display:RefreshImbues()
	check(display.imbueCells[1].Cooldown.__duration == 1800, "the countdown keeps its full length while it runs" .. tag)
	weapon[0][1].timeLeft = 1800000
	display:RefreshImbues()
	check(display.imbueCells[1].Cooldown.__duration == 1800 and display.imbueCells[1].Cooldown.__start == now,
		"a recast restarts the countdown" .. tag)

	-- Switched off, or Show Debuffs Only: no cells, no events, container back in place.
	display:Configure(Config({ showItemEnchantments = false }))
	check(ShownCells(display) == 0, "switching off hides the cells" .. tag)
	check(player.__x == 6 and player.__lineSize == 300, "switching off puts the container back" .. tag)
	check(next(display.imbueEvents.__events) == nil, "switching off stops listening" .. tag)
	display:Configure(Config({ showItemEnchantments = true }))
	check(ShownCells(display) == 1 and display.imbueEvents.__events.WEAPON_ENCHANT_CHANGED, "switching back on draws again" .. tag)
	display:Configure(Config({ maxBuffs = 0 }))
	check(ShownCells(display) == 0, "Show Debuffs Only hides the cells" .. tag)

	-- Displays without the capability never draw them.
	local plainDisplay = NewForever(nil)
	plainDisplay:Configure(Config())
	check(plainDisplay.imbueCells == nil, "no cells without the capability" .. tag)
end

-- Retail: the first copy loaded without C_Item.GetWeaponEnchantInfo never draws cells.
do
	local display = NewDisplay("12.1.0", true)
	display:Configure(Config())
	check(display.imbueCells == nil, "Retail never draws imbue cells")
end

-- Aura size: buttons used to keep the size the display was created with (the layout
-- default) while only the flow layout took the chosen size, so smaller icons overlapped.
do
	local display = NewDisplay("12.1.5", true)
	display:Configure(Config())
	local container = display.containers[1]
	local pooled = NewRegion("Button", container)
	pooled:SetSize(36, 36)
	container.GetAuraGroupFrameCount = function(_, key) return key == HARMFUL_GROUP and 1 or 0 end
	container.GetAuraGroupFrame = function() return pooled end
	display:Configure(Config({ size = 23 }))
	check(pooled:GetWidth() == 23, "pooled aura buttons follow the chosen size", tostring(pooled:GetWidth()))
	local state = container.__AzeriteUI_StyleState
	check(state and state.helpfulSize == 23 and state.harmfulSize == 23, "new aura buttons are created at the chosen size")
	local enchant = container.__enchants[MAIN]
	check(not enchant or enchant.button:GetWidth() == 23, "weapon enchant buttons follow the chosen size")
	check(not enchant or enchant.button.__AzeriteUI_TextSize == 10, "aura text shrinks with small icons")
	local lineSize
	container.SetFlowLayoutMaximumLineSize = function(_, width) lineSize = width end
	display:Configure(Config({ size = 23, maxCols = 3 }))
	check(lineSize == 3 * 23 + 2 * 4 + 1, "auras per row sets the native line size", tostring(lineSize))
	display:Configure(Config({ size = 23 }))
	check(lineSize == 300, "no per-row limit keeps the display width", tostring(lineSize))
	local groupLayout
	container.SetAuraGroupLayout = function(_, _, layout) groupLayout = layout end
	display:Configure(Config({ size = 22, spacingX = 4 }))
	check(groupLayout and groupLayout.elementSpacing == 4 and groupLayout.groupSpacing == 0, "no extra gap between aura groups")
end

print(string.format("Player aura enchants: %d checks, %d failures", checks, failures))
if (failures > 0) then error("player aura enchant harness failed", 0) end

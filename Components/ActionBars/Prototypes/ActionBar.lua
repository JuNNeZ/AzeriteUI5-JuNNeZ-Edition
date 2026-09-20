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
local API = ns.API

-- Lua API
local next = next
local pairs = pairs
local select = select
local setmetatable = setmetatable
local string_format = string.format
local table_concat = table.concat
local tonumber = tonumber
local tostring = tostring
local type = type
local unpack = unpack

-- GLOBALS: UIParent, C_ActionBar
-- GLOBALS: UnregisterStateDriver, RegisterStateDriver
-- GLOBALS: RegisterAttributeDriver, UnregisterAttributeDriver
-- GLOBALS: ClearOverrideBindings, GetBindingKey, SetOverrideBinding, SetOverrideBindingClick
-- GLOBALS: InCombatLockdown, PetDismiss, UnitExists, VehicleExit
-- GLOBALS: BOTTOMLEFT_ACTIONBAR_PAGE, BOTTOMRIGHT_ACTIONBAR_PAGE, RIGHT_ACTIONBAR_PAGE, LEFT_ACTIONBAR_PAGE
-- GLOBALS: MULTIBAR_5_ACTIONBAR_PAGE, MULTIBAR_6_ACTIONBAR_PAGE, MULTIBAR_7_ACTIONBAR_PAGE
-- GLOBALS: NUM_ACTIONBAR_BUTTONS, LEAVE_VEHICLE

local ButtonBar = ns.ButtonBar.prototype

local ActionBar = setmetatable({}, { __index = ButtonBar })
local ActionBar_MT = { __index = ActionBar }

local LFF = LibStub("LibFadingFrames-1.0")

local playerClass = ns.PlayerClass
local ACTION_BAR_FRAME_LEVEL = 100

-- Paging without restricted execution.
---------------------------------------------------------
-- `_onstate-page` resolves the symbolic states this bar's driver produces - possess,
-- dragon - into a page number, hands that to the buttons through `control:ChildUpdate`
-- and mirrors the result onto the bar. All three steps are restricted closures, so on
-- a client that cannot build one the bar never pages and, worse, its buttons never
-- receive a state at all, which leaves them with no `type` attribute and therefore
-- inert.
--
-- The replacement splits the work by what each half is allowed to do:
--
-- * Blizzard's own state-driver manager writes the page into `state-page` from secure
--   code, so the *conditional evaluation* stays exactly where it was. The driver is
--   built with numbers instead of symbols, because nothing insecure may resolve them
--   mid-fight.
-- * Each button gets its own `action` attribute driver carrying the slot for every
--   page. Blizzard applies those too, from secure code, so what a button casts stays
--   correct **in combat** - which is the part an insecure fallback cannot do.
-- * The icon, cooldown and count are not protected, so they are refreshed from Lua on
--   every page change, in or out of combat.
--
-- What is lost: dragging actions off these bars, the custom vehicle-exit state on
-- bar 1 button 7 (the separate dismount button module covers it), and `type` changes
-- between pages, since `type` can only be written outside combat.
local hasSecureSnippets = ns.HasSecureSnippets ~= false

-- Blizzard reports these through C_ActionBar on Forever and as bare globals on Retail.
local ResolveBarFunction = function(name)
	local fn = (C_ActionBar and C_ActionBar[name]) or _G[name]
	return (type(fn) == "function") and fn or nil
end

-- Long-standing client constants, used only if the client refuses to say.
local FALLBACK_BAR_INDEX = {
	GetVehicleBarIndex = 12,
	GetTempShapeshiftBarIndex = 13,
	GetOverrideBarIndex = 14
}

local GetBarIndex = function(name)
	local fn = ResolveBarFunction(name)
	local index = fn and fn()
	if (type(index) == "number" and index > 0) then return index end
	return FALLBACK_BAR_INDEX[name]
end

-- Bonus bars are pages 7 through 11, matching [bonusbar:1] through [bonusbar:5].
local BONUS_BAR_OFFSET = 6

-- The conditional list this bar's page driver is built from, as {condition, page}.
-- Order matters and matches the symbolic driver used where snippets work.
local GetPageConditions = function(barID)
	if (barID ~= 1) then
		return nil, barID
	end

	local conditions = {
		{ "[overridebar]", GetBarIndex("GetOverrideBarIndex") },
		{ "[possessbar]", GetBarIndex("GetVehicleBarIndex") },
		{ "[shapeshift]", GetBarIndex("GetTempShapeshiftBarIndex") },
		{ "[bonusbar:5]", BONUS_BAR_OFFSET + 5 },
		-- State 0 is this bar's own page, which for bar 1 is page 1.
		{ "[form,noform]", 1 },
		{ "[bar:2]", 2 },
		{ "[bar:3]", 3 },
		{ "[bar:4]", 4 },
		{ "[bar:5]", 5 },
		{ "[bar:6]", 6 }
	}

	local bonusBars = 0
	if (playerClass == "DRUID") then
		bonusBars = 4
	elseif (playerClass == "MONK") then
		bonusBars = 3
	elseif (playerClass == "ROGUE") then
		bonusBars = 1
	end

	for i = 1, bonusBars do
		conditions[#conditions + 1] = { "[bonusbar:"..i.."]", BONUS_BAR_OFFSET + i }
	end

	return conditions, 1
end

-- value(page) lets the same conditional list produce a page driver for the bar and a
-- slot driver for each button.
local BuildConditionalDriver = function(conditions, fallbackPage, value)
	if (not conditions) then
		return tostring(value(fallbackPage))
	end

	local parts = {}
	for i = 1, #conditions do
		parts[#parts + 1] = conditions[i][1].." "..value(conditions[i][2])
	end
	parts[#parts + 1] = tostring(value(fallbackPage))

	return table_concat(parts, "; ")
end

-- Faded buttons keep full mouse interactivity. LibFadingFrames only changes
-- alpha, so a button at zero opacity still casts when it is clicked, which is
-- how an invisible bar ends up firing abilities the player cannot see.
--
-- The button's own mouse state is the wrong lever: EnableMouse and friends are
-- protected on a protected frame while in combat, and combat is precisely when
-- a faded bar gets forced back to full opacity. Disabling clicks out of combat
-- would leave the button visible but dead for the whole following fight, with
-- no legal moment to undo it. An ordinary child frame is not protected, so one
-- shown over the button swallows the click instead, and can be taken back down
-- mid-fight the moment the button becomes visible again.
local BLOCKER_LEVEL_OFFSET = 10

local UpdateClickBlocker = function(button, alpha)
	local blocker = button.fadeClickBlocker
	if (not blocker) then return end

	-- Defensive only. A plain frame is not protected, so this should never be
	-- the branch taken, and the feature is worth nothing if it errors instead.
	if (InCombatLockdown() and blocker:IsProtected()) then return end

	blocker:SetShown((alpha or 1) <= 0)
end

local AcquireClickBlocker = function(button)
	local blocker = button.fadeClickBlocker
	if (not blocker) then
		blocker = CreateFrame("Frame", nil, button)
		blocker:SetAllPoints(button)
		blocker:EnableMouse(true)
		blocker:Hide()

		button.fadeClickBlocker = blocker
	end

	-- Re-stated rather than set once at creation, because the bar's frame
	-- level moves with layout changes and the blocker is only useful while it
	-- sits above the button it covers.
	blocker:SetFrameLevel(button:GetFrameLevel() + BLOCKER_LEVEL_OFFSET)

	return blocker
end

local ReleaseClickBlocker = function(button)
	button.OnFadeAlphaChanged = nil

	local blocker = button.fadeClickBlocker
	if (not blocker) then return end
	if (InCombatLockdown() and blocker:IsProtected()) then return end

	blocker:Hide()
end

-- An empty slot is invisible unless the grid is switched on, so anything that
-- restores alpha in bulk has to ask the button what its alpha should be rather
-- than assume full opacity. Forcing every button to 1 is what left empty slots
-- sitting at full brightness on a bar whose real buttons had faded away.
local GetRestingAlpha = function(button)
	local config = button.config
	if (config and config.showGrid) then return 1 end
	if (button.HasAction and button:HasAction()) then return 1 end
	return 0
end

local RestoreFadeAlpha = function(bar)
	bar:SetAlpha(1)
	for id,button in next,bar.buttons do
		button:SetAlpha(GetRestingAlpha(button))
		ReleaseClickBlocker(button)
	end
end

-- Return bindaction by blizzard barID.
local BINDTEMPLATE_BY_ID = {
	[1] = "ACTIONBUTTON%d",
	[BOTTOMLEFT_ACTIONBAR_PAGE] = "MULTIACTIONBAR1BUTTON%d",
	[BOTTOMRIGHT_ACTIONBAR_PAGE] = "MULTIACTIONBAR2BUTTON%d",
	[RIGHT_ACTIONBAR_PAGE] = "MULTIACTIONBAR3BUTTON%d",
	[LEFT_ACTIONBAR_PAGE] = "MULTIACTIONBAR4BUTTON%d"
}
if (ns.IsRetail) then
	if (MULTIBAR_5_ACTIONBAR_PAGE) then BINDTEMPLATE_BY_ID[MULTIBAR_5_ACTIONBAR_PAGE] = "MULTIACTIONBAR5BUTTON%d" end
	if (MULTIBAR_6_ACTIONBAR_PAGE) then BINDTEMPLATE_BY_ID[MULTIBAR_6_ACTIONBAR_PAGE] = "MULTIACTIONBAR6BUTTON%d" end
	if (MULTIBAR_7_ACTIONBAR_PAGE) then BINDTEMPLATE_BY_ID[MULTIBAR_7_ACTIONBAR_PAGE] = "MULTIACTIONBAR7BUTTON%d" end
end

-- Exit button for Wrath & Retail
local exitButton = {
	func = function(button)
		if (UnitExists("vehicle")) then
			VehicleExit()
		else
			PetDismiss()
		end
	end,
	tooltip = LEAVE_VEHICLE,
	texture = [[Interface\Icons\achievement_bg_kill_carrier_opposing_flagroom]]
}

local defaults = ns:Merge({
	enabled = false,
	useCommandBindingsForHoldCast = true,
	enableBarFading = false, -- whether to enable non-combat/hover button fading
	fadeInCombat = false, -- whether to keep fading out even in combat
	fadeFrom = 1, -- which button to start the button fading from
	numbuttons = 12, -- total number of buttons on the bar
	layout = "grid", -- currently applied layout type
	startAt = 1, -- at which button the zigzag pattern should begin
	growth = "horizontal", -- which direction the bar goes in
	growthHorizontal = "RIGHT", -- the bar's horizontal growth direction
	growthVertical = "UP", -- the bar's vertical growth direction
	padding = 8, -- horizontal padding between the buttons
	breakpadding = 8, -- vertical padding between the buttons
	breakpoint = 12, -- when to start a new grid row
	offset = 44/64, -- 44 -- relative offset in the growth direction for the alternate zigzag row as a fraction of button size.
	hitrects = { -10, -10, -10, -10 },
	hideElements = {
		macro = true,
		hotkey = false,
		equipped = true,
		border = false,
		borderIfEmpty = true
	},
	visibility = {
		dragon = false,
		possess = false,
		overridebar = false,
		vehicleui = false,
		mounted = true -- whether to keep the bar visible while mounted
	},
	blockFadedClicks = false, -- whether faded out buttons should swallow clicks instead of casting
	showEmptyButtons = false, -- whether slots without an action stay visible as empty buttons
	savedPosition = {
		scale = ns.API.GetEffectiveScale(),
		[1] = "CENTER",
		[2] = 0,
		[3] = 0
	}
}, ns.ButtonBar.defaults)

ns.ActionBar = {}
ns.ActionBar.prototype = ActionBar
ns.ActionBar.defaults = defaults
ns.ActionBar.GetRestingAlpha = GetRestingAlpha

ns.ActionBar.Create = function(self, id, config, name)

	local bar = setmetatable(ns.ButtonBar:Create(id, config, name), ActionBar_MT)
	-- Retail keeps its transparent native action buttons alive around level 52.
	-- Keep AzeriteUI's owned secure buttons above those retained click targets.
	bar:SetFrameLevel(ACTION_BAR_FRAME_LEVEL)

	bar:SetAttribute("UpdateVisibility", [[
		local visibility = self:GetAttribute("visibility");
		local userhidden = self:GetAttribute("userhidden");
		if (visibility == "show") then
			if (userhidden) then
				self:Hide();
			else
				self:Show();
			end
		elseif (visibility == "hide") then
			self:Hide();
		end
	]])

	-- Setting a snippet body the client cannot compile is worse than not having one:
	-- the first state change then raises out of Blizzard's OnAttributeChanged instead
	-- of doing nothing. Where they are unavailable the bar watches the same attribute
	-- from the insecure side instead.
	if (not hasSecureSnippets) then
		bar:HookScript("OnAttributeChanged", ActionBar.OnAttributeChanged)
	end

	if (hasSecureSnippets) then
		bar:SetAttribute("_onstate-vis", [[
			if (not newstate) then
				return
			end
			self:SetAttribute("visibility", newstate);
			self:RunAttribute("UpdateVisibility");
		]])

		bar:SetAttribute("_onstate-page", [[

			local hasVehicleBar, hasOverrideBar, hasTempShapeshiftBar, hasPossessBar;

			if (newstate == "possess" or newstate == "dragon" or newstate == "11") then

				if HasVehicleActionBar() then
					newstate = GetVehicleBarIndex();
					hasVehicleBar = true;

				elseif HasOverrideActionBar() then
					newstate = GetOverrideBarIndex();
					hasOverrideBar = true;

				elseif HasTempShapeshiftActionBar() then
					newstate = GetTempShapeshiftBarIndex();
					hasTempShapeshiftBar = true;

				elseif HasBonusActionBar() then
					newstate = GetBonusBarIndex();
					if (GetBonusBarOffset() == 5) then
						hasPossessBar = true;
					end
				else
					newstate = nil;
				end
				if (not newstate) then
					newstate = 12;
				end
			end

			self:SetAttribute("hasvehiclebar", hasVehicleBar);
			self:SetAttribute("hasoverridebar", hasOverrideBar);
			self:SetAttribute("hastempshapeshiftbar", hasTempShapeshiftBar);
			self:SetAttribute("haspossessbar", hasPossessBar);

			self:CallMethod("UpdateButtonFlags");

			self:SetAttribute("state", newstate);
			control:ChildUpdate("state", newstate);

			self:CallMethod("UpdateFading");
		]])

	end

	for i = 1,NUM_ACTIONBAR_BUTTONS do
		bar:CreateButton()
	end

	bar:UpdateButtonCount()
	bar:UpdateVisibilityDriver()

	bar:SetScript("OnEvent", ActionBar.OnEvent)
	bar:RegisterEvent("ACTIONBAR_SLOT_CHANGED")

	if (not hasSecureSnippets) then
		-- `state`, `type` and the per-page action fall behind whenever a page change
		-- lands mid-fight, because writing them is protected. Leaving combat is the
		-- first legal moment to catch up.
		bar:RegisterEvent("PLAYER_REGEN_ENABLED")
	end

	return bar
end

ActionBar.OnEvent = function(self, event, ...)
	if (event == "ACTIONBAR_SLOT_CHANGED") then
		self:UpdateFading()

	elseif (event == "PLAYER_REGEN_ENABLED") then
		-- Only reachable without restricted execution; see ApplyPageInsecure.
		self:ApplyPageInsecure(self:GetAttribute("state-page"))
	end
end

-- Blizzard's state-driver manager wrote a new page onto the bar. Everything the
-- `_onstate-page` snippet would have done from the restricted environment happens
-- here instead, minus whatever is protected while in combat.
ActionBar.OnAttributeChanged = function(self, name, value)
	if (name ~= "state-page") then return end

	self:ApplyPageInsecure(value)
end

ActionBar.ApplyPageInsecure = function(self, page)
	page = tonumber(page)
	-- UpdateStateDriver parks the attribute at "0" so the driver's first real answer
	-- always counts as a change. Page 0 is not a page.
	if (not page) or (page < 1) then return end

	-- The snippet reads these back off the bar's own attributes. Out of combat they
	-- are written the same way so nothing else has to learn a second route; in combat
	-- the Lua fields are set directly, which is not protected.
	--
	-- Booleans, never nil: UpdateButtonFlags treats a nil first argument as "not
	-- supplied, read the attributes", and those attributes go stale during a fight.
	local vehicle = page == GetBarIndex("GetVehicleBarIndex")
	local override = page == GetBarIndex("GetOverrideBarIndex")
	local tempshapeshift = page == GetBarIndex("GetTempShapeshiftBarIndex")
	local possess = page == (BONUS_BAR_OFFSET + 5)

	if (not InCombatLockdown()) then
		self:SetAttribute("hasvehiclebar", vehicle)
		self:SetAttribute("hasoverridebar", override)
		self:SetAttribute("hastempshapeshiftbar", tempshapeshift)
		self:SetAttribute("haspossessbar", possess)
		self:SetAttribute("state", page)
	end

	self:UpdateButtonFlags(vehicle, override, tempshapeshift, possess)

	for id,button in next,self.buttons do
		if (button.UpdateStateInsecure) then
			button:UpdateStateInsecure(page)
		end
	end

	self:UpdateFading()
end

-- The four flags are read off the bar's attributes when called from the snippet, and
-- passed in when the insecure page path has already worked them out.
ActionBar.UpdateButtonFlags = function(self, vehicle, override, tempshapeshift, possess)

	if (vehicle == nil) then
		vehicle = self:GetAttribute("hasvehiclebar")
		override = self:GetAttribute("hasoverridebar")
		tempshapeshift = self:GetAttribute("hastempshapeshiftbar")
		possess = self:GetAttribute("haspossessbar")
	end

	self.hasVehicleBar = vehicle
	self.hasOverrideBar = override
	self.hasTempShapeshiftBar = tempshapeshift
	self.hasPossessBar = possess

	for id,button in next,self.buttons do
		button.hasVehicleBar = self.hasVehicleBar
		button.hasOverrideBar = self.hasOverrideBar
		button.hasTempShapeshiftBar = self.hasTempShapeshiftBar
		button.hasPossessBar = self.hasPossessBar
	end

	-- Re-evaluate binding route after secure page/state transitions.
	self:UpdateBindings()
end

ActionBar.CreateButton = function(self, buttonConfig)

	local button = ButtonBar.CreateButton(self, buttonConfig)
	button:SetFrameLevel(self:GetFrameLevel() + 1)

	for k = 1,18 do
		button:SetState(k, "action", (k - 1) * NUM_ACTIONBAR_BUTTONS + button.id)
	end

	button:SetState(0, "action", (self.id - 1) * NUM_ACTIONBAR_BUTTONS + button.id)
	button:Show()
	button:SetAttribute("statehidden", nil)
	button:UpdateAction()

	-- The exit override swaps the button's `type` between pages, and `type` can only
	-- be written outside combat once the restricted environment is gone. A button
	-- left on "custom" would keep offering an exit that is no longer there, so the
	-- override is not installed at all there. VehicleExit.lua still provides the
	-- standalone dismount button, and it drives itself from `state-visibility`.
	if (self.id == 1 and button.id == 7 and hasSecureSnippets) then
		button:SetState(16, "custom", exitButton)
		button:SetState(17, "custom", exitButton)
		button:SetState(18, "custom", exitButton)
	end

	button.hasVehicleBar = self.hasVehicleBar
	button.hasOverrideBar = self.hasOverrideBar
	button.hasTempShapeshiftBar = self.hasTempShapeshiftBar
	button.hasPossessBar = self.hasPossessBar

	local buttonConfig = buttonConfig or button.config or {}
	buttonConfig.clickOnDown = self.config.clickOnDown
	buttonConfig.useCommandBindingsForHoldCast = self.config.useCommandBindingsForHoldCast
	buttonConfig.dimWhenResting = self.config.dimWhenResting
	buttonConfig.dimWhenInactive = self.config.dimWhenInactive
	buttonConfig.actionButtonUI = true
	buttonConfig.assistedHighlight = true
	-- LibActionButton calls the empty slot artwork a grid, and holds such slots
	-- at zero alpha unless this says otherwise.
	buttonConfig.showGrid = self.config.showEmptyButtons and true or false

	local keyBoundTarget = string_format(BINDTEMPLATE_BY_ID[self.id], button.id)
	button.keyBoundTarget = keyBoundTarget
	buttonConfig.keyBoundTarget = keyBoundTarget

	button:UpdateConfig(buttonConfig)
end

ActionBar.Enable = function(self)
	ButtonBar.Enable(self)
	self:Update()
end

ActionBar.Disable = function(self)
	ButtonBar.Disable(self)
	self:Update()
end

ActionBar.Update = function(self)
	if (InCombatLockdown()) then
		self:UpdateFading()
		return
	end

	self:UpdateButtonConfig()
	self:UpdateButtonCount()
	self:UpdateButtonLayout()
	self:UpdateStateDriver()
	self:UpdateVisibilityDriver()
	self:UpdateBindings()
	self:UpdateFading()
end

ActionBar.UpdateFading = function(self)
	if (not self:IsEnabled()) then
		LFF:UnregisterFrameForFading(self)
		for id, button in next,self.buttons do
			LFF:UnregisterFrameForFading(button)
		end
		RestoreFadeAlpha(self)
		return
	end
	if (not IsPlayerInWorld()) then return end

	local config, buttons = self.config, self.buttons

	if (config.enabled and config.enableBarFading) then

		-- Remove any previous fade registrations.
		for id = 1, #buttons do
			local button = buttons[id]
			LFF:UnregisterFrameForFading(button)
			ReleaseClickBlocker(button)
		end

		-- Register fading for selected buttons. An empty slot is only worth
		-- registering while the grid is on, since an already invisible button
		-- has nothing to fade. With the grid on it fades along with the rest
		-- instead of being left behind at full opacity.
		for id = config.fadeFrom or 1, #buttons do
			local button = buttons[id]
			if (button:GetTexture() or config.showEmptyButtons) then
				if (config.blockFadedClicks) then
					AcquireClickBlocker(button)
					button.OnFadeAlphaChanged = UpdateClickBlocker
					UpdateClickBlocker(button, button:GetAlpha())
				end
				LFF:RegisterFrameForFading(button, config.fadeAlone and self:GetName() or "actionbuttons", unpack(config.hitrects))
			else
				button:ForceUpdate()
			end
		end

	else

		-- Unregister all fading.
		LFF:UnregisterFrameForFading(self)
		for id, button in next,buttons do
			LFF:UnregisterFrameForFading(buttons[id])
			if (not button:GetTexture()) then
				button:ForceUpdate()
			end
		end
		RestoreFadeAlpha(self)
	end

end

ActionBar.UpdatePosition = function(self)
	if (InCombatLockdown()) then return end

	local config = self.config.savedPosition

	self:SetScale(config.scale)
	self:ClearAllPoints()
	self:SetPoint(config[1], UIParent, config[1], config[2]/config.scale, config[3]/config.scale)
end

ActionBar.UpdateAnchor = function(self)
	if (self.anchor) then

		local config = self.config.savedPosition

		self.anchor:SetSize(self:GetSize())
		self.anchor:SetScale(config.scale)
		self.anchor:ClearAllPoints()
		self.anchor:SetPoint(config[1], UIParent, config[1], config[2], config[3])
	end
end

ActionBar.UpdateButtonCount = function(self)
	ButtonBar.UpdateButtonCount(self)
end

ActionBar.UpdateButtonLayout = function(self)
	ButtonBar.UpdateButtonLayout(self)
end

ActionBar.UpdateBindings = function(self)
	if (InCombatLockdown()) then return end
	if (not next(self.buttons)) then return end

	ClearOverrideBindings(self)

	if (not self:IsEnabled()) then return end
	if (ns.API.IsHouseEditorActive()) then return end

	-- Bar 1 always uses click-route so that possess/vehicle/override/dragon
	-- state transitions work correctly even when entered in combat (where
	-- InCombatLockdown() would block any binding refresh). Click-route chains
	-- key → named button → button's current secure-paged action, which
	-- _onstate-page keeps correct regardless of combat lockdown.
	-- Hold-cast (clickOnDown) still functions through LAB's Keybind click type.
	-- Bars 2+ are stable pages so command-route (hold-cast) is safe there.
	--
	-- Without restricted execution the click route loses both of its advantages:
	-- `_onstate-page` no longer keeps the button current, and the "Keybind" click
	-- type is translated to a real mouse button by an OnClick wrapper that cannot be
	-- installed. The command route is then strictly better, because Blizzard's own
	-- ACTIONBUTTON/MULTIACTIONBAR commands page themselves inside the client and stay
	-- correct through a fight.
	local hasDynamicPageState = (self.id == 1) and hasSecureSnippets

	for id,button in pairs(self.buttons) do
		local bindingAction = button.keyBoundTarget
		if (bindingAction) then
			local useCommandBindings = self.config.useCommandBindingsForHoldCast ~= false
			local hasCustomVehicleState = button.state_types and button.state_types["16"] == "custom"
			local buttonName = button:GetName()

			-- iterate through the registered keys for the action
			for keyNumber = 1,select("#", GetBindingKey(bindingAction)) do

				-- get a key for the action
				local key = select(keyNumber, GetBindingKey(bindingAction))
				if (key and (key ~= "")) then
					local assigned = false
					-- Prefer command bindings for hold-cast support. During active bar-1 dynamic
					-- paging states (bonus/dragon/vehicle/override/possess), keep click routing
					-- so temporary actionbar slots stay in sync with the secure state driver.
					if (useCommandBindings and (not hasCustomVehicleState) and (not hasDynamicPageState) and SetOverrideBinding) then
						local ok = API.TryCall(SetOverrideBinding, self, false, key, bindingAction)
						if (ok) then
							assigned = true
						end
					end
					if (not assigned) then
						-- this is why we need named buttons
						SetOverrideBindingClick(self, false, key, buttonName, "Keybind") -- assign the key to our own button
					end
					button.__AzeriteUI_BindingMode = assigned and "command" or "click"
					button.__AzeriteUI_BindingRoute = assigned and bindingAction or ("CLICK "..tostring(buttonName)..":Keybind")
				end
			end
		end
	end
end

ActionBar.UpdateStateDriver = function(self)
	if (InCombatLockdown()) then return end

	-- CATA: check stances and states
	local statedriver
	if (self.id == 1) then
		statedriver = "[overridebar] possess; [possessbar] possess; [shapeshift] possess; [bonusbar:5] dragon; [form,noform] 0; [bar:2] 2; [bar:3] 3; [bar:4] 4; [bar:5] 5; [bar:6] 6"

		if (playerClass == "DRUID") then
			statedriver = statedriver .. "; [bonusbar:1] 7; [bonusbar:2] 8; [bonusbar:3] 9; [bonusbar:4] 10"

		elseif (playerClass == "MONK") then
			statedriver = statedriver .. "; [bonusbar:1] 7; [bonusbar:2] 8; [bonusbar:3] 9"

		elseif (playerClass == "ROGUE") then
			statedriver = statedriver .. "; [bonusbar:1] 7"
		end

		statedriver = statedriver .. "; 1"
	else
		statedriver = tostring(self.id)
	end

	-- The symbolic states above are resolved by `_onstate-page`. With no snippet to
	-- resolve them the driver has to arrive already numeric, so it is rebuilt from
	-- the same conditional list with the indices the client reports.
	if (not hasSecureSnippets) then
		local conditions, fallback = GetPageConditions(self.id)
		statedriver = BuildConditionalDriver(conditions, fallback, function(page) return page end)
	end

	UnregisterStateDriver(self, "page")
	self:SetAttribute("state-page", "0")
	RegisterStateDriver(self, "page", statedriver or "0")

	if (not hasSecureSnippets) then
		self:UpdateActionDrivers()
	end
end

-- One `action` attribute driver per button, carrying that button's slot for every
-- page the bar can reach.
--
-- This is the only part of paging that survives combat. Blizzard's state-driver
-- manager writes the attribute from its own untainted code, so the slot a button
-- casts follows a form change, a vehicle or an override bar mid-fight exactly as the
-- restricted environment used to make it. `type` stays whatever it was last given
-- outside combat, which is why the custom exit states are not installed here.
ActionBar.UpdateActionDrivers = function(self)
	if (InCombatLockdown()) then return end
	if (hasSecureSnippets) then return end

	local conditions, fallback = GetPageConditions(self.id)

	-- A bar that never pages has one slot per button for the whole session, already
	-- written by UpdateStateInsecure. Registering a constant driver for it would only
	-- add work to Blizzard's throttled rescan, which walks every driver in the game.
	if (not conditions) then return end

	for id,button in next,self.buttons do
		local slot = function(page)
			return (page - 1) * NUM_ACTIONBAR_BUTTONS + button.id
		end

		UnregisterAttributeDriver(button, "action")
		RegisterAttributeDriver(button, "action", BuildConditionalDriver(conditions, fallback, slot))
	end
end

ActionBar.UpdateVisibilityDriver = function(self)
	if (InCombatLockdown()) then return end

	local config = self.config

	local visdriver
	if (config.enabled) then

		visdriver = "[petbattle]hide;"

		if (config.visibility.possess) then
			visdriver = visdriver.."[possessbar]show;"
		else
			visdriver = visdriver.."[possessbar]hide;"
		end

		if (config.visibility.overridebar) then
			visdriver = visdriver.."[overridebar]show;"
		else
			visdriver = visdriver.."[overridebar]hide;"
		end

		if (config.visibility.vehicleui) then
			visdriver = visdriver.."[vehicleui]show;"
		else
			visdriver = visdriver.."[vehicleui]hide;"
		end

		if (config.visibility.dragon) then
			visdriver = visdriver.."[bonusbar:5]show;"
		else
			visdriver = visdriver.."[bonusbar:5]hide;"
		end

		-- Last of the conditionals on purpose. Skyriding counts as mounted, so
		-- [bonusbar:5] has to be settled before this or hiding while mounted
		-- would take the skyriding bar down with it.
		if (not config.visibility.mounted) then
			visdriver = visdriver.."[mounted]hide;"
		end

		visdriver = visdriver.."show"
	end

	-- `_onstate-vis` exists to fold `userhidden` into the driver's answer. Without a
	-- snippet the native `state-visibility` state does the show/hide itself, from
	-- Blizzard's own code, so it keeps working in combat - and `userhidden` needs no
	-- folding, because the only thing that sets it is Bar.Disable, which is always
	-- paired with config.enabled being false and therefore with a "hide" driver.
	if (not hasSecureSnippets) then
		UnregisterStateDriver(self, "vis")
		API.RegisterVisibilityDriver(self, visdriver or "hide")
		return
	end

	UnregisterStateDriver(self, "vis")
	self:SetAttribute("state-vis", "0")
	RegisterStateDriver(self, "vis", visdriver or "hide")
end

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
-- Nameplates, 10 of 10: the driver callback, mouseover, module events, profile migrations and enabling.
-- Loaded after Style.lua; see Settings.lua for how these files share their locals.
local _, ns = ...

local NP = ns.NamePlatesPrivate
if (not NP) then return end

local oUF = ns.oUF
local next = next

local NamePlatesMod = NP.NamePlatesMod
local defaults = NP.defaults
local FRIENDLY_NAME_ONLY_TARGET_SCALE_DEFAULT = NP.FRIENDLY_NAME_ONLY_TARGET_SCALE_DEFAULT
local NAMEPLATE_MAX_DISTANCE_DEFAULT = NP.NAMEPLATE_MAX_DISTANCE_DEFAULT
local NAMEPLATE_CASTBAR_OFFSET_DEFAULT = NP.NAMEPLATE_CASTBAR_OFFSET_DEFAULT
local FRIENDLY_NAMEPLATE_SCALE_DEFAULT = NP.FRIENDLY_NAMEPLATE_SCALE_DEFAULT
local ENEMY_NAMEPLATE_SCALE_DEFAULT = NP.ENEMY_NAMEPLATE_SCALE_DEFAULT
local FRIENDLY_NAMEPLATE_TARGET_SCALE_DEFAULT = NP.FRIENDLY_NAMEPLATE_TARGET_SCALE_DEFAULT
local GLOBAL_NAMEPLATE_TARGET_SCALE_DEFAULT = NP.GLOBAL_NAMEPLATE_TARGET_SCALE_DEFAULT
local LEGACY_FRIENDLY_NAMEPLATE_SCALE_DEFAULT = NP.LEGACY_FRIENDLY_NAMEPLATE_SCALE_DEFAULT
local LEGACY_ENEMY_NAMEPLATE_SCALE_DEFAULT = NP.LEGACY_ENEMY_NAMEPLATE_SCALE_DEFAULT
local LEGACY_FRIENDLY_NAMEPLATE_TARGET_SCALE_DEFAULT = NP.LEGACY_FRIENDLY_NAMEPLATE_TARGET_SCALE_DEFAULT
local LEGACY_GLOBAL_NAMEPLATE_TARGET_SCALE_DEFAULT = NP.LEGACY_GLOBAL_NAMEPLATE_TARGET_SCALE_DEFAULT
local PROMOTED_FRIENDLY_NAMEPLATE_TARGET_SCALE_DEFAULT = NP.PROMOTED_FRIENDLY_NAMEPLATE_TARGET_SCALE_DEFAULT
local PROMOTED_GLOBAL_NAMEPLATE_TARGET_SCALE_DEFAULT = NP.PROMOTED_GLOBAL_NAMEPLATE_TARGET_SCALE_DEFAULT
local UpdateNamePlateWidgetContainer = NP.UpdateNamePlateWidgetContainer
local SafeUnitMatches = NP.SafeUnitMatches
local IsUsingBlizzardGlobalScale = NP.IsUsingBlizzardGlobalScale
local ApplyNamePlateScale = NP.ApplyNamePlateScale
local ApplyFriendlyNameOnlyCVars = NP.ApplyFriendlyNameOnlyCVars
local RefreshActiveNamePlates = NP.RefreshActiveNamePlates
local GetDriverCVars = NP.GetDriverCVars
local ApplyNamePlateDriverSettings = NP.ApplyNamePlateDriverSettings
local ApplyPendingNamePlateStacking = NP.ApplyPendingNamePlateStacking
local ApplyPendingNamePlateVisibility = NP.ApplyPendingNamePlateVisibility
local NamePlate_PostUpdateElements = NP.NamePlate_PostUpdateElements
local NamePlate_NeedsSecondPass = NP.NamePlate_NeedsSecondPass
local NamePlate_PostUpdate = NP.NamePlate_PostUpdate
local NamePlate_OnEnter = NP.NamePlate_OnEnter
local NamePlate_OnLeave = NP.NamePlate_OnLeave
local NamePlate_RefreshSelection = NP.NamePlate_RefreshSelection
local style = NP.style
local IsVisibilityManagedCVar = NP.IsVisibilityManagedCVar
local IsBlizzardScaleCVar = NP.IsBlizzardScaleCVar
local IsBlizzardPlateSizeCVar = NP.IsBlizzardPlateSizeCVar
local IsFightingSomeoneElse = NP.IsFightingSomeoneElse
local ApplyNamePlateAlpha = NP.ApplyNamePlateAlpha
local CONTENT_TYPES = NP.CONTENT_TYPES
local GetCurrentContentType = NP.GetCurrentContentType
local GetContentSetting = NP.GetContentSetting
local UpdateExecuteMarker = NP.UpdateExecuteMarker

local callback = function(self, event, unit)
	if (event == "NAME_PLATE_UNIT_ADDED") then

		self.isPRD = SafeUnitMatches(unit, "player")

		if (self.WidgetContainer) then
			if (NamePlatesMod.db.profile.showBlizzardWidgets) then
				UpdateNamePlateWidgetContainer(self, true)

				local widgetFrames = self.WidgetContainer.widgetFrames

				if (widgetFrames) then
					for _, frame in next, widgetFrames do
						if (frame.Label) then
							frame.Label:SetAlpha(0)
						end
					end
				end
			else
				UpdateNamePlateWidgetContainer(self, false)
			end
		end

		if (self.SoftTargetFrame) then
			self.SoftTargetFrame:SetIgnoreParentAlpha(true)
			self.SoftTargetFrame:SetParent(self)
			self.SoftTargetFrame:ClearAllPoints()
			self.SoftTargetFrame:SetPoint("BOTTOM", self.Name, "TOP", 0, 0)
		end

		ns.NamePlates[self] = true
		ns.ActiveNamePlates[self] = true

		-- oUF lays the plate out right after this callback. See NamePlate_NeedsSecondPass.
		if (C_Timer and C_Timer.After) then
			C_Timer.After(0, function()
				if (self and self.unit == unit and NamePlate_NeedsSecondPass(self, unit)) then
					NamePlate_PostUpdate(self, "NAME_PLATE_UNIT_ADDED", unit)
				end
			end)
		end

	elseif (event == "NAME_PLATE_UNIT_REMOVED") then

		if (self.WidgetContainer) then
			if (NamePlatesMod.db.profile.showBlizzardWidgets) then
				UpdateNamePlateWidgetContainer(self, true)
			else
				UpdateNamePlateWidgetContainer(self, false)
			end
		end

		if (self.SoftTargetFrame) then
			self.SoftTargetFrame:SetIgnoreParentAlpha(false)
			if (self.blizzPlate) then
				self.SoftTargetFrame:SetParent(self.blizzPlate)
				self.SoftTargetFrame:ClearAllPoints()
				if (self.blizzPlate.name) then
					self.SoftTargetFrame:SetPoint("BOTTOM", self.blizzPlate.name, "TOP", 0, -8)
				end
			end
		end

		self.isPRD = nil
		self.inCombat = nil
		self.__AzeriteUI_CombatFaded = nil
		self.isFocus = nil
		self.isTarget = nil
		self.isSoftEnemy = nil
		self.isSoftInteract = nil
		self.isObjectPlate = nil
		self.nameplateShowsWidgetsOnly = nil

		if (self.RaidTargetIndicator) then
			self.RaidTargetIndicator:Hide()
		end
		if (self.Name) then
			self.Name:SetText("")
			self.Name:Hide()
		end

		ns.ActiveNamePlates[self] = nil
	end
end

-- Mouseover. UPDATE_MOUSEOVER_UNIT says the cursor reached a unit; nothing says it left, so a short
-- poll runs while a unit is under the cursor and stops when none is. (Two 20 Hz timers used to run
-- for the whole session, one of them repeating what the soft-target events already do.)
local MOUSEOVER
local UpdateMouseOver
UpdateMouseOver = function()
	if (not UnitExists("mouseover")) then
		if (MOUSEOVER) then
			NamePlate_OnLeave(MOUSEOVER)
			MOUSEOVER = nil
		end
		if (NamePlatesMod.mouseTimer) then
			NamePlatesMod:CancelTimer(NamePlatesMod.mouseTimer)
			NamePlatesMod.mouseTimer = nil
		end
		return
	end
	if (not NamePlatesMod.mouseTimer) then
		NamePlatesMod.mouseTimer = NamePlatesMod:ScheduleRepeatingTimer(UpdateMouseOver, 1/20)
	end
	if (MOUSEOVER) then
		if (SafeUnitMatches(MOUSEOVER.unit, "mouseover")) then
			return
		end
		NamePlate_OnLeave(MOUSEOVER)
		MOUSEOVER = nil
	end
	for frame in next, ns.ActiveNamePlates do
		if (SafeUnitMatches(frame.unit, "mouseover")) then
			MOUSEOVER = frame
			return NamePlate_OnEnter(MOUSEOVER)
		end
	end
end

-- Nameplate addons AzeriteUI's plates stand down for, by folder name. Returns the first one enabled,
-- which the options page names, or nothing.
NamePlatesMod.CheckForConflicts = function(self)
	for i,addon in next,{
		"BetterBlizzPlates",
		"ClassicPlatesPlus",
		"Kui_Nameplates",
		"NamePlateKAI",
		"Nameplates",
		"NDui",
		"NeatPlates",
		"Plater",
		"Platynator",
		"SimplePlates",
		"TidyPlates",
		"TidyPlates_ThreatPlates",
		"TidyPlatesContinued" } do
		if (ns.API.IsAddOnEnabled(addon)) then
			return addon
		end
	end
end

-- The combat filter's check: which enemy plates are fighting someone outside the group. A timer, not
-- events, since nothing announces a unit's threat table changing for someone else; it runs only while
-- the filter is on, and a pass touches only the plates whose answer changed.
local COMBAT_FILTER_INTERVAL = .5

NamePlatesMod.UpdateCombatFilter = function(self)
	for plate in next, ns.ActiveNamePlates do
		local faded = IsFightingSomeoneElse(plate)
		if (faded ~= (plate.__AzeriteUI_CombatFaded and true or false)) then
			plate.__AzeriteUI_CombatFaded = faded or nil
			ApplyNamePlateAlpha(plate)
		end
	end
end

NamePlatesMod.UpdateCombatFilterTimer = function(self)
	if (self.db.profile.combatFilter and self:IsEnabled()) then
		if (not self.combatFilterTimer) then
			self.combatFilterTimer = self:ScheduleRepeatingTimer(function() self:UpdateCombatFilter() end, COMBAT_FILTER_INTERVAL)
		end
		self:UpdateCombatFilter()
		return
	end
	if (self.combatFilterTimer) then
		self:CancelTimer(self.combatFilterTimer)
		self.combatFilterTimer = nil
	end
	for plate in next, ns.NamePlates do
		if (plate.__AzeriteUI_CombatFaded) then
			plate.__AzeriteUI_CombatFaded = nil
			ApplyNamePlateAlpha(plate)
		end
	end
end

NamePlatesMod.UpdateSettings = function(self)
	-- Check if the enabled state has changed. Standing down for another nameplate addon is not a
	-- change: counted as one, every setting changed on the page reloaded the interface.
	local isCurrentlyEnabled = self:IsEnabled()
	local shouldBeEnabled = self.db.profile.enabled and not self.conflictingAddOn

	if (isCurrentlyEnabled ~= shouldBeEnabled) then
		-- Enabled state changed - require a UI reload
		C_UI.Reload()
	elseif (isCurrentlyEnabled) then
		-- Only while these plates are in charge; otherwise the CVars belong to whoever is.
		ApplyFriendlyNameOnlyCVars()
		ApplyNamePlateDriverSettings(self)
		RefreshActiveNamePlates(true)
		self:UpdateCombatFilterTimer()
	end
end

-- Content settings, for the options page. Which kind of content is being edited is the page's own
-- state for the session, opening on the one the player is in.
NamePlatesMod.GetContentTypes = function(self)
	return CONTENT_TYPES
end
NamePlatesMod.GetEditedContent = function(self)
	return self.editedContent or GetCurrentContentType()
end
NamePlatesMod.SetEditedContent = function(self, contentType)
	self.editedContent = contentType
end
NamePlatesMod.GetContentValue = function(self, key)
	return GetContentSetting(self:GetEditedContent(), key)
end
NamePlatesMod.SetContentValue = function(self, key, value)
	local settings = self.db.profile.contentSettings[self:GetEditedContent()]
	if (not settings) then
		return
	end
	settings[key] = value
	self:UpdateSettings()
end

-- Target, focus and soft-target changes, once for all plates. Only a plate whose own state changed is
-- touched. A plate becoming the target is left to oUF, whose driver lays it out in full straight
-- after this event (Libs/oUF/ouf.lua:1003-1013); doing it here as well was the target plate's second
-- layout.
NamePlatesMod.OnSelectionChanged = function(self, event)
	for plate in next, ns.ActiveNamePlates do
		local unit = plate.unit
		if (event == "PLAYER_TARGET_CHANGED") then
			if (plate.isTarget and not SafeUnitMatches(unit, "target")) then
				plate.isTarget = false
				NamePlate_RefreshSelection(plate, event)
			end
		elseif (event == "PLAYER_FOCUS_CHANGED") then
			local isFocus = SafeUnitMatches(unit, "focus")
			if (isFocus ~= (plate.isFocus and true or false)) then
				plate.isFocus = isFocus
				NamePlate_RefreshSelection(plate, event)
			end
		else
			local key = (event == "PLAYER_SOFT_ENEMY_CHANGED") and "isSoftEnemy" or "isSoftInteract"
			local state = SafeUnitMatches(unit, (key == "isSoftEnemy") and "softenemy" or "softinteract")
			if (state ~= (plate[key] and true or false)) then
				plate[key] = state
				plate.isSoftTarget = (plate.isSoftEnemy or plate.isSoftInteract) and true or nil
				NamePlate_RefreshSelection(plate, event)
			end
		end
	end
end

-- Blizzard's driver sets every plate to its own size when its nameplate options or the display change
-- (Blizzard_NamePlates.lua, UpdateNamePlateSize), over the size the oUF driver set from our layout. Put
-- ours back on the next frame, once it has; in combat that waits like any driver refresh.
NamePlatesMod.ScheduleDriverRefresh = function(self)
	if (self.driverRefreshScheduled) then
		return
	end
	self.driverRefreshScheduled = true
	C_Timer.After(0, function()
		self.driverRefreshScheduled = nil
		if (self:IsEnabled()) then
			ApplyNamePlateDriverSettings(self)
		end
	end)
end

-- Entering combat changes what every plate shows (names, health text), so every plate is laid out,
-- once. Leaving combat is the module's full refresh, below.
NamePlatesMod.OnCombatStart = function(self, event)
	for plate in next, ns.ActiveNamePlates do
		plate.inCombat = true
		ApplyNamePlateScale(plate)
		NamePlate_PostUpdateElements(plate, event)
	end
end

NamePlatesMod.OnEvent = function(self, event, ...)
	if (event == "PLAYER_TARGET_CHANGED" or event == "PLAYER_FOCUS_CHANGED"
		or event == "PLAYER_SOFT_ENEMY_CHANGED" or event == "PLAYER_SOFT_INTERACT_CHANGED") then
		return self:OnSelectionChanged(event)
	elseif (event == "PLAYER_REGEN_DISABLED") then
		return self:OnCombatStart(event)
	elseif (event == "UPDATE_MOUSEOVER_UNIT") then
		return UpdateMouseOver()
	end
	if (event == "PLAYER_ENTERING_WORLD") then
		local isInitialLogin, isReloadingUi = ...
		ApplyFriendlyNameOnlyCVars()
		ApplyNamePlateDriverSettings(self)
		-- The zone decides only the alpha CVars, which the driver has just written. A real zone change
		-- removes and adds every plate around its loading screen anyway; login and reload lay out
		-- whatever is already there once.
		if (isInitialLogin or isReloadingUi) then
			RefreshActiveNamePlates(true)
		end
	elseif (event == "CHALLENGE_MODE_START" or event == "CHALLENGE_MODE_RESET" or event == "CHALLENGE_MODE_COMPLETED") then
		-- A key starting or ending turns a dungeon into Mythic+ and back without a loading screen.
		ApplyNamePlateDriverSettings(self)
	elseif (event == "UI_SCALE_CHANGED") then
		ApplyNamePlateDriverSettings(self)
		RefreshActiveNamePlates()
	elseif (event == "DISPLAY_SIZE_CHANGED") then
		self:ScheduleDriverRefresh()
	elseif (event == "CVAR_UPDATE") then
		local name = ...
		if (IsBlizzardScaleCVar(name) and IsUsingBlizzardGlobalScale()) then
			ApplyNamePlateDriverSettings(self)
			RefreshActiveNamePlates()
		elseif (IsVisibilityManagedCVar(name)) then
			RefreshActiveNamePlates()
		end
		if (IsBlizzardPlateSizeCVar(name)) then
			self:ScheduleDriverRefresh()
		end
	elseif (event == "PLAYER_REGEN_ENABLED") then
		if (self.pendingDriverRefresh) then
			ApplyNamePlateDriverSettings(self)
		end
		ApplyPendingNamePlateStacking(self)
		ApplyPendingNamePlateVisibility(self)
		-- A full pass on purpose: combat is when unit answers come back secret, and this is where a
		-- plate added under that restriction is read again with clear answers.
		RefreshActiveNamePlates()
	elseif (event == "NAME_PLATE_UNIT_ADDED") then
		local unit = ...
		if (unit == "preview") then
			return
		end
		if (unit and self.HideBlizzardNamePlateVisual) then
			if (C_Timer) then
				C_Timer.After(0, function() self.HideBlizzardNamePlateVisual(unit) end)
			else
				self.HideBlizzardNamePlateVisual(unit)
			end
		end
	end
end

NamePlatesMod.OnInitialize = function(self)
	-- Always register the database first so options can access it
	self.db = ns.db:RegisterNamespace("NamePlates", defaults)
	if (self.db and self.db.profile and (not self.db.profile.nameplateScaleModelVersion or self.db.profile.nameplateScaleModelVersion < 2)) then
		if (self.db.profile.friendlyNameOnlyTargetScale == FRIENDLY_NAME_ONLY_TARGET_SCALE_DEFAULT) then
			self.db.profile.friendlyNameOnlyTargetScale = false
		end
		self.db.profile.nameplateScaleModelVersion = 2
	end
	if (self.db and self.db.profile and self.db.profile.nameplateScaleModelVersion < 3) then
		if (self.db.profile.friendlyScale == LEGACY_FRIENDLY_NAMEPLATE_SCALE_DEFAULT) then
			self.db.profile.friendlyScale = FRIENDLY_NAMEPLATE_SCALE_DEFAULT
		end
		if (self.db.profile.enemyScale == LEGACY_ENEMY_NAMEPLATE_SCALE_DEFAULT) then
			self.db.profile.enemyScale = ENEMY_NAMEPLATE_SCALE_DEFAULT
		end
		if (self.db.profile.friendlyTargetScale == LEGACY_FRIENDLY_NAMEPLATE_TARGET_SCALE_DEFAULT) then
			self.db.profile.friendlyTargetScale = FRIENDLY_NAMEPLATE_TARGET_SCALE_DEFAULT
		end
		if (self.db.profile.enemyTargetScale == LEGACY_GLOBAL_NAMEPLATE_TARGET_SCALE_DEFAULT) then
			self.db.profile.enemyTargetScale = GLOBAL_NAMEPLATE_TARGET_SCALE_DEFAULT
		end
		if (self.db.profile.nameplateTargetScale == LEGACY_GLOBAL_NAMEPLATE_TARGET_SCALE_DEFAULT) then
			self.db.profile.nameplateTargetScale = GLOBAL_NAMEPLATE_TARGET_SCALE_DEFAULT
		end
		self.db.profile.nameplateScaleModelVersion = 3
	end
	if (self.db and self.db.profile and self.db.profile.nameplateScaleModelVersion < 4) then
		if (self.db.profile.friendlyTargetScale == PROMOTED_FRIENDLY_NAMEPLATE_TARGET_SCALE_DEFAULT) then
			self.db.profile.friendlyTargetScale = FRIENDLY_NAMEPLATE_TARGET_SCALE_DEFAULT
		end
		if (self.db.profile.enemyTargetScale == PROMOTED_GLOBAL_NAMEPLATE_TARGET_SCALE_DEFAULT) then
			self.db.profile.enemyTargetScale = GLOBAL_NAMEPLATE_TARGET_SCALE_DEFAULT
		end
		if (self.db.profile.nameplateTargetScale == PROMOTED_GLOBAL_NAMEPLATE_TARGET_SCALE_DEFAULT) then
			self.db.profile.nameplateTargetScale = GLOBAL_NAMEPLATE_TARGET_SCALE_DEFAULT
		end
		self.db.profile.nameplateScaleModelVersion = 4
	end
	if (self.db and self.db.profile and self.db.profile.nameplateScaleModelVersion < 5) then
		if (self.db.profile.friendlyScale == 1.95) then
			self.db.profile.friendlyScale = FRIENDLY_NAMEPLATE_SCALE_DEFAULT
		end
		if (self.db.profile.enemyTargetScale == 0) then
			self.db.profile.enemyTargetScale = .5
		end
		self.db.profile.nameplateScaleModelVersion = 5
	end
	if (self.db and self.db.profile and self.db.profile.nameplateScaleModelVersion < 6) then
		if (type(self.db.profile.maxDistance) ~= "number") then
			self.db.profile.maxDistance = NAMEPLATE_MAX_DISTANCE_DEFAULT
		end
		self.db.profile.nameplateScaleModelVersion = 6
	end
	if (self.db and self.db.profile and self.db.profile.nameplateScaleModelVersion < 7) then
		if (type(self.db.profile.castBarOffsetY) ~= "number") then
			self.db.profile.castBarOffsetY = NAMEPLATE_CASTBAR_OFFSET_DEFAULT
		end
		self.db.profile.nameplateScaleModelVersion = 7
	end
	if (self.db and self.db.profile and self.db.profile.nameplateScaleModelVersion < 8) then
		if (self.db.profile.castBarOffsetY == 0) then
			self.db.profile.castBarOffsetY = NAMEPLATE_CASTBAR_OFFSET_DEFAULT
		end
		self.db.profile.nameplateScaleModelVersion = 8
	end
	if (self.db and self.db.profile and self.db.profile.nameplateScaleModelVersion < 9) then
		if (self.db.profile.castBarOffsetY == 0) then
			self.db.profile.castBarOffsetY = NAMEPLATE_CASTBAR_OFFSET_DEFAULT
		end
		self.db.profile.nameplateScaleModelVersion = 9
	end
	if (self.db and self.db.profile and self.db.profile.nameplateScaleModelVersion < 10) then
		if (self.db.profile.castBarOffsetY == 8) then
			self.db.profile.castBarOffsetY = 0
		end
		self.db.profile.nameplateScaleModelVersion = 10
	end
	-- One maximum distance became one per kind of content (2026-09): a distance the player had set
	-- carries over to all of them.
	if (self.db and self.db.profile and self.db.profile.nameplateScaleModelVersion < 11) then
		local distance = self.db.profile.maxDistance
		if (type(distance) == "number" and distance ~= NAMEPLATE_MAX_DISTANCE_DEFAULT) then
			for _, contentType in ipairs(CONTENT_TYPES) do
				self.db.profile.contentSettings[contentType].maxDistance = distance
			end
		end
		self.db.profile.nameplateScaleModelVersion = 11
	end
	-- Check for conflicts with other nameplate addons
	self.conflictingAddOn = self:CheckForConflicts()
	if (self.conflictingAddOn) then return self:Disable() end

	-- If custom nameplates are disabled, don't enable the module
	if (not self.db.profile.enabled) then return self:Disable() end

	-- Only once these plates are in charge. Written before the two checks above, it overwrote the
	-- scale and friendly-name CVars of another nameplate addon, or of Blizzard's plates, every login.
	ApplyFriendlyNameOnlyCVars()

	LoadAddOn("Blizzard_NamePlates")

	self:HookNamePlates()
end

NamePlatesMod.OnEnable = function(self)
	if (ns.NameplateInterruptDB and ns.NameplateInterruptDB.SeedFromPlater) then
		ns.NameplateInterruptDB.SeedFromPlater()
	end

	oUF:RegisterStyle(ns.Prefix.."NamePlates", style)
	oUF:SetActiveStyle(ns.Prefix.."NamePlates")
	local driver = oUF:SpawnNamePlates(ns.Prefix)
	if (driver) then
		driver:SetAddedCallback(callback)
		driver:SetRemovedCallback(callback)
		driver:SetTargetCallback(callback)
		driver:SetCVars(GetDriverCVars())
		self.namePlateDriver = driver
	end
	ApplyNamePlateDriverSettings(self)

	self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEvent")
	self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnEvent")
	self:RegisterEvent("PLAYER_REGEN_DISABLED", "OnEvent")
	self:RegisterEvent("PLAYER_TARGET_CHANGED", "OnEvent")
	self:RegisterEvent("PLAYER_FOCUS_CHANGED", "OnEvent")
	self:RegisterEvent("PLAYER_SOFT_ENEMY_CHANGED", "OnEvent")
	self:RegisterEvent("PLAYER_SOFT_INTERACT_CHANGED", "OnEvent")
	self:RegisterEvent("UPDATE_MOUSEOVER_UNIT", "OnEvent")
	self:RegisterEvent("UI_SCALE_CHANGED", "OnEvent")
	self:RegisterEvent("DISPLAY_SIZE_CHANGED", "OnEvent")
	self:RegisterEvent("CVAR_UPDATE", "OnEvent")
	if (C_ChallengeMode) then
		self:RegisterEvent("CHALLENGE_MODE_START", "OnEvent")
		self:RegisterEvent("CHALLENGE_MODE_RESET", "OnEvent")
		self:RegisterEvent("CHALLENGE_MODE_COMPLETED", "OnEvent")
	end

	self:UpdateCombatFilterTimer()
	self:RegisterEvent("NAME_PLATE_UNIT_ADDED", "OnEvent")

	-- A spec, talent or spell change can move the execute threshold; only the markers follow it.
	if (ns.API.RegisterExecuteThresholdCallback and not self.executeThresholdCallback) then
		self.executeThresholdCallback = function()
			if (not self:IsEnabled() or not self.db.profile.executeMarker) then
				return
			end
			for plate in next, ns.ActiveNamePlates do
				UpdateExecuteMarker(plate)
			end
		end
		ns.API.RegisterExecuteThresholdCallback(self.executeThresholdCallback)
	end

end

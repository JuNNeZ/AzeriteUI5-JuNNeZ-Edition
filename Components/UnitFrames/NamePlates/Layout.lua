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
-- Nameplates, 7 of 10: the layout pass and the plate's own callbacks: shown, hidden, entered, left, its unit events.
-- Loaded after Castbar.lua; see Settings.lua for how these files share their locals.
local _, ns = ...

local NP = ns.NamePlatesPrivate
if (not NP) then return end

local next = next
local unpack = unpack

local NamePlatesMod = NP.NamePlatesMod
local BumpNamePlateAuraConfigVersion = NP.BumpNamePlateAuraConfigVersion
local UpdateNamePlateWidgetContainer = NP.UpdateNamePlateWidgetContainer
local SafeUnitMatches = NP.SafeUnitMatches
local GetNamePlateBarLayout = NP.GetNamePlateBarLayout
local ShouldUseFriendlyPlayerNameOnly = NP.ShouldUseFriendlyPlayerNameOnly
local SetNameColorForUnit = NP.SetNameColorForUnit
local ApplyNamePlateScale = NP.ApplyNamePlateScale
local AnchorStandardNamePlateCastBar = NP.AnchorStandardNamePlateCastBar
local ShouldShowNamePlateForBlizzardVisibility = NP.ShouldShowNamePlateForBlizzardVisibility
local ShouldShowObjectPlateOverlay = NP.ShouldShowObjectPlateOverlay
local ApplyObjectPlateVisualState = NP.ApplyObjectPlateVisualState
local ApplyHiddenNamePlateVisualState = NP.ApplyHiddenNamePlateVisualState
local ApplyNamePlateAlpha = NP.ApplyNamePlateAlpha
local SetNamePlateAurasShown = NP.SetNamePlateAurasShown
local ApplyFriendlyNameOnlyNameAnchor = NP.ApplyFriendlyNameOnlyNameAnchor
local ApplyFriendlyNameOnlyFontScale = NP.ApplyFriendlyNameOnlyFontScale
local ApplyFriendlyNameOnlyVisualState = NP.ApplyFriendlyNameOnlyVisualState
local TargetHighlight_Update = NP.TargetHighlight_Update
local Classification_Update = NP.Classification_Update
local NamePlate_PostUpdatePositions = NP.NamePlate_PostUpdatePositions
local NamePlate_PostUpdateHoverElements = NP.NamePlate_PostUpdateHoverElements
local UpdateExecuteMarker = NP.UpdateExecuteMarker
local NamePlate_ResetCastbarVisuals = NP.NamePlate_ResetCastbarVisuals
local NamePlate_ClearInterruptState = NP.NamePlate_ClearInterruptState
local NamePlate_UpdateInterruptWatcher = NP.NamePlate_UpdateInterruptWatcher
local NamePlate_ClearInterruptWatcher = NP.NamePlate_ClearInterruptWatcher
local Castbar_PostUpdate = NP.Castbar_PostUpdate
local NamePlate_Classify = NP.NamePlate_Classify

-- Every active plate laid out again from its unit. `settingsChanged` also redoes the bar setup that
-- only settings can change (orientation, textures, sizes; see NamePlate_PostUpdateElements).
local RefreshActiveNamePlates = function(settingsChanged)
	if (settingsChanged) then
		BumpNamePlateAuraConfigVersion()
	end
	for plate in next, ns.ActiveNamePlates do
		if (settingsChanged) then
			plate.__AzeriteUI_BarMode = nil
		end
		if (plate.UpdateAllElements) then
			plate:UpdateAllElements("ForceUpdate")
		end
	end
end

-- Callback that handles positions of elements
-- that change position within their frame.
-- Called on full updates and settings changes.
local NamePlate_PostUpdateElements = function(self, event, unit, ...)
	if (unit and unit ~= self.unit) then return end

	local db = ns.GetConfig("NamePlates")
	local showFriendlyPlayerNameOnly = ShouldUseFriendlyPlayerNameOnly(self)

	if (self.isObjectPlate and not self.isPRD) then
		SetNamePlateAurasShown(self, false)
		-- A recycled frame may still carry a name-only player's anchor and text size.
		ApplyFriendlyNameOnlyNameAnchor(self, db, false)
		ApplyFriendlyNameOnlyFontScale(self, false)
		if (ShouldShowObjectPlateOverlay(self)) then
			ApplyObjectPlateVisualState(self)
			NamePlate_PostUpdateHoverElements(self)
		else
			ApplyHiddenNamePlateVisualState(self)
		end
		return
	end

	if (not ShouldShowNamePlateForBlizzardVisibility(self)) then
		ApplyHiddenNamePlateVisualState(self)
		return
	end

	self.__AzeriteUI_AlphaHidden = nil
	ApplyNamePlateAlpha(self)
	if (self.SoftTargetFrame) then
		self.SoftTargetFrame:SetIgnoreParentAlpha(true)
		self.SoftTargetFrame:SetAlpha(1)
	end
	if (showFriendlyPlayerNameOnly) then
		ApplyFriendlyNameOnlyVisualState(self, true)
		SetNameColorForUnit(self, db)
		NamePlate_PostUpdatePositions(self)
		return
	end

	ApplyFriendlyNameOnlyVisualState(self, false)
	if (self.Health) then
		if (not self.Health:IsShown()) then
			self.Health:Show()
			if (self.Health.Backdrop) then
				self.Health.Backdrop:Show()
			end
		end
	end
	-- The hidden, object and name-only states hide the castbar. Showing it back unasked drew an idle
	-- bar, last fill and last spell name included, for the frame before oUF's OnUpdate hid it again
	-- (castbar.lua:658-662), on every mouseover. A bar hidden mid-cast asks oUF instead: CastStart
	-- shows it if the cast still runs, and clears it if the cast ended meanwhile (CastStop skips a
	-- hidden bar, castbar.lua:448). oUF shows an idle bar itself when the next cast starts.
	local castbar = self.Castbar
	if (castbar and not castbar:IsShown() and castbar.ForceUpdate
		and (castbar.casting or castbar.channeling or castbar.empowering)) then
		castbar:ForceUpdate()
	end
	-- What only changes with the plate's job - the personal resource display or any other plate -
	-- or with settings: applied once per job and again after a full refresh, which clears the
	-- mark. Anything a visual state can undo (alpha, shown state, anchors) stays below and runs
	-- every time; Power_PostUpdate moves the personal display's castbar, so its anchor is not here.
	local mode = self.isPRD and "prd" or "plate"
	if (self.__AzeriteUI_BarMode ~= mode) then
		self.__AzeriteUI_BarMode = mode

		local bars = GetNamePlateBarLayout(db)
		local mainOrientation = bars.mainOrientation
		local absorbOrientation = bars.absorbOrientation
		if (self.isPRD) then
			mainOrientation, absorbOrientation = absorbOrientation, mainOrientation
		end

		self.Health:SetOrientation(mainOrientation)
		self.Health:SetTexCoord(bars.texLeft, bars.texRight, bars.texTop, bars.texBottom)
		self.Health:SetReverseFill(false)
		self.Health:SetFlippedHorizontally(false)
		self.Health.__AzeriteUI_UseProductionNativeFill = true
		if (self.Health.Preview) then
			self.Health.Preview:SetOrientation(mainOrientation)
			self.Health.Preview:SetTexCoord(bars.texLeft, bars.texRight, bars.texTop, bars.texBottom)
			self.Health.Preview:SetReverseFill(false)
			self.Health.Preview:SetFlippedHorizontally(false)
		end
		self.Castbar:SetOrientation(mainOrientation)
		self.Castbar:SetTexCoord(bars.castTexLeft, bars.castTexRight, bars.castTexTop, bars.castTexBottom)
		if (self.Castbar.SetReverseFill) then
			self.Castbar:SetReverseFill(false)
		end
		self.Castbar:SetFlippedHorizontally(false)

		if (self.isPRD) then
			self.Castbar:SetSize(unpack(db.HealthBarSize))
			self.Castbar:SetSparkMap(db.HealthBarSparkMap)
			self.Castbar:SetStatusBarTexture(db.HealthBarTexture)
			self.Castbar:SetTexCoord(bars.texLeft, bars.texRight, bars.texTop, bars.texBottom)
			self.Castbar.Text:ClearAllPoints()
			self.Castbar.Text:SetPoint(unpack(db.CastBarNamePositionPlayer))
		else
			self.Castbar:SetSize(unpack(db.CastBarSize))
			self.Castbar:SetSparkMap(db.CastBarSparkMap)
			self.Castbar:SetStatusBarTexture(db.CastBarTexture)
			self.Castbar:SetTexCoord(bars.castTexLeft, bars.castTexRight, bars.castTexTop, bars.castTexBottom)
			self.Castbar.Text:ClearAllPoints()
			self.Castbar.Text:SetPoint(unpack(db.CastBarNamePosition))
		end
	end

	do
		local nativeTexture = self.Health:GetStatusBarTexture()
		if (nativeTexture and nativeTexture.SetAlpha) then
			nativeTexture:SetAlpha(1)
		end
		if (nativeTexture and nativeTexture.Show) then
			nativeTexture:Show()
		end
	end
	if (self.Health.Display) then
		self.Health.Display:SetAlpha(0)
		self.Health.Display:Hide()
	end

	if (self.isPRD) then
		self:SetIgnoreParentAlpha(false)
		SetNamePlateAurasShown(self, false)

		self.Castbar:ClearAllPoints()
		self.Castbar:SetAllPoints(self.Health)
		self.Castbar.Backdrop:Hide()

	else

		local profile = NamePlatesMod.db.profile
		SetNamePlateAurasShown(self, profile.showAuras and (not profile.showAurasOnTargetOnly or self.isTarget),
			event == "NAME_PLATE_UNIT_ADDED")

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

		if (self.isMouseOver or self.isTarget or self.isSoftTarget or self.inCombat) then
			-- SetIgnoreParentAlpha requires explicit true/false, or it'll bug out.
			self:SetIgnoreParentAlpha(((self.isMouseOver or self.isSoftTarget) and not self.isTarget) and true or false)
		else
			self:SetIgnoreParentAlpha(false)
		end

		AnchorStandardNamePlateCastBar(self)
		self.Castbar.Backdrop:Show()
	end
	UpdateExecuteMarker(self)

	SetNameColorForUnit(self, db)
	-- Name and health text. 5.3.29 skipped this on target and soft-target changes because it used
	-- to re-drive the castbar's interrupt colours and flipped other plates' casts grey; it no longer
	-- touches the castbar, and the skip was what kept a newly targeted plate from showing its name.
	if (self.Castbar) then
		Castbar_PostUpdate(self.Castbar)
	end
	NamePlate_PostUpdatePositions(self)
end

-- This is called on UpdateAllElements,
-- which is called when a frame is shown or its unit changed.
local NamePlate_PostUpdate = function(self, event, unit, ...)
	if (unit and unit ~= self.unit) then return end

	unit = unit or self.unit
	if (self.Castbar) then
		NamePlate_UpdateInterruptWatcher(self.Castbar, unit)
	end

	self.inCombat = InCombatLockdown()
	
	self.isFocus = SafeUnitMatches(unit, "focus")
	self.isTarget = SafeUnitMatches(unit, "target")
	self.isSoftEnemy = SafeUnitMatches(unit, "softenemy")
	self.isSoftInteract = SafeUnitMatches(unit, "softinteract")
	self.isSoftTarget = (self.isSoftEnemy or self.isSoftInteract) and true or nil
	self.__AzeriteUI_ClassKey = NamePlate_Classify(self, unit)

	-- Bar orientation is part of the bar setup NamePlate_PostUpdateElements applies once per job.
	if (self.isPRD) then
		self:DisableElement("RaidTargetIndicator")
	else
		if (self.nameplateShowsWidgetsOnly or self.isObjectPlate) then
			self:DisableElement("RaidTargetIndicator")
			if (self.RaidTargetIndicator) then
				self.RaidTargetIndicator:Hide()
			end
		else
			self:EnableElement("RaidTargetIndicator")
			self.RaidTargetIndicator:ForceUpdate()
		end
	end

	ApplyNamePlateScale(self)
	Classification_Update(self, event, unit, ...)
	TargetHighlight_Update(self, event, unit, ...)
	NamePlate_PostUpdateElements(self, event, unit, ...)
end

local NamePlate_OnEnter = function(self, ...)
	self.isMouseOver = true
	if (self.OnEnter) then
		self:OnEnter(...)
	end
end

local NamePlate_OnLeave = function(self, ...)
	self.isMouseOver = nil
	if (self.OnLeave) then
		self:OnLeave(...)
	end
end

local NamePlate_OnHide = function(self)
	self.inCombat = nil
	self.isFocus = nil
	self.isTarget = nil
	self.isSoftEnemy = nil
	self.isSoftInteract = nil
	self.canAttack = nil
	self.canAssist = nil
	self.isPlayerUnit = nil
	self.isObjectPlate = nil
	self.isFriendlyAssistableNPC = nil
	self.nameplateShowsWidgetsOnly = nil
	if (self.Castbar) then
		ns.API.ClearInterruptCastBarRefresh(self.Castbar)
		NamePlate_ClearInterruptState(self.Castbar)
		NamePlate_ClearInterruptWatcher(self.Castbar)
		NamePlate_ResetCastbarVisuals(self.Castbar)
	end

	if (self.RaidTargetIndicator) then
		self.RaidTargetIndicator:Hide()
	end
	if (self.Name) then
		self.Name:SetText("")
		self.Name:Hide()
	end
end

-- The plate's own unit events: its classification or its faction changed, so it is worked out again.
-- Target, focus, soft-target and combat changes are handled once for every plate by the module
-- (NamePlatesMod.OnSelectionChanged, OnCombatStart); each plate used to register them itself and
-- relay itself out on every one of them, whether it had changed or not.
local NamePlate_OnEvent = function(self, event, unit, ...)
	-- WoW 12 secret-value safety: unit can be secret in some events
	if (issecretvalue(unit)) then
		unit = nil -- Fall back to self.unit
	end
	if (unit and unit ~= self.unit) then return end
	NamePlate_PostUpdate(self, event, unit or self.unit, ...)
end

-- What a plate whose target, focus or soft-target state changed needs, and only that.
local NamePlate_RefreshSelection = function(self, event)
	ApplyNamePlateScale(self)
	Classification_Update(self, event, self.unit)
	TargetHighlight_Update(self, event, self.unit)
	NamePlate_PostUpdateElements(self, event)
end

NP.RefreshActiveNamePlates = RefreshActiveNamePlates
NP.NamePlate_PostUpdateElements = NamePlate_PostUpdateElements
NP.NamePlate_PostUpdate = NamePlate_PostUpdate
NP.NamePlate_OnEnter = NamePlate_OnEnter
NP.NamePlate_OnLeave = NamePlate_OnLeave
NP.NamePlate_OnHide = NamePlate_OnHide
NP.NamePlate_OnEvent = NamePlate_OnEvent
NP.NamePlate_RefreshSelection = NamePlate_RefreshSelection

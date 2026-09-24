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
-- Nameplates, 5 of 10: the element callbacks: health colour, power, outline, badge, name and health text, positions.
-- Loaded after Visibility.lua; see Settings.lua for how these files share their locals.
local _, ns = ...

local NP = ns.NamePlatesPrivate
if (not NP) then return end

local API = ns.API
local select = select
local unpack = unpack

local NamePlatesMod = NP.NamePlatesMod
local GetNamePlateRaidTargetSize = NP.GetNamePlateRaidTargetSize
local GetThreatColor = NP.GetThreatColor
local IsSafeTrue = NP.IsSafeTrue
local IsSafeFalse = NP.IsSafeFalse
local GetSafeColorByKey = NP.GetSafeColorByKey
local GetNamePlateWidgetLift = NP.GetNamePlateWidgetLift
local AnchorStandardNamePlateHealthBar = NP.AnchorStandardNamePlateHealthBar
local ShouldUseFriendlyPlayerNameOnly = NP.ShouldUseFriendlyPlayerNameOnly
local SetNameColorForUnit = NP.SetNameColorForUnit
local GetTargetLikeNameLift = NP.GetTargetLikeNameLift
local AnchorStandardNamePlateName = NP.AnchorStandardNamePlateName
local ShouldShowObjectPlateOverlay = NP.ShouldShowObjectPlateOverlay
local GetNamePlateExecuteThreshold = NP.GetNamePlateExecuteThreshold
local GetNamePlateBarLayout = NP.GetNamePlateBarLayout

-- Execute Marker
--------------------------------------------
-- A line across an enemy's health bar at the player's execute threshold, and the part of the bar
-- below it tinted once the enemy is inside it (Docs/Nameplates Overhaul Plan.md, Phase 8). The line
-- sits at a fixed share of the bar's layout width, so it reads no health. Whether the enemy is inside
-- is asked of UnitHealthPercent through a step curve the client evaluates; its answer is secret and
-- goes straight into SetAlpha, never into addon logic. Built the first time a plate needs it.
local WHITE = [[Interface\Buttons\WHITE8X8]]
local executeZoneCurves = {}

-- 1 below the threshold, 0 at or above it. False where the client has no curves.
local GetExecuteZoneCurve = function(threshold)
	local curve = executeZoneCurves[threshold]
	if (curve == nil) then
		curve = false
		if (C_CurveUtil and C_CurveUtil.CreateCurve and Enum and Enum.LuaCurveType and Enum.LuaCurveType.Step) then
			curve = C_CurveUtil.CreateCurve()
			curve:SetType(Enum.LuaCurveType.Step)
			curve:AddPoint(0, 1)
			curve:AddPoint(threshold, 0)
		end
		executeZoneCurves[threshold] = curve
	end
	return curve
end

-- On the health bar's overlay frame, so the shields and prediction do not cover it; below the text.
local CreateExecuteMarker = function(self)
	local db = ns.GetConfig("NamePlates")
	local parent = self.Health.Overlay or self.Health

	-- The bar's own art, cropped to the same share, so the tint has the bar's shape.
	local zone = parent:CreateTexture(nil, "ARTWORK", nil, -1)
	zone:SetTexture(db.HealthBarTexture)
	zone:SetVertexColor(unpack(db.ExecuteZoneColor))
	zone:SetAlpha(0)

	local line = parent:CreateTexture(nil, "ARTWORK", nil, 1)
	line:SetTexture(WHITE)
	line:SetVertexColor(unpack(db.ExecuteLineColor))
	line:SetSize(db.ExecuteLineWidth, db.HealthBarSize[2])

	local marker = { Zone = zone, Line = line, isShown = true }
	self.ExecuteMarker = marker
	return marker
end

-- The zone's alpha from the unit's health. Runs on every health update of a plate showing a marker.
local UpdateExecuteZone = function(self)
	local marker = self.ExecuteMarker
	if (not marker or not marker.isShown) then
		return
	end
	local alpha = 0
	local curve = GetExecuteZoneCurve(marker.threshold)
	if (curve and UnitHealthPercent and self.unit) then
		local ok, value = API.TryCall(UnitHealthPercent, self.unit, false, curve)
		if (ok and type(value) == "number") then
			alpha = value
		end
	end
	marker.Zone:SetAlpha(alpha)
end

-- Shown on plates the player can attack while the setting is on and there is a threshold; placed
-- again only when the threshold or the bar's fill direction changed.
local UpdateExecuteMarker = function(self)
	local marker = self.ExecuteMarker
	local profile = NamePlatesMod.db.profile
	local threshold = profile.executeMarker and GetNamePlateExecuteThreshold() or 0
	local show = threshold > 0 and self.canAttack and not self.isPRD and not self.isObjectPlate
		and not ShouldUseFriendlyPlayerNameOnly(self)
	if (not show) then
		if (marker and marker.isShown) then
			marker.isShown = false
			marker.Line:Hide()
			marker.Zone:Hide()
		end
		return
	end
	marker = marker or CreateExecuteMarker(self)

	-- A bar that fills from the right has its low end there, and the marker mirrors with it.
	local reverse = (self.Health.GetReverseFill and self.Health:GetReverseFill()) and true or false
	if (marker.threshold ~= threshold or marker.reverse ~= reverse) then
		marker.threshold = threshold
		marker.reverse = reverse

		local db = ns.GetConfig("NamePlates")
		local bars = GetNamePlateBarLayout(db)
		local width = db.HealthBarSize[1] * threshold
		local span = (bars.texRight - bars.texLeft) * threshold
		local edge = reverse and "RIGHT" or "LEFT"

		marker.Line:ClearAllPoints()
		marker.Line:SetPoint("CENTER", self.Health, edge, reverse and -width or width, 0)
		marker.Zone:ClearAllPoints()
		marker.Zone:SetPoint("TOP"..edge, self.Health, "TOP"..edge, 0, 0)
		marker.Zone:SetPoint("BOTTOM"..edge, self.Health, "BOTTOM"..edge, 0, 0)
		marker.Zone:SetWidth(width)
		if (reverse) then
			marker.Zone:SetTexCoord(bars.texRight - span, bars.texRight, bars.texTop, bars.texBottom)
		else
			marker.Zone:SetTexCoord(bars.texLeft, bars.texLeft + span, bars.texTop, bars.texBottom)
		end
	end
	if (not marker.isShown) then
		marker.isShown = true
		marker.Line:Show()
		marker.Zone:Show()
	end
	UpdateExecuteZone(self)
end

-- Element Callbacks
--------------------------------------------
-- Forceupdate health prediction on health updates,
-- to assure our smoothed elements are properly aligned.
local Health_PostUpdate = function(element, unit, cur, max)
	local predict = element.__owner.HealthPrediction
	if (predict) then
		predict:ForceUpdate()
	end
	UpdateExecuteZone(element.__owner)
end

local Health_UpdateColor = function(self, event, unit)
	if(not unit or self.unit ~= unit) then return end
	local element = self.Health
	local isConnected = UnitIsConnected(unit)
	local isPlayerControlled = UnitPlayerControlled(unit)
	local isPlayer = UnitIsPlayer(unit)
	local threatColor
	if (element.colorThreat and IsSafeFalse(isPlayerControlled)) then
		threatColor = GetThreatColor(self, UnitThreatSituation("player", unit))
	end
	local classHostilityAllowed = self.isPRD
		or not element.colorClassHostileOnly
		or IsSafeTrue(UnitCanAttack("player", unit))
	local useClassColor = classHostilityAllowed and (
		(element.colorClass and IsSafeTrue(isPlayer))
		or (element.colorClassNPC and IsSafeFalse(isPlayer))
		or (element.colorClassPet and IsSafeTrue(isPlayerControlled) and IsSafeFalse(isPlayer))
	)

	local r, g, b, color
	if (element.colorDisconnected and IsSafeFalse(isConnected)) then
		color = self.colors.disconnected
	elseif (element.colorTapping and IsSafeFalse(isPlayerControlled) and IsSafeTrue(UnitIsTapDenied(unit))) then
		color = self.colors.tapped
	elseif (threatColor) then
		color = threatColor
	elseif (useClassColor) then
		local _, class = UnitClass(unit)
		color = GetSafeColorByKey(self.colors.class, class, self.colors.health)
	elseif (element.colorReaction) then
		local reaction = UnitReaction(unit, "player")
		color = GetSafeColorByKey(self.colors.reaction, reaction, self.colors.health)
	elseif (element.colorSmooth) then
		local gradient = element.smoothGradient or (self.colors and self.colors.smooth)
		if (type(gradient) == "table" and gradient[1]) then
			r, g, b = self:ColorGradient(element.cur or 1, element.max or 1, unpack(gradient))
		else
			color = self.colors and self.colors.health
		end
	elseif (element.colorHealth) then
		color = self.colors.health
	end

	if (color) then
		r, g, b = color[1], color[2], color[3]
	end

	if (b) then
		element:SetStatusBarColor(r, g, b)

		local bg = element.bg
		if (bg) then
			local mu = bg.multiplier or 1
			bg:SetVertexColor(r * mu, g * mu, b * mu)
		end
	end

	--[[ Callback: Health:PostUpdateColor(unit, r, g, b)
	Called after the element color has been updated.

	* self - the Health element
	* unit - the unit for which the update has been triggered (string)
	* r    - the red component of the used color (number)[0-1]
	* g    - the green component of the used color (number)[0-1]
	* b    - the blue component of the used color (number)[0-1]
	--]]
	if (element.PostUpdateColor) then
		element:PostUpdateColor(unit, r, g, b)
	end
end

-- Update the health preview color on health color updates.
local Health_PostUpdateColor = function(element, unit, r, g, b)
	local preview = element.Preview
	if (preview and g) then
		preview:SetStatusBarColor(r * .7, g * .7, b * .7)
	end
end

-- Update power bar visibility if a frame
-- is the perrsonal resource display.
-- This callback only handles elements below the health bar.
local Power_PostUpdate = function(element, unit, cur, min, max)
	local self = element.__owner

	unit = unit or self.unit
	if (not unit) then
		return
	end

	local db = ns.GetConfig("NamePlates")
	local shouldShow

	if (self.isPRD) then
		local safeCur = cur
		local safeMax = max
		if (type(safeCur) ~= "number" or (issecretvalue and issecretvalue(safeCur))) then
			safeCur = element.safeCur or element.cur
		end
		if (type(safeMax) ~= "number" or (issecretvalue and issecretvalue(safeMax))) then
			safeMax = element.safeMax or element.max
		end
		if (type(safeCur) ~= "number" or type(safeMax) ~= "number") then
			safeCur, safeMax = nil, nil
		end
		if (safeCur and safeCur == 0) and (safeMax and safeMax == 0) then
			shouldShow = nil
		else
			shouldShow = safeMax and safeMax > 0
		end
	end

	local power = self.Power

	if (shouldShow) then
		if (power.isHidden) then
			power:SetAlpha(1)
			power.isHidden = false

			local cast = self.Castbar
			cast:ClearAllPoints()
			cast:SetPoint(unpack(db.CastBarPositionPlayer))
		end
	else
		if (not power.isHidden) then
			power:SetAlpha(0)
			power.isHidden = true

			local cast = self.Castbar
			cast:ClearAllPoints()
			cast:SetPoint(unpack(db.CastBarPosition))
		end
	end
end

-- Update targeting highlight outline
local TargetHighlight_Update = function(self, event, unit, ...)
	if (unit and unit ~= self.unit) then return end

	local element = self.TargetHighlight
	if (ShouldUseFriendlyPlayerNameOnly(self)) then
		return element:Hide()
	end

	if (self.isFocus or self.isTarget) then
		element:SetVertexColor(unpack(self.isFocus and element.colorFocus or element.colorTarget))
		element:Show()
	elseif (self.isSoftEnemy or self.isSoftInteract) then
		element:SetVertexColor(unpack(self.isSoftEnemy and element.colorSoftEnemy or element.colorSoftInteract))
		element:Show()
	else
		element:Hide()
	end
end

-- Update NPC classification badge for rares, elites and bosses.
local Classification_Update = function(self, event, unit, ...)
	if (unit and unit ~= self.unit) then return end

	local element = self.Classification
	unit = unit or self.unit

	if (UnitIsPlayer(unit) or not UnitCanAttack("player", unit)) then
		return element:Hide()
	end

	local l = UnitEffectiveLevel(unit)
	local c = (l and l < 1) and "worldboss" or UnitClassification(unit)
	if (c == "boss" or c == "worldboss") then
		element:SetTexture(element.bossTexture)
		element:Show()

	elseif (c == "elite") then
		element:SetTexture(element.eliteTexture)
		element:Show()

	elseif (c == "rare" or c == "rareelite") then
		element:SetTexture(element.rareTexture)
		element:Show()
	else
		element:Hide()
	end
end

-- The raid marker sits beside the health bar, where Blizzard's own 12.1 plates put it, on a spot
-- nothing else on the plate moves into; above the name on a name-only plate, which has no bar. It
-- used to ride on top of the aura rows and climb with every one, which cannot be done any more: the
-- native aura container keeps its size secret, and in combat addon code cannot see the auras to
-- count them.
local AnchorNamePlateRaidTarget = function(self)
	local raidTarget = self.RaidTargetIndicator
	if (not raidTarget) then
		return
	end
	local size = GetNamePlateRaidTargetSize()
	local nameOnly = ShouldUseFriendlyPlayerNameOnly(self) and true or false
	if (raidTarget.__AzeriteUI_Size == size and raidTarget.__AzeriteUI_NameOnly == nameOnly) then
		return
	end
	raidTarget.__AzeriteUI_Size = size
	raidTarget.__AzeriteUI_NameOnly = nameOnly

	local db = ns.GetConfig("NamePlates")
	raidTarget:SetSize(size, size)
	raidTarget:ClearAllPoints()
	if (nameOnly) then
		raidTarget:SetPoint("BOTTOM", self.Name, "TOP", 0, db.RaidTargetNameOnlyOffsetY or 0)
	else
		local point, relativePoint, x, y = unpack(db.RaidTargetPosition)
		raidTarget:SetPoint(point, self.Health, relativePoint, x, y)
	end
end

-- Messy callback that handles positions
-- of elements above the health bar.
local NamePlate_PostUpdatePositions = function(self)
	local db = ns.GetConfig("NamePlates")

	local auras = self.Auras
	local name = self.Name

	-- The PRD has neither name nor auras.
	if (not self.isPRD) then
		AnchorStandardNamePlateHealthBar(self)
		AnchorStandardNamePlateName(self)
		local hasName = ShouldUseFriendlyPlayerNameOnly(self) or NamePlatesMod.db.profile.showNameAlways or (self.isMouseOver or self.isSoftTarget or self.isTarget or self.inCombat) or false
		local nameOffset = hasName and (select(2, name:GetFont()) + auras.spacing + GetTargetLikeNameLift(self) + GetNamePlateWidgetLift(self)) or 0

		if (hasName ~= auras.usingNameOffset or nameOffset ~= auras.nameOffset or auras.usingNameOffset == nil) then
			if (hasName) then
				local point, x, y = unpack(db.AurasPosition)
				auras:ClearAllPoints()
				auras:SetPoint(point, x, y + nameOffset)
			else
				auras:ClearAllPoints()
				auras:SetPoint(unpack(db.AurasPosition))
			end
		end

		auras.usingNameOffset = hasName
		auras.nameOffset = nameOffset

		AnchorNamePlateRaidTarget(self)
	end
end

local NamePlate_ApplyHealthValueLayout = function(self)
	local value = self and self.Health and self.Health.Value
	if (not value) then
		return
	end

	local db = ns.GetConfig("NamePlates")
	local profile = NamePlatesMod and NamePlatesMod.db and NamePlatesMod.db.profile or nil
	local placement = profile and profile.healthValuePlacement or "below"
	local point

	if (placement == "inside") then
		point = db.HealthValuePositionInside or { "CENTER", 0, 0 }
	elseif (placement == "inside-combat" and self.inCombat) then
		point = db.HealthValuePositionInside or { "CENTER", 0, 0 }
	else
		point = db.HealthValuePosition
	end

	value:ClearAllPoints()
	value:SetPoint(unpack(point))
end

local NamePlate_PostUpdateHoverElements = function(self)
	local db = ns.GetConfig("NamePlates")
	SetNameColorForUnit(self, db)

	if (self.isObjectPlate and not self.isPRD) then
		if (ShouldShowObjectPlateOverlay(self)) then
			if (self.Name and self.Name.UpdateTag) then
				API.SafeCall("NamePlates.Name.UpdateTag", self.Name.UpdateTag, self.Name)
			end
			if (self.Name and self.unit) then
				local nameText = self.Name:GetText()
				local nameIsEmpty = (type(nameText) ~= "string") or (not issecretvalue(nameText) and nameText == "")
				if (nameIsEmpty) then
					local rawName = UnitName(self.unit)
					if (type(rawName) == "string") then
						self.Name:SetText(rawName)
					end
				end
			end
			if (self.Name) then
				self.Name:Show()
			end
		elseif (self.Name) then
			self.Name:Hide()
		end
		if (self.Health and self.Health.Value) then
			self.Health.Value:Hide()
		end
		return
	end

	if (self.isPRD) then
		self.Health.Value:Hide()
		self.Name:Hide()
	else
		if (ShouldUseFriendlyPlayerNameOnly(self)) then
			self.Name:Show()
			if (self.Health and self.Health.Value) then
				self.Health.Value:Hide()
			end
			return
		end

		local showNameAlways = NamePlatesMod.db.profile.showNameAlways

		-- Force tag update to ensure name is always current
		-- This is critical for dungeons where events may not fire reliably
		if (self.Name and self.Name.UpdateTag) then
			API.SafeCall("NamePlates.Name.UpdateTag", self.Name.UpdateTag, self.Name)
		end

		-- Fallback: if the tag returned empty (secret value filtered out),
		-- try setting the name directly via SetText which handles secrets.
		-- GetText() returns a secret if the fontstring has a secret text aspect,
		-- so we must use issecretvalue() before comparing with == to avoid errors.
		if (self.Name and self.unit) then
			local nameText = self.Name:GetText()
			local nameIsEmpty = (type(nameText) ~= "string") or (not issecretvalue(nameText) and nameText == "")
			if (nameIsEmpty) then
				local rawName = UnitName(self.unit)
				if (type(rawName) == "string") then
					self.Name:SetText(rawName)
				end
			end
		end

		if (self.isMouseOver or self.isTarget or self.isSoftTarget or self.inCombat) then
			local castbar = self.Castbar
			if (castbar and (castbar.casting or castbar.channeling or castbar.empowering)) then
				self.Health.Value:Hide()
			else
				NamePlate_ApplyHealthValueLayout(self)
				self.Health.Value:Show()
			end
			self.Name:Show()
		else
			if (showNameAlways) then
				self.Name:Show()
			else
				self.Name:Hide()
			end
			self.Health.Value:Hide()
		end
	end
end

-- Element proxy for the position updater above.
local Auras_PostUpdate = function(element, unit)
	NamePlate_PostUpdatePositions(element.__owner)
end

NP.UpdateExecuteMarker = UpdateExecuteMarker
NP.Health_PostUpdate = Health_PostUpdate
NP.Health_UpdateColor = Health_UpdateColor
NP.Health_PostUpdateColor = Health_PostUpdateColor
NP.Power_PostUpdate = Power_PostUpdate
NP.TargetHighlight_Update = TargetHighlight_Update
NP.Classification_Update = Classification_Update
NP.AnchorNamePlateRaidTarget = AnchorNamePlateRaidTarget
NP.NamePlate_PostUpdatePositions = NamePlate_PostUpdatePositions
NP.NamePlate_ApplyHealthValueLayout = NamePlate_ApplyHealthValueLayout
NP.NamePlate_PostUpdateHoverElements = NamePlate_PostUpdateHoverElements
NP.Auras_PostUpdate = Auras_PostUpdate

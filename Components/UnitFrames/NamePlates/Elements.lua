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
local Addon, ns = ...

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
local IsSecretValue = NP.IsSecretValue
local GetSafeColorByKey = NP.GetSafeColorByKey
local GetNamePlateWidgetLift = NP.GetNamePlateWidgetLift
local AnchorStandardNamePlateHealthBar = NP.AnchorStandardNamePlateHealthBar
local ShouldUseFriendlyPlayerNameOnly = NP.ShouldUseFriendlyPlayerNameOnly
local SetNameColorForUnit = NP.SetNameColorForUnit
local GetTargetLikeNameLift = NP.GetTargetLikeNameLift
local AnchorStandardNamePlateName = NP.AnchorStandardNamePlateName
local ShouldShowObjectPlateOverlay = NP.ShouldShowObjectPlateOverlay
local ShouldShowObjectPlateName = NP.ShouldShowObjectPlateName
local GetNamePlateExecuteThreshold = NP.GetNamePlateExecuteThreshold
local GetExecuteMarkerStyle = NP.GetExecuteMarkerStyle
local GetExecuteLeadCurve = NP.GetExecuteLeadCurve
local IsFightingYou = NP.IsFightingYou
local GetNamePlateBarLayout = NP.GetNamePlateBarLayout
local GetTankThreatState = NP.GetTankThreatState
local GetTankThreatColor = NP.GetTankThreatColor
local GetRoleThreatState = NP.GetRoleThreatState
local GetRoleThreatColor = NP.GetRoleThreatColor
local IsThreatScopeActive = NP.IsThreatScopeActive
local GetTankThreatPercent = NP.GetTankThreatPercent
local SafeUnitMatches = NP.SafeUnitMatches

-- Execute Marker
--------------------------------------------
-- A line across an enemy's health bar at the player's execute threshold, and the part of the bar
-- below it tinted once the enemy is inside it (Docs/Nameplates Overhaul Plan.md, Phase 8). The line
-- sits at a fixed share of the bar's layout width, so it reads no health. Whether the enemy is inside
-- is asked of UnitHealthPercent through a step curve the client evaluates; its answer is secret and
-- goes straight into SetAlpha, never into addon logic. Built the first time a plate needs it.
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

	-- A thin slice of the same art, so the line has the bar's silhouette: a plain rectangle
	-- reached past the shaped bar's top and bottom.
	local line = parent:CreateTexture(nil, "ARTWORK", nil, 1)
	line:SetTexture(db.HealthBarTexture)
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

	-- With a lead, the line appears only from threshold + lead down.
	local lineAlpha = 1
	if (marker.lead and marker.lead > 0 and UnitHealthPercent and self.unit) then
		lineAlpha = 0
		local leadCurve = GetExecuteLeadCurve(marker.threshold + marker.lead)
		if (leadCurve) then
			local ok, value = API.TryCall(UnitHealthPercent, self.unit, false, leadCurve)
			if (ok and type(value) == "number") then
				lineAlpha = value
			end
		end
	end
	marker.Line:SetAlpha(lineAlpha)
end

-- Shown on plates the player can attack while the setting is on and there is a threshold; placed
-- again only when the threshold or the bar's fill direction changed.
local UpdateExecuteMarker = function(self)
	local marker = self.ExecuteMarker
	local profile = NamePlatesMod.db.profile
	local threshold = profile.executeMarker and GetNamePlateExecuteThreshold() or 0
	local show = threshold > 0 and self.canAttack and not self.isPRD and not self.isObjectPlate
		and not ShouldUseFriendlyPlayerNameOnly(self)
		and (not profile.executeCombatOnly or IsFightingYou(self))
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
		-- The line's slice of the art, one layout pixel either side of the threshold.
		local sample = reverse and (bars.texRight - span) or (bars.texLeft + span)
		local half = (bars.texRight - bars.texLeft) * (db.ExecuteLineWidth / 2) / db.HealthBarSize[1]
		marker.Line:SetTexCoord(math.max(bars.texLeft, sample - half), math.min(bars.texRight, sample + half), bars.texTop, bars.texBottom)
	end

	-- The player's colours and lead, shared with the target frame.
	local lead, lineColor, zoneColor = GetExecuteMarkerStyle()
	marker.lead = lead
	-- A colour change stores a new table, so comparing the tables is enough.
	if (marker.lineColor ~= lineColor or marker.zoneColor ~= zoneColor or not marker.colored) then
		local db = ns.GetConfig("NamePlates")
		marker.lineColor, marker.zoneColor, marker.colored = lineColor, zoneColor, true
		marker.Line:SetVertexColor(unpack(lineColor or db.ExecuteLineColor))
		marker.Zone:SetVertexColor(unpack(zoneColor or db.ExecuteZoneColor))
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
	local owner = element.__owner
	local predict = owner.HealthPrediction
	if (predict) then
		predict:ForceUpdate()
	end
	UpdateExecuteZone(owner)
	-- A death (or a resurrection) decides whether the plate shows at all (NP.IsDeadNPC), and none of
	-- the plate's own events fire on one; its health does. Layout.lua loads later, hence the lookup.
	local dead = NP.IsDeadNPC(owner)
	if (dead ~= (owner.__AzeriteUI_Dead or false)) then
		owner.__AzeriteUI_Dead = dead
		NP.NamePlate_PostUpdateElements(owner, "UNIT_HEALTH", unit)
	end
end

-- Tank mode extras (Visibility.lua, GetTankThreatState)
--------------------------------------------
-- The name of whoever a mob you do not hold is hitting, under its plate, in their class colour: in
-- tank mode a lost or co-tanked mob, in healer mode a loose one. The
-- name and class may be secret; they only go into SetText and, through C_ClassColor, SetTextColor.
-- Hidden while the castbar shows: its own cast target sits in the same place.
local TankTarget_Update = function(self)
	local text = self and self.TankTarget
	if (not text) then
		return
	end
	local state = self.__AzeriteUI_TankState
	local profile = NamePlatesMod.db and NamePlatesMod.db.profile
	local castbar = self.Castbar
	local unit = self.unit
	if (profile and profile.tankTargetNames and (state == "lost" or state == "cotank" or self.__AzeriteUI_RoleState == "loose")
		and type(unit) == "string" and not (castbar and castbar:IsShown())) then
		local target = unit .. "target"
		if (IsSafeTrue(UnitExists(target)) and not SafeUnitMatches(target, "player")) then
			local name = UnitName(target)
			if (IsSecretValue(name) or type(name) == "string") then
				text:SetText(name)
				local base = ns.GetConfig("NamePlates").TankTargetColor
				text:SetTextColor(base[1], base[2], base[3], base[4] or 1)
				if (IsSafeTrue(UnitIsPlayer(target)) and C_ClassColor and C_ClassColor.GetClassColor) then
					API.TryCall(function()
						local _, class = UnitClass(target)
						local color = C_ClassColor.GetClassColor(class)
						if (color) then
							local r, g, b = color:GetRGB()
							text:SetTextColor(r, g, b, 1)
						end
					end)
				end
				text:Show()
				return
			end
		end
	end
	text:Hide()
end

-- Threat alerts (2026-11-08)
--------------------------------------------
-- Three alerts: "lost" (tank mode: a mob you held went to someone who is not a tank), "close" (healer
-- and DPS: your threat reached the warning or you are above the tank) and "aggro" (healer and DPS: a
-- mob turned on you). Each has its own switch and sound; the effects (sound, screen edge flash,
-- nameplate pulse, text in the middle of the screen) are shared. An alert fires at most once per
-- THREAT_ALERT_INTERVAL for all plates together, and only where the threat roles work
-- (Visibility.lua, IsThreatScopeActive). Names go to SetText only, so a secret one is fine.
local THREAT_ALERT_INTERVAL = 2
local THREAT_ALERTS = {
	lost = { switch = "tankLostAggroSound", file = "tankLostAggroSoundFile", sound = "RAID_WARNING", soundID = 8959,
		text = "Mob lost", nameOf = "target" },
	close = { switch = "threatWarnSound", file = "threatWarnSoundFile", sound = "UI_RAID_BOSS_WHISPER_WARNING", soundID = 37666,
		text = "Threat close", nameOf = "unit" },
	aggro = { switch = "threatAggroSound", file = "threatAggroSoundFile", sound = "RAID_WARNING", soundID = 8959,
		text = "Aggro!", nameOf = "unit" }
}
local THREAT_ALERT_FALLBACK_COLOR = { 1, .25, .25 }
local lastThreatAlert = {}

local localeTable
local GetLocaleText = function(key)
	if (localeTable == nil) then
		local lib = LibStub and LibStub("AceLocale-3.0", true)
		localeTable = lib and lib:GetLocale(Addon, true) or false
	end
	return localeTable and localeTable[key] or key
end

local GetAlertColor = function(kind)
	local color
	if (kind == "lost") then
		color = GetTankThreatColor("lost")
	else
		color = GetRoleThreatColor(kind)
	end
	return color or THREAT_ALERT_FALLBACK_COLOR
end

-- Plays an alert's sound: "Default" (or nothing chosen) is the game's own warning, anything else a
-- LibSharedMedia sound by name, falling back to the game's when the name is not registered.
-- For the options page too, which plays a sound as it is chosen.
local PlayThreatAlertSound = function(kind, choice)
	local alert = THREAT_ALERTS[kind]
	if (not alert) then
		return
	end
	if (type(choice) == "string" and choice ~= "" and choice ~= "Default" and type(PlaySoundFile) == "function") then
		local lsm = LibStub and LibStub("LibSharedMedia-3.0", true)
		local file = lsm and lsm:Fetch("sound", choice, true)
		if (type(file) == "string" or type(file) == "number") then
			PlaySoundFile(file, "Master")
			return
		end
	end
	if (type(PlaySound) == "function") then
		PlaySound(SOUNDKIT and SOUNDKIT[alert.sound] or alert.soundID, "Master")
	end
end

-- One frame fades every effect: up for the first quarter, down for the rest, then hidden.
local fadingEffects = {}
local effectFader
local StartEffectFade = function(region, duration, peak)
	if (not region) then
		return
	end
	if (not effectFader) then
		effectFader = CreateFrame("Frame")
		effectFader:Hide()
		effectFader:SetScript("OnUpdate", function(frame)
			local now = GetTime()
			for faded, fade in next, fadingEffects do
				local progress = (now - fade.start) / fade.duration
				if (progress >= 1) then
					fadingEffects[faded] = nil
					faded:SetAlpha(0)
					faded:Hide()
				else
					local level = progress < .25 and (progress / .25) or ((1 - progress) / .75)
					faded:SetAlpha(level * fade.peak)
				end
			end
			if (not next(fadingEffects)) then
				frame:Hide()
			end
		end)
	end
	fadingEffects[region] = { start = GetTime(), duration = duration, peak = peak }
	region:SetAlpha(0)
	region:Show()
	effectFader:Show()
end

-- The screen edge flash: the game's low health edge, over everything, never taking the mouse.
local screenFlash
local FlashScreenEdge = function()
	if (not screenFlash) then
		screenFlash = CreateFrame("Frame", nil, UIParent)
		screenFlash:SetAllPoints(UIParent)
		screenFlash:SetFrameStrata("FULLSCREEN_DIALOG")
		if (screenFlash.EnableMouse) then
			screenFlash:EnableMouse(false)
		end
		local texture = screenFlash:CreateTexture(nil, "BACKGROUND")
		texture:SetAllPoints(screenFlash)
		texture:SetTexture([[Interface\FullScreenTextures\LowHealth]])
		texture:SetBlendMode("ADD")
		screenFlash.Texture = texture
		screenFlash:Hide()
	end
	StartEffectFade(screenFlash, .8, 1)
end

-- The text in the middle of the screen: what happened, and under it the mob's name or, for a lost
-- mob, who it went to.
local alertText
local ShowAlertText = function(kind, name)
	if (not alertText) then
		local db = ns.GetConfig("NamePlates")
		alertText = CreateFrame("Frame", nil, UIParent)
		alertText:SetSize(400, 60)
		alertText:SetPoint(unpack(db.ThreatAlertTextPosition or { "CENTER", UIParent, "CENTER", 0, 180 }))
		alertText:SetFrameStrata("HIGH")
		local message = alertText:CreateFontString(nil, "OVERLAY")
		message:SetFontObject(db.ThreatAlertTextFont or API.GetFont(26, true))
		message:SetPoint("TOP", alertText, "TOP", 0, 0)
		local who = alertText:CreateFontString(nil, "OVERLAY")
		who:SetFontObject(db.ThreatAlertNameFont or API.GetFont(16, true))
		who:SetPoint("TOP", message, "BOTTOM", 0, -2)
		alertText.Message, alertText.Name = message, who
		alertText:Hide()
	end
	local color = GetAlertColor(kind)
	alertText.Message:SetText(GetLocaleText(THREAT_ALERTS[kind].text))
	alertText.Message:SetTextColor(color[1], color[2], color[3], 1)
	alertText.Name:SetText(name or "")
	StartEffectFade(alertText, 2, 1)
end

-- The plate's own glow, in the alert's colour (Style.lua makes it, behind the health bar).
local PulsePlate = function(self, kind)
	local pulse = self and self.ThreatPulse
	if (not pulse) then
		return
	end
	local color = GetAlertColor(kind)
	pulse:SetVertexColor(color[1], color[2], color[3], 1)
	StartEffectFade(pulse, 1, 1)
end

local GetAlertName = function(self, kind)
	local unit = self and self.unit
	if (type(unit) ~= "string") then
		return nil
	end
	if (THREAT_ALERTS[kind].nameOf == "target") then
		unit = unit .. "target"
	end
	if (not IsSafeTrue(UnitExists(unit))) then
		return nil
	end
	local name = UnitName(unit)
	if (IsSecretValue(name) or type(name) == "string") then
		return name
	end
end

local FireThreatAlert = function(self, kind)
	local alert = THREAT_ALERTS[kind]
	local profile = NamePlatesMod.db and NamePlatesMod.db.profile
	if (not alert or not profile or not profile[alert.switch] or not IsThreatScopeActive()) then
		return
	end
	local now = GetTime()
	if (lastThreatAlert[kind] and now - lastThreatAlert[kind] < THREAT_ALERT_INTERVAL) then
		return
	end
	lastThreatAlert[kind] = now
	if (profile.threatAlertSoundOn ~= false) then
		PlayThreatAlertSound(kind, profile[alert.file])
	end
	if (profile.threatAlertFlash) then
		FlashScreenEdge()
	end
	if (profile.threatAlertPulse) then
		PulsePlate(self, kind)
	end
	if (profile.threatAlertText) then
		ShowAlertText(kind, GetAlertName(self, kind))
	end
end

-- Stores the plate's tank state and its threat percent (Visibility.lua, GetTankThreatPercent: the
-- group's highest on a mob you hold, yours on a lost one), and, when a mob you held went to someone
-- who is not a tank, fires the lost alert. The percent asks the whole group, so at most once per
-- TANK_PERCENT_INTERVAL per plate (twice that in a raid) unless the state changed.
local TANK_PERCENT_INTERVAL = .5
local TankThreat_Update = function(self, state)
	local previous = self.__AzeriteUI_TankState
	self.__AzeriteUI_TankState = state or nil
	if (state == "lost" and (previous == "held" or previous == "slipping")) then
		FireThreatAlert(self, "lost")
	end
	if (state) then
		local now = GetTime()
		local interval = (IsInRaid and IsInRaid()) and TANK_PERCENT_INTERVAL * 2 or TANK_PERCENT_INTERVAL
		if (state ~= previous or not self.__AzeriteUI_TankPercentAt or now - self.__AzeriteUI_TankPercentAt >= interval) then
			self.__AzeriteUI_TankPercentAt = now
			self.__AzeriteUI_TankPercent = GetTankThreatPercent(self, state)
		end
	else
		self.__AzeriteUI_TankPercent, self.__AzeriteUI_TankPercentAt = nil, nil
	end
	TankTarget_Update(self)
end

-- Healer and DPS mode extras (Visibility.lua, GetRoleThreatState)
--------------------------------------------
-- Your threat on the mob inside the bar's right end, in the state's colour, only where the threat
-- roles work (IsThreatScopeActive; solo it is mostly 100% on you) and only while the castbar is not
-- up. The percent is a plain number: GetRoleThreatState hands out nil for a secret one.
local ThreatPercent_Update = function(self)
	local text = self and self.ThreatPercent
	if (not text) then
		return
	end
	local profile = NamePlatesMod.db and NamePlatesMod.db.profile
	local state, percent = self.__AzeriteUI_RoleState, self.__AzeriteUI_RolePercent
	local GetColor = GetRoleThreatColor
	if (not state) then
		-- Tank mode: the group's highest on a mob you hold, yours on a lost one.
		state, percent, GetColor = self.__AzeriteUI_TankState, self.__AzeriteUI_TankPercent, GetTankThreatColor
	end
	local castbar = self.Castbar
	if (profile and profile.threatPercentPlates and state and type(percent) == "number"
		and IsThreatScopeActive() and not (castbar and castbar:IsShown())) then
		if (percent < 0) then
			percent = 0
		elseif (percent > 999) then
			percent = 999
		end
		text:SetText(string.format("%d%%", math.floor(percent + .5)))
		local color = GetColor(state) or ns.GetConfig("NamePlates").ThreatPercentColor
		text:SetTextColor(color[1], color[2], color[3], color[4] or 1)
		text:Show()
		return
	end
	text:Hide()
end

-- Stores the plate's healer/DPS state and fires the two alerts (FireThreatAlert): close when your
-- threat on a mob comes close (close or pulling, from a calmer state), aggro when a mob turns on you.
local ROLE_CALM_STATES = { safe = true, loose = true }
local RoleThreat_Update = function(self, state, percent)
	local previous = self.__AzeriteUI_RoleState
	self.__AzeriteUI_RoleState = state or nil
	self.__AzeriteUI_RolePercent = state and percent or nil
	if (state and state ~= previous) then
		if (state == "aggro") then
			FireThreatAlert(self, "aggro")
		elseif ((state == "close" or state == "pulling") and (not previous or ROLE_CALM_STATES[previous])) then
			FireThreatAlert(self, "close")
		end
	end
	-- The target name follows in TankThreat_Update and the percent after it, both from Health_UpdateColor.
end

local Health_UpdateColor = function(self, event, unit)
	if(not unit or self.unit ~= unit) then return end
	local element = self.Health
	local isConnected = UnitIsConnected(unit)
	local isPlayerControlled = UnitPlayerControlled(unit)
	local isPlayer = UnitIsPlayer(unit)
	local threatColor
	if (element.colorThreat and IsSafeFalse(isPlayerControlled)) then
		local status = UnitThreatSituation("player", unit)
		-- Tank mode decides alone when it applies; held on the default preset is no threat colour.
		local tankState = GetTankThreatState(self, status)
		local roleState, rolePercent
		if (tankState == nil) then
			roleState, rolePercent = GetRoleThreatState(self, status)
		end
		-- The role state first: the target name reads it when tank mode's update redraws it.
		RoleThreat_Update(self, roleState, rolePercent)
		TankThreat_Update(self, tankState)
		ThreatPercent_Update(self)
		if (tankState ~= nil) then
			threatColor = tankState and GetTankThreatColor(tankState) or nil
		elseif (roleState ~= nil) then
			threatColor = roleState and GetRoleThreatColor(roleState) or nil
		else
			threatColor = GetThreatColor(self, status)
		end
	else
		RoleThreat_Update(self, nil)
		TankThreat_Update(self, nil)
		ThreatPercent_Update(self)
	end
	local canAttack = UnitCanAttack("player", unit)
	local classHostilityAllowed = self.isPRD
		or not element.colorClassHostileOnly
		or IsSafeTrue(canAttack)
	-- Players follow the per-side switches on the Nameplates page (Class colors).
	local profile = NamePlatesMod.db and NamePlatesMod.db.profile
	local playerClassAllowed = self.isPRD
		or not element.colorClassHostileOnly
		or (IsSafeTrue(canAttack) and not (profile and profile.classColorEnemyPlayers == false))
		or (IsSafeFalse(canAttack) and profile and profile.classColorFriendlyPlayers)
	local useClassColor = (element.colorClass and IsSafeTrue(isPlayer) and playerClassAllowed)
		or (classHostilityAllowed and (
			(element.colorClassNPC and IsSafeFalse(isPlayer))
			or (element.colorClassPet and IsSafeTrue(isPlayerControlled) and IsSafeFalse(isPlayer))
		))

	local r, g, b, color
	if (element.colorDisconnected and IsSafeFalse(isConnected)) then
		color = self.colors.disconnected
	elseif (element.colorTapping and IsSafeFalse(isPlayerControlled) and IsSafeTrue(UnitIsTapDenied(unit))) then
		color = self.colors.tapped
	elseif (threatColor) then
		color = threatColor
	elseif (useClassColor) then
		local _, class = UnitClass(unit)
		if (IsSecretValue(class)) then
			-- UnitClass is SecretWhenUnitIdentityRestricted (PvP). C_ClassColor takes secret
			-- arguments from addons and its colour goes straight to the widgets, as Plater and
			-- Platynator do; no test or arithmetic on it below.
			local classColor = C_ClassColor and C_ClassColor.GetClassColor and C_ClassColor.GetClassColor(class)
			if (type(classColor) == "table") then
				local sr, sg, sb = classColor.r, classColor.g, classColor.b
				element:SetStatusBarColor(sr, sg, sb)
				if (element.bg) then
					element.bg:SetVertexColor(sr, sg, sb)
				end
				if (element.PostUpdateColor) then
					element:PostUpdateColor(unit, sr, sg, sb)
				end
				return
			end
			color = self.colors.health
		else
			color = GetSafeColorByKey(self.colors.class, class, self.colors.health)
		end
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
	if (preview and IsSecretValue(g)) then
		-- A secret class colour (Health_UpdateColor) cannot be darkened here.
		preview:SetStatusBarColor(r, g, b)
	elseif (preview and g) then
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
	-- Object plates have no bar for the outline to frame (Blizzard draws neither on objects).
	if (self.isObjectPlate or ShouldUseFriendlyPlayerNameOnly(self)) then
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
				self.Name:SetShown(ShouldShowObjectPlateName(self))
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

-- Quest Marker
--------------------------------------------
-- A mark beside the health bar on units that belong to one of your active quests, from
-- C_QuestLog.UnitIsRelatedToActiveQuest (both clients; not documented as secret, and a
-- secret answer hides the mark). It sits where the raid marker goes and steps aside
-- while a raid marker is shown. Updated when a plate is set up, when its raid marker
-- changes, and when the quest log changes (Module.lua).
-- Quest progress ("3/10" or "40%") beside the mark (showQuestProgress). No API ties a unit to an
-- objective; the unit's tooltip lists the objectives it counts toward, as QuestObjective lines
-- (Enum.TooltipDataLineType, 8 on Retail and Forever alike). The first unfinished one is shown.
-- Any secret table, line or text gives nothing, so the mark shows alone. The number is read out
-- of the line's text: "x/y" first, then "y%", both written with digits in every locale.
local QUEST_OBJECTIVE_LINE_TYPE = Enum and Enum.TooltipDataLineType and Enum.TooltipDataLineType.QuestObjective or 8

local ParseQuestProgress = function(text)
	local have, need = text:match("(%d+)%s*/%s*(%d+)")
	have, need = tonumber(have), tonumber(need)
	if (have and need and need > 0) then
		return have < need and (have .. "/" .. need) or false
	end
	local percent = tonumber(text:match("(%d+)%s*%%"))
	if (percent) then
		return percent < 100 and (percent .. "%") or false
	end
	return nil
end

-- Returns the first unfinished objective's progress ("3/10"), false when the unit has objective lines
-- and every one is finished, or nil when nothing can be told: no objective lines, a secret table, line
-- or text, or an objective without a number that the game does not mark completed. Only false lets
-- the mark hide (hideFinishedQuestMarker); anything uncertain keeps it.
local ReadQuestProgress = function(unit)
	local data = C_TooltipInfo.GetUnit(unit)
	if (IsSecretValue(data) or type(data) ~= "table") then
		return nil
	end
	local lines = data.lines
	if (IsSecretValue(lines) or type(lines) ~= "table") then
		return nil
	end
	local finished, unknown
	for i = 1, #lines do
		local line = lines[i]
		if (IsSecretValue(line) or type(line) ~= "table") then
			unknown = true
		else
			local lineType, text, completed = line.type, line.leftText, line.completed
			if (IsSecretValue(lineType)) then
				unknown = true
			elseif (lineType == QUEST_OBJECTIVE_LINE_TYPE) then
				if (not IsSecretValue(completed) and completed == true) then
					finished = true
				elseif (IsSecretValue(text) or type(text) ~= "string") then
					unknown = true
				else
					local progress = ParseQuestProgress(text)
					if (progress) then
						return progress
					elseif (progress == false) then
						finished = true
					else
						unknown = true
					end
				end
			end
		end
	end
	if (finished and not unknown) then
		return false
	end
	return nil
end

local SetQuestProgressText = function(self, progress)
	local text = self and self.QuestProgress
	if (not text) then
		return
	end
	if (type(progress) == "string") then
		text:SetText(progress)
		text:Show()
	else
		text:Hide()
	end
end

local QuestMarker_Update = function(self)
	local marker = self and self.QuestMarker
	if (not marker) then
		return
	end

	local profile = NamePlatesMod and NamePlatesMod.db and NamePlatesMod.db.profile
	local unit = self.unit
	local show = profile and profile.showQuestMarker
		and type(unit) == "string" and unit:match("^nameplate%d+$")
		and not self.isPRD and not self.isObjectPlate and not self.nameplateShowsWidgetsOnly
		and not ShouldUseFriendlyPlayerNameOnly(self)
		and not (self.RaidTargetIndicator and self.RaidTargetIndicator:IsShown())
		and C_QuestLog and type(C_QuestLog.UnitIsRelatedToActiveQuest) == "function"

	if (show) then
		local ok, related = API.TryCall(C_QuestLog.UnitIsRelatedToActiveQuest, unit)
		show = ok and IsSafeTrue(related)
	end

	-- The tooltip is read only for a shown mark, and only when one of the two options needs it.
	local progress
	if (show and (profile.showQuestProgress or profile.hideFinishedQuestMarker)
		and C_TooltipInfo and type(C_TooltipInfo.GetUnit) == "function") then
		local ok, value = API.TryCall(ReadQuestProgress, unit)
		if (ok) then
			progress = value
		end
		if (progress == false and profile.hideFinishedQuestMarker) then
			show = false
		end
	end

	marker:SetShown(show and true or false)
	SetQuestProgressText(self, show and profile.showQuestProgress and progress or nil)
end

NP.UpdateExecuteMarker = UpdateExecuteMarker
NP.Health_PostUpdate = Health_PostUpdate
NP.Health_UpdateColor = Health_UpdateColor
NP.TankTarget_Update = TankTarget_Update
NP.ThreatPercent_Update = ThreatPercent_Update
NP.PlayThreatAlertSound = PlayThreatAlertSound

-- For the options page: play an alert's sound ("lost", "close", "aggro") as it is chosen.
NamePlatesMod.PlayThreatAlertSound = function(self, kind, choice)
	PlayThreatAlertSound(kind, choice)
end
NP.Health_PostUpdateColor = Health_PostUpdateColor
NP.Power_PostUpdate = Power_PostUpdate
NP.TargetHighlight_Update = TargetHighlight_Update
NP.Classification_Update = Classification_Update
NP.AnchorNamePlateRaidTarget = AnchorNamePlateRaidTarget
NP.NamePlate_PostUpdatePositions = NamePlate_PostUpdatePositions
NP.NamePlate_ApplyHealthValueLayout = NamePlate_ApplyHealthValueLayout
NP.NamePlate_PostUpdateHoverElements = NamePlate_PostUpdateHoverElements
NP.Auras_PostUpdate = Auras_PostUpdate
NP.QuestMarker_Update = QuestMarker_Update
NP.ParseQuestProgress = ParseQuestProgress

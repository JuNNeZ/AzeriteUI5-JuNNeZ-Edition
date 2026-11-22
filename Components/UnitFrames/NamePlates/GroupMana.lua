-- Tank mana warning (2026-11-22). In tank mode, in a group: a yellow line in the middle of the screen
-- while a healer (or, by choice, any mana user) is under 50% mana and a red one under 25%, to remind
-- you to slow down. Settings: tankManaWarning, tankManaWatch, tankManaSoundFile (Settings.lua).
--
-- Other players' mana is a secret value in combat (UnitPower and UnitPowerPercent are
-- SecretWhenUnitPowerRestricted, and mana is not a never-secret power type), so the lines never
-- compare it: UnitPowerPercent evaluates two step curves and the results go straight to SetAlpha,
-- and the percent goes straight to SetFormattedText, as the player's own mana orb does (Player.lua).
-- A sound needs a plain number, so it plays only while the mana can be read (between pulls) and
-- someone crosses a line: in practice as combat ends, before the next pull.
local Addon, ns = ...
local NP = ns.NamePlatesPrivate
if (not NP) then return end

local API = ns.API
local mod = NP.NamePlatesMod
local IsSecretValue = NP.IsSecretValue
local wipe = wipe or function(t) for key in next, t do t[key] = nil end return t end

local MANA = Enum and Enum.PowerType and Enum.PowerType.Mana or 0
local LOW, CRITICAL = .5, .25
local LEVEL_OK, LEVEL_LOW, LEVEL_CRITICAL = 1, 2, 3
local MAX_ROWS = 5
local ROW_WIDTH, ROW_HEIGHT = 520, 22
local ALERT_INTERVAL = 2
local PREVIEW_TIME = 6
local LOW_COLOR, CRITICAL_COLOR = { 1, .82, .1 }, { 1, .25, .25 }

local watcher, display
local watched = {}        -- { unit = token, name = plain name } in row order
local watchedByUnit = {}  -- token -> entry
local lastLevel = {}      -- token -> LEVEL_*, from plain numbers only
local rosterPending = false
local previewUntil = 0
local lastAlertAt

local localeTable
local GetLocaleText = function(key)
	if (localeTable == nil) then
		local lib = LibStub and LibStub("AceLocale-3.0", true)
		localeTable = lib and lib:GetLocale(Addon, true) or false
	end
	return localeTable and localeTable[key] or key
end

local IsTrue = function(value)
	return (not IsSecretValue(value)) and value == true
end

local IsFalse = function(value)
	return (not IsSecretValue(value)) and value == false
end

local GetProfile = function()
	return mod and mod.db and mod.db.profile
end

-- Step curves: "low" is 1 from 25% up to 50%, "critical" is 1 below 25%. Made once, on first use.
local curves
local GetCurves = function()
	if (curves ~= nil) then
		return curves or nil
	end
	curves = false
	if (type(UnitPowerPercent) == "function" and C_CurveUtil and C_CurveUtil.CreateCurve
		and Enum and Enum.LuaCurveType and Enum.LuaCurveType.Step ~= nil) then
		local low = C_CurveUtil.CreateCurve()
		low:SetType(Enum.LuaCurveType.Step)
		low:AddPoint(0, 0)
		low:AddPoint(CRITICAL, 1)
		low:AddPoint(LOW, 0)
		local critical = C_CurveUtil.CreateCurve()
		critical:SetType(Enum.LuaCurveType.Step)
		critical:AddPoint(0, 1)
		critical:AddPoint(CRITICAL, 0)
		curves = { low = low, critical = critical, percent = CurveConstants and CurveConstants.ScaleTo100 or nil }
	end
	return curves or nil
end

-- The share of mana left as a plain number, or nil while the game keeps it secret.
local ReadPlainFraction = function(unit)
	local okCur, cur = API.TryCall(UnitPower, unit, MANA)
	local okMax, max = API.TryCall(UnitPowerMax, unit, MANA)
	if (not okCur or not okMax or IsSecretValue(cur) or IsSecretValue(max)
		or type(cur) ~= "number" or type(max) ~= "number" or max <= 0) then
		return nil
	end
	return cur / max
end

local GetLevel = function(fraction)
	if (fraction < CRITICAL) then
		return LEVEL_CRITICAL
	elseif (fraction < LOW) then
		return LEVEL_LOW
	end
	return LEVEL_OK
end

local IsActive = function()
	local profile = GetProfile()
	return (profile and profile.tankManaWarning and mod:IsEnabled() and mod.tankModeActive
		and IsInGroup and IsInGroup()) and true or false
end

-- The lines
--------------------------------------------
local CreateDisplay = function()
	if (display) then
		return display
	end
	local db = ns.GetConfig("NamePlates") or {}
	display = CreateFrame("Frame", nil, UIParent)
	display:SetSize(ROW_WIDTH, ROW_HEIGHT * MAX_ROWS)
	display:SetPoint(unpack(db.TankManaWarningPosition or { "TOP", "UIParent", "CENTER", 0, 140 }))
	display:SetFrameStrata("HIGH")
	display.Rows = {}
	local font = db.TankManaWarningFont or API.GetFont(18, true)
	for index = 1, MAX_ROWS do
		local row = CreateFrame("Frame", nil, display)
		row:SetSize(ROW_WIDTH, ROW_HEIGHT)
		local low = row:CreateFontString(nil, "OVERLAY")
		low:SetFontObject(font)
		low:SetPoint("CENTER", row, "CENTER", 0, 0)
		low:SetTextColor(LOW_COLOR[1], LOW_COLOR[2], LOW_COLOR[3], 1)
		local critical = row:CreateFontString(nil, "OVERLAY")
		critical:SetFontObject(font)
		critical:SetPoint("CENTER", row, "CENTER", 0, 0)
		critical:SetTextColor(CRITICAL_COLOR[1], CRITICAL_COLOR[2], CRITICAL_COLOR[3], 1)
		row.Low, row.Critical = low, critical
		row:Hide()
		display.Rows[index] = row
	end
	display:Hide()
	return display
end

-- Shown rows stack from the top without gaps. In combat every watched member's row is shown (its
-- lines are invisible above 50%), so gaps can appear there; out of combat calm rows are hidden.
local LayoutRows = function()
	local previous
	for _, row in ipairs(display.Rows) do
		if (row:IsShown()) then
			row:ClearAllPoints()
			if (previous) then
				row:SetPoint("TOP", previous, "BOTTOM", 0, 0)
			else
				row:SetPoint("TOP", display, "TOP", 0, 0)
			end
			previous = row
		end
	end
end

local SetLineTexts = function(row, name, percent)
	if (percent ~= nil) then
		local okLow = API.TryCall(row.Low.SetFormattedText, row.Low, GetLocaleText("%s is at %d%% mana - slow down"), name, percent)
		local okCritical = API.TryCall(row.Critical.SetFormattedText, row.Critical, GetLocaleText("%s is at %d%% mana - stop pulling"), name, percent)
		if (okLow and okCritical) then
			return
		end
	end
	row.Low:SetFormattedText(GetLocaleText("%s is low on mana - slow down"), name)
	row.Critical:SetFormattedText(GetLocaleText("%s is almost out of mana - stop pulling"), name)
end

-- Sound and screen edge, as the threat alerts do (Elements.lua); the lines are the text.
local FireManaAlert = function()
	local profile = GetProfile()
	local now = GetTime()
	if (not profile or (lastAlertAt and now - lastAlertAt < ALERT_INTERVAL)) then
		return
	end
	lastAlertAt = now
	if (profile.threatAlertSoundOn ~= false and NP.PlayThreatAlertSound) then
		NP.PlayThreatAlertSound("mana", profile.tankManaSoundFile)
	end
	if (profile.threatAlertFlash and NP.FlashScreenEdge) then
		NP.FlashScreenEdge()
	end
end

-- One member's row. Returns true when it shows.
local UpdateRow = function(row, entry)
	local unit = entry.unit
	if (not IsTrue(UnitExists(unit)) or IsTrue(UnitIsDeadOrGhost(unit)) or IsFalse(UnitIsConnected(unit))) then
		lastLevel[unit] = nil
		row:Hide()
		return false
	end
	local fraction = ReadPlainFraction(unit)
	local level = fraction and GetLevel(fraction)
	if (level) then
		local previous = lastLevel[unit]
		lastLevel[unit] = level
		if (previous and level > previous) then
			FireManaAlert()
		end
		if (level == LEVEL_OK) then
			row:Hide()
			return false
		end
	end

	local set = GetCurves()
	local percent
	if (set and set.percent) then
		local ok, value = API.TryCall(UnitPowerPercent, unit, MANA, false, set.percent)
		percent = ok and value or nil
	end
	SetLineTexts(row, entry.name, percent)

	local lowDone, criticalDone = false, false
	if (set) then
		local okLow, lowAlpha = API.TryCall(UnitPowerPercent, unit, MANA, false, set.low)
		local okCritical, criticalAlpha = API.TryCall(UnitPowerPercent, unit, MANA, false, set.critical)
		lowDone = okLow and API.TryCall(row.Low.SetAlpha, row.Low, lowAlpha) or false
		criticalDone = okCritical and API.TryCall(row.Critical.SetAlpha, row.Critical, criticalAlpha) or false
	end
	if (not lowDone or not criticalDone) then
		-- No curves: plain numbers only, nothing while they are secret.
		row.Low:SetAlpha(level == LEVEL_LOW and 1 or 0)
		row.Critical:SetAlpha(level == LEVEL_CRITICAL and 1 or 0)
	end
	row:Show()
	return true
end

local HideRows = function()
	if (not display) then
		return
	end
	for _, row in ipairs(display.Rows) do
		row:Hide()
	end
	display:Hide()
end

local UpdateAll = function()
	if (GetTime() < previewUntil) then
		return
	end
	if (not IsActive() or #watched == 0) then
		HideRows()
		return
	end
	CreateDisplay()
	local any = false
	for index, row in ipairs(display.Rows) do
		local entry = watched[index]
		if (entry and UpdateRow(row, entry)) then
			any = true
		elseif (not entry) then
			row:Hide()
		end
	end
	LayoutRows()
	display:SetShown(any)
end

-- Who is watched
--------------------------------------------
-- Read out of combat only: roles can be secret in combat. Healers are members with the Healer role;
-- in a group where nobody has it (often on Forever), or with "Healers and mana users", every member
-- whose main power is mana. A raid watches its healers only. At most MAX_ROWS members.
local IsHealer = function(unit)
	if (type(UnitGroupRolesAssigned) ~= "function") then
		return false
	end
	local role = UnitGroupRolesAssigned(unit)
	return (not IsSecretValue(role)) and role == "HEALER"
end

local UsesMana = function(unit)
	local okType, powerType = API.TryCall(UnitPowerType, unit)
	if (not okType or IsSecretValue(powerType) or powerType ~= MANA) then
		return false
	end
	local okMax, max = API.TryCall(UnitPowerMax, unit, MANA)
	return okMax and (not IsSecretValue(max)) and type(max) == "number" and max > 0 or false
end

local AddEntry = function(unit)
	local name = UnitName(unit)
	if (IsSecretValue(name) or type(name) ~= "string" or name == "") then
		name = GetLocaleText("Healer")
	end
	local entry = { unit = unit, name = name }
	watched[#watched + 1] = entry
	watchedByUnit[unit] = entry
end

local BuildRoster = function()
	wipe(watched)
	wipe(watchedByUnit)
	rosterPending = false
	local profile = GetProfile()
	if (not profile or not IsActive()) then
		wipe(lastLevel)
		return
	end
	local inRaid = IsInRaid and IsInRaid()
	local prefix = inRaid and "raid" or "party"
	local count = inRaid and GetNumGroupMembers() or GetNumSubgroupMembers()
	local units = {}
	for index = 1, count do
		local unit = prefix .. index
		if (IsTrue(UnitExists(unit)) and not NP.SafeUnitMatches(unit, "player")) then
			units[#units + 1] = unit
		end
	end
	local healers, manaUsers = {}, {}
	for _, unit in ipairs(units) do
		if (IsHealer(unit)) then
			healers[#healers + 1] = unit
		elseif (UsesMana(unit)) then
			manaUsers[#manaUsers + 1] = unit
		end
	end
	for _, unit in ipairs(healers) do
		if (#watched < MAX_ROWS) then AddEntry(unit) end
	end
	if (not inRaid and (profile.tankManaWatch == "mana" or #healers == 0)) then
		for _, unit in ipairs(manaUsers) do
			if (#watched < MAX_ROWS) then AddEntry(unit) end
		end
	end
	for unit in next, lastLevel do
		if (not watchedByUnit[unit]) then
			lastLevel[unit] = nil
		end
	end
end

local RequestRoster = function()
	if (InCombatLockdown and InCombatLockdown()) then
		rosterPending = true
		return
	end
	BuildRoster()
end

-- Events
--------------------------------------------
local UNIT_EVENTS = { UNIT_POWER_UPDATE = true, UNIT_MAXPOWER = true, UNIT_DISPLAYPOWER = true,
	UNIT_CONNECTION = true, UNIT_HEALTH = true }

local OnEvent = function(_, event, unit, powerType)
	if (UNIT_EVENTS[event]) then
		if (IsSecretValue(unit) or type(unit) ~= "string" or not watchedByUnit[unit]) then
			return
		end
		if (event == "UNIT_POWER_UPDATE" and (IsSecretValue(powerType) or powerType ~= "MANA")) then
			return
		end
		if (GetTime() < previewUntil) then
			return
		end
		if (not IsActive()) then
			return UpdateAll()
		end
		local index
		for i, entry in ipairs(watched) do
			if (entry.unit == unit) then index = i break end
		end
		local row = index and display and display.Rows[index]
		if (not row) then
			return UpdateAll()
		end
		local wasShown = row:IsShown()
		local shown = UpdateRow(row, watched[index])
		if (shown ~= wasShown) then
			LayoutRows()
			local any = false
			for _, other in ipairs(display.Rows) do
				if (other:IsShown()) then any = true break end
			end
			display:SetShown(any)
		end
		return
	end
	if (event == "PLAYER_REGEN_ENABLED" and rosterPending) then
		BuildRoster()
	end
	UpdateAll()
end

local WATCH_EVENTS = { "UNIT_POWER_UPDATE", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER", "UNIT_CONNECTION",
	"UNIT_HEALTH", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED" }

-- Called by the module when it is enabled or disabled, when the threat role or the group changes,
-- and when a setting changes.
local ConfigureGroupMana = function()
	if (IsActive()) then
		if (not watcher) then
			watcher = CreateFrame("Frame")
			watcher:SetScript("OnEvent", OnEvent)
		end
		if (not watcher.registered) then
			for _, event in ipairs(WATCH_EVENTS) do
				if (not (C_EventUtils and C_EventUtils.IsEventValid) or C_EventUtils.IsEventValid(event)) then
					watcher:RegisterEvent(event)
				end
			end
			watcher.registered = true
		end
		RequestRoster()
	else
		if (watcher and watcher.registered) then
			watcher:UnregisterAllEvents()
			watcher.registered = nil
		end
		wipe(watched)
		wipe(watchedByUnit)
		wipe(lastLevel)
		rosterPending = false
	end
	UpdateAll()
end

-- The options page's preview: one yellow and one red example line for a few seconds, wherever you are.
local PreviewGroupMana = function()
	CreateDisplay()
	previewUntil = GetTime() + PREVIEW_TIME
	local rows = display.Rows
	for index, row in ipairs(rows) do
		row:SetShown(index <= 2)
	end
	local healer = GetLocaleText("Healer")
	SetLineTexts(rows[1], healer, 42)
	rows[1].Low:SetAlpha(1)
	rows[1].Critical:SetAlpha(0)
	SetLineTexts(rows[2], healer, 18)
	rows[2].Low:SetAlpha(0)
	rows[2].Critical:SetAlpha(1)
	LayoutRows()
	display:Show()
	if (C_Timer and C_Timer.After) then
		C_Timer.After(PREVIEW_TIME + .05, function()
			if (GetTime() >= previewUntil) then
				UpdateAll()
			end
		end)
	end
end

NP.ConfigureGroupMana = ConfigureGroupMana
NP.PreviewGroupMana = PreviewGroupMana

mod.ConfigureGroupMana = function(self)
	ConfigureGroupMana()
end

mod.PreviewGroupMana = function(self)
	PreviewGroupMana()
end

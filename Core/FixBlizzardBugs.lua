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

-- GLOBALS: LoadAddOn, ChannelFrame

local FixBlizzardBugs = ns:NewModule("FixBlizzardBugs")

-- Workaround for https://worldofwarcraft.blizzard.com/en-gb/news/24030413/hotfixes-november-16-2023
if (ns.WoW10 and ns.ClientBuild >= 52188) then

	local InCombatLockdown = _G.InCombatLockdown

	if (false and issecurevariable("IsItemInRange")) then
		local IsItemInRange = _G.IsItemInRange
		_G.IsItemInRange = function(...)
			return InCombatLockdown() and true or IsItemInRange(...)
		end
	end

	if (false and issecurevariable("UnitInRange")) then
		local UnitInRange = _G.UnitInRange
		_G.UnitInRange = function(...)
			return InCombatLockdown() and true or UnitInRange(...)
		end
	end

end

-- WoW 12 note:
-- The old emergency full-disable block used during early WoW 12 research is no longer active.
-- It is intentionally kept out of the live code path to make the current WoW 12 behavior easier to audit.
if (false and (issecretvalue or (ns.ClientBuild and ns.ClientBuild >= 120000))) then
		-- to avoid WoW12 secret arithmetic in Blizzard UnitFrame code.
		local frames = { _G.TargetFrame, _G.TargetFrameToT }
		for _, frame in ipairs(frames) do
			if (frame) then
				DisableFrame(frame)
			end
		end

	local function DisableEditModeSensitiveFrames()
		if (true) then
			return
		end
		DisablePRD()
		DisableEncounterWarnings()
		DisableLowHealthFrame()
		DisableBlizzardBuffs()
		DisableClassNameplateBars()
	end

	local EditModeBypass = ns.__AzeriteUI_EditModeBypass
	if (not EditModeBypass) then
		EditModeBypass = { active = false, prdWasShown = false, encounterWasShown = false, removedSystems = nil, prdMethods = nil, encounterMethods = nil }
		ns.__AzeriteUI_EditModeBypass = EditModeBypass
	end

	local Noop = ns and ns.Noop or function() end
	local string_lower = string.lower
	local table_remove = table.remove

	local function GetEditModeSystemName(frame)
		if (not frame) then
			return nil
		end
		local ftype = type(frame)
		if (ftype ~= "table" and ftype ~= "userdata") then
			return nil
		end
		local name = frame.systemNameString or frame.systemName or frame.name
		if (not name and frame.GetName) then
			name = frame:GetName()
		end
		if (name) then
			return string_lower(tostring(name))
		end
		return nil
	end

	local function IsPRDEditModeSystem(frame)
		if (frame == _G.PersonalResourceDisplayFrame) then
			return true
		end
		local lname = GetEditModeSystemName(frame)
		if (lname and (lname:find("personal resource", 1, true)
			or lname:find("personalresource", 1, true)
			or lname:find("personal resource display", 1, true)
			or lname:find("resourcedisplay", 1, true)
			or lname == "prd")) then
			return true
		end
		return false
	end

	local function IsBuffEditModeSystem(frame)
		if (frame == _G.BuffFrame or frame == _G.DebuffFrame or frame == _G.TemporaryEnchantFrame) then
			return true
		end
		local lname = GetEditModeSystemName(frame)
		if (not lname) then
			return false
		end
		if (lname:find("buff", 1, true) or lname:find("debuff", 1, true)
			or lname:find("aura", 1, true) or lname:find("enchant", 1, true)) then
			return true
		end
		return false
	end

	local function IsEncounterWarningsEditModeSystem(frame)
		local lname = GetEditModeSystemName(frame)
		if (not lname) then
			return false
		end
		if (lname:find("encounter warning", 1, true) or lname:find("encounter warnings", 1, true)
			or lname:find("encounterwarnings", 1, true) or lname:find("boss warning", 1, true)
			or lname:find("boss warnings", 1, true)) then
			return true
		end
		return false
	end

	local function ShouldPruneEditModeSystem(frame)
		return IsPRDEditModeSystem(frame) or IsEncounterWarningsEditModeSystem(frame) or IsBuffEditModeSystem(frame)
	end

	local function IsArray(tbl)
		if (type(tbl) ~= "table") then
			return false
		end
		local max = 0
		local count = 0
		for k in pairs(tbl) do
			if (type(k) ~= "number") then
				return false
			end
			if (k > max) then
				max = k
			end
			count = count + 1
		end
		return count > 0 and count == max
	end

	local function ExtractFrameFromEntry(entry)
		if (type(entry) ~= "table") then
			return entry
		end
		return entry.systemFrame or entry.system or entry.frame or entry
	end

	local function LookupSystemFrameById(id)
		if (type(id) ~= "number" or not EditModeManagerFrame) then
			return nil
		end
		local containers = {
			EditModeManagerFrame.registeredSystemFrames,
			EditModeManagerFrame.modernSystemMap,
			EditModeManagerFrame.systemMap,
			EditModeManagerFrame.registeredSystems,
			EditModeManagerFrame.systemFrames
		}
		for _, container in ipairs(containers) do
			if (type(container) == "table" and (not canaccesstable or canaccesstable(container))) then
				local entry = container[id]
				if (entry ~= nil) then
					return ExtractFrameFromEntry(entry)
				end
			end
		end
		return nil
	end

	local function ExtractSystemFrame(entry)
		local etype = type(entry)
		if (etype ~= "table") then
			if (etype == "number") then
				local mapped = LookupSystemFrameById(entry)
				if (mapped ~= nil) then
					return mapped
				end
			end
			return entry
		end
		if (entry.systemFrame) then
			return entry.systemFrame
		end
		if (entry.system) then
			if (type(entry.system) == "number") then
				local mapped = LookupSystemFrameById(entry.system)
				if (mapped ~= nil) then
					return mapped
				end
			end
			return entry.system
		end
		if (entry.frame) then
			return entry.frame
		end
		return entry
	end

	local function ShouldPruneEditModeEntry(entry)
		return ShouldPruneEditModeSystem(ExtractSystemFrame(entry))
	end

	local function PruneEditModeContainer(container)
		if (type(container) ~= "table") then
			return false
		end
		if (canaccesstable and not canaccesstable(container)) then
			return false
		end
		local removed = false
		if (IsArray(container)) then
			for i = #container, 1, -1 do
				if (ShouldPruneEditModeEntry(container[i])) then
					table_remove(container, i)
					removed = true
				end
			end
			return removed
		end
		for key, entry in pairs(container) do
			if (ShouldPruneEditModeEntry(entry)) then
				container[key] = nil
				removed = true
			end
		end
		return removed
	end

	local function PruneEditModeContainers()
		if (not EditModeManagerFrame) then
			return false
		end
		local removed = false
		removed = PruneEditModeContainer(EditModeManagerFrame.registeredSystemFrames) or removed
		removed = PruneEditModeContainer(EditModeManagerFrame.modernSystems) or removed
		removed = PruneEditModeContainer(EditModeManagerFrame.modernSystemMap) or removed
		removed = PruneEditModeContainer(EditModeManagerFrame.registeredSystems) or removed
		removed = PruneEditModeContainer(EditModeManagerFrame.systemMap) or removed
		removed = PruneEditModeContainer(EditModeManagerFrame.systems) or removed
		removed = PruneEditModeContainer(EditModeManagerFrame.systemFrames) or removed
		return removed
	end

	local function PruneEditModeSystems(active)
		if (true) then
			return
		end
		if (not EditModeManagerFrame or not EditModeManagerFrame.registeredSystemFrames) then
			return
		end
		local frames = EditModeManagerFrame.registeredSystemFrames
		if (active) then
			if (EditModeBypass.removedSystems) then
				return
			end
			local removed = {}
			for key, frame in pairs(frames) do
				if (ShouldPruneEditModeSystem(frame)) then
					removed[key] = frame
					frames[key] = nil
				end
			end
			EditModeBypass.removedSystems = removed
			PruneEditModeContainers()
		elseif (EditModeBypass.removedSystems) then
			for key, frame in pairs(EditModeBypass.removedSystems) do
				frames[key] = frame
			end
			EditModeBypass.removedSystems = nil
		end
	end

	local function PrePruneEditModeSystems()
		if (true) then
			return false
		end
		if (not EditModeManagerFrame) then
			return
		end
		if (PruneEditModeContainers()) then
			DebugFixes("EditMode pre-prune applied")
		end
	end

	local function HookEditModeRegistrationPrune()
		if (true) then
			return false
		end
		if (not EditModeManagerFrame) then
			return false
		end
		if (EditModeManagerFrame.__AzeriteUI_EditModePruneHooked) then
			return true
		end
		EditModeManagerFrame.__AzeriteUI_EditModePruneHooked = true

		local function HandleRegistration(...)
			for i = 1, select("#", ...) do
				local value = select(i, ...)
				if (ShouldPruneEditModeSystem(ExtractSystemFrame(value))) then
					PrePruneEditModeSystems()
					return
				end
			end
		end

		if (type(EditModeManagerFrame.RegisterSystemFrame) == "function") then
			hooksecurefunc(EditModeManagerFrame, "RegisterSystemFrame", function(self, ...)
				HandleRegistration(...)
			end)
		end
		if (type(EditModeManagerFrame.RegisterSystemFrameByContext) == "function") then
			hooksecurefunc(EditModeManagerFrame, "RegisterSystemFrameByContext", function(self, ...)
				HandleRegistration(...)
			end)
		end
		return true
	end

	local function NoopTargetMethods(target, names, store)
		if (not target) then
			return
		end
		store[target] = store[target] or {}
		for _, name in ipairs(names) do
			if (type(target[name]) == "function" and store[target][name] == nil) then
				store[target][name] = target[name]
				target[name] = Noop
			end
		end
	end

	local function RestoreTargetMethods(store)
		if (not store) then
			return
		end
		for target, methods in pairs(store) do
			if (target) then
				for name, original in pairs(methods) do
					target[name] = original
				end
			end
		end
	end

	local function SetEditModeBypass(active)
		if (true) then
			return
		end
		if (active and not EditModeBypass.active) then
			EditModeBypass.active = true
			PruneEditModeSystems(true)
			DisablePRD()
			DisableEncounterWarnings()
			local prd = _G.PersonalResourceDisplayFrame
			if (prd and prd.IsShown and prd.Hide) then
				EditModeBypass.prdWasShown = prd:IsShown()
				prd:Hide()
			end
			local ew = _G.EncounterWarningsView
			if (ew and ew.IsShown and ew.Hide) then
				EditModeBypass.encounterWasShown = ew:IsShown()
				ew:Hide()
			end
			local ewf = _G.EncounterWarnings
			if (ewf and ewf.Hide) then
				pcall(ewf.Hide, ewf)
			end
			-- Hide system selections as a fallback to prevent SecureUtil secret errors.
			if (EditModeManagerFrame and EditModeManagerFrame.HideSystemSelections) then
				local ok, err = pcall(EditModeManagerFrame.HideSystemSelections, EditModeManagerFrame)
				if (not ok and type(err) == "string" and err:find("secret value", 1, true)) then
					local frames = EditModeManagerFrame.registeredSystemFrames
					if (type(frames) == "table" and (not canaccesstable or canaccesstable(frames))) then
						for _, frame in pairs(frames) do
							if (frame and frame.HideSelection) then
								pcall(frame.HideSelection, frame)
							end
							if (frame and frame.ClearHighlight) then
								pcall(frame.ClearHighlight, frame)
							end
						end
					end
				end
			end
			DebugFixes("EditMode bypass ON")
		elseif (not active and EditModeBypass.active) then
			EditModeBypass.active = false
			PruneEditModeSystems(false)
			local prd = _G.PersonalResourceDisplayFrame
			if (prd and EditModeBypass.prdWasShown and prd.Show) then
				prd:Show()
			end
			local ew = _G.EncounterWarningsView
			if (ew and EditModeBypass.encounterWasShown and ew.Show) then
				ew:Show()
			end
			EditModeBypass.prdWasShown = false
			EditModeBypass.encounterWasShown = false
			DebugFixes("EditMode bypass OFF")
		end
	end

	local function HookEditModeBypass()
		if (true) then
			return false
		end
		if (not EditModeManagerFrame) then
			return false
		end
		if (EditModeManagerFrame.__AzeriteUI_EditModeBypassHooked) then
			return true
		end
		EditModeManagerFrame.__AzeriteUI_EditModeBypassHooked = true
		if (hooksecurefunc) then
			hooksecurefunc(EditModeManagerFrame, "EnterEditMode", function()
				SetEditModeBypass(true)
			end)
			hooksecurefunc(EditModeManagerFrame, "ExitEditMode", function()
				SetEditModeBypass(false)
			end)
			hooksecurefunc(EditModeManagerFrame, "Show", function()
				SetEditModeBypass(true)
			end)
			hooksecurefunc(EditModeManagerFrame, "Hide", function()
				SetEditModeBypass(false)
			end)
		end
		if (EditModeManagerFrame.HookScript) then
			EditModeManagerFrame:HookScript("OnShow", function()
				SetEditModeBypass(true)
			end)
			EditModeManagerFrame:HookScript("OnHide", function()
				SetEditModeBypass(false)
			end)
		end
		if (C_EditMode and C_EditMode.IsEditModeActive) then
			local ok, active = pcall(C_EditMode.IsEditModeActive)
			if (ok and active) then
				SetEditModeBypass(true)
			end
		end
		DebugFixes("EditMode bypass hook attached")
		return true
	end

	local function HookEditModeEventRegistry()
		if (true) then
			return false
		end
		if (_G.__AzeriteUI_EditModeEventRegistryHooked) then
			return true
		end
		if (not EventRegistry or not EventRegistry.RegisterCallback) then
			return false
		end
		_G.__AzeriteUI_EditModeEventRegistryHooked = true
		EventRegistry:RegisterCallback("EditMode.Enter", function()
			SetEditModeBypass(true)
			DisableEditModeSensitiveFrames()
		end, FixBlizzardBugs)
		EventRegistry:RegisterCallback("EditMode.Exit", function()
			SetEditModeBypass(false)
		end, FixBlizzardBugs)
		DebugFixes("EditMode EventRegistry hook attached")
		return true
	end

	-- Avoid wrapping Frame.SetShown in secret-value builds; it can taint protected code paths.

	-- Do not wrap SetNamePlateHitTestFrame in secret builds; wrapping can taint.

	-- Cast info cache for secret-value fallbacks
	local CastInfoCache = ns.__AzeriteUI_CastInfoCache
	if (not CastInfoCache) then
		CastInfoCache = {
			spellDurationMS = {},
			unitNotInterruptible = {},
			unitDurationMS = {}
		}
		ns.__AzeriteUI_CastInfoCache = CastInfoCache
	end

	local function CacheCastInfo(unit, startTime, endTime, notInterruptible, spellID)
		if (issecretvalue) then
			if (unit and issecretvalue(unit)) then
				unit = nil
			end
			if (spellID and issecretvalue(spellID)) then
				spellID = nil
			end
		end
		if (type(startTime) == "number" and type(endTime) == "number" and endTime > startTime) then
			if (unit) then
				CastInfoCache.unitDurationMS[unit] = endTime - startTime
			end
			if (spellID) then
				CastInfoCache.spellDurationMS[spellID] = endTime - startTime
			end
		end
		if (type(notInterruptible) == "boolean" and unit) then
			CastInfoCache.unitNotInterruptible[unit] = notInterruptible
		end
	end

	local function GuessSpellDuration(unit, spellID)
		if (issecretvalue) then
			if (unit and issecretvalue(unit)) then
				unit = nil
			end
			if (spellID and issecretvalue(spellID)) then
				spellID = nil
			end
		end
		if (unit) then
			local cachedUnit = CastInfoCache.unitDurationMS[unit]
			if (type(cachedUnit) == "number" and cachedUnit > 0) then
				return cachedUnit
			end
		end
		if (not spellID) then
			return nil
		end
		local cached = CastInfoCache.spellDurationMS[spellID]
		if (type(cached) == "number" and cached > 0) then
			return cached
		end
		if (C_Spell and C_Spell.GetSpellInfo) then
			local info = C_Spell.GetSpellInfo(spellID)
			if (info and type(info.castTime) == "number" and info.castTime > 0) then
				return info.castTime
			end
		end
		if (GetSpellInfo) then
			local _, _, _, castTime = GetSpellInfo(spellID)
			if (type(castTime) == "number" and castTime > 0) then
				return castTime
			end
		end
		return nil
	end

	local function SanitizeCastTimes(unit, startTime, endTime, notInterruptible, spellID)
		if (issecretvalue) then
			if (issecretvalue(startTime)) then
				startTime = nil
			end
			if (issecretvalue(endTime)) then
				endTime = nil
			end
			if (issecretvalue(notInterruptible)) then
				if (unit and not issecretvalue(unit)) then
					notInterruptible = CastInfoCache.unitNotInterruptible[unit] or false
				else
					notInterruptible = false
				end
			end
		end

		if (type(startTime) ~= "number" or type(endTime) ~= "number") then
			local duration = GuessSpellDuration(unit, spellID)
			if (type(duration) == "number" and duration > 0) then
				local nowMS = GetTime() * 1000
				if (type(startTime) ~= "number") then
					startTime = nowMS
				end
				if (type(endTime) ~= "number") then
					endTime = startTime + duration
				end
			end
		end
		if (type(startTime) ~= "number" or type(endTime) ~= "number") then
			local nowMS = GetTime() * 1000
			if (type(startTime) ~= "number") then
				startTime = nowMS
			end
			if (type(endTime) ~= "number") then
				endTime = startTime + 1
			end
		end

		CacheCastInfo(unit, startTime, endTime, notInterruptible, spellID)
		return startTime, endTime, notInterruptible
	end

	-- Sanitize UnitCastingInfo/UnitChannelInfo return values for secret times/flags
	local Pack = table.pack or function(...)
		return { n = select("#", ...), ... }
	end
	if (false and _G.UnitCastingInfo and not _G.__AzeriteUI_UnitCastingInfoWrapped) then
		_G.__AzeriteUI_UnitCastingInfoWrapped = true
		local Orig_UnitCastingInfo = _G.UnitCastingInfo
		_G.UnitCastingInfo = function(unit, ...)
			local results = Pack(Orig_UnitCastingInfo(unit, ...))
			local spellID = results[9]
			local startTime, endTime, notInterruptible = results[4], results[5], results[8]
			startTime, endTime, notInterruptible = SanitizeCastTimes(unit, startTime, endTime, notInterruptible, spellID)
			results[4] = startTime
			results[5] = endTime
			results[8] = notInterruptible
			return unpack(results, 1, results.n or #results)
		end
	end

	if (false and _G.UnitChannelInfo and not _G.__AzeriteUI_UnitChannelInfoWrapped) then
		_G.__AzeriteUI_UnitChannelInfoWrapped = true
		local Orig_UnitChannelInfo = _G.UnitChannelInfo
		_G.UnitChannelInfo = function(unit, ...)
			local results = Pack(Orig_UnitChannelInfo(unit, ...))
			local spellID = results[8]
			local startTime, endTime, notInterruptible = results[4], results[5], results[7]
			startTime, endTime, notInterruptible = SanitizeCastTimes(unit, startTime, endTime, notInterruptible, spellID)
			results[4] = startTime
			results[5] = endTime
			results[7] = notInterruptible
			return unpack(results, 1, results.n or #results)
		end
	end

	-- WoW 12.0.0: Fix Blizzard CastingBarFrame secret value bugs
	-- Hook after PLAYER_LOGIN when Blizzard frames exist
	local frame = CreateFrame("Frame")
	frame:RegisterEvent("PLAYER_LOGIN")
	frame:RegisterEvent("ADDON_LOADED")
	frame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
	frame:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED")
	local function PatchCastingBar(bar)
		if (not bar or bar.__AzeriteUI_CastbarSafePatched) then
			return
		end
		local function SafeBool(self, value, cacheKey, default)
			if (issecretvalue and issecretvalue(value)) then
				local cached = rawget(self, cacheKey)
				if (cached ~= nil) then
					return cached
				end
				return default
			end
			rawset(self, cacheKey, value)
			return value
		end
		if (_G.__AzeriteUI_CastbarSafeSetIsHighlightedCastTarget) then
			bar.SetIsHighlightedCastTarget = _G.__AzeriteUI_CastbarSafeSetIsHighlightedCastTarget
		else
			bar.SetIsHighlightedCastTarget = function(self, isHighlighted)
				isHighlighted = SafeBool(self, isHighlighted, "__AzeriteUI_isHighlightedCastTargetSafe", false)
				self.isHighlightedCastTarget = isHighlighted
				local indicator = self.CastTargetIndicator
				if indicator then
					if isHighlighted then
						indicator:Show()
					else
						indicator:Hide()
					end
				end
			end
		end
		if (_G.__AzeriteUI_CastbarSafeUpdateHighlightWhenCastTarget) then
			bar.UpdateHighlightWhenCastTarget = _G.__AzeriteUI_CastbarSafeUpdateHighlightWhenCastTarget
		else
			bar.UpdateHighlightWhenCastTarget = function(self)
				local highlightWhenCastTarget = SafeBool(self, self.highlightWhenCastTarget, "__AzeriteUI_highlightWhenCastTargetSafe", false)
				local isHighlighted = SafeBool(self, self.isHighlightedCastTarget, "__AzeriteUI_isHighlightedCastTargetSafe", false)
				self:SetIsHighlightedCastTarget(highlightWhenCastTarget and isHighlighted)
			end
		end
		if (_G.__AzeriteUI_CastbarSafeSetHighlightWhenCastTarget) then
			bar.SetHighlightWhenCastTarget = _G.__AzeriteUI_CastbarSafeSetHighlightWhenCastTarget
		else
			bar.SetHighlightWhenCastTarget = function(self, highlight)
				self.highlightWhenCastTarget = SafeBool(self, highlight, "__AzeriteUI_highlightWhenCastTargetSafe", false)
				self:UpdateHighlightWhenCastTarget()
			end
		end
		if (_G.__AzeriteUI_CastbarSafeSetIsHighlightedImportantCast) then
			bar.SetIsHighlightedImportantCast = _G.__AzeriteUI_CastbarSafeSetIsHighlightedImportantCast
		else
			bar.SetIsHighlightedImportantCast = function(self, isHighlighted)
				isHighlighted = SafeBool(self, isHighlighted, "__AzeriteUI_isHighlightedImportantCastSafe", false)
				self.isHighlightedImportantCast = isHighlighted
				local indicator = self.ImportantCastIndicator
				if indicator then
					if isHighlighted then
						indicator:Show()
					else
						indicator:Hide()
					end
				end
			end
		end
		if (_G.__AzeriteUI_CastbarSafeUpdateHighlightImportantCast) then
			bar.UpdateHighlightImportantCast = _G.__AzeriteUI_CastbarSafeUpdateHighlightImportantCast
		else
			bar.UpdateHighlightImportantCast = function(self)
				local highlightImportantCasts = SafeBool(self, self.highlightImportantCasts, "__AzeriteUI_highlightImportantCastsSafe", false)
				local isHighlighted = SafeBool(self, self.isHighlightedImportantCast, "__AzeriteUI_isHighlightedImportantCastSafe", false)
				self:SetIsHighlightedImportantCast(highlightImportantCasts and isHighlighted)
			end
		end
		local function WrapIndicator(indicator)
			if (not indicator or indicator.__AzeriteUI_SetShownWrapped) then
				return
			end
			if (type(indicator.SetShown) ~= "function") then
				return
			end
			indicator.__AzeriteUI_SetShownWrapped = true
			local original = indicator.SetShown
			indicator.SetShown = function(self, show)
				if (issecretvalue and issecretvalue(show)) then
					show = false
				end
				return original(self, show)
			end
		end
		WrapIndicator(bar.CastTargetIndicator)
		WrapIndicator(bar.ImportantCastIndicator)
		bar.__AzeriteUI_CastbarSafePatched = true
	end
	local function PatchCastingBarForUnit(unit)
		if (not unit or not C_NamePlate or not C_NamePlate.GetNamePlateForUnit) then
			return
		end
		if (issecretvalue and issecretvalue(unit)) then
			return
		end
		local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
		if (not ok) then
			return
		end
		local unitFrame = plate and (plate.UnitFrame or plate.unitFrame)
		local bar = unitFrame and (unitFrame.castBar or unitFrame.CastBar or unitFrame.castbar or unitFrame.Castbar or unitFrame.CastingBarFrame)
		PatchCastingBar(bar)
	end
	local function PatchExistingCastingBars()
		if (not C_NamePlate or not C_NamePlate.GetNamePlates) then
			return
		end
		for _, plate in pairs(C_NamePlate.GetNamePlates()) do
			local unitFrame = plate and (plate.UnitFrame or plate.unitFrame)
			local bar = unitFrame and (unitFrame.castBar or unitFrame.CastBar or unitFrame.castbar or unitFrame.Castbar or unitFrame.CastingBarFrame)
			PatchCastingBar(bar)
		end
	end
	local function ApplyCastingBarFixes()
		if (true) then
			return
		end
		if (not CastingBarFrameMixin) then
			return
		end

		local function SafeBool(self, value, cacheKey, default)
			if (issecretvalue and issecretvalue(value)) then
				local cached = rawget(self, cacheKey)
				if (cached ~= nil) then
					return cached
				end
				return default
			end
			rawset(self, cacheKey, value)
			return value
		end

		local function ShouldDebugCastbar()
			return ns.IsDevelopment and ns.db and ns.db.global and ns.db.global.enableDevelopmentMode
				and ns.API and ns.API.DEBUG_HEALTH_CHAT
		end

		local function Safe_SetIsHighlightedCastTarget(self, isHighlighted)
			-- Sanitize and store state
			isHighlighted = SafeBool(self, isHighlighted, "__AzeriteUI_isHighlightedCastTargetSafe", false)
			self.isHighlightedCastTarget = isHighlighted
			-- Directly show/hide the indicator without calling any Blizzard code
			local indicator = self.CastTargetIndicator
			if indicator then
				if isHighlighted then
					indicator:Show()
				else
					indicator:Hide()
				end
			end
			if (ShouldDebugCastbar()) then
				print("|cff33ff99", "Castbar:SetIsHighlightedCastTarget", self.unit or "?", "value", tostring(isHighlighted))
			end
		end

		local function Safe_UpdateHighlightWhenCastTarget(self)
			local highlightWhenCastTarget = SafeBool(self, self.highlightWhenCastTarget, "__AzeriteUI_highlightWhenCastTargetSafe", false)
			local isHighlighted = SafeBool(self, self.isHighlightedCastTarget, "__AzeriteUI_isHighlightedCastTargetSafe", false)
			local highlight = highlightWhenCastTarget and isHighlighted
			Safe_SetIsHighlightedCastTarget(self, highlight)
			if (ShouldDebugCastbar()) then
				print("|cff33ff99", "Castbar:UpdateHighlightWhenCastTarget", self.unit or "?", "highlightWhenCastTarget", tostring(self.highlightWhenCastTarget), "isHighlightedCastTarget", tostring(self.isHighlightedCastTarget))
			end
		end

		local function Safe_SetHighlightWhenCastTarget(self, highlight)
			self.highlightWhenCastTarget = SafeBool(self, highlight, "__AzeriteUI_highlightWhenCastTargetSafe", false)
			Safe_UpdateHighlightWhenCastTarget(self)
			if (ShouldDebugCastbar()) then
				print("|cff33ff99", "Castbar:SetHighlightWhenCastTarget", self.unit or "?", "value", tostring(highlight))
			end
		end

		local function Safe_SetIsHighlightedImportantCast(self, isHighlighted)
			isHighlighted = SafeBool(self, isHighlighted, "__AzeriteUI_isHighlightedImportantCastSafe", false)
			self.isHighlightedImportantCast = isHighlighted
			local indicator = self.ImportantCastIndicator
			if indicator then
				if isHighlighted then
					indicator:Show()
				else
					indicator:Hide()
				end
			end
		end

		local function Safe_UpdateHighlightImportantCast(self)
			local highlightImportantCasts = SafeBool(self, self.highlightImportantCasts, "__AzeriteUI_highlightImportantCastsSafe", false)
			local isHighlighted = SafeBool(self, self.isHighlightedImportantCast, "__AzeriteUI_isHighlightedImportantCastSafe", false)
			Safe_SetIsHighlightedImportantCast(self, highlightImportantCasts and isHighlighted)
		end

		local function ApplySafeHighlightMethods(target)
			if (not target or type(target) ~= "table") then
				return
			end
			target.SetIsHighlightedCastTarget = Safe_SetIsHighlightedCastTarget
			target.UpdateHighlightWhenCastTarget = Safe_UpdateHighlightWhenCastTarget
			target.SetHighlightWhenCastTarget = Safe_SetHighlightWhenCastTarget
			target.SetIsHighlightedImportantCast = Safe_SetIsHighlightedImportantCast
			target.UpdateHighlightImportantCast = Safe_UpdateHighlightImportantCast
		end

		-- Replace highlight methods with safe implementations that don't call original
		ApplySafeHighlightMethods(CastingBarFrameMixin)
		ApplySafeHighlightMethods(_G.NamePlateCastBarMixin)
		ApplySafeHighlightMethods(_G.NamePlateCastingBarMixin)
		ApplySafeHighlightMethods(_G.TargetedCastingBarMixin)
		ApplySafeHighlightMethods(_G.TargetedCastBarMixin)
		ApplySafeHighlightMethods(_G.CastingBarMixin)

		-- Guard GetEffectiveType against secret booleans (notInterruptible)
		if (CastingBarFrameMixin.GetEffectiveType and not _G.__AzeriteUI_CastingBarGetEffectiveTypeWrapped) then
			_G.__AzeriteUI_CastingBarGetEffectiveTypeWrapped = true
			local Orig_GetEffectiveType = CastingBarFrameMixin.GetEffectiveType
			CastingBarFrameMixin.GetEffectiveType = function(self, ...)
				self.notInterruptible = SafeBool(self, self.notInterruptible, "__AzeriteUI_notInterruptibleSafe", false)
				return Orig_GetEffectiveType(self, ...)
			end
		end

		if (CastingBarFrameMixin.HandleCastStop and not _G.__AzeriteUI_CastingBarHandleCastStopWrapped) then
			_G.__AzeriteUI_CastingBarHandleCastStopWrapped = true
			local Orig_HandleCastStop = CastingBarFrameMixin.HandleCastStop
			CastingBarFrameMixin.HandleCastStop = function(self, event, unit, castID, ...)
				if (issecretvalue) then
					if (castID and issecretvalue(castID)) then
						castID = nil
					end
					if (self and self.castID and issecretvalue(self.castID)) then
						self.castID = nil
					end
				end
				return Orig_HandleCastStop(self, event, unit, castID, ...)
			end
		end

		if (CastingBarFrameMixin.OnEvent and not _G.__AzeriteUI_CastingBarOnEventWrapped) then
			_G.__AzeriteUI_CastingBarOnEventWrapped = true
			local Orig_OnEvent = CastingBarFrameMixin.OnEvent
			CastingBarFrameMixin.OnEvent = function(self, event, unit, castID, ...)
				if (event and event:find("UNIT_SPELLCAST", 1, true)) then
					if (issecretvalue and castID and issecretvalue(castID)) then
						castID = nil
					end
					if (self and self.castID and issecretvalue and issecretvalue(self.castID)) then
						self.castID = nil
					end
					local args = {...}
					for i,v in ipairs(args) do
						if (issecretvalue and issecretvalue(v)) then
							args[i] = 0
						end
					end
					return Orig_OnEvent(self, event, unit, castID, unpack(args))
				end
				return Orig_OnEvent(self, event, unit, castID, ...)
			end
		end

		if (_G.CastingBarFrame_OnEvent and not _G.__AzeriteUI_CastingBarFrameOnEventWrapped) then
			_G.__AzeriteUI_CastingBarFrameOnEventWrapped = true
			local Orig_OnEvent = _G.CastingBarFrame_OnEvent
			_G.CastingBarFrame_OnEvent = function(self, event, unit, castID, ...)
				if (event and event:find("UNIT_SPELLCAST", 1, true)) then
					if (issecretvalue and castID and issecretvalue(castID)) then
						castID = nil
					end
					if (self and self.castID and issecretvalue and issecretvalue(self.castID)) then
						self.castID = nil
					end
					local args = {...}
					for i,v in ipairs(args) do
						if (issecretvalue and issecretvalue(v)) then
							args[i] = 0
						end
					end
					return Orig_OnEvent(self, event, unit, castID, unpack(args))
				end
				return Orig_OnEvent(self, event, unit, castID, ...)
			end
		end

		_G.__AzeriteUI_CastbarSafeSetIsHighlightedCastTarget = CastingBarFrameMixin.SetIsHighlightedCastTarget
		_G.__AzeriteUI_CastbarSafeUpdateHighlightWhenCastTarget = CastingBarFrameMixin.UpdateHighlightWhenCastTarget
		_G.__AzeriteUI_CastbarSafeSetHighlightWhenCastTarget = CastingBarFrameMixin.SetHighlightWhenCastTarget
		_G.__AzeriteUI_CastbarSafeSetIsHighlightedImportantCast = CastingBarFrameMixin.SetIsHighlightedImportantCast
		_G.__AzeriteUI_CastbarSafeUpdateHighlightImportantCast = CastingBarFrameMixin.UpdateHighlightImportantCast

		-- Override mixin methods up front so secret values never reach Blizzard implementations.
		local function SafeBool(self, value, cacheKey, default)
			if (type(value) == "boolean" and (not issecretvalue or not issecretvalue(value))) then
				self[cacheKey] = value
				return value
			end
			if (self[cacheKey] ~= nil) then
				return self[cacheKey]
			end
			self[cacheKey] = default
			return default
		end
		local function SafeSetShown(frame, flag)
			if frame and frame.SetShown then
				local safe = (type(flag) == "boolean" and (not issecretvalue or not issecretvalue(flag))) and flag or false
				frame:SetShown(safe)
			end
		end
		local function Safe_SetIsHighlightedCastTarget(self, isHighlighted)
			isHighlighted = SafeBool(self, isHighlighted, "__AzeriteUI_isHighlightedCastTargetSafe", false)
			self.isHighlightedCastTarget = isHighlighted
			SafeSetShown(self.CastTargetIndicator, isHighlighted)
		end
		local function Safe_UpdateHighlightWhenCastTarget(self)
			local highlightWhenCastTarget = SafeBool(self, self.highlightWhenCastTarget, "__AzeriteUI_highlightWhenCastTargetSafe", false)
			local isHighlighted = SafeBool(self, self.isHighlightedCastTarget, "__AzeriteUI_isHighlightedCastTargetSafe", false)
			Safe_SetIsHighlightedCastTarget(self, highlightWhenCastTarget and isHighlighted)
		end
		local function Safe_SetHighlightWhenCastTarget(self, highlight)
			self.highlightWhenCastTarget = SafeBool(self, highlight, "__AzeriteUI_highlightWhenCastTargetSafe", false)
			Safe_UpdateHighlightWhenCastTarget(self)
		end

		CastingBarFrameMixin.SetIsHighlightedCastTarget = Safe_SetIsHighlightedCastTarget
		CastingBarFrameMixin.UpdateHighlightWhenCastTarget = Safe_UpdateHighlightWhenCastTarget
		CastingBarFrameMixin.SetHighlightWhenCastTarget = Safe_SetHighlightWhenCastTarget
		PatchExistingCastingBars()
		-- Hook nameplate UpdateCastBarDisplay using hooksecurefunc to avoid tainting mixin
		if (_G.NamePlateUnitFrameMixin and not _G.__AzeriteUI_NamePlateCastbarOverridden) then
			_G.__AzeriteUI_NamePlateCastbarOverridden = true
			if (type(_G.NamePlateUnitFrameMixin.UpdateCastBarDisplay) == "function") then
				hooksecurefunc(_G.NamePlateUnitFrameMixin, "UpdateCastBarDisplay", function(self)
					local bar = self and (self.castBar or self.CastBar or self.castbar or self.Castbar or self.CastingBarFrame)
					if (bar and not bar.__AzeriteUI_CastbarPatched) then
						PatchCastingBar(bar)
					end
				end)
			end
		end
		if (ShouldDebugCastbar()) then
			print("|cff33ff99", "Castbar hooks applied")
		end
	end

	-- Apply immediately if mixin already exists
	ApplyCastingBarFixes()
	if (C_Timer and not _G.__AzeriteUI_CastbarPatchTicker) then
		_G.__AzeriteUI_CastbarPatchTicker = true
		C_Timer.NewTicker(1, PatchExistingCastingBars, 20)
	end

	-- WoW 12.0.0: Guard Blizzard Encounter Warnings against secret-value errors
	-- Sanitize fields that might be secret values before Blizzard code compares them
	local WrapEncounterWarnings = function()
		if (true) then
			return
		end
		if (EncounterWarningsViewElementsMixin and type(EncounterWarningsViewElementsMixin.Init) == "function") then
			if (EncounterWarningsViewElementsMixin.Init == _G.__AzeriteUI_EncounterWarningsInit) then
				return
			end
			_G.__AzeriteUI_EncounterWarningsWrapped = true
			local originalInit = EncounterWarningsViewElementsMixin.Init
			_G.__AzeriteUI_EncounterWarningsOriginalInit = originalInit
			local defaults = {
				text = "",
				targetName = "",
				casterName = "",
				iconFileID = 0,
				tooltipSpellID = 0,
				severity = 0,
				duration = 0,
				isDeadly = false,
				shouldShowWarning = true,
				shouldShowChatMessage = false,
				shouldPlaySound = false
			}
			local function SanitizeEncounterWarningInfo(info)
				if (type(info) ~= "table" or not issecretvalue) then
					return info
				end
				local function SanitizeValue(key, value)
					if (issecretvalue(value)) then
						DebugCount("EncounterWarnings:secret:" .. tostring(key))
						local fallback = defaults[key]
						if (fallback ~= nil) then
							return fallback
						end
						local valueType = type(value)
						if (valueType == "number") then
							return 0
						elseif (valueType == "boolean") then
							return false
						elseif (valueType == "string") then
							return ""
						end
						return nil
					end
					return value
				end
				local seen = {}
				local function DeepCopy(tbl, depth)
					if (type(tbl) ~= "table" or depth > 3) then
						return tbl
					end
					if (canaccesstable and not canaccesstable(tbl)) then
						return {}
					end
					if (seen[tbl]) then
						return seen[tbl]
					end
					local copy = {}
					seen[tbl] = copy
					for key, value in pairs(tbl) do
						if (type(value) == "table") then
							copy[key] = DeepCopy(value, depth + 1)
						else
							copy[key] = SanitizeValue(key, value)
						end
					end
					return copy
				end
				return DeepCopy(info, 0)
			end
			local WrappedInit = function(self, encounterWarningInfo, ...)
				if (not encounterWarningInfo) then return end
				if (EditModeBypass.active) then return end
				-- Sanitize fields that might be secret to avoid comparisons
				local info = SanitizeEncounterWarningInfo(encounterWarningInfo)
				local ok = pcall(originalInit, self, info, ...)
				if (not ok) then
					pcall(function() self:SetText("") end)
				end
			end
			local function WrapShowWarning(container, methodName)
				if (not container) then
					return
				end
				local original = container[methodName]
				if (type(original) ~= "function") then
					return
				end
				local key = "__AzeriteUI_" .. methodName .. "_Wrapped"
				if (container[key]) then
					return
				end
				container[key] = true
				container["__AzeriteUI_" .. methodName .. "_Original"] = original
				container[methodName] = function(self, warningInfo, ...)
					if (EditModeBypass.active) then
						return
					end
					local info = SanitizeEncounterWarningInfo(warningInfo)
					return original(self, info, ...)
				end
			end
			local function PatchEncounterWarningsInstances()
				local view = _G.EncounterWarningsView
				if (not view) then
					return
				end
				local pools = {
					view.warningPool,
					view.elementPool,
					view.framePool,
					view.pool
				}
				for _, pool in pairs(pools) do
					if (pool and pool.EnumerateActive) then
						for element in pool:EnumerateActive() do
							if (element and element.Init ~= WrappedInit) then
								element.Init = WrappedInit
							end
						end
					end
				end
				if (view.elements and type(view.elements) == "table") then
					for _, element in pairs(view.elements) do
						if (element and element.Init ~= WrappedInit) then
							element.Init = WrappedInit
						end
					end
				end
			end
			_G.__AzeriteUI_EncounterWarningsInit = WrappedInit
			EncounterWarningsViewElementsMixin.Init = WrappedInit
			WrapShowWarning(_G.EncounterWarningsView, "ShowWarning")
			WrapShowWarning(_G.EncounterWarnings, "ShowWarning")
			PatchEncounterWarningsInstances()
			if (C_Timer) then
				C_Timer.After(0, PatchEncounterWarningsInstances)
			end
		end
	end

	-- WoW 12.0.0: Guard PersonalResourceDisplay against secret-value arithmetic errors
	-- Keep behavior by sanitizing unit values instead of disabling the frame.
	local WrapPRD = function()
		-- Disabled: overriding PRD internals taints EditMode/secure paths in WoW 12.
		-- We rely on hide/disable behavior elsewhere instead.
		if (true) then
			return
		end
		local prd = _G.PersonalResourceDisplayFrame
		local prdMixin = _G.PersonalResourceDisplayMixin
		local prdFrameMixin = _G.PersonalResourceDisplayFrameMixin
		if (not prd and not prdMixin and not prdFrameMixin) then
			return
		end
		_G.__AzeriteUI_PersonalResourceDisplayWrapped = true

		local prdCache = ns.__AzeriteUI_PRDCache
		if (not prdCache) then
			prdCache = { health = {}, maxHealth = {}, power = {}, maxPower = {} }
			ns.__AzeriteUI_PRDCache = prdCache
		end

		local function SafeNumber(value, cacheTable, key, fallback)
			if (type(value) == "number" and (not issecretvalue or not issecretvalue(value))) then
				cacheTable[key] = value
				return value
			end
			if (issecretvalue and issecretvalue(value)) then
				DebugCount("PRD:secret:number", key)
				local cached = cacheTable[key]
				if (type(cached) == "number") then
					return cached
				end
				return fallback
			end
			return value
		end

		local prdFieldCache = ns.__AzeriteUI_PRDFieldCache
		if (not prdFieldCache) then
			prdFieldCache = {}
			ns.__AzeriteUI_PRDFieldCache = prdFieldCache
		end
		local RunWithSafeUnitNumbers

		local function SanitizeTableNumbers(tbl, prefix, depth)
			if (type(tbl) ~= "table" or depth > 3) then
				return
			end
			if (canaccesstable and not canaccesstable(tbl)) then
				return
			end
			for k,v in pairs(tbl) do
				local key = prefix .. "." .. tostring(k)
				if (issecretvalue and issecretvalue(v)) then
					DebugCount("PRD:secret:table", key)
					local cached = prdFieldCache[key]
					if (type(cached) == "number") then
						tbl[k] = cached
					else
						tbl[k] = 0
					end
				elseif (type(v) == "number") then
					prdFieldCache[key] = v
				elseif (type(v) == "table") then
					SanitizeTableNumbers(v, key, depth + 1)
				end
			end
		end

		local function SanitizePRDLayout(self)
			if (not self) then
				return
			end
			SanitizeTableNumbers(self.layoutInfo, "layoutInfo", 0)
			SanitizeTableNumbers(self.layoutData, "layoutData", 0)
			SanitizeTableNumbers(self.layoutSettings, "layoutSettings", 0)
			SanitizeTableNumbers(self.layoutConfig, "layoutConfig", 0)
			SanitizeTableNumbers(self.layout, "layout", 0)
			SanitizeTableNumbers(self.systemInfo, "systemInfo", 0)
			SanitizeTableNumbers(self.savedSystemInfo, "savedSystemInfo", 0)
			SanitizeTableNumbers(self.settingMap, "settingMap", 0)
			SanitizeTableNumbers(self.settingDisplayInfoMap, "settingDisplayInfoMap", 0)
			SanitizeTableNumbers(self.settingsDialogAnchor, "settingsDialogAnchor", 0)
		end

		local function WrapStatusBar(bar, keyPrefix)
			if (not bar or bar.__AzeriteUI_SecretWrapped) then
				return
			end
			bar.__AzeriteUI_SecretWrapped = true
			if (type(bar.GetValue) == "function") then
				local Orig_GetValue = bar.GetValue
				bar.GetValue = function(self)
					local value = Orig_GetValue(self)
					if (issecretvalue and issecretvalue(value)) then
						local cached = prdFieldCache[keyPrefix .. ".value"]
						return (type(cached) == "number") and cached or 0
					end
					if (type(value) == "number") then
						prdFieldCache[keyPrefix .. ".value"] = value
					end
					return value
				end
			end
			if (type(bar.GetMinMaxValues) == "function") then
				local Orig_GetMinMax = bar.GetMinMaxValues
				bar.GetMinMaxValues = function(self)
					local minVal, maxVal = Orig_GetMinMax(self)
					if (issecretvalue and issecretvalue(minVal)) then
						minVal = prdFieldCache[keyPrefix .. ".min"] or 0
					elseif (type(minVal) == "number") then
						prdFieldCache[keyPrefix .. ".min"] = minVal
					end
					if (issecretvalue and issecretvalue(maxVal)) then
						maxVal = prdFieldCache[keyPrefix .. ".max"] or 1
					elseif (type(maxVal) == "number") then
						prdFieldCache[keyPrefix .. ".max"] = maxVal
					end
					return minVal, maxVal
				end
			end
		end

		local function WrapFrameGeometry(frame, keyPrefix)
			if (not frame or frame.__AzeriteUI_GeometryWrapped) then
				return
			end
			frame.__AzeriteUI_GeometryWrapped = true
			local function wrap1(methodName, fallback)
				local original = frame[methodName]
				if (type(original) ~= "function") then
					return
				end
				frame[methodName] = function(self, ...)
					local value = original(self, ...)
					if (issecretvalue and issecretvalue(value)) then
						local cached = prdFieldCache[keyPrefix .. "." .. methodName]
						return (type(cached) == "number") and cached or (fallback or 0)
					end
					if (type(value) == "number") then
						prdFieldCache[keyPrefix .. "." .. methodName] = value
					end
					return value
				end
			end
			local function wrap2(methodName, fallbackA, fallbackB)
				local original = frame[methodName]
				if (type(original) ~= "function") then
					return
				end
				frame[methodName] = function(self, ...)
					local a, b = original(self, ...)
					if (issecretvalue and issecretvalue(a)) then
						local cached = prdFieldCache[keyPrefix .. "." .. methodName .. ".1"]
						a = (type(cached) == "number") and cached or (fallbackA or 0)
					elseif (type(a) == "number") then
						prdFieldCache[keyPrefix .. "." .. methodName .. ".1"] = a
					end
					if (issecretvalue and issecretvalue(b)) then
						local cached = prdFieldCache[keyPrefix .. "." .. methodName .. ".2"]
						b = (type(cached) == "number") and cached or (fallbackB or 0)
					elseif (type(b) == "number") then
						prdFieldCache[keyPrefix .. "." .. methodName .. ".2"] = b
					end
					return a, b
				end
			end
			wrap1("GetWidth", 0)
			wrap1("GetHeight", 0)
			wrap1("GetLeft", 0)
			wrap1("GetRight", 0)
			wrap1("GetTop", 0)
			wrap1("GetBottom", 0)
			wrap1("GetScale", 1)
			wrap1("GetEffectiveScale", 1)
			wrap2("GetCenter", 0, 0)
		end

		local function PreparePRD(self)
			-- Cover Blizzard's varying field names
			WrapStatusBar(self and self.healthBar, "healthBar")
			WrapStatusBar(self and self.healthbar, "healthbar")
			WrapStatusBar(self and self.powerBar, "powerBar")
			WrapStatusBar(self and self.PowerBar, "PowerBar")
			WrapStatusBar(self and self.manaBar, "manaBar")
			WrapStatusBar(self and self.resourceBar, "resourceBar")
			WrapStatusBar(self and self.altPowerBar, "altPowerBar")
			WrapStatusBar(self and self.AlternatePowerBar, "AlternatePowerBar")
			WrapStatusBar(self and self.tempMaxHealthLossBar, "tempMaxHealthLossBar")
			WrapFrameGeometry(self, "PersonalResourceDisplayFrame")
			WrapFrameGeometry(self and self.HealthBarsContainer, "HealthBarsContainer")
			WrapFrameGeometry(self and self.ClassFrameContainer, "ClassFrameContainer")
			WrapFrameGeometry(self and self.PowerBar, "PowerBar")
			WrapFrameGeometry(self and self.AlternatePowerBar, "AlternatePowerBar")
			WrapFrameGeometry(self and self.healthbar, "healthbar")
			WrapFrameGeometry(self and self.tempMaxHealthLossBar, "tempMaxHealthLossBar")
			SanitizePRDLayout(self)
		end

		local function WrapScript(frame, scriptName)
			if (not frame or not frame.GetScript or not frame.SetScript) then
				return
			end
			local original = frame:GetScript(scriptName)
			if (type(original) ~= "function") then
				return
			end
			local key = "__AzeriteUI_" .. scriptName .. "Wrapped"
			if (frame[key]) then
				return
			end
			frame[key] = true
			frame:SetScript(scriptName, function(self, ...)
				return RunWithSafeUnitNumbers(original, self, ...)
			end)
		end

		RunWithSafeUnitNumbers = function(func, self, ...)
			if (EditModeBypass.active) then
				return
			end
			PreparePRD(self)
			local origUnitHealth = _G.UnitHealth
			local origUnitHealthMax = _G.UnitHealthMax
			local origUnitPower = _G.UnitPower
			local origUnitPowerMax = _G.UnitPowerMax

			if (origUnitHealth) then
				_G.UnitHealth = function(unit)
					local value = origUnitHealth(unit)
					return SafeNumber(value, prdCache.health, unit or "nil", 0)
				end
			end
			if (origUnitHealthMax) then
				_G.UnitHealthMax = function(unit)
					local value = origUnitHealthMax(unit)
					return SafeNumber(value, prdCache.maxHealth, unit or "nil", 1)
				end
			end
			if (origUnitPower) then
				_G.UnitPower = function(unit, powerType)
					local value = origUnitPower(unit, powerType)
					local key = (unit or "nil") .. ":" .. tostring(powerType or 0)
					return SafeNumber(value, prdCache.power, key, 0)
				end
			end
			if (origUnitPowerMax) then
				_G.UnitPowerMax = function(unit, powerType)
					local value = origUnitPowerMax(unit, powerType)
					local key = (unit or "nil") .. ":" .. tostring(powerType or 0)
					return SafeNumber(value, prdCache.maxPower, key, 1)
				end
			end

			local results = Pack(pcall(func, self, ...))

			_G.UnitHealth = origUnitHealth
			_G.UnitHealthMax = origUnitHealthMax
			_G.UnitPower = origUnitPower
			_G.UnitPowerMax = origUnitPowerMax

			if (not results[1]) then
				local err = results[2]
				if (type(err) == "string" and err:find("secret value", 1, true)) then
					-- Secret-value failure: keep PRD functional with sanitized data
					PreparePRD(self)
					return
				end
				error(err, 0)
			end
			for i = 2, (results.n or #results) do
				if (type(results[i]) == "table") then
					SanitizeTableNumbers(results[i], "return." .. tostring(i), 0)
				end
			end
			return unpack(results, 2, results.n or #results)
		end

		local function WrapMethod(target, methodName)
			if (not target) then
				return
			end
			if (type(target[methodName]) ~= "function" or target["__AzeriteUI_" .. methodName .. "Wrapped"]) then
				-- If Blizzard overwrote the method after we wrapped, rewrap it
				if (type(target[methodName]) ~= "function") then
					return
				end
				if (target[methodName] == target["__AzeriteUI_" .. methodName .. "WrappedFunc"]) then
					return
				end
			end
			local original = target[methodName]
			target["__AzeriteUI_" .. methodName .. "Wrapped"] = true
			target["__AzeriteUI_" .. methodName .. "Original"] = original
			target["__AzeriteUI_" .. methodName .. "WrappedFunc"] = function(self, ...)
				return RunWithSafeUnitNumbers(original, self, ...)
			end
			target[methodName] = target["__AzeriteUI_" .. methodName .. "WrappedFunc"]
		end

		local methods = { "UpdateLayoutInfo", "UpdateLayout", "Update", "UpdateHealth", "GetLayoutInfo", "GetSystemInfo" }
		for _, name in ipairs(methods) do
			WrapMethod(prd, name)
			WrapMethod(prdMixin, name)
			WrapMethod(prdFrameMixin, name)
		end
		WrapScript(prd, "OnEvent")
		WrapScript(prd, "OnUpdate")
		WrapScript(prd, "OnShow")
		local function PatchEditModeRegisteredSystems()
			if (not EditModeManagerFrame or not EditModeManagerFrame.registeredSystemFrames) then
				return
			end
			for _, frame in pairs(EditModeManagerFrame.registeredSystemFrames) do
				if (frame == prd or (prd and frame and frame.system == prd.system) or (frame and frame.systemNameString == "Personal Resource Display")) then
					PreparePRD(frame)
				end
			end
		end
		PatchEditModeRegisteredSystems()
		if (C_Timer) then
			C_Timer.After(0, PatchEditModeRegisteredSystems)
			C_Timer.After(1, PatchEditModeRegisteredSystems)
		end
	end

	-- WoW 12.0.0: Sanitize aura APIs to avoid secret-value explosions
	local WrapAuraAPIs = function()
		if (ns.__AuraSanitizeWrapped) then
			return
		end
		if (not C_UnitAuras) then
			return
		end
		ns.__AuraSanitizeWrapped = true
		local auraDefaults = {
			isHarmful = false,
			isHelpful = false,
			isStealable = false,
			isFromPlayerOrPlayerPet = false,
			isPlayerAura = false,
			isRaid = false,
			isNameplateOnly = false,
			nameplateShowPersonal = false,
			nameplateShowAll = false,
			canApplyAura = false,
			canActivePlayerDispel = false,
			isBossAura = false,
			duration = 0,
			expirationTime = 0,
			applications = 0,
			spellId = 0,
			auraInstanceID = 0,
			timeMod = 1
		}

		local function SanitizeAuraData(aura)
			if (type(aura) ~= "table") then
				return aura
			end
			if (issecretvalue and issecretvalue(aura)) then
				return {}
			end
			if (canaccesstable and not canaccesstable(aura)) then
				return {}
			end
			if (not issecretvalue) then
				return aura
			end
			local needsCopy = false
			for k, fallback in pairs(auraDefaults) do
				local v = aura[k]
				if issecretvalue(v) then
					if (not needsCopy) then
						local ok, copy = pcall(CopyTable, aura)
						if (ok and type(copy) == "table") then
							aura = copy
						else
							aura = {}
						end
						needsCopy = true
					end
					-- Nil out secret fields so downstream comparisons/booleans are safe.
					aura[k] = fallback
				end
			end
			return aura
		end

		local Orig_GetAuraByID = C_UnitAuras.GetAuraDataByAuraInstanceID
		local Orig_GetAuraByIndex = C_UnitAuras.GetAuraDataByIndex
		local Orig_GetAuraBySlot = C_UnitAuras.GetAuraDataBySlot
		local Orig_GetPlayerAuraBySpellID = C_UnitAuras.GetPlayerAuraBySpellID
		local Orig_IsAuraFilteredOutByInstanceID = C_UnitAuras.IsAuraFilteredOutByInstanceID
		local Orig_ForEachAura = C_UnitAuras.ForEachAura

		if (Orig_GetAuraByID) then
			C_UnitAuras.GetAuraDataByAuraInstanceID = function(unit, auraInstanceID, ...)
				if (not unit or not auraInstanceID) then
					return nil
				end
				if (issecretvalue and (issecretvalue(unit) or issecretvalue(auraInstanceID))) then
					return nil
				end
				local ok, aura = pcall(Orig_GetAuraByID, unit, auraInstanceID, ...)
				if (not ok) then
					return nil
				end
				return SanitizeAuraData(aura)
			end
		end

		if (Orig_GetAuraByIndex) then
			C_UnitAuras.GetAuraDataByIndex = function(unit, index, filter)
				if (not unit or not index) then
					return nil
				end
				if (issecretvalue and (issecretvalue(unit) or issecretvalue(index) or issecretvalue(filter))) then
					return nil
				end
				local ok, aura = pcall(Orig_GetAuraByIndex, unit, index, filter)
				if (not ok) then
					return nil
				end
				return SanitizeAuraData(aura)
			end
		end

		if (Orig_GetAuraBySlot) then
			C_UnitAuras.GetAuraDataBySlot = function(unit, slot)
				if (not unit or not slot) then
					return nil
				end
				if (issecretvalue and (issecretvalue(unit) or issecretvalue(slot))) then
					return nil
				end
				local ok, aura = pcall(Orig_GetAuraBySlot, unit, slot)
				if (not ok) then
					return nil
				end
				return SanitizeAuraData(aura)
			end
		end

		if (Orig_GetPlayerAuraBySpellID) then
			C_UnitAuras.GetPlayerAuraBySpellID = function(...)
				local ok, aura = pcall(Orig_GetPlayerAuraBySpellID, ...)
				if (not ok) then
					return nil
				end
				return SanitizeAuraData(aura)
			end
		end

		if (Orig_ForEachAura) then
			C_UnitAuras.ForEachAura = function(unit, filter, maxCount, func, ...)
				if (not unit or not func) then
					return
				end
				if (issecretvalue and (issecretvalue(unit) or issecretvalue(filter) or issecretvalue(maxCount))) then
					return
				end
				local function SafeCallback(aura)
					aura = SanitizeAuraData(aura)
					return func(aura)
				end
				return Orig_ForEachAura(unit, filter, maxCount, SafeCallback, ...)
			end
		end

		if (Orig_IsAuraFilteredOutByInstanceID) then
			C_UnitAuras.IsAuraFilteredOutByInstanceID = function(unit, auraInstanceID, filter, ...)
				-- Guard against nil or secret values
				if (not unit or not auraInstanceID or not filter) then return true end
				if (issecretvalue and (issecretvalue(unit) or issecretvalue(auraInstanceID) or issecretvalue(filter))) then
					return true
				end
				return Orig_IsAuraFilteredOutByInstanceID(unit, auraInstanceID, filter, ...)
			end
		end

		-- AuraUtil helpers may also surface secret fields; sanitize callbacks.
		if (AuraUtil and AuraUtil.ForEachAura and not _G.__AzeriteUI_AuraUtilForEachWrapped) then
			_G.__AzeriteUI_AuraUtilForEachWrapped = true
			local Orig_AuraUtilForEach = AuraUtil.ForEachAura
			AuraUtil.ForEachAura = function(unit, filter, maxCount, func, ...)
				if (not unit or not func) then
					return
				end
				if (issecretvalue and (issecretvalue(unit) or issecretvalue(filter) or issecretvalue(maxCount))) then
					return
				end
				local function SafeCallback(aura)
					aura = SanitizeAuraData(aura)
					return func(aura)
				end
				return Orig_AuraUtilForEach(unit, filter, maxCount, SafeCallback, ...)
			end
		end

		if (false and AuraUtil and AuraUtil.UnpackAuraData and not _G.__AzeriteUI_AuraUtilUnpackWrapped) then
			_G.__AzeriteUI_AuraUtilUnpackWrapped = true
			local Orig_Unpack = AuraUtil.UnpackAuraData
			AuraUtil.UnpackAuraData = function(...)
				local results = Pack(Orig_Unpack(...))
				for i = 1, (results.n or #results) do
					if (issecretvalue and issecretvalue(results[i])) then
						results[i] = nil
					end
				end
				return unpack(results, 1, results.n or #results)
			end
		end
	end

	-- WoW 12.0.0: Nameplate aura fixes (secret aura fields, missing auraItemScale)
	local PatchAuraFrameMethods
	local function EnsureNamePlateAuraScaleForUnit(unit)
		if (not unit) then
			return
		end
		if (not C_NamePlate or not C_NamePlate.GetNamePlateForUnit) then
			return
		end
		if (issecretvalue and issecretvalue(unit)) then
			return
		end
		local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
		if (not ok) then
			return
		end
		local frame = plate and (plate.UnitFrame or plate.unitFrame)
		if (not frame) then
			return
		end
		local auraFrame = frame.AurasFrame or frame.aurasFrame
		-- Keep Blizzard aura API calls stable: these mixins expect a valid unit/unitToken.
		frame.unit = unit
		if (auraFrame) then
			auraFrame.unit = unit
			auraFrame.unitToken = unit
		end
		if (auraFrame and not auraFrame.__AzeriteUI_AuraScalePrimed) then
			auraFrame.__AzeriteUI_AuraScalePrimed = true
			if (auraFrame.BuffListFrame and auraFrame.BuffListFrame.auraItemScale == nil) then
				auraFrame.BuffListFrame.auraItemScale = 1
			end
			if (auraFrame.DebuffListFrame and auraFrame.DebuffListFrame.auraItemScale == nil) then
				auraFrame.DebuffListFrame.auraItemScale = 1
			end
			if (auraFrame.CrowdControlListFrame and auraFrame.CrowdControlListFrame.auraItemScale == nil) then
				auraFrame.CrowdControlListFrame.auraItemScale = 1
			end
		end
		if (frame.BuffListFrame and frame.BuffListFrame.auraItemScale == nil) then
			frame.BuffListFrame.auraItemScale = 1
		end
		if (frame.DebuffListFrame and frame.DebuffListFrame.auraItemScale == nil) then
			frame.DebuffListFrame.auraItemScale = 1
		end
		if (frame.CrowdControlListFrame and frame.CrowdControlListFrame.auraItemScale == nil) then
			frame.CrowdControlListFrame.auraItemScale = 1
		end
		if (PatchAuraFrameMethods) then
			PatchAuraFrameMethods(frame)
			if (auraFrame) then
				PatchAuraFrameMethods(auraFrame)
			end
		end
	end

	local ApplyNamePlateAuraFixes = function()
		if (true) then
			return
		end
		local function ResolveUnit(self)
			if (type(self.unit) == "string") then
				return self.unit
			end
			if (self.GetParent) then
				local parent = self:GetParent()
				if (parent) then
					if (type(parent.unit) == "string") then
						self.unit = parent.unit
						return self.unit
					end
					if (parent.UnitFrame and type(parent.UnitFrame.unit) == "string") then
						self.unit = parent.UnitFrame.unit
						return self.unit
					end
					if (parent.unitFrame and type(parent.unitFrame.unit) == "string") then
						self.unit = parent.unitFrame.unit
						return self.unit
					end
				end
			end
			return nil
		end
		local function EnsureAuraScale(listFrame)
			if (listFrame and listFrame.auraItemScale == nil) then
				listFrame.auraItemScale = 1
			end
		end
		local function EnsureFrameAuraScales(frame)
			if (not frame) then
				return
			end
			EnsureAuraScale(frame)
			EnsureAuraScale(frame.BuffListFrame)
			EnsureAuraScale(frame.DebuffListFrame)
			EnsureAuraScale(frame.CrowdControlListFrame)
			EnsureAuraScale(frame.auraList)
			if (frame.AurasFrame or frame.aurasFrame) then
				local auraFrame = frame.AurasFrame or frame.aurasFrame
				EnsureAuraScale(auraFrame.BuffListFrame)
				EnsureAuraScale(auraFrame.DebuffListFrame)
				EnsureAuraScale(auraFrame.CrowdControlListFrame)
			end
		end
		local defaults = {
			isHarmful = false,
			isHelpful = false,
			isStealable = false,
			isFromPlayerOrPlayerPet = false,
			isPlayerAura = false,
			isRaid = false,
			isNameplateOnly = false,
			nameplateShowPersonal = false,
			nameplateShowAll = false,
			duration = 0,
			expirationTime = 0,
			applications = 0,
			spellId = 0,
			auraInstanceID = 0
		}
		local function SanitizeAura(a)
			if (type(a) ~= "table") then
				return a
			end
			if (issecretvalue and issecretvalue(a)) then
				return {}
			end
			if (canaccesstable and not canaccesstable(a)) then
				return {}
			end
			if (not issecretvalue) then
				return a
			end
			local needsCopy = false
			for k, fallback in pairs(defaults) do
				local v = a[k]
				if issecretvalue(v) then
					if (not needsCopy) then
						local ok, copy = pcall(CopyTable, a)
						if (ok and type(copy) == "table") then
							a = copy
						else
							a = {}
						end
						needsCopy = true
					end
					if (fallback ~= nil) then
						a[k] = fallback
					else
						a[k] = nil
					end
				end
			end
			return a
		end

		local function ApplyToMixin(mixin)
			if (not mixin or type(mixin) ~= "table") then
				return
			end
			PatchAuraFrameMethods = function(auraframe)
				if (not auraframe or auraframe.__AzeriteUI_AuraFrameWrapped) then
					return
				end
				auraframe.__AzeriteUI_AuraFrameWrapped = true
				if (type(auraframe.AddAura) == "function") then
					local original = auraframe.AddAura
					auraframe.AddAura = function(self, unit, aura, ...)
						aura = SanitizeAura(aura)
						if (not unit) then
							unit = ResolveUnit(self)
						end
						EnsureFrameAuraScales(self)
						return original(self, unit, aura, ...)
					end
				end
				if (type(auraframe.RefreshList) == "function") then
					local original = auraframe.RefreshList
					auraframe.RefreshList = function(self, listFrame, ...)
						EnsureAuraScale(listFrame)
						EnsureFrameAuraScales(self)
						return original(self, listFrame, ...)
					end
				end
				if (type(auraframe.RefreshAuras) == "function") then
					local original = auraframe.RefreshAuras
					auraframe.RefreshAuras = function(self, ...)
						ResolveUnit(self)
						EnsureFrameAuraScales(self)
						return original(self, ...)
					end
				end
			end

			if (mixin.AddAura ~= mixin.__AzeriteUI_AddAuraWrapped and type(mixin.AddAura) == "function") then
				mixin.__AzeriteUI_AddAuraOriginal = mixin.AddAura
				mixin.__AzeriteUI_AddAuraWrapped = function(self, unit, aura, ...)
					aura = SanitizeAura(aura)
					if (not unit) then
						unit = ResolveUnit(self)
					end
					return mixin.__AzeriteUI_AddAuraOriginal(self, unit, aura, ...)
				end
				mixin.AddAura = mixin.__AzeriteUI_AddAuraWrapped
			end

			if (mixin.UpdateAura and mixin.UpdateAura ~= mixin.__AzeriteUI_UpdateAuraWrapped) then
				mixin.__AzeriteUI_UpdateAuraOriginal = mixin.UpdateAura
				mixin.__AzeriteUI_UpdateAuraWrapped = function(self, auraInstanceID, ...)
					ResolveUnit(self)
					return mixin.__AzeriteUI_UpdateAuraOriginal(self, auraInstanceID, ...)
				end
				mixin.UpdateAura = mixin.__AzeriteUI_UpdateAuraWrapped
			end

			if (mixin.RefreshList ~= mixin.__AzeriteUI_RefreshListWrapped and type(mixin.RefreshList) == "function") then
				mixin.__AzeriteUI_RefreshListOriginal = mixin.RefreshList
				mixin.__AzeriteUI_RefreshListWrapped = function(self, listFrame, ...)
					EnsureAuraScale(listFrame)
					return mixin.__AzeriteUI_RefreshListOriginal(self, listFrame, ...)
				end
				mixin.RefreshList = mixin.__AzeriteUI_RefreshListWrapped
			end

			if (mixin.RefreshAuras and mixin.RefreshAuras ~= mixin.__AzeriteUI_RefreshAurasWrapped) then
				mixin.__AzeriteUI_RefreshAurasOriginal = mixin.RefreshAuras
				mixin.__AzeriteUI_RefreshAurasWrapped = function(self, ...)
					ResolveUnit(self)
					EnsureAuraScale(self.auraList)
					EnsureFrameAuraScales(self)
					return mixin.__AzeriteUI_RefreshAurasOriginal(self, ...)
				end
				mixin.RefreshAuras = mixin.__AzeriteUI_RefreshAurasWrapped
			end
		end

		local function HookAuraScale(mixin)
			if (not mixin or type(mixin) ~= "table") then
				return
			end
			if (mixin.__AzeriteUI_AuraScaleHooked) then
				return
			end
			mixin.__AzeriteUI_AuraScaleHooked = true
			if (type(mixin.RefreshList) == "function") then
				hooksecurefunc(mixin, "RefreshList", function(self, listFrame)
					EnsureAuraScale(self)
					EnsureAuraScale(listFrame)
				end)
			end
			if (type(mixin.RefreshAuras) == "function") then
				hooksecurefunc(mixin, "RefreshAuras", function(self)
					EnsureFrameAuraScales(self)
				end)
			end
		end

		if (not issecretvalue) then
			-- Do NOT call ApplyToMixin on nameplate mixins - it taints nameplate creation
			-- Only use HookAuraScale which uses hooksecurefunc (safe)
			-- ApplyToMixin(_G.NamePlateBaseAuraFrameMixin)
			-- ApplyToMixin(_G.NamePlateAuraFrameMixin)
			-- ApplyToMixin(_G.NamePlateAurasMixin)
			-- ApplyToMixin(_G.NamePlateAuraMixin)
			-- ApplyToMixin(_G.NamePlateUnitFrameAuraMixin)
		end
	HookAuraScale(_G.NamePlateBaseAuraFrameMixin)
	HookAuraScale(_G.NamePlateAuraFrameMixin)
	HookAuraScale(_G.NamePlateAurasMixin)
	HookAuraScale(_G.NamePlateAuraMixin)
	HookAuraScale(_G.NamePlateUnitFrameAuraMixin)

	-- Guard class color lookups against secret class tokens.
	if (_G.ColorUtil and _G.ColorUtil.GetClassColor and not _G.__AzeriteUI_ColorUtilSafe) then
		_G.__AzeriteUI_ColorUtilSafe = true
		local Orig_GetClassColor = _G.ColorUtil.GetClassColor
		_G.ColorUtil.GetClassColor = function(classFilename, useAlt)
			if (issecretvalue and classFilename and issecretvalue(classFilename)) then
				classFilename = nil
			end
			if (type(classFilename) ~= "string") then
				classFilename = "PRIEST"
			end
			local ok, r = pcall(Orig_GetClassColor, classFilename, useAlt)
			if ok and r then
				return r
			end
			return {r=1,g=1,b=1,colorStr="FFFFFFFF"}
		end
	end

		if (C_NamePlate and C_NamePlate.GetNamePlates) then
			for _, plate in pairs(C_NamePlate.GetNamePlates()) do
				local frame = plate and (plate.UnitFrame or plate.unitFrame)
				EnsureFrameAuraScales(frame)
				if (PatchAuraFrameMethods) then
					PatchAuraFrameMethods(frame)
					if (frame and (frame.AurasFrame or frame.aurasFrame)) then
						PatchAuraFrameMethods(frame.AurasFrame or frame.aurasFrame)
					end
				end
			end
		end
	end

	-- WoW 12.0.0: Nameplate raid target secret-value fix
	local function ApplyNamePlateRaidTargetFixes()
		local function WrapMixin(mixin)
			if (not mixin or mixin.__AzeriteUI_RaidTargetWrapped) then
				return
			end
			if (type(mixin.SetRaidTargetIndex) ~= "function") then
				return
			end
			mixin.__AzeriteUI_RaidTargetWrapped = true
			local original = mixin.SetRaidTargetIndex
			mixin.SetRaidTargetIndex = function(self, raidTargetIndex, ...)
				if (issecretvalue and raidTargetIndex and issecretvalue(raidTargetIndex)) then
					raidTargetIndex = nil
				end
				if (self and issecretvalue and self.raidTargetIndex and issecretvalue(self.raidTargetIndex)) then
					self.raidTargetIndex = nil
				end
				return original(self, raidTargetIndex, ...)
			end
		end

		if (not issecretvalue) then
			WrapMixin(_G.NamePlateRaidTargetFrameMixin)
			WrapMixin(_G.NamePlateRaidTargetMixin)
		end

		if (issecretvalue) then
			return
		end

		if (C_NamePlate and C_NamePlate.GetNamePlates) then
			for _, plate in pairs(C_NamePlate.GetNamePlates()) do
				local frame = plate and (plate.UnitFrame or plate.unitFrame)
				local raid = frame and (frame.RaidTargetFrame or frame.raidTargetFrame or frame.RaidTarget)
				if (raid and type(raid.SetRaidTargetIndex) == "function" and not raid.__AzeriteUI_RaidTargetWrapped) then
					raid.__AzeriteUI_RaidTargetWrapped = true
					local original = raid.SetRaidTargetIndex
					raid.SetRaidTargetIndex = function(self, raidTargetIndex, ...)
						if (issecretvalue and raidTargetIndex and issecretvalue(raidTargetIndex)) then
							raidTargetIndex = nil
						end
						if (self and issecretvalue and self.raidTargetIndex and issecretvalue(self.raidTargetIndex)) then
							self.raidTargetIndex = nil
						end
						return original(self, raidTargetIndex, ...)
					end
				end
			end
		end
	end

	-- WoW 12.0.0: Fix Blizzard_PVPMatch scoreboard pool nil Release spam
	-- Blizzard_SharedXMLBase/Pools.lua:89 - PVP scoreboard tries to release nil objects
	local function FixPVPMatchScoreboardPools()
		if (_G.__AzeriteUI_PoolReleaseWrapped) then
			return true
		end
		-- Wrap ObjectPoolMixin Release to guard against nil
		if (_G.ObjectPoolMixin and type(_G.ObjectPoolMixin.Release) == "function") then
			local original = _G.ObjectPoolMixin.Release
			_G.ObjectPoolMixin.Release = function(self, object, ...)
				if (object == nil) then
					-- Silently ignore nil release - Blizzard PVP bug
					return
				end
				return original(self, object, ...)
			end
			_G.__AzeriteUI_PoolReleaseWrapped = true
			return true
		end
		return false
	end

	-- Apply immediately if mixin already exists
	ApplyNamePlateAuraFixes()
	if C_Timer then
		C_Timer.After(0, ApplyNamePlateAuraFixes)
	end
	ApplyNamePlateRaidTargetFixes()
	if C_Timer then
		C_Timer.After(0, ApplyNamePlateRaidTargetFixes)
	end

	frame:SetScript("OnEvent", function(_, event, addonName)
		-- Fix CastingBarFrame SetShown secret value error on ALL casting bars (including nameplates)
		-- Hook the CastingBarFrameMixin methods globally
		if (event == "PLAYER_LOGIN") then
			ApplyCastingBarFixes()
			DisableEditModeSensitiveFrames()
			DisableBlizzardUnitFrames()
			WrapEncounterWarnings()
			WrapPRD()
			FixPVPMatchScoreboardPools()
			local hooked = HookEditModeBypass()
			HookEditModeEventRegistry()
			HookEditModeRegistrationPrune()
			PrePruneEditModeSystems()
			-- Disabled: global aura API rewrites taint Blizzard aura consumers on WoW12.
			ApplyNamePlateAuraFixes()
			ApplyNamePlateRaidTargetFixes()
			if (C_EditMode and C_EditMode.IsEditModeActive) then
				local ok, active = pcall(C_EditMode.IsEditModeActive)
				if (ok) then
					SetEditModeBypass(active and true or false)
				end
			end
			if C_Timer then
				C_Timer.After(0, ApplyCastingBarFixes)
				C_Timer.After(1, ApplyCastingBarFixes)
				C_Timer.NewTicker(1, ApplyCastingBarFixes, 10)
				if (not _G.__AzeriteUI_EncounterWarningsTicker) then
					_G.__AzeriteUI_EncounterWarningsTicker = true
					C_Timer.NewTicker(1, WrapEncounterWarnings, 10)
				end
				if (not _G.__AzeriteUI_PRDTicker) then
					_G.__AzeriteUI_PRDTicker = true
					C_Timer.NewTicker(1, WrapPRD, 10)
				end
				C_Timer.After(0, PrePruneEditModeSystems)
				C_Timer.After(1, PrePruneEditModeSystems)
				C_Timer.After(0, HookEditModeRegistrationPrune)
				C_Timer.After(0, HookEditModeBypass)
				C_Timer.After(1, HookEditModeBypass)
				C_Timer.After(0, HookEditModeEventRegistry)
				C_Timer.After(0, DisableEditModeSensitiveFrames)
				C_Timer.After(1, DisableEditModeSensitiveFrames)
				if (not hooked and not _G.__AzeriteUI_EditModeBypassTicker) then
					_G.__AzeriteUI_EditModeBypassTicker = true
					local ticker
					ticker = C_Timer.NewTicker(1, function()
						if (HookEditModeBypass()) then
							if (ticker and ticker.Cancel) then
								ticker:Cancel()
							end
							_G.__AzeriteUI_EditModeBypassTicker = nil
						end
					end, 30)
				end
			end
		elseif (event == "ADDON_LOADED") then
			-- Re-apply if Blizzard overwrote mixins during addon loads
			if (CastingBarFrameMixin) then
				ApplyCastingBarFixes()
			end
			if (NamePlateBaseAuraFrameMixin) then
				ApplyNamePlateAuraFixes()
			end
			if (addonName == "Blizzard_NamePlates" or addonName == "Blizzard_UIPanels_Game") then
				-- Disabled: global aura API rewrites taint Blizzard aura consumers on WoW12.
				if C_Timer then
					C_Timer.After(0, ApplyCastingBarFixes)
					C_Timer.After(1, ApplyCastingBarFixes)
					C_Timer.NewTicker(1, ApplyCastingBarFixes, 10)
				end
			end
			if (addonName == "Blizzard_EncounterWarnings") then
				DisableEditModeSensitiveFrames()
				WrapEncounterWarnings()
				if (C_Timer and not _G.__AzeriteUI_EncounterWarningsTicker) then
					_G.__AzeriteUI_EncounterWarningsTicker = true
					C_Timer.NewTicker(1, WrapEncounterWarnings, 10)
				end
			end
			if (addonName == "Blizzard_PersonalResourceDisplay") then
				DisableEditModeSensitiveFrames()
				WrapPRD()
				if (C_Timer and not _G.__AzeriteUI_PRDTicker) then
					_G.__AzeriteUI_PRDTicker = true
					C_Timer.NewTicker(1, WrapPRD, 10)
				end
			end
			if (addonName == "Blizzard_EditMode") then
				HookEditModeEventRegistry()
				HookEditModeRegistrationPrune()
				PrePruneEditModeSystems()
				if (C_Timer) then
					C_Timer.After(0, PrePruneEditModeSystems)
					C_Timer.After(1, PrePruneEditModeSystems)
					C_Timer.After(0, HookEditModeRegistrationPrune)
				end
				if (not HookEditModeBypass() and C_Timer and not _G.__AzeriteUI_EditModeBypassTicker) then
					_G.__AzeriteUI_EditModeBypassTicker = true
					local ticker
					ticker = C_Timer.NewTicker(1, function()
						if (HookEditModeBypass()) then
							if (ticker and ticker.Cancel) then
								ticker:Cancel()
							end
							_G.__AzeriteUI_EditModeBypassTicker = nil
						end
					end, 30)
				end
				DisableEditModeSensitiveFrames()
			end
			if (addonName == "Blizzard_FrameXML" or addonName == "Blizzard_UIParentPanelManager") then
				DisableEditModeSensitiveFrames()
			end
			if (addonName == "Blizzard_BuffFrame") then
				DisableEditModeSensitiveFrames()
			end
			if (addonName == "Blizzard_UnitFrame") then
				DisableBlizzardUnitFrames()
			end
			if (addonName == "Blizzard_NamePlates") then
				ApplyNamePlateAuraFixes()
				ApplyNamePlateRaidTargetFixes()
				DisableClassNameplateBars()
				if (C_Timer and not _G.__AzeriteUI_NamePlateAuraFixTicker) then
					_G.__AzeriteUI_NamePlateAuraFixTicker = true
					C_Timer.NewTicker(1, ApplyNamePlateAuraFixes, 10)
				end
				if (C_Timer and not _G.__AzeriteUI_NamePlateRaidTargetFixTicker) then
					_G.__AzeriteUI_NamePlateRaidTargetFixTicker = true
					C_Timer.NewTicker(1, ApplyNamePlateRaidTargetFixes, 10)
				end
				if (C_Timer and not _G.__AzeriteUI_CastbarPatchTicker) then
					_G.__AzeriteUI_CastbarPatchTicker = true
					C_Timer.NewTicker(1, PatchExistingCastingBars, 20)
				end
			end
			if (addonName == "Blizzard_PVPMatch") then
				FixPVPMatchScoreboardPools()
				if (C_Timer and not _G.__AzeriteUI_PVPPoolFixTicker) then
					_G.__AzeriteUI_PVPPoolFixTicker = true
					C_Timer.NewTicker(1, FixPVPMatchScoreboardPools, 5)
				end
			end
		elseif (event == "NAME_PLATE_UNIT_ADDED") then
			EnsureNamePlateAuraScaleForUnit(addonName)
			PatchCastingBarForUnit(addonName)
			ApplyNamePlateRaidTargetFixes()
			DisableClassNameplateBars()
		elseif (event == "EDIT_MODE_LAYOUTS_UPDATED") then
			DisableEditModeSensitiveFrames()
			PrePruneEditModeSystems()
		end
	
	-- WoW 12.0.0: Fix Blizzard UnitFrame mana bar secret value errors
		-- Blizzard sometimes performs arithmetic/comparisons on secret values.
		-- We can't safely "fix" Blizzard's internal math, so we disable the mana bar on first error.
		if (false and not _G.__AzeriteUI_UnitFrameManaBar_UpdateWrapped) then
			local original = _G.UnitFrameManaBar_Update
			if (type(original) == "function") then
				_G.__AzeriteUI_UnitFrameManaBar_UpdateWrapped = true
				_G.UnitFrameManaBar_Update = function(manaBar, unit)
					if (manaBar and manaBar.__AzeriteUI_secretDisabled) then
						return
					end
					local ok = pcall(original, manaBar, unit)
					if (not ok) then
						if (manaBar) then
							manaBar.__AzeriteUI_secretDisabled = true
							if (manaBar.Hide) then
								manaBar:Hide()
							end
						end
					end
				end
			end
		end

		-- WoW 12.0.0: Fix Blizzard UnitFrame heal prediction secret value errors
		-- This can fire from Edit Mode / party frames even if you don't use Blizzard unitframes.
		local function wrapHealPrediction(funcName)
			local original = _G[funcName]
			if (type(original) ~= "function") then
				return
			end
			if (_G["__AzeriteUI_" .. funcName .. "Wrapped"]) then
				return
			end
			_G["__AzeriteUI_" .. funcName .. "Wrapped"] = true
			_G[funcName] = function(frame, ...)
				if (frame and frame.__AzeriteUI_healPredictionSecretDisabled) then
					return
				end
				local ok = pcall(original, frame, ...)
				if (not ok) then
					if (frame) then
						frame.__AzeriteUI_healPredictionSecretDisabled = true
						-- Hide common prediction bar regions if present
						pcall(function()
							if (frame.myHealPredictionBar) then frame.myHealPredictionBar:Hide() end
							if (frame.otherHealPredictionBar) then frame.otherHealPredictionBar:Hide() end
							if (frame.healAbsorbBar) then frame.healAbsorbBar:Hide() end
							if (frame.totalAbsorbBar) then frame.totalAbsorbBar:Hide() end
							if (frame.overAbsorbGlow) then frame.overAbsorbGlow:Hide() end
							if (frame.overHealAbsorbGlow) then frame.overHealAbsorbGlow:Hide() end
						end)
					end
				end
			end
		end

		if (false) then
			wrapHealPrediction("UnitFrameHealPredictionBars_Update")
		end

		-- WoW 12.0.0: Guard AuraUtil.UnpackAuraData against secret points
		if (AuraUtil and AuraUtil.UnpackAuraData and not _G.__AzeriteUI_AuraUtilUnpackWrapped) then
			_G.__AzeriteUI_AuraUtilUnpackWrapped = true
			local originalUnpack = AuraUtil.UnpackAuraData
			AuraUtil.UnpackAuraData = function(auraData, ...)
				if (issecretvalue and auraData) then
					if (issecretvalue(auraData)) then
						return originalUnpack(auraData, ...)
					end
					if (canaccesstable and not canaccesstable(auraData)) then
						return originalUnpack(auraData, ...)
					end
					if issecretvalue(auraData.points) then
						local ok, copy = pcall(CopyTable, auraData)
						if (ok and type(copy) == "table") then
							auraData = copy
							auraData.points = nil
						end
					end
				end
				return originalUnpack(auraData, ...)
			end
		end

		-- WoW 12.0.0: Guard C_UnitAuras.GetUnitAuras against invalid/secret unit/filter
		if (false and C_UnitAuras and C_UnitAuras.GetUnitAuras and not _G.__AzeriteUI_GetUnitAurasWrapped) then
			_G.__AzeriteUI_GetUnitAurasWrapped = true
			local originalGetUnitAuras = C_UnitAuras.GetUnitAuras
			C_UnitAuras.GetUnitAuras = function(unit, filter, ...)
				if (type(unit) ~= "string") then
					return {}
				end
				if (issecretvalue and (issecretvalue(unit) or issecretvalue(filter))) then
					return {}
				end
				local ok, result = pcall(originalGetUnitAuras, unit, filter, ...)
				if (not ok) then
					return {}
				end
				return result or {}
			end
		end

		-- WoW 12.0.0: Narrow argument guards for Blizzard nameplate aura APIs.
		-- Avoid broad aura table mutation; only coerce invalid inputs to safe fallbacks.
		if (false and C_UnitAuras and not _G.__AzeriteUI_UnitAuraArgGuardsWrapped) then
			_G.__AzeriteUI_UnitAuraArgGuardsWrapped = true

			if (type(C_UnitAuras.GetUnitAuras) == "function") then
				local Orig_GetUnitAuras = C_UnitAuras.GetUnitAuras
				C_UnitAuras.GetUnitAuras = function(unit, filter, ...)
					if (type(unit) ~= "string") then
						return {}
					end
					if (issecretvalue and (issecretvalue(unit) or issecretvalue(filter))) then
						return {}
					end
					local ok, result = pcall(Orig_GetUnitAuras, unit, filter, ...)
					if (not ok) then
						return {}
					end
					return result or {}
				end
			end

			if (type(C_UnitAuras.GetAuraDataByAuraInstanceID) == "function") then
				local Orig_GetAuraByID = C_UnitAuras.GetAuraDataByAuraInstanceID
				C_UnitAuras.GetAuraDataByAuraInstanceID = function(unit, auraInstanceID, ...)
					if (type(unit) ~= "string") then
						return nil
					end
					if (type(auraInstanceID) ~= "number") then
						return nil
					end
					if (issecretvalue and (issecretvalue(unit) or issecretvalue(auraInstanceID))) then
						return nil
					end
					local ok, aura = pcall(Orig_GetAuraByID, unit, auraInstanceID, ...)
					if (not ok) then
						return nil
					end
					return aura
				end
			end

			if (type(C_UnitAuras.IsAuraFilteredOutByInstanceID) == "function") then
				local Orig_IsAuraFiltered = C_UnitAuras.IsAuraFilteredOutByInstanceID
				C_UnitAuras.IsAuraFilteredOutByInstanceID = function(unit, auraInstanceID, filter, ...)
					if (type(unit) ~= "string") then
						return true
					end
					if (type(auraInstanceID) ~= "number") then
						return true
					end
					if (type(filter) ~= "string") then
						return true
					end
					if (issecretvalue and (issecretvalue(unit) or issecretvalue(auraInstanceID) or issecretvalue(filter))) then
						return true
					end
					local ok, isFiltered = pcall(Orig_IsAuraFiltered, unit, auraInstanceID, filter, ...)
					if (not ok) then
						return true
					end
					return isFiltered and true or false
				end
			end
		end

		-- WoW 12.0.0: Guard CompactUnitFrame_UpdateAuras to avoid secret-value errors (nameplates)
		if (false and _G.CompactUnitFrame_UpdateAuras and not _G.__AzeriteUI_CompactUnitFrameUpdateAurasWrapped) then
			_G.__AzeriteUI_CompactUnitFrameUpdateAurasWrapped = true
			local originalCUF = _G.CompactUnitFrame_UpdateAuras
			_G.CompactUnitFrame_UpdateAuras = function(frame, ...)
				local ok = pcall(originalCUF, frame, ...)
				if (not ok and frame and frame.AurasFrame) then
					frame.AurasFrame:Hide()
				end
			end
		end
		if (false) then
			wrapHealPrediction("UnitFrameHealPredictionBars_UpdateMax")
		end

		-- (WrapPRD moved outside event handler)

		-- WoW 12.0.0: Guard TextStatusBar UpdateTextStringWithValues against secret value comparisons (party frames)
		if (false and not _G.__AzeriteUI_TextStatusBarWrapped) then
			_G.__AzeriteUI_TextStatusBarWrapped = true
			-- Wrap the StatusBar mixin method globally
			if (_G.TextStatusBar and type(_G.TextStatusBar.UpdateTextStringWithValues) == "function") then
				local originalUpdate = _G.TextStatusBar.UpdateTextStringWithValues
				_G.TextStatusBar.UpdateTextStringWithValues = function(self, ...)
					local ok = pcall(originalUpdate, self, ...)
					if (not ok and self and self.TextString) then
						-- Suppress error, just hide the text
						pcall(function() self.TextString:SetText("") end)
					end
				end
			end
			-- Also wrap UpdateTextString which calls UpdateTextStringWithValues
			if (_G.TextStatusBar and type(_G.TextStatusBar.UpdateTextString) == "function") then
				local originalUpdateTextString = _G.TextStatusBar.UpdateTextString
				_G.TextStatusBar.UpdateTextString = function(self, ...)
					local ok = pcall(originalUpdateTextString, self, ...)
					if (not ok and self and self.TextString) then
						pcall(function() self.TextString:SetText("") end)
					end
				end
			end
		end
	end)
end

local function ApplyWoW12TooltipMoneyGuards()
	if (_G.SetTooltipMoney and not _G.__AzeriteUI_WoW12_SetTooltipMoneySafeWrapped) then
		_G.__AzeriteUI_WoW12_SetTooltipMoneySafeWrapped = true
		local original = _G.SetTooltipMoney
		_G.SetTooltipMoney = function(frame, money, ...)
			if (issecretvalue and issecretvalue(money)) then
				return
			end
			local ok = pcall(original, frame, money, ...)
			if (ok) then
				return
			end
			local moneyFrame = frame and frame.TooltipMoneyFrame
			if (moneyFrame and moneyFrame.Hide) then
				moneyFrame:Hide()
			end
		end
	end

	if (_G.MoneyFrame_Update and not _G.__AzeriteUI_WoW12_MoneyFrameUpdateSafeWrapped) then
		_G.__AzeriteUI_WoW12_MoneyFrameUpdateSafeWrapped = true
		local original = _G.MoneyFrame_Update
		_G.MoneyFrame_Update = function(frame, money, ...)
			if (issecretvalue and (issecretvalue(money) or issecretvalue(frame))) then
				if (frame and frame.Hide) then
					frame:Hide()
				end
				return
			end
			local ok = pcall(original, frame, money, ...)
			if (ok) then
				return
			end
			if (frame and frame.Hide) then
				frame:Hide()
			end
		end
	end
end

local function IsPassiveWoW12FixEnvironment()
	return (issecretvalue or canaccesstable or (ns.ClientVersion and ns.ClientVersion >= 120000)) and true or false
end

local function ApplyPlaterNamePlateAbsorbCleanup()
	if (not (ns and ns.API and ns.API.IsAddOnEnabled and ns.API.IsAddOnEnabled("Plater"))) then
		return
	end
	if (_G.__AzeriteUI_PlaterAbsorbCleanupInitialized) then
		return
	end
	_G.__AzeriteUI_PlaterAbsorbCleanupInitialized = true

	local function HideObject(object)
		if (not object) then
			return
		end
		if (object.SetAlpha) then
			pcall(object.SetAlpha, object, 0)
		end
		if (object.Hide) then
			pcall(object.Hide, object)
		end
		if (object.UnregisterAllEvents) then
			pcall(object.UnregisterAllEvents, object)
		end
	end

	local function LockHiddenOnShow(object)
		if (not object or object.__AzeriteUI_PlaterAbsorbHideHooked or not object.HookScript) then
			return
		end
		object.__AzeriteUI_PlaterAbsorbHideHooked = true
		object:HookScript("OnShow", function(self)
			HideObject(self)
		end)
	end

	local function HideNamedChildren(frame)
		if (not frame) then
			return
		end
		for _, key in ipairs({
			"AbsorbBar",
			"absorbBar",
			"TotalAbsorbBar",
			"totalAbsorbBar",
			"HealAbsorbBar",
			"healAbsorbBar",
			"ShieldBar",
			"shieldBar"
		}) do
			local child = frame[key]
			if (child) then
				HideObject(child)
				LockHiddenOnShow(child)
				HideObject(child.barTexture)
				HideObject(child.BarTexture)
				HideObject(child.border)
				HideObject(child.Border)
			end
		end
	end

	local function HideAbsorbChildrenByName(frame)
		if (not frame or not frame.GetNumChildren) then
			return
		end
		for i = 1, frame:GetNumChildren() do
			local child = select(i, frame:GetChildren())
			local childName = child and child.GetName and child:GetName()
			if (type(childName) == "string"
				and (string.find(childName, "Absorb", 1, true)
					or string.find(childName, "Shield", 1, true))) then
				HideObject(child)
				LockHiddenOnShow(child)
				HideObject(child.barTexture)
				HideObject(child.BarTexture)
				HideObject(child.border)
				HideObject(child.Border)
			end
		end
	end

	local function HidePlaterAbsorbVisualsForPlate(plate)
		if (not plate or not C_NamePlate or not C_NamePlate.GetNamePlateForUnit) then
			return
		end

		local unitFrame = plate.UnitFrame or plate.unitFrame
		if (not unitFrame) then
			return
		end

		local plateName = plate.GetName and plate:GetName() or ""
		local frameName = unitFrame.GetName and unitFrame:GetName() or ""
		if ((type(plateName) ~= "string" or not string.find(plateName, "Plater", 1, true))
			and (type(frameName) ~= "string" or not string.find(frameName, "Plater", 1, true))) then
			return
		end

		HideNamedChildren(unitFrame)
		HideAbsorbChildrenByName(unitFrame)

		local healthBar = unitFrame.healthBar or unitFrame.HealthBar or unitFrame.healthbar
		if (healthBar) then
			HideNamedChildren(healthBar)
			HideAbsorbChildrenByName(healthBar)
		end
	end

	local cleanupFrame = CreateFrame("Frame")
	cleanupFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
	cleanupFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
	cleanupFrame:RegisterEvent("ADDON_LOADED")
	cleanupFrame:SetScript("OnEvent", function(_, event, arg1)
		if (event == "ADDON_LOADED" and arg1 ~= "Plater") then
			return
		end
		if (event == "NAME_PLATE_UNIT_ADDED") then
			local unit = arg1
			if (type(unit) ~= "string") then
				return
			end
			local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
			if (ok and plate) then
				HidePlaterAbsorbVisualsForPlate(plate)
				if (C_Timer) then
					C_Timer.After(0, function() HidePlaterAbsorbVisualsForPlate(plate) end)
					C_Timer.After(.1, function() HidePlaterAbsorbVisualsForPlate(plate) end)
				end
			end
			return
		end
		if (C_NamePlate and C_NamePlate.GetNamePlates) then
			for _, plate in pairs(C_NamePlate.GetNamePlates()) do
				HidePlaterAbsorbVisualsForPlate(plate)
			end
		end
	end)
end


FixBlizzardBugs.OnInitialize = function(self)

	-- Don't call this prior to our own addon loading,
	-- or it'll completely mess up the loading order.
	local LoadAddOnFunc = (C_AddOns and C_AddOns.LoadAddOn) or LoadAddOn
	if (LoadAddOnFunc) then
		pcall(LoadAddOnFunc, "Blizzard_Channels")
	end

	-- Kill off the non-stop voice chat error 17 on retail.
	-- This only occurs in linux, but we can't check for that.
	if (ChannelFrame and ChannelFrame.UnregisterEvent) then
		ChannelFrame:UnregisterEvent("VOICE_CHAT_ERROR")
	end

	-- WoW 12+: keep this module passive to avoid tainting Blizzard secure flows.
	-- Follow the UnhaltedUnitFrames approach: avoid Blizzard function rewrites.
	-- Note: ns.ClientBuild is the build number (~58135), NOT the TOC version.
	-- ns.ClientVersion is the interface/TOC number (120000+ for WoW 12).
	if (IsPassiveWoW12FixEnvironment()) then
		ApplyWoW12TooltipMoneyGuards()
		ApplyPlaterNamePlateAbsorbCleanup()
		-- IMPORTANT: Do NOT replace BackdropMixin.SetupTextureCoordinates here.
		-- Replacing mixin methods with addon functions taints every frame that
		-- uses BackdropMixin, which spreads "tainted by AzeriteUI" to Edit Mode
		-- systems (EncounterWarnings, CompactUnitFrame, SecureUtil, etc.).
		-- The tooltip backdrop error is cosmetic; the taint cascade is not.
		-- CastingBarFrame StopFinishAnims guard is handled by FixBlizzardBugsWow12.lua.
		-- Everything below this return is the legacy pre-WoW12 path and does not
		-- execute once the secret-value / forbidden-table environment is present.
		return
	end

	-- Legacy pre-WoW12 path intentionally commented out.
	-- The live WoW 12 path returns above and uses:
	-- * `ApplyWoW12TooltipMoneyGuards()`
	-- * `ApplyPlaterNamePlateAbsorbCleanup()`
	-- * `Core/FixBlizzardBugsWow12.lua`
	--
	-- If pre-WoW12 support needs to be restored later, recover it from git history
	-- instead of mixing inactive legacy guards back into the live WoW 12 audit path.

end

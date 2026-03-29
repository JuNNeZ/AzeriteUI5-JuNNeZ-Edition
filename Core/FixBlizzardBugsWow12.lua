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

----------------------------------------------------------------
-- WoW 12+ Blizzard frame ownership reset
-- Keep this file narrow:
-- * quarantine Blizzard compact party/raid/arena frames we replace
-- * quarantine Blizzard spellbars we replace
-- * sanitize compact aura predicates only
-- Do NOT mutate Blizzard nameplate unitframes here.
----------------------------------------------------------------

if (not canaccesstable) then
	return
end

local Pack = table.pack or function(...)
	return { n = select("#", ...), ... }
end

local MAX_PARTY_MEMBERS = _G.MEMBERS_PER_RAID_GROUP or 5
local MAX_RAID_MEMBERS = _G.MAX_RAID_MEMBERS or 40
local MAX_BOSS_FRAMES = _G.MAX_BOSS_FRAMES or 8
local MAX_ARENA_MEMBERS = _G.MAX_ARENA_ENEMIES or 5

local COMPACT_AURA_DEFAULTS = {
	isBossAura = false,
	isFromPlayerOrPlayerPet = false,
	isHelpful = false,
	isStealable = false,
	isRaid = false,
	isHarmful = false,
	canApplyAura = false,
	canActivePlayerDispel = false,
	isTankRoleAura = false,
	isDPSRoleAura = false,
	isNameplateOnly = false,
	isHealerRoleAura = false,
	nameplateShowPersonal = false,
	nameplateShowAll = false,
	duration = 0,
	expirationTime = 0,
	applications = 0,
	spellId = 0,
	auraInstanceID = 0,
	timeMod = 1
}

local quarantineHiddenParent
local parentLockedFrames = {}
local pendingQuarantineFrames = {}
local pendingReparentFrames = {}
local PrepareCompactFrame
local SAFE_CASTBAR_TYPE_INFO = {
	filling = "ui-castingbar-filling-standard",
	full = "ui-castingbar-full-standard",
	glow = "ui-castingbar-full-glow-standard",
	sparkFx = "StandardGlow",
	finishAnim = "StandardFinish"
}

-- Generic wrapper: silently bail when the frame is inaccessible, pcall otherwise.
local function MakeSafeVoidMethod(origFunc)
	return function(self, ...)
		if (self and type(self) == "table" and not canaccesstable(self)) then
			return
		end
		pcall(origFunc, self, ...)
	end
end

local function MakeSafeGetTypeInfo(origFunc)
	return function(self, ...)
		if (self and type(self) == "table" and not canaccesstable(self)) then
			return SAFE_CASTBAR_TYPE_INFO
		end
		local ok, info = pcall(origFunc, self, ...)
		if (ok and type(info) == "table" and (not canaccesstable or canaccesstable(info))) then
			if (self and type(self) == "table") then
				self.__AzUI_W12_LastTypeInfo = info
			end
			return info
		end
		if (self and type(self) == "table") then
			local cached = rawget(self, "__AzUI_W12_LastTypeInfo")
			if (type(cached) == "table" and (not canaccesstable or canaccesstable(cached))) then
				return cached
			end
		end
		return SAFE_CASTBAR_TYPE_INFO
	end
end

-- Table-driven castbar method guards: each entry is { method, wrapper }.
-- MakeSafeVoidMethod is used for fire-and-forget visual methods;
-- MakeSafeGetTypeInfo is used for the one method that returns a value.
local CASTBAR_GUARDS = {
	{ "StopFinishAnims",  MakeSafeVoidMethod },
	{ "HideSpark",        MakeSafeVoidMethod },
	{ "ShowSpark",        MakeSafeVoidMethod },
	{ "PlayFinishAnim",   MakeSafeVoidMethod },
	{ "UpdateShownState", MakeSafeVoidMethod },
	{ "GetTypeInfo",      MakeSafeGetTypeInfo },
}

local function GuardCastingBarFrame(frame)
	if (not frame or type(frame) ~= "table") then
		return
	end
	for _, guard in ipairs(CASTBAR_GUARDS) do
		local method, wrapper = guard[1], guard[2]
		local flag = "__AzUI_W12_CB_" .. method
		if (type(frame[method]) == "function" and not frame[flag]) then
			frame[flag] = true
			frame[method] = wrapper(frame[method])
		end
	end
end

local function ApplyCastingBarGuards()
	-- Guard both mixin tables so newly created castbars inherit the wraps.
	for _, mixin in ipairs({ _G.CastingBarMixin, _G.CastingBarFrameMixin }) do
		if (mixin) then
			for _, guard in ipairs(CASTBAR_GUARDS) do
				local method, wrapper = guard[1], guard[2]
				local flag = "__AzUI_W12_CB_" .. method
				if (type(mixin[method]) == "function" and not mixin[flag]) then
					mixin[flag] = true
					mixin[method] = wrapper(mixin[method])
				end
			end
		end
	end

	GuardCastingBarFrame(_G.PlayerCastingBarFrame)
	GuardCastingBarFrame(_G.OverlayPlayerCastingBarFrame)
	GuardCastingBarFrame(_G.PetCastingBarFrame)
	GuardCastingBarFrame(_G.TargetFrameSpellBar)
	GuardCastingBarFrame(_G.FocusFrameSpellBar)

	for i = 1, MAX_BOSS_FRAMES do
		GuardCastingBarFrame(_G["Boss" .. i .. "TargetFrameSpellBar"])
	end

	if (_G.CompactArenaFrame and type(_G.CompactArenaFrame.memberUnitFrames) == "table") then
		for _, unitFrame in pairs(_G.CompactArenaFrame.memberUnitFrames) do
			if (unitFrame) then
				GuardCastingBarFrame(unitFrame.castBar or unitFrame.CastBar or unitFrame.castbar or unitFrame.CastingBarFrame)
				GuardCastingBarFrame(unitFrame)
			end
		end
	end

	for i = 1, MAX_ARENA_MEMBERS do
		local arenaFrame = _G["ArenaEnemyMatchFrame" .. i]
		if (arenaFrame) then
			GuardCastingBarFrame(arenaFrame.castBar or arenaFrame.CastBar or arenaFrame.castbar or arenaFrame.CastingBarFrame)
		end
		local compactArenaFrame = _G["CompactArenaFrameMember" .. i]
		if (compactArenaFrame) then
			GuardCastingBarFrame(compactArenaFrame.castBar or compactArenaFrame.CastBar or compactArenaFrame.castbar or compactArenaFrame.CastingBarFrame)
			GuardCastingBarFrame(compactArenaFrame)
		end
	end

	-- Hook CastingBarFrame_SetUnit (the global) to guard nameplate castbars.
	if (type(_G.CastingBarFrame_SetUnit) == "function"
		and not _G.__AzUI_W12_CastBarSetUnitHooked) then
		_G.__AzUI_W12_CastBarSetUnitHooked = true
		hooksecurefunc("CastingBarFrame_SetUnit", function(castBar)
			if (castBar) then
				GuardCastingBarFrame(castBar)
			end
		end)
	end
end

local function IsModuleEnabled(name, defaultValue)
	if (not ns or not ns.GetModule) then
		return defaultValue and true or false
	end
	local ok, module = pcall(ns.GetModule, ns, name, true)
	if (not ok or not module) then
		return defaultValue and true or false
	end
	local enabled = module.db and module.db.profile and module.db.profile.enabled
	if (type(enabled) == "boolean") then
		return enabled
	end
	return defaultValue and true or false
end

local function GetModuleProfileValue(name, key, defaultValue)
	if (not ns or not ns.GetModule) then
		return defaultValue
	end
	local ok, module = pcall(ns.GetModule, ns, name, true)
	if (not ok or not module) then
		return defaultValue
	end
	local profile = module.db and module.db.profile
	if (type(profile) ~= "table") then
		return defaultValue
	end
	local value = profile[key]
	if (value == nil) then
		return defaultValue
	end
	return value
end

local function ShouldHandlePartyFrames()
	return IsModuleEnabled("PartyFrames", true)
end

local function ShouldHandleRaidFrames()
	return IsModuleEnabled("RaidFrame5", true)
		or IsModuleEnabled("RaidFrame25", true)
		or IsModuleEnabled("RaidFrame40", true)
end

local function ShouldShowBlizzardRaidBar()
	if (ns and (ns.IsDevelopment or (ns.db and ns.db.global and ns.db.global.enableDevelopmentMode))
		and ns.db and ns.db.global and ns.db.global.debugForceBlizzardRaidBar) then
		return true
	end
	return ShouldHandleRaidFrames() and GetModuleProfileValue("UnitFrames", "showBlizzardRaidBar", false) and true or false
end

local function ShouldHandleArenaFrames()
	return IsModuleEnabled("ArenaFrames", true)
end

local function ShouldHandleUnitFrames()
	return IsModuleEnabled("UnitFrames", true)
end

local function ShouldHandleCustomUnitFrames()
	return ShouldHandleUnitFrames() and (ShouldHandlePartyFrames()
		or ShouldHandleRaidFrames()
		or ShouldHandleArenaFrames())
end

local function NormalizeBoolean(value)
	if (type(value) == "boolean") then
		return value
	end
	if (type(value) == "number") then
		return value ~= 0
	end
	if (type(value) == "string") then
		local lowered = string.lower(value)
		if (lowered == "1" or lowered == "true") then
			return true
		end
		if (lowered == "0" or lowered == "false") then
			return false
		end
	end
	return nil
end

local function GetQuarantineParent()
	if (ns and ns.Hider) then
		return ns.Hider
	end
	if (quarantineHiddenParent) then
		return quarantineHiddenParent
	end
	quarantineHiddenParent = CreateFrame("Frame", nil, UIParent)
	quarantineHiddenParent:SetAllPoints(UIParent)
	quarantineHiddenParent:Hide()
	return quarantineHiddenParent
end

local function LockToHiddenParent(frame, parent)
	local hiddenParent = GetQuarantineParent()
	if (parent == hiddenParent) then
		return
	end
	if (InCombatLockdown and InCombatLockdown() and frame and frame.IsProtected and frame:IsProtected()) then
		pendingReparentFrames[frame] = true
		return
	end
	if (frame and frame.SetParent) then
		pcall(frame.SetParent, frame, hiddenParent)
	end
end

local function SanitizeCompactAura(aura)
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

	local sanitized = aura
	local copied = false

	local function EnsureCopy()
		if (copied) then
			return
		end
		local ok, copy = pcall(CopyTable, aura)
		if (ok and type(copy) == "table") then
			sanitized = copy
		else
			sanitized = {}
		end
		copied = true
	end

	for key, fallback in pairs(COMPACT_AURA_DEFAULTS) do
		local value = aura[key]
		if (issecretvalue(value)) then
			EnsureCopy()
			if (fallback ~= nil) then
				sanitized[key] = fallback
			else
				sanitized[key] = nil
			end
		end
	end

	return sanitized
end

local function QuarantineSubElements(frame)
	if (not frame) then
		return
	end
	local children = {
		frame.petFrame or frame.PetFrame,
		frame.healthBar or frame.healthbar or frame.HealthBar or (frame.HealthBarsContainer and frame.HealthBarsContainer.healthBar),
		frame.manabar or frame.ManaBar,
		frame.castBar or frame.spellbar or frame.CastingBarFrame,
		frame.powerBarAlt or frame.PowerBarAlt,
		frame.totFrame,
		frame.BuffFrame or frame.AurasFrame,
		frame.CcRemoverFrame,
		frame.DebuffFrame
	}
	for _, child in pairs(children) do
		if (child and child.UnregisterAllEvents) then
			if (InCombatLockdown and InCombatLockdown() and child.IsProtected and child:IsProtected()) then
				-- Protected children are handled by the out-of-combat reapply.
			else
				pcall(child.UnregisterAllEvents, child)
			end
		end
	end
end

local function QuarantineFrame(frameOrName, opts)
	opts = opts or {}
	local frame = frameOrName
	if (type(frameOrName) == "string") then
		frame = _G[frameOrName]
	end
	if (not frame or (frame.IsForbidden and frame:IsForbidden())) then
		return
	end

	local isProtected = frame.IsProtected and frame:IsProtected()
	if (InCombatLockdown and InCombatLockdown() and isProtected) then
		pendingQuarantineFrames[frame] = {
			lockParent = opts.lockParent and true or false,
			skipParent = opts.skipParent and true or false
		}
		return
	end

	if (frame.UnregisterAllEvents) then
		pcall(frame.UnregisterAllEvents, frame)
	end
	QuarantineSubElements(frame)

	if (frame.Hide) then
		pcall(frame.Hide, frame)
	end
	if (frame.HookScript and not frame.__AzUI_W12_HideOnShowHooked) then
		frame.__AzUI_W12_HideOnShowHooked = true
		frame:HookScript("OnShow", function(self)
			if (self and self.Hide) then
				pcall(self.Hide, self)
			end
		end)
	end

	if (not opts.skipParent and frame.SetParent) then
		local hiddenParent = GetQuarantineParent()
		pcall(frame.SetParent, frame, hiddenParent)
		if (opts.lockParent and not parentLockedFrames[frame]) then
			parentLockedFrames[frame] = true
			hooksecurefunc(frame, "SetParent", LockToHiddenParent)
		end
	end
end

local function QuarantinePoolFrames(pool, opts)
	if (not pool or type(pool.EnumerateActive) ~= "function") then
		return
	end
	for frame in pool:EnumerateActive() do
		PrepareCompactFrame(frame)
		QuarantineFrame(frame, opts)
	end
end

local function IsCompactPartyFrameName(name)
	return name == "PartyFrame"
		or name == "CompactPartyFrame"
		or (type(name) == "string" and (string.match(name, "^PartyMemberFrame%d+$")
			or string.match(name, "^CompactPartyFrameMember%d+$")
			or string.match(name, "^CompactPartyFramePet%d+$")))
end

local function IsCompactRaidFrameName(name)
	return name == "CompactRaidFrameContainer"
		or name == "CompactRaidFrameManager"
		or (type(name) == "string" and (string.match(name, "^CompactRaidFrame%d+$")
			or string.match(name, "^CompactRaidGroup%d+Member%d+$")))
end

local function IsCompactArenaFrameName(name)
	return name == "CompactArenaFrame"
		or name == "ArenaEnemyFrames"
		or name == "ArenaEnemyFramesContainer"
		or name == "ArenaEnemyMatchFrames"
		or name == "ArenaEnemyMatchFramesContainer"
		or name == "ArenaPrepFrames"
		or name == "ArenaPrepFramesContainer"
		or (type(name) == "string" and (string.match(name, "^CompactArenaFrameMember%d+$")
			or string.match(name, "^ArenaEnemyMatchFrame%d+$")))
end

local function GetFrameName(frame)
	if (not frame) then
		return nil
	end
	if (frame.GetDebugName) then
		local ok, value = pcall(frame.GetDebugName, frame)
		if (ok and type(value) == "string") then
			return value
		end
	end
	if (frame.GetName) then
		local ok, value = pcall(frame.GetName, frame)
		if (ok and type(value) == "string") then
			return value
		end
	end
	return nil
end

local function ShouldQuarantineCompactFrame(frame)
	local name = GetFrameName(frame)
	if (not name or string.find(name, "NamePlate", 1, true)) then
		name = nil
	end
	if (name == "CompactRaidFrameManager") then
		return false
	end
	-- if (ShouldHandlePartyFrames() and IsCompactPartyFrameName(name)) then
	-- 	return true
	-- end
	if (ShouldHandleRaidFrames() and IsCompactRaidFrameName(name)) then
		return true
	end
	if (ShouldHandleArenaFrames() and IsCompactArenaFrameName(name)) then
		return true
	end
	local unit = frame and (frame.unit or frame.displayedUnit)
	if (type(unit) == "string") then
		if (ShouldHandlePartyFrames()
			and (unit == "player" or string.match(unit, "^party%d+$") or string.match(unit, "^partypet%d+$"))) then
			return true
		end
		if (ShouldHandleRaidFrames()
			and (string.match(unit, "^raid%d+$") or string.match(unit, "^raidpet%d+$") or string.match(unit, "^partypet%d+$"))) then
			return true
		end
		if (ShouldHandleArenaFrames() and string.match(unit, "^arena%d+$")) then
			return true
		end
	end
	return false
end

local function ApplyCompactRaidManagerVisibility()
	local manager = _G.CompactRaidFrameManager
	if (not manager or (manager.IsForbidden and manager:IsForbidden())) then
		return
	end
	if (ShouldShowBlizzardRaidBar()) then
		return
	end

	if (manager.SetAlpha) then
		pcall(manager.SetAlpha, manager, 0)
	end
	if (manager.HookScript and not manager.__AzUI_W12_SuppressOnShowHooked) then
		manager.__AzUI_W12_SuppressOnShowHooked = true
		manager:HookScript("OnShow", function(self)
			if (self.SetAlpha) then
				pcall(self.SetAlpha, self, 0)
			end
		end)
	end
end

local function GetRaidModule(name)
	if (not ns or not ns.GetModule) then
		return nil
	end
	local ok, module = pcall(ns.GetModule, ns, name, true)
	if (ok) then
		return module
	end
	return nil
end

local function GetCompactRaidHiddenMode()
	if (not ShouldShowBlizzardRaidBar()) then
		return false
	end

	local toggle = _G.CompactRaidFrameManagerDisplayFrameHiddenModeToggle
	if (toggle and type(toggle.GetChecked) == "function") then
		local ok, checked = pcall(toggle.GetChecked, toggle)
		checked = ok and NormalizeBoolean(checked) or nil
		if (checked ~= nil) then
			return checked
		end
	end

	local manager = _G.CompactRaidFrameManager
	local displayFrame = manager and (manager.displayFrame or _G.CompactRaidFrameManagerDisplayFrame)
	if (displayFrame) then
		for _, key in ipairs({ "hiddenMode", "isHiddenMode", "hidden" }) do
			local value = NormalizeBoolean(displayFrame[key])
			if (value ~= nil) then
				return value
			end
		end
	end

	local getter = _G.CompactRaidFrameManager_GetSetting or (manager and manager.GetSetting)
	if (type(getter) == "function") then
		for _, key in ipairs({ "HiddenMode", "IsHidden", "hideGroups" }) do
			local ok, value
			if (getter == _G.CompactRaidFrameManager_GetSetting) then
				ok, value = pcall(getter, key)
			else
				ok, value = pcall(getter, manager, key)
			end
			value = ok and NormalizeBoolean(value) or nil
			if (value ~= nil) then
				return value
			end
		end
	end

	return false
end

local function ApplyAzeriteRaidGroupVisibility()
	local alpha = GetCompactRaidHiddenMode() and 0 or 1
	for _, moduleName in ipairs({ "RaidFrame5", "RaidFrame25", "RaidFrame40" }) do
		local module = GetRaidModule(moduleName)
		local frame = module and module.GetFrame and module:GetFrame()
		if (frame and frame.SetAlpha) then
			pcall(frame.SetAlpha, frame, alpha)
		end
	end
end

local function HookRaidManagerHiddenMode()
	local toggle = _G.CompactRaidFrameManagerDisplayFrameHiddenModeToggle
	if (toggle and toggle.HookScript and not toggle.__AzUI_W12_HiddenModeHooked) then
		toggle.__AzUI_W12_HiddenModeHooked = true
		toggle:HookScript("OnClick", function()
			if (C_Timer) then
				C_Timer.After(0, ApplyAzeriteRaidGroupVisibility)
			else
				ApplyAzeriteRaidGroupVisibility()
			end
		end)
	end

	local manager = _G.CompactRaidFrameManager
	if (manager and manager.HookScript and not manager.__AzUI_W12_HiddenModeOnShowHooked) then
		manager.__AzUI_W12_HiddenModeOnShowHooked = true
		manager:HookScript("OnShow", function()
			if (C_Timer) then
				C_Timer.After(0, ApplyAzeriteRaidGroupVisibility)
			else
				ApplyAzeriteRaidGroupVisibility()
			end
		end)
	end

	if (type(_G.CompactRaidFrameManager_SetSetting) == "function" and not _G.__AzUI_W12_HiddenModeSettingHooked) then
		_G.__AzUI_W12_HiddenModeSettingHooked = true
		hooksecurefunc("CompactRaidFrameManager_SetSetting", function(setting)
			local key = type(setting) == "string" and string.lower(setting) or nil
			if (key == "hiddenmode" or key == "ishidden" or key == "hidegroups") then
				if (C_Timer) then
					C_Timer.After(0, ApplyAzeriteRaidGroupVisibility)
				else
					ApplyAzeriteRaidGroupVisibility()
				end
			end
		end)
	end
end

PrepareCompactFrame = function(frame)
	if (not ShouldQuarantineCompactFrame(frame)) then
		return
	end
	-- Intentionally no-op on WoW12:
	-- writing addon-owned state onto Blizzard compact frames taints later secret-value updates.
end

local function GuardUnitAuraApis()
	-- Intentionally no-op on WoW12:
	-- rewriting C_UnitAuras taints Blizzard compact/nameplate code paths.
end

local function GuardPartyFrameGlobals()
	-- Intentionally no-op on WoW12:
	-- rewriting party/statusbar globals taints Edit Mode and hidden Blizzard party frames.
end

local function GuardCompactUnitFrameGlobals()
	if (_G.CompactUnitFrame_UtilShouldDisplayBuff
		and not _G.__AzUI_W12_CUFShouldDisplayBuffWrapped) then
		_G.__AzUI_W12_CUFShouldDisplayBuffWrapped = true
		local original = _G.CompactUnitFrame_UtilShouldDisplayBuff
		_G.CompactUnitFrame_UtilShouldDisplayBuff = function(aura, ...)
			return original(SanitizeCompactAura(aura), ...)
		end
	end

	if (_G.CompactUnitFrame_UtilShouldDisplayDebuff
		and not _G.__AzUI_W12_CUFShouldDisplayDebuffWrapped) then
		_G.__AzUI_W12_CUFShouldDisplayDebuffWrapped = true
		local original = _G.CompactUnitFrame_UtilShouldDisplayDebuff
		_G.CompactUnitFrame_UtilShouldDisplayDebuff = function(aura, ...)
			return original(SanitizeCompactAura(aura), ...)
		end
	end
end

----------------------------------------------------------------
-- Nameplate guard
-- Our tooltip/backdrop styling taints the execution context.
-- When Blizzard nameplate code runs in this tainted context,
-- API calls like SetNamePlateHitTestFrame, C_UnitAuras, and
-- TextStatusBar comparisons fail with secret/forbidden errors.
-- We hook at the top-level entry points to pcall the entire
-- nameplate setup, and guard specific problem functions.
----------------------------------------------------------------
local function GuardNameplateFunctions()
	-- Intentionally no-op on WoW12:
	-- avoid pcall-replacing Blizzard nameplate / EditMode / party globals,
	-- because that makes AzeriteUI the caller and taint cascades outward.
end

local function GuardAuraUtilForEachAura()
	-- Intentionally no-op on WoW12:
	-- keep AuraUtil.ForEachAura caller identity untouched and sanitize
	-- downstream aura consumers instead.
end

local function GuardAuraUtilUnpack()
	if (not AuraUtil or type(AuraUtil.UnpackAuraData) ~= "function"
		or _G.__AzUI_W12_AuraUtilUnpackWrapped) then
		return
	end

	_G.__AzUI_W12_AuraUtilUnpackWrapped = true
	local original = AuraUtil.UnpackAuraData

	AuraUtil.UnpackAuraData = function(auraData, ...)
		if (auraData ~= nil) then
			if (type(auraData) ~= "table") then
				return nil
			end
			if (issecretvalue and issecretvalue(auraData)) then
				return nil
			end
			if (canaccesstable and not canaccesstable(auraData)) then
				return nil
			end
			if (issecretvalue and issecretvalue(auraData.points)) then
				local okCopy, copy = pcall(CopyTable, auraData)
				if (okCopy and type(copy) == "table") then
					auraData = copy
					auraData.points = nil
				else
					return nil
				end
			end
		end

		local results = Pack(pcall(original, auraData, ...))
		if (results[1]) then
			return unpack(results, 2, results.n or #results)
		end
		return nil
	end
end

local function IsSecretWidgetTooltipError(err)
	if (type(err) ~= "string") then
		return false
	end
	local lowered = string.lower(err)
	if (not string.find(lowered, "secret", 1, true)) then
		return false
	end
	return string.find(lowered, "blizzard_uiwidget", 1, true)
		or string.find(lowered, "uiwidgettemplatetextwithstate", 1, true)
		or string.find(lowered, "uiwidgettemplatebase", 1, true)
		or string.find(lowered, "uiwidgettemplateitemdisplay", 1, true)
		or string.find(lowered, "uiwidgetmanager", 1, true)
		or string.find(lowered, "sharedtooltiptemplates", 1, true)
		or string.find(lowered, "frameutil", 1, true)
		or string.find(lowered, "vignettedataprovider", 1, true)
end

-- Clear widget-related state fields on an object to prevent further tainted updates.
local function SilenceWidgetObject(obj)
	if (not obj) then
		return
	end
	if (obj.waitingForData ~= nil) then obj.waitingForData = false end
	if (obj.updateTooltipTimer ~= nil) then obj.updateTooltipTimer = 0 end
	if (obj.processingInfo ~= nil) then obj.processingInfo = nil end
	if (obj.infoList ~= nil) then obj.infoList = nil end
	if (obj.supportsDataRefresh ~= nil) then obj.supportsDataRefresh = false end
	if (obj.disableTooltip ~= nil) then obj.disableTooltip = true end
	if (obj.tooltipEnabled ~= nil) then obj.tooltipEnabled = false end
	if (obj.Hide) then pcall(obj.Hide, obj) end
end

local function HideSecretWidgetTarget(target)
	if (not target) then
		return false
	end
	SilenceWidgetObject(target)
	if (target.Tooltip) then
		SilenceWidgetObject(target.Tooltip)
	end
	if (target.widgetContainer) then
		if (target.widgetContainer.disableWidgetTooltips ~= nil) then
			target.widgetContainer.disableWidgetTooltips = true
		end
		if (target.widgetContainer.Hide) then
			pcall(target.widgetContainer.Hide, target.widgetContainer)
		end
	end
	return true
end

local function HideSecretWidgetTargets(...)
	local hidden = false
	for i = 1, select("#", ...) do
		local value = select(i, ...)
		local valueType = type(value)
		if (valueType == "table" or valueType == "userdata") then
			if (value.Tooltip or value.widgetContainer or value.widgetFrames or value.widgetType) then
				hidden = HideSecretWidgetTarget(value) or hidden
			end
		end
	end
	return hidden
end

local function HandleSecretWidgetError(err, ...)
	if (not IsSecretWidgetTooltipError(err)) then
		error(err, 0)
	end
	HideSecretWidgetTargets(...)
	return nil
end

-- Generic mixin method guard: wraps mixin[method] with pcall + secret-error recovery.
local function GuardWidgetMixinMethod(mixinName, method, flagName)
	local mixin = _G[mixinName]
	if (type(mixin) ~= "table" or type(mixin[method]) ~= "function" or _G[flagName]) then
		return
	end
	_G[flagName] = true
	local original = mixin[method]
	mixin[method] = function(...)
		local results = Pack(pcall(original, ...))
		if (results[1]) then
			return unpack(results, 2, results.n or #results)
		end
		return HandleSecretWidgetError(results[2], ...)
	end
end

----------------------------------------------------------------
-- Tooltip geometry guard
-- Our tooltip styling (SetScale, SetPoint, SetBackdrop) taints
-- the frame, causing all geometry methods to return secret
-- values. Instead of wrapping every Blizzard consumer, we hook
-- the geometry methods themselves on tooltip frames so they
-- always return clean (non-secret) values. When the real value
-- is tainted we return the last known good cached value.
-- This covers: GetWidth, GetHeight, GetSize, GetLeft, GetRight,
-- GetTop, GetBottom, GetCenter, GetRect, GetScale.
----------------------------------------------------------------
local tooltipGeometryCache = setmetatable({}, { __mode = "k" })

local function GetGeometryCache(tooltip)
	local cache = tooltipGeometryCache[tooltip]
	if (not cache) then
		cache = {}
		tooltipGeometryCache[tooltip] = cache
	end
	return cache
end

local function IsCleanValue(value)
	return type(value) == "number" and (not issecretvalue or not issecretvalue(value))
end

-- Generic single-value guard: wraps a method that returns one number.
local function MakeSafeSingleGetter(originalFn, cacheKey, fallback)
	return function(self)
		local ok, value = pcall(originalFn, self)
		local cache = GetGeometryCache(self)
		if (ok and IsCleanValue(value)) then
			cache[cacheKey] = value
			return value
		end
		local cached = cache[cacheKey]
		if (cached ~= nil) then
			return cached
		end
		return fallback
	end
end

local function GuardTooltipFrameGeometry(tooltip)
	if (not tooltip or tooltip.__AzUI_W12_GeometryGuarded) then
		return
	end
	tooltip.__AzUI_W12_GeometryGuarded = true

	-- Single-value getters
	local singleGetters = {
		{ method = "GetWidth",  key = "width",  fallback = 0 },
		{ method = "GetHeight", key = "height", fallback = 0 },
		{ method = "GetLeft",   key = "left",   fallback = nil },
		{ method = "GetRight",  key = "right",  fallback = nil },
		{ method = "GetTop",    key = "top",    fallback = nil },
		{ method = "GetBottom", key = "bottom",  fallback = nil },
		{ method = "GetScale",  key = "scale",  fallback = 1 },
	}

	for _, info in ipairs(singleGetters) do
		local original = tooltip[info.method]
		if (type(original) == "function") then
			tooltip[info.method] = MakeSafeSingleGetter(original, info.key, info.fallback)
		end
	end

	-- GetSize -> (width, height)
	local origGetSize = tooltip.GetSize
	local origGetWidth = tooltip.GetWidth
	local origGetHeight = tooltip.GetHeight
	if (type(origGetSize) == "function") then
		tooltip.GetSize = function(self)
			return origGetWidth(self), origGetHeight(self)
		end
	end

	-- GetCenter -> (x, y)
	local origGetCenter = tooltip.GetCenter
	if (type(origGetCenter) == "function") then
		tooltip.GetCenter = function(self)
			local ok, x, y = pcall(origGetCenter, self)
			local cache = GetGeometryCache(self)
			if (ok and IsCleanValue(x) and IsCleanValue(y)) then
				cache.centerX = x
				cache.centerY = y
				return x, y
			end
			return cache.centerX or 0, cache.centerY or 0
		end
	end

	-- GetRect -> (left, bottom, width, height)
	local origGetRect = tooltip.GetRect
	if (type(origGetRect) == "function") then
		tooltip.GetRect = function(self)
			local ok, l, b, w, h = pcall(origGetRect, self)
			local cache = GetGeometryCache(self)
			if (ok and IsCleanValue(l) and IsCleanValue(b) and IsCleanValue(w) and IsCleanValue(h)) then
				cache.left = l
				cache.bottom = b
				cache.width = w
				cache.height = h
				return l, b, w, h
			end
			return cache.left or 0, cache.bottom or 0, cache.width or 0, cache.height or 0
		end
	end
end

local function GuardTooltipDimensions()
	-- Guard the primary tooltips that our addon styles
	local tooltips = {
		_G.GameTooltip,
		_G.ItemRefTooltip,
		_G.ItemRefShoppingTooltip1,
		_G.ItemRefShoppingTooltip2,
		_G.EmbeddedItemTooltip,
		_G.ShoppingTooltip1,
		_G.ShoppingTooltip2,
		_G.GameNoHeaderTooltip,
		_G.GameSmallHeaderTooltip,
	}

	for _, tooltip in ipairs(tooltips) do
		if (tooltip and (not tooltip.IsForbidden or not tooltip:IsForbidden())) then
			GuardTooltipFrameGeometry(tooltip)
		end
	end

	-- Guard embedded widget tooltips (UIWidgetBaseItemEmbeddedTooltip1, etc.)
	-- These are created dynamically by UIWidgetTemplateItemDisplay and can
	-- inherit taint from the parent tooltip when doing arithmetic on dimensions.
	for i = 1, 10 do
		local embedded = _G["UIWidgetBaseItemEmbeddedTooltip" .. i]
		if (embedded and (not embedded.IsForbidden or not embedded:IsForbidden())) then
			GuardTooltipFrameGeometry(embedded)
		end
	end

end

-- Specialized guard for UIWidgetTemplateItemDisplayMixin.Setup:
-- The embedded tooltip (self.Item.Tooltip) is created dynamically and may
-- not exist when GuardTooltipDimensions() first runs. We guard its geometry
-- just-in-time before calling the original Setup so that GetWidth/GetHeight
-- never return secret values during the base Setup's dimension arithmetic.
local function GuardItemDisplaySetup()
	local mixin = _G["UIWidgetTemplateItemDisplayMixin"]
	if (type(mixin) ~= "table" or type(mixin.Setup) ~= "function"
		or _G.__AzUI_W12_UIWidgetItemDisplaySetupWrapped) then
		return
	end
	_G.__AzUI_W12_UIWidgetItemDisplaySetupWrapped = true
	local original = mixin.Setup
	-- Guard SetWidth/SetHeight on a widget frame so tainted values
	-- from the base Setup's return don't error inside Blizzard's
	-- ContinuableContainer xpcall (which reports to BugSack before
	-- our outer pcall can catch it).
	local function GuardWidgetFrameSetters(frame)
		if (not frame or frame.__AzUI_W12_SettersGuarded) then
			return
		end
		frame.__AzUI_W12_SettersGuarded = true
		local origSetWidth = frame.SetWidth
		if (type(origSetWidth) == "function") then
			frame.SetWidth = function(self, w, ...)
				if (issecretvalue and issecretvalue(w)) then return end
				return origSetWidth(self, w, ...)
			end
		end
		local origSetHeight = frame.SetHeight
		if (type(origSetHeight) == "function") then
			frame.SetHeight = function(self, h, ...)
				if (issecretvalue and issecretvalue(h)) then return end
				return origSetHeight(self, h, ...)
			end
		end
		local origSetSize = frame.SetSize
		if (type(origSetSize) == "function") then
			frame.SetSize = function(self, w, h, ...)
				if (issecretvalue and (issecretvalue(w) or issecretvalue(h))) then return end
				return origSetSize(self, w, h, ...)
			end
		end
	end

	mixin.Setup = function(self, ...)
		-- Guard the embedded tooltip before Setup does arithmetic on its dimensions
		if (self and type(self) == "table") then
			-- Guard the widget frame's setters against tainted dimensions
			GuardWidgetFrameSetters(self)
			GuardTooltipFrameGeometry(self)
			if (self.widgetContainer and type(self.widgetContainer) == "table") then
				GuardTooltipFrameGeometry(self.widgetContainer)
			end
			local tooltip = self.Tooltip
			if (not tooltip) then
				local item = self.Item
				if (item and type(item) == "table") then
					tooltip = item.Tooltip
				end
			end
			if (tooltip and not tooltip.__AzUI_W12_GeometryGuarded
				and (not tooltip.IsForbidden or not tooltip:IsForbidden())) then
				GuardTooltipFrameGeometry(tooltip)
			end
		end
		local results = Pack(pcall(original, self, ...))
		if (results[1]) then
			return unpack(results, 2, results.n or #results)
		end
		return HandleSecretWidgetError(results[2], self, ...)
	end
end

local function GuardWidgetSetups()
	GuardWidgetMixinMethod("UIWidgetTemplateTextWithStateMixin", "Setup",
		"__AzUI_W12_UIWidgetTextWithStateSetupWrapped")
	GuardItemDisplaySetup()
	GuardWidgetMixinMethod("UIWidgetManagerMixin", "RegisterForWidgetSet",
		"__AzUI_W12_UIWidgetManagerRegisterWrapped")
end

----------------------------------------------------------------
-- Backdrop SetupTextureCoordinates guard
-- WoW 12 secret values break BackdropTemplateMixin.SetupTextureCoordinates
-- when frame dimensions are tainted. Both ElvUI and GW2_UI replace
-- this method to skip when GetSize returns secret values.
-- We do the same: check dimensions before calling the original.
----------------------------------------------------------------
local function GuardBackdropSetupTextureCoordinates()
	if (not _G.BackdropTemplateMixin
		or type(_G.BackdropTemplateMixin.SetupTextureCoordinates) ~= "function"
		or _G.__AzUI_W12_BackdropSetupTexCoordsWrapped) then
		return
	end
	_G.__AzUI_W12_BackdropSetupTexCoordsWrapped = true
	local original = _G.BackdropTemplateMixin.SetupTextureCoordinates
	_G.BackdropTemplateMixin.SetupTextureCoordinates = function(self, ...)
		if (self and self.GetSize) then
			local width, height = self:GetSize()
			if (issecretvalue and (issecretvalue(width) or issecretvalue(height))) then
				return
			end
		end
		return original(self, ...)
	end
end

local function GuardTooltipWidgetSets()
	if (type(_G.GameTooltip_AddWidgetSet) ~= "function"
		or _G.__AzUI_W12_GameTooltipAddWidgetSetWrapped) then
		return
	end

	_G.__AzUI_W12_GameTooltipAddWidgetSetWrapped = true
	local original = _G.GameTooltip_AddWidgetSet

	_G.GameTooltip_AddWidgetSet = function(...)
		local results = Pack(pcall(original, ...))
		if (results[1]) then
			return unpack(results, 2, results.n or #results)
		end

		local err = results[2]
		local tooltip = select(1, ...)
		if (tooltip) then
			HideSecretWidgetTarget(tooltip)
		end
		return HandleSecretWidgetError(err, ...)
	end
end

local function GuardTooltipInsertedFrames()
	if (type(_G.GameTooltip_InsertFrame) ~= "function"
		or _G.__AzUI_W12_GameTooltipInsertFrameWrapped) then
		return
	end

	_G.__AzUI_W12_GameTooltipInsertFrameWrapped = true
	local original = _G.GameTooltip_InsertFrame

	_G.GameTooltip_InsertFrame = function(tooltipFrame, frame, ...)
		if (tooltipFrame and (not tooltipFrame.IsForbidden or not tooltipFrame:IsForbidden())) then
			GuardTooltipFrameGeometry(tooltipFrame)
		end
		if (frame and type(frame) == "table") then
			if (not frame.IsForbidden or not frame:IsForbidden()) then
				GuardTooltipFrameGeometry(frame)
			end
			local bar = frame.Bar or frame.StatusBar
			if (bar and type(bar) == "table"
				and (not bar.IsForbidden or not bar:IsForbidden())) then
				GuardTooltipFrameGeometry(bar)
			end
		end
		return original(tooltipFrame, frame, ...)
	end
end

local function IsSecretTooltipMoneyError(err)
	if (type(err) ~= "string") then
		return false
	end
	local lowered = string.lower(err)
	if (not string.find(lowered, "secret", 1, true)) then
		return false
	end
	return string.find(lowered, "moneyframe", 1, true)
		or string.find(lowered, "settooltipmoney", 1, true)
		or string.find(lowered, "tooltipaddmoney", 1, true)
end

-- Guard a money frame and its Gold/Silver/Copper button children
-- so that layout arithmetic on GetWidth/GetHeight returns clean values.
local function GuardMoneyFrameGeometry(frame)
	if (not frame or frame.__AzUI_W12_GeometryGuarded) then
		return
	end
	GuardTooltipFrameGeometry(frame)
	local frameName = frame.GetName and frame:GetName()
	if (type(frameName) == "string") then
		for _, suffix in next, { "GoldButton", "SilverButton", "CopperButton" } do
			local button = _G[frameName .. suffix]
			if (button and not button.__AzUI_W12_GeometryGuarded) then
				GuardTooltipFrameGeometry(button)
			end
		end
	end
end

local function IsTooltipOwnedMoneyFrame(frame)
	if (not frame) then
		return false
	end
	local name = frame.GetName and frame:GetName()
	if (type(name) == "string") then
		if (string.find(name, "GameTooltipMoneyFrame", 1, true)
			or string.find(name, "EmbeddedItemTooltipMoneyFrame", 1, true)
			or string.find(name, "ItemRefTooltipMoneyFrame", 1, true)
			or string.find(name, "ShoppingTooltip%d*MoneyFrame", 1)) then
			return true
		end
	end
	local parent = frame.GetParent and frame:GetParent()
	if (parent) then
		local parentName = parent.GetName and parent:GetName()
		if (type(parentName) == "string") then
			if (string.find(parentName, "GameTooltip", 1, true)
				or string.find(parentName, "EmbeddedItemTooltip", 1, true)
				or string.find(parentName, "ItemRefTooltip", 1, true)
				or string.find(parentName, "ShoppingTooltip", 1, true)) then
				return true
			end
		end
		if (parent.TooltipMoneyFrame == frame) then
			return true
		end
	end
	return false
end

local function HideTooltipMoneyFrames(tooltip)
	if (not tooltip) then
		return
	end
	local moneyFrame = tooltip.TooltipMoneyFrame
	if (moneyFrame and moneyFrame.Hide) then
		pcall(moneyFrame.Hide, moneyFrame)
	end
	local tooltipName = tooltip.GetName and tooltip:GetName()
	local numMoneyFrames = tooltip.numMoneyFrames
	if (type(numMoneyFrames) == "number" and numMoneyFrames > 0 and type(tooltipName) == "string") then
		for i = 1, numMoneyFrames do
			local frame = _G[tooltipName .. "MoneyFrame" .. i]
			if (frame and frame.Hide) then
				pcall(frame.Hide, frame)
			end
		end
	end
	if (tooltip.shownMoneyFrames ~= nil) then
		tooltip.shownMoneyFrames = 0
	end
	if (tooltip.numMoneyFrames ~= nil) then
		tooltip.numMoneyFrames = 0
	end
	if (tooltip.hasMoney ~= nil) then
		tooltip.hasMoney = nil
	end
end

local function GuardTooltipMoneyAdders()

	-- Guard existing tooltip money frames and their button children.
	-- These inherit taint from the parent tooltip and their GetWidth/GetHeight
	-- values are used in layout arithmetic inside SetTooltipMoney.
	for _, tooltipName in next, {
		"GameTooltip", "ItemRefTooltip", "EmbeddedItemTooltip",
		"ShoppingTooltip1", "ShoppingTooltip2",
	} do
		for i = 1, 5 do
			local mf = _G[tooltipName .. "MoneyFrame" .. i]
			if (mf) then
				GuardMoneyFrameGeometry(mf)
			end
		end
	end

	local function WrapTooltipMoneyAdder(globalName, flagName)
		local original = _G[globalName]
		if (type(original) ~= "function" or _G[flagName]) then
			return
		end
		_G[flagName] = true
		_G[globalName] = function(...)
			local results = Pack(pcall(original, ...))
			if (results[1]) then
				return unpack(results, 2, results.n or #results)
			end
			if (not IsSecretTooltipMoneyError(results[2])) then
				error(results[2], 0)
			end
			HideTooltipMoneyFrames(select(1, ...))
			return nil
		end
	end

	WrapTooltipMoneyAdder("GameTooltip_OnTooltipAddMoney", "__AzUI_W12_GameTooltipOnTooltipAddMoneyWrapped")
	WrapTooltipMoneyAdder("EmbeddedItemTooltip_OnTooltipAddMoney", "__AzUI_W12_EmbeddedItemTooltipOnTooltipAddMoneyWrapped")

	if (type(_G.MoneyFrame_Update) == "function" and not _G.__AzUI_W12_MoneyFrameUpdateTooltipWrapped) then
		_G.__AzUI_W12_MoneyFrameUpdateTooltipWrapped = true
		local original = _G.MoneyFrame_Update
		_G.MoneyFrame_Update = function(frame, money, ...)
			if (not IsTooltipOwnedMoneyFrame(frame)) then
				return original(frame, money, ...)
			end
			if (issecretvalue and (issecretvalue(money) or issecretvalue(frame))) then
				HideTooltipMoneyFrames(frame and frame.GetParent and frame:GetParent() or nil)
				if (frame and frame.Hide) then
					pcall(frame.Hide, frame)
				end
				return
			end
			-- Guard the money frame and its button children so layout
			-- arithmetic on GetWidth/GetHeight doesn't hit secret values.
			GuardMoneyFrameGeometry(frame)
			local results = Pack(pcall(original, frame, money, ...))
			if (results[1]) then
				return unpack(results, 2, results.n or #results)
			end
			if (not IsSecretTooltipMoneyError(results[2])) then
				error(results[2], 0)
			end
			HideTooltipMoneyFrames(frame and frame.GetParent and frame:GetParent() or nil)
			if (frame and frame.Hide) then
				pcall(frame.Hide, frame)
			end
			return nil
		end
	end

	-- Also wrap SetTooltipMoney — its internal layout path does arithmetic
	-- on button GetWidth/GetHeight which can be tainted, and this path
	-- does not go through MoneyFrame_Update.
	if (type(_G.SetTooltipMoney) == "function" and not _G.__AzUI_W12_SetTooltipMoneyWrapped) then
		_G.__AzUI_W12_SetTooltipMoneyWrapped = true
		local origSetTooltipMoney = _G.SetTooltipMoney
		_G.SetTooltipMoney = function(tooltip, money, ...)
			-- Guard any existing money frames before the layout runs
			if (tooltip) then
				local tooltipName = tooltip.GetName and tooltip:GetName()
				if (type(tooltipName) == "string") then
					local numMoney = tooltip.numMoneyFrames
					if (type(numMoney) == "number") then
						for i = 1, numMoney do
							local mf = _G[tooltipName .. "MoneyFrame" .. i]
							if (mf) then
								GuardMoneyFrameGeometry(mf)
							end
						end
					end
				end
			end
			if (issecretvalue and issecretvalue(money)) then
				return
			end
			local results = Pack(pcall(origSetTooltipMoney, tooltip, money, ...))
			if (results[1]) then
				-- Guard any newly created money frames after the call
				if (tooltip) then
					local tooltipName = tooltip.GetName and tooltip:GetName()
					if (type(tooltipName) == "string") then
						local numMoney = tooltip.numMoneyFrames
						if (type(numMoney) == "number") then
							for i = 1, numMoney do
								local mf = _G[tooltipName .. "MoneyFrame" .. i]
								if (mf) then
									GuardMoneyFrameGeometry(mf)
								end
							end
						end
					end
				end
				return unpack(results, 2, results.n or #results)
			end
			if (not IsSecretTooltipMoneyError(results[2])) then
				error(results[2], 0)
			end
			HideTooltipMoneyFrames(tooltip)
			return nil
		end
	end
end

local function QuarantineCompactFrames()
	if (not ShouldHandleCustomUnitFrames()) then
		return
	end

	if (ShouldHandlePartyFrames()) then
		PrepareCompactFrame(_G.PartyFrame)
		QuarantineFrame("PartyFrame", { lockParent = true })
		if (_G.PartyFrame and _G.PartyFrame.PartyMemberFramePool) then
			QuarantinePoolFrames(_G.PartyFrame.PartyMemberFramePool, { lockParent = true })
		end
		PrepareCompactFrame(_G.CompactPartyFrame)
		QuarantineFrame("CompactPartyFrame", { lockParent = true })
		for i = 1, MAX_PARTY_MEMBERS do
			local partyFrame = _G["PartyMemberFrame" .. i]
			local compactPartyFrame = _G["CompactPartyFrameMember" .. i]
			local compactPartyPetFrame = _G["CompactPartyFramePet" .. i]
			PrepareCompactFrame(partyFrame)
			PrepareCompactFrame(compactPartyFrame)
			PrepareCompactFrame(compactPartyPetFrame)
			QuarantineFrame(partyFrame)
			QuarantineFrame(compactPartyFrame)
			QuarantineFrame(compactPartyPetFrame)
		end
	end

	if (ShouldHandleRaidFrames()) then
		PrepareCompactFrame(_G.CompactRaidFrameContainer)
		QuarantineFrame("CompactRaidFrameContainer", { lockParent = true })
		ApplyCompactRaidManagerVisibility()
		for i = 1, MAX_RAID_MEMBERS do
			local raidFrame = _G["CompactRaidFrame" .. i]
			PrepareCompactFrame(raidFrame)
			QuarantineFrame(raidFrame)
		end
	end

	if (ShouldHandleArenaFrames()) then
		PrepareCompactFrame(_G.CompactArenaFrame)
		QuarantineFrame("CompactArenaFrame", { lockParent = true })
		if (_G.CompactArenaFrame and type(_G.CompactArenaFrame.memberUnitFrames) == "table") then
			for _, arenaFrame in pairs(_G.CompactArenaFrame.memberUnitFrames) do
				PrepareCompactFrame(arenaFrame)
				QuarantineFrame(arenaFrame, { lockParent = true })
			end
		end
		for i = 1, MAX_ARENA_MEMBERS do
			local arenaFrame = _G["CompactArenaFrameMember" .. i]
			local arenaMatchFrame = _G["ArenaEnemyMatchFrame" .. i]
			PrepareCompactFrame(arenaFrame)
			PrepareCompactFrame(arenaMatchFrame)
			QuarantineFrame(arenaFrame)
			QuarantineFrame(arenaMatchFrame)
		end
		QuarantineFrame("ArenaEnemyFrames", { lockParent = true })
		QuarantineFrame("ArenaEnemyFramesContainer", { lockParent = true })
		QuarantineFrame("ArenaEnemyMatchFrames", { lockParent = true })
		QuarantineFrame("ArenaEnemyMatchFramesContainer", { lockParent = true })
		QuarantineFrame("ArenaPrepFrames", { lockParent = true })
		QuarantineFrame("ArenaPrepFramesContainer", { lockParent = true })
	end
end

local function QuarantineSpellBars()
	if (not ShouldHandleCustomUnitFrames()) then
		return
	end
	QuarantineFrame("TargetFrameSpellBar", { skipParent = true })
	QuarantineFrame("FocusFrameSpellBar", { skipParent = true })
	for i = 1, MAX_BOSS_FRAMES do
		QuarantineFrame("Boss" .. i .. "TargetFrameSpellBar", { skipParent = true })
	end
end

local function HookCompactFrameLifecycle()
	if (_G.CompactUnitFrame_SetUpFrame and not _G.__AzUI_W12_CUF_SetUpFrameHooked) then
		_G.__AzUI_W12_CUF_SetUpFrameHooked = true
		hooksecurefunc("CompactUnitFrame_SetUpFrame", function(frame)
			PrepareCompactFrame(frame)
			if (ShouldQuarantineCompactFrame(frame)) then
				QuarantineFrame(frame)
			end
		end)
	end

	if (_G.CompactUnitFrame_SetUnit and not _G.__AzUI_W12_CUF_SetUnitHooked) then
		_G.__AzUI_W12_CUF_SetUnitHooked = true
		hooksecurefunc("CompactUnitFrame_SetUnit", function(frame)
			PrepareCompactFrame(frame)
			if (ShouldQuarantineCompactFrame(frame)) then
				QuarantineFrame(frame)
			end
		end)
	end

	if (_G.CompactRaidGroup_InitializeForGroup and not _G.__AzUI_W12_CUF_GroupInitHooked) then
		_G.__AzUI_W12_CUF_GroupInitHooked = true
		hooksecurefunc("CompactRaidGroup_InitializeForGroup", function(frame)
			PrepareCompactFrame(frame)
			if (ShouldQuarantineCompactFrame(frame)) then
				QuarantineFrame(frame, { lockParent = true })
			end
		end)
	end

	if (_G.PartyFrame_UpdatePartyFrames and not _G.__AzUI_W12_PartyFrameUpdateHooked) then
		_G.__AzUI_W12_PartyFrameUpdateHooked = true
		hooksecurefunc("PartyFrame_UpdatePartyFrames", function()
			QuarantineCompactFrames()
		end)
	end
end

local function FlushPendingQuarantineFrames()
	if (InCombatLockdown and InCombatLockdown()) then
		return
	end

	for frame, opts in pairs(pendingQuarantineFrames) do
		pendingQuarantineFrames[frame] = nil
		QuarantineFrame(frame, opts)
	end
	for frame in pairs(pendingReparentFrames) do
		pendingReparentFrames[frame] = nil
		if (frame and frame.SetParent) then
			pcall(frame.SetParent, frame, GetQuarantineParent())
		end
	end
end

local function ApplyBlizzardFrameQuarantine()
	QuarantineCompactFrames()
	QuarantineSpellBars()
end

ns.WoW12BlizzardQuarantine = ns.WoW12BlizzardQuarantine or {}
ns.WoW12BlizzardQuarantine.Apply = ApplyBlizzardFrameQuarantine
ns.WoW12BlizzardQuarantine.ApplyCompactFrames = QuarantineCompactFrames
ns.WoW12BlizzardQuarantine.ApplyRaidGroupVisibility = ApplyAzeriteRaidGroupVisibility
ns.WoW12BlizzardQuarantine.ApplySpellBars = QuarantineSpellBars
ns.WoW12BlizzardQuarantine.QuarantineFrame = QuarantineFrame

local function ApplyGuards()
	ApplyCastingBarGuards()
	GuardUnitAuraApis()
	GuardPartyFrameGlobals()
	GuardCompactUnitFrameGlobals()
	GuardAuraUtilUnpack()
	GuardWidgetSetups()
	GuardBackdropSetupTextureCoordinates()
	GuardTooltipDimensions()
	GuardTooltipWidgetSets()
	GuardTooltipInsertedFrames()
	GuardTooltipMoneyAdders()
	ApplyBlizzardFrameQuarantine()
	HookRaidManagerHiddenMode()
	ApplyAzeriteRaidGroupVisibility()
	HookCompactFrameLifecycle()
end

ApplyGuards()

local guardFrame = CreateFrame("Frame")
guardFrame:RegisterEvent("ADDON_LOADED")
guardFrame:RegisterEvent("PLAYER_LOGIN")
guardFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
guardFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
guardFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
guardFrame:SetScript("OnEvent", function(self, event, addonName)
	if (event == "ADDON_LOADED") then
		if (addonName == "Blizzard_UIPanels_Game"
			or addonName == "Blizzard_UnitFrame"
			or addonName == "Blizzard_CompactRaidFrames"
			or addonName == "Blizzard_CUFProfiles"
			or addonName == "Blizzard_ArenaUI"
			or addonName == "Blizzard_EditMode"
			or addonName == "Blizzard_GameTooltip"
			or addonName == "Blizzard_MoneyFrame"
			or addonName == "Blizzard_UIWidgets"
			or addonName == "Blizzard_NamePlates"
			or addonName == "Blizzard_TextStatusBar"
			or addonName == "Blizzard_FrameXMLUtil"
			or addonName == "Blizzard_PersonalResourceDisplay"
			or addonName == "Blizzard_EncounterWarnings"
			or addonName == "Blizzard_RaidFrame"
			or addonName == "Blizzard_DamageMeter"
			or addonName == "Blizzard_ActionBar") then
			ApplyGuards()
			if (C_Timer) then
				C_Timer.After(0, ApplyGuards)
				C_Timer.After(1, ApplyGuards)
			end
		end
	elseif (event == "PLAYER_LOGIN") then
		ApplyGuards()
		self:UnregisterEvent("PLAYER_LOGIN")
	elseif (event == "PLAYER_ENTERING_WORLD" or event == "GROUP_ROSTER_UPDATE") then
		ApplyGuards()
	elseif (event == "PLAYER_REGEN_ENABLED") then
		FlushPendingQuarantineFrames()
		ApplyGuards()
	end
end)

if (C_Timer) then
	C_Timer.After(0, ApplyGuards)
	C_Timer.After(1, ApplyGuards)
	C_Timer.After(3, ApplyGuards)
end

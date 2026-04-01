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

-- GLOBALS: ChannelFrame

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

-- Minimal Show/Hide logic for Blizzard raid bar
local pendingRaidBarVisible = nil

local function SetBlizzardRaidBarVisible(visible)
	local manager = _G.CompactRaidFrameManager
	if (not manager or not manager.SetParent or not manager.Show or not manager.Hide or not manager.SetAlpha) then
		return
	end
	if (InCombatLockdown and InCombatLockdown()) then
		pendingRaidBarVisible = visible
		return
	end
	pendingRaidBarVisible = nil
	pcall(manager.SetParent, manager, UIParent)
	if visible then
		pcall(manager.Show, manager)
		pcall(manager.SetAlpha, manager, 1)
	else
		pcall(manager.Hide, manager)
	end
end

local function ShouldShowBlizzardRaidBar()
	-- Read toggle from UnitFrames module profile (matches what the options UI writes)
	local enabled = nil
	if ns.GetModuleProfileValue then
		enabled = ns.GetModuleProfileValue("UnitFrames", "showBlizzardRaidBar", nil)
	end
	if (enabled == nil) and ns.GetModule then
		local ok, unitFrames = pcall(ns.GetModule, ns, "UnitFrames", true)
		if ok and unitFrames and unitFrames.db and unitFrames.db.profile then
			enabled = unitFrames.db.profile.showBlizzardRaidBar
		end
	end
	-- Only show when toggle is on AND in a party or raid (stock behavior)
	if (not enabled) then
		return false
	end
	return (IsInGroup() or IsInRaid()) and true or false
end

-- Export for options UI
ns.WoW12BlizzardQuarantine = ns.WoW12BlizzardQuarantine or {}
ns.WoW12BlizzardQuarantine.SetBlizzardRaidBarVisible = SetBlizzardRaidBarVisible
ns.WoW12BlizzardQuarantine.ShouldShowBlizzardRaidBar = ShouldShowBlizzardRaidBar

local MAX_PARTY_MEMBERS = _G.MEMBERS_PER_RAID_GROUP or 5
local MAX_RAID_MEMBERS = _G.MAX_RAID_MEMBERS or 40
local MAX_BOSS_FRAMES = _G.MAX_BOSS_FRAMES or 8
local MAX_ARENA_MEMBERS = _G.MAX_ARENA_ENEMIES or 5

local quarantineHiddenParent
local parentLockedFrames = {}
local pendingQuarantineFrames = {}
local pendingReparentFrames = {}
-- Side table: tracks quarantine hook state without writing to Blizzard frames (avoids WoW 12 taint).
local quarantineHooked = setmetatable({}, { __mode = "k" })
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
	{ "PlayFadeAnim",     MakeSafeVoidMethod },
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

local function ShouldHandlePartyFrames()
	return IsModuleEnabled("PartyFrames", true)
end

local function ShouldHandleRaidFrames()
	return IsModuleEnabled("RaidFrame5", true)
		or IsModuleEnabled("RaidFrame25", true)
		or IsModuleEnabled("RaidFrame40", true)
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
	if (frame.HookScript and not quarantineHooked[frame]) then
		quarantineHooked[frame] = true
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
	if (toggle and toggle.HookScript and not quarantineHooked[toggle]) then
		quarantineHooked[toggle] = true
		toggle:HookScript("OnClick", function()
			if (C_Timer) then
				C_Timer.After(0, ApplyAzeriteRaidGroupVisibility)
			else
				ApplyAzeriteRaidGroupVisibility()
			end
		end)
	end

	local manager = _G.CompactRaidFrameManager
	if (manager and manager.HookScript and not quarantineHooked[manager]) then
		quarantineHooked[manager] = true
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
	-- Intentionally no-op on WoW12:
	-- replacing global CompactUnitFrame_UtilShouldDisplay* with addon wrappers
	-- taints the execution context for all callers, including secure paths
	-- that lead to protected functions like UpgradeItem().
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
	-- Intentionally no-op on WoW12:
	-- replacing AuraUtil.UnpackAuraData with an addon wrapper taints all
	-- callers, including secure paths that lead to protected functions.
end

----------------------------------------------------------------
-- Tooltip geometry cache (passive, non-tainting)
-- Instead of replacing methods on Blizzard tooltip frames (which
-- taints the execution context and blocks protected calls like
-- UpgradeItem), we use hooksecurefunc to passively cache clean
-- geometry values in a side table. Our addon code reads from
-- the cache via ns.GetSafeGeometry(); Blizzard code is never
-- touched and remains in a secure execution context.
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

-- Hook a single-value getter to passively cache its result.
-- Uses hooksecurefunc: runs AFTER the original, does NOT taint.
-- Hook layout-changing methods on a frame to refresh geometry caches.
-- This is called once per frame after all single getters are seeded.
local function HookLayoutRefresh(frame)
	local function RefreshCache(self)
		local cache = GetGeometryCache(self)
		local refreshers = {
			{ method = "GetWidth",  key = "width" },
			{ method = "GetHeight", key = "height" },
			{ method = "GetScale",  key = "scale" },
		}
		for _, r in ipairs(refreshers) do
			if (type(self[r.method]) == "function") then
				local ok, v = pcall(self[r.method], self)
				if (ok and IsCleanValue(v)) then
					cache[r.key] = v
				end
			end
		end
	end

	-- Hook methods that change geometry to keep cache fresh.
	local layoutMethods = { "SetWidth", "SetHeight", "SetSize", "SetScale" }
	for _, m in ipairs(layoutMethods) do
		if (type(frame[m]) == "function") then
			hooksecurefunc(frame, m, RefreshCache)
		end
	end

	-- Also refresh on Show (frame may have been resized while hidden).
	if (frame.HookScript) then
		frame:HookScript("OnShow", RefreshCache)
	end
end

-- Seed all geometry caches for a frame from its current live values.
local function SeedGeometryCache(frame)
	if (not frame) then return end
	local cache = GetGeometryCache(frame)

	local singleGetters = {
		{ method = "GetWidth",  key = "width" },
		{ method = "GetHeight", key = "height" },
		{ method = "GetLeft",   key = "left" },
		{ method = "GetRight",  key = "right" },
		{ method = "GetTop",    key = "top" },
		{ method = "GetBottom", key = "bottom" },
		{ method = "GetScale",  key = "scale" },
	}
	for _, info in ipairs(singleGetters) do
		if (type(frame[info.method]) == "function") then
			local ok, v = pcall(frame[info.method], frame)
			if (ok and IsCleanValue(v)) then
				cache[info.key] = v
			end
		end
	end

	if (type(frame.GetCenter) == "function") then
		local ok, x, y = pcall(frame.GetCenter, frame)
		if (ok and IsCleanValue(x) and IsCleanValue(y)) then
			cache.centerX = x
			cache.centerY = y
		end
	end

	if (type(frame.GetRect) == "function") then
		local ok, l, b, w, h = pcall(frame.GetRect, frame)
		if (ok and IsCleanValue(l) and IsCleanValue(b) and IsCleanValue(w) and IsCleanValue(h)) then
			cache.left = l
			cache.bottom = b
			cache.width = w
			cache.height = h
		end
	end
end

-- Hook a frame's geometry methods to passively cache values.
-- Does NOT replace any methods on the frame.
local function HookTooltipGeometryCache(tooltip)
	if (not tooltip or (tooltipGeometryCache[tooltip] and tooltipGeometryCache[tooltip]._hooked)) then
		return
	end
	GetGeometryCache(tooltip)._hooked = true

	-- Seed all cached values from live state
	SeedGeometryCache(tooltip)

	-- Hook layout-changing methods to keep caches fresh.
	-- These hooks run AFTER the original and do not call the
	-- same method (avoiding infinite recursion).
	HookLayoutRefresh(tooltip)
end

-- Public API: get a safe (non-secret) geometry value for a frame.
-- Falls back to cached values when the live value is tainted.
local function GetSafeGeometryValue(frame, method, cacheKey, fallback)
	if (not frame or type(frame[method]) ~= "function") then
		return fallback
	end
	local ok, val = pcall(frame[method], frame)
	if (ok and IsCleanValue(val)) then
		-- Also update cache while we're at it
		local cache = GetGeometryCache(frame)
		cache[cacheKey] = val
		return val
	end
	local cache = tooltipGeometryCache[frame]
	if (cache and cache[cacheKey] ~= nil) then
		return cache[cacheKey]
	end
	return fallback
end

-- Convenience: get safe width for a frame
local function GetSafeWidth(frame)
	return GetSafeGeometryValue(frame, "GetWidth", "width", 0)
end

-- Convenience: get safe height for a frame
local function GetSafeHeight(frame)
	return GetSafeGeometryValue(frame, "GetHeight", "height", 0)
end

-- Convenience: get safe size for a frame
local function GetSafeSize(frame)
	return GetSafeWidth(frame), GetSafeHeight(frame)
end

-- Export safe geometry helpers for addon code
ns.GetSafeWidth = GetSafeWidth
ns.GetSafeHeight = GetSafeHeight
ns.GetSafeSize = GetSafeSize
ns.GetSafeGeometryValue = GetSafeGeometryValue

local function GuardTooltipDimensions()
	-- Hook (not replace) geometry methods on primary tooltips
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
			HookTooltipGeometryCache(tooltip)
		end
	end

	-- Hook embedded widget tooltips
	for i = 1, 10 do
		local embedded = _G["UIWidgetBaseItemEmbeddedTooltip" .. i]
		if (embedded and (not embedded.IsForbidden or not embedded:IsForbidden())) then
			HookTooltipGeometryCache(embedded)
		end
	end
end

-- Widget mixin Setup guards: use hooksecurefunc to recover from
-- secret-value errors AFTER Setup runs, without replacing the method.
local function GuardItemDisplaySetup()
	local mixin = _G["UIWidgetTemplateItemDisplayMixin"]
	if (type(mixin) ~= "table" or type(mixin.Setup) ~= "function"
		or _G.__AzUI_W12_UIWidgetItemDisplaySetupWrapped) then
		return
	end
	_G.__AzUI_W12_UIWidgetItemDisplaySetupWrapped = true
	hooksecurefunc(mixin, "Setup", function(self)
		-- After Setup completes, hook geometry caching on any
		-- dynamically created tooltip so our cache stays current.
		if (self and type(self) == "table") then
			HookTooltipGeometryCache(self)
			if (self.widgetContainer and type(self.widgetContainer) == "table") then
				HookTooltipGeometryCache(self.widgetContainer)
			end
			local tooltip = self.Tooltip
			if (not tooltip) then
				local item = self.Item
				if (item and type(item) == "table") then
					tooltip = item.Tooltip
				end
			end
			if (tooltip and (not tooltip.IsForbidden or not tooltip:IsForbidden())) then
				HookTooltipGeometryCache(tooltip)
			end
		end
	end)
end

local function GuardWidgetSetups()
	-- WoW 12: Do NOT wrap mixin methods with addon pcall wrappers.
	-- Replacing mixin methods taints all values set during the call,
	-- causing LayoutFrame secret-value errors and UpgradeItem taint.
	-- Instead, hook post-Setup to cache geometry on dynamic tooltips.
	GuardItemDisplaySetup()
end

----------------------------------------------------------------
-- Backdrop SetupTextureCoordinates guard
-- WoW 12 secret values break BackdropTemplateMixin.SetupTextureCoordinates
-- when frame dimensions are tainted. We use hooksecurefunc on
-- OnSizeChanged to keep the geometry cache fresh, rather than
-- replacing SetupTextureCoordinates (which taints the mixin).
-- The Blizzard error from secret dimensions is non-fatal and
-- preferable to tainting the entire secure execution context.
----------------------------------------------------------------
local function GuardBackdropSetupTextureCoordinates()
	-- Intentionally no-op: removing the direct mixin method replacement
	-- eliminates the taint vector. The non-fatal Blizzard error from
	-- secret dimensions in SetupTextureCoordinates is harmless compared
	-- to blocking UpgradeItem() and other protected functions.
end

-- Tooltip widget set / inserted frame guards: use hooksecurefunc
-- to passively cache geometry AFTER the Blizzard call, instead of
-- replacing the global function (which taints the execution context).
local function GuardTooltipWidgetSets()
	if (type(_G.GameTooltip_AddWidgetSet) ~= "function"
		or _G.__AzUI_W12_GameTooltipAddWidgetSetWrapped) then
		return
	end
	_G.__AzUI_W12_GameTooltipAddWidgetSetWrapped = true
	hooksecurefunc("GameTooltip_AddWidgetSet", function(tooltip, ...)
		if (tooltip and type(tooltip) == "table"
			and (not tooltip.IsForbidden or not tooltip:IsForbidden())) then
			HookTooltipGeometryCache(tooltip)
		end
	end)
end

local function GuardTooltipInsertedFrames()
	if (type(_G.GameTooltip_InsertFrame) ~= "function"
		or _G.__AzUI_W12_GameTooltipInsertFrameWrapped) then
		return
	end
	_G.__AzUI_W12_GameTooltipInsertFrameWrapped = true
	hooksecurefunc("GameTooltip_InsertFrame", function(tooltipFrame, frame, ...)
		if (tooltipFrame and (not tooltipFrame.IsForbidden or not tooltipFrame:IsForbidden())) then
			HookTooltipGeometryCache(tooltipFrame)
		end
		if (frame and type(frame) == "table") then
			if (not frame.IsForbidden or not frame:IsForbidden()) then
				HookTooltipGeometryCache(frame)
			end
			local bar = frame.Bar or frame.StatusBar
			if (bar and type(bar) == "table"
				and (not bar.IsForbidden or not bar:IsForbidden())) then
				HookTooltipGeometryCache(bar)
			end
		end
	end)
end

-- Hook geometry caching on a money frame and its Gold/Silver/Copper button children.
-- Uses passive hooksecurefunc caching, does NOT replace any methods.
local function HookMoneyFrameGeometryCache(frame)
	if (not frame) then return end
	local cache = tooltipGeometryCache[frame]
	if (cache and cache._hooked) then return end
	HookTooltipGeometryCache(frame)
	local frameName = frame.GetName and frame:GetName()
	if (type(frameName) == "string") then
		for _, suffix in next, { "GoldButton", "SilverButton", "CopperButton" } do
			local button = _G[frameName .. suffix]
			if (button) then
				HookTooltipGeometryCache(button)
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

local function GuardTooltipMoneyAdders()
	-- Hook (not replace) geometry caching on existing tooltip money frames.
	for _, tooltipName in next, {
		"GameTooltip", "ItemRefTooltip", "EmbeddedItemTooltip",
		"ShoppingTooltip1", "ShoppingTooltip2",
	} do
		for i = 1, 5 do
			local mf = _G[tooltipName .. "MoneyFrame" .. i]
			if (mf) then
				HookMoneyFrameGeometryCache(mf)
			end
		end
	end

	-- Hook MoneyFrame_Update to passively cache geometry on tooltip money
	-- frames AFTER the original runs. Does NOT replace the global function.
	if (type(_G.MoneyFrame_Update) == "function" and not _G.__AzUI_W12_MoneyFrameUpdateTooltipHooked) then
		_G.__AzUI_W12_MoneyFrameUpdateTooltipHooked = true
		hooksecurefunc("MoneyFrame_Update", function(frame)
			if (IsTooltipOwnedMoneyFrame(frame)) then
				HookMoneyFrameGeometryCache(frame)
			end
		end)
	end

	-- Hook SetTooltipMoney to passively cache geometry on any money frames
	-- created during the call. Does NOT replace the global function.
	if (type(_G.SetTooltipMoney) == "function" and not _G.__AzUI_W12_SetTooltipMoneyHooked) then
		_G.__AzUI_W12_SetTooltipMoneyHooked = true
		hooksecurefunc("SetTooltipMoney", function(tooltip)
			if (tooltip) then
				local tooltipName = tooltip.GetName and tooltip:GetName()
				if (type(tooltipName) == "string") then
					local numMoney = tooltip.numMoneyFrames
					if (type(numMoney) == "number") then
						for i = 1, numMoney do
							local mf = _G[tooltipName .. "MoneyFrame" .. i]
							if (mf) then
								HookMoneyFrameGeometryCache(mf)
							end
						end
					end
				end
			end
		end)
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
		SetBlizzardRaidBarVisible(ShouldShowBlizzardRaidBar())
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
	ApplyPlaterNamePlateAbsorbCleanup()
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
		if (addonName == "AzeriteUI5_JuNNeZ_Edition") then
			SetBlizzardRaidBarVisible(ShouldShowBlizzardRaidBar())
		end
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
		SetBlizzardRaidBarVisible(ShouldShowBlizzardRaidBar())
		self:UnregisterEvent("PLAYER_LOGIN")
	elseif (event == "PLAYER_ENTERING_WORLD" or event == "GROUP_ROSTER_UPDATE") then
		ApplyGuards()
		SetBlizzardRaidBarVisible(ShouldShowBlizzardRaidBar())
	elseif (event == "PLAYER_REGEN_ENABLED") then
		FlushPendingQuarantineFrames()
		ApplyGuards()
		if (pendingRaidBarVisible ~= nil) then
			SetBlizzardRaidBarVisible(pendingRaidBarVisible)
		end
	end
end)

if (C_Timer) then
	C_Timer.After(0, ApplyGuards)
	C_Timer.After(1, ApplyGuards)
	C_Timer.After(3, ApplyGuards)
end

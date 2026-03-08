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
-- WoW 12+ Blizzard Bug Guards
-- Runs at FILE SCOPE — not inside any module OnInitialize.
-- This avoids being blocked by early-returns elsewhere.
----------------------------------------------------------------

-- Only matters when the forbidden-table system exists.
if (not canaccesstable) then return end

----------------------------------------------------------------
-- CastingBarFrame StopFinishAnims / UpdateShownState guards
----------------------------------------------------------------
-- Problem:
--   oUF (and AzeriteUI) hides PlayerCastingBarFrame via addon
--   code, which taints the frame. When Edit Mode re-shows it,
--   Blizzard's StopFinishAnims iterates StagePips / StagePoints /
--   StageTiers without canaccesstable checks, producing:
--     "attempted to iterate a forbidden table"
--   at CastingBarFrame.lua:722.
--
-- Fix:
--   Replace StopFinishAnims (and its caller UpdateShownState) with
--   versions that pcall the originals to swallow forbidden-table
--   errors. Completely safe — worst case is a visual stage-pip
--   animation not stopping, which is cosmetic.
----------------------------------------------------------------

-- Wrap an original StopFinishAnims so forbidden-table iteration
-- is caught by pcall instead of propagating to BugSack.
local function MakeSafeStopFinishAnims(origFunc)
	return function(self, ...)
		if (self and type(self) == "table" and not canaccesstable(self)) then
			return
		end
		local ok = pcall(origFunc, self, ...)
		-- Swallow errors silently; they're all "forbidden table" noise.
	end
end

-- Same pattern for UpdateShownState, which can also touch
-- forbidden fields when toggling the frame visible.
local function MakeSafeUpdateShownState(origFunc)
	return function(self, ...)
		if (self and type(self) == "table" and not canaccesstable(self)) then
			return
		end
		local ok = pcall(origFunc, self, ...)
	end
end

-- Guard GetTypeInfo, which can index forbidden Blizzard tables during
-- spec/talent transitions after castbar taint.
local SAFE_CASTBAR_TYPE_INFO = {
	showCastbar = true,
	showTradeSkills = true,
	showShield = false,
	showIcon = true,
	barTexture = "Interface\\TargetingFrame\\UI-StatusBar",
	statusBarTexture = "Interface\\TargetingFrame\\UI-StatusBar",
	castBarTexture = "Interface\\TargetingFrame\\UI-StatusBar",
	texture = "Interface\\TargetingFrame\\UI-StatusBar"
}

local function SafeSetCastbarTexture(frame, asset)
	if (not frame or type(frame.SetStatusBarTexture) ~= "function") then
		return
	end
	local safeAsset = asset
	if (type(safeAsset) ~= "string" or safeAsset == "") then
		safeAsset = SAFE_CASTBAR_TYPE_INFO.barTexture
	end
	local ok = pcall(frame.SetStatusBarTexture, frame, safeAsset)
	if (not ok and safeAsset ~= SAFE_CASTBAR_TYPE_INFO.barTexture) then
		pcall(frame.SetStatusBarTexture, frame, SAFE_CASTBAR_TYPE_INFO.barTexture)
	end
end

local function GuardSetStatusBarTexture(frame)
	if (not frame or type(frame) ~= "table" or frame.__AzUI_W12_SBST) then
		return
	end
	if (type(frame.SetStatusBarTexture) ~= "function") then
		return
	end
	frame.__AzUI_W12_SBST = true
	local originalSetStatusBarTexture = frame.SetStatusBarTexture
	frame.SetStatusBarTexture = function(self, asset, ...)
		local safeAsset = asset
		if (type(safeAsset) ~= "string" or safeAsset == "") then
			safeAsset = SAFE_CASTBAR_TYPE_INFO.barTexture
		end
		local ok = pcall(originalSetStatusBarTexture, self, safeAsset, ...)
		if (not ok and safeAsset ~= SAFE_CASTBAR_TYPE_INFO.barTexture) then
			pcall(originalSetStatusBarTexture, self, SAFE_CASTBAR_TYPE_INFO.barTexture, ...)
		end
	end
end

local function NormalizeTypeInfo(info)
	if (type(info) ~= "table" or (canaccesstable and not canaccesstable(info))) then
		info = {}
	end

	local normalized = {}
	for key, value in pairs(SAFE_CASTBAR_TYPE_INFO) do
		normalized[key] = value
	end
	for key, value in pairs(info) do
		normalized[key] = value
	end

	if (type(normalized.showCastbar) ~= "boolean") then
		normalized.showCastbar = true
	end
	if (type(normalized.showTradeSkills) ~= "boolean") then
		normalized.showTradeSkills = true
	end
	if (type(normalized.showShield) ~= "boolean") then
		normalized.showShield = false
	end
	if (type(normalized.showIcon) ~= "boolean") then
		normalized.showIcon = true
	end

	local texture = normalized.barTexture
	if (type(texture) ~= "string" or texture == "") then
		texture = normalized.statusBarTexture
	end
	if (type(texture) ~= "string" or texture == "") then
		texture = normalized.castBarTexture
	end
	if (type(texture) ~= "string" or texture == "") then
		texture = normalized.texture
	end
	if (type(texture) ~= "string" or texture == "") then
		texture = SAFE_CASTBAR_TYPE_INFO.barTexture
	end
	normalized.barTexture = texture
	normalized.statusBarTexture = texture
	normalized.castBarTexture = texture
	normalized.texture = texture

	return normalized
end

local function MakeSafeGetTypeInfo(origFunc)
	return function(self, ...)
		if (self and type(self) == "table" and not canaccesstable(self)) then
			return SAFE_CASTBAR_TYPE_INFO
		end
		local ok, info = pcall(origFunc, self, ...)
		if (ok and type(info) == "table" and (not canaccesstable or canaccesstable(info))) then
			info = NormalizeTypeInfo(info)
			if (self and type(self) == "table") then
				self.__AzUI_W12_LastTypeInfo = info
			end
			return info
		end
		if (self and type(self) == "table") then
			local cached = rawget(self, "__AzUI_W12_LastTypeInfo")
			if (type(cached) == "table" and (not canaccesstable or canaccesstable(cached))) then
				return NormalizeTypeInfo(cached)
			end
		end
		return SAFE_CASTBAR_TYPE_INFO
	end
end

-- Guard FinishSpell, which can receive incomplete barTypeInfo after a guarded
-- GetTypeInfo fallback and then call SetStatusBarTexture(nil).
local function MakeSafeFinishSpell(origFunc)
	return function(self, ...)
		if (self and type(self) == "table" and not canaccesstable(self)) then
			return
		end
		local ok = pcall(origFunc, self, ...)
	end
end

local function MakeSafeOnEvent(origFunc)
	return function(self, ...)
		if (self and type(self) == "table" and not canaccesstable(self)) then
			return
		end
		if (self and type(self) == "table") then
			local barTypeInfo = SAFE_CASTBAR_TYPE_INFO
			if (self.GetTypeInfo) then
				local okType, info = pcall(self.GetTypeInfo, self)
				if (okType and type(info) == "table" and (not canaccesstable or canaccesstable(info))) then
					barTypeInfo = info
					self.__AzUI_W12_LastTypeInfo = NormalizeTypeInfo(info)
				else
					local cached = rawget(self, "__AzUI_W12_LastTypeInfo")
					if (type(cached) == "table" and (not canaccesstable or canaccesstable(cached))) then
						barTypeInfo = cached
					end
				end
			end
			barTypeInfo = NormalizeTypeInfo(barTypeInfo)
			SafeSetCastbarTexture(self, barTypeInfo.barTexture)
		end
		local ok = pcall(origFunc, self, ...)
	end
end

-- Guard a method on a mixin table (idempotent via flag name).
local function GuardMixin(mixin, method, wrapper, flag)
	if (not mixin or type(mixin[method]) ~= "function" or mixin[flag]) then
		return
	end
	mixin[flag] = true
	mixin[method] = wrapper(mixin[method])
end

-- Guard specific frame instances (they may have their OWN copies
-- of these methods set at creation time, separate from the mixin).
local function GuardFrame(frame)
	if (not frame or type(frame) ~= "table") then return end
	if (type(frame.StopFinishAnims) == "function"
		and not frame.__AzUI_W12_SFA) then
		frame.__AzUI_W12_SFA = true
		frame.StopFinishAnims = MakeSafeStopFinishAnims(frame.StopFinishAnims)
	end
	if (type(frame.UpdateShownState) == "function"
		and not frame.__AzUI_W12_USS) then
		frame.__AzUI_W12_USS = true
		frame.UpdateShownState = MakeSafeUpdateShownState(frame.UpdateShownState)
	end
	if (type(frame.GetTypeInfo) == "function"
		and not frame.__AzUI_W12_GTI) then
		frame.__AzUI_W12_GTI = true
		frame.GetTypeInfo = MakeSafeGetTypeInfo(frame.GetTypeInfo)
	end
	if (type(frame.FinishSpell) == "function"
		and not frame.__AzUI_W12_FS) then
		frame.__AzUI_W12_FS = true
		frame.FinishSpell = MakeSafeFinishSpell(frame.FinishSpell)
	end
	if (type(frame.OnEvent) == "function"
		and not frame.__AzUI_W12_OE) then
		frame.__AzUI_W12_OE = true
		frame.OnEvent = MakeSafeOnEvent(frame.OnEvent)
		if (type(frame.SetScript) == "function") then
			pcall(frame.SetScript, frame, "OnEvent", frame.OnEvent)
		end
	end
	GuardSetStatusBarTexture(frame)
end

local function GuardCompactUnitFrameGlobals()
	-- Intentionally no-op on WoW12:
	-- wrapping Blizzard CompactUnitFrame globals taints secure value flow
	-- and causes cascading secret-value errors in Edit Mode/nameplates.
end

local MAX_PARTY_MEMBERS = _G.MEMBERS_PER_RAID_GROUP or 5
local MAX_BOSS_CASTBARS = _G.MAX_BOSS_FRAMES or 8
local MAX_ARENA_MEMBERS = _G.MAX_ARENA_ENEMIES or 5

local quarantineHiddenParent
local parentLockedFrames = {}
local pendingQuarantineFrames = {}
local pendingReparentFrames = {}

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

local function IsUnitFramesActive()
	return IsModuleEnabled("UnitFrames", true)
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
	pcall(frame.SetParent, frame, hiddenParent)
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
			if (InCombatLockdown and InCombatLockdown()
				and child.IsProtected and child:IsProtected()) then
				-- Protected children are handled by out-of-combat reapply.
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
	if (not frame) then
		return
	end
	if (frame.IsForbidden and frame:IsForbidden()) then
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

	if (not opts.skipParent and frame.SetParent) then
		local hiddenParent = GetQuarantineParent()
		pcall(frame.SetParent, frame, hiddenParent)
		if (opts.lockParent and not parentLockedFrames[frame]) then
			parentLockedFrames[frame] = true
			hooksecurefunc(frame, "SetParent", LockToHiddenParent)
		end
	end
end

local function QuarantineSpellBars()
	if (not IsUnitFramesActive()) then
		return
	end

	-- Keep parent links for Target/Focus/Boss spellbars; Blizzard code reads parent data.
	QuarantineFrame("TargetFrameSpellBar", { skipParent = true })
	QuarantineFrame("FocusFrameSpellBar", { skipParent = true })

	for i = 1, MAX_BOSS_CASTBARS do
		QuarantineFrame("Boss" .. i .. "TargetFrameSpellBar", { skipParent = true })
	end
end

local function ShouldQuarantineCompactFrame(frame)
	if (not frame) then
		return false
	end
	if (frame.IsForbidden and frame:IsForbidden()) then
		return false
	end

	local name
	if (frame.GetDebugName) then
		local ok, value = pcall(frame.GetDebugName, frame)
		if (ok and type(value) == "string") then
			name = value
		end
	end
	if (not name and frame.GetName) then
		local ok, value = pcall(frame.GetName, frame)
		if (ok and type(value) == "string") then
			name = value
		end
	end
	if (not name) then
		return false
	end
	if (string.find(name, "NamePlate", 1, true)) then
		return false
	end

	if (name == "CompactPartyFrame"
		or name == "CompactRaidFrameContainer"
		or name == "CompactRaidFrameManager"
		or name == "CompactArenaFrame"
		or name == "PartyFrame"
		or name == "ArenaEnemyFrames"
		or name == "ArenaPrepFrames") then
		return true
	end

	return (string.match(name, "^PartyMemberFrame%d+$")
		or string.match(name, "^CompactPartyFrameMember%d+$")
		or string.match(name, "^CompactArenaFrameMember%d+$")
		or string.match(name, "^CompactRaidGroup%d+Member%d+$")) and true or false
end

local function HookCompactFrameLifecycle()
	if (_G.CompactUnitFrame_SetUpFrame and not _G.__AzUI_W12_CUF_SetUpFrameHooked) then
		_G.__AzUI_W12_CUF_SetUpFrameHooked = true
		hooksecurefunc("CompactUnitFrame_SetUpFrame", function(frame)
			if (IsUnitFramesActive() and ShouldQuarantineCompactFrame(frame)) then
				QuarantineFrame(frame)
			end
		end)
	end
	if (_G.CompactUnitFrame_SetUnit and not _G.__AzUI_W12_CUF_SetUnitHooked) then
		_G.__AzUI_W12_CUF_SetUnitHooked = true
		hooksecurefunc("CompactUnitFrame_SetUnit", function(frame)
			if (IsUnitFramesActive() and ShouldQuarantineCompactFrame(frame)) then
				QuarantineFrame(frame)
			end
		end)
	end
	if (_G.CompactRaidGroup_InitializeForGroup and not _G.__AzUI_W12_CUF_GroupInitHooked) then
		_G.__AzUI_W12_CUF_GroupInitHooked = true
		hooksecurefunc("CompactRaidGroup_InitializeForGroup", function(frame)
			if (IsUnitFramesActive() and ShouldQuarantineCompactFrame(frame)) then
				QuarantineFrame(frame, { lockParent = true })
			end
		end)
	end
	if (_G.PartyFrame_UpdatePartyFrames and not _G.__AzUI_W12_PartyFrameUpdateHooked) then
		_G.__AzUI_W12_PartyFrameUpdateHooked = true
		hooksecurefunc("PartyFrame_UpdatePartyFrames", function()
			if (IsUnitFramesActive()) then
				QuarantineCompactFrames()
			end
		end)
	end
end

local function GuardAuraBigDefensive()
	-- Intentionally no-op on WoW12:
	-- global AuraUtil/C_UnitAuras rewrites taint Blizzard compact/nameplate paths.
end

local function GuardPartyHealthFunctions()
	-- Intentionally no-op on WoW12:
	-- wrapping these globals taints Blizzard party/statusbar paths.
end

local function QuarantineCompactFrames()
	if (not IsUnitFramesActive()) then
		return
	end

	-- Avoid CompactRaidFrameManager_SetSetting here on WoW12.
	-- It can route into protected HideBase() during roster/EditMode refresh and
	-- trigger ADDON_ACTION_BLOCKED (CompactRaidFrameContainer:HideBase).

	if (UIParent and UIParent.UnregisterEvent) then
		pcall(UIParent.UnregisterEvent, UIParent, "GROUP_ROSTER_UPDATE")
	end

	QuarantineFrame("PartyFrame", { lockParent = true })
	QuarantineFrame("CompactPartyFrame", { lockParent = true })
	for i = 1, MAX_PARTY_MEMBERS do
		QuarantineFrame("PartyMemberFrame" .. i)
		QuarantineFrame("CompactPartyFrameMember" .. i)
	end

	QuarantineFrame("CompactRaidFrameContainer", { lockParent = true })
	QuarantineFrame("CompactRaidFrameManager", { lockParent = true })

	QuarantineFrame("CompactArenaFrame", { lockParent = true })
	for i = 1, MAX_ARENA_MEMBERS do
		QuarantineFrame("CompactArenaFrameMember" .. i)
	end

	QuarantineFrame("ArenaEnemyFrames", { lockParent = true })
	QuarantineFrame("ArenaPrepFrames", { lockParent = true })
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
ns.WoW12BlizzardQuarantine.ApplySpellBars = QuarantineSpellBars
ns.WoW12BlizzardQuarantine.QuarantineFrame = QuarantineFrame

-- Master apply (idempotent — safe to call many times).
local function ApplyGuards()
	-- Guard explicit castbar instances only.
	-- Avoid global mixin rewrites, which taint nameplate/shared Blizzard paths.
	GuardFrame(_G.PlayerCastingBarFrame)
	GuardFrame(_G.OverlayPlayerCastingBarFrame)
	GuardFrame(_G.PetCastingBarFrame)
	GuardFrame(_G.TargetFrameSpellBar)
	GuardFrame(_G.FocusFrameSpellBar)
	for i = 1, MAX_BOSS_CASTBARS do
		GuardFrame(_G["Boss" .. i .. "TargetFrameSpellBar"])
	end
	GuardCompactUnitFrameGlobals()
	ApplyBlizzardFrameQuarantine()
	HookCompactFrameLifecycle()
	GuardAuraBigDefensive()
	GuardPartyHealthFunctions()

	-- Arena castbar instances — created by Blizzard_ArenaUI.
	-- CompactArenaFrame has memberUnitFrames, each with a castBar.
	if (_G.CompactArenaFrame and type(_G.CompactArenaFrame.memberUnitFrames) == "table") then
		for _, unitFrame in pairs(_G.CompactArenaFrame.memberUnitFrames) do
			if (unitFrame) then
				-- The castbar can live under various keys
				local castBar = unitFrame.castBar or unitFrame.CastBar
					or unitFrame.castbar or unitFrame.CastingBarFrame
				if (castBar) then
					GuardFrame(castBar)
				end
				-- Guard the unit frame itself in case it holds the methods
				GuardFrame(unitFrame)
			end
		end
	end

	-- Also try direct ArenaEnemyMatchFrame* castbars if they exist
	for i = 1, 5 do
		local name = "ArenaEnemyMatchFrame" .. i
		local frame = _G[name]
		if (frame) then
			local castBar = frame.castBar or frame.CastBar
				or frame.castbar or frame.CastingBarFrame
			if (castBar) then
				GuardFrame(castBar)
			end
		end
		-- Also try CompactArenaFrameMember* pattern
		local name2 = "CompactArenaFrameMember" .. i
		local frame2 = _G[name2]
		if (frame2) then
			local castBar2 = frame2.castBar or frame2.CastBar
				or frame2.castbar or frame2.CastingBarFrame
			if (castBar2) then
				GuardFrame(castBar2)
			end
			GuardFrame(frame2)
		end
	end
end

----------------------------------------------------------------
-- Apply immediately (works if Blizzard_UIPanels_Game is loaded)
----------------------------------------------------------------
ApplyGuards()

----------------------------------------------------------------
-- Deferred: catch demand-loaded Blizzard addons
----------------------------------------------------------------
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
			or addonName == "Blizzard_EditMode"
			or addonName == "Blizzard_ArenaUI"
			or addonName == "Blizzard_NamePlates") then
			ApplyGuards()
			-- One-frame delay lets mixin copies propagate.
			if (C_Timer) then
				C_Timer.After(0, ApplyGuards)
				C_Timer.After(1, ApplyGuards)
			end
		end
	elseif (event == "PLAYER_LOGIN") then
		ApplyGuards()
		self:UnregisterEvent("PLAYER_LOGIN")
	elseif (event == "PLAYER_ENTERING_WORLD"
		or event == "GROUP_ROSTER_UPDATE") then
		ApplyGuards()
	elseif (event == "PLAYER_REGEN_ENABLED") then
		FlushPendingQuarantineFrames()
		ApplyGuards()
	end
end)

-- Belt-and-suspenders timers
if (C_Timer) then
	C_Timer.After(0, ApplyGuards)
	C_Timer.After(1, ApplyGuards)
	C_Timer.After(3, ApplyGuards)
end

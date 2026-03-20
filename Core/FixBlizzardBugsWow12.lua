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
	if (ShouldHandlePartyFrames() and IsCompactPartyFrameName(name)) then
		return true
	end
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
		PrepareCompactFrame(_G.CompactRaidFrameManager)
		QuarantineFrame("CompactRaidFrameManager", { lockParent = true })
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
ns.WoW12BlizzardQuarantine.ApplySpellBars = QuarantineSpellBars
ns.WoW12BlizzardQuarantine.QuarantineFrame = QuarantineFrame

local function ApplyGuards()
	GuardUnitAuraApis()
	GuardPartyFrameGlobals()
	GuardCompactUnitFrameGlobals()
	ApplyBlizzardFrameQuarantine()
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
			or addonName == "Blizzard_ArenaUI") then
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

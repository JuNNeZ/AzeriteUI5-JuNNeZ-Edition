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
local SAFE_CASTBAR_TYPE_INFO = {
	filling = "ui-castingbar-filling-standard",
	full = "ui-castingbar-full-standard",
	glow = "ui-castingbar-full-glow-standard",
	sparkFx = "StandardGlow",
	finishAnim = "StandardFinish"
}

local function MakeSafeStopFinishAnims(origFunc)
	return function(self, ...)
		if (self and type(self) == "table" and not canaccesstable(self)) then
			return
		end
		pcall(origFunc, self, ...)
	end
end

local function MakeSafeCastbarVisualMethod(origFunc)
	return function(self, ...)
		if (self and type(self) == "table" and not canaccesstable(self)) then
			return
		end
		pcall(origFunc, self, ...)
	end
end

local function MakeSafeUpdateShownState(origFunc)
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

local function GuardCastingBarMixinMethod(mixin, method, wrapper, flag)
	if (not mixin or type(mixin[method]) ~= "function" or mixin[flag]) then
		return
	end
	mixin[flag] = true
	mixin[method] = wrapper(mixin[method])
end

local function GuardCastingBarFrame(frame)
	if (not frame or type(frame) ~= "table") then
		return
	end
	if (type(frame.StopFinishAnims) == "function" and not frame.__AzUI_W12_SFA) then
		frame.__AzUI_W12_SFA = true
		frame.StopFinishAnims = MakeSafeStopFinishAnims(frame.StopFinishAnims)
	end
	if (type(frame.HideSpark) == "function" and not frame.__AzUI_W12_HS) then
		frame.__AzUI_W12_HS = true
		frame.HideSpark = MakeSafeCastbarVisualMethod(frame.HideSpark)
	end
	if (type(frame.ShowSpark) == "function" and not frame.__AzUI_W12_SS) then
		frame.__AzUI_W12_SS = true
		frame.ShowSpark = MakeSafeCastbarVisualMethod(frame.ShowSpark)
	end
	if (type(frame.PlayFinishAnim) == "function" and not frame.__AzUI_W12_PFA) then
		frame.__AzUI_W12_PFA = true
		frame.PlayFinishAnim = MakeSafeCastbarVisualMethod(frame.PlayFinishAnim)
	end
	if (type(frame.UpdateShownState) == "function" and not frame.__AzUI_W12_USS) then
		frame.__AzUI_W12_USS = true
		frame.UpdateShownState = MakeSafeUpdateShownState(frame.UpdateShownState)
	end
	if (type(frame.GetTypeInfo) == "function" and not frame.__AzUI_W12_GTI) then
		frame.__AzUI_W12_GTI = true
		frame.GetTypeInfo = MakeSafeGetTypeInfo(frame.GetTypeInfo)
	end
end

local function ApplyCastingBarGuards()
	GuardCastingBarMixinMethod(_G.CastingBarMixin, "StopFinishAnims",
		MakeSafeStopFinishAnims, "__AzUI_W12_SFA_CBM")
	GuardCastingBarMixinMethod(_G.CastingBarFrameMixin, "StopFinishAnims",
		MakeSafeStopFinishAnims, "__AzUI_W12_SFA_CBFM")
	GuardCastingBarMixinMethod(_G.CastingBarMixin, "HideSpark",
		MakeSafeCastbarVisualMethod, "__AzUI_W12_HS_CBM")
	GuardCastingBarMixinMethod(_G.CastingBarFrameMixin, "HideSpark",
		MakeSafeCastbarVisualMethod, "__AzUI_W12_HS_CBFM")
	GuardCastingBarMixinMethod(_G.CastingBarMixin, "ShowSpark",
		MakeSafeCastbarVisualMethod, "__AzUI_W12_SS_CBM")
	GuardCastingBarMixinMethod(_G.CastingBarFrameMixin, "ShowSpark",
		MakeSafeCastbarVisualMethod, "__AzUI_W12_SS_CBFM")
	GuardCastingBarMixinMethod(_G.CastingBarMixin, "PlayFinishAnim",
		MakeSafeCastbarVisualMethod, "__AzUI_W12_PFA_CBM")
	GuardCastingBarMixinMethod(_G.CastingBarFrameMixin, "PlayFinishAnim",
		MakeSafeCastbarVisualMethod, "__AzUI_W12_PFA_CBFM")
	GuardCastingBarMixinMethod(_G.CastingBarMixin, "UpdateShownState",
		MakeSafeUpdateShownState, "__AzUI_W12_USS_CBM")
	GuardCastingBarMixinMethod(_G.CastingBarFrameMixin, "UpdateShownState",
		MakeSafeUpdateShownState, "__AzUI_W12_USS_CBFM")
	GuardCastingBarMixinMethod(_G.CastingBarMixin, "GetTypeInfo",
		MakeSafeGetTypeInfo, "__AzUI_W12_GTI_CBM")
	GuardCastingBarMixinMethod(_G.CastingBarFrameMixin, "GetTypeInfo",
		MakeSafeGetTypeInfo, "__AzUI_W12_GTI_CBFM")

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
	if (manager.EnableMouse) then
		pcall(manager.EnableMouse, manager, false)
	end
	if (manager.UnregisterAllEvents) then
		pcall(manager.UnregisterAllEvents, manager)
	end
	if (manager.HookScript and not manager.__AzUI_W12_SuppressOnShowHooked) then
		manager.__AzUI_W12_SuppressOnShowHooked = true
		manager:HookScript("OnShow", function(self)
			if (self.SetAlpha) then
				pcall(self.SetAlpha, self, 0)
			end
			if (self.EnableMouse) then
				pcall(self.EnableMouse, self, false)
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

local function GuardAuraUtilUnpack()
	if (not AuraUtil or type(AuraUtil.UnpackAuraData) ~= "function"
		or _G.__AzUI_W12_AuraUtilUnpackWrapped) then
		return
	end

	_G.__AzUI_W12_AuraUtilUnpackWrapped = true
	local original = AuraUtil.UnpackAuraData
	local Pack = table.pack or function(...)
		return { n = select("#", ...), ... }
	end

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

local function HideSecretWidgetTarget(target)
	if (not target) then
		return false
	end
	if (target.Tooltip and target.Tooltip.Hide) then
		pcall(target.Tooltip.Hide, target.Tooltip)
	end
	if (target.Hide) then
		pcall(target.Hide, target)
	end
	if (target.disableTooltip ~= nil) then
		target.disableTooltip = true
	end
	if (target.tooltipEnabled ~= nil) then
		target.tooltipEnabled = false
	end
	if (target.widgetContainer) then
		if (target.widgetContainer.disableWidgetTooltips ~= nil) then
			target.widgetContainer.disableWidgetTooltips = true
		end
		if (target.widgetContainer.Hide) then
			pcall(target.widgetContainer.Hide, target.widgetContainer)
		end
	end
	if (target.widgetContainer and target.widgetContainer.Hide) then
		pcall(target.widgetContainer.Hide, target.widgetContainer)
	end
	return true
end

local function HideSecretWidgetTargets(...)
	local hidden = false
	for i = 1, select("#", ...) do
		local value = select(i, ...)
		local valueType = type(value)
		if (valueType == "table" or valueType == "userdata") then
			if ((value.Tooltip and value.Tooltip.Hide)
				or (value.widgetContainer and value.widgetContainer.Hide)) then
				hidden = HideSecretWidgetTarget(value) or hidden
			elseif (value.widgetFrames and value.Hide) then
				hidden = HideSecretWidgetTarget(value) or hidden
			elseif (value.widgetType and value.Hide) then
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

local function GuardWidgetTextWithStateSetup()
	if (type(_G.UIWidgetTemplateTextWithStateMixin) ~= "table"
		or type(_G.UIWidgetTemplateTextWithStateMixin.Setup) ~= "function"
		or _G.__AzUI_W12_UIWidgetTextWithStateSetupWrapped) then
		return
	end

	_G.__AzUI_W12_UIWidgetTextWithStateSetupWrapped = true
	local mixin = _G.UIWidgetTemplateTextWithStateMixin
	local original = mixin.Setup
	local Pack = table.pack or function(...)
		return { n = select("#", ...), ... }
	end

	mixin.Setup = function(...)
		local results = Pack(pcall(original, ...))
		if (results[1]) then
			return unpack(results, 2, results.n or #results)
		end
		return HandleSecretWidgetError(results[2], ...)
	end
end

local function GuardWidgetItemDisplaySetup()
	if (type(_G.UIWidgetTemplateItemDisplayMixin) ~= "table"
		or type(_G.UIWidgetTemplateItemDisplayMixin.Setup) ~= "function"
		or _G.__AzUI_W12_UIWidgetItemDisplaySetupWrapped) then
		return
	end

	_G.__AzUI_W12_UIWidgetItemDisplaySetupWrapped = true
	local mixin = _G.UIWidgetTemplateItemDisplayMixin
	local original = mixin.Setup
	local Pack = table.pack or function(...)
		return { n = select("#", ...), ... }
	end

	mixin.Setup = function(...)
		local results = Pack(pcall(original, ...))
		if (results[1]) then
			return unpack(results, 2, results.n or #results)
		end
		return HandleSecretWidgetError(results[2], ...)
	end
end

local function GuardWidgetManagerRegister()
	if (type(_G.UIWidgetManagerMixin) ~= "table"
		or type(_G.UIWidgetManagerMixin.RegisterForWidgetSet) ~= "function"
		or _G.__AzUI_W12_UIWidgetManagerRegisterWrapped) then
		return
	end

	_G.__AzUI_W12_UIWidgetManagerRegisterWrapped = true
	local mixin = _G.UIWidgetManagerMixin
	local original = mixin.RegisterForWidgetSet
	local Pack = table.pack or function(...)
		return { n = select("#", ...), ... }
	end

	mixin.RegisterForWidgetSet = function(...)
		local results = Pack(pcall(original, ...))
		if (results[1]) then
			return unpack(results, 2, results.n or #results)
		end
		return HandleSecretWidgetError(results[2], ...)
	end
end

local function GuardTooltipWidgetSets()
	if (type(_G.GameTooltip_AddWidgetSet) ~= "function"
		or _G.__AzUI_W12_GameTooltipAddWidgetSetWrapped) then
		return
	end

	_G.__AzUI_W12_GameTooltipAddWidgetSetWrapped = true
	local original = _G.GameTooltip_AddWidgetSet
	local Pack = table.pack or function(...)
		return { n = select("#", ...), ... }
	end

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
	local Pack = table.pack or function(...)
		return { n = select("#", ...), ... }
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
ns.WoW12BlizzardQuarantine.ApplySpellBars = QuarantineSpellBars
ns.WoW12BlizzardQuarantine.QuarantineFrame = QuarantineFrame

local function ApplyGuards()
	ApplyCastingBarGuards()
	GuardUnitAuraApis()
	GuardPartyFrameGlobals()
	GuardCompactUnitFrameGlobals()
	GuardAuraUtilUnpack()
	GuardWidgetTextWithStateSetup()
	GuardWidgetItemDisplaySetup()
	GuardWidgetManagerRegister()
	GuardTooltipWidgetSets()
	GuardTooltipMoneyAdders()
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
			or addonName == "Blizzard_ArenaUI"
			or addonName == "Blizzard_EditMode"
			or addonName == "Blizzard_GameTooltip"
			or addonName == "Blizzard_UIWidgets") then
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

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
local Addon, ns = ...

-- Backdrop template for Lua and XML
-- Allows us to always set these templates, even in Classic.
local MixinGlobal = Addon.."BackdropTemplateMixin"
_G[MixinGlobal] = {}
if (BackdropTemplateMixin) then
	_G[MixinGlobal] = CreateFromMixins(BackdropTemplateMixin) -- Usable in XML
	ns.Private.BackdropTemplate = "BackdropTemplate" -- Usable in Lua
end

-- Classics
if (not _G.UnitEffectiveLevel) then
	_G.UnitEffectiveLevel = UnitLevel
end

if (not _G.IsXPUserDisabled) then
	_G.IsXPUserDisabled = function() return false end
end

if (not _G.UnitHasVehicleUI) then
	_G.UnitHasVehicleUI = function() return false end
end

if (not _G.GetTimeToWellRested) then
	_G.GetTimeToWellRested = function() return nil end
end

local tocversion = select(4, GetBuildInfo())

-- Deprecated in 10.1.0
if (tocversion >= 100100) or (tocversion >= 40400 and tocversion < 50000) then
	if (not _G.GetAddOnMetadata) then
		_G.GetAddOnMetadata = C_AddOns.GetAddOnMetadata
	end
end

-- Deprecated in 10.2.0
if (tocversion >= 100200) or (tocversion >= 40400 and tocversion < 50000) then
	local original_SetPortraitToTexture = SetPortraitToTexture
	for method,func in next,{
		GetCVarInfo = C_CVar.GetCVarInfo,
		EnableAddOn = C_AddOns.EnableAddOn,
		DisableAddOn = C_AddOns.DisableAddOn,
		GetAddOnEnableState = function(character, name) return C_AddOns.GetAddOnEnableState(name, character) end,
		LoadAddOn = C_AddOns.LoadAddOn,
		IsAddOnLoaded = C_AddOns.IsAddOnLoaded,
		EnableAllAddOns = C_AddOns.EnableAllAddOns,
		DisableAllAddOns = C_AddOns.DisableAllAddOns,
		GetAddOnInfo = C_AddOns.GetAddOnInfo,
		GetAddOnDependencies = C_AddOns.GetAddOnDependencies,
		GetAddOnOptionalDependencies = C_AddOns.GetAddOnOptionalDependencies,
		GetNumAddOns = C_AddOns.GetNumAddOns,
		SaveAddOns = C_AddOns.SaveAddOns,
		ResetAddOns = C_AddOns.ResetAddOns,
		ResetDisabledAddOns = C_AddOns.ResetDisabledAddOns,
		IsAddonVersionCheckEnabled = C_AddOns.IsAddonVersionCheckEnabled,
		SetAddonVersionCheck = C_AddOns.SetAddonVersionCheck,
		IsAddOnLoadOnDemand = C_AddOns.IsAddOnLoadOnDemand,
		SetPortraitToTexture = function(texture, asset)
			if asset ~= nil then
				if type(texture) == "string" then
					texture = _G[texture]
				end
				if type(texture) == "table" and texture.SetTexture then
					if type(original_SetPortraitToTexture) == "function" then
						local ok = pcall(original_SetPortraitToTexture, texture, asset)
						if ok then
							return
						end
					end
					texture:SetTexture(asset)
				end
			end
		end
	} do
		if (not _G[method]) then
			_G[method] = func
		end
	end
end

-- Safe aura unpacker: tries AuraUtil.UnpackAuraData first, falls back
-- to direct field extraction when the secret-value wrapper returns nil.
-- This prevents addons like Decursive from losing debuff data when our
-- GuardAuraUtilUnpack wrapper rejects auras with secret fields.
do
	local issecretvalue = _G.issecretvalue
	local canaccessvalue = _G.canaccessvalue
	local select = _G.select
	local Pack = function(...)
		return { n = select("#", ...), ... }
	end
	ns.SafeUnpackAuraData = function(auraData)
		-- Try the (possibly wrapped) AuraUtil.UnpackAuraData first.
		if (AuraUtil and AuraUtil.UnpackAuraData) then
			local results = Pack(pcall(AuraUtil.UnpackAuraData, auraData))
			if (results[1] and results[2] ~= nil) then
				return unpack(results, 2, results.n)
			end
		end
		-- Fallback: extract fields directly, omitting secret points entirely.
		-- Secret values are truthy but fail type()/unpack(), so we must
		-- guard with issecretvalue before touching auraData.points.
		local safePoints
		if (issecretvalue) then
			local ok, pts = pcall(function() return auraData.points end)
			if (ok and not issecretvalue(pts) and type(pts) == "table") then
				safePoints = pts
			end
		else
			local ok, pts = pcall(function()
				local p = auraData.points
				if (type(p) == "table") then return p end
			end)
			if (ok and pts) then
				safePoints = pts
			end
		end
		if (safePoints) then
			return auraData.name, auraData.icon, auraData.applications,
				auraData.dispelName, auraData.duration, auraData.expirationTime,
				auraData.sourceUnit, auraData.isStealable, auraData.nameplateShowPersonal,
				auraData.spellId, auraData.canApplyAura, auraData.isBossAura,
				auraData.isFromPlayerOrPlayerPet, auraData.nameplateShowAll,
				auraData.timeMod, unpack(safePoints)
		end
		return auraData.name, auraData.icon, auraData.applications,
			auraData.dispelName, auraData.duration, auraData.expirationTime,
			auraData.sourceUnit, auraData.isStealable, auraData.nameplateShowPersonal,
			auraData.spellId, auraData.canApplyAura, auraData.isBossAura,
			auraData.isFromPlayerOrPlayerPet, auraData.nameplateShowAll,
			auraData.timeMod
	end
end

do
	local issecretvalue = _G.issecretvalue
	local canaccessvalue = _G.canaccessvalue
	local UnitCanAssist = _G.UnitCanAssist
	local InCombatLockdown = _G.InCombatLockdown
	local UnitAuras = _G.C_UnitAuras

	local function IsReadableValue(value)
		if (issecretvalue and issecretvalue(value)) then
			return false
		end
		if (canaccessvalue and not canaccessvalue(value)) then
			return false
		end
		return true
	end

	ns.GetLegacyUnitDebuffFilter = function(unitToken, filter)
		if (tocversion < 120000 or filter ~= nil or not UnitCanAssist or type(unitToken) ~= "string") then
			return filter
		end
		local ok, canAssist = pcall(UnitCanAssist, "player", unitToken)
		if (ok and type(canAssist) == "boolean" and IsReadableValue(canAssist) and canAssist) then
			if (InCombatLockdown and InCombatLockdown()) then
				-- Last known-good combat behavior: no filter. Direct RAID_PLAYER_DISPELLABLE
				-- can return zero on secret dispel fields during combat.
				return filter
			end
			return "RAID_PLAYER_DISPELLABLE"
		end
		return filter
	end

	ns.ShouldUseCombatFriendlyDispellableList = function(unitToken, filter)
		if (tocversion < 120000 or filter ~= nil or type(unitToken) ~= "string") then
			return false
		end
		if (not (InCombatLockdown and InCombatLockdown())) then
			return false
		end
		if (not UnitCanAssist) then
			return false
		end
		local ok, canAssist = pcall(UnitCanAssist, "player", unitToken)
		return ok and type(canAssist) == "boolean" and IsReadableValue(canAssist) and canAssist and true or false
	end

	ns.GetCombatFriendlyDispellableDebuffByIndex = function(unitToken, index)
		if (not UnitAuras or not UnitAuras.GetUnitAuraInstanceIDs or not UnitAuras.GetAuraDataByAuraInstanceID) then
			return nil, false
		end
		if (type(index) ~= "number" or index < 1) then
			return nil, true
		end

		local attemptedFilteredQuery = false

		local function TryGetAuraDataList(auraFilter)
			if (not UnitAuras.GetUnitAuras) then
				return nil
			end
			local okAuras, auraList = pcall(UnitAuras.GetUnitAuras, unitToken, auraFilter)
			if (okAuras and type(auraList) == "table") then
				attemptedFilteredQuery = true
				return auraList
			end
			return nil
		end

		local function TryGetInstanceIDs(auraFilter)
			local okIDs, auraInstanceIDs = pcall(UnitAuras.GetUnitAuraInstanceIDs, unitToken, auraFilter)
			if (okIDs and type(auraInstanceIDs) == "table") then
				attemptedFilteredQuery = true
				return auraInstanceIDs
			end
			return nil
		end

		local auraDataList = TryGetAuraDataList("HARMFUL|RAID_PLAYER_DISPELLABLE") or TryGetAuraDataList("RAID_PLAYER_DISPELLABLE")
		if (type(auraDataList) == "table") then
			local auraData = auraDataList[index]
			if (type(auraData) == "table") then
				return auraData, true
			end
			-- Filtered query succeeded and reported no Nth aura; keep this authoritative.
			return nil, true
		end

		local auraInstanceIDs = TryGetInstanceIDs("HARMFUL|RAID_PLAYER_DISPELLABLE") or TryGetInstanceIDs("RAID_PLAYER_DISPELLABLE")
		if (type(auraInstanceIDs) ~= "table") then
			return nil, attemptedFilteredQuery and true or false
		end
		local auraInstanceID = auraInstanceIDs[index]
		if (type(auraInstanceID) ~= "number") then
			return nil, true
		end
		local okAura, auraData = pcall(UnitAuras.GetAuraDataByAuraInstanceID, unitToken, auraInstanceID)
		if (okAura and auraData) then
			return auraData, true
		end
		return nil, false
	end
end

-- Deprecated in 10.2.5
if (tocversion >= 100205) or (tocversion >= 40400 and tocversion < 50000) then
	for method,func in next,{
		GetTimeToWellRested = function() return nil end,
		FillLocalizedClassList = function(tbl, isFemale)
			local classList = LocalizedClassList(isFemale)
			MergeTable(tbl, classList)
			return tbl
		end,
		GetSetBonusesForSpecializationByItemID = C_Item.GetSetBonusesForSpecializationByItemID,
		GetItemStats = function(itemLink, existingTable)
			local statTable = C_Item.GetItemStats(itemLink)
			if existingTable then
				MergeTable(existingTable, statTable)
				return existingTable
			else
				return statTable
			end
		end,
		GetItemStatDelta = function(itemLink1, itemLink2, existingTable)
			local statTable = C_Item.GetItemStatDelta(itemLink1, itemLink2)
			if existingTable then
				MergeTable(existingTable, statTable)
				return existingTable
			else
				return statTable
			end
		end,
		UnitAura = function(unitToken, index, filter)
			local auraData = C_UnitAuras.GetAuraDataByIndex(unitToken, index, filter)
			if not auraData then return nil end
			return ns.SafeUnpackAuraData(auraData)
		end,
		UnitBuff = function(unitToken, index, filter)
			local auraData = C_UnitAuras.GetBuffDataByIndex(unitToken, index, filter)
			if not auraData then return nil end
			return ns.SafeUnpackAuraData(auraData)
		end,
		UnitDebuff = function(unitToken, index, filter)
			local legacyFilter = ns.GetLegacyUnitDebuffFilter(unitToken, filter)
			local auraData
			local handledCombatFilteredQuery = false
			if (ns.ShouldUseCombatFriendlyDispellableList(unitToken, filter)) then
				auraData, handledCombatFilteredQuery = ns.GetCombatFriendlyDispellableDebuffByIndex(unitToken, index)
			end
			if (not auraData and not handledCombatFilteredQuery) then
				auraData = C_UnitAuras.GetDebuffDataByIndex(unitToken, index, legacyFilter)
			end
			if not auraData then return nil end
			if (tocversion >= 120000) then
				local name, icon, applications, dispelName, duration, expirationTime,
					sourceUnit, isStealable, nameplateShowPersonal, spellID = ns.SafeUnpackAuraData(auraData)
				return name, icon, applications, dispelName, duration, expirationTime,
					sourceUnit, isStealable, nameplateShowPersonal, spellID, auraData.auraInstanceID
			end
			return ns.SafeUnpackAuraData(auraData)
		end,
		UnitAuraBySlot = function(unitToken, index)
			local auraData = C_UnitAuras.GetAuraDataBySlot(unitToken, index)
			if not auraData then return nil end
			return ns.SafeUnpackAuraData(auraData)
		end,
		UnitAuraSlots = C_UnitAuras.GetAuraSlots
	} do
		if (not _G[method]) then
			_G[method] = func
		end
	end
end

-- WoW 12 compatibility: some third-party addons (Decursive among them)
-- still consume UnitDebuff tuple returns. Their secret-mode dispel logic
-- relies on receiving secret dispel fields unchanged, but branching directly
-- on a secret auraInstanceID can error. Only sanitize auraInstanceID.
do
	local unpack = _G.unpack or (table and rawget(table, "unpack"))
	local select = select
	local issecretvalue = _G.issecretvalue

	local function SanitizeAuraInstanceIDOnly(...)
		local count = select("#", ...)
		if (count == 0) then
			return
		end
		local values = { ... }
		if (issecretvalue and issecretvalue(values[11])) then
			values[11] = nil
		end
		return unpack(values, 1, count)
	end

	local function WrapLegacyAuraTuple(methodName)
		local original = _G[methodName]
		if (type(original) ~= "function") then
			return
		end
		local wrappedFlag = "__AzUI_W12_" .. methodName .. "SecretTupleWrapped"
		if (_G[wrappedFlag]) then
			return
		end
		_G[wrappedFlag] = true
		_G[methodName] = function(...)
			return SanitizeAuraInstanceIDOnly(original(...))
		end
	end

	if (tocversion >= 120000) then
		WrapLegacyAuraTuple("UnitDebuff")
	end
end

-- Deprecated in 10.x.x, removed in 11.0.0
if (tocversion >= 110000) then
	for method,func in next, {
		GetSpellCharges = function(...)
			local numArgs = select("#", ...)

			if (numArgs == 2) then
				local index, bookType
				local spellBank = (bookType == "spell") and Enum.SpellBookSpellBank.Player or Enum.SpellBookSpellBank.pet
				spellChargeInfo = C_SpellBook.GetSpellBookItemCharges(index, spellBank)
			else
				local spell = select(1, ...)
				spellChargeInfo = C_Spell.GetSpellCharges(spell)
			end

			if spellChargeInfo then
				return spellChargeInfo.currentCharges,
					   spellChargeInfo.maxCharges,
					   spellChargeInfo.cooldownStartTime,
					   spellChargeInfo.cooldownDuration,
					   spellChargeInfo.chargeModRate
			end
		end,
		GetSpellCooldown = function(...)
			local numArgs = select("#", ...)
			local spellCooldownInfo = nil

			if ((numArgs == 2)) then
				local spellBank = (bookType == "spell") and Enum.SpellBookSpellBank.Player or Enum.SpellBookSpellBank.pet
				spellCooldownInfo = C_SpellBook.GetSpellBookItemCooldown(spellOrIndex, spellBank)
			else
				local spell = select(1, ...)
				spellCooldownInfo = C_Spell.GetSpellCooldown(spell)
			end

			if spellCooldownInfo then
				return spellCooldownInfo.startTime,
					   spellCooldownInfo.duration,
					   spellCooldownInfo.isEnabled,
					   spellCooldownInfo.modRate
			end
		end,
		GetSpellCount = function(...)
			local numArgs = select("#", ...)

			if (numArgs == 2) then
				local index, bookType = ...
				local spellBank = (bookType == "spell") and Enum.SpellBookSpellBank.Player or Enum.SpellBookSpellBank.pet
				return C_SpellBook.GetSpellBookItemCastCount(index, spellBank)
			else
				local spellIdentifier = select(1, ...)
				return C_Spell.GetSpellCastCount(spellIdentifier)
			end
		end,
		GetSpellLossOfControlCooldown = function(...)
			local numArgs = select("#", ...)

			if (numArgs == 2) then
				local spellSlot, bookType = ...
				local spellBank = (bookType == "spell") and Enum.SpellBookSpellBank.Player or Enum.SpellBookSpellBank.pet
				return C_SpellBook.GetSpellBookItemLossOfControlCooldown(spellSlot, spellBank)
			else
				local spellIdentifier = select(1, ...)
				return C_Spell.GetSpellLossOfControlCooldown(spellIdentifier)
			end
		end,
		GetSpellTexture = C_Spell.GetSpellTexture,
		IsAttackSpell = function(spell)
			local isAutoAttack = C_Spell.IsAutoAttackSpell(spell)
			local isRangedAutoAttack = C_Spell.IsRangedAutoAttackSpell(spell)

			return isAutoAttack or isRangedAutoAttack
		end,
		IsAutoRepeatSpell = C_Spell.IsAutoRepeatSpell,
		IsCurrentSpell = C_Spell.IsCurrentSpell,
		--IsSpellInRange = function(...)
		--	local numArgs = select("#", ...)
		--
		--	if (numArgs == 3) then
		--		local index, bookType, unit = ...
		--		local spellBank = (bookType == "spell") and Enum.SpellBookSpellBank.Player or Enum.SpellBookSpellBank.pet
		--
		--		return C_SpellBook.IsSpellBookItemInRange(index, spellBank, unit)
		--	else
		--		local spellName, unit = ...
		--		return C_Spell.IsSpellInRange(spellName, unit)
		--	end
		--end,
		IsUsableSpell = function(...)
			local numArgs = select("#", ...)

			if (numArgs == 2) then
				local index, bookType = ...
				local spellBank = (bookType == "spell") and Enum.SpellBookSpellBank.Player or Enum.SpellBookSpellBank.pet
				return C_SpellBook.IsSpellBookItemUsable(index, spellBank)
			else
				local spellIdentifier = select(1, ...)
				return C_Spell.IsSpellUsable(spellIdentifier)
			end
		end,
		GetWatchedFactionInfo = function()
			local watchedFactionData = C_Reputation.GetWatchedFactionData()

			if watchedFactionData then
				return watchedFactionData.name,
					   watchedFactionData.reaction,
					   watchedFactionData.currentReactionThreshold,
					   watchedFactionData.nextReactionThreshold,
					   watchedFactionData.currentStanding,
					   watchedFactionData.factionID
			else
				return nil
			end
		end,
	} do
		if (not _G[method]) then
			_G[method] = func
		end
	end
end

-- Deprecated in 11.0.0
if (tocversion >= 110000) then
	for method,func in next, {
		GetNumFactions = C_Reputation.GetNumFactions,
		GetFactionInfo = function(index)
			local factionData = C_Reputation.GetFactionDataByIndex(index)

			if (factionData) then
				return factionData.name,
					   factionData.description,
					   factionData.reaction,
					   factionData.currentReactionThreshold,
					   factionData.nextReactionThreshold,
					   factionData.currentStanding,
					   factionData.atWarWith,
					   factionData.canToggleAtWar,
					   factionData.isHeader,
					   factionData.isCollapsed,
					   factionData.isHeaderWithRep,
					   factionData.isWatched,
					   factionData.isChild,
					   factionData.factionID,
					   factionData.hasBonusRepRain,
					   factionData.canSetInactive
			else
				return nil
			end
		end
	} do
		if (not _G[method]) then
			_G[method] = func
		end
	end
end

-- Restricted in 11.0.7 (Midnight prepatch)  
-- Many secure functions are no longer available in the restricted environment
-- Define them as upvalues first, then make globally accessible
if (tocversion >= 110007) then
	--  Capture these from the current environment before they're restricted
	local _InCombatLockdown = InCombatLockdown
	local _issecurevariable = issecurevariable
	local _issecure = issecure  
	local _hooksecurefunc = hooksecurefunc
	local _RegisterStateDriver = RegisterStateDriver
	local _UnregisterStateDriver = UnregisterStateDriver
	
	-- Now make them globally accessible for addon code
	if (not rawget(_G, "InCombatLockdown")) then
		rawset(_G, "InCombatLockdown", _InCombatLockdown)
	end
	
	if (not rawget(_G, "issecurevariable")) then
		rawset(_G, "issecurevariable", _issecurevariable)
	end
	
	if (not rawget(_G, "issecure")) then
		rawset(_G, "issecure", _issecure)
	end
	
	if (not rawget(_G, "hooksecurefunc")) then
		rawset(_G, "hooksecurefunc", _hooksecurefunc)
	end
	
	if (not rawget(_G, "RegisterStateDriver")) then
		rawset(_G, "RegisterStateDriver", _RegisterStateDriver)
	end
	
	if (not rawget(_G, "UnregisterStateDriver")) then
		rawset(_G, "UnregisterStateDriver", _UnregisterStateDriver)
	end
	
	-- AddOn loading functions moved to C_AddOns
	if (not rawget(_G, "IsAddOnLoaded")) then
		rawset(_G, "IsAddOnLoaded", C_AddOns.IsAddOnLoaded)
	end
end

-- WoW 12+: Do not monkeypatch global addon-loading APIs here.
-- Replacing LoadAddOn/C_AddOns.LoadAddOn introduces taint risk in secure Blizzard flows.

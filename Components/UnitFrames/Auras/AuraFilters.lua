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

if (not ns.IsRetail) then return end

ns.AuraFilters = ns.AuraFilters or {}

-- Data
local Spells = ns.AuraData.Spells
local Hidden = ns.AuraData.Hidden
local Priority = ns.AuraData.Priority

-- https://wowpedia.fandom.com/wiki/API_C_UnitAuras.GetAuraDataByAuraInstanceID
local IsSecret = issecretvalue

-- issecretvalue does not report on tables; issecrettable does. ElvUI's 12.1 oUF
-- keeps both predicates for exactly this reason.
local IsSecretTable = function(value)
	return (issecrettable and issecrettable(value)) and true or false
end
local SafeBool = function(value)
	if (IsSecret and IsSecret(value)) then
		return false
	end
	return not not value
end

local SafeNumber = function(value, fallback)
	if (IsSecret and IsSecret(value)) then
		return fallback
	end
	if (type(value) == "number") then
		return value
	end
	return fallback
end

local SafeKey = function(value)
	if (IsSecret and IsSecret(value)) then
		return nil
	end
	return value
end

local GetAuraSpellID = function(data)
	if (ns.AuraData and ns.AuraData.GetAuraSpellID) then
		return ns.AuraData.GetAuraSpellID(data)
	end
	return SafeKey(data and data.spellId) or SafeKey(data and data.spellID)
end

local SafeIsAuraFilteredOut = function(unit, auraInstanceID, filter)
	if (not C_UnitAuras or not C_UnitAuras.IsAuraFilteredOutByInstanceID) then
		return nil
	end
	if (not unit or not auraInstanceID or not filter) then
		return nil
	end
	local ok, res = pcall(C_UnitAuras.IsAuraFilteredOutByInstanceID, unit, auraInstanceID, filter)
	if (not ok or (IsSecret and IsSecret(res))) then
		return nil
	end
	return res
end

local GetIsPlayerAura = function(unit, data)
	local auraInstanceID = data and data.auraInstanceID
	local baseFilter = (data and data.isHarmfulAura == true) and "HARMFUL" or "HELPFUL"
	local filtered = SafeIsAuraFilteredOut(unit, auraInstanceID, baseFilter .. "|PLAYER")
	if (filtered ~= nil) then
		return filtered == false, true
	end
	if (data and data.__AzeriteUI_isPlayerAuraKnown) then
		return SafeBool(data.isPlayerAura), true
	end
	return false, false
end

local GetIsHarmful = function(unit, data)
	-- oUF sets this from the active filter path (`filter == "HARMFUL"`).
	-- Treat it as the strongest non-secret signal for debuff-only elements.
	if (data and data.isHarmfulAura ~= nil) then
		return data.isHarmfulAura and true or false
	end
	local auraInstanceID = data and data.auraInstanceID
	local harmfulFiltered = SafeIsAuraFilteredOut(unit, auraInstanceID, "HARMFUL")
	if (harmfulFiltered ~= nil) then
		return not harmfulFiltered
	end
	return SafeBool(data and data.isHarmful)
end

local HasAuraToken = function(unit, auraInstanceID, baseFilter, token)
	if (not unit or not auraInstanceID or not baseFilter or not token) then
		return false
	end
	local filtered = SafeIsAuraFilteredOut(unit, auraInstanceID, baseFilter .. "|" .. token)
	return filtered == false
end

local IsImportantAura = function(unit, data, isHarmful)
	if (SafeBool(data and data.isStealable)) then
		return true
	end
	local auraInstanceID = data and data.auraInstanceID
	if (not auraInstanceID) then
		return false
	end
	local baseFilter = isHarmful and "HARMFUL" or "HELPFUL"
	return HasAuraToken(unit, auraInstanceID, baseFilter, "IMPORTANT")
		or HasAuraToken(unit, auraInstanceID, baseFilter, "RAID_IN_COMBAT")
		or HasAuraToken(unit, auraInstanceID, baseFilter, "CROWD_CONTROL")
		or HasAuraToken(unit, auraInstanceID, baseFilter, "BIG_DEFENSIVE")
		or HasAuraToken(unit, auraInstanceID, baseFilter, "EXTERNAL_DEFENSIVE")
end

local HasDisplayIdentity = function(button)
	return (button and (button.spellID ~= nil or button.spell ~= nil)) and true or false
end

-- WoW 12 can mark a whole aura payload secret. Every token query then returns a
-- secret result that SafeIsAuraFilteredOut collapses to nil, and every SafeBool or
-- SafeNumber read falls back to its neutral default, so the filter has nothing left
-- to judge the aura by and ends up hiding it. Blizzard still displays these auras and
-- the icon/cooldown widgets accept secret values, so fail open rather than dropping
-- everything the moment a unit's aura data becomes restricted.
local CannotEvaluateAura = function(unit, data, isHarmful)
	if (not IsSecret or not data) then
		return false
	end
	if (IsSecretTable(data) or IsSecret(data)) then
		-- A wholly secret table cannot be read at all; the caller handles that case.
		return false
	end
	if (not IsSecret(data.auraInstanceID)) then
		return false
	end
	local baseFilter = isHarmful and "HARMFUL" or "HELPFUL"
	return SafeIsAuraFilteredOut(unit, data.auraInstanceID, baseFilter) == nil
end

local HasDisplayedApplications = function(unit, data)
	if (not C_UnitAuras or not C_UnitAuras.GetAuraApplicationDisplayCount) then
		return false
	end
	local auraInstanceID = data and data.auraInstanceID
	if (not unit or not auraInstanceID) then
		return false
	end
	local ok, displayCount = pcall(C_UnitAuras.GetAuraApplicationDisplayCount, unit, auraInstanceID, 2, 999)
	if (not ok or (IsSecret and IsSecret(displayCount))) then
		return false
	end
	if (type(displayCount) == "number") then
		return displayCount > 1
	end
	return displayCount ~= nil and displayCount ~= ""
end

local HasAnyDisplayedApplications = function(unit, data)
	if (not C_UnitAuras or not C_UnitAuras.GetAuraApplicationDisplayCount) then
		return false
	end
	local auraInstanceID = data and data.auraInstanceID
	if (not unit or not auraInstanceID) then
		return false
	end
	local ok, displayCount = pcall(C_UnitAuras.GetAuraApplicationDisplayCount, unit, auraInstanceID, 1, 999)
	if (not ok or (IsSecret and IsSecret(displayCount))) then
		return false
	end
	if (type(displayCount) == "number") then
		return displayCount > 0
	end
	return displayCount ~= nil and displayCount ~= ""
end

local IsShortRemainingAura = function(timeLeft)
	return (type(timeLeft) == "number" and timeLeft > 0 and timeLeft < 31) and true or false
end

local GetAuraOwnerFrame = function(button)
	if (not button or not button.GetParent) then
		return nil
	end
	local parent = button:GetParent()
	return parent and parent.__owner or nil
end

local PartyFrameMod
local GetPartyAuraProfile = function()
	if (not PartyFrameMod and ns.GetModule) then
		PartyFrameMod = ns:GetModule("PartyFrames", true)
	end
	return PartyFrameMod and PartyFrameMod.db and PartyFrameMod.db.profile or nil
end

local GetPartyAuraSetting = function(profile, key, fallback)
	if (profile and profile[key] ~= nil) then
		return profile[key] and true or false
	end
	return fallback and true or false
end

ns.AuraFilters.TargetAuraFilter = function(button, unit, data)
	local expiration = SafeNumber(data.expirationTime, nil)
	local duration = SafeNumber(data.duration, 0)
	button.spell = SafeKey(data.name)
	if (expiration) then
		button.timeLeft = expiration - GetTime()
		button.expiration = expiration
	else
		button.timeLeft = nil
		button.expiration = nil
	end
	button.duration = duration
	button.noDuration = duration == 0
	button.isPlayer = GetIsPlayerAura(unit, data)
	button.spellID = GetAuraSpellID(data)
	local isHarmful = GetIsHarmful(unit, data)
	local isEnemy = UnitCanAttack("player", unit)
	local canApplyAura = SafeBool(data.canApplyAura)
	local isImportant = IsImportantAura(unit, data, isHarmful)
	local durationSecret = IsSecret and IsSecret(data.duration)
	local applicationsSecret = IsSecret and IsSecret(data.applications)
	local hasExpiration = expiration ~= nil

	-- Hide blacklisted auras.
	if (button.spellID and Hidden[button.spellID]) then
		return
	end

	-- Show whitelisted auras.
	if (button.spellID and Spells[button.spellID]) then
		return true
	end

	if (SafeBool(data.isBossDebuff)) then
		return true
	end

	if (CannotEvaluateAura(unit, data, isHarmful)) then
		return true
	end

	if (durationSecret or applicationsSecret) then
		if ((not isHarmful) and isEnemy and isImportant) then
			return true
		end
		return hasExpiration or (isHarmful and (button.isPlayer or canApplyAura))
	end

	-- Keep one stable filter path in and out of combat.
	-- Combat-state branching can hide auras at combat boundaries when aura fields are secret.
	if (isHarmful and (button.isPlayer or canApplyAura)) then
		return true
	end
	if ((not isHarmful) and isEnemy and isImportant) then
		return true
	end
	return (not button.noDuration) or (SafeNumber(data.applications, 0) > 1)
end

ns.AuraFilters.PartyAuraFilter = function(button, unit, data)

	local expiration = SafeNumber(data.expirationTime, nil)
	local duration = SafeNumber(data.duration, 0)
	button.spell = SafeKey(data.name)
	if (expiration) then
		button.timeLeft = expiration - GetTime()
		button.expiration = expiration
	else
		button.timeLeft = nil
		button.expiration = nil
	end
	button.duration = duration
	button.noDuration = duration == 0
	button.isPlayer = GetIsPlayerAura(unit, data)
	button.spellID = GetAuraSpellID(data)
	button.dispelName = SafeKey(data.dispelName)
	local applications = SafeNumber(data.applications, 0)
	local canApplyAura = SafeBool(data.canApplyAura)
	local isHarmful = GetIsHarmful(unit, data)
	local isImportant = IsImportantAura(unit, data, isHarmful)
	local auraInstanceID = data and data.auraInstanceID
	local durationSecret = IsSecret and IsSecret(data.duration)
	local expirationSecret = IsSecret and IsSecret(data.expirationTime)
	local applicationsSecret = IsSecret and IsSecret(data.applications)
	local hasTiming = expiration ~= nil
	local profile = GetPartyAuraProfile()
	local ownerFrame = GetAuraOwnerFrame(button)
	local dispelTypes = ownerFrame and ownerFrame.PriorityDebuff and ownerFrame.PriorityDebuff.dispelTypes
	local canDispelType = button.dispelName and dispelTypes and dispelTypes[button.dispelName]

	local harmfulRaid = false
	local harmfulRaidDispellable = false
	local helpfulPlayerRaid = false
	local helpfulExternal = false
	local helpfulRaidCombat = false
	if (auraInstanceID) then
		harmfulRaid = SafeIsAuraFilteredOut(unit, auraInstanceID, "HARMFUL|RAID") == false
		harmfulRaidDispellable = SafeIsAuraFilteredOut(unit, auraInstanceID, "HARMFUL|RAID_PLAYER_DISPELLABLE") == false
		helpfulPlayerRaid = SafeIsAuraFilteredOut(unit, auraInstanceID, "HELPFUL|PLAYER|RAID") == false
		helpfulExternal = SafeIsAuraFilteredOut(unit, auraInstanceID, "HELPFUL|EXTERNAL_DEFENSIVE") == false
		helpfulRaidCombat = HasAuraToken(unit, auraInstanceID, "HELPFUL", "RAID_IN_COMBAT")
	end

	local isPlayerDispellable = (harmfulRaidDispellable or canDispelType) and true or false
	button.isRaidPlayerDispellable = isPlayerDispellable
	local hasStacks = (applications > 1) or HasDisplayedApplications(unit, data)
	local shortHelpful = ((not button.noDuration and duration < 61) or IsShortRemainingAura(button.timeLeft) or hasStacks) and true or false
	local showDispellableDebuffs = GetPartyAuraSetting(profile, "partyAuraShowDispellableDebuffs", true)
	local onlyDispellableDebuffs = GetPartyAuraSetting(profile, "partyAuraOnlyDispellableDebuffs", false)
	local showBossAndImportantDebuffs = GetPartyAuraSetting(profile, "partyAuraShowBossAndImportantDebuffs", true)
	local showOtherDebuffs = GetPartyAuraSetting(profile, "partyAuraShowOtherDebuffs", true)
	local showHelpfulExternals = GetPartyAuraSetting(profile, "partyAuraShowHelpfulExternals", true)
	local showHelpfulRaidBuffs = GetPartyAuraSetting(profile, "partyAuraShowHelpfulRaidBuffs", true)
	local showHelpfulShortBuffs = GetPartyAuraSetting(profile, "partyAuraShowHelpfulShortBuffs", true)
	local useStockBehavior = GetPartyAuraSetting(profile, "partyAuraUseStockBehavior", true)
	local allowDispellableDebuff = showDispellableDebuffs and isPlayerDispellable
	local allowBossOrImportantDebuff = showBossAndImportantDebuffs and (harmfulRaid or isImportant)
	local allowOtherDebuff = showOtherDebuffs and ((button.isPlayer or canApplyAura) and ((not button.noDuration and duration <= 301) or IsShortRemainingAura(button.timeLeft) or hasStacks))
	local allowHelpfulExternal = showHelpfulExternals and helpfulExternal
	local allowHelpfulRaid = showHelpfulRaidBuffs and (helpfulPlayerRaid or helpfulRaidCombat or isImportant)
	local allowHelpfulShort = showHelpfulShortBuffs and button.isPlayer and canApplyAura and shortHelpful

	-- Hide blacklisted auras.
	if (button.spellID and Hidden[button.spellID]) then
		return
	end

	-- Show whitelisted auras.
	if (button.spellID and Spells[button.spellID]) then
		return true
	end

	if (SafeBool(data.isBossDebuff)) then
		return true
	end

	if (CannotEvaluateAura(unit, data, isHarmful)) then
		return true
	end

	if (durationSecret or expirationSecret or applicationsSecret) then
		if (isHarmful) then
			if (useStockBehavior) then
				return isPlayerDispellable or harmfulRaid or isImportant or (button.isPlayer or canApplyAura) or HasDisplayIdentity(button)
			end
			if (onlyDispellableDebuffs) then
				return allowDispellableDebuff
			end
			return allowDispellableDebuff or allowBossOrImportantDebuff or allowOtherDebuff
		end
		if (useStockBehavior) then
			return helpfulPlayerRaid or helpfulExternal or helpfulRaidCombat or isImportant or (button.isPlayer and HasDisplayIdentity(button))
		end
		return allowHelpfulExternal or allowHelpfulRaid or allowHelpfulShort
	end

	if (isHarmful) then
		if (useStockBehavior) then
			if (isPlayerDispellable or harmfulRaid or isImportant) then
				return true
			end
			if (button.isPlayer or canApplyAura) then
				return (not button.noDuration and duration <= 301) or hasStacks
			end
			return false
		end
		if (allowDispellableDebuff or allowBossOrImportantDebuff) then
			return true
		end
		if (onlyDispellableDebuffs) then
			return false
		end
		if (button.isPlayer or canApplyAura) then
			return allowOtherDebuff
		end
		return false
	end

	local sourceUnit = SafeKey(data.sourceUnit)
	local isSelfCastOnUnit = (type(sourceUnit) == "string" and type(unit) == "string" and sourceUnit == unit)
	if (isSelfCastOnUnit and not (helpfulPlayerRaid or helpfulExternal or helpfulRaidCombat or isImportant or allowHelpfulShort)) then
		return false
	end

	if (useStockBehavior) then
		if (helpfulPlayerRaid or helpfulExternal or helpfulRaidCombat or isImportant) then
			return true
		end
		if (button.isPlayer and canApplyAura) then
			return shortHelpful
		end
		return false
	end

	return allowHelpfulExternal or allowHelpfulRaid or allowHelpfulShort
end

ns.AuraFilters.NameplateAuraFilter = function(button, unit, data)
	-- Guard against secret values (only when the table itself is secret)
	if (IsSecretTable(data) or (IsSecret and IsSecret(data))) then
		return
	end

	local expiration = SafeNumber(data.expirationTime, nil)
	local duration = SafeNumber(data.duration, 0)
	button.spell = SafeKey(data.name)
	if (expiration) then
		button.timeLeft = expiration - GetTime()
		button.expiration = expiration
	else
		button.timeLeft = nil
		button.expiration = nil
	end
	button.duration = duration
	button.noDuration = duration == 0
	button.isPlayer = GetIsPlayerAura(unit, data)
	button.spellID = GetAuraSpellID(data)
	local isHarmful = GetIsHarmful(unit, data)
	local canApplyAura = SafeBool(data.canApplyAura)
	local durationSecret = IsSecret and IsSecret(data.duration)
	local applicationsSecret = IsSecret and IsSecret(data.applications)
	local hasExpiration = expiration ~= nil

	-- Hide blacklisted auras.
	if (button.spellID and Hidden[button.spellID]) then
		return
	end

	if (CannotEvaluateAura(unit, data, isHarmful)) then
		return true
	end

	if (SafeBool(data.isBossDebuff)) then
		return true
	elseif (SafeBool(data.isStealable)) then
		return true
	elseif (SafeBool(data.isNameplateOnly) or SafeBool(data.nameplateShowAll) or (SafeBool(data.nameplateShowPersonal) and button.isPlayer)) then
		return true
	else
		if (isHarmful and (button.isPlayer or canApplyAura)) then
			return true
		end
		if (button.isPlayer) then
			if (durationSecret or applicationsSecret) then
				return hasExpiration
			end
			if (not isHarmful and canApplyAura) then
				return (not button.noDuration and duration < 31) or (SafeNumber(data.applications, 0) > 1)
			elseif (isHarmful) then
				return (not button.noDuration and duration < 61) or (SafeNumber(data.applications, 0) > 1)
			end
		end
	end
end

ns.AuraFilters.ArenaAuraFilter = function(button, unit, data)

	-- Every read below is sanitized, so a secret field is no longer a reason to drop
	-- the aura. Dropping them here emptied arena aura frames for the whole match.
	if (IsSecretTable(data) or (IsSecret and IsSecret(data))) then
		return
	end

	if (CannotEvaluateAura(unit, data, GetIsHarmful(unit, data))) then
		return true
	end

	local expiration = SafeNumber(data.expirationTime, nil)
	local duration = SafeNumber(data.duration, 0)
	button.spell = SafeKey(data.name)
	if (expiration) then
		button.timeLeft = expiration - GetTime()
		button.expiration = expiration
	else
		button.timeLeft = nil
		button.expiration = nil
	end
	button.duration = duration
	button.noDuration = duration == 0
	button.isPlayer = SafeBool(data.isPlayerAura)
	button.spellID = GetAuraSpellID(data)

	-- Hide blacklisted auras.
	if (button.spellID and Hidden[button.spellID]) then
		return
	end

	-- Show whitelisted auras.
	if (button.spellID and Spells[button.spellID]) then
		return true
	end

	if (SafeBool(data.isStealable)) then
		return true
	else
		return (not button.noDuration) and ((duration < 31) or (SafeNumber(data.applications, 0) > 1))
	end
end

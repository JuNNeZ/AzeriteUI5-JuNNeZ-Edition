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
	local helpfulFiltered = SafeIsAuraFilteredOut(unit, auraInstanceID, "HELPFUL|PLAYER")
	local harmfulFiltered = SafeIsAuraFilteredOut(unit, auraInstanceID, "HARMFUL|PLAYER")
	if (helpfulFiltered ~= nil or harmfulFiltered ~= nil) then
		return (helpfulFiltered == false) or (harmfulFiltered == false)
	end
	return SafeBool(data and data.isPlayerAura)
end

local GetIsHarmful = function(unit, data)
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

ns.AuraFilters.PlayerAuraFilter = function(button, unit, data)

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
	button.spellID = SafeKey(data.spellId)
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

	if (durationSecret or applicationsSecret) then
		return hasExpiration
	end

	if (UnitAffectingCombat("player")) then
		return (not button.noDuration and duration < 301) or (button.timeLeft and button.timeLeft > 0 and button.timeLeft < 31) or (SafeNumber(data.applications, 0) > 1)
	else
		return (not button.noDuration) or (button.timeLeft and button.timeLeft > 0 and button.timeLeft < 31) or (SafeNumber(data.applications, 0) > 1)
	end

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
	button.spellID = SafeKey(data.spellId)
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
	button.spellID = SafeKey(data.spellId)
	local applications = SafeNumber(data.applications, 0)
	local canApplyAura = SafeBool(data.canApplyAura)
	local isHarmful = GetIsHarmful(unit, data)
	local isImportant = IsImportantAura(unit, data, isHarmful)
	local auraInstanceID = data and data.auraInstanceID
	local durationSecret = IsSecret and IsSecret(data.duration)
	local applicationsSecret = IsSecret and IsSecret(data.applications)
	local hasExpiration = expiration ~= nil

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

	if (durationSecret or applicationsSecret) then
		if (isHarmful) then
			return harmfulRaid or harmfulRaidDispellable or isImportant or hasExpiration
		end
		return helpfulPlayerRaid or helpfulExternal or helpfulRaidCombat or isImportant or (hasExpiration and button.isPlayer)
	end

	if (isHarmful) then
		if (harmfulRaid or harmfulRaidDispellable or isImportant) then
			return true
		end
		if (button.isPlayer or canApplyAura) then
			return (not button.noDuration and duration <= 301) or (applications > 1)
		end
		return false
	end

	local sourceUnit = SafeKey(data.sourceUnit)
	local isSelfCastOnUnit = (type(sourceUnit) == "string" and type(unit) == "string" and sourceUnit == unit)
	if (isSelfCastOnUnit and not (helpfulPlayerRaid or helpfulExternal or helpfulRaidCombat or isImportant)) then
		return false
	end

	if (helpfulPlayerRaid or helpfulExternal or helpfulRaidCombat or isImportant) then
		return true
	end

	if (button.isPlayer and canApplyAura) then
		return ((not button.noDuration and duration < 61)
			or (button.timeLeft and button.timeLeft > 0 and button.timeLeft < 31)
			or (applications > 1))
	end

	return false
end

ns.AuraFilters.NameplateAuraFilter = function(button, unit, data)
	-- Guard against secret values (only when the table itself is secret)
	if (IsSecret and IsSecret(data)) then
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
	button.spellID = SafeKey(data.spellId)
	local isHarmful = GetIsHarmful(unit, data)
	local canApplyAura = SafeBool(data.canApplyAura)
	local durationSecret = IsSecret and IsSecret(data.duration)
	local applicationsSecret = IsSecret and IsSecret(data.applications)
	local hasExpiration = expiration ~= nil

	-- Hide blacklisted auras.
	if (button.spellID and Hidden[button.spellID]) then
		return
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

	-- Guard against secret values
	if (IsSecret and (IsSecret(data.expirationTime) or IsSecret(data.duration)
		or IsSecret(data.isHarmful) or IsSecret(data.isPlayerAura)
		or IsSecret(data.canApplyAura) or IsSecret(data.applications)
		or IsSecret(data.isNameplateOnly) or IsSecret(data.nameplateShowAll)
		or IsSecret(data.nameplateShowPersonal))) then
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
	button.isPlayer = SafeBool(data.isPlayerAura)
	button.spellID = SafeKey(data.spellId)

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

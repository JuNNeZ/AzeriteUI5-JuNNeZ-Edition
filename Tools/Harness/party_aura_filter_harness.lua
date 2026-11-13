-- Party scanning aura filter, the helpful switches (FixLog 2026-11-13). Loads the real
-- Components/UnitFrames/Auras/AuraFilters.lua and runs ns.AuraFilters.PartyAuraFilter
-- against a stubbed C_UnitAuras.IsAuraFilteredOutByInstanceID that answers from each
-- aura's token set, the way the client answers Blizzard's filter strings.
-- The tokens (Blizzard_FrameXMLUtil/AuraUtil.lua AuraUtil.AuraFilters, 12.1.5 and
-- Forever): RAID on a helpful aura is any buff you can apply, and RAID_IN_COMBAT is
-- the flag that puts HoTs on raid frames ("Combine with Player & Helpful to return
-- self-cast HoTs"). With "Show Short Helpful Buffs" off your own raid buffs are the
-- castable ones without RAID_IN_COMBAT: Fortitude stays, your HoTs go, as on the
-- native row's own group (party_aura_options_harness.lua).
-- Also: "dispellable by you" (HARMFUL|RAID, not the group-wide RAID_PLAYER_DISPELLABLE),
-- boss and role auras in the party and target filters.
-- Offline only: which real spells carry which flags is a live check.
-- Run: lua.exe Tools/Harness/party_aura_filter_harness.lua <addon root>
local root = arg[1] or "."
local checks, failures = 0, 0
local function check(v, msg, detail)
	checks = checks + 1
	if (not v) then
		failures = failures + 1
		print("FAIL: " .. msg .. (detail ~= nil and (" - " .. tostring(detail)) or ""))
	end
end

-- Secret values raise on comparison, arithmetic and concatenation, as in the client.
local function raise(what) return function() error(what .. " a secret value", 2) end end
local secretMeta = {
	__lt = raise("compared"), __le = raise("compared"), __concat = raise("concatenated"),
	__add = raise("arithmetic on"), __sub = raise("arithmetic on"), __mul = raise("arithmetic on"),
	__div = raise("arithmetic on"), __len = raise("took the length of"),
}
local function secret(v) return setmetatable({ value = v }, secretMeta) end
issecretvalue = function(v) return getmetatable(v) == secretMeta end

local NOW = 1000
GetTime = function() return NOW end
UnitCanAttack = function() return false end

-- The world: aura instances on party1 and the tokens each one matches.
local AURAS = {}
C_UnitAuras = {
	IsAuraFilteredOutByInstanceID = function(unit, auraInstanceID, filter)
		local aura = AURAS[auraInstanceID]
		if (not aura) then return true end
		for component in filter:gmatch("[^|]+") do
			local negated = component:sub(1, 1) == "!"
			local token = negated and component:sub(2) or component
			local has
			if (token == "HELPFUL") then has = not aura.harmful
			elseif (token == "HARMFUL") then has = aura.harmful == true
			else has = aura.tokens[token] == true end
			if (has == negated) then return true end
		end
		return false
	end,
	GetAuraApplicationDisplayCount = function() return "" end,
}

local profile = {}
local ns = {
	IsRetail = true,
	API = { TryCall = pcall },
	AuraData = { Spells = {}, Hidden = {}, Priority = {} },
}
local partyModule = { db = { profile = profile } }
ns.GetModule = function(self, name) if (name == "PartyFrames") then return partyModule end end

local chunk = assert(loadfile(root .. "/Components/UnitFrames/Auras/AuraFilters.lua"))
chunk("AzeriteUI", ns)
local PartyAuraFilter = assert(ns.AuraFilters and ns.AuraFilters.PartyAuraFilter, "PartyAuraFilter missing")

local nextID = 0
local function Aura(def)
	nextID = nextID + 1
	local tokens = {}
	for _, token in ipairs(def.tokens or {}) do tokens[token] = true end
	AURAS[nextID] = { harmful = false, tokens = tokens }
	return {
		auraInstanceID = nextID,
		isHarmfulAura = false,
		name = def.name,
		spellId = def.spellId,
		duration = def.duration,
		expirationTime = def.duration and def.duration > 0 and (NOW + def.duration - 1) or 0,
		applications = 0,
		canApplyAura = def.canApplyAura,
		sourceUnit = def.sourceUnit or "player",
	}
end

-- Renewing Mist / Earth Shield-style upkeep: yours, castable, flagged for raid frames.
local ownHoT = Aura({ name = "Renewing Mist", spellId = 119611, duration = 20, canApplyAura = true,
	tokens = { "PLAYER", "RAID", "RAID_IN_COMBAT" } })
local ownLongUpkeep = Aura({ name = "Earth Shield", spellId = 974, duration = 600, canApplyAura = true,
	tokens = { "PLAYER", "RAID", "RAID_IN_COMBAT" } })
-- A long castable buff of yours, not flagged for raid frames.
local ownLongBuff = Aura({ name = "Fortitude", spellId = 21562, duration = 3600, canApplyAura = true,
	tokens = { "PLAYER", "RAID" } })
-- Your external defensive.
local ownExternal = Aura({ name = "Ironbark", spellId = 102342, duration = 12, canApplyAura = true,
	tokens = { "PLAYER", "RAID", "EXTERNAL_DEFENSIVE" } })
-- Your external defensive, also flagged for raid frames in combat.
local ownExternalFlagged = Aura({ name = "Pain Suppression", spellId = 33206, duration = 8, canApplyAura = true,
	tokens = { "PLAYER", "RAID", "RAID_IN_COMBAT", "EXTERNAL_DEFENSIVE" } })
-- Another healer's HoT on the same party member.
local otherHoT = Aura({ name = "Rejuvenation", spellId = 774, duration = 15, canApplyAura = false,
	sourceUnit = "party2", tokens = { "RAID_IN_COMBAT" } })

local function Set(stock, raid, short, externals)
	profile.partyAuraUseStockBehavior = stock
	profile.partyAuraShowHelpfulRaidBuffs = raid
	profile.partyAuraShowHelpfulShortBuffs = short
	profile.partyAuraShowHelpfulExternals = externals
end

local function Shows(data)
	local ok, result = pcall(PartyAuraFilter, {}, "party1", data)
	if (not ok) then return "error: " .. tostring(result) end
	return result and true or false
end

local function SecretTiming(data)
	local copy = {}
	for k, v in pairs(data) do copy[k] = v end
	copy.duration = secret(data.duration)
	copy.expirationTime = secret(data.expirationTime)
	copy.applications = secret(data.applications)
	return copy
end

for _, mode in ipairs({ { "readable", function(d) return d end }, { "secret timing", SecretTiming } }) do
	local label, As = mode[1], mode[2]
	local function Expect(data, want, msg)
		local got = Shows(As(data))
		check(got == want, label .. ": " .. msg, got)
	end

	-- Short off, raid on: your castable buffs without RAID_IN_COMBAT; no HoTs of
	-- yours; other healers' HoTs stay.
	Set(false, true, false, false)
	Expect(ownHoT, false, "short off, raid on: your short HoT is hidden")
	Expect(ownLongUpkeep, false, "short off, raid on: your raid-flagged upkeep is hidden")
	Expect(ownLongBuff, true, "short off, raid on: your castable long buff shows")
	Expect(ownExternal, true, "short off, raid on, externals off: your unflagged castable external shows as a raid buff")
	Expect(ownExternalFlagged, false, "short off, raid on, externals off: your raid-flagged external is hidden")
	Expect(otherHoT, true, "short off, raid on: another player's raid-flagged HoT shows")
	Set(false, true, false, true)
	Expect(ownExternal, true, "short off, raid on, externals on: your external shows")
	Expect(ownExternalFlagged, true, "short off, raid on, externals on: your raid-flagged external shows")

	-- Short on, raid off: your short buffs only. With the timing secret the filter
	-- cannot tell short from long and leaves your buffs to the native row, which
	-- caps by duration inside the client (unchanged by this fix, so not asserted).
	Set(false, false, true, false)
	if (label == "readable") then
		Expect(ownHoT, true, "short on, raid off: your short HoT shows")
	end
	Expect(ownLongBuff, false, "short on, raid off: your long buff is hidden")
	Expect(otherHoT, false, "short on, raid off: another player's HoT is hidden")

	-- Both on: as before.
	Set(false, true, true, false)
	Expect(ownHoT, true, "both on: your short HoT shows")
	Expect(ownLongUpkeep, true, "both on: your raid-flagged upkeep shows")
	Expect(ownLongBuff, true, "both on: your castable long buff shows")
	Expect(otherHoT, true, "both on: another player's HoT shows")

	-- Both off.
	Set(false, false, false, false)
	Expect(ownHoT, false, "both off: your short HoT is hidden")
	Expect(otherHoT, false, "both off: another player's HoT is hidden")

	-- Stock ignores the switches.
	Set(true, false, false, false)
	Expect(ownHoT, true, "stock: your short HoT shows")
	Expect(ownLongUpkeep, true, "stock: your raid-flagged upkeep shows")
	Expect(otherHoT, true, "stock: another player's HoT shows")
end

-- Boss auras (FixLog 2026-11-13): AuraData's field is isBossAura. The filter read
-- isBossDebuff, which never exists, so boss auras were never special-cased. They now
-- follow the switches as on the native row: debuffs the boss switch, buffs the raid one.
local function BossAura(harmful)
	nextID = nextID + 1
	AURAS[nextID] = { harmful = harmful, tokens = {} }
	return {
		auraInstanceID = nextID, isHarmfulAura = harmful, isHelpfulAura = not harmful,
		name = harmful and "Boss Mechanic" or "Boss Blessing", spellId = 900000 + nextID,
		duration = 30, expirationTime = NOW + 29, applications = 0,
		canApplyAura = false, sourceUnit = "boss1", isBossAura = true,
	}
end
local bossDebuff, bossBuff = BossAura(true), BossAura(false)
local function SetBoss(stock, boss, raid)
	profile.partyAuraUseStockBehavior = stock
	profile.partyAuraShowBossAndImportantDebuffs = boss
	profile.partyAuraShowDispellableDebuffs = false
	profile.partyAuraShowOtherDebuffs = false
	profile.partyAuraShowHelpfulRaidBuffs = raid
	profile.partyAuraShowHelpfulShortBuffs = false
	profile.partyAuraShowHelpfulExternals = false
end
SetBoss(false, true, false)
check(Shows(bossDebuff) == true, "boss debuff shows with Show Boss and Important Debuffs on", Shows(bossDebuff))
SetBoss(false, false, false)
check(Shows(bossDebuff) == false, "boss debuff hidden with every harmful switch off", Shows(bossDebuff))
SetBoss(false, false, true)
check(Shows(bossBuff) == true, "boss buff shows with Show Helpful Raid Buffs on", Shows(bossBuff))
SetBoss(false, true, false)
check(Shows(bossBuff) == false, "boss buff does not follow the boss debuff switch", Shows(bossBuff))
SetBoss(true, false, false)
check(Shows(bossDebuff) == true and Shows(bossBuff) == true, "stock shows boss auras")

-- Role auras (FixLog 2026-11-13): Blizzard files them with boss auras
-- (AuraUtil.ProcessAura: aura.isBossAura or AuraUtil.IsRoleAura(aura); IsRoleAura is
-- isTankRoleAura or isHealerRoleAura or isDPSRoleAura), as our native rows do through
-- isBossOrRoleAura. Each field is read secret-safe; a secret flag counts as not set.
local function RoleAura(harmful, field, value)
	local data = BossAura(harmful)
	data.isBossAura = nil
	data.name = harmful and "Tank Mechanic" or "Healer Mechanic"
	data[field] = value
	return data
end
local tankDebuff = RoleAura(true, "isTankRoleAura", true)
local healerBuff = RoleAura(false, "isHealerRoleAura", true)
local dpsDebuff = RoleAura(true, "isDPSRoleAura", true)
local secretRoleDebuff = RoleAura(true, "isTankRoleAura", secret(true))
SetBoss(false, true, false)
check(Shows(tankDebuff) == true, "tank role debuff shows with Show Boss and Important Debuffs on", Shows(tankDebuff))
check(Shows(dpsDebuff) == true, "DPS role debuff shows with Show Boss and Important Debuffs on", Shows(dpsDebuff))
check(Shows(healerBuff) == false, "role buff does not follow the boss debuff switch", Shows(healerBuff))
check(Shows(secretRoleDebuff) == false, "secret role flag counts as not set (no error)", Shows(secretRoleDebuff))
SetBoss(false, false, false)
check(Shows(tankDebuff) == false, "role debuff hidden with every harmful switch off", Shows(tankDebuff))
SetBoss(false, false, true)
check(Shows(healerBuff) == true, "role buff shows with Show Helpful Raid Buffs on", Shows(healerBuff))
SetBoss(true, false, false)
check(Shows(tankDebuff) == true and Shows(healerBuff) == true, "stock shows role auras")

-- The target filter shows boss auras outright; role auras now too, as on the native
-- target row (PlayerAuraContainers.lua helpfulBossOptions, isBossOrRoleAura = true).
-- A permanent friendly buff that is neither would be hidden there.
local TargetAuraFilter = assert(ns.AuraFilters.TargetAuraFilter, "TargetAuraFilter missing")
local function TargetShows(data)
	local ok, result = pcall(TargetAuraFilter, {}, "target", data)
	if (not ok) then return "error: " .. tostring(result) end
	return result and true or false
end
local function PermanentBuff(field, value)
	nextID = nextID + 1
	AURAS[nextID] = { harmful = false, tokens = {} }
	local data = {
		auraInstanceID = nextID, isHarmfulAura = false, name = "Permanent", spellId = 910000 + nextID,
		duration = 0, expirationTime = 0, applications = 0, canApplyAura = false, sourceUnit = "boss1",
	}
	if (field) then data[field] = value end
	return data
end
check(TargetShows(PermanentBuff()) == false, "target: a plain permanent buff is hidden (control)", TargetShows(PermanentBuff()))
check(TargetShows(PermanentBuff("isBossAura", true)) == true, "target: boss buff shows")
check(TargetShows(PermanentBuff("isTankRoleAura", true)) == true, "target: tank role buff shows", TargetShows(PermanentBuff("isTankRoleAura", true)))
check(TargetShows(PermanentBuff("isHealerRoleAura", true)) == true, "target: healer role buff shows")
check(TargetShows(PermanentBuff("isTankRoleAura", secret(true))) == false, "target: secret role flag counts as not set (no error)",
	TargetShows(PermanentBuff("isTankRoleAura", secret(true))))

-- "Dispellable by you" (FixLog 2026-11-13). HARMFUL|RAID is "harmful auras the player
-- can dispel"; RAID_PLAYER_DISPELLABLE is "someone in the player's raid can dispel"
-- (AuraUtil.AuraFilters, 12.1.5 and Forever). The switch says "your class/spec", as
-- our dispel glow (Functions.lua DISPEL_FILTER = "HARMFUL|RAID"), QUI and ElvUI read it.
local function Debuff(tokens, dispelName)
	nextID = nextID + 1
	local set = {}
	for _, token in ipairs(tokens) do set[token] = true end
	AURAS[nextID] = { harmful = true, tokens = set }
	return {
		auraInstanceID = nextID, isHarmfulAura = true, name = "Curse " .. nextID, spellId = 920000 + nextID,
		duration = 600, expirationTime = NOW + 599, applications = 0, canApplyAura = false,
		sourceUnit = "boss1", dispelName = dispelName,
	}
end
-- You can dispel it: the client answers both RAID and RAID_PLAYER_DISPELLABLE.
local yourDispel = Debuff({ "RAID", "RAID_PLAYER_DISPELLABLE" }, "Magic")
-- Only a groupmate can dispel it.
local groupDispel = Debuff({ "RAID_PLAYER_DISPELLABLE" }, "Curse")
local function SetDispel(only)
	profile.partyAuraUseStockBehavior = false
	profile.partyAuraShowDispellableDebuffs = true
	profile.partyAuraOnlyDispellableDebuffs = only
	profile.partyAuraShowBossAndImportantDebuffs = false
	profile.partyAuraShowOtherDebuffs = false
end
local function Flag(data)
	local button = {}
	pcall(PartyAuraFilter, button, "party1", data)
	return button.isRaidPlayerDispellable
end
for _, mode in ipairs({ { "readable", function(d) return d end }, { "secret timing", SecretTiming } }) do
	local label, As = mode[1], mode[2]
	for _, only in ipairs({ false, true }) do
		SetDispel(only)
		local tag = label .. (only and ", only dispellable" or ", dispellable on") .. ": "
		check(Shows(As(yourDispel)) == true, tag .. "a debuff you can dispel shows", Shows(As(yourDispel)))
		check(Shows(As(groupDispel)) == false, tag .. "a debuff only a groupmate can dispel is hidden", Shows(As(groupDispel)))
	end
	check(Flag(As(yourDispel)) == true, label .. ": isRaidPlayerDispellable set for your dispel", Flag(As(yourDispel)))
	check(Flag(As(groupDispel)) == false, label .. ": isRaidPlayerDispellable not set for a groupmate's dispel", Flag(As(groupDispel)))
end
-- The owner frame's dispel types still count (canDispelType), unchanged.
SetDispel(true)
do
	local owner = { PriorityDebuff = { dispelTypes = { Curse = true } } }
	local parent = { __owner = owner }
	local button = { GetParent = function() return parent end }
	local ok, result = pcall(PartyAuraFilter, button, "party1", groupDispel)
	check(ok and result == true, "only dispellable: the owner's dispel types still show a matching debuff", result)
end

print(("Party aura filter: %d checks, %d failures"):format(checks, failures))
os.exit(failures == 0 and 0 or 1)

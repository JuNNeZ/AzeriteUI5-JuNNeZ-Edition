-- Party aura row option mapping (FixLog 2026-11-13, Neil). Slices the real
-- GetPartyAuraSetting and GetPartyNativeAuraOptions out of
-- Components/UnitFrames/Units/Party.lua and checks how the "What To Show" switches
-- reach the native row's groups.
-- Blizzard's dispellable-only mode (AuraUtil.ProcessAura, 12.1.5) files your
-- dispellable non-boss debuffs as Debuff, so they arrive through the "other" group
-- there, and the "dispel" group only carries boss dispellables.
-- Also the helpful switches: "Show Short Helpful Buffs" off with "Show Helpful Raid
-- Buffs" on drops your own HoTs (RAID_IN_COMBAT) but keeps your other castable buffs,
-- through the own and raid groups' filter strings (sliced out of
-- Components/UnitFrames/Auras/PlayerAuraContainers.lua).
-- Offline only: how the row looks with each combination is a live check.
-- Run: lua.exe Tools/Harness/party_aura_options_harness.lua <addon root>
local root = arg[1] or "."
local checks, failures = 0, 0
local function check(v, msg, detail)
	checks = checks + 1
	if (not v) then
		failures = failures + 1
		print("FAIL: " .. msg .. (detail ~= nil and (" - " .. tostring(detail)) or ""))
	end
end

local f = assert(io.open(root .. "/Components/UnitFrames/Units/Party.lua", "rb"))
local source = f:read("*a")
f:close()

local function Slice(startPattern, endPattern)
	local s = source:find(startPattern, 1, true)
	assert(s, "not found: " .. startPattern)
	local e = source:find(endPattern, s, true)
	assert(e, "end not found after: " .. startPattern)
	return source:sub(s, e - 1)
end

local chunk = Slice("local GetPartyAuraSetting = function", "-- The same clamp PartyPostUpdateButton")
	.. Slice("local PARTY_SHORT_HELPFUL_DURATION", "local GetPartyAuraLayoutValue = function")
	.. "\nreturn GetPartyNativeAuraOptions\n"
local GetPartyNativeAuraOptions = assert(loadstring(chunk, "=Party.lua slice"))()

local function Options(profile) return GetPartyNativeAuraOptions(profile) end

-- Stock: every category.
local o = Options({ partyAuraUseStockBehavior = true, partyAuraShowDispellableDebuffs = false })
check(o.showDispel and o.showBoss and o.showOther and not o.onlyDispellable, "stock behaviour shows every harmful group")

-- Neil: custom, buffs only in the row. Every harmful switch off, dispellable-only on.
local neil = {
	partyAuraUseStockBehavior = false,
	partyAuraShowDispellableDebuffs = false,
	partyAuraOnlyDispellableDebuffs = true,
	partyAuraShowBossAndImportantDebuffs = false,
	partyAuraShowOtherDebuffs = false,
}
o = Options(neil)
check(o.showDispel == false, "dispellable switch off: no dispel group")
check(o.showOther == false, "dispellable switch off in dispellable-only mode: no other group (dispellables arrive there)")
check(o.showBoss == false, "boss switch off is honoured in dispellable-only mode")
check(o.showOwn and o.showExternal and o.showRaid, "buffs stay")

-- Dispellable-only with dispellables on: they must still show, through either group.
o = Options({ partyAuraUseStockBehavior = false, partyAuraShowDispellableDebuffs = true,
	partyAuraOnlyDispellableDebuffs = true, partyAuraShowBossAndImportantDebuffs = true, partyAuraShowOtherDebuffs = false })
check(o.showDispel and o.showOther, "dispellable-only: dispellables shown through dispel and other groups")
check(o.showBoss, "dispellable-only: boss switch on shows boss debuffs")
check(o.onlyDispellable == true and o.otherMaxDuration == nil, "dispellable-only hands narrowing to Blizzard, no duration cap")

-- Normal mode: each switch maps to its own group.
o = Options({ partyAuraUseStockBehavior = false, partyAuraShowDispellableDebuffs = false,
	partyAuraOnlyDispellableDebuffs = false, partyAuraShowBossAndImportantDebuffs = true, partyAuraShowOtherDebuffs = true })
check(o.showDispel == false and o.showBoss == true and o.showOther == true, "normal mode: switches map one to one")
check(o.otherMaxDuration == 301, "normal mode: other debuffs capped at 301 seconds", o.otherMaxDuration)

o = Options({ partyAuraUseStockBehavior = false, partyAuraShowDispellableDebuffs = true,
	partyAuraOnlyDispellableDebuffs = false, partyAuraShowBossAndImportantDebuffs = false, partyAuraShowOtherDebuffs = false })
check(o.showDispel == true and o.showBoss == false and o.showOther == false, "normal mode: dispellables only")

-- Defaults (nil profile): stock.
o = Options(nil)
check(o.showDispel and o.showBoss and o.showOther, "no profile behaves as stock")

-- Helpful switches (FixLog 2026-11-13). Your own buffs, HoTs included, live in the
-- "own" group. RAID is any buff you can apply and RAID_IN_COMBAT the flag that puts
-- your HoTs on raid frames (AuraUtil.AuraFilters), so "Show Helpful Raid Buffs" alone
-- keeps the group but skips RAID_IN_COMBAT; "Show Short Helpful Buffs" alone caps it.
local function Buffs(raid, short)
	return Options({ partyAuraUseStockBehavior = false,
		partyAuraShowHelpfulRaidBuffs = raid, partyAuraShowHelpfulShortBuffs = short })
end
o = Buffs(true, false)
check(o.showOwn == true and o.ownSkipRaidInCombat == true, "short off, raid on: own group skips your raid-frame HoTs")
check(o.ownMaxDuration == nil, "short off, raid on: own group uncapped, your long raid buffs stay", o.ownMaxDuration)
check(o.showRaid == true, "short off, raid on: raid-flagged and boss/role buff groups stay")
o = Buffs(false, true)
check(o.showOwn == true and o.ownMaxDuration == 60, "short on, raid off: own group capped at 60 seconds", o.ownMaxDuration)
check(o.ownSkipRaidInCombat == false, "short on, raid off: own group keeps your HoTs")
check(o.showRaid == false, "short on, raid off: no raid groups")
o = Buffs(true, true)
check(o.showOwn == true and o.ownMaxDuration == nil and o.showRaid == true, "short on, raid on: own group uncapped, raid groups on")
check(o.ownSkipRaidInCombat == false, "short on, raid on: own group keeps your HoTs")
o = Buffs(false, false)
check(o.showOwn == false and o.showRaid == false, "both off: no own group, no raid groups")
o = Options({ partyAuraUseStockBehavior = true, partyAuraShowHelpfulRaidBuffs = false, partyAuraShowHelpfulShortBuffs = false })
check(o.showOwn == true and o.ownMaxDuration == nil and o.showRaid == true and o.ownSkipRaidInCombat == false,
	"stock behaviour ignores the helpful switches")

-- The raid-flagged group's filter string (PlayerAuraContainers.lua GetGroupFilterString).
-- RAID_IN_COMBAT is the flag that puts your HoTs on raid frames ("Combine with Player &
-- Helpful to return self-cast HoTs", AuraUtil.AuraFilters, 12.1.5 and Forever), so the
-- group must leave yours out even with the own group off, or they come back through it.
local pf = assert(io.open(root .. "/Components/UnitFrames/Auras/PlayerAuraContainers.lua", "rb"))
local pacSource = pf:read("*a")
pf:close()
local function SliceFrom(text, startPattern, endPattern)
	local s = text:find(startPattern, 1, true)
	assert(s, "not found: " .. startPattern)
	local e = text:find(endPattern, s, true)
	assert(e, "end not found after: " .. startPattern)
	return text:sub(s, e - 1)
end
local pacChunk = SliceFrom(pacSource, "local function IsUsableFilterString", "-- \"Player / Self Buffs\" means")
	.. SliceFrom(pacSource, "local GROUP_HELPFUL_OWN =", "local function GetGroupFrameCandidateFilters")
	.. "\nreturn GetGroupFilterString, GROUP_FRAME_AURA_GROUPS\n"
-- Blizzard's validator (Blizzard_FrameXMLUtil/AuraUtil.lua IsValidFilterString): known
-- tokens, each optionally negated with a leading "!".
local KNOWN_TOKENS = {
	HELPFUL = true, HARMFUL = true, PLAYER = true, RAID = true, CANCELABLE = true,
	INCLUDE_NAME_PLATE_ONLY = true, MAW = true, EXTERNAL_DEFENSIVE = true, CROWD_CONTROL = true,
	RAID_IN_COMBAT = true, RAID_PLAYER_DISPELLABLE = true, BIG_DEFENSIVE = true, IMPORTANT = true,
	DISPELLABLE = true,
}
local env = setmetatable({
	ns = { PlayerAuraContainers = {} },
	TryCall = pcall,
	AuraUtil = { IsValidFilterString = function(filterString)
		for component in filterString:gmatch("[^|]+") do
			if (not KNOWN_TOKENS[(component:gsub("^!", ""))]) then return false end
		end
		return true
	end },
}, { __index = _G })
local pacFn = assert(loadstring(pacChunk, "=PlayerAuraContainers.lua slice"))
setfenv(pacFn, env)
local GetGroupFilterString, groups = pacFn()
local raidGroup, externalGroup, ownGroup
for _, group in ipairs(groups) do
	if (group.key == "AzeriteGroupHelpfulRaid") then raidGroup = group end
	if (group.key == "AzeriteGroupHelpfulExternal") then externalGroup = group end
	if (group.key == "AzeriteGroupHelpfulOwn") then ownGroup = group end
end
assert(raidGroup and externalGroup and ownGroup, "own/raid/external groups not found")
local function HasToken(filterString, token)
	for component in filterString:gmatch("[^|]+") do
		if (component == token) then return true end
	end
	return false
end
local s = GetGroupFilterString(raidGroup, { showOwn = false, showExternal = false })
check(HasToken(s, "RAID_IN_COMBAT") and HasToken(s, "!PLAYER"), "own group off: raid group still leaves your buffs out", s)
s = GetGroupFilterString(raidGroup, { showOwn = true, showExternal = true })
check(HasToken(s, "!PLAYER") and HasToken(s, "!EXTERNAL_DEFENSIVE"), "own group on: raid group leaves yours and externals out", s)
s = GetGroupFilterString(raidGroup, { showOwn = true, ownSkipRaidInCombat = true, showExternal = false })
check(HasToken(s, "!PLAYER"), "own group skipping HoTs: raid group does not take your HoTs back", s)
s = GetGroupFilterString(externalGroup, { showOwn = false })
check(not HasToken(s, "!PLAYER"), "own group off: your externals stay with the externals switch", s)
s = GetGroupFilterString(externalGroup, { showOwn = true })
check(HasToken(s, "!PLAYER"), "own group takes all of yours: externals group leaves yours to it", s)
s = GetGroupFilterString(externalGroup, { showOwn = true, ownSkipRaidInCombat = true })
check(not HasToken(s, "!PLAYER"), "own group skipping HoTs: your externals go to the externals group", s)

-- The own group's filter string: raid on, short off drops RAID_IN_COMBAT (your HoTs)
-- and, while externals show, your externals (they are drawn by the externals group).
s = GetGroupFilterString(ownGroup, { showOwn = true, ownSkipRaidInCombat = true, showExternal = false })
check(s == "HELPFUL|!RAID_IN_COMBAT", "short off, raid on: own group skips RAID_IN_COMBAT", s)
s = GetGroupFilterString(ownGroup, { showOwn = true, ownSkipRaidInCombat = true, showExternal = true })
check(HasToken(s, "!RAID_IN_COMBAT") and HasToken(s, "!EXTERNAL_DEFENSIVE") and not HasToken(s, "!PLAYER"),
	"short off, raid on, externals on: own group skips HoTs and externals", s)
s = GetGroupFilterString(ownGroup, { showOwn = true, ownSkipRaidInCombat = false, showExternal = true })
check(s == "HELPFUL", "short on: own group filter unchanged", s)
-- End to end: the options as Party.lua builds them, through the filter strings.
local function OwnFilter(raid, short, externals)
	local opts = Options({ partyAuraUseStockBehavior = false, partyAuraShowHelpfulRaidBuffs = raid,
		partyAuraShowHelpfulShortBuffs = short, partyAuraShowHelpfulExternals = externals })
	return GetGroupFilterString(ownGroup, opts), GetGroupFilterString(externalGroup, opts), opts
end
local own, ext = OwnFilter(true, false, true)
check(HasToken(own, "!RAID_IN_COMBAT") and not HasToken(ext, "!PLAYER"), "end to end, short off raid on: HoTs out, externals kept", own .. " / " .. ext)
own, ext = OwnFilter(true, true, true)
check(own == "HELPFUL" and HasToken(ext, "!PLAYER"), "end to end, both on: as before", own .. " / " .. ext)
own, ext = OwnFilter(false, true, true)
check(own == "HELPFUL" and HasToken(ext, "!PLAYER"), "end to end, short only: as before", own .. " / " .. ext)

print(("Party aura options: %d checks, %d failures"):format(checks, failures))
os.exit(failures == 0 and 0 or 1)

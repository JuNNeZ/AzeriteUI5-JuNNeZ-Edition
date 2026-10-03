-- Unit frame level tiers (Novice/Hardened/Seasoned) and the critter check, on
-- any client and in any language. Loads the real Core/API/Frames.lua against a
-- small fake client; no claim of live WoW execution.
-- lua Tools/Harness/unit_tier_harness.lua .
local root = arg[1] or "."
local checks = 0
local function check(value, label)
	checks = checks + 1
	assert(value, label)
end

local SECRET = setmetatable({}, { __tostring = function() return "secret" end })
-- A secret that is still a number, as the client's are: only issecretvalue tells.
local SECRET_LEVEL = 4242

-- A client: caps answer as Blizzard's functions would; nil leaves a function out.
local function client(opts)
	opts = opts or {}
	local env = setmetatable({}, { __index = _G })
	env._G = env
	env.issecretvalue = function(value) return value == SECRET or value == SECRET_LEVEL end
	if (opts.rules ~= false) then
		env.GameRulesUtil = { GetEffectiveMaxLevelForPlayer = function()
			if (opts.rulesError) then error("no game rules") end
			return opts.rulesCap
		end }
	end
	env.GetMaxLevelForPlayerExpansion = opts.expansionCap and function() return opts.expansionCap end or nil
	env.GetMaxPlayerLevel = opts.playerCap and function() return opts.playerCap end or nil
	env.MAX_PLAYER_LEVEL = opts.globalCap
	env.UnitLevel = function() return opts.playerLevel end
	env.UnitCreatureType = function(unit)
		local creature = opts.creatures and opts.creatures[unit]
		if (not creature) then return nil end
		return creature[1], creature[2]
	end
	if (opts.critterName) then
		env.C_CreatureInfo = { GetCreatureTypeInfo = function(id)
			if (id == 8) then return { id = 8, name = opts.critterName } end
		end }
	end
	local ns = { API = { TryCall = function(func, ...)
		if (type(func) ~= "function") then return false end
		return pcall(func, ...)
	end } }
	local chunk = assert(loadfile(root .. "/Core/API/Frames.lua"))
	setfenv(chunk, env)
	chunk("AzeriteUI5_JuNNeZ_Edition", ns)
	return ns.API
end

-- Max level: Blizzard's rule first, then its own fallbacks, never a zero or secret cap.
local api = client({ rulesCap = 80 })
check(api.GetEffectiveMaxLevel() == 80, "GameRulesUtil cap used")
check(api.IsLevelAtEffectiveMaxLevel(80) and not api.IsLevelAtEffectiveMaxLevel(79), "cap compares")
api = client({ rules = false, expansionCap = 70, playerCap = 60 })
check(api.GetEffectiveMaxLevel() == 60, "no GameRulesUtil: min(expansion, player) cap")
api = client({ rulesError = true, expansionCap = 70 })
check(api.GetEffectiveMaxLevel() == 70, "GameRulesUtil error falls back")
api = client({ rulesCap = SECRET, playerCap = 60 })
check(api.GetEffectiveMaxLevel() == 60, "secret cap falls back")
api = client({ rulesCap = 0, playerCap = 60 })
check(api.GetEffectiveMaxLevel() == 60, "zero GameRulesUtil cap falls back")
api = client({ rules = false, globalCap = 0 })
check(api.GetEffectiveMaxLevel() == nil, "Forever's MAX_PLAYER_LEVEL = 0 is no cap")
check(api.GetLevelTier(60) == "Hardened", "unknown cap never makes Seasoned")
api = client({ rules = false, globalCap = 60 })
check(api.GetEffectiveMaxLevel() == 60, "global cap as last resort")

-- Tiers, the same on every client.
for _, cap in ipairs({ 60, 80, 90 }) do
	api = client({ rulesCap = cap, playerLevel = cap })
	check(api.GetLevelTier(1) == "Novice", "level 1 Novice at cap " .. cap)
	check(api.GetLevelTier(9) == "Novice", "level 9 Novice at cap " .. cap)
	check(api.GetLevelTier(10) == "Hardened", "level 10 Hardened at cap " .. cap)
	check(api.GetLevelTier(cap - 1) == "Hardened", "cap-1 Hardened at cap " .. cap)
	check(api.GetLevelTier(cap) == "Seasoned", "cap Seasoned at cap " .. cap)
	check(api.GetLevelTier(cap + 5) == "Seasoned", "above cap (timerunner) Seasoned")
	check(api.GetLevelTier(5, true) == "Seasoned", "XP disabled is Seasoned")
	check(api.GetLevelTier(5, false) == "Novice", "XP enabled keeps the level tier")
	check(api.GetLevelTier(-1) == "Seasoned", "?? level is Seasoned")
	check(api.GetLevelTier(SECRET) == "Hardened", "secret level never compared")
	check(api.GetLevelTier(SECRET_LEVEL) == "Hardened", "secret numeric level never compared")
	check(api.GetLevelTier(nil) == "Hardened", "missing level")
	check(api.IsPlayerAtEffectiveMaxLevel(), "player at cap")
end
check(api.GetSafeLevel(SECRET) == nil and api.GetSafeLevel("12") == nil and api.GetSafeLevel(12) == 12, "safe level")
check(not api.IsLevelAtEffectiveMaxLevel(SECRET_LEVEL), "secret level not at cap")

-- Critter: by id on any language, by name when there is no id.
api = client({ creatures = {
	enCritter = { "Critter", 8 },
	deCritter = { "Kleintier", 8 },
	deBeast = { "Wildtier", 1 },
	secretId = { SECRET, SECRET },
	nameOnlyEn = { "Critter" },
	nameOnlyDe = { "Kleintier" },
	enWrongId = { "Critter", 99 },
}, critterName = "Kleintier" })
check(api.IsUnitCritterType("enCritter"), "English critter")
check(api.IsUnitCritterType("deCritter"), "German critter by id")
check(not api.IsUnitCritterType("deBeast"), "German beast is no critter")
check(not api.IsUnitCritterType("secretId"), "secret creature type never compared")
check(api.IsUnitCritterType("nameOnlyEn"), "English name without id")
check(api.IsUnitCritterType("nameOnlyDe"), "client's own critter name without id")
check(api.IsUnitCritterType("enWrongId"), "English name still matches if the id table differs")
check(not api.IsUnitCritterType("nothing"), "no creature type")
api = client({ creatures = { nameOnlyDe = { "Kleintier" }, deCritter = { "Kleintier", 8 } } })
check(api.IsUnitCritterType("deCritter"), "German critter by id alone")
check(not api.IsUnitCritterType("nameOnlyDe"), "no C_CreatureInfo: unknown name is no critter")

-- Source contracts: the unit files use the shared helpers, not their own tier math.
local function read(path)
	local file = assert(io.open(root .. "/" .. path, "rb"))
	local text = file:read("*a")
	file:close()
	return text
end
for _, path in ipairs({
	"Components/UnitFrames/Units/Player.lua",
	"Components/UnitFrames/Units/PlayerAlternate.lua",
	"Components/UnitFrames/Units/Target.lua",
}) do
	local text = read(path)
	check(not text:find("< 10 and \"Novice\"", 1, true), path .. ": no private tier math")
	check(text:find("API.GetLevelTier(", 1, true), path .. ": uses GetLevelTier")
	check(text:find("GetSafeLevel(unit) or UnitLevel(\"player\")", 1, true), path .. ": level-up reads the payload")
end
local target = read("Components/UnitFrames/Units/Target.lua")
check(not target:find("creatureType == \"Critter\"", 1, true), "Target: no localized critter compare")
check(target:find("API.IsUnitCritterType(unit)", 1, true), "Target: critter by type id")
check(not target:find("(not ns.IsRetail) and", 1, true), "Target: Classic critter rule gated on content")
check(not target:find("return type(level) == \"number\" and level < 1\n", 1, true), "Target: ?? alone is no boss")

print(("unit tier harness: %d checks passed"):format(checks))

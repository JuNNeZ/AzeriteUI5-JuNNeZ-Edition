-- XP/reputation ring by the minimap (Components/ActionBars/Elements/StatusBars.lua). Loads the
-- real file with stubs: the XP bar hides under Blizzard's ExperienceBarDisabled game rule
-- (GameRulesUtil.CanShowExperienceBar) and is a no-op where the rule API is missing or
-- answers with a secret; the module refreshes on the renown, max level and expansion events
-- Blizzard's tracking manager listens to, only where the client has them.
-- Offline only: the ring's look and the renown label after a real level-up are live checks.
-- Run: lua.exe Tools/Harness/xp_bar_harness.lua <addon root> [StatusBars.lua to load instead]
local root = arg[1] or "."
local path = arg[2] or (root .. "/Components/ActionBars/Elements/StatusBars.lua")
local file = assert(io.open(path, "rb"))
local source = file:read("*a"):gsub("\r\n", "\n"); file:close()
local checks, failures = 0, 0
local function check(v, msg)
	checks = checks + 1
	if (not v) then failures = failures + 1; print("FAIL: " .. msg) end
end

local secretMeta = {}
for _, m in ipairs({ "__lt", "__le", "__eq", "__add", "__sub", "__mul", "__div", "__concat", "__unm" }) do
	secretMeta[m] = function() error("secret value used in Lua logic", 2) end
end
local function secret(v) return setmetatable({ value = v }, secretMeta) end

-- World state the stubs read.
local W = { level = 20, atCap = false, xpOff = false, rule = false, validEvents = nil, secretAsked = false }

local function Text()
	local t = { text = "" }
	function t:SetText(v) self.text = v end
	function t:SetFormattedText(f, ...) self.text = string.format(f, ...) end
	function t:SetTextColor() end
	return t
end
local function Ring()
	local b = { shown = false }
	function b:Show() self.shown = true end
	function b:Hide() self.shown = false end
	function b:IsShown() return self.shown end
	function b:SetMinMaxValues(a, z) self.min, self.max = a, z end
	function b:SetValue(v) self.value = v end
	function b:SetStatusBarColor() end
	b.Value, b.Description, b.Percent = Text(), Text(), Text()
	return b
end

local registered = {}
local module = {}
function module:RegisterEvent(event, method)
	if (W.validEvents and not W.validEvents[event]) then
		error("Attempt to register unknown event \"" .. event .. "\"", 2)
	end
	registered[event] = method
end
function module:Disable() self.disabled = true end

local ns = {
	Colors = { xp = { 1, 1, 1 }, rested = { 0, 0, 1 }, restedBonus = { 0, 0, 1 }, reaction = { { 1, 0, 0 } }, highlight = { 1, 1, 1 }, gray = { .5, .5, .5 } },
	API = {
		AbbreviateNumber = function(v) return tostring(v) end,
		IsPlayerAtEffectiveMaxLevel = function() return W.atCap end,
		IsEventAvailable = function(event) return not W.validEvents or W.validEvents[event] == true end,
	},
}
function ns:NewModule() return module end
function ns:GetModule(name) if (name == "Minimap") then return { IsEnabled = function() return true end, GetScale = function() return 1 end } end end

local function MakeEnv(withRule)
	local env = setmetatable({
		LibStub = function(name)
			if (name == "AceLocale-3.0") then
				return { GetLocale = function() return setmetatable({}, { __index = function(_, k) return k end }) end }
			end
			return {}
		end,
		-- Lua 5.1 never calls __eq between a table and a boolean, so `secret == true` cannot raise
		-- here as it would in the client; recording the question is what proves the guard runs.
		issecretvalue = function(v)
			local isSecret = getmetatable(v) == secretMeta
			if (isSecret) then W.secretAsked = true end
			return isSecret
		end,
		GetWatchedFactionInfo = function() return nil end,
		IsXPUserDisabled = function() return W.xpOff end,
		GetXPExhaustion = function() return nil end,
		UnitXP = function() return 300 end,
		UnitXPMax = function() return 1000 end,
		UnitLevel = function() return W.level end,
		XP = "XP",
	}, { __index = _G })
	if (withRule) then
		env.Enum = { GameRule = { ExperienceBarDisabled = 42 } }
		env.C_GameRules = { IsGameRuleActive = function(rule)
			assert(rule == 42, "asked for the ExperienceBarDisabled rule")
			return W.rule
		end }
	end
	return env
end

local function Load(withRule)
	for k in pairs(registered) do registered[k] = nil end
	for k in pairs(module) do
		if (type(module[k]) ~= "function" or k == "UpdateBars" or k == "OnEnable" or k == "CreateBars" or k == "UpdateScale") then
			if (k ~= "RegisterEvent" and k ~= "Disable") then module[k] = nil end
		end
	end
	local chunk = assert(loadstring(source, "StatusBars.lua"))
	setfenv(chunk, MakeEnv(withRule))
	chunk("AzeriteUI", ns)
	-- Skip the frame building; hand the module plain stand-ins.
	module.CreateBars = function(self)
		self.Bar, self.Bonus, self.Button = Ring(), Ring(), Ring()
	end
	module:OnEnable()
	return module
end

-- With the game rule API.
local m = Load(true)
check(m.Bar.shown == true and m.Button.shown == true and m.Bar.currentType == "xp", "levelling, rule off: XP bar shown")

W.rule = true; m:UpdateBars("PLAYER_ENTERING_WORLD")
check(m.Bar.shown == false and m.Button.shown == false and m.Bar.currentType == nil, "ExperienceBarDisabled active: XP bar and button hidden")

W.rule = false; m:UpdateBars("PLAYER_ENTERING_WORLD")
check(m.Bar.shown == true and m.Button.shown == true, "rule turned off again: XP bar back")

W.rule = secret(true); W.secretAsked = false
local ok, err = pcall(m.UpdateBars, m, "PLAYER_ENTERING_WORLD")
check(ok, "a secret rule answer raises nothing: " .. tostring(err))
check(W.secretAsked, "the rule answer goes through issecretvalue before it is used")
check(m.Bar.shown == true, "a secret rule answer keeps the bar as it was")
W.rule = false

W.atCap = true; m:UpdateBars("PLAYER_LEVEL_UP")
check(m.Bar.shown == false, "at the level cap: hidden (unchanged)")
W.atCap = false
W.xpOff = true; m:UpdateBars("DISABLE_XP_GAIN")
check(m.Bar.shown == false, "XP turned off: hidden (unchanged)")
W.xpOff = false

for _, event in ipairs({ "MAJOR_FACTION_RENOWN_LEVEL_CHANGED", "PLAYER_MAX_LEVEL_UPDATE", "UPDATE_EXPANSION_LEVEL" }) do
	check(registered[event] == "UpdateBars", event .. " refreshes the ring")
end
check(registered.UPDATE_FACTION == "UpdateBars" and registered.PLAYER_XP_UPDATE == "UpdateBars", "existing events still registered")

-- A client without the rule API (old builds, a stripped client): a no-op, bar shown.
ok, m = pcall(Load, false)
check(ok and m.Bar.shown == true, "no C_GameRules/Enum.GameRule: XP bar shown, nothing raised: " .. tostring(not ok and m or ""))
if (ok) then
	W.rule = true; ok, err = pcall(m.UpdateBars, m, "PLAYER_ENTERING_WORLD")
	check(ok and m.Bar.shown == true, "no rule API: the rule is never consulted: " .. tostring(err))
end
W.rule = false

-- A client that knows none of the three events: they are skipped, never registered blind.
W.validEvents = {}
for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_LOGIN", "PLAYER_ALIVE", "PLAYER_LEVEL_UP", "PLAYER_XP_UPDATE",
	"PLAYER_FLAGS_CHANGED", "DISABLE_XP_GAIN", "ENABLE_XP_GAIN", "PLAYER_UPDATE_RESTING", "UPDATE_EXHAUSTION", "UPDATE_FACTION" }) do
	W.validEvents[e] = true
end
ok, err = pcall(Load, true)
check(ok, "client without the three events: enable raises nothing: " .. tostring(err))
check(registered.MAJOR_FACTION_RENOWN_LEVEL_CHANGED == nil and registered.UPDATE_EXPANSION_LEVEL == nil, "unknown events are not registered")
check(registered.UPDATE_FACTION == "UpdateBars", "known events still registered there")
W.validEvents = nil

print(("XP bar: %d checks, %d failures (offline only)"):format(checks, failures))
os.exit(failures == 0 and 0 or 1)

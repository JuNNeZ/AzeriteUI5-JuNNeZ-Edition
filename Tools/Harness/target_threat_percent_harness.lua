-- The target frame's threat percent (Target.lua, ThreatPercent_Update; FixLog 2026-11-07).
-- Lua 5.1: lua Tools/Harness/target_threat_percent_harness.lua . [Forever]
-- Loads the real Target.lua and its layout, then drives the real update through the module's
-- own closure (TargetFrameMod.Update). Secret stand-ins raise on any arithmetic or comparison.
-- Not a WoW client: the event wiring and the text's place beside the name are owed live.
local root = arg[1] or "."
local flavor = arg[2] or "Retail"
local checks, failures = 0, 0
local function check(value, label, detail)
	checks = checks + 1
	if not value then failures = failures + 1; print("FAIL: " .. label .. (detail ~= nil and (" - " .. tostring(detail)) or "")) end
end
local function read(path)
	local f = assert(io.open(root .. "/" .. path, "rb"))
	local s = f:read("*a"); f:close()
	return s
end

local world = { group = true, exists = true, attack = true, controlled = false,
	isTanking = true, status = 3, scaled = 100 }
local secrets = setmetatable({}, { __mode = "k" })
local function forbidden() error("secret inspected", 2) end
local secretMT = { __add = forbidden, __sub = forbidden, __mul = forbidden, __div = forbidden,
	__lt = forbidden, __le = forbidden, __eq = forbidden, __concat = forbidden, __tostring = forbidden }
local function secret(value) local s = setmetatable({}, secretMT); secrets[s] = value; return s end

local env = setmetatable({}, { __index = _G }); env._G = env
env.type = function(value) if secrets[value] ~= nil then return "number" end return type(value) end
env.issecretvalue = function(value) return secrets[value] ~= nil end
env.UnitLevel = function() return flavor == "Forever" and 60 or 90 end
env.IsInGroup = function() return world.group end
env.UnitExists = function() return world.exists end
env.UnitCanAttack = function() return world.attack end
env.UnitPlayerControlled = function() return world.controlled end
env.UnitDetailedThreatSituation = function(unit, mob)
	assert(unit == "player" and mob == "target", "asks the player's threat on the target")
	if world.status == nil then return nil end
	return world.isTanking, world.status, world.scaled, world.scaled, 1000
end
env.CreateFrame = function()
	local f = {}
	function f:RegisterEvent() end
	function f:SetScript() end
	return f
end

local modules, configs = {}, {}
local ns = { IsForever = flavor == "Forever", API = {}, UnitFrameModule = {},
	MovableModulePrototype = { defaults = {} }, oUF = {} }
ns.Colors = setmetatable({ threat = { [0] = { .1, .1, .1 }, [1] = { .2, .2, .2 }, [2] = { .3, .3, .3 }, [3] = { .4, .4, .4 } } },
	{ __index = function() return { 1, 1, 1, 1 } end })
function ns:NewModule(name) modules[name] = {}; return modules[name] end
function ns:GetModule(name) return modules[name] end
function ns:Merge(a) return a end
function ns.GetConfig(name) return configs[name] end
function ns.RegisterConfig(name, data) configs[name] = data end
function ns.RegisterConfigVariant() end
ns.API.GetMedia = function(name) return "Assets/" .. name .. ".tga" end
ns.API.GetFont = function() return "font" end
ns.API.TryCall = function(fn, ...) return pcall(fn, ...) end
ns.API.IsSafeNumber = function(v) return env.type(v) == "number" and not env.issecretvalue(v) end
ns.API.GetEffectiveScale = function() return 1 end

local function load(path)
	local chunk = assert(loadstring(read(path), "@" .. path))
	setfenv(chunk, env); chunk("AzeriteUI5_JuNNeZ_Edition", ns)
end
load("Components/UnitFrames/ExecuteRange.lua")
load("Layouts/Data/TargetUnitFrame.lua")
load("Components/UnitFrames/Units/Target.lua")

local M = modules.TargetFrame
M.db = { profile = M:GenerateDefaults().profile }
check(M.db.profile.showThreatPercent == true, "Show Threat Percent is on by default")
check(configs.TargetFrame and configs.TargetFrame.ThreatPercentFont ~= nil, "the layout gives the threat text a font")

local update
for i = 1, 60 do
	local name, value = debug.getupvalue(M.Update, i)
	if not name then break end
	if name == "ThreatPercent_Update" then update = value end
end
assert(update, "the real ThreatPercent_Update is not reachable from TargetFrameMod.Update")

local text = { shown = false }
function text:Show() self.shown = true end
function text:Hide() self.shown = false end
function text:SetFormattedText(fmt, ...) self.value = string.format(fmt, ...) end
function text:SetTextColor(r, g, b, a) self.color = { r, g, b, a } end
local frame = { ThreatPercent = text }

local function run(label)
	local ok, err = pcall(update, frame)
	check(ok, label .. " runs without raising", err)
end

run("tanking")
check(text.shown and text.value == "100%" and text.color[1] == .4, "tanking: 100% in the securely-tanking colour", text.value)

world.isTanking, world.status, world.scaled = false, 1, 87.6
run("behind the tank")
check(text.shown and text.value == "88%" and text.color[1] == .2, "behind the tank: the rounded share in that status's colour", text.value)

world.status = nil
run("not on the table")
check(not text.shown, "not on the target's threat table: hidden")
world.status = 1

world.group = false
run("solo")
check(not text.shown, "solo: hidden")
world.group = true

world.controlled = true
run("a player target")
check(not text.shown, "a player-controlled target: hidden")
world.controlled = false

world.attack = false
run("a friendly target")
check(not text.shown, "a target you cannot attack: hidden")
world.attack = true

world.scaled = secret(50)
run("secret threat values")
check(not text.shown, "secret threat values: hidden, never compared")
world.scaled = 50
world.status = secret(1)
run("a secret status")
check(not text.shown, "a secret status: hidden")
world.status = 1

world.exists = false
run("no target")
check(not text.shown, "no target: hidden")
world.exists = true

M.db.profile.showThreatPercent = false
run("switched off")
check(not text.shown, "Show Threat Percent off: hidden")
M.db.profile.showThreatPercent = true
run("switched back on")
check(text.shown and text.value == "50%", "switched back on: shown again", text.value)

-- The events the text follows, and the option on the page.
local targetSource = read("Components/UnitFrames/Units/Target.lua")
for _, event in ipairs({ "UNIT_THREAT_LIST_UPDATE", "UNIT_THREAT_SITUATION_UPDATE", "GROUP_ROSTER_UPDATE", "PLAYER_REGEN_ENABLED" }) do
	check(targetSource:find('self:RegisterEvent("' .. event .. '", ThreatPercent_OnEvent', 1, true), "the frame follows " .. event)
end
check(read("Options/OptionsPages/UnitFrames.lua"):find("suboptions.args.showThreatPercent", 1, true), "the Target page has the switch")

print(("target threat percent harness (%s): %d checks, %d failures"):format(flavor, checks, failures))
if failures > 0 then os.exit(1) end

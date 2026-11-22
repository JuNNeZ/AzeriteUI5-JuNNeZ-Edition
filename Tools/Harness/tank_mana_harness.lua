-- The tank mana warning (Components/UnitFrames/NamePlates/GroupMana.lua, 2026-11-22).
-- Loads the real file against stubs. Group mana is a strict secret stand-in in combat: type() says
-- "number", issecretvalue() says true, and arithmetic, comparison, concatenation or indexing throws,
-- so any addon-side use of the number in combat fails the run. Curves follow Blizzard's Step reading
-- used by Player.lua's mana crystal. No claim of live WoW execution.
-- lua Tools/Harness/tank_mana_harness.lua .
local root = arg[1] or "."
local checks, failures = 0, 0
local function check(value, label, detail)
	checks = checks + 1
	if (not value) then
		failures = failures + 1
		print("FAIL: " .. label .. (detail and (" - " .. tostring(detail)) or ""))
	end
end

-- Secret stand-in ------------------------------------------------------------
local hidden = setmetatable({}, { __mode = "k" })
local SecretMT = {}
for _, event in ipairs({ "__add", "__sub", "__mul", "__div", "__mod", "__pow", "__unm",
	"__concat", "__len", "__lt", "__le", "__eq", "__call", "__index", "__newindex" }) do
	SecretMT[event] = function() error("secret value used by addon code (" .. event .. ")", 2) end
end
local function secret(value)
	local proxy = setmetatable({}, SecretMT)
	hidden[proxy] = value
	return proxy
end
local function isSecret(value) return hidden[value] ~= nil end
local function reveal(value)
	if (isSecret(value)) then return hidden[value] end
	return value
end

-- Widgets ----------------------------------------------------------------------
local function Widget(kind)
	local w = { kind = kind, shown = true, alpha = 1, scripts = {}, events = {} }
	function w:Show() self.shown = true end
	function w:Hide() self.shown = false end
	function w:SetShown(show) self.shown = show and true or false end
	function w:IsShown() return self.shown end
	function w:SetAlpha(alpha)
		assert(type(alpha) == "number" or isSecret(alpha), "SetAlpha needs a number")
		self.alpha = alpha
	end
	function w:CreateFontString() return Widget("FontString") end
	function w:SetFormattedText(fmt, ...)
		local args = { ... }
		for i = 1, select("#", ...) do
			assert(args[i] ~= nil, "SetFormattedText got nil")
			if (isSecret(args[i])) then args[i] = reveal(args[i]) self.secretText = true end
		end
		self.text = string.format(fmt, unpack(args))
	end
	function w:SetText(text) self.text = text end
	function w:SetScript(name, func) self.scripts[name] = func end
	function w:RegisterEvent(event) self.events[event] = true end
	function w:UnregisterAllEvents() self.events = {} end
	function w:SetPoint(point, relativeTo) self.anchor = { point, relativeTo } end
	return setmetatable(w, { __index = function(_, key)
		if (type(key) == "string" and (key:match("^Set") or key:match("^Clear"))) then
			return function() end
		end
	end })
end

-- Client -----------------------------------------------------------------------
local now, inCombat = 100, false
local members = {}
local function reset()
	members = {
		party1 = { name = "Holly", role = "HEALER", power = 0, mana = 100, max = 100 },
		party2 = { name = "Merlin", role = "DAMAGER", power = 0, mana = 100, max = 100 },
		party3 = { name = "Grom", role = "DAMAGER", power = 1, mana = 0, max = 0 }
	}
end
reset()
local function wrap(value)
	if (inCombat) then return secret(value) end
	return value
end
local sounds, flashes, timers = {}, 0, {}
local frames = {}

local env = setmetatable({}, { __index = _G })
env._G = env
env.type = function(value)
	if (isSecret(value)) then return "number" end
	return type(value)
end
env.Enum = { PowerType = { Mana = 0 }, LuaCurveType = { Linear = 0, Step = 1 } }
env.GetTime = function() return now end
env.InCombatLockdown = function() return inCombat end
local groupSize = 3
env.IsInGroup = function() return groupSize > 0 end
env.IsInRaid = function() return false end
env.GetNumGroupMembers = function() return groupSize + 1 end
env.GetNumSubgroupMembers = function() return groupSize end
env.UnitExists = function(unit) return members[unit] ~= nil end
env.UnitIsDeadOrGhost = function(unit) return members[unit] and members[unit].dead or false end
env.UnitIsConnected = function(unit) return not (members[unit] and members[unit].offline) end
env.UnitName = function(unit) return members[unit] and members[unit].name end
env.UnitGroupRolesAssigned = function(unit)
	local role = members[unit] and members[unit].role or "NONE"
	if (inCombat) then return secret(role) end
	return role
end
env.UnitPowerType = function(unit) return members[unit] and members[unit].power end
env.UnitPower = function(unit, powerType)
	assert(powerType == 0, "mana only")
	return wrap(members[unit].mana)
end
env.UnitPowerMax = function(unit, powerType)
	assert(powerType == 0, "mana only")
	return members[unit].max -- player-controlled: plain
end
env.C_CurveUtil = { CreateCurve = function()
	local curve = { points = {} }
	function curve:SetType(curveType) self.type = curveType end
	function curve:AddPoint(x, y)
		local last = self.points[#self.points]
		assert(not last or x > last[1], "curve points must be added in ascending order")
		self.points[#self.points + 1] = { x, y }
	end
	function curve:Evaluate(x)
		assert(self.type == 1, "step curves")
		local y = self.points[1] and self.points[1][2] or 0
		for _, point in ipairs(self.points) do
			if (x >= point[1]) then y = point[2] end
		end
		return y
	end
	return curve
end }
local ScaleTo100 = { Evaluate = function(_, x) return x * 100 end }
env.CurveConstants = { ScaleTo100 = ScaleTo100 }
env.UnitPowerPercent = function(unit, powerType, unmodified, curve)
	assert(powerType == 0 and unmodified == false and curve, "UnitPowerPercent arguments")
	local m = members[unit]
	-- Just under the exact value for the step curves, so a line placed exactly on 25% or 50% is caught.
	local fraction = m.max > 0 and (m.mana / m.max) * (curve == ScaleTo100 and 1 or (1 - 1e-6)) or 0
	return wrap(curve:Evaluate(fraction))
end
env.CreateFrame = function(kind)
	local widget = Widget(kind)
	frames[#frames + 1] = widget
	return widget
end
env.UIParent = Widget("Frame")
env.C_Timer = { After = function(delay, func) timers[#timers + 1] = { at = now + delay, func = func } end }
env.wipe = nil -- the file brings its own when the client's is missing
env.LibStub = function() return { GetLocale = function() return setmetatable({}, { __index = function(_, k) return k end }) end } end

-- Namespace ----------------------------------------------------------------------
local profile = { tankManaWarning = false, tankManaWatch = "healers", tankManaSoundFile = "Default",
	threatAlertSoundOn = true, threatAlertFlash = false }
local mod = { db = { profile = profile }, tankModeActive = true, enabled = true }
function mod:IsEnabled() return self.enabled end
local NP = {
	NamePlatesMod = mod,
	IsSecretValue = isSecret,
	SafeUnitMatches = function(a, b) return a == b end,
	PlayThreatAlertSound = function(kind, file) sounds[#sounds + 1] = kind .. ":" .. tostring(file) end,
	FlashScreenEdge = function() flashes = flashes + 1 end
}
local ns = { NamePlatesPrivate = NP, GetConfig = function() return {} end,
	API = { TryCall = pcall, GetFont = function() return {} end } }

local chunk = assert(loadfile(root .. "/Components/UnitFrames/NamePlates/GroupMana.lua"))
setfenv(chunk, env)
chunk("AzeriteUI5_JuNNeZ_Edition", ns)
check(type(NP.ConfigureGroupMana) == "function" and type(mod.PreviewGroupMana) == "function", "the file exports its entry points")

local watcher, display
local function find()
	for _, f in ipairs(frames) do
		if (f.scripts.OnEvent) then watcher = f end
		if (f.Rows) then display = f end
	end
end
local function Fire(event, ...)
	find()
	assert(watcher, "no watcher")
	local ok, err = pcall(watcher.scripts.OnEvent, watcher, event, ...)
	check(ok, event .. " runs without error", err)
end
local function Row(i) return display and display.Rows[i] end
local function Lines(i)
	local row = Row(i)
	return row and row:IsShown(), row and reveal(row.Low.alpha), row and reveal(row.Critical.alpha)
end
local function Mana(unit, value)
	members[unit].mana = value
	Fire("UNIT_POWER_UPDATE", unit, "MANA")
end

-- Off by default ---------------------------------------------------------------
NP.ConfigureGroupMana()
find()
check(not watcher and not display, "off by default: no watcher, no lines")

-- On, tank, in a party: the healer only ----------------------------------------
profile.tankManaWarning = true
NP.ConfigureGroupMana()
find()
check(watcher and watcher.events.UNIT_POWER_UPDATE and watcher.events.PLAYER_REGEN_ENABLED, "on: the watcher listens")
check(display and not display:IsShown(), "everyone above 50%: nothing shown")

Mana("party1", 40)
local shown, low, crit = Lines(1)
check(shown and low == 1 and crit == 0 and display:IsShown(), "healer under 50%: the yellow line", tostring(low) .. "/" .. tostring(crit))
check(Row(1).Low.text == "Holly is at 40% mana - slow down", "the line names the healer and the percent", Row(1).Low.text)
check(#sounds == 1 and sounds[1] == "mana:Default", "crossing 50% out of combat plays the sound", table.concat(sounds, " "))

now = now + 3
Mana("party1", 35)
check(#sounds == 1, "staying under 50% does not repeat it, even after the alert interval")
now = now + 3
Mana("party1", 20)
shown, low, crit = Lines(1)
check(shown and low == 0 and crit == 1, "under 25%: the red line only")
check(#sounds == 2, "crossing 25% plays it again")
check(Row(1).Critical.text == "Holly is at 20% mana - stop pulling", "the red line's text", Row(1).Critical.text)
check(not Row(2):IsShown(), "the mage is not watched in Healers mode")

profile.threatAlertFlash = true
now = now + 3
Mana("party1", 90)
check(not Row(1):IsShown() and not display:IsShown(), "drinking back over 50%: hidden")
Mana("party1", 10)
check(flashes == 1, "the screen edge flash follows the shared setting")
profile.threatAlertFlash = false
now = now + 3
Mana("party1", 100)

-- Combat: secret mana, lines by curve, no sound ---------------------------------
inCombat = true
local before = #sounds
Fire("PLAYER_REGEN_DISABLED")
shown, low, crit = Lines(1)
check(shown and low == 0 and crit == 0, "combat at full mana: the row is up but both lines are invisible")
check(isSecret(Row(1).Low.alpha), "in combat the alpha is the curve's secret, untouched")
Mana("party1", 45)
shown, low, crit = Lines(1)
check(shown and low == 1 and crit == 0, "combat under 50%: the yellow line through the curve")
check(Row(1).Low.secretText and Row(1).Low.text == "Holly is at 44.99955% mana - slow down"
	or (Row(1).Low.text or ""):find("Holly is at 4", 1, true), "the secret percent goes to the text", Row(1).Low.text)
Mana("party1", 10)
shown, low, crit = Lines(1)
check(low == 0 and crit == 1, "combat under 25%: the red line")
check(#sounds == before, "no sound while the mana is secret")

-- A role read in combat would be secret: the roster waits for the end of combat.
members.party4 = { name = "Ann", role = "HEALER", power = 0, mana = 20, max = 100 }
groupSize = 4
local okRoster, errRoster = pcall(NP.ConfigureGroupMana)
check(okRoster, "a roster change in combat does not read secret roles", errRoster)
check(not Row(2):IsShown(), "and adds nobody until combat ends")

-- Combat ends: readable again, and the drop since the last plain reading sounds.
inCombat = false
now = now + 3
Fire("PLAYER_REGEN_ENABLED")
check(#sounds == before + 1, "combat over with the healer at 10%: the sound, before the next pull", #sounds - before)
check(Row(2):IsShown() and select(3, Lines(2)) == 1, "the healer who joined in combat is watched after it")
members.party4, groupSize = nil, 3
NP.ConfigureGroupMana()

-- Secret or unknown event units are ignored.
Fire("UNIT_POWER_UPDATE", secret("party1"), "MANA")
Fire("UNIT_POWER_UPDATE", "nameplate3", "MANA")
Fire("UNIT_POWER_UPDATE", "party1", secret("MANA"))

-- Dead or offline healers drop out.
members.party1.dead = true
Fire("UNIT_HEALTH", "party1")
check(not Row(1):IsShown(), "a dead healer's line goes")
members.party1.dead = nil
members.party1.offline = true
Fire("UNIT_CONNECTION", "party1")
check(not Row(1):IsShown(), "an offline healer's line goes")
members.party1.offline = nil
Fire("UNIT_CONNECTION", "party1")
check(Row(1):IsShown(), "back online, back")

-- Healers and mana users; the warrior never.
profile.tankManaWatch = "mana"
NP.ConfigureGroupMana()
members.party2.mana = 30
members.party1.mana = 100
NP.ConfigureGroupMana()
check(not Row(1):IsShown() and Row(2):IsShown() and Row(2).Low.text:find("Merlin", 1, true), "Healers and mana users: the mage too")
check(not Row(3):IsShown(), "rage users are never watched")
check(Row(2).anchor and Row(2).anchor[2] == display, "the first shown row sits at the top, no gap")
profile.tankManaWatch = "healers"
NP.ConfigureGroupMana()
check(not Row(2):IsShown(), "back to Healers: the mage goes")

-- No healer role in the group (often on Forever): the mana users stand in.
members.party1.role = "NONE"
NP.ConfigureGroupMana()
check(Row(2):IsShown() or Row(1):IsShown(), "nobody has the Healer role: mana users are watched")
members.party1.role = "HEALER"
members.party2.mana = 100

-- Not tanking, no group, setting off, module off: hidden and silent.
members.party1.mana = 10
NP.ConfigureGroupMana()
check(display:IsShown(), "shown before the gates")
mod.tankModeActive = false
NP.ConfigureGroupMana()
check(not display:IsShown() and not next(watcher.events), "not in tank mode: hidden, events off")
mod.tankModeActive = true
groupSize = 0
NP.ConfigureGroupMana()
check(not display:IsShown(), "no group: hidden")
groupSize = 3
mod.enabled = false
NP.ConfigureGroupMana()
check(not display:IsShown(), "module disabled: hidden")
mod.enabled = true
profile.tankManaWarning = false
NP.ConfigureGroupMana()
check(not display:IsShown(), "setting off: hidden")

-- Preview: two example lines anywhere, then back to the real state.
mod.PreviewGroupMana()
check(display:IsShown() and Row(1):IsShown() and Row(2):IsShown(), "the preview shows two lines")
check(Row(1).Low.alpha == 1 and Row(2).Critical.alpha == 1 and Row(1).Low.text:find("42%%"), "a yellow and a red one", Row(1).Low.text)
Fire("UNIT_POWER_UPDATE", "party1", "MANA")
check(display:IsShown(), "events do not cut the preview short")
now = now + 10
for _, timer in ipairs(timers) do timer.func() end
check(not display:IsShown(), "after the preview the real state returns (off)")

-- No curve API: plain numbers out of combat, nothing in combat, no errors.
profile.tankManaWarning = true
env.UnitPowerPercent = nil
chunk = assert(loadfile(root .. "/Components/UnitFrames/NamePlates/GroupMana.lua"))
setfenv(chunk, env)
frames = {}
watcher, display = nil, nil
chunk("AzeriteUI5_JuNNeZ_Edition", ns)
members.party1.mana = 30
NP.ConfigureGroupMana()
find()
shown, low, crit = Lines(1)
check(shown and low == 1 and crit == 0, "without curves: plain numbers still work out of combat")
check(Row(1).Low.text == "Holly is low on mana - slow down", "and the line has no percent", Row(1).Low.text)
inCombat = true
Fire("UNIT_POWER_UPDATE", "party1", "MANA")
shown, low, crit = Lines(1)
check(low == 0 and crit == 0, "without curves in combat: nothing rather than a guess")
inCombat = false

print(string.format("tank_mana_harness: %d checks, %d failures", checks, failures))
if (failures > 0) then os.exit(1) end

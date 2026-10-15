-- Smoother combat, offline: the cooldown timer text and Explorer Mode's event work.
--
-- Cooldowns: loads the real Core/API/Abbreviations.lua and Core/Widgets/Cooldowns.lua
-- with a clock the harness moves, runs the shared timer at 144 frames a second and
-- counts what reaches the widgets: text is written only when it changes, a cooldown with
-- no visible bar is worked ten times a second, a visible bar every frame, the last
-- second still counts down in tenths, an expired cooldown clears and stops the timer,
-- and a restarted cooldown always writes its text.
--
-- Explorer Mode: loads the real Core/ExplorerMode.lua and counts UpdateSettings calls:
-- UNIT_AURA is no longer registered; power, health and cursor events reach it only when
-- their flag changes; other events as before.
--
-- It cannot measure frame time in game. lua Tools/Harness/smooth_combat_harness.lua .

local root = arg and arg[1] or "."

local checks, failures = 0, 0
local function check(value, label, detail)
	checks = checks + 1
	if (not value) then
		failures = failures + 1
		print("FAIL: " .. label .. (detail ~= nil and ("  (" .. tostring(detail) .. ")") or ""))
	end
end

--------------------------------------------------------------------------
-- Cooldowns
--------------------------------------------------------------------------
local now = 1000
_G.GetTime = function() return now end
_G.GetLocale = function() return "enUS" end
_G.issecretvalue = function() return false end

local timerFrame
_G.CreateFrame = function()
	local frame = { shown = true, scripts = {} }
	frame.Hide = function(self) self.shown = false end
	frame.Show = function(self) self.shown = true end
	frame.IsShown = function(self) return self.shown end
	frame.SetScript = function(self, name, fn) self.scripts[name] = fn end
	timerFrame = timerFrame or frame
	return frame
end
_G.hooksecurefunc = function(object, method, post)
	local original = object[method]
	object[method] = function(self, ...)
		local a, b, c = original(self, ...)
		post(self, ...)
		return a, b, c
	end
end

local ns = { API = {}, Private = {} }
ns.API.TryCall = function(fn, ...) return pcall(fn, ...) end
assert(loadfile(root .. "/Core/API/Abbreviations.lua"))("AzeriteUI5_JuNNeZ_Edition", ns)
assert(loadfile(root .. "/Core/Widgets/Cooldowns.lua"))("AzeriteUI5_JuNNeZ_Edition", ns)
local Widgets = ns.Private.Widgets
check(Widgets and Widgets.RegisterCooldown, "Cooldowns.lua loads")

local function NewText()
	local text = { writes = 0, value = "" }
	text.IsObjectType = function(_, kind) return kind == "FontString" end
	text.SetFormattedText = function(self, fmt, ...)
		self.writes = self.writes + 1
		self.value = string.format(fmt, ...)
	end
	text.SetText = function(self, value) self.writes = self.writes + 1; self.value = value end
	return text
end

local function NewBar(visible)
	local bar = { values = 0, visible = visible }
	bar.IsObjectType = function(_, kind) return kind == "StatusBar" end
	bar.IsVisible = function(self) return self.visible end
	bar.IsShown = function(self) return self.visible end
	bar.SetValue = function(self) self.values = self.values + 1 end
	bar.SetMinMaxValues = function() end
	bar.Show = function() end
	bar.Hide = function() end
	return bar
end

local function NewCooldown()
	local cooldown = {}
	cooldown.IsObjectType = function(_, kind) return kind == "Cooldown" end
	cooldown.SetCooldown = function() end
	cooldown.Clear = function() end
	cooldown.Hide = function() end
	cooldown.Show = function() end
	return cooldown
end

-- Runs the shared timer for `seconds` at `fps`.
local function Run(seconds, fps)
	local step = 1 / (fps or 144)
	local frames = math.floor(seconds * (fps or 144) + .5)
	for _ = 1, frames do
		now = now + step
		if (timerFrame.shown) then timerFrame.scripts.OnUpdate(timerFrame, step) end
	end
end

-- An action button: a 30 second cooldown with count text and no bar.
local textOnly = NewCooldown()
local count = NewText()
Widgets.RegisterCooldown(textOnly, count)
textOnly:SetCooldown(now, 30)
check(count.value == "30", "the text is written when the cooldown starts", count.value)
local startWrites = count.writes
Run(2.05)
check(count.value == "28", "just over two seconds later it reads 28", count.value)
check(count.writes - startWrites <= 3, "about one write per second, not one per frame", count.writes - startWrites)

-- An aura with a visible bar: the bar moves every frame.
local withBar = NewCooldown()
local bar, barText = NewBar(true), NewText()
Widgets.RegisterCooldown(withBar, bar, barText)
withBar:SetCooldown(now, 10)
local barStart = bar.values
Run(1)
-- The timer has always capped itself at 100 a second (elapsed .01): at 144 frames a
-- second that is every other frame, as before this change.
check(bar.values - barStart >= 70, "a visible bar is updated on every timer tick", bar.values - barStart)
check(barText.writes <= 3, "its text still only when it changes", barText.writes)

-- The same with the bar hidden: worked ten times a second.
local hiddenBar = NewCooldown()
local hidden = NewBar(false)
Widgets.RegisterCooldown(hiddenBar, hidden, NewText())
hiddenBar:SetCooldown(now, 10)
local hiddenStart = hidden.values
Run(1)
check(hidden.values - hiddenStart == 0, "a hidden bar is not pushed values", hidden.values - hiddenStart)

-- The last second counts down in tenths, ten changes a second.
local short = NewCooldown()
local shortText = NewText()
Widgets.RegisterCooldown(short, shortText)
short:SetCooldown(now, 2)
Run(1.05)
local before = shortText.writes
local seen = {}
for _ = 1, 9 do
	Run(.1)
	seen[shortText.value] = true
end
local distinct = 0
for _ in pairs(seen) do distinct = distinct + 1 end
check(distinct >= 7, "the last second still ticks in tenths", distinct)
check(shortText.writes - before <= 10, "with at most one write per change", shortText.writes - before)

-- Expiry clears the text and, once nothing is active, stops the timer.
Run(.3)
check(shortText.value == "", "an expired cooldown's text is cleared", shortText.value)
Run(31)
check(not timerFrame.shown, "the timer stops when nothing is active")

-- A restart with the same displayed value still writes it (the cache is reset).
local again = NewCooldown()
local againText = NewText()
Widgets.RegisterCooldown(again, againText)
again:SetCooldown(now, 5.5)
againText.value = "something else"
again:SetCooldown(now, 5.5)
check(againText.value == "6", "a restarted cooldown always writes its text", againText.value)
again:Hide()
check(againText.value == "", "Hide clears the text")
again:SetCooldown(now, 5.5)
check(againText.value == "6", "and the next start writes it again", againText.value)

--------------------------------------------------------------------------
-- Explorer Mode
--------------------------------------------------------------------------
local power, powerMax, health, healthMax, cursor = 100, 100, 100, 100, nil
_G.Enum = { PowerType = { Mana = 0 } }
_G.UnitClass = function() return "Warrior", "WARRIOR" end
_G.UnitLevel = function() return 80 end
_G.UnitPowerType = function() return 0, "MANA" end
_G.UnitPower = function() return power end
_G.UnitPowerMax = function() return powerMax end
_G.UnitHealth = function() return health end
_G.UnitHealthMax = function() return healthMax end
_G.GetCursorInfo = function() return cursor end
_G.UnitExists = function() return false end
_G.LibStub = function() return setmetatable({}, { __index = function() return function() end end }) end

local registered = {}
local explorerNs = { API = {}, MovableModulePrototype = { defaults = {} } }
explorerNs.Merge = function(_, target) return target end
explorerNs.NewModule = function(_, name)
	local module = { GetName = function() return name end }
	module.RegisterEvent = function(_, event) registered[event] = true end
	module.RegisterUnitEvent = function(_, event) registered[event] = true end
	module.UnregisterEvent = function(_, event) registered[event] = nil end
	explorerNs.module = module
	return module
end
explorerNs.API.IsEventAvailable = function() return false end
explorerNs.RegisterCallback = function() end
explorerNs.UnregisterCallback = function() end
assert(loadfile(root .. "/Core/ExplorerMode.lua"))("AzeriteUI5_JuNNeZ_Edition", explorerNs)
local Explorer = explorerNs.module
Explorer.db = { profile = Explorer:GenerateDefaults().profile }
Explorer.db.profile.fadeThresholdMana = .5
Explorer.db.profile.fadeThresholdHealth = .5
Explorer:EnableExplorerMode()
check(not registered.UNIT_AURA, "UNIT_AURA is no longer registered")
check(registered.UNIT_POWER_FREQUENT and registered.UNIT_HEALTH and registered.CURSOR_CHANGED, "power, health and cursor still are")

local updates = 0
Explorer.UpdateSettings = function() updates = updates + 1 end

for _ = 1, 50 do power = power - 0.5; Explorer:OnEvent("UNIT_POWER_FREQUENT", "player") end
check(updates == 0, "50 power ticks above the threshold do no settings work", updates)
power = 40
Explorer:OnEvent("UNIT_POWER_FREQUENT", "player")
check(updates == 1 and Explorer.lowPower == true, "crossing the threshold does", updates)
Explorer:OnEvent("UNIT_POWER_FREQUENT", "player")
check(updates == 1, "staying below it does not again", updates)
power = 90
Explorer:OnEvent("UNIT_DISPLAYPOWER", "player")
check(updates == 2 and not Explorer.lowPower, "coming back above it does", updates)

for _ = 1, 20 do Explorer:OnEvent("UNIT_HEALTH", "player") end
check(updates == 2, "health events at full health do nothing", updates)
health = 30
Explorer:OnEvent("UNIT_HEALTH", "player")
check(updates == 3 and Explorer.lowHealth == true, "low health does", updates)

Explorer:OnEvent("CURSOR_CHANGED")
check(updates == 3, "a cursor change that is not a pickup does nothing", updates)
cursor = "spell"
Explorer:OnEvent("CURSOR_CHANGED")
check(updates == 4 and Explorer.busyCursor == true, "picking up a spell does", updates)

Explorer:OnEvent("PLAYER_TARGET_CHANGED")
check(updates == 5, "other events still run the settings pass", updates)

print(string.format("smooth combat: %d checks, %d failures", checks, failures))
os.exit(failures == 0 and 0 or 1)

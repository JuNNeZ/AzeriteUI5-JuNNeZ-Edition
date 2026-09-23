-- Hide the Blizzard Tracker (Components/Misc/TrackerWoW11.lua), on Retail and on Forever.
-- The tracker frame itself is never hidden: an invisible secure child, `autoHider`, is shown and
-- hidden by a state driver, and its OnShow/OnHide set the tracker's alpha. This loads the real
-- module and the real Core/API/SecureDrivers.lua against two Blizzard behaviours copied from
-- source, because the module used to be wrong about both:
--   SecureHandlerStateTemplate dispatches only `state-*` attributes to a snippet
--     (Blizzard_RestrictedAddOnEnvironment/SecureHandlers.lua:107).
--   resolveDriver calls Show()/Hide() on every pass, and OnShow/OnHide fire only on a change
--     (SecureStateDriver.lua:95).
-- Snippets run as plain Lua here. No rendering, taint or restricted-environment checks.
-- lua Tools/Harness/tracker_harness.lua .
-- lua Tools/Harness/tracker_harness.lua . <path to a mutated TrackerWoW11.lua>
-- Mutations: the "tracker" entries in mutate_client.lua.
local root = arg[1] or "."
local path = arg[2] or (root .. "/Components/Misc/TrackerWoW11.lua")
local checks, failures = 0, 0
local function check(value, label)
	checks = checks + 1
	if (not value) then
		failures = failures + 1
		print("FAIL: " .. label)
	end
end

-- What the stubs read and record. Replaced by every Load.
local world
local drivers

-- A restricted snippet. Forever cannot run one at all (RestrictedExecution.lua:79).
local function RunSnippet(frame, body, stateid, newstate)
	world.snippetRuns = world.snippetRuns + 1
	if (not world.snippets) then
		world.snippetErrors = world.snippetErrors + 1
		return
	end
	local fn = assert(loadstring("local self, stateid, newstate = ...\n" .. body))
	fn(frame, stateid, newstate)
end

local Frame = {}
Frame.__index = Frame

local function NewFrame(template, shown)
	return setmetatable({
		shown = shown ~= false, alpha = 1, attributes = {}, scripts = {},
		template = template, protected = template ~= nil
	}, Frame)
end

function Frame:IsShown() return self.shown end
function Frame:Show()
	if (self.shown) then return end
	self.shown = true
	if (self.scripts.OnShow) then self.scripts.OnShow(self) end
end
function Frame:Hide()
	if (not self.shown) then return end
	self.shown = false
	if (self.scripts.OnHide) then self.scripts.OnHide(self) end
end
function Frame:SetScript(name, fn) self.scripts[name] = fn end
function Frame:GetScript(name) return self.scripts[name] end
function Frame:SetAlpha(alpha) self.alpha = alpha end
function Frame:GetAlpha() return self.alpha end
function Frame:GetAttribute(name) return self.attributes[name] end
function Frame:SetAttribute(name, value)
	if (self.protected and world.combat and not world.inSecure) then
		world.blocked = world.blocked + 1
		return
	end
	self.attributes[name] = value
	if (self.template == "SecureHandlerStateTemplate") then
		local stateid = name:match("^state%-(.+)")
		if (stateid) then
			local body = self.attributes["_onstate-" .. stateid]
			if (body) then RunSnippet(self, body, stateid, value) end
		end
	end
end
function Frame:SetFrameStrata() end
function Frame:SetFrameLevel() end
function Frame:SetClampedToScreen() end

-- SecureCmdOptionParse, for the one condition the module uses.
local function Condition(text)
	local unit = text:match("^@(%w+),exists$")
	assert(unit, "unmodelled macro condition: " .. text)
	return world.units[unit] and true or false
end

local function OptionParse(values)
	for clause in values:gmatch("[^;]+") do
		local rest, any, matched = clause, false, false
		while (true) do
			local condition, after = rest:match("^%[([^%]]*)%](.*)$")
			if (not condition) then break end
			any = true
			matched = matched or Condition(condition)
			rest = after
		end
		if (not any or matched) then return rest end
	end
end

local function Resolve(frame, attribute, values)
	local newValue = OptionParse(values)
	if (attribute == "state-visibility") then
		if (newValue == "show") then
			frame:Show()
			frame:SetAttribute("statehidden", nil)
		elseif (newValue == "hide") then
			frame:Hide()
			frame:SetAttribute("statehidden", true)
		end
	elseif (newValue and frame:GetAttribute(attribute) ~= newValue) then
		frame:SetAttribute(attribute, newValue)
	end
end

-- The state driver manager's OnUpdate pass.
local function Tick()
	world.inSecure = true
	for frame, list in pairs(drivers) do
		for attribute, values in pairs(list) do
			Resolve(frame, attribute, values)
		end
	end
	world.inSecure = false
end

local function RegisterStateDriver(frame, state, values)
	if (world.combat) then
		world.blocked = world.blocked + 1
		return
	end
	drivers[frame] = drivers[frame] or {}
	drivers[frame]["state-" .. state] = values
	world.inSecure = true
	Resolve(frame, "state-" .. state, values)
	world.inSecure = false
end

local function UnregisterStateDriver(frame, state)
	if (world.combat) then
		world.blocked = world.blocked + 1
		return
	end
	if (drivers[frame]) then drivers[frame]["state-" .. state] = nil end
end

local function Load(options)
	world = {
		units = {}, combat = false, inSecure = false, events = {},
		snippets = options.snippets, snippetRuns = 0, snippetErrors = 0, blocked = 0
	}
	drivers = {}

	local tracker = NewFrame()
	local module = { hooks = {} }
	module.RegisterEvent = function(self, event) world.events[event] = true end
	module.UnregisterEvent = function(self, event) world.events[event] = nil end
	module.IsHooked = function(self, object, name)
		return self.hooks[object] and self.hooks[object][name] or false
	end
	module.SecureHook = function(self, object, method, fn)
		self.hooks[object] = self.hooks[object] or {}
		self.hooks[object][method] = true
		local original = object[method]
		object[method] = function(...) local r = original(...); fn(...); return r end
	end
	module.SecureHookScript = function(self, object, script, fn)
		self.hooks[object] = self.hooks[object] or {}
		self.hooks[object][script] = true
		local original = object.scripts[script]
		object.scripts[script] = function(...)
			if (original) then original(...) end
			fn(...)
		end
	end

	local ns = {
		WoW11 = true,
		HasSecureSnippets = options.snippets,
		API = { GetFont = function() end, GetMedia = function() end },
		Hider = {},
		MovableModulePrototype = { defaults = {} },
		Merge = function(_, a) return a end,
		NewModule = function() return module end
	}
	local env = setmetatable({
		ObjectiveTrackerFrame = tracker,
		ObjectiveTrackerUIWidgetContainer = NewFrame(),
		ImmersionFrame = options.immersion and NewFrame(nil, false) or nil,
		CreateFrame = function(_, _, _, template) return NewFrame(template) end,
		RegisterStateDriver = RegisterStateDriver,
		UnregisterStateDriver = UnregisterStateDriver,
		InCombatLockdown = function() return world.combat end,
		issecretvalue = function() return false end,
		LoadAddOn = function() end
	}, { __index = _G })

	for _, file in ipairs({ root .. "/Core/API/SecureDrivers.lua", path }) do
		local chunk = assert(loadfile(file))
		setfenv(chunk, env)
		chunk("AzeriteUI5_JuNNeZ_Edition", ns)
	end
	module.db = { profile = { disableBlizzardTracker = options.disabled } }
	return module, tracker, env
end

local function Hidden(tracker) return tracker.alpha == 0 end

for _, client in ipairs({ { name = "Retail", snippets = true }, { name = "Forever", snippets = false } }) do
	local function label(text) return client.name .. ": " .. text end

	-- Switched on: hidden from login, and it stays hidden through everything that re-applies it.
	local m, t = Load({ snippets = client.snippets, disabled = true })
	m:OnEnable()
	check(Hidden(t), label("hidden as soon as the module is enabled"))
	m:OnEvent("PLAYER_ENTERING_WORLD", true, false)
	check(Hidden(t), label("hidden after the login PLAYER_ENTERING_WORLD"))
	m:OnEvent("SETTINGS_LOADED")
	check(Hidden(t), label("hidden after SETTINGS_LOADED"))
	m:OnEvent("PLAYER_ENTERING_WORLD", false, false)
	check(Hidden(t), label("hidden after a loading screen"))
	Tick()
	check(Hidden(t), label("hidden after the driver's next pass"))
	t:SetAlpha(1)
	m:OnEvent("PLAYER_ENTERING_WORLD", false, false)
	check(Hidden(t), label("a loading screen undoes an alpha someone else wrote"))

	world.units.boss1 = true; Tick()
	check(Hidden(t), label("hidden while a boss exists"))
	world.units.boss1 = nil; Tick()
	check(Hidden(t), label("still hidden after the boss despawns"))

	-- Switched off: visible, and the boss/arena auto-hide still works.
	m.db.profile.disableBlizzardTracker = false
	m:UpdateSettings()
	check(not Hidden(t), label("shown when switched off"))
	world.units.arena2 = true; Tick()
	check(Hidden(t), label("auto-hidden while an arena enemy exists"))
	world.units.arena2 = nil; Tick()
	check(not Hidden(t), label("back once the arena enemy is gone"))
	m:OnEvent("PLAYER_ENTERING_WORLD", false, false)
	check(not Hidden(t), label("switched off, still visible after a loading screen"))
	t:SetAlpha(0)
	m:OnEvent("SETTINGS_LOADED")
	check(t.alpha == .9, label("switched off, SETTINGS_LOADED restores the tracker's own alpha"))

	-- Switched on during a boss: stays hidden when the boss goes.
	world.units.boss3 = true; Tick()
	m.db.profile.disableBlizzardTracker = true
	m:UpdateSettings()
	world.units.boss3 = nil; Tick()
	check(Hidden(t), label("switched on mid-encounter, hidden after the boss despawns"))

	-- Switched in combat: held without touching anything protected, applied when combat ends.
	m.db.profile.disableBlizzardTracker = false
	m:UpdateSettings()
	world.combat = true
	m.db.profile.disableBlizzardTracker = true
	m:UpdateSettings()
	check(world.blocked == 0, label("nothing protected is touched from combat"))
	check(world.events.PLAYER_REGEN_ENABLED, label("a refresh is queued for the end of combat"))
	world.combat = false
	m:OnEvent("PLAYER_REGEN_ENABLED")
	check(Hidden(t), label("hidden once combat ends"))
	check(not world.events.PLAYER_REGEN_ENABLED, label("the combat refresh unregisters itself"))
	check(world.snippetErrors == 0, label("no restricted snippet runs on a client without them"))

	-- Settings arriving before the world, as a reload may deliver them.
	m, t = Load({ snippets = client.snippets, disabled = true })
	m:OnEnable()
	m:OnEvent("SETTINGS_LOADED")
	m:OnEvent("PLAYER_ENTERING_WORLD", false, true)
	check(Hidden(t), label("hidden when SETTINGS_LOADED comes first"))

	-- Switched off at login: visible from the start.
	m, t = Load({ snippets = client.snippets, disabled = false })
	m:OnEnable()
	m:OnEvent("PLAYER_ENTERING_WORLD", true, false)
	m:OnEvent("SETTINGS_LOADED")
	check(not Hidden(t), label("visible at login when switched off"))

	-- A reload taken in combat: nothing protected until combat ends, then hidden.
	m, t = Load({ snippets = client.snippets, disabled = true })
	world.combat = true
	m:OnEnable()
	m:OnEvent("PLAYER_ENTERING_WORLD", false, true)
	check(world.blocked == 0, label("a combat reload touches nothing protected"))
	world.combat = false
	m:OnEvent("PLAYER_REGEN_ENABLED")
	check(Hidden(t), label("hidden once a combat reload's refresh runs"))

	-- Immersion hides the tracker while it talks, and must not bring back one switched off.
	local env
	m, t, env = Load({ snippets = client.snippets, disabled = true, immersion = true })
	m:OnEnable()
	m:OnEvent("PLAYER_ENTERING_WORLD", true, false)
	env.ImmersionFrame:Show()
	env.ImmersionFrame:Hide()
	check(Hidden(t), label("switched on, still hidden after an Immersion dialogue closes"))
	m.db.profile.disableBlizzardTracker = false
	m:UpdateSettings()
	env.ImmersionFrame:Show()
	check(Hidden(t), label("switched off, hidden while Immersion is open"))
	m:OnEvent("PLAYER_ENTERING_WORLD", false, false)
	check(Hidden(t), label("switched off, a loading screen does not show it over Immersion"))
	env.ImmersionFrame:Hide()
	check(not Hidden(t), label("switched off, back when Immersion closes"))
end

print(string.format("Tracker: %d checks, %d failures", checks, failures))
-- Raised rather than os.exit, so mutate_client.lua can run this inside a pcall.
if (failures > 0) then error("tracker harness failed", 0) end

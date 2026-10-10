-- The What's New popup (Options/Kit/WhatsNew.lua) and its notes (Options/WhatsNew.lua).
-- Loads both real files against small stubs and drives logins through the watcher frame's own
-- OnEvent: first login vs /reload, fresh install, a version with and without an entry, "Got it",
-- the switch on the Changelog page, combat at the moment the timer fires, and the item buttons.
-- No rendering: frame sizes, fonts and the options panel are stubs.
-- lua Tools/Harness/whatsnew_harness.lua .
local root = arg[1] or "."
local checks, failures = 0, 0
local function check(value, label)
	checks = checks + 1
	if (not value) then
		failures = failures + 1
		print("FAIL: " .. label)
	end
end

-- Frames: every method is a no-op unless defined here. Scripts and events are recorded.
local frames
local function NewFrame()
	local f = { scripts = {}, events = {}, shown = true, enabled = true }
	frames[#frames + 1] = f
	return setmetatable(f, { __index = function(self, key)
		local methods = {
			SetScript = function(s, name, fn) s.scripts[name] = fn end,
			GetScript = function(s, name) return s.scripts[name] end,
			RegisterEvent = function(s, e) s.events[e] = true end,
			UnregisterEvent = function(s, e) s.events[e] = nil end,
			Show = function(s) s.shown = true end,
			Hide = function(s) s.shown = false end,
			SetShown = function(s, v) s.shown = v and true or false end,
			IsShown = function(s) return s.shown end,
			SetEnabled = function(s, v) s.enabled = v and true or false end,
			IsEnabled = function(s) return s.enabled end,
			IsMouseOver = function() return false end,
			GetStringHeight = function() return 14 end,
			CreateFontString = function() return NewFrame() end,
			CreateTexture = function() return NewFrame() end,
			SetText = function(s, t) s.text_ = t end,
		}
		if (methods[key]) then return methods[key] end
		-- Only widget methods (capitalized) answer; an unset field is nil, as in the game.
		if (type(key) == "string" and key:match("^%u")) then return function() end end
	end })
end

local world
local function Load(opts)
	frames = {}
	world = { combat = false, timers = {}, prints = {}, opened = {}, hud = {} }

	_G.CreateFrame = function() return NewFrame() end
	_G.UIParent = NewFrame()
	_G.UISpecialFrames = {}
	_G.InCombatLockdown = function() return world.combat end
	_G.C_Timer = { After = function(delay, fn) world.timers[#world.timers + 1] = { delay = delay, fn = fn } end }
	_G.unpack = unpack

	local L = setmetatable({}, { __index = function(_, k) return k end })
	_G.LibStub = function() return { GetLocale = function() return L end } end

	local panel = {
		SetTab = function(self, tab) world.tab = tab end,
		Open = function(self, key) world.opened[#world.opened + 1] = key; return true end,
		OpenSection = function(self, key, section)
			world.opened[#world.opened + 1] = key .. "/" .. tostring(section); return true
		end,
		LoadTheme = function() end,
	}
	local Kit = {
		Panel = panel, InsetBackdrop = {}, WindowBackdrop = {},
		WindowColor = {}, BorderIdle = {}, BorderHover = {}, InsetColor = {},
		TextSelected = {}, TextDisabled = {}, TextNormal = {}, TextHighlight = {},
		CreateBackdrop = function() return NewFrame() end,
		SetBorderColor = function() end,
		GetFont = function() return {} end,
	}
	local hud = { Command = function(self, input) world.hud[#world.hud + 1] = input end }

	local ns = {
		OptionsKit = Kit, Prefix = "AzeriteUI", Version = opts.version or "5.20.1-JuNNeZ",
		IsDevelopment = opts.development, IsFreshInstall = opts.fresh,
		db = { global = opts.global or {} },
		Print = function(self, ...) world.prints[#world.prints + 1] = table.concat({ ... }, " ") end,
		GetModule = function(self, name) return name == "LegacyHUD" and hud or nil end,
	}

	assert(loadfile(root .. "/Options/WhatsNew.lua"))("AzeriteUI5_JuNNeZ_Edition", ns)
	if (opts.entries) then ns.WhatsNew = opts.entries end
	assert(loadfile(root .. "/Options/Kit/WhatsNew.lua"))("AzeriteUI5_JuNNeZ_Edition", ns)

	world.ns, world.kit = ns, Kit
	world.watcher = frames[#frames]
	return Kit.WhatsNew
end

local function Login(initial)
	world.watcher.scripts.OnEvent(world.watcher, "PLAYER_ENTERING_WORLD", initial, not initial)
end
local function FireTimers()
	local list = world.timers
	world.timers = {}
	for _, t in ipairs(list) do t.fn() end
	return list
end

local ENTRY = { { version = "5.20.1-JuNNeZ", items = {
	{ text = "Page item", page = "Action Bars", section = "Proc Highlight" },
	{ text = "Run item", run = function() world.ran = true end, label = "/go legacy" },
	{ text = "Text only" },
} } }

-- The shipped notes load and are shaped as the window expects.
do
	local W = Load({})
	local list = world.ns.WhatsNew
	check(type(list) == "table" and #list >= 1, "shipped: ns.WhatsNew is a non-empty list")
	for i, entry in ipairs(list) do
		check(type(entry.version) == "string" and entry.version:find("%-JuNNeZ"), "shipped: entry " .. i .. " has a version")
		check(type(entry.items) == "table" and #entry.items >= 1 and #entry.items <= 5, "shipped: entry " .. i .. " has 1-5 items")
		for j, item in ipairs(entry.items or {}) do
			check(type(item.text) == "string" and item.text ~= "", "shipped: entry " .. i .. " item " .. j .. " has text")
		end
	end
	-- The shipped /go legacy item reaches the HUD command.
	check(W:Open(), "shipped: opens the newest entry")
	local runItem
	for _, item in ipairs(list[1].items) do if (item.run) then runItem = item end end
	if (runItem) then
		runItem.run()
		check(world.hud[1] == "legacy", "shipped: the run item calls LegacyHUD:Command('legacy')")
	end
end

-- First login on a version with an entry: one 8 second timer, then the window.
do
	local W = Load({ entries = ENTRY })
	Login(true)
	check(#world.timers == 1 and world.timers[1].delay == 8, "upgrade: one timer of 8 seconds")
	check(not W:IsShown(), "upgrade: not shown before the timer")
	FireTimers()
	check(W:IsShown(), "upgrade: shown when the timer fires")
	check(not world.watcher.events.PLAYER_ENTERING_WORLD, "upgrade: watcher stops listening after the first login")
end

-- A /reload is not a new start.
do
	local W = Load({ entries = ENTRY })
	Login(false)
	check(#world.timers == 0, "reload: no timer")
	check(not W:IsShown(), "reload: not shown")
end

-- Fresh install records the version and stays quiet.
do
	local W = Load({ entries = ENTRY, fresh = true })
	Login(true)
	check(#world.timers == 0, "fresh: no timer")
	check(world.ns.db.global.whatsNewSeen == "5.20.1-JuNNeZ", "fresh: version recorded as seen")
	check(not W:ShouldShow(), "fresh: ShouldShow is false afterwards")
end

-- A version with no entry shows nothing.
do
	local W = Load({ entries = ENTRY, version = "5.20.2-JuNNeZ" })
	Login(true)
	FireTimers()
	check(not W:IsShown(), "no entry: not shown")
end

-- Development builds never show it.
do
	local W = Load({ entries = ENTRY, development = true })
	Login(true)
	FireTimers()
	check(not W:IsShown(), "development: not shown")
end

-- "Got it" hides it until the next version; "Remind me later" does not.
do
	local W = Load({ entries = ENTRY })
	W:Open("5.20.1-JuNNeZ")
	W:Close()
	check(world.ns.db.global.whatsNewSeen == nil, "later: nothing recorded")
	check(W:ShouldShow(), "later: still due")
	W:Open("5.20.1-JuNNeZ")
	W:Dismiss()
	check(not W:IsShown(), "got it: closed")
	check(world.ns.db.global.whatsNewSeen == "5.20.1-JuNNeZ", "got it: version recorded")
	check(not W:ShouldShow(), "got it: no longer due")
end

-- Seen on an older version: due again.
do
	local W = Load({ entries = ENTRY, global = { whatsNewSeen = "5.20.0-JuNNeZ" } })
	check(W:ShouldShow(), "older seen: due again")
end

-- The switch on the Changelog page.
do
	local W = Load({ entries = ENTRY })
	check(W:IsEnabled(), "switch: on by default")
	W:SetEnabled(false)
	check(not W:IsEnabled() and not W:ShouldShow(), "switch: off stops it")
	Login(true)
	FireTimers()
	check(not W:IsShown(), "switch: off, not shown on login")
	W:SetEnabled(true)
	check(world.ns.db.global.whatsNewDisabled == nil, "switch: on clears the saved value")
	check(W:Open(), "switch: /az whatsnew still opens it when off")
end

-- Combat when the timer fires: waits for PLAYER_REGEN_ENABLED, then shows.
do
	local W = Load({ entries = ENTRY })
	Login(true)
	world.combat = true
	FireTimers()
	check(not W:IsShown(), "combat: not shown in combat")
	check(world.watcher.events.PLAYER_REGEN_ENABLED, "combat: waits for combat to end")
	world.combat = false
	world.watcher.scripts.OnEvent(world.watcher, "PLAYER_REGEN_ENABLED")
	check(W:IsShown(), "combat: shown after combat")
	check(not world.watcher.events.PLAYER_REGEN_ENABLED, "combat: stops waiting")
end

-- Item buttons: page items open the page and section, run items run, text-only has none,
-- and nothing starts in combat.
do
	local W = Load({ entries = ENTRY })
	W:Open("5.20.1-JuNNeZ")
	-- Find the row buttons by their label text.
	local byLabel = {}
	for _, f in ipairs(frames) do
		if (f.scripts.OnClick and f.text and f.text.text_) then byLabel[f.text.text_] = f end
	end
	local show, go = byLabel["Show me"], byLabel["/go legacy"]
	check(show and go, "buttons: page item uses the default label, run item its own")
	local count = 0
	for _, f in ipairs(frames) do
		if (f.text and (f.text.text_ == "Show me" or f.text.text_ == "/go legacy") and f.shown) then count = count + 1 end
	end
	check(count == 2, "buttons: the text-only item has no visible button")
	if (show and go) then
		world.combat = true
		show.scripts.OnClick(show)
		go.scripts.OnClick(go)
		check(#world.opened == 0 and not world.ran, "buttons: nothing runs in combat")
		world.combat = false
		show.scripts.OnClick(show)
		check(world.tab == "options" and world.opened[1] == "Action Bars/Proc Highlight", "buttons: page item opens page and section")
		go.scripts.OnClick(go)
		check(world.ran, "buttons: run item runs")
	end
	local notes = byLabel["All release notes"]
	if (notes) then
		notes.scripts.OnClick(notes)
		check(world.tab == "settings" and world.opened[#world.opened] == "changelog", "notes: opens the Changelog on the settings tab")
	else
		check(false, "notes: button found")
	end
end

print(string.format("What's New: %d checks, %d failures", checks, failures))
os.exit(failures == 0 and 0 or 1)

-- Game menu style conflict (FixLog 2026-11-13, SaiyaRatt). Loads the real
-- Components/Misc/GameMenu.lua once per simulated session, with the character's
-- saved choice carried across, and checks:
--   * the question is asked once per rival per character, not every session;
--   * Console Port counts as a clash only while its own Game Menu setting is on;
--   * Console Port can share the menu ("Both"): nothing is turned off;
--   * AzeriteUI/Blizzard turn the rival off under the player GUID, the key
--     Blizzard's addon list (12.1.5 and Forever) and Console Port use;
--   * a rival without canShare keeps the Blizzard button and gets no "Both".
-- Offline only: how the two styles look together on the live menu is a live check.
-- Run: lua.exe Tools/Harness/game_menu_conflict_harness.lua <addon root>
local root = arg[1] or "."
local checks, failures = 0, 0
local function check(v, msg, detail)
	checks = checks + 1
	if (not v) then
		failures = failures + 1
		print("FAIL: " .. msg .. (detail ~= nil and (" - " .. tostring(detail)) or ""))
	end
end

local GUID, NAME = "Player-1234-ABCDEF", "Saiya"

-- Generic frame: any unknown method is a no-op answering 0.
local function Stub(extra)
	local t = extra or {}
	return setmetatable(t, { __index = function(_, k) return function() return 0 end end })
end

local function NewSession(world, saved)
	local session = { prompts = {}, reloads = 0, disabled = {} }

	-- Addon state: enabled per GUID only, the name answers nothing (the suspected
	-- Retail 12 behaviour; the code must work whichever key the client honours).
	_G.C_AddOns = {
		IsAddOnLoaded = function(a) return world.loaded[a] and true or false end,
		GetAddOnEnableState = function(a, character)
			if (character == GUID and world.enabled[a]) then return 1 end
			return 0
		end,
		DisableAddOn = function(a, character) session.disabled[#session.disabled + 1] = { a, character } end,
		GetAddOnInfo = function(a) return a, world.titles[a] or a end,
	}
	_G.UnitGUID = function(u) return u == "player" and GUID or nil end
	_G.UnitName = function(u) return u == "player" and NAME or nil end
	_G.issecretvalue = function() return false end
	_G.ReloadUI = function() session.reloads = session.reloads + 1 end
	_G.C_Timer = { After = function(_, fn) fn() end }
	_G.StaticPopupDialogs = {}
	_G.StaticPopup_Show = function(key, text, _, data)
		local d = StaticPopupDialogs[key]
		session.prompts[#session.prompts + 1] = { key = key, text = text, data = data,
			button1 = d.button1, button2 = d.button2, button3 = d.button3, button4 = d.button4, dialog = d }
	end
	_G.CreateFrame = function() return Stub() end
	_G.InCombatLockdown = function() return false end
	_G.LibStub = function() return { GetLocale = function()
		return setmetatable({}, { __index = function(_, k) return k end })
	end } end

	local children = {}
	if (world.gw2Styled) then children[1] = Stub({ gw2Styled = true, IsForbidden = function() return false end, IsShown = function() return false end }) end
	-- Explicit methods only: the code reads fields such as NineSlice and template,
	-- which must be nil here, not stub functions.
	_G.GameMenuFrame = {
		IsForbidden = function() return false end,
		GetRegions = function() end,
		GetChildren = function() return unpack(children) end,
		GetFrameLevel = function() return 1 end,
		InitButtons = function() end,
	}
	_G.ConsolePortMenu = world.loaded.ConsolePort_Menu and {} or nil
	if (world.cpGameMenu ~= nil) then
		local settings = { gameMenuEnable = world.cpGameMenu }
		local db = setmetatable({ Settings = settings }, { __call = function(self, path)
			local repo, var = path:match("^(.-)/(.+)$")
			if (repo) then return self[repo][var] end
			return self[path]
		end })
		_G.ConsolePort = { GetData = function() return db end }
	else
		_G.ConsolePort = nil
	end

	local module
	local ns = {
		API = {
			GetFont = function() return {} end,
			GetMedia = function() return "" end,
			-- Core/API/Addons.lua reads this character's state by GUID.
			IsAddOnEnabled = function(a) return C_AddOns.GetAddOnEnableState(a, GUID) > 0 end,
			GetAddOnCharacter = function() return UnitGUID("player") or UnitName("player") end,
		},
		Hider = Stub(),
		Colors = { highlight = { 1, 1, 1 } },
		db = { RegisterNamespace = function() return { char = saved, profile = { showMenuButton = true } } end },
	}
	function ns:NewModule(name)
		module = { hooks = {} }
		function module:GetName() return name end
		function module:IsHooked() return false end
		function module:SecureHookScript(_, script, method) self.hooks[script] = method end
		function module:SecureHook() end
		function module:DisableSettingsExport() end
		return module
	end
	function ns:GetModule() return nil end

	assert(loadfile(root .. "/Components/Misc/GameMenu.lua"))("AzeriteUI5_JuNNeZ_Edition", ns)
	module:OnInitialize()
	module:OnEnable()
	session.module = module
	session.OpenMenu = function() module:OnMenuShown() end
	return session
end

local function Click(session, index)
	local p = session.prompts[#session.prompts]
	local fn = p.dialog["OnButton" .. index]
	fn(nil, p.data)
end

local CP = { loaded = { ConsolePort = true, ConsolePort_Menu = true }, enabled = { ConsolePort_Menu = true },
	titles = { ConsolePort_Menu = "Console Port Menu" }, cpGameMenu = true }

-- 1. First session: Console Port's game menu on, asked once, "Both" offered.
local saved = {}
local s = NewSession(CP, saved)
s.OpenMenu()
check(#s.prompts == 1, "asked when Console Port's game menu clashes", #s.prompts)
local p = s.prompts[1]
check(p and p.button2 == "Console Port Menu" and p.button3 == "Both", "buttons: AzeriteUI, Console Port Menu, Both", p and p.button3)
check(p and p.text:find("Both keeps the two running", 1, true), "text explains Both")
s.OpenMenu()
check(#s.prompts == 1, "asked at most once per session")
local choices = s.module:GetStyleChoices()
check(choices.both == "AzeriteUI and Console Port Menu" and choices.other == "Console Port Menu" and choices.blizzard, "options page offers Both for Console Port")

-- 2. Both: nothing turned off, reload, and never asked again.
Click(s, 3)
check(#s.disabled == 0, "Both turns nothing off")
check(s.reloads == 1 and saved.owner == "both" and saved.rival == "ConsolePort_Menu", "Both saved and reloaded")
s = NewSession(CP, saved)
check(s.module.skinning == true, "Both keeps AzeriteUI's style on")
s.OpenMenu()
check(#s.prompts == 0, "Both: not asked again next session")
check(s.module:GetStyle() == "both", "options page shows Both", s.module:GetStyle())

-- 3. AzeriteUI: Console Port Menu turned off under the GUID; if it comes back, no nagging.
saved = {}
s = NewSession(CP, saved)
s.OpenMenu()
Click(s, 1)
check(#s.disabled == 1 and s.disabled[1][1] == "ConsolePort_Menu" and s.disabled[1][2] == GUID, "AzeriteUI turns the rival off under the player GUID",
	s.disabled[1] and s.disabled[1][2])
s = NewSession(CP, saved) -- the module turned itself back on
s.OpenMenu()
check(#s.prompts == 0, "AzeriteUI answered: not asked again even if the rival is back")

-- 4. Console Port's own style: AzeriteUI stands down, found through the GUID/loaded state.
saved = {}
s = NewSession(CP, saved)
s.OpenMenu()
Click(s, 2)
check(#s.disabled == 0 and saved.owner == "other", "Console Port's style saved, nothing off")
s = NewSession(CP, saved)
check(s.module.skinning == false, "other: AzeriteUI does not style the menu although the name-keyed check says disabled")
s.OpenMenu()
check(#s.prompts == 0, "other: not asked again")

-- 5. Decide Later: asked again next session.
saved = {}
s = NewSession(CP, saved)
s.OpenMenu()
Click(s, 4)
check(saved.owner == nil and s.reloads == 0, "Decide Later saves nothing")
s = NewSession(CP, saved)
s.OpenMenu()
check(#s.prompts == 1, "Decide Later: asked again next session")

-- 6. Console Port loaded with its Game Menu setting off: no clash at all.
local cpOff = { loaded = CP.loaded, enabled = CP.enabled, titles = CP.titles, cpGameMenu = false }
s = NewSession(cpOff, {})
s.OpenMenu()
check(#s.prompts == 0, "Console Port with its game menu off is not a clash")

-- 7. A rival that cannot share keeps the Blizzard button and no Both.
local gw2 = { loaded = { GW2_UI = true }, enabled = { GW2_UI = true }, titles = { GW2_UI = "GW2 UI" }, gw2Styled = true }
saved = {}
s = NewSession(gw2, saved)
s.OpenMenu()
p = s.prompts[1]
check(p and p.button3 == "Blizzard", "GW2_UI keeps the Blizzard button", p and p.button3)
check(s.module:GetStyleChoices().both == nil, "no Both for GW2_UI")
Click(s, 3)
check(saved.owner == "blizzard" and #s.disabled == 1, "Blizzard choice turns GW2_UI off")

-- 8. Options page change to Both explains no addon is turned off.
saved = {}
s = NewSession(CP, saved)
s.OpenMenu()
s.prompts = {}
s.module:PromptStyleChange("both")
p = s.prompts[1]
check(p and p.text == "The game menu style changes when the interface reloads.", "options Both: no 'turns off' warning", p and p.text)
p.dialog.OnAccept(nil, p.data)
check(saved.owner == "both" and #s.disabled == 0, "options Both saved, nothing off")

print(("Game menu conflict: %d checks, %d failures"):format(checks, failures))
os.exit(failures == 0 and 0 or 1)

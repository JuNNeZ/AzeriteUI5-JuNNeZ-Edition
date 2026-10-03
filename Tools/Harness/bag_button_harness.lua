--[[
	The bag button beside the cog (Components/ActionBars/Elements/MicroMenu.lua).

	Loads the real module against a fake client and checks: the button is built with or
	without the cog, it forwards to Blizzard's backpack button through a secure /click
	macro (no AzeriteUI code in the bag-opening chain), the switch applies at once out
	of combat and after combat when flipped mid-fight, it never asks for a reload, and
	the free-slot count handles full bags and an unreadable answer.

	Run from the addon root:  lua Tools/Harness/bag_button_harness.lua .
]]

local root = (arg and arg[1]) or "."

local passed, failed = 0, 0
local check = function(ok, label)
	if (ok) then passed = passed + 1 else failed = failed + 1; print("FAIL: " .. label) end
end

local Load = function(opts)
	local world = { combat = false, freeSlots = 12, drivers = {}, popups = 0, backpack = opts.backpack ~= false }

	local NewFrame
	NewFrame = function(kind, name)
		local f = { kind = kind, name = name, attributes = {}, scripts = {}, points = {} }
		local methods = {
			GetName = function(self) return self.name end,
			SetAttribute = function(self, k, v) self.attributes[k] = v end,
			GetAttribute = function(self, k) return self.attributes[k] end,
			SetScript = function(self, k, fn) self.scripts[k] = fn end,
			HookScript = function(self, k, fn) self.scripts[k] = fn end,
			GetScript = function(self, k) return self.scripts[k] or function() end end,
			CreateTexture = function() return NewFrame("Texture") end,
			CreateFontString = function()
				local fs = NewFrame("FontString")
				fs.SetText = function(self, t) self.text = t end
				fs.SetTextColor = function(self, r, g, b) self.color = { r, g, b } end
				return fs
			end,
			ClearAllPoints = function(self) self.points = {} end,
			SetPoint = function(self, ...) self.points[#self.points + 1] = { ... } end,
			IsShown = function(self) return self.shown end,
			Show = function(self) self.shown = true end,
			Hide = function(self) self.shown = false end,
		}
		return setmetatable(f, { __index = function(_, k)
			if (methods[k]) then return methods[k] end
			if (type(k) == "string" and k:match("^%u")) then return function() end end
		end })
	end

	local env = setmetatable({
		LibStub = function(name)
			if (name == "AceLocale-3.0") then
				return { GetLocale = function() return setmetatable({}, { __index = function(_, k) return k end }) end }
			end
		end,
		CreateFrame = function(kind, name) return NewFrame(kind, name) end,
		UIParent = NewFrame("Frame", "UIParent"),
		MainMenuBarBackpackButton = world.backpack and NewFrame("ItemButton", "MainMenuBarBackpackButton") or nil,
		-- One micro button, so the cog and its menu are built.
		CharacterMicroButton = NewFrame("Button", "CharacterMicroButton"),
		InCombatLockdown = function() return world.combat end,
		RegisterStateDriver = function(frame, state, value)
			if (world.combat) then error("RegisterStateDriver in combat") end
			world.drivers[frame] = value
		end,
		C_Container = { CalculateTotalNumberOfFreeBagSlots = function() return world.freeSlots end },
		StaticPopup_Show = function() world.popups = world.popups + 1 end,
		StaticPopupDialogs = {},
		GameTooltip = NewFrame("GameTooltip"),
	}, { __index = _G })
	env._G = env

	local module
	local ns = {
		Prefix = "AzeriteUI",
		HasSecureSnippets = true,
		Colors = { ui = { .1, .2, .3 }, red = { 1, 0, 0 }, normal = { 1, .7, .1 }, highlight = { 1, 1, 1 },
			offwhite = { .9, .9, .9 }, gray = { .5, .5, .5 } },
		API = {
			GetFont = function() return {} end,
			GetMedia = function(name) return "media/" .. name end,
			GetEffectiveScale = function() return 1 end,
			IsSafeNumber = function(v) return type(v) == "number" and v ~= world.secret end,
		},
		db = { RegisterNamespace = function(_, _, defaults)
			local profile = {}
			for k, v in pairs(defaults.profile) do profile[k] = v end
			for k, v in pairs(opts.profile or {}) do profile[k] = v end
			return { profile = profile }
		end },
	}
	function ns:NewModule(name)
		module = { name = name, events = {} }
		function module:GetName() return self.name end
		function module:RegisterEvent(event, handler) self.events[event] = handler end
		function module:IsHooked() return false end
		function module:SecureHook() end
		return module
	end
	function ns:GetModule() return module end

	local chunk = assert(loadfile(root .. "/Components/ActionBars/Elements/MicroMenu.lua"))
	setfenv(chunk, env)
	chunk("AzeriteUI", ns)
	module:OnInitialize()
	module:OnEnable()

	local Fire = function(event)
		local handler = module.events[event]
		if (type(handler) == "string") then module[handler](module, event) end
	end
	return module, world, Fire, env
end

do
	local m, world, Fire = Load({})
	local b = m.bagButton
	check(b ~= nil, "bag button built")
	check(b and b.attributes.type == "macro" and b.attributes.macrotext == "/click MainMenuBarBackpackButton",
		"forwards to Blizzard's backpack button through a secure /click")
	check(b and not b.scripts.OnClick, "no insecure click handler when the backpack button exists")
	check(world.drivers[b] == "[petbattle]hide;show", "shown by default, hidden in pet battles")
	check(b and b.points[1] and b.points[1][2] == m.toggle, "sits beside the cog")
	check(b and b.Count.text == 12, "free slot count shown")

	world.freeSlots = 0
	Fire("BAG_UPDATE_DELAYED")
	check(b.Count.text == 0 and b.Count.color[1] == 1 and b.Count.color[2] == 0, "full bags count in red")

	world.freeSlots, world.secret = 7, 7
	Fire("BAG_UPDATE_DELAYED")
	check(b.Count.text == "" and b.freeSlots == nil, "unreadable count left blank")
	world.secret = nil

	-- The switch, out of combat.
	m.db.profile.showBagButton = false
	m:UpdateSettings()
	check(world.drivers[b] == "hide", "switched off at once")
	check(world.popups == 0, "switching it asks for no reload")

	-- The switch, mid-fight.
	world.combat = true
	m.db.profile.showBagButton = true
	local ok = pcall(m.UpdateSettings, m)
	check(ok and world.drivers[b] == "hide", "switched in combat: deferred, no protected call")
	world.combat = false
	Fire("PLAYER_REGEN_ENABLED")
	check(world.drivers[b] == "[petbattle]hide;show", "applied when the fight ends")

	-- Bag events with no micro menu rows must not trip UpdateButtons.
	check(pcall(Fire, "PLAYER_ENTERING_WORLD"), "events run cleanly")
end

do
	local m, world, Fire = Load({ profile = { enabled = false } })
	local b = m.bagButton
	check(b ~= nil and m.toggle == nil, "built without the cog")
	check(b and b.points[1] and b.points[1][1] == "BOTTOMRIGHT", "takes the corner when the cog is off")
	check(pcall(Fire, "PLAYER_REGEN_DISABLED") and pcall(Fire, "PLAYER_ENTERING_WORLD"), "no cog, events still clean")
end

do
	local m, world = Load({ profile = { showBagButton = false } })
	check(world.drivers[m.bagButton] == "hide", "starts hidden when switched off")
end

do
	local m = Load({ backpack = false })
	local b = m.bagButton
	check(b and b.attributes.type == nil and b.scripts.OnClick ~= nil, "falls back to opening the bags itself")
end

print(string.format("bag_button_harness: %d passed, %d failed", passed, failed))
if (failed > 0) then os.exit(1) end

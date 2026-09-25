-- Flyout discovery in Libs/LibActionButton-1.0-GE, which took every action bar with it on WoW Forever
-- 1.60.1.70009 (FixLog 2026-09-25).
--
-- The lib probes flyout IDs 1-300 with pcall(GetFlyoutInfo, id) and used to count on an unknown ID
-- raising. 70009 adds C_Flyout, whose FlyoutDocumentation.lua marks GetFlyoutInfo and GetFlyoutSlotInfo
-- MayReturnNothing, and the global answers an unknown ID with nothing at all. Both behaviours are
-- modelled; everything the flyout code does not read is a universal stub.
--
-- The lib is loaded whole, as an upgrade over an older copy that already has a button, because that runs
-- InitializeEventHandler at load - the call the first CreateButton makes - and with the player logged in
-- it discovers flyouts at once. That is the reported path: an error there leaves ActionBarMod:Enable()
-- before a single bar exists. No rendering, taint or restricted-environment checks; Execute only records.
-- lua Tools/Harness/flyout_harness.lua .
-- lua Tools/Harness/flyout_harness.lua . <path to another LibActionButton-1.0-GE.lua>
-- Mutations: the "flyout" entries in mutate_client.lua.
local root = arg[1] or "."
local path = arg[2] or (root .. "/Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua")
local MAJOR = "LibActionButton-1.0-GE"
local checks, failures = 0, 0
local function check(value, label)
	checks = checks + 1
	if (not value) then
		failures = failures + 1
		print("FAIL: " .. label)
	end
end

-- Answers every field and every call with itself, and swallows writes. Its metatable is locked, so
-- the lib cannot adopt it as a button (UpdateAction re-metatables its buttons) and break later loads.
local Stub = {}
setmetatable(Stub, {
	__index = function() return Stub end,
	__call = function() return Stub end,
	__newindex = function() end,
	__metatable = false,
})

-- The upgrade block runs InitializeEventHandler, then refreshes every old button. That refresh is
-- button code, not flyout code, so the old button stops the load the moment it is touched: reaching
-- it means event setup, and with it discovery, finished. Any other error is a real failure.
local REACHED_BUTTONS = setmetatable({}, { __tostring = function() return "reached the old buttons" end })

-- The flyouts this client knows. ID 1 is deliberately absent: it was the reporter's first probe.
local FLYOUTS = {
	[8] = { isKnown = true, slots = { 101, 102, 103 } },
	[66] = { isKnown = false, slots = { 201, 202 } },
	[229] = { isKnown = true, slots = { 301 } },
}

-- Only Lua itself comes from the real globals, so nothing another harness left behind leaks in.
local LUA = {
	"assert", "error", "getmetatable", "ipairs", "next", "pairs", "pcall", "print", "rawequal", "rawget",
	"rawset", "select", "setmetatable", "tonumber", "tostring", "type", "unpack", "xpcall",
	"coroutine", "math", "string", "table",
}

-- Must read as nil: a stub here would switch the custom flyout off (UseCustomFlyout).
local ABSENT = { ActionButton_UpdateFlyout = true }

local function Load(client)
	local world = { flyoutCalls = 0, executed = {}, fired = {}, flyouts = {} }
	for id, info in pairs(FLYOUTS) do
		world.flyouts[id] = info
	end
	local scripts = {}

	-- Widget methods start with a capital; an unset lowercase field reads nil, as in the game.
	local function NewFrame()
		return setmetatable({}, { __index = function(_, key)
			if (key == "SetScript") then
				return function(self, name, fn)
					scripts[self] = scripts[self] or {}
					scripts[self][name] = fn
				end
			elseif (key == "Execute") then
				return function(_, body) world.executed[#world.executed + 1] = body end
			elseif (type(key) == "string" and key:match("^%u")) then
				return function() return Stub end
			end
		end })
	end

	-- An older copy of the lib with one live button, so this load is an upgrade. Three flyout buttons
	-- already exist, enough for every flyout here, so the sync never has to make one.
	local oldButton = setmetatable({}, { __index = function() error(REACHED_BUTTONS, 0) end })
	local libs = { [MAJOR] = { buttonRegistry = { [oldButton] = true }, FlyoutButtons = { Stub, Stub, Stub } } }
	local minors = { [MAJOR] = 76 }
	local CBH = { New = function()
		return { Fire = function(_, name) world.fired[#world.fired + 1] = name end }
	end }
	local LibStub = setmetatable({
		NewLibrary = function(_, major, minor)
			local old = minors[major]
			if (old and old >= minor) then return nil end
			minors[major] = minor
			libs[major] = libs[major] or {}
			return libs[major], old
		end,
	}, { __call = function(_, major, silent)
		if (major == "CallbackHandler-1.0") then return CBH end
		if (libs[major]) then return libs[major] end
		if (not silent) then error("LibStub: missing " .. major, 2) end
	end })

	local env = {
		LibStub = LibStub,
		format = string.format, strmatch = string.match, tinsert = table.insert, tremove = table.remove,
		wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
		hooksecurefunc = function() end,
		issecretvalue = function() return false end,
		CreateFrame = function() return NewFrame() end,
		FlyoutButtonMixin = {},
		IsLoggedIn = function() return client.loggedIn end,
		InCombatLockdown = function() return false end,
		GetFlyoutInfo = function(id)
			world.flyoutCalls = world.flyoutCalls + 1
			local flyout = world.flyouts[id]
			if (flyout) then return "Flyout " .. id, "", #flyout.slots, flyout.isKnown end
			if (client.raises) then error("Invalid flyout ID", 2) end
		end,
		GetFlyoutSlotInfo = function(id, slot)
			local flyout = world.flyouts[id]
			local spellID = flyout and flyout.slots[slot]
			if (spellID) then return spellID, spellID, flyout.isKnown, "Spell " .. spellID end
		end,
		GetCallPetSpellInfo = function() return nil end,
	}
	for _, name in ipairs(LUA) do
		env[name] = _G[name]
	end
	env._G = env
	setmetatable(env, { __index = function(_, key)
		if (not ABSENT[key]) then return Stub end
	end })

	local chunk = assert(loadfile(path))
	setfenv(chunk, env)
	local ns = { HasSecureSnippets = client.snippets }
	local ok, err = pcall(chunk, "AzeriteUI5_JuNNeZ_Edition", ns)
	if (not ok and err == REACHED_BUTTONS) then
		ok, err = true, nil
	elseif (ok) then
		ok, err = false, "the load never reached the old buttons, so the upgrade path did not run"
	end

	local lib = libs[MAJOR]
	local function Fire(event)
		local handler = scripts[lib.eventFrame] and scripts[lib.eventFrame].OnEvent
		if (not handler) then return false, "no OnEvent handler was set" end
		return pcall(handler, lib.eventFrame, event)
	end
	return ok, err, lib, world, Fire
end

local function Keys(t)
	local keys = {}
	for key in pairs(t) do
		keys[#keys + 1] = key
	end
	table.sort(keys)
	return table.concat(keys, ",")
end

local function Executed(world, fragment)
	for _, body in ipairs(world.executed) do
		if (body:find(fragment, 1, true)) then return true end
	end
	return false
end

local clients = {
	{ name = "Retail 12.1.0", snippets = true, raises = true },
	{ name = "a client with C_Flyout and restricted execution", snippets = true, raises = false },
	{ name = "Forever 1.60.1.70009", snippets = false, raises = false },
	{ name = "Forever 1.60.1.69913", snippets = false, raises = true },
}

for _, client in ipairs(clients) do
	for _, loggedIn in ipairs({ true, false }) do
		client.loggedIn = loggedIn
		local function label(text)
			return client.name .. (loggedIn and ", buttons made after login: " or ", buttons made before login: ") .. text
		end

		local ok, err, lib, world, Fire = Load(client)
		check(ok, label("the lib loads and gets past its first button (" .. tostring(err) .. ")"))
		if (ok and not loggedIn) then
			local fired, fireErr = Fire("PLAYER_LOGIN")
			check(fired, label("PLAYER_LOGIN discovers flyouts without raising (" .. tostring(fireErr) .. ")"))
		end

		if (ok) then
			if (client.snippets) then
				check(Keys(lib.FlyoutInfo) == "8,66,229",
					label("every real flyout discovered and nothing else, got " .. Keys(lib.FlyoutInfo)))
				local eight = lib.FlyoutInfo[8]
				check(eight and eight.numSlots == 3 and #eight.slots == 3 and eight.slots[3].spellID == 103,
					label("a flyout's slots are recorded"))
				check(Executed(world, "LAB_FlyoutInfo[8] = info") and Executed(world, "LAB_FlyoutInfo[229] = info"),
					label("known flyouts reach the restricted environment"))
				check(not Executed(world, "LAB_FlyoutInfo[66] = info"), label("an unknown flyout does not"))
			else
				-- The custom flyout opens only from a restricted closure; without one the data has no reader.
				check(world.flyoutCalls == 0, label("no flyout is probed without restricted execution, got "
					.. world.flyoutCalls .. " calls"))
				check(next(lib.FlyoutInfo) == nil, label("nothing is recorded without restricted execution"))
			end

			local fired, fireErr = Fire("SPELLS_CHANGED")
			check(fired, label("SPELLS_CHANGED updates flyouts without raising (" .. tostring(fireErr) .. ")"))

			if (client.snippets) then
				-- A flyout that stops answering mid-session (a hotfix) is skipped, not fatal.
				world.flyouts[229] = nil
				fired, fireErr = Fire("SPELL_FLYOUT_UPDATE")
				check(fired, label("a flyout that stops answering is skipped (" .. tostring(fireErr) .. ")"))
				check(lib.FlyoutInfo[8] and lib.FlyoutInfo[8].isKnown == true, label("the others are still updated"))
			end
		end
	end
end

print(string.format("Flyout: %d checks, %d failures", checks, failures))
-- Raised rather than os.exit, so mutate_client.lua can run this inside a pcall.
if (failures > 0) then error("flyout harness failed", 0) end

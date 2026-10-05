-- Run from the addon root: lua Tools/Harness/sanity_bar_harness.lua .
-- Checks the addon/native execution boundary, not live WoW secret values.
local root = (arg and arg[1]) or "."
local passed, failed = 0, 0
local function Check(ok, label)
	if ok then passed = passed + 1 else failed = failed + 1; print("FAIL: " .. label) end
end

local function Load(opts)
	local world = { frames = {}, tickers = {}, scriptReads = 0, handlerCalls = 0, disables = 0 }
	local function NewFrame()
		local frame = { events = {}, scripts = {}, hidden = false }
		function frame:RegisterEvent(event) self.events[event] = true end
		function frame:UnregisterEvent(event) self.events[event] = nil end
		function frame:SetScript(event, func) self.scripts[event] = func end
		function frame:GetScript(event)
			world.scriptReads = world.scriptReads + 1
			return self.scripts[event]
		end
		function frame:Hide() self.hidden = true end
		return frame
	end
	local alt = NewFrame()
	alt.scripts.OnEvent = function() world.handlerCalls = world.handlerCalls + 1 end
	local env = setmetatable({
		PlayerPowerBarAlt = not opts.missing and alt or nil,
		SlashCmdList = {},
		CreateFrame = function()
			local frame = NewFrame()
			world.frames[#world.frames + 1] = frame
			return frame
		end,
		C_Timer = { NewTicker = function(_, callback, iterations)
			world.tickers[#world.tickers + 1] = { callback = callback, iterations = iterations }
		end },
	}, { __index = _G })
	env._G = env
	local ns = {
		WoW11 = not opts.legacy,
		API = { TryCall = pcall },
		oUF = { objects = { { DisableElement = function(_, element)
			assert(element == "AlternativePower")
			world.disables = world.disables + 1
		end } } },
		GetActiveConfigVariant = function() return opts.saiya and "SaiyaRatt" or "Azerite" end,
	}
	local chunk = assert(loadfile(root .. "/Components/Misc/SanityBarFix.lua"))
	setfenv(chunk, env)
	chunk("AzeriteUI", ns)
	local function Fire(event, ...)
		local frame = world.frames[1]
		if frame and frame.events[event] then frame.scripts.OnEvent(frame, event, ...) end
	end
	return world, alt, Fire, env
end

local restored = { "UNIT_POWER_BAR_SHOW", "UNIT_POWER_BAR_HIDE", "PLAYER_ENTERING_WORLD",
	"UNIT_POWER_UPDATE", "UNIT_MAXPOWER" }
do
	local w, alt, Fire = Load({})
	Fire("PLAYER_LOGIN")
	Check(w.disables == 1, "oUF alternate power disabled at login")
	for _, ticker in ipairs(w.tickers) do
		for _ = 1, ticker.iterations do ticker.callback() end
	end
	Check(w.disables == 13, "late oUF objects checked for six seconds")
	Fire("PLAYER_ENTERING_WORLD")
	for _, event in ipairs(restored) do Check(alt.events[event], event .. " restored") end
	Check(not alt.hidden, "normal layout keeps Blizzard bar available")
	alt.events.UNIT_POWER_BAR_SHOW = nil
	Fire("UNIT_POWER_BAR_SHOW", "target")
	Check(not alt.events.UNIT_POWER_BAR_SHOW, "other units do not restore player events")
	Fire("UNIT_POWER_BAR_SHOW", "player")
	Check(alt.events.UNIT_POWER_BAR_SHOW, "player show restores events")
	Check(w.scriptReads == 0 and w.handlerCalls == 0, "never acquires or calls Blizzard OnEvent")
	Check(alt.value == nil and alt.displayedValue == nil, "does not write native power fields")
	-- Fake native dispatch remains possible with the original script intact.
	local callsBefore = w.handlerCalls
	alt.scripts.OnEvent(alt, "UNIT_POWER_BAR_SHOW", "player")
	Check(w.handlerCalls == callsBefore + 1, "original native handler retained")
end
do
	local w, alt, Fire = Load({ saiya = true })
	for _, event in ipairs(restored) do alt.events[event] = true end
	Fire("PLAYER_LOGIN")
	Check(alt.hidden and w.disables == 0, "SaiyaRatt suppression preserved")
	for _, event in ipairs(restored) do Check(not alt.events[event], event .. " suppressed") end
	Check(w.handlerCalls == 0, "SaiyaRatt never invokes native handler")
end
do
	local w, _, Fire = Load({ missing = true })
	Fire("PLAYER_LOGIN")
	Check(pcall(Fire, "PLAYER_ENTERING_WORLD"), "missing bar tolerated")
	Check(w.handlerCalls == 0, "missing bar does not cause synthetic updates")
end
do
	local w, _, _, env = Load({ legacy = true })
	Check(#w.frames == 0 and env.SLASH_SANITYBARFIX1 == nil, "legacy client left alone")
end

print(string.format("sanity_bar_harness: %d passed, %d failed", passed, failed))
if failed > 0 then os.exit(1) end

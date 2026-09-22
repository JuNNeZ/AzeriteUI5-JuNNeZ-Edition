-- Chat replacements (Prat-3.0, ls_Glass, BigInputBox, Chattynator) take over the chat frames or
-- the editbox, so Components/Misc/ChatFrames.lua must not build its module while one is enabled.
-- Chattynator anchors ChatFrame1EditBox to its own window at login; StyleFrame running on
-- PLAYER_ENTERING_WORLD re-anchored it under ChatFrame1 until 5.8.0. This loads the real file and
-- checks both guards: the file-level return and OnInitialize. No frames, rendering or taint.
-- lua Tools/Harness/chat_guard_harness.lua .
-- lua Tools/Harness/chat_guard_harness.lua . <path to a mutated ChatFrames.lua>
local root = arg[1] or "."
local path = arg[2] or (root .. "/Components/Misc/ChatFrames.lua")
local checks, failures = 0, 0
local function check(value, label)
	checks = checks + 1
	if (not value) then
		failures = failures + 1
		print("FAIL: " .. label)
	end
end

local frameMeta = { __index = { SetAlpha = function() end, GetAlpha = function() return 1 end } }
local env = setmetatable({
	CreateFrame = function() return setmetatable({}, frameMeta) end,
	CHAT_FONT_HEIGHTS = { 10, 12 },
	CHAT_FRAMES = {}
}, { __index = _G })

-- Loads the file with the given addons enabled. Returns what happened, the module (if one was
-- built) and the enabled set, which a caller may change before calling OnInitialize.
local function load(enabled)
	local state = { created = false, disabled = false, namespaced = false }
	local module = {
		GetName = function() return "ChatFrames" end,
		Disable = function() state.disabled = true end,
		RegisterChatCommand = function() end
	}
	local ns = {
		API = {
			IsAddOnEnabled = function(name) return enabled[name] and true or nil end,
			GetFont = function() end
		},
		Hider = {},
		MovableModulePrototype = { defaults = {} },
		Merge = function(_, a) return a end,
		db = { RegisterNamespace = function() state.namespaced = true; return { profile = {} } end },
		NewModule = function() state.created = true; return module end
	}
	local chunk = assert(loadfile(path))
	setfenv(chunk, env)
	chunk("AzeriteUI5_JuNNeZ_Edition", ns)
	return state, module, enabled
end

local REPLACEMENTS = { "Prat-3.0", "ls_Glass", "BigInputBox", "Chattynator" }

-- File-level guard: with any replacement enabled the module is never created.
for _, name in ipairs(REPLACEMENTS) do
	local state = load({ [name] = true })
	check(not state.created, "module not created with " .. name .. " enabled")
end

-- No replacement: the module is created and initializes normally.
local state, module = load({})
check(state.created, "module created with no chat replacement")
module:OnInitialize()
check(not state.disabled, "OnInitialize does not disable with no chat replacement")
check(state.namespaced, "OnInitialize registers its db namespace")

-- OnInitialize guard: reads the same list, so each replacement disables it.
for _, name in ipairs(REPLACEMENTS) do
	local s, m, e = load({})
	e[name] = true
	m:OnInitialize()
	check(s.disabled, "OnInitialize disables with " .. name .. " enabled")
	check(not s.namespaced, "OnInitialize returns before its db with " .. name .. " enabled")
end

-- Similar names are not matches.
check(load({ ["Chattynator_Extra"] = true, ["Prat"] = true }).created,
	"similarly named addons do not disable the module")

print(string.format("Chat guard: %d checks, %d failures", checks, failures))
os.exit(failures == 0 and 0 or 1)

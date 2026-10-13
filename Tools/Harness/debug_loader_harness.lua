-- Core/DebugLoader.lua and the load-on-demand companion AzeriteUI5_JuNNeZ_Edition_Debug.
-- Loads the real loader against stubs: commands, loading on first use, forwarding,
-- the saved debug switches and script errors. Then checks the companion's files: the
-- TOCs list only files that exist, the main addon no longer loads them, and a
-- companion file finds the main namespace through the global, as it must in game.
-- Run: lua.exe Tools/Harness/debug_loader_harness.lua <addon root>
local root = arg[1] or '.'
local checks, failures = 0, 0
local function check(v, msg)
	checks = checks + 1
	if (not v) then failures = failures + 1; io.write("FAIL: ", msg, string.char(10)) end
end
local function read(path)
	local f = io.open(root .. "/" .. path, "rb")
	if (not f) then return nil end
	local text = f:read("*a"); f:close(); return text
end

-- Client.
local cvars, printed = {}, {}
C_CVar = { SetCVar = function(name, value) cvars[name] = value end }
local realPrint = print
print = function(...)
	local parts = {}
	for i = 1, select("#", ...) do parts[i] = tostring((select(i, ...))) end
	printed[#printed + 1] = table.concat(parts, " ")
end
local companionAvailable, loadCalls = true, 0
local modules = {}
local debugModule
C_AddOns = { LoadAddOn = function(name)
	loadCalls = loadCalls + 1
	if (name ~= "AzeriteUI5_JuNNeZ_Edition_Debug") then return false, "MISSING" end
	if (not companionAvailable) then return false, "DISABLED" end
	-- As AceAddon does on the companion's ADDON_LOADED: the module now exists.
	debugModule = { calls = {} }
	for _, method in ipairs({ "DebugMenu", "DebugKeysMenu", "TargetDebugMenu", "TestModeCommand", "SecretJuNNeZCommand", "SecretGoldpawCommand" }) do
		debugModule[method] = function(self, input) self.calls[#self.calls + 1] = { method, input } end
	end
	modules.Debugging = debugModule
	return true
end }

-- Namespace and module system.
local chat, events = {}, {}
local ns = { API = {}, WoW10 = true, db = { global = {
	debugHealth = true, debugHealthChat = false, debugBars = true, debugAurasFilter = "Rejuv",
	debugHealthFilter = "", runtimeUnitTestMode = true, debugKeysVerbose = true
} } }
ns.NewModule = function(_, name)
	local module = {
		RegisterChatCommand = function(self, command, fn) chat[command] = fn end,
		RegisterEvent = function(self, event, method) events[event] = method end
	}
	modules[name] = module
	return module
end
ns.GetModule = function(_, name) return modules[name] end

assert(loadfile(root .. "/Core/DebugLoader.lua"))("AzeriteUI5_JuNNeZ_Edition", ns)
local loader = modules.DebugLoader
loader:OnInitialize()

-- What used to happen for every player at load still happens.
for _, command in ipairs({ "azdebug", "azdebugkeys", "azdebugtarget", "aztest", "junnez", "goldpaw" }) do
	check(type(chat[command]) == "function", "/" .. command .. " is answered before the companion loads")
end
check(cvars.scriptErrors == "1", "script errors switched on at load, as before")
check(events.PLAYER_ENTERING_WORLD and events.VARIABLES_LOADED and events.SETTINGS_LOADED, "and again on the same events as before")
cvars.scriptErrors = "0"
loader[events.PLAYER_ENTERING_WORLD](loader, "PLAYER_ENTERING_WORLD")
check(cvars.scriptErrors == "1", "entering the world switches script errors back on")
check(ns.db.global.runtimeUnitTestMode == false, "unit test mode never survives a reload")
check(ns.API.DEBUG_HEALTH == true and ns.API.DEBUG_HEALTH_CHAT == false, "saved health switches applied")
check(_G.__AzeriteUI_DEBUG_BARS == true and _G.__AzeriteUI_DEBUG_KEYS == true, "saved global switches applied")
check(ns.API.DEBUG_AURA_FILTER == "Rejuv" and ns.API.DEBUG_POWER_FILTER == "", "filters applied, unset ones empty")
check(ns.API.DEBUG_HEALTH_FILTER == "Target." and ns.db.global.debugHealthFilter == "Target.", "empty health filter defaults to Target.")
check(loadCalls == 0, "nothing is loaded at login")

-- First use: loads, then forwards the input to the right handler.
chat.azdebug("sated")
check(loadCalls == 1, "/azdebug loads the companion")
check(debugModule.calls[1] and debugModule.calls[1][1] == "DebugMenu" and debugModule.calls[1][2] == "sated", "and hands it the input")
chat.azdebugkeys("status")
check(loadCalls == 1, "loaded once only")
check(debugModule.calls[2][1] == "DebugKeysMenu" and debugModule.calls[2][2] == "status", "each command reaches its own handler")
check(ns.LoadDebugTools() == debugModule, "ns.LoadDebugTools returns the loaded module")

-- Companion missing or disabled: a clear message, no error.
modules.Debugging, companionAvailable, printed = nil, false, {}
local ok = pcall(chat.aztest, "on")
check(ok, "a disabled companion raises nothing")
check(printed[1] and printed[1]:find("disabled in the AddOns list", 1, true), "and says why: " .. tostring(printed[1]))
local module, reason = ns.LoadDebugTools()
check(module == nil and reason == "DISABLED", "LoadDebugTools passes the client's reason on")

-- The companion's files.
local toc = read("AzeriteUI5_JuNNeZ_Edition_Debug/AzeriteUI5_JuNNeZ_Edition_Debug.toc")
local camelot = read("AzeriteUI5_JuNNeZ_Edition_Debug/AzeriteUI5_JuNNeZ_Edition_Debug_Camelot.toc")
check(toc and camelot, "both companion TOCs exist (Tools/BuildClientTOC.ps1)")
for _, text in ipairs({ toc or "", camelot or "" }) do
	check(text:find("## LoadOnDemand: 1", 1, true) and text:find("## Dependencies: AzeriteUI5_JuNNeZ_Edition", 1, true),
		"companion is load on demand and depends on the main addon")
	for line in text:gmatch("[^\r\n]+") do
		if (not line:find("^#") and line:find("%.lua$")) then
			check(read("AzeriteUI5_JuNNeZ_Edition_Debug/" .. line) ~= nil, "TOC file exists: " .. line)
		end
	end
end
local mainToc = read("AzeriteUI5_JuNNeZ_Edition.toc") or ""
check(mainToc:match("## Version:%s*(%S+)") == (toc or ""):match("## Version:%s*(%S+)"), "companion version matches the main TOC")
check(mainToc:match("## Interface:%s*(%S+)") == (toc or ""):match("## Interface:%s*(%S+)"), "companion interface matches the main TOC")
check(not (read("Core/Core.xml") or ""):find("Debugging.lua", 1, true), "the main addon no longer loads Debugging.lua")
check(not (read("Components/UnitFrames/UnitFrames.xml") or ""):find("AuraCostProbe", 1, true), "nor AuraCostProbe.lua")
check(read("AzeriteUI5_JuNNeZ_Edition_Debug/probe.svg") ~= nil, "the SVG probe's file ships with it")

-- In game a companion file's `...` names the companion; it must use the main namespace.
local mainNS = { API = { GetMedia = function() return "x" end } }
_G["AzeriteUI5_JuNNeZ_Edition"] = mainNS
local companionNS = {}
assert(loadfile(root .. "/AzeriteUI5_JuNNeZ_Edition_Debug/RenderProbe.lua"))("AzeriteUI5_JuNNeZ_Edition_Debug", companionNS)
check(mainNS.RenderProbe and not companionNS.RenderProbe, "a companion file registers on the main addon's namespace")
_G["AzeriteUI5_JuNNeZ_Edition"] = nil
local passedNS = { API = {} }
assert(loadfile(root .. "/AzeriteUI5_JuNNeZ_Edition_Debug/RenderProbe.lua"))("AzeriteUI", passedNS)
check(passedNS.RenderProbe, "and on the passed namespace when there is no global (harnesses)")

realPrint(string.format("Debug loader: %d checks, %d failures (offline only).", checks, failures))
if (failures > 0) then os.exit(1) end

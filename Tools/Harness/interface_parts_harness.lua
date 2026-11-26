-- /az -> Interface Parts: the core profile's disabledParts (Core/Core.lua) and its page
-- (Options/OptionsPages/InterfaceParts.lua), driven through the real AceDB-GE and AceAddon.
-- Checks: a part that is off never runs its own OnEnable, on the login path and on an explicit
-- :Enable() (Retail's delayed starts, WoW11/Misc/*.lua); its mixins' OnEmbedDisable still runs
-- (AceHook unhooks there); a part that is on enables as before; names outside ns.ToggleableParts
-- are never read or written; turning a part on starts it at once only where its OnEnable allows,
-- never in combat, and an OnEnable that refuses leaves the reload owed; the page asks for a
-- reload only when a switch differs from what runs, names the addon a part stands down for, and
-- passes AceConfigRegistry's validation (/az classic, /az legacy).
-- The mirrors of other pages' switches are checked against the real options table in
-- frame_panel_harness.lua.
-- lua Tools/Harness/interface_parts_harness.lua            (from the repo root)
-- lua Tools/Harness/interface_parts_harness.lua <Core.lua>  (a mutated copy, to see it fail)
local corePath = arg[1] or "Core/Core.lua"
local checks, failures = 0, 0
local function check(value, label, detail)
	checks = checks + 1
	if (not value) then
		failures = failures + 1
		print("FAIL: " .. label .. (detail ~= nil and ("  (" .. tostring(detail) .. ")") or ""))
	end
end

-- Client stubs (as Tools/Harness/character_settings_harness.lua).
GetRealmName = function() return "Realm" end
UnitName = function() return "Tester" end
UnitClass = function() return "Druid", "DRUID" end
UnitRace = function() return "Night Elf", "NightElf" end
UnitFactionGroup = function() return "Alliance" end
GetLocale = function() return "enUS" end
GetCurrentRegion = function() return 3 end
RegionalUniqueNamesEnabled = function() return true end
Enum = { GameRule = {} }
C_GameRules = { IsGameRuleActive = function() return false end }
securecallfunction = function(func, ...) return func(...) end
-- WoW's xpcall passes extra arguments on (AceAddon's safecall relies on it); Lua 5.1's drops them.
do
	local xpcall51 = xpcall
	xpcall = function(func, handler, ...)
		local n, args = select("#", ...), { ... }
		return xpcall51(function() return func(unpack(args, 1, n)) end, handler)
	end
end
geterrorhandler = function() return function(err) print("ERROR: " .. tostring(err)) end end
IsLoggedIn = function() return false end
local scripts = {}
CreateFrame = function()
	local frame = { Hide = function() end, RegisterEvent = function() end, UnregisterEvent = function() end }
	frame.SetScript = function(self, script, func) scripts[#scripts + 1] = func end
	return frame
end
local inCombat = false
InCombatLockdown = function() return inCombat end
ReloadUI = function() end

dofile("Libs/LibStub/LibStub.lua")
dofile("Libs/CallbackHandler-1.0/CallbackHandler-1.0.lua")
LibStub:NewLibrary("LibDeflate", 1)
LibStub:NewLibrary("AceAddon-3.0", 1).NewAddon = function(_, ns) return ns end
dofile("Libs/AceDB-3.0-GE/AceDB-3.0-GE.lua")

-- A mixin that records what AceAddon asks of it, standing in for AceHook-3.0.
local hooks = LibStub:NewLibrary("PartsTestHook-1.0", 1)
hooks.disabled = {}
hooks.Embed = function(self, target) return target end
hooks.OnEmbedDisable = function(self, target) hooks.disabled[target:GetName()] = true end

-- Boot the addon core with a saved profile that turns parts off.
AzeriteUI5_DB = {
	global = { version = 25 },
	profiles = { Azerite = { disabledParts = {
		Tooltips = true, Durability = true, ChatFrames = false, Options = true, Bogus = true,
		Banners = true, VehicleSeat = true, Containers = true
	} } }
}
local modules = {}
local ns = {
	Prefix = "Azerite",
	ThemeEffects = { ApplyPendingTheme = function() end },
	RegisterChatCommand = function() end,
	GetModule = function(self, name) return modules[name] end
}
assert(loadfile("Core/CharacterSettings.lua"))("AzeriteUI", ns)
assert(loadfile(corePath))("AzeriteUI", ns)
ns:OnInitialize()
check(ns.db:GetCurrentProfile() == "Azerite", "boots on the saved Azerite profile")

-- The real AceAddon, loaded over the stub, with modules shaped like the addon's own.
LibStub.minors["AceAddon-3.0"] = 0
dofile("Libs/AceAddon-3.0/AceAddon-3.0.lua")
local AceAddon = LibStub("AceAddon-3.0")
local host = AceAddon:NewAddon("PartsTest")
local ran = {}
local function Make(name, delayed)
	local module = host:NewModule(name, "PartsTestHook-1.0")
	module.OnEnable = function(self) ran[name] = (ran[name] or 0) + 1 end
	if (delayed) then module:SetEnabledState(false) end -- as WoW11/Misc/Tooltips.lua does
	modules[name] = module
	return module
end
Make("Tooltips", true)
Make("Durability")
Make("ChatFrames")
Make("Tracker")
Make("Banners") -- can start live, off at login
local seat = Make("VehicleSeat") -- can start live, but here its OnEnable refuses (as PlayerStatusBars does without the minimap)
seat.OnEnable = function(self) ran.VehicleSeat = (ran.VehicleSeat or 0) + 1; self:Disable() end
Make("Containers") -- gives Blizzard's bag bar back while off, so never started live
Make("Options") -- never toggleable, even with a saved value
-- Can stop mid-session: StopPart and PostPartStart record what Core asked of them.
local stopped, restarted = 0, 0
local info = Make("Info")
info.StopPart = function(self) stopped = stopped + 1 end
info.PostPartStart = function(self) restarted = restarted + 1 end

ns:OnEnable() -- runs ApplyDisabledParts, before the host enables its modules
for _, onEvent in ipairs(scripts) do onEvent(nil, "ADDON_LOADED", "PartsTest") end
IsLoggedIn = function() return true end
for _, onEvent in ipairs(scripts) do onEvent(nil, "PLAYER_LOGIN") end

check(not ran.Durability and not modules.Durability:IsEnabled(), "a part that is off never runs its OnEnable at login")
check(hooks.disabled.Durability, "a part that is off still runs its mixins' OnEmbedDisable")
check(ran.ChatFrames == 1 and modules.ChatFrames:IsEnabled(), "a part saved as on (false) enables")
check(ran.Tracker == 1 and modules.Tracker:IsEnabled(), "a part with no saved value enables")
check(ran.Options == 1 and modules.Options.partActive == nil, "names outside ns.ToggleableParts are ignored")
check(not ran.Tooltips and not modules.Tooltips:IsEnabled(), "a delayed part has not enabled yet")
modules.Tooltips:Enable() -- Retail's delayed start
check(not ran.Tooltips and not modules.Tooltips:IsEnabled(), "an explicit :Enable() on a part that is off ends disabled")
check(hooks.disabled.Tooltips, "the explicit :Enable() path also unhooks")

-- The core API.
check(ns:IsPartDisabled("Durability") and not ns:IsPartDisabled("ChatFrames"), "IsPartDisabled reads true and false")
check(not ns:IsPartDisabled("Options") and not ns:IsPartDisabled("Bogus"), "IsPartDisabled ignores unlisted names")
ns:SetPartDisabled("Options", true)
ns:SetPartDisabled("Nope", true)
check(ns.db.profile.disabledParts.Nope == nil, "SetPartDisabled refuses unlisted names")
ns:SetPartDisabled("Tracker", true)
check(ns.db.profile.disabledParts.Tracker == true, "SetPartDisabled stores a part as off")
check(ns:IsPartPending("Tracker"), "a running part switched off owes a reload")
ns:SetPartDisabled("Tracker", false)
check(ns.db.profile.disabledParts.Tracker == nil and not ns:IsPartPending("Tracker"), "switching it back on clears both")

-- Starting a part without a reload.
check(not ns:CanStartPartNow("Tooltips"), "Tooltips waits for a reload (it sets up on PLAYER_ENTERING_WORLD)")
check(not ns:CanStartPartNow("Tracker"), "a part that is already running is not started again")
check(not ns:StartPartNow("Banners"), "a part still switched off is not started")
ns:SetPartDisabled("Banners", false)
inCombat = true
check(not ns:CanStartPartNow("Banners") and not ns:StartPartNow("Banners") and not ran.Banners, "never in combat")
inCombat = false
check(ns:StartPartNow("Banners") and ran.Banners == 1 and modules.Banners:IsEnabled(), "Banners starts at once, with its own OnEnable")
check(not ns:IsPartPending("Banners"), "and owes no reload")
check(not ns:StartPartNow("Banners") and ran.Banners == 1, "starting it twice does nothing")
ns:SetPartDisabled("VehicleSeat", false)
check(not ns:StartPartNow("VehicleSeat") and ran.VehicleSeat == 1, "an OnEnable that refuses leaves the part off")
check(ns:IsPartPending("VehicleSeat"), "and the reload is still owed")
ns:SetPartDisabled("VehicleSeat", true)
ns:SetPartDisabled("Containers", false)
check(not ns:CanStartPartNow("Containers") and ns:IsPartPending("Containers"), "Blizzard's bag bar is back for this session, so the bags wait for a reload")
ns:SetPartDisabled("Containers", true)

-- Stopping a part without a reload.
check(ran.Info == 1 and modules.Info:IsEnabled(), "the info bar runs from login")
check(not ns:StopPartNow("Info"), "a part still switched on is not stopped")
ns:SetPartDisabled("Info", true)
inCombat = true
check(not ns:StopPartNow("Info") and stopped == 0 and modules.Info:IsEnabled(), "never stopped in combat")
check(ns:IsPartPending("Info"), "so the reload is owed meanwhile")
inCombat = false
check(ns:StopPartNow("Info") and stopped == 1 and not modules.Info:IsEnabled(), "the info bar stops at once, through its StopPart")
check(hooks.disabled.Info and not ns:IsPartPending("Info"), "unhooked, and no reload owed")
modules.Info:Enable() -- another module's explicit enable, as Minimap's does for the bars
check(ran.Info == 1 and not modules.Info:IsEnabled(), "a stopped part cannot be brought back by another module")
ns:SetPartDisabled("Info", false)
check(ns:StartPartNow("Info") and ran.Info == 2 and restarted == 1 and modules.Info:IsEnabled(),
	"and starts again with its own OnEnable and PostPartStart")
ns:SetPartDisabled("Tracker", true)
check(not ns:StopPartNow("Tracker") and modules.Tracker:IsEnabled() and ns:IsPartPending("Tracker"),
	"a part that changes Blizzard's frames is not stopped live; the reload is owed")
ns:SetPartDisabled("Tracker", false)

-- The page.
local page
LibStub:NewLibrary("AceLocale-3.0", 1).GetLocale = function()
	return setmetatable({}, { __index = function(_, key) return key end })
end
modules.Options = { AddGroup = function(_, key, generate) assert(key == "Interface Parts"); page = generate end }
assert(loadfile("Options/OptionsPages/InterfaceParts.lua"))("AzeriteUI", ns)
local function Build()
	local options = assert(page and page(), "the page builds")
	local byName = {}
	for _, option in pairs(options.args) do
		if (option.type == "toggle" and type(option.name) == "string") then byName[option.name] = option end
	end
	return options.args, byName
end
local args, rows = Build()

-- /az classic and /az legacy hand the table to AceConfigRegistry, which refuses
-- unknown keys; the mirror and hover marks live beside the table (Config.lua).
dofile("Libs/AceConfig-3.0/AceConfigRegistry-3.0/AceConfigRegistry-3.0.lua")
local valid, problem = pcall(LibStub("AceConfigRegistry-3.0").ValidateOptionsTable,
	LibStub("AceConfigRegistry-3.0"), assert(page()), "InterfaceParts")
check(valid, "the page passes AceConfigRegistry's validation", problem)
check(rows.Tooltips and rows.Durability and rows.Chat and rows["Objectives Tracker"] and rows.Banners, "existing parts are listed")
check(not rows["Encounter Bar"] and not rows["Breath / Fatigue"], "missing modules are not listed")
check(rows.Durability.get() == false and rows["Objectives Tracker"].get() == true, "switches read the profile")
check(args.reload.disabled() == true, "no reload asked while every switch matches what runs")
rows["Objectives Tracker"].set(nil, false)
check(ns:IsPartDisabled("Tracker") and args.reload.disabled() == false, "turning a part off asks for a reload")
rows["Objectives Tracker"].set(nil, true)
check(args.reload.disabled() == true, "turning it back on before a reload cancels the request")
rows.Durability.set(nil, true)
check(not ns:IsPartDisabled("Durability") and args.reload.disabled() == false, "a part that cannot start live asks for a reload")
check(rows.Durability.desc() == "Takes effect after a reload." and rows.Tooltips.desc() == nil,
	"the switch waiting for a reload says so; the others do not")
inCombat = true
check(args.reload.disabled() == true, "no reload button in combat")
inCombat = false
check(type(rows.Bags.desc()) == "string", "a part with more to say carries a note")
rows["Info Bar"].set(nil, false)
check(not modules.Info:IsEnabled() and rows["Info Bar"].desc() == nil, "the info bar switch stops it at once, with nothing owed")
rows["Info Bar"].set(nil, true)
check(modules.Info:IsEnabled() and rows["Info Bar"].desc() == nil, "and starts it again")

-- A part that stands down for another addon.
ns.API = { IsAddOnEnabled = function(addon) return addon == "Chattynator" end, GetAddOnTitle = function(addon) return addon end }
ns.PartStandDowns.ChatFrames = { "Prat-3.0", "Chattynator" }
check(ns:GetPartStandDown("ChatFrames") == "Chattynator" and ns:GetPartStandDown("Tooltips") == nil, "GetPartStandDown names the enabled addon")
modules.ChatFrames = nil -- ChatFrames.lua returns before creating its module
args, rows = Build()
check(rows.Chat and rows.Chat.disabled() and rows.Chat.get() == false, "a part standing down is still listed, greyed and off")

print(string.format("Interface parts: %d checks, %d failures", checks, failures))
if (failures > 0) then os.exit(1) end

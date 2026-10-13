-- Core/ThemeEngine.lua on its own: which theme a hook reaches, what stock AzeriteUI
-- answers, the media swap and tint rule, layout copies and endcap settings.
-- The three real themes are covered by their own harnesses; the themed layout tables
-- were also diffed against the pre-engine files (FixLog 2026-10-13), identical.
-- Run: lua.exe Tools/Harness/theme_engine_harness.lua <addon root>
local root = arg[1] or '.'
local checks, failures = 0, 0
local function check(v, msg)
	checks = checks + 1
	if (not v) then failures = failures + 1; print("FAIL: " .. msg) end
end

local combat, reloads = false, 0
InCombatLockdown = function() return combat end
ReloadUI = function() reloads = reloads + 1 end
local ns = { db = { char = {}, RegisterCallback = function() end } }
assert(loadfile(root .. "/Core/ThemeEngine.lua"))("AzeriteUI5_JuNNeZ_Edition", ns)
local Engine = ns.ThemeEngine

-- Stock answers with no theme.
check(Engine:GetActive() == nil, "no theme registered: none active")
check(Engine:ResolvePath("x\\Assets\\a.tga") == "x\\Assets\\a.tga", "stock ResolvePath keeps the path")
local original = {}
check(Engine:GetConfig("PlayerFrame", original) == original, "stock GetConfig hands back the original")
check(Engine:UseIceCrystal(true) == true and Engine:UseIceCrystal(false) == false, "stock UseIceCrystal follows the request")
check(Engine:GetNameplateCastOffset(5) == 5, "stock cast offset unchanged")
check(Engine:ResolveMedia("x") == nil and Engine:StyleHealth({}) == nil, "stock media and styling: nothing")

-- Priority: the lower number wins when two are active; hooks reach only it.
local function Theme(name, active)
	local theme = { name = name, active = active, calls = {} }
	theme.IsActive = function(self) return self.active end
	theme.StyleHealth = function(self, owner) self.calls[#self.calls + 1] = owner; return name end
	return theme
end
local paladin, hunter, mage = Theme("paladin", true), Theme("hunter", false), Theme("mage", true)
Engine:Register(paladin, 30); Engine:Register(hunter, 10); Engine:Register(mage, 20)
check(Engine:GetActive() == mage, "mage (20) wins over paladin (30)")
check(Engine:StyleHealth("bar") == "mage" and #paladin.calls == 0, "the hook reaches the active theme only")
hunter.active = true
check(Engine:GetActive() == hunter, "hunter (10) wins over both")
mage.StyleCompass = nil; hunter.active, mage.active, paladin.active = false, true, false
check(Engine:StyleCompass("compass") == nil, "a hook the theme lacks falls back to stock")

-- Main layout gate.
ns.LegacyHUD = { IsActive = function() return ns.legacy end }
ns.GetActiveConfigVariant = function() return ns.variant end
ns.IsSaiyaRattProfile = function() return ns.variant == "SaiyaRatt" end
check(Engine:IsMainLayout(), "main layout")
ns.legacy = true; check(not Engine:IsMainLayout(), "Legacy is not the main layout"); ns.legacy = nil
ns.variant = "SaiyaRatt"; check(not Engine:IsMainLayout(), "SaiyaRatt is not the main layout"); ns.variant = nil

-- Layout copy keeps widgets, copies tables, keeps cycles.
local widget = { GetObjectType = function() return "Font" end }
local source = { a = { 1, 2 }, font = widget }
source.self = source
local copy = Engine:CopyLayout(source)
check(copy ~= source and copy.a ~= source.a and copy.a[2] == 2, "tables are copied")
check(copy.font == widget and copy.self == copy, "widgets keep identity, cycles are kept")

-- Media swap and the tint rule.
local layout = {
	HealthBackdropTexture = "Interface\\AddOns\\X\\Assets\\hp_cap_case.tga", HealthBackdropColor = { .2, .3, .4, .5 },
	HaloTexture = "Interface\\AddOns\\X\\Assets\\halo.tga", HaloColor = { 1, 0, 0 },
	OtherTexture = "Interface\\AddOns\\X\\Assets\\not_themed.tga", OtherColor = { 0, 1, 0 },
	nested = { CastTexturePath = "x/Assets/cast_back.tga", CastColor = { .1, .1, .1 } }
}
local afterCalls = 0
Engine:ReplaceMedia(layout, {
	resolve = function(name) return (name == "hp_cap_case" or name == "halo" or name == "cast_back") and ("T\\Assets\\Theme\\" .. name .. ".tga") or nil end,
	keepTint = function(asset) return asset == "halo" end,
	after = function(t) afterCalls = afterCalls + 1 end
})
check(layout.HealthBackdropTexture == "T\\Assets\\Theme\\hp_cap_case.tga", "a themed name is replaced")
check(layout.HealthBackdropColor[1] == 1 and layout.HealthBackdropColor[4] == .5, "its tint turns white, alpha kept")
check(layout.HaloColor[1] == 1 and layout.HaloColor[2] == 0, "keepTint keeps a neutral texture's colour")
check(layout.OtherTexture:find("not_themed") and layout.OtherColor[2] == 1, "an unthemed name and its colour stay")
check(layout.nested.CastTexturePath:find("Theme") and layout.nested.CastColor[1] == 1, "nested tables and ...TexturePath keys too")
check(afterCalls >= 2, "after runs for each table")

-- Config cache: one copy per source table.
local builds = 0
local cached = Engine:NewConfigCache(function(name, source) builds = builds + 1; return { from = source } end)
local s1, s2 = {}, {}
check(cached("A", s1) == cached("A", s1) and builds == 1, "a source table is copied once")
check(cached("B", s2) ~= cached("A", s1) and builds == 2, "each source has its own copy")

-- Endcap settings.
local refreshed = 0
local choices = { school = true, aluneth = true, none = true }
local settings = Engine:NewEndcapSettings({ prefix = "test", choices = choices, default = "school", clearDefault = true,
	refresh = function() refreshed = refreshed + 1 end })
local holder = {}
settings.Install(holder)
check(holder:GetEndcap() == "school" and holder:GetEndcapScale() == 1, "defaults")
check(holder:SetEndcap("aluneth") and ns.db.char.testEndcap == "aluneth" and refreshed == 1, "a choice is stored and redrawn")
check(holder:SetEndcap("school") and ns.db.char.testEndcap == nil, "clearDefault stores the default as nil")
check(not holder:SetEndcap("bogus") and holder:GetEndcap() == "school", "unknown keys refused")
local keep = Engine:NewEndcapSettings({ prefix = "keep", choices = choices, default = "school" })
keep.SetKey("school")
check(ns.db.char.keepEndcap == "school", "without clearDefault the default key is stored")
check(holder:SetEndcapScale(1.5) and ns.db.char.testEndcapScale == 1.5, "scale stored")
check(not holder:SetEndcapScale(3) and not holder:SetEndcapScale("x"), "out of range scale refused")
check(holder:SetEndcapScale(1) and ns.db.char.testEndcapScale == nil, "scale 1 clears")
check(holder:SetEndcapOffset(99, -4) and ns.db.char.testEndcapX == 60 and select(1, holder:GetEndcapOffset()) == 60, "offset clamped to 60 when stored")
check(holder:SetEndcapOffset(nil, 3) and select(1, holder:GetEndcapOffset()) == 60 and select(2, holder:GetEndcapOffset()) == 3, "nil keeps a value")
combat = true
check(not holder:SetEndcap("none") and not holder:SetEndcapScale(1.2) and not holder:SetEndcapOffset(1, 1) and not holder:ResetEndcapPlacement(), "all refused in combat")
combat = false
check(holder:ResetEndcapPlacement() and ns.db.char.testEndcapX == nil and ns.db.char.testEndcapScale == nil, "reset clears placement")

-- Profile change: reload only when the theme flips, deferred in combat.
local module = { loadedActive = false, active = false, events = {} }
module.IsActive = function(self) return self.active end
module.RegisterEvent = function(self, event) self.events[event] = true end
module.UnregisterEvent = function(self, event) self.events[event] = nil end
module.ProfileChanged = Engine.ProfileChanged
module:ProfileChanged()
check(reloads == 0, "no flip, no reload")
module.active = true; combat = true
module:ProfileChanged()
check(reloads == 0 and module.events.PLAYER_REGEN_ENABLED, "a flip in combat waits")
combat = false
module:ProfileChanged()
check(reloads == 1 and not module.events.PLAYER_REGEN_ENABLED, "and reloads after")

print(string.format("Theme engine: %d checks, %d failures (offline only).", checks, failures))
if (failures > 0) then os.exit(1) end

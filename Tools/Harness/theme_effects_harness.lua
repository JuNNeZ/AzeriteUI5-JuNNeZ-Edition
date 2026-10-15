-- Core/ThemeEffects.lua: which theme is in use, what reloads, and which crystal
-- and orb effect is drawn, with and without Lite+. The theme modules are
-- recording stand-ins; their own drawing is covered by the theme harnesses.
-- lua Tools/Harness/theme_effects_harness.lua .
local root = arg[1] or "."
local checks = 0
local function check(value, label)
	checks = checks + 1
	assert(value, label)
end

local reloads, refreshes, combat = 0, 0, false
C_UI = { Reload = function() reloads = reloads + 1 end }
ReloadUI = function() error("theme dropdown must use modern reload API") end
InCombatLockdown = function() return combat end

local ns = { db = { global = {}, char = {} } }
local variant
function ns:GetActiveConfigVariant() return variant end
function ns:IsSaiyaRattProfile() return variant == "SaiyaRatt" end
function ns:Print(message) self.message = message end
local player = { frame = {}, IsEnabled = function() return true end, UpdateSettings = function() refreshes = refreshes + 1 end }
function ns:GetModule(name) if (name == "PlayerFrame") then return player end end

-- Theme stand-ins: active from the same saved flags as the real modules, and
-- built (loadedActive) as they were when the interface last loaded.
local calls = {}
local function record(name) return function(_, ...) calls[#calls + 1] = name; return true end end
ns.HunterTheme = {
	IsActive = function() return ns.db.char.hunterPreview == true and not variant end,
	StyleCrystal = record("hunter:case"),
	ApplyOrbEffect = record("hunter:orb")
}
ns.PaladinTheme = {
	IsActive = function()
		return ns.db.char.paladinPreview == true and not ns.HunterTheme:IsActive() and not variant
	end,
	ApplyCrystalEffect = record("paladin:crystal"), ClearCrystalEffect = record("paladin:crystal-off"),
	ApplyOrbEffect = record("paladin:orb"), ClearOrbEffect = record("paladin:orb-off")
}
ns.MageTheme = {
	IsActive = function() return ns.db.char.magePreview == true and not ns.HunterTheme:IsActive() and not variant end,
	StyleCrystal = record("mage:badge"),
	RefreshOrnaments = record("mage:ornaments")
}
ns.MageCrystalPreview = { StyleCrystal = record("mage:crystal") }

assert(loadfile(root .. "/Core/ThemeEffects.lua"))("AzeriteUI5_JuNNeZ_Edition", ns)
local E = ns.ThemeEffects
local function drawn()
	calls = {}
	E:StyleCrystal({}, "crystal.tga", { 0, 1, 0, 1 }, "case.tga")
	local orb = E:StyleOrb({})
	local seen = {}
	for _, name in ipairs(calls) do seen[name] = true end
	return seen, orb
end

-- Defaults: AzeriteUI, no effects; Paladin offered like the other themes.
check(E:GetTheme() == "azerite", "AzeriteUI by default")
check(E:GetCrystalEffect() == "none" and E:GetOrbEffect() == "none", "no effects by default")
check(#E:GetThemes() == 4, "Paladin offered outside Development Mode", #E:GetThemes())
check(not E:NeedsReload("azerite"), "the theme already built needs no reload")
local seen, orb = drawn()
check(seen["paladin:crystal-off"] and seen["paladin:orb-off"] and not orb, "unused effects are cleared, orb left to Player.lua")
check(seen["hunter:case"] and seen["mage:crystal"], "Hunter case and Mage always asked (both check for themselves)")

-- Mage rebuilds the layouts with its own casings: a reload each way.
check(E:SetTheme("mage") and reloads == 1 and ns.db.char.magePreview, "AzeriteUI to Mage reloads")
ns.MageTheme.loadedActive = true
check(E:GetTheme() == "mage" and E:GetCrystalEffect() == "mage" and E:GetOrbEffect() == "none", "Mage theme draws the Mage crystal")
seen = drawn()
check(seen["mage:crystal"] and seen["mage:badge"] and not seen["hunter:case"], "the Mage crystal brings its own case and badge")
local redraws = refreshes
check(E:SetCrystalChoice("none", true) and refreshes == redraws + 1 and E:IsLitePlus() and E:GetCrystalEffect() == "none", "Lite+ and a choice in one redraw")
check(E:GetTheme() == "mage" and reloads == 1, "the Mage casings stay without the Mage crystal")
calls = {}; E:Refresh(); check(calls[1] == "mage:ornaments", "a redraw refreshes the Mage ornaments")
E:SetLitePlus(false); E:SetCrystalChoice("theme")
check(E:SetTheme("azerite") and reloads == 2 and not ns.db.char.magePreview, "Mage back to AzeriteUI reloads")
ns.MageTheme.loadedActive = nil

-- Hunter rebuilds the layouts: reload going in, and coming out once built.
check(E:NeedsReload("hunter") and E:NeedsReload("mage") and not E:NeedsReload("azerite"), "every other theme needs a reload")
E:SetTheme("hunter")
check(reloads == 3 and ns.db.char.hunterPreview and not ns.db.char.magePreview, "switching to Hunter reloads")
ns.HunterTheme.loadedActive = true
check(E:GetTheme() == "hunter" and E:GetOrbEffect() == "hunter" and E:GetCrystalEffect() == "none", "Hunter brings its orb")
seen, orb = drawn()
check(orb and seen["hunter:orb"] and seen["hunter:case"], "Hunter orb and case drawn")
check(E:NeedsReload("mage") and E:NeedsReload("azerite"), "leaving a built Hunter layout reloads")

-- Lite+: effects from other themes, live, and the theme's own by default.
ns.db.global.enableDevelopmentMode = true
local before = reloads
check(E:SetLitePlus(true) and E:GetCrystalChoice() == "theme", "Lite+ starts with the theme's own")
check(E:SetCrystalChoice("mage") and E:GetCrystalEffect() == "mage", "Mage crystal on Hunter")
check(E:SetOrbChoice("paladin") and E:GetOrbEffect() == "paladin", "Paladin orb on Hunter")
check(reloads == before, "Lite+ changes never reload")
seen, orb = drawn()
check(orb and seen["paladin:orb"] and not seen["hunter:orb"] and seen["mage:crystal"] and not seen["hunter:case"], "picked effects drawn instead of the theme's")
check(not E:SetCrystalChoice("hunter") and E:GetCrystalChoice() == "mage", "an effect a crystal does not have is refused")
check(E:SetOrbChoice("none") and E:GetOrbEffect() == "none", "Lite+ can switch an effect off")
check(E:SetLitePlus(false) and E:GetCrystalEffect() == "none" and E:GetOrbEffect() == "hunter", "Lite+ off returns to the theme's own, choices kept")
check(ns.db.char.themeCrystalEffect == "mage", "choices survive Lite+ off")

-- Approved Paladin effects are public in Lite+; the full artwork stays gated.
E:SetLitePlus(true); E:SetCrystalChoice("paladin")
ns.db.global.enableDevelopmentMode = false
check(E:GetCrystalEffect() == "paladin", "Paladin Light in Lite+ outside Development Mode")
check(E:SetOrbChoice("paladin") and E:GetOrbEffect() == "paladin", "Paladin orb Light outside Development Mode")
local offered = false
for _, key in ipairs(E:GetThemes()) do if (key == "paladin") then offered = true end end
check(offered, "the full Paladin theme is offered outside Development Mode")
seen, orb = drawn()
check(orb and seen["paladin:crystal"] and seen["paladin:orb"], "both public Lite+ Light effects dispatched")
ns.db.global.enableDevelopmentMode = true
check(E:GetCrystalEffect() == "paladin", "Paladin effect in Development Mode")

-- Off the main layout, nothing is drawn and no theme can be chosen.
variant = "SaiyaRatt"
check(E:GetTheme() == "azerite" and E:GetCrystalEffect() == "none" and E:GetOrbEffect() == "none", "other layouts draw no effects")
check(not E:SetTheme("mage") and ns.message, "themes refused on other layouts")
variant = nil

-- Combat: every write waits.
combat = true
check(not E:SetLitePlus(false) and not E:SetCrystalChoice("none") and not E:SetTheme("azerite"), "combat refuses changes")
check(E:IsLitePlus() and E:GetCrystalChoice() == "paladin", "combat leaves state intact")
combat = false
check(not E:SetTheme("bogus"), "unknown theme refused")

-- Caps: Paladin and Hunter crystal and orb cases above the health casing.
local function widget(parent)
	local w = { parent = parent, level = 1, shown = true }
	function w:GetParent() return self.parent end
	function w:SetParent(p) self.parent = p end
	function w:SetFrameLevel(v) self.level = v end
	function w:GetFrameLevel() return self.level end
	function w:SetAllPoints(a) self.allPoints = a end
	function w:EnableMouse(v) self.mouse = v end
	function w:IsShown() return self.shown end
	return w
end
CreateFrame = function(_, _, parent) return widget(parent) end
local unit = widget(); unit.level = 5
unit.Health = widget(unit); unit.Health.level = 8
local power = widget(unit); power.level = 3; power.Case = widget(power)
local orbFrame = widget(unit); orbFrame.level = 3; orbFrame.Case = widget(widget(orbFrame))
local orbCaseParent = orbFrame.Case.parent
local function style() E:StyleCrystal(power, "crystal.tga", { 0, 1, 0, 1 }, "case.tga"); E:StyleOrb(orbFrame) end
ns.db.char.hunterPreview, ns.db.char.paladinPreview, ns.db.char.magePreview = false, false, false
ns.db.char.themeLitePlus = nil
style()
check(power.Case.parent == power and orbFrame.Case.parent == orbCaseParent and not E:CapsInFront(), "AzeriteUI keeps its native case levels")
ns.db.char.magePreview = true; style()
check(power.Case.parent == power and orbFrame.Case.parent == orbCaseParent, "Mage keeps its native case levels")
ns.db.char.magePreview = false; ns.db.char.paladinPreview = true
check(E:CapsInFront(), "Paladin caps in front")
style()
check(power.Case.parent == power.ThemeCapFrame and power.ThemeCapFrame.level == 12, "Paladin crystal case above the health casing")
check(orbFrame.Case.parent == orbFrame.ThemeCapFrame and orbFrame.ThemeCapFrame.level == 12, "Paladin orb case above the health casing")
check(power.ThemeCapFrame.parent == power and power.ThemeCapFrame.allPoints == power and power.ThemeCapFrame.mouse == false, "cap frame follows the element, no mouse")
local capFrame = power.ThemeCapFrame
unit.Health.level = 10; style()
check(power.ThemeCapFrame == capFrame and capFrame.level == 14, "cap frame reused and kept above a moved health bar")
ns.db.char.paladinPreview = false; ns.db.char.hunterPreview = true; style()
check(capFrame.level == 14 and power.Case.parent == capFrame, "Hunter caps in front too")
local foreground = widget(power); power.MageCrystalCaseFrame = foreground; power.Case.parent = foreground
style()
check(power.Case.parent == foreground and foreground.level == 14, "the Mage crystal's own case frame is lifted instead")

-- Legacy in the theme list (2026-10-13): always offered, chosen like /go legacy.
ns.LegacyHUD = { IsActive = function() return ns.db.char.legacyHUD == true and not variant end }
ns.db.char.paladinPreview, ns.db.char.hunterPreview, ns.db.char.magePreview = false, false, false
ns.HunterTheme.loadedActive, ns.PaladinTheme.loadedActive, ns.MageTheme.loadedActive = nil, nil, nil
local themes = E:GetThemes()
check(themes[1] == "azerite" and themes[2] == "legacy", "Legacy is offered right after AzeriteUI, before it is active")
local before = reloads
check(E:SetTheme("legacy") and reloads == before + 1, "choosing Legacy reloads")
check(ns.db.char.legacyHUD == true and not ns.db.char.hunterPreview and not ns.db.char.magePreview and not ns.db.char.paladinPreview,
	"it writes the switch /go legacy writes and clears the class themes")
ns.LegacyHUD.loadedActive = true
check(E:GetTheme() == "legacy" and E:GetCrystalEffect() == "none" and E:GetOrbEffect() == "none", "Legacy in use, no crystal or orb effects")
check(E:SetTheme("hunter") and reloads == before + 2 and ns.db.char.legacyHUD == false and ns.db.char.hunterPreview, "Legacy to Hunter reloads and leaves Legacy")
ns.LegacyHUD.loadedActive = nil
variant = "SaiyaRatt"
check(not E:SetTheme("legacy"), "Legacy refused on another layout, as /go refuses it")
variant = nil
ns.LegacyHUD = nil
check(not E:GetThemes()[2] or E:GetThemes()[2] ~= "legacy", "without the Legacy module it is not offered")

print("Theme effects: " .. checks .. " checks passed (offline only)")

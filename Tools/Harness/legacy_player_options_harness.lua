-- Player options the Legacy HUD cannot use are hidden while it is active, against the REAL
-- options table (Options/OptionsPages/UnitFrames.lua), and the frame settings panel
-- (Options/Kit/FramePanel.lua) drops them with it, since it reads the same `hidden`.
--
-- Under Legacy the orb is never shown (Core/LegacyHUD.lua sets ManaOrb alpha 0), the power
-- widget ignores the style (Player.lua ResolvePlayerPowerWidgetVisibility), the Ice Crystal is
-- off (Player.lua UsePlayerIceCrystal) and the party-style player keeps its full layout
-- (PlayerParty.lua UpdateLayout). Settings that still reach the Legacy bar stay listed.
-- Offline only: it cannot say how the page looks in game.
--
-- lua Tools/Harness/legacy_player_options_harness.lua . Tools/Harness [Forever]

local root = arg[1] or "."
package.path = (arg[2] or ".") .. "/?.lua;" .. package.path

local S = dofile((arg[2] or ".") .. "/stubs.lua")
local ns, Addon = S.ns, S.Addon
local forever = arg[3] == "Forever"
ns.IsForever = forever
ns.IsRetailContent = not forever
ns.PlayerClass = "MAGE"

-- Permissive module stubs, as frame_panel_harness.lua builds them, so every page builds.
local autoMT
autoMT = { __index = function(t, k) local v = setmetatable({}, autoMT); rawset(t, k, v); return v end }
local dataFields = { db = true, defaults = true, settings = true, bars = true }
local moduleStubMT = {
	__index = function(t, k)
		local v
		if dataFields[k] then v = setmetatable({}, autoMT) else v = function() return setmetatable({}, autoMT) end end
		rawset(t, k, v)
		return v
	end
}
local realModules = S.modules
ns.GetModule = function(self, name)
	if forever and (name == "ArenaFrames" or name == "PlayerClassPowerFrame") then return nil end
	if realModules[name] then return realModules[name] end
	realModules[name] = setmetatable({}, moduleStubMT)
	if name == "ActionBars" then
		realModules[name].bars = {}
		for id = 1, forever and 5 or 8 do realModules[name].bars[id] = {} end
	end
	return realModules[name]
end

local function load(relative)
	local chunk, err = loadfile(root .. "/" .. relative)
	if not chunk then error("could not load " .. relative .. ": " .. tostring(err)) end
	return chunk(Addon, ns)
end

-- The switch every Legacy check in the options reads.
local legacy = false
ns.LegacyHUD = { IsActive = function() return legacy end }

-- UnitFrames.lua captures the spec lookup and spec IDs when it loads, so these go in first
-- (the stubs would hand back the constant's own name).
local spec = nil
rawset(_G, "C_SpecializationInfo", { GetSpecialization = function() return spec end })
rawset(_G, "SPEC_SHAMAN_ELEMENTAL", 1)

ns.HunterTheme = setmetatable({ loadedActive = false, IsActive = function() return false end, GetEndcapChoices = function() return { none = true } end }, moduleStubMT)
ns.PaladinTheme = setmetatable({ loadedActive = false, IsActive = function() return false end }, moduleStubMT)
ns.MageTheme = setmetatable({ loadedActive = false, IsActive = function() return false end, GetEndcapChoices = function() return { none = true } end }, moduleStubMT)
ns.MageCrystalPreview = setmetatable({ IsActive = function() return false end }, moduleStubMT)
ns.db = ns.db or {}
ns.db.char = ns.db.char or {}
ns.db.global = ns.db.global or {}
assert(loadfile(root .. "/Core/ThemeEffects.lua"))(Addon, ns)

load("Core/ThemeBarPreview.lua")
load("Options/Kit/Kit.lua")
load("Options/Kit/Widgets.lua")
load("Options/Kit/Window.lua")
load("Options/Options.lua")

local Kit = ns.OptionsKit
local Options = realModules["Options"]

-- Player and Player (Party Style) both on, so only the Legacy switch decides what shows.
ns:GetModule("PlayerFrame").db.profile.enabled = true
ns:GetModule("PlayerFrameAlternate").db.profile.enabled = false
ns:GetModule("PlayerFrameParty").db.profile.enabled = true

dofile((arg[2] or ".") .. "/option_components.lua")(load, ns)

-- Pages that will not load under the stubs are not this harness's subject; Unit Frames must.
local xml = io.open(root .. "/Options/Options.xml"):read("*a")
for file in xml:gmatch('<Script file="OptionsPages\\([%w_]+%.lua)"/>') do
	local path = "Options/OptionsPages/" .. file
	local ok, err = pcall(load, path)
	if (not ok and file == "UnitFrames.lua") then error("UnitFrames.lua did not load: " .. tostring(err)) end
end

assert(pcall(function() Options:GenerateOptionsMenu() end), "GenerateOptionsMenu failed")
local options = assert(Options:GetOptionsObject(), "no options table")

for _, file in ipairs({ "Options/Kit/Config.lua", "Options/Kit/Defaults.lua", "Options/Kit/Combat.lua",
	"Options/Kit/Controls.lua", "Options/Kit/Preview.lua", "Options/Kit/Renderer.lua" }) do
	local key = file:match("Kit/(%a+)%.lua")
	if (not Kit[key]) then load(file) end
end
load("Options/Kit/FramePanel.lua")
local Config, FramePanel = Kit.Config, Kit.FramePanel

local checks, failures = 0, 0
local function check(value, label)
	checks = checks + 1
	if (not value) then
		failures = failures + 1
		print("FAIL: " .. label)
	end
end

local UNIT_FRAMES = "Unit Frames"

local function Hidden(section, key)
	local path = { UNIT_FRAMES, section, key }
	local option = Config.GetGroup(options, path)
	if (type(option) ~= "table") then return nil end
	return Config.IsHidden(option, options, path, Addon) and true or false
end

local function PanelHas(moverKey, key)
	for _, entry in ipairs(FramePanel:CollectSettings(moverKey, options)) do
		if (entry.path[#entry.path] == key) then return true end
	end
	return false
end

-- Dead under Legacy.
local LEGACY_HIDDEN = {
	{ "player", "powerOrbMode" },
	{ "player", "useWrathCrystal" },
	{ "player", "manaOrbTexture" },
	{ "player", "flowingMana" },
	{ "player", "manaOrbGlass" },
	{ "player", "manaOrbRim" },
	{ "player", "manaOrbPedestal" },
	{ "playerParty", "showPortrait" }
}
-- Still reach the Legacy bar or frame, so they stay.
local LEGACY_KEPT = {
	{ "player", "crystalOrbColorMode" },
	{ "player", "showPowerValue" },
	{ "player", "showAuras" },
	{ "playerParty", "useClassColor" }
}

legacy = false
for _, entry in ipairs(LEGACY_HIDDEN) do
	check(Hidden(entry[1], entry[2]) == false, "Azerite HUD shows " .. entry[1] .. "." .. entry[2])
end
check(Hidden("player", "legacyCenterWithoutTarget") == true, "Azerite HUD hides Center Without a Target")
check(PanelHas("PlayerFrame", "powerOrbMode"), "Azerite HUD frame panel offers Player Power Style")
check(PanelHas("PlayerFrameParty", "showPortrait"), "Azerite HUD frame panel offers Show Portrait")

legacy = true
for _, entry in ipairs(LEGACY_HIDDEN) do
	check(Hidden(entry[1], entry[2]) == true, "Legacy HUD hides " .. entry[1] .. "." .. entry[2])
end
for _, entry in ipairs(LEGACY_KEPT) do
	check(Hidden(entry[1], entry[2]) == false, "Legacy HUD keeps " .. entry[1] .. "." .. entry[2])
end
check(Hidden("player", "legacyCenterWithoutTarget") == false, "Legacy HUD shows Center Without a Target")
check(not PanelHas("PlayerFrame", "powerOrbMode"), "Legacy HUD frame panel drops Player Power Style")
check(not PanelHas("PlayerFrame.secondaryMana", "powerOrbMode"), "Legacy HUD secondary mana panel drops Player Power Style")
check(PanelHas("PlayerFrame.secondaryMana", "crystalOrbColorMode"), "Legacy HUD secondary mana panel keeps the color source")
check(not PanelHas("PlayerFrameParty", "showPortrait"), "Legacy HUD frame panel drops Show Portrait")

-- The Elemental split stays: Legacy drops the swap bar (PlayerClassPower.lua
-- ShouldUseElementalSwapBar), but the Legacy power bar is the player's crystal element,
-- whose GetDisplayPower still reads the split (Player.lua), so it picks Maelstrom or Mana.
if (not forever) then
	local savedClass = ns.PlayerClass
	ns.PlayerClass, spec = "SHAMAN", 1
	for _, on in ipairs({ false, true }) do
		legacy = on
		check(Hidden("classpower", "elementalMaelstromDisplayMode") == false,
			(on and "Legacy" or "Azerite") .. " HUD keeps the Elemental Crystal/Bar split for an Elemental Shaman")
	end
	ns.PlayerClass, spec = savedClass, nil
	legacy = true
end

-- The existing switches still win: a player frame that is off hides its settings under either HUD.
legacy = false
ns:GetModule("PlayerFrame").db.profile.enabled = false
check(Hidden("player", "manaOrbTexture") == true, "Player off still hides Mana Orb Texture")
ns:GetModule("PlayerFrame").db.profile.enabled = true

print(string.format("Legacy player options%s: %d checks, %d failures", forever and " (Forever)" or "", checks, failures))
if (failures > 0) then os.exit(1) end

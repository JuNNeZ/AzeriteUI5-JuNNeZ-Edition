-- Runs the dialogControl pass over the addon's REAL option pages.
--
-- Every page's GenerateOptions is invoked against permissive module stubs, so
-- pages that only ask their module for values will build. Pages that call real
-- module methods may fail; those are reported, not hidden.
--
-- Usage: lua real_options_harness.lua <addon root>

local root = arg[1] or "."
package.path = (arg[2] or ".") .. "/?.lua;" .. package.path

local S = dofile((arg[2] or ".") .. "/stubs.lua")
local ns, Addon = S.ns, S.Addon
local forever = arg[3] == "Forever"
ns.IsForever = forever
ns.IsRetailContent = not forever
ns.PlayerClass = "MAGE"

-- Pages ask ns:GetModule(name, true) and bail when it is nil. Hand every page
-- a permissive stub so the option definitions themselves actually get built.
-- A table that grows whatever key is asked of it, so module.db.profile.foo
-- resolves without knowing any module's schema.
local autoMT
autoMT = {
	__index = function(t, k)
		local v = setmetatable({}, autoMT)
		rawset(t, k, v)
		return v
	end
}

local dataFields = { db = true, defaults = true, settings = true, bars = true }

local moduleStubMT = {
	__index = function(t, k)
		local v
		if dataFields[k] then
			v = setmetatable({}, autoMT)
		else
			v = function() return setmetatable({}, autoMT) end
		end
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

-- The theme modules live in Core/ and are not loaded here; the Themes page only
-- calls their documented methods, so permissive stubs stand in for them. The
-- real Core/ThemeEffects.lua decides what the page shows.
ns.HunterTheme = setmetatable({
	loadedActive = true,
	IsActive = function() return true end,
	GetEndcapChoices = function() return { thasdorah = true, talonclaw = true, titanstrike = true, thoridal = true, raeshalare = true, none = true } end
}, moduleStubMT)
ns.PaladinTheme = setmetatable({ loadedActive = false, IsActive = function() return false end }, moduleStubMT)
ns.MageTheme = setmetatable({
	loadedActive = false,
	IsActive = function() return false end,
	GetEndcapChoices = function() return { school = true, aluneth = true, felomelorn = true, ebonchill = true, atiesh = true, dragonwrath = true, none = true } end
}, moduleStubMT)
ns.MageCrystalPreview = setmetatable({ IsActive = function() return false end }, moduleStubMT)
ns.db = ns.db or {}
ns.db.char = ns.db.char or {}
ns.db.global = ns.db.global or {}
assert(loadfile(root .. "/Core/ThemeEffects.lua"))(Addon, ns)

load("Options/Kit/Kit.lua")
load("Options/Kit/Widgets.lua")
load("Options/Kit/Window.lua")
load("Options/Options.lua")

local Kit = ns.OptionsKit
local Options = realModules["Options"]

-- Load every page listed in Options.xml, in its declared order.
local xml = io.open(root .. "/Options/Options.xml"):read("*a")
local pages, failedPages = {}, {}
for file in xml:gmatch('<Script file="OptionsPages\\([%w_]+%.lua)"/>') do
	pages[#pages + 1] = "Options/OptionsPages/" .. file
end
print(string.format("Option pages listed in Options.xml: %d", #pages))

for _, path in ipairs(pages) do
	local ok, err = pcall(load, path)
	if not ok then failedPages[#failedPages + 1] = { path, err } end
end

if #failedPages > 0 then
	print("\nPages that would not load under stubs:")
	for _, f in ipairs(failedPages) do
		print("  " .. f[1] .. "\n    " .. tostring(f[2]):sub(1, 160))
	end
end

-- Build the real menu. This runs GenerateOptionsMenu, which also runs the
-- dialogControl pass.
local ok, err = pcall(function() Options:GenerateOptionsMenu() end)
if not ok then
	print("\nGenerateOptionsMenu failed: " .. tostring(err))
	os.exit(1)
end

local options = Options:GetOptionsObject()
if not options then
	print("\nNo options table was produced.")
	os.exit(1)
end

-- Inspect the actual option closures, including profiles imported from Retail.
local units = assert(options.args.UnitFrames or options.args["Unit Frames"])
if forever then
	assert(units.args.arena.hidden == true, "Forever arena settings must be hidden")
	assert(units.args.classpower.hidden == true, "Forever mage has no Arcane Charges settings")
end
for _, key in ipairs({"party", "raid5", "raid25", "raid40"}) do
	local group = assert(units.args[key], key)
	local option = group.args.usePortraitSpecIcons or group.args.useSpecIcons
	assert(option.hidden({"UnitFrames", key, "useSpecIcons"}) == forever, "specialization visibility: " .. key)
end
local minimap = assert(options.args.Minimap)
assert((minimap.args.autoHide.args.autoHideInArenas.hidden == true) == forever, "arena auto-hide visibility")
print("Client option gates: " .. (forever and "Forever" or "Retail") .. " passed")

-- Themes page: a theme dropdown, Lite+, and only the settings in use.
local themes = assert(options.args.Themes, "Themes page built")
for _, key in ipairs({ "theme", "litePlus", "effects", "hunter", "paladin", "mageTheme", "mage" }) do assert(themes.args[key], "Themes entry: " .. key) end
local themeSelect = themes.args.theme
assert(themeSelect.get() == "hunter", "the dropdown shows the theme in use")
assert(themeSelect.values().mage and not themeSelect.values().paladin, "Paladin offered only in Development Mode")
assert(themeSelect.sorting()[1] == "azerite", "AzeriteUI first")
assert(type(themeSelect.confirm(nil, "mage")) == "string", "leaving Hunter asks before reloading")
assert(not themes.args.hunter.hidden() and themes.args.paladin.hidden() and themes.args.mage.hidden() and themes.args.mageTheme.hidden(), "only the Hunter settings show on Hunter")
local mageEndcap = themes.args.mageTheme.args.endcap
assert(mageEndcap.values().school and mageEndcap.values().dragonwrath and mageEndcap.sorting[1] == "school", "Mage staves, the school's first")
assert(themes.args.effects.hidden(), "Lite+ effects hidden until Lite+ is on")
ns.db.char.themeLitePlus = true; ns.db.global.enableDevelopmentMode = true; ns.db.char.themeOrbEffect = "paladin"
assert(not themes.args.effects.hidden() and not themes.args.paladin.hidden(), "Lite+ shows the effects and the settings of the Paladin orb")
local crystalValues = themes.args.effects.args.crystal.values()
assert(crystalValues.theme and crystalValues.mage and crystalValues.paladin and crystalValues.none, "crystal effect choices")
assert(themes.args.effects.args.crystal.sorting()[1] == "theme", "the theme's own first")
ns.db.char.themeLitePlus, ns.db.char.themeOrbEffect, ns.db.global.enableDevelopmentMode = nil, nil, nil
local endcap = themes.args.hunter.args.endcap
local values = endcap.values()
assert(values.thasdorah and values.none and endcap.sorting[1] == "thasdorah", "endcap choices and order")
assert(endcap.confirm == nil, "a new endcap applies without a reload")
print("Themes page passed")

local bars = assert(options.args.ActionBars or options.args["Action Bars"])
for id = 1, 8 do
	assert((bars.args["bar" .. id] ~= nil) == (not forever or id <= 5), "only existing bars get options: " .. id)
end

--------------------------------------------------------------------------
-- Walk the real table
--------------------------------------------------------------------------
local counts, unmapped, bad = {}, {}, {}
local total, groups = 0, 0
local maxDepth = 0

local function walk(group, depth)
	maxDepth = math.max(maxDepth, depth)
	if type(group.args) ~= "table" then return end

	for key, v in pairs(group.args) do
		if type(v) == "table" and v.type then
			if v.type == "group" then
				groups = groups + 1
				walk(v, depth + 1)
			else
				total = total + 1
				local control = v.dialogControl
				if control then
					counts[control] = (counts[control] or 0) + 1
					if not S.registeredWidgets[control] then
						bad[#bad + 1] = key .. " -> " .. tostring(control)
					end
				else
					local t = v.type .. (v.multiline and " (multiline)" or "")
						.. (v.type == "execute" and v.image and " (image)" or "")
						.. (v.type == "select" and v.style == "radio" and " (radio)" or "")
					unmapped[t] = (unmapped[t] or 0) + 1
				end
			end
		end
	end
end

walk(options, 0)

print(string.format("\nTop-level pages: %d", (function()
	local n = 0
	for _, v in pairs(options.args) do if v.type == "group" then n = n + 1 end end
	return n
end)()))
print(string.format("Groups walked:   %d", groups))
print(string.format("Leaf options:    %d", total))
print(string.format("Deepest nesting: %d", maxDepth))

print("\nOptions routed to an AzeriteUI widget:")
local shortNames = {}
for short, full in pairs(Kit.Types) do shortNames[full] = short end
local ordered = {}
for control, n in pairs(counts) do ordered[#ordered + 1] = { shortNames[control] or control, n } end
table.sort(ordered, function(a, b) return a[2] > b[2] end)
local routed = 0
for _, row in ipairs(ordered) do
	print(string.format("  %-12s %5d", row[1], row[2]))
	routed = routed + row[2]
end

print("\nOptions deliberately left on stock widgets:")
local leftOrdered = {}
for t, n in pairs(unmapped) do leftOrdered[#leftOrdered + 1] = { t, n } end
table.sort(leftOrdered, function(a, b) return a[2] > b[2] end)
for _, row in ipairs(leftOrdered) do
	print(string.format("  %-22s %5d", row[1], row[2]))
end

print(string.format("\nRouted %d of %d leaf options (%.1f%%)",
	routed, total, total > 0 and routed / total * 100 or 0))

if #bad > 0 then
	print("\nFAIL: dialogControl naming an unregistered widget type:")
	for _, b in ipairs(bad) do print("  " .. b) end
	os.exit(1)
end

-- The root must hold groups only, or the window's rail cannot be built from it.
local nonGroups = {}
for key, v in pairs(options.args) do
	if v.type ~= "group" then nonGroups[#nonGroups + 1] = key .. " (" .. tostring(v.type) .. ")" end
end
if #nonGroups > 0 then
	print("\nFAIL: root holds non-group entries: " .. table.concat(nonGroups, ", "))
	os.exit(1)
end
print("\nRoot holds groups only: OK")

-- Every page must be openable by the window, which addresses pages by key.
local Window = ns.OptionsKit.Window
S.optionsTables[Addon] = options
realModules["Options"].GetOptionsObject = function() return options end

local ok2, err2 = pcall(function() Window:Open() end)
print("Window opens against the real table: " .. (ok2 and "OK" or ("FAIL - " .. tostring(err2))))
if not ok2 then os.exit(1) end

print(string.format("Rail built %d page buttons", Window.pages and #Window.pages or 0))

-- Search across the real table.
for _, term in ipairs({ "scale", "aura", "minimap", "font", "zzzz" }) do
	local ok3, err3 = pcall(function() Window:ShowResults(term) end)
	print(string.format("  search %-8s %s", "'" .. term .. "'", ok3 and "OK" or ("FAIL - " .. tostring(err3))))
	if not ok3 then os.exit(1) end
end

print("\nAll real-table checks passed.")

-- Greyed-out options say why (FixLog 2026-11-13).
--
-- The options Kit shows a reason in place of a row's help line while the row is
-- disabled (Options/Kit/Config.lua SetDisabledDesc/GetDisabledDesc, Options/Kit/Renderer.lua
-- Bind). The reason is kept beside the option table, never in it, because
-- AceConfigRegistry refuses unknown keys and /az classic and /az legacy validate it.
--
--   A  every row on the Tooltips page, the Explorer Mode page and the party group
--      that can be shown greyed out has a reason, in every combination of the
--      settings that grey it, and the reason names the setting that actually does
--   B  the renderer shows the reason while the row is disabled and the help line
--      otherwise, on a page, after a live refresh, through inheritance and in a
--      gathered list (Views, the frame settings panel use the same Bind)
--   C  "Prioritize Unit Frame Auras" writes UnitFrames db.profile.disableAuraSorting
--      and every runtime reader reads that same profile key (source scan)
--   D  the real Tooltips, Explorer Mode and Group Frames tables still pass the real
--      AceConfigRegistry validator, which an option-table `disabledDesc` key fails
--
-- Offline only: how the reason looks in each window style is a live check.
-- Usage: lua Tools/Harness/options_disabled_reason_harness.lua <addon root> [stubs dir]
local root, scratch = arg[1] or ".", arg[2] or "Tools/Harness"
local S = dofile(scratch .. "/stubs.lua")
local ns, Addon = S.ns, S.Addon
ns.IsForever, ns.IsRetailContent, ns.IsRetail = false, true, true
ns.PlayerClass = "WARRIOR"

local checks, failures = 0, 0
local function check(ok, label, detail)
	checks = checks + 1
	if (not ok) then
		failures = failures + 1
		print("FAIL " .. label .. (detail ~= nil and (": " .. tostring(detail)) or ""))
	end
	return ok
end

local function readFile(relative)
	local f = assert(io.open(root .. "/" .. relative, "rb"))
	local text = f:read("*a")
	f:close()
	return text
end

local function load(relative)
	local chunk, err = loadfile(root .. "/" .. relative)
	if (not chunk) then error("could not load " .. relative .. ": " .. tostring(err)) end
	return chunk(Addon, ns)
end

-- The modules the three pages read, with plain profiles this harness sets.
local profiles = {
	Tooltips = { theme = "Azerite", disableAzeriteUITooltips = false, anchor = true, anchorToCursor = false },
	ExplorerMode = { enabled = true },
	PartyFrames = { enabled = true, showAuras = true },
	UnitFrames = { disableAuraSorting = false }
}

-- Everything else builds against permissive stubs, as real_options_harness does.
local autoMT
autoMT = { __index = function(t, k) local v = setmetatable({}, autoMT); rawset(t, k, v); return v end }
local dataFields = { db = true, defaults = true, settings = true, bars = true }
local moduleStubMT = {
	__index = function(t, k)
		local v
		if (dataFields[k]) then v = setmetatable({}, autoMT)
		else v = function() return setmetatable({}, autoMT) end end
		rawset(t, k, v)
		return v
	end
}
local realModules = S.modules
for name, profile in pairs(profiles) do
	realModules[name] = setmetatable({
		db = { profile = profile },
		IsEnabled = function() return true end,
		UpdateSettings = function() end
	}, moduleStubMT)
end
ns.GetModule = function(self, name)
	if (realModules[name]) then return realModules[name] end
	realModules[name] = setmetatable({}, moduleStubMT)
	if (name == "ActionBars") then
		realModules[name].bars = {}
		for id = 1, 8 do realModules[name].bars[id] = {} end
	end
	return realModules[name]
end

local consolePort = false
ns.API.IsAddOnEnabled = function(name)
	return consolePort and (name == "ConsolePort" or name == "ConsolePort_Bar") or false
end

-- Theme modules the Themes page asks for, as real_options_harness stubs them.
for _, theme in ipairs({ "HunterTheme", "PaladinTheme", "MageTheme", "WarriorTheme", "DruidTheme" }) do
	ns[theme] = setmetatable({ loadedActive = false, IsActive = function() return false end,
		GetEndcapChoices = function() return { none = true } end,
		GetCastEndcapChoices = function() return { none = true } end }, moduleStubMT)
end
ns.MoonwellSlosh = { GetStrength = function() return .8 end, SetStrength = function() end }
ns.WildheartCrystal = { GetStrength = function() return .7 end, SetStrength = function() end }
ns.MageCrystalPreview = setmetatable({ IsActive = function() return false end }, moduleStubMT)
ns.db = ns.db or {}
ns.db.char = ns.db.char or {}
ns.db.global = ns.db.global or {}
assert(loadfile(root .. "/Core/ThemeEffects.lua"))(Addon, ns)
load("Core/ThemeBarPreview.lua")

-- The Kit in Options.xml order, then the pages.
for _, relative in ipairs({
	"Options/Kit/Kit.lua", "Options/Kit/Look.lua", "Options/Kit/Config.lua",
	"Options/Kit/Defaults.lua", "Options/Kit/Combat.lua", "Options/Kit/Controls.lua",
	"Options/Kit/Renderer.lua", "Options/Kit/Views.lua", "Options/Kit/Widgets.lua", "Options/Kit/Window.lua",
	"Options/Options.lua"
}) do load(relative) end
local Kit = ns.OptionsKit
local Config, Renderer = Kit.Config, Kit.Renderer
assert(Config.GetDisabledDesc and Config.SetDisabledDesc, "Config has no disabled-reason accessors")

dofile(scratch .. "/option_components.lua")(load, ns)
for file in readFile("Options/Options.xml"):gmatch('<Script file="OptionsPages\\([%w_]+%.lua)"/>') do
	local ok, err = pcall(load, "Options/OptionsPages/" .. file)
	if (not ok) then print("note: page did not load under stubs: " .. file .. " " .. tostring(err):sub(1, 120)) end
end
local Options = realModules.Options
assert(pcall(function() Options:GenerateOptionsMenu() end), "GenerateOptionsMenu failed")
local options = assert(Options:GetOptionsObject(), "no options table")

local tooltips = assert(options.args["Tooltips"], "Tooltips page")
local explorer = assert(options.args["Explorer Mode"], "Explorer Mode page")
local groupFrames = assert(options.args["Group Frames"], "Group Frames page")
local unitFrames = assert(options.args["Unit Frames"], "Unit Frames page")
assert(groupFrames.args.party, "party group")

local ON = "Unavailable while \"%s\" is on."
local OFF = "Unavailable while \"%s\" is off."

--------------------------------------------------------------------------
-- A: every row that can be shown greyed out has the right reason
--------------------------------------------------------------------------
local function visible(path)
	local group = options
	for i = 1, #path do
		group = Config.GetSubOption(group, path[i])
		local sub = {}
		for j = 1, i do sub[j] = path[j] end
		if (not group or Config.IsHidden(group, options, sub, Addon)) then return false end
	end
	return true
end

local function rows(group, path, out)
	for key, option in pairs(group.args or {}) do
		local here = {}
		for i = 1, #path do here[i] = path[i] end
		here[#here + 1] = key
		if (option.type == "group") then
			rows(option, here, out)
		elseif (option.type ~= "header" and option.type ~= "description") then
			out[#out + 1] = { key = key, option = option, path = here }
		end
	end
	return out
end

-- Runs every combination of `keys` (booleans in `profile`), plus ConsolePort on/off
-- when asked, and calls back for each row that is shown and disabled.
local function sweep(pagePath, group, profile, keys, withConsolePort, expect)
	local list = rows(group, pagePath, {})
	local seen, greyed = {}, 0
	local states = 2 ^ (#keys + (withConsolePort and 1 or 0))
	for n = 0, states - 1 do
		local state, bits = {}, n
		for _, key in ipairs(keys) do
			state[key] = (bits % 2 == 1); bits = math.floor(bits / 2)
			profile[key] = state[key]
		end
		consolePort = withConsolePort and (bits % 2 == 1) or false
		for _, row in ipairs(list) do
			if (visible(row.path) and Config.IsDisabled(row.option, options, row.path, Addon)) then
				greyed = greyed + 1
				seen[row.key] = true
				local reason = Config.GetDisabledDesc(row.option, options, row.path, Addon)
				local want = expect(row.key, state, consolePort)
				if (not check(type(reason) == "string" and reason ~= "", "greyed row has a reason", row.key)) then
				elseif (want) then
					check(reason == want, "reason names what greys " .. row.key, reason .. " ~= " .. want)
				end
			end
		end
	end
	consolePort = false
	return seen, greyed
end

-- Tooltips: ConsolePort first (it also locks "Do not style tooltips"), then
-- styling off, then anchoring off for "Anchor to Cursor".
do
	local seen = sweep({ "Tooltips" }, tooltips, profiles.Tooltips, { "disableAzeriteUITooltips", "anchor" }, true,
		function(key, state, cp)
			local byCP = (key ~= "showItemID" and key ~= "showSpellID" and key ~= "showMythicPlusRating")
			if (byCP and cp) then return "Unavailable while ConsolePort is enabled." end
			if (state.disableAzeriteUITooltips) then return ON:format("Do not style tooltips") end
			if (key == "anchorToCursor" and not state.anchor) then return OFF:format("Enable Anchoring") end
		end)
	for _, key in ipairs({ "theme", "disableAzeriteUITooltips", "nameplateUnitTransparency", "showItemID",
		"showSpellID", "showMythicPlusRating", "anchor", "anchorToCursor" }) do
		check(seen[key], "Tooltips row seen greyed", key)
	end
	profiles.Tooltips.disableAzeriteUITooltips, profiles.Tooltips.anchor = false, true
end

-- Explorer Mode. The stored values are reversed: true = let it fade.
do
	local seen = sweep({ "Explorer Mode" }, explorer, profiles.ExplorerMode,
		{ "enabled", "fadeInInstances", "fadeWithFriendlyTarget", "fadeWithHostileTarget", "fadeWithLowMana" }, false,
		function(key)
			if (key == "fadeInMythicPlus") then
				return ("Unavailable while \"%s\" keeps your interface visible."):format("While in an instance")
			end
			if (key == "fadeWithDeadTarget") then
				return "Unavailable while neither friendly nor hostile targets keep your interface visible."
			end
			if (key == "fadeThresholdManaInForms") then return "Only Druids use this." end
		end)
	for _, key in ipairs({ "fadeInMythicPlus", "fadeWithDeadTarget", "fadeThresholdManaInForms" }) do
		check(seen[key], "Explorer row seen greyed", key)
	end
	profiles.ExplorerMode.enabled = true
end

-- Party group: aura row off, stock behaviour, dispellable-only; class colours; range.
do
	local seen = sweep({ "Group Frames", "party" }, groupFrames.args.party, profiles.PartyFrames,
		{ "enabled", "showAuras", "partyAuraUseStockBehavior", "partyAuraOnlyDispellableDebuffs",
			"useClassColors", "useRangeIndicator" }, false,
		function(key, state)
			if (key == "useBlizzardHealthColors" or key == "useClassColorOnMouseoverOnly") then
				return OFF:format("Use Class Colors")
			end
			if (key == "rangeIndicatorRange") then return OFF:format("Use Range Indicator") end
			if (not state.showAuras) then return OFF:format("Show Auras") end
			if (state.partyAuraUseStockBehavior) then return ON:format("Use AzeriteUI Stock Behavior") end
			if (state.partyAuraOnlyDispellableDebuffs) then return ON:format("Only Show Dispellable Debuffs") end
		end)
	for _, key in ipairs({ "partyAuraShowOtherDebuffs", "partyAuraShowDispellableDebuffs", "partyAuraUseStockBehavior",
		"AuraSize", "useBlizzardHealthColors", "rangeIndicatorRange" }) do
		check(seen[key], "party row seen greyed", key)
	end
	-- The row the brief names: dispellable-only greys it with its own reason.
	local p = profiles.PartyFrames
	p.enabled, p.showAuras, p.partyAuraUseStockBehavior, p.partyAuraOnlyDispellableDebuffs = true, true, false, true
	local other = groupFrames.args.party.args.partyAuraShowOtherDebuffs
	local path = { "Group Frames", "party", "partyAuraShowOtherDebuffs" }
	check(Config.IsDisabled(other, options, path, Addon) and
		Config.GetDisabledDesc(other, options, path, Addon) == ON:format("Only Show Dispellable Debuffs"),
		"Show Other Short Debuffs: greyed by dispellable-only, says so")
	p.partyAuraOnlyDispellableDebuffs = false
	check(not Config.IsDisabled(other, options, path, Addon), "Show Other Short Debuffs usable again")
end

--------------------------------------------------------------------------
-- B: the renderer shows the reason only while disabled
--------------------------------------------------------------------------
local function helpOf(page, key)
	for _, control in ipairs(page:GetControls()) do
		if (control.path and control.path[#control.path] == key) then
			return control.shownHelp or control.helpText, control
		end
	end
end

do
	local flag = false
	local fixture = {
		type = "group", name = "Fixture",
		args = {
			page = {
				type = "group", name = "Page",
				args = {
					plain = { type = "toggle", name = "Plain", desc = "Plain help", order = 1,
						get = function() return true end, set = function() end,
						disabled = function() return flag end },
					fn = { type = "toggle", name = "Fn", desc = "Fn help", order = 2,
						get = function() return true end, set = function() end,
						disabled = function() return flag end },
					silent = { type = "toggle", name = "Silent", desc = "Silent help", order = 3,
						get = function() return true end, set = function() end,
						disabled = function() return flag end },
					inner = {
						type = "group", name = "Inner", inline = true, order = 4,
						disabled = function() return flag end,
						args = {
							child = { type = "toggle", name = "Child", desc = "Child help",
								get = function() return true end, set = function() end }
						}
					}
				}
			}
		}
	}
	local page = fixture.args.page
	Config.SetDisabledDesc(page.args.plain, "Plain reason")
	Config.SetDisabledDesc(page.args.fn, function(info) return "Reason for " .. tostring(info[#info]) end)
	Config.SetDisabledDesc(page.args.inner, "Inherited reason")
	check(fixture.args.page.args.plain.disabledDesc == nil, "the reason is not written into the option table")

	local content = CreateFrame("Frame")
	content:SetWidth(704)
	local view = Renderer:CreatePage(content)
	view:Show(fixture, { "page" })
	check(helpOf(view, "plain") == "Plain help", "usable row shows its help", helpOf(view, "plain"))
	check(helpOf(view, "child") == "Child help", "usable child shows its help", helpOf(view, "child"))

	flag = true
	view:Refresh()
	local help, control = helpOf(view, "plain")
	check(help == "Plain reason", "greyed row shows its reason after a refresh", help)
	check(control and control.disabled == true, "and is greyed")
	check(helpOf(view, "fn") == "Reason for fn", "a function reason gets the row's info", helpOf(view, "fn"))
	check(helpOf(view, "silent") == "Silent help", "a greyed row without a reason keeps its help", helpOf(view, "silent"))
	check(helpOf(view, "child") == "Inherited reason", "the reason is inherited like disabled", helpOf(view, "child"))

	flag = false
	view:Refresh()
	check(helpOf(view, "plain") == "Plain help", "the help line returns once usable", helpOf(view, "plain"))

	-- A gathered list (Quick Start, Changed, search) binds each row the same way.
	flag = true
	view:ShowList(fixture, function() return Renderer:Collect(page, fixture, { "page" }) end)
	check(helpOf(view, "plain") == "Plain reason", "a gathered row shows the reason too", helpOf(view, "plain"))
	flag = false
	view:Refresh()
	check(helpOf(view, "plain") == "Plain help", "and its help once usable", helpOf(view, "plain"))

	-- The real Tooltips page, end to end.
	profiles.Tooltips.disableAzeriteUITooltips = true
	view:Show(options, { "Tooltips" })
	check(helpOf(view, "showSpellID") == ON:format("Do not style tooltips"), "real page: reason while styling is off",
		helpOf(view, "showSpellID"))
	check(helpOf(view, "hideInCombat") == "Hide Tooltips while engaged in combat.", "real page: an unaffected row keeps its help")
	profiles.Tooltips.disableAzeriteUITooltips = false
	view:Refresh()
	check(helpOf(view, "showSpellID") ==
		"Toggle whether to add spellIDs and auraIDs in tooltips containing actions, spells or auras.",
		"real page: help line back when styling is on", helpOf(view, "showSpellID"))
end

--------------------------------------------------------------------------
-- C: disableAuraSorting is written and read in UnitFrames db.profile
--------------------------------------------------------------------------
do
	local option = assert(unitFrames.args.disableAuraSorting, "Prioritize Unit Frame Auras option")
	local path = { "Unit Frames", "disableAuraSorting" }
	Config.SetValue(option, options, path, Addon, false)
	check(profiles.UnitFrames.disableAuraSorting == true, "unticking writes UnitFrames db.profile.disableAuraSorting")
	Config.SetValue(option, options, path, Addon, true)
	check(profiles.UnitFrames.disableAuraSorting == false, "ticking clears it")
	check(Config.GetValue(option, options, path, Addon) == true, "and reads it back from the same key")

	local readers = {
		"Components/UnitFrames/UnitFrame.lua", "Components/UnitFrames/Units/Party.lua",
		"Components/UnitFrames/Units/Raid5.lua", "Components/UnitFrames/Units/Arena.lua",
		"Components/UnitFrames/NamePlates/Style.lua"
	}
	local total = 0
	for _, relative in ipairs(readers) do
		local source = readFile(relative)
		local ownModule = source:find('ns:NewModule("UnitFrames"', 1, true) ~= nil
		local count = 0
		for line in (source .. "\n"):gmatch("([^\n]*)\n") do
			if (line:find("disableAuraSorting", 1, true)) then
				-- The expression before the key, without the `if (` around it.
				local expr = (line:match("([%w_%.:%(%)\"]*)%.disableAuraSorting") or ""):gsub("^%(+", "")
				local isDefault = line:match("^%s*disableAuraSorting%s*=")
				if (not isDefault) then
					count = count + 1
					local good = (expr == 'ns:GetModule("UnitFrames").db.profile')
						or (ownModule and expr == "self.db.profile")
					check(good, "reads UnitFrames db.profile: " .. relative, line:gsub("^%s+", ""))
				end
			end
		end
		check(count > 0, "has a disableAuraSorting reader", relative)
		total = total + count
	end
	check(total >= 5, "five runtime readers found", total)
end

--------------------------------------------------------------------------
-- D: the tables still pass the real AceConfigRegistry validator
--------------------------------------------------------------------------
do
	local env = setmetatable({}, { __index = _G })
	local libs = {}
	env.LibStub = setmetatable({
		NewLibrary = function(_, major) libs[major] = libs[major] or {}; return libs[major] end
	}, { __call = function(_, major)
		if (major == "CallbackHandler-1.0") then return { New = function() return {} end } end
		return libs[major]
	end })
	local chunk = assert(loadfile(root .. "/Libs/AceConfig-3.0/AceConfigRegistry-3.0/AceConfigRegistry-3.0.lua"))
	setfenv(chunk, env)
	chunk()
	local Registry = assert(libs["AceConfigRegistry-3.0"], "AceConfigRegistry loaded")

	for name, group in pairs({ Tooltips = tooltips, ["Explorer Mode"] = explorer, ["Group Frames"] = groupFrames }) do
		local ok, err = pcall(Registry.ValidateOptionsTable, Registry, group, name)
		check(ok, "AceConfigRegistry accepts the " .. name .. " table", err)
	end

	-- Why the reason is kept aside: a key on the option fails validation.
	local probe = { type = "group", args = { row = { type = "toggle", name = "Row", disabledDesc = "why" } } }
	check(not pcall(Registry.ValidateOptionsTable, Registry, probe, "probe"),
		"a disabledDesc key on an option fails AceConfigRegistry")
end

print(string.format("Disabled reasons: %d checks, %d failures", checks, failures))
if (failures > 0) then os.exit(1) end

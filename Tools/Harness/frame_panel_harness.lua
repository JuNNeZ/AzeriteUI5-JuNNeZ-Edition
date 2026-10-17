-- The frame settings panel (Options/Kit/FramePanel.lua) against the REAL options table.
--
-- Builds every option page as real_options_harness.lua does, then checks each frame's quick
-- settings: every path reaches a drawable setting, every key is a real mover, at most five rows,
-- and "More settings" names a real section. It cannot say how the panel looks or feels in game.
--
-- lua Tools/Harness/frame_panel_harness.lua . Tools/Harness [Forever]

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

load("Core/ThemeBarPreview.lua")
load("Options/Kit/Kit.lua")
load("Options/Kit/Widgets.lua")
load("Options/Kit/Window.lua")
load("Options/Options.lua")

local Kit = ns.OptionsKit
local Options = realModules["Options"]

-- A default profile: Player on, the other two player frames off (one at a time).
ns:GetModule("PlayerFrame").db.profile.enabled = true
ns:GetModule("PlayerFrameAlternate").db.profile.enabled = false
ns:GetModule("PlayerFrameParty").db.profile.enabled = false

-- Components an option page builds from directly (Tools/Harness/option_components.lua).
dofile((arg[2] or ".") .. "/option_components.lua")(load, ns)

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


local checks, failures = 0, 0
local function check(value, label, detail)
	checks = checks + 1
	if (not value) then
		failures = failures + 1
		print("FAIL: " .. label .. (detail ~= nil and ("  (" .. tostring(detail) .. ")") or ""))
	end
end

for _, file in ipairs({ "Options/Kit/Config.lua", "Options/Kit/Defaults.lua", "Options/Kit/Combat.lua",
	"Options/Kit/Controls.lua", "Options/Kit/Preview.lua", "Options/Kit/Renderer.lua" }) do
	local key = file:match("Kit/(%a+)%.lua")
	if (not Kit[key]) then load(file) end
end
load("Options/Kit/FramePanel.lua")
local FramePanel = Kit.FramePanel
check(FramePanel and FramePanel.Settings, "FramePanel loads")

-- The real mover keys: every module that calls CreateAnchor, plus the ones that name their own.
local movers = { PetBar = true, StanceBar = true, ["PlayerFrame.debuffs"] = true, ["PlayerFrame.secondaryMana"] = true }
for id = 1, 8 do movers["ActionBars.bar" .. id] = true end
-- Every file Components.xml loads, followed through its includes the way the client does.
local function Walk(xmlPath)
	local handle = io.open(root .. "/" .. xmlPath)
	if (not handle) then return end
	local text = handle:read("*a")
	handle:close()
	local dir = xmlPath:match("^(.*)/[^/]*$") or ""
	for kind, file in text:gmatch('<(%a+) file="([^"]+)"') do
		local path = dir .. "/" .. file:gsub("\\", "/")
		if (kind == "Include") then
			Walk(path)
		elseif (kind == "Script") then
			local lua = io.open(root .. "/" .. path)
			if (lua) then
				local source = lua:read("*a")
				lua:close()
				if (source:find(":CreateAnchor%(")) then
					local name = source:match('ns:NewModule%("([%w_]+)"')
					if (name) then movers[name] = true end
					-- A shared body building several modules from specs (RaidLarge.lua).
					for specName in source:gmatch('moduleName = "([%w_]+)"') do movers[specName] = true end
				end
			end
		end
	end
end
Walk("Components/Components.xml")
local found = 0
for _ in pairs(movers) do found = found + 1 end
check(found > 40, "movers found through Components.xml", found)

local count, drawn = 0, {}
for key, spec in pairs(FramePanel.Settings) do
	count = count + 1
	check(movers[key], "a real mover: " .. key)
	check(#spec.rows >= 1 and #spec.rows <= 5, key .. " has one to five settings", #spec.rows)

	local section = Kit.Config.GetGroup(options, spec.section)
	local sectionBar = tonumber((spec.section[2] or ""):match("^bar(%d)$"))
	if (not (forever and sectionBar and sectionBar > 5)) then
		check(type(section) == "table" and section.type == "group", key .. ": its section exists", table.concat(spec.section, "."))
	end
	-- Class Power's heading is its module's GetLabel(), which the stub cannot answer.
	if (spec.section[2] and type(section) == "table" and key ~= "PlayerClassPowerFrame") then
		local name = Kit.Config.GetName(section, options, spec.section, Addon)
		check(type(name) == "string" and name ~= "", key .. ": the section has a heading to open")
	end

	local entries = FramePanel:CollectSettings(key, options)
	for _, path in ipairs(spec.rows) do
		local option = Kit.Config.GetGroup(options, path)
		-- Forever has no arena or class power settings for a Mage, and five bars.
		local bar = tonumber((path[2] or ""):match("^bar(%d)$"))
		local hiddenHere = forever and (path[2] == "arena" or path[2] == "classpower" or (bar and bar > 5))
		if (not hiddenHere) then
			check(type(option) == "table" and option.type ~= "group" and option.type ~= "header",
				key .. ": " .. table.concat(path, "."), option and option.type)
		end
	end
	-- A page may hide its own rows (a disabled module, another client); the panel follows.
	check(#entries <= #spec.rows, key .. ": no more rows than listed", #entries .. "/" .. #spec.rows)
	drawn[key] = #entries
	for _, entry in ipairs(entries) do
		check(entry.option and entry.path and entry.kind, key .. ": entry carries option, path and kind")
	end
end
check(count >= 30, "settings for every frame with options", count)
-- Frames whose rows nothing hides under these stubs: all five must come through.
check(drawn["ActionBars.bar1"] == 5 and drawn.TargetFrame == 5 and drawn.PartyFrames == 5 and drawn.Tooltips == 5,
	"bar 1, Target, Party and Tooltips draw all five", tostring(drawn["ActionBars.bar1"]) .. "," .. tostring(drawn.TargetFrame))
-- The three player frames are always listed; while Player is on, the other two show only
-- their switch (FixLog 2026-10-17: Alternate used to be hidden until Player was off).
check(drawn.PlayerFrameAlternate == 1, "Player Alternate shows its switch while the Player frame is on", drawn.PlayerFrameAlternate)
-- Its switch, and Explorer Mode's player fade, which is shared and never hidden.
check(drawn.PlayerFrameParty == 2, "Player (Party Style) shows its switch while the Player frame is on", drawn.PlayerFrameParty)

-- One player frame at a time, through the real switches (UnitFrames.lua UsePlayerFrame).
do
	local profiles = {
		PlayerFrame = ns:GetModule("PlayerFrame").db.profile,
		PlayerFrameAlternate = ns:GetModule("PlayerFrameAlternate").db.profile,
		PlayerFrameParty = ns:GetModule("PlayerFrameParty").db.profile
	}
	local function state()
		return string.format("%s/%s/%s", tostring(profiles.PlayerFrame.enabled),
			tostring(profiles.PlayerFrameAlternate.enabled), tostring(profiles.PlayerFrameParty.enabled))
	end
	local function switch(page, val)
		local path = { "Unit Frames", page, "enabled" }
		local option = Kit.Config.GetGroup(options, path)
		option.set({ "Unit Frames", page, "enabled" }, val)
	end
	switch("playerParty", true)
	check(state() == "false/false/true", "Use Party Frame as Player Frame turns Player and Alternate off", state())
	switch("playerAlternate", true)
	check(state() == "false/true/false", "Alternate on turns the party style off", state())
	switch("playerParty", true)
	switch("playerParty", false)
	check(state() == "true/false/false", "party style off brings Player back", state())
	switch("playerAlternate", true)
	switch("player", true)
	check(state() == "true/false/false", "Player on turns Alternate off", state())
	switch("player", false)
	check(state() == "false/false/false", "Player off leaves no player frame, as before", state())
	switch("player", true)
end
check(forever and drawn.Minimap == 5 or (not forever and drawn.Minimap == 4), "Day and Night only on Forever", drawn.Minimap)
check(forever and drawn["ActionBars.bar6"] == 0 or (not forever and drawn["ActionBars.bar6"] == 5), "bar 6 only where it exists",
	drawn["ActionBars.bar6"])
check(#FramePanel:CollectSettings("AlertFrames", options) == 0, "a frame with no options gets Position only")

-- The Position rows come from the /lock window's table, by name.
local fake = { type = "group", args = {} }
for _, key in ipairs(FramePanel.PositionRows) do
	fake.args[key] = { type = key:find("Offset") and "input" or (key == "scale" and "range" or "select"), name = key, values = {} }
end
check(#FramePanel:CollectPosition(fake) == #FramePanel.PositionRows, "every Position row is collected")
fake.args.anchorPoint.hidden = function() return true end
check(#FramePanel:CollectPosition(fake) == #FramePanel.PositionRows - 1, "a hidden Position row is left out")

print(string.format("Frame panel%s: %d checks, %d failures (%d frames)", forever and " (Forever)" or "", checks, failures, count))
os.exit(failures == 0 and 0 or 1)

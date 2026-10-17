-- Full-path options navigation over the real Config, Renderer and Panel.
-- Usage: lua Tools/Harness/options_navigation_harness.lua . Tools/Harness [Forever]
-- Fourth argument injects one in-memory mutant: shallow-collect, skip-folds,
-- skip-tabs, page-only-jump. Each must fail; source files are never modified.
-- This records widget state and layout; it does not establish live WoW rendering.
local root, scratch = arg[1] or ".", arg[2] or "Tools/Harness"
local S = dofile(scratch .. "/stubs.lua")
local ns, Addon = S.ns, S.Addon
if arg[3] == "Forever" then
	ns.IsRetail, ns.IsRetailContent, ns.IsMainline = false, false, false
	ns.IsForever = true
end

local checks, failures = 0, 0
local function check(ok, label, detail)
	checks = checks + 1
	if not ok then
		failures = failures + 1
		print("FAIL " .. label .. (detail and ": " .. tostring(detail) or ""))
	end
	return ok
end

local mutation = arg[4]
local mutants = {
	["shallow-collect"] = {
		file = "Options/Kit/Renderer.lua",
		before = "Collect(option, options, childPath, out, depth + 1)",
		after = "if (depth == 0) then Collect(option, options, childPath, out, depth + 1) end"
	},
	["skip-folds"] = {
		file = "Options/Kit/Renderer.lua",
		before = "if (child.collapsible) then page.sectionState[child.id] = true end",
		after = "-- mutant: leave enclosing sections closed"
	},
	["skip-tabs"] = {
		file = "Options/Kit/Renderer.lua",
		before = "if (child.tabbed) then page.activeTabs[node.id] = child.id end",
		after = "-- mutant: leave the previous tab selected"
	},
	["page-only-jump"] = {
		file = "Options/Kit/Panel.lua",
		before = "return self:RevealPath(path)",
		after = "return true -- mutant: open only the page, ignoring the setting path"
	}
}
assert(not mutation or mutants[mutation], "unknown navigation mutation: " .. tostring(mutation))
local mutationApplied = false
local function load(relative)
	local chunk, err
	local mutant = mutation and mutants[mutation]
	if mutant and relative == mutant.file then
		local file = assert(io.open(root .. "/" .. relative, "rb"))
		local source = file:read("*a"); file:close()
		local first, last = source:find(mutant.before, 1, true)
		assert(first, "mutation no longer matches source: " .. mutation)
		assert(not source:find(mutant.before, last + 1, true), "mutation match is ambiguous: " .. mutation)
		source = source:sub(1, first - 1) .. mutant.after .. source:sub(last + 1)
		chunk, err = loadstring(source, "@" .. relative .. ":" .. mutation)
		mutationApplied = true
	else
		chunk, err = loadfile(root .. "/" .. relative)
	end
	assert(chunk, err)
	return chunk(Addon, ns)
end
for _, relative in ipairs({
	"Options/Kit/Kit.lua", "Options/Kit/Look.lua", "Options/Kit/Config.lua",
	"Options/Kit/Defaults.lua", "Options/Kit/Combat.lua", "Options/Kit/Controls.lua",
	"Options/Kit/Renderer.lua", "Options/Kit/Views.lua", "Options/Kit/PanelOptions.lua",
	"Options/Kit/Panel.lua"
}) do load(relative) end
assert(not mutation or mutationApplied, "mutation was not applied")
local Kit = ns.OptionsKit
local Renderer, Panel, Config = Kit.Renderer, Kit.Panel, Kit.Config

-- Timers run only when the harness asks. This distinguishes the immediate
-- layout jump, next-frame range correction, and the later highlight expiry.
local timers = {}
C_Timer.After = function(delay, callback)
	timers[#timers + 1] = { delay = delay, callback = callback }
end
local function flushImmediate()
	for pass = 1, 10 do
		local pending, ran = timers, false
		timers = {}
		for _, timer in ipairs(pending) do
			if timer.delay == 0 then timer.callback(); ran = true
			else timers[#timers + 1] = timer end
		end
		if not ran then return end
	end
	error("navigation did not settle after ten timer passes")
end

local values, defaults, writes = {}, {}, 0
local function toggle(key, label, order)
	values[key], defaults[key] = false, false
	return {
		type = "toggle", name = label, order = order,
		get = function() return values[key] end,
		set = function(_, value) values[key] = value; writes = writes + 1 end
	}
end
local function group(name, args, order)
	return { type = "group", name = name, args = args, order = order }
end
local function fill(args, prefix, count, order)
	for i = 1, count do
		local key = prefix .. i
		args[key] = toggle(key, prefix .. " " .. i, (order or 0) + i)
	end
end
local conditionalVisible = true
local glow = group("Glow", { target = toggle("target", "Needle target", 50) }, 2)
fill(glow.args, "glow", 18)
local choices = group("Finish", {
	color = group("Colour", { color = toggle("color", "Colour flag", 1) }, 1),
	glow = glow
}, 2)
choices.childGroups = "tab"
local nested = group("Nested", {
	first = group("First", { first = toggle("first", "First nested flag", 1) }, 1),
	finish = choices
}, 30)
local generalAppearance = group("Appearance", {
	peer = toggle("peer", "Peer appearance flag", 1)
}, 2)
local advancedAppearance = group("Appearance", { nested = nested }, 2)
fill(advancedAppearance.args, "appearance", 18)
local advanced = group("Advanced", {
	start = group("Overview", { advanced = toggle("advanced", "Advanced flag", 1) }, 1),
	appearance = advancedAppearance,
	conditional = group("Conditional", { gated = toggle("gated", "Needle gated", 1) }, 3)
}, 2)
advanced.args.conditional.hidden = function() return not conditionalVisible end
local main = group("Navigation", {
	general = group("General", {
		start = group("Overview", { general = toggle("general", "General flag", 1) }, 1),
		appearance = generalAppearance
	}, 1),
	advanced = advanced,
	client = group("Client", { retail = toggle("retail", "Needle Retail", 1) }, 3)
}, 1)
main.args.client.hidden = function() return ns.IsForever end
local short = group("Short", { tiny = toggle("tiny", "Tiny flag", 1) }, 2)
local automatic = group("Automatic", {
	first = group("First", {}, 1), second = group("Second", {}, 2)
}, 3)
fill(automatic.args.first.args, "autofirst", 12)
fill(automatic.args.second.args, "autosecond", 12)
local options = group("Harness", { main = main, short = short, automatic = automatic })

-- Sidecars preserve the AceConfig schema, module bindings and saved values.
Renderer:SetNavigation(main, "tabs")
Renderer:SetNavigation(main.args.general, "sections")
Renderer:SetNavigation(advanced, "sections")
Renderer:SetNavigation(advancedAppearance, "sections")
Renderer:SetNavigation(nested, "sections")
S.modules.NavigationProbe = { GetProfileDefaults = function() return defaults end }
Kit.Defaults.Bind(options, "NavigationProbe")
S.modules.Options = {
	GetOptionsObject = function() return options end,
	GetSection = function() return "frames" end
}
S.AceConfigRegistry:RegisterOptionsTable(Addon, options)

check(Panel:Open("main"), "panel opens the fixture")
Panel.contentScroll:SetHeight(260)
Panel.railScroll:SetHeight(620)
Panel.page.content:SetWidth(704)
Panel:SelectPage("main")

local function samePath(a, b)
	if type(a) ~= "table" or type(b) ~= "table" or #a ~= #b then return false end
	for i = 1, #a do if a[i] ~= b[i] then return false end end
	return true
end
local function controlAt(path)
	local offset, index, control = Panel.page:GetPathOffset(path)
	return control, offset, index
end
local function sectionAt(path)
	for _, entry in ipairs(Panel.page:GetSections()) do
		if samePath(entry.path, path) then return entry end
	end
end
local function tabAt(path)
	for _, entry in ipairs(Panel.page:GetTabs()) do
		if samePath(entry.path, path) then return entry end
	end
end
local function clickSection(path)
	local entry = sectionAt(path)
	local button = entry and entry.header and entry.header.button
	local click = button and button:GetScript("OnClick")
	check(type(click) == "function", "section has a real click handler", table.concat(path, "."))
	if click then click(button) end
end
local function valueCount(entries)
	local count = 0
	for _, entry in ipairs(entries) do if entry.option then count = count + 1 end end
	return count
end
local function allCount()
	return valueCount(Renderer:Collect(main, options, { "main" }))
end
local target = { "main", "advanced", "appearance", "nested", "finish", "glow", "target" }
local peer = { "main", "general", "appearance", "peer" }

check(tabAt({ "main", "general" }) and tabAt({ "main", "general" }).selected,
	"first page tab starts selected")
check(controlAt(target) == nil, "target starts hidden behind inactive tab and folds")
local structuralBefore = allCount()
check(structuralBefore > 40, "structural collection includes inactive deep descendants", structuralBefore)
check(writes == 0, "initial navigation writes no setting")

-- Search uses its real Enter handler, which clicks the first actual result.
Panel.searchBox:SetFocus()
Panel.searchBox:SetText("Needle target")
Panel:ShowResults("Needle target")
local enter = Panel.searchBox:GetScript("OnEnterPressed")
check(type(enter) == "function", "search Enter is wired")
if enter then enter(Panel.searchBox) end
flushImmediate()
local targetControl, targetOffset = controlAt(target)
check(not Panel.searching and Panel.selected == "main", "search result opens its owning page")
check(targetControl and targetControl.labelText == "Needle target", "result reveals the exact deeply nested leaf")
check(tabAt({ "main", "advanced" }) and tabAt({ "main", "advanced" }).selected,
	"result selects its inactive ancestor tab")
check(tabAt({ "main", "advanced", "appearance", "nested", "finish", "glow" })
	and tabAt({ "main", "advanced", "appearance", "nested", "finish", "glow" }).selected,
	"result selects the nested tab too")
for _, path in ipairs({
	{ "main", "advanced", "appearance" },
	{ "main", "advanced", "appearance", "nested" },
	{ "main", "advanced", "appearance", "nested", "finish" }
}) do
	local entry = sectionAt(path)
	check(entry and not entry.closed, "result opens every fold ancestor", table.concat(path, "."))
end
local scroll, viewport = Panel.contentScroll:GetVerticalScroll(), Panel.contentScroll:GetHeight()
check(targetControl and targetOffset >= scroll and targetOffset < scroll + viewport,
	"exact target lies inside the viewport", tostring(targetOffset) .. " / " .. tostring(scroll))
check(targetControl and targetControl.focused, "exact result is visibly highlighted")
check(not Panel.searchBox:HasFocus() and Panel.keyboardHost == nil
	and not Panel.frame:IsKeyboardEnabled(), "revealing a result leaves movement keys available")
check(writes == 0 and allCount() == structuralBefore, "opening all ancestors preserves values and structural collection")

-- The same display name and child key in another tab must not share state.
check(Panel:GoTo(peer), "full path navigates to the peer Appearance")
flushImmediate()
check(controlAt(peer) ~= nil and controlAt(target) == nil, "peer path selects only its own tab")
clickSection({ "main", "general", "appearance" })
check(controlAt(peer) == nil, "the peer Appearance can be closed")
check(Panel:GoTo(target), "returning to a deep target opens its own Appearance")
flushImmediate()
check(controlAt(target) ~= nil, "other Appearance remains independently navigable")
check(Panel:GoTo({ "main", "general" }), "tab path alone can be opened")
flushImmediate()
check(sectionAt({ "main", "general", "appearance" })
	and sectionAt({ "main", "general", "appearance" }).closed,
	"closing a same-name section affects only its full path")

-- Changed and reset read structural settings even when controls are hidden.
values.target = true
local changed, changedCount = Kit.Views.CollectChanged(options, { { key = "main", name = "Navigation" } })
check(changedCount == 1 and valueCount(changed) == 1 and samePath(changed[#changed].path, target),
	"Changed includes a modified leaf in an inactive closed branch")
check(Kit.Defaults.CountModified(options, { "main" }) == 1, "rail tally includes that hidden modified leaf")
Panel:SelectPage(Kit.Views.CHANGED)
local changedControl = controlAt(target)
check(changedControl and #Panel.page:GetTabs() == 0,
	"the actual Changed view draws the hidden setting without tabs")
if changedControl and changedControl.onRevert then changedControl.onRevert(changedControl) end
check(values.target == false, "Changed reset writes the original full-path setting")
check(Kit.Defaults.CountModified(options, { "main" }) == 0, "reset removes the hidden change from the tally")

-- Search is rebuilt against current class/client visibility, independent of
-- navigation state; stale paths must not make a hidden group available.
conditionalVisible = false
Panel:BuildRail()
check(Panel:GoTo({ "main", "advanced", "conditional", "gated" }) == false,
	"hidden ancestor rejects a stale full-path jump")
Panel:ShowResults("Needle gated")
check(Panel.pageDesc:GetText() == "Nothing matches that.", "hidden conditional descendants leave search")
Panel:ClearSearch()
Panel:ShowResults("Needle Retail")
check((Panel.pageDesc:GetText() == "Nothing matches that.") == ns.IsForever,
	"client hidden descendants follow the current client gate")
Panel:ClearSearch()

-- Plain short pages keep their existing rows; long groups get useful folding
-- without annotating every page in the addon.
Panel:SelectPage("short")
check(#Panel.page:GetTabs() == 0 and #Panel.page:GetSections() == 0
	and #Panel.page:GetControls() == 1 and controlAt({ "short", "tiny" }),
	"short ungrouped page keeps one ordinary control")
Panel:SelectPage("automatic")
check(sectionAt({ "automatic", "first" }) and not sectionAt({ "automatic", "first" }).closed,
	"long page automatically opens its first section")
check(sectionAt({ "automatic", "second" }) and sectionAt({ "automatic", "second" }).closed,
	"long page automatically closes later sections")
check(controlAt({ "automatic", "second", "autosecond1" }) == nil,
	"closed auto section omits its controls")
check(valueCount(Renderer:Collect(automatic, options, { "automatic" })) == 24,
	"closed auto sections remain complete in structural collection")

-- A legacy section label and a full mover path both select the right content.
check(Panel:OpenSection("main", target), "mover full section path opens")
flushImmediate()
check(controlAt(target) ~= nil, "mover path reaches a leaf inside tabs and folds")
check(Panel:OpenSection("automatic", "Second"), "legacy section label still opens")
flushImmediate()
check(controlAt({ "automatic", "second", "autosecond1" }) ~= nil,
	"legacy label opens the requested collapsed section")

-- A delayed scroll from a search must not drag the next page away from its top.
Panel:GoTo(target)
Panel:SelectPage("short")
flushImmediate()
check(Panel.selected == "short" and Panel.contentScroll:GetVerticalScroll() == 0,
	"a deferred jump cannot move a different page")
check(Panel:GoTo({ "main", "missing", "target" }) == false,
	"missing paths do not claim navigation succeeded")
check(values.target == false and values.peer == false and writes == 1,
	"only the explicit reset wrote profile data", writes)

-- Mouse navigation is passive; keyboard navigation is explicitly entered and
-- can still operate the new tab strips and foldable headings.
local function focusControl(predicate)
	Panel:ClearKeyboardFocus()
	for i = 1, 500 do
		Panel:MoveKeyboardFocus(1)
		local kind, index = Panel:GetKeyboardFocus()
		local control = kind == "control" and Panel.page:GetControls()[index]
		if control and predicate(control) then return control end
	end
end
Panel:SelectPage("main")
local tabsControl = focusControl(function(control) return control.kind == "tabs" end)
check(tabsControl and Panel.keyboardHost == tabsControl.frame,
	"Tab can explicitly reach the tab-strip control")
local selectedTab
for _, entry in ipairs(Panel.page:GetTabs()) do
	if #entry.path == 2 and entry.selected then selectedTab = entry.path[2] end
end
Panel:OnKey("RIGHT")
local nextTab
for _, entry in ipairs(Panel.page:GetTabs()) do
	if #entry.path == 2 and entry.selected then nextTab = entry.path[2] end
end
check(nextTab and nextTab ~= selectedTab, "Right changes the explicitly focused tab")
check(Panel.keyboardHost == nil, "tab replacement releases the old keyboard host")
Panel:SelectPage("automatic")
if sectionAt({ "automatic", "second" }) and not sectionAt({ "automatic", "second" }).closed then
	clickSection({ "automatic", "second" })
end
local closedHeader = focusControl(function(control) return control.kind == "header" and control.closed end)
check(closedHeader and closedHeader.navigation, "Tab can explicitly reach a closed section heading")
Panel:OnKey("ENTER")
check(controlAt({ "automatic", "second", "autosecond1" }) ~= nil,
	"Enter opens a focused section heading")
check(Panel.keyboardHost == nil, "fold replacement releases the old keyboard host")

-- Timed search feedback must not erase a newer mark after controls are pooled,
-- or erase a keyboard mark acquired while the search feedback was fading.
Panel:GoTo(target)
flushImmediate()
local expired = timers
timers = {}
Panel:SelectPage("short")
Panel:GoTo(target)
flushImmediate()
targetControl = controlAt(target)
for _, timer in ipairs(expired) do if timer.delay > 0 then timer.callback() end end
check(targetControl and targetControl.focused, "old pooled highlight timers cannot clear a newer result")
local pendingExpiry = timers
timers = {}
for _, timer in ipairs(pendingExpiry) do if timer.delay > 0 then timer.callback() end end
check(targetControl and not targetControl.focused, "the current search highlight expires")
Panel:GoTo(target)
flushImmediate()
local keyboardTarget = focusControl(function(control) return control.labelText == "Needle target" end)
local keyboardExpiry = timers
timers = {}
for _, timer in ipairs(keyboardExpiry) do if timer.delay > 0 then timer.callback() end end
check(keyboardTarget and keyboardTarget.focused and Panel.keyboardHost == keyboardTarget.frame,
	"search expiry cannot clear a later keyboard focus mark")
Panel:ClearKeyboardFocus()
check(values.target == false and writes == 1, "navigation keys never write the target setting")

print(string.format("%d checks, %d failures (%s)", checks, failures, ns.IsForever and "Forever" or "Retail"))
os.exit(failures == 0 and 0 or 1)

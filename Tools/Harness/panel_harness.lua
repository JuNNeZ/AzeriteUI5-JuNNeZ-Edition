-- Drives the new panel over the addon's real option tables.
--
-- Opens it, walks every page in the rail, renders each one, searches, and
-- reports what got drawn. The point is that all ~590 real options go through
-- Config -> Renderer -> Controls without a single error, because that is the
-- path AceConfigDialog used to own.
--
-- Usage: lua panel_harness.lua <addon root> <scratchpad>

local root, SP = arg[1], arg[2]
local S = dofile(SP .. "/stubs.lua")
local ns, Addon = S.ns, S.Addon

local failures, checks = 0, 0
local function check(ok, what, detail)
	checks = checks + 1
	if not ok then
		failures = failures + 1
		if failures <= 30 then
			print(string.format("  FAIL  %s%s", what, detail and ("  -- " .. tostring(detail)) or ""))
		end
	end
	return ok
end

local function section(name) print("\n== " .. name .. " ==") end

--------------------------------------------------------------------------
-- Build the real option tables
--------------------------------------------------------------------------
local autoMT
autoMT = { __index = function(t, k)
	-- t[nil] is a legal read in Lua and answers nil; only a write raises. Caching
	-- the miss would make this stub stricter than the language it stands in for.
	if k == nil then return nil end
	local v = setmetatable({}, autoMT); rawset(t, k, v); return v
end }

local dataFields = { db = true, defaults = true, settings = true, bars = true }
local moduleStubMT = { __index = function(t, k)
	local v
	if dataFields[k] then v = setmetatable({}, autoMT)
	else v = function() return setmetatable({}, autoMT) end end
	rawset(t, k, v); return v
end }

ns.GetModule = function(self, name)
	if S.modules[name] then return S.modules[name] end
	S.modules[name] = setmetatable({}, moduleStubMT)
	return S.modules[name]
end

local function load(rel)
	local chunk, err = loadfile(root .. "/" .. rel)
	if not chunk then error("could not load " .. rel .. ": " .. tostring(err)) end
	return chunk(Addon, ns)
end

section("The stubs themselves")
--------------------------------------------------------------------------
-- Three of the four bugs this panel has shipped were harness stubs that lied,
-- and each one passed every check it was supposed to fail. So the stub's own
-- contract is checked here, first, before anything trusts it.
do
	local f = CreateFrame("Frame", nil, nil)

	check(f.railOffset == nil, "an unset field reads as nil, not as a no-op function",
		type(f.railOffset))
	check(type(f.SetPoint) == "function", "an unasked-for widget method still exists",
		type(f.SetPoint))

	check(f:IsShown() == true, "a new frame starts shown", f:IsShown())
	f:Hide()
	check(f:IsShown() == false, "Hide is remembered", f:IsShown())
	f:SetShown(true)
	check(f:IsShown() == true, "SetShown is remembered", f:IsShown())

	f:SetHeight(120)
	check(f:GetHeight() == 120, "a height that was set reads back", f:GetHeight())

	local scroll = CreateFrame("ScrollFrame", nil, nil)
	local child = CreateFrame("Frame", nil, scroll)
	child:SetHeight(1000)
	scroll:SetHeight(400)
	scroll:SetScrollChild(child)

	check(scroll:GetVerticalScrollRange() == 600,
		"the scroll range is the child minus the view", scroll:GetVerticalScrollRange())

	scroll:SetVerticalScroll(999999)
	check(scroll:GetVerticalScroll() == 600, "you cannot scroll past the end",
		scroll:GetVerticalScroll())

	local fired = 0
	scroll:SetScript("OnVerticalScroll", function() fired = fired + 1 end)
	scroll:SetVerticalScroll(600)
	check(fired == 0, "a scroll that does not move fires nothing", fired)
	scroll:SetVerticalScroll(0)
	check(fired == 1, "a scroll that does move fires once", fired)
end

--------------------------------------------------------------------------
section("Loading")
for _, file in ipairs({
	"Options/Kit/Kit.lua", "Options/Kit/Config.lua", "Options/Kit/Defaults.lua",
	"Options/Kit/Controls.lua", "Options/Kit/Preview.lua",
	"Options/Kit/Renderer.lua",
	"Options/Changelog.lua", "Options/Kit/PanelOptions.lua",
	"Options/Kit/Panel.lua", "Options/Kit/Gallery.lua",
	"Options/Kit/Widgets.lua", "Options/Kit/Window.lua", "Options/Options.lua",
}) do
	local ok, err = pcall(load, file)
	check(ok, file:match("[^/]+$") .. " loads", err)
end

local xml = io.open(root .. "/Options/Options.xml"):read("*a")
local pages, declaredPages = 0, 0
for file in xml:gmatch('<Script file="OptionsPages\\([%w_]+%.lua)"/>') do
	declaredPages = declaredPages + 1
	local ok = pcall(load, "Options/OptionsPages/" .. file)
	if ok then pages = pages + 1 end
end
check(declaredPages > 0 and pages == declaredPages,
	"all declared option pages load", string.format("%d of %d", pages, declaredPages))

local Options = S.modules["Options"]
Options:GenerateOptionsMenu()
local options = Options:GetOptionsObject()
check(options ~= nil, "the real options table is built")

local Kit = ns.OptionsKit
local Panel, Renderer, Config = Kit.Panel, Kit.Renderer, Kit.Config
check(Panel ~= nil, "Kit.Panel exists")
check(Renderer ~= nil, "Kit.Renderer exists")

--------------------------------------------------------------------------
section("Sections")
--------------------------------------------------------------------------
-- Every page must land in a named band, or the rail silently drops it into the
-- catch-all and the grouping stops meaning anything.
local keys = Config.SortedKeys(options, options, {}, Addon)
local sectioned, unsectioned = 0, {}
for _, key in ipairs(keys) do
	local option = Config.GetSubOption(options, key)
	if type(option) == "table" and option.type == "group" then
		local s = Options:GetSection(key)
		if s then sectioned = sectioned + 1 else unsectioned[#unsectioned + 1] = key end
	end
end
check(#unsectioned == 0, "every page names a rail section",
	table.concat(unsectioned, ", "))
print(string.format("  %d pages, all sectioned", sectioned))

--------------------------------------------------------------------------
section("Opening")
--------------------------------------------------------------------------
local ok, err = pcall(function() Panel:Open() end)
check(ok, "the panel builds and opens", err)
check(Panel.pages ~= nil and #Panel.pages > 0, "the rail has pages",
	Panel.pages and #Panel.pages)

-- Both scroll frames take their size from anchors, which nothing here resolves,
-- so they are given the sizes the real window lands at. Without this the
-- viewport is 24px tall, every page scrolls almost its whole height, and no
-- check can see content that cannot be brought to the top of the view.
local VIEWPORT, RAIL_VIEWPORT = 560, 620
local PAGE_WIDTH = 704

Panel.contentScroll:SetHeight(VIEWPORT)
Panel.railScroll:SetHeight(RAIL_VIEWPORT)

-- The page measures its wrapped text against this. Without a width every
-- paragraph measures as one line however long it is, which is exactly the bug
-- that drew the changelog on top of itself.
Panel.page.content:SetWidth(PAGE_WIDTH)

--------------------------------------------------------------------------
section("Rendering every page")
--------------------------------------------------------------------------
local totalControls, byKind = 0, {}

for _, entry in ipairs(Panel.pages or {}) do
	local ok2, err2 = pcall(function() Panel:SelectPage(entry.key) end)
	check(ok2, "renders: " .. entry.name, err2)

	if ok2 then
		local controls = Panel.page:GetControls()
		totalControls = totalControls + #controls
		for _, c in ipairs(controls) do
			local kind = c.segmented and "segmented" or c.kind
			byKind[kind] = (byKind[kind] or 0) + 1
		end
		-- A page that draws nothing is a page somebody cannot configure.
		check(#controls > 0, "page is not empty: " .. entry.name, #controls)
	end
end

print()
print(string.format("  %d controls drawn across %d pages", totalControls, #Panel.pages))
local ordered = {}
for kind, n in pairs(byKind) do ordered[#ordered + 1] = { kind, n } end
table.sort(ordered, function(a, b) return a[2] > b[2] end)
for _, row in ipairs(ordered) do
	print(string.format("    %-12s %4d", row[1], row[2]))
end

-- Every option must bind, and the ones that cannot must name themselves.
--
-- Two do not, and both are artefacts of this harness rather than faults in the
-- panel. ActionBars.lua:889 wraps those getters in `math_min(getter(info), max)`,
-- and the stubbed database hands back a table where the game hands back a
-- number. They are listed rather than tolerated silently, so that a third one
-- appearing is a failure and not a shrug.
local KNOWN_STUB_FAILURES = {
	["Action Bars > stancebar > fadeFrom"] = true,
	["Action Bars > stancebar > numbuttons"] = true,
}

local unexpected, stubbed = {}, 0
for _, pageKey in ipairs(keys) do
	local pageOption = Config.GetSubOption(options, pageKey)
	if type(pageOption) == "table" and pageOption.type == "group" then
		for _, entry in ipairs(Renderer:Collect(pageOption, options, { pageKey })) do
			if entry.option then
				local label = table.concat(entry.path, " > ")
				local ok5 = pcall(Config.GetValue, entry.option, options, entry.path, Addon)
				if not ok5 then
					if KNOWN_STUB_FAILURES[label] then
						stubbed = stubbed + 1
					else
						unexpected[#unexpected + 1] = label
					end
				end
			end
		end
	end
end

check(#unexpected == 0, "every option binds, bar the known stub artefacts",
	table.concat(unexpected, ", "))
check(stubbed == 2, "both known stub artefacts are still the only ones", stubbed)

-- A binding that fails must degrade to a labelled row, never take the page down.
local labelled = 0
for _, entry in ipairs(Panel.pages or {}) do
	Panel:SelectPage(entry.key)
	for _, c in ipairs(Panel.page:GetControls()) do
		local text = c.label and c.label.GetText and c.label:GetText()
		if type(text) == "string" and text:find("(failed)", 1, true) then
			labelled = labelled + 1
		end
	end
end
check(labelled == stubbed, "a failed binding shows as a labelled row", labelled)

-- Export and Import is unusable without its boxes, and they were skipped until
-- there was a multiline control to draw them with.
do
	Panel:SelectPage("sharing")
	local multiline = 0
	for _, c in ipairs(Panel.page:GetControls()) do
		if c.multiline then multiline = multiline + 1 end
	end
	check(multiline > 0, "Export and Import draws its text boxes", multiline)
end

--------------------------------------------------------------------------
section("Page heading")
--------------------------------------------------------------------------
-- Every page has to name itself: which band it sits in, what it is called, and
-- what it is for. A page whose title is blank looks broken.
local blankTitles, blankCrumbs = {}, {}
for _, entry in ipairs(Panel.pages or {}) do
	Panel:SelectPage(entry.key)

	local title = Panel.pageTitle and Panel.pageTitle:GetText()
	local crumb = Panel.crumb and Panel.crumb:GetText()

	if type(title) ~= "string" or title == "" then blankTitles[#blankTitles + 1] = entry.key end
	if type(crumb) ~= "string" or crumb == "" then blankCrumbs[#blankCrumbs + 1] = entry.key end
end
check(#blankTitles == 0, "every page names itself", table.concat(blankTitles, ", "))
check(#blankCrumbs == 0, "every page names its section", table.concat(blankCrumbs, ", "))

check(Panel.count and Panel.count:GetText() ~= "", "the count is shown",
	Panel.count and Panel.count:GetText())

--------------------------------------------------------------------------
section("Defaults and modified marks")
--------------------------------------------------------------------------
local Defaults = Kit.Defaults
check(Defaults ~= nil, "Kit.Defaults exists")

-- What matters is whether a *setting* resolves, not whether its page does:
-- UnitFrames and ActionBars bind per sub-group, so their pages are deliberately
-- unbound while everything inside them is not.
local resolved, unresolved, byPage = 0, 0, {}

for _, entry in ipairs(Panel.pages or {}) do
	local pageOption = Config.GetSubOption(options, entry.key)
	local hit, miss = 0, 0

	for _, item in ipairs(Renderer:Collect(pageOption, options, { entry.key })) do
		if item.option and item.kind ~= "execute" then
			if Defaults.ModuleNameFor(options, item.path) then hit = hit + 1
			else miss = miss + 1 end
		end
	end

	resolved, unresolved = resolved + hit, unresolved + miss
	byPage[#byPage + 1] = { name = entry.name, key = entry.key, hit = hit, miss = miss }
end

local total = resolved + unresolved
print(string.format("  %d of %d settings resolve to a module (%.0f%%)",
	resolved, total, total > 0 and resolved / total * 100 or 0))
for _, row in ipairs(byPage) do
	if row.miss > 0 then
		print(string.format("    %-22s %d of %d unresolved", row.name, row.miss, row.hit + row.miss))
	end
end

-- The profile and sharing pages hold no module settings of their own, so their
-- settings are expected not to resolve. Every other page must.
local expectedUnbound = { profiles = true, sharing = true }
local surprises = {}
for _, row in ipairs(byPage) do
	if row.miss > 0 and not expectedUnbound[row.key] then
		surprises[#surprises + 1] = string.format("%s (%d)", row.name, row.miss)
	end
end
check(#surprises == 0, "every settings page resolves its settings to a module",
	table.concat(surprises, ", "))

-- A sub-group naming its own module must win over the page around it, which is
-- what UnitFrames and ActionBars need: one page, a module per section.
do
	local deep, shallow
	for _, entry in ipairs(Panel.pages or {}) do
		local group = Config.GetSubOption(options, entry.key)
		if type(group) == "table" then
			for _, childKey in ipairs(Config.SortedKeys(group, options, { entry.key }, Addon)) do
				local child = Config.GetSubOption(group, childKey)
				if type(child) == "table" and child.type == "group" then
					local outer = Defaults.ModuleNameFor(options, { entry.key })
					local inner = Defaults.ModuleNameFor(options, { entry.key, childKey })
					if inner and outer and inner ~= outer then deep = true end
					if inner and not outer then shallow = true end
				end
			end
		end
	end
	check(deep or shallow, "a sub-group can name a module of its own")
end

-- IsModified has to answer three ways, and "no idea" must not read as "no".
do
	local unknown = Defaults.IsModified(options, { "nope", "nothing" }, 1)
	check(unknown == nil, "an unknown default answers nil, not false", tostring(unknown))
	check(Defaults.Get(options, {}) == nil, "an empty path has no default")
end

-- Tables compare by content, since colours and positions are tables.
check(Defaults.Same({ 1, 2, 3 }, { 1, 2, 3 }), "identical tables compare equal")
check(not Defaults.Same({ 1, 2, 3 }, { 1, 2, 4 }), "differing tables compare unequal")
check(not Defaults.Same({ 1, 2 }, { 1, 2, 3 }), "a longer table is not equal")
check(Defaults.Same(5, 5) and not Defaults.Same(5, 6), "scalars compare directly")

-- Counting must not error on any real page.
for _, entry in ipairs(Panel.pages or {}) do
	local ok6 = pcall(Defaults.CountModified, options, { entry.key })
	check(ok6, "counting changes on " .. entry.name .. " does not error")
end

--------------------------------------------------------------------------
section("Live frame previews")
--------------------------------------------------------------------------
local Preview = Kit.Preview
check(Preview ~= nil, "Kit.Preview exists")
check(Kit.PreviewGlowBackdrop.edgeFile:find("border%-glow%.tga$") ~= nil,
	"the live preview uses the shipped glow art instead of the tooltip border",
	Kit.PreviewGlowBackdrop.edgeFile)
check(Kit.PreviewGlowLabelBackdrop.edgeFile:find("border%-glow%.tga$") ~= nil,
	"the preview label uses the same glow family",
	Kit.PreviewGlowLabelBackdrop.edgeFile)
check(Kit.PreviewGold[1] == ns.Colors.normal[1]
	and Kit.PreviewGold[2] == ns.Colors.normal[2]
	and Kit.PreviewGold[3] == ns.Colors.normal[3],
	"the preview glow keeps AzeriteUI gold independently of panel themes")

do
	local values = { enabled = false, size = 5, choice = "a", text = "old" }
	local mutations = 0
	local savedActionBars = S.modules.ActionBars
	local savedPlayerFrame = S.modules.PlayerFrame
	local savedActiveNamePlates = ns.ActiveNamePlates
	local target = CreateFrame("Frame", nil, UIParent)
	target:SetSize(180, 42)

	-- The preview may inspect the target and anchor its own sibling to it. It
	-- must not change the target itself, especially when it is protected in game.
	for _, method in ipairs({ "Show", "Hide", "SetShown", "SetAlpha", "SetScale",
		"SetSize", "SetWidth", "SetHeight", "SetParent", "SetPoint", "ClearAllPoints" }) do
		target[method] = function() mutations = mutations + 1 end
	end

	S.modules.PreviewOuter = {
		GetProfileDefaults = function()
			return { enabled = false, size = 5, choice = "a", text = "old" }
		end
	}
	S.modules.PreviewInner = {
		frame = target,
		GetProfileDefaults = function()
			return { enabled = false, size = 5, choice = "a", text = "old" }
		end
	}

	local nested = {
		name = "Nested preview", type = "group", order = 1,
		args = {
			enabled = {
				name = "Preview Toggle", type = "toggle", order = 1,
				get = function(info) return values[info[#info]] end,
				set = function(info, value) values[info[#info]] = value end
			},
			size = {
				name = "Preview Range", type = "range", order = 2,
				min = 1, max = 10, step = 1,
				get = function(info) return values[info[#info]] end,
				set = function(info, value) values[info[#info]] = value end
			},
			choice = {
				name = "Preview Select", type = "select", order = 3,
				values = { a = "A", b = "B" },
				get = function(info) return values[info[#info]] end,
				set = function(info, value) values[info[#info]] = value end
			},
			text = {
				name = "Preview Input", type = "input", order = 4,
				get = function(info) return values[info[#info]] end,
				set = function(info, value) values[info[#info]] = value end
			},
			action = {
				name = "Preview Action", type = "execute", order = 5,
				func = function() end
			}
		}
	}
	local previewGroup = {
		name = "Preview page", type = "group", order = 1,
		args = { nested = nested }
	}
	local previewOptions = {
		type = "group",
		args = { preview = previewGroup }
	}

	Defaults.Bind(previewGroup, "PreviewOuter")
	Defaults.Bind(nested, "PreviewInner")

	local content = CreateFrame("Frame", nil, UIParent)
	content:SetWidth(600)
	local previewPage = Renderer:CreatePage(content)
	previewPage:Show(previewOptions, { "preview" })

	local FindControl = function(label)
		for _, control in ipairs(previewPage:GetControls()) do
			if control.labelText == label then return control end
		end
	end

	local toggle, action = FindControl("Preview Toggle"), FindControl("Preview Action")

	check(toggle ~= nil, "the preview test toggle is rendered")
	check(action ~= nil, "the preview test action is rendered")

	if toggle then
		toggle:Fire(true)
		local request = Preview:GetLastRequest()
		check(request and request.moduleName == "PreviewInner",
			"a changed nested setting previews its deepest bound module",
			request and request.moduleName)
		check(request and request.target == target,
			"the owning module's real frame is the preview target")
		check(request and request.label == "Preview Toggle",
			"the preview names the changed setting", request and request.label)
		check(request and request.style == "golden-glow",
			"the preview records the golden glow treatment", request and request.style)
		check(mutations == 0, "the preview never mutates the target frame", mutations)

		local beforeRevert = request and request.id or 0
		if toggle.onRevert then toggle.onRevert(toggle) end
		local reverted = Preview:GetLastRequest()
		check(reverted and reverted.id > beforeRevert,
			"reverting one setting requests a new preview")
	end

	for _, change in ipairs({
		{ label = "Preview Range", value = 7 },
		{ label = "Preview Select", value = "b" },
		{ label = "Preview Input", value = "new" }
	}) do
		local control = FindControl(change.label)
		local before = Preview:GetLastRequest()
		before = before and before.id or 0
		if control then control:Fire(change.value) end
		local request = Preview:GetLastRequest()
		check(control and request and request.id > before and request.label == change.label,
			change.label .. " requests the owning frame preview",
			request and request.label)
	end

	local beforeAction = Preview:GetLastRequest()
	beforeAction = beforeAction and beforeAction.id or 0
	action = FindControl("Preview Action")
	if action then action:Fire(true) end
	local afterAction = Preview:GetLastRequest()
	check((afterAction and afterAction.id or 0) == beforeAction,
		"an execute action does not request a frame preview")

	S.modules.NoFramePreview = {
		GetProfileDefaults = function() return { enabled = false } end
	}
	local noFrameGroup = {
		name = "No frame", type = "group", order = 1,
		args = {
			enabled = {
				name = "No Frame Toggle", type = "toggle", order = 1,
				get = function() return false end,
				set = function() end
			}
		}
	}
	local noFrameOptions = { type = "group", args = { noframe = noFrameGroup } }
	Defaults.Bind(noFrameGroup, "NoFramePreview")
	previewPage:Show(noFrameOptions, { "noframe" })
	local noFrameToggle = previewPage:GetControls()[1]
	if noFrameToggle then noFrameToggle:Fire(true) end
	local noFrameRequest = Preview:GetLastRequest()
	check(noFrameRequest and noFrameRequest.moduleName == "NoFramePreview"
		and noFrameRequest.target == nil,
		"a bound setting without a live object records an honest no-frame result")
	check(Panel.previewText and Panel.previewText:GetText():find("No visible frame", 1, true),
		"the panel explains when no live frame can be outlined",
		Panel.previewText and Panel.previewText:GetText())

	local beforeUnbound = noFrameRequest and noFrameRequest.id or 0
	local unboundGroup = {
		name = "Unbound", type = "group", order = 1,
		args = {
			enabled = {
				name = "Unbound Toggle", type = "toggle", order = 1,
				get = function() return false end,
				set = function() end
			}
		}
	}
	local unboundOptions = { type = "group", args = { unbound = unboundGroup } }
	previewPage:Show(unboundOptions, { "unbound" })
	previewPage:GetControls()[1]:Fire(true)
	check((Preview:GetLastRequest() and Preview:GetLastRequest().id or 0) == beforeUnbound,
		"an unbound profile or panel setting requests no preview")

	local thirdBar = CreateFrame("Frame", nil, UIParent)
	thirdBar:SetSize(300, 36)
	S.modules.ActionBars = { bars = { [3] = thirdBar } }
	check(Preview:ResolveModuleTarget("ActionBars", { "actionbars", "bar3", "enabled" }) == thirdBar,
		"Action Bar 3 settings resolve to Action Bar 3")

	local player = CreateFrame("Frame", nil, UIParent)
	player:SetSize(240, 70)
	S.modules.PlayerFrame = { frame = player }
	check(Preview:ResolveModuleTarget("UnitFrames", { "healthprediction", "enabled" }) == player,
		"shared Unit Frames settings resolve to the player frame")
	check(Preview:ResolveModuleTarget("ExplorerMode", { "explorer", "fadePlayerFrame" }) == player,
		"Explorer Mode resolves an element setting to that element's frame")

	local livePlate = CreateFrame("Frame", nil, UIParent)
	livePlate:SetSize(120, 24)
	livePlate.isTarget = true
	ns.ActiveNamePlates = { [livePlate] = true }
	check(Preview:ResolveModuleTarget("NamePlates", { "nameplates", "scale" }) == livePlate,
		"nameplate settings resolve to the addon-owned live target plate")

	-- The rest of this harness still drives the addon's real option tables.
	S.modules.ActionBars = savedActionBars
	S.modules.PlayerFrame = savedPlayerFrame
	ns.ActiveNamePlates = savedActiveNamePlates
end

--------------------------------------------------------------------------
section("Search")
--------------------------------------------------------------------------
for _, term in ipairs({ "player", "scale", "aura", "font", "minimap", "zzzznothing" }) do
	local ok3, err3 = pcall(function() Panel:ShowResults(term) end)
	check(ok3, "search '" .. term .. "'", err3)
end
check(pcall(function() Panel:ClearSearch() end), "clearing search restores the rail")

--------------------------------------------------------------------------
section("Section navigation")
--------------------------------------------------------------------------
-- A page of a hundred and fifty rows needs a way in. Flattening its sub-groups
-- was right, but it left nothing to navigate by until the rail listed them.
do
	local widest, widestName, widestSections = 0, nil, 0
	for _, entry in ipairs(Panel.pages or {}) do
		Panel:SelectPage(entry.key)
		local n = #Panel.page:GetControls()
		local sections = Panel.page:GetSections()
		if n > widest then
			widest, widestName, widestSections = n, entry.name, #sections
		end
	end
	print(string.format("  longest page: %s, %d rows in %d sections",
		widestName, widest, widestSections))

	check(widestSections > 1, "the longest page is divided into sections", widestSections)

	-- Offsets must climb, or a jump would land above where it came from.
	Panel:SelectPage("Unit Frames")
	local sections = Panel.page:GetSections()
	local climbing, last = true, -1
	for _, sec in ipairs(sections) do
		if sec.offset <= last then climbing = false end
		last = sec.offset
		if type(sec.label) ~= "string" or sec.label == "" then climbing = false end
	end
	check(climbing, "each section starts below the one before it")
	check(#(Panel.sectionRows or {}) > 0, "the rail lists them",
		#(Panel.sectionRows or {}))

	-- Frame positions cannot be read back outside the game, so the rail writes
	-- its layout down. Nothing may sit on top of anything else: the first cut of
	-- this drew each page's sections over the page row itself and left a gap the
	-- height of a row at the end, and every check still passed.
	local overlaps, gaps = {}, {}
	local previous
	for _, item in ipairs(Panel.railLayout or {}) do
		if previous then
			local bottom = previous.offset + previous.height
			if item.offset < bottom then
				overlaps[#overlaps + 1] = string.format("%s over %s", item.label, previous.label)
			elseif item.offset > bottom then
				gaps[#gaps + 1] = string.format("%s after %s (%d)",
					item.label, previous.label, item.offset - bottom)
			end
		end
		previous = item
	end

	check(#overlaps == 0, "nothing in the rail is drawn on top of anything else",
		table.concat(overlaps, ", "))
	check(#gaps == 0, "the rail has no holes in it", table.concat(gaps, ", "))

	-- And the scroll child has to be tall enough to hold all of it.
	if previous then
		check((Panel.railHeight or 0) >= previous.offset + previous.height,
			"the rail is tall enough for its contents",
			string.format("%d for %d", Panel.railHeight or 0, previous.offset + previous.height))
	end

	-- Sections are navigation, not headings: they keep the case they were
	-- written in rather than the shouting the page draws them with.
	local shouted = {}
	for _, item in ipairs(Panel.railLayout or {}) do
		if item.kind == "section" and item.label == item.label:upper()
			and item.label:lower() ~= item.label then
			shouted[#shouted + 1] = item.label
		end
	end
	check(#shouted == 0, "section names keep the case they were written in",
		table.concat(shouted, ", "))
end

--------------------------------------------------------------------------
section("Which section is showing")
--------------------------------------------------------------------------
-- Listing the sections is only half of it. Without a mark you can see where you
-- could go but not where you are.
do
	Panel:SelectPage("Action Bars")

	local sections = Panel.page:GetSections()
	local rows = Panel.sectionRows or {}
	check(#sections > 2, "the test page has sections to move between", #sections)

	local function activeLabel()
		for i = 1, #rows do
			if rows[i]:IsShown() and rows[i].active then return rows[i].label end
		end
	end

	-- At the top you are in the first section, not in none of them.
	Panel.contentScroll:SetVerticalScroll(0)
	Panel:UpdateActiveSection()
	local first = activeLabel()
	check(first ~= nil, "a page at the top is in its first section", tostring(first))

	-- Scrolling past each heading moves the mark, and never backwards.
	local seen = {}
	local wrong = {}
	for i, sec in ipairs(sections) do
		Panel.contentScroll:SetVerticalScroll(sec.offset + 1)

		local label = activeLabel()
		seen[#seen + 1] = label

		if label ~= sec.label then
			wrong[#wrong + 1] = string.format("at %s expected %s, got %s",
				sec.offset, tostring(sec.label), tostring(label))
		end
	end

	check(#wrong == 0, "scrolling to a heading marks that section",
		table.concat(wrong, " | "))

	-- Exactly one may be marked at a time.
	Panel.contentScroll:SetVerticalScroll(sections[2] and sections[2].offset + 1 or 40)
	local marked = 0
	for i = 1, #rows do
		if rows[i]:IsShown() and rows[i].active then marked = marked + 1 end
	end
	check(marked == 1, "exactly one section is marked", marked)

	-- The rail is on the far left, so the crumb says it again above the page.
	local crumbs, base = {}, nil
	Panel.contentScroll:SetVerticalScroll(0)
	base = Panel.crumbBase
	check(type(base) == "string" and base ~= "", "the page knows its own crumb", tostring(base))

	for _, sec in ipairs(sections) do
		Panel.contentScroll:SetVerticalScroll(sec.offset + 1)
		local want = base .. " > " .. sec.label
		if Panel.crumb:GetText() ~= want then
			crumbs[#crumbs + 1] = string.format("at %s wanted %q, got %q",
				sec.offset, want, tostring(Panel.crumb:GetText()))
		end
	end
	check(#crumbs == 0, "the crumb names the section being read",
		table.concat(crumbs, " | "))

	-- A mark you cannot see is not a mark. The rail scrolls to keep it in view.
	-- Squeezed to a height the rail cannot fit in, so there is something to
	-- scroll: on a tall window the whole list is visible and this proves nothing.
	local offscreen = {}
	local railHeight = 240
	Panel.railScroll:SetHeight(railHeight)

	for _, sec in ipairs(sections) do
		Panel.contentScroll:SetVerticalScroll(sec.offset + 1)

		local row
		for i = 1, #rows do
			if rows[i]:IsShown() and rows[i].active then row = rows[i] end
		end

		if row then
			local at = Panel.railScroll:GetVerticalScroll()
			local top, bottom = row.railOffset, row.railOffset + 19
			if top < at or bottom > at + railHeight then
				offscreen[#offscreen + 1] = string.format("%s at %d, rail at %d",
					row.label, top, at)
			end
		end
	end
	check(#offscreen == 0, "the rail scrolls the marked section into view",
		table.concat(offscreen, " | "))

	-- Searching replaces the page, so no section is the one being read.
	Panel:ShowResults("scale")
	Panel:UpdateActiveSection()
	local duringSearch = 0
	for i = 1, #rows do
		if rows[i]:IsShown() and rows[i].active then duringSearch = duringSearch + 1 end
	end
	check(duringSearch == 0, "no section is marked while searching", duringSearch)
	check(Panel.crumb:GetText() ~= base, "the crumb stops naming a section while searching",
		tostring(Panel.crumb:GetText()))
	Panel:ClearSearch()
	Panel.railScroll:SetHeight(RAIL_VIEWPORT)
end

--------------------------------------------------------------------------
section("The sections at the end of a page")
--------------------------------------------------------------------------
-- Reported from the game: clicking Arena Enemy Frames, Cast Bar or Class Power
-- under Unit Frame Settings leaves the mark on Boss Frames. They are the last
-- sections on the page and a scroll frame stops at the end of its content, so
-- their headings can never reach the top of the view. You are looking straight
-- at Arena Enemy Frames and the rail says Boss Frames.
--
-- The page is right to stop where it does. The rule for the mark is what is
-- wrong: "the last heading past the top" has nothing to say about the sections
-- stranded below the last scroll position.
--
-- This is about the click doing what it says, so it clicks: the rail row's own
-- OnClick, not SetVerticalScroll.
do
	local unmarked, offscreen, tails = {}, {}, 0

	for _, entry in ipairs(Panel.pages) do
		Panel:SelectPage(entry.key)

		local rows = Panel.sectionRows or {}
		local sections = Panel.page:GetSections()
		local range = Panel.contentScroll:GetVerticalScrollRange()

		for i, sec in ipairs(sections) do
			local row = rows[i]
			if row and row:IsShown() then
				if sec.offset > range then tails = tails + 1 end

				row:GetScript("OnClick")(row)

				local marked
				for j = 1, #rows do
					if rows[j]:IsShown() and rows[j].active then marked = rows[j].label end
				end
				if marked ~= sec.label then
					unmarked[#unmarked + 1] = string.format("%s / clicked %s, marked %s",
						entry.key, sec.label, tostring(marked))
				end

				-- Marking something you cannot see would be a worse lie than
				-- marking the wrong one, so the heading has to be on screen.
				local at = Panel.contentScroll:GetVerticalScroll()
				local top = sec.offset - at
				if top < 0 or top >= VIEWPORT then
					offscreen[#offscreen + 1] = string.format("%s / %s sits %d into a %d view",
						entry.key, sec.label, top, VIEWPORT)
				end
			end
		end
	end

	print(string.format("  %d section headings cannot be brought to the top of their page", tails))
	check(tails > 0, "some sections really are past the last scroll position", tails)
	check(#unmarked == 0, "clicking a section marks the section you clicked",
		table.concat(unmarked, " | "))
	check(#offscreen == 0, "and the section it marks is on screen",
		table.concat(offscreen, " | "))

	-- The mark is pinned only while the page is stuck at its end. Scroll back up
	-- and the ordinary rule takes over again, or the rail would be stale.
	Panel:SelectPage("Unit Frames")
	local rows, sections = Panel.sectionRows, Panel.page:GetSections()
	local last = #sections
	rows[last]:GetScript("OnClick")(rows[last])
	check(rows[last].active == true, "the last section can be marked at all")

	Panel.contentScroll:SetVerticalScroll(sections[1].offset)
	check(rows[1].active == true and rows[last].active ~= true,
		"scrolling back up hands the mark over again",
		tostring(rows[1].active) .. "/" .. tostring(rows[last].active))

	-- Away from the end, a section that can be scrolled to the top needs no
	-- pin and must not keep one: the reader has moved and the rail follows.
	local reachable
	local range = Panel.contentScroll:GetVerticalScrollRange()
	for i, sec in ipairs(sections) do
		if sec.offset > 0 and sec.offset < range - VIEWPORT then reachable = i end
	end
	check(reachable ~= nil, "the page has a section in its middle", tostring(reachable))

	if reachable then
		rows[reachable]:GetScript("OnClick")(rows[reachable])
		check(rows[reachable].active == true, "clicking a reachable section marks it")

		-- Back up by less than a view, so its heading is still on screen below.
		Panel.contentScroll:SetVerticalScroll(sections[reachable].offset - 40)
		check(rows[reachable].active ~= true,
			"and scrolling up out of it hands the mark back",
			tostring(rows[reachable].active))
	end

	-- A page too short to scroll is the same problem with no scrolling at all:
	-- every section is on screen, no heading will ever pass the top, and the
	-- ordinary rule can only ever answer "the first one". A window tall enough
	-- to hold a whole page reaches that state - so does a short page in a normal
	-- window, which is why it is worth checking.
	Panel.contentScroll:SetHeight(20000)

	local shortPages = {}
	for _, entry in ipairs(Panel.pages) do
		Panel:SelectPage(entry.key)
		if Panel.contentScroll:GetVerticalScrollRange() <= 0 and #Panel.page:GetSections() > 1 then
			shortPages[#shortPages + 1] = entry.key
		end
	end

	check(#shortPages >= 2, "there are pages that do not scroll at all", #shortPages)

	local shortPage = shortPages[1]
	if shortPage and shortPages[2] then
		local r = Panel.sectionRows

		-- Leave a live mark on one page, then walk to another. Nothing about the
		-- second page's scroll position can dislodge a pin - it does not scroll -
		-- so if changing page does not clear it, the new page opens on the wrong
		-- section. This is the only place that shows it.
		Panel:SelectPage(shortPage)
		r[2]:GetScript("OnClick")(r[2])
		check(r[2].active == true, "a section is marked before leaving the page")

		Panel:SelectPage(shortPages[2])
		check(r[1].active == true and r[2].active ~= true,
			"a page you have just opened marks its own first section",
			tostring(r[1].active) .. "/" .. tostring(r[2].active))

		Panel:SelectPage(shortPage)
		r[2]:GetScript("OnClick")(r[2])
		check(r[2].active == true,
			"a section on a page that does not scroll can still be marked",
			shortPage .. ": " .. tostring(r[1].active) .. "/" .. tostring(r[2].active))

		r[1]:GetScript("OnClick")(r[1])
		check(r[1].active == true and r[2].active ~= true,
			"and the mark moves back when another is asked for",
			tostring(r[1].active) .. "/" .. tostring(r[2].active))
	end

	Panel.contentScroll:SetHeight(VIEWPORT)
end

--------------------------------------------------------------------------
section("The rail drawer closes")
--------------------------------------------------------------------------
-- Maintainer: clicking the category you already have open should close its
-- drawer. Opening a different one is not the only way to shut the first.
do
	local function shownSections()
		local n = 0
		for _, row in ipairs(Panel.sectionRows or {}) do
			if row:IsShown() then n = n + 1 end
		end
		return n
	end

	local function pageRow(key)
		for _, row in ipairs(Panel.railRows or {}) do
			if row:IsShown() and row.key == key then return row end
		end
	end

	Panel:SelectPage("Unit Frames")
	local open = shownSections()
	check(open > 2, "the open page shows its sections", open)

	local row = pageRow("Unit Frames")
	check(row ~= nil, "the open page has a row in the rail")

	row:GetScript("OnClick")(row)
	check(shownSections() == 0, "clicking it again closes the drawer", shownSections())
	check(Panel.selected == "Unit Frames", "and leaves you on the page", tostring(Panel.selected))

	-- The rail has to shrink with it, or the list ends in a hole.
	local collapsedHeight = Panel.railHeight
	row:GetScript("OnClick")(row)
	check(shownSections() == open, "clicking once more opens it again", shownSections())
	check(Panel.railHeight > collapsedHeight, "the rail is shorter while it is closed",
		string.format("%d closed, %d open", collapsedHeight, Panel.railHeight))

	-- And moving to another page opens that one's drawer rather than staying shut.
	row:GetScript("OnClick")(row)
	Panel:SelectPage("Action Bars")
	check(shownSections() > 2, "a different page opens its own drawer", shownSections())

	local previous = Panel.railLayout
	check(previous ~= nil, "the rail still records its layout")
end

--------------------------------------------------------------------------
section("Search on the page")
--------------------------------------------------------------------------
-- Results belong where there is room for them, and the rail must survive.
do
	Panel:ShowResults("scale")
	check(Panel.searching == true, "searching takes over the page")
	check(#Panel.page:GetControls() == 0, "the page's own rows stand down",
		#Panel.page:GetControls())

	check(Panel.pageTitle:GetText() ~= "", "the heading says what is being searched")

	-- The rail still offers every page while a search is up.
	local railShown = 0
	for _, entry in ipairs(Panel.pages or {}) do railShown = railShown + 1 end
	check(railShown > 0, "the rail still lists the pages", railShown)

	-- And leaving a result returns to a real page.
	Panel:ClearSearch()
	check(Panel.searching ~= true, "clearing the search hands the page back")
	check(#Panel.page:GetControls() > 0, "the page draws its rows again",
		#Panel.page:GetControls())
end

--------------------------------------------------------------------------
section("The Settings tab")
--------------------------------------------------------------------------
-- The window's own settings, and the changelog, on a tab of their own at the
-- bottom of the rail. They are not settings for the interface, and the theme
-- picker filed under Profiles was the proof that putting them there confuses
-- everyone including the code.
do
	check(#(Panel.tabs or {}) == 2, "there are two tabs", #(Panel.tabs or {}))

	local labels = {}
	for _, button in ipairs(Panel.tabs or {}) do
		labels[#labels + 1] = button.text:GetText()
	end
	check(table.concat(labels, "/") == "Options/Settings", "and they are named",
		table.concat(labels, "/"))

	-- Where we were on the Options tab, to come back to.
	Panel:SelectPage("Unit Frames")
	local wasOn = Panel.selected

	local selectedTabs = 0
	for _, button in ipairs(Panel.tabs) do
		if button.selected then selectedTabs = selectedTabs + 1 end
	end
	check(selectedTabs == 1, "exactly one tab is selected", selectedTabs)

	----------------------------------------------------------------
	-- Over to Settings
	----------------------------------------------------------------
	local settingsTab = Panel.tabs[2]
	settingsTab:GetScript("OnClick")(settingsTab)

	check(Panel.tab == "settings", "clicking the tab switches to it", Panel.tab)
	check(settingsTab.selected == true, "and the tab shows as selected")
	check(Panel.tabs[1].selected ~= true, "and the other one does not")

	local keys = {}
	for _, entry in ipairs(Panel.pages or {}) do keys[#keys + 1] = entry.key end
	check(table.concat(keys, ",") == "appearance,changelog",
		"the rail lists the window's own pages", table.concat(keys, ","))

	-- The window's own settings are not the addon's, so the bands say so.
	local bands = {}
	for _, item in ipairs(Panel.railLayout or {}) do
		if item.kind == "band" then bands[#bands + 1] = item.label end
	end
	check(table.concat(bands, "/") == "Options Panel/About",
		"under bands of its own", table.concat(bands, "/"))

	-- The gems mean "differs from the module default", and these have no module.
	-- Counting reads every setting on a page, so it should not even be asked.
	local gems = 0
	for _, row in ipairs(Panel.railRows or {}) do
		if row:IsShown() and row.dot:IsShown() then gems = gems + 1 end
	end
	check(gems == 0, "nothing on this tab carries a changed gem", gems)

	local counted = 0
	local realCount = Kit.Defaults.CountModified
	Kit.Defaults.CountModified = function(...) counted = counted + 1 return realCount(...) end

	Panel.changedByPage = {}
	Panel:BuildRail()
	check(counted == 0, "and nothing is counted to find that out", counted)

	Kit.Defaults.CountModified = realCount

	----------------------------------------------------------------
	-- Appearance
	----------------------------------------------------------------
	Panel:SelectPage("appearance")

	local kinds = {}
	for _, control in ipairs(Panel.page:GetControls()) do
		kinds[control.kind] = (kinds[control.kind] or 0) + 1
	end
	check((kinds.select or 0) >= 1, "the theme picker is drawn", kinds.select)
	check((kinds.range or 0) >= 1, "the opacity slider is drawn", kinds.range)
	check((kinds.execute or 0) >= 1, "the reset button is drawn", kinds.execute)

	-- Picking a theme has to repaint this window. It used to call
	-- Window:SetTheme, which repainted the old one and left this one alone.
	check(type(Panel.SetTheme) == "function", "the panel can set its own theme")

	local before = Kit.GetTheme()
	local painted = 0
	local realApply = Panel.ApplyTheme
	Panel.ApplyTheme = function(self, ...) painted = painted + 1 return realApply(self, ...) end

	Panel:SetTheme(before == "dark" and "light" or "dark")
	check(painted > 0, "and setting it repaints the window", painted)
	check(Kit.GetTheme() ~= before, "and the theme actually changed", Kit.GetTheme())

	Panel.ApplyTheme = realApply
	Panel:SetTheme(before)

	----------------------------------------------------------------
	-- Changelog
	----------------------------------------------------------------
	Panel:SelectPage("changelog")

	local versions = Panel.page:GetSections()
	check(#versions >= 5, "the changelog lists its releases in the rail", #versions)
	check(versions[1] and versions[1].label:match("^%d+%.%d+"),
		"and the newest release is first",
		versions[1] and versions[1].label or "none")

	-- A paragraph keeps its words on control.text; only a row with a label has a
	-- control.label. Reading the wrong one said every note was blank.
	local notes, empty = 0, 0
	for _, control in ipairs(Panel.page:GetControls()) do
		if control.kind == "description" then
			notes = notes + 1
			local text = control.text and control.text:GetText() or ""
			if text == "" then empty = empty + 1 end
		end
	end
	print(string.format("  %d releases, %d notes", #versions, notes))
	check(notes >= 20, "the notes themselves are on the page", notes)
	check(empty == 0, "and none of them are blank", empty)

	-- Markdown marks would show up as literal asterisks and backticks.
	local marked = {}
	for _, release in ipairs(ns.Changelog or {}) do
		for _, group in ipairs(release.groups or {}) do
			for _, text in ipairs(group.items or {}) do
				if text:match("%*") or text:match("`") then
					marked[#marked + 1] = text:sub(1, 40)
				end
			end
		end
	end
	check(#marked == 0, "no markdown survives into the game",
		table.concat(marked, " | "))

	----------------------------------------------------------------
	-- The generator, on input the real file does not happen to contain
	----------------------------------------------------------------
	-- The 12 releases that ship use ** and backticks but no single-* italics,
	-- so the rule that strips those had nothing to prove itself against. This
	-- feeds the generator a release that uses every mark at once.
	do
		local fixture = SP .. "/changelog_fixture.md"
		local built = SP .. "/changelog_built.lua"

		local f = io.open(fixture, "w")
		f:write([[
# Changelog

## 9.9.9-Test (2026-01-02) - A **Bold** Title

### Fixed

- **Bold lead.** Body with *italics*, a `code span` and a [link](http://example.com),
  continued on a second line.
- A plain note.

### Internal

- Another one.
]])
		f:close()

		local saved = arg
		arg = { "--source", fixture, "--target", built, "--releases", "5" }

		local chunk = loadfile(root .. "/Tools/BuildChangelog.lua")
		check(chunk ~= nil, "the changelog generator loads")

		if chunk then
			local quiet = print
			print = function() end
			local built_ok = pcall(chunk)
			print = quiet
			arg = saved

			check(built_ok, "and runs over a fixture")

			local data = { }
			local loaded = loadfile(built)
			check(loaded ~= nil, "and writes loadable Lua")

			if loaded then
				loaded("Test", data)

				local release = data.Changelog and data.Changelog[1]
				check(release ~= nil, "the fixture release is read back")
				check(release and release.version == "9.9.9-Test", "with its version",
					release and release.version)
				check(release and release.title == "A Bold Title",
					"and a title with no marks left in", release and release.title)

				local all = {}
				for _, group in ipairs(release and release.groups or {}) do
					for _, text in ipairs(group.items) do all[#all + 1] = text end
				end
				check(#all == 3, "every note is kept", #all)

				local joined = table.concat(all, " ")
				check(not joined:match("%*"), "no asterisk survives", joined:match("%*[^%s]*"))
				check(not joined:match("`"), "no backtick survives")
				check(not joined:match("%["), "no link brackets survive")
				check(joined:match("italics"), "the words inside the marks are kept")
				check(joined:match("continued on a second line"),
					"and a note that wraps is joined up")
			end
		end
	end

	----------------------------------------------------------------
	-- Back again
	----------------------------------------------------------------
	local optionsTab = Panel.tabs[1]
	optionsTab:GetScript("OnClick")(optionsTab)

	check(Panel.tab == "options", "clicking the other tab goes back", Panel.tab)
	check(Panel.selected == wasOn, "and lands on the page you left",
		tostring(Panel.selected) .. " wanted " .. tostring(wasOn))

	local backKeys = 0
	for _, entry in ipairs(Panel.pages or {}) do backKeys = backKeys + 1 end
	check(backKeys > 10, "and the rail lists the addon's pages again", backKeys)

	-- The window's own settings must not also be on a page of the addon's.
	Panel:SelectPage("profiles")
	local strays = {}
	for _, control in ipairs(Panel.page:GetControls()) do
		local text = (control.label and control.label:GetText())
			or (control.text and control.text:GetText()) or ""
		if text == "Theme" or text == "Background Opacity" or text == "OPTIONS PANEL" then
			strays[#strays + 1] = text
		end
	end
	check(#strays == 0, "the theme and opacity have left the profile page",
		table.concat(strays, ", "))

	Panel:SelectPage(wasOn)
end

--------------------------------------------------------------------------
section("Text that does not fit")
--------------------------------------------------------------------------
-- Reported from the game: a help line clipped to one line ending in an
-- ellipsis, and the changelog drawing its releases on top of one another. Both
-- are the same thing - a row asked how tall it is before anything knows how
-- wide it is - so both are checked the same way: every row has to be at least
-- as tall as the text inside it.
do
	local short, tall = {}, 0

	-- Both tabs. The changelog is where this went most wrong, and it is not on
	-- the tab the panel opens on - selecting one of its pages from the Options
	-- tab silently renders nothing, which is how an earlier draft of this check
	-- passed on an empty page.
	for _, tab in ipairs({ "options", "settings" }) do
		Panel:SetTab(tab)
		check(Panel.tab == tab, "the " .. tab .. " tab is up to be walked", Panel.tab)

		for _, entry in ipairs(Panel.pages) do
			Panel:SelectPage(entry.key)
			check(#Panel.page:GetControls() > 0, tab .. "/" .. entry.key .. " draws something",
				#Panel.page:GetControls())

			for _, item in ipairs(Panel.page.layout or {}) do
				if item.textHeight and item.textHeight > 0 then
					if item.textHeight > 13 then tall = tall + 1 end
					if item.height < item.textHeight then
						short[#short + 1] = string.format("%s / %s: %dpx row, %dpx of text",
							entry.key, tostring(item.label):sub(1, 30), item.height, item.textHeight)
					end
				end
			end
		end
	end

	print(string.format("  %d rows carry more than one line of text", tall))
	check(tall > 20, "there really is text that has to wrap", tall)
	check(#short == 0, "no row is shorter than the text inside it",
		table.concat(short, " | "))

	-- Rows are placed one after another, so a row that is too short does not
	-- overlap the next by itself - the text spills over it. This catches the
	-- placement going wrong as well.
	Panel:SetTab("settings")
	Panel:SelectPage("changelog")
	check(#Panel.page:GetControls() > 40, "the changelog page is a long one",
		#Panel.page:GetControls())

	local overlaps, previous = {}, nil
	for _, item in ipairs(Panel.page.layout or {}) do
		if previous and item.offset < previous.offset + previous.height then
			overlaps[#overlaps + 1] = string.format("%s over %s",
				tostring(item.label):sub(1, 24), tostring(previous.label):sub(1, 24))
		end
		previous = item
	end
	check(#overlaps == 0, "the changelog does not draw on top of itself",
		table.concat(overlaps, " | "))

	----------------------------------------------------------------
	-- A narrower window re-wraps
	----------------------------------------------------------------
	local wide = Panel.page.content:GetHeight()
	check(wide > 200, "the changelog has a real height to compare", wide)

	-- Through the resize handler, not by calling Layout directly. Nothing used
	-- to re-lay the page out when the window changed width, and a test that
	-- calls Layout itself cannot see that.
	local resized = Panel.contentScroll:GetScript("OnSizeChanged")
	check(resized ~= nil, "the page reacts to its scroll frame changing size")

	Panel.contentScroll:SetWidth(360)
	resized(Panel.contentScroll, 360)
	local narrow = Panel.page.content:GetHeight()

	check(narrow > wide, "a narrower page is a taller one",
		string.format("%d wide, %d narrow", wide, narrow))

	Panel.contentScroll:SetWidth(PAGE_WIDTH)
	resized(Panel.contentScroll, PAGE_WIDTH)
	check(Panel.page.content:GetHeight() == wide, "and widening it back gives the height back",
		string.format("%d, was %d", Panel.page.content:GetHeight(), wide))

	----------------------------------------------------------------
	-- The help line
	----------------------------------------------------------------
	Panel:SetTab("options")
	Panel:SelectPage("Unit Frames")

	local shortest, longest
	for _, control in ipairs(Panel.page:GetControls()) do
		if control.helpText then
			if not longest or #control.helpText > #longest.helpText then longest = control end
			if not shortest or #control.helpText < #shortest.helpText then shortest = control end
		end
	end

	check(longest ~= nil and shortest ~= nil, "the page has help lines of both lengths")

	if longest and shortest and #longest.helpText > #shortest.helpText * 2 then
		check(longest:GetHeight() > shortest:GetHeight(),
			"a long help line makes its row taller",
			string.format("%d vs %d", longest:GetHeight(), shortest:GetHeight()))
	end

	check(longest and longest.help:GetText() == longest.helpText,
		"the row is given the whole help text, not a trimmed one")

	-- Giving the row the whole string is not enough on its own: a FontString
	-- with word wrap off clips it to one line and ends in an ellipsis, which is
	-- what was reported. These read back what SetWordWrap and SetMaxLines were
	-- called with.
	check(longest and longest.help.wraps == true, "and the help line wraps rather than clipping",
		tostring(longest and longest.help.wraps))
	check(longest and longest.help.maxLines == 2, "to at most two lines",
		tostring(longest and longest.help.maxLines))

	-- However tall the row, the tooltip carries all of it.
	check(longest and longest.textArea ~= nil, "the text column takes the mouse")
	check(longest and longest.textArea:GetScript("OnEnter") ~= nil,
		"and has something to show on hover")

	local shown = {}
	GameTooltip.AddLine = function(self, text) shown[#shown + 1] = text end
	longest.textArea:GetScript("OnEnter")(longest.textArea)

	check(#shown == 2, "the tooltip carries the label and the help", #shown)
	check(shown[2] == longest.helpText, "and the help in full, however much fits on the row")
end

--------------------------------------------------------------------------
section("Opacity, theme and scale")
--------------------------------------------------------------------------
do
	----------------------------------------------------------------
	-- Changing the theme after the opacity
	----------------------------------------------------------------
	-- Reported from the game: change the opacity, then the theme, and the
	-- background keeps the colour it had until the opacity is nudged again.
	Kit.SetOpacity(0.5)
	Panel:SetTheme("azerite")
	local azerite = { Panel.frame:GetBackdropColor() }

	Panel:SetTheme("light")
	local light = { Panel.frame:GetBackdropColor() }

	check(light[1] ~= nil, "the window is painted at all", tostring(light[1]))
	check(light[1] ~= azerite[1],
		"changing the theme repaints the background straight away",
		string.format("%.3f then %.3f", azerite[1] or -1, light[1] or -1))

	check(math.abs((light[4] or 0) - Kit.WindowColor[4]) < .001,
		"and paints it at the opacity that was already set",
		string.format("%.3f painted, %.3f wanted", light[4] or -1, Kit.WindowColor[4]))

	check((light[4] or 1) < 0.6, "which is still the reduced one", light[4])

	----------------------------------------------------------------
	-- 100% means opaque
	----------------------------------------------------------------
	for _, key in ipairs(({ Kit.GetThemeChoices() }) [2] or { "azerite", "dark", "light", "class" }) do
		Kit.SetTheme(key)
		Kit.SetOpacity(1)
		check(math.abs(Kit.WindowColor[4] - 1) < .001,
			"100% is fully opaque under " .. key, Kit.WindowColor[4])
	end

	-- And the layering survives it: a backdrop on the window is not more solid
	-- than the window, and an inset is not more solid than the backdrop.
	Kit.SetTheme("azerite")
	Kit.SetOpacity(1)
	-- Strictly less, not equal. Setting all three to the slider's value would
	-- pass a "no more solid than" check while throwing away the depth the theme
	-- is drawn with.
	check(Kit.BackdropColor[4] < Kit.WindowColor[4],
		"a backdrop is less solid than the window it sits on",
		string.format("%.3f on %.3f", Kit.BackdropColor[4], Kit.WindowColor[4]))
	check(Kit.InsetColor[4] < Kit.BackdropColor[4],
		"and an inset less than the backdrop",
		string.format("%.3f in %.3f", Kit.InsetColor[4], Kit.BackdropColor[4]))

	-- The bottom of the slider is still see-through.
	Kit.SetOpacity(Kit.MinOpacity)
	check(Kit.WindowColor[4] < .35, "and the bottom of the slider is not",
		Kit.WindowColor[4])
	Kit.SetOpacity(1)

	----------------------------------------------------------------
	-- Scale
	----------------------------------------------------------------
	check(type(Panel.SetPanelScale) == "function", "the panel can be scaled")

	Panel:SetPanelScale(1.2)
	check(math.abs(Panel.frame:GetScale() - 1.2) < .001, "the window takes the scale",
		Panel.frame:GetScale())
	check(math.abs(Panel:GetPanelScale() - 1.2) < .001, "and reads it back", Panel:GetPanelScale())
	check(ns.db.global.optionsScale == 1.2, "and remembers it", ns.db.global.optionsScale)

	-- Out of range is clamped, not accepted: a window at 10% cannot be clicked
	-- back to a readable size.
	Panel:SetPanelScale(9)
	check(Panel.frame:GetScale() <= Panel.MaxScale + .001, "too large is clamped",
		Panel.frame:GetScale())
	Panel:SetPanelScale(0.01)
	check(Panel.frame:GetScale() >= Panel.MinScale - .001, "too small is clamped",
		Panel.frame:GetScale())

	Panel:SetPanelScale(1)
	Panel:SetTheme("azerite")
end

--------------------------------------------------------------------------
section("A type the panel cannot draw")
--------------------------------------------------------------------------
-- color, keybinding and multiselect have no control of ours. No page uses one
-- today, which is exactly what makes it dangerous: adding the first colour
-- picker would produce a setting that is simply not on the page, with nothing
-- to say so and nothing to error. It has to be visible instead.
do
	local group = {
		type = "group",
		name = "Undrawable",
		args = {
			ordinary = { type = "toggle", name = "An ordinary toggle", order = 1,
				get = function() return true end, set = function() end },
			tint = { type = "color", name = "Some Colour", order = 2,
				get = function() return 1, 1, 1, 1 end, set = function() end },
			bind = { type = "keybinding", name = "Some Keybinding", order = 3,
				get = function() return "" end, set = function() end },
			many = { type = "multiselect", name = "Some Multiselect", order = 4,
				values = function() return {} end,
				get = function() return false end, set = function() end }
		}
	}

	local entries = Renderer:Collect(group, group, {})
	check(#entries == 4, "nothing is dropped on the floor", #entries)

	local named, kinds = 0, {}
	for _, entry in ipairs(entries) do
		if entry.unsupported then
			named = named + 1
			kinds[#kinds + 1] = entry.unsupported
			check(entry.label:match(entry.unsupported) ~= nil,
				"the line names the " .. entry.unsupported .. " type it wanted", entry.label)
		end
	end

	table.sort(kinds)
	check(table.concat(kinds, ",") == "color,keybinding,multiselect",
		"each undrawable type says so", table.concat(kinds, ","))

	-- And the ordinary toggle beside them is untouched.
	local ordinary = 0
	for _, entry in ipairs(entries) do
		if entry.kind == "toggle" then ordinary = ordinary + 1 end
	end
	check(ordinary == 1, "a type we can draw is still drawn", ordinary)
end

--------------------------------------------------------------------------
section("Themes")
--------------------------------------------------------------------------
local _, order = Kit.GetThemeChoices()
for _, key in ipairs(order) do
	Kit.SetTheme(key)
	local ok4, err4 = pcall(function() Panel:ApplyTheme() end)
	check(ok4, "the panel restyles under " .. key, err4)
end
Kit.SetTheme("azerite")

--------------------------------------------------------------------------
section("Refresh and close")
--------------------------------------------------------------------------
-- Opacity is applied through the theme, so re-skinning must not lose it.
Kit.SetOpacity(0.55)
check(pcall(function() Panel:ApplyTheme() end), "the panel restyles at reduced opacity")
check(math.abs(Kit.GetOpacity() - 0.55) < .001, "the panel does not reset opacity")
Kit.SetOpacity(1)

check(pcall(function() Panel:Refresh() end), "the panel refreshes")
check(pcall(function() Panel:Close() end), "the panel closes")

--------------------------------------------------------------------------
section("Command routing")
--------------------------------------------------------------------------
-- Phase 6 makes the new panel the ordinary command while deliberately keeping
-- both older escape hatches. Exercise the dispatch itself, not just the three
-- windows in isolation, so a later cleanup cannot silently swap them back.
do
	local Window = Kit.Window
	local Dialog = S.AceConfigDialog
	local calls = {}

	local realPanelToggle, realPanelClose = Panel.Toggle, Panel.Close
	local realWindowOpen, realWindowClose = Window.Open, Window.Close
	local realRemove = Window.RemoveDialogControls
	local realDialogOpen, realDialogClose = Dialog.Open, Dialog.Close

	Panel.Toggle = function() calls[#calls + 1] = "panel" return true end
	Panel.Close = function() calls[#calls + 1] = "panel-close" end
	Window.Open = function() calls[#calls + 1] = "classic" return true end
	Window.Close = function() calls[#calls + 1] = "classic-close" end
	Window.RemoveDialogControls = function() calls[#calls + 1] = "controls-remove" end
	Dialog.Open = function() calls[#calls + 1] = "stock" end
	Dialog.Close = function() calls[#calls + 1] = "stock-close" end

	Options:OpenOptionsMenu()
	check(calls[#calls] == "panel", "bare /az opens the new panel", calls[#calls])

	Options:OpenOptionsMenu("new")
	check(calls[#calls] == "panel", "/az new remains a new-panel alias", calls[#calls])

	Options:OpenOptionsMenu("classic")
	check(calls[#calls] == "classic", "/az classic opens the retained window", calls[#calls])

	Options:OpenOptionsMenu("legacy")
	check(calls[#calls] == "stock", "/az legacy opens stock Ace3", calls[#calls])
	check(calls[#calls - 1] == "controls-remove",
		"the stock fallback removes custom dialog controls", calls[#calls - 1])

	Panel.Toggle = function() calls[#calls + 1] = "panel-failed" return false end
	Options:OpenOptionsMenu()
	check(calls[#calls] == "classic", "a failed new panel falls back to classic", calls[#calls])

	Window.Open = function() calls[#calls + 1] = "classic-failed" return false end
	Options:OpenOptionsMenu("classic")
	check(calls[#calls] == "stock", "a failed classic window falls back to stock", calls[#calls])

	Panel.Toggle, Panel.Close = realPanelToggle, realPanelClose
	Window.Open, Window.Close = realWindowOpen, realWindowClose
	Window.RemoveDialogControls = realRemove
	Dialog.Open, Dialog.Close = realDialogOpen, realDialogClose
end

--------------------------------------------------------------------------
print()
print(string.format("%d checks, %d failures", checks, failures))
os.exit(failures == 0 and 0 or 1)

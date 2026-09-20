-- Differential test for Options/Kit/Config.lua.
--
-- Config.lua reimplements AceConfigDialog's option-table contract. Rather than
-- trust a hand transcription, this harness lifts the library's own resolver
-- straight out of AceConfigDialog-3.0.lua at run time, loads it in a sandbox,
-- and runs both implementations over every option the addon really defines,
-- comparing every answer - including which ones raise an error.
--
-- If the two agree on all of it, the contract is right. If they disagree on a
-- single member of a single option, that is a bug this would otherwise have hidden
-- until somebody's setting silently read the wrong value.
--
-- Usage: lua config_diff_harness.lua <addon root> <scratchpad dir>

local root = arg[1] or "."
local SP = arg[2] or "."

local S = dofile(SP .. "/stubs.lua")
local ns, Addon = S.ns, S.Addon

local failures, checks = 0, 0
local function check(ok, what, detail)
	checks = checks + 1
	if not ok then
		failures = failures + 1
		if failures <= 40 then
			print(string.format("  FAIL  %s%s", what, detail and ("  -- " .. tostring(detail)) or ""))
		end
	end
	return ok
end

--------------------------------------------------------------------------
-- Lift the library's resolver out of its source
--------------------------------------------------------------------------
local libPath = root .. "/Libs/AceConfig-3.0/AceConfigDialog-3.0/AceConfigDialog-3.0.lua"
local handle = assert(io.open(libPath), "cannot open " .. libPath)
local libSrc = handle:read("*a")
handle:close()

local function grab(header, terminator)
	local from = libSrc:find(header, 1, true)
	assert(from, "not found in the library source: " .. header)
	local to = libSrc:find(terminator, from, true)
	assert(to, "no terminator for: " .. header)
	return libSrc:sub(from, to + #terminator - 1)
end

local function grabFunc(header) return grab(header, "\nend\n") end
local function grabTable(header) return grab(header, "\n}\n") end

local oracleSrc = table.concat({
	"local new, del, format, pairs, tinsert, tsort, select, type, error, MAJOR = ...",
	"local tempOrders, tempNames",
	grabFunc("local function pickfirstset(...)"),
	grabFunc("local function GetSubOption(group, key)"),
	grabTable("local isInherited = {"),
	grabTable("local stringIsLiteral = {"),
	grabTable("local allIsLiteral = {"),
	grabFunc("local function GetOptionsMemberValue(membername, option, options, path, appName, ...)"),
	grabFunc("local function CheckOptionHidden(option, options, path, appName)"),
	grabFunc("local function CheckOptionDisabled(option, options, path, appName)"),
	grabFunc("local function compareOptions(a,b)"),
	grabFunc("local function BuildSortedOptionsTable(group, keySort, opts, options, path, appName)"),
	[[return {
		GetOptionsMemberValue = GetOptionsMemberValue,
		CheckOptionHidden = CheckOptionHidden,
		CheckOptionDisabled = CheckOptionDisabled,
		BuildSortedOptionsTable = BuildSortedOptionsTable,
	}]],
}, "\n")

local chunk = assert(loadstring(oracleSrc, "@AceConfigDialog-oracle"))
local oracle = chunk(
	function() return {} end,   -- new
	function() end,             -- del
	string.format,
	pairs, table.insert, table.sort, select, type, error,
	"AceConfigDialog-3.0"
)

print(string.format("oracle lifted from the library: %d bytes, %d functions",
	#oracleSrc, 4))

--------------------------------------------------------------------------
-- Build the real options table
--------------------------------------------------------------------------
local autoMT
autoMT = { __index = function(t, k)
	local v = setmetatable({}, autoMT); rawset(t, k, v); return v
end }

local dataFields = { db = true, defaults = true, settings = true, bars = true }
local moduleStubMT = { __index = function(t, k)
	local v
	if dataFields[k] then v = setmetatable({}, autoMT)
	else v = function() return setmetatable({}, autoMT) end end
	rawset(t, k, v); return v
end }

local realModules = S.modules
ns.GetModule = function(self, name)
	if realModules[name] then return realModules[name] end
	realModules[name] = setmetatable({}, moduleStubMT)
	return realModules[name]
end

local function load(rel)
	local c, err = loadfile(root .. "/" .. rel)
	if not c then error("could not load " .. rel .. ": " .. tostring(err)) end
	return c(Addon, ns)
end

load("Options/Kit/Kit.lua")
load("Options/Kit/Config.lua")
load("Options/Kit/Widgets.lua")
load("Options/Kit/Window.lua")
load("Options/Options.lua")

local xml = io.open(root .. "/Options/Options.xml"):read("*a")
for file in xml:gmatch('<Script file="OptionsPages\\([%w_]+%.lua)"/>') do
	pcall(load, "Options/OptionsPages/" .. file)
end

local Options = realModules["Options"]
Options:GenerateOptionsMenu()
local options = Options:GetOptionsObject()
assert(options, "no options table was produced")

local Config = ns.OptionsKit.Config

--------------------------------------------------------------------------
-- Compare
--------------------------------------------------------------------------
-- `set` and `func` are deliberately absent: calling them would write settings
-- and fire actions. Everything else an option can carry is compared.
local MEMBERS = {
	"name", "desc", "order", "get", "values", "sorting", "width", "min", "max",
	"step", "softMin", "softMax", "bigStep", "isPercent", "multiline", "fontSize",
	"descStyle", "image", "imageWidth", "imageHeight", "imageCoords", "arg", "usage",
	"tristate", "style", "confirm", "validate", "dialogControl", "control",
	"childGroups", "inline", "dialogInline", "guiInline", "icon", "type",
	"hidden", "disabled", "cmdHidden", "tooltipHyperlink", "itemControl",
}

-- Up to four returns, because a colour option's get returns r, g, b, a.
local function call4(fn, ...)
	local ok, a, b, c, d = pcall(fn, ...)
	return ok, a, b, c, d
end

-- Several options build their table fresh on every call - a `values` closure
-- that returns a new list, say - so two correct implementations hand back equal
-- but distinct tables. Comparing identity would report those as failures, so
-- tables are compared by content.
local tablesCompared = 0

local function same(x, y, depth)
	depth = depth or 0
	if x == y then return true end
	-- NaN never equals itself; treat two NaNs as agreement.
	if x ~= x and y ~= y then return true end

	if type(x) ~= "table" or type(y) ~= "table" then return false end
	if depth == 0 then tablesCompared = tablesCompared + 1 end
	if depth > 6 then return true end

	for k, v in pairs(x) do
		if not same(v, rawget(y, k), depth + 1) then return false end
	end
	for k in pairs(y) do
		if rawget(x, k) == nil then return false end
	end
	return true
end

local nodes, comparisons, errorsBoth = 0, 0, 0

local function compareNode(options, option, path, label)
	nodes = nodes + 1

	for _, member in ipairs(MEMBERS) do
		local mOk, m1, m2, m3, m4 = call4(Config.GetMember, member, option, options, path, Addon)
		local oOk, o1, o2, o3, o4 = call4(oracle.GetOptionsMemberValue, member, option, options, path, Addon)

		comparisons = comparisons + 1

		if not mOk and not oOk then
			errorsBoth = errorsBoth + 1
		else
			check(mOk == oOk,
				string.format("%s . %s: both must %s", label, member, oOk and "succeed" or "error"),
				string.format("ours=%s theirs=%s", mOk and "ok" or "error", oOk and "ok" or "error"))

			if mOk and oOk then
				check(same(m1, o1) and same(m2, o2) and same(m3, o3) and same(m4, o4),
					string.format("%s . %s: same value", label, member),
					string.format("ours=%s theirs=%s", tostring(m1), tostring(o1)))
			end
		end
	end

	-- hidden and disabled go through the dialog-specific short circuit.
	local hOk, h = pcall(Config.IsHidden, option, options, path, Addon)
	local hoOk, ho = pcall(oracle.CheckOptionHidden, option, options, path, Addon)
	comparisons = comparisons + 1
	check(hOk == hoOk and (not hOk or same(h, ho)),
		label .. " : IsHidden agrees", string.format("ours=%s theirs=%s", tostring(h), tostring(ho)))

	local dOk, d = pcall(Config.IsDisabled, option, options, path, Addon)
	local doOk, dd = pcall(oracle.CheckOptionDisabled, option, options, path, Addon)
	comparisons = comparisons + 1
	check(dOk == doOk and (not dOk or same(d, dd)),
		label .. " : IsDisabled agrees", string.format("ours=%s theirs=%s", tostring(d), tostring(dd)))
end

local groupsCompared = 0

local function compareGroup(options, group, path, label)
	-- Draw order must match exactly, including the rule that a negative order
	-- sorts last and a missing order counts as 100.
	local mine = Config.SortedKeys(group, options, path, Addon)

	local theirs, opts = {}, {}
	oracle.BuildSortedOptionsTable(group, theirs, opts, options, path, Addon)

	groupsCompared = groupsCompared + 1
	check(#mine == #theirs, label .. " : same number of children",
		string.format("ours=%d theirs=%d", #mine, #theirs))

	local order1 = table.concat(mine, ",")
	local order2 = table.concat(theirs, ",")
	check(order1 == order2, label .. " : same draw order",
		#order1 < 220 and ("\n      ours   " .. order1 .. "\n      theirs " .. order2) or "(long)")

	for _, key in ipairs(mine) do
		local option = Config.GetSubOption(group, key)
		if type(option) == "table" then
			path[#path + 1] = key
			compareNode(options, option, path, label .. " > " .. key)
			if option.type == "group" then
				compareGroup(options, option, path, label .. " > " .. key)
			end
			path[#path] = nil
		end
	end
end

compareGroup(options, options, {}, "real")

--------------------------------------------------------------------------
-- A second corpus, for the corners the real table never reaches
--------------------------------------------------------------------------
-- Mutation testing showed three rules that no option in this addon exercises:
-- `handler` inheritance, a missing `order`, and the dialogHidden/guiHidden short
-- circuit. A differential test can only prove what the data reaches, so this
-- table deliberately reaches the rest of the contract.
local handlerRoot = {
	RootGet = function(self, info) return "root:" .. tostring(info[#info]) end,
	RootDisabled = function(self, info) return info[#info] == "disabledByRoot" end,
	RootHidden = function(self, info) return false end,
	RootName = function(self, info) return "named by root handler" end,
	RootValues = function(self, info) return { a = "A", b = "B" } end,
	RootColour = function(self, info) return 0.1, 0.2, 0.3, 0.4 end,
	RootConfirm = function(self, info) return "are you sure?" end,
	RootValidate = function(self, info, value) return true end,
}

local handlerDeep = {
	RootGet = function(self, info) return "deep:" .. tostring(info[#info]) end,
	RootDisabled = function(self, info) return true end,
	RootHidden = function(self, info) return false end,
	RootName = function(self, info) return "named by deep handler" end,
	RootValues = function(self, info) return { c = "C" } end,
	RootColour = function(self, info) return 0.9, 0.8, 0.7, 0.6 end,
	RootConfirm = function(self, info) return false end,
	RootValidate = function(self, info, value) return "no" end,
}

local synthetic = {
	type = "group",
	name = "Synthetic",
	handler = handlerRoot,
	-- Inherited members, given as handler method names rather than functions.
	get = "RootGet",
	disabled = "RootDisabled",
	hidden = "RootHidden",
	confirm = "RootConfirm",
	validate = "RootValidate",
	args = {
		-- No order at all, so the "missing counts as 100" rule is exercised,
		-- and the tie then breaks on the uppercased name.
		zeta = { type = "toggle", name = "zeta" },
		alpha = { type = "toggle", name = "alpha" },
		Beta = { type = "toggle", name = "Beta" },

		negative = { type = "toggle", name = "negative", order = -5 },
		negative2 = { type = "toggle", name = "negative two", order = -100 },
		positive = { type = "toggle", name = "positive", order = 5 },
		zeroth = { type = "toggle", name = "zeroth", order = 0 },

		-- The dialog-specific short circuits.
		dialogHidden = { type = "toggle", name = "dialog hidden", order = 10, dialogHidden = true },
		guiHidden = { type = "toggle", name = "gui hidden", order = 11, guiHidden = true },
		dialogShown = { type = "toggle", name = "dialog shown", order = 12, dialogHidden = false, hidden = true },
		dialogDisabled = { type = "toggle", name = "dialog disabled", order = 13, dialogDisabled = true },
		guiDisabled = { type = "toggle", name = "gui disabled", order = 14, guiDisabled = false, disabled = true },
		disabledByRoot = { type = "toggle", name = "disabled by root handler", order = 15 },

		-- name as a handler method, and name as a plain string that must NOT be
		-- treated as one.
		namedByHandler = { type = "toggle", name = "RootName", order = 16 },
		namedLiteral = { type = "toggle", name = "RootName is not called here", order = 17 },
		descLiteral = { type = "toggle", name = "desc literal", desc = "RootName", order = 18 },

		-- Four returns.
		colour = { type = "color", name = "colour", order = 19, get = "RootColour", hasAlpha = true },

		valuesByHandler = { type = "select", name = "values by handler", order = 20, values = "RootValues" },

		-- A nested group that overrides the handler, so everything below it must
		-- resolve against the deeper one.
		deep = {
			type = "group",
			name = "deep",
			order = 21,
			handler = handlerDeep,
			args = {
				inherited = { type = "toggle", name = "inherited from deep", order = 1 },
				colour = { type = "color", name = "deep colour", order = 2, get = "RootColour" },
				deeper = {
					type = "group",
					name = "deeper",
					order = 3,
					args = {
						stillDeep = { type = "toggle", name = "still the deep handler", order = 1 },
						ownGet = { type = "toggle", name = "own get wins", order = 2,
							get = function(info) return "own" end },
					}
				}
			}
		},

		-- Plugins, which take precedence over args of the same key.
		plugged = { type = "group", name = "plugged", order = 22, args = {},
			plugins = {
				somebodyElse = {
					fromPlugin = { type = "toggle", name = "from a plugin", order = 1 },
				}
			}
		},
	}
}

compareGroup(synthetic, synthetic, {}, "synthetic")

--------------------------------------------------------------------------
print()
print(string.format("groups compared    %d", groupsCompared))
print(string.format("options compared   %d", nodes))
print(string.format("member comparisons %d", comparisons))
print(string.format("  of which both implementations errored identically: %d", errorsBoth))
print(string.format("  of which returned tables, compared by content:     %d", tablesCompared))
print()
print(string.format("%d checks, %d failures", checks, failures))
if failures > 40 then
	print(string.format("(%d further failures not printed)", failures - 40))
end
os.exit(failures == 0 and 0 or 1)

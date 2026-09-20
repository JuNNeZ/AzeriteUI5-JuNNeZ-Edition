-- Prints the root pages in the order AceConfigDialog would actually draw them,
-- using Config.SortedKeys. Checks whether the Profiles page lands where the
-- custom window's own rail currently puts it.
--
-- Usage: lua order_probe.lua <addon root> <scratchpad>

local root, SP = arg[1], arg[2]
local S = dofile(SP .. "/stubs.lua")
local ns, Addon = S.ns, S.Addon

local autoMT
autoMT = { __index = function(t, k)
	local v = setmetatable({}, autoMT); rawset(t, k, v); return v
end }

local dataFields = { db = true, defaults = true, settings = true }
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
	local chunk, err = assert(loadfile(root .. "/" .. rel), tostring(err))
	return chunk(Addon, ns)
end

load("Options/Kit/Kit.lua")
load("Options/Kit/Config.lua")
load("Options/Kit/Widgets.lua")
load("Options/Kit/Window.lua")
load("Options/Options.lua")

local xml = io.open(root .. "/Options/Options.xml"):read("*a")
local loaded, failed = 0, 0
for file in xml:gmatch('<Script file="OptionsPages\\([%w_]+%.lua)"/>') do
	local ok = pcall(load, "Options/OptionsPages/" .. file)
	if ok then loaded = loaded + 1 else failed = failed + 1 end
end
print(string.format("pages loaded %d, failed %d", loaded, failed))

local Options = S.modules["Options"]
assert(Options, "no Options module")
Options:GenerateOptionsMenu()

local options = Options:GetOptionsObject()
assert(options, "GenerateOptionsMenu produced nothing")

local Config = ns.OptionsKit.Config
local keys = Config.SortedKeys(options, options, {}, Addon)

print("\nDraw order Ace3 would use:")
for i, key in ipairs(keys) do
	local option = Config.GetSubOption(options, key)
	print(string.format("  %2d. %-28s order %s", i, key, tostring(option and option.order)))
end

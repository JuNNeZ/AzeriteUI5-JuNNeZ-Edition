-- Finds the options that fail to bind, and says why.
-- Usage: lua bind_probe.lua <addon root> <scratchpad>

local root, SP = arg[1], arg[2]
local S = dofile(SP .. "/stubs.lua")
local ns, Addon = S.ns, S.Addon

local autoMT
autoMT = { __index = function(t, k)
	-- t[nil] is a legal read in Lua and answers nil; only a write raises. Caching
	-- the miss would make this stub stricter than the language it stands in for.
	if k == nil then return nil end
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
	return assert(loadfile(root .. "/" .. rel))(Addon, ns)
end

for _, f in ipairs({
	"Options/Kit/Kit.lua", "Options/Kit/Config.lua", "Options/Kit/Controls.lua",
	"Options/Kit/Renderer.lua", "Options/Kit/Panel.lua", "Options/Kit/Gallery.lua",
	"Options/Kit/Widgets.lua", "Options/Kit/Window.lua", "Options/Options.lua",
}) do load(f) end

local xml = io.open(root .. "/Options/Options.xml"):read("*a")
for file in xml:gmatch('<Script file="OptionsPages\\([%w_]+%.lua)"/>') do
	pcall(load, "Options/OptionsPages/" .. file)
end

local Options = S.modules["Options"]
Options:GenerateOptionsMenu()
local options = Options:GetOptionsObject()

local Kit = ns.OptionsKit
local Config, Renderer = Kit.Config, Kit.Renderer
local APP = Addon

-- Walk every page the way the renderer does, and try each binding step on its
-- own so the failure names itself.
local keys = Config.SortedKeys(options, options, {}, APP)
local failures = 0

for _, pageKey in ipairs(keys) do
	local pageOption = Config.GetSubOption(options, pageKey)
	if type(pageOption) == "table" and pageOption.type == "group" then
		local entries = Renderer:Collect(pageOption, options, { pageKey })

		for _, entry in ipairs(entries) do
			if entry.option then
				local o, path = entry.option, entry.path

				local steps = {
					{ "name", function() return Config.GetName(o, options, path, APP) end },
					{ "desc", function() return Config.GetDesc(o, options, path, APP) end },
					{ "disabled", function() return Config.IsDisabled(o, options, path, APP) end },
					{ "get", function() return Config.GetValue(o, options, path, APP) end },
				}
				if entry.kind == "select" then
					steps[#steps + 1] = { "values", function() return Config.GetValues(o, options, path, APP) end }
					steps[#steps + 1] = { "sorting", function() return Config.GetMember("sorting", o, options, path, APP) end }
				end

				for _, step in ipairs(steps) do
					local ok, err = pcall(step[2])
					if not ok then
						failures = failures + 1
						print(string.format("%-16s %-28s %-9s %s",
							pageKey, table.concat(path, " > "), step[1],
							tostring(err):gsub("^.*:%d+: ", "")))
					end
				end
			end
		end
	end
end

print()
print(failures .. " failing member calls")

-- Now the real thing: render each page and report every row that fell back to
-- the failure label, with the reason the renderer recorded under it.
print()
print("rows that fell back to the failure label:")
local Panel = Kit.Panel
Panel:Open()
local seen = 0
for _, entry in ipairs(Panel.pages or {}) do
	Panel:SelectPage(entry.key)
	for _, c in ipairs(Panel.page:GetControls()) do
		local text = c.label and c.label.GetText and c.label:GetText()
		if type(text) == "string" and text:find("(failed)", 1, true) then
			seen = seen + 1
			local why = c.help and c.help.GetText and c.help:GetText() or "?"
			print(string.format("  %-16s %-18s %s", entry.key, text,
				tostring(why):gsub("^.*:%d+: ", "")))
		end
	end
end
print("  total " .. seen)

--[[

	The MIT License (MIT)

	Copyright (c) 2026 Jonas "JuNNeZ" Andersen

--]]
-- Which settings differ from their defaults.
--
-- The artifact marks a changed setting with a gem and offers to put that one
-- setting back without resetting the whole profile. Doing that needs a default
-- value per option, and an AceConfig option table does not carry one: the
-- getters are closures like
--
--     function(info) return getmodule().db.profile[info[#info]] end
--
-- so the key is `info[#info]`, which we have, and the module is captured inside
-- the closure, which we do not.
--
-- Rather than guess, a group says which module its settings live in. The
-- generators that already know are the ones that take the module's name and
-- return a group - `GenerateSubOptions` in UnitFrames, `GenerateBarOptions` in
-- ActionBars - plus the pages that describe a single module, which declare it
-- alongside their rail section.
--
-- The binding is kept here, keyed by the group's own table, rather than as a
-- field on it: AceConfigRegistry validates option tables and an unknown key in
-- one would be a risk for nothing.
--
-- A group that names no module simply shows no gem, which is why every page
-- still renders whether or not anyone got round to declaring it.
local Addon, ns = ...

local Kit = ns.OptionsKit
local Config = Kit.Config
if (not Config) then return end

-- Lua API
local pairs = pairs
local pcall = pcall
local type = type

local Defaults = {}
Kit.Defaults = Defaults

local APP = Addon

-- Weak keys: a group table that goes away takes its binding with it.
local bindings = setmetatable({}, { __mode = "k" })

--------------------------------------------------------------------------
-- Binding
--------------------------------------------------------------------------
-- Declares that everything in `group` reads and writes the named module's
-- profile. Safe to call with nil, so a caller need not check first.
Defaults.Bind = function(group, moduleName)
	if (type(group) ~= "table" or type(moduleName) ~= "string") then return end
	bindings[group] = moduleName
end

Defaults.GetBinding = function(group)
	return type(group) == "table" and bindings[group] or nil
end

-- Walks the path from the root, keeping the deepest binding seen. A sub-group
-- that names its own module therefore wins over the page around it, which is
-- what UnitFrames and ActionBars need: one page, a module per section.
Defaults.ModuleNameFor = function(options, path)
	local group = options
	local found = bindings[group]

	for i = 1, #path do
		group = Config.GetSubOption(group, path[i])
		if (type(group) ~= "table") then break end
		if (bindings[group]) then found = bindings[group] end
	end

	return found
end

--------------------------------------------------------------------------
-- Values
--------------------------------------------------------------------------
local ProfileDefaults = function(moduleName)
	if (not moduleName) then return end

	local module = ns:GetModule(moduleName, true)
	if (not module or not module.GetProfileDefaults) then return end

	local ok, defaults = pcall(module.GetProfileDefaults, module)
	return ok and type(defaults) == "table" and defaults or nil
end

-- The default for the option at `path`. The last element of the path is the
-- database key, which is the convention every option page in this addon writes
-- its getters and setters against.
--
-- Returns nil when there is no binding, no module, or no default recorded, and
-- the caller is expected to show no gem rather than assume anything.
Defaults.Get = function(options, path)
	if (type(path) ~= "table" or #path == 0) then return end

	local defaults = ProfileDefaults(Defaults.ModuleNameFor(options, path))
	if (not defaults) then return end

	return defaults[path[#path]]
end

-- Colours and positions are tables, so equality has to look inside one level.
local Same = function(a, b)
	if (a == b) then return true end
	if (type(a) ~= "table" or type(b) ~= "table") then return false end

	for k, v in pairs(a) do
		if (b[k] ~= v) then return false end
	end
	for k in pairs(b) do
		if (a[k] == nil) then return false end
	end
	return true
end
Defaults.Same = Same

-- Three answers, not two: true, false, and "no idea". A setting whose default
-- is unknown must not be marked either way.
Defaults.IsModified = function(options, path, current)
	local default = Defaults.Get(options, path)
	if (default == nil) then return nil end

	return not Same(current, default)
end

-- Puts one setting back without touching the rest of the profile.
Defaults.Revert = function(options, path)
	local default = Defaults.Get(options, path)
	if (default == nil) then return false end

	local group = Config.GetGroup(options, path)
	if (type(group) ~= "table") then return false end

	local ok = pcall(Config.SetValue, group, options, path, APP, default)
	return ok
end

--------------------------------------------------------------------------
-- Counting
--------------------------------------------------------------------------
-- How many settings under a group differ from their defaults. Used for the dot
-- beside a page in the rail, and for the tally in the header.
Defaults.CountModified = function(options, path)
	local group = Config.GetGroup(options, path)
	if (type(group) ~= "table") then return 0 end

	local count = 0

	local Walk
	Walk = function(node, nodePath)
		Config.ForEachChild(node, options, nodePath, APP, function(key, option, childPath)
			if (option.type == "group") then
				Walk(option, childPath)
				return
			end

			if (option.type == "header" or option.type == "description") then return end
			if (option.type == "execute") then return end

			local ok, value = pcall(Config.GetValue, option, options, childPath, APP)
			if (not ok) then return end

			if (Defaults.IsModified(options, childPath, value)) then
				count = count + 1
			end
		end)
	end

	Walk(group, path)
	return count
end

--[[

	The MIT License (MIT)

	Copyright (c) 2026 Jonas "JuNNeZ" Andersen

--]]
-- Reading an AceConfig options table.
--
-- The custom options panel draws itself, but the option tables stay exactly as
-- AceConfig defines them: five thousand lines of them, written against a
-- contract this file has to honour precisely. Get one rule wrong and a setting
-- silently reads the wrong value, or a `disabled` closure stops being consulted,
-- and nothing errors to say so.
--
-- So this is a deliberate reimplementation of AceConfigDialog-3.0.lua:106-260,
-- kept close enough to the original to be diffed against it. The harness does
-- exactly that: it runs the library's own resolver beside this one over every
-- option the addon really defines and compares both answers, including which
-- ones error.
--
-- Nothing here creates a frame or touches AceGUI. It is pure table reading, so
-- it can be tested away from the game.
local Addon, ns = ...

-- Lua API
local error = error
local ipairs, pairs = ipairs, pairs
local select = select
local string_format = string.format
local table_sort = table.sort
local tinsert = table.insert
local type = type

local Config = {}
ns.OptionsKit.Config = Config

Config.AppName = Addon

--------------------------------------------------------------------------
-- Member classification
--------------------------------------------------------------------------
-- Verbatim from AceConfigDialog-3.0.lua:131-159. These three tables are the
-- whole of the contract's subtlety, so they are copied rather than paraphrased.

-- Inherited from the parent groups, deepest definition winning.
local isInherited = {
	set = true,
	get = true,
	func = true,
	confirm = true,
	validate = true,
	disabled = true,
	hidden = true
}

-- For these, a string is the value itself. For every other member a string
-- means "call this method on the handler".
local stringIsLiteral = {
	name = true,
	desc = true,
	icon = true,
	usage = true,
	width = true,
	image = true,
	fontSize = true,
	tooltipHyperlink = true
}

-- Never callable, whatever they hold.
local allIsLiteral = {
	type = true,
	descStyle = true,
	imageWidth = true,
	imageHeight = true
}

--------------------------------------------------------------------------
-- Tree walking
--------------------------------------------------------------------------
-- Plugins are other addons' additions to our table. Nothing registers any
-- today, but the lookup order is part of the contract.
local GetSubOption = function(group, key)
	if (group.plugins) then
		for plugin, t in pairs(group.plugins) do
			if (t[key]) then
				return t[key]
			end
		end
	end

	return group.args and group.args[key]
end
Config.GetSubOption = GetSubOption

-- Follows a path from the root, returning the group it names.
Config.GetGroup = function(options, path)
	local group = options
	for i = 1, #path do
		if (not group) then return end
		group = GetSubOption(group, path[i])
	end
	return group
end

-- Picks the first argument that is not nil.
local pickfirstset = function(...)
	for i = 1, select("#", ...) do
		if (select(i, ...) ~= nil) then
			return (select(i, ...))
		end
	end
end

--------------------------------------------------------------------------
-- The info table
--------------------------------------------------------------------------
-- What every get, set, func, validate, confirm, disabled and hidden closure in
-- the option pages is handed. The array part is the path, and the pages lean on
-- that hard: `info[#info]` is the database key in nearly every setter they
-- write.
--
-- AceConfigDialog recycles these through a pool. Here they are plain tables:
-- the allocation is nothing next to building a page, and a pooled table handed
-- to an option's closure that keeps a reference would be a bug waiting to
-- happen.
local BuildInfo = function(options, path, appName, option)
	local info = {}

	local group = options
	local handler = group.handler

	for i = 1, #path do
		group = GetSubOption(group, path[i])
		if (not group) then break end
		info[i] = path[i]
		handler = group.handler or handler
	end

	info.options = options
	info.appName = appName
	info[0] = appName
	info.arg = option and option.arg
	info.handler = handler
	info.option = option
	info.type = option and option.type
	info.uiType = "dialog"
	info.uiName = "AceConfigDialog-3.0"

	return info, handler
end
Config.BuildInfo = BuildInfo

--------------------------------------------------------------------------
-- Member resolution
--------------------------------------------------------------------------
-- Returns up to four values, because a colour option's `get` returns r, g, b, a.
--
-- `path` must already include the option's own key: AceConfigDialog pushes the
-- key on before it asks, so a leaf's own `handler` is part of the chain.
local GetMember = function(membername, option, options, path, appName, ...)
	local member

	if (isInherited[membername]) then
		local group = options
		if (group[membername] ~= nil) then
			member = group[membername]
		end
		for i = 1, #path do
			group = GetSubOption(group, path[i])
			if (not group) then break end
			if (group[membername] ~= nil) then
				member = group[membername]
			end
		end
	else
		member = option[membername]
	end

	local callable = (not allIsLiteral[membername])
		and (type(member) == "function"
			or ((not stringIsLiteral[membername]) and type(member) == "string"))

	if (not callable) then
		return member
	end

	local info, handler = BuildInfo(options, path, appName, option)

	if (type(member) == "function") then
		return member(info, ...)
	end

	if (handler and handler[member]) then
		return handler[member](handler, info, ...)
	end

	error(string_format("Method %s doesn't exist in handler for type %s", member, membername))
end
Config.GetMember = GetMember

--------------------------------------------------------------------------
-- Named accessors
--------------------------------------------------------------------------
Config.GetName = function(option, options, path, appName)
	return GetMember("name", option, options, path, appName)
end

Config.GetDesc = function(option, options, path, appName)
	return GetMember("desc", option, options, path, appName)
end

Config.GetOrder = function(option, options, path, appName)
	return GetMember("order", option, options, path, appName)
end

-- A dialog-specific flag wins over the shared one, and short-circuits the
-- inherited lookup entirely.
Config.IsHidden = function(option, options, path, appName)
	local hidden = pickfirstset(option.dialogHidden, option.guiHidden)
	if (hidden ~= nil) then
		return hidden
	end
	return GetMember("hidden", option, options, path, appName)
end

Config.IsDisabled = function(option, options, path, appName)
	local disabled = pickfirstset(option.dialogDisabled, option.guiDisabled)
	if (disabled ~= nil) then
		return disabled
	end
	return GetMember("disabled", option, options, path, appName)
end

-- Reads a value. Extra arguments are passed through, which multiselect needs.
Config.GetValue = function(option, options, path, appName, ...)
	return GetMember("get", option, options, path, appName, ...)
end

-- Writes a value.
Config.SetValue = function(option, options, path, appName, ...)
	return GetMember("set", option, options, path, appName, ...)
end

-- Runs an execute.
Config.Execute = function(option, options, path, appName, ...)
	return GetMember("func", option, options, path, appName, ...)
end

-- Returns true, or a string to show, when a change needs confirming.
Config.GetConfirm = function(option, options, path, appName, ...)
	return GetMember("confirm", option, options, path, appName, ...)
end

-- Returns true when the value is acceptable, or a string explaining why not.
Config.Validate = function(option, options, path, appName, ...)
	return GetMember("validate", option, options, path, appName, ...)
end

Config.GetValues = function(option, options, path, appName)
	return GetMember("values", option, options, path, appName)
end

--------------------------------------------------------------------------
-- Ordering
--------------------------------------------------------------------------
-- AceConfigDialog's own comparison, and it has a rule worth stating out loud:
-- a **negative order sorts last**, not first. Anything without an order counts
-- as 100. Ties break on the uppercased name.
local orders, names

local compareOptions = function(a, b)
	if (not a) then return true end
	if (not b) then return false end

	local orderA, orderB = orders[a] or 100, orders[b] or 100

	if (orderA == orderB) then
		local nameA = (type(names[a]) == "string") and names[a] or ""
		local nameB = (type(names[b]) == "string") and names[b] or ""
		return nameA:upper() < nameB:upper()
	end

	if (orderA < 0) then
		if (orderB >= 0) then return false end
	else
		if (orderB < 0) then return true end
	end

	return orderA < orderB
end

-- Returns this group's child keys in the order AceConfigDialog would draw them.
Config.SortedKeys = function(group, options, path, appName)
	local keys, seen = {}, {}
	orders, names = {}, {}

	local collect = function(source)
		for key, option in pairs(source) do
			if (not seen[key]) then
				seen[key] = option
				tinsert(keys, key)

				path[#path + 1] = key
				orders[key] = GetMember("order", option, options, path, appName)
				names[key] = GetMember("name", option, options, path, appName)
				path[#path] = nil
			end
		end
	end

	if (group.plugins) then
		for plugin, t in pairs(group.plugins) do
			collect(t)
		end
	end
	if (group.args) then
		collect(group.args)
	end

	table_sort(keys, compareOptions)

	orders, names = nil, nil

	return keys, seen
end

--------------------------------------------------------------------------
-- Iteration
--------------------------------------------------------------------------
-- Walks a group's visible children in draw order, calling
-- `callback(key, option, path)` with `path` already including the key. Hidden
-- children are skipped, which is what the panel wants everywhere.
Config.ForEachChild = function(group, options, path, appName, callback)
	local keys, byKey = Config.SortedKeys(group, options, path, appName)

	for i = 1, #keys do
		local key = keys[i]
		local option = byKey[key]

		path[#path + 1] = key
		if (not Config.IsHidden(option, options, path, appName)) then
			callback(key, option, path)
		end
		path[#path] = nil
	end
end

-- True when a group has at least one visible child group, which decides
-- whether a page needs sub-pages at all.
Config.HasChildGroups = function(group, options, path, appName)
	local found = false

	Config.ForEachChild(group, options, path, appName, function(key, option)
		if (option.type == "group" and not option.inline
			and not option.dialogInline and not option.guiInline) then
			found = true
		end
	end)

	return found
end

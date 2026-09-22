--[[

	The MIT License (MIT)

	Copyright (c) 2026 Jonas "JuNNeZ" Andersen

--]]
-- A page of the control types no shipped setting uses yet.
--
-- `color`, `keybinding` and `multiselect` are drawn by the options panel as of
-- Phase 9, and nothing in this addon has a setting of any of those types. That
-- left them testable only by adding a scratch page by hand and remembering to
-- delete it again, which is exactly the kind of thing that gets forgotten in a
-- release build.
--
-- So it lives here instead, hidden unless Development Mode is on (Options ->
-- Advanced, or the version label's right-click menu). A player never sees it; a
-- maintainer gets it by toggling one setting, and it is the first thing to check
-- when one of these three stops working.
--
-- The values are scratch. They live in the global section rather than a profile,
-- they are not read by anything, and nothing here carries a gem: a gem needs a
-- module's `GetProfileDefaults` to compare against, and this page has no module
-- by design. The per-key gem logic for a multiselect is covered by
-- `Tools/Harness/panel_harness.lua` instead.
local _, ns = ...

local L = LibStub("AceLocale-3.0"):GetLocale((...))

local Options = ns:GetModule("Options")

local IsDevelopment = function()
	return (ns.db and ns.db.global and ns.db.global.enableDevelopmentMode) and true or false
end

-- One scratch table, kept in the global section so a value survives the reload
-- you do in the middle of testing it.
local Store = function()
	if (not ns.db or not ns.db.global) then return {} end

	if (type(ns.db.global.controlTypeTest) ~= "table") then
		ns.db.global.controlTypeTest = {}
	end

	local store = ns.db.global.controlTypeTest
	if (type(store.tint) ~= "table") then store.tint = { 1, 0.5, 0, 1 } end
	if (type(store.choices) ~= "table") then store.choices = { alpha = true } end
	return store
end

local GenerateOptions = function()
	local options = {
		name = L["Control Types"],
		desc = L["The control types no setting in this addon uses yet, so that they can be tested at all. Visible only in Development Mode; nothing here changes the interface."],
		type = "group",
		hidden = function() return not IsDevelopment() end,
		args = {}
	}

	options.args.colorHeader = {
		name = L["Colour"], type = "header", order = 1
	}

	options.args.tint = {
		name = L["Colour With Alpha"],
		desc = L["Opens the game's own colour picker. The swatch shows the colour as it is used on the left and opaque on the right."],
		type = "color", hasAlpha = true,
		order = 2,
		get = function()
			local tint = Store().tint
			return tint[1], tint[2], tint[3], tint[4]
		end,
		set = function(info, r, g, b, a)
			Store().tint = { r, g, b, a }
		end
	}

	options.args.solid = {
		name = L["Colour Without Alpha"],
		desc = L["The same control with no opacity to set, which is the more common shape."],
		type = "color",
		order = 3,
		get = function()
			local tint = Store().tint
			return tint[1], tint[2], tint[3]
		end,
		set = function(info, r, g, b)
			local tint = Store().tint
			Store().tint = { r, g, b, tint[4] or 1 }
		end
	}

	options.args.bindHeader = {
		name = L["Keybinding"], type = "header", order = 10
	}

	options.args.binding = {
		name = L["A Keybinding"],
		desc = L["Click, then press the combination you want. Escape clears it. This records the binding as text and binds nothing; a real setting decides what to do with it."],
		type = "keybinding",
		order = 11,
		get = function() return Store().binding end,
		set = function(info, value) Store().binding = value end
	}

	options.args.multiHeader = {
		name = L["Multiselect"], type = "header", order = 20
	}

	options.args.choices = {
		name = L["Several Choices"],
		desc = L["One setting with a value per key, drawn as a toggle each. Each row reads and writes its own key."],
		type = "multiselect",
		order = 21,
		values = {
			alpha = L["Alpha"],
			beta = L["Beta"],
			gamma = L["Gamma"]
		},
		get = function(info, key) return Store().choices[key] and true or false end,
		set = function(info, key, value) Store().choices[key] = value and true or nil end
	}

	options.args.report = {
		name = function()
			local store = Store()
			local tint = store.tint

			local chosen = {}
			for _, key in ipairs({ "alpha", "beta", "gamma" }) do
				if (store.choices[key]) then chosen[#chosen + 1] = key end
			end

			return string.format(
				L["Colour %.2f %.2f %.2f at %.0f%%. Keybinding %s. Chosen %s"],
				tint[1] or 0, tint[2] or 0, tint[3] or 0, (tint[4] or 1) * 100,
				tostring(store.binding or L["Not bound"]),
				#chosen > 0 and table.concat(chosen, ", ") or L["nothing"])
		end,
		type = "description", fontSize = "medium",
		order = 30
	}

	return options
end

Options:AddGroup(L["Control Types"], GenerateOptions, -3000, "other")

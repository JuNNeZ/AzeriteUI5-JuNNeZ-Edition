--[[

	The MIT License (MIT)

	Copyright (c) 2026 Jonas "JuNNeZ" Andersen

--]]
-- Interface Parts: every part of AzeriteUI that can be turned off, in one list by
-- area (FixLog 2026-11-26).
--
--   Part     a part with no page switch of its own. Stored in the core profile's
--            disabledParts (Core/Core.lua); a part that is off never enables, so
--            Blizzard's own frame stays as Blizzard made it. Turning one on starts
--            it at once where its OnEnable allows (ns:StartPartNow); otherwise, and
--            for turning off, the Reload button lights up.
--   Mirror   the switch a part already has on its own page, drawn by the renderer
--            as that real setting at its real path (Renderer Collect, Config.SetMirror), so
--            gem, revert, combat hold and change counts are the page's own.
--
-- Hovering a switch outlines its part on screen (Renderer Bind, Preview).
-- A part that stands down for another addon (ns.PartStandDowns) says which.
local _, ns = ...

local L = LibStub("AceLocale-3.0"):GetLocale((...))

local Options = ns:GetModule("Options")

-- Read when used: the options kit may load after this file (the offline harnesses).
local Cfg = function()
	return ns.OptionsKit and ns.OptionsKit.Config
end

-- GLOBALS: InCombatLockdown, ReloadUI, WORLD_MAP
-- GLOBALS: SYSTEM_MESSAGES, DURABILITY, HUD_EDIT_MODE_ENCOUNTER_BAR_LABEL, BREATH_LABEL, EXHAUSTION_LABEL
-- GLOBALS: CHAT_MSG_RAID_BOSS_EMOTE, CHAT_MSG_RAID_WARNING, PROFESSIONS_ARCHAEOLOGY

local APP = (...)

-- The names the parts carry as /lock movers, where they have one.
local Label = function(name)
	if (name == "Tooltips") then return L["Tooltips"] end
	if (name == "ChatFrames") then return L["Chat"] end
	if (name == "Containers") then return L["Bags"] end
	if (name == "Tracker") then return L["Objectives Tracker"] end
	if (name == "AlertFrames") then return L["Alerts"] end
	if (name == "ErrorsFrame") then return SYSTEM_MESSAGES or "System Messages" end
	if (name == "PlayerStatusBars") then return L["Experience and reputation bars"] end
	if (name == "Durability") then return DURABILITY or "Durability" end
	if (name == "VehicleSeat") then return L["Vehicle Seat"] end
	if (name == "VehicleExit") then return L["Dismount Button"] end
	if (name == "ExtraActionButtons") then return L["Extra action buttons"] end
	if (name == "EncounterBar") then return HUD_EDIT_MODE_ENCOUNTER_BAR_LABEL or "Encounter Bar" end
	if (name == "MirrorTimers") then
		return (BREATH_LABEL and EXHAUSTION_LABEL) and (BREATH_LABEL .. " / " .. EXHAUSTION_LABEL) or "Breath / Fatigue"
	end
	if (name == "Banners") then return L["Banners"] end
	if (name == "RaidBossEmotes") then return CHAT_MSG_RAID_BOSS_EMOTE or "Boss Emote" end
	if (name == "RaidWarnings") then return CHAT_MSG_RAID_WARNING or "Raid Warning" end
	if (name == "UIWidgetTopCenter") then return L["Widgets: Top"] end
	if (name == "UIWidgetBelowMinimap") then return L["Widgets: Minimap"] end
	if (name == "ArcheologyBar") then return PROFESSIONS_ARCHAEOLOGY or "Archaeology" end
	if (name == "Info") then return L["Info Bar"] end
	if (name == "MythicPlus") then return L["Mythic+"] end
	return name
end

-- Only where switching off does more than hand the part back to Blizzard.
local Desc = function(name)
	if (name == "Containers") then
		return L["Off also removes the Bags page and the group loot settings on it."]
	end
end

--------------------------------------------------------------------------
-- Rows
--------------------------------------------------------------------------
local GetOptions = function()
	return Options.GetOptionsObject and Options:GetOptionsObject() or nil
end

-- The real setting behind a mirror, with the whole table, or nil when it or any
-- group above it is missing or hidden here (another client, class or addon).
local Real = function(path)
	local options, Config = GetOptions(), Cfg()
	if (not Config or not options) then return end
	for i = 1, #path do
		local partial = {}
		for j = 1, i do partial[j] = path[j] end
		local node = Config.GetGroup(options, partial)
		if (type(node) ~= "table") then return end
		local ok, hidden = pcall(Config.IsHidden, node, options, partial, APP)
		if (ok and hidden) then return end
	end
	return Config.GetGroup(options, path), options
end

-- A real switch named only "Enable" takes its group's name: "Player", "Auras".
local MirrorName = function(path)
	local option, options = Real(path)
	if (not option) then return "" end
	local Config = Cfg()
	local name = Config.GetName(option, options, path, APP)
	if (name == L["Enable"] and #path > 1) then
		local parentPath = {}
		for i = 1, #path - 1 do parentPath[i] = path[i] end
		local parent = Config.GetGroup(options, parentPath)
		if (type(parent) == "table") then
			name = Config.GetName(parent, options, parentPath, APP)
		end
	end
	return type(name) == "string" and name or ""
end

-- The panel draws a mirror as its real setting (Renderer Collect, marked with
-- Config.SetMirror: AceConfigRegistry refuses unknown keys on the table itself).
-- Its own get/set/disabled pass through to that setting too, for the classic windows.
local Mirror = function(path, order, label)
	local option = {
		type = "toggle", width = "full", order = order,
		name = function() return label or MirrorName(path) end,
		hidden = function() return Real(path) == nil end,
		disabled = function()
			local option, options = Real(path)
			return not option or Cfg().IsDisabled(option, options, path, APP)
		end,
		get = function()
			local option, options = Real(path)
			return option and Cfg().GetValue(option, options, path, APP) or false
		end,
		set = function(_, value)
			local option, options = Real(path)
			if (option) then Cfg().SetValue(option, options, path, APP, value) end
		end
	}
	local Config = Cfg()
	if (Config and Config.SetMirror) then Config.SetMirror(option, path) end
	return option
end

local Part = function(name, order)
	if (not ns.IsToggleablePart or not ns:IsToggleablePart(name)) then return end
	local present = ns:GetModule(name, true)
	-- A part that stands down for another addon is not even created; say so rather
	-- than leaving it out without a word.
	local standDown = ns:GetPartStandDown(name)
	if (not present and not standDown) then return end

	local option = {
		type = "toggle", width = "full", order = order,
		name = Label(name),
		-- A switch that has not taken effect says so where it is flipped.
		desc = function()
			if (ns:IsPartPending(name)) then return L["Takes effect after a reload."] end
			return Desc(name)
		end,
		disabled = function() return standDown and true or false end,
		get = function()
			if (standDown) then return false end
			return not ns:IsPartDisabled(name)
		end,
		-- Started or stopped at once where the part allows it (Core/Core.lua);
		-- otherwise the reload is owed and the help line says so.
		set = function(_, value)
			ns:SetPartDisabled(name, not value)
			if (value) then
				ns:StartPartNow(name)
			else
				ns:StopPartNow(name)
			end
		end
	}
	local Config = Cfg()
	-- Hovering the switch outlines the part (Renderer Bind, Preview.RequestModule).
	if (present and Config and Config.SetHoverModule) then Config.SetHoverModule(option, name) end
	if (standDown and Config and Config.SetDisabledDesc) then
		Config.SetDisabledDesc(option, function()
			return string.format(L["Off while %s is enabled: it does this job."], standDown)
		end)
	end
	return option
end

--------------------------------------------------------------------------
-- Areas
--------------------------------------------------------------------------
-- Each row is { part = module } or { mirror = real path [, label] }.
local AREAS = {
	{ label = L["Unit Frames"], rows = {
		{ mirror = { "Unit Frames", "player", "enabled" } },
		{ mirror = { "Unit Frames", "playerAlternate", "enabled" } },
		{ mirror = { "Unit Frames", "playerParty", "enabled" } },
		{ mirror = { "Unit Frames", "castbar", "enabled" } },
		-- Named here: its section heading is the module's GetLabel(), not a fixed string.
		{ mirror = { "Unit Frames", "classpower", "enabled" }, label = L["Class Power"] },
		{ mirror = { "Unit Frames", "totems", "enabled" } },
		{ mirror = { "Unit Frames", "pet", "enabled" } },
		{ mirror = { "Unit Frames", "target", "enabled" } },
		{ mirror = { "Unit Frames", "tot", "enabled" } },
		{ mirror = { "Unit Frames", "focus", "enabled" } },
		{ mirror = { "Unit Frames", "boss", "enabled" } },
		{ mirror = { "Unit Frames", "arena", "enabled" } }
	} },
	{ label = L["Group Frames"], rows = {
		{ mirror = { "Group Frames", "party", "enabled" } },
		{ mirror = { "Group Frames", "raid5", "enabled" } },
		{ mirror = { "Group Frames", "raid25", "enabled" } },
		{ mirror = { "Group Frames", "raid40", "enabled" } },
		{ mirror = { "Group Frames", "raidTools", "enabled" } },
		{ mirror = { "Group Frames", "targetMarkersLite", "enabled" } }
	} },
	{ label = L["Action Bars"], rows = {
		{ mirror = { "Action Bars", "bar1", "enabled" } },
		{ mirror = { "Action Bars", "bar2", "enabled" } },
		{ mirror = { "Action Bars", "bar3", "enabled" } },
		{ mirror = { "Action Bars", "bar4", "enabled" } },
		{ mirror = { "Action Bars", "bar5", "enabled" } },
		{ mirror = { "Action Bars", "bar6", "enabled" } },
		{ mirror = { "Action Bars", "bar7", "enabled" } },
		{ mirror = { "Action Bars", "bar8", "enabled" } },
		{ mirror = { "Action Bars", "petbar", "enabled" } },
		{ mirror = { "Action Bars", "stancebar", "enabled" } },
		{ mirror = { "Action Bars", "questItemButton", "enabled" } },
		{ part = "ExtraActionButtons" },
		{ part = "VehicleExit" },
		{ part = "EncounterBar" },
		{ mirror = { "Micro Menu", "enabled" } },
		{ mirror = { "Cooldown Manager", "styleIcons" } }
	} },
	{ label = L["Nameplates"], rows = {
		{ mirror = { "Nameplates", "enabled" } },
		{ mirror = { "Enemy Casts", "enabled" } }
	} },
	{ label = L["Auras"], rows = {
		{ mirror = { "Auras", "enabled" } },
		{ mirror = { "Aura Sounds", "enabled" } }
	} },
	{ label = L["Minimap and Info Bar"], rows = {
		{ mirror = { "Minimap", "enabled" }, label = L["Minimap"] },
		{ part = "Info" },
		{ part = "PlayerStatusBars" },
		{ part = "UIWidgetBelowMinimap" },
		{ part = "Durability" },
		{ part = "VehicleSeat" }
	} },
	{ label = L["World Map and Objectives"], rows = {
		{ mirror = { "World Map", "enabled" }, label = WORLD_MAP or "World Map" },
		{ part = "Tracker" },
		{ part = "UIWidgetTopCenter" },
		{ part = "MythicPlus" },
		{ part = "ArcheologyBar" }
	} },
	{ label = L["Alerts"], rows = {
		{ part = "AlertFrames" },
		{ part = "ErrorsFrame" },
		{ part = "Banners" },
		{ part = "RaidBossEmotes" },
		{ part = "RaidWarnings" },
		{ part = "MirrorTimers" }
	} },
	{ label = L["Interface"], rows = {
		{ part = "Tooltips" },
		{ part = "ChatFrames" },
		{ part = "Containers" }
	} }
}

-- Exposed for Tools/Harness/interface_parts_harness.lua.
ns.InterfacePartsAreas = AREAS

-- Whether any part's switch differs from what is running.
local IsPending = function()
	for _, name in ipairs(ns.ToggleableParts or {}) do
		if (ns:IsPartPending(name)) then return true end
	end
	return false
end

local GenerateOptions = function()
	if (not ns.ToggleableParts or not ns.IsPartPending) then return end

	local options = {
		name = L["Interface Parts"],
		type = "group",
		args = {
			description = {
				name = L["Turn off any part of AzeriteUI you do not want. A part that is off is left to the game: where Blizzard has its own version, it shows as Blizzard made it. Hover a switch to see which part it is."],
				order = 1, type = "description", fontSize = "medium"
			},
			reloadNote = {
				name = L["Most parts come back as soon as you turn them on. Turning a part off is immediate when it only uses AzeriteUI's own frames; one that changes Blizzard's frames needs a reload to give them back as Blizzard made them, and its switch says so. Parts with a page of their own use the same switch as on that page."],
				order = 2, type = "description", fontSize = "medium"
			},
			reload = {
				name = L["Reload UI"], type = "execute", order = 3,
				disabled = function() return InCombatLockdown() or not IsPending() end,
				func = function() if (not InCombatLockdown()) then ReloadUI() end end
			}
		}
	}

	local order = 10
	for index, area in ipairs(AREAS) do
		local headerOrder = order + 1
		order = order + 1
		local rows = {}
		for _, row in ipairs(area.rows) do
			order = order + 1
			local option
			if (row.part) then
				option = Part(row.part, order)
			elseif (row.mirror) then
				option = Mirror(row.mirror, order, row.label)
			end
			if (option) then rows[#rows + 1] = option end
		end
		-- An area with nothing on this client, class or addon set gets no heading.
		if (#rows > 0) then
			options.args["area" .. index] = {
				name = area.label, type = "header", order = headerOrder,
				hidden = function()
					for _, option in ipairs(rows) do
						if (not option.hidden or not option.hidden()) then return false end
					end
					return true
				end
			}
			for i, option in ipairs(rows) do
				options.args["area" .. index .. "row" .. i] = option
			end
		end
	end

	return options
end

Options:AddGroup("Interface Parts", GenerateOptions, -2300, "interface")

--[[

	The MIT License (MIT)

	Copyright (c) 2026 Jonas "JuNNeZ" Andersen

--]]
-- How the options window itself is drawn.
--
-- Two window styles, both in AzeriteUI's own metal:
--
--   "classic"  the window as it has been since Phase 7: a flat fill with the
--              tooltip's sculpted border hung outside it (Kit.WindowCasing).
--   "rounded"  the same border with softly rounded corners, round metal
--              fastenings and a bevel, the window lifted by a soft shadow, the
--              rail set in a rounded well of the aura border, rounded highlights
--              and the addon's bar-small rule between the bands.
--
-- Nothing in "rounded" is new material. Tools/Build-OptionsPanelArt.py copies the
-- straight cells of border-tooltip.tga and border-aura.tga byte for byte and only
-- rebuilds their corner cells, so both edges are drawn as backdrops at the same
-- edge sizes, and the casing keeps every measurement Kit.lua records for it.
-- The casing stays untinted, for the reason Kit.WindowCasingColor gives; the well
-- is tinted like the inset backdrop it replaces.
--
-- Only the window's chrome changes. The controls are Controls.lua's and are the
-- same in both styles. The style is read once, when the window is built, so
-- changing it reloads.
local Addon, ns = ...

local Kit = ns.OptionsKit
if (not Kit) then return end

local L = LibStub("AceLocale-3.0"):GetLocale(Addon)

-- Lua API
local _G = _G
local max = math.max
local pairs = pairs
local type = type

-- GLOBALS: CreateFrame, UIParent, Enum

local Look = {}
Kit.Look = Look

local GetMedia = Kit.GetMedia

Look.DEFAULT = "rounded"

-- Original greyscale page art, built by Tools/Build-OptionsPageIcons.py.
-- Keep this flag and Assets/options-pages.tga together.
Look.PageIconsAvailable = true

--------------------------------------------------------------------------
-- The edges
--------------------------------------------------------------------------
-- The tooltip's border with round corners, drawn exactly as Kit.WindowCasing is:
-- same edge size, same outset, untinted.
Look.CasingBackdrop = {
	edgeFile = GetMedia("options-casing-round"),
	edgeSize = 32
}

-- The window's fill under the rounded casing. Kit.WindowFill reaches 2px past
-- the window so it stays under the square rim at half-pixel scales; under the
-- curve that overhang would put the fill's corners past the rim, so this one
-- stops at the window's edge, where the rim's inner shadow still covers it.
Look.WindowFill = {
	bgFile = GetMedia("plain"),
	insets = { left = 0, right = 0, top = 0, bottom = 0 }
}

-- The aura border with round corners, for the rail well and the search box. The
-- fill starts 7px in rather than Kit.InsetBackdrop's 4, because the rounded rim
-- curves in further than the square one did, and a square fill reaching past the
-- curve shows at each corner.
Look.InsetBackdrop = {
	bgFile = [[Interface\Tooltips\UI-Tooltip-Background]],
	edgeFile = GetMedia("options-well-round"),
	edgeSize = 10,
	insets = { left = 7, right = 7, top = 7, bottom = 7 }
}

--------------------------------------------------------------------------
-- The style
--------------------------------------------------------------------------
local labels = {
	rounded = L["Rounded"],
	classic = L["Classic"]
}

local order = { "rounded", "classic" }

-- What was chosen, as stored. Unknown or missing values are the default.
Look.GetChosenStyle = function()
	local db = ns.db
	local key = db and db.global and db.global.optionsWindowStyle
	return labels[key] and key or Look.DEFAULT
end

Look.GetStyle = function()
	return Look.GetChosenStyle()
end

Look.IsRounded = function()
	return Look.GetStyle() == "rounded"
end

Look.SetStyle = function(key)
	if (not labels[key]) then return false end
	local db = ns.db
	if (not db or not db.global) then return false end
	db.global.optionsWindowStyle = key
	return true
end

-- For the Appearance dropdown, as { key = label } plus the order.
Look.GetStyleChoices = function()
	local values = {}
	for key, label in pairs(labels) do values[key] = label end
	return values, order
end

--------------------------------------------------------------------------
-- Sliced shapes
--------------------------------------------------------------------------
-- The highlights and the shadow are plain white shapes sliced so their corners
-- keep their shape at any size. A client without slicing draws the highlights
-- square and leaves the shadow out, which is how the classic style draws them.
local canSlice
Look.CanSlice = function()
	if (canSlice == nil) then
		local texture = UIParent and UIParent.CreateTexture and UIParent:CreateTexture()
		canSlice = (texture and type(texture.SetTextureSliceMargins) == "function") and true or false
		if (texture and texture.Hide) then texture:Hide() end
	end
	return canSlice
end

local Slice = function(texture, file, margin)
	texture:SetTexture(file)
	texture:SetTextureSliceMargins(margin, margin, margin, margin)
	if (texture.SetTextureSliceMode and Enum and Enum.UITextureSliceMode) then
		texture:SetTextureSliceMode(Enum.UITextureSliceMode.Stretched)
	end
end

-- Turns a highlight texture into a rounded one, in place, so everything that
-- shows, hides and tints it keeps working. Radius 6, slice margin 8, as
-- Tools/Build-OptionsPanelArt.py cuts it.
Look.RoundTexture = function(texture)
	if (Look.CanSlice()) then
		Slice(texture, GetMedia("options-round6-fill"), 8)
	end
	return texture
end

-- A soft shadow under the window, on a frame one level below it so it never
-- covers anything the window draws. It spreads past the casing, not the window,
-- so it reads as the shadow of the metal rather than of the fill inside it.
Look.SHADOW_SPREAD = 18

Look.Shadow = function(frame)
	if (not Look.CanSlice()) then return end

	local outset = Kit.WindowOutset
	local spread = Look.SHADOW_SPREAD

	local holder = CreateFrame("Frame", nil, frame)
	holder:SetPoint("TOPLEFT", frame, "TOPLEFT", -outset.left - spread, outset.top + spread)
	holder:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", outset.right + spread, -outset.bottom - spread)
	holder:SetFrameLevel(max(0, frame:GetFrameLevel() - 1))
	holder:EnableMouse(false)

	local shadow = holder:CreateTexture(nil, "BACKGROUND", nil, -8)
	Slice(shadow, GetMedia("options-shadow"), 40)
	shadow:SetAllPoints(holder)
	shadow:SetVertexColor(0, 0, 0, .75)

	holder.texture = shadow
	return holder
end

-- The rule between the window's bands: the addon's bar-small, the sculpted bar
-- the roadmap artifact uses for its rules, tinted to the theme's border.
Look.Rule = function(parent)
	local rule = parent:CreateTexture(nil, "ARTWORK")
	rule:SetTexture(GetMedia("bar-small"))
	rule:SetHeight(3)
	return rule
end

--------------------------------------------------------------------------
-- Page icons
--------------------------------------------------------------------------
-- options-pages.tga: a 512x256 sheet of 8x4 cells, 64px each, one icon per page,
-- laid out as the handoff draws it. Pages are known by their key in the option
-- table, and several of those keys are localised strings, so the map is built
-- from the same strings the pages register with.
local COLS, ROWS = 8, 4

local cells = {
	quickstart = 0, themes = 1, profiles = 2, sharing = 3,
	unitframes = 4, auras = 5, nameplates = 6, actionbars = 7,
	cooldowns = 8, minimap = 9, mythicplus = 10, worldmap = 11,
	tracker = 12, bags = 13, chat = 14, infobar = 15,
	tooltips = 16, widgets = 17, gamemenu = 18, explorer = 19,
	debug = 20, controltypes = 21, appearance = 22, changelog = 23,
	changed = 24, generic = 25
}
Look.PageIconCells = cells

local byKey
local IconFor = function(key)
	if (not byKey) then
		local views = Kit.Views
		byKey = {
			profiles = "profiles", sharing = "sharing",
			appearance = "appearance", changelog = "changelog",
			["Auras"] = "auras", ["Chat"] = "chat", ["Info Bar"] = "infobar",
			["MythicPlus"] = "mythicplus", ["Themes"] = "themes",
			["Objectives Tracker"] = "tracker", ["Widgets"] = "widgets",
			[L["Action Bars"]] = "actionbars", [L["Bags"]] = "bags",
			[L["Control Types"]] = "controltypes", [L["Cooldown Manager"]] = "cooldowns",
			[L["Debug tools"]] = "debug", [L["Explorer Mode"]] = "explorer",
			[L["Minimap"]] = "minimap", [L["Nameplates"]] = "nameplates",
			[L["Tooltips"]] = "tooltips", [L["Unit Frames"]] = "unitframes"
		}
		-- The keys OptionsPages/GameMenu.lua and WorldMap.lua register with.
		byKey[_G.MAINMENU_BUTTON or "Game Menu"] = "gamemenu"
		if (_G.WORLD_MAP) then byKey[_G.WORLD_MAP] = "worldmap" end
		if (views) then
			if (views.QUICKSTART) then byKey[views.QUICKSTART] = "quickstart" end
			if (views.CHANGED) then byKey[views.CHANGED] = "changed" end
		end
	end
	return byKey[key] or "generic"
end
Look.PageIconFor = IconFor

Look.GetPageIconCoords = function(key)
	local cell = cells[IconFor(key)] or cells.generic
	local col, row = cell % COLS, (cell - cell % COLS) / COLS
	return col / COLS, (col + 1) / COLS, row / ROWS, (row + 1) / ROWS
end

-- Points a texture at a page's icon. Answers false, and leaves the texture
-- alone, while the art has not shipped.
Look.SetPageIcon = function(texture, key)
	if (not Look.PageIconsAvailable or not texture) then return false end
	texture:SetTexture(GetMedia("options-pages"))
	texture:SetTexCoord(Look.GetPageIconCoords(key))
	return true
end

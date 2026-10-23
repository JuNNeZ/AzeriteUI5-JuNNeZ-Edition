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

-- Remember the sheet, not the current theme, so pooled and already visible
-- icons switch instantly along with the text. Texcoords stay the same.
local iconTextures = setmetatable({}, { __mode = "k" })
local SetIconTexture = function(texture, sheet)
	iconTextures[texture] = sheet
	texture:SetTexture(GetMedia(sheet .. (Kit.GetTheme() == "light" and "-light" or "")))
end

Look.RefreshIcons = function()
	for texture, sheet in pairs(iconTextures) do SetIconTexture(texture, sheet) end
end

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
	changed = 24, generic = 25, groupframes = 26, aurasounds = 27,
	micromenu = 28, executerange = 29
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
			[L["Tooltips"]] = "tooltips", [L["Unit Frames"]] = "unitframes",
			[L["Group Frames"]] = "groupframes", [L["Aura Sounds"]] = "aurasounds",
			[L["Micro Menu"]] = "micromenu", [L["Execute range"]] = "executerange"
		}
		-- The keys OptionsPages/GameMenu.lua and WorldMap.lua register with.
		byKey[_G.MAINMENU_BUTTON or "Game Menu"] = "gamemenu"
		if (_G.GAME_MENU) then byKey[_G.GAME_MENU] = "gamemenu" end
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

-- Section icons
--------------------------------------------------------------------------
-- options-sections.tga, built by Tools/Build-OptionsSectionIcons.py: the same
-- 8x8 sheet of 64px cells, for the sections a page lists in the rail and heads
-- on the page. Known by the section's key in the option table, never by its
-- localised name. Several sections share a motif. Icons are for finding your
-- way, not for individual settings; unknown sections have no generic fallback.
local SECTION_COLS, SECTION_ROWS = 8, 8
local sectionCells = {
	player = 0, target = 1, tot = 2, focus = 3, pet = 4, boss = 5, arena = 6, castbar = 7,
	classpower = 8, heal = 9, party = 10, raid = 11, corners = 12, actionbar = 13, stance = 14, proc = 15,
	assist = 16, bell = 17, eye = 18, eyeslash = 19, resize = 20, droplet = 21, funnel = 22, gate = 23,
	friendly = 24, gear = 25, wrench = 26, horseshoe = 27, clock = 28, key = 29,
	hunter = 30, paladin = 31, mage = 32, druid = 33, warrior = 34, crystal = 35,
	orb = 36, leaf = 37, moon = 38, totem = 39, smooth = 40, text = 41,
	sort = 42, anchor = 43, export = 44, import = 45, shield = 46
}
Look.SectionIconCells = sectionCells

-- Section key -> motif. "page:<icon>" borrows a page icon where the section is
-- that page's subject (the Execute range page's Nameplates section).
local SECTION_ICONS = {
	player = "player", playerAlternate = "player", target = "target", tot = "tot", focus = "focus",
	pet = "pet", petbar = "pet", boss = "boss", arena = "arena", otherFights = "arena",
	castbar = "castbar", classpower = "classpower", healthPrediction = "heal", health = "heal",
	party = "party", raid = "raid", raid5 = "raid", raid25 = "raid", raid40 = "raid",
	groupIndicators = "corners", stancebar = "stance", procHighlight = "proc",
	assistedHighlight = "assist", readyAlerts = "bell", visibility = "eye", autoHide = "eyeslash",
	size = "resize", colors = "droplet", auraFilters = "funnel", contentSettings = "gate",
	friendlyPlayers = "friendly", stacking = "gear", advanced = "wrench", utilities = "wrench",
	dismountbutton = "horseshoe", cooldown = "clock", keys = "key",
	threshold = "page:executerange", nameplates = "page:nameplates",
	playerParty = "party", totems = "totem", enemyCastbars = "castbar", names = "text",
	hunter = "hunter", paladin = "paladin", mageTheme = "mage", druid = "druid", warrior = "warrior",
	effects = "proc", mage = "crystal", wildheart = "leaf", moonvein = "moon",
	dreamsap = "droplet", moonwell = "orb", tests = "castbar", smooth = "smooth",
	elementHeader = "page:unitframes", elementsHeader = "page:widgets",
	healthColorsHeader = "droplet", colorHeader = "droplet", themeHeader = "page:themes",
	partyAuraLayoutHeader = "page:auras", partyAuraHeader = "page:auras",
	partyAuraWhatToShowHeader = "funnel", cornerHeader = "corners",
	visibilityHeader = "eye", sortingHeader = "sort", layoutHeader = "page:actionbars",
	anchorHeader = "anchor", castHeader = "castbar", windowHeader = "page:appearance",
	explorermodesituationsheader = "eye", explorermodedelayheader = "clock",
	explorermodeframeheader = "eyeslash", exportHeader = "export", importHeader = "import",
	pvpIndicatorHeader = "arena", playerAuraDebuffsHeader = "page:auras",
	playerAuraWhatToShowHeader = "page:auras", playerAuraLayoutHeader = "page:auras",
	playerAuraSettingsHeader = "page:auras", auraLayoutHeader = "page:auras",
	textHeader = "text", textureHeader = "page:themes", bindHeader = "key",
	multiHeader = "page:tracker", reloadHeader = "shield", fadingHeader = "eyeslash",
	newprofileheader = "page:profiles", header = "eye"
}
Look.SectionIcons = SECTION_ICONS

-- The motif for a section key, or nil. Numbered bars share one.
Look.SectionIconFor = function(key)
	if (type(key) ~= "string") then return end
	if (key:match("^bar%d+$")) then return "actionbar" end
	if (key:match("^slot%d+$")) then return "page:aurasounds" end
	if (key:match("^release%d+$") or key:match("^kind%d+$")) then return "page:changelog" end
	return SECTION_ICONS[key]
end

-- Points a texture at a section's icon. Answers false, and leaves the texture
-- alone, for a section without one or while the art has not shipped.
Look.SetSectionIcon = function(texture, key)
	if (not Look.PageIconsAvailable or not texture) then return false end
	local icon = Look.SectionIconFor(key)
	if (not icon) then return false end
	local pageIcon = icon:match("^page:(.+)$")
	if (pageIcon) then
		local cell = cells[pageIcon]
		if (not cell) then return false end
		local col, row = cell % COLS, (cell - cell % COLS) / COLS
		SetIconTexture(texture, "options-pages")
		texture:SetTexCoord(col / COLS, (col + 1) / COLS, row / ROWS, (row + 1) / ROWS)
		return true
	end
	local cell = sectionCells[icon]
	if (not cell) then return false end
	local col, row = cell % SECTION_COLS, (cell - cell % SECTION_COLS) / SECTION_COLS
	SetIconTexture(texture, "options-sections")
	texture:SetTexCoord(col / SECTION_COLS, (col + 1) / SECTION_COLS, row / SECTION_ROWS, (row + 1) / SECTION_ROWS)
	return true
end

-- Points a texture at a page's icon. Answers false, and leaves the texture
-- alone, while the art has not shipped.
Look.SetPageIcon = function(texture, key)
	if (not Look.PageIconsAvailable or not texture) then return false end
	SetIconTexture(texture, "options-pages")
	texture:SetTexCoord(Look.GetPageIconCoords(key))
	return true
end

--[[

	The MIT License (MIT)

	Copyright (c) 2026 Lars Norberg
	Copyright (c) 2026 Jonas "JuNNeZ" Andersen (JuNNeZ Edition modifications)

	Permission is hereby granted, free of charge, to any person obtaining a copy
	of this software and associated documentation files (the "Software"), to deal
	in the Software without restriction, including without limitation the rights
	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	copies of the Software, and to permit persons to whom the Software is
	furnished to do so, subject to the following conditions:

	The above copyright notice and this permission notice shall be included in all
	copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
	SOFTWARE.

	AzeriteUI art on Blizzard's native controller bars (Forever GamepadUI).

	Blizzard's buttons keep every function: the GAMEPADACTIONBUTTON bindings,
	pages, modifiers, stance/possess bars, radial flyouts and target bars all
	run through GamepadMainActionBarFrame:PressActionButton, which only knows
	its own buttons (Blizzard_GamepadActionBars Bindings.xml, MainActionBarFrame
	PressActionButton). That chain is plain Blizzard Lua that stays secure only
	while nothing it reads was written by an addon, and Blizzard sets every
	button's size and position again on each press and focus change
	(ActionBarStyles.lua ApplyExtraButtonStyles).

	So this file only adds two textures to each button and sets the alpha of
	Blizzard's ring, pushed and drop-shadow art. It writes no fields, methods,
	scripts or attributes on Blizzard's frames, changes no size, point or
	parent, and installs no hook on the press path. The art is anchored to the
	button and cropped to the 64px cell it was painted for, so it follows
	every size Blizzard gives the button (collapsed, expanded, pushed) without
	being told. Refreshes ride the page unit's active-bar callback, which
	Blizzard dispatches through secureexecuterange.

--]]
local _, ns = ...

-- Only in a native controller session, and only while Blizzard's bars are
-- the bars. ConsolePort_Bar and Bartender4 replace them themselves.
local Native = ns.NativeController
if (not Native or not Native.IsActive()) then return end
if (Native.GetConflict and Native.GetConflict()) then return end

local Skin = ns:NewModule("NativeGamepadSkin", "LibMoreEvents-1.0")

-- GLOBALS: C_AddOns, GamepadMainActionBarFrame

-- Lua API
local ipairs = ipairs
local next = next
local pairs = pairs
local setmetatable = setmetatable
local type = type

local ADDON = "Blizzard_GamepadActionBars"

-- Blizzard's own textures our art replaces. Alpha only: the regions stay
-- where they are, and Blizzard keeps setting their atlases.
local HIDDEN_REGIONS = { "NormalTexture", "PushedTexture", "CircleShadow", "SquareShadow" }

local defaults = { profile = { enabled = true } }

-- Button -> our record. Weak keys: nothing is stored on Blizzard's frames.
local skins = setmetatable({}, { __mode = "k" })

-- The circle art for round buttons, the square art for square ones, as
-- Blizzard draws them: the D-pad group square, the face buttons round.
local GetArt = function(shape)
	local db = ns.API.GetShapedButtonConfig(ns.GetConfig("ActionButton"), shape)
	local cell = type(db.ButtonSize) == "table" and db.ButtonSize[1]
	if (type(cell) ~= "number" or cell <= 0) then return end
	local backdrop = type(db.ButtonBackdropSize) == "table" and db.ButtonBackdropSize[1]
	local border = type(db.ButtonBorderSize) == "table" and db.ButtonBorderSize[1]
	if (type(backdrop) ~= "number" or type(border) ~= "number") then return end
	return {
		backdrop = db.ButtonBackdropTexture,
		backdropColor = db.ButtonBackdropColor,
		-- Half the art's width that one cell covers: the crop that maps the
		-- painted cell onto the button. The ring's outer edge lies inside it.
		backdropCrop = .5 * cell / backdrop,
		border = db.ButtonBorderTexture,
		borderColor = db.ButtonBorderColor,
		borderCrop = .5 * cell / border
	}
end

local SetCrop = function(texture, crop)
	local lo, hi = .5 - crop, .5 + crop
	texture:SetTexCoord(lo, hi, lo, hi)
end

local ColorOf = function(color)
	if (type(color) ~= "table") then return 1, 1, 1, 1 end
	return color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1
end

-- Read only. Blizzard keeps the shape in a plain string field.
local GetShape = function(button)
	return (button.activeButtonShape == "Circle") and "circle" or "square"
end

Skin.IsEnabled = function(self)
	return self.db and self.db.profile.enabled and true or false
end

Skin.ApplyShape = function(self, skin, shape)
	local art = self.art and self.art[shape]
	if (not art) then return end
	skin.shape = shape
	skin.backdrop:SetTexture(art.backdrop)
	skin.backdrop:SetVertexColor(ColorOf(art.backdropColor))
	SetCrop(skin.backdrop, art.backdropCrop)
	skin.border:SetTexture(art.border)
	skin.border:SetVertexColor(ColorOf(art.borderColor))
	SetCrop(skin.border, art.borderCrop)
end

-- Builds our two textures on one Blizzard button. CreateTexture adds regions
-- only; no field on the button is written.
Skin.SkinButton = function(self, button)
	if (skins[button]) then return skins[button] end
	if (type(button) ~= "table" or type(button.CreateTexture) ~= "function") then return end

	local skin = { alpha = {} }
	for _, key in ipairs(HIDDEN_REGIONS) do
		local region = button[key]
		if (type(region) == "table" and region.GetAlpha) then
			skin.alpha[region] = region:GetAlpha()
		end
	end

	-- Below Blizzard's icon and shadows (BACKGROUND -1).
	local backdrop = button:CreateTexture(nil, "BACKGROUND", nil, -8)
	backdrop:SetAllPoints(button)
	skin.backdrop = backdrop

	-- Above the icon and flash, below Blizzard's equipped border, its child
	-- frames (cooldown, cast, interrupt and proc effects) and the text overlay.
	local border = button:CreateTexture(nil, "ARTWORK", nil, 7)
	border:SetAllPoints(button)
	skin.border = border

	skins[button] = skin
	return skin
end

Skin.UpdateButton = function(self, button)
	local skin = skins[button]
	if (not skin) then return end
	local enabled = self:IsEnabled()
	if (enabled) then
		local shape = GetShape(button)
		if (skin.shape ~= shape) then self:ApplyShape(skin, shape) end
	end
	skin.backdrop:SetShown(enabled)
	skin.border:SetShown(enabled)
	for region, alpha in pairs(skin.alpha) do
		region:SetAlpha(enabled and 0 or alpha)
	end
end

Skin.UpdateAll = function(self)
	for button in next, skins do
		self:UpdateButton(button)
	end
end

-- Walks the page unit's bars (PageUnit.lua SetupActionBarReferences) and each
-- bar's button list (ActionBar.lua InitActionButtons). Reads only.
Skin.CollectButtons = function(self)
	local frame = GamepadMainActionBarFrame
	local unit = type(frame) == "table" and frame.PageUnit
	local bars = type(unit) == "table" and unit.actionBars
	if (type(bars) ~= "table") then return end
	for _, bar in pairs(bars) do
		local buttons = type(bar) == "table" and bar.actionButtons
		if (type(buttons) == "table") then
			for _, button in ipairs(buttons) do
				self:SkinButton(button)
			end
		end
	end
	return unit
end

Skin.Setup = function(self)
	if (self.unit) then return end
	-- The theme can swap the art at login; build it when the bars are styled.
	self.art = { circle = GetArt(nil), square = GetArt("square") }
	local unit = self:CollectButtons()
	if (not unit) then return end
	self.unit = unit
	if (type(unit.RegisterActiveActionBarUpdatedCallback) == "function") then
		unit:RegisterActiveActionBarUpdatedCallback(function() self:UpdateAll() end, self)
	end
	self:UpdateAll()
end

Skin.Refresh = function(self)
	self.art = { circle = GetArt(nil), square = GetArt("square") }
	for _, skin in next, skins do skin.shape = nil end
	self:UpdateAll()
end

Skin.UpdateSettings = function(self)
	if (self.unit) then self:Refresh() else self:Setup() end
end

Skin.OnEvent = function(self, event, ...)
	if (event == "ADDON_LOADED") then
		if (... ~= ADDON) then return end
		self:UnregisterEvent("ADDON_LOADED", "OnEvent")
	end
	-- A theme can swap the button art at login; the first world entry settles it.
	self:UpdateSettings()
end

Skin.OnInitialize = function(self)
	self.db = ns.db:RegisterNamespace(self:GetName(), defaults)
	self.db.RegisterCallback(self, "OnProfileChanged", "UpdateSettings")
	self.db.RegisterCallback(self, "OnProfileCopied", "UpdateSettings")
	self.db.RegisterCallback(self, "OnProfileReset", "UpdateSettings")
end

Skin.OnEnable = function(self)
	local loaded = C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded(ADDON)
	if (loaded) then
		self:Setup()
	else
		-- The native bars can load after us (not LoadOnDemand, but no order).
		self:RegisterEvent("ADDON_LOADED", "OnEvent")
	end
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEvent")
end

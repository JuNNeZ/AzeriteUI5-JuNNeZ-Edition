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

--]]
local _, ns = ...

local L = LibStub("AceLocale-3.0"):GetLocale((...))

local MovableFramesManager = ns:NewModule("MovableFramesManager", "LibMoreEvents-1.0", "AceConsole-3.0", "AceHook-3.0")

local AceGUI = LibStub("AceGUI-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")

-- Lua API
local error = error
local getmetatable = getmetatable
local math_abs = math.abs
local math_floor = math.floor
local next = next
local pairs = pairs
local rawget = rawget
local select = select
local setmetatable = setmetatable
local string_format = string.format
local string_match = string.match
local table_insert = table.insert
local table_sort = table.sort
local tonumber = tonumber
local tostring = tostring
local type = type
local unpack = unpack

-- GLOBALS: C_Timer, CreateFrame, EditModeManagerFrame, InCombatLockdown, UIParent, WorldFrame

-- Addon API
local Colors = ns.Colors
local GetFont = ns.API.GetFont
local GetMedia = ns.API.GetMedia

-- Constants & Flags
local SCALE = UIParent:GetScale() -- current blizzard scale
local CURRENT -- currently selected anchor frame
local HOVERED -- currently mouseovered anchor frame

-- Outline frame for mouseover events.
local OUTLINE = CreateFrame("Frame", nil, UIParent, ns.BackdropTemplate)
OUTLINE:SetBackdrop({ edgeFile = [[Interface\Tooltips\UI-Tooltip-Border]], edgeSize = 16, insets = { left = 5, right = 3, top = 3, bottom = 5 } })
OUTLINE:SetBackdropBorderColor(Colors.highlight[1], Colors.highlight[2], Colors.highlight[3], .75)
OUTLINE:SetFrameStrata("HIGH")
OUTLINE:SetFrameLevel(10000)

-- Anchor cache
local AnchorData = {}
local AnchorProxies = {}
local KeyedAnchors = {} -- stable key -> anchor, for links (RequestAnchor(key))

-- Links between movers (Docs/Mover Anchoring Plan.md). A follower is placed by its link
-- and saved as a plain UIParent position through MFM_PositionUpdated, like any move.
local LINKS_SUSPENDED -- set while every mover is rescaled at once
local PROPAGATING -- set while followers are being placed, so each pass runs once
-- Set from load until a frame after the first PLAYER_ENTERING_WORLD, and for a frame after a
-- profile change. Movers are created, sized and placed by their modules then, some late
-- (Retail's action bars enable on PLAYER_ENTERING_WORLD), and the UI scale may change under
-- them. Saved positions are already right, so nothing follows anything while settling; at
-- the end each link's offset is taken from the saved positions (SyncLinkOffsets). Placing
-- followers from half-built geometry here pushed linked action bars off screen at login
-- (Luciful, 2026-10-15).
local SETTLING = true

-- Snapping
--------------------------------------
-- Guide lines shown while a dragged mover sits snapped to a line. Plain textures on
-- our own frame; Blizzard's snap preview lines are left alone.
local GUIDES
local GetGuides = function()
	if (GUIDES) then return GUIDES end
	local frame = CreateFrame("Frame", nil, UIParent)
	frame:SetAllPoints()
	frame:SetFrameStrata("HIGH")
	frame:SetFrameLevel(10001)
	frame:EnableMouse(false)
	local vertical = frame:CreateTexture(nil, "OVERLAY")
	vertical:SetColorTexture(Colors.title[1], Colors.title[2], Colors.title[3], .85)
	vertical:SetWidth(2)
	vertical:Hide()
	local horizontal = frame:CreateTexture(nil, "OVERLAY")
	horizontal:SetColorTexture(Colors.title[1], Colors.title[2], Colors.title[3], .85)
	horizontal:SetHeight(2)
	horizontal:Hide()
	GUIDES = { frame = frame, vertical = vertical, horizontal = horizontal }
	return GUIDES
end

local HideGuides = function()
	if (not GUIDES) then return end
	GUIDES.vertical:Hide()
	GUIDES.horizontal:Hide()
end

local ShowGuide = function(texture, isVertical, offset)
	texture:ClearAllPoints()
	if (isVertical) then
		texture:SetPoint("TOP", UIParent, "TOPLEFT", offset, 0)
		texture:SetPoint("BOTTOM", UIParent, "BOTTOMLEFT", offset, 0)
	else
		texture:SetPoint("LEFT", UIParent, "BOTTOMLEFT", 0, offset)
		texture:SetPoint("RIGHT", UIParent, "BOTTOMRIGHT", 0, offset)
	end
	texture:Show()
end

local IsEditModeActive = function()
	local editMode = EditModeManagerFrame
	return editMode and editMode.IsEditModeActive and editMode:IsEditModeActive() and true or false
end

-- Snapping follows our own switch, and while Blizzard's Edit Mode is open also its
-- Enable Snap checkbox. Holding Alt places a frame freely.
local IsSnapEnabled = function()
	local profile = ns.db and ns.db.profile
	if (profile and profile.moverSnapping == false) then return false end
	if (IsAltKeyDown and IsAltKeyDown()) then return false end
	if (IsEditModeActive() and EditModeManagerFrame.IsSnapEnabled) then
		return EditModeManagerFrame:IsSnapEnabled() and true or false
	end
	return true
end

-- The lines a dragged mover may snap to, in UIParent units from its bottom left:
-- the screen's edges and centre, the Edit Mode grid while it is shown, and the
-- edges and centres of every other mover on screen. `exclude` holds movers that
-- move with the dragged one (its followers): snapping to them would chase itself.
-- Built once when a drag starts; nothing else moves while one mover is dragged.
local GetSnapTargets = function(dragged, exclude)
	local uiLeft, uiBottom = UIParent:GetLeft() or 0, UIParent:GetBottom() or 0
	local uiWidth, uiHeight = UIParent:GetWidth(), UIParent:GetHeight()
	local xTargets = { 0, uiWidth / 2, uiWidth }
	local yTargets = { 0, uiHeight / 2, uiHeight }

	local grid = IsEditModeActive() and EditModeManagerFrame.Grid
	if (grid and grid:IsShown() and type(grid.gridSpacing) == "number") then
		ns.API.AddGridLines(xTargets, uiWidth / 2, uiWidth, grid.gridSpacing)
		ns.API.AddGridLines(yTargets, uiHeight / 2, uiHeight, grid.gridSpacing)
	end

	for anchor in next, AnchorData do
		if (anchor ~= dragged and anchor:IsShown() and not (exclude and exclude[anchor])) then
			local left, bottom, width, height = anchor:GetRect()
			if (left and width and width > 0 and height > 0) then
				left, bottom = left - uiLeft, bottom - uiBottom
				xTargets[#xTargets + 1] = left
				xTargets[#xTargets + 1] = left + width / 2
				xTargets[#xTargets + 1] = left + width
				yTargets[#yTargets + 1] = bottom
				yTargets[#yTargets + 1] = bottom + height / 2
				yTargets[#yTargets + 1] = bottom + height
			end
		end
	end
	return xTargets, yTargets
end

-- Utility
--------------------------------------
-- Compare two scales or two positions.
local compare = function(...)
	local numArgs = select("#", ...)
	if (numArgs == 2) then
		local s, s2 = ...
		return (math_abs(s - s2) < 0.01)
	else
		local point, x, y, point2, x2, y2, diff = ...
		return (point == point2) and (math_abs(x - x2) < (diff or 0.01)) and (math_abs(y - y2) < (diff or 0.01))
	end
end

-- Get a properly parsed position of a frame,
-- relative to UIParent and the frame's scale.
local getPosition = function(frame, point)

	-- Retrieve UI coordinates, convert to unscaled screen coordinates
	local worldHeight = 768 -- WorldFrame:GetHeight()
	local worldWidth = WorldFrame:GetWidth()
	local uiScale = UIParent:GetEffectiveScale()
	local uiWidth = UIParent:GetWidth() * uiScale
	local uiHeight = UIParent:GetHeight() * uiScale
	local uiBottom = UIParent:GetBottom() * uiScale
	local uiLeft = UIParent:GetLeft() * uiScale
	local uiTop = UIParent:GetTop() * uiScale - worldHeight -- use values relative to edges, not origin
	local uiRight = UIParent:GetRight() * uiScale - worldWidth -- use values relative to edges, not origin

	-- Retrieve frame coordinates, convert to unscaled screen coordinates
	local frameScale = frame:GetEffectiveScale()
	local x, y = frame:GetCenter(); x = x * frameScale; y = y * frameScale
	local bottom = frame:GetBottom() * frameScale
	local left = frame:GetLeft() * frameScale
	local top = frame:GetTop() * frameScale - worldHeight -- use values relative to edges, not origin
	local right = frame:GetRight() * frameScale - worldWidth -- use values relative to edges, not origin

	-- Figure out the frame position relative to UIParent
	left = left - uiLeft
	bottom = bottom - uiBottom
	right = right - uiRight
	top = top - uiTop

	-- Has this frame requested a specific anchor point?
	-- If so, calculate the coordinates relative to it,
	-- regardless of its position on-screen.
	if (point) then
		if (point == "TOPLEFT") then
			return "TOPLEFT", left / frameScale, top / frameScale

		elseif (point == "TOP") then
			return "TOP", (x - uiWidth/2) / frameScale, top / frameScale

		elseif (point == "TOPRIGHT") then
			return "TOPRIGHT", right / frameScale, top / frameScale

		elseif (point == "RIGHT") then
			return "RIGHT", right / frameScale, (y - uiHeight/2) / frameScale

		elseif (point == "BOTTOMRIGHT") then
			return "BOTTOMRIGHT", right / frameScale, bottom / frameScale

		elseif (point == "BOTTOM") then
			return "BOTTOM", (x - uiWidth/2) / frameScale, bottom / frameScale

		elseif (point == "BOTTOMLEFT") then
			return "BOTTOMLEFT", left / frameScale, bottom / frameScale

		elseif (point == "LEFT") then
			return "LEFT", left / frameScale, (y - uiHeight/2) / frameScale

		elseif (point == "CENTER") then
			return "CENTER", (x - uiWidth/2) / frameScale, (y - uiHeight/2) / frameScale
		end
	end

	-- Figure out the point within the given coordinate space,
	-- return values converted to the frame's own scale.
	--[[
	                  1/3             2/3
	        _______________________________________ uiWidth, uiHeight
	        | TOPLEFT  |     TOP       | TOPRIGHT |
	        |__________|_______________|__________| 3/4
	        |      1/4      CENTER       3/4      |
	        | LEFT  |                     | RIGHT |
	        |       |_________1/3_________|       |
	        |_______|__                 __|_______| 1/4
	        | BOTTOM   |    BOTTOM     |   BOTTOM |
	        |_LEFT_____|_______________|____RIGHT_|
		0,0

	--]]

	-- Top Row
	if (y > uiHeight * 3/4) then

		-- Top Left
		if (x < uiWidth * 1/3) then
			return "TOPLEFT", left / frameScale, top / frameScale

		-- Top Right
		elseif (x > uiWidth * 2/3) then
			return "TOPRIGHT", right / frameScale, top / frameScale

		-- Top Center
		else
			return "TOP", (x - uiWidth/2) / frameScale, top / frameScale
		end

	-- Mid & Bottom Segments
	else

		-- Mid to Bottom Left Columns
		if (x < uiWidth * 1/4) then

			-- Mid Left
			if (y > uiHeight * 1/4) then
				return "LEFT", left / frameScale, (y - uiHeight/2) / frameScale

			-- Bottom Left
			else
				return "BOTTOMLEFT", left / frameScale, bottom / frameScale
			end

		-- Mid to Bottom Right Columns
		elseif (x > uiWidth * 3/4) then

			-- Mid Right
			if (y > uiHeight * 1/4) then
				return "RIGHT", right / frameScale, (y - uiHeight/2) / frameScale

			-- Bottom Right
			else
				return "BOTTOMRIGHT", right / frameScale, bottom / frameScale
			end

		-- Mid and Bottom Center Columns
		else

			-- Center
			if (y > uiHeight * 1/3) then
				return "CENTER", (x - uiWidth/2) / frameScale, (y - uiHeight/2) / frameScale

			-- Bottom Center Segment
			else

				-- Bottom Left
				if (x < uiWidth * 1/3) then
					return "BOTTOMLEFT", left / frameScale, bottom / frameScale

				-- Bottom Right
				elseif (x > uiWidth * 2/3) then
					return "BOTTOMRIGHT", right / frameScale, bottom / frameScale

				-- Bottom Center
				else
					return "BOTTOM", (x - uiWidth/2) / frameScale, bottom / frameScale
				end
			end

		end

	end

end

-- Anchor Template
--------------------------------------
local mt = getmetatable(CreateFrame("Button")).__index
local Anchor = {}

-- Constructor
Anchor.Create = function(self, key)

	local anchor = CreateFrame("Button", nil, UIParent)
	anchor:Hide()
	anchor:SetFrameStrata("HIGH")
	anchor:SetFrameLevel(1000)
	anchor:SetMovable(true)
	anchor:SetClampedToScreen(false)
	anchor:RegisterForDrag("LeftButton")
	anchor:RegisterForClicks("AnyUp")
	anchor:SetScript("OnDragStart", Anchor.OnDragStart)
	anchor:SetScript("OnDragStop", Anchor.OnDragStop)
	anchor:SetScript("OnMouseWheel", Anchor.OnMouseWheel)
	anchor:SetScript("OnClick", Anchor.OnClick)
	anchor:SetScript("OnShow", Anchor.OnShow)
	anchor:SetScript("OnHide", Anchor.OnHide)
	anchor:SetScript("OnEnter", Anchor.OnEnter)
	anchor:SetScript("OnLeave", Anchor.OnLeave)

	for method,func in next,Anchor do
		anchor[method] = func
	end

	local overlay = CreateFrame("Frame", nil, anchor, ns.BackdropTemplate)
	overlay:SetAllPoints()
	overlay:SetBackdrop({
		bgFile =[[Interface\Tooltips\UI-Tooltip-Background]],
		tile = true,
		tileSize = 16,
		edgeFile = [[Interface\Tooltips\UI-Tooltip-Border]],
		edgeSize = 16,
		insets = { left = 5, right = 3, top = 3, bottom = 5 }
	})

	local r, g, b = unpack(Colors.anchor.general)
	overlay:SetBackdropColor(r, g, b, .75)
	overlay:SetBackdropBorderColor(r, g, b, 1)

	anchor.Overlay = overlay

	local text = overlay:CreateFontString(nil, "OVERLAY", nil, 1)
	text:SetFontObject(GetFont(13, true))
	text:SetTextColor(unpack(Colors.highlight))
	text:SetIgnoreParentScale(true)
	text:SetIgnoreParentAlpha(true)
	text:SetJustifyV("MIDDLE")
	text:SetJustifyH("CENTER")
	text:SetPoint("CENTER")
	anchor.Text = text

	local title = overlay:CreateFontString(nil, "OVERLAY", nil, 1)
	title:SetFontObject(GetFont(15, true))
	title:SetTextColor(unpack(Colors.highlight))
	title:SetIgnoreParentScale(true)
	title:SetIgnoreParentAlpha(true)
	title:SetJustifyV("MIDDLE")
	title:SetJustifyH("CENTER")
	title:SetPoint("CENTER")
	title:SetAlpha(.5)
	anchor.Title = title

	AnchorData[anchor] = {
		isMovable = true,
		isScalable = true,
		scale = ns.API.GetEffectiveScale(),
		defaultScale = ns.API.GetEffectiveScale(),
		minScale = .25,
		maxScale = 2.5,
		scaleStep = .1,
		lockAnchorPoint = false,
		colorGroup = "general",
		key = (type(key) == "string" and key ~= "" and not KeyedAnchors[key]) and key or nil
	}
	if (AnchorData[anchor].key) then
		KeyedAnchors[AnchorData[anchor].key] = anchor
	end

	AnchorProxies[overlay] = AnchorData[anchor]

	anchor:Enable()

	return anchor
end

Anchor.Enable = function(self)
	self.enabled = true
	if (MovableFramesManager:IsMFMFrameOpen()) then
		MovableFramesManager:UpdateMovableFrameAnchors()
	end
end

Anchor.Disable = function(self)
	self.enabled = false
	self:Hide()
end

Anchor.IsEnabled = function(self)
	return self.enabled
end

Anchor.SetEnabled = function(self, enable)
	self.enabled = enable and true or false
end

-- 'true' if the frame is in its default position and scale.
Anchor.IsInDefaultPosition = function(self, diff)
	local anchorData = AnchorData[self]
	if (not anchorData.defaultPosition) then return end
	local point2, x2, y2 = self:GetParsedDefaultPosition() -- unpack(anchorData.defaultPosition)
	local point, x, y = getPosition(self, point2) -- compare with same anchor point

	return compare(anchorData.scale, anchorData.defaultScale) and compare(point, x, y, point2, x2, y2, diff)
end

-- 'true' if the frame can be scaled.
Anchor.IsScalable = function(self)
	return AnchorData[self].isScalable
end

-- 'true' if the frame can be moved.
Anchor.IsMovableBase = mt.IsMovable
Anchor.IsMovable = function(self)
	return AnchorData[self].isMovable
end

-- 'true' if set to always obey the same anchor point.
Anchor.IsAnchorPointLocked = function(self)
	return AnchorData[self].lockAnchorPoint and true or false
end

-- 'true' if the frame has moved since last showing the anchor.
Anchor.HasMovedSinceLastUpdate = function(self)
	local anchorData = AnchorData[self]
	if (not anchorData.lastPosition) then return end
	local point, x, y = unpack(anchorData.currentPosition)
	local point2, x2, y2 = unpack(anchorData.lastPosition)
	return not compare(anchorData.scale, anchorData.lastScale or anchorData.defaultScale) or not compare(point, x, y, point2, x2, y2)
end

-- Reset to initial position after last showing the anchor.
Anchor.ResetLastChange = function(self)
	local anchorData = AnchorData[self]
	if (not anchorData.lastPosition) then return end

	local point, x, y = unpack(anchorData.lastPosition)

	anchorData.currentPosition = { point, x, y }

	self:UpdateScale(anchorData.lastScale or anchorData.scale or anchorData.defaultScale)
	self:UpdatePosition(point, x, y)
	self:UpdateText()

	ns:Fire("MFM_PositionUpdated", self, point, x, y, anchorData.scale)
end

-- Reset to default position.
Anchor.ResetToDefault = function(self)
	local anchorData = AnchorData[self]
	if (not anchorData.defaultPosition) then return end

	local point, x, y = self:GetParsedDefaultPosition() -- unpack(anchorData.defaultPosition)

	anchorData.currentPosition = { point, x, y }
	anchorData.lastPosition = { point, x, y }

	self:UpdateScale(anchorData.defaultScale)
	self:UpdatePosition(point, x, y)
	self:UpdateText()

	ns:Fire("MFM_PositionUpdated", self, point, x, y, anchorData.scale)
end

Anchor.UpdateText = function(self)
	local anchorData = AnchorData[self]

	if (not anchorData.currentPosition) then return end

	local msg
	if (self:IsScalable()) then
		msg = string_format(Colors.highlight.colorCode.."%s, %.0f, %.0f ( %.2f )|r", anchorData.currentPosition[1], anchorData.currentPosition[2], anchorData.currentPosition[3], anchorData.scale)
	else
		msg = string_format(Colors.highlight.colorCode.."%s, %.0f, %.0f|r", unpack(anchorData.currentPosition))
	end

	do
		local width,height = self:GetSize()
		if (width/height < .8) and (width > 100) then
			self.Text:SetRotation(-math.pi/2)
			self.Title:SetRotation(-math.pi/2)
		else
			self.Text:SetRotation(0)
			self.Title:SetRotation(0)
		end
	end

	if (self.isSelected) then
		if (self:IsInDefaultPosition()) then
			if (self:IsMovable()) then
				msg = msg .. Colors.green.colorCode.."\n"..L["<Left-Click and drag to move>"].."|r"
			end
			if (self:IsScalable()) then
				msg = msg .. Colors.green.colorCode.."\n"..L["<MouseWheel to change scale>"].."|r"
			end
		else
			if (self:HasMovedSinceLastUpdate()) then
				msg = msg .. Colors.green.colorCode.."\n"..L["<Ctrl and Right-Click to undo last change>"].."|r"
			end
			msg = msg .. Colors.green.colorCode.."\n"..L["<Shift-Click to reset to default>"].."|r"
		end
		self.Title:Hide()
		self.Text:Show()
	else
		self.Title:Show()
		self.Text:Hide()
	end

	self.Text:SetText(msg)

	if (self:IsDragging()) then
		self.Text:SetTextColor(unpack(Colors.normal))
	else
		self.Text:SetTextColor(unpack(Colors.highlight))
	end
end

Anchor.UpdatePosition = function(self, point, x, y)
	local anchorData = AnchorData[self]

	anchorData.currentPosition = { point, x, y }

	self:ClearAllPoints()
	self:SetPointBase(point, UIParent, point, x, y)
	self:UpdateText()

	self.Overlay:SetSize(self:GetSize())
	self.Overlay:ClearAllPoints()
	self.Overlay:SetPoint(point, UIParent, point, x, y)

	ns:Fire("MFM_PositionUpdated", self, point, x, y, anchorData.scale)
end

Anchor.UpdateScale = function(self, scale)
	local anchorData = AnchorData[self]
	if (anchorData.scale == scale) then return end

	anchorData.scale = scale

	if (anchorData.width and anchorData.height) then
		self:SetSizeBase(anchorData.width * anchorData.scale, anchorData.height * anchorData.scale)
		self:UpdateText()

		self.Overlay:SetSize(self:GetSize())
		self.Overlay:ClearAllPoints()
		self.Overlay:SetPoint(self:GetPoint())
	end

	ns:Fire("MFM_ScaleUpdated", self, anchorData.scale)
end

-- Anchor Getters
--------------------------------------
Anchor.GetPosition = function(self)
	local anchorData = AnchorData[self]

	if (not anchorData.currentPosition) then return end

	return anchorData.currentPosition[1], anchorData.currentPosition[2], anchorData.currentPosition[3]
end

Anchor.GetScale = function(self)
	return AnchorData[self].scale
end

Anchor.GetDefaultScale = function(self, scale)
	return AnchorData[self].defaultScale
end

Anchor.GetDefaultPosition = function(self)
	return AnchorData[self].defaultPosition[1], AnchorData[self].defaultPosition[2], AnchorData[self].defaultPosition[3]
end

local dummy = CreateFrame("Frame", nil, UIParent)
dummy:Hide()

Anchor.GetParsedDefaultPosition = function(self)
	local anchorData = AnchorData[self]
	local point, x, y = unpack(anchorData.defaultPosition)

	dummy:Show()
	dummy:ClearAllPoints()
	dummy:SetPoint(point, x, y)
	dummy:SetSize(self:GetSize())

	AnchorProxies[dummy] = anchorData

	point, x, y = getPosition(dummy, point) -- keep relative to default point

	dummy:Hide()

	AnchorProxies[dummy] = nil

	return point, x, y
end

Anchor.GetColorGroup = function(self)
	return AnchorData[self].colorGroup or "general"
end


-- Anchor Setters
--------------------------------------
Anchor.RestrictToHorizontal = function(self)
	AnchorData[self].restrictToHorizontal = true
	AnchorData[self].restrictToVertical = nil
end

Anchor.RestrictToVertical = function(self)
	AnchorData[self].restrictToHorizontal = nil
	AnchorData[self].restrictToVertical = true
end

Anchor.Unrestrict = function(self)
	AnchorData[self].restrictToHorizontal = nil
	AnchorData[self].restrictToVertical = nil
end

Anchor.SetAnchorPointLocked = function(self, isLocked)
	AnchorData[self].lockAnchorPoint = isLocked and true or false
end

-- Scale can still be set and changed,
-- this setting only toggles mousewheel input.
Anchor.SetScalable = function(self, scalable)
	if (scalable) then
		AnchorData[self].isScalable = true
		self:EnableMouseWheel(true)
	else
		AnchorData[self].isScalable = nil
		self:EnableMouseWheel(false)
	end
end

Anchor.SetMovableBase = mt.SetMovable
Anchor.SetMovable = function(self, movable)
	if (movable) then
		AnchorData[self].isMovable = true
	else
		AnchorData[self].isMovable = nil
	end
end

-- Scale can be outside these bounds,
-- they don't even need to exist.
-- This is only for mousewheel input.
Anchor.SetMinMaxScale = function(self, min, max, step)
	local anchorData = AnchorData[self]
	anchorData.minScale = min
	anchorData.maxScale = max
	anchorData.scaleStep = step
end

Anchor.SetDefaultScale = function(self, scale)
	AnchorData[self].defaultScale = scale
end

Anchor.SetDefaultPosition = function(self, point, x, y)
	AnchorData[self].defaultPosition = { point, x, y }
end

-- Don't scale, just size based on it.
Anchor.SetBaseScale = mt.SetScale
Anchor.SetScale = function(self, scale)
	self:UpdateScale(scale)
end

Anchor.SetSizeBase = mt.SetSize
Anchor.SetSize = function(self, width, height)
	local anchorData = AnchorData[self]
	anchorData.width, anchorData.height = width, height
	self:SetSizeBase(width * anchorData.scale, height * anchorData.scale)
end

Anchor.SetWidthBase = mt.SetWidth
Anchor.SetWidth = function(self, width)
	local anchorData = AnchorData[self]
	anchorData.width = width
	self:SetWidthBase(width * anchorData.scale)
	self:UpdateHitRect()
end

Anchor.SetHeightBase = mt.SetHeight
Anchor.SetHeight = function(self, height)
	local anchorData = AnchorData[self]
	anchorData.height = height
	self:SetHeightBase(height * anchorData.scale)
	self:UpdateHitRect()
end

-- A mover under 20 wide or tall gets 10 extra on each side of that axis to click.
-- (SetWidth and SetHeight read the other side from locals that did not exist.)
Anchor.UpdateHitRect = function(self)
	local anchorData = AnchorData[self]
	local width, height = anchorData.width or 0, anchorData.height or 0
	local padX = width < 20 and -10 or 0
	local padY = height < 20 and -10 or 0
	self:SetHitRectInsets(padX, padX, padY, padY)
end

Anchor.SetPointBase = mt.SetPoint
Anchor.SetPoint = function(self, ...)

	-- Set the raw point to what the user has decided.
	self:SetPointBase(...)

	-- Parse the position.
	local point, x, y = getPosition(self, (self:IsAnchorPointLocked() and self:GetPosition()))

	-- Reset the position to our system.
	self:UpdatePosition(point, x, y)

	-- Set this as the default position
	-- if none has been registered so far.
	local anchorData = AnchorData[self]
	if (not anchorData.defaultPosition) then
		anchorData.defaultPosition = { point, x, y }
	end
end

Anchor.SetTitle = function(self, title)
	self.Title:SetText(title)
end

Anchor.SetColorGroup = function(self, colorGroup)

	AnchorData[self].colorGroup = colorGroup and Colors.anchor[colorGroup] and colorGroup or "general"

	local r, g, b = unpack(Colors.anchor[AnchorData[self].colorGroup])
	self.Overlay:SetBackdropColor(r, g, b, .75)
	self.Overlay:SetBackdropBorderColor(r, g, b, 1)
end

-- The frame settings panel (Options/Kit/FramePanel.lua), loaded after us.
local GetFramePanel = function()
	local Kit = ns.OptionsKit
	return Kit and Kit.FramePanel
end

-- Anchor Links
--------------------------------------
-- The links of the HUD in use: Legacy keeps its own positions, so it keeps its own links.
local GetLinks = function(create)
	local profile = ns.db and ns.db.profile
	if (not profile) then return end
	local all = profile.moverLinks
	if (type(all) ~= "table") then
		if (not create) then return end
		all = {}
		profile.moverLinks = all
	end
	local hud = (ns.LegacyHUD and ns.LegacyHUD:IsActive()) and "legacy" or "azerite"
	local links = all[hud]
	if (type(links) ~= "table") then
		if (not create) then return end
		links = {}
		all[hud] = links
	end
	return links
end

-- A mover's rect in UIParent units from its bottom left, read from its saved position
-- and size rather than from the frame, so hidden movers answer too.
local GetAnchorRect = function(anchor)
	local point, x, y = anchor:GetPosition()
	local width, height = anchor:GetSize()
	if (not point or not width or not height or width <= 0 or height <= 0) then return end
	local left, bottom = ns.API.RectFromPoint(point, x, y, width, height, UIParent:GetWidth(), UIParent:GetHeight())
	if (not left) then return end
	return left, bottom, width, height
end

Anchor.GetKey = function(self)
	return AnchorData[self].key
end

-- This mover's link and the mover it follows, if both exist and the target is enabled.
Anchor.GetLink = function(self)
	local key = AnchorData[self].key
	local links = key and GetLinks()
	local link = links and links[key]
	if (type(link) ~= "table") then return end
	local target = KeyedAnchors[link.target]
	return link, (target and target:IsEnabled()) and target or nil
end

-- Places this mover by its link. Keeps its own anchor point, so its saved position keeps
-- the shape its module expects. Returns true if it moved.
Anchor.ApplyLink = function(self)
	local link, target = self:GetLink()
	if (not link or not target) then return end
	local targetLeft, targetBottom, targetWidth, targetHeight = GetAnchorRect(target)
	local width, height = self:GetSize()
	local point, currentX, currentY = self:GetPosition()
	if (not targetLeft or not point or not width or not height) then return end
	local left, bottom = ns.API.LinkedRect(link, targetLeft, targetBottom, targetWidth, targetHeight, width, height)
	if (not left) then return end
	local x, y = ns.API.PointFromRect(point, left, bottom, width, height, UIParent:GetWidth(), UIParent:GetHeight())
	if (not x or compare(point, currentX, currentY, point, x, y)) then return end
	self:UpdatePosition(point, x, y)
	return true
end

-- After the person moves a linked mover, the link keeps it there: its offset is rewritten.
Anchor.UpdateLinkOffset = function(self)
	local link, target = self:GetLink()
	if (not link or not target) then return end
	local targetLeft, targetBottom, targetWidth, targetHeight = GetAnchorRect(target)
	local left, bottom, width, height = GetAnchorRect(self)
	if (not targetLeft or not left) then return end
	local x, y = ns.API.LinkOffset(link.point, link.relativePoint, targetLeft, targetBottom, targetWidth, targetHeight, left, bottom, width, height)
	if (x) then
		link.x = math_floor(x * 100 + .5) / 100
		link.y = math_floor(y * 100 + .5) / 100
	end
end

-- Anchor Script Handlers
--------------------------------------
Anchor.OnClick = function(self, button)
	if (self.PreClick) then
		self:PreClick(button)
	end

	if (button == "LeftButton") then
		if (CURRENT) then
			CURRENT.isSelected = nil
			CURRENT:OnLeave()
		end
		CURRENT = self

		self.isSelected = true
		self:OnEnter()
		self:SetFrameLevel(60)

		if (IsShiftKeyDown() and not self:IsInDefaultPosition()) then
			-- Back to default means back to following nothing.
			if (self:GetLink()) then
				MovableFramesManager:SetAnchorLink(self, nil)
			end
			self:ResetToDefault()
		end

		MovableFramesManager:RefreshMFMFrame()

		-- Like Edit Mode's settings dialog: this frame's settings beside it.
		local panel = GetFramePanel()
		if (panel) then panel:Open(self) end

	elseif (button == "RightButton") then
		if (CURRENT and CURRENT == self) then
			CURRENT = nil
			self.isSelected = nil
			self:OnLeave()

			local panel = GetFramePanel()
			if (panel) then panel:Close() end

			MovableFramesManager:RefreshMFMFrame()
		end
		self:SetFrameLevel(40)

		if (IsControlKeyDown() and self:HasMovedSinceLastUpdate()) then
			self:ResetLastChange()
			self:UpdateLinkOffset()
		end
	end

	if (self.PostClick) then
		self:PostClick(button)
	end
end

Anchor.OnMouseWheel = function(self, delta)
	if (not self.isSelected) then return end

	local anchorData = AnchorData[self]
	local scale = anchorData.scale
	local step = anchorData.scaleStep or .1

	if (delta > 0) then
		if ((scale + step) > anchorData.maxScale) then
			scale = anchorData.maxScale
		else
			scale = scale + step
		end
	elseif (delta < 0) then
		if ((scale - step) < anchorData.minScale) then
			scale = anchorData.minScale
		else
			scale = scale - step
		end
	end
	self:SetScale(scale)

	MovableFramesManager:RefreshMFMFrame()
end

Anchor.OnDragStart = function(self, button)
	local anchorData = AnchorData[self]
	if (not anchorData.isMovable) then return end

	local w, h = self:GetSize()
	local fx, fy = self:GetCenter()
	local frameScale = self:GetEffectiveScale()

	--fx = fx * frameScale
	--fy = fy * frameScale

	anchorData.dragStartPosition = { fx - (w/2), fy - (h/2) }
	anchorData.isDragging = true

	-- Snap lines for this whole drag, leaving out the movers that follow this one.
	local exclude
	local key = anchorData.key
	local links = key and GetLinks()
	if (links and next(links)) then
		exclude = {}
		for _, followerKey in next, ns.API.LinkFollowers(links, key) do
			local follower = KeyedAnchors[followerKey]
			if (follower) then exclude[follower] = true end
		end
	end
	anchorData.snapX, anchorData.snapY = GetSnapTargets(self, exclude)
	--anchorData.dragStartPosition = { fx - (w/2)*frameScale, fy - (h/2)*frameScale }

	-- Treat the dragged frame as clicked.
	if (CURRENT) then
		CURRENT.isSelected = nil
		CURRENT:OnLeave()
	end

	CURRENT = self

	self.isSelected = true
	self:OnEnter()
	self:SetFrameLevel(60)

	-- Start the drag handler.
	self:StartMoving()
	self:SetUserPlaced(false)
	self.elapsed = 0
	self:SetScript("OnUpdate", self.OnUpdate)

	anchorData.hasMoved = true

	MovableFramesManager:RefreshMFMFrame()
end

Anchor.UpdateOverlay = function(self)
	local anchorData = AnchorData[self]

	local w, h = self:GetSize()
	local frameScale = self:GetEffectiveScale()
	local fx, fy = GetCursorPosition()
	fx = fx / frameScale
	fy = fy / frameScale

	fx = anchorData.restrictToVertical and anchorData.dragStartPosition[1] or (fx - (w/2))
	fy = anchorData.restrictToHorizontal and anchorData.dragStartPosition[2] or (fy - (h/2))

	-- Snap an edge or the centre onto a nearby line, per axis, and show where.
	local snappedX, snappedY
	if (IsSnapEnabled()) then
		local range = ns.API.SNAP_RANGE / (UIParent:GetEffectiveScale() or 1)
		local xTargets, yTargets = anchorData.snapX, anchorData.snapY
		if (not xTargets) then
			xTargets, yTargets = GetSnapTargets(self)
		end
		if (not anchorData.restrictToVertical) then
			local delta, line = ns.API.FindSnap(fx, w, xTargets, range)
			if (delta) then fx, snappedX = fx + delta, line end
		end
		if (not anchorData.restrictToHorizontal) then
			local delta, line = ns.API.FindSnap(fy, h, yTargets, range)
			if (delta) then fy, snappedY = fy + delta, line end
		end
	end
	local guides = (snappedX or snappedY or GUIDES) and GetGuides()
	if (guides) then
		if (snappedX) then ShowGuide(guides.vertical, true, snappedX) else guides.vertical:Hide() end
		if (snappedY) then ShowGuide(guides.horizontal, false, snappedY) else guides.horizontal:Hide() end
	end

	self.Overlay:SetSize(w,h)
	self.Overlay:ClearAllPoints()
	self.Overlay:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", fx, fy)

end

Anchor.OnDragStop = function(self)
	local anchorData = AnchorData[self]

	self:StopMovingOrSizing()
	self:SetScript("OnUpdate", nil)
	-- One last pass at the release point, so the frame lands where it snapped
	-- rather than where the last 0.05 s tick left the overlay. Only after a real
	-- drag: a mover that may not move gets OnDragStop too.
	if (anchorData.isDragging) then
		self:UpdateOverlay()
	end
	anchorData.isDragging = nil
	anchorData.snapX, anchorData.snapY = nil, nil
	HideGuides()

	local point, x, y = getPosition(self.Overlay, (self:IsAnchorPointLocked() and self:GetPosition()))

	anchorData.currentPosition = { point, x, y }

	self:UpdatePosition(point, x, y)
	self:UpdateLinkOffset()

	MovableFramesManager:RefreshMFMFrame()
end

Anchor.OnEnter = function(self)
	if (HOVERED ~= self) then
		HOVERED = self
		OUTLINE:ClearAllPoints()
		OUTLINE:SetAllPoints(self.Overlay)
		OUTLINE:Show()
	end
	self:SetAlpha(.75)
	self.Title:SetTextColor(unpack(Colors.normal))
	self.Title:SetAlpha(1)
	self:UpdateText()
end

Anchor.OnLeave = function(self)
	if (HOVERED == self) then
		HOVERED = nil
		OUTLINE:ClearAllPoints()
		OUTLINE:Hide()
	end
	self.Title:SetTextColor(unpack(Colors.highlight))
	self.Title:SetAlpha(.5)
	self:SetAlpha(.25)
	self:UpdateText()
end

Anchor.OnShow = function(self)
	-- Allow modules to position anchor correctly.
	if (self.PreUpdate) then
		self:PreUpdate()
	end

	local anchorData = AnchorData[self]
	local point, x, y = getPosition(self, (self:IsAnchorPointLocked() and self:GetPosition()))

	anchorData.lastScale = anchorData.scale
	anchorData.lastPosition = { point, x, y }
	anchorData.currentPosition = { point, x, y }

	self:SetFrameLevel(50)
	self:SetAlpha(.5)
	self:ClearAllPoints()
	self:SetPointBase(point, UIParent, point, x, y)
	self:UpdateText()

	self.Overlay:SetSize(self:GetSize())
	self.Overlay:ClearAllPoints()
	self.Overlay:SetPoint(point, UIParent, point, x, y)

	ns:Fire("MFM_AnchorShown", self, point, x, y)
end

Anchor.OnHide = function(self)
	self:SetScript("OnUpdate", nil)
	self.elapsed = 0
	HideGuides()
end

Anchor.OnUpdate = function(self, elapsed)
	self.elapsed = self.elapsed + elapsed
	if (self.elapsed < .05) then
		return
	end
	self.elapsed = 0
	self:UpdateOverlay()

	local point, x, y = getPosition(self.Overlay, (self:IsAnchorPointLocked() and self:GetPosition()))

	-- Reuse old table here,
	-- or we'll spam the garbage handler.
	local anchorData = AnchorData[self]
	anchorData.currentPosition[1] = point
	anchorData.currentPosition[2] = x
	anchorData.currentPosition[3] = y

	self:UpdateText()

	ns:Fire("MFM_Dragging", self, point, x, y)
end

-- Module API
--------------------------------------
--- Creates a mover. key is a stable, unlocalized name (the module's, or the module's plus
-- a suffix when it has several); only keyed movers can be linked to one another.
MovableFramesManager.RequestAnchor = function(self, key)
	return Anchor:Create(key)
end

MovableFramesManager.GetAnchorByKey = function(self, key)
	return key and KeyedAnchors[key]
end

--- Links anchor to target so that anchor's point sits on target's relativePoint, keeping
-- anchor where it is now. A nil target removes the link and leaves the frame in place.
-- Returns true, or false and a reason: "combat", "nokey", "cycle", "target", "point".
MovableFramesManager.SetAnchorLink = function(self, anchor, target, point, relativePoint)
	if (InCombatLockdown()) then return false, "combat" end
	local key = anchor and AnchorData[anchor] and AnchorData[anchor].key
	if (not key) then return false, "nokey" end

	if (not target) then
		local links = GetLinks()
		if (links) then links[key] = nil end
		self:RefreshMFMFrame()
		return true
	end

	local targetKey = AnchorData[target] and AnchorData[target].key
	if (not targetKey or not target:IsEnabled()) then return false, "target" end
	point = point or "CENTER"
	relativePoint = relativePoint or point
	if (not ns.API.IsAnchorPoint(point) or not ns.API.IsAnchorPoint(relativePoint)) then return false, "point" end
	local links = GetLinks(true)
	if (not links or ns.API.WouldLinkCycle(links, key, targetKey)) then return false, "cycle" end

	links[key] = { target = targetKey, point = point, relativePoint = relativePoint, x = 0, y = 0 }
	anchor:UpdateLinkOffset()
	self:RefreshMFMFrame()
	return true
end

--- The movers anchor may be linked to: keyed, enabled, and not following anchor.
MovableFramesManager.GetLinkTargets = function(self, anchor)
	local out = {}
	local key = anchor and AnchorData[anchor] and AnchorData[anchor].key
	if (not key) then return out end
	local links = GetLinks()
	for targetKey, target in next, KeyedAnchors do
		if (target ~= anchor and target:IsEnabled() and not ns.API.WouldLinkCycle(links, key, targetKey)) then
			out[#out + 1] = target
		end
	end
	return out
end

-- Places every mover that follows anchor, nearest first, once.
MovableFramesManager.ApplyFollowers = function(self, anchor)
	local key = AnchorData[anchor] and AnchorData[anchor].key
	local links = key and GetLinks()
	if (not links or not next(links)) then return end
	local followers = ns.API.LinkFollowers(links, key)
	if (#followers == 0) then return end
	PROPAGATING = true
	for _, followerKey in next, followers do
		local follower = KeyedAnchors[followerKey]
		if (follower and follower:IsEnabled()) then
			follower:ApplyLink()
		end
	end
	PROPAGATING = nil
end

-- Places every linked mover, targets before their followers. After a rescale and after
-- combat if something waited. Not at login or on a profile change: see SETTLING.
MovableFramesManager.ApplyAllLinks = function(self)
	if (InCombatLockdown()) then
		self.linksPending = true
		return
	end
	self.linksPending = nil
	local links = GetLinks()
	if (not links or not next(links)) then return end
	local order = {}
	for key in next, links do order[#order + 1] = key end
	table_sort(order, function(a, b)
		local da, db = ns.API.LinkDepth(links, a), ns.API.LinkDepth(links, b)
		if (da ~= db) then return da < db end
		return tostring(a) < tostring(b)
	end)
	PROPAGATING = true
	for _, key in next, order do
		local follower = KeyedAnchors[key]
		if (follower and follower:IsEnabled()) then
			follower:ApplyLink()
		end
	end
	PROPAGATING = nil
end

-- A mover moved, rescaled or was shown: its followers go with it. A mover that rescaled
-- is first put back on its own link, since its size changed around its anchor point.
MovableFramesManager.OnMoverChanged = function(self, event, anchor)
	if (SETTLING or LINKS_SUSPENDED or PROPAGATING or not anchor or not AnchorData[anchor]) then return end
	if (InCombatLockdown()) then
		self.linksPending = true
		return
	end
	if (event == "MFM_ScaleUpdated") then
		PROPAGATING = true
		anchor:ApplyLink()
		PROPAGATING = nil
	end
	self:ApplyFollowers(anchor)
end

--- Rewrites every link's offset from where its follower and target are saved, moving nothing.
-- Links whose follower or target is missing or disabled are left as they are.
MovableFramesManager.SyncLinkOffsets = function(self)
	local links = GetLinks()
	if (not links or not next(links)) then return end
	for key in next, links do
		local follower = KeyedAnchors[key]
		if (follower and follower:IsEnabled()) then
			follower:UpdateLinkOffset()
		end
	end
end

MovableFramesManager.IsSettling = function(self)
	return SETTLING and true or false
end

-- After login and profile changes the modules place their movers first, from their saved
-- positions; on the next frame the links take their offsets from those positions.
MovableFramesManager.ScheduleSettle = function(self)
	SETTLING = true
	local settle = function()
		SETTLING = nil
		self:SyncLinkOffsets()
	end
	if (C_Timer and C_Timer.After) then
		C_Timer.After(0, settle)
	else
		settle()
	end
end

MovableFramesManager.GenerateMFMFrame = function(self)
	if (self.appName and AceConfigRegistry:GetOptionsTable(self.appName)) then
		return
	end

	local Options = ns:GetModule("Options", true)
	if (not Options) then return end

	local noselection = function(info)
		return not CURRENT
	end

	local hasselection = function(info)
		return CURRENT
	end

	local getter = function(info)
		if (not CURRENT) then return end

		local point, x, y = CURRENT:GetPosition()
		local scale = CURRENT:GetScale()

		local arg = info[#info]
		if (arg == "point") then
			return point

		elseif (arg == "offsetX") then
			return tostring(math_floor(x * 1000 + .5)/1000)

		elseif (arg == "offsetY") then
			return tostring(math_floor(y * 1000 + .5)/1000)

		elseif (arg == "scale") then
			return tostring(math_floor(scale * 1000 + .5)/1000)
		elseif (arg == "lockAnchorPoint") then
			return AnchorData[CURRENT].lockAnchorPoint
		end
	end

	local setter = function(info,val)
		if (not CURRENT) then return end

		local point, x, y = CURRENT:GetPosition()
		local scale = CURRENT:GetScale()

		local arg = info[#info]
		if (arg == "point") then

			if (CURRENT:IsAnchorPointLocked()) then
				point, x, y = getPosition(CURRENT, val)

				CURRENT:UpdatePosition(point, x, y)
			else
				point = val
			end

		elseif (arg == "offsetX") then

			local val = tonumber((string_match(val,"(-*%d+%.?%d*)")))
			if (not val) then return end

			x = val

		elseif (arg == "offsetY") then

			local val = tonumber((string_match(val,"(-*%d+%.?%d*)")))
			if (not val) then return end

			y = val

		elseif (arg == "scale") then
			local val = tonumber((string_match(val,"(-*%d+%.?%d*)")))
			if (not val) then return end

			scale = val

		elseif (arg == "lockAnchorPoint") then
			CURRENT:SetAnchorPointLocked(val and true or false)
		end

		CURRENT:ClearAllPoints()
		CURRENT:SetPoint(point, x, y)
		CURRENT:SetScale(scale)
		CURRENT:UpdateLinkOffset()
	end

	local validate = function(info,val)
		local val = tonumber((string_match(val,"(-*%d+%.?%d*)")))
		if (val) then return true end
		return L["Only numbers are allowed."]
	end

	local options, orderoffset = Options:GenerateProfileMenu()
	orderoffset = orderoffset + 30

	-- /lock is for placing frames, so its Reset puts only the layout back. The
	-- full reset stays on /az -> Profiles. This table is built fresh per call.
	local profileArgs = options.args.profiles and options.args.profiles.args
	if (profileArgs and profileArgs.reset) then
		profileArgs.reset = {
			name = L["Reset layout"],
			desc = L["Puts every frame back in its default position and removes anchors and AzeriteUI Scale. Every other setting stays as it is. The interface reloads."],
			type = "execute",
			order = profileArgs.reset.order,
			disabled = function() return InCombatLockdown() end,
			confirm = function() return L["Reset the layout of this profile to default? The interface reloads."] end,
			func = function() ns:ResetLayout() end
		}
	end

	-- Frame positioning & scaling.
	options.args.frameSelectionHeader = {
		name = function(info)
			return CURRENT and CURRENT.Title:GetText() or L["Current Frame"]
		end,
		order = orderoffset + 10,
		type = "header",
		--hidden = noselection
	}
	options.args.frameSelection = {
		name = L["Select Frame"],
		order = orderoffset + 11,
		type = "select", style = "dropdown",
		-- Create a table of currently enabled anchors,
		-- use their titles as display names.
		values = function(info)
			local values = { ["N/A"] = L["Nothing Selected"] }
			for anchor in next,AnchorData do
				if (anchor:IsEnabled()) then
					local title = anchor.Title:GetText()
					if (title and title ~= "") then
						values[anchor] = title
					end
				end
			end
			return values
		end,
		-- Create a sorted table of the frame display names.
		sorting = function(info)
			local sorted = {}
			for anchor in next,AnchorData do
				if (anchor:IsEnabled()) then
					local title = anchor.Title:GetText()
					if (title and title ~= "") then
						table_insert(sorted, anchor)
					end
				end
			end
			table_sort(sorted, function(a,b)
				return a.Title:GetText() < b.Title:GetText()
			end)
			table_insert(sorted, 1, "N/A")
			return sorted
		end,
		set = function(info, val)
			if (val == "N/A") then
				if (CURRENT) then
					CURRENT.isSelected = nil
					CURRENT:OnLeave()
					CURRENT = nil

					local panel = GetFramePanel()
					if (panel) then panel:Close() end

					MovableFramesManager:RefreshMFMFrame()
				end
			else
				val:OnClick("LeftButton")
			end
		end,
		get = function(info)
			if (CURRENT) then
				return CURRENT
			else
				return "N/A"
			end
		end
	}
	orderoffset = orderoffset + 20

	-- How movers behave: with Blizzard's Edit Mode, and when dragged near a line.
	options.args.moversHeader = {
		type = "header",
		order = orderoffset + 40,
		name = L["Moving Frames"]
	}
	options.args.moversInEditMode = {
		type = "toggle", width = "full",
		order = orderoffset + 41,
		name = L["Show in Edit Mode"],
		desc = L["Show these frames while Blizzard's Edit Mode is open, so you can move Blizzard's frames and AzeriteUI's together."],
		get = function() return not (ns.db.profile.moversInEditMode == false) end,
		set = function(info, val)
			ns.db.profile.moversInEditMode = val and true or false
			MovableFramesManager:RefreshEditModeAnchors()
		end
	}
	options.args.moverSnapping = {
		type = "toggle", width = "full",
		order = orderoffset + 42,
		name = L["Snap to edges and other frames"],
		desc = L["A dragged frame snaps to the screen's edges and center, to other frames, and to the Edit Mode grid when it is shown. Hold Alt while dragging to place it freely."],
		get = function() return not (ns.db.profile.moverSnapping == false) end,
		set = function(info, val) ns.db.profile.moverSnapping = val and true or false end
	}
	-- Another profile's frame positions, anchors and master scale, nothing else.
	options.args.copyLayout = {
		type = "select", style = "dropdown", width = "full",
		order = orderoffset + 44,
		name = L["Copy layout from"],
		desc = L["Copies frame positions, anchors and AzeriteUI Scale from another profile into this one. Every other setting stays as it is. The interface reloads."],
		disabled = function() return InCombatLockdown() end,
		values = function()
			local values = {}
			local current = ns:GetProfile()
			for _, key in next, ns:GetProfiles() do
				if (key ~= current) then values[key] = key end
			end
			return values
		end,
		get = function() return nil end,
		set = function(info, val) ns:CopyLayout(val) end,
		confirm = function(info, val)
			return string_format(L["Copy the layout from %s into this profile? The interface reloads."], tostring(val))
		end
	}
	-- One slider for the whole layout: every frame's scale and its distance
	-- from its screen anchor grow together, so frames keep their spacing.
	options.args.frameScale = {
		type = "range", width = "full",
		order = orderoffset + 43,
		name = L["AzeriteUI Scale"],
		desc = L["Scales every AzeriteUI frame at once, keeping the layout's proportions. Each frame's own scale still applies on top. Nameplates have their own size settings."],
		min = ns.API.FRAME_SCALE_MIN, max = ns.API.FRAME_SCALE_MAX, softMin = .7, softMax = 1.5, step = .01, bigStep = .05,
		isPercent = true,
		disabled = function() return InCombatLockdown() end,
		get = function() return ns.API.GetFrameScaleMultiplier() end,
		set = function(info, val) MovableFramesManager:SetFrameScale(val) end
	}

	local colorize = function(msg)
		msg = string.gsub(msg, "<", "|cffffd200<")
		msg = string.gsub(msg, ">", ">|r")
		return msg
	end

	-- Guide text when nothing is selected.
	options.args.guideHeader = {
		name = L["Help"],
		order = orderoffset + 89,
		type = "header",
		hidden = hasselection
	}
	options.args.guideText1 = {
		name = colorize(L["<Left-Click> an anchor to select it and raise it."]),
		order = orderoffset + 90,
		type = "description",
		fontSize = "medium",
		hidden = hasselection
	}
	options.args.guideText2 = {
		name = colorize(L["<Right-Click> an anchor to deselect it and/or lower it."]),
		order = orderoffset + 91,
		type = "description",
		fontSize = "medium",
		hidden = hasselection
	}

	options.args.positionDesc = {
		name = L["Fine-tune the position."],
		order = orderoffset + 101,
		type = "description",
		fontSize = "medium",
		hidden = noselection
	}
	local pointValues = {
		["TOPLEFT"] = L["Top-Left Corner"],
		["TOP"] = L["Top Center"],
		["TOPRIGHT"] = L["Top-Right Corner"],
		["RIGHT"] = L["Middle Right Side"],
		["BOTTOMRIGHT"] = L["Bottom-Right Corner"],
		["BOTTOM"] = L["Bottom Center"],
		["BOTTOMLEFT"] = L["Bottom-Left Corner"],
		["LEFT"] = L["Middle Left Side"],
		["CENTER"] = L["Center"]
	}
	options.args.point = {
		name = L["Anchor Point"],
		desc = L["Sets the anchor point."],
		order = orderoffset + 110,
		hidden = noselection,
		type = "select", style = "dropdown",
		values = pointValues,
		set = setter,
		get = getter
	}
	options.args.lockAnchorPoint = {
		name = "Lock Anchor Point",
		desc = "Forces the frame to always use this anchor point regardless of position on-screen.\n\nThis is useful if you wish a frame to always have a certain distance from a specific anchor point regardless of screen size, ratio or scale.\n\nWhen this option is chosen, changing anchor point does not move the frame, but rather recalculates the coordinates relative to that anchor point.",
		order = orderoffset + 111,
		hidden = noselection,
		type = "toggle",
		set = setter,
		get = getter
	}
	options.args.pointSpace = {
		name = "", order = orderoffset + 112, type = "description", hidden = noselection
	}
	options.args.offsetX = {
		name = L["X Offset"],
		desc = L["Sets the horizontal offset from your chosen anchor point. Positive values means right, negative values means left."],
		order = orderoffset + 120,
		type = "input",
		hidden = noselection,
		validate = validate,
		set = setter,
		get = getter
	}
	options.args.offsetY = {
		name = L["Y Offset"],
		desc = L["Sets the vertical offset from your chosen anchor point. Positive values means up, negative values means down."],
		order = orderoffset + 130,
		type = "input",
		hidden = noselection,
		validate = validate,
		set = setter,
		get = getter
	}
	options.args.scale = {
		name = L["Scale"],
		desc = L["Sets the relative scale of this element. Default scale is set to match the ideal size."],
		order = orderoffset + 140,
		type = "range", width = "full", min = 0.25 * 100, max = 2.5 * 100, step = 0.1, bigStep = 1,
		hidden = noselection,
		validate = validate,
		set = function(info,val)
			setter(info,tostring(val/100))
		end,
		get = function(info)
			return tonumber(getter(info)*100)
		end
	}

	-- Anchoring to another AzeriteUI frame (Docs/Mover Anchoring Plan.md). Changing the
	-- target or a point keeps the frame where it is; the offsets move it.
	local nolink = function(info)
		return not CURRENT or not CURRENT:GetLink()
	end
	local cannotlink = function(info)
		return InCombatLockdown() or not CURRENT or not CURRENT:GetKey()
	end
	-- Refusals need no message: the rows are disabled in combat, and loops are not offered.
	local linkSet = function(target, point, relativePoint)
		MovableFramesManager:SetAnchorLink(CURRENT, target, point, relativePoint)
	end
	options.args.anchorTarget = {
		name = L["Anchor To"],
		desc = L["Keeps this frame beside another AzeriteUI frame and moves it when that frame moves. Dragging it changes the distance. Shift-click resets it and removes the anchor."],
		order = orderoffset + 150,
		hidden = noselection,
		disabled = cannotlink,
		type = "select", style = "dropdown", width = "full",
		values = function(info)
			local values = { NONE = L["Not anchored"] }
			for _, target in next, MovableFramesManager:GetLinkTargets(CURRENT) do
				local title = target.Title:GetText()
				values[target:GetKey()] = (title and title ~= "") and title or target:GetKey()
			end
			return values
		end,
		sorting = function(info)
			local sorted = {}
			for _, target in next, MovableFramesManager:GetLinkTargets(CURRENT) do
				sorted[#sorted + 1] = target
			end
			table_sort(sorted, function(a, b)
				return (a.Title:GetText() or a:GetKey()) < (b.Title:GetText() or b:GetKey())
			end)
			for index, target in next, sorted do sorted[index] = target:GetKey() end
			table_insert(sorted, 1, "NONE")
			return sorted
		end,
		get = function(info)
			local link = CURRENT and CURRENT:GetLink()
			return link and link.target or "NONE"
		end,
		set = function(info, val)
			if (not CURRENT) then return end
			if (val == "NONE") then return linkSet(nil) end
			local link = CURRENT:GetLink()
			linkSet(MovableFramesManager:GetAnchorByKey(val), link and link.point, link and link.relativePoint)
		end
	}
	options.args.anchorPoint = {
		name = L["This frame's point"],
		order = orderoffset + 151,
		hidden = nolink, disabled = cannotlink,
		type = "select", style = "dropdown",
		values = pointValues,
		get = function(info) local link = CURRENT and CURRENT:GetLink(); return link and link.point end,
		set = function(info, val)
			local link, target = CURRENT:GetLink()
			if (target) then linkSet(target, val, link.relativePoint) end
		end
	}
	options.args.anchorRelativePoint = {
		name = L["Point on the other frame"],
		order = orderoffset + 152,
		hidden = nolink, disabled = cannotlink,
		type = "select", style = "dropdown",
		values = pointValues,
		get = function(info) local link = CURRENT and CURRENT:GetLink(); return link and link.relativePoint end,
		set = function(info, val)
			local link, target = CURRENT:GetLink()
			if (target) then linkSet(target, link.point, val) end
		end
	}
	local linkOffsetGet = function(info)
		local link = CURRENT and CURRENT:GetLink()
		if (not link) then return end
		local value = (info[#info] == "anchorOffsetX") and link.x or link.y
		return tostring(math_floor((tonumber(value) or 0) * 100 + .5) / 100)
	end
	local linkOffsetSet = function(info, val)
		if (not CURRENT) then return end
		local link, target = CURRENT:GetLink()
		val = tonumber((string_match(val, "(-*%d+%.?%d*)")))
		if (not link or not target or not val or InCombatLockdown()) then return end
		if (info[#info] == "anchorOffsetX") then link.x = val else link.y = val end
		CURRENT:ApplyLink()
		MovableFramesManager:RefreshMFMFrame()
	end
	options.args.anchorOffsetX = {
		name = L["Distance X"],
		desc = L["Distance between the two points. 0 puts them on top of each other."],
		order = orderoffset + 153,
		hidden = nolink, disabled = cannotlink,
		type = "input", validate = validate,
		get = linkOffsetGet, set = linkOffsetSet
	}
	options.args.anchorOffsetY = {
		name = L["Distance Y"],
		desc = L["Distance between the two points. 0 puts them on top of each other."],
		order = orderoffset + 154,
		hidden = nolink, disabled = cannotlink,
		type = "input", validate = validate,
		get = linkOffsetGet, set = linkOffsetSet
	}

	-- The frame settings panel draws these same rows (Options/Kit/FramePanel.lua).
	self.positionOptions = {
		type = "group", name = "",
		args = {
			scale = options.args.scale,
			anchorTarget = options.args.anchorTarget,
			anchorPoint = options.args.anchorPoint,
			anchorRelativePoint = options.args.anchorRelativePoint,
			anchorOffsetX = options.args.anchorOffsetX,
			anchorOffsetY = options.args.anchorOffsetY
		}
	}

	self:SecureHook(self.app.frame, "Show", "UpdateMovableFrameAnchors")
	self:SecureHook(self.app.frame, "Hide", "HideMovableFrameAnchors")

	-- Hook into the blizzard function to close windows on Esc
	-- without tainting their table of special windows to close.
	-- Kindly borrowed this method from AceConfigDialog which also does it.
	if (not self.CloseSpecialWindows) then
		self.CloseSpecialWindows = CloseSpecialWindows
		CloseSpecialWindows = function()
			local found = self.CloseSpecialWindows()
			return self:CloseMFMFrame() or found
		end
	end

	AceConfigRegistry:RegisterOptionsTable(self.appName, options)

	return
end

--- The selected mover's Position rows, as an option table of their own.
MovableFramesManager.GetPositionOptions = function(self)
	if (not self.positionOptions) then
		self:GenerateMFMFrame()
	end
	return self.positionOptions
end

-- Clicks, drag ends, wheel steps and combat changes all ask for a refresh, often several
-- in one frame. Nothing is redrawn unless the /lock window or the frame panel is open,
-- and then once, on the next frame.
MovableFramesManager.RefreshMFMFrame = function(self)
	local panel = GetFramePanel()
	local panelShown = panel and panel:IsShown()
	local windowShown = self.app and self.app.frame and self.app.frame:IsShown()
	if (not panelShown and not windowShown) then return end
	if (self.refreshQueued) then return end
	self.refreshQueued = true
	if (C_Timer and C_Timer.After) then
		C_Timer.After(0, function() self:RefreshMFMFrameNow() end)
	else
		self:RefreshMFMFrameNow()
	end
end

MovableFramesManager.RefreshMFMFrameNow = function(self)
	self.refreshQueued = nil

	local panel = GetFramePanel()
	if (panel) then panel:Refresh() end

	if (AceConfigRegistry:GetOptionsTable(self.appName)) then
		if (self.app.frame:IsShown()) then
			-- When using a custom window for the dialog,
			-- the library's notify callback does not fire for it.
			-- So we need to fake a refresh by hiding and showing.
			if (self:IsHooked(self.app.frame, "Hide")) then
				self:Unhook(self.app.frame, "Hide")
			end
			self.app.frame:Hide()
			self:SecureHook(self.app.frame, "Hide", "HideMovableFrameAnchors")
			self:OpenMFMFrame()
		end
	end
end

MovableFramesManager.OpenMFMFrame = function(self)
	if (not AceConfigRegistry:GetOptionsTable(self.appName)) then
		self:GenerateMFMFrame()
	end
	AceConfigDialog:SetDefaultSize(self.appName, self.app.status.width, self.app.status.height)
	AceConfigDialog:Open(self.appName, self.app)
end

MovableFramesManager.CloseMFMFrame = function(self)
	if (not AceConfigRegistry:GetOptionsTable(self.appName)) then return end
	if (self.app.frame:IsShown()) then
		self.app.frame:Hide()
		return true -- prevents game menu from being shown
	end
end

MovableFramesManager.IsMFMFrameOpen = function(self)
	return self.app.frame:IsShown()
end

MovableFramesManager.ToggleMFMFrame = function(self)
	if (self.app.frame:IsShown()) then
		self:CloseMFMFrame()
	else
		self:OpenMFMFrame()
	end
end

MovableFramesManager.UpdateMovableFrameAnchors = function(self)
	for anchor in next,AnchorData do
		if (anchor:IsEnabled()) then
			anchor:Show()
		end
	end
end

MovableFramesManager.HideMovableFrameAnchors = function(self)
	if (not self.app.frame:IsShown() and not self.editModeShowsAnchors) then
		for anchor in next,AnchorData do
			anchor:Hide()
		end
		local panel = GetFramePanel()
		if (panel) then panel:Close() end
	end
end

-- Blizzard's Edit Mode: our movers come and go with it, so one tool moves both
-- Blizzard's frames and ours. EventRegistry runs these callbacks through
-- securecallfunction (CallbackRegistry.lua, TriggerEvent), so nothing of ours runs
-- inside Edit Mode's own secure walk over its systems, and nothing of Blizzard's
-- is written here. Positions still save to the profile, exactly as in /lock.
MovableFramesManager.OnEditModeEnter = function(self)
	local profile = ns.db and ns.db.profile
	if (profile and profile.moversInEditMode == false) then return end
	self.editModeShowsAnchors = true
	self:UpdateMovableFrameAnchors()
end

MovableFramesManager.OnEditModeExit = function(self)
	if (not self.editModeShowsAnchors) then return end
	self.editModeShowsAnchors = nil
	if (CURRENT) then
		CURRENT.isSelected = nil
		CURRENT:OnLeave()
		CURRENT = nil
	end
	local panel = GetFramePanel()
	if (panel) then panel:Close() end
	HideGuides()
	self:HideMovableFrameAnchors()
end

-- For the /lock window's switch: apply it at once if Edit Mode is already open.
MovableFramesManager.RefreshEditModeAnchors = function(self)
	if (not IsEditModeActive()) then return end
	local profile = ns.db and ns.db.profile
	if (profile and profile.moversInEditMode == false) then
		self:OnEditModeExit()
	else
		self:OnEditModeEnter()
	end
end

MovableFramesManager.OnEvent = function(self, event, ...)
	if (event == "PLAYER_REGEN_DISABLED") then
		self.incombat = true

		if (self:IsMFMFrameOpen()) then
			self:RefreshMFMFrame()
		end

	elseif (event == "PLAYER_REGEN_ENABLED") then
		if (not InCombatLockdown()) then
			self.incombat = nil

			if (self.frameScaleReloadPending) then
				self:OnFrameScaleProfileChanged()
			end

			if (self.linksPending) then
				self:ApplyAllLinks()
			end

			if (self:IsMFMFrameOpen()) then
				self:RefreshMFMFrame()
			end
		end

	elseif (event == "PLAYER_ENTERING_WORLD") then
		self.incombat = InCombatLockdown()
		-- Only the first one: later loading screens put movers back where they are saved.
		if (not self.settledOnce) then
			self.settledOnce = true
			self:ScheduleSettle()
		end
	end

	if (event == "UI_SCALE_CHANGED" or event == "DISPLAY_SIZE_CHANGED") then
		local scale = UIParent:GetScale()
		local factor = SCALE / scale
		SCALE = scale
		self:RescaleAnchors(factor)
	end
end

--- Multiplies every mover's scale and position, current and default, by factor.
-- A UI scale change and the master scale both zoom AzeriteUI this way, so the
-- layout keeps its proportions; each module saves the result through its own
-- MFM_ScaleUpdated / MFM_PositionUpdated handler, then MFM_UIScaleChanged
-- lets it rebuild its defaults.
MovableFramesManager.RescaleAnchors = function(self, factor)
	if (type(factor) ~= "number" or factor <= 0 or factor == 1) then return end

	-- Followers are placed once, after every mover has its new scale and spot.
	LINKS_SUSPENDED = true
	for anchor,anchorData in next,AnchorData do

		local point, x, y = anchor:GetPosition()
		if (point) then
			local nscale = anchor:GetScale() * factor
			local npoint, nx, ny = point, x * factor, y * factor

			anchor:SetScale(nscale)
			anchor:ClearAllPoints()
			anchor:SetPoint(npoint, nx, ny)

			anchorData.lastScale = nscale
			anchorData.lastPosition = { npoint, nx, ny }
			anchorData.currentPosition = { npoint, nx, ny }
		end

		if (anchorData.defaultPosition and anchorData.defaultScale) then
			anchorData.defaultPosition[2] = anchorData.defaultPosition[2] * factor
			anchorData.defaultPosition[3] = anchorData.defaultPosition[3] * factor
			anchorData.defaultScale = anchorData.defaultScale * factor
		end
	end
	LINKS_SUSPENDED = nil

	-- While settling, the links take their offsets from the rescaled positions afterwards.
	-- Scaling them here as well would count movers that do not exist yet.
	if (SETTLING) then
		ns:Fire("MFM_UIScaleChanged")
		return
	end

	local links = GetLinks()
	if (links) then
		for _, link in next, links do
			if (type(link) == "table") then
				link.x = (tonumber(link.x) or 0) * factor
				link.y = (tonumber(link.y) or 0) * factor
			end
		end
	end
	self:ApplyAllLinks()

	ns:Fire("MFM_UIScaleChanged")
end

--- Sets the master scale (a fraction, 1 = normal) and zooms every mover by the change.
-- Refused in combat: the modules would apply it after combat, but the movers would not.
MovableFramesManager.SetFrameScale = function(self, value)
	if (InCombatLockdown()) then return false end
	value = tonumber(value)
	if (not value or not ns.db or not ns.db.profile) then return false end
	local old = ns.API.GetFrameScaleMultiplier()
	ns.db.profile.frameScale = math.max(ns.API.FRAME_SCALE_MIN, math.min(ns.API.FRAME_SCALE_MAX, value))
	local new = ns.API.GetFrameScaleMultiplier()
	self.appliedFrameScale = new
	if (math.abs(new - old) > .0001) then
		self:RescaleAnchors(new / old)
	end
	return true
end

-- A profile change, copy or reset: links of the new profile, then the master scale check.
MovableFramesManager.OnCoreProfileChanged = function(self)
	self:ScheduleSettle()
	self:OnFrameScaleProfileChanged()
end

-- Defaults were generated with the master scale in use at login; another
-- profile's saved positions carry its own. A reload rebuilds both together.
-- OnEvent's PLAYER_REGEN_ENABLED branch retries a reload deferred by combat.
MovableFramesManager.OnFrameScaleProfileChanged = function(self)
	self.frameScaleReloadPending = nil
	if (not self.appliedFrameScale or math.abs(ns.API.GetFrameScaleMultiplier() - self.appliedFrameScale) < .0001) then return end
	if (InCombatLockdown()) then
		self.frameScaleReloadPending = true
		return
	end
	if (C_UI and C_UI.Reload) then C_UI.Reload() elseif (ReloadUI) then ReloadUI() end
end

MovableFramesManager.OnInitialize = function(self)

	SCALE = UIParent:GetScale()

	local app = AceGUI:Create("Frame")
	app:Hide()
	app:SetStatusTable({
		width = 440,
		height = 580,
		left = 160,
		top = UIParent:GetTop() / 2 + 100
	})

	self.app = app
	self.appName = L["Movable Frames Manager"]

	self:RegisterChatCommand("lock", "ToggleMFMFrame")

	-- Retail and Forever both send these from EditModeManagerFrameMixin.
	-- The master scale this session's defaults were generated with.
	self.appliedFrameScale = ns.API.GetFrameScaleMultiplier()
	if (ns.db and ns.db.RegisterCallback) then
		ns.db.RegisterCallback(self, "OnProfileChanged", "OnCoreProfileChanged")
		ns.db.RegisterCallback(self, "OnProfileCopied", "OnCoreProfileChanged")
		ns.db.RegisterCallback(self, "OnProfileReset", "OnCoreProfileChanged")
	end

	-- Linked movers follow their targets (Docs/Mover Anchoring Plan.md).
	ns.RegisterCallback(self, "MFM_PositionUpdated", "OnMoverChanged")
	ns.RegisterCallback(self, "MFM_ScaleUpdated", "OnMoverChanged")
	ns.RegisterCallback(self, "MFM_Dragging", "OnMoverChanged")
	ns.RegisterCallback(self, "MFM_AnchorShown", "OnMoverChanged")

	if (EventRegistry and EventRegistry.RegisterCallback) then
		EventRegistry:RegisterCallback("EditMode.Enter", self.OnEditModeEnter, self)
		EventRegistry:RegisterCallback("EditMode.Exit", self.OnEditModeExit, self)
	end
	self:RegisterEvent("DISPLAY_SIZE_CHANGED", "OnEvent")
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEvent")
	self:RegisterEvent("PLAYER_REGEN_DISABLED", "OnEvent")
	self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnEvent")
	self:RegisterEvent("UI_SCALE_CHANGED", "OnEvent")
end

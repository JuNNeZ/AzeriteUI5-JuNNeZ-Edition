--[[

	The MIT License (MIT)

	Copyright (c) 2026 Jonas "JuNNeZ" Andersen

--]]
-- The frame settings panel: what Edit Mode's settings dialog is for Blizzard's
-- frames, for ours (Docs/Mover Anchoring Plan.md).
--
-- Clicking a /lock mover, in /lock or while Blizzard's Edit Mode is open, opens
-- this beside it. It holds two short pages drawn by the same renderer as /az:
--
--   Position  - the mover's own rows from the /lock window (scale, Anchor To,
--               points, distance), so both edit the same thing
--   Settings  - up to five of that frame's own /az settings, by their real
--               option paths, so a change here is a change there
--
-- and a button to the frame's full /az section. Nothing is copied: a setting
-- that moves or is renamed on its page drops out of this list rather than
-- breaking it (Tools/Harness/frame_panel_harness.lua checks every path).
local Addon, ns = ...

local Kit = ns.OptionsKit
if (not Kit or not Kit.Renderer or not Kit.Config) then return end

local Config, Renderer = Kit.Config, Kit.Renderer

local L = LibStub("AceLocale-3.0"):GetLocale(Addon)

-- Lua API
local ipairs = ipairs
local max = math.max
local pcall = pcall
local tostring = tostring
local type = type
local unpack = unpack

-- GLOBALS: C_Timer, CreateFrame, EditModeManagerFrame, HideUIPanel, InCombatLockdown
-- GLOBALS: securecallfunction, UIParent, UISpecialFrames

local APP = Addon
local WIDTH = 360
local PAD = 16
local BUTTON_HEIGHT = 24

local FramePanel = {}
Kit.FramePanel = FramePanel

--------------------------------------------------------------------------
-- What each frame offers
--------------------------------------------------------------------------
-- Keyed by mover key (RequestAnchor). `section` is the /az page and section
-- "More settings" opens; each row is a path into the real options table, read
-- from the page as it is built. A frame with no entry gets Position only.
local Bar = function(section)
	return {
		section = { "Action Bars", section },
		rows = {
			{ "Action Bars", section, "enabled" },
			{ "Action Bars", section, "numbuttons" },
			{ "Action Bars", section, "layout" },
			{ "Action Bars", section, "enableBarFading" },
			{ "Action Bars", section, "buttonShape" }
		}
	}
end

local Raid = function(section)
	return {
		section = { "Group Frames", section },
		rows = {
			{ "Group Frames", section, "enabled" },
			{ "Group Frames", section, "showPriorityDebuff" },
			{ "Group Frames", section, "useRangeIndicator" },
			{ "Group Frames", section, "useClassColors" },
			{ "Group Frames", section, "sortBy" }
		}
	}
end

FramePanel.Settings = {
	["PetBar"] = Bar("petbar"),
	["StanceBar"] = Bar("stancebar"),
	["PlayerFrame"] = {
		section = { "Unit Frames", "player" },
		rows = {
			{ "Unit Frames", "player", "enabled" },
			{ "Unit Frames", "player", "showAuras" },
			{ "Unit Frames", "player", "showCastbar" },
			{ "Unit Frames", "player", "powerOrbMode" },
			{ "Unit Frames", "player", "showPowerValue" }
		}
	},
	["PlayerFrame.debuffs"] = {
		section = { "Unit Frames", "player" },
		rows = {
			{ "Unit Frames", "player", "playerAuraSeparateDebuffs" },
			{ "Unit Frames", "player", "playerAuraSeparateDebuffsMax" },
			{ "Unit Frames", "player", "playerAuraShowDebuffs" },
			{ "Unit Frames", "player", "playerAuraMaxShown" },
			{ "Unit Frames", "player", "playerAuraAlwaysBright" }
		}
	},
	["PlayerFrame.secondaryMana"] = {
		section = { "Unit Frames", "player" },
		rows = {
			{ "Unit Frames", "player", "powerOrbMode" },
			{ "Unit Frames", "player", "crystalOrbColorMode" },
			{ "Unit Frames", "player", "showPowerValue" },
			{ "Unit Frames", "player", "PowerValueFormat" },
			{ "Unit Frames", "player", "powerValueCombatDriven" }
		}
	},
	["PlayerFrameAlternate"] = {
		section = { "Unit Frames", "playerAlternate" },
		rows = {
			{ "Unit Frames", "playerAlternate", "enabled" },
			{ "Unit Frames", "playerAlternate", "showAuras" },
			{ "Unit Frames", "playerAlternate", "aurasBelowFrame" },
			{ "Unit Frames", "playerAlternate", "showCastbar" },
			{ "Unit Frames", "playerAlternate", "showName" }
		}
	},
	["PlayerFrameParty"] = {
		section = { "Unit Frames", "playerParty" },
		rows = {
			{ "Unit Frames", "playerParty", "enabled" },
			{ "Unit Frames", "playerParty", "showPortrait" },
			{ "Unit Frames", "playerParty", "useClassColor" },
			{ "Explorer Mode", "fadePlayerFrame" }
		}
	},
	["PetFrame"] = {
		section = { "Unit Frames", "pet" },
		rows = {
			{ "Unit Frames", "pet", "enabled" },
			{ "Explorer Mode", "fadePetFrame" }
		}
	},
	["TargetFrame"] = {
		section = { "Unit Frames", "target" },
		rows = {
			{ "Unit Frames", "target", "enabled" },
			{ "Unit Frames", "target", "showAuras" },
			{ "Unit Frames", "target", "showCastbar" },
			{ "Unit Frames", "target", "showHealthPercent" },
			{ "Execute range", "target", "executeMarker" }
		}
	},
	["ToTFrame"] = {
		section = { "Unit Frames", "tot" },
		rows = {
			{ "Unit Frames", "tot", "enabled" },
			{ "Unit Frames", "tot", "hideWhenTargetingPlayer" },
			{ "Unit Frames", "tot", "hideWhenTargetingSelf" }
		}
	},
	["FocusFrame"] = {
		section = { "Unit Frames", "focus" },
		rows = {
			{ "Unit Frames", "focus", "enabled" },
			{ "Explorer Mode", "fadeFocusFrame" }
		}
	},
	["BossFrames"] = {
		section = { "Unit Frames", "boss" },
		rows = {
			{ "Unit Frames", "boss", "enabled" }
		}
	},
	["ArenaFrames"] = {
		section = { "Unit Frames", "arena" },
		rows = {
			{ "Unit Frames", "arena", "enabled" },
			{ "Unit Frames", "arena", "useRangeIndicator" },
			{ "Unit Frames", "arena", "rangeIndicatorRange" },
			{ "Unit Frames", "arena", "showInBattlegrounds" }
		}
	},
	["PlayerCastBarFrame"] = {
		section = { "Unit Frames", "castbar" },
		rows = {
			{ "Unit Frames", "castbar", "enabled" },
			{ "Unit Frames", "castbar", "showDelay" },
			{ "Unit Frames", "colorCastSpellTextByState" }
		}
	},
	["PlayerClassPowerFrame"] = {
		section = { "Unit Frames", "classpower" },
		rows = {
			{ "Unit Frames", "classpower", "enabled" },
			{ "Unit Frames", "classpower", "showFullOutOfCombat" },
			{ "Unit Frames", "classpower", "clickThrough" },
			{ "Explorer Mode", "fadePlayerClassPower" }
		}
	},
	["PartyFrames"] = {
		section = { "Group Frames", "party" },
		rows = {
			{ "Group Frames", "party", "enabled" },
			{ "Group Frames", "party", "showAuras" },
			{ "Group Frames", "party", "useRangeIndicator" },
			{ "Group Frames", "party", "showPlayerInParty" },
			{ "Group Frames", "party", "sortBy" }
		}
	},
	["RaidFrame5"] = {
		section = { "Group Frames", "raid5" },
		rows = {
			{ "Group Frames", "raid5", "enabled" },
			{ "Group Frames", "raid5", "showAuras" },
			{ "Group Frames", "raid5", "useRangeIndicator" },
			{ "Group Frames", "raid5", "useClassColors" },
			{ "Group Frames", "raid5", "sortBy" }
		}
	},
	["RaidFrame25"] = Raid("raid25"),
	["RaidFrame40"] = Raid("raid40"),
	["Minimap"] = {
		section = { "Minimap" },
		rows = {
			{ "Minimap", "enabled" },
			{ "Minimap", "hideAddonText" },
			{ "Minimap", "hideClockText" },
			{ "Minimap", "dielEnabled" },
			{ "Minimap", "autoHide", "autoHideEnabled" }
		}
	},
	["Info"] = {
		section = { "Info Bar" },
		rows = {
			{ "Info Bar", "useHalfClock" },
			{ "Info Bar", "useServerTime" },
			{ "Info Bar", "enableGreatVault" }
		}
	},
	["Auras"] = {
		section = { "Auras" },
		rows = {
			{ "Auras", "enabled" },
			{ "Auras", "enableAuraFading" },
			{ "Auras", "wrapAfter" },
			{ "Auras", "growthX" },
			{ "Auras", "paddingX" }
		}
	},
	["Tooltips"] = {
		section = { "Tooltips" },
		rows = {
			{ "Tooltips", "anchor" },
			{ "Tooltips", "anchorToCursor" },
			{ "Tooltips", "hideInCombat" },
			{ "Tooltips", "showSpellID" },
			{ "Tooltips", "showItemID" }
		}
	},
	["MythicPlus"] = {
		section = { "MythicPlus" },
		rows = {
			{ "MythicPlus", "showTimer" },
			{ "MythicPlus", "showAffixes" },
			{ "MythicPlus", "showForces" },
			{ "MythicPlus", "showBosses" },
			{ "MythicPlus", "showBattleRez" }
		}
	},
	["UIWidgetTopCenter"] = {
		section = { "Widgets" },
		rows = {
			{ "Widgets", "alwaysShow" },
			{ "Widgets", "hideWithTarget" }
		}
	},
	["VehicleExit"] = {
		section = { "Minimap", "dismountbutton" },
		rows = {
			{ "Minimap", "dismountbutton", "useCustomPosition" }
		}
	}
}
for id = 1, 8 do
	FramePanel.Settings["ActionBars.bar" .. id] = Bar("bar" .. id)
end

-- The Position rows, in this order, from the /lock window's own table.
FramePanel.PositionRows = { "scale", "anchorTarget", "anchorPoint", "anchorRelativePoint", "anchorOffsetX", "anchorOffsetY" }

-- Kinds the renderer draws as one row.
local DRAWN = { toggle = true, range = true, select = true, input = true, color = true, execute = true }

--------------------------------------------------------------------------
-- Rows
--------------------------------------------------------------------------
local GetOptions = function()
	local module = ns:GetModule("Options", true)
	return module and module.GetOptionsObject and module:GetOptionsObject() or nil
end

-- One entry for the renderer, or nil when the path leads nowhere drawable or
-- to something hidden right now (another class's class power, say).
local Entry = function(options, path)
	if (type(options) ~= "table" or type(path) ~= "table") then return end
	for i = 1, #path - 1 do
		local group = Config.GetGroup(options, { unpack(path, 1, i) })
		if (type(group) ~= "table") then return end
		local ok, hidden = pcall(Config.IsHidden, group, options, { unpack(path, 1, i) }, APP)
		if (ok and hidden) then return end
	end
	local option = Config.GetGroup(options, path)
	if (type(option) ~= "table" or not DRAWN[option.type]) then return end
	if (option.type == "select" and option.style == "radio") then return end
	local ok, hidden = pcall(Config.IsHidden, option, options, path, APP)
	if (not ok or hidden) then return end
	local copy = {}
	for i = 1, #path do copy[i] = path[i] end
	return { kind = option.type, option = option, path = copy }
end

--- The settings rows a mover would show, as renderer entries. Exposed for the harness.
FramePanel.CollectSettings = function(self, key, options)
	local out = {}
	local spec = key and self.Settings[key]
	options = options or GetOptions()
	if (not spec or not options) then return out end
	for _, path in ipairs(spec.rows) do
		local entry = Entry(options, path)
		if (entry) then out[#out + 1] = entry end
	end
	return out
end

FramePanel.CollectPosition = function(self, options)
	local out = {}
	if (type(options) ~= "table") then return out end
	for _, key in ipairs(self.PositionRows) do
		local entry = Entry(options, { key })
		if (entry) then out[#out + 1] = entry end
	end
	return out
end

--------------------------------------------------------------------------
-- The window
--------------------------------------------------------------------------
local frame, positionPage, settingsPage, moreButton, current
-- Where the panel was dragged to this session (left, top in UIParent units), or nil.
local userPosition

local CreateButton = function(parent, label)
	local button = CreateFrame("Button", nil, parent)
	button:SetHeight(BUTTON_HEIGHT)
	local backdrop = Kit.CreateBackdrop(button, Kit.InsetBackdrop, 1)
	local text = button:CreateFontString(nil, "OVERLAY")
	text:SetFontObject(Kit.GetFont(11))
	text:SetPoint("LEFT", button, "LEFT", 6, 0)
	text:SetPoint("RIGHT", button, "RIGHT", -6, 0)
	text:SetJustifyH("CENTER")
	text:SetWordWrap(false)
	text:SetText(label)
	button.text = text
	button.Restyle = function(self)
		local hover = self:IsEnabled() and self:IsMouseOver()
		backdrop:SetBackdropColor(unpack(Kit.InsetColor))
		Kit.SetBorderColor(backdrop, hover and Kit.BorderHover or Kit.BorderIdle)
		text:SetTextColor(unpack((not self:IsEnabled()) and Kit.TextDisabled
			or hover and Kit.TextHighlight or Kit.TextNormal))
	end
	button:SetScript("OnEnter", button.Restyle)
	button:SetScript("OnLeave", button.Restyle)
	button:SetScript("OnEnable", button.Restyle)
	button:SetScript("OnDisable", button.Restyle)
	return button
end

local CreateHeading = function(parent, label)
	local text = parent:CreateFontString(nil, "OVERLAY")
	text:SetFontObject(Kit.GetFont(13, true))
	text:SetJustifyH("LEFT")
	text:SetText(label)
	return text
end

local Fit

local Build = function()
	local name = ns.Prefix .. "FramePanel"

	frame = CreateFrame("Frame", name, UIParent, ns.BackdropTemplate)
	frame:Hide()
	frame:SetWidth(WIDTH)
	frame:SetFrameStrata("DIALOG")
	frame:SetToplevel(true)
	frame:SetClampedToScreen(true)
	frame:EnableMouse(true)
	-- Dragged like Blizzard's Edit Mode settings dialog, and it stays where it is put
	-- for the rest of the session.
	frame:SetMovable(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
	frame:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		local left, top = self:GetLeft(), self:GetTop()
		if (left and top) then
			userPosition = { left, top }
			self:ClearAllPoints()
			self:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
		end
	end)
	-- The options window's own fill and casing (Panel.lua Build): an opaque plain fill,
	-- so nothing behind it (Edit Mode's dialog) shows through, and the sculpted edge
	-- on a frame of its own. The old tooltip backdrop let the world through.
	local Look = Kit.Look
	local rounded = (Look and Look.IsRounded and Look.IsRounded()) and true or false
	frame:SetBackdrop(rounded and Look.WindowFill or Kit.WindowFill)
	local outset = Kit.WindowOutset
	frame:SetClampRectInsets(-outset.left, outset.right, outset.top, -outset.bottom)
	local casing = CreateFrame("Frame", nil, frame, ns.BackdropTemplate)
	casing:SetPoint("TOPLEFT", frame, "TOPLEFT", -outset.left, outset.top)
	casing:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", outset.right, -outset.bottom)
	casing:SetBackdrop(rounded and Look.CasingBackdrop or Kit.WindowCasing)
	casing:EnableMouse(false)
	frame.casing = casing
	UISpecialFrames[#UISpecialFrames + 1] = name

	local title = frame:CreateFontString(nil, "OVERLAY")
	title:SetFontObject(Kit.GetFont(16, true))
	title:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -PAD)
	title:SetPoint("RIGHT", frame, "RIGHT", -PAD - 26, 0)
	title:SetJustifyH("LEFT")
	title:SetWordWrap(false)
	frame.title = title

	local close = CreateButton(frame, "x")
	close:SetSize(22, 22)
	close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, -12)
	close:SetScript("OnClick", function() FramePanel:Close() end)
	frame.close = close

	frame.positionHeading = CreateHeading(frame, L["Position"])
	frame.settingsHeading = CreateHeading(frame, L["Settings"])

	local positionContent = CreateFrame("Frame", nil, frame)
	positionContent:SetWidth(WIDTH - PAD * 2)
	positionContent:SetHeight(1)
	positionPage = Renderer:CreatePage(positionContent)
	positionPage.stacked = true -- labels and help in full, the control below (Controls SetStacked)
	positionPage.OnChanged = function() C_Timer.After(0, Fit) end
	frame.positionContent = positionContent

	local settingsContent = CreateFrame("Frame", nil, frame)
	settingsContent:SetWidth(WIDTH - PAD * 2)
	settingsContent:SetHeight(1)
	settingsPage = Renderer:CreatePage(settingsContent)
	settingsPage.stacked = true
	settingsPage.OnChanged = function() C_Timer.After(0, Fit) end
	frame.settingsContent = settingsContent

	moreButton = CreateButton(frame, L["More settings"])
	moreButton:SetWidth(140)
	moreButton:SetScript("OnClick", function() FramePanel:OpenMore() end)

	frame:RegisterEvent("PLAYER_REGEN_DISABLED")
	frame:RegisterEvent("PLAYER_REGEN_ENABLED")
	frame:SetScript("OnEvent", function()
		if (frame:IsShown()) then FramePanel:Refresh() end
	end)
	frame:SetScript("OnHide", function()
		current = nil
	end)
end

-- Stacks the title, Position, Settings and the button, and sizes the window.
Fit = function()
	if (not frame or not frame:IsShown()) then return end

	local offset = PAD + 16 + 12

	frame.positionHeading:ClearAllPoints()
	frame.positionHeading:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -offset)
	offset = offset + 18
	frame.positionContent:ClearAllPoints()
	frame.positionContent:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -offset)
	offset = offset + max(1, positionPage:Layout()) + 10

	local hasSettings = #(settingsPage.controls or {}) > 0
	frame.settingsHeading:SetShown(hasSettings)
	frame.settingsContent:SetShown(hasSettings)
	if (hasSettings) then
		frame.settingsHeading:ClearAllPoints()
		frame.settingsHeading:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -offset)
		offset = offset + 18
		frame.settingsContent:ClearAllPoints()
		frame.settingsContent:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -offset)
		offset = offset + max(1, settingsPage:Layout()) + 10
	end

	local spec = current and FramePanel.Settings[current:GetKey() or ""]
	moreButton:SetShown(spec and spec.section and true or false)
	moreButton:ClearAllPoints()
	moreButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PAD, -offset)
	if (moreButton:IsShown()) then offset = offset + BUTTON_HEIGHT end

	frame:SetHeight(offset + PAD)
end

local Restyle = function()
	-- Opaque whatever the options window's own opacity is: this sits over Edit Mode.
	local c = Kit.WindowColor
	frame:SetBackdropColor(c[1] or 0, c[2] or 0, c[3] or 0, 1)
	if (frame.casing) then
		frame.casing:SetBackdropBorderColor(unpack(Kit.WindowCasingColor))
		-- Above the rows, as the options window raises its casing.
		frame.casing:SetFrameLevel(frame:GetFrameLevel() + 20)
	end
	frame.title:SetTextColor(unpack(Kit.TextSelected))
	frame.positionHeading:SetTextColor(unpack(Kit.TextSelected))
	frame.settingsHeading:SetTextColor(unpack(Kit.TextSelected))
	frame.close:Restyle()
	moreButton:Restyle()
	positionPage:Restyle()
	settingsPage:Restyle()
end

-- Where the panel opens: beside the mover, on whichever side has room, top level with
-- it. It is placed at fixed screen coordinates, not anchored to the mover, so changing
-- the frame's scale or dragging it does not drag the panel along (as Blizzard's Edit
-- Mode settings dialog stays put). A position the panel was dragged to wins.
local Place = function(anchor)
	frame:ClearAllPoints()
	if (userPosition) then
		frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", userPosition[1], userPosition[2])
		return
	end
	local target = anchor and (anchor.Overlay or anchor)
	local left, right, top = target and target.GetLeft and target:GetLeft(), target and target.GetRight and target:GetRight(), target and target.GetTop and target:GetTop()
	if (type(left) ~= "number" or type(right) ~= "number" or type(top) ~= "number") then
		frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
		return
	end
	local width = UIParent:GetWidth() or 0
	local x = (right + 12 + WIDTH <= width) and (right + 12) or (left - 12 - WIDTH)
	frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, top)
end

--------------------------------------------------------------------------
-- Public
--------------------------------------------------------------------------
--- Opens the panel for a mover. Returns true when it is shown.
FramePanel.Open = function(self, anchor)
	if (not anchor) then return false end
	local manager = ns:GetModule("MovableFramesManager", true)
	local positionOptions = manager and manager.GetPositionOptions and manager:GetPositionOptions()
	if (not positionOptions) then return false end

	if (not frame) then
		local ok, err = pcall(Build)
		if (not ok) then
			frame = nil
			ns:Print("The frame settings panel could not be built:", tostring(err))
			return false
		end
	end

	if (Kit.Panel and Kit.Panel.LoadTheme) then Kit.Panel:LoadTheme() end

	-- Already open for another frame: it stays where it is and only changes content.
	local wasShown = frame:IsShown()
	current = anchor
	frame.title:SetText(anchor.Title and anchor.Title:GetText() or "")
	frame:Show()
	frame:Raise()

	local key = anchor:GetKey()
	positionPage:ShowList(positionOptions, function() return FramePanel:CollectPosition(positionOptions) end)
	local options = GetOptions()
	if (options) then
		settingsPage:ShowList(options, function() return FramePanel:CollectSettings(key, options) end)
	else
		settingsPage:Clear()
	end

	if (not wasShown) then Place(anchor) end
	Restyle()
	Fit()
	return true
end

--- Re-reads every row, for when the mover moved or combat began or ended.
FramePanel.Refresh = function(self)
	if (not frame or not frame:IsShown() or not current) then return end
	positionPage:Refresh()
	settingsPage:Refresh()
	Restyle()
	Fit()
end

--- Kept for callers: the panel no longer follows its mover once it is open (Place).
FramePanel.Reposition = function(self)
end

FramePanel.Close = function(self)
	if (frame) then frame:Hide() end
end

FramePanel.IsShown = function(self)
	return frame and frame:IsShown() and true or false
end

FramePanel.GetAnchor = function(self)
	return current
end

--- Opens the frame's section on /az.
FramePanel.OpenMore = function(self)
	local spec = current and self.Settings[current:GetKey() or ""]
	local panel = Kit.Panel
	if (not spec or not spec.section or not panel) then return end

	-- The full settings take over: this panel closes, and Blizzard's Edit Mode closes
	-- too when it is open, out of combat only. Through its own close path (the X and
	-- Escape use it), so unsaved Edit Mode changes bring up Blizzard's own "unsaved
	-- changes" dialog instead of being thrown away. securecallfunction keeps whatever
	-- that runs from coming back into this code.
	self:Close()
	local editMode = EditModeManagerFrame
	if (type(editMode) == "table" and editMode.IsEditModeActive and editMode:IsEditModeActive() and not InCombatLockdown()) then
		local close = editMode.onCloseCallback
		if (type(close) == "function") then
			if (securecallfunction) then securecallfunction(close) else close() end
		elseif (HideUIPanel) then
			HideUIPanel(editMode)
		end
	end

	if (panel.SetTab) then panel:SetTab("options") end
	panel:OpenSection(spec.section[1], spec.section)
end

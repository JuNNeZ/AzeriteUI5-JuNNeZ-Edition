-- Shared cosmetic proc styling. LAB still owns activation and deactivation.
local _, ns = ...
local L = LibStub("AceLocale-3.0"):GetLocale((...))
local GetMedia = ns.API.GetMedia
local Highlight = {}
ns.ActionBarProcHighlight = Highlight

Highlight.defaults = {
	procHighlightStyle = "current",
	procHighlightThickness = "medium",
	procHighlightColorSource = "gold",
	procHighlightColor = { 249/255, 188/255, 65/255 },
	procHighlightOpacity = .75
}

local styles = { current = true, outline = true, glow = true, both = true, off = true }
local widths = { thin = true, medium = true, thick = true }
local sources = { gold = true, class = true, custom = true }
local gold = Highlight.defaults.procHighlightColor
local function channel(value, fallback)
	if (type(value) ~= "number" or value ~= value) then return fallback end
	return math.max(0, math.min(1, value))
end

function Highlight.GetCustomColor(profile)
	local color = type(profile.procHighlightColor) == "table" and profile.procHighlightColor or gold
	return channel(color[1], gold[1]), channel(color[2], gold[2]), channel(color[3], gold[3])
end

-- A single normal frame supplies the texture-compatible methods LAB's public
-- spell activation API uses. Its children inherit Show/Hide, so a settings
-- change never invents a proc or loses an active proc (including while Off).
function Highlight.Create(parent, db)
	local alert = CreateFrame("Frame", nil, parent)
	alert:SetFrameLevel(parent:GetFrameLevel())
	alert:SetSize(unpack(db.ButtonSpellHighlightSize))
	alert:SetPoint(unpack(db.ButtonSpellHighlightPosition))
	alert:EnableMouse(false)
	alert.ring = alert:CreateTexture(nil, "ARTWORK", nil, -6)
	alert.ring:SetAllPoints()
	alert.halo = alert:CreateTexture(nil, "ARTWORK", nil, -7)
	alert.halo:SetAllPoints()
	alert.halo:SetBlendMode("ADD")
	alert.legacyTexture = db.ButtonSpellHighlightTexture
	alert.SetTexture = function(self, texture) self.ring:SetTexture(texture) end
	alert.SetVertexColor = function(self, r, g, b, a)
		self.ring:SetVertexColor(r, g, b, a or .75)
		self.halo:SetVertexColor(r, g, b, a or .75)
	end
	alert:Hide()
	return alert
end

function Highlight.Apply(alert, profile)
	profile = profile or {}
	local style = styles[profile.procHighlightStyle] and profile.procHighlightStyle or "current"
	local thickness = widths[profile.procHighlightThickness] and profile.procHighlightThickness or "medium"
	local source = sources[profile.procHighlightColorSource] and profile.procHighlightColorSource or "gold"
	local color = gold
	if (source == "class") then
		color = (ns.Colors.class and ns.Colors.class[ns.PlayerClass]) or gold
	elseif (source == "custom" and type(profile.procHighlightColor) == "table") then
		color = profile.procHighlightColor
	end
	local opacity = channel(profile.procHighlightOpacity, .75)
	local legacy = style == "current" and source == "gold"
	alert:SetTexture(legacy and alert.legacyTexture or GetMedia("actionbutton-proc-outline-"..(style == "current" and "thin" or thickness)))
	alert.halo:SetTexture(GetMedia("actionbutton-proc-glow-"..thickness))
	alert:SetVertexColor(channel(color[1], gold[1]), channel(color[2], gold[2]), channel(color[3], gold[3]), opacity)
	alert.ring:SetShown(style == "current" or style == "outline" or style == "both")
	alert.halo:SetShown(style == "glow" or style == "both")
end

-- An isolated sample, never a forced glow on a live/protected action button.
-- It stays open beside the options and redraws whenever the settings change.
function Highlight.Preview(profile)
	if (not Highlight.preview) then
		local frame = CreateFrame("Frame", ns.Prefix.."ProcHighlightPreview", UIParent, "BackdropTemplate")
		frame:SetSize(200, 190)
		frame:SetPoint("CENTER", UIParent, "CENTER", 360, 0)
		frame:SetFrameStrata("DIALOG")
		frame:SetBackdrop({ bgFile = GetMedia("plain"), edgeFile = GetMedia("plain"), edgeSize = 1 })
		frame:SetBackdropColor(.06, .06, .06, .95)
		frame:SetBackdropBorderColor(.6, .5, .3, 1)
		frame:SetClampedToScreen(true)
		frame:SetMovable(true)
		frame:EnableMouse(true)
		frame:RegisterForDrag("LeftButton")
		frame:SetScript("OnDragStart", frame.StartMoving)
		frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
		table.insert(UISpecialFrames, frame:GetName())
		local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		title:SetPoint("TOP", 0, -12)
		title:SetWidth(140)
		title:SetText(L["Proc Highlight"])
		local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
		close:SetPoint("TOPRIGHT", 0, 0)
		close:SetScript("OnClick", function() frame:Hide() end)
		local db = ns.GetConfig("ActionButton")
		local sample = CreateFrame("Frame", nil, frame)
		sample:SetSize(unpack(db.ButtonSize))
		sample:SetPoint("CENTER", 0, -8)
		local back = sample:CreateTexture(nil, "BACKGROUND")
		back:SetTexture(db.ButtonBackdropTexture)
		back:SetSize(unpack(db.ButtonBackdropSize))
		back:SetPoint(unpack(db.ButtonBackdropPosition))
		back:SetVertexColor(unpack(db.ButtonBackdropColor))
		local icon = sample:CreateTexture(nil, "BACKGROUND", nil, 1)
		icon:SetTexture([[Interface\Icons\ability_hunter_cobrashot]])
		icon:SetSize(unpack(db.ButtonIconSize))
		icon:SetPoint(unpack(db.ButtonIconPosition))
		icon:SetMask(db.ButtonMaskTexture)
		local border = sample:CreateTexture(nil, "BORDER")
		border:SetTexture(db.ButtonBorderTexture)
		border:SetSize(unpack(db.ButtonBorderSize))
		border:SetPoint(unpack(db.ButtonBorderPosition))
		border:SetVertexColor(unpack(db.ButtonBorderColor))
		frame.alert = Highlight.Create(sample, db)
		frame.alert:Show()
		local note = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		note:SetPoint("BOTTOM", 0, 12)
		note:SetWidth(176)
		note:SetText(L["Sample only; no ability is activated."])
		Highlight.preview = frame
	end
	Highlight.Apply(Highlight.preview.alert, profile)
	Highlight.preview:Show()
end

function Highlight.UpdatePreview(profile)
	if (Highlight.preview and Highlight.preview:IsShown()) then
		Highlight.Apply(Highlight.preview.alert, profile)
	end
end

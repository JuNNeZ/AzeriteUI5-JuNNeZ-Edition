-- Shared cosmetic styling for two button highlights: the proc alert (spell
-- activation) and the assisted combat suggestion. LAB still owns activation and
-- deactivation of both; this only decides what each looks like.
--
--   ns.ActionBarProcHighlight      profile keys procHighlight*
--   ns.ActionBarAssistedHighlight  profile keys assistedHighlight*
--
-- Both draw from the same neutral textures (Tools/Build-ProcHighlightAssets.py)
-- and keep separate settings, so a proc and a suggestion stay told apart.
local _, ns = ...
local L = LibStub("AceLocale-3.0"):GetLocale((...))
local GetMedia = ns.API.GetMedia

local styles = { current = true, outline = true, glow = true, both = true, off = true }
local widths = { thin = true, medium = true, thick = true }
local function channel(value, fallback)
	if (type(value) ~= "number" or value ~= value) then return fallback end
	return math.max(0, math.min(1, value))
end

-- spec.prefix         the profile keys' prefix
-- spec.defaults       those keys' defaults
-- spec.base           the colour source meaning "this highlight's own colour"
-- spec.keepArt        "current" keeps the original art whatever the colour (it is
--                     neutral, so any tint reads true); otherwise only the base
--                     colour keeps it, and any other colour uses the neutral ring
-- spec.legacyTexture  function(db) returning the original art for this button
-- spec.title, spec.previewName, spec.previewOffset, spec.icon  the preview window
local function New(spec)
	local Highlight = {}
	local key = {
		style = spec.prefix.."Style", thickness = spec.prefix.."Thickness",
		source = spec.prefix.."ColorSource", color = spec.prefix.."Color", opacity = spec.prefix.."Opacity"
	}
	Highlight.keys = key
	Highlight.defaults = spec.defaults
	local base = spec.defaults[key.color]
	local defaultOpacity = spec.defaults[key.opacity]
	local sources = { [spec.base] = true, class = true, custom = true }

	function Highlight.GetCustomColor(profile)
		local color = type(profile[key.color]) == "table" and profile[key.color] or base
		return channel(color[1], base[1]), channel(color[2], base[2]), channel(color[3], base[3])
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
		alert.legacyTexture = spec.legacyTexture(db)
		alert.SetTexture = function(self, texture) self.ring:SetTexture(texture) end
		alert.SetVertexColor = function(self, r, g, b, a)
			self.ring:SetVertexColor(r, g, b, a or defaultOpacity)
			self.halo:SetVertexColor(r, g, b, a or defaultOpacity)
		end
		-- The Legacy HUD desaturates the assisted highlight, which was a texture
		-- until it became one of these (Core/LegacyHUD.lua, StyleButton).
		alert.SetDesaturated = function(self, desaturated)
			self.ring:SetDesaturated(desaturated)
			self.halo:SetDesaturated(desaturated)
		end
		alert:Hide()
		return alert
	end

	function Highlight.Apply(alert, profile)
		profile = profile or {}
		local style = styles[profile[key.style]] and profile[key.style] or "current"
		local thickness = widths[profile[key.thickness]] and profile[key.thickness] or "medium"
		local source = sources[profile[key.source]] and profile[key.source] or spec.base
		local color = base
		if (source == "class") then
			color = (ns.Colors.class and ns.Colors.class[ns.PlayerClass]) or base
		elseif (source == "custom" and type(profile[key.color]) == "table") then
			color = profile[key.color]
		end
		local opacity = channel(profile[key.opacity], defaultOpacity)
		local legacy = style == "current" and (spec.keepArt or source == spec.base)
		alert:SetTexture(legacy and alert.legacyTexture or GetMedia("actionbutton-proc-outline-"..(style == "current" and "thin" or thickness)))
		alert.halo:SetTexture(GetMedia("actionbutton-proc-glow-"..thickness))
		alert:SetVertexColor(channel(color[1], base[1]), channel(color[2], base[2]), channel(color[3], base[3]), opacity)
		alert.ring:SetShown(style == "current" or style == "outline" or style == "both")
		alert.halo:SetShown(style == "glow" or style == "both")
	end

	-- An isolated sample, never a forced glow on a live/protected action button.
	-- It stays open beside the options and redraws whenever the settings change.
	function Highlight.Preview(profile)
		if (not Highlight.preview) then
			local frame = CreateFrame("Frame", ns.Prefix..spec.previewName, UIParent, "BackdropTemplate")
			frame:SetSize(200, 190)
			frame:SetPoint("CENTER", UIParent, "CENTER", 360, spec.previewOffset or 0)
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
			title:SetWidth(160)
			title:SetText(spec.title)
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
			icon:SetTexture(spec.icon)
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

	return Highlight
end

ns.ActionBarProcHighlight = New({
	prefix = "procHighlight",
	base = "gold",
	defaults = {
		procHighlightStyle = "current",
		procHighlightThickness = "medium",
		procHighlightColorSource = "gold",
		procHighlightColor = { 249/255, 188/255, 65/255 },
		procHighlightOpacity = .75
	},
	legacyTexture = function(db) return db.ButtonSpellHighlightTexture end,
	title = L["Proc Highlight"],
	previewName = "ProcHighlightPreview",
	icon = [[Interface\Icons\ability_hunter_cobrashot]]
})

-- The assisted suggestion keeps what it has looked like since its circle shipped:
-- actionbutton-glow-white (Layouts/Data/ActionButton.lua, ButtonAssistedHighlightTexture,
-- or the shape's own highlight) tinted cyan at 95%. That art is neutral, so "current"
-- keeps it under any colour.
ns.ActionBarAssistedHighlight = New({
	prefix = "assistedHighlight",
	base = "default",
	keepArt = true,
	defaults = {
		assistedHighlightStyle = "current",
		assistedHighlightThickness = "medium",
		assistedHighlightColorSource = "default",
		assistedHighlightColor = { .35, .85, 1 },
		assistedHighlightOpacity = .95
	},
	legacyTexture = function(db) return db.ButtonAssistedHighlightTexture or db.ButtonSpellHighlightTexture end,
	title = L["Assisted Combat Highlight"],
	previewName = "AssistedHighlightPreview",
	previewOffset = -200,
	icon = [[Interface\Icons\ability_hunter_killcommand]]
})

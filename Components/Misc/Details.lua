-- MIT License. Copyright (c) 2026 Jonas "JuNNeZ" Andersen.
-- Register an opt-in Details skin; Details owns applying and saving it.
local _, ns = ...
local Skin = ns:NewModule("DetailsSkin", "LibMoreEvents-1.0")
local SKIN_NAME = "AzeriteUI Forged (Preview)"
local Art = ns.DetailsSkinArt
local borders = setmetatable({}, { __mode = "k" })
local rowMasks = setmetatable({}, { __mode = "k" })
local TOOLBAR_KEYS = { "modo_selecao", "segmento", "atributo", "report", "reset", "fechar" }
Skin.Style = { idleIcons = .08, hoverIcons = .85 }
local function IsOurSkin(instance)
	return instance.skin == SKIN_NAME or instance.skin == "AzeriteUI Minimal" or instance.skin == "AzeriteUI"
end

-- Only our decorative child changes. Details continues to own bounds, input,
-- resizing and visibility, including each window's saved position and scale.
Skin.UpdateBorder = function(instance)
	local border = borders[instance]
	if (not IsOurSkin(instance)) then
		if (border) then border:Hide() end
		return
	end
	-- Frame only the header. Empty rows below it must never become a giant box.
	local parent = instance.baseframe and instance.baseframe.titleBar
	if (not parent) then return end
	if (not border) then
		-- Same parent/layer as the native title backing: an opaque child frame
		-- here would cover the native title FontString instead of sitting below it.
		border = parent:CreateTexture(nil, "BACKGROUND", nil, -1)
		border:SetAllPoints(parent)
		border:SetTexture(ns.API.GetMedia("Details\\header"))
		border:SetTexCoord(unpack(Art.header))
		borders[instance] = border
	end
	border:Show()
end

Skin.UpdateRow = function(instance, row)
	local mask = rowMasks[row]
	local active = IsOurSkin(instance)
	if (not active) then
		if (mask and mask.attached) then
			row.textura:RemoveMaskTexture(mask)
			row.background:RemoveMaskTexture(mask)
			mask.attached = nil
			-- SetBarSettings resets the files, but does not reset custom UVs.
			row.textura:SetTexCoord(0, 1, 0, 1)
			row.background:SetTexCoord(0, 1, 0, 1)
			row.overlayTexture:SetTexCoord(0, 1, 0, 1)
		end
		return
	end
	if (not row.statusbar or not row.textura or not row.background or not row.overlayTexture
		or not row.textura.AddMaskTexture or not row.background.AddMaskTexture) then return end
	-- NEWROW fires after construction, before a later full settings pass. Supply
	-- the actual paint as well as its mask so late rows never retain blank textures.
	row.textura:SetTexture(ns.API.GetMedia("Details\\fill"))
	row.background:SetTexture(ns.API.GetMedia("Details\\fill"))
	row.overlayTexture:SetTexture(ns.API.GetMedia("Details\\casing"))
	local settings = instance.row_info
	if (settings) then
		if (not settings.texture_background_class_color and settings.fixed_texture_background_color) then
			row.background:SetVertexColor(unpack(settings.fixed_texture_background_color))
		end
		if (settings.overlay_color) then row.overlayTexture:SetVertexColor(unpack(settings.overlay_color)) end
	end
	if (not mask) then
		mask = row.statusbar:CreateMaskTexture(nil, "BACKGROUND")
		mask:SetAllPoints(row.statusbar)
		mask:SetTexture(ns.API.GetMedia("Details\\row-mask"), "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
		mask:SetTexCoord(unpack(Art.casing))
		rowMasks[row] = mask
	end
	if (not mask.attached) then
		row.textura:AddMaskTexture(mask)
		row.background:AddMaskTexture(mask)
		mask.attached = true
	end
	-- Texture coordinates are art registration only. Never inspect a row's value.
	row.textura:SetTexCoord(unpack(Art.fill))
	row.background:SetTexCoord(unpack(Art.fill))
	row.overlayTexture:SetTexCoord(unpack(Art.casing))
end

Skin.UpdateRows = function(instance)
	for _, row in ipairs(instance.barras or {}) do Skin.UpdateRow(instance, row) end
end

Skin.UpdateToolbar = function(instance)
	if (not IsOurSkin(instance)) then return end
	local header = instance.baseframe and instance.baseframe.cabecalho
	if (not header) then return end
	local alpha = instance.is_interacting and Skin.Style.hoverIcons or Skin.Style.idleIcons
	-- Keep every enabled button clickable; never change menu/profile preferences.
	for _, key in ipairs(TOOLBAR_KEYS) do
		local button = header[key]
		if (button) then button:SetAlpha(alpha) end
	end
end

local function Copy(value)
	if (type(value) ~= "table") then return value end
	local copy = {}
	for key, entry in pairs(value) do copy[key] = Copy(entry) end
	return copy
end

Skin.TryInstall = function(self)
	local details = _G.Details
	local media = LibStub("LibSharedMedia-3.0", true)
	if (not Art or not media or type(details) ~= "table" or type(details.InstallSkin) ~= "function"
		or type(details.skins) ~= "table") then return end
	local base = details.skins["Minimalistic"]
	if (type(base) ~= "table" or type(base.instance_cprops) ~= "table") then return end
	if (type(base.instance_cprops.row_info) ~= "table"
		or type(base.instance_cprops.attribute_text) ~= "table"
		or type(base.micro_frames) ~= "table") then return end

	-- Clone Details' own atlas geometry, never its live instances or profile.
	local skin = Copy(base)
	skin.author = "JuNNeZ"
	skin.version = "4.0"
	skin.desc = "Approved AzeriteUI artwork: forged header, faceted fills and angled row casings. Live preview."
	skin.file = ns.API.GetMedia("blank") -- Keep atlas anchors, replace its visible chrome.
	skin.no_cache = true -- Assets require AzeriteUI; do not cache an orphan skin.
	skin.is_cached_skin = nil
	skin.callback = nil
	skin.skin_options = nil -- Do not expose the base skin's global tooltip actions.

	local font = ns.API.GetFont(11, true)
	local fontFile = font and font:GetFont()
	if (not fontFile) then return end
	media:Register("font", "AzeriteUI Details", fontFile)
	media:Register("statusbar", "AzeriteUI Details", ns.API.GetMedia("Details\\fill"))
	media:Register("statusbar", "AzeriteUI Details Casing", ns.API.GetMedia("Details\\casing"))
	media:Register("background", "AzeriteUI Clear", ns.API.GetMedia("blank"))

	local props = skin.instance_cprops
	props.skin = SKIN_NAME
	props.color = { .12, .12, .12, 0 } -- Native metal replaces the generic atlas chrome.
	props.bg_r, props.bg_g, props.bg_b, props.bg_alpha = 0, 0, 0, 0
	props.backdrop_texture = "AzeriteUI Clear"
	props.show_statusbar, props.show_sidebars = false, false
	props.rounded_corner_enabled = false
	props.fullborder_shown, props.rowareaborder_shown = false, false
	props.titlebar_shown = true
	props.titlebar_height = 32
	props.titlebar_texture = "Solid"
	props.titlebar_texture_color = { 0, 0, 0, 0 }
	props.menu_icons_size, props.menu_icons_alpha = .7, Skin.Style.hoverIcons
	props.desaturated_menu = true
	props.hide_icon = true
	props.attribute_text.text_face = "AzeriteUI Details"
	props.attribute_text.text_size = 12
	props.attribute_text.anchor = { 7, 2 }
	props.attribute_text.text_color = { 229/255, 178/255, 38/255, 1 }
	props.attribute_text.show_timer_always = false
	props.attribute_text.show_timer = false
	props.attribute_text.show_timer_bg = false
	props.attribute_text.show_timer_arena = false
	props.use_multi_fontstrings = false
	local row = props.row_info
	row.texture = "AzeriteUI Details"
	row.texture_file = ns.API.GetMedia("Details\\fill")
	row.texture_background = "AzeriteUI Details"
	row.texture_background_file = row.texture_file
	row.texture_custom = ""
	row.texture_custom_file = "Interface\\"
	row.texture_class_colors = true
	row.texture_background_class_color = false
	row.fixed_texture_background_color = { .1, .1, .1, .9 }
	row.overlay_texture = "AzeriteUI Details Casing"
	row.overlay_color = { 1, 1, 1, 1 }
	row.backdrop = { enabled = false, color = { 1, 1, 1, 1 }, size = 0 }
	row.fixed_text_color = { 220/255, 220/255, 220/255, 1 }
	row.font_face, row.font_face_file = "AzeriteUI Details", fontFile
	row.font_size, row.height, row.alpha = 11, 22, 1
	row.textL_outline, row.textR_outline = false, false
	row.textL_outline_small, row.textR_outline_small = true, true
	row.textL_show_number = false
	row.textR_show_data = { false, true, false } -- Rate only; names retain their space.
	row.textR_enable_custom_text = true
	row.textR_custom_text = "{data2}" -- Details formats the rate, including combat secrets.
	row.show_percent = false
	row.no_icon = true
	-- Current Details has per-column anchors; use the meter itself when icons are off.
	row.texts = {
		{ anchor = { point = "left", relativeTo = "statusbar", relativePoint = "left", x = 9, y = 0 } },
		-- Native meter rendering can write these regardless of legacy column switches.
		-- Style the auxiliary columns out, including their shadows; do not read values.
		{ color = { byClass = false, fixed = { 1, 1, 1, 0 } }, shadow = { color = { 0, 0, 0, 0 } } },
		{ color = { byClass = false, fixed = { 1, 1, 1, 0 } }, shadow = { color = { 0, 0, 0, 0 } } },
		{ anchor = { point = "right", relativeTo = "statusbar", relativePoint = "right", x = -9, y = 0 } }
	}
	row.space = { left = 2, right = 2, between = 3 }
	skin.micro_frames.font = "AzeriteUI Details"
	skin.micro_frames.size = 11
	skin.micro_frames.color = { 196/255, 196/255, 196/255, 1 }

	-- Details' current ChangeSkin does not invoke skin.callback. Post-hooks are
	-- required for the owned border and hover treatment, including skin cleanup.
	if (not self.hooked and type(details.ChangeSkin) == "function"
		and type(details.SetAutoHideMenu) == "function" and type(details.SetIconAlpha) == "function"
		and type(details.SetBarSettings) == "function" and type(details.CreateEventListener) == "function") then
		hooksecurefunc(details, "ChangeSkin", function(instance)
			Skin.UpdateBorder(instance)
			Skin.UpdateToolbar(instance)
			Skin.UpdateRows(instance)
		end)
		hooksecurefunc(details, "SetAutoHideMenu", Skin.UpdateToolbar)
		hooksecurefunc(details, "SetIconAlpha", Skin.UpdateToolbar)
		hooksecurefunc(details, "SetBarSettings", Skin.UpdateRows)
		self.listener = details:CreateEventListener()
		self.listener:RegisterEvent("DETAILS_INSTANCE_NEWROW", function(_, instance, row)
			Skin.UpdateRow(instance, row)
		end)
		self.hooked = true
	end

	if (details:InstallSkin(SKIN_NAME, skin)) then
		-- Keep saved selections resolvable. The distinct new name guarantees that
		-- selecting Forged runs Details' full preset path instead of same-skin refresh.
		details:InstallSkin("AzeriteUI", Copy(skin))
		details:InstallSkin("AzeriteUI Minimal", Copy(skin))
		self:UnregisterEvent("ADDON_LOADED")
		self:UnregisterEvent("PLAYER_LOGIN")
	end
end

Skin.OnInitialize = function(self)
	-- Both addon load orders, including Details loaded on demand after login.
	self:RegisterEvent("ADDON_LOADED", "TryInstall")
	self:RegisterEvent("PLAYER_LOGIN", "TryInstall")
	self:TryInstall()
end

-- Offline integration check. Optional argument: installed Details functions/skins.lua.
local registered, events, module = {}, {}, {}
local frames, hooks = {}, 0
local function texture(parent, layer)
	local t = { parent = parent, layer = layer, masks = {} }
	function t:SetAllPoints(value) self.points = value end
	function t:SetTexture(value) self.file = value end
	function t:SetVertexColor(...) self.color = { ... } end
	function t:SetTexCoord(...) self.uv = { ... } end
	function t:Show() self.shown = true end
	function t:Hide() self.shown = false end
	function t:AddMaskTexture(mask) self.masks[mask] = true end
	function t:RemoveMaskTexture(mask) self.masks[mask] = nil end
	return t
end
local titleBar = { CreateTexture = function(self, _, layer)
	local t = texture(self, layer)
	frames[#frames+1] = t
	return t
end }
function CreateFrame(_, _, parent, template)
	assert(template == "BackdropTemplate")
	local frame = { parent = parent, points = {} }
	function frame:EnableMouse(value) self.mouse = value end
	function frame:SetPoint(...) self.points[#self.points + 1] = { ... } end
	function frame:SetBackdrop(value) self.backdrop = value end
	function frame:SetBackdropBorderColor(...) self.color = { ... } end
	function frame:Show() self.shown = true end
	function frame:Hide() self.shown = false end
	frames[#frames + 1] = frame
	return frame
end
function hooksecurefunc(object, key, callback)
	local original = assert(object[key])
	object[key] = function(...)
		original(...)
		callback(...)
	end
	hooks = hooks + 1
end
local ns = { API = {} }
function ns:NewModule() return module end
function module:RegisterEvent(event, method) events[event] = method end
function module:UnregisterEvent(event) events[event] = nil end
function ns.API.GetFont()
	return { GetFont = function() return "Fonts\\FRIZQT__.TTF", 12, "OUTLINE" end }
end
function ns.API.GetMedia(name)
	return "Interface\\AddOns\\AzeriteUI5_JuNNeZ_Edition\\Assets\\" .. name .. ".tga"
end
local media = {}
function media:Register(kind, name, path) registered[kind .. ":" .. name] = path end
function LibStub(name)
	if (name == "LibSharedMedia-3.0") then return media end
	return { GetLocale = function() return setmetatable({}, { __index = function(_, k) return k end }) end }
end
assert(loadfile("Components/Misc/DetailsArt.lua"))("AzeriteUI5_JuNNeZ_Edition", ns)
assert(loadfile("Components/Misc/Details.lua"))("AzeriteUI5_JuNNeZ_Edition", ns)
module:OnInitialize()
assert(events.ADDON_LOADED and events.PLAYER_LOGIN, "must wait when Details is absent")
Details = { skins = {} }
module:TryInstall()
assert(events.ADDON_LOADED, "must tolerate partial Details initialization")
if (arg[1]) then
	-- Execute the actual installed Details registry and built-in skin definitions.
	assert(loadfile(arg[1]))("Details", {})
else
	function Details:InstallSkin(name, skin) self.skins[name] = skin; return true end
	Details.skins.Minimalistic = {
		file = "DetailsAtlas", instance_cprops = { attribute_text = {}, row_info = { space = {} } },
		micro_frames = {}, skin_options = { "base tooltip action" }
	}
end
local base = Details.skins.Minimalistic
local originalFont = base.instance_cprops.row_info.font_face
function Details:ChangeSkin(name) self.skin = name or self.skin end
function Details:SetAutoHideMenu() end
function Details:SetIconAlpha() end
function Details:SetBarSettings() end
local rowEvent
function Details:CreateEventListener()
	return { RegisterEvent = function(_, event, callback)
		assert(event == "DETAILS_INSTANCE_NEWROW")
		rowEvent = callback
	end }
end
local instances = { skin = "Existing", x = 123, combat = { damage = 42 } }
Details.instances = instances
module:TryInstall()
local skin = assert(Details.skins["AzeriteUI Minimal"], "skin not registered")
assert(skin.file == ns.API.GetMedia("blank"), "generic atlas chrome must be absent")
assert(skin ~= base and skin.instance_cprops.row_info ~= base.instance_cprops.row_info)
assert(base.instance_cprops.row_info.font_face == originalFont, "base skin mutated")
assert(Details.instances == instances and instances.skin == "Existing" and instances.x == 123)
assert(instances.combat.damage == 42, "combat data changed")
assert(skin.no_cache and not skin.is_cached_skin, "must not cache asset dependencies")
assert(not skin.skin_options and not skin.callback, "base actions leaked")
assert(skin.instance_cprops.row_info.texture == "AzeriteUI Details")
assert(registered["statusbar:AzeriteUI Details"] == ns.API.GetMedia("Details\\fill"))
assert(registered["statusbar:AzeriteUI Details Casing"] == ns.API.GetMedia("Details\\casing"))
assert(registered["font:AzeriteUI Details"] == "Fonts\\FRIZQT__.TTF")
assert(not events.ADDON_LOADED and not events.PLAYER_LOGIN, "listeners not released")
assert(hooks == 4 and rowEvent, "missing lifecycle hooks")
-- The real Details registry does not call callbacks; test the post-hook path.
local window = setmetatable({ baseframe = { titleBar = titleBar, fullWindowFrame = {}, cabecalho = {} } }, { __index = Details })
local button = { SetAlpha = function(self, value) self.alpha = value end }
window.baseframe.cabecalho.report = button
window:ChangeSkin("Existing")
assert(#frames == 0, "must not decorate other skins")
window:ChangeSkin("AzeriteUI Minimal")
assert(#frames == 1 and frames[1].shown and frames[1].layer == "BACKGROUND")
assert(frames[1].parent == window.baseframe.titleBar, "must frame only the header")
assert(frames[1].file == ns.API.GetMedia("Details\\header"))
assert(frames[1].uv[3] == ns.DetailsSkinArt.header[3])
assert(button.alpha == module.Style.idleIcons)
window.is_interacting = true
window:SetAutoHideMenu()
assert(button.alpha == module.Style.hoverIcons)
window.is_interacting = false
window:SetIconAlpha()
assert(button.alpha == module.Style.idleIcons)
window:ChangeSkin("AzeriteUI Minimal")
assert(#frames == 1, "reapplying must reuse the border")
window:ChangeSkin("Existing")
assert(not frames[1].shown, "switching away must hide the border")
button.alpha = .6
window:SetAutoHideMenu()
assert(button.alpha == .6, "must not restyle other skins")
window:ChangeSkin("AzeriteUI Minimal")
assert(#frames == 1 and frames[1].shown, "switching back must reuse the border")
-- AzeriteUI loads after Details: registration must also happen immediately.
Details.skins.AzeriteUI = nil
Details.skins["AzeriteUI Minimal"] = nil
module:OnInitialize()
assert(Details.skins.AzeriteUI and Details.skins["AzeriteUI Minimal"] and not events.ADDON_LOADED)
assert(hooks == 4, "registration must not duplicate hooks")
assert(Details.skins["AzeriteUI Forged (Preview)"], "new artwork preset must be selectable")
local row = { statusbar = {}, textura = texture(), background = texture(), overlayTexture = texture() }
function row.statusbar:CreateMaskTexture() self.mask = texture(self); return self.mask end
window.barras = { row }
window:SetBarSettings()
local mask = row.statusbar.mask
assert(mask.file == ns.API.GetMedia("Details\\row-mask"))
assert(row.textura.masks[mask] and row.background.masks[mask] and mask.attached)
assert(row.overlayTexture.uv[3] == ns.DetailsSkinArt.casing[3])
window:SetBarSettings()
assert(row.statusbar.mask == mask, "mask must be reused")
window:ChangeSkin("Existing")
assert(not mask.attached and not row.textura.masks[mask] and not row.background.masks[mask])
assert(row.textura.uv[3] == 0 and row.overlayTexture.uv[4] == 1, "other skins need default UVs")
window:ChangeSkin("AzeriteUI Forged (Preview)")
assert(row.statusbar.mask == mask and mask.attached)
local newRow = { statusbar = {}, textura = texture(), background = texture(), overlayTexture = texture() }
newRow.statusbar.CreateMaskTexture = row.statusbar.CreateMaskTexture
rowEvent("DETAILS_INSTANCE_NEWROW", window, newRow)
assert(newRow.statusbar.mask.attached, "rows created later must receive the art mask")
assert(newRow.textura.file == ns.API.GetMedia("Details\\fill"))
assert(newRow.overlayTexture.file == ns.API.GetMedia("Details\\casing"), "later rows need paint, not only a mask")
assert(skin.instance_cprops.bg_alpha == 0, "empty body must be transparent")
assert(skin.instance_cprops.backdrop_texture == "AzeriteUI Clear")
assert(registered["background:AzeriteUI Clear"] == ns.API.GetMedia("blank"))
assert(skin.instance_cprops.row_info.no_icon and not skin.instance_cprops.row_info.textL_show_number)
assert(not skin.instance_cprops.attribute_text.show_timer)
assert(not skin.instance_cprops.use_multi_fontstrings)
assert(skin.instance_cprops.row_info.textR_custom_text == "{data2}")
-- Execute the actual installed ChangeSkin settings branch (before frame rendering).
-- This reproduces the screenshot's stale .86 background on a same-name reload.
if (arg[1]) then
	local mainPath = arg[1]:gsub("functions[/\\]skins%.lua$", "frames/window_main.lua")
	local file = assert(io.open(mainPath, "r"))
	local source = file:read("*a")
	file:close()
	local prefix = assert(source:match("(function Details:ChangeSkin%(skin_name%)[%s%S]-)\n\tself.skin = skin_name"))
	local function copy(value)
		if (type(value) ~= "table") then return value end
		local result = {}
		for key, entry in pairs(value) do result[key] = copy(entry) end
		return result
	end
	local native = {
		skins = Details.skins, CopyTable = copy,
		instance_skin_ignored_values = { libwindow = true, window_scale = true },
		StatusBar = { Reset = function() end, ApplyOptions = function() end },
		ResetInstanceConfigKeepingValues = function() end
	}
	local chunk = assert(loadstring(prefix .. "\n self.skin = skin_name\nend"))
	setfenv(chunk, setmetatable({ Details = native, Details222 = { RowTexts = { Prepare = function() end } } }, { __index = _G }))
	chunk()
	local saved = setmetatable({
		skin = "AzeriteUI", bg_alpha = .86, row_info = { textL_show_number = true },
		baseframe = {}, bgframe = {}, StatusBar = { left = {}, center = {}, right = {} },
		libwindow = { x = 77, y = 88 }, window_scale = 1.2
	}, { __index = native })
	saved:ChangeSkin("AzeriteUI")
	assert(saved.bg_alpha == .86, "native same-name refresh must reproduce stale appearance")
	saved:ChangeSkin("AzeriteUI Minimal")
	assert(saved.bg_alpha == 0 and saved.backdrop_texture == "AzeriteUI Clear")
	assert(not saved.row_info.textL_show_number and not saved.use_multi_fontstrings)
	assert(saved.row_info.textR_custom_text == "{data2}" and not saved.attribute_text.show_timer)
	assert(saved.libwindow.x == 77 and saved.libwindow.y == 88 and saved.window_scale == 1.2)
	-- Run the installed text migration/style code, including the parallel fontstrings.
	local function deploy(target, defaults)
		for key, value in pairs(defaults) do
			if (target[key] == nil) then target[key] = copy(value)
			elseif (type(value) == "table" and type(target[key]) == "table") then deploy(target[key], value) end
		end
	end
	native.table = { deploy = deploy }
	local rowNS = {}
	local framework = {
		IsAddonApocalypseWow = function() return false end,
		SetFont = function() end
	}
	local rowChunk = assert(loadfile(arg[1]:gsub("skins%.lua$", "rowtexts.lua")))
	setfenv(rowChunk, setmetatable({ _G = { Details = native, DetailsFramework = framework } }, { __index = _G }))
	rowChunk("Details", rowNS)
	rowNS.RowTexts.Migrate(saved, saved.row_info)
	local row = {}
	for _, index in ipairs({1, 2, 3, 4, 11, 12, 13, 14}) do
		local text = {}
		function text:SetJustifyH() end
		function text:SetJustifyV() end
		function text:SetShadowOffset() end
		function text:SetWidth() end
		function text:SetTextColor(_, _, _, alpha) self.alpha = alpha end
		function text:SetShadowColor(_, _, _, alpha) self.shadowAlpha = alpha end
		row["lineText" .. index] = text
	end
	rowNS.RowTexts.ApplyStyleToRow(saved, row)
	for _, index in ipairs({2, 3, 12, 13}) do
		assert(row["lineText" .. index].alpha == 0 and row["lineText" .. index].shadowAlpha == 0)
	end
	assert(row.lineText1.alpha == 1 and row.lineText4.alpha == 1)
end
-- Export the actual registered settings for the offline assembled preview.
if (arg[2]) then
	local function json(value)
		if (type(value) == "string") then return string.format("%q", value):gsub("\\\n", "\\n") end
		if (type(value) ~= "table") then return tostring(value) end
		local parts = {}
		if (#value > 0) then
			for _, entry in ipairs(value) do parts[#parts + 1] = json(entry) end
			return "[" .. table.concat(parts, ",") .. "]"
		end
		for key, entry in pairs(value) do parts[#parts + 1] = json(key) .. ":" .. json(entry) end
		return "{" .. table.concat(parts, ",") .. "}"
	end
	local file = assert(io.open(arg[2], "w"))
	file:write(json({ props = skin.instance_cprops, style = module.Style }))
	file:close()
end
print("Details skin: dependency/load order, registry/media isolation, border lifecycle, hover and hook reuse passed")

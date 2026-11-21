local _, ns = ...
local Skin = ns:NewModule("TRP3Skin", "LibMoreEvents-1.0")

local addonName = "totalRP3"
local roots = {
	"TRP3_MainFrame", "TRP3_ToolbarFrame", "TRP3_TargetFrame", "TRP3_GlanceBar",
	"TRP3_PopupsFrame", "TRP3_CurrentlyFrame", "TRP3_NPCTalkFrame",
	"TRP3_LinkCopyDialog", "TRP3_AtFirstGlanceEditor", "TRP3_TutorialTooltip",
	"TRP3_ResizeShadowFrame", "TRP3_IconBrowserButtonTooltip",
	"TRP3_WorldMapButton", "TRP3_ScanLoaderFrame", "LibDBIcon10_Total RP 3"
}
local tooltips = {
	"TRP3_MainTooltip", "TRP3_CharacterTooltip", "TRP3_CompanionTooltip", "TRP3_RefTooltip"
}
local borderPieces = {
	"TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner",
	"TopEdge", "BottomEdge", "LeftEdge", "RightEdge"
}
local wood = {
	"TopWoodBorder", "BottomWoodBorder", "LeftWoodBorder", "RightWoodBorder", "SidebarWoodBorder"
}
local menuBackgrounds = {
	["common-dropdown-bg"] = true,
	["common-dropdown-c-bg"] = true,
	["common-dropdown-classic-bg"] = true,
	["common-dropdown-classic-b-bg"] = true
}
local uiPath = "interface/addons/totalrp3/resources/ui/"
local chrome = {
	["ui-frame-neutral-background"] = .42,
	["ui-frame-settings-background"] = .68,
	["ui-frame-profiles-background"] = .75,
	["ui-frame-parchment-background"] = .95,
	["ui-frame-wooden-border"] = .58
}
local buttonArt = {
	"ui-panel-button", "ui-dialogbox-button", "ui-character-tab", "ui-optionsframe",
	"ui-scrollbar", "ui-sliderbar", "ui-editbox", "common-dropdown", "minimal-scrollbar",
	"ui-frame-button", "ui-button-", "minimap-trackingborder"
}
local active, pending
local watched = setmetatable({}, { __mode = "k" })
local branches = setmetatable({}, { __mode = "k" })
local tinted, faded, backdrops = {}, {}, {}
local tooltipArt = setmetatable({}, { __mode = "k" })
local activeMenus = {}
local mapPinArt = setmetatable({}, { __mode = "k" })
local panelBackdrop
local fillColor = { .065, .073, .082, .96 }
local edgeColor = { .31, .40, .45, .95 }
local raisedColor = { .61, .75, .82 }

local function IsAccessible(region)
	return region and not (issecretvalue and issecretvalue(region))
		and not (region.IsForbidden and region:IsForbidden())
end

local function CanChange(region)
	return IsAccessible(region) and not (InCombatLockdown() and region.IsProtected and region:IsProtected())
end

local function GetPanelBackdrop()
	if not panelBackdrop then
		panelBackdrop = {
			bgFile = [[Interface\Tooltips\UI-Tooltip-Background]],
			edgeFile = ns.API.GetMedia("border-tooltip"),
			edgeSize = 16,
			insets = { left = 5, right = 5, top = 5, bottom = 5 }
		}
	end
	return panelBackdrop
end

local function ArtName(texture)
	if not IsAccessible(texture) then return end
	local path = texture.GetAtlas and texture:GetAtlas()
	if issecretvalue and issecretvalue(path) then return end
	if type(path) ~= "string" or path == "" then
		path = texture.GetTextureFilePath and texture:GetTextureFilePath()
	end
	if issecretvalue and issecretvalue(path) then return end
	if type(path) == "string" then
		return path:lower():gsub("\\", "/"):gsub("%.blp$", ""):gsub("%.tga$", "")
	end
end

local function Tint(texture, r, g, b)
	if not IsAccessible(texture) or not texture.GetVertexColor or not texture.SetVertexColor then return end
	local red, green, blue, alpha = texture:GetVertexColor()
	if issecretvalue and (issecretvalue(red) or issecretvalue(green) or issecretvalue(blue) or issecretvalue(alpha)) then return end
	local state = tinted[texture]
	if not state or red ~= state.red or green ~= state.green or blue ~= state.blue or alpha ~= state.alpha then
		state = { original = { red, green, blue, alpha }, alpha = alpha }
		tinted[texture] = state
	end
	state.red, state.green, state.blue = r, g, b
	texture:SetVertexColor(r, g, b, alpha)
end

local function Fade(texture)
	if not IsAccessible(texture) or not texture.GetAlpha then return end
	if faded[texture] == nil then
		local alpha = texture:GetAlpha()
		if issecretvalue and issecretvalue(alpha) then return end
		faded[texture] = alpha
	end
	texture:SetAlpha(0)
end

local function PaintTexture(texture)
	local name = ArtName(texture)
	if not name then return end
	local asset = name:sub(1, #uiPath) == uiPath and name:sub(#uiPath + 1):gsub("^[!_]", "")
	local shade = asset and chrome[asset]
	if shade then
		-- Parchment carries dark text. Keep its luminance while reducing the yellow.
		Tint(texture, shade * .91, shade * .97, shade)
		return
	end
	for _, fragment in ipairs(buttonArt) do
		if name:find(fragment, 1, true) then
			Tint(texture, unpack(raisedColor))
			return
		end
	end
end

local function ApplyBackdrop(frame, replace)
	if not frame.SetBackdrop or not frame.GetBackdropColor or not frame.GetBackdropBorderColor then return end
	local native = frame.backdropInfo
	if type(native) ~= "table" or (not native.edgeFile and not native.bgFile) then return end
	local state = backdrops[frame]
	if state and native == state.applied then return end
	local source = GetPanelBackdrop()
	local style = {
		bgFile = native.bgFile and source.bgFile,
		edgeFile = native.edgeFile and source.edgeFile,
		edgeSize = native.edgeFile and (replace and source.edgeSize or native.edgeSize),
		insets = replace and source.insets or native.insets
	}
	local fill = { frame:GetBackdropColor() }
	local edge = { frame:GetBackdropBorderColor() }
	if state and fill[1] == fillColor[1] and fill[2] == fillColor[2] and fill[3] == fillColor[3] then fill = state.fill end
	if state and edge[1] == edgeColor[1] and edge[2] == edgeColor[2] and edge[3] == edgeColor[3] then edge = state.edge end
	frame:SetBackdrop(style)
	frame:SetBackdropColor(unpack(fillColor))
	frame:SetBackdropBorderColor(unpack(edgeColor))
	backdrops[frame] = { native = native, applied = frame.backdropInfo, fill = fill, edge = edge }
end

local PaintBranch
local function RememberHook(object, name, callback)
	if not object or type(object[name]) ~= "function" then return end
	local hooks = watched[object]
	if not hooks then
		hooks = {}
		watched[object] = hooks
	end
	if hooks[name] then return end
	hooksecurefunc(object, name, callback)
	hooks[name] = true
end

local function Repaint(frame)
	if not active then return end
	if InCombatLockdown() then
		pending = true
	else
		PaintBranch(frame)
	end
end

PaintBranch = function(frame)
	if not CanChange(frame) or branches[frame] or not frame.GetObjectType then return end
	local frameType = frame:GetObjectType()
	-- Tooltips have a separate renderer. Models and embedded Blizzard controls
	-- can contain regions that are not part of the TRP3 interface.
	if frameType == "GameTooltip" or frameType == "ModelScene" or frameType == "PlayerModel" then return end
	if frame.GetRegions then
		for _, region in ipairs({ frame:GetRegions() }) do PaintTexture(region) end
	end
	for _, key in ipairs(wood) do
		if frame[key] then Fade(frame[key]) end
	end
	local isMainBackdrop = _G.TRP3_MainFrame and frame == _G.TRP3_MainFrame.Backdrop
	ApplyBackdrop(frame, isMainBackdrop)
	if isMainBackdrop then
		local slice = frame.NineSlice or frame
		for _, key in ipairs(borderPieces) do Tint(slice[key], unpack(raisedColor)) end
	end
	if frame.IconMask and frame.Border then
		Tint(frame.Border, unpack(raisedColor))
	end
	-- TRP3 creates and recycles directory, profile and picker rows through ScrollBox.
	if frame.GetView and frame.GetFrames and frame.RegisterCallback and ScrollBoxListMixin and ScrollBoxListMixin.Event and ScrollBoxListMixin.Event.OnInitializedFrame then
		local hooks = watched[frame] or {}
		watched[frame] = hooks
		if not hooks.row then
			frame:RegisterCallback(ScrollBoxListMixin.Event.OnInitializedFrame, function(_, row)
				Repaint(row)
			end, Skin)
			hooks.row = true
		end
	end
	if frame.GetChildren then
		for _, child in ipairs({ frame:GetChildren() }) do PaintBranch(child) end
	end
end

local function UpdateTooltipBorder(tooltip)
	local state = tooltipArt[tooltip]
	local slice = tooltip.NineSlice
	if not active or not state or not slice or not slice.GetBorderColor then return end
	local r, g, b, a = slice:GetBorderColor()
	if issecretvalue and (issecretvalue(r) or issecretvalue(g) or issecretvalue(b) or issecretvalue(a)) then return end
	local api = _G.TRP3_API
	local tooltipAPI = api and api.ui and api.ui.tooltip
	local defaultColor = tooltipAPI and tooltipAPI.tooltipBorderColor
	local dr, dg, db = 1, 1, 1
	if defaultColor then dr, dg, db = defaultColor:GetRGB() end
	if r and g and b and (r ~= dr or g ~= dg or b ~= db) and (r ~= 1 or g ~= 1 or b ~= 1) then
		state.frame:SetBackdropBorderColor(r, g, b, a or 1)
	else
		state.frame:SetBackdropBorderColor(unpack(state.edge))
	end
end

local function PaintTooltip(tooltip)
	if not CanChange(tooltip) or not tooltip.NineSlice then return end
	local tooltipsModule = ns:GetModule("Tooltips", true)
	if tooltipsModule and tooltipsModule.ReleaseTRP3Backdrop then tooltipsModule:ReleaseTRP3Backdrop(tooltip) end
	local theme = tooltipsModule and tooltipsModule:GetTheme()
	local style = theme and theme.backdropStyle
	local state = tooltipArt[tooltip]
	if not state then
		local frame = CreateFrame("Frame", nil, tooltip, ns.BackdropTemplate)
		branches[frame] = true
		frame:SetFrameLevel(math.max(0, tooltip:GetFrameLevel() - 1))
		state = { frame = frame }
		tooltipArt[tooltip] = state
		RememberHook(tooltip, "SetBorderColor", UpdateTooltipBorder)
	end
	local frame = state.frame
	frame:ClearAllPoints()
	frame:SetPoint("TOPLEFT", tooltip, "TOPLEFT", style and style.offsetLeft or 0, style and style.offsetTop or 0)
	frame:SetPoint("BOTTOMRIGHT", tooltip, "BOTTOMRIGHT", style and style.offsetRight or 0, style and style.offsetBottom or 0)
	frame:SetBackdrop(style and style.backdrop or GetPanelBackdrop())
	frame:SetBackdropColor(unpack(style and style.backdropColor or fillColor))
	state.edge = style and style.backdropBorderColor or edgeColor
	Fade(tooltip.NineSlice)
	UpdateTooltipBorder(tooltip)
	frame:Show()
end

local function PaintMapPins(provider)
	if not active or not provider or not provider.GetMap then return end
	if InCombatLockdown() then
		pending = true
		return
	end
	local template = provider.pinTemplate
	if template ~= "TRP3_PlayerMapPinTemplate" and template ~= "TRP3_PlayerHousePinTemplate" then return end
	local map = provider:GetMap()
	if not IsAccessible(map) or not map.EnumeratePinsByTemplate then return end
	for pin in map:EnumeratePinsByTemplate(template) do
		if CanChange(pin) then
			local rim = mapPinArt[pin]
			if not rim then
				rim = CreateFrame("Frame", nil, pin, ns.BackdropTemplate)
				rim:SetPoint("TOPLEFT", pin, "TOPLEFT", -2, 2)
				rim:SetPoint("BOTTOMRIGHT", pin, "BOTTOMRIGHT", 2, -2)
				rim:SetBackdrop({ edgeFile = GetPanelBackdrop().edgeFile, edgeSize = 8 })
				rim:SetBackdropBorderColor(unpack(edgeColor))
				mapPinArt[pin] = rim
			end
			rim:Show()
		end
	end
end

local function RestoreMenu(menu)
	local state = activeMenus[menu]
	if not state then return end
	activeMenus[menu] = nil
	if IsAccessible(state.texture) then state.texture:SetVertexColor(unpack(state.color)) end
end

local function Restore()
	for menu in pairs(activeMenus) do RestoreMenu(menu) end
	for texture, color in pairs(tinted) do
		if IsAccessible(texture) then
			local r, g, b, a = texture:GetVertexColor()
			if not (issecretvalue and (issecretvalue(r) or issecretvalue(g) or issecretvalue(b) or issecretvalue(a)))
				and r == color.red and g == color.green and b == color.blue and a == color.alpha then
				texture:SetVertexColor(unpack(color.original))
			end
		end
	end
	for region, alpha in pairs(faded) do
		if IsAccessible(region) then
			local current = region:GetAlpha()
			if not (issecretvalue and issecretvalue(current)) and current == 0 then region:SetAlpha(alpha) end
		end
	end
	for frame, state in pairs(backdrops) do
		if CanChange(frame) and frame.backdropInfo == state.applied then
			local r, g, b, a = frame:GetBackdropColor()
			local er, eg, eb, ea = frame:GetBackdropBorderColor()
			local fill = r == fillColor[1] and g == fillColor[2] and b == fillColor[3] and a == fillColor[4] and state.fill or { r, g, b, a }
			local edge = er == edgeColor[1] and eg == edgeColor[2] and eb == edgeColor[3] and ea == edgeColor[4] and state.edge or { er, eg, eb, ea }
			frame:SetBackdrop(state.native)
			frame:SetBackdropColor(unpack(fill))
			frame:SetBackdropBorderColor(unpack(edge))
		end
	end
	for _, state in pairs(tooltipArt) do state.frame:Hide() end
	for _, rim in pairs(mapPinArt) do rim:Hide() end
	wipe(tinted)
	wipe(faded)
	wipe(backdrops)
end

local function PrepareMenu(description)
	if not active or not description.AddMenuAcquiredCallback or not description.AddMenuReleasedCallback then return end
	description:AddMenuAcquiredCallback(function(menu)
		if not active or InCombatLockdown() or not CanChange(menu) then return end
		-- Shared menu frames are pooled. Only touch the generated backdrop of this
		-- description and restore it when the menu manager releases the frame.
		for _, texture in ipairs({ menu:GetRegions() }) do
			if menuBackgrounds[ArtName(texture)] then
				activeMenus[menu] = { texture = texture, color = { texture:GetVertexColor() } }
				texture:SetVertexColor(unpack(raisedColor))
				break
			end
		end
	end)
	description:AddMenuReleasedCallback(RestoreMenu)
end

local function AddRoot(frame)
	if not CanChange(frame) then return end
	local hooks = watched[frame] or {}
	watched[frame] = hooks
	if not hooks.show then
		if frame.HasScript and frame:HasScript("OnShow") then frame:HookScript("OnShow", Repaint) end
		hooks.show = true
	end
	PaintBranch(frame)
end

local function RefreshTooltips()
	if not active then return end
	if InCombatLockdown() then
		pending = true
		return
	end
	for _, name in ipairs(tooltips) do PaintTooltip(_G[name]) end
end

local function Refresh()
	if InCombatLockdown() then
		pending = true
		return
	end
	pending = nil
	local enabled = ns.db and ns.db.char and ns.db.char.totalRP3Skin and _G.TRP3_MainFrame
	if not enabled then
		if active then
			active = nil
			ns.TRP3TooltipSkin = nil
			Restore()
		end
		return
	end
	active = true
	ns.TRP3TooltipSkin = Skin
	for _, name in ipairs(roots) do AddRoot(_G[name]) end
	RefreshTooltips()
	local tooltipsModule = ns:GetModule("Tooltips", true)
	RememberHook(tooltipsModule, "UpdateTooltipThemes", RefreshTooltips)
	local toolbar = _G.TRP3_ToolbarFrame
	RememberHook(toolbar, "UpdateButtons", Repaint)
	local menu = _G.TRP3_MenuUtil
	RememberHook(menu, "PrepareRootMenuDescription", PrepareMenu)
	local api = _G.TRP3_API
	local provider = api and api.MapDataProvider
	RememberHook(provider, "RefreshAllData", PaintMapPins)
	PaintMapPins(provider)
end

function Skin:OwnsTooltip(tooltip)
	if not active or not IsAccessible(tooltip) then return false end
	for _, name in ipairs(tooltips) do
		if tooltip == _G[name] then return true end
	end
	return false
end

function Skin:SetEnabled(enabled)
	ns.db.char.totalRP3Skin = enabled or nil
	Refresh()
end

function Skin:OnInitialize()
	local observed
	local function Attach()
		local api, addon = _G.TRP3_API, _G.TRP3_Addon
		if api and api.RegisterCallback and addon and addon.Events and addon ~= observed then
			observed = addon
			if addon.Events.WORKFLOW_ON_FINISH then
				api.RegisterCallback(addon, addon.Events.WORKFLOW_ON_FINISH, Refresh)
			end
			if addon.Events.PAGE_OPENED then
				api.RegisterCallback(addon, addon.Events.PAGE_OPENED, function()
					Repaint(_G.TRP3_MainFrame)
				end)
			end
		end
		Refresh()
	end

	self:RegisterEvent("ADDON_LOADED", function(_, _, name)
		if name == addonName then Attach() end
	end)
	self:RegisterEvent("PLAYER_LOGIN", function()
		Attach()
		-- TRP3 can finish its AceAddon startup later in the same login event.
		C_Timer.After(0, Refresh)
	end)
	self:RegisterEvent("PLAYER_REGEN_ENABLED", function()
		if pending then Refresh() end
	end)
	Attach()
end

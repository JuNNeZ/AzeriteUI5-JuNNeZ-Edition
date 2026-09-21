--[[

	The MIT License (MIT)

	Copyright (c) 2026 Jonas "JuNNeZ" Andersen

--]]
-- Live previews for the custom options panel.
--
-- A preview is an outline owned by the options panel and anchored around the
-- real frame affected by a setting. The target is never shown, hidden,
-- reparented, resized, recoloured or otherwise changed. This keeps the preview
-- honest and, just as importantly, keeps it away from protected frame state.
--
-- Some pages own several frames (Action Bars, Explorer Mode), while some style
-- Blizzard frames rather than keeping one on their module. Those cases are
-- resolved here explicitly. If no usable live object exists, the panel says so
-- in its footer instead of drawing a pretend frame that can drift from reality.
local Addon, ns = ...

local Kit = ns.OptionsKit
local Defaults = Kit.Defaults
if (not Defaults) then return end

local L = LibStub("AceLocale-3.0"):GetLocale(Addon)

-- Lua API
local ipairs = ipairs
local pairs = pairs
local pcall = pcall
local string_format = string.format
local string_match = string.match
local tonumber, type = tonumber, type
local unpack = unpack

-- GLOBALS: C_NamePlate, CreateFrame, GameTooltip, UIParent, issecurefunc, issecretvalue

local Preview = {}
Kit.Preview = Preview

local DURATION = 1.8
local PULSE = .45
local DEFAULT_STYLE = {
	name = "golden-glow",
	backdrop = Kit.PreviewGlowBackdrop,
	labelBackdrop = Kit.PreviewGlowLabelBackdrop,
	color = Kit.PreviewGold,
	inset = 10
}

Preview.DefaultStyle = DEFAULT_STYLE

local overlay
local requestID = 0

local Overlay_OnUpdate = function(self, elapsed)
	self.elapsed = (self.elapsed or 0) + elapsed
	if (self.elapsed >= DURATION) then
		self:Hide()
		self:ClearAllPoints()
		self:SetScript("OnUpdate", nil)
		return
	end

	local phase = (self.elapsed % PULSE) / PULSE
	self:SetAlpha(phase < .5 and (.55 + phase * .9) or (1.45 - phase * .9))
end

local CopyPath = function(path)
	local copy = {}
	for i = 1, #(path or {}) do copy[i] = path[i] end
	return copy
end

-- A UI object is useful only when it is safe to inspect and has a real area to
-- outline. Hidden frames still qualify: disabling a bar should flash the place
-- it occupied rather than make the preview disappear with it.
local IsUsableFrame = function(frame)
	if (not frame or frame == UIParent) then return false end
	if (type(frame.GetWidth) ~= "function" or type(frame.GetHeight) ~= "function") then
		return false
	end

	if (type(frame.IsForbidden) == "function") then
		local ok, forbidden = pcall(frame.IsForbidden, frame)
		if (not ok or forbidden) then return false end
	end

	local okWidth, width = pcall(frame.GetWidth, frame)
	local okHeight, height = pcall(frame.GetHeight, frame)
	if (not okWidth or not okHeight) then return false end
	if (type(width) ~= "number" or type(height) ~= "number") then return false end
	if (issecretvalue and (issecretvalue(width) or issecretvalue(height))) then return false end

	return width > 1 and height > 1
end

local PreferContent = function(frame)
	if (not frame) then return end

	local objectType = type(frame)
	if ((objectType ~= "table") and (objectType ~= "userdata")) then return end

	local contentOK, content = pcall(function()
		return frame.content
	end)
	if (contentOK and IsUsableFrame(content)) then return content end
	return IsUsableFrame(frame) and frame or nil
end

local CallFrameProvider = function(module, method)
	local provider = module and module[method]
	if (type(provider) ~= "function") then return end

	local ok, frame = pcall(provider, module)
	return ok and PreferContent(frame) or nil
end

local FirstModuleFrame = function(module)
	if (not module) then return end

	-- An explicit provider is the extension point for modules whose useful frame
	-- is not stored under one of the established fields below.
	local frame = CallFrameProvider(module, "GetOptionsPreviewFrame")
		or CallFrameProvider(module, "GetFrame")
	if (frame) then return frame end

	for _, key in ipairs({ "frame", "Frame", "bar", "Button", "anchor" }) do
		frame = PreferContent(module[key])
		if (frame) then return frame end
	end
end

local Module = function(name)
	if (type(name) ~= "string") then return end
	local ok, module = pcall(ns.GetModule, ns, name, true)
	return ok and module or nil
end

local FindPathKey = function(path, pattern)
	for i = #path, 1, -1 do
		local key = path[i]
		if (type(key) == "string") then
			local value = string_match(key, pattern)
			if (value) then return value end
		end
	end
end

local ResolveActionBar = function(module, path)
	local id = tonumber(FindPathKey(path, "^bar(%d+)$"))
	local bars = module and module.bars
	if (type(bars) ~= "table") then return end

	return PreferContent(id and bars[id] or bars[1])
end

local ResolveNamePlate = function()
	-- These are the addon-owned oUF frames the player actually sees. Prefer the
	-- target plate, then any active plate, before falling back to Blizzard's
	-- plate object on clients where the active registry is unavailable.
	if (type(ns.ActiveNamePlates) == "table") then
		for frame in pairs(ns.ActiveNamePlates) do
			if (frame.isTarget and IsUsableFrame(frame)) then return frame end
		end
		for frame in pairs(ns.ActiveNamePlates) do
			if (IsUsableFrame(frame)) then return frame end
		end
	end

	if (not C_NamePlate or type(C_NamePlate.GetNamePlateForUnit) ~= "function") then return end

	for _, unit in ipairs({ "target", "mouseover", "nameplate1" }) do
		local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit,
			issecurefunc and issecurefunc())
		if (ok and plate) then
			local frame = PreferContent(plate.UnitFrame) or PreferContent(plate)
			if (frame) then return frame end
		end
	end
end

local ResolveGlobal = function(moduleName)
	if (moduleName == "ChatFrames") then
		return PreferContent(_G.ChatFrame1)
	elseif (moduleName == "Containers") then
		return PreferContent(_G.ContainerFrameCombinedBags) or PreferContent(_G.ContainerFrame1)
	elseif (moduleName == "GameMenuSkin") then
		return PreferContent(_G.GameMenuFrame)
	elseif (moduleName == "WorldMap") then
		return PreferContent(_G.WorldMapFrame)
	elseif (moduleName == "Tooltips") then
		return PreferContent(GameTooltip)
	elseif (moduleName == "NamePlates") then
		return ResolveNamePlate()
	end
end

local ResolveNamed

local explorerTargets = {
	fadeActionBars = "ActionBars",
	fadePetBar = "PetBar",
	fadeStanceBar = "StanceBar",
	fadePlayerFrame = "PlayerFrame",
	fadePlayerClassPower = "PlayerClassPowerFrame",
	fadePetFrame = "PetFrame",
	fadeFocusFrame = "FocusFrame",
	fadeTracker = "Tracker",
	fadeChatFrames = "ChatFrames"
}

local ResolveExplorer = function(path)
	local key = path[#path]
	return ResolveNamed(explorerTargets[key] or "PlayerFrame", path)
end

ResolveNamed = function(moduleName, path)
	local module = Module(moduleName)

	if (moduleName == "ActionBars") then
		local frame = ResolveActionBar(module, path)
		if (frame) then return frame end
	elseif (moduleName == "ExplorerMode") then
		return ResolveExplorer(path)
	elseif (moduleName == "UnitFrames") then
		-- UnitFrames owns shared policies, not a frame. Player is the concrete
		-- representative for those policies, including health prediction.
		return ResolveNamed("PlayerFrame", path)
	end

	return FirstModuleFrame(module) or ResolveGlobal(moduleName)
end

Preview.ResolveModuleTarget = function(self, moduleName, path)
	return ResolveNamed(moduleName, path or {})
end

Preview.ResolveTarget = function(self, options, path)
	local moduleName = Defaults.ModuleNameFor(options, path or {})
	if (not moduleName) then return end
	return self:ResolveModuleTarget(moduleName, path), moduleName
end

local CreateOverlay = function()
	local frame = CreateFrame("Frame", nil, UIParent, ns.BackdropTemplate)
	frame:SetFrameStrata("TOOLTIP")
	frame:SetToplevel(true)
	-- Do not clamp this: moving the overlay inward at a screen edge would make
	-- the outline stop matching the frame it is meant to identify.
	frame:SetBackdrop(DEFAULT_STYLE.backdrop)
	frame:SetBackdropColor(0, 0, 0, 0)
	frame:EnableMouse(false)
	frame:Hide()

	local labelFrame = CreateFrame("Frame", nil, frame, ns.BackdropTemplate)
	labelFrame:SetSize(260, 24)
	labelFrame:SetPoint("BOTTOM", frame, "TOP", 0, 8)
	labelFrame:SetBackdrop(DEFAULT_STYLE.labelBackdrop)
	labelFrame:EnableMouse(false)
	frame.labelFrame = labelFrame

	local label = labelFrame:CreateFontString(nil, "OVERLAY")
	label:SetFontObject(Kit.GetFont(12, true))
	label:SetPoint("LEFT", labelFrame, "LEFT", 8, 0)
	label:SetPoint("RIGHT", labelFrame, "RIGHT", -8, 0)
	label:SetJustifyH("CENTER")
	label:SetWordWrap(false)
	frame.label = label

	overlay = frame
	return frame
end

Preview.Restyle = function(self)
	if (not overlay) then return end

	local style = overlay.previewStyle or DEFAULT_STYLE
	overlay:SetBackdrop(style.backdrop)
	overlay:SetBackdropBorderColor(unpack(style.color))
	overlay.labelFrame:SetBackdrop(style.labelBackdrop)
	overlay.labelFrame:SetBackdropColor(0, 0, 0, .88)
	overlay.labelFrame:SetBackdropBorderColor(unpack(style.color))
	overlay.label:SetTextColor(unpack(style.color))
end

Preview.Hide = function(self)
	if (not overlay) then return end
	overlay:Hide()
	overlay:ClearAllPoints()
	overlay:SetScript("OnUpdate", nil)
end

local SetPanelStatus = function(text, found)
	local panel = Kit.Panel
	if (panel and panel.SetPreviewStatus) then
		panel:SetPreviewStatus(text, found)
	end
end

Preview.Request = function(self, options, path, label)
	local target, moduleName = self:ResolveTarget(options, path)
	if (not moduleName) then return false end
	local style = self.DefaultStyle

	requestID = requestID + 1
	label = (type(label) == "string" and label ~= "") and label or moduleName

	self.lastRequest = {
		id = requestID,
		label = label,
		moduleName = moduleName,
		path = CopyPath(path),
		target = target,
		style = style.name
	}

	if (not target) then
		self:Hide()
		SetPanelStatus(string_format(L["No visible frame to preview for %s."], label), false)
		return true
	end

	local frame = overlay or CreateOverlay()
	frame.previewStyle = style
	frame:Hide()
	frame:ClearAllPoints()
	frame:SetPoint("TOPLEFT", target, "TOPLEFT", -style.inset, style.inset)
	frame:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", style.inset, -style.inset)
	frame.label:SetText(label)
	frame.elapsed = 0
	frame:SetAlpha(1)
	frame:SetScript("OnUpdate", Overlay_OnUpdate)

	self:Restyle()
	frame:Show()
	SetPanelStatus(string_format(L["Previewing %s."], label), true)
	return true
end

Preview.GetLastRequest = function(self)
	return self.lastRequest
end

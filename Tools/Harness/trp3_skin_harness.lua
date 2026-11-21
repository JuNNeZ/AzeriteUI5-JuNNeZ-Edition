-- Standalone Elune coverage for TRP3 skin lifecycle and pooled controls.
local root = (...) or "."
local combat, overlayCount, transferred = false, 0, 0
local events, trpEvents = {}, {}
local function copy(value) return { unpack(value) } end
local function same(a, b)
	for i = 1, #b do if a[i] ~= b[i] then return false end end
	return true
end

function InCombatLockdown() return combat end
function wipe(tbl) for key in pairs(tbl) do tbl[key] = nil end end
function hooksecurefunc(object, key, hook)
	local original = object[key]
	object[key] = function(...)
		original(...)
		hook(...)
	end
end

local function Texture(path, atlas)
	return {
		path = path, atlas = atlas, alpha = 1, color = { 1, 1, 1, 1 },
		GetTextureFilePath = function(self) return self.path end,
		GetAtlas = function(self) return self.atlas end,
		GetVertexColor = function(self) return unpack(self.color) end,
		SetVertexColor = function(self, r, g, b, a) self.color = { r, g, b, a or 1 } end,
		GetAlpha = function(self) return self.alpha end,
		SetAlpha = function(self, alpha) self.alpha = alpha end
	}
end

local function Frame(kind)
	return {
		children = {}, regions = {}, frameLevel = 3, alpha = 1,
		fill = { .4, .3, .2, .7 }, edge = { .7, .6, .5, 1 },
		GetObjectType = function() return kind or "Frame" end,
		GetRegions = function(self) return unpack(self.regions) end,
		GetChildren = function(self) return unpack(self.children) end,
		GetFrameLevel = function(self) return self.frameLevel end,
		SetFrameLevel = function(self, level) self.frameLevel = level end,
		SetBackdrop = function(self, backdrop) self.backdropInfo = backdrop end,
		GetBackdropColor = function(self) return unpack(self.fill) end,
		SetBackdropColor = function(self, ...) self.fill = { ... } end,
		GetBackdropBorderColor = function(self) return unpack(self.edge) end,
		SetBackdropBorderColor = function(self, ...) self.edge = { ... } end,
		ClearAllPoints = function() end,
		SetPoint = function() end,
		SetAlpha = function(self, alpha) self.alpha = alpha end,
		GetAlpha = function(self) return self.alpha end,
		HasScript = function() return true end,
		HookScript = function(self, name, callback) self[name] = callback end,
		Show = function(self) self.shown = true end,
		Hide = function(self) self.shown = false end
	}
end

function CreateFrame(_, _, parent)
	local frame = Frame()
	overlayCount = overlayCount + 1
	parent.children[#parent.children + 1] = frame
	return frame
end

C_Timer = { After = function(_, callback) callback() end }
ScrollBoxListMixin = { Event = { OnInitializedFrame = "row" } }
local skin = { RegisterEvent = function(_, event, callback) events[event] = callback end }
local tooltips = {
	GetTheme = function()
		return { backdropStyle = {
			backdrop = { edgeFile = "tooltip-theme" },
			backdropColor = { 0, 0, 0, 1 }, backdropBorderColor = { .2, .3, .4, 1 }
		} }
	end,
	ReleaseTRP3Backdrop = function() transferred = transferred + 1 end
}
local ns = {
	db = { char = { totalRP3Skin = true } }, BackdropTemplate = "BackdropTemplate",
	API = { GetMedia = function() return "border-tooltip" end },
	NewModule = function() return skin end,
	GetModule = function() return tooltips end
}
assert(loadfile(root .. "/Components/Misc/TRP3Skin.lua"))("AzeriteUI", ns)
skin:OnInitialize()
assert(overlayCount == 0, "TRP3 is an optional dependency")

TRP3_MainFrame, TRP3_ToolbarFrame = Frame(), Frame()
TRP3_CharacterTooltip = Frame("GameTooltip")
local tooltip = TRP3_CharacterTooltip
tooltip.NineSlice = Frame()
tooltip.NineSlice.GetBorderColor = function(self) return unpack(self.edge) end
tooltip.NineSlice.edge = { 1, 1, 1, 1 }
function tooltip:SetBorderColor(r, g, b, a) self.NineSlice.edge = { r, g, b, a or 1 } end
TRP3_Addon = { Events = { PAGE_OPENED = "page", WORKFLOW_ON_FINISH = "finish" } }
TRP3_API = { RegisterCallback = function(_, event, callback) trpEvents[event] = callback end }
TRP3_MenuUtil = { PrepareRootMenuDescription = function() end }

local panel = TRP3_MainFrame
local native = { bgFile = "art", edgeFile = "edge", edgeSize = 8 }
local originalFill = copy(panel.fill)
panel.backdropInfo = native
panel.TopWoodBorder = Texture()
panel.regions = {
	Texture("Interface\\AddOns\\totalRP3\\Resources\\UI\\ui-frame-neutral-background.blp"),
	Texture("Interface\\Icons\\important-profile-art.blp")
}
local list = Frame()
list.GetView = function() end
list.GetFrames = function() end
list.RegisterCallback = function(self, event, callback) self[event] = callback end
panel.children[1] = list
local toolbarTexture = Texture(nil, "common-dropdown-c-button")
function TRP3_ToolbarFrame:UpdateButtons()
	self.regions = { toolbarTexture }
end
events.ADDON_LOADED(nil, "ADDON_LOADED", "totalRP3")
assert(overlayCount == 1 and transferred == 1 and skin:OwnsTooltip(tooltip))
assert(panel.backdropInfo.edgeFile == "border-tooltip" and panel.TopWoodBorder.alpha == 0)
assert(panel.regions[1].color[1] < 1 and panel.regions[2].color[1] == 1)
trpEvents.finish()
assert(overlayCount == 1 and panel.backdropInfo.edgeFile == "border-tooltip")
assert(same(tooltip.children[1].edge, { .2, .3, .4, 1 }))
tooltip:SetBorderColor(.2, .68, .7)
assert(same(tooltip.children[1].edge, { .2, .68, .7, 1 }))
tooltip:SetBorderColor(1, 1, 1)
assert(same(tooltip.children[1].edge, { .2, .3, .4, 1 }))

local page = Frame()
page.regions[1] = Texture(nil, "common-dropdown-c-button")
panel.children[2] = page
trpEvents.page()
assert(page.regions[1].color[1] < 1)
local row = Frame("Button")
row.regions[1] = Texture("Interface\\Buttons\\UI-Panel-Button-Up.blp")
list.children[1] = row
list.row(list, row)
assert(row.regions[1].color[1] < 1)
TRP3_ToolbarFrame:UpdateButtons()
assert(toolbarTexture.color[1] < 1)

local menu, description = Frame(), {
	AddMenuAcquiredCallback = function(self, callback) self.acquire = callback end,
	AddMenuReleasedCallback = function(self, callback) self.release = callback end
}
menu.regions[1] = Texture(nil, "common-dropdown-bg")
TRP3_MenuUtil.PrepareRootMenuDescription(description)
description.acquire(menu)
assert(menu.regions[1].color[1] < 1)
description.release(menu)
assert(menu.regions[1].color[1] == 1, "the shared pooled menu returns its original texture")
description.acquire(menu)

local pin = Frame()
local map = {}
map.EnumeratePinsByTemplate = function(_, template)
	assert(template == "TRP3_PlayerMapPinTemplate")
	local yielded
	return function()
		if not yielded then yielded = true return pin end
	end
end
TRP3_API.MapDataProvider = {
	pinTemplate = "TRP3_PlayerMapPinTemplate",
	GetMap = function() return map end,
	RefreshAllData = function() end
}
trpEvents.finish()
local rim = pin.children[1]
assert(rim and rim.shown and rim.backdropInfo.edgeFile == "border-tooltip")
TRP3_API.MapDataProvider:RefreshAllData()
assert(#pin.children == 1, "map refresh reuses pin styling")

combat = true
skin:SetEnabled(false)
assert(panel.TopWoodBorder.alpha == 0, "combat defers visual restoration")
combat = false
events.PLAYER_REGEN_ENABLED()
assert(panel.TopWoodBorder.alpha == 1 and panel.backdropInfo == native)
assert(same(panel.fill, originalFill) and row.regions[1].color[1] == 1)
assert(menu.regions[1].color[1] == 1 and not rim.shown)
assert(tooltip.NineSlice.alpha == 1 and not tooltip.children[1].shown and not skin:OwnsTooltip(tooltip))
skin:SetEnabled(true)
assert(overlayCount == 2 and tooltip.children[1].shown and rim.shown)
print("TRP3 skin lifecycle, recycled rows, shared-menu restoration, map-pin reuse and tooltip borders passed")

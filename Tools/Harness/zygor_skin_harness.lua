-- Exercise load order, native redraws, pooled rows and restoration without WoW.
local module, events, textures = {}, {}, {}
local ns = { db = { char = {} }, NewModule = function() return module end }
local noop = function() end
local function widget()
	local w = { alpha = 1, shown = true }
	for _, name in ipairs({ "SetTexCoord", "SetAllPoints", "SetPoint", "SetHeight",
		"SetSize", "SetVertexColor", "ClearAllPoints", "SetColorTexture" }) do w[name] = noop end
	function w:SetTexture(path) self.path = path end
	function w:SetAllPoints(relative) self.fill = relative end
	function w:SetPoint(point, relative, relativePoint) self[point] = { relative, relativePoint } end
	function w:SetParent(parent) self.parent = parent end
	function w:SetShown(v) self.shown = v end
	function w:Show() self.shown = true end
	function w:Hide() self.shown = false end
	function w:IsShown() return self.shown end
	function w:GetAlpha() return self.alpha end
	function w:SetAlpha(v) self.alpha = v end
	function w:CreateTexture(_, layer)
		local t = widget()
		t.parent, t.layer = self, layer
		textures[#textures+1] = t
		return t
	end
	return w
end
function module:RegisterEvent(event, callback) events[event] = callback end
function hooksecurefunc(obj, key, hook)
	local original = assert(obj[key])
	obj[key] = function(...) original(...) hook(...) end
end
local combat = false
function InCombatLockdown() return combat end
local line = widget()
line.tipgoal, line.back, line.label = {}, widget(), widget()
line.back.Center = {}
function line.back.Center:SetColorTexture(...) self.rgba = {...} end
function line.back:SetBackdropColor(...)
	self.native = {...}
	self.Center:SetColorTexture(...)
end
function line.back:GetBackdropColor() return unpack(self.native) end
line.back:SetBackdropColor(.65, .02, .03, .8)
local text, color = "|cffeeeeccOn top of a crate.|r", { .9, .9, .9, 1 }
function line.label:GetText() return text end
function line.label:SetText(t) text = t end
function line.label:GetTextColor() return unpack(color) end
function line.label:SetTextColor(...) color = { ... } end
local step = { Render = noop, Center = widget(), lines = { line } }
function step:ApplySkin() self.Center:Show() end
local border = widget()
border.Center, border.Back, border.TitleBar, border.Toolbar = widget(), widget(), widget(), widget()
border.Center.alpha = .78
border.Back.Center = widget()
border.LeftEdge, border.Back.BottomEdge = widget(), widget()
local scroll = widget()
local frame = { Border = border, Controls = { Scroll = scroll }, ApplySkin = noop, stepframes = {} }
function frame:AlignFrame() border.Back.BottomEdge:Show() end
function frame:AddStep(s) self.stepframes[1] = s end
local zgv = { Frame = frame, db = { profile = {} }, SetSkin = noop,
	Tabs = { ActiveTab = {Button = widget()}, SetAsCurrent = noop } }
local function tabLabel()
	local label = { color = {1, 1, 1, 1} }
	function label:GetTextColor() return unpack(self.color) end
	function label:SetTextColor(...) self.color = {...} end
	return label
end
local firstTab = zgv.Tabs.ActiveTab
firstTab.Text = tabLabel()
local early = arg[1] == "early"
if early then ZygorGuidesViewer = zgv end
assert(loadfile("Components/Misc/ZygorSkin.lua"))("AzeriteUI", ns)
module:OnInitialize()
assert(#textures == 0)
if not early then
	ZygorGuidesViewer = zgv
	events.ADDON_LOADED(module, "ADDON_LOADED", "ZygorGuidesViewerForever")
end
events.PLAYER_LOGIN(module, "PLAYER_LOGIN")
frame:AddStep(step)
module:SetChoice("Forged")
assert(textures[1].path:match("Forged$"))
assert(not step.Center.shown and line.back.Center.rgba[1] == .42)
local readingSurface, paper
for _, texture in ipairs(textures) do
	if texture.parent == scroll and texture.layer == "BACKGROUND" then readingSurface = texture end
	if texture.parent == border and texture.layer == "ARTWORK" then paper = texture end
end
assert(readingSurface and readingSurface.shown and readingSurface.path:match("Forged$"))
step:ApplySkin()
assert(not step.Center.shown)
module:SetChoice("Glass")
assert(not border.Center.shown and not border.Back.Center.shown and not step.Center.shown)
assert(not readingSurface.shown and not paper.shown and line.back.Center.rgba[1] == .46)
assert(not border.LeftEdge.shown and not border.Back.BottomEdge.shown)
frame:ApplySkin()
assert(not border.Center.shown)
module:SetChoice("Field-Journal")
local wax
for _, texture in ipairs(textures) do
	if texture.path and texture.path:match("Journal%-Wax$") then wax = texture end
end
assert(wax and wax.shown and wax.alpha == 1 and not step.Center.shown)
assert(not readingSurface.shown and paper.shown and paper.path:match("Field%-Journal$"))
assert(paper.TOP[1] == border.Toolbar and paper.BOTTOM[1] == border)
assert(paper.LEFT[1] == border and paper.RIGHT[1] == border)
zgv.db.profile.resizeup = true
frame:AlignFrame()
assert(paper.TOP[1] == border and paper.BOTTOM[1] == border.Toolbar)
assert(not border.Back.BottomEdge.shown)
assert(wax.fill == line.back and line.back.Center.rgba[4] == 0)
assert(line.back:GetBackdropColor() == .65)
line.back:SetBackdropColor(.2, .6, .2, .9)
assert(not wax.shown and line.back.Center.rgba[2] == .6 and line.back.Center.rgba[4] == .9 * .22)
assert(color[1] == .15 and text:find("|cff123330", 1, true))
line.back:SetBackdropColor(.7, .2, .1, .7)
assert(wax.shown and wax.alpha == 1 and line.back.Center.rgba[4] == 0)
assert(firstTab.Text.color[1] == .15)
local nextTab = {Button = widget(), Text = tabLabel()}
zgv.Tabs.ActiveTab = nextTab
zgv.Tabs:SetAsCurrent()
assert(firstTab.Text.color[1] == 1 and nextTab.Text.color[1] == .15)
assert(color[1] == 1 and text:find("|cffffde9f", 1, true))
assert(not border.Center.shown and not border.Back.Center.shown and border.Center.alpha == .78)
-- Provider assigns a quest row to the same object.
line.tipgoal, line.goal, text = nil, {}, "Quest"
step:Render()
assert(color[1] == 1 and text == "Quest")
line.tipgoal, text = {}, "|cffeeeeccA new tip|r"
step:Render()
frame.stepframes = {}
module:SetChoice("default")
assert(line.back.Center.rgba[1] == .7 and line.back.Center.rgba[2] == .2)
assert(step.Center.shown and not wax.shown and not readingSurface.shown)
assert(text == "|cffeeeeccA new tip|r" and color[1] == .9 and not ns.db.char.zygorSkin)
assert(nextTab.Text.color[1] == 1)
assert(border.Center.shown and border.Back.Center.shown and border.LeftEdge.shown and border.Back.BottomEdge.shown)
for _, t in ipairs(textures) do assert(not t.shown) end
combat = true
module:SetChoice("Glass")
assert(not ns.db.char.zygorSkin)
print("Zygor skin load, switch, redraw, pool and restore passed", arg[1])

-- Exercise load order, native redraws, pooled rows and restoration without WoW.
local module, events, textures = {}, {}, {}
local ns = { db = { char = {} }, NewModule = function() return module end }
local noop = function() end
local function widget()
	local w = { alpha = 1, shown = true }
	for _, name in ipairs({ "SetTexCoord", "SetAllPoints", "SetPoint", "SetHeight",
		"SetSize", "SetVertexColor", "ClearAllPoints", "SetColorTexture" }) do w[name] = noop end
	function w:SetTexture(path) self.path = path end
	function w:SetParent(parent) self.parent = parent end
	function w:SetShown(v) self.shown = v end
	function w:Show() self.shown = true end
	function w:Hide() self.shown = false end
	function w:IsShown() return self.shown end
	function w:GetAlpha() return self.alpha end
	function w:SetAlpha(v) self.alpha = v end
	function w:CreateTexture()
		local t = widget()
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
local text, color = "|cffeeeeccOn top of a crate.|r", { .9, .9, .9, 1 }
function line.label:GetText() return text end
function line.label:SetText(t) text = t end
function line.label:GetTextColor() return unpack(color) end
function line.label:SetTextColor(...) color = { ... } end
local step = { Render = noop, Center = widget(), lines = { line } }
local border = { Center = widget(), Back = widget(), TitleBar = widget(), Toolbar = widget() }
border.Center.alpha = .78
border.Back.Center = widget()
local frame = { Border = border, ApplySkin = noop, stepframes = {} }
function frame:AddStep(s) self.stepframes[1] = s end
local zgv = { Frame = frame, SetSkin = noop, Tabs = { ActiveTab = {Button = widget()}, SetAsCurrent = noop } }
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
module:SetChoice("Glass")
assert(border.Center.alpha == .78 * .52 and step.Center.alpha == .35)
frame:ApplySkin()
assert(border.Center.alpha == .78 * .52)
module:SetChoice("Field-Journal")
assert(firstTab.Text.color[1] == .15)
local nextTab = {Button = widget(), Text = tabLabel()}
zgv.Tabs.ActiveTab = nextTab
zgv.Tabs:SetAsCurrent()
assert(firstTab.Text.color[1] == 1 and nextTab.Text.color[1] == .15)
assert(color[1] == .15 and text:find("|cff155453", 1, true))
assert(border.Center.alpha == .78)
-- Provider assigns a quest row to the same object.
line.tipgoal, line.goal, text = nil, {}, "Quest"
step:Render()
assert(color[1] == .9 and text == "Quest")
line.tipgoal, text = {}, "|cffeeeeccA new tip|r"
step:Render()
frame.stepframes = {}
module:SetChoice("default")
assert(text == "|cffeeeeccA new tip|r" and color[1] == .9 and not ns.db.char.zygorSkin)
assert(nextTab.Text.color[1] == 1)
for _, t in ipairs(textures) do assert(not t.shown) end
combat = true
module:SetChoice("Glass")
assert(not ns.db.char.zygorSkin)
print("Zygor skin load, switch, redraw, pool and restore passed", arg[1])

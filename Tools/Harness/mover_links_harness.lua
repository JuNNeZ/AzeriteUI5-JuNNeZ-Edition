-- Mover links in the real Core/MovableFrameManager.lua, offline.
--
-- Frames here keep their real size and point and answer GetLeft/GetTop/GetCenter from
-- them, on a 1920x1080 UIParent at scale 1, because a stub answering constants would
-- hide exactly what this checks: a follower moving with its target, chains, cycles,
-- rescaling, combat and the Legacy HUD keeping its own links. Modules are modelled by
-- one listener saving MFM_PositionUpdated, as the prototype does. It cannot say how it
-- looks in game, or how Edit Mode feels. See Docs/Mover Anchoring Plan.md.
--
-- lua Tools/Harness/mover_links_harness.lua .

local root = arg and arg[1] or "."

local checks, failures = 0, 0
local function check(value, label, detail)
	checks = checks + 1
	if (not value) then
		failures = failures + 1
		print("FAIL: " .. label .. (detail ~= nil and ("  (" .. tostring(detail) .. ")") or ""))
	end
end
local function near(a, b, e) return type(a) == "number" and type(b) == "number" and math.abs(a - b) < (e or 0.02) end

--------------------------------------------------------------------------
-- Frames with geometry
--------------------------------------------------------------------------
local UI_W, UI_H = 1920, 1080
local FRACTIONS = {
	TOPLEFT = { 0, 1 }, TOP = { .5, 1 }, TOPRIGHT = { 1, 1 },
	LEFT = { 0, .5 }, CENTER = { .5, .5 }, RIGHT = { 1, .5 },
	BOTTOMLEFT = { 0, 0 }, BOTTOM = { .5, 0 }, BOTTOMRIGHT = { 1, 0 }
}

-- A table, as in the game: the manager reads getmetatable(frame).__index for base methods.
-- Any other capitalized method is a no-op setter; lowercase fields read nil.
local Methods = setmetatable({}, { __index = function(_, k)
	if (type(k) == "string" and k:match("^%u")) then return function(self) return self end end
end })
local FrameMT = { __index = Methods }

local function NewFrame()
	return setmetatable({ _w = 0, _h = 0, _shown = true, _scripts = {} }, FrameMT)
end

Methods.SetSize = function(self, w, h) self._w, self._h = w, h end
Methods.SetWidth = function(self, w) self._w = w end
Methods.SetHeight = function(self, h) self._h = h end
Methods.GetSize = function(self) return self._w, self._h end
Methods.GetWidth = function(self) return self._w end
Methods.GetHeight = function(self) return self._h end
Methods.ClearAllPoints = function(self) self._point = nil end
Methods.SetAllPoints = function(self) self._point = nil end
Methods.SetPoint = function(self, point, a, b, c, d)
	-- SetPoint(point, x, y) or SetPoint(point, relativeTo, relativePoint, x, y), all on UIParent here.
	local x, y
	if (type(a) == "number") then x, y = a, b else x, y = c or 0, d or 0 end
	self._point = { point, x, y }
end
Methods.GetPoint = function(self) local p = self._point; if (p) then return p[1], nil, p[1], p[2], p[3] end end
Methods.GetLeftBottom = function(self)
	local p = self._point
	if (not p) then return 0, 0 end
	local f = FRACTIONS[p[1]]
	return UI_W * f[1] + p[2] - self._w * f[1], UI_H * f[2] + p[3] - self._h * f[2]
end
Methods.GetLeft = function(self) local l = self:GetLeftBottom(); return l end
Methods.GetBottom = function(self) local _, b = self:GetLeftBottom(); return b end
Methods.GetRight = function(self) local l = self:GetLeftBottom(); return l + self._w end
Methods.GetTop = function(self) local _, b = self:GetLeftBottom(); return b + self._h end
Methods.GetCenter = function(self) local l, b = self:GetLeftBottom(); return l + self._w / 2, b + self._h / 2 end
Methods.GetRect = function(self) local l, b = self:GetLeftBottom(); return l, b, self._w, self._h end
Methods.GetEffectiveScale = function() return 1 end
Methods.GetScale = function() return 1 end
Methods.Show = function(self) local was = self._shown; self._shown = true; if (not was and self._scripts.OnShow) then self._scripts.OnShow(self) end end
Methods.Hide = function(self) self._shown = false end
Methods.IsShown = function(self) return self._shown end
Methods.IsVisible = function(self) return self._shown end
Methods.SetScript = function(self, name, fn) self._scripts[name] = fn end
Methods.IsDragging = function() return false end
Methods.IsMovable = function() return true end
Methods.CreateFontString = function() return NewFrame() end
Methods.CreateTexture = function() return NewFrame() end
Methods.GetText = function(self) return self._text end
Methods.SetText = function(self, text) self._text = text end

local UIParent = NewFrame()
UIParent:SetSize(UI_W, UI_H)
UIParent._point = { "BOTTOMLEFT", 0, 0 }

local inCombat = false

_G.UIParent = UIParent
_G.WorldFrame = { GetWidth = function() return UI_W end, GetHeight = function() return 768 end }
_G.CreateFrame = function() return NewFrame() end
_G.InCombatLockdown = function() return inCombat end
_G.IsShiftKeyDown = function() return false end
_G.IsControlKeyDown = function() return false end
_G.IsAltKeyDown = function() return false end
local cursorX, cursorY = 0, 0
_G.GetCursorPosition = function() return cursorX, cursorY end
_G.C_Timer = { After = function(_, fn) fn() end }
_G.CloseSpecialWindows = function() end

local LibStub = setmetatable({}, { __call = function(_, name)
	if (name == "AceLocale-3.0") then
		return { GetLocale = function() return setmetatable({}, { __index = function(_, k) return k end }) end }
	end
	if (name == "AceConfigRegistry-3.0") then
		return {
			RegisterOptionsTable = function(_, app, options) _G.__MFM_OPTIONS = options end,
			GetOptionsTable = function() return nil end
		}
	end
	if (name == "AceGUI-3.0") then
		return { Create = function()
			local frame = NewFrame()
			frame:Hide()
			return { frame = frame, status = {}, Hide = function() end, SetStatusTable = function() end }
		end }
	end
	return setmetatable({}, { __index = function() return function() end end })
end })
_G.LibStub = LibStub

--------------------------------------------------------------------------
-- The addon namespace
--------------------------------------------------------------------------
local callbacks = {}
local color = setmetatable({ 1, 1, 1, colorCode = "|cffffffff" }, {})
local ns = {
	BackdropTemplate = nil,
	Colors = setmetatable({ anchor = setmetatable({}, { __index = function() return color end }) },
		{ __index = function() return color end }),
	db = { profile = {} },
	LegacyHUD = { active = false, IsActive = function(self) return self.active end },
	API = {
		GetFont = function() return {} end,
		GetMedia = function() return "" end,
		GetEffectiveScale = function() return 1 end,
		GetFrameScaleMultiplier = function() return 1 end,
		FRAME_SCALE_MIN = .5, FRAME_SCALE_MAX = 2
	}
}
ns.RegisterCallback = function(owner, event, method)
	callbacks[event] = callbacks[event] or {}
	callbacks[event][#callbacks[event] + 1] = { owner = owner, method = method }
end
function ns:Fire(event, ...)
	for _, cb in ipairs(callbacks[event] or {}) do
		local fn = type(cb.method) == "function" and cb.method or cb.owner[cb.method]
		fn(cb.owner, event, ...)
	end
end
local modules = {}
function ns:NewModule(name)
	local module = {
		GetName = function() return name end,
		RegisterEvent = function() end, UnregisterEvent = function() end,
		RegisterChatCommand = function() end,
		SecureHook = function() end, IsHooked = function() return false end, Unhook = function() end
	}
	modules[name] = module
	return module
end
function ns:GetModule(name) return modules[name] end

assert(loadfile(root .. "/Core/API/Anchoring.lua"))("AzeriteUI5_JuNNeZ_Edition", ns)
assert(loadfile(root .. "/Core/API/Snapping.lua"))("AzeriteUI5_JuNNeZ_Edition", ns)
assert(loadfile(root .. "/Core/MovableFrameManager.lua"))("AzeriteUI5_JuNNeZ_Edition", ns)

local MFM = modules.MovableFramesManager
MFM:OnInitialize()
local RealRefresh = MFM.RefreshMFMFrame
MFM.RefreshMFMFrame = function() end

-- The modules: each saves what its mover reports, the way the prototype does.
local saved = {}
local saver = {}
saver.OnAnchorEvent = function(_, event, anchor, point, x, y)
	if (event == "MFM_PositionUpdated") then saved[anchor] = { point, x, y } end
end
ns.RegisterCallback(saver, "MFM_PositionUpdated", "OnAnchorEvent")

local function Mover(key, w, h, point, x, y)
	local anchor = MFM:RequestAnchor(key)
	anchor:SetSize(w, h)
	anchor:SetPoint(point, x, y)
	return anchor
end
local function Rect(anchor) return anchor:GetRect() end
local function MoveTo(anchor, point, x, y) anchor:UpdatePosition(point, x, y) end

--------------------------------------------------------------------------
-- Checks
--------------------------------------------------------------------------
local player = Mover("PlayerFrame", 400, 100, "BOTTOMLEFT", 100, 200)
local target = Mover("TargetFrame", 300, 80, "TOPRIGHT", -100, -100)
local tot = Mover("ToTFrame", 100, 40, "TOPRIGHT", -50, -300)
local loose = Mover(nil, 50, 50, "CENTER", 0, 0)

check(MFM:GetAnchorByKey("PlayerFrame") == player, "a keyed mover is found by its key")
check(loose:GetKey() == nil, "an unkeyed mover has no key")
check(MFM:RequestAnchor("PlayerFrame"):GetKey() == nil, "a second mover with a taken key gets none")

-- Linking keeps the follower where it is.
local tl, tb = Rect(target)
local ok, why = MFM:SetAnchorLink(target, player, "LEFT", "RIGHT")
check(ok, "Target links to Player", why)
local tl2, tb2 = Rect(target)
check(near(tl, tl2) and near(tb, tb2), "linking does not move it", tostring(tl2) .. "," .. tostring(tb2))

-- Moving the target of a link moves the follower by the same amount, and it is saved.
MoveTo(player, "BOTTOMLEFT", 150, 180)
local tl3, tb3 = Rect(target)
check(near(tl3 - tl, 50) and near(tb3 - tb, -20), "Target follows Player", tostring(tl3 - tl) .. "," .. tostring(tb3 - tb))
check(saved[target] and saved[target][1] == "TOPRIGHT", "the follower is saved through MFM_PositionUpdated, own point kept",
	saved[target] and saved[target][1])

-- Chains: ToT follows Target follows Player.
check(MFM:SetAnchorLink(tot, target, "TOP", "BOTTOM"), "ToT links to Target")
local ol = Rect(tot)
MoveTo(player, "BOTTOMLEFT", 160, 180)
check(near(Rect(tot) - ol, 10), "a chain moves together", Rect(tot) - ol)

-- Cycles are refused, the targets list leaves them out.
local cyc, reason = MFM:SetAnchorLink(player, tot, "CENTER", "CENTER")
check(cyc == false and reason == "cycle", "Player cannot follow ToT", reason)
local listed = {}
for _, a in ipairs(MFM:GetLinkTargets(player)) do listed[a] = true end
check(not listed[tot] and not listed[target] and not listed[player] and not listed[loose], "targets exclude loops, itself and unkeyed")
check(select(2, MFM:SetAnchorLink(loose, player)) == "nokey", "an unkeyed mover cannot follow")

-- Dropping a follower somewhere else (the real OnDragStop, reading the overlay as a drag
-- leaves it) rewrites its offset and keeps the link.
target.Overlay:ClearAllPoints()
target.Overlay:SetSize(target:GetSize())
target.Overlay:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -200, -100)
target:OnDragStop()
check(target:GetLink() ~= nil, "a dragged follower keeps its link")
local tl4 = Rect(target)
MoveTo(player, "BOTTOMLEFT", 170, 180)
check(near(Rect(target) - tl4, 10), "after a hand move it follows from its new spot", Rect(target) - tl4)

-- A follower that rescales stays on its link point.
local link = target:GetLink()
target:SetScale(1.5)
local l, b, _, h = Rect(target)
local pl, pb, pw, ph = Rect(player)
check(near(l, pl + pw + link.x) and near(b + h / 2, pb + ph / 2 + link.y), "a rescaled follower keeps its LEFT on Player's RIGHT",
	tostring(l) .. " vs " .. tostring(pl + pw + link.x))
target:SetScale(1)

-- Combat: nothing moves, it waits, and goes after.
inCombat = true
local before = Rect(target)
MoveTo(player, "BOTTOMLEFT", 200, 180)
check(near(Rect(target), before), "in combat the follower waits")
check(MFM.linksPending == true, "and the pass is owed")
check(select(2, MFM:SetAnchorLink(target, nil)) == "combat", "links cannot change in combat")
inCombat = false
MFM:ApplyAllLinks()
check(near(Rect(target) - before, 30), "after combat it catches up", Rect(target) - before)

-- A disabled target: the follower stays put.
player:Disable()
local still = Rect(target)
MoveTo(player, "BOTTOMLEFT", 260, 180)
MFM:ApplyAllLinks()
check(near(Rect(target), still), "a disabled target leaves its follower in place")
player:SetEnabled(true)

-- Rescaling everything keeps the relation, and the gap shrinks with the layout.
local gap = target:GetLink().x
MFM:RescaleAnchors(.8)
check(near(target:GetLink().x, gap * .8), "the link's offset scales with the layout", tostring(target:GetLink().x) .. " vs " .. tostring(gap * .8))
local l8, b8, _, h8 = Rect(target)
local pl8, pb8, pw8, ph8 = Rect(player)
local link8 = target:GetLink()
check(near(l8, pl8 + pw8 + link8.x, .05) and near(b8 + h8 / 2, pb8 + ph8 / 2 + link8.y, .05), "after a rescale Target still sits on Player",
	tostring(l8) .. " vs " .. tostring(pl8 + pw8 + link8.x))

-- Legacy keeps its own links.
ns.LegacyHUD.active = true
check(target:GetLink() == nil, "the Legacy HUD does not see Azerite's links")
ns.LegacyHUD.active = false
check(target:GetLink() ~= nil, "and Azerite still has them")

-- Removing a link leaves the frame and stops following.
check(MFM:SetAnchorLink(target, nil), "a link can be removed")
local fixed = Rect(target)
MoveTo(player, "BOTTOMLEFT", 100, 100)
check(near(Rect(target), fixed), "an unlinked frame stays put")
check(ns.db.profile.moverLinks.azerite.TargetFrame == nil, "and the saved link is gone")

-- A saved loop (hand-edited SavedVariables) must not hang or recurse.
ns.db.profile.moverLinks.azerite.PlayerFrame = { target = "ToTFrame", point = "CENTER", relativePoint = "CENTER", x = 0, y = 0 }
ns.db.profile.moverLinks.azerite.TargetFrame = { target = "PlayerFrame", point = "CENTER", relativePoint = "CENTER", x = 0, y = 0 }
ns.db.profile.moverLinks.azerite.ToTFrame = { target = "TargetFrame", point = "CENTER", relativePoint = "CENTER", x = 0, y = 0 }
local fine = pcall(function() MFM:ApplyAllLinks(); MoveTo(player, "BOTTOMLEFT", 120, 100) end)
check(fine, "a saved loop runs without error")

-- The /lock window's anchoring rows, through the real options table.
ns.db.profile.moverLinks = nil
modules.Options = { GenerateProfileMenu = function() return { args = {} }, 0 end }
MFM:GenerateMFMFrame()
local args = _G.__MFM_OPTIONS and _G.__MFM_OPTIONS.args
check(args and args.anchorTarget and args.anchorPoint and args.anchorOffsetX, "the /lock window has the anchoring rows")
if (args and args.anchorTarget) then
	local info = function(key) return { key } end
	check(args.anchorTarget.hidden(info("anchorTarget")), "nothing selected: rows hidden")
	target:OnClick("LeftButton")
	check(not args.anchorTarget.hidden(info("anchorTarget")) and args.anchorPoint.hidden(info("anchorPoint")),
		"Target selected: Anchor To shown, point rows hidden until linked")
	local values = args.anchorTarget.values(info("anchorTarget"))
	check(values.NONE and values.PlayerFrame and not values.TargetFrame, "the list offers Player, not Target itself")
	local sorting = args.anchorTarget.sorting(info("anchorTarget"))
	check(sorting[1] == "NONE" and #sorting == 3, "sorted with None first", #sorting)
	check(args.anchorTarget.get(info("anchorTarget")) == "NONE", "not anchored yet")

	local before = Rect(target)
	args.anchorTarget.set(info("anchorTarget"), "PlayerFrame")
	check(args.anchorTarget.get(info("anchorTarget")) == "PlayerFrame" and near(Rect(target), before), "choosing Player links it in place")
	check(not args.anchorPoint.hidden(info("anchorPoint")) and args.anchorPoint.get(info("anchorPoint")) == "CENTER", "points shown, CENTER by default")

	args.anchorPoint.set(info("anchorPoint"), "LEFT")
	args.anchorRelativePoint.set(info("anchorRelativePoint"), "RIGHT")
	check(near(Rect(target), before) and target:GetLink().point == "LEFT" and target:GetLink().relativePoint == "RIGHT",
		"changing points keeps the frame where it is")

	args.anchorOffsetX.set(info("anchorOffsetX"), "0")
	args.anchorOffsetY.set(info("anchorOffsetY"), "0")
	local l0, b0, _, h0 = Rect(target)
	local pl0, pb0, pw0, ph0 = Rect(player)
	check(near(l0, pl0 + pw0) and near(b0 + h0 / 2, pb0 + ph0 / 2), "distance 0 puts Target's LEFT on Player's RIGHT")
	check(args.anchorOffsetX.get(info("anchorOffsetX")) == "0", "and reads back 0", args.anchorOffsetX.get(info("anchorOffsetX")))

	inCombat = true
	check(args.anchorTarget.disabled(info("anchorTarget")), "disabled in combat")
	inCombat = false

	args.anchorTarget.set(info("anchorTarget"), "NONE")
	check(target:GetLink() == nil and near(Rect(target), l0), "None removes the link in place")
end

-- The frame settings panel draws the same six rows, the same tables.
local position = MFM:GetPositionOptions()
check(position and position.args, "the Position rows are offered to the frame settings panel")
if (position and args) then
	for _, key in ipairs({ "scale", "anchorTarget", "anchorPoint", "anchorRelativePoint", "anchorOffsetX", "anchorOffsetY" }) do
		check(position.args[key] == args[key], "Position row is the /lock row: " .. key)
	end
end

-- Snapping while dragging a mover that has followers (optimization 1 and 2).
ns.db.profile.moverLinks = nil
local snapA = Mover("SnapA", 100, 50, "BOTTOMLEFT", 100, 100)
local snapB = Mover("SnapB", 100, 50, "BOTTOMLEFT", 500, 100)
local snapC = Mover(nil, 100, 50, "BOTTOMLEFT", 900, 600)
check(MFM:SetAnchorLink(snapB, snapA, "BOTTOMLEFT", "BOTTOMLEFT"), "SnapB follows SnapA")
-- Movers are snap targets only while shown, as in /lock or Edit Mode. Everything else off screen.
for anchor in pairs({ [player] = 1, [target] = 1, [tot] = 1, [loose] = 1 }) do anchor:Hide() end
snapA:Show(); snapB:Show(); snapC:Show()

local function DragTo(anchor, left, bottom)
	local w, h = anchor:GetSize()
	cursorX, cursorY = left + w / 2, bottom + h / 2
	anchor:UpdateOverlay()
	return anchor.Overlay:GetLeft(), anchor.Overlay:GetBottom()
end

snapA:OnDragStart("LeftButton")
local left = DragTo(snapA, 503, 300)
check(near(left, 503), "a dragged mover does not snap to its own follower", left)
left = DragTo(snapA, 896, 300)
check(near(left, 900), "it still snaps to other movers", left)
-- The lines were taken when the drag began: a mover moved since is not chased.
snapC:UpdatePosition("BOTTOMLEFT", 1300, 600)
left = DragTo(snapA, 1296, 300)
check(near(left, 1296), "snap lines are built once per drag", left)
snapA:OnDragStop()
snapA:OnDragStart("LeftButton")
left = DragTo(snapA, 1296, 300)
check(near(left, 1300), "and built again for the next drag", left)
snapA:OnDragStop()

-- A dragged follower still snaps to its own target.
snapB:OnDragStart("LeftButton")
local targetLeft = snapA:GetLeft()
left = DragTo(snapB, targetLeft + 4, 450)
check(near(left, targetLeft), "a follower snaps to the mover it follows", tostring(left) .. " vs " .. tostring(targetLeft))
snapB:OnDragStop()

-- Optimization 3: the latent SetWidth / SetHeight locals.
check(pcall(snapC.SetWidth, snapC, 10), "SetWidth on a small mover works")
check(pcall(snapC.SetHeight, snapC, 300), "SetHeight works")

-- Optimization 4: several refreshes in one frame redraw once, and none while nothing is open.
local timers = {}
_G.C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end }
local panelRefreshes, panelShown = 0, false
ns.OptionsKit = { FramePanel = {
	IsShown = function() return panelShown end,
	Refresh = function() panelRefreshes = panelRefreshes + 1 end,
	Close = function() end, GetAnchor = function() end, Reposition = function() end, Open = function() end
} }
MFM.RefreshMFMFrame = RealRefresh
MFM:RefreshMFMFrame()
check(#timers == 0, "nothing open: no refresh is queued", #timers)
panelShown = true
MFM:RefreshMFMFrame(); MFM:RefreshMFMFrame(); MFM:RefreshMFMFrame()
check(#timers == 1, "three asks in one frame queue one refresh", #timers)
if (timers[1]) then timers[1]() end
check(panelRefreshes == 1, "and it runs once", panelRefreshes)
MFM:RefreshMFMFrame()
check(#timers == 2, "the next frame can queue again", #timers)
MFM.RefreshMFMFrame = function() end
ns.OptionsKit = nil
_G.C_Timer = { After = function(_, fn) fn() end }

print(string.format("mover links: %d checks, %d failures", checks, failures))
os.exit(failures == 0 and 0 or 1)

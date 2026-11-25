-- Offline harness for Core/MoverGhosts.lua: when a mover counts as empty, when
-- its ghost and eye show, the per-profile hidden choice and the master switch.
-- Run: lua.exe Tools/Harness/mover_ghosts_harness.lua <repo root>
-- Frames are a small model with real parent visibility (IsVisible follows the
-- parent chain), not the shared stubs, whose IsShown answers a constant. It
-- cannot show what a ghost looks like; that is a live check.
local root = arg[1] or "."
local checks, failures = 0, 0
local function check(ok, label)
	checks = checks + 1
	if (not ok) then failures = failures + 1; print("FAIL: " .. label) end
end

-- Frame model
--------------------------------------
local Frame = {}
Frame.__index = function(t, key)
	local method = rawget(Frame, key)
	if (method) then return method end
	if (type(key) == "string" and key:match("^%u")) then
		return function() return t end -- other widget setters are no-ops
	end
end
local function New(parent, w, h)
	local f = setmetatable({ shown = true, parent = parent, children = {}, regions = {}, w = w or 100, h = h or 40 }, Frame)
	if (parent) then table.insert(parent.children, f) end
	return f
end
function Frame:Show() self.shown = true end
function Frame:Hide() self.shown = false end
function Frame:SetShown(v) self.shown = v and true or false end
function Frame:IsShown() return self.shown end
function Frame:IsVisible()
	if (not self.shown) then return false end
	if (self.parent) then return self.parent:IsVisible() end
	return true
end
function Frame:GetChildren() return unpack(self.children) end
function Frame:GetRegions() return unpack(self.regions) end
function Frame:GetSize() return self.w, self.h end
function Frame:GetFrameLevel() return 1 end
function Frame:GetFrameStrata() return "MEDIUM" end
function Frame:SetScript(name, fn) self.scripts = self.scripts or {}; self.scripts[name] = fn end
function Frame:CreateTexture()
	local t = New(nil); t.parent = self; table.insert(self.regions, t)
	function t:SetDesaturated(v) self.desaturated = v end
	return t
end

UIParent = New(nil, 1920, 1080)
function CreateFrame(_, _, parent) return New(parent) end
function InCombatLockdown() return false end
issecretvalue = function() return false end
GameTooltip = New(UIParent); function GameTooltip:IsOwned() return false end

-- Addon namespace
--------------------------------------
local modules = {}
local callbacks = {}
local ns = {
	db = { profile = { moverGhosts = true, moverGhostsHidden = {} } },
	API = { GetMedia = function(name) return name end },
	GetModule = function(_, name) return modules[name] end,
	RegisterCallback = function(owner, event, method) callbacks[event] = function(...) return owner[method](owner, event, ...) end end
}
local built = {}
ns.ThemeBarPreview = {
	Create = function(_, kind, parent)
		local owner = New(parent, 50, 20)
		built[#built + 1] = kind
		return { owner = owner, bars = {}, db = {}, kind = kind }
	end,
	StyleEntry = function() end
}
LibStub = function() return { GetLocale = function() return setmetatable({}, { __index = function(_, k) return k end }) end } end

assert(loadfile(root .. "/Core/MoverGhosts.lua"))("AzeriteUI", ns)
local Ghosts = ns.MoverGhosts
check(Ghosts and callbacks.MFM_AnchorShown, "module loads and listens for shown movers")

local function MakeAnchor(key, w, h)
	local anchor = New(UIParent, w, h)
	anchor.Overlay = New(anchor, w, h)
	anchor.GetKey = function() return key end
	return anchor
end

-- Target: a single unit frame, hidden without a target.
local target = New(UIParent, 300, 80); target.unit = "target"; target:Hide()
modules.TargetFrame = { frame = target }
local targetAnchor = MakeAnchor("TargetFrame", 300, 80)
callbacks.MFM_AnchorShown(targetAnchor)
local state = function(anchor)
	local ghost, eye
	for _, child in ipairs(anchor.Overlay.children) do
		if (child.key) then eye = child elseif (not ghost) then ghost = child end
	end
	return ghost, eye
end
local ghost, eye = state(targetAnchor)
check(ghost and ghost:IsShown(), "empty target frame shows a ghost")
check(eye and eye:IsShown(), "empty target frame shows the eye")
check(built[1] == "targetHi", "target ghost uses the themed target layout")

target:Show()
Ghosts:RefreshAll()
check(not ghost:IsShown() and not eye:IsShown(), "target present: ghost and eye hide")
target:Hide()
Ghosts:RefreshAll()
check(ghost:IsShown(), "target gone again: ghost back")

-- The eye hides this ghost only, saved per profile.
eye.scripts.OnClick(eye)
check(ns.db.profile.moverGhostsHidden.TargetFrame == true, "eye saves the hidden choice")
check(not ghost:IsShown() and eye:IsShown(), "hidden ghost: ghost off, eye stays to bring it back")
check(eye.Icon.desaturated == true, "hidden ghost: eye greyed")
eye.scripts.OnClick(eye)
check(ns.db.profile.moverGhostsHidden.TargetFrame == nil and ghost:IsShown(), "eye again: ghost back, choice cleared")

-- Party: a header whose unit buttons are its children.
local party = New(UIParent, 160, 100)
local member = New(party); member.unit = "party1"; member:Hide()
modules.PartyFrames = { frame = party }
local partyAnchor = MakeAnchor("PartyFrames", 160, 100)
built = {}
callbacks.MFM_AnchorShown(partyAnchor)
local partyGhost = state(partyAnchor)
check(partyGhost and partyGhost:IsShown(), "party without members shows a ghost")
check(#built == 15, "party ghost tiles as many cells as fit (3 x 5 of 50x20 in 160x100), got " .. #built)
member:Show()
Ghosts:RefreshAll()
check(not partyGhost:IsShown(), "a visible party member hides the party ghost")

-- Raid container with content.
local raid = New(UIParent, 200, 200); raid.content = New(UIParent); raid.content:Hide()
modules.RaidFrame5 = { frame = raid }
check(Ghosts:IsEmpty("RaidFrame5"), "raid content hidden: empty")
raid.content:Show(); local raidUnit = New(raid.content); raidUnit.unit = "raid1"
check(not Ghosts:IsEmpty("RaidFrame5"), "raid unit visible: not empty")

-- Player castbar: frame always shown, empty outside a cast.
local castFrame = New(UIParent); castFrame.unit = "player"; castFrame.Castbar = New(castFrame); castFrame.Castbar:Hide()
modules.PlayerCastBarFrame = { frame = castFrame }
check(Ghosts:IsEmpty("PlayerCastBarFrame"), "castbar without a cast: empty")
castFrame.Castbar:Show()
check(not Ghosts:IsEmpty("PlayerCastBarFrame"), "castbar casting: not empty")

-- Other movers: a placeholder while the holder shows nothing.
local timers = New(UIParent); local bar = New(timers); bar:Hide()
modules.QuestTimers = { frame = timers }
local timersAnchor = MakeAnchor("QuestTimers", 120, 30)
built = {}
callbacks.MFM_AnchorShown(timersAnchor)
local timersGhost = state(timersAnchor)
check(timersGhost and timersGhost:IsShown() and #built == 0, "plain holder without content: placeholder, no themed build")
bar:Show()
Ghosts:RefreshAll()
check(not timersGhost:IsShown(), "holder with a visible child: placeholder hides")

-- A module that draws its own ghost (EnemyCasts.BuildMoverGhost) gets that, not the placeholder.
local casts = New(UIParent); casts:Hide()
local drawnInto
modules.EnemyCasts = { frame = casts, BuildMoverGhost = function(self, container) drawnInto = container; return true end }
local castsAnchor = MakeAnchor("EnemyCasts", 260, 186)
built = {}
callbacks.MFM_AnchorShown(castsAnchor)
local castsGhost = state(castsAnchor)
check(castsGhost and castsGhost:IsShown() and drawnInto == castsGhost and #built == 0, "module's own ghost builder used")

-- A builder that fails falls back to the placeholder instead of breaking the movers.
local broken = New(UIParent); broken:Hide()
modules.BrokenGhost = { frame = broken, BuildMoverGhost = function() error("boom") end }
local brokenAnchor = MakeAnchor("BrokenGhost", 100, 40)
callbacks.MFM_AnchorShown(brokenAnchor)
check(state(brokenAnchor) and state(brokenAnchor):IsShown(), "failing ghost builder: placeholder instead")
castsAnchor:Hide(); brokenAnchor:Hide()

-- A module without a frame gets nothing.
modules.NoFrame = {}
check(not Ghosts:IsEmpty("NoFrame"), "module without a frame: no ghost")

-- Master switch.
ns.db.profile.moverGhosts = false
Ghosts:RefreshAll()
check(not ghost:IsShown() and not eye:IsShown(), "master switch off: no ghosts or eyes")
ns.db.profile.moverGhosts = true
Ghosts:RefreshAll()
check(ghost:IsShown(), "master switch on: ghost back")

-- Movers closed: the driver stops.
targetAnchor:Hide(); partyAnchor:Hide(); timersAnchor:Hide()
Ghosts:RefreshAll()
check(not ghost:IsVisible(), "movers hidden: ghosts hidden with them")

print(string.format("mover ghosts: %d checks, %d failures", checks, failures))
if (failures > 0) then os.exit(1) end

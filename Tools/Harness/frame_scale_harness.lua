-- Master scale (/lock -> AzeriteUI Scale): real Core/API/Scale.lua and the real
-- MovableFrameModulePrototype handlers, fed what MovableFramesManager:RescaleAnchors
-- sends (MFM_ScaleUpdated, then MFM_PositionUpdated, both multiplied by the factor).
-- Frames are plain tables; rendering, the mover window and combat are not simulated.
-- Run: lua.exe Tools/Harness/frame_scale_harness.lua <addon root>
local root = arg[1] or '.'
local checks = 0
local function check(v, msg) assert(v, msg); checks = checks + 1 end
local function near(a, b) return math.abs(a - b) < 1e-6 end

local uiScale = .64
UIParent = { GetScale = function() return uiScale end }
InCombatLockdown = function() return false end

-- One frame "class": the prototype caches SetScale/SetPoint/ClearAllPoints off its metatable.
local methods = {}
function methods:SetScale(s) self.scale = s end
function methods:ClearAllPoints() self.point = nil end
function methods:SetPoint(...) self.point = { ... } end
function methods:GetSize() return 100, 50 end
CreateFrame = function() return setmetatable({}, { __index = methods }) end

local ns = { API = {} }
function ns:Merge(a, b) for k, v in pairs(b) do if a[k] == nil then a[k] = v end end return a end
ns.ModulePrototype = {}
ns.RegisterCallback = function() end
local function load(path) return assert(loadfile(root .. '/' .. path))('AzeriteUI5_JuNNeZ_Edition', ns) end
load('Core/API/Scale.lua')
load('Core/MovableFrameModulePrototype.lua')
local API, Proto = ns.API, ns.MovableModulePrototype

-- Scale API
local base = (768/1080) / uiScale
check(near(API.GetEffectiveScale(), base) and API.GetFrameScaleMultiplier() == 1, 'no database yet: multiplier 1')
ns.db = { profile = {} }
check(API.GetFrameScaleMultiplier() == 1, 'unset setting: 1')
ns.db.profile.frameScale = 1.25
check(near(API.GetEffectiveScale(), base * 1.25) and near(API.GetBaseEffectiveScale(), base), 'effective scale carries the master scale, base does not')
ns.db.profile.frameScale = 9
check(API.GetFrameScaleMultiplier() == API.FRAME_SCALE_MAX, 'clamped high')
ns.db.profile.frameScale = 0
check(API.GetFrameScaleMultiplier() == API.FRAME_SCALE_MIN, 'clamped low')
ns.db.profile.frameScale = 0/0
check(API.GetFrameScaleMultiplier() == 1, 'NaN ignored')
ns.db.profile.frameScale = 'x'
check(API.GetFrameScaleMultiplier() == 1, 'junk ignored')
ns.db.profile.frameScale = 1

-- A movable module, saved where the player put it.
local function Module(point, x, y, scale)
	local m = setmetatable({}, { __index = Proto })
	m.frame = CreateFrame()
	m.anchor = { IsAnchorPointLocked = function() return false end }
	m.db = { profile = { savedPosition = { point, x, y, scale = scale } } }
	m.UpdateAnchor = function() end
	return m
end
-- What the player sees: the frame's scale, and its anchor point's distance from
-- the screen point in UIParent units (SetPoint offsets are in the frame's own units).
local function Screen(m)
	local p = m.frame.point
	return m.frame.scale, p[1], p[4] * m.frame.scale, p[5] * m.frame.scale
end

local bars = Module('BOTTOM', 0, 25, base)
local pet = Module('BOTTOM', 0, 116, base * .8)
local map = Module('TOPRIGHT', -44, -54, base)
for _, m in ipairs({ bars, pet, map }) do m:UpdatePositionAndScale() end
local s0, _, x0, y0 = Screen(pet)
check(near(s0, base * .8) and near(y0, 116), 'baseline: saved scale and offset applied as before')

-- RescaleAnchors(f): each anchor fires ScaleUpdated(scale*f), then PositionUpdated(point, x*f, y*f).
local function Rescale(m, f)
	local sp = m.db.profile.savedPosition
	local anchor = m.anchor
	m:OnAnchorEvent('MFM_ScaleUpdated', anchor, sp.scale * f)
	m:OnAnchorEvent('MFM_PositionUpdated', anchor, sp[1], sp[2] * f, sp[3] * f)
end
local f = 1.2
for _, m in ipairs({ bars, pet, map }) do Rescale(m, f) end
local s1, p1, x1, y1 = Screen(pet)
check(near(s1, s0 * f) and p1 == 'BOTTOM' and near(y1, y0 * f), 'pet bar: size and distance both grow by the factor')
check(near(pet.db.profile.savedPosition.scale, base * .8 * f) and near(pet.db.profile.savedPosition[3], 116 * f), 'saved values carry the factor')
check(near(pet.db.profile.savedPosition.scale / bars.db.profile.savedPosition.scale, .8), "a frame's own scale stays relative to the others")
local _, _, _, ybars = Screen(bars)
-- Bars' top edge (bottom offset + scaled height) stays below the pet bar: spacing zooms too.
check(ybars + 50 * bars.frame.scale < y1, 'bars do not grow into the pet bar')
local _, mp, mx, my = Screen(map)
check(mp == 'TOPRIGHT' and near(mx, -44 * f) and near(my, -54 * f), 'corner frames keep their corner, inset scales')

-- Back to 100% restores the original numbers (no drift beyond float noise).
for _, m in ipairs({ bars, pet, map }) do Rescale(m, 1 / f) end
local s2, _, _, y2 = Screen(pet)
check(near(s2, s0) and near(y2, y0), 'round trip returns to the original layout')

-- Tooltips: saved scale already carries the master scale; base effective keeps it single.
ns.db.profile.frameScale = f
local tipSaved = base * f
check(near(tipSaved * API.GetBaseEffectiveScale(), base * base * f), 'tooltip scales once with the master scale, not squared')

print(('Frame scale: %d checks passed (real Scale.lua and module prototype; offline only).'):format(checks))

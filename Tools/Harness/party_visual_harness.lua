-- Offline lifecycle/mask checks against Party.lua callbacks. No rendering or client emulation.
local root = arg[1] or "."
local f = assert(io.open(root .. "/Components/UnitFrames/Units/Party.lua", "rb"))
local source = f:read("*a")
f:close()
local checks = 0
local function check(value, label)
	checks = checks + 1
	assert(value, label)
end
local function slice(first, last)
	local start = assert(source:find(first, 1, true))
	return source:sub(start, assert(source:find(last, start, true)) - 1)
end
local function region()
	local r = {}
	function r:SetDrawLayer() end
	function r:SetAllPoints(target) self.target = target end
	function r:SetTexCoord(...) self.coords = { ... } end
	function r:SetTexture(path) self.texture = path end
	function r:AddMaskTexture(mask) self.mask = mask end
	function r:Show() self.shown = true end
	function r:Hide() self.shown = false end
	return r
end
local queued, combat = {}, false
local player, other = { unit = "player" }, { unit = "party1" }
for _, frame in ipairs({ player, other }) do
	frame.Castbar = { calls = 0, ForceUpdate = function(self) self.calls = self.calls + 1 end }
end
local module = { UpdateHeader = function() end, UpdateUnits = function() end }
local env = setmetatable({
	Units = { [player] = true, [other] = true }, PartyFrameMod = module,
	next = next, C_Timer = { After = function(_, fn) queued[#queued + 1] = fn end },
	InCombatLockdown = function() return combat end,
	UsePartySpecPortraits = function() return false end,
	ns = { SpecIcons = { HideOnPortrait = function() end } },
	API = { RefreshPortraitModelAlpha = function() end },
	GetMedia = function(key) return key end,
	SetPortraitTexture = function(texture, unit) texture.unit = unit end,
}, { __index = _G })
local chunk = assert(loadstring(slice("local RefreshPlayerCastOverlay = function", "PartyFrameMod.UpdateAnchorAndMouseForLock = function")
	.. "\nreturn RefreshPlayerCastOverlay"))
setfenv(chunk, env)
local refresh = chunk()
module:OnEvent("PLAYER_ENTERING_WORLD")
check(player.Castbar.calls == 1 and other.Castbar.calls == 0, "only own overlay refreshed on entry")
queued[1]()
check(player.Castbar.calls == 2, "own overlay refreshed after snapshot settles")
combat = true
module:OnEvent("PLAYER_ENTERING_WORLD")
check(module.needHeaderUpdate and player.Castbar.calls == 3, "combat defers layout but not overlay repair")
queued[#queued]()
check(player.Castbar.calls == 4, "delayed repair also runs in combat")
player.unit = "party2"
refresh()
check(player.Castbar.calls == 4, "reused button for another member is left alone")

chunk = assert(loadstring(slice("local Portrait_PostUpdate = function", "-- Update the border color of priority debuffs.")
	.. "\nreturn Portrait_PostUpdate"))
setfenv(chunk, env)
local update = chunk()
local portrait = { created = 0 }
function portrait:ClearModel() end
function portrait:CreateTexture() self.created = self.created + 1; return region() end
function portrait:CreateMaskTexture() return region() end
update(portrait, "party1")
check(portrait.fallback2DTexture.mask == portrait.fallback2DMask, "fallback uses actual mask attachment")
check(portrait.fallback2DMask.texture == "actionbutton-mask-circular", "fallback mask is circular")
check(portrait.fallback2DMask.target == portrait, "mask follows portrait bounds")
update(portrait, "party2")
check(portrait.created == 1 and portrait.fallback2DTexture.unit == "party2", "reused fallback retains mask and updates unit")
print(("Party visuals: %d checks, 0 failures"):format(checks))

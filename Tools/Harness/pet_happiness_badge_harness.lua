-- Exercise the real pet layout's callback and binding without a WoW client.
local root = arg[1] or "."
assert(loadfile(root.."/Components/UnitFrames/Units/Pet.lua"))
local file = assert(io.open(root.."/Components/UnitFrames/Units/Pet.lua", "rb"))
local source = file:read("*a"); file:close()
local checks = 0
local function check(value, label)
	checks = checks + 1; assert(value, label)
end
local secret = {}
local env = setmetatable({ issecretvalue = function(value) return value == secret end }, { __index = _G })
local callbackSource = assert(source:match("(local happinessColors =.-)\nlocal UnitFrame_PostUpdate"))
local chunk = assert(loadstring(callbackSource.."\nreturn PetHappiness_UpdateBadge"))
setfenv(chunk, env)
env.PetHappiness_UpdateBadge = chunk()
local badge = {
	SetDesaturated = function(self, value) self.desaturated = value end,
	SetVertexColor = function(self, ...) self.color = {...} end
}
local enters, leaves, updates = 0, 0, 0
local indicator = {
	shown = true, level = 0,
	Texture = { SetAlpha = function(self, value) self.alpha = value end },
	OnEnter = function() enters = enters + 1 end,
	OnLeave = function() leaves = leaves + 1 end,
	IsShown = function(self) return self.shown end,
	ClearAllPoints = function() end,
	SetAllPoints = function(self, value) self.anchor = value end,
	SetFrameLevel = function(self, value) self.level = value end,
	UpdateHappiness = function(self, value)
		updates = updates + 1
		self.tooltipData = value and { happiness = value, damagePercentage = 125, loyaltyRate = 1 } or nil
		self.shown = value ~= nil
	end
}
env.self = { PetHappiness = indicator, PetHappinessBadge = badge }
env.overlay = { GetFrameLevel = function() return 12 end }
env.hooksecurefunc = function(object, method, callback)
	local original = object[method]
	object[method] = function(...) original(...); callback(...) end
end
local binding = assert(source:match('(\tif %(self.PetHappiness and self.PetHappinessBadge%) then.-\n\tend)'))
chunk = assert(loadstring(binding)); setfenv(chunk, env); chunk()
check(badge.desaturated and indicator.Texture.alpha == 0, "smiley hidden without hiding hover frame")
check(indicator.anchor == badge and indicator.level == 13, "hover area covers paw above casing")
for _, state in ipairs({ 3, 2, 1, 3 }) do
	indicator:UpdateHappiness(state)
	local c = badge.color
	check((state == 3 and c[2] == 1 and c[1] == .25)
		or (state == 2 and c[1] == 1 and c[2] == .85)
		or (state == 1 and c[1] == 1 and c[2] == .15), "happiness transition "..state)
	check(indicator.tooltipData.damagePercentage == 125, "native tooltip data preserved")
end
indicator:OnEnter(); indicator:OnLeave()
check(enters == 1 and leaves == 1 and updates == 4, "native tooltip handlers and update retained")
indicator:UpdateHappiness(nil)
check(not indicator.shown and badge.color[1] == .6, "dismissal resets stale happy tint")
indicator:UpdateHappiness(secret)
check(badge.color[1] == .6, "secret happiness never indexed")
indicator:UpdateHappiness(99)
check(badge.color[1] == .6, "unknown happiness is neutral")
env.self = { PetHappiness = indicator }; chunk()
env.self = { PetHappinessBadge = badge }; chunk()
check(true, "themes without a badge and clients without happiness skip binding")
print("Pet happiness badge: "..checks.." checks passed (offline only)")

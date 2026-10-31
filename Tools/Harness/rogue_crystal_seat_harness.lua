-- Isolated contract for the staged cosmetic layer. Not a WoW client emulator.
local staged = "Docs/Research_Assets/Rogue/Layered-Rebuild-2026-10-30/Runtime/RogueCrystalSeat.lua"
local checks = 0
local function check(value, message) checks = checks + 1; assert(value, message) end
local globals = {}; for key in pairs(_G) do globals[key] = true end
local hooks = setmetatable({}, { __mode = "k" })
hooksecurefunc = function(object, method, callback)
	local key = hooks[object] or {}; hooks[object] = key
	key[method] = key[method] or {}; table.insert(key[method], callback)
end
issecretvalue = function(value) return value == "secret" end
local function trigger(object, method, ...)
	for _, callback in ipairs((hooks[object] or {})[method] or {}) do callback(object, ...) end
end
local case = { shown = true }
case.IsShown = function(self) return self.shown end
local back = { layer = "BACKGROUND", sublevel = -2 }
back.GetDrawLayer = function(self) return self.layer, self.sublevel end
local fill = { layer = "ARTWORK", sublevel = 0 }
fill.GetDrawLayer = back.GetDrawLayer
local count = 0
local power = { Case = case, Backdrop = back }
power.GetStatusBarTexture = function() return fill end
power.CreateTexture = function(owner, name, layer, template, sublevel)
	check(owner == power and name == nil and template == nil, "seat belongs only to power")
	count = count + 1
	local texture = { parent = owner, layer = layer, sublevel = sublevel }
	texture.SetTexture = function(self, value) self.texture = value end
	texture.SetTexCoord = function(self, ...) self.uv = {...} end
	texture.SetVertexColor = function(self, ...) self.tint = {...} end
	texture.SetBlendMode = function(self, value) self.blend = value end
	texture.SetDrawLayer = function(self, l, s) self.layer, self.sublevel = l, s end
	texture.ClearAllPoints = function(self) self.anchor = nil end
	texture.SetAllPoints = function(self, value) self.anchor = value end
	texture.SetShown = function(self, value) self.shown = not not value end
	texture.Hide = function(self) self.shown = false end
	return texture
end
power.GetValue = function() error("native resource value must not be read") end
power.SetValue = function() error("native resource value must not be written") end
power.SetPoint = function() error("resource anchor must not change") end
power.SetSize = function() error("resource size must not change") end
case.SetPoint = function() error("holder anchor must not change") end
case.SetSize = function() error("holder size must not change") end
local Theme = { active = true }
Theme.IsActive = function(self) return self.active end
local prefix = "Interface/AddOns/AzeriteUI/Assets/Rogue/"
local ns = { RogueTheme = Theme, ThemeEngine = {} }
ns.ThemeEngine.MediaPath = function() return function(name) return prefix..name..".tga" end end
assert(loadfile(staged))("AzeriteUI", ns)
for key in pairs(_G) do
	check(globals[key] or key == "hooksecurefunc" or key == "issecretvalue", "staged file leaked a global")
end
Theme:StyleCrystal(nil, prefix.."pw_crystal_case.tga")
Theme:StyleCrystal(power, prefix.."pw_crystal_case_low.tga")
check(count == 0, "low unchanged")
local high = prefix.."pw_crystal_case.tga"
Theme:StyleCrystal(power, high)
local seat = power.RogueCrystalSeat
check(count == 1 and seat.shown and seat.anchor == case, "seat follows original holder")
check(seat.parent == power and seat.layer == "BORDER" and seat.sublevel == 0, "above shadow and below painted face")
check(seat.texture == prefix.."pw_crystal_case-seat.tga", "only new seat texture")
check(table.concat(seat.uv, ",") == "0,1,0,1" and table.concat(seat.tint, ",") == "1,1,1,1", "native UV and neutral source")
for _ = 1, 3 do Theme:StyleCrystal(power, high) end
check(count == 1 and #hooks[case].Show == 1, "reload/settings refresh allocates once")
trigger(case, "Hide"); check(not seat.shown, "holder hide")
trigger(case, "Show"); check(seat.shown, "holder show")
trigger(case, "SetShown", false); check(not seat.shown, "holder SetShown false")
trigger(case, "SetShown", true); check(seat.shown, "holder SetShown true")
for _, sublevel in ipairs({-8, -7, -2, 0, 5, 7}) do
	back.sublevel = sublevel; Theme:StyleCrystal(power, high)
	check(seat.shown and seat.layer == "BORDER" and seat.sublevel == 0, "all custom sublevels keep material order")
end
back.sublevel = -2; back.layer = "ARTWORK"; Theme:StyleCrystal(power, high); check(not seat.shown, "unexpected backdrop layer omitted")
trigger(case, "Show"); check(not seat.shown, "disabled seat cannot return from visibility hook")
back.layer = "BACKGROUND"
fill.layer = "BACKGROUND"; Theme:StyleCrystal(power, high); check(not seat.shown, "unexpected fill layer omitted")
fill.layer = "ARTWORK"
for _, args in ipairs({ {high, true}, {prefix.."pw_crystal_case_low.tga", false}, {"Assets/Warrior/pw_crystal_case.tga", false}, {123, false} }) do
	Theme:StyleCrystal(power, high); Theme:StyleCrystal(power, args[1], args[2]); check(not seat.shown, "effect/low/unrelated cases omitted")
end
Theme:StyleCrystal(power, high); Theme.active = false; Theme:StyleCrystal(power, high)
check(not seat.shown and not seat.Enabled, "theme disable")
Theme.active = true; case.shown = false; Theme:StyleCrystal(power, high); check(not seat.shown, "initial hidden holder")
case.shown = true; Theme:StyleCrystal(power, high); check(seat.shown, "restored active holder")
print("Rogue staged rear seat: "..checks.." assertions passed; no live client validation.")

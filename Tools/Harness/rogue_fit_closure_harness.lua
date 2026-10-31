-- Reuse the existing complete module/layer fixture, redirecting only its module
-- load to the STAGED proposal. Nothing is loaded into or written to the game.
local installed = arg[1] == "installed-current"
local stage = "Docs/Research_Assets/Rogue/Fit-Closure-2026-10-31/Runtime/"
local originalLoad, originalPrint = loadfile, print
local capturedNS, capturedPower
loadfile = function(path)
	if (path == "Core/ThemeEffects.lua" and not installed) then return originalLoad(stage.."ThemeEffects.lua") end
	if (path ~= "Core/RogueTheme.lua") then return originalLoad(path) end
	local chunk = assert(originalLoad(installed and path or stage.."RogueTheme.lua"))
	return function(addon, ns)
		capturedNS = ns
		chunk(addon, ns)
		local actualStyle = ns.RogueTheme.StyleCrystal
		ns.RogueTheme.StyleCrystal = function(self, power, ...)
			if (power and power.Backdrop) then
				capturedPower = power
				power.Backdrop.GetTexture = function() error("floor must use the already chosen fill path") end
			end
			return actualStyle(self, power, ...)
		end
	end
end
print = function(value)
	originalPrint((tostring(value):gsub("Rogue installed", "Rogue STAGED full module")))
end
arg[1] = "installed" -- choose the complete-module fixture, redirected above
dofile("Tools/Harness/rogue_crystal_seat_installed_harness.lua")
loadfile, print = originalLoad, originalPrint

local checks = 0
local function check(value, message) checks = checks + 1; assert(value, message) end
local ns, power = capturedNS, capturedPower
local theme, back = ns.RogueTheme, power.Backdrop
local high = "Interface/AddOns/AzeriteUI/Assets/Rogue/pw_crystal_case.tga"
local seat = power.RogueCrystalSeat
ns.ThemeEffects.GetCrystalEffect = function() return "none" end
for _, test in ipairs({
	{ "Assets/power-crystal.tga", "pw_crystal_case-seat.tga" },
	{ "Assets/power-crystal-ice.tga", "pw_crystal_case-seat-wrath.tga" },
	{ "Assets/power-crystal.tga", "pw_crystal_case-seat.tga" },
	{ 12345, "pw_crystal_case-seat.tga" },
	{ false, "pw_crystal_case-seat.tga" }
}) do
	ns.ThemeEffects:StyleCrystal(power, test[1], {0,1,0,1}, high)
	check(power.RogueCrystalSeat == seat, "mode change reuses existing cosmetic texture")
	check(seat.texture:sub(-#test[2]) == test[2], "correct normal/ice source chosen")
	check(seat.layer == "BORDER" and seat.sublevel == 0 and seat.parent == power, "native ordering unchanged")
	check(seat.anchor == power.Case and seat.shown, "same existing casing rectangle and visibility")
end
theme:StyleCrystal(power, high, true, "Assets/power-crystal-ice.tga")
check(not seat.shown, "Mage override removes floor in ice mode")
theme:StyleCrystal(power, high, false, "Assets/power-crystal-ice.tga")
check(seat.shown and seat.texture:find("seat-wrath", 1, true), "ice floor returns after Mage override")
theme:StyleCrystal(power, "Assets/Warrior/pw_crystal_case.tga", false)
check(not seat.shown, "other-theme resource cannot show Rogue floor")
print("Rogue "..(installed and "installed-current" or "STAGED").." floor modes: "..checks.." extra assertions passed; no client validation.")

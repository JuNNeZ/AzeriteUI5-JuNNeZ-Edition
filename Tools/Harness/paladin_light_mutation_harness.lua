-- Negative controls for the real Paladin light tests. No production files change.
-- Tools/Run-Elune.ps1 -Script Tools/Harness/paladin_light_mutation_harness.lua .
local root = arg[1] or "."
local originalLoad = loadfile
local originalOpen = io.open
local file = assert(io.open(root.."/Core/PaladinTheme.lua", "r"))
local source = file:read("*a"); file:close()
local mutants = {
	{ "wrong atlas wrap", "(index+1)%64", "(index+1)%63", "following sample remains inside sheet at cell 63" },
	{ "resource events reset phase", "local ApplyLight = function(content)",
		"local ApplyLight = function(content) content.Time = 0", "resource restyle preserves animation phase" },
	{ "cleared effect keeps ticking", 'content:SetScript("OnUpdate", nil)',
		'-- removed stop', "effect switching stops both animation callbacks" },
	{ "spheres share the wave reset", 'content.SphereTime = ((content.SphereTime or 0) + elapsed)%48',
		'content.SphereTime = content.Time', "wave wrap does not reset sphere motion" },
	{ "spheres lose mask", 'art:AddMaskTexture(mask)\n\t\tcontent.Spheres[i] = art',
		'content.Spheres[i] = art', "sphere foreground shares silhouette and draws above waves" },
	{ "public effect gated again", '\treturn effect\nend',
		'\tif (effect == "paladin" and not DevMode()) then effect = "none" end\n\treturn effect\nend',
		"public Lite+ shows effects and Holy light strength", "Core/ThemeEffects.lua" },
	{ "public dropdown gated again", 'key == "paladin" and not withTheme and not',
		'key == "paladin" and not', "both Lite+ lists offer approved Light without Development Mode",
		"Options/OptionsPages/Themes.lua" },
	{ "Light colour ignored", 'if (colorMode == "light" and ns.PaladinTheme) then',
		'if (false) then', "explicit Light choice colours the crystal gold",
		"Components/UnitFrames/Units/Player.lua" },
	{ "Light keeps baked blue ice", 'if (profile and profile.crystalOrbColorMode == "light" and self:IsActive()) then return false end',
		'if (false) then return false end', "Light uses neutral crystal without erasing the saved ice preference" }
}
for _, mutant in ipairs(mutants) do
	local target, original = mutant[5] or "Core/PaladinTheme.lua", source
	if (mutant[5]) then
		local input = assert(io.open(root.."/"..target, "r"))
		original = input:read("*a"); input:close()
	end
	local start = assert(original:find(mutant[2], 1, true), mutant[1].." mutation target missing")
	local changed = original:sub(1, start-1)..mutant[3]..original:sub(start+#mutant[2])
	loadfile = function(name)
		if name == root.."/"..target then return loadstring(changed, "@"..name) end
		return originalLoad(name)
	end
	-- The palette checks extract real local functions from Player.lua. Feed
	-- that read the in-memory mutant too, without changing the installed file.
	io.open = function(name, mode)
		if (name == root.."/"..target and (mode == "r" or mode == "rb")) then
			return { read = function() return changed end, close = function() end }
		end
		return originalOpen(name, mode)
	end
	local ok, err = pcall(assert(originalLoad(root.."/Tools/Harness/paladin_theme_harness.lua")))
	loadfile = originalLoad
	io.open = originalOpen
	assert(not ok, mutant[1].." survived")
	-- The wrong wrap is caught by the explicit last->first sample check.
	local expected = mutant[1] == "wrong atlas wrap" and "last frame crossfades directly to first frame" or mutant[4]
	assert(tostring(err):find(expected, 1, true), mutant[1].." failed for an unrelated reason: "..tostring(err))
	print("Paladin Light mutant rejected: "..mutant[1])
end

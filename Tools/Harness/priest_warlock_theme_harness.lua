-- Reuse the existing recording-widget integration contract against each REAL
-- relic-theme module, selector, options page, installed data and installed art.
-- No live WoW emulation or production acceptance is implied.
local root, selected = arg[1] or ".", arg[2] or "Both"
local cases = {
	{ name = "Priest", key = "priest", class = "PRIEST", health = "tuure", healthName = "T'uure", cast = "wrath", castName = "Light's Wrath", effect = "sanctum" },
	{ name = "Warlock", key = "warlock", class = "WARLOCK", health = "ulthalesh", healthName = "Ulthalesh", cast = "thalkiel", castName = "Thal'kiel", effect = "affliction" }
}
local file = assert(io.open(root.."/Tools/Harness/deathknight_theme_harness.lua", "rb"))
local contract = file:read("*a"); file:close()
local function replace(text, old, new)
	local result, at = {}, 1
	while true do
		local first, last = text:find(old, at, true)
		if not first then result[#result+1] = text:sub(at); break end
		result[#result+1] = text:sub(at, first-1)
		result[#result+1] = new
		at = last+1
	end
	return table.concat(result)
end
for _, case in ipairs(cases) do
	if selected == "Both" or selected == case.name then
		local probe = {}
		assert(loadfile(root.."/Core/"..case.name.."ThemeData.lua"))("AzeriteUI5_JuNNeZ_Edition", probe)
		local edge = assert(probe[case.name.."ThemeData"].edges[case.health].hp_cap_case)
		local source = contract
		-- This theme has one health motif. Do not inflate checks by duplicating it.
		source = replace(source, '{"frost","unholy","none"}', '{"frost","none"}')
		for _, mapping in ipairs({
			{ "DeathKnight", case.name }, { "deathknight", case.key }, { "DEATHKNIGHT", case.class },
			{ "Death Knight", case.name }, { "frost", case.health }, { "unholy", case.health },
			{ "maw", case.cast }, { "Apocalypse", case.healthName }, { "Maw of the Damned", case.castName },
			{ "rime", case.effect }, { "Rime", case.effect }, { "692/1024", tostring(edge).."/1024" }
		}) do source = replace(source, mapping[1], mapping[2]) end
		assert(loadstring(source, "@"..case.key.."_real_module_contract"))()
	end
end

-- In-memory mutations: never edits addon files or the working tree.
-- lua Tools/Harness/mutate_client.lua .
local root = arg[1] or "."
local originalLoadfile = loadfile
local cases = {
	{"client detection", "Core/Client.lua", "ns.Private.IsForever = forever and true or false", "ns.Private.IsForever = false"},
	{"modern engine", "Core/Client.lua", "ns.Private.IsRetail = ns.Private.IsMainline", "ns.Private.IsRetail = false"},
	{"API aliases", "Core/Compatibility.lua", "if (C_Spell and C_SpellBook and C_Reputation) then", "if (false) then"},
	{"secret tuple", "Core/Compatibility.lua", "local hasSecretValues = ns.HasSecretValues", "local hasSecretValues = false"},
	{"arena gate", "Components/UnitFrames/Units/Arena.lua", "if (ns.IsForever) then return end", ""},
	{"arena bootstrap", "WoW11/UnitFrames/ArenaFrames.lua", "not ns.WoW11 or ns.IsForever", "not ns.WoW11"},
	{"inspect gate", "Components/UnitFrames/GroupSpecCache.lua", "ticker or ns.IsForever or", "ticker or"},
	{"class resource gate", "Libs/oUF/elements/classpower.lua", "if(ns.IsForever and playerClass", "if(false and playerClass"},
	{"menu game rules", "Components/ActionBars/Elements/MicroMenu.lua", "and not disabled and not", "and not"},
	{"menu callbacks", "Components/ActionBars/Elements/MicroMenu.lua", "info.callback and info.callback()", "false"},
	{"event validation", "Libs/oUF/private.lua", "return C_EventUtils.IsEventValid(event)", "return true"}
}
assert(originalLoadfile(root .. "/Tools/Harness/client_harness.lua"))()
for _, case in ipairs(cases) do
	local mutations = 0
	loadfile = function(path)
		if path:sub(-#case[2]) ~= case[2] then return originalLoadfile(path) end
		local file = assert(io.open(path, "r"))
		local source = file:read("*a")
		file:close()
		local first, last = source:find(case[3], 1, true)
		assert(first, "mutation target missing: " .. case[1])
		mutations = mutations + 1
		return loadstring(source:sub(1, first - 1) .. case[4] .. source:sub(last + 1), "@" .. path)
	end
	local ok, err = pcall(assert(originalLoadfile(root .. "/Tools/Harness/client_harness.lua")))
	loadfile = originalLoadfile
	assert(mutations > 0, "mutation was not applied: " .. case[1])
	assert(not ok, "mutation survived: " .. case[1])
	print("Caught " .. case[1] .. ": " .. tostring(err))
end
print("Client mutations: " .. #cases .. " caught; no files modified")

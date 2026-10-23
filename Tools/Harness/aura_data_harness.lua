-- Aura spell lists by client: Retail's in AuraData.lua, Forever's classic-era ranks in AuraData_Forever.lua.
-- Loads both real files under each client's flags, as Core/Client.lua sets them (IsRetail is the modern
-- engine on both; IsForever only on Forever). No claim of live WoW execution.
-- lua Tools/Harness/aura_data_harness.lua .
local root = arg[1] or "."
local checks, failures = 0, 0
-- WoW's bit library, which plain Lua 5.1 lacks: enough for the 12 aura flags (2^0 to 2^11).
if (type(bit) ~= "table") then
	local function op(a, b, keep)
		local result, place = 0, 1
		for _ = 0, 15 do
			local x, y = a % 2, b % 2
			if (keep(x, y)) then result = result + place end
			a, b, place = (a - x) / 2, (b - y) / 2, place * 2
		end
		return result
	end
	bit = {
		bor = function(a, b) return op(a, b, function(x, y) return x == 1 or y == 1 end) end,
		band = function(a, b) return op(a, b, function(x, y) return x == 1 and y == 1 end) end
	}
end
local function check(value, label)
	checks = checks + 1
	if (not value) then
		failures = failures + 1
		print("FAIL: " .. label)
	end
end

local function load(forever)
	local ns = { IsRetail = true, IsMainline = true, IsForever = forever, IsRetailContent = not forever }
	for _, file in ipairs({ "AuraData.lua", "AuraData_Forever.lua" }) do
		local chunk = assert(loadfile(root .. "/Components/UnitFrames/Auras/" .. file))
		chunk("AzeriteUI5_JuNNeZ_Edition", ns)
	end
	return ns.AuraData
end

local forever, retail = load(true), load(false)
local CC, INTERRUPT, ROOT = forever.Flags.CC, forever.Flags.INTERRUPT, forever.Flags.ROOT
local function has(data, spellID, flag) return data.Spells[spellID] and bit.band(data.Spells[spellID], flag) == flag end

-- A few of the classic ranks Forever's auras carry (Classic_AuraData.lua's own entries).
check(has(forever, 12826, CC), "Forever: Polymorph rank 4 is crowd control")
check(has(forever, 1769, INTERRUPT), "Forever: Kick rank 4 is an interrupt")
check(forever.Priority[12294], "Forever: Mortal Strike is a priority aura")
local rootCount = 0
for _, bits in pairs(forever.Spells) do
	if (bit.band(bits, ROOT) == ROOT) then rootCount = rootCount + 1 end
end
check(rootCount > 0, "Forever: roots are listed")
-- Forever additions, from Forever's own spell tables: new spells, and Classic ones the Classic list lacked.
check(has(forever, 1277335, ROOT), "Forever: Chastise rank 5 is a root")
check(has(forever, 1265883, ROOT), "Forever: Web's rank 5 root aura is a root")
check(has(forever, 10326, CC), "Forever: Turn Undead rank 3 is crowd control")
check(has(forever, 1310897, forever.Flags.IMMUNITY), "Forever: Voice of Truth is an immunity")
check(not forever.Spells[19753], "Forever: Divine Intervention (stuns your own ally) is left out")
check(not has(retail, 1277335, ROOT), "Retail: Forever additions are not added")

-- Retail loads none of them, and keeps its own list.
check(not has(retail, 12826, CC), "Retail: classic Polymorph rank 4 is not added")
check(not retail.Priority[12294], "Retail: classic Mortal Strike priority is not added")
check(retail.Priority[34914], "Retail: Vampiric Touch keeps its priority")
-- Forever still gets Retail's list too, which is harmless: those IDs never reach a Forever aura.
check(forever.Priority[34914], "Forever: Retail's list still loads (IDs Forever never sees)")
-- Nothing on either client is hidden by these lists.
check(next(forever.Hidden) == nil and next(retail.Hidden) == nil, "no aura is hidden by the lists")

print(string.format("Aura data: %d checks, %d failures", checks, failures))
if (failures > 0) then error("aura data harness failed") end

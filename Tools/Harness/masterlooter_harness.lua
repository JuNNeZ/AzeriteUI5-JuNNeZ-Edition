-- Forever master looter icon (FixLog 2026-10-20). Loads the real
-- Libs/oUF/elements/masterlooterindicator.lua: enabled only on Forever with the loot API,
-- shown on the master looter's frame (party index 0 = you, partyN, raidN), hidden for
-- everyone else and for any other loot method, and PostUpdate gets the shown state
-- RaidLarge.lua anchors by. Offline only: the icon's look and a real master-loot raid are live.
-- Run: lua.exe Tools/Harness/masterlooter_harness.lua <addon root>
local root = arg[1] or '.'
local checks, failures = 0, 0
local function check(v, msg, detail)
	checks = checks + 1
	if (not v) then
		failures = failures + 1
		print("FAIL: " .. msg .. (detail ~= nil and (" - " .. tostring(detail)) or ""))
	end
end

Enum = { LootMethod = { Freeforall = 0, Roundrobin = 1, Masterlooter = 2, Group = 3, Needbeforegreed = 4, Personal = 5 } }
local W = { method = 2, party = nil, raid = 3, inRaid = { raid1 = 1, raid3 = 3 }, inParty = {} }
C_PartyInfo = { GetLootMethod = function() return W.method, W.party, W.raid end }
UnitInParty = function(u) return W.inParty[u] or false end
UnitInRaid = function(u) return W.inRaid[u] end
UnitIsUnit = function(a, b) return a == b end

local element
local ns = { IsForever = true, oUF = { AddElement = function(_, name, update, enable, disable)
	element = { name = name, update = update, enable = enable, disable = disable }
end } }
assert(loadfile(root .. "/Libs/oUF/elements/masterlooterindicator.lua"))("AzeriteUI5_JuNNeZ_Edition", ns)
check(element and element.name == "MasterLooterIndicator", "element registered")

local function Frame(unit)
	local f = { unit = unit, events = {} }
	function f:RegisterEvent(e, fn, unitless) self.events[e] = { fn = fn, unitless = unitless } end
	function f:UnregisterEvent(e) self.events[e] = nil end
	local ind = { shown = nil }
	function ind:SetShown(v) self.shown = v end
	function ind:Hide() self.shown = false end
	function ind:IsObjectType(t) return t == "Texture" end
	function ind:GetTexture() return self.texture end
	function ind:SetTexture(t) self.texture = t end
	ind.PostUpdate = function(self, isShown) self.post = isShown end
	f.MasterLooterIndicator = ind
	return f, ind
end

local f3, i3 = Frame("raid3")
check(element.enable(f3) == true, "enables on Forever")
check(f3.events.PARTY_LOOT_METHOD_CHANGED and f3.events.PARTY_LOOT_METHOD_CHANGED.unitless == true, "loot method event registered unitless")
check(i3.texture and i3.texture:find("MasterLooter"), "default icon set")
element.update(f3, "ForceUpdate")
check(i3.shown == true and i3.post == true, "master looter raid3: shown, PostUpdate true")

local f1, i1 = Frame("raid1"); element.enable(f1); element.update(f1, "ForceUpdate")
check(i1.shown == false and i1.post == false, "other raid member: hidden")

W.method = 3
element.update(f3, "PARTY_LOOT_METHOD_CHANGED")
check(i3.shown == false, "group loot: hidden")

W.method, W.party, W.raid = 2, 0, nil
W.inParty.player = true
local fp, ip = Frame("player"); element.enable(fp); element.update(fp, "ForceUpdate")
check(ip.shown == true, "party index 0 means you")

W.party = 2; W.inParty.party2 = true
local fq, iq = Frame("party2"); element.enable(fq); element.update(fq, "ForceUpdate")
check(iq.shown == true, "party index 2 means party2")

local fx, ix = Frame("raid9"); element.enable(fx); element.update(fx, "ForceUpdate")
check(ix.shown == false, "not in the group: hidden")

element.disable(f3)
check(f3.events.PARTY_LOOT_METHOD_CHANGED == nil and i3.shown == false, "disable unregisters and hides")

ns.IsForever = false
local fr, ir = Frame("raid3")
check(element.enable(fr) == false and ir.shown == false, "Retail: does not enable")
check(next(fr.events) == nil, "Retail: no events")

print(("Master looter: %d checks, %d failures (offline only)"):format(checks, failures))
os.exit(failures == 0 and 0 or 1)

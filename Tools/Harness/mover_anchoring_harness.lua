-- Mover anchoring arithmetic, offline.
--
-- Loads the real Core/API/Anchoring.lua and checks it against SetPoint's rules: a frame
-- placed with SetPoint(point, UIParent, point, x, y) has its `point` at UIParent's `point`
-- plus x, y. Links, offsets, cycles and chain order are checked by round trips. It cannot
-- say how a linked frame looks in game. See Docs/Mover Anchoring Plan.md.
--
-- lua Tools/Harness/mover_anchoring_harness.lua .

local root = arg and arg[1] or "."

local checks, failures = 0, 0
local function check(value, label, detail)
	checks = checks + 1
	if (not value) then
		failures = failures + 1
		print("FAIL: " .. label .. (detail ~= nil and ("  (" .. tostring(detail) .. ")") or ""))
	end
end
local function near(a, b) return type(a) == "number" and type(b) == "number" and math.abs(a - b) < 1e-6 end

local ns = { API = {} }
local chunk = assert(loadfile(root .. "/Core/API/Anchoring.lua"))
chunk("AzeriteUI5_JuNNeZ_Edition", ns)
local API = ns.API

local W, H = 1920, 1080

-- SetPoint semantics, one point at a time, against hand-worked numbers.
local l, b = API.RectFromPoint("BOTTOMLEFT", 10, 20, 100, 50, W, H)
check(near(l, 10) and near(b, 20), "BOTTOMLEFT: corner at the offset", tostring(l) .. "," .. tostring(b))
l, b = API.RectFromPoint("TOPRIGHT", -10, -20, 100, 50, W, H)
check(near(l, 1810) and near(b, 1010), "TOPRIGHT: offsets measured from the top right", tostring(l) .. "," .. tostring(b))
l, b = API.RectFromPoint("CENTER", 0, 0, 100, 50, W, H)
check(near(l, 910) and near(b, 515), "CENTER: centred", tostring(l) .. "," .. tostring(b))
l, b = API.RectFromPoint("BOTTOM", 30, 40, 200, 60, W, H)
check(near(l, 890) and near(b, 40), "BOTTOM: centred horizontally, offset up", tostring(l) .. "," .. tostring(b))
check(API.RectFromPoint("NOPE", 0, 0, 1, 1, W, H) == nil, "an unknown point gives nothing")
check(API.RectFromPoint("CENTER", nil, 0, 1, 1, W, H) == nil, "a missing offset gives nothing")

-- Round trip every point.
for _, point in ipairs(API.ANCHOR_POINTS) do
	local left, bottom = API.RectFromPoint(point, 37, -12, 123, 45, W, H)
	local x, y = API.PointFromRect(point, left, bottom, 123, 45, W, H)
	check(near(x, 37) and near(y, -12), "round trip " .. point, tostring(x) .. "," .. tostring(y))
end

-- A link: follower's LEFT on the target's RIGHT, 8 to the right.
local link = { target = "Player", point = "LEFT", relativePoint = "RIGHT", x = 8, y = 0 }
local fl, fb = API.LinkedRect(link, 100, 200, 300, 100, 50, 20)
check(near(fl, 408) and near(fb, 240), "LEFT to RIGHT: beside the target, centred on its height", tostring(fl) .. "," .. tostring(fb))

-- The mirror: follower's RIGHT on the target's LEFT, its own width counts.
fl, fb = API.LinkedRect({ point = "RIGHT", relativePoint = "LEFT", x = -8, y = 0 }, 100, 200, 300, 100, 50, 20)
check(near(fl, 42) and near(fb, 240), "RIGHT to LEFT: the follower's width puts it left of the target", tostring(fl) .. "," .. tostring(fb))
-- And a round trip through a centred follower point on both axes.

local cx, cy = API.LinkOffset("CENTER", "TOPRIGHT", 100, 200, 300, 100, 500, 400, 60, 30)
fl, fb = API.LinkedRect({ point = "CENTER", relativePoint = "TOPRIGHT", x = cx, y = cy }, 100, 200, 300, 100, 60, 30)
check(near(fl, 500) and near(fb, 400), "CENTER to TOPRIGHT round trip", tostring(fl) .. "," .. tostring(fb))

-- The offset that keeps a frame where it is, and that link puts it back there.
local ox, oy = API.LinkOffset("TOPLEFT", "BOTTOMLEFT", 100, 200, 300, 100, 120, 130, 50, 40)
check(near(ox, 20) and near(oy, -30), "offset of a frame under the target", tostring(ox) .. "," .. tostring(oy))
fl, fb = API.LinkedRect({ point = "TOPLEFT", relativePoint = "BOTTOMLEFT", x = ox, y = oy }, 100, 200, 300, 100, 50, 40)
check(near(fl, 120) and near(fb, 130), "and the link puts it back", tostring(fl) .. "," .. tostring(fb))

-- Moving the target moves the follower by the same amount.
local fl2, fb2 = API.LinkedRect(link, 150, 180, 300, 100, 50, 20)
check(near(fl2 - 408, 50) and near(fb2 - 240, -20), "the follower moves with the target")
-- A wider target pushes a RIGHT-anchored follower out by the growth.
local fl3 = API.LinkedRect(link, 100, 200, 340, 100, 50, 20)
check(near(fl3 - 408, 40), "a wider target pushes it out", fl3)
check(API.LinkedRect({ point = "LEFT", relativePoint = "X" }, 0, 0, 1, 1, 1, 1) == nil, "a bad relative point gives nothing")

-- Cycles.
local links = {
	Target = { target = "Player" },
	ToT = { target = "Target" }
}
check(API.WouldLinkCycle(links, "Player", "ToT") == true, "Player to ToT would loop through Target")
check(API.WouldLinkCycle(links, "Player", "Target") == true, "Player to Target would loop")
check(API.WouldLinkCycle(links, "Focus", "ToT") == false, "Focus to ToT is fine")
check(API.WouldLinkCycle(links, "ToT", "ToT") == true, "a frame cannot follow itself")
check(API.WouldLinkCycle(links, nil, "ToT") == true, "a missing key is refused")
check(API.WouldLinkCycle(nil, "A", "B") == false, "no links, no loop")

-- Depth and chain order.
check(API.LinkDepth(links, "Player") == 0, "Player follows nothing")
check(API.LinkDepth(links, "ToT") == 2, "ToT is two links down", API.LinkDepth(links, "ToT"))
local followers = API.LinkFollowers(links, "Player")
check(#followers == 2 and followers[1] == "Target" and followers[2] == "ToT", "Player's followers, nearest first",
	table.concat(followers, ","))
check(#API.LinkFollowers(links, "ToT") == 0, "ToT has none")
-- A corrupt saved loop must not hang.
local loop = { A = { target = "B" }, B = { target = "A" } }
check(#API.LinkFollowers(loop, "A") == 1, "a saved loop is walked once")
check(API.LinkDepth(loop, "A") >= 1, "and depth stops")

print(string.format("mover anchoring: %d checks, %d failures", checks, failures))
os.exit(failures == 0 and 0 or 1)

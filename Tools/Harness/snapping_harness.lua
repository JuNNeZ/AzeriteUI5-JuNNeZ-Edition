-- Snapping for the /lock movers, offline.
--
-- Loads the real Core/API/Snapping.lua and checks its arithmetic against the rules of
-- Blizzard's Edit Mode magnetism (Blizzard_EditMode/Shared/EditModeUtil.lua): an edge
-- or the centre within range of a line snaps to the nearest line, per axis, and the
-- grid's lines sit around its centre as EditModeGridMixin:UpdateGrid lays them out.
-- It cannot say how dragging feels in game, or where Blizzard's grid really is.
--
-- lua Tools/Harness/snapping_harness.lua .

local root = arg and arg[1] or "."

local checks, failures = 0, 0
local function check(value, label, detail)
	checks = checks + 1
	if (not value) then
		failures = failures + 1
		print("FAIL: " .. label .. (detail ~= nil and ("  (" .. tostring(detail) .. ")") or ""))
	end
end

local ns = { API = {} }
local chunk = assert(loadfile(root .. "/Core/API/Snapping.lua"))
chunk("AzeriteUI5_JuNNeZ_Edition", ns)
local API = ns.API

check(API.SNAP_RANGE == 8, "the range is Blizzard's 8 pixels", API.SNAP_RANGE)
check(type(API.FindSnap) == "function" and type(API.AddGridLines) == "function", "both helpers exist")

-- A 100 wide frame. Screen 1920 wide: lines at 0, 960, 1920.
local screen = { 0, 960, 1920 }

local delta, line = API.FindSnap(5, 100, screen, 8)
check(delta == -5 and line == 0, "a left edge 5 from the screen edge snaps onto it", delta)

delta, line = API.FindSnap(1815, 100, screen, 8)
check(delta == 5 and line == 1920, "a right edge 5 short of the edge snaps out to it", delta)

delta, line = API.FindSnap(906, 100, screen, 8)
check(delta == 4 and line == 960, "the centre snaps to the screen's centre", delta)

delta = API.FindSnap(500, 100, screen, 8)
check(delta == nil, "nothing within range: no snap")

delta = API.FindSnap(8, 100, screen, 8)
check(delta == -8, "exactly at the range still snaps, as Blizzard's <= does", delta)

delta = API.FindSnap(9, 100, screen, 8)
check(delta == nil, "one past the range does not")

-- The nearest of two candidate lines wins, whichever edge it belongs to.
delta, line = API.FindSnap(204, 100, { 200, 310 }, 8)
check(delta == -4 and line == 200, "left edge 4 away beats right edge 6 away", delta)
delta, line = API.FindSnap(203, 100, { 200, 305 }, 8)
check(delta == 2 and line == 305, "right edge 2 away beats left edge 3 away", delta)

-- Lining up with another frame: its edges and centre are lines like any other.
local other = { 300, 350, 400 } -- a frame from 300 to 400
delta, line = API.FindSnap(397, 60, other, 8)
check(delta == 3 and line == 400, "docks against another frame's right edge", delta)

-- Bad input never raises.
check(API.FindSnap(nil, 100, screen, 8) == nil, "no start, no snap")
check(API.FindSnap(5, 100, nil, 8) == nil, "no targets, no snap")
check(API.FindSnap(5, 100, screen, 0) == nil, "a zero range never snaps")
check(API.FindSnap(5, 100, {}, 8) == nil, "an empty target list never snaps")

-- The grid, centred: 1920 wide at spacing 100 gives the centre and 9 lines each side.
local grid = API.AddGridLines({}, 960, 1920, 100)
check(#grid == 19, "centre plus nine lines each way", #grid)
check(grid[1] == 960 and grid[2] == 1060 and grid[3] == 860, "lines step out from the centre")
local hasEdge = false
for _, value in ipairs(grid) do if (value == 60 or value == 1860) then hasEdge = true end end
check(hasEdge, "the outermost lines are inside the screen")

delta, line = API.FindSnap(1063, 50, grid, 8)
check(delta == -3 and line == 1060, "a frame snaps to a grid line", delta)

local unchanged = { 1, 2 }
check(API.AddGridLines(unchanged, 960, 1920, 0) == unchanged and #unchanged == 2, "no spacing adds no lines")
check(#API.AddGridLines({}, 960, 1920, "100") == 0, "a non-number spacing adds no lines")

print(string.format("Snapping: %d checks, %d failures", checks, failures))
if (failures > 0) then error("snapping_harness failed", 0) end

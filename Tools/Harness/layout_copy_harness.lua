-- Copying a layout between profiles, offline.
--
-- Loads the real Core/API/Layout.lua and runs it on a SavedVariables table shaped like
-- AceDB's (db.sv: profiles, namespaces[name].profiles): positions at any depth, mover
-- links and the master scale travel; every other setting stays; the target's own
-- positions go when the source has none (back to defaults); a live namespace table is
-- written in place. It cannot say that every module reads its copy after the reload.
--
-- lua Tools/Harness/layout_copy_harness.lua .

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
assert(loadfile(root .. "/Core/API/Layout.lua"))("AzeriteUI5_JuNNeZ_Edition", ns)
local API = ns.API

local function Fresh()
	return {
		profiles = {
			Main = { frameScale = .9, moverLinks = { azerite = { TargetFrame = { target = "PlayerFrame", point = "LEFT", relativePoint = "RIGHT", x = 4, y = 0 } } }, moversInEditMode = false },
			Alt = { frameScale = 1.1, moverLinks = { azerite = { ToTFrame = { target = "TargetFrame" } } }, moverSnapping = false }
		},
		namespaces = {
			PlayerFrame = { profiles = {
				Main = { savedPosition = { "BOTTOMLEFT", 100, 200, scale = 1 }, debuffsSavedPosition = { "TOP", 0, -10 }, showAuras = false },
				Alt = { savedPosition = { "CENTER", 0, 0, scale = 1.2 }, showAuras = true }
			} },
			ActionBars = { profiles = {
				Main = { bars = { [1] = { savedPosition = { "BOTTOM", 0, 10 }, numbuttons = 12 }, [2] = { numbuttons = 6 } } },
				Alt = { bars = { [1] = { savedPosition = { "BOTTOM", 0, 50 }, numbuttons = 7 } } }
			} },
			TargetFrame = { profiles = {
				Alt = { savedPosition = { "TOPRIGHT", -5, -5 }, showCastbar = false }
			} },
			Minimap = { profiles = {
				Main = { enabled = false }
			} },
			LegacyHUD_PlayerFrame = { profiles = {
				Main = { savedPosition = { "BOTTOM", 0, 0 } }
			} }
		}
	}
end

-- Main over Alt.
local sv = Fresh()
local n = API.CopyLayout(sv, "Main", "Alt")
local alt = sv.profiles.Alt
check(alt.frameScale == .9, "the master scale travels", alt.frameScale)
check(alt.moverLinks.azerite.TargetFrame and not alt.moverLinks.azerite.ToTFrame, "the links are the source's, not merged")
check(alt.moverLinks ~= sv.profiles.Main.moverLinks and alt.moverLinks.azerite.TargetFrame ~= sv.profiles.Main.moverLinks.azerite.TargetFrame,
	"copies, not shared tables")
check(alt.moverSnapping == false, "other core settings stay")
check(alt.moversInEditMode == nil, "and the source's are not brought over")

local player = sv.namespaces.PlayerFrame.profiles.Alt
check(player.savedPosition[1] == "BOTTOMLEFT" and player.savedPosition[3] == 200 and player.savedPosition.scale == 1, "a frame's position is copied")
check(player.debuffsSavedPosition and player.debuffsSavedPosition[1] == "TOP", "a ...SavedPosition key is copied")
check(player.showAuras == true, "the frame's settings stay")

local bars = sv.namespaces.ActionBars.profiles.Alt.bars
check(bars[1].savedPosition[3] == 10, "a nested position (bar 1) is copied", bars[1].savedPosition[3])
check(bars[1].numbuttons == 7, "bar 1 keeps its own button count")
check(bars[2] == nil, "a bar with no position in the source is not created")

check(sv.namespaces.TargetFrame.profiles.Alt.savedPosition == nil, "a position the source does not have goes back to default")
check(sv.namespaces.TargetFrame.profiles.Alt.showCastbar == false, "without touching the frame's settings")
check(sv.namespaces.Minimap.profiles.Alt == nil, "a namespace without positions is left alone")
check(sv.namespaces.LegacyHUD_PlayerFrame.profiles.Alt.savedPosition[1] == "BOTTOM", "Legacy's own positions travel too")
check(n == 3, "three namespaces now hold the source's positions", n)

check(sv.namespaces.PlayerFrame.profiles.Main.savedPosition[3] == 200 and sv.profiles.Main.frameScale == .9, "the source is unchanged")

-- A live, registered namespace is written in place, so the table in use and the saved one stay one.
sv = Fresh()
local live = { savedPosition = { "LEFT", 1, 1 } }
sv.namespaces.Minimap.profiles.Main.savedPosition = { "TOPRIGHT", -10, -10 }
API.CopyLayout(sv, "Main", "Alt", function(name) if (name == "Minimap") then return live end end)
check(sv.namespaces.Minimap.profiles.Alt == live and live.savedPosition[1] == "TOPRIGHT", "the live table gets the position")

-- A source with nothing at all: the target ends up on defaults for layout, nothing else.
sv = Fresh()
API.CopyLayout(sv, "Empty", "Main")
check(sv.profiles.Main.frameScale == nil and sv.profiles.Main.moverLinks == nil, "an empty source resets scale and links")
check(sv.namespaces.PlayerFrame.profiles.Main.savedPosition == nil and sv.namespaces.PlayerFrame.profiles.Main.showAuras == false,
	"and positions, and nothing more")

-- Reset layout (the /lock window's Reset): Main's layout goes, its settings and Alt stay.
sv = Fresh()
local liveMinimap = { savedPosition = { "TOPRIGHT", -10, -10 }, enabled = false }
local cleared = API.ResetLayout(sv, "Main", function(name) if (name == "Minimap") then return liveMinimap end end)
local main = sv.profiles.Main
check(main.frameScale == nil and main.moverLinks == nil, "reset clears the master scale and links")
check(main.moversInEditMode == false, "reset keeps other core settings")
local mainPlayer = sv.namespaces.PlayerFrame.profiles.Main
check(mainPlayer.savedPosition == nil and mainPlayer.debuffsSavedPosition == nil and mainPlayer.showAuras == false,
	"reset clears a frame's positions and keeps its settings")
local mainBars = sv.namespaces.ActionBars.profiles.Main.bars
check(mainBars[1].savedPosition == nil and mainBars[1].numbuttons == 12, "reset clears a nested position, keeps the bar")
check(sv.namespaces.LegacyHUD_PlayerFrame.profiles.Main.savedPosition == nil, "reset clears Legacy's positions too")
check(sv.namespaces.Minimap.profiles.Main.enabled == false and liveMinimap.savedPosition[1] == "TOPRIGHT",
	"a saved profile is preferred over the live lookup")
check(sv.profiles.Alt.frameScale == 1.1 and sv.namespaces.PlayerFrame.profiles.Alt.savedPosition[1] == "CENTER",
	"other profiles are untouched")
check(cleared == 3, "three namespaces held positions", cleared)
sv.namespaces.Minimap.profiles.Main = nil
API.ResetLayout(sv, "Main", function(name) if (name == "Minimap") then return liveMinimap end end)
check(liveMinimap.savedPosition == nil and liveMinimap.enabled == false, "a live-only namespace is cleared in place")
check(API.ResetLayout(nil, "Main") == 0 and API.ResetLayout({}, "Main") == 0, "nothing saved, nothing done")

-- Refusals.
check(API.CopyLayout(sv, "Main", "Main") == 0, "a profile does not copy onto itself")
check(API.CopyLayout(nil, "Main", "Alt") == 0, "no saved variables, nothing done")
check(API.IsLayoutKey("savedPosition") and API.IsLayoutKey("secondaryManaSavedPosition") and not API.IsLayoutKey("savedPositions")
	and not API.IsLayoutKey("position"), "position keys are recognised, nothing more")

print(string.format("layout copy: %d checks, %d failures", checks, failures))
os.exit(failures == 0 and 0 or 1)

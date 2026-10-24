-- Offline checks for Hide Activity Button (the China client's event button).
--
-- Runs the real block out of Components/Misc/Minimap.lua - the source slice
-- between its section comment and the defaults table - against a stubbed client,
-- so a change to the shipped file is what gets tested.
--
--   lua Tools/Harness/event_button_harness.lua .
--
-- It cannot see Blizzard's Refresh(), the tooltip or a real China realm. Live
-- /reload on a China Forever client stays required.

local root = arg[1] or "."

local failures, checks = 0, 0

local function check(name, ok, detail)
	checks = checks + 1
	if (not ok) then
		failures = failures + 1
		print(string.format("FAIL  %s%s", name, detail and ("  -> " .. tostring(detail)) or ""))
	else
		print("ok    " .. name)
	end
end

--------------------------------------------------------------------------
-- Stubs, recording only what these checks assert on.
--------------------------------------------------------------------------
local function makeFrame(name)
	local f = { name = name, protected = false, setParentCalls = 0 }
	function f:GetParent() return self.parent end
	function f:SetParent(p) self.parent = p; self.setParentCalls = self.setParentCalls + 1 end
	function f:IsProtected() return self.protected end
	return f
end

local MinimapBackdrop = makeFrame("MinimapBackdrop")
local UIHider = makeFrame("UIHider")
local button = makeFrame("ExternalEventURLButton")
button.parent = MinimapBackdrop
MinimapBackdrop.ExternalEventURLButton = button

local client = { region = "CN", combat = false }

local MinimapMod = {}

local env = {
	MinimapMod = MinimapMod,
	MinimapBackdrop = MinimapBackdrop,
	UIHider = UIHider,
	type = type,
	GetCurrentRegionName = function() return client.region end,
	InCombatLockdown = function() return client.combat end
}
setmetatable(env, { __index = _G })

--------------------------------------------------------------------------
-- Extract and run the real block.
--------------------------------------------------------------------------
local path = root .. "/Components/Misc/Minimap.lua"
local handle = assert(io.open(path, "r"), "cannot open " .. path)
local source = handle:read("*a")
handle:close()

local first = source:find("-- The China client's Activity button", 1, true)
local last = source:find("local defaults = ", first or 1, true)
assert(first and last and last > first, "Activity button section markers not found in " .. path)

local chunk = assert(loadstring(source:sub(first, last - 1), "@Activity button block"))
setfenv(chunk, env)
chunk()

check("block defines both entry points",
	type(MinimapMod.HasEventButton) == "function" and type(MinimapMod.UpdateEventButton) == "function")

--------------------------------------------------------------------------
-- HasEventButton: China client with the button only.
--------------------------------------------------------------------------
MinimapMod.db = { profile = { enabled = true, hideEventButton = false } }

check("China client with the button offers it", MinimapMod:HasEventButton() == true)

client.region = "EU"
check("other regions never offer it", MinimapMod:HasEventButton() == false)

client.region = "TW"
check("Taiwan is not China", MinimapMod:HasEventButton() == false)
client.region = "CN"

MinimapBackdrop.ExternalEventURLButton = nil
check("no button, no option", MinimapMod:HasEventButton() == false)
MinimapBackdrop.ExternalEventURLButton = button

env.GetCurrentRegionName = nil
check("a client without GetCurrentRegionName is left alone", MinimapMod:HasEventButton() == false)
env.GetCurrentRegionName = function() return client.region end

--------------------------------------------------------------------------
-- UpdateEventButton: hide, restore, and leave alone.
--------------------------------------------------------------------------
MinimapMod:UpdateEventButton()
check("off by default leaves Blizzard's parent", button.parent == MinimapBackdrop and button.setParentCalls == 0)

MinimapMod.db.profile.hideEventButton = true
MinimapMod:UpdateEventButton()
check("hiding moves it into the hidden frame", button.parent == UIHider)

MinimapMod:UpdateEventButton()
check("hiding twice keeps the original parent to return to", MinimapMod.eventButtonParent == MinimapBackdrop)

MinimapMod.db.profile.hideEventButton = false
MinimapMod:UpdateEventButton()
check("unhiding gives it back to MinimapBackdrop", button.parent == MinimapBackdrop)
check("and forgets the saved parent", MinimapMod.eventButtonParent == nil)

local calls = button.setParentCalls
MinimapMod:UpdateEventButton()
check("unhidden and never moved is not touched again", button.setParentCalls == calls)

MinimapMod.db.profile.hideEventButton = true
MinimapMod:UpdateEventButton()
MinimapMod.db.profile.enabled = false
MinimapMod:UpdateEventButton()
check("turning the minimap module off gives it back", button.parent == MinimapBackdrop)
MinimapMod.db.profile.enabled = true

client.region = "EU"
calls = button.setParentCalls
MinimapMod:UpdateEventButton()
check("outside China a saved true does nothing", button.setParentCalls == calls and button.parent == MinimapBackdrop)
client.region = "CN"

--------------------------------------------------------------------------
-- Combat: a plain button is moved at once, a protected one waits.
--------------------------------------------------------------------------
client.combat = true
MinimapMod:UpdateEventButton()
check("a plain button hides in combat", button.parent == UIHider and not MinimapMod.eventButtonPending)

MinimapMod.db.profile.hideEventButton = false
button.protected = true
MinimapMod:UpdateEventButton()
check("a protected button waits out combat", button.parent == UIHider and MinimapMod.eventButtonPending == true)

client.combat = false
MinimapMod:UpdateEventButton()
check("and is given back after combat", button.parent == MinimapBackdrop and MinimapMod.eventButtonPending == nil)

print(string.format("\n%d checks, %d failures", checks, failures))
os.exit(failures == 0 and 0 or 1)

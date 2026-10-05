-- Run with Tools/Run-Elune.ps1 -Script Tools/Harness/sanity_bar_taint_probe.lua.
-- Isolated Lua taint experiment; does not model WoW frames or secret numbers.
local bar = {}
local function NativeOnEvent(self)
	-- A C function result models a fresh API value (literal constants stay clean).
	self.value = tonumber("25")
	self.displayedValue = tonumber("20")
end
assert(issecure())
NativeOnEvent(bar)
assert(issecurevariable(bar, "value"))
local function AddonDispatch()
	debug.setstacktaint("AzeriteUI5_JuNNeZ_Edition")
	assert(pcall(NativeOnEvent, bar))
end
securecall(AddonDispatch)
local secure, source = issecurevariable(bar, "value")
assert(not secure, "pcall must not sanitize native field writes")
assert(source == "AzeriteUI5_JuNNeZ_Edition")
print("Elune: native handler called through addon pcall taints value; source=" .. source)

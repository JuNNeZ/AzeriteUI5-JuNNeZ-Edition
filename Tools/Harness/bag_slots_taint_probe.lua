-- Run with Tools/Run-Elune.ps1 -Script Tools/Harness/bag_slots_taint_probe.lua.
-- Tests the actual AceHook method post-hook boundary, not WoW frames or navigation.
local root = arg[1] or "."
assert(loadfile(root .. "/Libs/LibStub/LibStub.lua"))()
assert(loadfile(root .. "/Libs/AceHook-3.0/AceHook-3.0.lua"))()
local native = {}
function native:Layout()
	assert(issecure(), "native layout must run before entering addon code")
	self.value = tonumber("25")
end
local addon = {}
LibStub("AceHook-3.0"):Embed(addon)
local called = false
local function Install()
	debug.setstacktaint("AzeriteUI5_JuNNeZ_Edition")
	addon:SecureHook(native, "Layout", function()
		assert(not issecure(), "addon hook keeps its own taint")
		called = true
	end)
end
securecall(Install)
native:Layout()
assert(issecure(), "caller remains secure after the post-hook")
assert(issecurevariable(native, "value"), "native field write remains clean")
assert(called, "post-hook ran")
print("bag_slots_taint: AceHook post-hook preserves native layout security (Elune only)")

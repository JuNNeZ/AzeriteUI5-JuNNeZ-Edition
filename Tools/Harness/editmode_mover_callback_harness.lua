-- Run with Tools/Run-Elune.ps1 -Script Tools/Harness/editmode_mover_callback_harness.lua.
-- Models how Core/MovableFrameManager.lua joins Blizzard's Edit Mode: an addon callback
-- registered on EventRegistry for "EditMode.Enter"/"EditMode.Exit". Blizzard triggers it
-- from EnterEditMode after its own secure walk over the systems, through
-- CallbackRegistryMixin:TriggerEvent, which runs each callback with securecallfunction
-- inside secureexecuterange (Blizzard_SharedXMLBase/CallbackRegistry.lua:184-214).
-- Checks that Blizzard's path stays secure after the tainted callback ran, that the
-- registry of systems is untouched, and that the callback did its own (tainted) work.
-- Not a WoW client: frames are plain tables, so a live /reload + Edit Mode is still owed.

local function MakeFrame()
	local f = { shown = false }
	function f:Show() self.shown = true end
	function f:Hide() self.shown = false end
	return f
end

-- Blizzard (secure): the systems Edit Mode walks, and its callback registry.
local system = MakeFrame()
local registeredSystemFrames = { system }
local callbacks = {}

-- The per-event table is made securely, as CallbackRegistryMixin:SecureInsertEvent does
-- through a forbidden frame's attribute handler ("Taint barrier for inserting event key
-- into callback tables"). Only our own entry in it is tainted. A first model that made
-- the table from addon code tainted EnterEditMode, which is what that barrier prevents.
local function SecureInsertEvent(event)
	if (not callbacks[event]) then
		securecallfunction(rawset, callbacks, event, {})
	end
end

local function RegisterCallback(event, func, owner)
	callbacks[event][owner] = func
end

-- Blizzard has the keys long before any addon registers; model that from secure code.
SecureInsertEvent("EditMode.Enter")
SecureInsertEvent("EditMode.Exit")

local function TriggerEvent(event, ...)
	local funcs = callbacks[event]
	if (not funcs) then return end
	local function ExecuteOwnerPair(owner, func, ...)
		securecallfunction(func, owner, ...)
	end
	secureexecuterange(funcs, ExecuteOwnerPair, ...)
end

local function EnterEditMode()
	secureexecuterange(registeredSystemFrames, function(_, frame) frame:Show() end)
	TriggerEvent("EditMode.Enter")
end

local function ExitEditMode()
	secureexecuterange(registeredSystemFrames, function(_, frame) frame:Hide() end)
	TriggerEvent("EditMode.Exit")
end

-- Addon (tainted): the mover manager and one mover.
local manager = { anchors = { MakeFrame() } }
function manager:OnEditModeEnter()
	self.editModeShowsAnchors = true
	for _, anchor in ipairs(self.anchors) do anchor:Show() end
end
function manager:OnEditModeExit()
	self.editModeShowsAnchors = nil
	for _, anchor in ipairs(self.anchors) do anchor:Hide() end
end

assert(issecure())
securecall(function()
	debug.setstacktaint("AzeriteUI5_JuNNeZ_Edition")
	RegisterCallback("EditMode.Enter", manager.OnEditModeEnter, manager)
	RegisterCallback("EditMode.Exit", manager.OnEditModeExit, manager)
end)

EnterEditMode()
assert(issecure(), "Blizzard's EnterEditMode must stay secure after our callback ran")
assert(system.shown, "Blizzard's own systems still enter Edit Mode")
assert(manager.anchors[1].shown and manager.editModeShowsAnchors, "our movers show with Edit Mode")
assert(#registeredSystemFrames == 1 and registeredSystemFrames[1] == system, "the system registry is untouched")
assert(issecurevariable(registeredSystemFrames, 1), "registry entries stay secure")

ExitEditMode()
assert(issecure(), "Blizzard's ExitEditMode must stay secure after our callback ran")
assert(not system.shown and not manager.anchors[1].shown, "both leave Edit Mode")
assert(manager.editModeShowsAnchors == nil, "the flag clears on exit")

EnterEditMode(); ExitEditMode(); EnterEditMode()
assert(issecure() and manager.anchors[1].shown, "stable across repeated entries")
print("Elune: EditMode.Enter/Exit callbacks show and hide movers; Blizzard's path stays secure, registry untouched")

-- Negative control: calling the tainted callback directly, not through
-- securecallfunction, taints the caller. That is why we register instead of hooking.
local tainted = false
securecall(function()
	debug.setstacktaint("AzeriteUI5_JuNNeZ_Edition")
	manager:OnEditModeEnter()
	tainted = not issecure()
end)
assert(tainted, "control: our code itself runs tainted")
print("Elune: control confirms the callback body is tainted, contained by securecallfunction")

-- Run with Tools/Run-Elune.ps1 -Script Tools/Harness/editmode_selection_hide_harness.lua.
-- Models ns.HideEditModeSelection (Components/ActionBars/Compatibility/HideBlizzard.lua):
-- a post-hook on a system's Selection:Show that hides it. Checks that Blizzard's secure
-- Edit Mode path stays secure, the overlay ends up hidden, and the registry is untouched.
-- Not a WoW client: frames are plain tables, so live /reload + Edit Mode remains owed.
local function MakeSelection()
	local s = { shown = false }
	function s:Show() self.shown = true end
	function s:Hide() self.shown = false end
	function s:IsShown() return self.shown end
	return s
end
local bar = { Selection = MakeSelection() }
local registry = { bar }
local registrySize = #registry

-- Blizzard (secure): ShowHighlighted -> Selection:Show, driven over the registry.
local function HighlightSystem(frame) frame.Selection:Show() end
local function EnterEditMode()
	for _, f in ipairs(registry) do HighlightSystem(f) end
end

-- Addon (tainted): install the hook, as HideBlizzard.lua does.
local hooked, hiding = false, false
local function HideEditModeSelection(frame)
	local selection = frame.Selection
	if hooked then return end
	hooked = true
	hooksecurefunc(selection, "Show", function(self)
		if hiding then return end
		hiding = true
		self:Hide()
		hiding = false
	end)
	if selection:IsShown() then selection:Hide() end
end

assert(issecure())
EnterEditMode()
assert(bar.Selection:IsShown(), "control: without the hook the overlay shows")
bar.Selection:Hide()

securecall(function()
	debug.setstacktaint("AzeriteUI5_JuNNeZ_Edition")
	HideEditModeSelection(bar)
end)

EnterEditMode()
assert(issecure(), "post-hook must not taint Blizzard's calling path")
assert(not bar.Selection:IsShown(), "overlay must be hidden after Edit Mode enters")
assert(#registry == registrySize and registry[1] == bar, "registry must be untouched")
local ok = issecurevariable(registry, 1)
assert(ok, "registry entries must stay secure")
EnterEditMode()
assert(issecure() and not bar.Selection:IsShown(), "stable across repeated entries")
print("Elune: Selection:Show post-hook hides overlay, caller stays secure, registry untouched")

-- Negative control: mutating the registry from addon code taints it (why we do not).
securecall(function()
	debug.setstacktaint("AzeriteUI5_JuNNeZ_Edition")
	registry.entry = bar
end)
assert(not issecurevariable(registry, "entry"), "control: addon registry write must taint")
print("Elune: control confirms registry mutation taints (approach rejected)")

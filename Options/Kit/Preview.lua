--[[

	The MIT License (MIT)

	Copyright (c) 2026 Jonas "JuNNeZ" Andersen

--]]
-- Live previews for the custom options panel.
--
-- A preview is an outline owned by the options panel and anchored around the
-- real frame affected by a setting. The target is never shown, hidden,
-- reparented, resized, recoloured or otherwise changed. This keeps the preview
-- honest and, just as importantly, keeps it away from protected frame state.
--
-- Some pages own several frames (Action Bars, Explorer Mode), while some style
-- Blizzard frames rather than keeping one on their module. Those cases are
-- resolved here explicitly. If no usable live object exists, the panel says so
-- in its footer instead of drawing a pretend frame that can drift from reality.
local Addon, ns = ...

local Kit = ns.OptionsKit
local Defaults = Kit.Defaults
if (not Defaults) then return end

local L = LibStub("AceLocale-3.0"):GetLocale(Addon)

-- Lua API
local ipairs = ipairs
local pairs = pairs
local pcall = pcall
local string_format = string.format
local string_match = string.match
local tonumber, type = tonumber, type
local unpack = unpack

-- GLOBALS: C_NamePlate, CreateFrame, GameTooltip, UIParent, issecurefunc, issecretvalue

local Preview = {}
Kit.Preview = Preview

local DURATION = 1.8
local PULSE = .45
-- A family glows every visible member. This is a backstop, not a budget: the
-- largest family (health bars in a boss fight) reaches about fourteen frames,
-- and members are collected in a fixed order so a cut is never random.
local MAX_TARGETS = 16
-- An explanation has to be read, not glanced at like a frame name.
local EXPLAIN_HOLD = 4.5
local DEFAULT_STYLE = {
	name = "golden-glow",
	backdrop = Kit.PreviewGlowBackdrop,
	labelBackdrop = Kit.PreviewGlowLabelBackdrop,
	color = Kit.PreviewGold,
	inset = 10
}

Preview.DefaultStyle = DEFAULT_STYLE
Preview.MaxTargets = MAX_TARGETS

-- The first overlay carries the label; the rest of a family glows without one.
local overlays = {}
local requestID = 0

local Overlay_OnUpdate = function(self, elapsed)
	self.elapsed = (self.elapsed or 0) + elapsed
	if (self.elapsed >= DURATION) then
		self:Hide()
		self:ClearAllPoints()
		self:SetScript("OnUpdate", nil)
		return
	end

	local phase = (self.elapsed % PULSE) / PULSE
	self:SetAlpha(phase < .5 and (.55 + phase * .9) or (1.45 - phase * .9))
end

local CopyPath = function(path)
	local copy = {}
	for i = 1, #(path or {}) do copy[i] = path[i] end
	return copy
end

-- A UI object is useful only when it is safe to inspect and has a real area to
-- outline. Hidden frames still qualify: disabling a bar should flash the place
-- it occupied rather than make the preview disappear with it.
local IsUsableFrame = function(frame)
	if (not frame or frame == UIParent) then return false end
	-- A `content` field, a provider's return value or a plate's UnitFrame can be
	-- anything another addon put there. Indexing a function would throw.
	local objectType = type(frame)
	if ((objectType ~= "table") and (objectType ~= "userdata")) then return false end
	if (type(frame.GetWidth) ~= "function" or type(frame.GetHeight) ~= "function") then
		return false
	end

	if (type(frame.IsForbidden) == "function") then
		local ok, forbidden = pcall(frame.IsForbidden, frame)
		if (not ok or forbidden) then return false end
	end

	local okWidth, width = pcall(frame.GetWidth, frame)
	local okHeight, height = pcall(frame.GetHeight, frame)
	if (not okWidth or not okHeight) then return false end
	if (type(width) ~= "number" or type(height) ~= "number") then return false end
	if (issecretvalue and (issecretvalue(width) or issecretvalue(height))) then return false end

	return width > 1 and height > 1
end

-- For the cases where a hidden frame's last position means nothing: a closed
-- tooltip, map or bag, or a family member that is not on screen right now.
local IsVisibleFrame = function(frame)
	if (not frame or type(frame.IsVisible) ~= "function") then return false end

	local ok, visible = pcall(frame.IsVisible, frame)
	if (not ok or (issecretvalue and issecretvalue(visible))) then return false end
	return visible and true or false
end

local PreferContent = function(frame)
	if (not frame) then return end

	local objectType = type(frame)
	if ((objectType ~= "table") and (objectType ~= "userdata")) then return end

	local contentOK, content = pcall(function()
		return frame.content
	end)
	if (contentOK and IsUsableFrame(content)) then return content end
	return IsUsableFrame(frame) and frame or nil
end

local CallFrameProvider = function(module, method)
	local provider = module and module[method]
	if (type(provider) ~= "function") then return end

	local ok, frame = pcall(provider, module)
	return ok and PreferContent(frame) or nil
end

local FirstModuleFrame = function(module)
	if (not module) then return end

	-- An explicit provider is the extension point for modules whose useful frame
	-- is not stored under one of the established fields below.
	local frame = CallFrameProvider(module, "GetOptionsPreviewFrame")
		or CallFrameProvider(module, "GetFrame")
	if (frame) then return frame end

	for _, key in ipairs({ "frame", "Frame", "bar", "Button", "anchor" }) do
		frame = PreferContent(module[key])
		if (frame) then return frame end
	end
end

local Module = function(name)
	if (type(name) ~= "string") then return end
	local ok, module = pcall(ns.GetModule, ns, name, true)
	return ok and module or nil
end

local FindPathKey = function(path, pattern)
	for i = #path, 1, -1 do
		local key = path[i]
		if (type(key) == "string") then
			local value = string_match(key, pattern)
			if (value) then return value end
		end
	end
end

local ResolveActionBar = function(module, path)
	local id = tonumber(FindPathKey(path, "^bar(%d+)$"))
	local bars = module and module.bars
	if (type(bars) ~= "table") then return end

	return PreferContent(id and bars[id] or bars[1])
end

-- Which live plates a nameplate setting reaches. These read the plain flags
-- NamePlates.lua already derived and sanitised for its own scaling, never a
-- unit API, so nothing here can touch a secret value. They mirror the branches
-- in its GetEffectivePlateScale.
local IsTargetPlate = function(frame)
	return frame.isTarget == true or frame.isSoftTarget == true
end

local IsEnemyPlate = function(frame)
	return frame.canAttack == true
end

local IsFriendlyNPCPlate = function(frame)
	return frame.canAttack ~= true and frame.isFriendlyAssistableNPC == true
end

local IsFriendlyPlate = function(frame)
	return frame.canAttack ~= true and frame.isFriendlyAssistableNPC ~= true
		and not frame.isObjectPlate and not frame.isPRD
end

local IsFriendlyPlayerPlate = function(frame)
	return IsFriendlyPlate(frame) and frame.isPlayerUnit == true
end

local ResolveNamePlate = function(accept)
	-- These are the addon-owned oUF frames the player actually sees. Prefer the
	-- target plate, then any active plate, before falling back to Blizzard's
	-- plate object on clients where the active registry is unavailable.
	if (type(ns.ActiveNamePlates) == "table") then
		for frame in pairs(ns.ActiveNamePlates) do
			if (frame.isTarget and IsUsableFrame(frame) and (not accept or accept(frame))) then
				return frame
			end
		end
		for frame in pairs(ns.ActiveNamePlates) do
			if (IsUsableFrame(frame) and (not accept or accept(frame))) then return frame end
		end
	end

	-- Blizzard's plate carries none of the flags above, so a setting that only
	-- reaches some plates cannot honestly pick one of these.
	if (accept) then return end
	if (not C_NamePlate or type(C_NamePlate.GetNamePlateForUnit) ~= "function") then return end

	for _, unit in ipairs({ "target", "mouseover", "nameplate1" }) do
		local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit,
			issecurefunc and issecurefunc())
		if (ok and plate) then
			local frame = PreferContent(plate.UnitFrame) or PreferContent(plate)
			if (frame) then return frame end
		end
	end
end

local ResolveGlobal = function(moduleName)
	if (moduleName == "ChatFrames") then
		return PreferContent(_G.ChatFrame1)
	elseif (moduleName == "Containers") then
		return PreferContent(_G.ContainerFrameCombinedBags) or PreferContent(_G.ContainerFrame1)
	elseif (moduleName == "GameMenuSkin") then
		return PreferContent(_G.GameMenuFrame)
	elseif (moduleName == "WorldMap") then
		return PreferContent(_G.WorldMapFrame)
	elseif (moduleName == "Tooltips") then
		return PreferContent(GameTooltip)
	elseif (moduleName == "NamePlates") then
		return ResolveNamePlate()
	end
end

local ResolveNamed

-- In the order Core/ExplorerMode.lua lists them, so a family built from these
-- is always collected the same way.
local explorerOrder = {
	{ "fadeActionBars", "ActionBars" },
	{ "fadePetBar", "PetBar" },
	{ "fadeStanceBar", "StanceBar" },
	{ "fadePlayerFrame", "PlayerFrame" },
	{ "fadePlayerClassPower", "PlayerClassPowerFrame" },
	{ "fadePetFrame", "PetFrame" },
	{ "fadeFocusFrame", "FocusFrame" },
	{ "fadeTracker", "Tracker" },
	{ "fadeChatFrames", "ChatFrames" }
}

local explorerTargets = {}
for _, entry in ipairs(explorerOrder) do explorerTargets[entry[1]] = entry[2] end

-- Read by the panel harness, which checks it against Core/ExplorerMode.lua.
Preview.ExplorerTargets = explorerTargets

-- Only the element toggles name a frame. Explorer Mode's timing and condition
-- settings are handled as a family in the policy table below; anything else
-- resolves to nothing rather than to a frame it does not own.
local ResolveExplorer = function(path)
	local moduleName = explorerTargets[path[#path]]
	if (not moduleName) then return end
	return ResolveNamed(moduleName, path)
end

ResolveNamed = function(moduleName, path)
	local module = Module(moduleName)

	if (moduleName == "ActionBars") then
		local frame = ResolveActionBar(module, path)
		if (frame) then return frame end
	elseif (moduleName == "ExplorerMode") then
		return ResolveExplorer(path)
	elseif (moduleName == "UnitFrames") then
		-- UnitFrames stores shared settings but owns no frame. Each of its
		-- settings is listed in the policy table; one added later without an
		-- entry previews nothing, rather than silently flashing the player frame.
		return
	end

	return FirstModuleFrame(module) or ResolveGlobal(moduleName)
end

Preview.ResolveModuleTarget = function(self, moduleName, path)
	return ResolveNamed(moduleName, path or {})
end

--------------------------------------------------------------------------
-- Policies
--------------------------------------------------------------------------
-- A module binding records whose profile a setting is stored in, not what it
-- changes on screen. For most settings the two agree and the resolution above
-- is right. These are the ones the 2026-09-22 audit of every bound setting
-- found where it is not, each with one of three honest answers:
--
--   exact    One frame, but not the one the module would give. With
--            `visibleOnly`, a hidden frame is not outlined at its last spot.
--   family   Several frames. Every visible member glows; the label goes on
--            the first and the footer gives the count.
--   explain  Nothing on screen shows the change, so no glow at all. The
--            footer says what the setting does instead.
--
-- `explain` doubles as the fallback wording when an exact or family target is
-- not visible. It does not repeat the setting's name: the player has just
-- changed that setting, and the footer is one line that does not wrap. The
-- panel harness holds each one to the footer's width at the smallest window.
--------------------------------------------------------------------------
-- A family member is judged by what is actually on screen. Several unit frame
-- modules keep a plain container for Edit Mode that stays shown however empty
-- it is; the real frames are its `content` (Raid5, Raid25, Raid40, Arena) or
-- its `units` (Boss). PreferContent only hands the container back when its
-- content had no usable size, which means there is nothing on screen to show.
local AddShown = function(add, frame)
	if (not frame) then return end

	local units = frame.units
	if (type(units) == "table") then
		for _, unit in ipairs(units) do add(PreferContent(unit)) end
		return
	end

	if (frame.content ~= nil) then return end
	add(frame)
end

local Members = function(...)
	local names = { ... }
	return function(path, add)
		for _, name in ipairs(names) do
			AddShown(add, ResolveNamed(name, path))
		end
	end
end

local AllActionBars = function(path, add)
	local module = Module("ActionBars")
	local bars = module and module.bars
	if (type(bars) ~= "table") then return end
	for _, bar in ipairs(bars) do add(PreferContent(bar)) end
end

-- The elements Explorer Mode is currently set to fade. One that is switched
-- off is untouched by its timing and conditions, so it is not outlined.
local ExplorerElements = function(path, add)
	local module = Module("ExplorerMode")
	local profile = module and module.db and module.db.profile
	for _, entry in ipairs(explorerOrder) do
		local key, moduleName = entry[1], entry[2]
		if (type(profile) ~= "table" or profile[key] ~= false) then
			if (moduleName == "ActionBars") then
				AllActionBars(path, add)
			else
				AddShown(add, ResolveNamed(moduleName, path))
			end
		end
	end
end

-- UnitFrame.lua re-sorts the Auras, Buffs and Debuffs elements; only these
-- create one. The player frame keeps its own PlayerAuras and is not affected.
local AURA_SORT_FRAMES = Members("TargetFrame", "PartyFrames", "RaidFrame5", "ArenaFrames", "NamePlates")

-- The only two readers of ns.UnitFrame.ShouldColorCastSpellTextByState.
local CAST_TEXT_FRAMES = Members("TargetFrame", "NamePlates")

-- Every module that builds a health prediction element.
local HEALTH_FRAMES = Members("PlayerFrame", "PlayerFrameAlternate", "TargetFrame", "ToTFrame",
	"FocusFrame", "PetFrame", "PartyFrames", "RaidFrame5", "RaidFrame25", "RaidFrame40",
	"BossFrames", "ArenaFrames", "NamePlates")

local healthPolicy = {
	kind = "family",
	members = HEALTH_FRAMES,
	explain = L["Applies to health bars on unit frames and nameplates."]
}

local Plates = function(accept, explain)
	return {
		kind = "exact",
		frame = function() return ResolveNamePlate(accept) end,
		explain = explain
	}
end

local friendlyTarget = function(frame) return IsTargetPlate(frame) and IsFriendlyPlate(frame) end
local enemyTarget = function(frame) return IsTargetPlate(frame) and IsEnemyPlate(frame) end
local friendlyPlayerTarget = function(frame) return IsTargetPlate(frame) and IsFriendlyPlayerPlate(frame) end

local BarPageOnly = function(path)
	-- A per-bar group carries its bar's key; the page-level settings do not.
	return FindPathKey(path, "^bar(%d+)$") == nil
end

local barFamily = {
	kind = "family",
	members = AllActionBars,
	when = BarPageOnly,
	explain = L["Applies to every action bar."]
}

-- How a key press reaches a button, which no outline can show.
local keyHandling = {
	kind = "explain",
	when = BarPageOnly,
	explain = L["Changes how key presses reach the bars, not how they look."]
}

local policies = {
	UnitFrames = {
		showBlizzardRaidBar = {
			kind = "exact",
			visibleOnly = true,
			frame = function() return PreferContent(_G.CompactRaidFrameManager) end,
			explain = L["Blizzard's raid bar only appears in a party or raid."]
		},
		colorCastSpellTextByState = {
			kind = "family",
			members = CAST_TEXT_FRAMES,
			explain = L["Applies to cast names on the target frame and nameplates."]
		},
		disableAuraSorting = {
			kind = "family",
			members = AURA_SORT_FRAMES,
			explain = L["Applies to auras on target, group and arena frames and nameplates."]
		},
		showIncomingHeals = healthPolicy,
		showOverhealIndicator = healthPolicy,
		showDamageAbsorbs = healthPolicy,
		absorbDisplayMode = healthPolicy,
		showHealAbsorbs = healthPolicy
	},
	ActionBars = {
		hideElementsHotkey = barFamily,
		showEmptyButtons = barFamily,
		dimWhenInactive = barFamily,
		dimWhenResting = barFamily,
		clickOnDown = keyHandling,
		useCommandBindingsForHoldCast = keyHandling
	},
	ExplorerMode = {
		-- Its own toggle names a whole set of bars, not bar one.
		fadeActionBars = { kind = "family", members = AllActionBars },
		["*"] = {
			kind = "family",
			members = ExplorerElements,
			when = function(path) return explorerTargets[path[#path]] == nil end,
			explain = L["Applies to every element Explorer Mode fades."]
		}
	},
	NamePlates = {
		friendlyScale = Plates(IsFriendlyPlate, L["No friendly nameplate is visible to preview."]),
		friendlyNPCScale = Plates(IsFriendlyNPCPlate, L["No friendly NPC nameplate is visible to preview."]),
		enemyScale = Plates(IsEnemyPlate, L["No enemy nameplate is visible to preview."]),
		threatColorPreset = Plates(IsEnemyPlate, L["No enemy nameplate is visible to preview."]),
		friendlyTargetScale = Plates(friendlyTarget, L["Target a friendly unit to preview this."]),
		nameplateTargetScale = Plates(enemyTarget, L["Target an enemy to preview this."]),
		hideFriendlyPlayerHealthBar = Plates(IsFriendlyPlayerPlate, L["No friendly player nameplate is visible to preview."]),
		friendlyNameOnlyFontScale = Plates(IsFriendlyPlayerPlate, L["No friendly player nameplate is visible to preview."]),
		friendlyNameOnlyTargetScale = Plates(friendlyPlayerTarget, L["Target a friendly player to preview this."]),
		maxDistance = {
			kind = "explain",
			explain = L["Changes how far away nameplates appear."]
		},
		-- Both fade the plates that are not your target, so the target plate shows nothing of them.
		contentMinAlpha = {
			kind = "explain",
			explain = L["Changes how faint nameplates get."]
		},
		contentOccludedAlpha = {
			kind = "explain",
			explain = L["Changes how faint nameplates get."]
		},
		combatFilter = {
			kind = "explain",
			explain = L["Changes how faint nameplates get."]
		},
		combatFilterAlpha = {
			kind = "explain",
			explain = L["Changes how faint nameplates get."]
		},
		-- The marker is drawn on the plates the player can attack, the ones IsEnemyPlate picks.
		executeMarker = Plates(IsEnemyPlate, L["No enemy nameplate is visible to preview."]),
		executeThresholdMode = Plates(IsEnemyPlate, L["No enemy nameplate is visible to preview."]),
		executeThreshold = Plates(IsEnemyPlate, L["No enemy nameplate is visible to preview."])
	},
	MicroMenu = {
		-- The module's `bar` is the cog's popup, hidden until clicked.
		enabled = {
			kind = "exact",
			frame = function()
				local module = Module("MicroMenu")
				return module and PreferContent(module.toggle)
			end
		},
		showBlizzardMicroMenu = {
			kind = "exact",
			frame = function()
				return PreferContent(_G.MicroMenuContainer) or PreferContent(_G.MicroMenu)
			end
		}
	},
	-- Windows that are closed most of the time. Their last position is not a
	-- place the setting lives.
	Tooltips = { ["*"] = { kind = "exact", visibleOnly = true,
		explain = L["Applies to tooltips. Hover over something to see one."] } },
	WorldMap = { ["*"] = { kind = "exact", visibleOnly = true,
		explain = L["Open the world map to preview this."] } },
	GameMenuSkin = { ["*"] = { kind = "exact", visibleOnly = true,
		explain = L["Open the game menu to preview this."] } },
	Containers = { ["*"] = { kind = "exact", visibleOnly = true,
		explain = L["Open your bags to preview this."] } }
}

Preview.Policies = policies

local FindPolicy = function(moduleName, path)
	local set = policies[moduleName]
	if (not set) then return end

	-- Not ipairs over the pair: a setting with no entry of its own is a nil in
	-- the first slot, and ipairs would stop there without reaching the "*".
	local key = path[#path]
	local own, any = set[key], set["*"]
	if (own and (not own.when or own.when(path))) then return own end
	if (any and (not any.when or any.when(path))) then return any end
end

Preview.GetPolicy = function(self, moduleName, path)
	return FindPolicy(moduleName, path or {})
end

-- The frames to outline for a setting, in order, and the policy that chose
-- them. An empty list is an answer too: nothing honest to show.
local ResolveTargets = function(moduleName, path, policy)
	local kind = policy and policy.kind or "exact"
	local targets, seen = {}, {}

	local add = function(frame)
		if (not frame or seen[frame] or #targets >= MAX_TARGETS) then return end
		if (kind == "family" or (policy and policy.visibleOnly)) then
			if (not IsVisibleFrame(frame)) then return end
		end
		seen[frame] = true
		targets[#targets + 1] = frame
	end

	if (kind == "family") then
		policy.members(path, add)
	elseif (kind == "exact") then
		-- A policy that names its frame is final: falling back to the module's
		-- own frame would bring back exactly the wrong target it exists to fix.
		if (policy and policy.frame) then
			local ok, frame = pcall(policy.frame, path)
			add(ok and frame or nil)
		else
			add(ResolveNamed(moduleName, path))
		end
	end

	return targets, kind
end

Preview.ResolveTargets = function(self, options, path)
	path = path or {}
	local moduleName = Defaults.ModuleNameFor(options, path)
	if (not moduleName) then return end

	local policy = FindPolicy(moduleName, path)
	local targets, kind = ResolveTargets(moduleName, path, policy)
	return targets, moduleName, kind, policy
end

Preview.ResolveTarget = function(self, options, path)
	local targets, moduleName = self:ResolveTargets(options, path)
	if (not moduleName) then return end
	return targets[1], moduleName
end

local CreateOverlay = function(withLabel)
	local frame = CreateFrame("Frame", nil, UIParent, ns.BackdropTemplate)
	frame:SetFrameStrata("TOOLTIP")
	frame:SetToplevel(true)
	-- Do not clamp this: moving the overlay inward at a screen edge would make
	-- the outline stop matching the frame it is meant to identify.
	frame:SetBackdrop(DEFAULT_STYLE.backdrop)
	frame:SetBackdropColor(0, 0, 0, 0)
	frame:EnableMouse(false)
	frame:Hide()

	if (withLabel) then
		local labelFrame = CreateFrame("Frame", nil, frame, ns.BackdropTemplate)
		labelFrame:SetSize(260, 24)
		labelFrame:SetPoint("BOTTOM", frame, "TOP", 0, 8)
		labelFrame:SetBackdrop(DEFAULT_STYLE.labelBackdrop)
		labelFrame:EnableMouse(false)
		frame.labelFrame = labelFrame

		local label = labelFrame:CreateFontString(nil, "OVERLAY")
		label:SetFontObject(Kit.GetFont(12, true))
		label:SetPoint("LEFT", labelFrame, "LEFT", 8, 0)
		label:SetPoint("RIGHT", labelFrame, "RIGHT", -8, 0)
		label:SetJustifyH("CENTER")
		label:SetWordWrap(false)
		frame.label = label
	end

	return frame
end

local GetOverlay = function(index)
	local frame = overlays[index]
	if (not frame) then
		frame = CreateOverlay(index == 1)
		overlays[index] = frame
	end
	return frame
end

local HideOverlay = function(frame)
	frame:Hide()
	frame:ClearAllPoints()
	frame:SetScript("OnUpdate", nil)
end

Preview.Restyle = function(self)
	for _, frame in ipairs(overlays) do
		local style = frame.previewStyle or DEFAULT_STYLE
		frame:SetBackdrop(style.backdrop)
		frame:SetBackdropBorderColor(unpack(style.color))
		if (frame.labelFrame) then
			frame.labelFrame:SetBackdrop(style.labelBackdrop)
			frame.labelFrame:SetBackdropColor(0, 0, 0, .88)
			frame.labelFrame:SetBackdropBorderColor(unpack(style.color))
			frame.label:SetTextColor(unpack(style.color))
		end
	end
end

Preview.Hide = function(self)
	for _, frame in ipairs(overlays) do HideOverlay(frame) end
end

Preview.GetOverlays = function(self)
	return overlays
end

local SetPanelStatus = function(text, found, hold)
	local panel = Kit.Panel
	if (panel and panel.SetPreviewStatus) then
		panel:SetPreviewStatus(text, found, hold)
	end
end

Preview.Request = function(self, options, path, label)
	local targets, moduleName, kind, policy = self:ResolveTargets(options, path)
	if (not moduleName) then return false end
	local style = self.DefaultStyle

	requestID = requestID + 1
	label = (type(label) == "string" and label ~= "") and label or moduleName

	local explanation = policy and policy.explain or nil

	self.lastRequest = {
		id = requestID,
		label = label,
		moduleName = moduleName,
		path = CopyPath(path),
		kind = kind,
		target = targets[1],
		targets = targets,
		explanation = explanation,
		style = style.name
	}

	self:Hide()

	if (#targets == 0) then
		if (explanation) then
			SetPanelStatus(explanation, false, EXPLAIN_HOLD)
		else
			SetPanelStatus(string_format(L["No visible frame to preview for %s."], label), false)
		end
		return true
	end

	for index, target in ipairs(targets) do
		local frame = GetOverlay(index)
		frame.previewStyle = style
		frame:ClearAllPoints()
		frame:SetPoint("TOPLEFT", target, "TOPLEFT", -style.inset, style.inset)
		frame:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", style.inset, -style.inset)
		if (frame.label) then frame.label:SetText(label) end
		frame.elapsed = 0
		frame:SetAlpha(1)
		frame:SetScript("OnUpdate", Overlay_OnUpdate)
	end

	self:Restyle()
	for index = 1, #targets do overlays[index]:Show() end

	if (#targets > 1) then
		-- The count comes first, so a long name cut off at the footer's edge
		-- loses its tail rather than the number.
		SetPanelStatus(string_format(L["Previewing %d frames for %s."], #targets, label), true)
	else
		SetPanelStatus(string_format(L["Previewing %s."], label), true)
	end
	return true
end

Preview.GetLastRequest = function(self)
	return self.lastRequest
end

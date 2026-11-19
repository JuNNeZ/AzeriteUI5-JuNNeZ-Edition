-- Usage: Tools/Run-Elune.ps1 -Script Tools/Harness/loot_roll_choices_harness.lua . mainline|forever
local root, flavor = arg[1] or ".", arg[2] or "mainline"
local alerts = { db = { profile = {} } }
local container = {
	rollFrames = {},
	IsVisible = function() return true end,
	IsShown = function(self) return self.shown end
}
local tooltip = { lines = {} }
function tooltip:IsOwned(button) return self.owner == button end
function tooltip:AddLine(name) self.lines[#self.lines + 1] = name end
function tooltip:Show() end

local function Region()
	return {
		SetAlpha = function(self, alpha) self.alpha = alpha end,
		ClearAllPoints = function(self) self.point = nil end,
		SetPoint = function(self, ...) self.point = { ... } end,
		SetSize = function(self, width, height) self.width, self.height = width, height end,
		GetHeight = function(self) return self.height end,
		GetFrameLevel = function(self) return self.level end,
		IsVisible = function(self) return self:IsShown() end,
		SetFrameLevel = function(self, level) self.level = level end,
		SetTexture = function(self, texture) self.texture = texture end,
		SetVertexColor = function(self, ...) self.vertexColor = { ... } end,
		SetTexCoord = function(self, ...) self.uv = { ... } end,
		SetAllPoints = function(self, relative) self.allPoints = relative end,
		SetColorTexture = function(self, ...) self.color = { ... } end,
		SetFontObject = function() end,
		level = 10
	}
end

local function Button(shown)
	local button = Region()
	button.shown = shown
	button.scripts = {}
	local normal, pushed, highlight = Region(), Region(), Region()
	function button:GetNormalTexture() return normal end
	function button:GetPushedTexture() return pushed end
	function button:GetHighlightTexture() return highlight end
	function button:CreateTexture(_, layer)
		local texture = Region()
		self[layer] = texture
		return texture
	end
	function button:IsShown() return self.shown end
	function button:CreateFontString()
		local count = { SetPoint = function() end, SetFontObject = function() end, SetTextColor = function() end }
		function count:SetText(value) self.value = value end
		function count:Hide() self.shown = false end
		function count:Show() self.shown = true end
		self.count = count
		return count
	end
	function button:HookScript(name, callback)
		self.scripts[name] = self.scripts[name] or {}
		table.insert(self.scripts[name], callback)
	end
	return button
end

local buttons = { NeedButton = Button(true), GreedButton = Button(true), PassButton = Button(true), TransmogButton = Button(false) }
local frame = Region()
if flavor == "forever" then
	frame.LootButtonContainer = buttons
else
	for key, button in pairs(buttons) do frame[key] = button end
end
frame.IsProtected = function() return false end
frame.CreateTexture = function(self, _, layer)
	local texture = Region()
	self[layer] = texture
	return texture
end
frame.Background, frame.Border, frame.Name, frame.IconFrame, frame.Timer = Region(), Region(), Region(), Region(), Region()
frame.Timer.Background = { SetColorTexture = function() end }
frame.Timer.SetStatusBarTexture = function(self, texture) self.texture = texture end
frame.Timer.SetStatusBarColor = function() end
frame.HookScript = function(self, event, callback) self[event] = callback end
frame.rollID = 101
frame.IsShown = function() return true end
container.rollFrames[2] = frame
local active = { 101 }
local links = { [101] = "first item", [102] = "first item", [103] = "second item" }
local states = { NeedMainSpec = 0, NeedOffSpec = 1, Transmog = 2, Greed = 3, NoRoll = 4, Pass = 5 }
local need, greed, pass, transmog = buttons.NeedButton, buttons.GreedButton, buttons.PassButton, buttons.TransmogButton
greed.tooltipText, transmog.tooltipText = "Greed", "Transmog choice"
local secret = {}
local pending
local function Drop(link, rollInfos)
	return { itemHyperlink = link, rollInfos = rollInfos, startTime = 100, duration = 60 }
end
local drop = Drop(links[101], {
	{ playerName = "Main", state = states.NeedMainSpec },
	{ playerName = "Off", state = states.NeedOffSpec },
	{ playerName = "Greedy", state = states.Greed },
	{ playerName = "Waiting", state = states.NoRoll },
	{ playerName = "Transmog", state = states.Transmog }
})
local drops = { drop }
local env = setmetatable({
	LibStub = function() return { GetLocale = function() return {} end } end,
	Enum = { EncounterLootDropRollState = states },
	GroupLootContainer = container,
	GameTooltip = tooltip,
	issecretvalue = function(value) return value == secret end,
	GetActiveLootRollIDs = function() return active end,
	GetLootRollItemLink = function(id) return links[id] end,
	C_Timer = { After = function(delay, callback)
		assert(delay == 0 and not pending)
		pending = callback
	end },
	C_LootHistory = {
		GetLootHistoryTime = function() return 120 end,
		GetAllEncounterInfos = function() return { { encounterID = 12 } } end,
		GetSortedDropsForEncounter = function() return drops end
	}
}, { __index = _G })
local ns = {
	NewModule = function() return alerts end,
	Merge = function(_, values) return values end,
	MovableModulePrototype = {},
	Colors = { highlight = { 1, .8, .5 } },
	API = { GetFont = function() return {} end, GetEffectiveScale = function() return 1 end }
}
setfenv(assert(loadfile(root .. "/Components/Misc/AlertFrames.lua")), env)("AzeriteUI", ns)
alerts.db.profile = alerts:GenerateDefaults().profile
local function Refresh()
	alerts:QueueLootRollRefresh()
	alerts:QueueLootRollRefresh()
	local run = assert(pending)
	pending = nil
	run()
end
local function Hover(button)
	tooltip.lines, tooltip.owner = { "Native tooltip" }, button
	for _, callback in ipairs(button.scripts.OnEnter) do callback(button) end
	return table.concat(tooltip.lines, ", ")
end

alerts:QueueLootRollRefresh()
assert(not pending and not need.count, "default off must leave native buttons alone")
alerts.db.profile.showLootRollChoices = true
Refresh()
assert(need.count.shown and need.count.value == 2 and greed.count.value == 1 and pass.count.value == 0)
assert(Hover(need) == "Native tooltip, Main, Off"
	and Hover(greed) == "Native tooltip, Greedy, Transmog choice, Transmog")
assert(not transmog.count, "hidden alternate button does not get a badge")
transmog.shown, greed.shown = true, false
Refresh()
assert(not greed.count.shown and transmog.count.value == 1 and Hover(transmog) == "Native tooltip, Transmog, Greed, Greedy")

active[2] = 102
Refresh()
assert(not need.count.shown, "duplicate active roll, including a queued roll")
active[2] = nil
drops[2] = Drop(links[101], {})
Refresh()
assert(not need.count.shown, "duplicate pending history records")
drops[2].startTime = 0
Refresh()
assert(need.count.shown and need.count.value == 2, "expired history does not shadow the current drop")
drop.rollInfos[1].playerName = secret
Refresh()
assert(need.count.value == 2 and Hover(need) == "Native tooltip, Off", "restricted name is omitted")
drop.rollInfos[1].state = secret
Refresh()
assert(not need.count.shown, "restricted choice suppresses the count")

frame.rollID, active[1] = 103, 103
drops[3] = Drop(links[103], { { playerName = "New", state = states.NeedMainSpec } })
assert(Hover(need) == "Native tooltip", "pooled frame cannot show names from its previous roll")
Refresh()
assert(need.count.value == 1 and Hover(need) == "Native tooltip, New")
drops = {}
Refresh()
assert(not need.count.shown and Hover(need) == "Native tooltip", "cleared history removes previous data")

drops[1] = Drop(links[103], {})
Refresh()
assert(need.count.shown and need.count.value == 0, "verified empty history shows zero")
alerts.db.profile.showLootRollChoices = false
Refresh()
assert(not need.count.shown and Hover(need) == "Native tooltip")
local generateBagsOptions
local containers = { IsEnabled = function() return true end }
local options = { AddGroup = function(_, _, generate) generateBagsOptions = generate end }
local modules = { AlertFrames = alerts, Containers = containers, Options = options }
alerts.IsEnabled = function() return true end
ns.GetModule = function(_, name) return modules[name] end
ns.BackdropTemplate = "BackdropTemplate"
local theme = "Azerite"
local classTheme
ns.ThemeEngine = { GetActive = function() return classTheme end }
ns.API.GetMedia = function(name) return theme .. "/" .. name end
local rounded, panelFill = true, { .03, .03, .03, .95 }
ns.OptionsKit = {
	WindowOutset = { left = 10, right = 10, top = 18, bottom = 18 },
	WindowCasing = { edgeFile = "Classic/options-edge", edgeSize = 32 },
	WindowCasingColor = { 1, 1, 1, 1 },
	GetSavedWindowColor = function() return unpack(panelFill) end,
	Look = {
		IsRounded = function() return rounded end,
		CasingBackdrop = { edgeFile = "Azerite/options-round", edgeSize = 32 },
		RoundTexture = function(texture) texture:SetTexture("options-round-fill") end
	}
}
ns.GetConfig = function(name)
	if name == "PlayerCastBar" then
		return { CastBarTexture = theme .. "/cast", CastBarColor = { 1, .8, .4, 1 } }
	end
	return { AlertFramesSize = { 200, 40 }, AlertFramesPadding = 10 }
end
env._G = { GroupLootFrame1 = frame }
local casings = {}
local function LocaleStub()
	return { GetLocale = function() return setmetatable({}, { __index = function(_, key) return key end }) end }
end
env.LibStub = LocaleStub
env.CreateFrame = function(_, _, parent)
	local casing = Region()
	casing.SetAllPoints = function() end
	casing.SetBackdrop = function(self, config) self.backdrop = config end
	casing.SetBackdropColor = function() end
	casing.SetBackdropBorderColor = function(self, r) self.brass = r end
	casings[parent] = casing
	return casing
end
setfenv(assert(loadfile(root .. "/Components/Misc/LootRollSkin.lua")), env)("AzeriteUI", ns)
env.C_Container = {}
setfenv(assert(loadfile(root .. "/Options/OptionsPages/Bags.lua")), env)("AzeriteUI", ns)
local bagOptions = generateBagsOptions().args
local toggle = bagOptions.showLootRollChoices
assert(toggle and not toggle.get(), "Bags exposes the option with the saved default")
toggle.set(nil, true)
assert(toggle.get() and pending, "Bags toggle saves the choice and schedules a refresh")
Refresh()
assert(need.count.shown)

alerts:PrepareLootRollSkin()
assert(not alerts:IsLootRollSkinned(frame) and not casings[frame], "default off uses native geometry")
local skin = bagOptions.skinLootRolls
local classSkin = bagOptions.lootRollClassTheme
assert(skin and not skin.get())
assert(classSkin and not classSkin.get(), "the Options look is the default")
skin.set(nil, true)
assert(skin.get() and not casings[frame], "cosmetic layout is applied on reload")
alerts:PrepareLootRollSkin()
assert(alerts:IsLootRollSkinned(frame) and frame.height == 46)
assert(frame.Background.alpha == 0 and frame.Border.alpha == 0 and casings[frame])
assert(frame.Name.point[4] + 145 < 320 + need.point[4] - 32, "item name clears Need hitbox")
assert(frame.Timer.height == 3 and frame.Timer.texture == "Azerite/cast" and frame.Timer.level > frame.level)
assert(casings[frame].backdrop.edgeFile == "Azerite/options-round" and casings[frame].backdrop.edgeSize == 24
	and not casings[frame].backdrop.bgFile and frame.BACKGROUND.texture == "options-round-fill")
local function AssertBorderlessButton(button)
	assert(button.width == 32 and button.height == 32 and button.BACKGROUND.allPoints == button)
	assert(button.BACKGROUND.color and not button.ARTWORK and not casings[button])
	assert(button:GetNormalTexture().width == 20 and button:GetHighlightTexture().width == 20)
end
for _, button in ipairs({ need, greed, pass, transmog }) do AssertBorderlessButton(button) end
assert(need.point[4] < greed.point[4] and greed.point[4] < pass.point[4])
assert(greed.point[4] == transmog.point[4], "alternate uses the same slot")
frame.Timer:SetFrameLevel(frame:GetFrameLevel() - 1)
theme = "Paladin"
panelFill = { .88, .88, .90, .97 }
ns.OptionsKit.Look.CasingBackdrop.edgeFile = "Paladin/options-round"
frame.OnShow(frame)
assert(frame.Timer.level > frame.level, "recycled native row restores timer layer")
assert(casings[frame].backdrop.edgeFile == "Paladin/options-round" and frame.Timer.texture == "Paladin/cast"
	and frame.BACKGROUND.vertexColor[1] == panelFill[1], "show resolves panel and timer themes")
alerts:PrepareLootRollSkin()
assert(#need.scripts.OnEnter == 1, "the tooltip hook is installed once")
drops[1].rollInfos[1] = { playerName = "Main", state = states.NeedMainSpec }
Refresh()
assert(Hover(need) == "Native tooltip, Main")

local secondFrame = Region()
env._G.GroupLootFrame2 = secondFrame
secondFrame.IsProtected = frame.IsProtected
secondFrame.CreateTexture = frame.CreateTexture
secondFrame.Background, secondFrame.Border, secondFrame.Name, secondFrame.IconFrame = Region(), Region(), Region(), Region()
secondFrame.Timer = Region()
secondFrame.Timer.Background = frame.Timer.Background
secondFrame.Timer.SetStatusBarTexture = frame.Timer.SetStatusBarTexture
secondFrame.Timer.SetStatusBarColor = frame.Timer.SetStatusBarColor
secondFrame.HookScript = frame.HookScript
local secondButtons = flavor == "forever" and {} or secondFrame
if flavor == "forever" then secondFrame.LootButtonContainer = secondButtons end
for key in pairs(buttons) do secondButtons[key] = Button(true) end
alerts:PrepareLootRollSkin()

local updateContainer
alerts.SecureHook = function(_, target, hook)
	if target == "GroupLootContainer_Update" then updateContainer = hook end
end
ns.Prefix, ns.IsRetail = "AzeriteUI", true
env.AlertFrame, env.UIParent = {}, {}
alerts:PrepareFrames()
container.rollFrames[1], container.rollFrames[2], container.rollFrames[3] = frame, nil, secondFrame
container.maxIndex, container.reservedSize = 3, 100
container.SetHeight = function(self, height) self.height = height end
container.Show = function(self) self.shown = true end
container.Hide = function(self) self.shown = false end
updateContainer(container)
assert(container.height == 97 and secondFrame.point[2] == frame and secondFrame.point[5] == -5,
	"compact stack reserves two rows and a single gap even when a roll was removed")
alerts.db.profile.useAutomaticGrowth, alerts.db.profile.growUpwards = false, true
updateContainer(container)
assert(secondFrame.point[1] == "BOTTOM" and secondFrame.point[5] == 5, "compact stack grows upward from its mover")

local window
local CreateCasing = env.CreateFrame
local function Noop() end
env.NEED, env.GREED, env.PASS, env.TRANSMOGRIFICATION = "Need", "Greed", "Pass", "Transmog"
env.RollOnLoot = function() error("Preview must not submit a real vote") end
env.GetActiveLootRollIDs = function() error("Preview must not read live rolls") end
env.C_LootHistory.GetAllEncounterInfos = function() error("Preview must not read loot history") end
tooltip.SetOwner = function(self, owner) self.owner = owner end
tooltip.SetText = function(self, label) self.lines = { label } end
tooltip.Hide = function(self) self.owner = nil end
env.CreateFrame = function(kind, name, parent, template)
	if template == ns.BackdropTemplate then return CreateCasing(kind, name, parent) end
	local widget = kind == "Button" and Button(true) or Region()
	widget.children, widget.shown = {}, true
	if parent == env.UIParent then window = widget else table.insert(parent.children, widget) end
	local hooks = widget.HookScript
	widget.HookScript = hooks or function(self, event, callback) self[event .. "Hook"] = callback end
	widget.SetScript = function(self, event, callback) self[event] = callback end
	widget.SetShown = function(self, shown)
		if self.shown == shown then return end
		self.shown = shown
		if shown and self.OnShow then self:OnShow() end
	end
	widget.Show = function(self) self:SetShown(true) end
	widget.Hide = function(self) self:SetShown(false) end
	widget.IsShown = function(self) return self.shown end
	widget.CreateTexture = widget.CreateTexture or function() return Region() end
	widget.CreateFontString = widget.CreateFontString or function()
		local font = Region()
		font.SetFontObject = function(self) self.hasFont = true end
		font.SetText = function(self) assert(self.hasFont, "set font before text") end
		font.SetTextColor, font.SetJustifyH = Noop, Noop
		return font
	end
	widget.IsProtected = function() return false end
	widget.EnableMouse = function(self, enabled) self.mouseEnabled = enabled end
	widget.SetFrameStrata, widget.SetClampedToScreen = Noop, Noop
	widget.SetNormalAtlas, widget.SetPushedAtlas, widget.SetHighlightAtlas = Noop, Noop, Noop
	widget.SetNormalTexture, widget.SetHighlightTexture = Noop, Noop
	widget.SetMinMaxValues, widget.SetStatusBarTexture, widget.SetStatusBarColor = Noop, Noop, Noop
	widget.SetValue = function(self, value) self.value = value end
	return widget
end
skin.set(nil, false)
toggle.set(nil, false)
local preview = bagOptions.previewLootRolls
assert(preview and preview.type == "execute")
rounded = false
preview.func()
local close, sampleOne, sampleTwo = unpack(window.children)
assert(window.shown and sampleOne.height == frame.height and sampleTwo.point[5] - sampleOne.point[5] == -51)
assert(casings[sampleOne].backdrop.edgeFile == "Classic/options-edge", "preview also supports the classic panel casing")
assert(close.point[2] == sampleOne and close.point[3] == "TOPRIGHT" and close.level > casings[sampleOne].level)
assert(close.point[4] - close.width / 2 >= sampleOne.PassButton.point[4], "close clears the Pass hitbox")
secondFrame.IsShown = function() return true end
classSkin.set(nil, true)
assert(classSkin.get() and casings[sampleOne].backdrop.edgeFile == "Classic/options-edge", "no active class theme falls back")
classTheme = { ResolveOwnMedia = function(_, asset)
	assert(asset == "border-tooltip")
	return "Paladin/class-edge"
end }
classSkin.set(nil, true)
assert(casings[sampleOne].backdrop.edgeFile == "Paladin/class-edge"
	and casings[frame].backdrop.edgeFile == "Paladin/class-edge", "live style change reaches preview and native rows")
classSkin.set(nil, false)
assert(casings[sampleOne].backdrop.edgeFile == "Classic/options-edge"
	and casings[frame].backdrop.edgeFile == "Paladin/options-round", "turning class mode off restores the panel style")
assert(sampleOne.GreedButton.count.value == 3 and sampleTwo.TransmogButton.count.value == 1)
assert(sampleTwo.GreedButton.count == nil and sampleTwo.TransmogButton.shown)
local sampleTimer = sampleOne.Timer.value
window:OnUpdate(1)
assert(sampleOne.Timer.value == sampleTimer - 1 and sampleOne.Timer.value > sampleTwo.Timer.value)
local previewNeed = sampleOne.NeedButton
AssertBorderlessButton(previewNeed)
AssertBorderlessButton(sampleTwo.TransmogButton)
previewNeed:OnClick()
previewNeed:OnClick()
sampleOne.GreedButton:OnClick()
assert(previewNeed.count.value == 2 and sampleOne.GreedButton.count.value == 3, "one mock vote per row")
previewNeed:OnEnter()
for _, callback in ipairs(previewNeed.scripts.OnEnter) do callback(previewNeed) end
assert(table.concat(tooltip.lines, ", ") == "Need, Simaru, You (test roll)")
close:OnClick()
assert(not window.shown)
preview.func()
assert(window.shown and previewNeed.count.value == 1 and sampleOne.Timer.value == sampleTimer)
preview.func()
assert(not window.shown and not skin.get() and not toggle.get(), "preview never changes either option")

local standalone = window
local mover = env.CreateFrame("Frame", nil, env.UIParent)
alerts.anchor = mover
mover:Hide()
alerts:PrepareLootRollLayoutPreview()
mover:Show()
mover:OnShowHook()
local layout = window
local layoutFirst, layoutSecond = unpack(layout.children)
assert(layout ~= standalone and not layout.shown, "active rolls take priority over the layout preview")
assert(layoutFirst.NeedButton.mouseEnabled == false and not layoutFirst.NeedButton.OnClick, "layout preview is passive")
container.rollFrames[1], container.rollFrames[3], container.maxIndex = nil, nil, 0
updateContainer(container)
assert(layout.shown and layout.point[2] == alerts.frame and layout.point[1] == "BOTTOM")
assert(layoutSecond.point[2] == layoutFirst and layoutSecond.point[5] == 5, "layout preview grows upwards")

env._G.AzeriteUIAlertFrameHolder = alerts.frame
env.AlertFrame = { ClearAllPoints = Noop, SetAllPoints = Noop, alertFrameSubSystems = {} }
container.ClearAllPoints, container.SetPoint = frame.ClearAllPoints, frame.SetPoint
alerts.db.profile.growUpwards = false
alerts:PostUpdatePositionAndScale()
assert(layout.point[1] == container.point[1] and layout.point[2] == container.point[2]
	and layout.point[5] == container.point[5] and layoutSecond.point[5] == -5, "layout preview uses the live stack anchors")
mover:Hide()
mover:OnHideHook()
assert(not layout.shown and not standalone.shown, "leaving layout hides only its preview")
io.write("Loot roll choices passed for ", flavor, "\n")

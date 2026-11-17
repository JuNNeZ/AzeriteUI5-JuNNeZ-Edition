-- Real popup service; records model owned override routing, not WoW's input engine.
local root = arg[1] or "."
local checks, failures = 0, 0
local function check(ok, message)
	checks = checks + 1
	if not ok then failures = failures + 1; print("FAIL: " .. message) end
end
local combat, made, all = false, 0, {}
local bindings, gameplay, restricted = {}, 0, false
local function frame(parent)
	local f = { scripts = {}, shown = true, attributes = {}, parent = parent, children = {} }
	if parent then parent.children[#parent.children + 1] = f end
	function f:SetScript(k, fn) self.scripts[k] = fn end
	function f:GetScript(k) return self.scripts[k] end
	local function NotifyVisibility(self, script)
		if self.scripts[script] then self.scripts[script](self) end
		for _, child in ipairs(self.children) do if child.shown then NotifyVisibility(child, script) end end
	end
	function f:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
	function f:Hide()
		local visible = self:IsVisible(); self.shown = false
		if visible then NotifyVisibility(self, "OnHide") end
	end
	function f:Show()
		local visible = self:IsVisible(); self.shown = true
		if not visible and self:IsVisible() then NotifyVisibility(self, "OnShow") end
	end
	function f:IsShown() return self.shown end
	function f:SetShown(v) if v then self:Show() else self:Hide() end end
	function f:SetText(v) self.text = v end
	function f:GetStringHeight() return 38 end
	function f:SetFrameLevel(v) self.level = v end
	function f:SetPropagateKeyboardInput(v) assert(not combat); self.propagate = v end
	function f:CreateFontString() return frame() end
	function f:RegisterEvent(e) self.event = e end
	function f:SetAttribute(k, v) assert(not combat); self.attributes[k] = v end
	function f:RegisterForClicks(...) self.clicks = {...} end
	function f:ClearBindings() assert(restricted); bindings[self] = nil end
	for _, method in ipairs({"SetSize","SetPoint","SetFrameStrata","EnableMouse","SetBackdrop","SetBackdropColor",
		"SetFontObject","SetWidth","SetAllPoints","EnableKeyboard","EnableGamePadButton","EnableMouseMotion","ClearAllPoints","SetHeight","SetBackdropBorderColor"}) do
		f[method] = function() end
	end
	return f
end
CreateFrame = function(_, name, parent, template)
	assert(not template or template == "BackdropTemplate" or template == "SecureHandlerStateTemplate", "no native popup/input template")
	assert(not combat, "no dialog construction in combat")
	made = made + 1; local f = frame(parent); all[#all + 1] = f
	if name then _G[name] = f end
	return f
end
UIParent = frame()
InCombatLockdown = function() return combat end
SetOverrideBindingClick = function(owner, priority, key, name, click)
	assert(owner ~= UIParent, "never replace the native UIParent binding owner")
	assert(not combat, "no addon binding mutation in combat")
	assert(priority == true, "popup bindings take priority over gameplay")
	bindings[owner] = bindings[owner] or {}
	bindings[owner][key] = { name = name, click = click }
end
ClearOverrideBindings = function(owner)
	assert(owner ~= UIParent, "never clear native UIParent bindings")
	assert(not combat, "insecure combat clear refused")
	bindings[owner] = nil
end
RegisterStateDriver = function(owner, state, condition)
	assert(not combat and state == "combat" and condition == "[combat] combat; safe")
	owner.driver = true
end
local function SetCombat(value)
	combat = value
	for _, owner in ipairs(all) do
		if owner.driver then
			local fn = assert(loadstring(owner.attributes["_onstate-combat"]))
			setfenv(fn, { self = owner, newstate = value and "combat" or "safe" })
			restricted = true; fn(); restricted = false
		end
	end
end
local function Pad(key, down)
	for _, keys in pairs(bindings) do
		local bind = keys[key]
		if bind then
			local button = assert(_G[bind.name])
			button.scripts.OnClick(button, bind.click, down)
			return true
		end
	end
	-- Raw frame notifications do not replace the game's binding for the press.
	for i = #all, 1, -1 do
		local f = all[i]
		if f:IsShown() and f.scripts.OnGamePadButtonDown and down then
			f.scripts.OnGamePadButtonDown(f, key)
			break
		end
	end
	gameplay = gameplay + 1
	return false
end
local function Press(key) local a = Pad(key, true); local b = Pad(key, false); return a and b end
local native = 0
StaticPopupDialogs = {}
StaticPopup_Show = function() native = native + 1; return "native" end
local ns = { IsForever = true, Private = {}, BackdropTemplate = "BackdropTemplate",
	API = { GetFont = function() return {} end, GetMedia = function(v) return v end } }
assert(loadfile(root .. "/Core/Widgets/Popups.lua"))("AzeriteUI", ns)
local API = ns.API
if arg[2] == "modal-baseline" then
	local count = 0
	API.PopupDialogs.modal = { text = "Modal", button1 = "OK", hideOnEscape = true,
		OnAccept = function() count = count + 1 end }
	local f = API.ShowPopup("modal")
	check(not f.scripts.OnGamePadButtonDown, "raw gamepad listeners are not used as modal bindings")
	check(Press("PAD1") and count == 1 and gameplay == 0, "owned override consumes both accept edges")
	f = API.ShowPopup("modal")
	SetCombat(true)
	check(not next(bindings), "secure combat state clears owned overrides")
	print(string.format("owned_popup modal baseline: %d checks, %d failures", checks, failures))
	os.exit(failures == 0 and 0 or 1)
end
if arg[2] == "taint" then
	local nativeState = {}
	local originalShow, originalDialogs = StaticPopup_Show, StaticPopupDialogs
	API.PopupDialogs.taint = { text = "Own decision", button1 = "OK" }
	securecall(function()
		debug.setstacktaint("AzeriteUI5_JuNNeZ_Edition")
		API.ShowPopup("taint")
	end)
	check(issecure(), "tainted dialog request leaves native caller secure")
	nativeState.after = tonumber("19")
	check(issecurevariable(nativeState, "after"), "native subsequent state remains untainted")
	check(StaticPopup_Show == originalShow and StaticPopupDialogs == originalDialogs and native == 0
		and not next(originalDialogs), "native popup functions and registrations untouched")
	-- Inspect intentionally tainted owned records inside a barrier, as a native
	-- caller must not read addon-owned state and then claim its own stack is clean.
	securecall(function() assert(next(bindings) ~= nil and not bindings[UIParent]) end)
	check(issecure(), "tainted request installs overrides only on its private owner")
	securecall(function() SetCombat(true) end)
	securecall(function() assert(not next(bindings)) end)
	check(issecure(), "combat driver clears private overrides without contaminating native caller")
	securecall(function() SetCombat(false); all[1].scripts.OnEvent() end)
	securecall(function() assert(next(bindings) ~= nil) end)
	check(issecure(), "out-of-combat replay remains isolated from native caller")
	securecall(function() Press("PAD1") end)
	securecall(function() assert(not next(bindings)) end)
	check(issecure(), "owned binding acceptance retires overrides without native contamination")
	securecall(function()
		debug.setstacktaint("AzeriteUI5_JuNNeZ_Edition")
		nativeState.negative = tonumber("23")
	end)
	check(not issecurevariable(nativeState, "negative"), "negative control detects direct native state contamination")
	API.HidePopup("taint")
end
local accepted, cancelled, chosen = 0, 0, {}
API.PopupDialogs.confirm = { text = "%s", button1 = "Yes", button2 = "No", hideOnEscape = true, timeout = 0,
	OnAccept = function(_, data) accepted = accepted + data end,
	OnCancel = function() cancelled = cancelled + 1 end }
local f = API.ShowPopup("confirm", "Question?", nil, 2)
check(f and f.Text.text == "Question?", "formats message and opens owned frame")
check(native == 0 and not next(StaticPopupDialogs), "Forever never registers or opens native popup")
local oldClick = f.buttons[1]:GetScript("OnClick")
local replacement = API.ShowPopup("confirm", "Replacement", nil, 3)
check(cancelled == 1, "reuse cancels old decision once")
oldClick()
check(accepted == 0, "retired button callback cannot accept replacement")
replacement.buttons[1]:GetScript("OnClick")()
check(accepted == 3 and not replacement:IsShown(), "accept uses replacement data exactly once")
replacement.buttons[1]:GetScript("OnClick")()
check(accepted == 3, "duplicate callback ignored")
f = API.ShowPopup("confirm", "Cancel", nil, 7)
check(Press("PAD2") and cancelled == 2 and accepted == 3, "B cancels through owned binding")
f = API.ShowPopup("confirm", "Escape", nil, 7)
f.scripts.OnKeyDown(f, "ESCAPE")
check(cancelled == 3 and accepted == 3 and not f:IsShown(), "Escape cancels")
API.PopupDialogs.indexed = { text = "Choose", selectCallbackByIndex = true, hideOnEscape = true }
for i = 1, 4 do
	API.PopupDialogs.indexed["button" .. i] = "Choice " .. i
	API.PopupDialogs.indexed["OnButton" .. i] = function() chosen[#chosen + 1] = i end
end
for i = 1, 4 do
	f = API.ShowPopup("indexed")
	for j = 2, i do Press("PADDDOWN") end
	Press("PAD1")
	check(chosen[#chosen] == i, "D-pad and A reach indexed choice " .. i)
end
f = API.ShowPopup("indexed")
local count = #chosen
Press("PAD2")
check(#chosen == count and not f:IsShown(), "B never selects indexed second/fourth choice")
f = API.ShowPopup("confirm", "Combat", nil, 9)
SetCombat(true)
check(not next(bindings) and not Pad("PAD1", true), "secure combat transition releases owned controller bindings")
f.buttons[1]:GetScript("OnClick")()
f.scripts.OnKeyDown(f, "ESCAPE")
check(accepted == 3 and f:IsShown(), "combat blocks choices without keyboard state writes")
local before = made
API.PopupDialogs.queued = { text = "After combat", button1 = "OK", OnAccept = function() accepted = accepted + 20 end }
check(API.ShowPopup("queued") ~= nil and made == before, "combat request queued without frames")
SetCombat(false)
all[1].scripts.OnEvent()
local q
for _, candidate in ipairs(all) do if candidate.request and candidate.request.key == "queued" then q = candidate end end
check(q and q:IsShown() and accepted == 3, "queued decision shown after combat, never auto-accepted")
check(not f.scripts.OnGamePadButtonDown, "older dialog has no raw controller listener")
f.buttons[1]:GetScript("OnClick")()
check(accepted == 3, "older dialog ignores mouse acceptance while a newer decision is open")
API.HidePopup("queued"); API.HidePopup("confirm")
API.PopupDialogs.reopen = { text = "Reopen", button1 = "OK", OnAccept = function() API.ShowPopup("reopen") end }
f = API.ShowPopup("reopen"); f.buttons[1]:GetScript("OnClick")()
check(f:IsShown() and f.request and f.request.key == "reopen", "accept callback can reopen its decision")
API.HidePopup("reopen")
local reentered = false
API.PopupDialogs.reentrant = { text = "Original", button1 = "OK", OnCancel = function()
	if not reentered then reentered = true; API.PopupDialogs.reentrant.OnCancel = nil; API.ShowPopup("reentrant") end
end }
API.ShowPopup("reentrant"); API.ShowPopup("reentrant")
local matching = 0
for _, candidate in ipairs(all) do if candidate.request and candidate.request.key == "reentrant" then matching = matching + 1 end end
check(matching == 1, "reentrant cancellation cannot install duplicate approvals")
API.HidePopup("reentrant")
local savedAccept = API.PopupDialogs.confirm.OnAccept
f = API.ShowPopup("confirm", "Snapshot", nil, 5)
API.PopupDialogs.confirm.OnAccept = function() accepted = accepted + 100 end
f.buttons[1]:GetScript("OnClick")()
check(accepted == 8, "open decision keeps its callback snapshot")
API.PopupDialogs.confirm.OnAccept = savedAccept
for i = 1, 4 do
	API.PopupDialogs["slot" .. i] = { text = "Occupied", button1 = "OK" }
	check(API.ShowPopup("slot" .. i) ~= nil, "owned popup slot " .. i .. " available")
end
check(API.ShowPopup("confirm", "Full", nil, 99) == nil and accepted == 8,
	"full popup service refuses without accepting")
for i = 1, 4 do API.HidePopup("slot" .. i) end
-- Both key edges stay on the owned route. A held key cannot accept a replacement.
local padAccepted = 0
API.PopupDialogs.modal = { text = "Modal", button1 = "OK", hideOnEscape = true,
	OnAccept = function() padAccepted = padAccepted + 1 end }
f = API.ShowPopup("modal")
local beforeGameplay = gameplay
check(Pad("PAD1", true) and padAccepted == 0, "pad press waits for release")
API.ShowPopup("modal")
check(Pad("PAD1", false) and padAccepted == 0, "held key release cannot accept replacement")
check(Press("PAD1") and padAccepted == 1 and gameplay == beforeGameplay, "accept consumes down and up without gameplay fallthrough")
check(not next(bindings), "closing final decision clears owned overrides")
f = API.ShowPopup("modal")
check(not f.scripts.OnGamePadButtonDown, "popup installs no raw pad listener")
for _, modifier in ipairs({ "", "SHIFT-", "CTRL-", "ALT-", "CTRL-SHIFT-", "ALT-SHIFT-", "ALT-CTRL-", "ALT-CTRL-SHIFT-" }) do
	for _, key in ipairs({ "PAD3", "PAD4", "PADDUP", "PADDDOWN", "PADDLEFT", "PADDRIGHT" }) do
		check(Press(modifier .. key), "modified dialog key consumed: " .. modifier .. key)
	end
end
check(gameplay == beforeGameplay and padAccepted == 1, "navigation and unused face buttons do not activate gameplay")
Pad("PAD1", true)
SetCombat(true)
check(not next(bindings), "combat driver clears active overrides without insecure binding writes")
SetCombat(false)
all[1].scripts.OnEvent()
check(Pad("PAD1", false) and padAccepted == 1, "combat cannot retain an earlier approval press")
check(Press("ALT-CTRL-SHIFT-PAD1") and padAccepted == 2, "bindings return out of combat and accept modified pad key")
f = API.ShowPopup("modal")
SetCombat(true)
API.HidePopup("modal")
check(not f:IsShown() and not next(bindings), "combat hide leaves no stuck overrides")
SetCombat(false)
all[1].scripts.OnEvent()
check(not next(bindings), "retired combat decision never regains bindings")
f = API.ShowPopup("modal")
local hiddenClick = f.buttons[1]:GetScript("OnClick")
f:Hide()
check(not next(bindings) and padAccepted == 2, "direct popup Hide releases bindings without choosing")
hiddenClick()
check(padAccepted == 2, "hidden current popup cannot accept a retained mouse callback")
f:Show()
check(next(bindings) ~= nil, "direct popup Show restores newest bindings")
UIParent:Hide()
check(f:IsShown() and not f:IsVisible() and not next(bindings), "hidden parent releases effectively invisible popup bindings")
UIParent:Show()
check(next(bindings) ~= nil, "parent visibility restoration restores modal bindings")
API.HidePopup("modal")
-- Exercise the frozen public ConsolePort API, not a competing override loop.
local cpFixture = root .. "/.research/tmp/native-gamepad-2026-11-16/consoleport-current/ConsolePort/API.lua"
local file = io.open(cpFixture, "rb")
if file then
local cpCallbacks, cpFrames, timers = {}, {}, {}
local cursor = { active = true }
function cursor:IsShown() return self.active end
function cursor:SetCurrentNodeIfActive(node) if self.active then self.node = node end end
local cpData = { Cursor = cursor, Stack = { SetFrame = function(_, node) cpFrames[node] = true end } }
function cpData:RegisterCallback(event, fn, owner) cpCallbacks[event] = function() fn(owner) end end
ConsolePort = { GetData = function() return cpData end }
C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end }
local function flush() local pending = timers; timers = {}; for _, fn in ipairs(pending) do fn() end end
local cpSource = file:read("*a"):gsub("\r\n", "\n"); file:close()
local from = assert(cpSource:find("function ConsolePort:AddInterfaceCursorFrame", 1, true))
local to = assert(cpSource:find("function ConsolePort:RemoveInterfaceCursorFrame", from, true))
local mapFrom = assert(cpSource:find("do local map = function", 1, true))
local mapTo = assert(cpSource:find("-- Rings API", mapFrom, true))
local cpEnv = setmetatable({ ConsolePort = ConsolePort, C_Widget = { IsFrameWidget = function() return true end },
	EventUtil = { ContinueOnAddOnLoaded = function(_, fn) fn() end } }, { __index = _G })
local cpChunk = assert(loadstring("local db, CURSOR_ADDON_NAME = ...\n" .. cpSource:sub(from, to - 1) .. cpSource:sub(mapFrom, mapTo - 1)))
setfenv(cpChunk, cpEnv); cpChunk(cpData, "ConsolePort_Cursor")
f = API.ShowPopup("modal")
check(cpFrames[f] and cursor.node == f.buttons[1] and not next(bindings), "real CP public API registers/focuses popup and owns input")
check(f.blocker:IsShown() and f.blocker.level < f.buttons[1].level, "modal pointer blocker is below its choices")
local cpButton = f.buttons[1]
cpButton:GetScript("OnMouseDown")(cpButton) -- CP EmulateFrontend sends no button argument.
API.ShowPopup("modal")
cpButton:GetScript("OnClick")(cpButton, "LeftButton")
check(padAccepted == 2, "CP held release cannot approve replacement")
cpButton:GetScript("OnMouseDown")(cpButton)
cpButton:GetScript("OnClick")(cpButton, "LeftButton")
check(padAccepted == 3, "CP normal cursor click accepts newest request")
f = API.ShowPopup("modal")
f.buttons[1].OnCancelClick()
check(not f:IsShown() and padAccepted == 3, "CP dedicated cancel never chooses accept")
f = API.ShowPopup("modal")
cursor.active = false; cpCallbacks.OnCursorHide(); flush()
check(next(bindings) ~= nil, "cursor hide restores owned pad route")
cursor.active = true; cpCallbacks.OnCursorShow(); flush()
check(not next(bindings), "cursor activation yields owned overrides")
SetCombat(true); all[1].scripts.OnEvent(all[1], "PLAYER_REGEN_DISABLED")
check(not f.blocker:IsShown() and not next(bindings), "combat releases pointer blocker and private pad route")
SetCombat(false); all[1].scripts.OnEvent(all[1], "PLAYER_REGEN_ENABLED")
check(f.blocker:IsShown() and not next(bindings), "combat exit restores CP-owned modal")
API.HidePopup("modal")
ConsolePort = nil
else
	print("ConsolePort public API integration checks skipped: missing " .. cpFixture)
end
API.PopupDialogs.unsupported = { text = "Edit", button1 = "OK", hasEditBox = true }
check(API.ShowPopup("unsupported") == nil, "unsupported dialog fails closed")
ns.IsForever = false
check(API.ShowPopup("confirm", "Retail") == "native" and native == 1, "Retail retains native route")
print(string.format("owned_popup: %d checks, %d failures", checks, failures))
os.exit(failures == 0 and 0 or 1)

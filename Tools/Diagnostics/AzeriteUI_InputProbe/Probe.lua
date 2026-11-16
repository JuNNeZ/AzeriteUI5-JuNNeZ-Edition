-- Standalone diagnostic only. No AzeriteUI dependency, automatic writes, or bindings.
local addonName, ns = ...
local Probe = { eventSupport = {} }
ns.InputProbe = Probe
local UNKNOWN, CVAR, LIMIT = "unknown", "InputDeviceInterfaceStyle", 400

local function Secret(value)
    if type(issecretvalue) ~= "function" then return false end
    local ok, result = pcall(issecretvalue, value)
    return not ok or result
end
local function Scalar(value)
    if Secret(value) then return UNKNOWN end
    local kind = type(value)
    if kind == "number" then
        if value == value and value > -math.huge and value < math.huge then return value end
    elseif kind == "boolean" then return value
    elseif kind == "string" then return value:sub(1, 160) end
    return UNKNOWN
end
local function Table(value)
    if not Secret(value) and type(value) == "table" then return value end
end
local function Field(object, key)
    object = Table(object)
    if not object then return nil end
    local ok, value = pcall(function() return object[key] end)
    if ok and not Secret(value) then return value end
end
local function Invoke(fn, ...)
    if Secret(fn) or type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, ...)
    if ok and not Secret(value) then return value end
end
local function Bool(value)
    value = Scalar(value)
    if type(value) == "boolean" then return value end
    return UNKNOWN
end
local function Now()
    local value = Scalar(Invoke(GetTime))
    return type(value) == "number" and value or 0
end
local function EnumStyle(key) return Scalar(Field(Field(Enum, "InputDeviceInterfaceType"), key)) end
local function CurrentStyle() return Scalar(Invoke(Field(C_InputInterfaceStyle, "GetCurrentStyle"))) end
local function GetCVarValue()
    return Scalar(Invoke(Field(C_CVar, "GetCVar") or GetCVar, CVAR))
end
local function IsTarget(value)
    value = Scalar(value)
    local mkb, pad = EnumStyle("Mkb"), EnumStyle("Gamepad")
    return type(mkb) == "number" and type(pad) == "number" and mkb ~= pad
        and type(value) == "number" and (value == mkb or value == pad)
end
local function Copy(value, depth)
    if not Table(value) or depth == 0 then return Scalar(value) end
    local result, count = {}, 0
    -- SavedVariables and API tables may contain inaccessible values; never serialize them raw.
    pcall(function()
        for key, child in pairs(value) do
            local safeKey = Scalar(key)
            if (type(safeKey) == "number" or type(safeKey) == "string") and safeKey ~= UNKNOWN then
                result[safeKey] = Copy(child, depth - 1)
                count = count + 1
                if count >= LIMIT then break end
            end
        end
    end)
    return result
end
local function Flatten(value)
    if type(value) ~= "table" then return tostring(Scalar(value)) end
    local keys, parts = {}, {}
    for key in pairs(value) do keys[#keys + 1] = key end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    for _, key in ipairs(keys) do parts[#parts + 1] = tostring(key) .. "=" .. Flatten(value[key]) end
    return "{" .. table.concat(parts, ",") .. "}"
end

function Probe:Snapshot()
    local snapshot = {
        style = CurrentStyle(), cvar = GetCVarValue(), combat = Bool(Invoke(InCombatLockdown)),
        usingGamepad = Bool(Invoke(IsUsingGamepad)), usingMouse = Bool(Invoke(IsUsingMouse)),
        gamepadEnabled = Bool(Invoke(Field(C_GamePad, "IsEnabled"))),
        activeDeviceID = Scalar(Invoke(Field(C_GamePad, "GetActiveDeviceID"))),
        gamePadReadySetLoaded = Bool(Invoke(Field(C_AddOns, "IsAddOnLoaded") or IsAddOnLoaded, "GamePadReadySet")),
        shift = Bool(Invoke(IsShiftKeyDown)), control = Bool(Invoke(IsControlKeyDown)), alt = Bool(Invoke(IsAltKeyDown)),
        enumMkb = EnumStyle("Mkb"), enumGamepad = EnumStyle("Gamepad"),
        devices = UNKNOWN, deviceCount = UNKNOWN
    }
    local devices = Table(Invoke(Field(C_GamePad, "GetAllDeviceIDs")))
    local deviceCount = devices and Scalar(Invoke(function() return #devices end)) or UNKNOWN
    if type(deviceCount) == "number" and deviceCount >= 0 and deviceCount % 1 == 0 then
        snapshot.devices = {}
        snapshot.deviceCount, snapshot.devicesTruncated = deviceCount, deviceCount > 32
        for index = 1, math.min(deviceCount, 32) do
            local id = Scalar(Field(devices, index))
            local row = { id = id, rawState = UNKNOWN, mappedButtons = UNKNOWN, maxStick = UNKNOWN }
            if type(id) == "number" then
                if Table(Invoke(Field(C_GamePad, "GetDeviceRawState"), id)) then row.rawState = "available" end
                local mapped = Table(Invoke(Field(C_GamePad, "GetDeviceMappedState"), id))
                local count, buttons = Scalar(Field(mapped, "buttonCount")), Table(Field(mapped, "buttons"))
                if type(count) == "number" and count >= 0 and count <= 64 and count % 1 == 0 and buttons then
                    row.mappedButtons = 0
                    for i = 1, count do
                        local pressed = Bool(Field(buttons, i))
                        if pressed == UNKNOWN then row.mappedButtons = UNKNOWN; break end
                        if pressed then row.mappedButtons = row.mappedButtons + 1 end
                    end
                end
                local sticks, stickCount = Table(Field(mapped, "sticks")), Scalar(Field(mapped, "stickCount"))
                if sticks and type(stickCount) == "number" and stickCount >= 0 and stickCount <= 8 and stickCount % 1 == 0 then
                    row.maxStick = 0
                    for i = 1, stickCount do
                        local magnitude = Scalar(Field(Field(sticks, i), "len"))
                        if type(magnitude) ~= "number" or magnitude < 0 then row.maxStick = UNKNOWN; break end
                        row.maxStick = math.max(row.maxStick, math.floor(magnitude * 100) / 100)
                    end
                end
            end
            snapshot.devices[#snapshot.devices + 1] = row
        end
    end
    return snapshot
end
function Probe:Record(event, details, snapshot)
    if not self.db then return end
    local records = self.db.records
    records[#records + 1] = { event = Scalar(event), session = self.db.session, time = Now(),
        details = details and Copy(details, 3) or {}, snapshot = snapshot or self:Snapshot() }
    if #records > LIMIT then table.remove(records, 1); self.db.droppedRecords = self.db.droppedRecords + 1 end
end
function Probe:CancelTimer()
    self.generation = (self.generation or 0) + 1
    if self.timer then
        -- WoW timer handles may be userdata rather than ordinary Lua tables.
        pcall(function() self.timer:Cancel() end)
        self.timer = nil
    end
    if self.inFlight and self.db and self.db.pending and not self.db.pending.attempted then
        self.db.pending.status = "cancelled"
        self.db.lastRequest = self.db.pending
        self:Record("TEST_CANCELLED", self.db.pending)
        self.db.pending, self.inFlight = nil, false
    end
end
function Probe:Initialize()
    if self.db then self:CancelTimer(); return true end
    local old = Copy(AzeriteUI_InputProbeDB, 7)
    if type(old) ~= "table" or old.schema ~= 1 then old = {} end
    local serial = Scalar(old.session)
    local records = type(old.records) == "table" and old.records or {}
    local kept = {}
    for i = math.max(1, #records - LIMIT + 1), #records do
        if type(records[i]) == "table" then kept[#kept + 1] = records[i] end
    end
    self.db = { schema = 1, session = type(serial) == "number" and math.floor(serial) + 1 or 1,
        records = kept, droppedRecords = type(old.droppedRecords) == "number" and old.droppedRecords or 0,
        pending = type(old.pending) == "table" and old.pending or nil,
        lastRequest = type(old.lastRequest) == "table" and old.lastRequest or nil }
    AzeriteUI_InputProbeDB = self.db
    self.collecting, self.inFlight, self.generation = false, false, 0
    self.db.sessionInfo = { session = self.db.session, version = Scalar(Invoke(GetBuildInfo)), time = Now(),
        events = Copy(self.eventSupport, 1) }
    if type(GetBuildInfo) == "function" then
        local ok, _, build, date, toc = pcall(GetBuildInfo)
        if ok then self.db.sessionInfo.build, self.db.sessionInfo.date, self.db.sessionInfo.toc = Scalar(build), Scalar(date), Scalar(toc) end
    end
    local pending = self.db.pending
    if pending then
        local actual = CurrentStyle()
        pending.afterStyle = actual
        pending.status = not pending.attempted and "recovered-cancelled"
            or (not IsTarget(actual) and "recovered-unknown" or (actual == pending.target and "recovered-match" or "recovered-mismatch"))
        self.db.lastRequest, self.db.pending = pending, nil
        self:Record("TEST_RECOVERED", pending)
    end
    self:Record("SESSION_START", self.db.sessionInfo)
    self:BuildUI()
    return true
end
function Probe:Start()
    if not self.db then self:Initialize() end
    if self.collecting then return true end
    self.collecting, self.lastSample, self.lastSignature = true, nil, nil
    self:Record("COLLECTION_START")
    self:RefreshUI()
    return true
end
function Probe:Stop()
    self:CancelTimer()
    if self.collecting then self:Record("COLLECTION_STOP") end
    self.collecting = false
    self:RefreshUI()
end
function Probe:Sample()
    if not self.collecting then return end
    local snapshot, time = self:Snapshot(), Now()
    local signature = Flatten(snapshot)
    if not self.lastSample or (time - self.lastSample >= 1 and signature ~= self.lastSignature) or time - self.lastSample >= 5 then
        self.lastSample, self.lastSignature = time, signature
        self:Record("SAMPLE", nil, snapshot)
        self:RefreshUI()
    end
end
function Probe:SelectTarget(style)
    self:CancelTimer()
    style = Scalar(style)
    if not IsTarget(style) then self.target = nil; self:RefreshUI(); return false, "target" end
    self.target = style
    self:RefreshUI()
    return true
end
function Probe:CheckTest()
    if not IsTarget(self.target) then return false, "target" end
    local combat = Bool(Invoke(InCombatLockdown))
    if combat ~= false then return false, combat == true and "combat" or "unknown-combat" end
    local actual, cvar = CurrentStyle(), GetCVarValue()
    local setter = Field(C_CVar, "SetCVar") or SetCVar
    if type(setter) ~= "function" or cvar == UNKNOWN or cvar == "" then return false, "unavailable" end
    if not IsTarget(actual) then return false, "unknown-style" end
    return true, actual == self.target and "noop" or "ready", setter
end
function Probe:ApplyTest(request)
    local ok, reason, setter = self:CheckTest()
    if not ok or reason == "noop" then
        request.status = reason
        self.db.lastRequest, self.db.pending, self.inFlight = request, nil, false
        self:Record("TEST_SKIPPED", request)
        self:RefreshUI()
        return ok, reason
    end
    request.status, request.attempted = "pending", true
    self.db.pending, self.db.lastRequest = request, request
    -- Persist intent before the call: the transition can be synchronous or reload the UI.
    self:Record("TEST_WRITE", request)
    local called, result = pcall(setter, CVAR, request.target)
    request.setterCalled, request.setterResult = called, Scalar(result)
    request.afterStyle = CurrentStyle()
    request.status = request.afterStyle == request.target and "confirmed" or (called and "unconfirmed" or "error")
    self.inFlight = false
    -- Keep the receipt until next initialization or deliberate test. A native reload
    -- may happen during the synchronous event, inside the setter, or after it returns.
    self:Record("TEST_RESULT", request)
    self:RefreshUI()
    return called, request.status
end
function Probe:RequestTest(kind)
    if not self.db then self:Initialize() end
    kind = Scalar(kind)
    local function Reject(ok, reason)
        self.uiResult = reason
        self:Record("TEST_SKIPPED", { kind = kind, reason = reason })
        self:RefreshUI()
        return ok, reason
    end
    if kind ~= "click" and kind ~= "timer" then return Reject(false, "kind") end
    if self.inFlight then return Reject(false, "busy") end
    local ok, reason = self:CheckTest()
    if not ok or reason == "noop" then return Reject(ok, reason) end
    local request = { kind = kind, target = self.target, session = self.db.session, time = Now(), status = "scheduled", attempted = false }
    if kind == "timer" and type(Field(C_Timer, "NewTimer")) ~= "function" then return Reject(false, "unavailable") end
    self.uiResult = nil
    self.inFlight, self.db.pending, self.db.lastRequest = true, request, request
    self:Record("TEST_REQUEST", request)
    if kind == "click" then return self:ApplyTest(request) end
    local generation = self.generation
    self.timer = Invoke(Field(C_Timer, "NewTimer"), 1, function()
        if generation ~= self.generation then return end
        self.timer = nil
        self:ApplyTest(request)
    end)
    if not self.timer then
        request.status = "error"
        self.db.pending, self.inFlight = nil, false
        self:Record("TEST_RESULT", request)
        self:RefreshUI()
        return false, "error"
    end
    self:RefreshUI()
    return true, "scheduled"
end
function Probe:OnEvent(event, ...)
    event = Scalar(event)
    if event == "ADDON_LOADED" then
        if Scalar((...)) == addonName then self:Initialize() end
        return
    end
    if not self.db then return end
    local first, second = ...
    local details = {}
    local pendingTransition = self.db.pending and self.db.pending.status == "unconfirmed" and event == "INPUT_DEVICE_INTERFACE_TRANSITION"
    if event == "CVAR_UPDATE" then
        local name = Scalar(first)
        if type(name) ~= "string" or name:lower() ~= CVAR:lower() then return end
    end
    if event == "INPUT_DEVICE_INTERFACE_TRANSITION" then
        details.newMode, details.oldMode = Scalar(first), Scalar(second)
        local request = self.db.pending
        if request and request.attempted and CurrentStyle() == request.target then
            request.status, request.afterStyle = "confirmed", CurrentStyle()
            self.db.lastRequest = request
        end
    elseif event == "GAME_PAD_ACTIVE_CHANGED" then
        details.activeCandidate, details.physicalInputConfirmed = Bool(first), false
    elseif event == "GLOBAL_MOUSE_DOWN" or event == "GLOBAL_MOUSE_UP" or event == "MODIFIER_STATE_CHANGED" then
        details.physicalInputConfirmed = false -- Deliberately omit button/key names.
    elseif event == "ADDON_ACTION_BLOCKED" or event == "ADDON_ACTION_FORBIDDEN" then
        details.addon, details.action = Scalar(first), Scalar(second)
    end
    if self.collecting or self.inFlight or pendingTransition then self:Record(event, details) end
    self:RefreshUI()
end
function Probe:GetReport()
    if not self.db then return "Input Probe: not initialized" end
    local lines = { "Input Probe schema=1 session=" .. self.db.session .. " collecting=" .. tostring(self.collecting),
        "Dropped records=" .. self.db.droppedRecords .. "; unknown means unavailable, inaccessible or indeterminate.",
        "Input activity is not proof of physical input. No key/chat text is collected.",
        "Session=" .. Flatten(self.db.sessionInfo), "LastRequest=" .. Flatten(self.db.lastRequest), "Current=" .. Flatten(self:Snapshot()) }
    for _, record in ipairs(self.db.records) do lines[#lines + 1] = Flatten(record) end
    return table.concat(lines, "\n")
end

function Probe:RefreshUI()
    if not self.status then return end
    local target = IsTarget(self.target) and (self.target == EnumStyle("Gamepad") and "Gamepad" or "MnK") or "not selected"
    local current = CurrentStyle()
    current = IsTarget(current) and (current == EnumStyle("Gamepad") and "Gamepad" or "MnK") or UNKNOWN
    local result = Scalar(self.uiResult or Field(self.db and self.db.lastRequest, "status") or "none")
    self.status:SetText("Collect: " .. (self.collecting and "ON" or "OFF") .. "  Native: " .. current .. " (CVar " .. tostring(GetCVarValue()) .. ")"
        .. "  Target: " .. target .. "  Result: " .. tostring(result))
end
function Probe:BuildUI()
    if self.panel or type(CreateFrame) ~= "function" or not UIParent then return end
    local panel = CreateFrame("Frame", nil, UIParent)
    self.panel = panel
    panel:SetSize(650, 390); panel:SetPoint("CENTER"); panel:SetFrameStrata("DIALOG")
    panel:EnableMouse(true)
    local background = panel:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints(); background:SetColorTexture(0.04, 0.04, 0.06, 0.98)
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -14); title:SetText("AzeriteUI Input Probe - diagnostic only")
    local warning = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    warning:SetPoint("TOPLEFT", 16, -43); warning:SetWidth(618); warning:SetJustifyH("LEFT")
    warning:SetText("Each Test button explicitly requests ONE style write. It may reload the UI.\nOutside combat only. No automatic switching. Stop cancels a pending timer.")
    self.status = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    self.status:SetPoint("TOPLEFT", 16, -79); self.status:SetWidth(618); self.status:SetHeight(32); self.status:SetJustifyH("LEFT")
    local function Button(parent, label, x, y, width, callback)
        local button = CreateFrame("Button", nil, parent)
        button:SetSize(width, 26); button:SetPoint("TOPLEFT", x, y)
        local bg = button:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(); bg:SetColorTexture(0.17, 0.22, 0.3, 1)
        local text = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        text:SetAllPoints(); text:SetText(label)
        button:SetScript("OnClick", callback)
        return button
    end
    Button(panel, "Start", 16, -117, 72, function() self:Start() end)
    Button(panel, "Stop", 96, -117, 72, function() self:Stop() end)
    Button(panel, "Select MnK", 176, -117, 104, function() self:SelectTarget(EnumStyle("Mkb")) end)
    Button(panel, "Select Gamepad", 288, -117, 130, function() self:SelectTarget(EnumStyle("Gamepad")) end)
    Button(panel, "Test click", 426, -117, 96, function() self:RequestTest("click") end)
    Button(panel, "Test timer", 530, -117, 104, function() self:RequestTest("timer") end)
    local scroll = CreateFrame("ScrollFrame", nil, panel)
    scroll:SetPoint("TOPLEFT", 16, -184); scroll:SetSize(618, 190)
    local edit = CreateFrame("EditBox", nil, scroll)
    edit:SetMultiLine(true); edit:SetAutoFocus(false); edit:SetFontObject("GameFontHighlightSmall")
    edit:SetWidth(600); edit:SetHeight(190); edit:SetMaxLetters(0); scroll:SetScrollChild(edit)
    edit:SetScript("OnEscapePressed", function(box) box:ClearFocus() end)
    edit:SetScript("OnCursorChanged", function(_, _, y, _, height)
        local offset = scroll:GetVerticalScroll()
        if -y < offset then scroll:SetVerticalScroll(-y)
        elseif -y + height > offset + 190 then scroll:SetVerticalScroll(-y + height - 190) end
    end)
    Button(panel, "Prepare report (click text, Ctrl+A/C)", 16, -150, 310, function() edit:SetText(self:GetReport()); edit:ClearFocus() end)
    local reopen = Button(UIParent, "Input Probe", 20, -180, 100, function() panel:Show() end)
    Button(panel, "Close", 542, -150, 92, function() panel:Hide() end)
    reopen:SetFrameStrata("DIALOG")
    self:RefreshUI()
end

if type(CreateFrame) == "function" then
    local frame = CreateFrame("Frame")
    Probe.eventFrame = frame
    local events = { "ADDON_LOADED", "PLAYER_ENTERING_WORLD", "GAME_PAD_CONNECTED", "GAME_PAD_DISCONNECTED", "GAME_PAD_CONFIGS_CHANGED",
        "GAME_PAD_ACTIVE_CHANGED", "INPUT_DEVICE_INTERFACE_TRANSITION", "CVAR_UPDATE", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
        "ADDON_ACTION_BLOCKED", "ADDON_ACTION_FORBIDDEN", "GLOBAL_MOUSE_DOWN", "GLOBAL_MOUSE_UP", "MODIFIER_STATE_CHANGED" }
    for _, event in ipairs(events) do
        local ok, registered = pcall(frame.RegisterEvent, frame, event)
        Probe.eventSupport[event] = ok and Scalar(registered) ~= false
    end
    frame:SetScript("OnEvent", function(_, event, ...) Probe:OnEvent(event, ...) end)
    local elapsed = 0
    frame:SetScript("OnUpdate", function(_, delta)
        if not Probe.collecting then return end
        delta = Scalar(delta)
        if type(delta) ~= "number" then return end
        elapsed = elapsed + delta
        if elapsed >= 0.1 then elapsed = 0; Probe:Sample() end
    end)
end

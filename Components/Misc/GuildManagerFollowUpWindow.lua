-- MIT License. Copyright (c) 2026 Jonas "JuNNeZ" Andersen.
local Addon, ns = ...
local Guild = ns:GetModule("GuildManager")
local L = LibStub("AceLocale-3.0"):GetLocale(Addon)
local UI, ROWS = Guild.UI, 9
local FILTERS = { { "attention", "Needs attention" }, { "active", "Active follow-ups" }, { "all", "All" },
    { "trials", "Trials" }, { "absence", "Absence" }, { "tasks", "Tasks" } }
local DATES = { { "trialStart", "Trial start", 18, -74 }, { "trialEnd", "Trial review", 214, -74 },
    { "absenceStart", "Away from", 18, -132 }, { "absenceEnd", "Away until", 214, -132 } }

Guild.SelectFollowUpItem = function(self, item)
    local window = self.followUpWindow
    local store, key = self:GetFollowUpStore()
    window.root, window.personName, window.personLabel = item and item.root, item and item.name, item and item.label
    window.guildKey, window.revision = key, store and store.revision or 0
    window.taskId = item and item.task and item.task.id
    local person = item and self:GetFollowUpPerson(item.root) or {}
    person = person or {}
    window.title:SetText(item and item.label or L["Select a person"])
    window.character:SetText(item and item.name or "")
    for _, field in ipairs(DATES) do window[field[1]]:SetText(person[field[1]] or "") end
    window.absenceNote:SetText(person.absenceNote or "")
    local task = item and item.task
    window.taskTitle:SetText(task and task.title or ""); window.owner:SetText(task and task.owner or "")
    window.due:SetText(task and task.due or ""); window.feedback:SetText("")
    self:RefreshFollowUp()
end

Guild.FinishFollowUpEdit = function(self, ok, scope)
    local window = self.followUpWindow
    if (ok) then
        local draft = {}
        if (scope == "task") then
            for _, field in ipairs(DATES) do draft[field[1]] = window[field[1]]:GetText() end
            draft.absenceNote = window.absenceNote:GetText()
        elseif (scope == "schedule") then
            draft.taskId = window.taskId
            for _, field in ipairs({ "taskTitle", "owner", "due" }) do draft[field] = window[field]:GetText() end
        end
        self:SelectFollowUpItem(window.root and { root = window.root, name = window.personName, label = window.personLabel })
        for field, value in pairs(draft) do if (field ~= "taskId") then window[field]:SetText(value) end end
        if (scope == "schedule") then window.taskId = draft.taskId end
        self:RefreshFollowUp()
    end
    window.feedback:SetText(ok and L["Saved locally. Undo is available."] or L[self.followUpError or "Select a person first."])
end

Guild.RefreshFollowUp = function(self)
    local window = self.followUpWindow
    if (not window or not window:IsShown() or self.buildingFollowUp) then return end
    local store, key = self:GetFollowUpStore()
    if (window.guildKey ~= key) then self:SelectFollowUpItem(nil); return end
    local filter = FILTERS[window.filterIndex]
    local items, attention = self:GetFollowUpItems(window.search:GetText(), filter[1])
    window.offset = math.max(0, math.min(window.offset or 0, math.max(0, #items-ROWS)))
    window.filter.label:SetText(L[filter[2]])
    window.summary:SetText(string.format(L["%d require attention / %d rows shown"], attention, #items))
    if (self.activePage == "followup") then self.pageSummary:SetText(window.summary:GetText()) end
    window.empty:SetText(not key and L["Join a guild to use officer follow-up."] or #items == 0 and L["No matches. Choose All to select a person and add a follow-up."] or "")
    local ready = key and window.root ~= nil or false
    if (window.personName) then
        window.personLabel = self:Resolve(window.personName) or window.personName
        window.title:SetText(window.personLabel)
    end
    window.saveSchedule:SetEnabled(ready); window.saveTask:SetEnabled(ready); window.newTask:SetEnabled(ready)
    window.clear:SetEnabled(ready)
    local task
    local person = ready and self:GetFollowUpPerson(window.root)
    for _, value in ipairs(person and person.tasks or {}) do if (value.id == window.taskId) then task = value; break end end
    window.toggleTask:SetEnabled(task ~= nil); window.removeTask:SetEnabled(task ~= nil)
    window.toggleTask.label:SetText(task and task.done and L["Reopen task"] or L["Mark task done"])
    window.saveTask.label:SetText(window.taskId and L["Save task"] or L["Add task"])
    local undo = key and self.followUpUndo and self.followUpUndo[key]
    window.undo:SetEnabled(undo and #undo > 0 or false)
    window.previous:SetEnabled(window.offset > 0); window.next:SetEnabled(window.offset+ROWS < #items)
    for index, row in ipairs(window.rows) do
        local item = items[window.offset+index]
        row.item = item; row:SetShown(item ~= nil)
        if (item) then
            row.name:SetText(item.label .. "  |  " .. L[item.status], true)
            row.detail:SetText((item.due and item.due .. "  |  " or "") .. item.text, true)
            row.background:SetColorTexture(item.attention and .8 or .4, .45, .12, item.attention and .16 or .04)
        end
    end
end

Guild.OpenFollowUp = function(self)
    if (not self.followUpWindow) then
        self.buildingFollowUp = true
        local window = UI.Page(ns.Prefix .. "GuildFollowUp", "followup", L["Officer follow-up"], 1120, 727, 131)
        self.followUpWindow = window
        window.filterIndex = 1
        UI.Label(window, L["Officer follow-up"], 24, -25, 820, 22)
        window.summary = UI.Label(window, "", 24, -62, 790, 13)
        window.search = UI.Input(window, L["Search people, tasks and owners"], 24, -131, 310)
        window.search:SetScript("OnTextChanged", function() window.offset = 0; self:RefreshFollowUp() end)
        window.filter = UI.QuietButton(window, "", 346, -150, 160, function()
            window.filterIndex = window.filterIndex%#FILTERS+1; window.offset = 0; self:RefreshFollowUp()
        end)
        UI.QuietButton(window, L["Refresh"], 520, -150, 136, function() self:RequestRoster(); self:RefreshFollowUp() end)
        window.rows = {}
        for index = 1, ROWS do
            local row = CreateFrame("Button", nil, window)
            row:SetPoint("TOPLEFT", 24, -210-(index-1)*50); row:SetSize(632, 46)
            row.background = row:CreateTexture(nil, "BACKGROUND"); row.background:SetAllPoints()
            row.name = UI.Label(row, "", 8, -5, 616, 12)
            row.detail = UI.Label(row, "", 8, -24, 616, 11)
            row:SetScript("OnClick", function() if (row.item) then self:SelectFollowUpItem(row.item) end end)
            window.rows[index] = row
        end
        window.empty = UI.Label(window, "", 24, -210, 632, 13, 3)
        window.previous = UI.QuietButton(window, "<", 24, -696, 32, function() window.offset = (window.offset or 0)-ROWS; self:RefreshFollowUp() end)
        window.next = UI.QuietButton(window, ">", 66, -696, 32, function() window.offset = (window.offset or 0)+ROWS; self:RefreshFollowUp() end)
        UI.Label(window, L["Local to your account. Owner names are labels; no messages are sent."], 120, -704, 536, 11, 2)
        local card = CreateFrame("Frame", nil, window, ns.BackdropTemplate)
        card:SetPoint("TOPLEFT", 682, -131); card:SetSize(414, 596)
        card:SetBackdrop((ns.OptionsKit.Look and ns.OptionsKit.Look.InsetBackdrop or ns.OptionsKit.InsetBackdrop)); card:SetBackdropColor(.03, .033, .038, 1)
        card:SetBackdropBorderColor(.52, .43, .29, 1); UI.Opaque(card)
        UI.Rule(card, 18, -64, 376); UI.Rule(card, 18, -276, 248)
        window.title = UI.Label(card, L["Select a person"], 18, -18, 376, 17)
        window.character = UI.Label(card, "", 18, -43, 376, 11)
        for _, field in ipairs(DATES) do window[field[1]] = UI.Input(card, L[field[2]], field[3], field[4], 180, 28, 10) end
        window.absenceNote = UI.Input(card, L["Absence note (local)"], 18, -190, 376, 28, 160)
        window.saveSchedule = UI.QuietButton(card, L["Save dates"], 18, -248, 180, function()
            local values = { absenceNote = window.absenceNote:GetText() }
            for _, field in ipairs(DATES) do values[field[1]] = window[field[1]]:GetText() end
            self:FinishFollowUpEdit(self:SaveFollowUpSchedule(window.root, window.personName, values, window.guildKey, window.revision), "schedule")
        end, true)
        window.clear = UI.QuietButton(card, L["Clear dates"], 214, -248, 180, function()
            for _, field in ipairs(DATES) do window[field[1]]:SetText("") end
            window.absenceNote:SetText(""); window.feedback:SetText(L["Dates cleared in editor. Save dates to apply."])
        end)
        UI.Label(card, L["Tasks"], 18, -286, 230, 15)
        window.newTask = UI.QuietButton(card, L["New task"], 280, -278, 114, function()
            window.taskId = nil; window.taskTitle:SetText(""); window.owner:SetText(""); window.due:SetText(""); self:RefreshFollowUp()
        end)
        window.taskTitle = UI.Input(card, L["Task"], 18, -306, 376, 28, 160)
        window.owner = UI.Input(card, L["Owner (optional)"], 18, -364, 180, 28, 80)
        window.due = UI.Input(card, L["Deadline (optional)"], 214, -364, 180, 28, 10)
        window.saveTask = UI.QuietButton(card, L["Add task"], 18, -422, 180, function()
            self:FinishFollowUpEdit(self:SaveFollowUpTask(window.root, window.personName, window.taskTitle:GetText(),
                window.owner:GetText(), window.due:GetText(), window.guildKey, window.revision, window.taskId), "task")
        end, true)
        window.toggleTask = UI.QuietButton(card, L["Mark task done"], 214, -422, 180, function()
            self:FinishFollowUpEdit(self:ChangeFollowUpTask(window.root, window.taskId, false, window.guildKey, window.revision), "task")
        end)
        window.removeTask = UI.QuietButton(card, L["Remove task"], 18, -464, 180, function()
            self:FinishFollowUpEdit(self:ChangeFollowUpTask(window.root, window.taskId, true, window.guildKey, window.revision), "task")
        end)
        window.undo = UI.QuietButton(card, L["Undo follow-up"], 214, -464, 180, function() self:FinishFollowUpEdit(self:UndoFollowUp()) end)
        window.feedback = UI.Label(card, "", 18, -510, 376, 11, 3)
        UI.Label(card, L["Dates: YYYY-MM-DD. Fill both dates of a period; clear both to remove it."], 18, -565, 376, 11, 2)
        window:SetScript("OnHide", function()
            for _, name in ipairs({ "search", "trialStart", "trialEnd", "absenceStart", "absenceEnd", "absenceNote", "taskTitle", "owner", "due" }) do window[name]:ClearFocus() end
        end)
        self.buildingFollowUp = nil
    end
    local window = self.followUpWindow
    UI.Show(window)
    local _, guildKey = self:GetFollowUpStore()
    if (window.loaded and window.root == self.selectedRoot and window.guildKey == guildKey) then
        self:RefreshFollowUp(); return
    end
    local selected
    for _, item in ipairs(self:GetFollowUpItems("", "all")) do
        if (item.root == self.selectedRoot and not item.task) then selected = item; break end
        if (item.root == self.selectedRoot) then selected = { root = item.root, name = item.name, label = item.label } end
    end
    self:SelectFollowUpItem(selected)
    window.loaded = true
end

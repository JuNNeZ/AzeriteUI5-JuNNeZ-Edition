-- MIT License. Copyright (c) 2026 Jonas "JuNNeZ" Andersen.
local _, ns = ...
local Guild = ns:GetModule("GuildManager")
local FIELDS = { "name", "trialStart", "trialEnd", "absenceStart", "absenceEnd", "absenceNote", "updated" }
local function Fail(self, message) self.followUpError = message; return false end

Guild.IsFollowUpDate = function(self, value)
    value = self.ReadText(value)
    if (not value) then return false end
    if (value == "") then return true end
    local year, month, day = value:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)$")
    year, month, day = tonumber(year), tonumber(month), tonumber(day)
    if (not year or year < 1900 or year > 2199 or month < 1 or month > 12) then return false end
    local days = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
    if (year%4 == 0 and (year%100 ~= 0 or year%400 == 0)) then days[2] = 29 end
    return day >= 1 and day <= days[month]
end

local function Plain(self, value, limit)
    value = self.ReadText(value)
    if (not value or #value > limit or value:find("[|%c]")) then return end
    return value:match("^%s*(.-)%s*$")
end
local function Copy(person)
    local copy = { tasks = {} }
    for _, field in ipairs(FIELDS) do copy[field] = person and person[field] end
    for i, task in ipairs(person and person.tasks or {}) do
        copy.tasks[i] = { id = task.id, title = task.title, owner = task.owner, due = task.due,
            done = task.done, completed = task.completed }
    end
    return copy
end

Guild.GetFollowUpStore = function(self)
    local _, key = self:GetGuildHistory()
    return key and self.db.global.followUps and self.db.global.followUps[key], key
end
Guild.GetFollowUpPerson = function(self, root)
    local store = self:GetFollowUpStore()
    return store and store.people[root]
end

Guild.CommitFollowUp = function(self, root, person, guildKey, expectedRevision, nextTaskId)
    local store, currentGuild = self:GetFollowUpStore()
    root = self.ReadText(root)
    if (not root or self:CharacterKey(root) ~= root or self:CharacterKey(person.name) ~= root) then
        return Fail(self, "Select a person first.")
    end
    if (not currentGuild or guildKey ~= currentGuild or (store and store.revision or 0) ~= expectedRevision) then
        return Fail(self, "Guild or follow-up changed. Select the person again.")
    end
    local hasContent = person.trialStart or person.absenceStart or #person.tasks > 0
    if (not store and not hasContent) then self.followUpError = nil; return true end
    local stores = self.db.global.followUps or {}
    if (not store) then
        local count = 0; for _ in pairs(stores) do count = count+1 end
        if (count >= 10) then return Fail(self, "Local follow-up storage is full.") end
        store = { people = {}, revision = 0, nextTaskId = 0 }
    end
    if (not store.people[root] and hasContent) then
        local count = 0; for _ in pairs(store.people) do count = count+1 end
        if (count >= 500) then return Fail(self, "Local follow-up storage is full.") end
    end
    self.followUpUndo = self.followUpUndo or {}
    local undo = self.followUpUndo[guildKey] or {}
    self.followUpUndo[guildKey] = undo
    undo[#undo+1] = { root = root, previous = store.people[root] and Copy(store.people[root]) }
    if (#undo > 20) then table.remove(undo, 1) end
    person.updated = time()
    store.people[root] = hasContent and person or nil
    store.revision = store.revision+1
    if (nextTaskId) then store.nextTaskId = nextTaskId end
    undo[#undo].revision = store.revision
    stores[guildKey] = store; self.db.global.followUps = stores
    self.followUpError = nil
    return true
end

Guild.SaveFollowUpSchedule = function(self, root, name, values, guildKey, revision)
    if (type(values) ~= "table") then return Fail(self, "Enter valid YYYY-MM-DD dates.") end
    local person = Copy(self:GetFollowUpPerson(root))
    person.name = name
    for _, field in ipairs({ "trialStart", "trialEnd", "absenceStart", "absenceEnd" }) do
        local value = values[field]
        if (not self:IsFollowUpDate(value)) then return Fail(self, "Enter valid YYYY-MM-DD dates.") end
        person[field] = value ~= "" and value or nil
    end
    for _, prefix in ipairs({ "trial", "absence" }) do
        local first, last = person[prefix .. "Start"], person[prefix .. "End"]
        if ((first ~= nil) ~= (last ~= nil) or first and last < first) then
            return Fail(self, "Fill both period dates; the end must be on or after the start.")
        end
    end
    local note = Plain(self, values.absenceNote, 160)
    if (not note) then return Fail(self, "Enter a plain absence note.") end
    if (note ~= "" and not person.absenceStart) then return Fail(self, "Enter absence dates before adding an absence note.") end
    person.absenceNote = note ~= "" and note or nil
    return self:CommitFollowUp(root, person, guildKey, revision)
end

Guild.SaveFollowUpTask = function(self, root, name, title, owner, due, guildKey, revision, taskId)
    title, owner = Plain(self, title, 160), Plain(self, owner, 80)
    if (not title or title == "" or not owner) then return Fail(self, "Enter a task title and a plain text owner.") end
    if (not self:IsFollowUpDate(due)) then return Fail(self, "Enter valid YYYY-MM-DD dates.") end
    local store = self:GetFollowUpStore()
    local person = Copy(self:GetFollowUpPerson(root))
    if (taskId) then
        for _, task in ipairs(person.tasks) do
            if (task.id == taskId) then
                task.title, task.owner, task.due = title, owner, due ~= "" and due or nil
                return self:CommitFollowUp(root, person, guildKey, revision)
            end
        end
        return Fail(self, "Task changed. Select it again.")
    end
    if (#person.tasks >= 20) then return Fail(self, "A person can have 20 tasks. Remove an old task first.") end
    local id = (store and store.nextTaskId or 0)+1
    person.name = name
    person.tasks[#person.tasks+1] = { id = id, title = title, owner = owner, due = due ~= "" and due or nil, done = false }
    return self:CommitFollowUp(root, person, guildKey, revision, id)
end

Guild.ChangeFollowUpTask = function(self, root, id, remove, guildKey, revision)
    local source = self:GetFollowUpPerson(root)
    if (not source) then return Fail(self, "Task changed. Select it again.") end
    local person = Copy(source)
    for index, task in ipairs(person.tasks) do
        if (task.id == id) then
            if (remove) then table.remove(person.tasks, index)
            else task.done = not task.done; task.completed = task.done and date("%Y-%m-%d") or nil end
            return self:CommitFollowUp(root, person, guildKey, revision)
        end
    end
    return Fail(self, "Task changed. Select it again.")
end

Guild.UndoFollowUp = function(self)
    local store, key = self:GetFollowUpStore()
    local undo = key and self.followUpUndo and self.followUpUndo[key]
    local entry = undo and undo[#undo]
    if (not entry or not store or entry.revision ~= store.revision) then return Fail(self, "No local follow-up changes to undo.") end
    store.people[entry.root] = entry.previous
    store.revision = store.revision+1
    table.remove(undo)
    if (undo[#undo]) then undo[#undo].revision = store.revision end
    self.followUpError = nil
    return true
end

Guild.GetFollowUpItems = function(self, search, filter, guildPeople)
    local store, key = self:GetFollowUpStore()
    if (not key) then return {}, 0 end
    local people, items, attention = {}, {}, 0
    local today = date("%Y-%m-%d")
    search = string.lower(search or "")
    for _, person in ipairs(guildPeople or self:GetPeople("", { inGuild = true })) do
        people[person.key] = { name = person.name, label = person.label }
    end
    for root, person in pairs(store and store.people or {}) do
        people[root] = people[root] or { name = person.name, label = person.name }
    end
    local function Add(item, active, needsAttention, category, text)
        if (needsAttention) then attention = attention+1 end
        local show = filter == "all" or filter == category or filter == "active" and active
            or filter == "attention" and needsAttention
        if (show and (search == "" or string.lower(item.label .. " " .. item.name .. " " .. text):find(search, 1, true))) then
            item.attention = needsAttention; items[#items+1] = item
        end
    end
    for root, identity in pairs(people) do
        local person = store and store.people[root] or {}
        local function Item(kind, status, due, text, task)
            return { root = root, name = identity.name, label = identity.label, kind = kind,
                status = status, due = due, text = text or "", task = task }
        end
        local scheduled = false
        if (person.trialStart) then
            scheduled = true
            local status = today >= person.trialEnd and "Review trial" or today < person.trialStart and "Planned trial" or "Trial in progress"
            Add(Item("trial", status, person.trialEnd, person.trialStart .. " -> " .. person.trialEnd), true,
                status == "Review trial", "trials", "trial " .. person.trialStart .. " " .. person.trialEnd)
        end
        if (person.absenceStart) then
            scheduled = true
            local status = today > person.absenceEnd and "Confirm return" or today < person.absenceStart and "Planned absence" or "Away"
            Add(Item("absence", status, person.absenceEnd, person.absenceStart .. " -> " .. person.absenceEnd .. "  " .. (person.absenceNote or "")),
                true, status == "Confirm return", "absence", "absence " .. (person.absenceNote or ""))
        end
        for _, task in ipairs(person.tasks or {}) do
            scheduled = true
            local due = not task.done and task.due and task.due <= today or false
            Add(Item("task", task.done and "Completed task" or due and "Task due" or "Open task", task.due,
                task.title .. (task.owner ~= "" and "  /  " .. task.owner or ""), task), not task.done, due, "tasks", task.title .. " " .. task.owner)
        end
        if (not scheduled) then Add(Item("person", "No follow-up"), false, false, "people", "") end
    end
    table.sort(items, function(a, b)
        if (a.attention ~= b.attention) then return a.attention end
        if ((a.due or "9999") ~= (b.due or "9999")) then return (a.due or "9999") < (b.due or "9999") end
        if (a.root ~= b.root) then return a.root < b.root end
        if (a.kind ~= b.kind) then return a.kind < b.kind end
        return (a.task and a.task.id or 0) < (b.task and b.task.id or 0)
    end)
    return items, attention
end

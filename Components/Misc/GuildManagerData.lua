-- MIT License. Copyright (c) 2026 Jonas "JuNNeZ" Andersen.
local _, ns = ...
local Guild = ns:GetModule("GuildManager")
local MAX_RECORDS, MAX_BACKUP = 2000, 1500000
local BACKUP_PREFIX = "AZGUILD:1:"
local FIELDS = { "name", "nickname", "main", "favorite", "privateNote" }

Guild.CopyRecords = function(self, source)
    local copy = {}
    for key, record in pairs(source or self.db.global.characters) do
        copy[key] = {}
        for _, field in ipairs(FIELDS) do copy[key][field] = record[field] end
    end
    return copy
end

Guild.CommitRecords = function(self, records, reason)
    self.undoStack = self.undoStack or {}
    self.undoStack[#self.undoStack+1] = { records = self:CopyRecords(), reason = reason }
    if (#self.undoStack > 20) then table.remove(self.undoStack, 1) end
    self.db.global.characters = records
    self.identityRevision = (self.identityRevision or 0)+1
    self:UpdateSettings()
end

Guild.UndoIdentity = function(self)
    local entry = self.undoStack and table.remove(self.undoStack)
    if (not entry) then return false end
    self.db.global.characters = entry.records
    self.identityRevision = (self.identityRevision or 0)+1
    self:UpdateSettings()
    return true
end

Guild.SetPersonDetails = function(self, name, favorite, note)
    local _, root = self:Resolve(name)
    local member = (self.members or {})[root]
    if (not root or type(favorite) ~= "boolean" or not self.ReadText(note)
        or #note > 512 or note:find("[|%z\1-\8\11-\31]")) then return false end
    local records = self:CopyRecords()
    records[root] = records[root] or { name = member and member.name or root }
    records[root].favorite = favorite or nil
    records[root].privateNote = note ~= "" and note or nil
    self:CommitRecords(records, "details")
    return true
end

Guild.SavePersonCard = function(self, name, nickname, main, favorite, note)
    if (type(favorite) ~= "boolean" or not self.ReadText(note) or #note > 512
        or note:find("[|%z\1-\8\11-\31]")) then return false end
    local _, previousRoot = self:Resolve(name)
    local records = self:SaveIdentity(name, nickname, main, true)
    if (type(records) ~= "table") then return false end
    local root = self:CharacterKey(name)
    while (records[root] and records[root].main) do root = records[root].main end
    -- Linking an alt must not erase the destination person's existing notes.
    if (root == previousRoot) then
        records[root].favorite, records[root].privateNote = favorite or nil, note ~= "" and note or nil
    end
    self:CommitRecords(records, "card")
    return true
end

Guild.GetChatFormat = function(self, info)
    local kind = self.ReadText(info.type) or ""
    local event = self.ReadText(info.event) or ""
    if (kind == "" and event:sub(1, 9) == "CHAT_MSG_") then kind = event:sub(10) end
    local key = "otherFormat"
    if (kind == "GUILD" or kind == "OFFICER") then key = "guildFormat"
    elseif (kind:match("^PARTY") or kind:match("^RAID") or kind:match("^INSTANCE_CHAT")) then key = "groupFormat"
    elseif (kind:match("^WHISPER")) then key = "whisperFormat" end
    local mode = self.db.profile[key]
    return (mode == "both" or mode == "original") and mode or "nickname"
end

Guild.GetPeople = function(self, search, filters)
    filters, search = filters or {}, string.lower(search or "")
    local low, high = search:match("^%s*(%d+)%s*%-%s*(%d+)%s*$")
    low, high = tonumber(low), tonumber(high)
    local groups = {}
    for _, row in ipairs(self:GetRows("", true)) do
        local _, root = self:Resolve(row.member.name)
        root = root or row.key
        local record = self.db.global.characters[root] or {}
        local person = groups[root]
        if (not person) then
            local mainMember = (self.members or {})[root]
            local name = record.name or (mainMember and mainMember.name) or root
            local nickname = self.ReadText(record.nickname)
            person = { key = root, name = name, nickname = nickname, label = nickname or name:match("^([^-]+)"),
                favorite = record.favorite == true, privateNote = record.privateNote or "", rows = {}, online = 0 }
            groups[root] = person
        end
        person.rows[#person.rows+1] = row
        if (row.member.online) then person.online = person.online+1 end
        local lastOnline = row.member.lastOnline
        if (lastOnline and (not person.lastOnline or lastOnline.order < person.lastOnline.order)) then
            person.lastOnline = lastOnline
        end
    end
    local people = {}
    for _, person in pairs(groups) do
        local matches = search == "" or string.lower(person.label .. " " .. person.privateNote):find(search, 1, true)
        local classMatch, rankMatch, levelMatch = not filters.class, not filters.rank, not low
        local linked, inGuild = #person.rows > 1, false
        for _, row in ipairs(person.rows) do
            local member = row.member
            inGuild = inGuild or not member.saved
            local record = self.db.global.characters[row.key]
            linked = linked or (record and record.main ~= nil)
            local text = table.concat({ member.name, member.rank or "", member.note or "", member.zone or "", member.className or "" }, " ")
            matches = matches or string.lower(text):find(search, 1, true)
            classMatch = classMatch or member.class == filters.class
            rankMatch = rankMatch or member.rank == filters.rank
            levelMatch = levelMatch or member.level and member.level > 0 and member.level >= low and member.level <= high
        end
        if (low) then matches = levelMatch end
        if (matches and classMatch and rankMatch and (not filters.inGuild or inGuild) and (not filters.online or person.online > 0)
            and (not filters.favorite or person.favorite) and (not filters.missing or not person.nickname)
            and (not filters.unlinked or not linked)) then
            table.sort(person.rows, function(a, b)
                if ((a.key == person.key) ~= (b.key == person.key)) then return a.key == person.key end
                return a.key < b.key
            end)
            people[#people+1] = person
        end
    end
    table.sort(people, function(a, b)
        if (a.favorite ~= b.favorite) then return a.favorite end
        if ((a.online > 0) ~= (b.online > 0)) then return a.online > 0 end
        local aName, bName = string.lower(a.label), string.lower(b.label)
        return aName == bName and a.key < b.key or aName ~= bName and aName < bName
    end)
    return people
end

-- Unknown data always sorts last, in either direction. These are readable
-- roster snapshots, not live unit queries. Keep the existing default ordering.
Guild.GetMemberSortValue = function(self, member, field)
    if (field == "name") then return string.lower(member.name or "") end
    local value = field == "rank" and member.rankIndex or field == "level" and member.level
        or field == "lastOnline" and (member.online and -1 or member.lastOnline and member.lastOnline.order)
    if (issecretvalue and issecretvalue(value)) then return end
    if (type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge) then return end
    if (field == "level" and (value <= 0 or value%1 ~= 0)) then return end
    return value
end
local function Before(aValue, bValue, aKey, bKey, descending)
    if ((aValue == nil) ~= (bValue == nil)) then return aValue ~= nil end
    if (aValue ~= bValue) then
        if (descending) then return aValue > bValue end
        return aValue < bValue
    end
    return aKey < bKey
end
Guild.GetDisplayRows = function(self, search, filters, expanded, sort)
    local people, rows, online, characters = self:GetPeople(search, filters), {}, 0, 0
    local field = sort and sort.field
    if (field == "name" or field == "rank" or field == "level" or field == "lastOnline") then
        local function PersonValue(person)
            if (field == "name") then return string.lower(person.label) end
            if (field == "lastOnline") then
                return self:GetMemberSortValue({ online = person.online > 0, lastOnline = person.lastOnline }, field)
            end
            return self:GetMemberSortValue(person.rows[1].member, field)
        end
        table.sort(people, function(a, b)
            return Before(PersonValue(a), PersonValue(b), a.key, b.key, sort.descending)
        end)
        for _, person in ipairs(people) do
            table.sort(person.rows, function(a, b)
                if ((a.key == person.key) ~= (b.key == person.key)) then return a.key == person.key end
                return Before(self:GetMemberSortValue(a.member, field), self:GetMemberSortValue(b.member, field),
                    a.key, b.key, sort.descending)
            end)
        end
    end
    for _, person in ipairs(people) do
        rows[#rows+1] = { kind = "person", key = person.key, person = person }
        online, characters = online+person.online, characters+#person.rows
        if (expanded and expanded[person.key]) then
            for _, row in ipairs(person.rows) do
                rows[#rows+1] = { kind = "character", key = row.key, person = person, row = row }
            end
        end
    end
    return rows, #people, online, characters
end

Guild.GetFilterChoices = function(self, field)
    local values, seen = {}, {}
    for _, member in pairs(self.members or {}) do
        local value = member[field]
        if (value and value ~= "" and not seen[value]) then seen[value] = true; values[#values+1] = value end
    end
    table.sort(values)
    return values
end

local function Signature(self, members)
    local parts = {}
    for _, member in ipairs(members) do
        local record = self.db.global.characters[self:CharacterKey(member.name)] or {}
        local nickname, root = self:Resolve(member.name)
        parts[#parts+1] = table.concat({ member.name, member.note, record.main or "", record.nickname or "", nickname or "", root or "" }, "\30")
    end
    return table.concat(parts, "\31")
end

Guild.BuildNoteSuggestions = function(self)
    local grouped, proposals, skipped = {}, {}, 0
    for _, member in pairs(self.members or {}) do
        local nickname = self:NoteCandidate(member.note)
        if (nickname) then
            local id = string.lower(nickname)
            grouped[id] = grouped[id] or { id = id, nickname = nickname, members = {} }
            table.insert(grouped[id].members, member)
        elseif (member.note ~= "") then skipped = skipped+1 end
    end
    for _, proposal in pairs(grouped) do
        table.sort(proposal.members, function(a, b) return a.name < b.name end)
        local roots, rootCount = {}, 0
        proposal.targets = {}
        for _, member in ipairs(proposal.members) do
            local key = self:CharacterKey(member.name)
            proposal.targets[#proposal.targets+1] = key
            local nickname, root = self:Resolve(member.name)
            local record = self.db.global.characters[key]
            if (record and (record.main or record.nickname)) then
                if (not roots[root]) then roots[root] = true; rootCount = rootCount+1 end
                if (nickname and string.lower(nickname) ~= proposal.id) then proposal.conflict = true end
            end
            local suffix = member.note:match("^%s*[^%s,;:/%(%)%-]+(.*)$") or ""
            if (suffix ~= "" and not suffix:match("^%s*$") and not suffix:match("^%s*[-/(]")) then proposal.ambiguous = true end
        end
        if (rootCount > 1) then proposal.conflict = true end
        proposal.main = proposal.targets[1]
        if (rootCount == 1) then
            for root in pairs(roots) do
                proposal.main = root
                local found = false
                for _, target in ipairs(proposal.targets) do if (root == target) then found = true end end
                if (not found) then proposal.targets[#proposal.targets+1] = root end
            end
        end
        proposal.signature = Signature(self, proposal.members)
        proposals[#proposals+1] = proposal
    end
    table.sort(proposals, function(a, b) return a.id < b.id end)
    return proposals, skipped
end

Guild.ValidateRecords = function(self, input)
    if (type(input) ~= "table") then return end
    local clean, count = {}, 0
    for key, record in pairs(input) do
        count = count+1
        if (count > MAX_RECORDS or type(key) ~= "string" or type(record) ~= "table"
            or not self.ReadText(record.name) or self:CharacterKey(record.name) ~= key) then return end
        for field in pairs(record) do
            if (field ~= "name" and field ~= "nickname" and field ~= "main" and field ~= "favorite" and field ~= "privateNote") then return end
        end
        if (record.nickname ~= nil and (not self.ReadText(record.nickname) or #record.nickname == 0 or #record.nickname > 48 or record.nickname:find("[|%c]"))) then return end
        if (record.main ~= nil and (type(record.main) ~= "string" or self:CharacterKey(record.main) ~= record.main or record.main == key)) then return end
        if (record.favorite ~= nil and type(record.favorite) ~= "boolean") then return end
        if (record.privateNote ~= nil and (not self.ReadText(record.privateNote) or #record.privateNote > 512 or record.privateNote:find("[|%z\1-\8\11-\31]"))) then return end
        clean[key] = {}
        for _, field in ipairs(FIELDS) do clean[key][field] = record[field] end
    end
    for key in pairs(clean) do
        local seen, cursor = {}, key
        while (cursor) do
            if (seen[cursor]) then return end
            seen[cursor] = true
            cursor = clean[cursor] and clean[cursor].main
        end
    end
    return clean, count
end

Guild.ApplyNoteSuggestions = function(self, proposals, selected)
    local latest, live = self:BuildNoteSuggestions(), {}
    for _, proposal in ipairs(latest) do live[proposal.id] = proposal end
    local records, count, used = self:CopyRecords(), 0, {}
    for _, proposal in ipairs(proposals) do
        if (selected[proposal.id]) then
            local current = live[proposal.id]
            if (not current or current.signature ~= proposal.signature) then return false, "stale" end
            local allowed = false
            for _, target in ipairs(current.targets) do if (target == proposal.main) then allowed = true end end
            if (not allowed) then return false, "main" end
            if (used[proposal.main]) then return false, "overlap" end
            used[proposal.main] = true
            for _, member in ipairs(current.members) do
                local key = self:CharacterKey(member.name)
                if (key ~= proposal.main) then
                    if (used[key]) then return false, "overlap" end
                    used[key] = true
                end
            end
            local target = records[proposal.main] or (self.members or {})[proposal.main]
            if (not target) then return false, "main" end
            records[proposal.main] = records[proposal.main] or { name = target.name }
            records[proposal.main].main, records[proposal.main].nickname = nil, proposal.nickname
            for _, member in ipairs(current.members) do
                local key = self:CharacterKey(member.name)
                if (key ~= proposal.main) then
                    records[key] = records[key] or { name = member.name }
                    records[key].main, records[key].nickname = proposal.main, nil
                end
            end
            count = count+1
        end
    end
    local valid = self:ValidateRecords(records)
    if (not valid or count == 0) then return false, "empty" end
    self:CommitRecords(valid, "notes")
    return true, count
end

Guild.ExportIdentities = function(self, includePrivate)
    local records = self:CopyRecords()
    for key, record in pairs(records) do
        -- Old records may have been entered without an explicit realm.
        if (not record.name:find("-", 1, true)) then record.name = record.name .. "-" .. key:match("%-([^-]+)$") end
        if (not includePrivate) then record.privateNote = nil end
    end
    local valid = self:ValidateRecords(records)
    if (not valid) then return end
    local serialized = LibStub("AceSerializer-3.0"):Serialize({ format = "AzGuild", version = 1, characters = valid })
    if (#serialized > MAX_BACKUP) then return end
    return BACKUP_PREFIX .. serialized
end

Guild.DecodeIdentityBackup = function(self, text)
    if (not self.ReadText(text) or #text > MAX_BACKUP+#BACKUP_PREFIX or text:sub(1, #BACKUP_PREFIX) ~= BACKUP_PREFIX) then return end
    local serialized, depth, tables = text:sub(#BACKUP_PREFIX+1), 0, 0
    -- This schema has only envelope -> character map -> flat records. Reject
    -- deeply nested inputs before passing them to the recursive deserializer.
    for token in serialized:gmatch("%^([Tt])") do
        if (token == "T") then depth, tables = depth+1, tables+1 else depth = depth-1 end
        if (depth < 0 or depth > 3 or tables > MAX_RECORDS+2) then return end
    end
    if (depth ~= 0) then return end
    local ok, data = LibStub("AceSerializer-3.0"):Deserialize(serialized)
    if (not ok or type(data) ~= "table" or data.format ~= "AzGuild" or data.version ~= 1) then return end
    return self:ValidateRecords(data.characters)
end

Guild.PreviewIdentityImport = function(self, text)
    local incoming, count = self:DecodeIdentityBackup(text)
    if (not incoming) then return end
    local merged, conflicts, added = self:CopyRecords(), 0, 0
    for key, record in pairs(incoming) do
        local old = merged[key]
        if (old) then
            if (old.nickname ~= record.nickname or old.main ~= record.main or old.favorite ~= record.favorite
                or record.privateNote ~= nil and old.privateNote ~= record.privateNote) then conflicts = conflicts+1 end
            if (record.privateNote == nil) then record.privateNote = old.privateNote end
        else added = added+1 end
        merged[key] = record
    end
    local valid = self:ValidateRecords(merged)
    if (not valid) then return end
    return { records = valid, count = count, conflicts = conflicts, added = added, revision = self.identityRevision or 0 }
end

Guild.ImportIdentities = function(self, text, expectedRevision)
    if (expectedRevision and expectedRevision ~= (self.identityRevision or 0)) then return false end
    local preview = self:PreviewIdentityImport(text)
    if (not preview) then return false end
    self:CommitRecords(preview.records, "import")
    return true
end

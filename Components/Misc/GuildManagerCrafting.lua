-- MIT License. Copyright (c) 2026 Jonas "JuNNeZ" Andersen.
local _, ns = ...
local Guild = ns:GetModule("GuildManager")
local PREFIX, MAX_RECIPES, MAX_TEXT = "AZCRAFT:1:", 3000, 500000
local function Safe(value) return not (issecretvalue and issecretvalue(value)) end
local function Integer(value, max)
    return Safe(value) and type(value) == "number" and value >= 1 and value <= max and value == math.floor(value)
end
local function Plain(self, value, max)
    value = self.ReadText(value)
    return value and #value > 0 and #value <= max and not value:find("[|%c]") and value
end
local function Fields(input, allowed)
    if (not Safe(input) or type(input) ~= "table") then return false end
    for key in pairs(input) do if (not allowed[key]) then return false end end
    return true
end
local SNAPSHOT = { owner = true, guid = true, professionID = true, profession = true, scanned = true, recipes = true }
local RECIPE = { name = true, itemID = true, itemName = true }

Guild.ValidateCrafting = function(self, input)
    if (not Fields(input, SNAPSHOT) or not Plain(self, input.owner, 160) or self:CharacterKey(input.owner) ~= input.owner
        or not Plain(self, input.guid, 80) or not Integer(input.professionID, 1000000) or not Plain(self, input.profession, 96)
        or not Integer(input.scanned, time()+300) or not Safe(input.recipes) or type(input.recipes) ~= "table") then return end
    local clean = { owner = input.owner, guid = input.guid, professionID = input.professionID,
        profession = input.profession, scanned = input.scanned, recipes = {} }
    local count = 0
    for id, recipe in pairs(input.recipes) do
        count = count+1
        if (count > MAX_RECIPES or not Integer(id, 10000000) or not Fields(recipe, RECIPE) or not Plain(self, recipe.name, 192)
            or recipe.itemID ~= nil and not Integer(recipe.itemID, 10000000)
            or recipe.itemName ~= nil and not Plain(self, recipe.itemName, 192)) then return end
        clean.recipes[id] = { name = recipe.name, itemID = recipe.itemID, itemName = recipe.itemName }
    end
    if (count > 0) then return clean, count end
end

Guild.CraftingGuildKey = function(self)
    local name = IsInGuild() and self.ReadText(GetGuildInfo("player"))
    return name and name ~= "" and self.realm and (self.realm .. ":" .. name) or nil
end

Guild.LiveCraftingMember = function(self, key, guid)
    if (self.suspended or not self.db.profile.enabled or InCombatLockdown() or not self:CraftingGuildKey()) then return end
    local count = GetNumGuildMembers()
    if (not Integer(count, 2000)) then return end
    for index = 1, count do
        local name, _, _, _, _, _, _, _, online, _, _, _, _, _, _, _, id = GetGuildRosterInfo(index)
        if (self:CharacterKey(name) == key and self.ReadText(id) == guid) then
            return { name = name, guid = guid, online = Safe(online) and online == true }
        end
    end
end

Guild.StoreCrafting = function(self, snapshot, source)
    if (source ~= "own" and source ~= "import") then return false end
    local clean = self:ValidateCrafting(snapshot)
    if (not clean) then return false end
    local data, total, characters = self.db.global.crafting, 0, 0
    for owner, professions in pairs(data) do
        characters = characters+1
        for profession, saved in pairs(professions) do
            if (owner ~= clean.owner or profession ~= clean.professionID) then
                for _ in pairs(saved.snapshot.recipes) do total = total+1 end
            end
        end
    end
    if (not data[clean.owner] and characters >= 200) then return false end
    local professions, number = data[clean.owner] or {}, 0
    for _ in pairs(professions) do number = number+1 end
    if (not professions[clean.professionID] and number >= 10) then return false end
    for _ in pairs(clean.recipes) do total = total+1 end
    if (total > 50000) then return false end
    self.craftingUndo = self.craftingUndo or {}
    self.craftingUndo[#self.craftingUndo+1] = { owner = clean.owner, professionID = clean.professionID, previous = professions[clean.professionID] }
    if (#self.craftingUndo > 5) then table.remove(self.craftingUndo, 1) end
    professions[clean.professionID] = { snapshot = clean, source = source, received = time() }
    data[clean.owner] = professions
    self.craftingRevision = (self.craftingRevision or 0)+1
    return true
end

Guild.UndoCrafting = function(self)
    local entry = self.craftingUndo and table.remove(self.craftingUndo)
    if (not entry) then return false end
    local data = self.db.global.crafting
    data[entry.owner] = data[entry.owner] or {}
    data[entry.owner][entry.professionID] = entry.previous
    if (not next(data[entry.owner])) then data[entry.owner] = nil end
    self.craftingRevision = (self.craftingRevision or 0)+1
    return true
end

Guild.ScanOwnCrafting = function(self)
    if (self.suspended or not self.db.profile.enabled or InCombatLockdown()) then return false end
    local api = C_TradeSkillUI
    if (not api or not api.GetAllRecipeIDs or not api.GetRecipeInfo or not api.GetBaseProfessionInfo or not api.IsTradeSkillReady
        or not api.IsTradeSkillLinked or not api.IsTradeSkillGuild or not api.IsTradeSkillGuildMember) then return false end
    local ready, linked, guild, member = api.IsTradeSkillReady(), api.IsTradeSkillLinked(), api.IsTradeSkillGuild(), api.IsTradeSkillGuildMember()
    if (not Safe(ready) or ready ~= true or not Safe(linked) or linked ~= false
        or not Safe(guild) or guild ~= false or not Safe(member) or member ~= false) then return false end
    local profession, ids = api.GetBaseProfessionInfo(), api.GetAllRecipeIDs()
    if (not Safe(profession) or type(profession) ~= "table" or not Safe(ids) or type(ids) ~= "table" or #ids > 10000) then return false end
    local number = 0
    for index in pairs(ids) do
        if (not Integer(index, #ids)) then return false end
        number = number+1
    end
    if (number ~= #ids) then return false end
    local name, realm = UnitFullName("player")
    name, realm = self.ReadText(name), self.ReadText(realm)
    local owner = name and self:CharacterKey(name .. "-" .. (realm and realm ~= "" and realm or self.realm or ""))
    local snapshot = { owner = owner, guid = self.ReadText(UnitGUID("player")), professionID = profession.professionID,
        profession = profession.professionName, scanned = time(), recipes = {} }
    for _, id in ipairs(ids) do
        if (not Integer(id, 10000000)) then return false end
        local info = api.GetRecipeInfo(id)
        -- A partial cache must not erase a previously saved list.
        if (not Safe(info) or type(info) ~= "table" or not Safe(info.learned) or type(info.learned) ~= "boolean") then return false end
        if (info.learned) then
            local recipe = { name = info.name }
            local link = api.GetRecipeItemLink and self.ReadText(api.GetRecipeItemLink(id))
            if (link) then
                recipe.itemID = tonumber(link:match("|Hitem:(%d+)"))
                local label = link:match("|h%[(.-)%]|h")
                recipe.itemName = Plain(self, label, 192) or nil
            end
            snapshot.recipes[id] = recipe
        end
    end
    local clean = self:ValidateCrafting(snapshot)
    if (not clean) then return false end
    -- Recheck ownership/readiness before committing the completed scan.
    local final = api.GetBaseProfessionInfo()
    ready, linked, guild, member = api.IsTradeSkillReady(), api.IsTradeSkillLinked(), api.IsTradeSkillGuild(), api.IsTradeSkillGuildMember()
    if (not Safe(final) or type(final) ~= "table" or not Safe(final.professionID) or final.professionID ~= clean.professionID
        or self.ReadText(UnitGUID("player")) ~= clean.guid or not Safe(ready) or ready ~= true
        or not Safe(linked) or linked ~= false or not Safe(guild) or guild ~= false or not Safe(member) or member ~= false) then return false end
    return self:StoreCrafting(clean, "own")
end

Guild.CanExportCrafting = function(self, row)
    local saved = row and self.db.global.crafting[row.owner] and self.db.global.crafting[row.owner][row.professionID]
    return saved ~= nil and saved.source == "own" and saved.snapshot.guid == self.ReadText(UnitGUID("player"))
end

Guild.ExportCrafting = function(self, row)
    if (not self:CanExportCrafting(row)) then return end
    local saved = self.db.global.crafting[row.owner][row.professionID]
    local clean = self:ValidateCrafting(saved.snapshot)
    if (not clean) then return end
    local serialized = LibStub("AceSerializer-3.0"):Serialize(clean)
    if (#serialized <= MAX_TEXT) then return PREFIX .. serialized end
end

Guild.PreviewCraftingImport = function(self, text)
    text = self.ReadText(text)
    if (not text or #text > MAX_TEXT+#PREFIX or text:sub(1, #PREFIX) ~= PREFIX or InCombatLockdown()) then return end
    local depth, tables, serialized = 0, 0, text:sub(#PREFIX+1)
    for token in serialized:gmatch("%^([Tt])") do
        if (token == "T") then depth, tables = depth+1, tables+1 else depth = depth-1 end
        if (depth < 0 or depth > 3 or tables > MAX_RECIPES+2) then return end
    end
    if (depth ~= 0) then return end
    local ok, input = LibStub("AceSerializer-3.0"):Deserialize(serialized)
    if (not ok) then return end
    local snapshot, count = self:ValidateCrafting(input)
    if (not snapshot) then return end
    local member = self:LiveCraftingMember(snapshot.owner, snapshot.guid)
    if (not member) then return end
    local old = self.db.global.crafting[snapshot.owner] and self.db.global.crafting[snapshot.owner][snapshot.professionID]
    local added, removed, changed = 0, 0, 0
    for id, recipe in pairs(snapshot.recipes) do
        local previous = old and old.snapshot.recipes[id]
        if (not previous) then added = added+1
        elseif (previous.name ~= recipe.name or previous.itemID ~= recipe.itemID or previous.itemName ~= recipe.itemName) then changed = changed+1 end
    end
    if (old) then for id in pairs(old.snapshot.recipes) do if (not snapshot.recipes[id]) then removed = removed+1 end end end
    return { snapshot = snapshot, count = count, name = member.name, replacing = old ~= nil,
        added = added, removed = removed, changed = changed, text = text, guild = self:CraftingGuildKey(), revision = self.craftingRevision or 0 }
end

Guild.ImportCrafting = function(self, text, preview)
    if (not preview or text ~= preview.text or preview.revision ~= (self.craftingRevision or 0) or preview.guild ~= self:CraftingGuildKey()) then return false end
    local current = self:PreviewCraftingImport(text)
    if (not current or current.snapshot.owner ~= preview.snapshot.owner or current.snapshot.guid ~= preview.snapshot.guid
        or current.snapshot.professionID ~= preview.snapshot.professionID) then return false end
    return self:StoreCrafting(current.snapshot, "import")
end

Guild.GetCraftingRows = function(self, search, onlineOnly)
    local rows, found = {}, {}
    search = string.lower(search or "")
    local function Add(owner, snapshot, id, recipe, source, received)
        local member = (self.members or {})[owner]
        if (not member or member.guid ~= snapshot.guid or onlineOnly and not member.online) then return end
        local nickname = self:Resolve(member.name) or member.name
        local text = table.concat({ nickname, member.name, snapshot.profession, recipe.name, recipe.itemName or "",
            tostring(recipe.itemID or ""), tostring(id) }, " ")
        if (search ~= "" and not string.lower(text):find(search, 1, true)) then return end
        local identity = owner .. ":" .. snapshot.professionID .. ":" .. id
        if (found[identity]) then return end
        found[identity] = true
        rows[#rows+1] = { owner = owner, professionID = snapshot.professionID, snapshot = snapshot, id = id,
            recipe = recipe, source = source, received = received, member = member, nickname = nickname }
    end
    if (self.craftingResults and self.craftingResults.guild == self:CraftingGuildKey()) then
        for _, row in ipairs(self.craftingResults.rows) do Add(row.owner, row.snapshot, row.id, row.recipe, "blizzard", row.received) end
    end
    for owner, professions in pairs(self.db.global.crafting) do
        for _, saved in pairs(professions) do
            for id, recipe in pairs(saved.snapshot.recipes) do Add(owner, saved.snapshot, id, recipe, saved.source, saved.received) end
        end
    end
    table.sort(rows, function(a, b)
        if (a.member.online ~= b.member.online) then return a.member.online end
        if (a.recipe.name ~= b.recipe.name) then return a.recipe.name < b.recipe.name end
        if (a.owner ~= b.owner) then return a.owner < b.owner end
        return a.professionID < b.professionID or a.professionID == b.professionID and a.id < b.id
    end)
    return rows
end

Guild.CancelCraftingQuery = function(self)
    self.craftingPending, self.craftingResults = nil, nil
    self.craftingStatus = nil
end

Guild.CraftingStatus = function(self, message)
    self.craftingStatus = message
    if (self.RefreshCrafting) then self:RefreshCrafting() end
end

Guild.QueryCrafting = function(self, row)
    if (not row or self.craftingPending or self.suspended or not self.db.profile.enabled or InCombatLockdown()
        or not self:CraftingGuildKey() or not C_GuildInfo or not C_GuildInfo.QueryGuildMembersForRecipe
        or not GetGuildRecipeInfoPostQuery or not GetGuildRecipeMember) then return false end
    self:CancelCraftingQuery()
    local id = C_GuildInfo.QueryGuildMembersForRecipe(row.professionID, row.id)
    if (not Integer(id, 10000000)) then return false end
    local pending = { guild = self:CraftingGuildKey(), professionID = row.professionID, id = id,
        recipe = row.recipe, profession = row.snapshot.profession }
    self.craftingPending = pending
    C_Timer.After(15, function()
        if (self.craftingPending == pending) then
            self.craftingPending = nil
            self:CraftingStatus("No guild recipe response. Availability is unknown.")
        end
    end)
    return true
end

Guild.OnCraftingQuery = function(self)
    local pending = self.craftingPending
    if (not pending or self.suspended or not self.db.profile.enabled or InCombatLockdown() or pending.guild ~= self:CraftingGuildKey()) then return end
    local profession, id, count = GetGuildRecipeInfoPostQuery()
    if (not Integer(profession, 1000000) or not Integer(id, 10000000) or not Safe(count) or type(count) ~= "number"
        or count < 0 or count > 2000 or count ~= math.floor(count) or profession ~= pending.professionID or id ~= pending.id) then return end
    self.craftingPending = nil
    local rows = {}
    for index = 1, count do
        -- Signature follows Blizzard_ProfessionsGuildMemberList on both clients;
        -- the legacy API annotation still documents an older two-return shape.
        local _, name = GetGuildRecipeMember(index)
        local key = self:CharacterKey(name)
        local member = key and (self.members or {})[key]
        if (member and member.guid) then
            rows[#rows+1] = { owner = key, snapshot = { guid = member.guid, professionID = profession,
                profession = pending.profession, scanned = time() }, id = id, recipe = pending.recipe, received = time() }
        end
    end
    self.craftingResults = { guild = pending.guild, rows = rows }
    self:CraftingStatus(#rows > 0 and "Blizzard guild recipe response received."
        or "No members returned. Guild recipe data may be unavailable.")
end

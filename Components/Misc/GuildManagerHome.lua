-- MIT License. Copyright (c) 2026 Jonas "JuNNeZ" Andersen.
local Addon, ns = ...
local Guild = ns:GetModule("GuildManager")
local L = LibStub("AceLocale-3.0"):GetLocale(Addon)
local UI = Guild.UI

Guild.LastOnlineText = function(self, online, value)
    if (online) then return L["Online"] end
    if (not value) then return L["Unknown"] end
    for _, unit in ipairs({ { "years", "%d years ago" }, { "months", "%d months ago" }, { "days", "%d days ago" } }) do
        if (value[unit[1]] > 0) then return string.format(L[unit[2]], value[unit[1]]) end
    end
    return value.hours > 0 and string.format(L["%d hours ago"], value.hours) or L["Less than an hour ago"]
end

Guild.ContactSelected = function(self, invite)
    -- Re-read the selected roster entry, never the editable character input.
    local member = self.selected and (self.members or {})[self.selected]
    if (not member or not member.online or InCombatLockdown() or not self:CharacterKey(member.name)) then return end
    if (invite) then
        if (C_PartyInfo and C_PartyInfo.InviteUnit) then C_PartyInfo.InviteUnit(member.name) end
    elseif (ChatFrameUtil and ChatFrameUtil.SendTell) then ChatFrameUtil.SendTell(member.name) end
end

local function TextPanel(parent, title, x, y, width, height)
    local panel = CreateFrame("Frame", nil, parent, ns.BackdropTemplate)
    panel:SetPoint("TOPLEFT", x-12, y+10); panel:SetSize(width+20, height+55)
    panel:SetBackdrop((ns.OptionsKit.Look and ns.OptionsKit.Look.InsetBackdrop or ns.OptionsKit.InsetBackdrop)); panel:SetBackdropColor(.03, .033, .038, .98)
    panel:SetBackdropBorderColor(.52, .43, .29, 1)
    UI.Opaque(panel)
    UI.Label(panel, title, 12, -10, width, 15)
    local scroll = CreateFrame("ScrollFrame", nil, panel)
    scroll:SetPoint("TOPLEFT", 12, -40); scroll:SetSize(width-16, height); scroll:SetClipsChildren(true)
    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(width-16, height); scroll:SetScrollChild(child)
    UI.ScrollBar(scroll, panel)
    local text = UI.Label(child, "", 0, 0, width-24, 13, 0)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(_, delta)
        scroll:SetVerticalScroll(math.max(0, math.min(scroll:GetVerticalScroll()-delta*30, scroll:GetVerticalScrollRange())))
    end)
    return { text = text, child = child, scroll = scroll, height = height }
end

Guild.RefreshHome = function(self)
    local home = self.homeWindow
    if (not home or not home:IsShown()) then return end
    local details = self.guildDetails or {}
    home.title:SetText(details.name or L["Guild & Nicknames"])
    local characters, online, people, onlinePeople, favorites = 0, 0, 0, 0, 0
    local ranks, rankNames, rankOrders = {}, {}, {}
    for _, person in ipairs(self:GetPeople("", {})) do
        local inGuild = false
        for _, row in ipairs(person.rows) do
            if (not row.member.saved) then inGuild = true end
        end
        if (inGuild) then
            people = people+1
            if (person.online > 0) then onlinePeople = onlinePeople+1 end
            if (person.favorite) then favorites = favorites+1 end
        end
    end
    for _, member in pairs(self.members or {}) do
        characters = characters+1
        if (member.online) then online = online+1 end
        local rank = member.rank ~= "" and member.rank or L["Unknown"]
        if (not ranks[rank]) then ranks[rank] = 0; rankNames[#rankNames+1] = rank end
        ranks[rank] = ranks[rank]+1
        rankOrders[rank] = math.min(rankOrders[rank] or math.huge, member.rankIndex or math.huge)
    end
    table.sort(rankNames, function(a, b)
        if (rankOrders[a] ~= rankOrders[b]) then return rankOrders[a] < rankOrders[b] end
        return a < b
    end)
    home.counts:SetText(string.format(L["%d people  /  %d characters  /  %d online"], people, characters, online))
    home.people:SetText(string.format(L["%d online people  /  %d favorites"], onlinePeople, favorites))
    local lines = {}
    for _, rank in ipairs(rankNames) do lines[#lines+1] = rank .. ": " .. ranks[rank] end
    for _, panel in ipairs({ home.motd, home.info, home.ranks }) do
        local value
        if (panel == home.motd) then value = details.motd
        elseif (panel == home.info) then value = details.info
        else value = table.concat(lines, "\n") end
        value = value and value ~= "" and value or L["No guild data available."]
        if (panel.value ~= value) then panel.scroll:SetVerticalScroll(0); panel.value = value end
        panel.text:SetText(value, true)
        panel.child:SetHeight(math.max(panel.height, panel.text:GetStringHeight()+12))
    end
    home.emblem:Hide()
    if (IsInGuild() and SetLargeGuildTabardTextures and C_GuildInfo and C_GuildInfo.GetGuildTabardInfo) then
        SetLargeGuildTabardTextures("player", home.emblem)
        home.emblem:Show()
    end
end

Guild.OpenHome = function(self)
    if (not self.homeWindow) then
        local home = UI.Page(ns.Prefix .. "GuildHome", "home", L["Guild home"], 900, 596)
        self.homeWindow = home
        home.emblem = home:CreateTexture(nil, "ARTWORK")
        home.emblem:SetSize(64, 64); home.emblem:SetPoint("TOPLEFT", 46, -30)
        home.title = UI.Label(home, "", 142, -36, 640, 22)
        home.counts = UI.Label(home, "", 144, -72, 640, 13)
        home.people = UI.Label(home, "", 26, -112, 810, 15)
        home.motd = TextPanel(home, L["Guild message of the day"], 26, -150, 560, 90)
        home.info = TextPanel(home, L["Guild information"], 26, -300, 560, 180)
        home.ranks = TextPanel(home, L["Ranks"], 620, -150, 250, 330)
        UI.Label(home, L["People are based on your main/alt links. Counts use the current guild roster."], 26, -550, 350, 11, 2)
        UI.QuietButton(home, L["Guild crafting"], 400, -550, 170, function() self:OpenCrafting() end)
        UI.QuietButton(home, L["Guild history"], 584, -550, 138, function() self:OpenHistory() end)
        UI.QuietButton(home, L["Refresh"], 736, -550, 138, function() self:RequestRoster() end)
    end
    UI.Show(self.homeWindow); self:RequestRoster(); self:RefreshHome()
end

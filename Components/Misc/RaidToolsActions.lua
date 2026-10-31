-- MIT License. Copyright (c) 2026 Jonas "JuNNeZ" Andersen.
-- Public party APIs and AzeriteUI-owned raid filters. No Blizzard panel methods.
local Addon, ns = ...
local Tools = ns:GetModule("RaidTools", true)
if (not Tools) then return end
local L = LibStub("AceLocale-3.0"):GetLocale(Addon)
local function PartyFunction(name)
    return C_PartyInfo and type(C_PartyInfo[name]) == "function" and C_PartyInfo[name] or nil
end
local function Restricted()
    return (HasLFGRestrictions and HasLFGRestrictions())
        or (UnitPopupSharedUtil and UnitPopupSharedUtil.HasLFGRestrictions and UnitPopupSharedUtil.HasLFGRestrictions())
end

Tools.HasPermission = function(self)
    return IsInGroup() and (not IsInRaid() or UnitIsGroupLeader("player") or UnitIsGroupAssistant("player"))
end
Tools.GetRaidHiddenMode = function(self)
    if (self.suspended or not self.db or not self.db.profile.enabled or not IsInRaid()) then return nil end
    return self.db.profile.hideGroups and true or false
end
Tools.GetRaidGroupFilter = function(self)
    if (self:GetRaidHiddenMode() == nil) then return nil end
    if (self.db.profile.hideGroups) then return "0" end
    local groups = {}
    for i = 1, 8 do
        if (not self.db.profile.groups or self.db.profile.groups[i] ~= false) then groups[#groups+1] = tostring(i) end
    end
    return #groups > 0 and table.concat(groups, ",") or "0"
end
Tools.ApplyRaidFilters = function(self)
    if (InCombatLockdown()) then return end
    local filter = self:GetRaidGroupFilter()
    local hidden = self:GetRaidHiddenMode()
    if (filter == self.appliedFilter and hidden == self.appliedHidden) then return end
    local bridge = ns.WoW12BlizzardQuarantine
    if (not bridge) then return end
    self.appliedFilter, self.appliedHidden = filter, hidden
    if (bridge and bridge.ApplyRaidGroupFilter) then bridge.ApplyRaidGroupFilter() end
    if (bridge and bridge.ApplyRaidGroupVisibility) then bridge.ApplyRaidGroupVisibility() end
end

Tools.CanPerformAction = function(self, key)
    if (self.preview or self.suspended or not self.db.profile.enabled) then return false end
    if (key == "visibility") then return IsInGroup() and IsInRaid() end
    if (InCombatLockdown()) then return false end
    if (key == "settings") then return true end
    if (not IsInGroup()) then return false end
    local leader = UnitIsGroupLeader("player")
    local lead = leader or UnitIsGroupAssistant("player")
    if (key == "leave") then
        return PartyFunction("LeaveParty") ~= nil and (not PartyFunction("IsPartyWalkIn") or not C_PartyInfo.IsPartyWalkIn() or type(LeaveWalkInParty) == "function")
    end
    if (key == "instance") then return PartyUtil and PartyUtil.CanLeaveInstance and PartyUtil.CanLeaveInstance() and type(ConfirmOrLeaveParty) == "function" end
    if (key == "ready") then return lead and PartyFunction("DoReadyCheck") ~= nil end
    if (key == "roles") then return lead and type(InitiateRolePoll) == "function" and not Restricted() and not (UnitInBattleground and UnitInBattleground("player")) end
    if (key == "countdown") then return lead and PartyFunction("DoCountdown") ~= nil end
    if (key == "assist") then return leader and IsInRaid() and PartyFunction("SetEveryoneIsAssistant") ~= nil and type(IsEveryoneAssistant) == "function" end
    if (key == "convert") then
        local count = self.ReadNumber(GetNumGroupMembers())
        return leader and not Restricted() and (not IsInRaid() or (count and count <= 5)) and PartyFunction(IsInRaid() and "ConvertToParty" or "ConvertToRaid") ~= nil
    end
    if (key == "difficulty") then
        return leader and MenuUtil and MenuUtil.CreateContextMenu and DifficultyUtil and DifficultyUtil.ID
            and (not DifficultyUtil.HasAnyUserSelectableDifficulties or DifficultyUtil.HasAnyUserSelectableDifficulties())
    end
    if (key == "pings") then
        return lead and MenuUtil and MenuUtil.CreateContextMenu and PartyFunction("SetRestrictPings") and PartyFunction("GetRestrictPings")
            and Enum and Enum.RestrictPingsTo and (not C_Ping or not C_Ping.IsPingSystemEnabled or C_Ping.IsPingSystemEnabled())
    end
    return false
end

Tools.GetDifficultyChoices = function(self)
    local util = DifficultyUtil
    if (not util or not util.ID) then return {} end
    local raid = IsInRaid()
    local keys = raid and { "PrimaryRaidNormal", "PrimaryRaidHeroic", "PrimaryRaidMythic" } or { "DungeonNormal", "DungeonHeroic", "DungeonMythic" }
    local choices = {}
    for _, key in ipairs(keys) do
        local id = self.ReadNumber(util.ID[key])
        if (id) then
            local selectable = true
            if (ns.IsForever) then
                selectable = false
                if (GetDifficultyInfo) then
                    local flag = select(11, GetDifficultyInfo(id))
                    if (not issecretvalue or not issecretvalue(flag)) then selectable = flag == true end
                end
            end
            if (selectable) then
                local enabled = false
                local check = raid and util.IsRaidDifficultyEnabled or util.IsDungeonDifficultyEnabled
                if (type(check) == "function") then enabled = check(id) end
                choices[#choices+1] = { id = id, label = util.GetDifficultyName and util.GetDifficultyName(id) or tostring(id), enabled = enabled and true or false }
            end
        end
    end
    return choices
end
Tools.SetDifficulty = function(self, id, raid)
    if (not self:CanPerformAction("difficulty") or IsInRaid() ~= raid) then return end
    for _, choice in ipairs(self:GetDifficultyChoices()) do
        if (choice.id == id and choice.enabled) then
            if (raid and type(SetRaidDifficulties) == "function") then SetRaidDifficulties(true, id)
            elseif (not raid and type(SetDungeonDifficultyID) == "function") then SetDungeonDifficultyID(id) end
            return
        end
    end
end
Tools.ShowDifficultyMenu = function(self, button)
    if (not self:CanPerformAction("difficulty")) then return end
    local raid = IsInRaid()
    MenuUtil.CreateContextMenu(button, function(_, menu)
        menu:CreateTitle(_G.CRF_DIFFICULTY or L["Difficulty"])
        local choices = self:GetDifficultyChoices()
        for _, data in ipairs(choices) do
            local id = data.id
            local radio = menu:CreateRadio(data.label, function()
                if (raid) then return DifficultyUtil.DoesCurrentRaidDifficultyMatch and DifficultyUtil.DoesCurrentRaidDifficultyMatch(id) end
                return GetDungeonDifficultyID() == id
            end, function() self:SetDifficulty(id, raid) end)
            radio:SetEnabled(data.enabled)
        end
    end)
end
Tools.SetPingPermission = function(self, value)
    if (not self:CanPerformAction("pings")) then return end
    for _, key in ipairs({ "None", "Lead", "Assist", "TankHealer" }) do
        if (Enum.RestrictPingsTo[key] == value) then C_PartyInfo.SetRestrictPings(value); return end
    end
end
Tools.ShowPingMenu = function(self, button)
    if (not self:CanPerformAction("pings")) then return end
    MenuUtil.CreateContextMenu(button, function(_, menu)
        menu:CreateTitle(L["Ping permissions"])
        local choices = {
            { "None", _G.NONE }, { "Lead", _G.RAID_MANAGER_RESTRICT_PINGS_TO_LEAD },
            { "Assist", _G.RAID_MANAGER_RESTRICT_PINGS_TO_ASSIST }, { "TankHealer", _G.RAID_MANAGER_RESTRICT_PINGS_TO_TANKS_HEALERS }
        }
        for _, data in ipairs(choices) do
            local value = Enum.RestrictPingsTo[data[1]]
            if (value ~= nil and type(data[2]) == "string") then
                menu:CreateRadio(data[2], function() return C_PartyInfo.GetRestrictPings() == value end, function() self:SetPingPermission(value) end)
            end
        end
    end)
end

Tools.RequestLeave = function(self)
    if (not self:CanPerformAction("leave") or not StaticPopupDialogs or not StaticPopup_Show) then return end
    local key = "AZERITEUI_RAIDTOOLS_LEAVE"
    if (not StaticPopupDialogs[key]) then
        StaticPopupDialogs[key] = {
            text = L["Leave your current group?"], button1 = _G.YES, button2 = _G.NO,
            timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
            OnAccept = function(_, data)
                -- A roster change while the confirmation was open invalidates this request.
                if (not data or data.serial ~= data.module.rosterSerial or not data.module:CanPerformAction("leave")) then return end
                if (PartyFunction("IsPartyWalkIn") and C_PartyInfo.IsPartyWalkIn()) then LeaveWalkInParty()
                else C_PartyInfo.LeaveParty() end
            end
        }
    end
    StaticPopup_Show(key, nil, nil, { module = self, serial = self.rosterSerial })
end
Tools.PerformAction = function(self, key, button)
    -- Every callback rechecks permissions, including callbacks from an already-open menu.
    if (not self:CanPerformAction(key)) then return end
    if (key == "ready") then C_PartyInfo.DoReadyCheck()
    elseif (key == "roles") then InitiateRolePoll()
    elseif (key == "countdown") then C_PartyInfo.DoCountdown(10)
    elseif (key == "assist") then
        local current = IsEveryoneAssistant()
        if (issecretvalue and issecretvalue(current)) then return end
        C_PartyInfo.SetEveryoneIsAssistant(not current)
    elseif (key == "convert") then
        if (IsInRaid()) then C_PartyInfo.ConvertToParty() else C_PartyInfo.ConvertToRaid() end
    elseif (key == "difficulty") then self:ShowDifficultyMenu(button)
    elseif (key == "pings") then self:ShowPingMenu(button)
    elseif (key == "leave") then self:RequestLeave()
    elseif (key == "instance") then ConfirmOrLeaveParty()
    elseif (key == "visibility") then self.db.profile.hideGroups = not self.db.profile.hideGroups; self:UpdateSettings()
    elseif (key == "settings") then
        local panel = ns.OptionsKit and ns.OptionsKit.Panel
        if (panel and panel.OpenSection) then panel:OpenSection(L["Group Frames"], { L["Group Frames"], "raidTools" })
        else
            local options = ns:GetModule("Options", true)
            if (options and options.OpenOptionsMenu) then options:OpenOptionsMenu() end
        end
    end
end

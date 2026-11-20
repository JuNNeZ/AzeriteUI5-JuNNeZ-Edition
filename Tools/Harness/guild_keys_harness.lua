-- Guild overview keys: override bindings only, deferred in combat, cleared on disable.
-- Stubs record override calls; no WoW client, binding UI, secure or taint claims.
-- lua Tools/Harness/guild_keys_harness.lua .
local root = arg[1] or "."
local checks, combat = 0, false
local function check(value, label) checks = checks+1; assert(value, label) end
local overrides, created, toggles, setBinding = {}, 0, 0, 0
local blizzardKeys = { "J", "SHIFT-G" }
issecretvalue = function() return false end
InCombatLockdown = function() return combat end
IsInGuild = function() return false end
GetNormalizedRealmName = function() return "TestRealm" end
UIParent = {}
CreateFrame = function(kind, name)
    created = created+1
    local frame = { name = name, kind = kind }
    frame.SetScript = function(self, script, func) self[script] = func end
    return frame
end
ClearOverrideBindings = function(owner)
    assert(not combat, "ClearOverrideBindings in combat")
    for key, entry in pairs(overrides) do if (entry.owner == owner) then overrides[key] = nil end end
end
SetOverrideBindingClick = function(owner, priority, key, button)
    assert(not combat, "SetOverrideBindingClick in combat")
    overrides[key] = { owner = owner, button = button, priority = priority }
end
-- Base bindings only: an override would hide the key from this lookup in the client.
GetBindingKey = function(command)
    if (command ~= "TOGGLEGUILDTAB") then return end
    return unpack(blizzardKeys)
end
SetBinding = function() setBinding = setBinding+1 end
LibStub = function() return { GetLocale = function() return setmetatable({}, { __index = function(_, key) return key end }) end } end
local registered = {}
local module = { DisableSettingsExport = function() end, RegisterChatCommand = function() end,
    RegisterEvent = function(_, event) registered[event] = true end }
local ns = { NewModule = function() return module end, GetModule = function() return module end,
    db = { RegisterNamespace = function(_, _, defaults)
        return { global = defaults.global, profile = defaults.profile, RegisterCallback = function() end }
    end } }
assert(loadfile(root .. "/Components/Misc/GuildManager.lua"))("TestAddon", ns)
module.ToggleWindow = function() toggles = toggles+1 end
module.RequestRoster = function() end
module:OnInitialize()
module:OnEnable()
local function Count() local n = 0; for _ in pairs(overrides) do n = n+1 end; return n end

check(created == 0 and Count() == 0, "nothing is created or bound by default")
check(registered.UPDATE_BINDINGS and registered.PLAYER_REGEN_ENABLED, "binding and combat-end events registered")
local profile = module.db.profile
profile.blizzardGuildKey = true
module:UpdateBindings()
check(created == 1 and overrides.J and overrides["SHIFT-G"] and Count() == 2, "every Blizzard guild key is overridden")
check(overrides.J.button == "TestAddonGuildManagerToggle" and overrides.J.priority == false, "override clicks our named button, normal priority")
module.toggleButton.OnClick()
check(toggles == 1, "the button toggles the overview")

profile.toggleKey = "CTRL-K"
module:UpdateBindings()
check(Count() == 3 and overrides["CTRL-K"], "custom key added")
profile.toggleKey = "bad key|"
module:UpdateBindings()
check(Count() == 2 and not overrides["CTRL-K"], "invalid custom key ignored and old one cleared")

-- The player moves Blizzard's guild key: the override follows.
blizzardKeys = { "L" }
module:OnEvent("UPDATE_BINDINGS")
check(Count() == 1 and overrides.L and not overrides.J, "follows Blizzard's rebinding")

-- Combat: nothing is touched until it ends.
combat = true
profile.blizzardGuildKey = false
module:UpdateBindings()
check(overrides.L and module.bindingsPending, "combat defers the change")
combat = false
module:OnEvent("PLAYER_REGEN_ENABLED")
check(Count() == 0 and not module.bindingsPending, "change applied after combat; key returned")

profile.blizzardGuildKey, profile.toggleKey = true, "CTRL-K"
module:UpdateBindings()
check(Count() == 2, "re-enabled")
module:OnDisable()
check(Count() == 0, "disabling the module returns every key")
check(created == 1 and setBinding == 0, "one button; saved bindings never written")
print("Guild keys: " .. checks .. " checks passed")

--[[
The MIT License (MIT)
Copyright (c) 2026 Jonas "JuNNeZ" Andersen
]]
local _, ns = ...
local L = LibStub("AceLocale-3.0"):GetLocale((...))
local Options = ns:GetModule("Options")

local getmodule = function()
  local module = ns:GetModule("UIWidgetTopCenter", true)
  if (module and module:IsEnabled()) then return module end
end

local setter = function(info,val)
  getmodule().db.profile[info[#info]] = val
  getmodule():OnEvent("PLAYER_TARGET_CHANGED")
end

local getter = function(info)
  return getmodule().db.profile[info[#info]]
end

-- The widgets choice, read from the two stored switches; its default is worked
-- out the same way (Options/Kit/Defaults.lua SetComputed).
local VisibilityMode = function(profile)
  if (profile.alwaysShow or not profile.hideWithTarget) then return "always" end
  return "target"
end
local VisibilityGet = function()
  local module = getmodule()
  return module and VisibilityMode(module.db.profile) or "target"
end
if (ns.OptionsKit and ns.OptionsKit.Defaults and ns.OptionsKit.Defaults.SetComputed) then
  ns.OptionsKit.Defaults.SetComputed(VisibilityGet, VisibilityMode)
end

local GenerateOptions = function()
  if (not getmodule()) then return end
  local options = {
    name = L["Top Center Widgets"],
    type = "group",
    args = {
      header = {
        name = L["Widget Visibility"],
        order = 1,
        type = "header"
      },
      description = {
        name = L["These settings control the top-center encounter and zone widgets shown above the play area."],
        order = 2,
        type = "description",
        fontSize = "medium"
      },
      -- One choice over the two stored switches, so nothing saved changes (Docs/Options
      -- Navigation Review - 2026-11-22.md, step 7). alwaysShow wins, as the module decides.
      visibility = {
        name = L["Show the top center widgets"],
        desc = L["Always, or only while you have no target."],
        order = 10,
        type = "select", width = "full",
        values = { always = L["Always"], target = L["Hide with a target"] },
        sorting = { "always", "target" },
        set = function(info, val)
          local profile = getmodule().db.profile
          profile.alwaysShow = (val == "always")
          if (val == "target") then profile.hideWithTarget = true end
          getmodule():OnEvent("PLAYER_TARGET_CHANGED")
        end,
        get = VisibilityGet
      }
    }
  }
  return options
end

Options:AddGroup("Widgets", GenerateOptions, -2700, "world", "UIWidgetTopCenter")

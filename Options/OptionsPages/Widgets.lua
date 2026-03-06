--[[
The MIT License (MIT)
Copyright (c) 2026
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

local GenerateOptions = function()
  if (not getmodule()) then return end
  local options = {
    name = L["Widgets"],
    type = "group",
    args = {
      alwaysShow = {
        name = L["Always show Top Center Widgets"],
        desc = L["Keep the top center widgets visible even when you have a target."],
        order = 1,
        type = "toggle", width = "full",
        set = setter,
        get = getter
      },
      hideWithTarget = {
        name = L["Hide with Target"],
        desc = L["Hide the top center widgets whenever you have a target (disabled if Always Show is enabled)."],
        order = 2,
        type = "toggle", width = "full",
        disabled = function(info) return getmodule().db.profile.alwaysShow end,
        set = setter,
        get = getter
      }
    }
  }
  return options
end

Options:AddGroup(L["Widgets"], GenerateOptions, -1000)

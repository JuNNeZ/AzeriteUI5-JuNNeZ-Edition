--[[

	The MIT License (MIT)

	Copyright (c) 2026 Lars Norberg

	Permission is hereby granted, free of charge, to any person obtaining a copy
	of this software and associated documentation files (the "Software"), to deal
	in the Software without restriction, including without limitation the rights
	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	copies of the Software, and to permit persons to whom the Software is
	furnished to do so, subject to the following conditions:

	The above copyright notice and this permission notice shall be included in all
	copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
	SOFTWARE.

--]]
local _, ns = ...

local GameMenuSkin = ns:NewModule("GameMenuSkin", "AceHook-3.0")

-- Lua API
local ipairs = ipairs
local pairs = pairs
local unpack = unpack

-- Addon API
local GetFont = ns.API.GetFont
local GetMedia = ns.API.GetMedia
local UIHider = ns.Hider

local function IsGameMenuButton(button)
	if (not button or button:GetParent() ~= GameMenuFrame) then
		return false
	end
	if (button.GetObjectType and button:GetObjectType() ~= "Button") then
		return false
	end
	return (button.Left and button.Middle and button.Right and button.GetText) and true or false
end

local function SkinButton(button)
	if (not IsGameMenuButton(button) or button.__AzeriteUI_GameMenuSkinned) then
		return
	end
	button.__AzeriteUI_GameMenuSkinned = true

	if (button.Left) then button.Left:SetAlpha(0) end
	if (button.Middle) then button.Middle:SetAlpha(0) end
	if (button.Right) then button.Right:SetAlpha(0) end

	local backdrop = CreateFrame("Frame", nil, button, ns.BackdropTemplate)
	backdrop:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
	backdrop:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
	backdrop:SetFrameLevel(button:GetFrameLevel() - 1)
	backdrop:SetBackdrop({
		bgFile = [[Interface\Tooltips\UI-Tooltip-Background]],
		edgeFile = GetMedia("border-tooltip"),
		edgeSize = 16,
		insets = { left = 5, right = 5, top = 5, bottom = 5 }
	})
	backdrop:SetBackdropColor(.05, .05, .05, .92)
	backdrop:SetBackdropBorderColor(.35, .35, .35, .95)
	button.__AzeriteUI_GameMenuBackdrop = backdrop

	local text = button:GetFontString() or button.Text
	if (text) then
		text:SetFontObject(GetFont(14, true))
	end

	button:HookScript("OnEnter", function(self)
		local bg = self.__AzeriteUI_GameMenuBackdrop
		if (bg) then
			bg:SetBackdropBorderColor(unpack(ns.Colors.highlight))
		end
	end)
	button:HookScript("OnLeave", function(self)
		local bg = self.__AzeriteUI_GameMenuBackdrop
		if (bg) then
			bg:SetBackdropBorderColor(.35, .35, .35, .95)
		end
	end)
end

local function SkinFrame()
	if (not GameMenuFrame or GameMenuFrame:IsForbidden()) then
		return
	end

	if (not GameMenuFrame.__AzeriteUI_GameMenuArtStripped) then
		GameMenuFrame.__AzeriteUI_GameMenuArtStripped = true

		-- Remove legacy Blizzard frame regions that can survive NineSlice hiding.
		for _, region in ipairs({ GameMenuFrame:GetRegions() }) do
			if (region and region.GetObjectType and region:GetObjectType() == "Texture") then
				region:SetTexture(nil)
				region:SetAlpha(0)
				region:Hide()
			end
		end
	end

	if (GameMenuFrame.NineSlice and GameMenuFrame.NineSlice.GetParent and GameMenuFrame.NineSlice:GetParent() ~= UIHider) then
		GameMenuFrame.NineSlice:SetParent(UIHider)
	end
	if (GameMenuFrame.Border) then
		GameMenuFrame.Border:SetAlpha(0)
		GameMenuFrame.Border:Hide()
	end
	if (GameMenuFrame.Background) then
		GameMenuFrame.Background:SetAlpha(0)
		GameMenuFrame.Background:Hide()
	end
	if (GameMenuFrameHeader) then
		GameMenuFrameHeader:Hide()
	end

	if (not GameMenuFrame.__AzeriteUI_GameMenuBackdrop) then
		local frameBackdrop = CreateFrame("Frame", nil, GameMenuFrame, ns.BackdropTemplate)
		frameBackdrop:SetPoint("TOPLEFT", GameMenuFrame, "TOPLEFT", -8, 8)
		frameBackdrop:SetPoint("BOTTOMRIGHT", GameMenuFrame, "BOTTOMRIGHT", 8, -8)
		frameBackdrop:SetFrameLevel(GameMenuFrame:GetFrameLevel() - 1)
		frameBackdrop:SetBackdrop({
			bgFile = [[Interface\Tooltips\UI-Tooltip-Background]],
			edgeFile = GetMedia("border-tooltip"),
			edgeSize = 24,
			insets = { left = 7, right = 7, top = 7, bottom = 7 }
		})
		frameBackdrop:SetBackdropColor(.03, .03, .03, .95)
		frameBackdrop:SetBackdropBorderColor(.25, .25, .25, .95)
		GameMenuFrame.__AzeriteUI_GameMenuBackdrop = frameBackdrop
	end

	for _, child in ipairs({ GameMenuFrame:GetChildren() }) do
		if (child and child.IsShown and child:IsShown()) then
			SkinButton(child)
		end
	end
end

GameMenuSkin.UpdateSkin = function(self)
	SkinFrame()
end

GameMenuSkin.OnEnable = function(self)
	if (not GameMenuFrame) then
		return
	end

	if (not self:IsHooked(GameMenuFrame, "OnShow")) then
		self:SecureHookScript(GameMenuFrame, "OnShow", "UpdateSkin")
	end
	if (type(GameMenuFrame_UpdateVisibleButtons) == "function" and not self:IsHooked("GameMenuFrame_UpdateVisibleButtons")) then
		self:SecureHook("GameMenuFrame_UpdateVisibleButtons", "UpdateSkin")
	end

	self:UpdateSkin()
end

--[[

	The MIT License (MIT)

	Copyright (c) 2026 Jonas "JuNNeZ" Andersen

--]]
-- Turning an AceConfig option table into rows.
--
-- Config.lua reads the table, Controls.lua draws the widgets, and this is what
-- joins them: it walks a page in draw order, builds a control for each option,
-- binds the control's value to the option's get and set, and stacks the results
-- down a scrolling column.
--
-- One level of nesting is flattened deliberately. AceConfigDialog would render a
-- page's sub-groups as a row of tabs; the roadmap artifact instead runs them down
-- one page as titled sections, which is why `childGroups = "tab"` is ignored here
-- and a sub-group becomes a heading followed by its rows. The real table is only
-- two deep, so one level covers all of it.
local Addon, ns = ...

local Kit = ns.OptionsKit
local Config = Kit.Config
local Controls = Kit.Controls
if (not Config or not Controls) then return end

-- Lua API
local ipairs = ipairs
local max = math.max
local pcall = pcall
local string_format = string.format
local tonumber, tostring, type = tonumber, tostring, type

local L = LibStub("AceLocale-3.0"):GetLocale(Addon)

local Renderer = {}
Kit.Renderer = Renderer

local APP = Addon

--------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------
local Copy = function(path)
	local out = {}
	for i = 1, #path do out[i] = path[i] end
	return out
end

local AsString = function(value, fallback)
	if (type(value) == "string") then return value end
	if (type(value) == "number") then return tostring(value) end
	return fallback
end

-- An option is inline when it asks to be drawn in place rather than as a page
-- of its own. We flatten those the same way we flatten everything else.
local IsInline = function(option)
	return (option.dialogInline or option.guiInline or option.inline) and true or false
end

-- Whether this option's choices read better as a strip of buttons than as a
-- dropdown. Controls owns the rule; the renderer only has to ask.
local WantsStrip = function(option, options, path)
	local values = Config.GetValues(option, options, path, APP)
	return Controls.WantsSegmented(values), values
end

--------------------------------------------------------------------------
-- Binding
--------------------------------------------------------------------------
-- Everything a control needs in order to speak for one option.
--
-- `SetValue` on a control is deliberately silent unless a person moved it, so
-- writing a value in here can never turn round and write it back out again.
-- A gem on anything that differs from its default, and one click to put that
-- one setting back. `IsModified` answers nil when the default is unknown,
-- which must not be read as "unchanged": no binding means no gem.
local MarkModified = function(control, options, path, current)
	local Defaults = Kit.Defaults
	if (not Defaults) then return end

	local modified = Defaults.IsModified(options, path, current)
	if (modified == nil) then
		control:SetOnRevert(nil)
		control:SetModified(false)
		return
	end

	control:SetModified(modified)
end

-- A change is previewed before the page rebuilds and releases the control that
-- made it. Unbound settings (profiles and the panel's own appearance) simply
-- return false from Preview.Request and leave no trace.
local PreviewChange = function(options, path, label)
	local Preview = Kit.Preview
	if (Preview) then Preview:Request(options, path, label) end
end

local Bind = function(control, option, options, path, page)
	local bound = Copy(path)
	local label = AsString(Config.GetName(option, options, path, APP), "")

	control:SetLabel(label)

	-- The artifact puts the description under the label as a plain line rather
	-- than inside a tooltip nobody hovers to find.
	local desc = Config.GetDesc(option, options, path, APP)
	control:SetHelp(AsString(desc, nil))

	local disabled = Config.IsDisabled(option, options, bound, APP)
	control:SetDisabled(disabled and true or false)

	local kind = option.type

	if (kind == "execute") then
		control:SetText(AsString(Config.GetName(option, options, path, APP), ""))
		control:SetCallback(function()
			Config.Execute(option, options, bound, APP)
			page:Refresh()
		end)
		return
	end

	if (kind == "toggle") then
		local value = Config.GetValue(option, options, bound, APP) and true or false
		control:SetValue(value)

		MarkModified(control, options, bound, value)
		control:SetOnRevert(function(self)
			if (Kit.Defaults and Kit.Defaults.Revert(options, bound)) then
				PreviewChange(options, bound, label)
				page:Refresh()
			end
		end)
		control:SetCallback(function(self, value)
			Config.SetValue(option, options, bound, APP, value and true or false)
			PreviewChange(options, bound, label)
			page:Refresh()
		end)
		return
	end

	if (kind == "range") then
		-- Coerced, because a bound is read straight off the table rather than
		-- through Config, and an option carrying something that is not a number
		-- should narrow the slider rather than blank the whole row.
		local lo = tonumber(option.softMin or option.min) or 0
		local hi = tonumber(option.softMax or option.max) or 100
		local step = tonumber(option.bigStep or option.step) or 0

		control:SetSliderValues(lo, hi, step)
		control:SetIsPercent(option.isPercent and true or false)

		local value = Config.GetValue(option, options, bound, APP)
		control:SetValue(type(value) == "number" and value or lo)

		MarkModified(control, options, bound, value)
		control:SetOnRevert(function(self)
			if (Kit.Defaults and Kit.Defaults.Revert(options, bound)) then
				PreviewChange(options, bound, label)
				page:Refresh()
			end
		end)

		control:SetCallback(function(self, newValue)
			Config.SetValue(option, options, bound, APP, newValue)
			PreviewChange(options, bound, label)
			page:Refresh()
		end)
		return
	end

	if (kind == "select") then
		local values = Config.GetValues(option, options, path, APP)
		local sorting = Config.GetMember("sorting", option, options, path, APP)

		control:SetList(type(values) == "table" and values or {}, sorting)

		local value = Config.GetValue(option, options, bound, APP)
		if (type(values) == "table" and values[value] == nil) then value = nil end
		control:SetValue(value)

		MarkModified(control, options, bound, value)
		control:SetOnRevert(function(self)
			if (Kit.Defaults and Kit.Defaults.Revert(options, bound)) then
				PreviewChange(options, bound, label)
				page:Refresh()
			end
		end)

		control:SetCallback(function(self, newValue)
			Config.SetValue(option, options, bound, APP, newValue)
			PreviewChange(options, bound, label)
			page:Refresh()
		end)
		return
	end

	if (kind == "input") then
		if (control.multiline and control.SetNumLines) then
			control:SetNumLines(tonumber(option.multiline) or 4)
		end

		local text = Config.GetValue(option, options, bound, APP)
		control:SetValue(AsString(text, ""))

		control:SetCallback(function(self, newText)
			Config.SetValue(option, options, bound, APP, newText)
			PreviewChange(options, bound, label)
			page:Refresh()
		end)
		return
	end
end

--------------------------------------------------------------------------
-- Rendering
--------------------------------------------------------------------------
-- Builds the flat list of things to draw for one page: descriptions and
-- headings as they come, sub-groups flattened into a heading plus their rows.
local Collect
Collect = function(group, options, path, out, depth)
	Config.ForEachChild(group, options, path, APP, function(key, option, childPath)
		local kind = option.type

		if (kind == "group") then
			-- Only one level is flattened. Anything deeper would run the page on
			-- forever, and the real table never goes there.
			if (depth == 0 or IsInline(option)) then
				-- A sub-group is a place you might want to jump to. The `header`
				-- entries inside one are punctuation within it, not destinations:
				-- Action Bars has twelve of the former and thirty-two of the two
				-- combined, and a rail listing all thirty-two helps nobody.
				out[#out + 1] = {
					kind = "header",
					major = true,
					label = AsString(Config.GetName(option, options, childPath, APP), key)
				}
				Collect(option, options, childPath, out, depth + 1)
			end
			return
		end

		if (kind == "header") then
			out[#out + 1] = {
				kind = "header",
				label = AsString(Config.GetName(option, options, childPath, APP), "")
			}
			return
		end

		if (kind == "description") then
			out[#out + 1] = {
				kind = "description",
				label = AsString(Config.GetName(option, options, childPath, APP), "")
			}
			return
		end

		if (kind == "toggle" or kind == "range" or kind == "select"
			or kind == "input" or kind == "execute") then

			if (kind == "select" and option.style == "radio") then return end

			out[#out + 1] = {
				kind = kind,
				option = option,
				path = Copy(childPath)
			}
			return
		end

		-- A type with no control of ours - `color`, `keybinding`, `multiselect`.
		-- The real table has none of them today, which is exactly what makes
		-- this dangerous: add a colour picker to a page and it would simply not
		-- be there, with nothing to say so and nothing to error.
		--
		-- So it says so. A line on the page naming the setting and the type it
		-- wants is worth more than a silent gap, and it is how whoever adds the
		-- first one finds out they have to draw it.
		out[#out + 1] = {
			kind = "description",
			unsupported = kind,
			label = string_format(L["%s - this setting needs a %s control, which this panel cannot draw yet."],
				AsString(Config.GetName(option, options, childPath, APP), key), kind)
		}
	end)
end

Renderer.Collect = function(self, group, options, path)
	local out = {}
	Collect(group, options, path or {}, out, 0)
	return out
end

--------------------------------------------------------------------------
-- A page
--------------------------------------------------------------------------
-- Owns a scroll child, the controls inside it, and the job of refreshing them
-- when a value changes somewhere else in the table.
Renderer.CreatePage = function(self, content)
	local page = { content = content, controls = {}, pool = {} }

	-- Controls are kept and reused between pages rather than rebuilt, because a
	-- page of sixty rows is a lot of frames to make twice.
	local Acquire = function(kind, wantsStrip)
		-- Strips and dropdowns are both `select`, so they pool separately.
		local poolKey = kind
		if (kind == "select") then
			poolKey = wantsStrip and "segmented" or "select"
		elseif (kind == "input" and wantsStrip) then
			-- `wantsStrip` carries "this one is multiline" for an input.
			poolKey = "multiline"
		end
		local pool = page.pool[poolKey]
		if (not pool) then
			pool = {}
			page.pool[poolKey] = pool
		end

		local control = table.remove(pool)
		if (not control) then
			if (kind == "select") then
				control = wantsStrip and Controls.CreateSegmented(content)
					or Controls.CreateDropdown(content)
			elseif (kind == "input" and wantsStrip) then
				control = Controls.CreateMultiline(content)
			else
				control = Controls.Create(content, kind)
			end
		end
		return control
	end

	local Release = function(control)
		control.frame:Hide()
		control.major = nil
		control:SetCallback(nil)
		control:SetOnRevert(nil)
		control:SetModified(false)

		local key = control.segmented and "segmented" or control.kind
		page.pool[key] = page.pool[key] or {}
		page.pool[key][#page.pool[key] + 1] = control
	end

	page.Clear = function(self)
		for i = #self.controls, 1, -1 do
			Release(self.controls[i])
			self.controls[i] = nil
		end
	end

	-- Where each section starts, so the rail can offer to jump to one. A page
	-- of a hundred and fifty settings is a long way to scroll blind.
	page.Layout = function(self)
		self.sections = self.sections or {}
		for i = #self.sections, 1, -1 do self.sections[i] = nil end

		-- Every control that wraps text is measured against this before it is
		-- placed. Without it a row is asked how tall it is while its own width
		-- is still unknown, and answers as though nothing wrapped.
		local width = content:GetWidth() or 0
		self.width = width

		-- What went where, so a page can be checked for rows drawn on top of one
		-- another the way the rail already is.
		self.layout = self.layout or {}
		for i = #self.layout, 1, -1 do self.layout[i] = nil end

		local offset = 0
		for i, control in ipairs(self.controls) do
			if (control.kind == "header" and control.major) then
				self.sections[#self.sections + 1] = {
					label = control.GetLabel and control:GetLabel() or control.label:GetText(),
					offset = offset
				}
			end

			if (control.Measure) then control:Measure(width) end
			local height = control:GetHeight()

			control.frame:ClearAllPoints()
			control.frame:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -offset)
			control.frame:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -offset)
			control.frame:SetHeight(height)
			control.frame:Show()

			self.layout[#self.layout + 1] = {
				kind = control.kind,
				label = control.labelText,
				offset = offset,
				height = height,
				textHeight = control.textHeight or control.helpHeight
			}

			offset = offset + height
		end
		content:SetHeight(max(1, offset))
		return offset
	end

	-- Re-reads every visible control from the table. A setting that enables
	-- another one has to be able to grey it out the moment it changes.
	page.Refresh = function(self)
		if (not self.options or not self.path) then return end
		self:Show(self.options, self.path)
	end

	page.Show = function(self, options, path)
		self.options, self.path = options, path

		local group = Config.GetGroup(options, path)
		if (not group) then
			self:Clear()
			self:Layout()
			return 0
		end

		local entries = Renderer:Collect(group, options, path)

		self:Clear()

		for i, entry in ipairs(entries) do
			local control

			if (entry.kind == "header") then
				control = Acquire("header")
				control:SetLabel(entry.label)
				control.major = entry.major and true or false

			elseif (entry.kind == "description") then
				control = Acquire("description")
				control:SetLabel(entry.label)

			else
				-- For a select this asks for a strip; for an input it asks for
				-- the multiline shape. Both are "the other kind of this type".
				local wantsStrip
				if (entry.kind == "select") then
					wantsStrip = WantsStrip(entry.option, options, entry.path)
				elseif (entry.kind == "input") then
					wantsStrip = entry.option.multiline and true or false
				end

				control = Acquire(entry.kind, wantsStrip)

				-- A control out of the pool may have been built as a dropdown
				-- when this option wants a strip, or the other way round.
				if (entry.kind == "select"
					and (control.segmented and true or false) ~= (wantsStrip and true or false)) then
					control = wantsStrip and Controls.CreateSegmented(content)
						or Controls.CreateDropdown(content)
				elseif (entry.kind == "input"
					and (control.multiline and true or false) ~= (wantsStrip and true or false)) then
					control = wantsStrip and Controls.CreateMultiline(content)
						or Controls.CreateInput(content)
				end

				local ok, err = pcall(Bind, control, entry.option, options, entry.path, self)
				if (not ok) then
					control:SetLabel(entry.kind .. " (failed)")
					control:SetHelp(tostring(err))
				end
			end

			self.controls[#self.controls + 1] = control
		end

		return self:Layout()
	end

	page.Restyle = function(self)
		for i, control in ipairs(self.controls) do
			control:Restyle()
		end
	end

	page.GetControls = function(self)
		return self.controls
	end

	page.GetSections = function(self)
		return self.sections or {}
	end

	return page
end

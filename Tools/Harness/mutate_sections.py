# Does the "which section is showing" check actually catch a broken indicator?
#
# Every one of these mutations is a way the mark could plausibly go wrong. The
# harness has to fail on all of them; a mutation that survives means the check
# is decoration.
import subprocess, sys, os, shutil, re

ADDON = r"C:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns\AzeriteUI5_JuNNeZ_Edition"
SP = os.path.dirname(os.path.abspath(__file__))
LUA = r"C:\Program Files (x86)\Lua\5.1\lua.exe"

PANEL = os.path.join(ADDON, "Options", "Kit", "Panel.lua")
PANELOPTS = os.path.join(ADDON, "Options", "Kit", "PanelOptions.lua")
CONTROLS = os.path.join(ADDON, "Options", "Kit", "Controls.lua")
RENDERER = os.path.join(ADDON, "Options", "Kit", "Renderer.lua")
KIT = os.path.join(ADDON, "Options", "Kit", "Kit.lua")
STUBS = os.path.join(SP, "stubs.lua")

# Mutating the changelog generator proves nothing until the data is generated
# again, so these run it. Options/Changelog.lua is restored afterwards.
CHANGEGEN = os.path.join(ADDON, "Tools", "BuildChangelog.lua")
CHANGELOG = os.path.join(ADDON, "Options", "Changelog.lua")
LUA = r"C:\Program Files (x86)\Lua\5.1\lua.exe"

MUTATIONS = [
    # Panel.lua
    (PANEL, "never marks anything",
     "\t\t\t\tactive = i\n", "\t\t\t\tactive = active\n"),
    (PANEL, "marks the section you have not reached yet",
     "row.offset <= scroll + 12", "row.offset >= scroll + 12"),
    (PANEL, "marks the first section it finds rather than the last",
     "\t\t\tif (row:IsShown() and row.offset and row.offset <= scroll + 12) then",
     "\t\t\tif (not active and row:IsShown() and row.offset and row.offset <= scroll + 12) then"),
    (PANEL, "no section at all above the first heading",
     "\t\tif (not active and rows[1] and rows[1]:IsShown()) then\n\t\t\tactive = 1\n\t\tend",
     "\t\tif (false) then\n\t\t\tactive = 1\n\t\tend"),
    (PANEL, "marks every section at once",
     "\t\trow.active = (i == active)", "\t\trow.active = (active ~= nil)"),
    (PANEL, "keeps marking a section while searching",
     "\tif (not self.searching) then", "\tif (true) then"),
    (PANEL, "forgets to record the label the rail shows",
     "\t\t\t\t\t\t\tsub.label = section.label\n", ""),
    (PANEL, "never redraws the mark when the page scrolls",
     "\t\tPanel:UpdateActiveSection()\n\tend)", "\tend)"),
    (PANEL, "crumb never grows its third step",
     'self.crumb:SetText(here and (self.crumbBase .. " > " .. here) or self.crumbBase)',
     "self.crumb:SetText(self.crumbBase)"),
    (PANEL, "crumb keeps the section it had when the page was opened",
     "\tif (not self.searching and self.crumbBase and self.crumb) then",
     "\tif (false and self.crumbBase and self.crumb) then"),
    (PANEL, "crumb goes on naming a section during a search",
     "\tif (not self.searching and self.crumbBase and self.crumb) then",
     "\tif (self.crumbBase and self.crumb) then"),
    (PANEL, "rail never follows the marked section down",
     "\t\tif (top < at) then\n\t\t\twant = top\n\t\telseif (height > 0 and top + 19 > at + height) then\n\t\t\twant = top + 19 - height\n\t\tend",
     "\t\tif (top < at) then\n\t\t\twant = top\n\t\tend"),
    (PANEL, "rail row remembers the page offset instead of its own",
     "\t\t\t\t\t\t\tsub.railOffset = offset\n", "\t\t\t\t\t\t\tsub.railOffset = section.offset\n"),
    # The sections stranded past the last scroll position.
    (PANEL, "no pinning, so the end of a page marks the wrong section",
     "\t\telseif (self.requestedSection) then", "\t\telseif (false) then"),
    (PANEL, "the click is never recorded",
     "\t\t\tPanel.requestedSection = index\n", ""),
    (PANEL, "the pin outlives the end of the page",
     "\t\tif (not atTheEnd) then\n\t\t\tself.requestedSection = nil\n\t\telseif (self.requestedSection) then",
     "\t\tif (false) then\n\t\t\tself.requestedSection = nil\n\t\telseif (self.requestedSection) then"),
    # SetTab now clears the same two fields with the same indentation, and it is
    # defined first, so these have to name the line above to hit SelectPage.
    (PANEL, "the pin survives moving to another page",
     "\tself.selected = key\n\tself.railClosed = nil\n\tself.requestedSection = nil",
     "\tself.selected = key\n\tself.railClosed = nil"),
    # The drawer.
    (PANEL, "the drawer never closes",
     "if (entry.key == self.selected and page and not self.railClosed) then",
     "if (entry.key == self.selected and page) then"),
    (PANEL, "clicking the open page reselects it instead of closing",
     "\tif (row.key == Panel.selected) then", "\tif (false) then"),
    (PANEL, "the drawer stays shut when you move to another page",
     "\tself.selected = key\n\tself.railClosed = nil\n\tself.requestedSection = nil",
     "\tself.selected = key\n\tself.requestedSection = nil"),
    # The Settings tab.
    (PANEL, "the tab never changes the table being read",
     '\tif (Panel.tab == "settings") then\n\t\treturn Kit.PanelOptions and Kit.PanelOptions.GetTable(), nil\n\tend\n\n',
     ""),
    (PANEL, "the tab button does nothing",
     "\t\t\tPanel:SetTab(self.key)", "\t\t\tlocal _ = self.key"),
    (PANEL, "only one tab is ever built",
     "\tfor index, info in ipairs(TABS) do", "\tfor index, info in ipairs({ TABS[1] }) do"),
    (PANEL, "no tab is ever marked selected",
     "\t\tbutton.selected = (button.key == self.tab)", "\t\tbutton.selected = false"),
    (PANEL, "switching tabs forgets where you were",
     "\tself.lastPage[self.tab] = self.selected", "\tself.lastPage[self.tab] = nil"),
    (PANEL, "the settings tab uses the addon's rail bands",
     '\tif (Panel.tab == "settings") then\n\t\treturn (Kit.PanelOptions and Kit.PanelOptions.Bands) or SECTIONS\n\tend\n',
     ""),
    (PANEL, "gems are counted on the settings tab too",
     '\t\t\t\tif (self.tab == "options") then', "\t\t\t\tif (true) then"),
    (PANEL, "setting a theme does not repaint the window",
     "\tself:ApplyTheme()\n\n\tif (Kit.Window) then Kit.Window:ApplyTheme() end",
     "\tif (Kit.Window) then Kit.Window:ApplyTheme() end"),
    # PanelOptions.lua
    (PANELOPTS, "every release is written to the same key",
     '\t\targs["release" .. index] = {', '\t\targs["release"] = {'),
    (PANELOPTS, "the theme picker is not on the page",
     '\t\ttheme = {\n\t\t\tname = L["Theme"],', '\t\ttheme = {\n\t\t\thidden = true,\n\t\t\tname = L["Theme"],'),
    (PANELOPTS, "the two pages are filed under one band",
     '\tappearance = "panel",\n\tchangelog = "about"', '\tappearance = "panel",\n\tchangelog = "panel"'),
    # Tools/BuildChangelog.lua
    # Removing only the ** rule is an equivalent mutant: the single-* rule that
    # follows it strips **bold** to bold on its own. The * rule is the one that
    # has to be there.
    (CHANGEGEN, "markdown emphasis is left in",
     '\ttext = text:gsub("%*(.-)%*", "%1")\n', ""),
    (CHANGEGEN, "code spans are left in",
     '\ttext = text:gsub("`(.-)`", "%1")\n', ""),
    # Text that does not fit.
    (RENDERER, "nothing is measured before it is placed",
     "\t\t\tif (control.Measure) then control:Measure(width) end\n", ""),
    (RENDERER, "the page is measured against no width at all",
     "\t\tlocal width = content:GetWidth() or 0", "\t\tlocal width = 0"),
    (CONTROLS, "a paragraph goes back to asking the FontString",
     "\t\tself.textHeight = MeasureText(GetFont(12), self.labelText, self.textWidth)",
     "\t\tself.textHeight = self.text:GetStringHeight()"),
    (CONTROLS, "a row ignores how tall its help line is",
     "\t\treturn ROW_HEIGHT + max(ROW_HELP_EXTRA, (self.helpHeight or 0) + 4)",
     "\t\treturn ROW_HEIGHT + ROW_HELP_EXTRA"),
    (CONTROLS, "the help line is clipped to one line again",
     "\thelp:SetWordWrap(true)", "\thelp:SetWordWrap(false)"),
    (CONTROLS, "the tooltip drops the help and shows only the label",
     "\t\tif (control.helpText) then", "\t\tif (false) then"),
    (CONTROLS, "the ruler measures at no width",
     "\truler:SetWidth(width)", "\truler:SetWidth(4000)"),
    (PANEL, "resizing the window does not lay the page out again",
     "\t\tif (page and page.width ~= width) then\n\t\t\tpage:Layout()",
     "\t\tif (false) then\n\t\t\tpage:Layout()"),
    # Opacity, theme and scale.
    (KIT, "opacity is not normalised, so 100% is not opaque",
     "\t\t\tfill[4] = (fill[4] or 1) / top * opacity", "\t\t\tfill[4] = (fill[4] or 1) * opacity"),
    (KIT, "the layering is flattened instead of scaled",
     "\t\t\tfill[4] = (fill[4] or 1) / top * opacity", "\t\t\tfill[4] = opacity"),
    (KIT, "a theme change forgets the opacity already set",
     "\t\tfor _, fill in ipairs(fills) do\n\t\t\tfill[4] = (fill[4] or 1) / top * opacity\n\t\tend",
     "\t\tfor _, fill in ipairs(fills) do\n\t\t\tfill[4] = (fill[4] or 1) / top\n\t\tend"),
    (PANEL, "setting the theme does not repaint the background",
     "\tframe:SetBackdropColor(unpack(Kit.WindowColor))", "\tlocal _ = Kit.WindowColor"),
    (PANEL, "the scale is not applied to the window",
     "\t\tframe:SetScale(value)", "\t\tlocal _ = value"),
    (PANEL, "the scale is not clamped",
     "\tvalue = min(self.MaxScale, max(self.MinScale, value))", "\tvalue = value"),
    (PANEL, "the scale is not remembered",
     "\t\tdb.global.optionsScale = value", "\t\tlocal _ = value"),
    # Types the panel cannot draw.
    (RENDERER, "an undrawable type goes missing silently again",
     '\t\tout[#out + 1] = {\n\t\t\tkind = "description",\n\t\t\tunsupported = kind,',
     '\t\tif (true) then return end\n\t\tout[#out + 1] = {\n\t\t\tkind = "description",\n\t\t\tunsupported = kind,'),
    (RENDERER, "the line does not name the type it wanted",
     'AsString(Config.GetName(option, options, childPath, APP), key), kind)',
     'AsString(Config.GetName(option, options, childPath, APP), key), "")'),
    # stubs.lua
    (STUBS, "[stub] every string is one line tall again",
     "\t\tlocal perLine = math.max(1, math.floor(width / CHAR_W))\n"
     "\t\tlocal lines = math.max(1, math.ceil(#text / perLine))",
     "\t\tlocal lines = 1"),
    (STUBS, "[stub] backdrop colours are not recorded",
     '\trawset(t, "SetBackdropColor", function(self, r, g, b, a)\n'
     '\t\trawset(self, "backdropColor", { r, g, b, a })\n'
     '\t\treturn self\n'
     '\tend)',
     '\trawset(t, "SetBackdropColor", function(self) return self end)'),
    (STUBS, "[stub] scroll range is a flat 4000 again",
     "\t\t\tlocal inner = child.GetHeight and child:GetHeight() or 0\n"
     "\t\t\tlocal outer = self:GetHeight() or 0\n"
     "\t\t\treturn math.max(0, inner - outer)",
     "\t\t\treturn 4000"),
    (STUBS, "[stub] scrolling is not clamped to the range",
     "\t\t\tself.scrollValue = math.max(0, math.min(range, value or 0))",
     "\t\t\tself.scrollValue = value or 0"),
    (STUBS, "[stub] unset fields read back as truthy no-ops again",
     '\tif (type(key) ~= "string" or not key:match("^%u")) then\n\t\treturn nil\n\tend\n\n',
     ""),
    # stubs.lua: the stub itself has to be honest, or none of the above bite.
    (STUBS, "[stub] Show does not make a frame shown",
     'rawset(t, "shownValue", true)\n\n\trawset(t, "Show"',
     'rawset(t, "shownValue", true)\n\n\trawset(t, "ShowX"'),
]


def run():
    p = subprocess.run([LUA, os.path.join(SP, "panel_harness.lua"), ".", SP],
                       cwd=ADDON, capture_output=True, text=True)
    out = (p.stdout or "") + (p.stderr or "")
    for line in out.splitlines():
        if "checks," in line and "failure" in line:
            return line.strip(), out
    return "harness did not finish", out


# "0 failures" as a substring also matches "10 failures", which reported a
# caught mutation as a survivor. Read the number.
def failures(result):
    m = re.search(r"(\d+) failures?", result)
    return int(m.group(1)) if m else -1


baseline, out = run()
print("baseline:", baseline)
if failures(baseline) != 0:
    print(out)
    sys.exit(1)

def regenerate():
    subprocess.run([LUA, os.path.join("Tools", "BuildChangelog.lua")],
                   cwd=ADDON, capture_output=True, text=True)


caught = 0
for path, label, old, new in MUTATIONS:
    src = open(path, encoding="utf-8").read()
    if old not in src:
        print("  MISSING  %-52s (mutation text not found)" % label)
        continue

    generated = (path == CHANGEGEN)
    backups = [path] + ([CHANGELOG] if generated else [])
    for f in backups:
        shutil.copyfile(f, f + ".bak")

    try:
        open(path, "w", encoding="utf-8").write(src.replace(old, new, 1))
        if generated:
            regenerate()
        result, _ = run()
        ok = failures(result) != 0
        caught += ok
        print("  %-8s %-52s %s" % ("caught" if ok else "SURVIVED", label, result))
    finally:
        for f in backups:
            shutil.copyfile(f + ".bak", f)
            os.remove(f + ".bak")

print("\n%d of %d mutations caught" % (caught, len(MUTATIONS)))
after, _ = run()
print("restored:", after)
if failures(after) != 0:
    sys.exit(1)

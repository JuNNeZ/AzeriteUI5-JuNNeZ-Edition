# Offline harnesses for the options panel and client compatibility

The custom options panel draws itself, so these are the only thing between a change and a broken
window. They run under plain Lua 5.1 against the addon's **real** option tables, with the WoW API
stubbed in `stubs.lua`.

Not shipped: `.pkgmeta` ignores `Tools`.

## Running them

From the addon root, with `lua.exe` 5.1 on the machine (`C:\Program Files (x86)\Lua\5.1\`):

```sh
lua Tools/Harness/panel_harness.lua        . Tools/Harness   # the window
lua Tools/Harness/kit_harness.lua          . Tools/Harness   # art, themes, controls
lua Tools/Harness/config_diff_harness.lua  . Tools/Harness   # Config vs the Ace3 library
lua Tools/Harness/real_options_harness.lua . Tools/Harness   # the real table, end to end
lua Tools/Harness/real_options_harness.lua . Tools/Harness Forever # unavailable settings hidden
lua Tools/Harness/client_harness.lua      .                # Retail/Forever detection, APIs, modules, menus
lua Tools/Harness/diel_harness.lua        .                # the Forever day and night indicator
lua Tools/Harness/combo_points_harness.lua .               # Forever secret combo points
lua Tools/Harness/chat_guard_harness.lua   .               # chat module stays out of chat replacements
```

Two arguments: the addon root, then this folder. Both harness files and `stubs.lua` are found
relative to the second.

`client_harness.lua` only needs the addon root. It executes real compatibility,
module and library files with deliberately missing client capabilities. It does
not emulate secret values or protected frame security; `/reload` and combat tests
on both clients remain required. See `Docs/CLIENT_COMPATIBILITY.md`.

`diel_harness.lua` also only needs the addon root. It slices the day and night
block straight out of `Components/Misc/Minimap.lua` - between its two section
comments - and runs that real source against a stubbed client, so it tests the
shipped file rather than a copy that drifts from it. Move those comments and it
fails loudly rather than silently testing nothing. It cannot see textures, frame
strata, Blizzard's Edit Mode or a real cycle transition.

`combo_points_harness.lua` also only needs the addon root. It runs the real oUF
ClassPower element, the real PlayerClassPower style and the real layout data against
a secret stand-in that reports as a number but throws on any arithmetic, ordering
comparison or indexing - Forever returns combo points that way even out of combat.
Its curve and StatusBar model Blizzard's documented Step and clamp behavior; they
are not the client. `mutate_client.lua` carries its mutations.

For client-aware API, UI-source, TOC/XML, and Forever game-data checks, use
[Hated WoW MCP](https://github.com/RdyGaming/hated-wow-mcp) with `flavor: "forever"`.
For isolated Lua 5.1 taint experiments, use `Tools/Run-Elune.ps1`. Neither tool
replaces the harnesses or live `/reload` testing.

Mutation runs — do the checks above actually catch a break?

```sh
python Tools/Harness/mutate.py . Tools/Harness     # Config.lua
python Tools/Harness/mutate_sections.py            # the panel, the kit, the controls, the stubs
lua Tools/Harness/mutate_client.lua .              # client gates, entirely in memory
```

`mutate_sections.py` runs the panel harness by default and the kit harness for the mutations that
name it - the window's own edge is measured against `Layouts/Data/Tooltips.lua`, which is a kit
check. Both are run clean first and again at the end.

`mutate_sections.py` has the addon root and the Lua path at the top of the file. It backs up every
file it edits and restores it, and prints `restored:` at the end — if that line is missing or shows
failures, check `git status` before doing anything else.

## The rule that matters

**A check that has never failed has never been shown to work.** Every group of checks gets a
mutation entry before it is trusted. This panel has now produced five separate stub lies, each of
which passed every check it should have failed:

| The stub said | It should have said |
| --- | --- |
| every font is valid | only the sizes `FontStyles.xml` defines |
| `IsShown()` is always false | what `Show`/`Hide`/`SetShown` were last told |
| any unset field is a no-op function | `nil`, unless the name starts with a capital |
| the scroll range is 4000, and scrolling never clamps | child height minus view height, clamped |
| every string is 12px tall | as many lines as it wraps to at that width |

Each one hid a real defect. When a check passes on the first run, suspect the stub.

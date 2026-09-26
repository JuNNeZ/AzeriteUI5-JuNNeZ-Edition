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
lua Tools/Harness/tracker_harness.lua      .               # Hide the Blizzard Tracker, Retail and Forever
lua Tools/Harness/locale_harness.lua       .               # all ten locales: parity, specifiers, widths
lua Tools/Harness/nameplate_harness.lua    .               # nameplates: named checks + golden snapshot
lua Tools/Harness/flyout_harness.lua       .               # LibActionButton flyout discovery, both clients
lua Tools/Harness/tooltip_compare_harness.lua .            # compare tooltips: borders and the Equipped tab
lua Tools/Harness/castbar_pushback_harness.lua .           # oUF castbar: the player's bar steps back on pushback
```

`castbar_pushback_harness.lua` loads the real `Libs/oUF/elements/castbar.lua` into its own environment and
drives the player's cast through a start and two pushbacks, a channel cut short, an empowered cast,
another unit's cast and a client without `C_DurationUtil` (GitHub #5, FixLog 2026-09-26). The bar is what
the element's own `OnUpdate` draws, the timer the last duration handed to `SetTimerDuration`; the
client's duration getters answer with the span the cast started with, as the reporter found Forever does
after a delay. It fails against the 5.10.2 element: the bar full before the cast ends, the timer on the
old span, the delay counted twice. Its mutations are the `castbar` entries in `mutate_client.lua`.

`tooltip_compare_harness.lua` loads the real `Components/Misc/Tooltips.lua` with its layout data and
`Core/API/ProtectedCall.lua`, and Blizzard's `TooltipComparisonManager` `Initialize` and
`AnchorShoppingTooltips` copied verbatim (the file is identical on Retail and Forever). Its frames
resolve their anchors to screen rectangles, so it measures what is drawn: the seam between two
tooltips' backdrops (negative is an overlap), whether the compare tooltips still line up with the
tooltip they compare against, and whether the "Equipped" tab's bottom edge lands inside the band where
each theme's border art is solid (measured from the art; see the file). Cases: both themes, either
side, one or two items, a scaled tooltip, the first compare of a session, a re-anchor, switched off and
on, secret anchoring and scale, no compare modifier. It fails against the 5.10.0 module (FixLog
2026-09-25). After 5.10.1 and the audit's first cut, the live client still drew compare tooltips edge to
edge although our hook on the manager had set the offsets, so `Compare` runs Blizzard's anchoring a second
time after the manager, as an unhooked copy calling the frames' own `SetPoint`; both of those versions
fail here on the seams, as they did live. The module now re-makes each join from a `SetPoint` post-hook
on the compare tooltip, and the checks require each compare tooltip to be held by its join alone (no
`TOP`), the join to still be ours a frame later (as `/azdebug tooltips` reports it), secret anchoring to
change nothing, other addons' anchors to be left alone, an embedded tooltip's top to stay level, and the
compare tooltips to take GameTooltip's scale. Hide in Combat's answers and the action bar refreshes are
checked here too. The rest of the tooltip audit runs against the same loaded module: the native
aura containers' `AuraButtonTooltip` styled through a fake `AuraContainerInbound` that validates the
documented `AuraContainerTooltipBackdropOptions` (per theme, theme change, switch off and on, off from
login, `Blizzard_AuraContainer` loading late, a refusal retried), aura spell IDs with no `UnitAura`
global (Retail and Forever have none), the unit name written to the tooltip the unit is on, and secret
health hiding the value text. It fails against the 5.10.1 module in every one of those areas. Its
mutations are the `tooltip` entries in `mutate_client.lua`.

`flyout_harness.lua` loads the whole of `Libs/LibActionButton-1.0-GE` as an upgrade over an older copy
with one button, because that runs `InitializeEventHandler` at load - the call the first `CreateButton`
makes, which with the player logged in discovers flyouts at once. It models the two ways a client
answers `GetFlyoutInfo` for an unknown ID: raising (Retail 12.1.0, Forever before 1.60.1.70009) and
returning nothing (Forever 1.60.1.70009's `C_Flyout`, `MayReturnNothing`). The second took every action
bar with it (FixLog 2026-09-25). The old button stops the load the moment it is touched, so button code
never runs against the stubs; reaching it is the proof that discovery finished. Its mutations are the
`flyout` entries in `mutate_client.lua`.

`nameplate_harness.lua` is the contract for the nameplate overhaul (`Docs/Nameplates Overhaul
Plan.md`). It loads the real module - every `NamePlates\*.lua` file, in the order
`Components/UnitFrames/UnitFrames.xml` lists them, so it also proves that order - with the layout
data, colours and interrupt database, against a fake of oUF's nameplate driver that does what
`Libs/oUF/ouf.lua:1000-1070` does, and walks eleven plates of every kind through a scripted session.
Some checks are about work rather than looks (a target change touches only the plates that changed,
nothing polls while nothing is hovered); they count widget calls, which the golden file cannot see. Three outputs: named checks for the behaviours
that must survive; `nameplate_golden.txt`, every plate's visible state after every step (only the
plates that changed are written); and `nameplate_metrics.txt`, widget calls and plates touched per
step. A deliberate behaviour change is a reviewed golden diff re-recorded with `--record`; a
performance change is checked with `--metrics` and re-recorded with `--record-metrics`. The fake
oUF elements copy what the real ones do to visibility (castbar hidden when idle, raid marker and
threat glow only when set), because the first draft showed all three on every plate and the golden
file was recording the stub. The fake castbar update does what oUF's `CastStart` does (a running cast
shown, none cleared and hidden), and each step ends with the frame boundary, oUF's OnUpdate hiding an
idle castbar. The golden cannot see what was on screen for the frame before that boundary, so a named
check does: no step may end with an idle castbar shown (FixLog 2026-09-25). Plates draw their auras through Blizzard's native `AuraContainer` on
Retail; the harness loads the real `Auras/PlayerAuraContainers.lua` against a fake container that
keeps the unit, the on/off state and how often it was told to re-read, and rejects the inputs
`Blizzard_CustomAuraContainer.lua` would (unknown filter tokens, candidate filters or layout keys).
Which auras it would show is the client's and is not modelled; which kinds a container asks for (the
Aura filters settings) is, group by group. Blizzard's stacking option is a fake bitfield CVar behind
`C_CVar.GetCVarBitfield` / `SetCVarBitfield`, so the passthrough's reads, writes and combat hold are
checked. The execute marker's tint goes through `UnitHealthPercent` with a step curve: the harness
evaluates the curve against a per-unit `healthPercent` and hands back a secret number that `type()`
calls a number but that raises on arithmetic or comparison, as the client's does, so a marker that
did maths on its answer would fail here. Standing down for another nameplate addon (`W.addons`) is
checked for CVar writes and reloads. The CVars are Retail 12.1's, by the names both clients have
(`nameplateShowFriendlyPlayers`, `nameplateShowFriendlyNpcs`, `nameplateSize` and so on), and a write to
any other is refused and counted, as the client refuses it; a named check holds the whole session to
none. A vendor that cannot be assisted and a follower companion (`UnitTreatAsPlayerForDisplay`) stand
for the friendly NPCs `UnitCanAssist` used to miss (FixLog 2026-09-25). It runs in its own environment so it cannot leave globals behind for the next harness in
`mutate_client.lua`.

`locale_harness.lua` loads every `Locale/*.lua` through a stub AceLocale instead of parsing it, so
it sees keys exactly as the client does - the `\n` keys a pattern once dropped included. It fails
when a locale lacks an enUS key or has an extra one, defines a key twice, leaves a value empty,
moves or changes a format specifier, or lets a preview explanation or tab label outgrow the panel.
The explanations are read out of `Options/Kit/Preview.lua` and the widths out of
`Options/Kit/Panel.lua`, so neither is a copy that can drift. Adding an enUS key fails it until the
nine translations are in.

`tracker_harness.lua` also only needs the addon root. It runs the real tracker module and
`Core/API/SecureDrivers.lua` against two Blizzard behaviours copied from source: a
`SecureHandlerStateTemplate` only runs snippets for `state-*` attributes, and a state driver's
`Hide()` on an already hidden frame fires no `OnHide`. The module used to be wrong about both. Its
mutations are the `tracker` entries in `mutate_client.lua`.

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

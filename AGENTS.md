# AGENTS.md

## AI Agent Operating Rules (Codex / Copilot)

These rules apply to any AI assistant working in this repository.

### Grounding (mandatory)
Before proposing or implementing changes:

1) Search the repository.
2) Read the relevant files fully.
3) Reference file paths explicitly in responses.
4) Quote small snippets if needed for clarity.

Never invent APIs, folders, or patterns.

If something is missing or unclear, add TODO markers and explicitly state which file(s) are required.

### Change Protocol (always follow)
1) Search → read files
2) Propose short plan (3–8 bullets)
3) Implement minimal diffs
4) Run `/reload` test loop
5) Summarize with:

- What changed
- Why
- How to test
- Files touched list

Prefer small, reviewable changes.  
Avoid refactors unless explicitly requested.

### Output expectations
- Patch-style answers preferred
- Minimal diffs
- Reload-safe code
- Defensive defaults
- No accidental globals
- End every task with:

**Files touched:**
- path — reason

If repo context is insufficient, STOP and ask.

---

## Purpose
Quick reference for AzeriteUI maintainers: project structure, debug/testing workflow, and WoW 12.0 secret-value handling.

Target:
- World of Warcraft AddOn
- Expansion: Midnight / WoW 12+
- Environment: VS Code + Codex + Copilot

---

## Installed Extension Tooling (Use All Available)

The current workspace has these WoW/Lua-relevant extensions installed and available:

- `ketho.wow-api` (WoW API annotations, LuaLS integration)
- `septh.wow-bundle` (WoW Lua/TOC language support + snippets)
- `stanzilla.vscode-wow-toc` (TOC grammar/snippets)
- `sumneko.lua` (Lua language server diagnostics/intellisense)
- `johnnymorganz.stylua` (Lua formatter)
- `actboy168.lua-debug` (Lua debugger)

### Required usage order for API and implementation work

1. Use repo code first (`rg`, read full files, existing patterns).
2. Use `ketho.wow-api` data (via MCP `wow-api` server when available).
3. Use local docs:
   - `Docs/API Framework.md`
   - `.research/api/API_CHANGES_12.0.0.md`
   - `.research/api/API_CHANGES_12.0.0_FULL.md`
4. Only then fall back to external wiki/forums.


### WoW MCP tools (Codex)
Use the `wow-api` MCP tools directly when available:

- `mcp__wow-api__lookup_api`
- `mcp__wow-api__search_api`
- `mcp__wow-api__get_namespace`
- `mcp__wow-api__get_event`
- `mcp__wow-api__get_enum`
- `mcp__wow-api__get_widget_methods`
- `mcp__wow-api__list_deprecated`

Do not treat `resources/list` as required success for this server. Some builds expose tools without implementing `resources/list`.

### Practical rules

- Prefer WoW API lookups from `ketho.wow-api` over memory.
- For `.toc` edits/validation, rely on WoW TOC language support (bundle + stanzilla).
- Keep Lua diagnostics clean under `sumneko.lua` assumptions (no accidental globals, defensive nil checks).
- Use Stylua formatting style only when a file is already using that flow or when explicitly requested.
- Use Lua debug extension for runtime reproduction workflows when interactive debugging is required.

### MCP note (`wow-api`)

- Server name: `wow-api`.
- In Codex sessions, MCP server launch may come from `~/.codex/config.toml` rather than only workspace `.vscode/mcp.json`.
- Keep `WOW_API_EXT_PATH` stable (prefer the extensions directory, not a version-pinned folder):
  - `C:\Users\Jonas\.vscode\extensions`
- Health check in this order:
  1. Call one real tool first (for example `mcp__wow-api__get_namespace` with `name="list"`).
  2. If needed, run `list_mcp_resources(server:"wow-api")` as secondary signal only.
- If unavailable, troubleshoot before continuing broad API assumptions:
  - verify `ketho.wow-api` extension path exists
  - verify MCP config command/env
  - restart MCP host/client after config changes

## Current Target Castbar Focus (from FixLog.md)

Latest log trend (2026-03-01): non-self target casts can still stall in pending/idle state when callback payload timing is missing or late.

When touching `Components/UnitFrames/Units/Target.lua`:
- Keep a single cast resolver + single renderer path (avoid competing branches).
- Treat callback duration payload as primary source, with explicit documented fallback order.
- Keep secret-safe handling: no addon-side arithmetic on secret values.
- Validate with `/azdebug dump target` and confirm cast fake source/path transitions are live, not pinned to pending.

Always append each castbar iteration to `FixLog.md` before and after changes.

---

## Project Structure (Where Stuff Is)

- **Core/**: Addon bootstrap, shared utilities, Blizzard bug guards, and compatibility.
  - `Core/FixBlizzardBugs.lua`: All WoW 12+ secret-value fixes and Blizzard UI workarounds.
  - `Core/Debugging.lua`: Debug menu, chat commands, and all debug toggles.
  - `Core/EditMode.lua`, `Core/MovableFrameManager.lua`: Edit Mode and frame movement logic (be careful with protected calls).

- **Components/**: Feature modules.
  - `Components/UnitFrames/Units/`: Per-unit layout logic (Player, Target, ToT, etc). Castbar, orientation, and texture fixes.
  - `Components/Auras/`: Aura and nameplate logic.
  - `Components/ActionBars/`, `Components/Misc/`: Other feature modules.

- **Options/**: Config UIs and profile management.
- **Assets/**: Media (textures, fonts).
- **Layouts/**: Layout presets and placement.
- **Libs/**: Embedded libraries.
- **WoW11/**: Compatibility for earlier WoW versions.

- **FixLog.md**: Running log of current version work. ALWAYS update this first for new bugs/fixes.
  - **FixLog_Archive_20260303.md**: Historical entries (14,673 lines) through 2026-03-03. Reference for deep history.
  - Fresh log starts with v5.2.216-JuNNeZ as baseline.

- **.research/api/API_CHANGES_12.0.0.md**
- **.research/api/API_CHANGES_12.0.0_FULL.md**

These contain WoW 12 API + secret-value best practices.

---

## Secret-Value Best Practices (WoW 12+)

- Never do arithmetic, comparisons, concatenation, or boolean tests on secret values.
- You may pass secret values into Blizzard widgets, but never use them in addon logic.
- Always sanitize with `issecretvalue`.
- Use cached numeric fallbacks when needed.
- Avoid wrapping protected functions (e.g., secureexecuterange).
- Do NOT override EditModeManagerFrame methods unless taint safety is proven.

Assume everything touching unit data can become secret.

---

## Where to Fix What

- **Blizzard UI errors / secret crashes**
  → `Core/FixBlizzardBugs.lua`

- **Unit frame layout / castbars / textures**
  → `Components/UnitFrames/Units/`

- **Auras / nameplates**
  → `Components/Auras/` and `Core/FixBlizzardBugs.lua`

- **Config / UI**
  → `Options/`

- **Edit Mode side effects**
  → `Core/EditMode.lua`
  → `Core/MovableFrameManager.lua`

Prefer local fixes over global overrides.

---

## Coding Standards (WoW Lua)

### Safety
- Avoid globals. Use locals, addon namespace tables, or existing module patterns.
- Respect TOC load order.
- SavedVariables:
  - Initialize defensively
  - Version schemas
  - Handle fresh installs + upgrades
- Debug logging must be toggleable and quiet by default.

### Style
- Small functions
- Early returns
- Avoid deep nesting
- Follow existing naming conventions
- Public APIs must be documented inline

---

## Debugging & Testing

Enable Dev Mode in AzeriteUI options (`enableDevelopmentMode`).

### `/azdebug`
Opens debug menu with toggles:

- Health debug
- Health debug chat
- Statusbar/orb debug
- FixBlizzardBugs debug
- Health filter (prefix)
- Dump buttons: Target, Player, ToT, All bars
- Utilities:
  - Print Status
  - Enable Blizzard AddOns
  - Enable Script Errors
  - Scale Status
  - Reset UnitFrame Scales
- Secret value test (unit input)

Subcommands:

- `/azdebug health [on|off|toggle]`
- `/azdebug healthchat [on|off|toggle]`
- `/azdebug bars [on|off|toggle]`
- `/azdebug fixes [on|off|toggle]`
- `/azdebug dump [target|player|tot|all]`
- `/azdebug blizzard enable`
- `/azdebug scale [reset]`
- `/azdebug scripterrors`
- `/azdebug secrettest [unit]`

BugGrabber/BugSack:
- `/buggrabber reset` before testing

Edit Mode bypass:
FixBlizzardBugs can temporarily hide PRD + EncounterWarnings.

---

## Modern Testing Checklist

1. `/reload` after every change.
2. Reproduce with ONLY AzeriteUI enabled.
3. Check FixLog.md before touching code.
4. Log full stack + locals in FixLog.md for new bugs.
5. Apply smallest possible fix.
6. Test Edit Mode.
7. Verify:
   - Castbars
   - Auras
   - Nameplates
   - Player / Target / ToT
8. Check BugSack counts:
   - “Generated” for current session
   - “Time” for first occurrence
9. Update FixLog.md after each iteration.

---

## TOC / Interface Notes

Prefer placeholder interface tokens (e.g. `@toc-version-midnight@`) where supported.

To retrieve interface number in-game:

/dump select(4, GetBuildInfo())


---

## Release Output Path

For release packaging tasks, always place release archives in:

`C:\Users\Jonas\OneDrive\Skrivebord\azeriteui_fan_edit\`

Do not default to workspace temp folders or other desktop paths unless explicitly requested.

---

## Version Management (JuNNeZ Edition)

**MANDATORY: Update version number BEFORE every release build.**

### Files to update:
1. `AzeriteUI.toc` — Line with `## Version:`
2. `AzeriteUI_Vanilla.toc` — Line with `## Version:`
3. `build-release.ps1` — `$Version` variable (line ~8)

### Versioning scheme:
- **Patch fixes (bugs):** Increment third number → `5.2.211` → `5.2.212`
- **Minor features:** Increment second number → `5.2.x` → `5.3.0`
- **Major overhauls:** Increment first number → `5.x.x` → `6.0.0`
- **Always append:** `-JuNNeZ` to maintain edition branding

### Example update workflow:
1. Determine change type (patch/minor/major)
2. Update version in both TOC files
3. Update version in build script
4. Update `Docs/Release/CHANGELOG.md` with **ONLY** changes since previous version
5. Update FixLog.md with new version entry
6. Run `build-release.ps1`
7. Verify filename includes new version number

### Release notes policy (MANDATORY)
- Changelog/release notes must be **delta-only** per version.
- Include only fixes/features introduced since the last released version.
- Do **not** repeat older items from earlier versions in the new release entry.
- If needed, keep old items in previous sections, but never duplicate them in the latest section.

### Current version tracking:
- **Latest:** 5.2.212-JuNNeZ
- **Last updated:** 2026-03-02
- **Next planned:** 5.2.213-JuNNeZ (future fixes)

---

## Final Rule

For ANY new bug or feature:

Start with FixLog.md  
Reproduce clean  
Apply minimal fix  
Document everything  

When in doubt: smaller changes, local scope, written evidence.

You are debugging Blizzard as much as AzeriteUI.


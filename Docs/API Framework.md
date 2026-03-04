
# AzeriteUI API Framework

Welcome to the AzeriteUI API Framework documentation! This guide is your one-stop resource for understanding, using, and contributing to AzeriteUI’s API usage and defensive patterns in World of Warcraft 12+ (Midnight). Whether you’re a new contributor or a seasoned maintainer, you’ll find practical advice, best practices, and real-world examples here.

---

## Table of Contents

1. [Introduction](#introduction)
2. [Quick Reference & FAQ](#quick-reference--faq)
3. [Glossary](#glossary)
4. [API Version & Deprecation Notes](#api-version--deprecation-notes)
5. [Widget Method Reference](#widget-method-reference)
6. [Event Reference Table](#event-reference-table)
7. [Defensive Patterns & Secret Value Handling](#defensive-patterns--secret-value-handling)
8. [Practical Examples](#practical-examples)
9. [Pro Tips](#pro-tips)
10. [Troubleshooting & Debugging](#troubleshooting--debugging)
11. [Security & Taint Safety](#security--taint-safety-best-practices)
12. [Contribution Guidelines](#contribution-guidelines-for-api-usage)
13. [API Change Tracking](#api-change-tracking-table)
14. [Testing Checklist](#testing-checklist)

---

## Introduction

AzeriteUI is a modern, secure, and highly customizable World of Warcraft UI AddOn. This document details:

- Which Blizzard APIs are used and why
- How to handle secret values and protected functions
- Defensive coding patterns for WoW 12+
- Best practices for taint safety, debugging, and contribution

Use this as both a reference and a living guide—update it as AzeriteUI evolves!

---

## Quick Reference & FAQ

**Q: How do I check if a value from the API is safe to use?**
> Always use `issecretvalue(value)` before using any API return in logic, math, or as a table index. Secret values can be passed to Blizzard widgets, but not used in custom calculations.

**Q: Where can I find the official documentation for an API?**
> See the [WoW API Main](https://warcraft.wiki.gg/wiki/World_of_Warcraft_API) and links in the tables below.

**Q: What’s the difference between a widget method and a global API?**
> Widget methods (e.g., `StatusBar:SetValue`) must be called on a widget instance, not as a global function.

**Q: What’s new or changed in WoW 12+?**
> Many APIs now return secret values. Some legacy APIs are removed or moved to C_ namespaces. See version notes below.

---

## Glossary

**Secret Value:** A value returned by the WoW API that cannot be used in logic, math, or as a table index. Must be checked with `issecretvalue`.

**Widget:** A UI element (e.g., StatusBar, Button, Minimap) that exposes instance methods for manipulation.

**Instance Method:** A function called on a specific widget or object (e.g., `statusbar:SetValue`).

**Taint:** Contamination of secure execution paths by addon code, leading to UI errors or blocked actions.

**Protected Function:** A Blizzard API function that cannot be called or wrapped by addons, especially in combat.

**C_ Namespace:** Blizzard convention for new/secure API namespaces (e.g., `C_UnitAuras`).

---

## API Version & Deprecation Notes

**Secret Value:** A value returned by the WoW API that cannot be used in logic, math, or as a table index. Must be checked with `issecretvalue`.

**Widget:** A UI element (e.g., StatusBar, Button, Minimap) that exposes instance methods for manipulation.

**Instance Method:** A function called on a specific widget or object (e.g., `statusbar:SetValue`).

**Taint:** Contamination of secure execution paths by addon code, leading to UI errors or blocked actions.

**Protected Function:** A Blizzard API function that cannot be called or wrapped by addons, especially in combat.

**C_ Namespace:** Blizzard convention for new/secure API namespaces (e.g., `C_UnitAuras`).

---

## Widget Method Reference

**Common Errors:**

- “attempt to perform arithmetic on a secret value”: You used a secret value in math or logic. Always check with `issecretvalue`.
- “blocked action: taint detected”: Addon code touched a protected function or frame. Review recent changes and FixLog.md.

**Debug Workflow:**

1. Enable `/azdebug` and development mode in AzeriteUI options.
2. Use BugSack/BugGrabber to capture errors.
3. Check FixLog.md for recent issues and update it with new findings.
4. Use `/reload` after changes and reproduce the bug with only AzeriteUI enabled.
5. Log stack traces and locals for new bugs.

**When to Update FixLog.md:**

- After every new bug, hypothesis, or fix attempt.
- When adding or removing API usage.

---

## Event Reference Table

-- Always check new APIs with wow_api and Blizzard documentation.
-- Update this document with every new API, usage note, or defensive pattern.
-- Add practical usage examples for new APIs.
-- Note version/deprecation status for all APIs.
-- Use defensive patterns for all unit data and event handling.

---

## Defensive Patterns & Secret Value Handling

**Full Defensive UnitFrame Update Loop:**

```lua
local function UpdateUnitFrame(frame, unit)
  local health = UnitHealth(unit)
  local maxHealth = UnitHealthMax(unit)
  if issecretvalue(health) or issecretvalue(maxHealth) then
    health, maxHealth = 0, 1
  end
  frame.HealthBar:SetMinMaxValues(0, maxHealth)
  frame.HealthBar:SetValue(health)
end
```

**Edit Mode Change Handling:**

```lua
local function OnEditModeLayoutsUpdated()
  -- Refresh layout or reposition frames
end
frame:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED")
frame:SetScript("OnEvent", function(self, event)
  if event == "EDIT_MODE_LAYOUTS_UPDATED" then
    OnEditModeLayoutsUpdated()
  end
end)
```

**Safe Event Registration/Unregistration:**

```lua
frame:RegisterEvent("UNIT_HEALTH")
frame:SetScript("OnEvent", function(self, event, ...)
  if event == "UNIT_HEALTH" then
    UpdateUnitFrame(self, ...)
  end
end)
-- On frame hide or disable:
frame:UnregisterEvent("UNIT_HEALTH")
```

---

## Practical Examples

| Date | AzeriteUI Version | API | Change Summary |
| ------ | ------------------- | ----- | --------------- |
| 2026-02-24 | Midnight | C_UnitAuras.GetUnitAuras | Confirmed usage, added defensive patterns |
| 2026-02-24 | Midnight | issecretvalue | Added for WoW 12+ secret value compliance |
| 2026-02-24 | Midnight | C_CVar.GetCVar | Updated to use C_ namespace |

---

## Pro Tips

- **Use `SetTexCoord` for Mirroring:** Flip status bar textures horizontally or vertically for custom fill effects without relying solely on `SetReverseFill`.
- **Combine `SetReverseFill` and Flipped Textures:** For perfect mirrored layouts, use both a flipped texture and `SetReverseFill(true)`.
- **Leverage `pcall` for Risky Calls:** Wrap any API call that might fail or taint in `pcall` to prevent UI breakage.
- **Use Defensive Defaults:** Always provide a fallback value (e.g., 0 or "?") for any UI element that could receive a secret or nil value.
- **Batch Event Registration:** Register multiple events at once with a table and a loop to keep code DRY and maintainable.
- **Profile with `C_AddOnProfiler`:** Use `C_AddOnProfiler.GetAddOnMetric` to monitor performance and catch regressions early.
- **Debug with `/azdebug` and BugSack:** Use all available debug tools and always check FixLog.md after changes.
- **Check for Taint Early:** If you see odd UI behavior, run `/fstack` and check for taint before it becomes a bigger issue.
- **Read API Change Logs:** Always check [API Change Summaries](https://warcraft.wiki.gg/wiki/API_change_summaries) after a patch for silent API changes.
- **Document Everything:** If you discover a new trick, bug, or workaround, add it to this doc and FixLog.md for future maintainers.

---

## Troubleshooting & Debugging

- Reproduce with only AzeriteUI enabled and run `/reload` after changes.
- Use BugSack/BugGrabber to capture full stack traces; add the trace to `FixLog.md`.
- If you see "attempt to perform arithmetic on a secret value": find the offending value, wrap checks with `issecretvalue`, and provide a defensive fallback.
- For "blocked action" / taint errors: run `/fstack` to locate the tainted frame, rollback recent changes touching Blizzard frames, and avoid wrapping protected functions.
- Event-related issues: ensure proper `RegisterEvent`/`UnregisterEvent` usage and guard handlers with early returns for invalid input.
- Visual glitches: verify texture UVs with `GetTexCoord()` and test `SetRotation`/`SetTexCoord` combinations on representative textures.

- Never call, wrap, or override protected functions (see Blizzard’s protected list).
- Avoid touching Blizzard-provided frames unless explicitly allowed.
- Always use widget instance methods, not globals.
- Register and unregister events properly to avoid leaks and taint.
- Use `pcall` for risky API calls or debug code when appropriate.
- Log and investigate any taint or blocked action errors immediately; record fixes in `FixLog.md`.

---

## Texture Coordinates & SetTexCoord

Texture coordinates (UVs) control which portion of a texture is shown by a `Texture` object. Use `SetTexCoord` to flip, crop, or remap textures without modifying the underlying texture asset.

- Common parameter forms:
  - `texture:SetTexCoord(u1, v1, u2, v2)` — 4-arg shorthand defining the top-left (`u1`,`v1`) and bottom-right (`u2`,`v2`) UV corners.
  - `texture:SetTexCoord(uTL, vTL, uBL, vBL, uTR, vTR, uBR, vBR)` — 8-arg form specifying each corner (top-left, bottom-left, top-right, bottom-right).

- Practical examples:

```lua
-- Crop an icon to remove border (common for ability icons)
icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

-- Flip horizontally
tex:SetTexCoord(1, 0, 0, 1)

-- Flip vertically
tex:SetTexCoord(0, 1, 1, 0)

-- Mirror a statusbar texture and reverse fill for mirrored progress
local tex = statusBar:GetStatusBarTexture()
tex:SetTexCoord(1, 0, 0, 1)
statusBar:SetReverseFill(true)
```

- Notes & gotchas:
  - `GetTexCoord()` returns the same number of values that were set (4 or 8), use them when restoring state.
  - Not all textures tile/rotate identically — test with `StatusBar:SetRotatesTexture`, `TextureBase:SetRotation`, and `Texture:SetTexCoord` combinations when using rotated or tiled textures.
  - When flipping textures for mirrored layouts prefer using the status bar API (`SetReverseFill`) in combination with `SetTexCoord` for predictable fill behavior.
  - Avoid doing arithmetic on UV values from unknown sources unless sanitized; they are plain numbers but may interact strangely with tiling.

---

### Advanced: Rotation + TexCoord for Reversed Fill (Secret-value safe)

This pattern is useful when you want a status bar (health/power) to appear mirrored or rotated while avoiding any interaction with secret values. The implementation only changes visual state via widget setters (`SetTexCoord`, `SetRotation`, `SetReverseFill`) and does not read or compute on unit-provided values.

- Why this is safe:
  - You never read bar values like `GetValue()` or `Unit*` returns for logic or math — you only call visual setters on widget objects, which Blizzard allows even when values are secret.
  - Avoids taint because it does not wrap or override protected functions or change secure handlers.

- Example: mirror a bar and rotate 180° for a reversed, rotated appearance

```lua
local function MirrorAndRotateStatusBar(bar)
  if not bar or not bar.GetStatusBarTexture then return end

  local tex = bar:GetStatusBarTexture()
  if not tex then return end

  -- Save original state for restoration (local to addon)
  local originalTexCoords = { tex:GetTexCoord() }
  local originalRotation = tex.GetRotation and tex:GetRotation() or nil
  local originalReverse = bar.GetReverseFill and bar:GetReverseFill() or nil

  -- Mirror horizontally
  tex:SetTexCoord(1, 0, 0, 1)
  -- Reverse fill so the visual fill direction matches the mirrored texture
  if bar.SetReverseFill then bar:SetReverseFill(true) end
  -- Rotate 180 degrees (math.pi radians) if supported
  if tex.SetRotation then tex:SetRotation(math.pi) end

  -- Return a restore function that re-applies the captured state
  return function()
    if tex and tex.SetTexCoord and #originalTexCoords > 0 then
      tex:SetTexCoord(unpack(originalTexCoords))
    end
    if bar and bar.SetReverseFill and originalReverse ~= nil then
      bar:SetReverseFill(originalReverse)
    end
    if tex and tex.SetRotation and originalRotation then
      tex:SetRotation(originalRotation)
    end
  end
end

-- Usage:
-- local restore = MirrorAndRotateStatusBar(targetFrame.HealthBar)
-- ...later: if restore then restore() end
```

- Additional notes:
  - `TextureBase:GetTexCoord()` may return 4 or 8 values depending on how the texture was configured; capture them with `{ tex:GetTexCoord() }` and `unpack` when restoring.
  - `TextureBase:SetRotation(radians)` expects radians; use `math.pi` for 180°.
  - If `SetRotation` is not available or you need a 90°-style rotation on a texture that doesn't support rotation, you can remap corners with the 8-arg `SetTexCoord` form to emulate rotation.
  - Only store and restore visual state from values you captured earlier in your addon; do not use captured unit-related secret values in logic.

---

---

## Security & Taint Safety Best Practices

Security and taint safety are critical. Follow these concise rules:

- Treat any value from unit APIs as potentially secret. Use `issecretvalue()` before using values in logic, math, or as table keys.
- Prefer passing secret values directly into Blizzard widget setters (e.g., `statusBar:SetValue`) instead of extracting and operating on them in addon code.
- Never perform arithmetic, concatenation, or boolean logic on secret values.
- Avoid wrapping or replacing Blizzard secure functions or handlers; do visual-only changes (textures, UVs, rotation, colors) when possible.
- Keep SavedVariables defensive and versioned. Migrate schemas on load if necessary.
- Test in three configurations: (1) `/reload` with AzeriteUI only, (2) in-combat UI interactions, (3) with common conflicting addons disabled.

Checklist:

- [ ] `/reload` after every change
- [ ] Test with only AzeriteUI enabled
- [ ] Use `/azdebug` and debug toggles
- [ ] Trigger all relevant events (health, auras, action bars, edit mode)
- [ ] Check BugSack/BugGrabber for errors
- [ ] Review FixLog.md for new issues
- [ ] Validate no secret value or taint errors
- [ ] Update documentation and FixLog.md as needed

---

## Contribution Guidelines for API Usage

Contributions should be small, documented, and defensive. Follow this workflow:

1. Search the repo for existing patterns related to your change and read `FixLog.md` for context.
2. Propose a short plan in the PR description (3–6 bullets) describing what you will change and why.
3. Implement minimal, reviewable diffs that avoid changing unrelated files.
4. Add unit/integration-like manual test steps (reload loop and event triggers) in the PR description.
5. Run `/reload` and test with only AzeriteUI enabled; include BugSack stacks for any errors.

Guidelines for API usage:

- Always prefer instance widget setters over extracting and reusing API-returned values in logic.
- Use `issecretvalue` / `scrubsecretvalues` for defensive handling of new APIs in WoW 12+.
- Keep debug logging toggleable and quiet by default.

Example: flipping a statusbar texture to reverse visual fill

If you want your targetframe's bar to fill right-to-left without relying on Blizzard's `SetReverseFill`, you can use a horizontally flipped texture. This is done by setting the texture's TexCoord to flip it, or by using a pre-flipped asset.

#### Example: Flipping a StatusBar Texture

```lua
-- Assume 'statusbar' is your StatusBar widget
local texture = statusbar:GetStatusBarTexture()
-- Flip the texture horizontally (left-to-right becomes right-to-left)
texture:SetTexCoord(1, 0, 0, 1)
```

This will visually reverse the fill direction of the bar, even if you use the default left-to-right fill logic. You can combine this with custom textures for more advanced effects.

#### Notes

- You do not need to call `SetReverseFill` if you flip the texture; the bar will appear to fill in the opposite direction.
- Make sure your texture is symmetrical or designed to look correct when flipped.
- If you want to flip vertically, use `SetTexCoord(0, 1, 1, 0)`.
- This technique works for any StatusBar, including targetframe, castbar, or power bar.

## API Change Tracking Table
Maintain the API Change Tracking Table by adding a single row per API change with date, scope, and reason. When deprecating an API, note the replacement and any defensive patterns required.

Use FixLog.md for runtime errors and this table for long-term API tracking.
## Testing Checklist
Use this checklist to validate changes before submitting:

- Run `/reload` after each edit and reproduce the issue or verify the fix.
- Test with only AzeriteUI enabled.
- Trigger relevant events (UNIT_HEALTH, UNIT_POWER_UPDATE, UNIT_AURA, PLAYER_TARGET_CHANGED, EDIT_MODE_LAYOUTS_UPDATED).
- Check BugSack/BugGrabber for stack traces and add new entries to `FixLog.md`.
- Ensure no secret-value arithmetic or taint errors appear in the logs.
- Verify visual changes across multiple UI scales and layouts.

**Q: How do I check if a value from the API is safe to use?**
> Always use `issecretvalue(value)` before using any API return in logic, math, or as a table index. Secret values can be passed to Blizzard widgets, but not used in custom calculations.

**Q: Where can I find the official documentation for an API?**
> See the [WoW API Main](https://warcraft.wiki.gg/wiki/World_of_Warcraft_API) and links in the tables below.

**Q: What’s the difference between a widget method and a global API?**
> Widget methods (e.g., `StatusBar:SetValue`) must be called on a widget instance, not as a global function.

**Q: What’s new or changed in WoW 12+?**
> Many APIs now return secret values. Some legacy APIs are removed or moved to C_ namespaces. See version notes below.

---

## API Version & Deprecation Notes

| API | Link | Version | Notes |
| ----- | ------ | --------- | ------- |
| UnitHealth | [UnitHealth](https://warcraft.wiki.gg/wiki/API_UnitHealth) | Mainline, Vanilla, Mists | Returns secret values in 12+ |
| UnitHealthMax | [UnitHealthMax](https://warcraft.wiki.gg/wiki/API_UnitHealthMax) | Mainline, Vanilla, Mists | |
| UnitPower | [UnitPower](https://warcraft.wiki.gg/wiki/API_UnitPower) | Mainline, Vanilla, Mists | |
| UnitPowerMax | [UnitPowerMax](https://warcraft.wiki.gg/wiki/API_UnitPowerMax) | Mainline, Vanilla, Mists | |
| C_UnitAuras.GetUnitAuras | [GetUnitAuras](https://warcraft.wiki.gg/wiki/API_C_UnitAuras.GetUnitAuras) | Mainline, Mists | |
| C_UnitAuras.GetAuraDataByIndex | [GetAuraDataByIndex](https://warcraft.wiki.gg/wiki/API_C_UnitAuras.GetAuraDataByIndex) | Mainline, Vanilla, Mists | |
| issecretvalue | [issecretvalue](https://warcraft.wiki.gg/wiki/API_issecretvalue) | Mainline | WoW 12+ only |
| scrubsecretvalues | [scrubsecretvalues](https://warcraft.wiki.gg/wiki/API_scrubsecretvalues) | Mainline | WoW 12+ only |
| hasanysecretvalues | [hasanysecretvalues](https://warcraft.wiki.gg/wiki/API_hasanysecretvalues) | Mainline | WoW 12+ only |
| C_Secrets.ShouldUnitPowerMaxBeSecret | [ShouldUnitPowerMaxBeSecret](https://warcraft.wiki.gg/wiki/API_C_Secrets.ShouldUnitPowerMaxBeSecret) | Mainline | WoW 12+ only |
| C_Spell.GetSpellCooldown | [GetSpellCooldown](https://warcraft.wiki.gg/wiki/API_C_Spell.GetSpellCooldown) | Vanilla, Mists | |
| C_Spell.GetSpellCharges | [GetSpellCharges](https://warcraft.wiki.gg/wiki/API_C_Spell.GetSpellCharges) | Vanilla, Mists | |
| C_ActionBar.GetActionCooldown | [GetActionCooldown](https://warcraft.wiki.gg/wiki/API_C_ActionBar.GetActionCooldown) | Vanilla, Mists | |
| C_ActionBar.GetActionCharges | [GetActionCharges](https://warcraft.wiki.gg/wiki/API_C_ActionBar.GetActionCharges) | Vanilla, Mists | |
| C_Item.GetItemCount | [GetItemCount](https://warcraft.wiki.gg/wiki/API_C_Item.GetItemCount) | Mainline, Vanilla, Mists | |
| C_EditMode.GetLayouts | [GetLayouts](https://warcraft.wiki.gg/wiki/API_C_EditMode.GetLayouts) | Mainline, Mists | |
| C_AddOns.GetAddOnInfo | [GetAddOnInfo](https://warcraft.wiki.gg/wiki/API_C_AddOns.GetAddOnInfo) | Mainline, Vanilla, Mists | |
| C_CVar.GetCVar | [GetCVar](https://warcraft.wiki.gg/wiki/API_C_CVar.GetCVar) | Mainline, Vanilla, Mists | Use C_CVar namespace in 12+ |

---

## Widget Method Reference

| Widget Type | Key Methods |
| ------------- | ------------ |
| StatusBar | SetValue, SetMinMaxValues, SetStatusBarColor, SetOrientation, SetReverseFill |
| Button | SetScript, SetAttribute |
| Texture | SetTexture |
| Cooldown | SetCooldown |
| Minimap | SetMaskTexture, SetBlipTexture, SetZoom, GetZoom |
| FontString | SetText |

---

## Event Reference Table

| Event | Description |
| ------- | ------------- |
| UNIT_HEALTH | Fired when a unit’s health changes |
| UNIT_POWER_UPDATE | Fired when a unit’s power changes |
| UNIT_AURA | Fired when a unit’s auras change |
| PLAYER_TARGET_CHANGED | Fired when the player’s target changes |
| ACTIONBAR_SLOT_CHANGED | Fired when an action bar slot changes |
| ACTIONBAR_UPDATE_COOLDOWN | Fired when action bar cooldowns update |
| BAG_UPDATE_COOLDOWN | Fired when bag item cooldowns update |
| NAME_PLATE_UNIT_ADDED | Fired when a nameplate is shown |
| NAME_PLATE_UNIT_REMOVED | Fired when a nameplate is hidden |
| EDIT_MODE_LAYOUTS_UPDATED | Fired when edit mode layouts change |
| PLAYER_ENTERING_WORLD | Fired when entering the world |

---

## More Secret Value Handling Examples

**Defensive Aura Table Iteration:**

```lua
local auras = C_UnitAuras.GetUnitAuras(unit, "HELPFUL")
if hasanysecretvalues(auras) then
  auras = scrubsecretvalues(auras)
end
for _, aura in ipairs(auras) do
  -- Display aura.icon, aura.duration, etc.
end
```

**Charge Overlay Fallback:**

```lua
local charges = C_Spell.GetSpellCharges(spellID)
if charges and not issecretvalue(charges.currentCharges) then
  button.Count:SetText(charges.currentCharges)
else
  button.Count:SetText("")
end
```

**Smoothing Fallback:**

```lua
local health = UnitHealth(unit)
if issecretvalue(health) then
  -- skip smoothing, set instantly
  statusbar:SetValue(0)
else
  -- safe to animate
  AnimateBarTo(health)
end
```

---

## Common Pitfalls

- **Using secret values in math or logic:** Always check with `issecretvalue` before any calculation or comparison.
- **Assuming widget methods are global:** Always call widget methods on the correct instance (e.g., `statusbar:SetValue`).
- **Using removed or legacy APIs:** Check version notes and use C_ namespaces where required.
- **Forgetting to sanitize tables:** Use `scrubsecretvalues` before iterating aura or data tables.
- **Not unregistering events:** Always unregister events to avoid leaks or taint.

---

## Table of Contents

1. [Introduction](#introduction)
2. [How AzeriteUI Uses oUF](#how-azeriteui-uses-ouf)
3. [Protected Functions: What We Check and How We Fix](#protected-functions-what-we-check-and-how-we-fix)
4. [oUF Tag Usage and Defensive Patterns](#ouf-tag-usage-and-defensive-patterns)
5. [WoW 12.0.0.x API Changes & AddOn Restrictions](#wow-12000x-api-changes--addon-restrictions)
6. [StatusBar Growth, Orientation, and Smoothing](#statusbar-growth-orientation-and-smoothing-wow-12)
7. [AzeriteUI: Defensive Patterns & Examples](#azeriteui-defensive-patterns--examples)
8. [API Reference: Commonly Used Functions](#api-reference-commonly-used-functions-azeriteui)
9. [Best Practices for AzeriteUI Developers](#best-practices-for-azeriteui-developers)
10. [Further Reading](#further-reading)

---

## Introduction

This document provides a comprehensive reference for AzeriteUI’s API usage, defensive coding patterns, protected function handling, and oUF integration for World of Warcraft 12+.

---

## How AzeriteUI Uses oUF

AzeriteUI leverages the oUF framework to manage unit frames and retrieve unit-related data (health, power, auras, threat, etc.).

### AzeriteUI oUF Integration Details

AzeriteUI uses the oUF framework as its core engine for unit frame management, data retrieval, and event-driven updates. This integration allows AzeriteUI to focus on layout, appearance, and user experience, while oUF handles the complexities of interacting with the World of Warcraft API and maintaining compliance with Blizzard's restrictions (especially in WoW 12+).

**How AzeriteUI Uses oUF:**

- **Unit Frame Registration:** AzeriteUI defines custom layouts and registers unit frames (Player, Target, ToT, etc.) with oUF. oUF is responsible for creating, updating, and destroying these frames as needed.
- **Element System:** Each unit frame is built from oUF elements (such as Health, Power, Castbar, Auras). Elements are modular components that encapsulate logic for a specific type of unit data or widget.
- **Event Handling:** oUF listens for all relevant game events (e.g., `UNIT_HEALTH`, `UNIT_POWER_UPDATE`, `UNIT_AURA`, `PLAYER_TARGET_CHANGED`). When an event fires, oUF determines which frames and elements are affected and triggers their update functions.
- **Data Flow:** When an update is needed, oUF elements call the appropriate Blizzard API functions (such as `UnitHealth`, `UnitPower`, `C_UnitAuras.GetUnitAuras`, `UnitThreatSituation`, etc.) to fetch the latest data for the unit. The element then updates the corresponding widget (e.g., a StatusBar or FontString) with the new value.
- **Defensive Patterns:** In WoW 12+, oUF elements are updated to check for secret values using `issecretvalue` and related APIs before using any data in logic or display. If a value is secret, the element provides a fallback or skips the update, ensuring compliance with Blizzard's restrictions and preventing taint or errors.
- **No Direct API Calls in Layouts:** AzeriteUI's layout code does not call the WoW API directly for unit data. Instead, it relies on oUF's element system to abstract away the API details and event logic. This separation ensures that all data handling is centralized, consistent, and compliant.

**APIs Used by oUF (and leveraged by AzeriteUI):**

- `UnitHealth`, `UnitHealthMax`, `UnitPower`, `UnitPowerMax`, `UnitThreatSituation`, `UnitReaction`, `UnitSelectionType`, `C_UnitAuras.GetUnitAuras`, and other unit-related APIs for retrieving live data.
- `issecretvalue`, `scrubsecretvalues`, `C_Secrets.ShouldUnitPowerMaxBeSecret`, and related APIs for secret value detection and compliance.
- Widget APIs such as `StatusBar:SetValue`, `StatusBar:SetMinMaxValues`, `FontString:SetText`, etc., for updating the UI.
- Event APIs for listening to and responding to changes in unit state.
- **Defensive use of `pcall`:** AzeriteUI and oUF frequently use Lua's `pcall` (protected call) to safely invoke Blizzard API functions and internal calculations. This ensures that if an API call fails (due to taint, nil values, or unexpected Blizzard changes), the error is caught and handled gracefully, preventing UI breakage or taint propagation. This is especially important in WoW 12+, where API contracts and return types may change or become protected at runtime.

**Why This Matters:**

- By leveraging oUF, AzeriteUI avoids duplicating complex event and data logic, reduces the risk of taint or forbidden API usage, and ensures future compatibility as Blizzard updates the API.
- oUF's modular element system makes it easy to add, remove, or customize unit frame features without rewriting core logic.
- Centralizing all API interaction in oUF elements ensures that defensive patterns (such as secret value checks) are consistently applied everywhere unit data is used.

### How oUF Gets Unit Data

- **Element update functions:** oUF elements (such as Health, Power, Auras) define update functions that call the appropriate WoW API functions (e.g., UnitHealth, UnitPower, UnitAura).
- **Event-driven:** oUF listens for relevant game events (e.g., UNIT_HEALTH, UNIT_POWER_UPDATE) and triggers element updates when these events fire.
- **API abstraction:** oUF abstracts the details of event handling and API calls, providing a clean interface for layout authors.
- **Defensive patterns:** In WoW 12+, oUF elements are updated to check for secret values before using API returns, ensuring compliance with new restrictions.

### Example Data Flow

1. The player’s health changes.
2. WoW fires the UNIT_HEALTH event.
3. oUF receives the event and calls the Health element’s update function.
4. The Health element calls UnitHealth(unit) to get the new value.
5. If the value is not secret, it updates the StatusBar; if secret, it uses a fallback or skips the update.

### Summary

- AzeriteUI relies on oUF’s element and event system to get all unit data.
- oUF retrieves data from the WoW API, applies defensive checks, and updates the UI.
- This separation allows AzeriteUI to focus on layout and appearance, while oUF handles data retrieval and compliance with API restrictions.

---
---

## Protected Functions: What We Check and How We Fix

### What are Protected Functions?

Protected functions are Blizzard API functions that cannot be called, wrapped, or replaced by addons, especially in combat or secure contexts. Examples include securecall, SetScript, EditModeManagerFrame methods, and others listed at [Protected Functions](https://warcraft.wiki.gg/wiki/Category:World_of_Warcraft_API/Protected_Functions).

### AzeriteUI Approach

- **No direct use:** AzeriteUI does not call, wrap, or override protected functions in its codebase. All widget and frame manipulation is done through Blizzard-documented, addon-safe APIs only.
- **No overrides:** We do not override EditModeManagerFrame methods or any secure execution path.
- **No custom secure handlers:** No use of securecall, securecallfunction, secureexecuterange, or similar.
- **No forbidden SetScript/SetAttribute:** We do not set scripts or attributes on Blizzard-protected frames.
- **No taint risk:** All logic is designed to avoid taint propagation by never touching protected or forbidden APIs.

### How We Fix Issues

- **Defensive checks:** All API returns are checked for secret values before use. If a value is secret, we provide a fallback or skip logic.
- **Widget-only updates:** All UI updates (e.g., StatusBar:SetValue, SetOrientation) are performed only through allowed widget methods.
- **No forbidden hooks:** We do not use hooksecurefunc or similar on protected functions.
- **Validation:** We test for taint, forbidden API usage, and secret value errors after every change.

### Comparison with AzeriteUI_Stock

- No protected function usage or forbidden overrides were found in AzeriteUI_Stock either. Both codebases follow the same defensive, widget-only approach.

---

---

## oUF Tag Usage and Defensive Patterns

### oUF Tag System

oUF provides a tag system for unit frame text and info (e.g., health, power, name). AzeriteUI does not register custom tags or override oUF’s tag logic in the scanned sources. Instead, it relies on oUF’s default tag handling, which is updated to be WoW 12+ safe.

### Defensive Use of oUF

- **No custom tag registration:** No oUF:RegisterTag or similar calls are present.
- **Default tags only:** AzeriteUI uses oUF’s built-in tags, which are maintained to avoid forbidden operations and secret value misuse.
- **Safe info retrieval:** All tag-related info (health, power, etc.) is checked for secret values before display or logic.
- **No tag math or logic:** No custom math, concatenation, or logic is performed on tag values that could be secret.

### Can We Use oUF Tags to Work Around Restrictions?

- **No:** Since oUF tags ultimately call the same Blizzard APIs, they are subject to the same secret value and protected function restrictions. The only safe workaround is to ensure all tag logic is defensive and never uses secret values in forbidden ways.

---

---

## WoW 12.0.0.x API Changes & AddOn Restrictions

### Secret Value Handling (WoW 12+)

World of Warcraft 12+ introduces "secret values" for many unit-related API calls (health, power, threat, selection, auras, etc.).

- **What is a secret value?**
  - A value returned by the WoW API that cannot be used in arithmetic, comparisons, table indices, or boolean logic in addon code. This is to prevent leaking sensitive information.
- **How to detect?**
  - Use `issecretvalue(value)` to check if a value is secret before using it. Never use secret values as table keys or in logic.
- **How to sanitize?**
  - Use `scrubsecretvalues(values)` to remove or replace secret values in tables.
- **Allowed usage:**
  - Secret values can be passed to Blizzard widgets (e.g., `StatusBar:SetValue`), but not used in custom logic or calculations.
- **APIs for secret checks:**
  - `C_Secrets.ShouldUnitPowerMaxBeSecret`, `issecretvalue`, `hasanysecretvalues`, and related FrameScript functions.
- **Debugging:**
  - Use defensive patterns and debug logging to catch and report secret value issues. Always provide fallback values for UI display if a value is secret.

### Forbidden Operations

You must **never**:

- Perform arithmetic, concatenation, or boolean tests on secret values.
- Use secret values as table indices.
- Compare secret values (==, ~=, <, >, etc.).
- Branch logic (if/then) on secret values.
- Wrap or replace protected functions (taint risk).
- Override EditModeManagerFrame methods unless proven taint-safe.

### AddOn API Restrictions (12.0.0.x)

- Many functions remain protected or forbidden for addons. See the full list at [Protected Functions](https://warcraft.wiki.gg/wiki/Category:World_of_Warcraft_API/Protected_Functions).
- Some legacy APIs are removed or changed; always check [API change summaries](https://warcraft.wiki.gg/wiki/API_change_summaries).
- Many systems are now under C_namespaces (e.g., C_UnitAuras, C_Secrets, C_AddOns).
- Only use Blizzard-documented widget methods for UI manipulation. Avoid direct manipulation of Blizzard frames unless explicitly documented.
- Use C_AddOnProfiler for performance metrics.

---

---

## StatusBar Growth, Orientation, and Smoothing (WoW 12+)

### Growth Direction & Orientation

You can control the growth direction of targetframe and other status bars using:

- `StatusBar:SetOrientation("HORIZONTAL"|"VERTICAL")` — Sets the bar's orientation.
- `StatusBar:SetReverseFill(true|false)` — Reverses the fill direction (e.g., right-to-left or top-to-bottom).

**Allowed growth directions:**

- Horizontal (left-to-right or right-to-left with reverse fill)
- Vertical (bottom-to-top or top-to-bottom with reverse fill)

**How to implement:**
Set orientation and reverse fill as needed for your layout. Example:

```lua
bar:SetOrientation("HORIZONTAL")
bar:SetReverseFill(true) -- right-to-left
```

### Smoothing & Animation

There is **no official StatusBar:SetSmoothing or SetValueSmooth API** in WoW 12+. Smoothing is not natively exposed. If you want smooth animation, you must:

- Implement it manually (e.g., via OnUpdate scripts or libraries),
- **But:** You must not use secret values in custom math, interpolation, or animation logic. Only use non-secret, sanitized values for smoothing.
- If the value is secret, update the bar instantly or use a fallback.

### Allowed Widget Methods for StatusBar

You may use the following documented methods:

- `SetOrientation(orientation)`
- `SetReverseFill(isReverseFill)`
- `SetMinMaxValues(min, max)`
- `SetValue(value)`
- `SetStatusBarTexture(asset)`
- `SetFillStyle(fillStyle)`
- `SetRotatesTexture(rotatesTexture)`
- `SetColorFill(r, g, b, a)`
- `SetStatusBarColor(r, g, b, a)`
- `SetStatusBarDesaturation(desaturation)`

**Do not use undocumented or removed methods.**

### Restrictions Recap

- You cannot use secret values in custom animation, smoothing, or math logic.
- Only use the above widget methods for growth/orientation.
- No direct manipulation of Blizzard frames outside documented widget APIs.

---

---

## AzeriteUI: Defensive Patterns & Examples

### Defensive Health Bar Update

```lua
local health = UnitHealth(unit)
if issecretvalue(health) then
  health = 0 -- fallback or skip update
end
statusbar:SetValue(health)
```

### Defensive Table Index

```lua
local threat = UnitThreatSituation(unit)
if not issecretvalue(threat) then
  local color = ThreatColors[threat]
  -- ...
end
```

---

---

## API Reference: Commonly Used Functions (AzeriteUI)

### Secret Value & Defensive APIs

### LibActionButton API Usage

LibActionButton-1.0-GE is used for action bar buttons, normalizing API calls and handling multiple action types (action, spell, item, macro, custom). It uses defensive patterns for WoW 12+.

**APIs Used:**

- `C_ActionBar.GetActionCooldown`, `C_ActionBar.GetActionCharges`
- `C_Spell.GetSpellCooldown`, `C_Spell.GetSpellCharges`, `C_Spell.IsSpellUsable`, `C_Spell.GetSpellTexture`
- `C_Item.GetItemCount`, `C_Item.GetItemIconByID`, `C_Item.IsUsableItem`, `C_Item.IsEquippedItem`
- `C_Container.GetItemCooldown`
- `C_UnitAuras.GetCooldownAuraBySpellID`
- `issecretvalue`, `hasanysecretvalues`, `scrubsecretvalues`
- Widget methods: `SetTexture`, `SetVertexColor`, `Show`, `Hide`, `SetTooltip`, `SetSpellActivationColor`, `ShowSpellActivation`, `HideSpellActivation`

---

### Module-Specific API Usage

#### UnitFrames (Player, Target, ToT, etc.)

- `UnitHealth`, `UnitHealthMax`, `UnitPower`, `UnitPowerMax`, `UnitThreatSituation`, `UnitReaction`, `UnitSelectionType`
- `C_UnitAuras.GetUnitAuras`, `C_UnitAuras.GetAuraDataByIndex` *(GetAuraDataBySpellID is not available in WoW 12+; use GetAuraDataByIndex or GetUnitAuras instead)*
- `issecretvalue`, `scrubsecretvalues`, `hasanysecretvalues`, `C_Secrets.ShouldUnitPowerMaxBeSecret`
- Widget: `StatusBar:SetValue`, `StatusBar:SetMinMaxValues`, `FontString:SetText`, `StatusBar:SetStatusBarColor`, `StatusBar:SetOrientation`, `StatusBar:SetReverseFill` *(these are instance methods, not global APIs; always call on the widget instance)*
- Events: `UNIT_HEALTH`, `UNIT_POWER_UPDATE`, `UNIT_AURA`, `PLAYER_TARGET_CHANGED`, etc.

#### Auras (Buffs, Debuffs, Nameplates)

- `C_UnitAuras.GetUnitAuras`, `C_UnitAuras.GetAuraDataByIndex` *(GetAuraDataBySpellID is not available in WoW 12+; use GetAuraDataByIndex or GetUnitAuras instead)*
- `issecretvalue`, `scrubsecretvalues`, `hasanysecretvalues`, `C_Secrets.ShouldAurasBeSecret`
- Widget: `CreateFrame("Button")`, `Button:SetScript`, `Button:SetAttribute`, `Texture:SetTexture`, `Cooldown:SetCooldown` *(these are instance methods; call on the correct widget type)*
- Events: `UNIT_AURA`, `NAME_PLATE_UNIT_ADDED`, `NAME_PLATE_UNIT_REMOVED`

#### Castbars

- `UnitCastingInfo`, `UnitChannelInfo`, `UnitIsUnit`, `UnitGUID`
- Widget: `StatusBar:SetMinMaxValues`, `StatusBar:SetValue`, `SetStatusBarColor`, `SetOrientation`, `SetReverseFill`, `SetSparkTexture`, `Show`, `Hide`
- Events: `UNIT_SPELLCAST_START`, `UNIT_SPELLCAST_STOP`, `UNIT_SPELLCAST_CHANNEL_START`, `UNIT_SPELLCAST_CHANNEL_STOP`

#### Edit Mode & Movable Frames

- `C_EditMode.GetLayouts`, `C_EditMode.GetAccountSettings` *(SetLayout is not available as an API; layouts are managed via GetLayouts and UI interactions)*
- `CreateFrame`, `SetPoint`, `ClearAllPoints`, `SetMovable`, `StartMoving`, `StopMovingOrSizing`, `RegisterForDrag`, `SetScript`
- Events: `EDIT_MODE_LAYOUTS_UPDATED`, `PLAYER_ENTERING_WORLD`

#### Miscellaneous (Minimap, Tracker, Debug, AddOn info)

- `Minimap:SetMaskTexture`, `Minimap:SetBlipTexture`, `Minimap:SetZoom`, `Minimap:GetZoom` *(these are widget instance methods and may not appear in the global API list; usage is valid on the Minimap widget)*
- `C_AddOns.GetAddOnInfo`, `C_AddOns.IsAddOnLoaded`, `C_AddOnProfiler.GetAddOnMetric`
- `hooksecurefunc`, `pcall`, `LibStub` *(library loader, not a Blizzard API)*, `RegisterEvent`, `UnregisterEvent`, `RegisterUnitEvent`
- Debug: `print`, `GetTime`, `GetBuildInfo`, `C_CVar.GetCVar`, `C_CVar.SetCVar` *(use the C_CVar namespace for CVars in WoW 12+)*

---

**Charge Handling:**

- To get spell charges, use `C_Spell.GetSpellCharges(spellID)`.
- If the returned charge count is a secret value (`issecretvalue(chargeInfo.currentCharges)`), you must NOT display, use, or branch logic on it.
- In combat, if the charge count is secret, AzeriteUI will not display the number of charges left. If not secret, it is shown.
- This restriction applies to all charge-based spells and actions. Secret values are allowed to be passed to Blizzard widgets, but not used in custom logic or display.

**Summary Table:**

| API Namespace   | Key Functions Used                                   | Defensive Patterns           |
| ----------------| -----------------------------------------------------| -----------------------------|
| C_ActionBar     | GetActionCooldown, GetActionCharges                  | Secret value checks          |
| C_Spell         | GetSpellCooldown, GetSpellCharges, IsSpellUsable     | Secret value checks          |
| C_Item          | GetItemCount, GetItemIconByID, IsUsableItem          | Secret value checks          |
| C_Container     | GetItemCooldown                                      | Secret value checks          |
| C_UnitAuras     | GetCooldownAuraBySpellID                             | Secret value checks          |
| Widget          | SetTexture, SetVertexColor, Show, Hide               | Allowed with secret values   |
| Defensive       | issecretvalue, hasanysecretvalues, scrubsecretvalues | All logic is defensive       |

**Charge Display in Combat:**

- If `C_Spell.GetSpellCharges` returns a secret value for `currentCharges`, AzeriteUI will not display the charge count in combat.
- If the value is not secret, it is displayed normally.
- This is enforced by checking `issecretvalue(chargeInfo.currentCharges)` before display.

**How to Test:**

- Enable AzeriteUI and action bars.
- Use `/reload` and trigger action bar events (slot changes, cooldowns, overlays).
- Cast charge-based spells in and out of combat, observe charge display.
- Check FixLog.md for any secret value or taint errors.

---

### Module-Specific API Usage

#### UnitFrames (Player, Target, ToT, etc.)

**Overview:**
UnitFrames are the backbone of AzeriteUI, representing the player, target, target-of-target, and other units. They display health, power, threat, and selection state, and are updated in response to game events. All data is retrieved via Blizzard APIs and handled defensively.

- **UnitHealth(unit, usePredicted?)**
  - **UnitPower(unit, powerType?, unmodified?)**
    - *Dev*: Returns the unit’s current power (mana, rage, etc.).
    - *Plain*: How much resource a unit has.
    - *Usage*: Used for power bars, checked for secret values.
    - *Trick*: Use `powerType` to get specific resource types.

  - **UnitHealthMax(unit)**
    - *Dev*: Returns the maximum health for a unit.
    - *Plain*: The highest possible health a unit can have.
    - *Usage*: Used to set the max value for health bars.
    - *Trick*: Always check for secret values before using in logic.

  - **UnitPowerMax(unit, powerType?)**
    - *Dev*: Returns the maximum power for a unit (mana, rage, etc.).
    - *Plain*: The highest possible resource a unit can have.
    - *Usage*: Used to set the max value for power bars.
    - *Trick*: Always check for secret values before using in logic.

  - **UnitGUID(unit)**
    - *Dev*: Returns the globally unique identifier for a unit.
    - *Plain*: A unique ID for each unit in the game.
    - *Usage*: Used for tracking units, especially when updating or comparing frames.

  - **UnitIsUnit(unit1, unit2)**
    - *Dev*: Returns true if two unit tokens refer to the same unit.
    - *Plain*: Checks if two frames are showing the same thing.
    - *Usage*: Used for frame logic and event handling.

  - **UnitIsPlayer(unit)**
    - *Dev*: Returns true if the unit is a player.
    - *Plain*: Checks if a frame is showing a player.
    - *Usage*: Used for coloring, filtering, and logic.

  - **UnitIsDeadOrGhost(unit)**
    - *Dev*: Returns true if the unit is dead or a ghost.
    - *Plain*: Checks if a unit is dead.
    - *Usage*: Used for graying out frames or showing death indicators.

  - **UnitClass(unit)**
    - *Dev*: Returns the class of a unit.
    - *Plain*: What class (e.g., Warrior, Mage) a unit is.
    - *Usage*: Used for coloring and class-specific logic.

  **Practical Example:**

  ```lua
  local health = UnitHealth(unit)
  local maxHealth = UnitHealthMax(unit)
  if issecretvalue(health) or issecretvalue(maxHealth) then
    health, maxHealth = 0, 1 -- fallback
  end
  statusbar:SetMinMaxValues(0, maxHealth)
  statusbar:SetValue(health)
  ```

  **Usage Notes:**
  - Always check for secret values before using any API return in logic, math, or as a table index.
  - Use event-driven updates: listen for `UNIT_HEALTH`, `UNIT_POWER_UPDATE`, etc.
  - Use `UnitGUID` and `UnitIsUnit` to ensure updates are for the correct frame.
  - Use `UnitClass` and `UnitIsPlayer` for coloring and filtering.
  - *Dev*: Returns the unit’s current health as a number. Optionally includes predicted incoming heals.
  - *Plain*: How much health a unit has right now.
  - *Usage*: Used for health bars, always checked with `issecretvalue` before logic.
  - *Trick*: Secret values can be passed to StatusBar widgets, but not used in math or comparisons.

- **UnitPower(unit, powerType?, unmodified?)**
  - *Dev*: Returns the unit’s current power (mana, rage, etc.).
  - *Plain*: How much resource a unit has.
  - *Usage*: Used for power bars, checked for secret values.
  - *Trick*: Use `powerType` to get specific resource types.

- **UnitThreatSituation(unit, mobGUID?)**
  - *Dev*: Returns threat status (aggro) for a unit.
  - *Plain*: How much a unit is targeted by enemies.
  - *Usage*: Used for threat coloring, checked for secret values.

- **UnitReaction(unit, target)**
  - *Dev*: Returns reaction (friendly, hostile, neutral) between units.
  - *Plain*: Whether a unit is friendly or hostile.
  - *Usage*: Used for coloring and selection logic.

- **UnitSelectionType(unit, useExtendedColors?)**
  - *Dev*: Returns selection type for coloring (e.g., player, enemy).
  - *Plain*: What kind of unit is selected.
  - *Usage*: Used for frame coloring.

- **issecretvalue(value)**
  - *Dev*: Returns true if a value is secret (cannot be used in logic).
  - *Plain*: Checks if a value is “hidden” by Blizzard.
  - *Usage*: Always used before math, comparisons, or display.

- **scrubsecretvalues(table)**
  - *Dev*: Removes/replaces secret values in a table.
  - *Plain*: Cleans up lists so only safe values remain.
  - *Usage*: Used before iterating or displaying API data.

- **hasanysecretvalues(table)**
  - *Dev*: Returns true if any value in a table is secret.
  - *Plain*: Checks if a list has any “hidden” values.
  - *Usage*: Used for defensive checks.

- **C_Secrets.ShouldUnitPowerMaxBeSecret(unit, powerType?)**
  - *Dev*: Returns true if max power queries will be secret.
  - *Plain*: Checks if max resource is hidden.
  - *Usage*: Used for fallback logic.

- **StatusBar:SetValue(value), SetMinMaxValues(min, max), SetStatusBarColor(r, g, b, a), SetOrientation(orientation), SetReverseFill(isReverseFill)**
  - *Dev*: Widget methods for updating bar visuals.
  - *Plain*: Changes how bars look and fill.
  - *Usage*: Used for health/power bars, can accept secret values.

---

#### Auras (Buffs, Debuffs, Nameplates)

**Overview:**
Auras are buffs and debuffs shown on unit frames and nameplates. AzeriteUI uses Blizzard’s secure aura APIs to fetch, filter, and display these, always checking for secret values and using defensive patterns.

- **C_UnitAuras.GetUnitAuras(unit, filter, maxCount?, sortRule?, sortDirection?)**
  - **C_UnitAuras.GetAuraDataByIndex(unit, index, filter?)**
    - *Dev*: Returns aura data at a specific index.
    - *Plain*: Gets a single buff/debuff.
    - *Usage*: Used for detailed aura info.

  - **C_UnitAuras.GetAuraDataBySpellID**
    - *Dev*: (If available) Returns aura data for a specific spell ID.
    - *Plain*: Gets a buff/debuff by spell.
    - *Usage*: Used for advanced filtering or highlighting.

  - **UnitAura(unit, index, filter?)**
    - *Dev*: (Legacy) Returns aura info for a unit at a given index.
    - *Plain*: Old way to get buffs/debuffs.
    - *Usage*: Used for compatibility or fallback.

  - **C_Secrets.ShouldAurasBeSecret()**
  - **C_UnitAuras.GetCooldownAuraBySpellID(spellID)**
    - *Dev*: Returns cooldown aura info for a spell.
    - *Plain*: Gets cooldown info for a specific spell.
    - *Usage*: Used for advanced aura/cooldown displays.

  **Practical Example:**

  ```lua
  local auras = C_UnitAuras.GetUnitAuras(unit, "HELPFUL")
  if hasanysecretvalues(auras) then
    auras = scrubsecretvalues(auras)
  end
  for _, aura in ipairs(auras) do
    -- Display aura.icon, aura.duration, etc.
  end
  ```

  **Usage Notes:**
  - Always check for secret values in aura tables before iterating or displaying.
  - Use filters ("HELPFUL", "HARMFUL") to separate buffs and debuffs.
  - Use sort options for custom ordering, but avoid sorting by secret expiration times.
  - Use `C_Secrets.ShouldAurasBeSecret()` to detect if aura info is restricted.
  - For nameplates, listen for `NAME_PLATE_UNIT_ADDED` and `NAME_PLATE_UNIT_REMOVED` events.
  - *Dev*: Returns a list of aura data for a unit.
  - *Plain*: Gets all buffs/debuffs on a unit.
  - *Usage*: Used for aura displays, checked for secret values.
  - *Trick*: Use filters and sorting for custom displays.

- **C_UnitAuras.GetAuraDataByIndex(unit, index, filter?)**
  - *Dev*: Returns aura data at a specific index.
  - *Plain*: Gets a single buff/debuff.
  - *Usage*: Used for detailed aura info.

- **C_Secrets.ShouldAurasBeSecret()**
  - *Dev*: Returns true if aura queries will be secret.
  - *Plain*: Checks if buffs/debuffs are hidden.
  - *Usage*: Used for fallback logic.

- **C_UnitAuras.GetCooldownAuraBySpellID(spellID)**
  - *Dev*: Returns cooldown aura info for a spell.
  - *Plain*: Gets cooldown info for a specific spell.
  - *Usage*: Used for advanced aura/cooldown displays.

---

#### Castbars

**Overview:**
Castbars show spell casting and channeling progress for units. AzeriteUI uses both classic and C_ APIs to fetch cast/channel info, durations, and icons, and updates bars in response to spell events. All values are checked for secret status.

- **UnitCastingInfo(unit)**
  - *Dev*: Returns info about a spell being cast by a unit (name, start time, end time, etc.).
  - *Plain*: What spell a unit is casting and how long it takes.
  - *Usage*: Used to start and update castbars.

- **UnitChannelInfo(unit)**
  - *Dev*: Returns info about a spell a unit is channeling.
  - *Plain*: What spell a unit is channeling and how long it lasts.
  - *Usage*: Used for channeling bars.

- **C_Spell.GetSpellCooldown(spellIdentifier)**
  - **C_Spell.GetSpellCharges(spellIdentifier)**
    - *Dev*: Returns charge info for a spell.
    - *Plain*: How many times a spell can be used before recharging.
    - *Usage*: Used for charge overlays or cooldowns.

  - **C_Spell.IsSpellUsable(spellIdentifier)**
  - **C_Spell.GetSpellTexture(spellIdentifier)**
    - *Dev*: Returns icon texture for a spell.
    - *Plain*: Gets the image for a spell.
    - *Usage*: Used for castbar icons.

  - **UnitIsUnit(unit1, unit2)**
    - *Dev*: Returns true if two unit tokens refer to the same unit.
    - *Plain*: Checks if two frames are showing the same thing.
    - *Usage*: Used to ensure castbar updates are for the correct unit.

  - **UnitGUID(unit)**
    - *Dev*: Returns the globally unique identifier for a unit.
    - *Plain*: A unique ID for each unit in the game.
    - *Usage*: Used for tracking and updating castbars.

  **Practical Example:**

  ```lua
  local name, _, _, startTime, endTime = UnitCastingInfo(unit)
  if name and not issecretvalue(startTime) and not issecretvalue(endTime) then
    local duration = (endTime - startTime) / 1000
    castbar:SetMinMaxValues(0, duration)
    castbar:SetValue(GetTime() - (startTime / 1000))
  end
  ```

  **Usage Notes:**
  - Always check for secret values before using cast/channel times in math or display.
  - Use `UnitGUID` and `UnitIsUnit` to ensure updates are for the correct frame.
  - Listen for `UNIT_SPELLCAST_START`, `UNIT_SPELLCAST_STOP`, `UNIT_SPELLCAST_CHANNEL_START`, `UNIT_SPELLCAST_CHANNEL_STOP` events.
  - Use `C_Spell.GetSpellTexture` for icons and `C_Spell.GetSpellCharges` for charge overlays.
  - *Dev*: Returns cooldown info for a spell.
  - *Plain*: How long until a spell can be cast again.
  - *Usage*: Used for castbar progress, checked for secret values.

**WoW 12 Cast Duration Objects (Recommended Pattern)**

- **Primary API objects:**
  - [`UnitCastingDuration(unit)`](https://warcraft.wiki.gg/wiki/API_UnitCastingDuration)
  - [`UnitChannelDuration(unit)`](https://warcraft.wiki.gg/wiki/API_UnitChannelDuration)
  - [`UnitEmpoweredChannelDuration(unit)`](https://warcraft.wiki.gg/wiki/API_UnitEmpoweredChannelDuration)
  - [`DurationObject`](https://warcraft.wiki.gg/wiki/DurationObject)
  - [`CurveObject` / `CurveConstants.ZeroToOne`](https://warcraft.wiki.gg/wiki/ScriptObject_CurveObject)
- **Why this matters in WoW12:**
  - Some cast timelines are no longer consistently available as plain numeric start/end values for non-player units.
  - Duration objects are the stable way to sample cast progress without touching protected/secret math directly.
- **Safe percent order (target castbars):**
  1. Use callback payload (`CustomTimeText` / `CustomDelayText`) when provided.
  2. If missing, query unit duration object directly (`UnitCastingDuration`, `UnitChannelDuration`, `UnitEmpoweredChannelDuration`).
  3. If still missing, use mirrored widget percent as visual fallback.
  4. Only then show idle/full mirrored fake fill.
- **Practical tip:**
  - Keep the native castbar texture visible at alpha `0` so native geometry/timer updates continue, then anchor a fake visible texture to that region for final art/crop.
- **Reference discussions:**
  - Blizzard UI & Macro forum thread on secret values and combat restrictions:
    [`New extra secure system in 11.0.5`](https://us.forums.blizzard.com/en/wow/t/new-extra-secure-system-in-1105/1994456)
  - API surface changes/compatibility reports from addon authors:
    [`The War Within API changes`](https://us.forums.blizzard.com/en/wow/t/the-war-within-api-changes/1919304)

- **C_Spell.GetSpellCharges(spellIdentifier)**
  - *Dev*: Returns charge info for a spell.
  - *Plain*: How many times a spell can be used before recharging.
  - *Usage*: Used for charge displays, checked for secret values.

- **C_Spell.IsSpellUsable(spellIdentifier)**
  - *Dev*: Returns whether a spell can be cast.
  - *Plain*: Checks if a spell is ready to use.
  - *Usage*: Used for castbar usability.

- **C_Spell.GetSpellTexture(spellIdentifier)**
  - *Dev*: Returns icon texture for a spell.
  - *Plain*: Gets the image for a spell.
  - *Usage*: Used for castbar icons.

---

#### Action Bars & Items

**Overview:**
Action bars and item buttons display spells, macros, and items the player can use. AzeriteUI uses Blizzard’s secure APIs to fetch cooldowns, charges, usability, and icons, and updates buttons in response to action bar and bag events. All values are checked for secret status.

- **C_ActionBar.GetActionCooldown(actionID)**
  - **C_ActionBar.GetActionCharges(actionID)**
    - *Dev*: Returns charge info for an action slot.
    - *Plain*: How many times an action can be used before recharging.
    - *Usage*: Used for action bar charge displays.

  - **GetActionInfo(actionID)**
    - *Dev*: Returns the type and ID of the action assigned to a slot (spell, item, macro, etc.).
    - *Plain*: What kind of thing is on a button.
    - *Usage*: Used to determine how to fetch icon, cooldown, or usability.

  - **GetActionText(actionID)**
    - *Dev*: Returns the macro name or custom text for an action slot.
    - *Plain*: The label for a button.
    - *Usage*: Used for displaying macro names.

  - **GetActionCount(actionID)**
    - *Dev*: Returns the number of charges or items for an action slot.
    - *Plain*: How many times you can use a button.
    - *Usage*: Used for overlays and count displays.

  - **C_Item.GetItemCount(itemInfo, includeBank?, includeUses?, includeReagentBank?, includeAccountBank?)**
  - **C_Item.GetItemIconByID(itemInfo)**
  - **C_Item.IsUsableItem(itemInfo)**
  - **C_Item.IsEquippedItem(itemInfo)**
  - **C_Container.GetItemCooldown(itemID)**
    - *Dev*: Returns cooldown info for an item.
    - *Plain*: How long until an item can be used again.
    - *Usage*: Used for item cooldown overlays.

  - **IsUsableAction(actionID)**
    - *Dev*: Returns whether an action slot is usable (spell, item, macro).
    - *Plain*: Checks if a button is ready to use.
    - *Usage*: Used for button overlays and usability coloring.

  - **IsEquippedAction(actionID)**
    - *Dev*: Returns whether an action slot is equipped (for items).
    - *Plain*: Checks if a button is showing an equipped item.
    - *Usage*: Used for overlays and coloring.

  - **IsCurrentAction(actionID)**
    - *Dev*: Returns whether an action slot is currently active (e.g., auto-attack).
    - *Plain*: Checks if a button is "on".
    - *Usage*: Used for highlighting and overlays.

  **Practical Example:**

  ```lua
  local charges = C_ActionBar.GetActionCharges(slot)
  if charges and not issecretvalue(charges.currentCharges) then
    button.Count:SetText(charges.currentCharges)
  else
    button.Count:SetText("")
  end
  ```

  **Usage Notes:**
  - Always check for secret values before displaying or using counts/cooldowns.
  - Use `GetActionInfo` to determine if a button is a spell, item, or macro.
  - Use overlays and coloring to indicate usability, equipped state, and cooldowns.
  - Listen for `ACTIONBAR_SLOT_CHANGED`, `ACTIONBAR_UPDATE_COOLDOWN`, `BAG_UPDATE_COOLDOWN`, and related events.
  - *Dev*: Returns cooldown info for an action slot.
  - *Plain*: How long until an action can be used again.
  - *Usage*: Used for action bar cooldown overlays.

- **C_ActionBar.GetActionCharges(actionID)**
  - *Dev*: Returns charge info for an action slot.
  - *Plain*: How many times an action can be used before recharging.
  - *Usage*: Used for action bar charge displays.

- **C_Item.GetItemCount(itemInfo, includeBank?, includeUses?, includeReagentBank?, includeAccountBank?)**
  - *Dev*: Returns item count, with options for bank/reagents.
  - *Plain*: How many of an item you have.
  - *Usage*: Used for item displays, checked for secret values.

- **C_Item.GetItemIconByID(itemInfo)**
  - *Dev*: Returns icon for an item.
  - *Plain*: Gets the image for an item.
  - *Usage*: Used for item icons.

- **C_Item.IsUsableItem(itemInfo)**
  - *Dev*: Returns whether an item can be used.
  - *Plain*: Checks if an item is ready to use.
  - *Usage*: Used for item usability overlays.

- **C_Item.IsEquippedItem(itemInfo)**
  - *Dev*: Returns whether an item is equipped.
  - *Plain*: Checks if an item is worn.
  - *Usage*: Used for item status displays.

- **C_Container.GetItemCooldown(itemID)**
  - *Dev*: Returns cooldown info for an item.
  - *Plain*: How long until an item can be used again.
  - *Usage*: Used for item cooldown overlays.

---

#### Edit Mode & Miscellaneous

**Overview:**
Edit Mode and miscellaneous APIs are used for customizing layouts, checking addon state, debugging, and interacting with Blizzard widgets like the minimap. AzeriteUI uses these APIs for user customization, compatibility, and diagnostics.

- **C_EditMode.GetLayouts()**
  - **C_AddOns.GetAddOnInfo(name), C_AddOns.IsAddOnLoaded(name)**
  - **C_AddOnProfiler.GetAddOnMetric(name, metric)**
    - *Dev*: Returns performance metrics for an addon.
    - *Plain*: Gets how much time/resources an addon uses.
    - *Usage*: Used for performance profiling.

  - **CreateFrame(frameType, name, parent, template)**
    - *Dev*: Creates a new frame of a given type (Button, StatusBar, etc.).
    - *Plain*: Makes a new UI element.
    - *Usage*: Used for all custom UI widgets, including movable frames.

  - **SetPoint, ClearAllPoints, SetMovable, StartMoving, StopMovingOrSizing, RegisterForDrag, SetScript**
    - *Dev*: Frame methods for positioning and movement.
    - *Plain*: Lets users move and place UI elements.
    - *Usage*: Used for Edit Mode and custom frame movement.

  - **Minimap:SetMaskTexture, SetBlipTexture, SetZoom, GetZoom**
    - *Dev*: Widget methods for customizing the minimap.
    - *Plain*: Changes how the minimap looks and works.
    - *Usage*: Used for minimap theming and zoom controls.

  - **hooksecurefunc(functionName, hookFunc)**
    - *Dev*: Securely attaches a function to run after a Blizzard function.
    - *Plain*: Lets us add extra logic to Blizzard code safely.
    - *Usage*: Used for compatibility and bugfixes.

  - **pcall(func, ...)**
    - *Dev*: Calls a function in protected mode, catching errors.
    - *Plain*: Runs code safely so it doesn’t break the UI.
    - *Usage*: Used for risky API calls and debugging.

  - **LibStub(libName, silent?)**
    - *Dev*: Loads a library by name.
    - *Plain*: Lets us use shared code from other addons.
    - *Usage*: Used for all embedded libraries.

  - **RegisterEvent, UnregisterEvent, RegisterUnitEvent**
    - *Dev*: Frame methods for listening to game events.
    - *Plain*: Lets us react to things happening in the game.
    - *Usage*: Used for all event-driven updates.

  - **GetTime, GetBuildInfo, GetCVar, SetCVar, print**
    - *Dev*: Utility and debug functions.
    - *Plain*: Used for logging, diagnostics, and version checks.
    - *Usage*: Used in debug modules and for troubleshooting.

  **Practical Example:**

  ```lua
  local frame = CreateFrame("Frame", nil, UIParent)
  frame:SetMovable(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
  frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
  ```

  **Usage Notes:**
  - Use `C_EditMode.GetLayouts` and related APIs for layout switching and saving.
  - Use `CreateFrame` and movement methods for custom, user-movable frames.
  - Use `hooksecurefunc` for safe Blizzard API hooks; never overwrite Blizzard functions directly.
  - Use `pcall` for risky or debug code to avoid UI errors.
  - Always register and unregister events properly to avoid leaks or taint.
  - *Dev*: Returns available edit mode layouts.
  - *Plain*: Gets all UI layout presets.
  - *Usage*: Used for layout switching and customization.

- **C_AddOns.GetAddOnInfo(name), C_AddOns.IsAddOnLoaded(name)**
  - *Dev*: Returns info and load status for an addon.
  - *Plain*: Checks if an addon is loaded and gets its details.
  - *Usage*: Used for compatibility and debug checks.

- **C_AddOnProfiler.GetAddOnMetric(name, metric)**
  - *Dev*: Returns performance metrics for an addon.
  - *Plain*: Gets how much time/resources an addon uses.
  - *Usage*: Used for performance profiling.

---

**Known Tricks & Limitations:**

- Secret values: Always check with `issecretvalue` before using any API return in logic, math, or display. Secret values can be passed to widgets (e.g., StatusBar), but not used in custom calculations.
- Defensive patterns: Use `scrubsecretvalues` and `hasanysecretvalues` for tables/lists.
- Widget APIs: You can flip textures with `SetTexCoord` for mirrored bars, and combine `SetReverseFill` with flipped textures for advanced effects.
- Aura sorting: Use API sort options for custom aura displays, but avoid sorting by secret expiration times.
- Edit Mode: Layouts can be switched and customized, but protected frames cannot be moved in combat.

### AddOn & System APIs

- `C_AddOns.IsAddOnLoaded(name)` — Returns true if the addon is loaded.
- `C_AddOns.GetAddOnInfo(name)` — Returns info about an addon.
- `C_AddOnProfiler.GetAddOnMetric(name, metric)` — Returns performance metrics for an addon.
- `C_EditMode.GetLayouts()` — Returns available edit mode layouts.

### Widget & Frame APIs (StatusBar)

- `StatusBar:SetMinMaxValues(min, max)` — Sets the min/max for a status bar.
- `StatusBar:SetValue(value)` — Sets the value (can be secret).
- `StatusBar:SetStatusBarTexture(texture)` — Sets the bar texture.
- `StatusBar:SetOrientation(orientation)` — Sets bar orientation.
- `StatusBar:SetReverseFill(reverse)` — Sets reverse fill.
- `StatusBar:SetFillStyle(fillStyle)` — Sets fill style.
- `StatusBar:SetRotatesTexture(rotatesTexture)` — Rotates the bar texture.
- `StatusBar:SetColorFill(r, g, b, a)` — Sets color fill.
- `StatusBar:SetStatusBarColor(r, g, b, a)` — Sets bar color.
- `StatusBar:SetStatusBarDesaturation(desaturation)` — Sets desaturation.

#### Example: Safe StatusBar Usage

```lua
-- Defensive update for a health bar:
local health = UnitHealth(unit)
if issecretvalue(health) then
  health = 0 -- fallback or skip update
end
statusbar:SetMinMaxValues(0, UnitHealthMax(unit))
statusbar:SetValue(health)
statusbar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
statusbar:SetOrientation("HORIZONTAL")
statusbar:SetReverseFill(false)
statusbar:SetStatusBarColor(0, 1, 0, 1) -- green
```

#### Why This Works

- All StatusBar widget methods listed above are Blizzard-documented and explicitly allowed for addons in WoW 12+.
- You may pass secret values (e.g., from `UnitHealth`) directly to `SetValue`—the widget will render the bar, but you must not use the value in custom math, logic, or as a table index.
- Orientation and fill methods (`SetOrientation`, `SetReverseFill`) control the direction and style of the bar, and are safe for all layouts.
- Texture and color methods (`SetStatusBarTexture`, `SetStatusBarColor`) allow full customization without taint or forbidden access.
- Never use undocumented or removed methods, and always check for secret values before using API returns in your own logic.

---

### Tricks and Challenges: Mirrored TargetFrame & Reversed Castbar Fill

#### What We Try (and Why)

- **Mirrored TargetFrame:**
  - To make the target frame appear as a mirror image of the player frame (e.g., health/power bars filling right-to-left instead of left-to-right), we use:
    - `StatusBar:SetOrientation("HORIZONTAL")`
    - `StatusBar:SetReverseFill(true)`
    - Optionally, `StatusBar:SetStatusBarTexture()` with a horizontally flipped texture, or `SetTexCoord` tricks for advanced mirroring.
  - **Why:** This creates a visually balanced layout, with the player and target frames "facing" each other.

- **Reversed Castbar Fill:**
  - For the target's castbar, we want the fill to progress from right to left (mirrored to the player castbar).
  - We use the same approach: `SetOrientation("HORIZONTAL")` and `SetReverseFill(true)`.

#### What Works

- `SetReverseFill(true)` reliably reverses the fill direction for most StatusBars, including health and power bars, as long as the bar's texture and anchors are set up correctly.
- For simple bars, this is usually enough to achieve a mirrored effect.

#### What Sometimes Doesn't Work (and Why)

- **Castbar Issues:**
  - Some Blizzard-provided castbar templates or oUF elements may not fully respect `SetReverseFill` or may have hardcoded anchors, spark effects, or overlays that do not mirror correctly.
  - Texture stretching, spark positioning, or text overlays may remain left-to-right even if the bar fill is reversed.
  - In WoW 12+, some widget behaviors or protected frames may ignore or override reverse fill settings, especially if the bar is parented to a secure or Blizzard-provided frame.

- **Texture Mirroring:**
  - Flipping a texture with `SetTexCoord` or using a horizontally flipped asset can help, but may break if the bar uses a tiled or non-uniform texture.
  - Some bars require both `SetReverseFill(true)` and a flipped texture to look correct.

#### Summary

- Mirroring and reverse fill are possible using only allowed widget APIs, but require careful setup of textures, anchors, and overlays.
- Some Blizzard-provided bars (especially castbars) may not fully support mirroring due to hardcoded logic or protected frame restrictions.
- Always test with different units and in combat to ensure the effect is reliable and taint-free.

---

---

## Best Practices for AzeriteUI Developers

- **Always check for secret values** before using API returns in logic or as table indices.
- **Provide fallbacks** for UI display if a value is secret.
- **Use only Blizzard-documented widget methods** for UI manipulation.
- **Never use secret values in custom math, smoothing, or animation.**
- **Log all secret value bugs and fixes** in FixLog.md.
- **Test with `/reload` and debug toggles** after every change.
- **Validate**: No secret value errors, no forbidden API usage, no taint.
- **Update this document** as new APIs are used or as Blizzard changes restrictions.

---

---

## Further Reading

For the full, up-to-date API and system documentation, see:

- [WoW API Main](https://warcraft.wiki.gg/wiki/World_of_Warcraft_API)
- [API Change Summaries](https://warcraft.wiki.gg/wiki/API_change_summaries)
- [Protected Functions](https://warcraft.wiki.gg/wiki/Category:World_of_Warcraft_API/Protected_Functions)
- [Removed Functions](https://warcraft.wiki.gg/wiki/Category:World_of_Warcraft_API/Removed_Functions)
- [Widget API](https://warcraft.wiki.gg/wiki/Widget_API)

---

#### Last updated: February 23, 2026

---

## AzeriteUI: API Usage & Defensive Patterns

### Core Defensive Patterns

- **Always check for secret values** before using API returns in logic or as table indices.
- **Fallbacks**: Provide numeric or string fallbacks for UI display if a value is secret.
- **Debug logging**: Use toggleable debug output for all secret value handling.
- **Sanitize tables**: Use `scrubsecretvalues` or similar before iterating or displaying API data.
- **Respect load order**: Follow .toc and module load order for all API-dependent code.

### StatusBar & UnitFrame API

- Use only Blizzard-documented widget methods for StatusBar manipulation (SetMinMaxValues, SetValue, SetStatusBarTexture, SetOrientation, SetReverseFill, etc.).
- Never use secret values in custom math for bar growth, orientation, or spark logic.
- Use `issecretvalue` before using threat, selection, or reaction values as indices or for coloring.
- For auras, always check for secret status before displaying or filtering.

### Example: Defensive Health Bar Update

```lua
local health = UnitHealth(unit)
if issecretvalue(health) then
  health = 0 -- fallback or skip update
end
statusbar:SetValue(health)
```

### Example: Defensive Table Index

```lua
local threat = UnitThreatSituation(unit)
if not issecretvalue(threat) then
  local color = ThreatColors[threat]
  -- ...
end
```

---

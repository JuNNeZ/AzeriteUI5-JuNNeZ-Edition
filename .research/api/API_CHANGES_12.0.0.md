# WoW 12.0.0 API Changes - Best Practices Reference (Summary)

Source: https://raw.githubusercontent.com/Arahort/diabolic/refs/heads/github/API_CHANGES_12.0.0.md
Retrieved: 2026-01-25

This file is a condensed reference for AzeriteUI fixes and code reviews. It summarizes
the key practices from the source document and highlights where they intersect with
common error patterns we have been debugging (secret values, Edit Mode, castbars,
auras, cooldowns, and unit frames).

---

## 1) Secret Values (core concept)

- Secret values are restricted during tainted execution (combat or after interacting with protected frames).
- You can store or pass secret values to Blizzard widgets, but you cannot do direct math,
  comparisons, concatenation, or boolean tests on them in tainted code.
- Widgets can accept secret values safely; retrieving values back from widgets can return
  secret values.
- Text or positions derived from secret values can propagate secrecy (secret aspects / anchors).

Guiding rule: Avoid arithmetic or comparisons on data that might be secret. Let widgets
consume the values and perform internal handling.

---

## 2) Migration Highlights (API namespaces)

Prefer new C_ namespaces (add fallbacks for older clients if needed):

- C_Spell.* replaces legacy spell functions (GetSpellInfo, GetSpellCooldown, IsSpellOverlayed).
- C_ActionBar.* replaces action bar functions (GetActionCooldown, IsActionInRange, GetActionCharges).
- C_CombatLog.* replaces CombatLogGetCurrentEventInfo and related legacy functions.

---

## 3) Durations and Castbars

- Start/duration values can be secret.
- Use duration objects when needed (C_DurationUtil) instead of doing math on start/duration.
- For custom time text, avoid manual subtraction on secret durations; use framework callbacks.

---

## 4) Widgets and Status Bars

- Status bars can accept secret values directly:
  - SetMinMaxValues and SetValue are safe to call with secret numbers.
  - Avoid reading values back to do math; if needed, use PostUpdate callbacks with
    already-processed values from the framework.

---

## 5) Auras and Sorting

- Avoid sorting or comparing aura durations or expiration times directly if they may be secret.
- Prefer framework or API-provided sorting and filtering.

---

## 6) Tags and Text

- Avoid string concatenation with secret values in tags or text.
- Prefer PostUpdate callbacks, or use safe formatting functions if supported by the framework.
- If you must format, use guarded pcall and provide fallback text.

---

## 7) Testing Functions

- issecretvalue(value)
- canaccesssecrets()
- canaccessvalue(value)

Use these to detect secret values or taint state and decide safe paths.

---

## 8) Best-Practice Patterns for AzeriteUI Fixes

- Let widgets handle values: pass secret values to SetValue/SetMinMaxValues and avoid math.
- Use PostUpdate callbacks for visual tweaks instead of touching raw values.
- Prefer event-driven updates rather than OnUpdate loops.
- Avoid high-frequency pcall use; use it sparingly for risky text formatting.
- When wrapping Blizzard functions, sanitize inputs/returns and preserve behavior (do not
  hide functionality unless absolutely necessary).

---

## 9) Practical Fix Checklist

- Unit frames:
  - No direct arithmetic/comparison on UnitHealth/UnitPower results.
  - Use PostUpdate callbacks for colors/text.
- Castbars:
  - Avoid manual duration math; use duration objects or framework callbacks.
- Auras:
  - Avoid sorting by secret expiration times.
- Tooltips:
  - Wrap unsafe comparisons/concats in pcall or use safe formatters.

---

## 10) Source Links (from original doc)

The original document includes links to community and official resources that detail
the API changes and secret value model. See the source URL above for the full list.


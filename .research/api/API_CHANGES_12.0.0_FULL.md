# WoW 12.0.0 Midnight - API Changes Documentation (Full Text)
#
# Source: https://raw.githubusercontent.com/Arahort/diabolic/refs/heads/github/API_CHANGES_12.0.0.md
# Author: Arahort (alex@arahort.pro)
# Retrieved: 2026-01-25
#
# The content below is reproduced in full from the source for reference.

# WoW 12.0.0 Midnight - API Changes Documentation

Comprehensive guide to API changes, restrictions, and migration strategies for addon development in World of Warcraft patch 12.0.0 (Midnight expansion).

**Author:** Arahort (alex@arahort.pro)
**Date:** January 21, 2026
**Expansion:** Midnight (12.0.0)

---

## Table of Contents

1. [Overview](#overview)
2. [Secret Values System](#secret-values-system)
3. [Function Migrations](#function-migrations)
4. [New APIs](#new-apis)
5. [Removed/Deprecated APIs](#removeddeprecated-apis)
6. [Cooldown System Changes](#cooldown-system-changes)
7. [Widget Behavior Changes](#widget-behavior-changes)
8. [Common Issues & Solutions](#common-issues--solutions)
9. [Testing Functions](#testing-functions)
10. [Sources](#sources)

---

## Overview

Patch 12.0.0 introduces the most significant addon API changes since the protected function system. The core change is the **Secret Values** mechanism that restricts addon logic based on combat information while preserving UI customization capabilities.

### Key Impacts on Addons

- **Unit Frames:** Cannot directly compare or calculate with health/power values during combat
- **Cast Bars:** Must use new duration objects instead of direct time calculations
- **Cooldown Timers:** New APIs required for proper display
- **Auras:** Enhanced filtering and sorting capabilities
- **Tags:** Cannot concatenate secret values directly

**Release Timeline:**
- Pre-patch: January 21, 2026 (12.0.0)
- Expansion Launch: March 2, 2026 (12.0.1)

---

## Secret Values System

### What Are Secret Values?

Secret values are special Lua values that **cannot be operated on by tainted code** (code running during combat or on tainted execution paths). They are designed to prevent addons from making automated decisions based on combat data.

### Technical Restrictions

When execution is **tainted** (in combat or after interacting with protected frames):

#### ❌ Forbidden Operations

```lua
-- Arithmetic operations
local health = UnitHealth("player")
local maxHealth = UnitHealthMax("player")
local percent = health / maxHealth  -- ERROR: attempt to perform arithmetic on a secret value

-- Comparisons
if health > 1000 then  -- ERROR: attempt to compare secret value
    -- do something
end

-- Concatenation
local text = "Health: " .. health  -- ERROR: attempt to concatenate a secret value

-- Boolean tests
if not health then  -- ERROR in some contexts
    -- do something
end

-- Table operations (some cases)
local myTable = {}
myTable[health] = true  -- May error depending on context
```

#### ✅ Allowed Operations

```lua
-- Store in variables
local health = UnitHealth("player")  -- OK

-- Store in tables
local data = { health = health }  -- OK

-- Pass to functions
SomeFunction(health)  -- OK

-- Pass to WoW API functions
MyStatusBar:SetValue(health)  -- OK - widget handles secret internally
```

### When Are Values Secret?

Functions that **always return secrets:**
- `UnitHealth(unit)`
- `UnitPower(unit, powerType)`
- `UnitGetTotalAbsorbs(unit)`
- Cooldown durations when retrieved from certain APIs
- Cast bar durations

Functions that **conditionally return secrets:**
- `UnitName(unit)` - secret for enemies in combat
- `GetSpellCooldown()` - depends on spell and combat state

### Testing for Secret Values

```lua
-- Check if a value is secret
if issecretvalue(myValue) then
    print("Value is secret")
end

-- Check if current execution can access secrets
if not canaccesssecrets() then
    print("Execution is tainted")
end

-- Check if specific value can be accessed
if canaccessvalue(myValue) then
    print("Can access this value")
end
```

### Secret Aspects & Anchors

**Secret Aspects:**
When a widget receives a secret value, it gains a "secret aspect" for that property:

```lua
fontString:SetText(secretValue)  -- fontString gains "Text" secret aspect
local text = fontString:GetText()  -- Returns a secret value now!
```

**Secret Anchors:**
Frames anchored to frames with secret positions propagate secrecy:

```lua
frame1:SetPoint("LEFT", UIParent, "CENTER", secretOffset, 0)
-- frame1 now has secret position

frame2:SetPoint("LEFT", frame1, "RIGHT", 0, 0)
-- frame2 now also has secret position (propagated)
```

---

## Function Migrations

### Spell Functions → C_Spell

```lua
-- OLD (Removed)
IsSpellOverlayed(spellID)
GetSpellInfo(spellID)
GetSpellCooldown(spellID)

-- NEW
C_Spell.IsSpellOverlayed(spellID)
C_Spell.GetSpellInfo(spellID)
C_Spell.GetSpellCooldown(spellID)
```

**Migration Example:**

```lua
-- Before
local function UpdateOverlay(self)
    local spellId = self:GetSpellId()
    if spellId and IsSpellOverlayed(spellId) then
        ShowOverlayGlow(self)
    else
        HideOverlayGlow(self)
    end
end

-- After
local function UpdateOverlay(self)
    local spellId = self:GetSpellId()
    local isOverlayed = (C_Spell and C_Spell.IsSpellOverlayed)
        and C_Spell.IsSpellOverlayed(spellId)
        or (IsSpellOverlayed and IsSpellOverlayed(spellId))  -- Fallback for older versions
    if spellId and isOverlayed then
        ShowOverlayGlow(self)
    else
        HideOverlayGlow(self)
    end
end
```

### Action Bar Functions → C_ActionBar

```lua
-- OLD
GetActionCooldown(slot)
IsActionInRange(slot)
GetActionCharges(slot)

-- NEW
C_ActionBar.GetActionCooldown(slot)
C_ActionBar.IsActionInRange(slot)
C_ActionBar.GetActionCharges(slot)
```

### Combat Log Functions → C_CombatLog

```lua
-- OLD
CombatLogGetCurrentEventInfo()
-- Multiple legacy combat log functions

-- NEW
C_CombatLog.GetCurrentEventInfo()
C_CombatLog.GetFilterSetting(category)
C_CombatLog.SetFilterSetting(category, enabled)
```

---

## New APIs

### C_DurationUtil - Working with Secret Durations

Essential for handling cooldown and cast bar durations:

```lua
-- Create a duration object from secret or normal values
local durationObj = C_DurationUtil.CreateDuration(startTime, duration)

-- Duration object methods (hypothetical - check actual API)
durationObj:GetRemaining()  -- Returns remaining time
durationObj:GetProgress()   -- Returns 0-1 progress value
```

**Usage in Cooldowns:**

```lua
-- OLD
local start, duration = GetSpellCooldown(spellID)
cooldown:SetCooldown(start, duration)

-- NEW (if start/duration are secret)
local start, duration = C_Spell.GetSpellCooldown(spellID)
local durationObj = C_DurationUtil.CreateDuration(start, duration)
cooldown:SetCooldownFromDurationObject(durationObj)
```

### C_Spell - Spell Information

```lua
C_Spell.GetSpellInfo(spellID)
-- Returns: SpellInfo table with name, iconID, castTime, etc.

C_Spell.GetSpellCooldown(spellID)
-- Returns: start, duration (may be secret values)

C_Spell.IsSpellOverlayed(spellID)
-- Returns: boolean indicating if spell should show overlay glow

C_Spell.GetSpellCharges(spellID)
-- Returns: currentCharges, maxCharges, cooldownStart, cooldownDuration, chargeModRate
```

### C_UnitHealPrediction - Heal Prediction

New namespace for heal prediction (replaces direct calculation):

```lua
-- Use the new calculator object
local calculator = C_UnitHealPrediction.CreateCalculator()
calculator:SetUnit("player")

-- Get prediction values (these may NOT be secret with new API)
local myIncomingHeal = calculator:GetMyIncomingHeal()
local otherIncomingHeal = calculator:GetOtherIncomingHeal()
local totalAbsorb = calculator:GetAbsorb()
local healAbsorb = calculator:GetHealAbsorb()
```

### C_CurveUtil - Visualizing Secret Values

For creating visual representations of secret values:

```lua
-- Create a curve object
local curve = C_CurveUtil.CreateCurve()

-- Use with status bars to display secret values
statusBar:SetValueCurve(curve)
```

### C_ColorUtil - Color Conversion

```lua
C_ColorUtil.CreateColorFromHex(hexString)
C_ColorUtil.CreateColorFromRGBA(r, g, b, a)
C_ColorUtil.HSVToRGB(h, s, v)
C_ColorUtil.RGBToHSV(r, g, b)
```

### C_StringUtil - String Utilities

```lua
C_StringUtil.EscapeMarkup(text)
C_StringUtil.SplitString(text, delimiter)
C_StringUtil.TruncateString(text, maxLength)
```

---

## Removed/Deprecated APIs

### Removed in 12.0.0

**Combat Log Functions:**
- `CombatLogGetCurrentEventInfo()` → `C_CombatLog.GetCurrentEventInfo()`
- Various legacy combat log functions

**Spell Functions:**
- `IsSpellOverlayed()` → `C_Spell.IsSpellOverlayed()`
- `GetSpellInfo()` → `C_Spell.GetSpellInfo()`

**Instance Encounter:**
- Legacy encounter functions → `C_InstanceEncounter`

### Still Available But May Change

These functions still exist but addon authors should prepare for future deprecation:

```lua
UnitHealth(unit)  -- Still works, but returns secret values
UnitPower(unit, powerType)  -- Still works, but returns secret values
UnitGetTotalAbsorbs(unit)  -- Still works, but returns secret values
```

---

## Cooldown System Changes

### Old Cooldown API

```lua
-- Direct time-based cooldown
cooldownFrame:SetCooldown(startTime, duration)
```

### New Cooldown API

For secret duration values, use:

```lua
-- Method 1: SetCooldownFromDurationObject
local start, duration = C_Spell.GetSpellCooldown(spellID)
local durationObj = C_DurationUtil.CreateDuration(start, duration)
cooldownFrame:SetCooldownFromDurationObject(durationObj)

-- Method 2: Let widget handle secrets (if supported)
local start, duration = C_Spell.GetSpellCooldown(spellID)
cooldownFrame:SetCooldown(start, duration)  -- Widget may handle secret internally
```

### Charge Cooldowns

```lua
local currentCharges, maxCharges, cooldownStart, cooldownDuration = C_Spell.GetSpellCharges(spellID)

if currentCharges < maxCharges then
    -- Show cooldown for next charge
    cooldownFrame:SetCooldown(cooldownStart, cooldownDuration)
else
    -- Hide cooldown
    cooldownFrame:Hide()
end
```

---

## Widget Behavior Changes

### Status Bars

Status bars can now accept secret values directly:

```lua
local health = UnitHealth("player")
local maxHealth = UnitHealthMax("player")

-- This works even if health/maxHealth are secret
healthBar:SetMinMaxValues(0, maxHealth)
healthBar:SetValue(health)
```

**However,** getting values back may return secrets:

```lua
healthBar:SetValue(secretValue)
local value = healthBar:GetValue()  -- Returns secret value!
```

### Font Strings

Font strings gain "Text" secret aspect when displaying secret text:

```lua
-- Set secret text
fontString:SetText(secretHealthValue)

-- Getting text returns secret
local text = fontString:GetText()  -- Secret value!

-- Alternative: Use format strings that WoW API handles
fontString:SetFormattedText("%s / %s", secretCur, secretMax)  -- May work depending on context
```

### Cooldown Frames

Cooldown frames can display secret durations:

```lua
-- If start/duration are secret, use DurationObject
local durationObj = C_DurationUtil.CreateDuration(secretStart, secretDuration)
cooldown:SetCooldownFromDurationObject(durationObj)

-- Getting values back may return secrets
local start, duration = cooldown:GetCooldownTimes()  -- May be secret
```

---

## Common Issues & Solutions

### Issue 1: Empty Health/Power Orbs

**Problem:**
```lua
-- This fails if value is secret
local function SetValue(self, value)
    if value > self.maxValue then
        value = self.maxValue
    end
    self.bar:SetValue(value)
end
```

**Solution 1: Let Widget Handle It**
```lua
local function SetValue(self, value)
    -- Skip comparisons, let widget clamp
    self.bar:SetMinMaxValues(0, self.maxValue)
    self.bar:SetValue(value)  -- Widget handles secret clamping
end
```

**Solution 2: Use PostUpdate Callbacks**
```lua
-- oUF handles secret values internally
-- Use PostUpdate to update visuals without touching raw values
health.PostUpdate = function(element, unit, cur, max)
    -- Update colors, textures, etc.
    -- Don't try to calculate percentages
end
```

### Issue 2: Cast Bar Time Display

**Problem:**
```lua
-- Cannot do math on secret duration
local function UpdateTime(self, elapsed)
    self.duration = self.duration - elapsed  -- ERROR if secret
    self.timeText:SetFormattedText("%.1f", self.duration)
end
```

**Solution: Use Duration Formatters**
```lua
-- Use SecondsFormatter or similar WoW API utility
local function UpdateTime(self, elapsed)
    -- Let WoW handle the secret value formatting
    local formatter = CreateAndInitFromMixin(SecondsFormatterMixin)
    formatter:SetMinInterval(SecondsFormatter.Interval.Seconds)

    -- Or use custom PostUpdate that doesn't touch raw values
end
```

**Solution 2: Don't Update Manually**
```lua
-- oUF castbar element handles secret durations internally
cast.CustomTimeText = function(element, duration)
    -- This is called by oUF with proper handling
    -- duration may be processed value, not raw secret
    element.Time:SetFormattedText("%.1f", duration)
end
```

### Issue 3: Health Prediction Overlay

**Problem:**
```lua
local function UpdatePredict(element, unit, myIncomingHeal, otherIncomingHeal, absorb, healAbsorb, hasOverAbsorb, hasOverHealAbsorb, curHealth, maxHealth)
    local totalHeal = myIncomingHeal + otherIncomingHeal  -- ERROR if secret
    local percent = curHealth / maxHealth  -- ERROR if secret
end
```

**Solution: Use Ratio Bars**
```lua
local function UpdatePredict(element, unit, myIncomingHeal, otherIncomingHeal, absorb, healAbsorb, hasOverAbsorb, hasOverHealAbsorb, curHealth, maxHealth)
    -- Don't do math, set widget values directly
    element.healthBar:SetMinMaxValues(0, maxHealth)
    element.healthBar:SetValue(curHealth)

    -- Let separate bar show prediction
    element.predictBar:SetMinMaxValues(0, maxHealth)
    element.predictBar:SetValue(curHealth + myIncomingHeal + otherIncomingHeal)

    -- Texture coordinates calculated by widget, not by us
end
```

**Solution 2: Check for nil first (heal values may be nil)**
```lua
local function UpdatePredict(element, unit, myIncomingHeal, otherIncomingHeal, absorb, healAbsorb, hasOverAbsorb, hasOverHealAbsorb, curHealth, maxHealth)
    -- Values may be nil before becoming secret
    if not myIncomingHeal or not otherIncomingHeal then
        element:Hide()
        return
    end

    -- Then let widgets handle the secret values
    -- ...
end
```

### Issue 4: Aura Sorting/Filtering

**Problem:**
```lua
-- Cannot compare secret expiration times
table.sort(auras, function(a, b)
    return a.expirationTime < b.expirationTime  -- ERROR if secret
end)
```

**Solution: Use oUF Built-in Sorting**
```lua
-- oUF handles secret-safe sorting internally
auras.SortAuras = function(a, b)
    -- oUF provides safe sorting methods
    return a.priority > b.priority  -- Use non-secret properties
end

-- Or use new C_UnitAuras sorting APIs (check documentation)
```

### Issue 5: Tag Concatenation

**Problem:**
```lua
-- Cannot concatenate secret values
Methods["MyAddon:Health"] = function(unit)
    local cur = UnitHealth(unit)
    local max = UnitHealthMax(unit)
    return cur .. " / " .. max  -- ERROR if secret
end
```

**Solution 1: Use Format Functions**
```lua
Methods["MyAddon:Health"] = function(unit)
    local cur = UnitHealth(unit)
    local max = UnitHealthMax(unit)

    -- FontString:SetFormattedText can handle secrets in some cases
    -- But in tags, wrap in pcall or use alternative approach
    local success, result = pcall(function()
        return AbbreviateNumber(cur) .. " / " .. AbbreviateNumber(max)
    end)

    if success then
        return result
    else
        return ""  -- Or return nothing
    end
end
```

**Solution 2: Use PostUpdate Instead of Tags**
```lua
-- Instead of tag, use PostUpdate callback
health.PostUpdate = function(element, unit, cur, max)
    -- Let element handle the values, we just update appearance
    -- Don't try to format text directly from secret values
end
```

### Issue 6: Tooltip Health Values

**Problem:**
```lua
local function SetHealthValue(self, unit)
    local cur, max = UnitHealth(unit), UnitHealthMax(unit)
    if cur == max then  -- ERROR if secret
        self.text:SetText(cur)
    end
end
```

**Solution: Wrap in pcall**
```lua
local function SetHealthValue(self, unit)
    local cur, max = UnitHealth(unit), UnitHealthMax(unit)

    if cur and max then
        local success, result = pcall(function()
            if cur == max then
                return AbbreviateNumber(cur)
            else
                return AbbreviateNumber(cur) .. " / " .. AbbreviateNumber(max)
            end
        end)

        if success and result then
            self.text:SetText(result)
        else
            self.text:SetText("")
        end
    end
end
```

---

## Testing Functions

### Core Testing APIs

```lua
-- Check if value is secret
issecretvalue(value)
-- Returns: true if value is secret, false otherwise

-- Check if current execution can access secrets
canaccesssecrets()
-- Returns: false if execution is tainted and cannot access secrets

-- Check if specific value can be accessed
canaccessvalue(value)
-- Returns: true if value is not secret OR execution can access secrets
```

### Debugging Secret Values

```lua
-- Safe way to debug values
local function DebugValue(name, value)
    if issecretvalue(value) then
        print(name .. " = <secret value>")
    else
        print(name .. " = " .. tostring(value))
    end
end

local health = UnitHealth("player")
DebugValue("Player Health", health)
```

### Testing Taint State

```lua
local function CheckTaintState()
    if not canaccesssecrets() then
        print("Code is tainted - cannot access secrets")
    else
        print("Code is untainted - can access secrets")
    end
end
```

---

## Migration Checklist

### Critical Areas to Review

- [ ] **Unit Frames**
  - [ ] Health/power value displays use widgets directly
  - [ ] No direct arithmetic on health/power values
  - [ ] Tags use pcall or PostUpdate callbacks
  - [ ] Prediction overlays use widget positioning

- [ ] **Action Bars**
  - [ ] Cooldown display uses SetCooldownFromDurationObject if needed
  - [ ] IsSpellOverlayed migrated to C_Spell
  - [ ] Charge cooldowns handle secrets properly

- [ ] **Cast Bars**
  - [ ] Duration display uses proper formatting
  - [ ] No direct time arithmetic on secret durations
  - [ ] CustomTimeText doesn't operate on secrets

- [ ] **Auras**
  - [ ] Sorting doesn't compare secret values
  - [ ] Duration formatting uses WoW APIs
  - [ ] Cooldown spirals use proper APIs

- [ ] **Tooltips**
  - [ ] Health value comparisons wrapped in pcall
  - [ ] No direct concatenation of secret values

- [ ] **Libraries**
  - [ ] LibOrb-1.0: SetValue handles secrets
  - [ ] LibSmoothBar-1.0: SetMinMaxValues handles secrets
  - [ ] Custom libraries reviewed for secret value operations

### Testing Procedure

1. **Test Outside Combat (Untainted)**
   - Everything should work normally
   - Values should not be secret

2. **Test During Combat (Tainted)**
   - Check for Lua errors
   - Verify displays update correctly
   - Check that automation doesn't fail

3. **Test with Protected Frames**
   - Interact with Blizzard frames
   - Check taint propagation
   - Verify addon remains functional

4. **Check Error Log**
   ```lua
   /console scriptErrors 1  -- Enable Lua error display
   ```

---

## Best Practices

### 1. Minimize Direct Value Operations

❌ **Bad:**
```lua
local health = UnitHealth("player")
if health > 1000 then
    -- Do something
end
```

✅ **Good:**
```lua
-- Let widgets handle comparison
healthBar:SetValue(UnitHealth("player"))
-- Widget does internal comparison to maxValue
```

### 2. Use Callbacks, Not Direct Access

❌ **Bad:**
```lua
local value = statusBar:GetValue()
local percent = value / statusBar.maxValue
```

✅ **Good:**
```lua
statusBar.PostUpdate = function(element, cur, max)
    -- oUF provides processed values, not raw secrets
    -- Update appearance based on these
end
```

### 3. Wrap Uncertain Operations in pcall

❌ **Bad:**
```lua
local text = "Health: " .. health .. " / " .. maxHealth
```

✅ **Good:**
```lua
local success, text = pcall(function()
    return "Health: " .. health .. " / " .. maxHealth
end)
if not success then
    text = ""  -- Fallback
end
```

### 4. Check for nil Before Assuming Secret

Some values may be nil before they become secret:

```lua
local function Update(self, myHeal, otherHeal)
    -- Check nil first
    if not myHeal or not otherHeal then
        self:Hide()
        return
    end

    -- Then let widgets handle possible secrets
    -- ...
end
```

### 5. Use oUF Elements Properly

oUF framework handles most secret value issues internally if you use elements correctly:

```lua
-- Let oUF Health element handle secrets
self.Health = healthBar
self.Health.PostUpdate = function(element, unit, cur, max)
    -- Safe to update colors, etc.
    -- Don't touch cur/max directly
end

-- Let oUF Castbar element handle secrets
self.Castbar = castBar
self.Castbar.CustomTimeText = function(element, duration)
    -- duration is already processed by oUF
    element.Time:SetFormattedText("%.1f", duration)
end
```

---

## Performance Considerations

### Avoid Excessive pcall Usage

pcall has overhead. Don't use it in high-frequency updates:

❌ **Bad (High Frequency):**
```lua
frame:SetScript("OnUpdate", function(self, elapsed)
    local success, percent = pcall(function()
        return UnitHealth("player") / UnitHealthMax("player")
    end)
end)
```

✅ **Good (Let Widget Handle):**
```lua
-- Widgets update internally without your OnUpdate
healthBar:SetValue(UnitHealth("player"))
-- Widget handles secret values in C code, much faster
```

### Use Event-Driven Updates

Prefer event-driven updates over OnUpdate:

```lua
frame:RegisterUnitEvent("UNIT_HEALTH", "player")
frame:SetScript("OnEvent", function(self, event, unit)
    healthBar:SetValue(UnitHealth(unit))
end)
```

---

## Sources

Official documentation and community resources:

- [Patch 12.0.0 API Changes - Warcraft Wiki](https://warcraft.wiki.gg/wiki/Patch_12.0.0/API_changes)
- [Patch 12.0.0 Planned API Changes - Warcraft Wiki](https://warcraft.wiki.gg/wiki/Patch_12.0.0/Planned_API_changes)
- [Blizzard Relaxing More Addon Limitations - Icy Veins](https://www.icy-veins.com/wow/news/blizzard-relaxing-more-addon-limitations-in-midnight/)
- [WoW Midnight Addon Changes - Escapist Magazine](https://www.escapistmagazine.com/world-of-warcraft-midnight-addon/)
- [Majority of Addon Changes Finalized - Wowhead](https://www.wowhead.com/news/majority-of-addon-changes-finalized-for-midnight-pre-patch-whitelisted-spells-379738)
- [oUF PR #725 - Midnight WIP](https://github.com/oUF-wow/oUF/pull/725)

---

## Revision History

- **2026-01-21:** Initial documentation created for DiabolicUI3 adaptation

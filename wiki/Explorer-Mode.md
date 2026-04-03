# Explorer Mode

Explorer Mode is an immersive system that **fades UI elements** when they are not needed, giving you a cleaner, unobstructed view of the game world. The UI automatically reappears when the situation demands it.

Access via `/az → Explorer Mode`.

---

## Overview

When Explorer Mode is active and no exit conditions are met, configured UI elements become transparent or invisible. As soon as any exit condition triggers (combat, low health, target selected, etc.), the UI instantly returns to full opacity.

This lets you enjoy open-world exploration, cinematics, and relaxed play without UI clutter, while ensuring your interface is always visible when you actually need it.

---

## Timing

Control the delay before Explorer Mode activates after each situation:

| Timing Setting | Description | Range |
|---|---|---|
| **After Login** | Delay after character login before fading starts | 0–15 seconds |
| **After Reload** | Delay after `/reload` before fading starts | 0–15 seconds |
| **After Loading Screen** | Delay after any zone loading screen | 0–15 seconds |
| **After Combat Ends** | Delay after leaving combat before fading | 0–15 seconds |

> **Tip:** Setting a slightly longer "After Combat Ends" delay (e.g., 3–5 seconds) prevents the UI from flickering in and out during short combat pauses.

---

## Exit Conditions

Each condition below, when enabled, will **keep the UI visible** while that condition is true. Disable conditions you don't need to maximize UI transparency during those situations.

| Condition | Description |
|---|---|
| **While in Combat** | UI stays visible during combat |
| **While Having Low Health** | UI stays visible below a configurable health threshold (30–90%) |
| **While Having Low Mana** | UI stays visible below a configurable mana threshold |
| **Druid Form Mana Threshold** | Separate low-mana threshold for Druid forms |
| **While in a Group** | UI stays visible when in a party or raid |
| **While in an Instance** | UI stays visible in dungeons, raids, and scenarios |
| **While Targeting a Friendly Unit** | UI stays visible when you have a friendly target |
| **While Targeting a Hostile Unit** | UI stays visible when you have an enemy target |
| **While Targeting a Dead Unit** | UI stays visible when targeting a dead unit |
| **While Having a Focus Target** | UI stays visible when a focus target is set |
| **While in a Vehicle** | UI stays visible during vehicle sequences and replacement action bars |

---

## Elements to Fade

Choose exactly which UI elements are affected by Explorer Mode. Each element can be independently toggled:

| Element | Description |
|---|---|
| **Action Bars** | All main action bars (1–8) |
| **Pet Bar** | The pet ability bar |
| **Stance Bar** | The stance/form/presence bar |
| **Player Unit Frame** | Your health bar and power widget |
| **Player Class Power** | Combo points, Holy Power, Runes, etc. |
| **Pet Unit Frame** | Your pet's health frame |
| **Focus Unit Frame** | Your focus target frame |
| **Objectives Tracker** | The quest/mission tracker on the right side of the screen |
| **Chat Windows** | All chat windows |

> **Note:** Target, party, and raid frames are not included in Explorer Mode fading — they appear and disappear based on whether you have a valid target/group, not based on Explorer Mode timing.

---

## Common Configurations

### Casual / Open World
Fade everything except action bars. Keep all exit conditions enabled.

### Immersive Solo Play
Fade all elements. Keep combat and low health as exit conditions; disable group and instance conditions so the UI stays hidden during group content if desired.

### Raider
Disable Explorer Mode entirely, or set it to only fade chat and the objectives tracker. Enable "While in an Instance" as an exit condition to ensure nothing fades during raid encounters.

### Roleplay / Screenshot
Fade all elements, disable all exit conditions except low health. Gives maximum screen real estate for screenshots.

---

## Troubleshooting

**My UI disappears in dungeons:**
Enable the exit condition **While in an Instance** in Explorer Mode settings.

**My UI disappears when I'm in a group:**
Enable the exit condition **While in a Group**.

**The fade delay is too long/short after combat:**
Adjust the **After Combat Ends** timing slider.

**I want to fade bars but not my player frame:**
In the Elements to Fade section, disable **Player Unit Frame** while keeping **Action Bars** enabled.

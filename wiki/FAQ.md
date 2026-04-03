# Frequently Asked Questions

---

## General

**Q: How do I open the options menu?**

Type `/az` or `/azerite` in the chat. You can also find AzeriteUI in the Blizzard AddOns settings panel (`Esc → Options → AddOns`), but the most complete options are inside `/az`.

---

**Q: Something is wrong — how do I reset everything?**

Type `/resetsettings` in chat. **Warning: this permanently erases all profiles and saved settings.** You cannot undo this. It is an emergency-only option. Consider backing up your `WTF` folder first.

---

**Q: How do I move UI elements around?**

Type `/lock` in chat. Drag handles appear on all AzeriteUI-managed frames. Drag them to your preferred positions, then type `/lock` again to save. For Blizzard default frames, use WoW's built-in EditMode (`Esc → EditMode`).

---

**Q: Is this compatible with the official AzeriteUI?**

No. **Do not install both simultaneously.** This fan edition fully replaces the official addon and shares the same saved variable name.

---

**Q: Where can I get support?**

JuNNeZ has a dedicated channel in the [GoldpawsStuff Discord](https://discord.gg/RwcSm8V3Dy) for this edition. For bugs and feature requests, open a [GitHub Issue](https://github.com/JuNNeZ/AzeriteUI5-JuNNeZ-Edition/issues).

---

**Q: What version of WoW does this work with?**

AzeriteUI JuNNeZ Edition targets **WoW Retail 12.0.x** (the Midnight expansion). It will not work on Classic, Season of Discovery, or Wrath of the Lich King Classic.

---

**Q: I get Lua errors on every login. What do I do?**

1. Try `/reload` once — this often clears first-login errors.
2. Check if you have another UI addon (like ElvUI) installed alongside AzeriteUI — they conflict.
3. Check [GitHub Issues](https://github.com/JuNNeZ/AzeriteUI5-JuNNeZ-Edition/issues) to see if the error is a known bug.
4. Post the error text in the Discord channel or GitHub.

---

**Q: How do I enable Development Mode?**

Type `/devmode` in chat, or find the option in the settings panel. Development Mode unlocks experimental features like the Player Alternate Frame.

---

## Unit Frames

**Q: How do I switch between the orb-style and bar-style player frame?**

Enable Development Mode (`/devmode`), then go to `/az → Unit Frames → Player Alternate` and toggle between the two styles. Enabling one automatically disables the other.

---

**Q: Can I show health percentages on the player and target frames?**

Yes. Go to `/az → Unit Frames → Player` (or Target) and enable **Show Health Percent**.

---

**Q: How do I choose between the Power Crystal and the Mana Orb?**

In `/az → Unit Frames → Player`, look for **Player Power Style**. Options are:
- **Automatic (By Class)** — switches automatically based on your class resource
- **Mana Orb Only** — always uses the circular orb
- **Power Crystal Only** — always uses the vertical crystal

---

**Q: What is the "Ice Crystal Art" option?**

It replaces the power crystal's default texture with an alternate ice-themed design inspired by Wrath of the Lich King.

---

**Q: Can I hide the player castbar from the unit frame?**

Yes. Under `/az → Unit Frames → Player`, disable **Show Castbar**. You can still use the standalone **Cast Bar** module (a separate repositionable castbar).

---

**Q: How do I show party frames in a dungeon?**

Go to `/az → Unit Frames → Party Frames`. Under **Visibility**, make sure the appropriate group sizes are checked (e.g., "Party 2–5" and "Raid 1–5").

---

**Q: Party frames and raid frames are overlapping. How do I fix this?**

AzeriteUI has three raid frame styles (5-man, 25-man, 40-man) in addition to party frames. Each has independent visibility toggles. Configure them so only one frame type is active per group size. For example: Party Frames active for 2–5, Raid 5-man active for 6–10, Raid 25-man for 11–25, etc.

---

**Q: How do I track combo points / Holy Power / class resources?**

The **Player Class Power** module handles this automatically for your class. If it's not showing, check `/az → Unit Frames → Player Class Power` and ensure it's enabled. You can also reposition it with `/lock`.

---

**Q: My target frame is very large for some targets and small for others. Is that a bug?**

No — this is intentional. AzeriteUI uses **smart texture scaling** on the target frame: boss targets use a larger frame style, and critters use a smaller one. You can turn this off in `/az → Unit Frames → Target` if you prefer consistent sizing.

---

## Action Bars

**Q: How many action bars can I use?**

Up to **8 action bars** on Retail WoW 12, plus a Pet Bar and a Stance Bar.

---

**Q: What is the ZigZag layout?**

An alternating offset pattern for buttons, creating a staggered visual. Instead of a flat grid, every other row is offset horizontally. Configure the starting point with **Fade From Button** in bar settings.

---

**Q: My bars are invisible. What happened?**

Check these things in order:
1. Is **Enable Bar Fading** turned on for that bar? Hover over the bar's screen area to see if it appears.
2. Is **Only Show on Mouseover** enabled? Hover over the bar area.
3. Is **Explorer Mode** fading your bars? Check `/az → Explorer Mode → Elements to Fade`.
4. Is the bar enabled at all? Check `/az → Action Bars → Bar [number]`.

---

**Q: How do I make a bar only show when I mouse over it?**

1. Enable **Enable Bar Fading** for that bar.
2. Enable **Only Show on Mouseover**.

The bar will now be fully hidden until your mouse is in its screen area.

---

**Q: How do I remove an ability from the action bar?**

Hold **Alt + Ctrl + Shift** and **left-click drag** the ability off the bar. Standard drag-to-remove requires this modifier combination in AzeriteUI.

---

**Q: How do I use Bartender4 with AzeriteUI?**

Disable AzeriteUI's action bars in `/az → Action Bars` (disable bars 1–8, Pet Bar, and Stance Bar). Then configure Bartender normally. Note that AzeriteUI's visual styling will not apply to Bartender-managed buttons.

---

## Explorer Mode

**Q: What is Explorer Mode?**

An immersive feature that fades UI elements (action bars, unit frames, chat, etc.) when they are not needed — such as when out of combat with no target. The UI automatically reappears when any configured exit condition is triggered.

---

**Q: My UI keeps disappearing in dungeons. How do I fix it?**

In `/az → Explorer Mode`, enable the exit condition **While in an Instance**. This ensures Explorer Mode deactivates inside dungeons and raids.

---

**Q: My UI fades out when I'm in a group. How do I prevent this?**

Enable the exit condition **While in a Group** in Explorer Mode settings.

---

**Q: Can I keep some elements visible while fading others?**

Yes. In `/az → Explorer Mode → Elements to Fade`, toggle each element independently. For example, you can fade action bars but keep your player frame fully visible at all times.

---

## Nameplates

**Q: What do the enemy castbar colors mean?**

| Color | Meaning |
|---|---|
| 🟡 Yellow | Your interrupt is **ready** |
| 🔴 Red | Your interrupt is **on cooldown** |
| ⬜ Gray | The cast **cannot be interrupted** |
| Default | Interrupt state is **unknown** |

---

**Q: How do I make nameplates bigger or smaller?**

In `/az → Nameplates`, adjust the **Overall size (%)** slider. You can also fine-tune separate sliders for friendly, enemy, and NPC plates.

---

**Q: Can I hide health bars on friendly player nameplates?**

Yes. Enable **Use names only for friendly players** in `/az → Nameplates → Friendly Players`. This shows class-colored names and hides the health bar for friendly players.

---

**Q: Can I use Plater with AzeriteUI?**

Yes, but you should disable AzeriteUI's nameplate management. In `/az → Nameplates`, disable AzeriteUI nameplates and let Plater handle them.

---

## Auras

**Q: What's the difference between the "Aura Header" and unit frame auras?**

- **Aura Header** — The top-right buff/debuff display (your personal buffs). Configured via `/az → Auras`.
- **Unit Frame Auras** — Icons shown on individual unit frames (player, target, party, etc.). Configured per-frame in `/az → Unit Frames`.

---

**Q: How do I customize which buffs appear on my player frame?**

In `/az → Unit Frames → Player → Auras`, disable **Use AzeriteUI Stock Behavior** to unlock custom category toggles. Then enable only the buff/debuff categories you want to track.

---

**Q: Can I hide the top-right aura header?**

Yes. You can:
- Disable it entirely in `/az → Auras`
- Set it to **Fade When Idle**
- Require a modifier key (**Only Show With Modifier Key**)

---

**Q: My auras are dimmed and I don't know why.**

AzeriteUI's Stock Behavior dims lower-priority auras. To disable dimming, go to `/az → Unit Frames → Player → Auras` and enable **Always Show Full Brightness**.

---

## Chat

**Q: Why is my chat empty after logging in?**

The **Clear Chat On Reload** feature temporarily blocks old messages for a short delay. Hold **Shift** during login to bypass it. You can also disable it or reduce the delay in `/az → Chat`.

---

**Q: How do I stop chat from fading?**

In `/az → Chat`, disable **Fade Chat**.

---

## Tooltips

**Q: Can I use my own tooltip addon instead of AzeriteUI's tooltips?**

Yes. In `/az → Tooltips`, enable **Disable AzeriteUI Tooltips**. This lets Blizzard or another addon handle tooltip styling.

---

**Q: My compare tooltips overlap each other when hovering over rings/trinkets.**

This was fixed in version 5.3.52-JuNNeZ. Make sure you're on the latest version. If it still happens, report it as a GitHub issue.

---

## Technical

**Q: What does "secret-value compatibility" mean?**

WoW 12 (Midnight) introduced "secret-valued" numbers — certain API return values are obscured in restricted combat environments to reduce addon taint. AzeriteUI JuNNeZ Edition patches affected code paths to safely read these values using Blizzard's recommended patterns.

---

**Q: What is Development Mode?**

A hidden mode that enables experimental and in-progress features:
- Player Alternate Frame (bar-style player frame)
- Debug menu and aura snapshot commands
- Additional experimental toggles

Enable it with `/devmode`. It is intended for testing, not regular use.

---

**Q: Does AzeriteUI work with WeakAuras?**

Yes. WeakAuras and AzeriteUI do not conflict. You can use WeakAuras for custom tracking alongside AzeriteUI's built-in aura systems.

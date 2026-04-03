# Compatibility

AzeriteUI JuNNeZ Edition is designed to coexist gracefully with many popular addons. This page covers known integrations, conflicts, and recommendations.

---

## Fully Supported

These addons are tested and integrate with AzeriteUI:

| Addon | Integration Notes |
|---|---|
| **Clique** | Click-casting fully works on all AzeriteUI unit frames. Clique is listed as an optional dependency. |
| **Decursive** | The JuNNeZ Edition includes specific WoW 12 compatibility patches for Decursive's dispel detection. Works correctly in combat. |
| **TaintLess** | Bundled as an optional dependency. Reduces taint warnings on WoW 12. Highly recommended. |
| **LibSharedMedia** | Bundled. Allows other addons to provide AzeriteUI with custom fonts and textures through the shared media registry. |
| **LibEditModeOverride** | Bundled. Enables AzeriteUI to auto-load custom Edit Mode layouts on profile switch. |
| **LibKeyBound** | Bundled. Provides consistent keybinding UI for action buttons. |

---

## Partial Support / Auto-Detection

| Addon | Behavior |
|---|---|
| **ConsolePort** | Automatically detected by AzeriteUI. When ConsolePort is active, AzeriteUI disables its tooltip styling and cursor anchoring to avoid conflicts. Action bar management defers to ConsolePort. |
| **Bartender4** | If you prefer Bartender for action bars, disable AzeriteUI's action bars in `/az → Action Bars`. Note: AzeriteUI's visual action bar style (dimming, Azerite aesthetics) will not apply to Bartender-managed bars. |

---

## Addons That Require Configuration

These addons can conflict with AzeriteUI if both are active and managing the same UI element. Choose one and disable the other's management of that element.

| Addon | Conflict Area | Recommendation |
|---|---|---|
| **Plater Nameplates** | Nameplates | Disable AzeriteUI nameplates in `/az → Nameplates` and let Plater manage nameplates |
| **KuiNameplates** | Nameplates | Same as Plater — disable AzeriteUI's nameplate styling |
| **ElvUI** | Everything | AzeriteUI and ElvUI are both full UI replacements. **Do not use both simultaneously.** |
| **ShadowedUF / oUF layouts** | Unit Frames | AzeriteUI uses oUF internally; using external oUF layouts may conflict. Not recommended. |
| **MoveAnything** | Frame positions | May conflict with `/lock` frame positioning. Use one or the other. |
| **Dominos / Bartender4** | Action Bars | Choose one action bar addon. Disable AzeriteUI's bars if using Dominos/Bartender. |
| **KGPanels / Sunn Viewport** | Viewport / backgrounds | May conflict with AzeriteUI's frame layout at certain screen sizes |

---

## Not Compatible

| Addon | Reason |
|---|---|
| **AzeriteUI 5 (Official)** | This fan edition **replaces** the official release. **Never install both simultaneously.** They share the same saved variable name (`AzeriteUI5_DB`) and will conflict. |
| **AzeriteUI 4 or earlier** | Different addon name/saved variable, but will cause confusion. Not tested together. |

---

## Bundled Libraries

AzeriteUI bundles the following libraries internally. You do not need to install them separately:

| Library | Purpose |
|---|---|
| **Ace3** (AceAddon, AceDB, AceConsole, AceConfig, AceLocale, AceHook) | Core addon framework, options panel, saved variables |
| **oUF** | Unit frame framework |
| **LibMoreEvents** | Extended event system for WoW |
| **LibActionButton-1.0-GE** | Action button management with WoW 12 patches |
| **LibEditModeOverride** | Edit Mode layout integration |
| **LibKeyBound** | Keybinding interface |
| **LibSharedMedia** | Shared font/texture registry |
| **LibFadingFrames** | Frame fade system for action bars and Explorer Mode |
| **LibOrb** (by Arahort) | Mana Orb circular power display |
| **TaintLess** | WoW taint mitigation |
| **!LibUIDropDownMenu** | Replacement dropdown menu library |

---

## Localization

AzeriteUI ships with built-in translations for:

| Locale | Language |
|---|---|
| enUS | English (default) |
| deDE | German |
| esES | Spanish |
| frFR | French |
| ruRU | Russian |
| ptBR | Portuguese (Brazil) |
| koKR | Korean |
| zhCN | Chinese (Simplified) |
| zhTW | Chinese (Traditional) |
| itIT | Italian |

No additional localization addons are needed.

---

## Reporting Compatibility Issues

If you find an addon that conflicts with AzeriteUI JuNNeZ Edition:

1. Open a [GitHub Issue](https://github.com/JuNNeZ/AzeriteUI5-JuNNeZ-Edition/issues) describing the conflict
2. Include both addon names, versions, and what behavior you see
3. Check the [CHANGELOG](https://github.com/JuNNeZ/AzeriteUI5-JuNNeZ-Edition/blob/main/CHANGELOG.md) to see if it's already been addressed

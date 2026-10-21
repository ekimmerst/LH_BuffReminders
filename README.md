# LH_Reminders

Version: 1.0.0. WoW Forever (Interface 16001).

LH_Reminders shows clickable icons for selected buffs that are missing on the player. The addon is grouped under LH Tweaks in the AddOn list and has a native page at **Settings > AddOns > LH Tweaks > LH Reminders**. Its icon is copied from LH Tweaks.

## Buff selection

The settings page has an icon-and-name list for the current class. Use `x` to remove an entry. Type the name or spell ID of a **learned** buff in the field below the list and press `+` or Enter to add it. Duplicate buff families are rejected. The list scrolls when it grows beyond six entries. The reminder icon disappears while the matching player buff is active and returns when it expires. Clicking a reminder casts the selected spell on yourself. Another character of the same class uses the same selection; other classes have separate lists. Buffs not yet learned by a lower-level character do not appear as clickable reminders until learned.

Shamans initially retain the original weapon-enchantment and shield reminders. Any active weapon enchantment on either weapon satisfies the weapon reminder, and Lightning Shield, Water Shield and Earth Shield count as alternatives for the shield reminder. The addon checks player auras and equipped weapon tooltips, including existing buffs after login or reload. The weapon reminder is hidden when no weapon is equipped. Remove either default entry with `x` if you do not want it. Other classes begin with an empty list; Hunter aspects can be added through the same picker.

The page also has activation and unlock/preview controls. The reminder icons are 36 UI pixels, glow gold and are centered around the saved position with an 8-pixel gap. Unlock shows a draggable preview icon. All icon changes are deferred until combat ends because the icons are secure cast buttons. Reminders are hidden while the player is dead.

## Class-wide saved settings

`LH_RemindersClassDB` stores each class's monitored buffs, exceptions, activation, lock state and position for the whole account. An existing character's `LH_RemindersDB` position and exceptions are copied into its class's settings the first time that class is initialized; subsequent characters of the same class use the shared values. The former per-character variable remains declared only so this migration can read it.

## Commands

- `/lh_reminders`: open the native settings page.
- `/lh_reminders unlock`: show a preview icon; left-drag it to move the reminders.
- `/lh_reminders lock`: save the position and show missing buffs.
- `/lh_reminders except "Lightning Shield"`: suppress a buff reminder for this class.
- `/lh_reminders allow "Lightning Shield"`: allow it again.

The legacy exception commands continue to match all ranks and ignore capitalization. Changes made during combat update the display after combat.

## Installation and upgrade

Place the complete `LH_Reminders` folder under `Interface/AddOns`, including `LH_Reminders.toc`, `LH_Reminders.lua`, `Settings.lua`, `BuffList.xml` and `Media`. Install and enable LH_Tweaks as a required addon. A full WoW restart is needed for this upgrade because the TOC loads new settings files, account-wide saved variables and icon/group metadata.

If upgrading from MiniReminders, replace its folder with LH_Reminders and restart. To migrate old saved values, close WoW and copy the character's `SavedVariables/MiniReminders.lua` to `SavedVariables/LH_Reminders.lua`, then rename `MiniRemindersDB` to `LH_RemindersDB` inside the copy before starting WoW. Do not overwrite existing LH_Reminders data you want to keep.

## Verification

`python LH_Reminders/_run_tests.py` covers the existing Shaman buff, weapon, secure button, combat and command behavior. `python LH_Reminders/_settings_test.py` covers Hunter aspects, add/remove, aura matching, class switching, activation, the native page and its icon/name/`x`/`+` controls. Both run from the AddOns folder. Native visual layout and secure casting still require in-game verification.

## Changelog

### 1.0.0 - 2026-10-21

- Added native settings under LH Tweaks, the shared gold icon and AddOn grouping.
- Added a scrollable class-specific buff list with spell icons, names, remove buttons and an add field/button.
- Moved active settings to an account-wide class table, migrating existing per-character positions and exceptions on first use.
- Preserved Shaman weapon and shield reminders as the class defaults; enabled selected buff reminders for other classes.

## Required core addon

LH_Tweaks must be installed and enabled so the configuration category can load. CurseForge releases must list it as a required dependency.

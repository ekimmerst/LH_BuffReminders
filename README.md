# LH_Reminders

Version: 0.3.1. WoW Forever (Interface 16001).

Reminds Shamans when a weapon enchantment or shield buff is missing. Any active weapon enchantment on either weapon satisfies the weapon reminder. Shaman weapon buffs are also recognized as player auras, across all ranks; for example, "Rockbiter 2" counts as Rockbiter. Both equipped weapon tooltips are checked as well, including after login or a reload with an existing buff.

Lightning Shield, Water Shield and Earth Shield on the player count as alternatives. Only learned spells are suggested. Other classes do not yet receive reminders. The weapon reminder is hidden when no weapon is equipped, and all reminders are hidden while dead.

The icons are 36 by 36 UI pixels, glow gold and are centered around the saved position with an 8-pixel gap. Left-click an icon to cast its displayed buff on yourself. During combat, the current display and spell assignments are retained; reminders update after combat. Moving is available outside combat.

## Commands

- `/lh_reminders unlock`: replace reminders with a preview icon. Hold the left mouse button and drag to move it.
- `/lh_reminders lock`: lock the position and replace the preview with actual missing buffs.
- `/lh_reminders except "Lightning Shield"`: disable the reminder for that buff. All ranks are treated together, and names are case-insensitive.
- `/lh_reminders allow "Lightning Shield"`: enable the reminder again.

Exceptions apply to the suggested buff and are saved per character. Changes during combat update the display after combat. The preview icon remains visible independently of exceptions. Position and exceptions are stored in `LH_RemindersDB`; the unlock preview is not a saved setting.

## Installation and upgrade

Place the `LH_Reminders` folder in your game's `Interface/AddOns` folder. It must contain `LH_Reminders.toc` and `LH_Reminders.lua`. Restart WoW and enable **LH_Reminders** in the addon list.

When upgrading from MiniReminders, replace the old folder and fully restart WoW. Do not enable both versions together. Commands now use `/lh_reminders`.

To retain your position and exceptions, close WoW and back up each character's `WTF/Account/<account>/<realm>/<character>/SavedVariables/MiniReminders.lua` file. Copy it to `LH_Reminders.lua` in the same SavedVariables folder, then change `MiniRemindersDB` to `LH_RemindersDB` inside the copy. Migrate before first using the renamed addon; do not overwrite an existing `LH_Reminders.lua` containing settings you want to keep. Without migration, the addon uses the default position with no buff exceptions.

## Changelog

### 0.3.1 - 2026-10-21

- Renamed MiniReminders to LH_Reminders, including the addon folder, Lua/TOC files, metadata, named frames, tooltip references, saved-variable table and test references.
- Changed the chat command to `/lh_reminders`.
- Translated documentation, chat messages and addon tooltip instructions into English.
- Added instructions for transferring the saved position and buff exceptions.

## Required core addon

Install and enable **LH_Tweaks** alongside this addon. LH_Tweaks is the shared LiteHawk configuration host and must load first. CurseForge releases must list LH_Tweaks as a required dependency so the client installs it automatically.

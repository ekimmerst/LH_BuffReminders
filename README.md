<h1 style="color: #d9a94b;">LH BuffReminders</h1>

<p>Get a small, movable on-screen reminder when a selected class buff is missing, with separate checks in and out of combat.</p>

<p>For the buff you meant to cast before setting off. LH BuffReminders gives you a small on-screen reminder when one of your chosen class buffs is missing.</p>

<h2 style="color: #73c9c4;">Choose your reminders</h2>

<ul>
  <li>Add a learned buff by its name or spell ID.</li>
  <li>Choose separately whether to watch for it in combat or out of combat.</li>
  <li>Optionally show a Cooking icon when no Well Fed food buff is active, regardless of which food provided it. This reminder is off by default.</li>
  <li>For a missing buff whose cast spell has a cooldown, show its reminder only when that spell is ready again. An available charge also counts as ready.</li>
  <li>Show new reminders only while their spells are usable. A missing-buff reminder already visible in combat stays visible through a temporary form restriction.</li>
  <li>Reminder icons are display-only and stay centered together, even when their number changes during combat.</li>
  <li>Unlock a draggable preview to place the reminder where it suits your UI.</li>
</ul>

<p>Monitored buffs, exclusions and the food reminder switch are saved per character. Existing class-wide choices are copied to each character the first time it loads this version. Position and lock state can follow another character through the settings profile; activation remains per character.</p>

<p>In combat, WoW may keep aura details secret. A buff already known to be missing before combat can still trigger a reminder when its spell is usable. Once visible, that reminder stays visible through a temporary form restriction. If a buff disappears during combat while its aura is hidden, the addon may be unable to detect the loss. An unknown aura state is not treated as a missing buff, and cooldown readiness alone does not prove that the buff is gone.</p>

<h2 style="color: #c78be6;">Settings</h2>

<p>Open <strong>Options → AddOns → LH Tweaks → LH BuffReminders</strong> to enable reminders, switch on <strong>Remind me to eat buff food</strong>, add or remove buffs and set when each one should be watched. The food reminder checks the player's Well Fed aura and appears beside the other icons with the Cooking symbol. The list accepts learned buff names or IDs.</p>

<h2 style="color: #c78be6;">Settings profiles</h2>

<p>Choose a character under <strong>Use settings from</strong> to share reminder position and lock state, or apply the source chosen in LH Tweaks to all LH addons. Enabled state, food reminder choice, monitored buffs, combat watch choices and exclusions remain individual. <strong>This character</strong> restores your own position and lock state.</p>

<h2 style="color: #73c9c4;">More LH addons</h2>

<p>Choose only the pieces you want. Most companion addons require LH Tweaks; LH NameplateQuestInfo also works without it.</p>

<ul>
  <li><strong>LH AuraBars:</strong> Compact bars for buffs, debuffs and spell cooldowns.</li>
  <li><strong>LH CooldownPulse:</strong> Flashes an ability icon when its cooldown finishes.</li>
  <li><strong>LH ExpBar:</strong> A minimal experience bar with rested XP.</li>
  <li><strong>LH HideMe:</strong> Hides selected parts of the default UI, individually or all at once.</li>
  <li><strong>LH JobsDone:</strong> Plays the Warcraft peasant voice when a quest is ready to turn in.</li>
  <li><strong>LH MailBags:</strong> Opens your bags at the mailbox, with optional closing.</li>
  <li><strong>LH MP5:</strong> Shows an estimated five-second timer on the player mana bar.</li>
  <li><strong>LH NameplateQuestInfo:</strong> Adds quest markers and objective progress to nameplates.</li>
  <li><strong>LH NameplateThreatColors:</strong> Colors Blizzard nameplates by threat and role.</li>
  <li><strong>LH PetStats:</strong> Shows hunter pet loyalty beside the pet portrait.</li>
  <li><strong>LH Range:</strong> Shows melee range, configurable spell-range zones for every class, and a live non-Mana resource bar in melee range.</li>
  <li><strong>LH Skills:</strong> Shows profession ranks in a movable compact bar.</li>
  <li><strong>LH Stats:</strong> Shows money, free bag slots and remaining ammo below the minimap.</li>
  <li><strong>LH SwingTimer:</strong> Shows main-hand and ranged swing timers below the player cast bar.</li>
  <li><strong>LH TinyDPS:</strong> Shows built-in damage meter data in a compact separate window.</li>
  <li><strong>LH Tweaks:</strong> Provides the shared settings hub plus chat, positioning, merchant and fishing tweaks.</li>
</ul>

<h2 style="color: #d9a94b;">Installation and feedback</h2>

<p><strong>LH Tweaks is required</strong> and must be installed alongside LH BuffReminders. I made this for the buffs I kept forgetting myself. If a class buff does not behave as expected, or you have an idea to improve the reminders, please tell me in the CurseForge comments.</p>

<h2 style="color: #73c9c4;">Changelog</h2>

<p><strong>1.3.5 - Forever and Retail</strong></p>

<ul>
  <li>Add an optional per-character Cooking icon reminder when no Well Fed food buff is active.</li>
</ul>

<p><strong>1.3.4 - Forever and Retail</strong></p>

<ul>
  <li>Prevent false missing-buff alerts for active auras whose state is hidden in combat, including Mark of the Wild.</li>
  <li>Center the combat layout using only buffs with a known missing state.</li>
</ul>

<p><strong>1.3.3 - Forever and Retail</strong></p>

<ul>
  <li>Keep all visible reminder icons adjacent and centered as buffs, forms and cooldowns change during combat.</li>
  <li>Remove spell casting by clicking reminder icons. The position preview can still be dragged while unlocked.</li>
</ul>

<p><strong>1.3.2 - Forever and Retail</strong></p>

<ul>
  <li>Hide reminders while their spells are unusable, for example Enrage outside Bear Form.</li>
  <li>Use the readable cooldown activity flag when cooldown times are hidden in combat.</li>
</ul>

<p><strong>1.3.1 - Forever and Retail</strong></p>

<ul>
  <li>Wait until the triggering spell's cooldown has finished before showing a missing-buff reminder. Available charges remain usable.</li>
</ul>

<p><strong>1.3.0 - Forever and Retail</strong></p>

<ul>
  <li>Added a character settings source for reminder position and lock state.</li>
  <li>Monitored buffs, watch choices and exclusions are now saved per character. Existing class settings are copied on first load.</li>
</ul>

<p><strong>1.2.1 - Forever</strong></p>

<ul>
  <li>Newly shown missing-buff icons briefly grow and shrink to draw attention.</li>
</ul>

<hr>
<p><sup>*</sup> Implemented with the help of Codex and GPT-6-SOL. Not every class and race ability may be covered yet; please report anything you notice.</p>

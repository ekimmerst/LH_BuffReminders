<h1 style="color: #d9a94b;">LH BuffReminders</h1>

<p>For the buff you meant to cast before setting off. LH BuffReminders gives you a small on-screen reminder when one of your chosen class buffs is missing.</p>

<h2 style="color: #73c9c4;">Choose your reminders</h2>

<ul>
  <li>Add a learned buff by its name or spell ID.</li>
  <li>Choose separately whether to watch for it in combat or out of combat.</li>
  <li>Unlock a draggable preview to place the reminder where it suits your UI.</li>
</ul>

<p>Your monitored buffs and layout are shared by characters of the same class, so you only need to set them up once per class.</p>

<h2 style="color: #c78be6;">Settings</h2>

<p>Open <strong>Options → AddOns → LH Tweaks → LH BuffReminders</strong> to enable reminders, add or remove buffs and set when each one should be watched. The list accepts learned buff names or IDs.</p>

<h2 style="color: #c78be6;">Upgrading from LH Reminders</h2>

<p>Replace the old <code>LH_Reminders</code> addon folder with <code>LH_BuffReminders</code> and restart WoW. To keep your class-wide buff lists and positions, close WoW first, copy <code>WTF/Account/&lt;account&gt;/SavedVariables/LH_Reminders.lua</code> to <code>LH_BuffReminders.lua</code>, and replace <code>LH_RemindersClassDB</code> with <code>LH_BuffRemindersClassDB</code> inside the copy. If you also have older per-character settings to keep, copy each character's <code>SavedVariables/LH_Reminders.lua</code> to <code>LH_BuffReminders.lua</code> and replace <code>LH_RemindersDB</code> with <code>LH_BuffRemindersDB</code> inside that copy. Keep the original files as backups until you have checked your settings in game.</p>

<h2 style="color: #73c9c4;">More LH addons</h2>

<p>Choose only the pieces you want. Each companion addon also requires LH Tweaks.</p>

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
  <li><strong>LH Range:</strong> Shows melee range and Shaman or Hunter spell-range zones.</li>
  <li><strong>LH Skills:</strong> Shows profession ranks in a movable compact bar.</li>
  <li><strong>LH Stats:</strong> Shows money, free bag slots and remaining ammo below the minimap.</li>
  <li><strong>LH SwingTimer:</strong> Shows main-hand and ranged swing timers below the player cast bar.</li>
  <li><strong>LH TinyDPS:</strong> Shows built-in damage meter data in a compact separate window.</li>
  <li><strong>LH Tweaks:</strong> Provides the shared settings hub plus chat, positioning, merchant and fishing tweaks.</li>
</ul>

<h2 style="color: #d9a94b;">Installation and feedback</h2>

<p><strong>LH Tweaks is required</strong> and must be installed alongside LH BuffReminders. I made this for the buffs I kept forgetting myself. If a class buff does not behave as expected, or you have an idea to improve the reminders, please tell me in the CurseForge comments.</p>

<hr>
<p><sup>*</sup> Implemented with the help of Codex and GPT-6-SOL and tested by me as thoroughly as I could in the WoW beta client. Not every class and race ability may be covered yet; please report anything you notice.</p>

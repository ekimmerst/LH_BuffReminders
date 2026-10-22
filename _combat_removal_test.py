"""Regression checks for aura removals while secure buttons are locked."""
from pathlib import Path
import os
import sys

root = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(root / 'LH_Tweaks/.test-runtime'))
from lupa.lua51 import LuaRuntime

assert 'COMBAT_LOG_EVENT_UNFILTERED' not in (root / 'LH_BuffReminders/LH_BuffReminders.lua').read_text(encoding='utf-8')
os.chdir(root)
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute((root / 'LH_BuffReminders/_test.lua').read_text(encoding='utf-8'))
lua.execute('''
local originalInfo, originalKnown = GetSpellInfo, IsPlayerSpell
GetSpellInfo = function(id)
    if id == 6673 then return 'Battle Shout', nil, 'ShoutIcon' end
    return originalInfo(id)
end
IsPlayerSpell = function(id) return id == 6673 or originalKnown(id) end
GetNumSpellTabs = function() return 1 end
GetSpellTabInfo = function() return 'Warrior', nil, 0, 1 end
GetSpellBookItemInfo = function() return 'SPELL', 6673 end
local now = 100
GetTime = function() return now end
TestRemindersSetClass('WARRIOR')
assert(LH_BuffReminders:AddBuff('Battle Shout'))
local aura = {name='Battle Shout', spellId=6673, auraInstanceID=77}
C_UnitAuras = {GetUnitAuras=function() return {aura} end}
TestRemindersEvent('UNIT_AURA', 'player')
assert(#TestRemindersVisible()==0)
TestRemindersCombat(true)
TestRemindersEvent('PLAYER_REGEN_DISABLED')
-- A complete empty scan is enough when the client sends no removal IDs.
C_UnitAuras.GetUnitAuras = function() return {} end
TestRemindersEvent('UNIT_AURA', 'player')
assert(#TestRemindersVisible()==1, 'Missing Battle Shout with no removal payload was missed')
-- A complete batch scan stays conclusive if indexed aura lookups are denied.
C_UnitAuras.GetUnitAuras = function() return {{name='Other buff'}} end
C_UnitAuras.GetAuraDataByIndex = function() error('restricted index') end
TestRemindersEvent('UNIT_AURA', 'player')
assert(#TestRemindersVisible()==1, 'Restricted index overrode a complete batch scan')
-- A newly observed aura hides the icon again.
C_UnitAuras.GetUnitAuras = function() return {aura} end
TestRemindersEvent('UNIT_AURA', 'player', {addedAuras={aura}})
assert(#TestRemindersVisible()==0)
-- The old aura can remain visible to list scans after its removal event.
TestRemindersEvent('UNIT_AURA', 'player', {removedAuraInstanceIDs={77}})
assert(#TestRemindersVisible()==1, 'Aura removal must override a stale scan')
-- A new cast clears the removal and hides the reminder again.
now = 101
TestRemindersEvent('UNIT_SPELLCAST_SUCCEEDED', 'player', 'cast-guid', 6673)
assert(#TestRemindersVisible()==0)
-- The next aura event gives the new instance and restores tracking.
local newAura = {name='Battle Shout', spellId=6673, auraInstanceID=88}
C_UnitAuras = {GetUnitAuras=function() return {newAura} end}
TestRemindersEvent('UNIT_AURA', 'player', {addedAuras={newAura}})
assert(#TestRemindersVisible()==0)
TestRemindersEvent('UNIT_AURA', 'player', {removedAuraInstanceIDs={88}})
assert(#TestRemindersVisible()==1, 'Recast Battle Shout removal was missed')
-- The legacy aura API also supplies an expiry, which must survive an unreadable fight.
TestRemindersCombat(false)
C_UnitAuras = nil
UnitBuff = function(_, index)
    if index == 1 then return 'Battle Shout', nil, nil, nil, 120, now + 2 end
end
TestRemindersEvent('PLAYER_REGEN_ENABLED')
assert(#TestRemindersVisible()==0)
TestRemindersCombat(true)
TestRemindersEvent('PLAYER_REGEN_DISABLED')
UnitBuff = function() error('restricted aura scan') end
now = now + 1
TestRemindersEvent('UNIT_AURA', 'player')
assert(#TestRemindersVisible()==0, 'Battle Shout expired too early')
now = now + 2
TestRemindersEvent('UNIT_AURA', 'player')
assert(#TestRemindersVisible()==1, 'Legacy Battle Shout expiry was missed')
''')
print('PASS: Battle Shout removal by complete scan and aura event, recast tracking and legacy expiry')

from pathlib import Path
import sys

root = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(root / 'LH_Tweaks/.test-runtime'))
from lupa.lua51 import LuaRuntime

lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute((root / 'LH_BuffReminders/_test.lua').read_text(encoding='utf-8'))
lua.execute('''
local oldInfo,oldKnown=GetSpellInfo,IsPlayerSpell
GetSpellInfo=function(id)
 if id==13165 then return 'Aspect of the Hawk',nil,'HawkIcon' end
 if id==5118 then return 'Aspect of the Cheetah',nil,'CheetahIcon' end
 return oldInfo(id)
end
IsPlayerSpell=function(id) return id==13165 or id==5118 or oldKnown(id) end
GetNumSpellTabs=function() return 1 end
GetSpellTabInfo=function() return 'Hunter',nil,0,2 end
GetSpellBookItemInfo=function(slot) return 'SPELL',slot==1 and 13165 or 5118 end
TestRemindersSetClass('HUNTER')
assert(#LH_BuffReminders:GetMonitored()==0 and LH_BuffRemindersClassDB.HUNTER.enabled)
local ok,message=LH_BuffReminders:AddBuff('Aspect of the Hawk')
assert(ok and #LH_BuffReminders:GetMonitored()==1,message)
assert(LH_BuffReminders:GetEntry(1)=='Aspect of the Hawk')
ok=LH_BuffReminders:AddBuff('13165');assert(not ok and #LH_BuffReminders:GetMonitored()==1)
ok=LH_BuffReminders:AddBuff('unknown');assert(not ok)
local shown=TestRemindersVisible()
assert(#shown==1 and shown[1].spellID==13165 and shown[1].attributes.spell=='Aspect of the Hawk')
local oldBuff=UnitBuff
UnitBuff=function(_,index) if index==1 then return 'Aspect of the Hawk' end end
TestRemindersEvent('UNIT_AURA','player');assert(#TestRemindersVisible()==0)
UnitBuff=oldBuff;TestRemindersEvent('UNIT_AURA','player');assert(#TestRemindersVisible()==1)
LH_BuffReminders:SetEnabled(false);assert(#TestRemindersVisible()==0)
LH_BuffReminders:SetEnabled(true);assert(#TestRemindersVisible()==1)
TestRemindersSetClass('MAGE');assert(#LH_BuffReminders:GetMonitored()==0 and #TestRemindersVisible()==0)
TestRemindersSetClass('HUNTER');assert(#LH_BuffReminders:GetMonitored()==1 and #TestRemindersVisible()==1)
assert(LH_BuffRemindersClassDB.SHAMAN.monitored[1].kind=='weapon')
local hunterKnown,hunterTabs=IsPlayerSpell,GetNumSpellTabs
IsPlayerSpell=function(id) return id~=13165 and hunterKnown(id) end
GetNumSpellTabs=function() return 0 end
TestRemindersEvent('SPELLS_CHANGED')
assert(#LH_BuffReminders:GetMonitored()==1 and #TestRemindersVisible()==0)
IsPlayerSpell=hunterKnown;GetNumSpellTabs=hunterTabs
TestRemindersEvent('SPELLS_CHANGED');assert(#TestRemindersVisible()==1)
LH_BuffRemindersDB={x=15,y=-37,exceptions={fortitude=true}}
TestRemindersSetClass('PRIEST')
assert(LH_BuffRemindersClassDB.PRIEST.x==15 and LH_BuffRemindersClassDB.PRIEST.y==-37)
assert(LH_BuffRemindersClassDB.PRIEST.exceptions.fortitude)
LH_BuffRemindersDB={x=99,y=99}
TestRemindersSetClass('HUNTER')
assert(#LH_BuffReminders:GetMonitored()==1 and LH_BuffRemindersClassDB.HUNTER.x~=99)

methods=getmetatable(UIParent).__index
function methods:CreateFontString() return setmetatable({}, {__index=methods}) end
function methods:SetText(value) self.text=value end
function methods:GetText() return self.text end
function methods:SetTexture(value) self.texture=value end
function methods:GetParent() return self.parent end
function methods:SetHeight(value) self.height=value end
function methods:SetScrollChild(value) self.child=value end
function methods:SetMaxLetters(value) self.maxLetters=value end
function methods:ClearFocus() self.focus=false end
function methods:IsVisible() return self.shown end
function CreateFromMixins(base) return setmetatable({}, {__index=base}) end
settingsRows={};registry={};callbacks={};Settings={}
function Settings.RegisterVerticalLayoutSubcategory(parent,title)
 local c={parent=parent,title=title};function c:GetID() return title end
 local layout={rows={}};function layout:AddInitializer(row) table.insert(self.rows,row) end
 c.layout=layout;return c,layout
end
function Settings.RegisterAddOnCategory(c) registered=c end
function Settings.RegisterProxySetting(c,v,kind,label,default,get,set)
 local setting={default=default,get=get,set=set};registry[v]=setting;return setting
end
function Settings.CreateCheckbox(c,setting)
 local row={setting=setting};function row:SetParentInitializer(parent) self.parent=parent end
 c.layout:AddInitializer(row);return row
end
function Settings.CreatePanelInitializer(template,data)
 local row={template=template,data=data};panelInitializer=row;return row
end
function Settings.NotifyUpdate() end
function Settings.OpenToCategory(id) opened=id end
function CreateSettingsListSectionHeaderInitializer(name) return {header=name} end
function CreateSettingsButtonInitializer(label,text,callback)
 resetButton=callback;return {label=label,text=text}
end
EventRegistry={}
function EventRegistry:RegisterCallback(event,fn,owner) callbacks[event]={fn,owner} end
LH_Tweaks={modules={},category={}}
''')
source = (root / 'LH_Tweaks/LH_Tweaks.lua').read_text(encoding='utf-8')
registration = source.split('function Hub:RegisterModule(id, title, build)')[1].split('\nfunction Hub:RestoreDefaults')[0]
lua.execute('local Hub=LH_Tweaks\nfunction Hub:RegisterModule(id, title, build)' + registration)
source = (root / 'LH_Tweaks/Settings.lua').read_text(encoding='utf-8')
registration = source.split('function Hub:RegisterModulePage(id)')[1].split('\nlocal function RegisterSettings')[0]
lua.execute('local Hub=LH_Tweaks\nfunction Hub:RegisterModulePage(id)' + registration)
lua.execute((root / 'LH_BuffReminders/Settings.lua').read_text(encoding='utf-8'), 'LH_BuffReminders')
lua.execute('''
assert(registered.parent==LH_Tweaks.category and registered.title=='LH BuffReminders')
assert(panelInitializer.template=='LHBuffRemindersBuffListTemplate')
assert(registry.LH_BuffReminders_enabled.get() and not registry.LH_BuffReminders_unlocked.get())
registry.LH_BuffReminders_enabled.set(false);assert(#TestRemindersVisible()==0)
registry.LH_BuffReminders_enabled.set(true);assert(#TestRemindersVisible()==1)
SlashCmdList.LH_BUFFREMINDERS('');assert(opened=='LH BuffReminders')
local panel=CreateFrame('Frame')
setmetatable(panel,{__index=function(_,key) return LHBuffRemindersBuffListMixin[key] or methods[key] end})
panel:OnLoad();panel:Init(panelInitializer)
assert(panel.rows[1].name.text=='Aspect of the Hawk' and panel.rows[1].icon.texture=='HawkIcon')
panel.edit:SetText('Aspect of the Cheetah');panel.add.scripts.OnClick()
assert(#LH_BuffReminders:GetMonitored()==2 and panel.rows[2].icon.texture=='CheetahIcon')
panel.rows[1].remove.scripts.OnClick(panel.rows[1].remove)
assert(#LH_BuffReminders:GetMonitored()==1 and panel.rows[1].name.text=='Aspect of the Cheetah')
panel.edit:SetText('Aspect of the Hawk');panel.edit.scripts.OnEnterPressed()
assert(#LH_BuffReminders:GetMonitored()==2 and panel.rows[2].name.text=='Aspect of the Hawk')
assert(resetButton==nil and LH_BuffReminders.ResetClass==nil)
''')
for ext in ('png', 'tga'):
    assert (root / f'LH_BuffReminders/Media/Icon.{ext}').read_bytes() == (root / f'LH_Tweaks/Icon.{ext}').read_bytes()
from xml.etree import ElementTree

buff_template = ElementTree.parse(root / 'LH_BuffReminders/BuffList.xml').getroot()[0]
assert buff_template.attrib['name'] == 'LHBuffRemindersBuffListTemplate'
assert 'inherits' not in buff_template.attrib, 'A settings-row tooltip frame blocks the buff input'
print('PASS: class-wide buffs, Hunter aspects, aura matching, activation, native page, icon/name/x/+ controls and shared icon')
lua.execute('''
-- Per-buff watching outside and inside combat; combat changes use alpha only.
TestRemindersSetClass('HUNTER')
local entry=LH_BuffRemindersClassDB.HUNTER.monitored[1]
local cheetah=LH_BuffRemindersClassDB.HUNTER.monitored[2]
LH_BuffReminders:RemoveBuff(1)
assert(#LH_BuffReminders:GetMonitored()==1 and LH_BuffReminders:GetWatch(1,'ooc') and LH_BuffReminders:GetWatch(1,'combat'))
local oldBuff=UnitBuff
local hawk=true
UnitBuff=function(_,index) if hawk and index==1 then return 'Aspect of the Hawk' end end
TestRemindersEvent('UNIT_AURA','player');assert(#TestRemindersVisible()==0)
-- Buff lost in combat: the reminder appears; recast hides it again.
TestRemindersCombat(true);TestRemindersEvent('PLAYER_REGEN_DISABLED')
hawk=false;TestRemindersEvent('UNIT_AURA','player');assert(#TestRemindersVisible()==1)
hawk=true;TestRemindersEvent('UNIT_AURA','player');assert(#TestRemindersVisible()==0)
hawk=false;TestRemindersEvent('UNIT_AURA','player');assert(#TestRemindersVisible()==1)
-- Not watched in combat: hidden during combat, shown again afterwards.
LH_BuffReminders:SetWatch(1,'combat',false);assert(#TestRemindersVisible()==0)
TestRemindersCombat(false);TestRemindersEvent('PLAYER_REGEN_ENABLED');assert(#TestRemindersVisible()==1)
-- Not watched outside combat: hidden now, shown when combat starts without any layout change.
LH_BuffReminders:SetWatch(1,'combat',true);LH_BuffReminders:SetWatch(1,'ooc',false)
assert(#TestRemindersVisible()==0 and not LH_BuffReminders:GetWatch(1,'ooc'))
TestRemindersCombat(true);TestRemindersEvent('PLAYER_REGEN_DISABLED');assert(#TestRemindersVisible()==1)
TestRemindersCombat(false);TestRemindersEvent('PLAYER_REGEN_ENABLED');assert(#TestRemindersVisible()==0)
LH_BuffReminders:SetWatch(1,'ooc',true);assert(#TestRemindersVisible()==1)
-- Combat restrictions can hide aura data; the player's own cast then hides the reminder.
local secret={}
local oldSecret,oldTime=issecretvalue,GetTime
local now=100;GetTime=function() return now end
issecretvalue=function(v) return v==secret end
UnitBuff=function(_,index) if index==1 then return secret end end
TestRemindersCombat(true);TestRemindersEvent('PLAYER_REGEN_DISABLED')
TestRemindersEvent('UNIT_AURA','player');assert(#TestRemindersVisible()==1,'Unreadable auras must not hide the reminder')
TestRemindersEvent('UNIT_SPELLCAST_SUCCEEDED','player','guid',13165);assert(#TestRemindersVisible()==0)
now=110;TestRemindersEvent('UNIT_AURA','player');assert(#TestRemindersVisible()==0)
TestRemindersCombat(false);TestRemindersEvent('PLAYER_REGEN_ENABLED');assert(#TestRemindersVisible()==1)
-- A denied aura scan cannot disprove a successful cast.
UnitBuff=function() error('restricted aura scan') end
TestRemindersCombat(true);TestRemindersEvent('PLAYER_REGEN_DISABLED')
now=200;TestRemindersEvent('UNIT_SPELLCAST_SUCCEEDED','player','guid',13165);assert(#TestRemindersVisible()==0)
now=210;TestRemindersEvent('UNIT_AURA','player');assert(#TestRemindersVisible()==0,'Unrelated aura event re-showed the icon')
-- Once the aura has been seen, its disappearance means it was lost.
UnitBuff=function(_,index) if index==1 then return 'Aspect of the Hawk' end end
now=211;TestRemindersEvent('UNIT_AURA','player');assert(#TestRemindersVisible()==0)
UnitBuff=function() end
now=212;TestRemindersEvent('UNIT_AURA','player');assert(#TestRemindersVisible()==1)
TestRemindersCombat(false)
TestRemindersEvent('PLAYER_REGEN_ENABLED')
LH_BuffReminders:SetEnabled(false)
LH_BuffReminders:SetEnabled(true)
local pulseButton=TestRemindersVisible()[1]
assert(pulseButton.pulseStart==now and pulseButton.scripts.OnUpdate)
now=212.25;pulseButton.scripts.OnUpdate(pulseButton)
assert(pulseButton.icon.width>pulseButton.width,'New reminder icon did not grow')
now=215.5;pulseButton.scripts.OnUpdate(pulseButton)
assert(pulseButton.icon.width==pulseButton.width and not pulseButton.scripts.OnUpdate,
    'Reminder pulse did not stop and restore its size')
TestRemindersCombat(false);TestRemindersEvent('PLAYER_REGEN_ENABLED')
-- Buff present before combat but unreadable in combat.
UnitBuff=function(_,index) if index==1 then return 'Aspect of the Hawk' end end
TestRemindersEvent('UNIT_AURA','player');assert(#TestRemindersVisible()==0)
UnitBuff=function() error('restricted aura scan') end
TestRemindersCombat(true);TestRemindersEvent('PLAYER_REGEN_DISABLED')
now=300;TestRemindersEvent('UNIT_AURA','player');assert(#TestRemindersVisible()==0,'Pre-combat buff re-shown in combat')
TestRemindersCombat(false);TestRemindersEvent('PLAYER_REGEN_ENABLED')
assert(#TestRemindersVisible()==1)
-- Removal (expiry or right-click) is noticed in combat through the UNIT_AURA details.
local oldAuras=C_UnitAuras
local list={{name='Aspect of the Hawk',auraInstanceID=77,expirationTime=0}}
C_UnitAuras={GetUnitAuras=function() return list end}
UnitBuff=function() end
now=400;TestRemindersEvent('UNIT_AURA','player');assert(#TestRemindersVisible()==0)
list={}
TestRemindersCombat(true);TestRemindersEvent('PLAYER_REGEN_DISABLED')
C_UnitAuras.GetUnitAuras=function() error('restricted aura scan') end
TestRemindersEvent('UNIT_AURA','player',{removedAuraInstanceIDs={5}});assert(#TestRemindersVisible()==0)
C_UnitAuras.GetUnitAuras=function() return list end
TestRemindersEvent('UNIT_AURA','player',{removedAuraInstanceIDs={77}});assert(#TestRemindersVisible()==1,'Removed aura not noticed in combat')
-- Recast: the aura appears again and is tracked; its known expiry time then hides/shows it.
now=410;TestRemindersEvent('UNIT_SPELLCAST_SUCCEEDED','player','guid',13165);assert(#TestRemindersVisible()==0)
TestRemindersEvent('UNIT_AURA','player',{addedAuras={{name='Aspect of the Hawk',auraInstanceID=88,expirationTime=500}}})
C_UnitAuras.GetUnitAuras=function() error('restricted aura scan') end
now=450;TestRemindersEvent('UNIT_AURA','player');assert(#TestRemindersVisible()==0)
now=500.2;TestRemindersEvent('UNIT_AURA','player');assert(#TestRemindersVisible()==0,'Expiry grace')
now=501;TestRemindersEvent('UNIT_AURA','player');assert(#TestRemindersVisible()==1,'Expired aura not noticed in combat')
TestRemindersCombat(false);TestRemindersEvent('PLAYER_REGEN_ENABLED')
-- Presence probes work without a usable aura list or event payload.
local present=true
list={{name='Aspect of the Hawk',auraInstanceID=91,expirationTime=0}}
C_UnitAuras={GetUnitAuras=function() return list end,
 GetAuraDataByAuraInstanceID=function(_,id) assert(id==91);if present then return {} end end}
TestRemindersEvent('UNIT_AURA','player');assert(#TestRemindersVisible()==0)
list={}
TestRemindersCombat(true);TestRemindersEvent('PLAYER_REGEN_DISABLED')
TestRemindersEvent('UNIT_AURA','player');assert(#TestRemindersVisible()==0)
present=false;TestRemindersEvent('UNIT_AURA','player');assert(#TestRemindersVisible()==1,'Vanished aura instance not noticed')
-- Spell-ID probe finds a recast buff and records its instance.
C_UnitAuras.GetPlayerAuraBySpellID=function(id) if id==13165 then return {auraInstanceID=92} end end
C_UnitAuras.GetAuraDataByAuraInstanceID=function(_,id) if id==92 then return {} end end
now=600;TestRemindersEvent('UNIT_AURA','player');assert(#TestRemindersVisible()==0)
-- Once the spell probe has found the buff in combat, its absence means the buff is gone.
C_UnitAuras.GetPlayerAuraBySpellID=function() return nil end
C_UnitAuras.GetAuraDataByAuraInstanceID=nil
now=610;TestRemindersEvent('UNIT_AURA','player');assert(#TestRemindersVisible()==1,'Missing proven spell probe not noticed')
TestRemindersCombat(false);TestRemindersEvent('PLAYER_REGEN_ENABLED')
C_UnitAuras=oldAuras
-- Unreadable aura added right after the cast (either event order) is claimed by the cast.
local present2=true
C_UnitAuras={GetUnitAuras=function() error('restricted') end,
 GetAuraDataByAuraInstanceID=function(_,id) if present2 and id==93 then return {} end end,
 GetPlayerAuraBySpellID=function() return nil end}
issecretvalue=function(v) return v==secret end
TestRemindersCombat(true);TestRemindersEvent('PLAYER_REGEN_DISABLED')
now=700;TestRemindersEvent('UNIT_SPELLCAST_SUCCEEDED','player','guid',13165)
TestRemindersEvent('UNIT_AURA','player',{addedAuras={{name=secret,spellId=secret,auraInstanceID=93}}})
now=720;TestRemindersEvent('UNIT_AURA','player');assert(#TestRemindersVisible()==0,'Claimed aura should hide the icon')
present2=false;TestRemindersEvent('UNIT_AURA','player');assert(#TestRemindersVisible()==1,'Claimed aura removal not noticed')
-- Aura event before the cast event.
present2=true
C_UnitAuras.GetAuraDataByAuraInstanceID=function(_,id) if present2 and id==94 then return {} end end
now=800;TestRemindersEvent('UNIT_AURA','player',{addedAuras={{name=secret,spellId=secret,auraInstanceID=94}}})
TestRemindersEvent('UNIT_SPELLCAST_SUCCEEDED','player','guid',13165)
now=820;TestRemindersEvent('UNIT_AURA','player');assert(#TestRemindersVisible()==0)
present2=false;TestRemindersEvent('UNIT_AURA','player');assert(#TestRemindersVisible()==1,'Pending aura attribution failed')
TestRemindersCombat(false);TestRemindersEvent('PLAYER_REGEN_ENABLED')
C_UnitAuras=oldAuras
issecretvalue,GetTime=oldSecret,oldTime
UnitBuff=oldBuff
''')
print('PASS: per-buff out-of-combat/in-combat watching and in-combat icon removal and reappearance')
lua.execute('''
-- Diagnostic commands must not raise errors.
SlashCmdList.LH_BUFFREMINDERS('debug');SlashCmdList.LH_BUFFREMINDERS('probe')
''')

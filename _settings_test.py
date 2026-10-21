from pathlib import Path
import sys

root = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(root / 'LH_Tweaks/.test-runtime'))
from lupa.lua51 import LuaRuntime

lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute((root / 'LH_Reminders/_test.lua').read_text(encoding='utf-8'))
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
assert(#LH_Reminders:GetMonitored()==0 and LH_RemindersClassDB.HUNTER.enabled)
local ok,message=LH_Reminders:AddBuff('Aspect of the Hawk')
assert(ok and #LH_Reminders:GetMonitored()==1,message)
assert(LH_Reminders:GetEntry(1)=='Aspect of the Hawk')
ok=LH_Reminders:AddBuff('13165');assert(not ok and #LH_Reminders:GetMonitored()==1)
ok=LH_Reminders:AddBuff('unknown');assert(not ok)
local shown=TestRemindersVisible()
assert(#shown==1 and shown[1].spellID==13165 and shown[1].attributes.spell=='Aspect of the Hawk')
local oldBuff=UnitBuff
UnitBuff=function(_,index) if index==1 then return 'Aspect of the Hawk' end end
TestRemindersEvent('UNIT_AURA','player');assert(#TestRemindersVisible()==0)
UnitBuff=oldBuff;TestRemindersEvent('UNIT_AURA','player');assert(#TestRemindersVisible()==1)
LH_Reminders:SetEnabled(false);assert(#TestRemindersVisible()==0)
LH_Reminders:SetEnabled(true);assert(#TestRemindersVisible()==1)
TestRemindersSetClass('MAGE');assert(#LH_Reminders:GetMonitored()==0 and #TestRemindersVisible()==0)
TestRemindersSetClass('HUNTER');assert(#LH_Reminders:GetMonitored()==1 and #TestRemindersVisible()==1)
assert(LH_RemindersClassDB.SHAMAN.monitored[1].kind=='weapon')
local hunterKnown,hunterTabs=IsPlayerSpell,GetNumSpellTabs
IsPlayerSpell=function(id) return id~=13165 and hunterKnown(id) end
GetNumSpellTabs=function() return 0 end
TestRemindersEvent('SPELLS_CHANGED')
assert(#LH_Reminders:GetMonitored()==1 and #TestRemindersVisible()==0)
IsPlayerSpell=hunterKnown;GetNumSpellTabs=hunterTabs
TestRemindersEvent('SPELLS_CHANGED');assert(#TestRemindersVisible()==1)
LH_RemindersDB={x=15,y=-37,exceptions={fortitude=true}}
TestRemindersSetClass('PRIEST')
assert(LH_RemindersClassDB.PRIEST.x==15 and LH_RemindersClassDB.PRIEST.y==-37)
assert(LH_RemindersClassDB.PRIEST.exceptions.fortitude)
LH_RemindersDB={x=99,y=99}
TestRemindersSetClass('HUNTER')
assert(#LH_Reminders:GetMonitored()==1 and LH_RemindersClassDB.HUNTER.x~=99)

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
SettingsListElementMixin={OnLoad=function() end,Init=function() end}
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
lua.execute((root / 'LH_Reminders/Settings.lua').read_text(encoding='utf-8'), 'LH_Reminders')
lua.execute('''
assert(registered.parent==LH_Tweaks.category and registered.title=='LH Reminders')
assert(panelInitializer.template=='LHRemindersBuffListTemplate')
assert(registry.LH_Reminders_enabled.get() and not registry.LH_Reminders_unlocked.get())
registry.LH_Reminders_enabled.set(false);assert(#TestRemindersVisible()==0)
registry.LH_Reminders_enabled.set(true);assert(#TestRemindersVisible()==1)
SlashCmdList.LH_REMINDERS('');assert(opened=='LH Reminders')
local panel=CreateFrame('Frame')
setmetatable(panel,{__index=function(_,key) return LHRemindersBuffListMixin[key] or methods[key] end})
panel:OnLoad();panel:Init(panelInitializer)
assert(panel.rows[1].name.text=='Aspect of the Hawk' and panel.rows[1].icon.texture=='HawkIcon')
panel.edit:SetText('Aspect of the Cheetah');panel.add.scripts.OnClick()
assert(#LH_Reminders:GetMonitored()==2 and panel.rows[2].icon.texture=='CheetahIcon')
panel.rows[1].remove.scripts.OnClick(panel.rows[1].remove)
assert(#LH_Reminders:GetMonitored()==1 and panel.rows[1].name.text=='Aspect of the Cheetah')
assert(resetButton==nil and LH_Reminders.ResetClass==nil)
''')
for ext in ('png', 'tga'):
    assert (root / f'LH_Reminders/Media/Icon.{ext}').read_bytes() == (root / f'LH_Tweaks/Icon.{ext}').read_bytes()
assert 'LHRemindersBuffListTemplate' in (root / 'LH_Reminders/BuffList.xml').read_text()
print('PASS: class-wide buffs, Hunter aspects, aura matching, activation, native page, icon/name/x/+ controls and shared icon')

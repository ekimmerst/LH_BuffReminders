local frames = {}
local legacyTooltipText
local methods = {}
setmetatable(methods, { __index = function() return function() end end })
function methods:SetScript(k,v) self.scripts[k]=v end
function methods:SetSize(w,h) self.width,self.height=w,h end
function methods:SetPoint(...)
 assert(not (self.kind=='Button' and InCombatLockdown()), 'Secure button moved in combat')
 self.point={...}; self.pointChanges=(rawget(self,'pointChanges') or 0)+1
end
function methods:SetAlpha(a) self.alpha=a end
function methods:GetAlpha() return rawget(self,'alpha') or 1 end
function methods:GetCenter() return 500,300 end
function methods:Show()
 assert(not (self.kind=='Button' and InCombatLockdown()), 'Secure button shown in combat')
 self.shown=true
end
function methods:Hide()
 assert(not (self.kind=='Button' and InCombatLockdown()), 'Secure button hidden in combat')
 self.shown=false; self.hideCalls=(rawget(self,'hideCalls') or 0)+1 end
function methods:StartMoving() self.moving=true end
function methods:StopMovingOrSizing() self.moving=false end
function methods:SetAttribute(key,value)
 assert(not InCombatLockdown(), 'Secure attribute changed in combat')
 self.attributes[key]=value
end
function methods:NumLines() return legacyTooltipText and 1 or 0 end
function methods:CreateTexture() return setmetatable({}, {__index=methods}) end
function CreateFrame(kind,name,parent,template)
 local f=setmetatable({kind=kind,parent=parent,template=template,attributes={},scripts={}}, {__index=methods})
 frames[#frames+1]=f; if name then _G[name]=f end; return f
end
UIParent=CreateFrame('Frame')
SlashCmdList={}
local class, enchanted, shield, dead, weapon='SHAMAN',false,false,false,true
local combat=false
function InCombatLockdown() return combat end
function GetTime() return 0 end
function UnitClass() return 'Shaman',class end
function GetSpellInfo(id)
 if id==8017 then return 'Rockbiter Weapon',nil,'Icon'..id end
 if id==8018 then return 'Rockbiter Weapon 2',nil,'Icon'..id end
 if id==324 then return 'Lightning Shield',nil,'Icon'..id end
 return 'Spell'..id,nil,'Icon'..id
end
function IsPlayerSpell(id) return id==8017 or id==324 end
function GetWeaponEnchantInfo() return enchanted,nil,nil,nil,false end
function GetInventoryItemLink() if weapon then return 'weapon' end end
function UnitIsDeadOrGhost() return dead end
function UnitBuff(_,i) if shield and i==1 then return 'Lightning Shield' end end
assert(loadfile('LH_BuffReminders/LH_BuffReminders.lua'))('LH_BuffReminders')
local f=LH_BuffRemindersFrame
local function event(e,u) f.scripts.OnEvent(f,e,u) end
local function visible()
 local result={}
 for _,b in ipairs(frames) do if b.template=='SecureActionButtonTemplate' and b.shown and b:GetAlpha()~=0 then result[#result+1]=b end end
 return result
end
-- The weapon enchant already exists at login but neither aura nor enchant API reports it.
local tooltipLines={{leftText='Rockbiter 2'}}
C_TooltipInfo={GetInventoryItem=function() return {lines=tooltipLines} end}
event('ADDON_LOADED','LH_BuffReminders')
assert(#visible()==1 and visible()[1].spellID==324, 'Existing login weapon buff missed')
tooltipLines={}; f.scripts.OnUpdate(f,0.5)
local b=visible(); assert(#b==2)
assert(b[1].template=='SecureActionButtonTemplate')
assert(b[1].attributes.type=='spell' and b[1].attributes.spell=='Rockbiter Weapon')
assert(b[1].attributes.unit=='player')
local known=IsPlayerSpell
IsPlayerSpell=function(id) return id==8018 or id==324 end
event('SPELLS_CHANGED')
assert(visible()[1].attributes.spell=='Rockbiter Weapon 2', 'Click must use learned rank 2')
IsPlayerSpell=known; event('SPELLS_CHANGED')
local modernTooltip=C_TooltipInfo
C_TooltipInfo=nil
legacyTooltipText='Rockbiter 2'
LH_BuffRemindersWeaponTooltipTextLeft1={GetText=function() return legacyTooltipText end}
event('PLAYER_ENTERING_WORLD'); assert(#visible()==1, 'Legacy weapon tooltip missed')
legacyTooltipText=nil; C_TooltipInfo=modernTooltip
f.scripts.OnUpdate(f,0.5); b=visible(); assert(#b==2)
tooltipLines={{leftText='|cff00ff00Rockbiter 2 (4 min)|r'}}
event('PLAYER_ENTERING_WORLD'); assert(#visible()==1)
tooltipLines={{leftText='Weapon Damage +2'}}
event('UNIT_INVENTORY_CHANGED','player'); assert(#visible()==2)
tooltipLines={{leftText='Rockbiter 2'}}
-- A buff gained during combat hides its reminder at once (alpha only, no secure changes).
combat=true; event('PLAYER_REGEN_DISABLED'); event('UNIT_AURA','player'); f.scripts.OnUpdate(f,0.5)
assert(#visible()==1, 'Buff gained in combat must hide the reminder')
combat=false; event('PLAYER_REGEN_ENABLED'); assert(#visible()==1)
tooltipLines={}; f.scripts.OnUpdate(f,0.5); b=visible()
assert(b[1].width==36 and b[1].height==36)
assert(b[1].point[4]==-22 and b[2].point[4]==22)
enchanted=true; event('UNIT_AURA','player'); assert(#visible()==1)
-- Forever weapon imbues may be player auras while item enchant flags are false.
enchanted=false
local legacyBuff=UnitBuff
UnitBuff=function(_,i) if i==1 then return 'Rockbiter 2' end end
event('UNIT_AURA','player'); assert(#visible()==1 and visible()[1].spellID==324)
UnitBuff=legacyBuff
C_UnitAuras={GetUnitAuras=function() return {{name='Rockbiter 2'}} end}
event('UNIT_AURA','player'); assert(#visible()==1 and visible()[1].spellID==324)
for _,name in ipairs({'Rockbiter 1','Rockbiter 7','Rockbiter Weapon 2','Rockbiter (Rank 2)','Rockbiter Rank 7','Rockbiter 20'}) do
 C_UnitAuras.GetUnitAuras=function() return {{name=name}} end
 event('UNIT_AURA','player'); assert(#visible()==1, 'Unrecognized rank: '..name)
end
C_UnitAuras.GetUnitAuras=function() return {{name='Unrelated buff 2'}} end
event('UNIT_AURA','player'); assert(#visible()==2, 'Unrelated aura matched weapon family')
C_UnitAuras.GetUnitAuras=function() return {{name='Different aura name',spellId=8018}} end
event('UNIT_AURA','player'); assert(#visible()==1, 'Rockbiter rank 2 ID not recognized')
C_UnitAuras.GetUnitAuras=function() return {} end
C_UnitAuras.GetAuraDataByIndex=function(_,i) if i==1 then return {spellId=8017} end end
event('UNIT_AURA','player'); assert(#visible()==1 and visible()[1].spellID==324)
-- Empty modern API results must not mask a valid legacy aura.
C_UnitAuras.GetAuraDataByIndex=function() return nil end
UnitBuff=function(_,i) if i==1 then return 'Rockbiter 2' end end
event('UNIT_AURA','player'); assert(#visible()==1 and visible()[1].spellID==324)
UnitBuff=legacyBuff; C_UnitAuras=nil
event('UNIT_AURA','player'); assert(#visible()==2, 'Expired weapon aura must restore reminder')
enchanted=true
shield=true; event('UNIT_AURA','player'); assert(#visible()==0)
SlashCmdList.LH_BUFFREMINDERS('unlock'); b=visible(); assert(#b==1 and b[1].example)
assert(b[1].attributes.type==nil and b[1].attributes.spell==nil, 'Example must not cast')
local example=b[1]
local hides, points=rawget(example,'hideCalls') or 0, example.pointChanges
for attempt=1,3 do
 example.scripts.OnDragStart(); assert(f.moving)
 for tick=1,20 do
  f.scripts.OnUpdate(f,0.5)
  event('UNIT_AURA','player')
  event('SPELLS_CHANGED')
 end
 assert(example.shown and f.moving)
 assert((rawget(example,'hideCalls') or 0)==hides, 'Refresh hid the dragged example')
 assert(example.pointChanges==points, 'Refresh reanchored the dragged example')
 example.scripts.OnDragStop(); assert(not f.moving)
end
assert(LH_BuffRemindersClassDB.SHAMAN.x==0)
SlashCmdList.LH_BUFFREMINDERS('lock'); assert(#visible()==0)
enchanted=false; shield=false; dead=true; event('PLAYER_DEAD'); assert(#visible()==0)
dead=false; weapon=false; event('PLAYER_ALIVE'); assert(#visible()==1)
class='MAGE'; event('SPELLS_CHANGED'); assert(#visible()==0)
SlashCmdList.LH_BUFFREMINDERS('unlock'); assert(#visible()==1)
SlashCmdList.LH_BUFFREMINDERS('lock'); assert(#visible()==0)
class='SHAMAN'; weapon=true; enchanted=false; shield=false; tooltipLines={}
event('SPELLS_CHANGED'); assert(#visible()==2)
SlashCmdList.LH_BUFFREMINDERS('except "Lightning Shield"')
assert(#visible()==1 and visible()[1].spellID==8017)
assert(LH_BuffRemindersClassDB.SHAMAN.exceptions['lightning shield'])
event('ADDON_LOADED','LH_BuffReminders'); event('PLAYER_ENTERING_WORLD')
assert(#visible()==1, 'Exception did not survive initialization')
SlashCmdList.LH_BUFFREMINDERS('  ALLOW "LIGHTNING SHIELD 2"  '); assert(#visible()==2)
SlashCmdList.LH_BUFFREMINDERS('except "Blitzschlagschild"'); assert(#visible()==1)
SlashCmdList.LH_BUFFREMINDERS('allow Lightning Shield'); assert(#visible()==2)
for _,cmd in ipairs({'except', 'except ""', 'except "Lightning Shield', 'except "Lightning Shield" extra', 'allow "'}) do
 SlashCmdList.LH_BUFFREMINDERS(cmd)
 assert(#visible()==2 and next(LH_BuffRemindersClassDB.SHAMAN.exceptions)==nil, 'Invalid input changed exceptions')
end
combat=true
SlashCmdList.LH_BUFFREMINDERS('except "Lightning Shield"'); assert(#visible()==1, 'Exception must apply in combat')
combat=false; event('PLAYER_REGEN_ENABLED'); assert(#visible()==1)
SlashCmdList.LH_BUFFREMINDERS('unlock'); assert(#visible()==1 and visible()[1].example)
SlashCmdList.LH_BUFFREMINDERS('except "Rockbiter 2"'); assert(#visible()==1 and visible()[1].example)
SlashCmdList.LH_BUFFREMINDERS('lock'); assert(#visible()==0)
SlashCmdList.LH_BUFFREMINDERS('allow "Rockbiter Weapon"'); assert(#visible()==1)
SlashCmdList.LH_BUFFREMINDERS('allow "Lightning Shield"'); assert(#visible()==2)
function TestRemindersSetClass(token) class=token; event('SPELLS_CHANGED') end
TestRemindersVisible=visible
function TestRemindersCombat(value) combat=value end
function TestRemindersEvent(name,unit,...) f.scripts.OnEvent(f,name,unit,...) end
print('PASS: persistent per-buff exceptions, allow, ranks, quotes, invalid input, combat deferral and unlock preview')
print('PASS: pre-existing login enchant, modern/legacy weapon tooltips, rank 2 casting attributes, aura ranks, expiry, combat deferral, stable dragging, layout and class filtering')

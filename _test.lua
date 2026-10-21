local frames = {}
local legacyTooltipText
local methods = {}
setmetatable(methods, { __index = function() return function() end end })
function methods:SetScript(k,v) self.scripts[k]=v end
function methods:SetSize(w,h) self.width,self.height=w,h end
function methods:SetPoint(...) self.point={...}; self.pointChanges=(rawget(self,'pointChanges') or 0)+1 end
function methods:GetCenter() return 500,300 end
function methods:Show() self.shown=true end
function methods:Hide() self.shown=false; self.hideCalls=(rawget(self,'hideCalls') or 0)+1 end
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
function UnitClass() return 'Shaman',class end
function GetSpellInfo(id)
 if id==8017 then return 'Rockbiter Weapon',nil,'Icon'..id end
 if id==8018 then return 'Rockbiter Weapon 2',nil,'Icon'..id end
 return 'Spell'..id,nil,'Icon'..id
end
function IsPlayerSpell(id) return id==8017 or id==324 end
function GetWeaponEnchantInfo() return enchanted,nil,nil,nil,false end
function GetInventoryItemLink() if weapon then return 'weapon' end end
function UnitIsDeadOrGhost() return dead end
function UnitBuff(_,i) if shield and i==1 then return 'Spell324' end end
assert(loadfile('MiniReminders/MiniReminders.lua'))('MiniReminders')
local f=MiniRemindersFrame
local function event(e,u) f.scripts.OnEvent(f,e,u) end
local function visible()
 local result={}
 for _,b in ipairs(frames) do if b.kind=='Button' and b.shown then result[#result+1]=b end end
 return result
end
-- The weapon enchant already exists at login but neither aura nor enchant API reports it.
local tooltipLines={{leftText='Rockbiter 2'}}
C_TooltipInfo={GetInventoryItem=function() return {lines=tooltipLines} end}
event('ADDON_LOADED','MiniReminders')
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
MiniRemindersWeaponTooltipTextLeft1={GetText=function() return legacyTooltipText end}
event('PLAYER_ENTERING_WORLD'); assert(#visible()==1, 'Legacy weapon tooltip missed')
legacyTooltipText=nil; C_TooltipInfo=modernTooltip
f.scripts.OnUpdate(f,0.5); b=visible(); assert(#b==2)
tooltipLines={{leftText='|cff00ff00Rockbiter 2 (4 min)|r'}}
event('PLAYER_ENTERING_WORLD'); assert(#visible()==1)
tooltipLines={{leftText='Weapon Damage +2'}}
event('UNIT_INVENTORY_CHANGED','player'); assert(#visible()==2)
tooltipLines={{leftText='Rockbiter 2'}}
combat=true; event('UNIT_AURA','player'); f.scripts.OnUpdate(f,0.5)
assert(#visible()==2, 'Secure buttons changed in combat')
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
SlashCmdList.MINIREMINDERS('unlock'); b=visible(); assert(#b==1 and b[1].example)
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
assert(MiniRemindersDB.x==0)
SlashCmdList.MINIREMINDERS('lock'); assert(#visible()==0)
enchanted=false; shield=false; dead=true; event('PLAYER_DEAD'); assert(#visible()==0)
dead=false; weapon=false; event('PLAYER_ALIVE'); assert(#visible()==1)
class='MAGE'; event('SPELLS_CHANGED'); assert(#visible()==0)
SlashCmdList.MINIREMINDERS('unlock'); assert(#visible()==1)
SlashCmdList.MINIREMINDERS('lock'); assert(#visible()==0)
print('PASS: pre-existing login enchant, modern/legacy weapon tooltips, rank 2 casting attributes, aura ranks, expiry, combat deferral, stable dragging, layout and class filtering')

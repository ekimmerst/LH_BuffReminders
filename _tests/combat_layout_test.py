"""Small Lua regression checks for secret auras and reminder positions."""

from pathlib import Path

from lupa import LuaRuntime


source = (Path(__file__).resolve().parents[1] / "LH_BuffReminders.lua").read_text(encoding="utf-8")


def section(start, end):
    return source[source.index(start) : source.index(end)]


lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute("""buttons = {}; SIZE = 36; GAP = 8; anchor = {}; unlocked = false
function InCombat() return true end
function GetButton(i)
    if buttons[i] then return buttons[i] end
    local b = {alpha = 0, icon = {SetTexture = function() end}}
    function b:SetAlpha(v) self.alpha = v end
    function b:ClearAllPoints() end
    function b:SetPoint(_, _, _, x) self.offset = x end
    function b:SetMouseClickEnabled(v) self.click = v end
    function b:Show() self.shown = true end
    function b:Hide() self.shown = false end
    buttons[i] = b
    return b
end
function SetReminderShown(b, shown) b:SetAlpha(shown and 1 or 0) end""")
layout = lua.execute(section("local function LayoutReminders(missing)", "local function CombatRefresh()")
                     + "\nreturn LayoutReminders")
layout(lua.eval("{{name='Read Leyline',id=1},{name='Enrage',id=2}}"))
assert (lua.eval("buttons[1].offset"), lua.eval("buttons[2].offset")) == (-22, 22)
layout(lua.eval("{{name='Enrage',id=2}}"))
assert lua.eval("buttons[1].offset") == 0 and not lua.eval("buttons[2].shown")
layout(lua.eval("{{id=1},{id=2},{id=3}}"))
assert tuple(lua.eval(f"buttons[{i}].offset") for i in (1, 2, 3)) == (-44, 0, 44)

lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute("""config = {enabled = true, exceptions = {}}; unlocked = false
buttons = {}
groups = {{name = 'Mark of the Wild', id = 1},
          {name = 'Read Leyline', id = 2, precombatMissing = true},
          {name = 'Enrage', id = 3, precombatMissing = true}}
function UnitIsDeadOrGhost() return false end
function Watched() return true end
function BuffName(s) return s end
function AuraRestricted() return true end
function IsActive(g) return g.active end
function AuraPresent() return nil end
function SpellUsable() return true end
function CooldownActive() return false end
function GetTime() return 100 end
function LayoutReminders(missing) shown = missing end""")
combat = lua.execute(section("local function CombatRefresh()", "Refresh = function()")
                     + "\nreturn CombatRefresh")
combat()
assert lua.eval("#shown") == 2
assert tuple(lua.eval(f"shown[{i}].name") for i in (1, 2)) == ("Read Leyline", "Enrage")

lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute("""initialized = true; calls = 0
function InCombat() return false end
function Fighting() return true end
function CombatRefresh() calls = calls + 1 end""")
lua.execute(section("Refresh = function()", "-- Diagnostic reports open"))
lua.eval("Refresh()")
assert lua.eval("calls") == 1, "The combat event must select CombatRefresh before lockdown starts"

lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute("""C_Secrets = {ShouldAurasBeSecret = function() return true end}
C_UnitAuras = {GetUnitAuras = function() return {} end}
function Public() return true end
function InCombat() return true end""")
aura_code = section("local function AuraRestricted(group)",
                    "-- true/false, or nil when combat restrictions hide the aura data.")
aura_code += section("local function HasBuff(group)", "local function WeaponTooltipHasBuff(group, slot)")
has_buff = lua.execute(aura_code + "\nreturn HasBuff")
assert has_buff(lua.eval("{id=1, names={}, ids={}}")) is None

lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute("""config = {enabled=true, exceptions={}}; unlocked=false
local leyline = {name='Read Leyline', id=1259705, precombatMissing=true}
groups = {leyline}; buttons = {}; usable = true
function UnitIsDeadOrGhost() return false end
function Watched() return true end
function BuffName(s) return s end
function AuraRestricted() return true end
function IsActive() return nil end
function AuraPresent() return nil end
function GetTime() return 100 end
function SpellUsable() return usable end
function CooldownActive() return false end
function LayoutReminders(missing)
    shown = missing; buttons = {}
    for _, group in ipairs(missing) do
        local button = {group=group}
        function button:IsShown() return true end
        function button:GetAlpha() return 1 end
        buttons[#buttons+1] = button
    end
end""")
combat = lua.execute(section("local function CombatRefresh()", "Refresh = function()")
                     + "\nreturn CombatRefresh")
combat()
assert lua.eval("#shown") == 1
lua.execute("usable = false")
combat()
assert lua.eval("#shown") == 1, "Bear Form hid an already visible Read Leyline reminder"
lua.execute("groups[1].precombatMissing = nil")
combat()
assert lua.eval("#shown") == 0, "Unknown aura state created a reminder"

print("Combat aura and centering scenarios OK")

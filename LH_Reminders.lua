local addonName = ...
local SIZE, GAP = 36, 8
local unlocked, initialized = false, false
local buttons, groups = {}, {}
local weaponTooltip
local function InCombat()
    return InCombatLockdown and InCombatLockdown()
end
local anchor = CreateFrame("Frame", "LH_RemindersFrame", UIParent)
anchor:SetSize(SIZE, SIZE)
anchor:SetMovable(true)
anchor:SetClampedToScreen(true)

local function SpellInfo(id)
    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(id)
        if info then return info.name, info.iconID end
    elseif GetSpellInfo then
        local name, _, icon = GetSpellInfo(id)
        return name, icon
    end
end

local function Known(id)
    if IsPlayerSpell and IsPlayerSpell(id) then return true end
    if IsSpellKnown and IsSpellKnown(id) then return true end
    return false
end

local function BuffName(name)
    if type(name) ~= "string" then return nil end
    name = name:lower():match("^%s*(.-)%s*$")
    -- Forever can include the rank in the aura name (e.g. "Rockbiter 2").
    name = name:gsub("%s*%(%s*rank%s+%d+%s*%)$", "")
        :gsub("%s*%(%s*rang%s+%d+%s*%)$", "")
        :gsub("%s*%(%s*%d+%s*%)$", "")
        :gsub("%s+rank%s+%d+$", ""):gsub("%s+rang%s+%d+$", "")
        :gsub("%s+%d+$", "")
    -- The cast and the resulting aura can use different family names.
    local aliases = {
        ["rockbiter weapon"] = "rockbiter", ["waffe des felsbeißers"] = "felsbeißer",
        ["waffe des felsbeissers"] = "felsbeißer", ["felsbeisser"] = "felsbeißer",
        ["flametongue weapon"] = "flametongue", ["frostbrand weapon"] = "frostbrand",
        ["windfury weapon"] = "windfury", ["earthliving weapon"] = "earthliving",
        ["blitzschlagschild"] = "lightning shield", ["wasserschild"] = "water shield",
        ["erdschild"] = "earth shield",
    }
    return aliases[name] or name
end

local definitions = {
    { kind = "weapon", ids = {
        8017, 8018, 8019, 10399, 16314, 16315, 16316,
        8024, 8027, 8030, 16339, 16341, 16342,
        8033, 8038, 10456, 16355, 16356,
        8232, 8235, 10486, 16362, 51730,
    } },
    { kind = "shield", ids = { 324, 52127, 974 } },
}

local function BuildGroups()
    groups = {}
    local _, class = UnitClass("player")
    if class ~= "SHAMAN" then return end
    for _, definition in ipairs(definitions) do
        local group = { kind = definition.kind, names = {}, ids = {} }
        for _, id in ipairs(definition.ids) do
            group.ids[id] = true
            local name, icon = SpellInfo(id)
            if name then
                group.names[BuffName(name)] = true
                if Known(id) and (not group.id or BuffName(group.name) == BuffName(name)) then
                    group.id, group.name, group.icon = id, name, icon
                end
            end
        end
        -- Spellbook discovery also handles characters who only know a higher rank.
        local function Visit(id)
            if not id then return end
            local name, icon = SpellInfo(id)
            if name and group.names[BuffName(name)] then
                group.ids[id] = true
                if not group.id or BuffName(group.name) == BuffName(name) then
                    group.id, group.name, group.icon = id, name, icon
                end
            end
        end
        if C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines then
            local bank = Enum.SpellBookSpellBank.Player
            for tab = 1, C_SpellBook.GetNumSpellBookSkillLines() do
                local info = C_SpellBook.GetSpellBookSkillLineInfo(tab)
                if info then
                    for i = info.itemIndexOffset + 1, info.itemIndexOffset + info.numSpellBookItems do
                        local spell = C_SpellBook.GetSpellBookItemInfo(i, bank)
                        if spell and not spell.isOffSpec and not spell.isPassive then Visit(spell.spellID) end
                    end
                end
            end
        elseif GetNumSpellTabs and GetSpellBookItemInfo then
            for tab = 1, GetNumSpellTabs() do
                local _, _, offset, count = GetSpellTabInfo(tab)
                for i = offset + 1, offset + count do
                    local kind, id = GetSpellBookItemInfo(i, BOOKTYPE_SPELL or "spell")
                    if kind == "SPELL" then Visit(id) end
                end
            end
        end
        if group.id then groups[#groups + 1] = group end
    end
end

local function HasBuff(group)
    local function Matches(aura)
        if not aura then return false end
        local id = aura.spellId or aura.spellID
        if id and group.ids[id] then return true end
        if aura.name and group.names[BuffName(aura.name)] then return true end
        local name = id and SpellInfo(id)
        return name and group.names[BuffName(name)] or false
    end
    -- Forever can expose weapon buffs as player auras instead of temporary
    -- item enchants. Prefer its batch API, but retain indexed/legacy fallbacks.
    if C_UnitAuras and C_UnitAuras.GetUnitAuras then
        local ok, auras = pcall(C_UnitAuras.GetUnitAuras, "player", "HELPFUL")
        if ok and type(auras) == "table" then
            for _, aura in ipairs(auras) do
                if Matches(aura) then return true end
            end
        end
    end
    for i = 1, 255 do
        local name
        if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
            local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, "player", i, "HELPFUL")
            if ok and aura then
                if Matches(aura) then return true end
                name = aura.name
            end
        end
        if not name and (UnitBuff or UnitAura) then
            local ok, legacyName = pcall(UnitBuff or UnitAura, "player", i, "HELPFUL")
            if ok then name = legacyName end
        end
        if not name then break end
        if group.names[BuffName(name)] then return true end
    end
    return false
end

local function WeaponTooltipHasBuff(group, slot)
    local function Matches(text)
        if type(text) ~= "string" then return false end
        text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
        if group.names[BuffName(text)] then return true end
        -- Timed enchants may append their remaining duration to the name.
        local label = text:match("^(.-)%s+%(")
        return label and group.names[BuffName(label)] or false
    end
    if C_TooltipInfo and C_TooltipInfo.GetInventoryItem then
        local ok, info = pcall(C_TooltipInfo.GetInventoryItem, "player", slot)
        if ok and info and info.lines then
            for _, line in ipairs(info.lines) do
                if Matches(line.leftText) or Matches(line.rightText) then return true end
            end
        end
    end
    -- Read the equipped item itself, including enchants already present at login.
    if not weaponTooltip then
        weaponTooltip = CreateFrame("GameTooltip", "LH_RemindersWeaponTooltip", UIParent, "GameTooltipTemplate")
    end
    weaponTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    weaponTooltip:ClearLines()
    local ok = pcall(weaponTooltip.SetInventoryItem, weaponTooltip, "player", slot)
    local found = false
    if ok then
        for i = 1, weaponTooltip:NumLines() do
            local left = _G["LH_RemindersWeaponTooltipTextLeft" .. i]
            local right = _G["LH_RemindersWeaponTooltipTextRight" .. i]
            if (left and Matches(left:GetText())) or (right and Matches(right:GetText())) then
                found = true
                break
            end
        end
    end
    weaponTooltip:Hide()
    return found
end

local function SavePosition()
    anchor:StopMovingOrSizing()
    local x, y = anchor:GetCenter()
    local cx, cy = UIParent:GetCenter()
    if x and cx then
        LH_RemindersDB.x, LH_RemindersDB.y = x - cx, y - cy
        anchor:ClearAllPoints()
        anchor:SetPoint("CENTER", UIParent, "CENTER", LH_RemindersDB.x, LH_RemindersDB.y)
    end
end

local function GetButton(index)
    if buttons[index] then return buttons[index] end
    local button = CreateFrame("Button", nil, anchor, "SecureActionButtonTemplate")
    button:SetSize(SIZE, SIZE)
    button:RegisterForClicks("AnyUp", "AnyDown")
    button:SetAttribute("unit", "player")
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetAllPoints()
    button.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    button.glow = button:CreateTexture(nil, "OVERLAY")
    button.glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    button.glow:SetBlendMode("ADD")
    button.glow:SetVertexColor(1, 0.8, 0.15, 1)
    button.glow:SetSize(64, 64)
    button.glow:SetPoint("CENTER")
    button:RegisterForDrag("LeftButton")
    button:SetScript("OnDragStart", function()
        if unlocked and not InCombat() then anchor:StartMoving() end
    end)
    button:SetScript("OnDragStop", SavePosition)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if self.example then
            GameTooltip:SetText("LH_Reminders: Position")
            GameTooltip:AddLine("Left-drag to move. /lh_reminders lock", 1, 1, 1, true)
        else
            GameTooltip:SetSpellByID(self.spellID)
            GameTooltip:AddLine("Missing buff", 1, 0.8, 0.15)
        end
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    buttons[index] = button
    return button
end

local function Refresh()
    -- Secure actions, visibility and layout must only be changed out of combat.
    if not initialized or InCombat() then return end
    local missing = {}
    if unlocked then
        missing[1] = { id = 8017, icon = select(2, SpellInfo(8017)), example = true }
    elseif not UnitIsDeadOrGhost("player") then
        for _, group in ipairs(groups) do
            local active
            if group.kind == "weapon" then
                local main, _, _, _, off = GetWeaponEnchantInfo()
                local mainLink = GetInventoryItemLink("player", 16)
                local offLink = GetInventoryItemLink("player", 17)
                active = main or off or HasBuff(group) or not (mainLink or offLink)
                if not active then
                    active = (mainLink and WeaponTooltipHasBuff(group, 16))
                        or (offLink and WeaponTooltipHasBuff(group, 17))
                end
            else
                active = HasBuff(group)
            end
            if not active and not LH_RemindersDB.exceptions[BuffName(group.name)] then
                missing[#missing + 1] = group
            end
        end
    end
    -- Hiding a dragged button interrupts WoW's drag capture. Keep visible
    -- buttons alive and only change their anchors when the layout changes.
    for i = #missing + 1, #buttons do buttons[i]:Hide() end
    for i, group in ipairs(missing) do
        local button = GetButton(i)
        local action = not group.example and group.id or nil
        if button.action ~= action then
            button:SetAttribute("type", action and "spell" or nil)
            -- A localized spell name lets WoW choose the highest learned rank.
            button:SetAttribute("spell", action and (group.name or group.id) or nil)
            button.action = action
        end
        button.spellID, button.example = group.id, group.example
        button.icon:SetTexture(group.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        local offset = (i - (#missing + 1) / 2) * (SIZE + GAP)
        if button.offset ~= offset then
            button:ClearAllPoints()
            button:SetPoint("CENTER", anchor, "CENTER", offset, 0)
            button.offset = offset
        end
        button:Show()
    end
end

SLASH_LH_REMINDERS1 = "/lh_reminders"
SlashCmdList.LH_REMINDERS = function(message)
    local input = (message or ""):match("^%s*(.-)%s*$")
    local command, argument = input:match("^(%S+)%s*(.-)$")
    command = (command or ""):lower()
    if command == "except" or command == "allow" then
        local first, last = argument:sub(1, 1), argument:sub(-1)
        if first == '"' or first == "'" then
            if last ~= first or #argument < 2 then
                print('LH_Reminders: /lh_reminders ' .. command .. ' "Spell name"')
                return
            end
            argument = argument:sub(2, -2)
        end
        local name = BuffName(argument)
        if not name or name == "" or argument:find('["\']') then
            print('LH_Reminders: /lh_reminders ' .. command .. ' "Spell name"')
            return
        end
        if not initialized then return end
        LH_RemindersDB.exceptions[name] = command == "except" and true or nil
        print("LH_Reminders: " .. argument .. (command == "except" and " disabled." or " enabled.")
            .. (InCombat() and " The display will update after combat." or ""))
        Refresh()
        return
    end
    if argument ~= "" then command = "" end
    if (command == "unlock" or command == "lock") and InCombat() then
        print("LH_Reminders: Edit the position after combat.")
        return
    end
    if command == "unlock" then
        unlocked = true
    elseif command == "lock" then
        if initialized then SavePosition() end
        unlocked = false
    else
        print('LH_Reminders: /lh_reminders unlock | lock | except "Spell name" | allow "Spell name"')
        return
    end
    Refresh()
end

anchor:SetScript("OnEvent", function(_, event, unit)
    if event == "ADDON_LOADED" then
        if unit ~= addonName then return end
        LH_RemindersDB = type(LH_RemindersDB) == "table" and LH_RemindersDB or {}
        if type(LH_RemindersDB.exceptions) ~= "table" then LH_RemindersDB.exceptions = {} end
        local x = tonumber(LH_RemindersDB.x) or 0
        local y = tonumber(LH_RemindersDB.y) or -120
        anchor:SetPoint("CENTER", UIParent, "CENTER", x, y)
        initialized = true
        BuildGroups()
    elseif event == "UNIT_AURA" and unit ~= "player" then
        return
    elseif event == "SPELLS_CHANGED" or event == "PLAYER_ENTERING_WORLD" then
        BuildGroups()
    end
    Refresh()
end)
for _, event in ipairs({ "ADDON_LOADED", "PLAYER_ENTERING_WORLD", "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED", "PLAYER_ALIVE", "PLAYER_DEAD", "PLAYER_UNGHOST", "PLAYER_REGEN_ENABLED", "UNIT_INVENTORY_CHANGED" }) do
    anchor:RegisterEvent(event)
end
-- Temporary weapon enchantments can expire without UNIT_AURA firing.
local elapsed = 0
anchor:SetScript("OnUpdate", function(_, delta)
    elapsed = elapsed + delta
    if elapsed >= 0.5 then elapsed = 0; Refresh() end
end)

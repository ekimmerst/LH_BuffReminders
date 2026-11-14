local addonName = ...
local Addon = {}
LH_BuffReminders = Addon
local SIZE, GAP = 36, 8
local unlocked, initialized = false, false
local buttons, groups = {}, {}
local groupsDirty = false
local weaponTooltip
local config
local Refresh
local function InCombat()
    return InCombatLockdown and InCombatLockdown()
end
-- Track the combat state from events as well as the lockdown API.
local fighting = false
local function Fighting() return fighting or InCombat() end
local anchor = CreateFrame("Frame", "LH_BuffRemindersFrame", UIParent)
anchor:SetSize(SIZE, SIZE)
anchor:SetMovable(true)
anchor:SetClampedToScreen(true)

local function SpellInfo(id)
    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(id)
        if info then return info.name, info.iconID end
    end
    if GetSpellInfo then
        local name, _, icon = GetSpellInfo(id)
        return name, icon
    end
end

local function EachKnownSpell(visit)
    if C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines and C_SpellBook.GetSpellBookSkillLineInfo
        and C_SpellBook.GetSpellBookItemInfo and Enum and Enum.SpellBookSpellBank then
        local bank = Enum.SpellBookSpellBank.Player
        for tab = 1, C_SpellBook.GetNumSpellBookSkillLines() do
            local line = C_SpellBook.GetSpellBookSkillLineInfo(tab)
            if line then
                for slot = line.itemIndexOffset + 1, line.itemIndexOffset + line.numSpellBookItems do
                    local spell = C_SpellBook.GetSpellBookItemInfo(slot, bank)
                    if spell and spell.spellID and not spell.isOffSpec and not spell.isPassive then
                        visit(spell.spellID)
                    end
                end
            end
        end
    elseif GetNumSpellTabs and GetSpellTabInfo and GetSpellBookItemInfo then
        for tab = 1, GetNumSpellTabs() do
            local _, _, offset, count = GetSpellTabInfo(tab)
            for slot = offset + 1, offset + count do
                local kind, id = GetSpellBookItemInfo(slot, BOOKTYPE_SPELL or "spell")
                if kind == "SPELL" and id then visit(id) end
            end
        end
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

local function CurrentClass()
    local _, class = UnitClass("player")
    return class
end

local function ClassConfig()
    local class = CurrentClass()
    if not class then return end
    LH_BuffRemindersDB = type(LH_BuffRemindersDB) == "table" and LH_BuffRemindersDB or {}
    local value = LH_BuffRemindersDB.config
    if type(value) ~= "table" then
        local classDB = type(LH_BuffRemindersClassDB) == "table" and LH_BuffRemindersClassDB[class]
        local legacy = type(classDB) == "table" and classDB or LH_BuffRemindersDB
        local exceptions = {}
        if type(legacy.exceptions) == "table" then
            for name, excluded in pairs(legacy.exceptions) do
                if excluded then exceptions[name] = true end
            end
        end
        local monitored = {}
        if type(legacy.monitored) == "table" then
            for _, entry in ipairs(legacy.monitored) do
                if type(entry) == "table" then
                    local copy = {}
                    for key, item in pairs(entry) do copy[key] = item end
                    monitored[#monitored + 1] = copy
                end
            end
        elseif class == "SHAMAN" then
            monitored = {{kind = "weapon"}, {kind = "shield"}}
        end
        value = {
            enabled = legacy.enabled ~= false, locked = legacy.locked ~= false,
            foodEnabled = legacy.foodEnabled == true,
            x = tonumber(legacy.x) or 0, y = tonumber(legacy.y) or -120,
            exceptions = exceptions,
            monitored = monitored,
        }
        LH_BuffRemindersDB.config = value
    end
    if type(value.monitored) ~= "table" then value.monitored = {} end
    if type(value.exceptions) ~= "table" then value.exceptions = {} end
    if type(value.enabled) ~= "boolean" then value.enabled = true end
    if type(value.foodEnabled) ~= "boolean" then value.foodEnabled = false end
    if type(value.locked) ~= "boolean" then value.locked = true end
    -- The monitored buffs and exceptions belong to this class, not the source.
    LH_LayoutProfiles:Register(addonName, value, LH_BuffRemindersDB, {"x", "y", "locked"})
    return value
end

local function SelectConfig()
    local selected = ClassConfig()
    if not selected then return end
    if config ~= selected then
        config = selected
        unlocked = not config.locked
        anchor:ClearAllPoints()
        anchor:SetPoint("CENTER", UIParent, "CENTER", tonumber(config.x) or 0, tonumber(config.y) or -120)
    end
    return config
end

function Addon:GetConfig() return config end

local definitions = {
    { kind = "weapon", ids = {
        8017, 8018, 8019, 10399, 16314, 16315, 16316,
        8024, 8027, 8030, 16339, 16341, 16342,
        8033, 8038, 10456, 16355, 16356,
        8232, 8235, 10486, 16362, 51730,
    } },
    { kind = "shield", ids = { 324, 52127, 974 } },
}

local function BuildShamanDefaults()
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

local function ResolveKnownSpell(id)
    local name = SpellInfo(id)
    if not name then return end
    local family = BuffName(name)
    local result = Known(id) and id or nil
    EachKnownSpell(function(candidate)
        local candidateName = SpellInfo(candidate)
        if candidateName and BuffName(candidateName) == family then result = candidate end
    end)
    if not result then return end
    local resolvedName, icon = SpellInfo(result)
    return result, resolvedName, icon
end

local function BuildGroups()
    SelectConfig()
    if not config then return end
    BuildShamanDefaults()
    local defaults = {}
    for _, group in ipairs(groups) do defaults[group.kind] = group end
    groups = {}
    for _, entry in ipairs(config.monitored) do
        if type(entry) == "table" then
            if entry.kind and defaults[entry.kind] then
                defaults[entry.kind].entry = entry
                groups[#groups + 1] = defaults[entry.kind]
            elseif type(entry.id) == "number" then
                local id, name, icon = ResolveKnownSpell(entry.id)
                if id then
                    groups[#groups + 1] = {
                        kind = "buff", id = id, name = name, icon = icon, entry = entry,
                        ids = {[entry.id] = true, [id] = true}, names = {[BuffName(name)] = true},
                    }
                end
            end
        end
    end
    if config.foodEnabled then
        -- Different foods use different spell IDs but share the localized aura name.
        local wellFed = SpellInfo(19705)
        local names = { ["well fed"] = true }
        if wellFed then names[BuffName(wellFed)] = true end
        groups[#groups + 1] = {
            kind = "food", name = wellFed or "Well Fed",
            icon = select(2, SpellInfo(2550)) or "Interface\\Icons\\Trade_Cooking",
            ids = {}, names = names,
        }
    end
    if Addon.RefreshSettings then Addon:RefreshSettings() end
end

function Addon:GetMonitored()
    return config and config.monitored or {}
end

function Addon:GetEntry(index)
    local entry = config and config.monitored[index]
    if not entry then return end
    if entry.kind then
        for _, group in ipairs(groups) do
            if group.kind == entry.kind then return group.name, group.icon end
        end
        return entry.kind == "weapon" and "Weapon enchant" or "Shield", nil
    end
    return SpellInfo(entry.id)
end

-- mode is "ooc" (watch outside combat) or "combat"; both default to on.
function Addon:GetWatch(index, mode)
    local entry = config and config.monitored[index]
    return entry ~= nil and entry[mode] ~= false
end

function Addon:SetWatch(index, mode, value)
    local entry = config and config.monitored[index]
    if not entry or (mode ~= "ooc" and mode ~= "combat") then return end
    entry[mode] = value and true or false
    Refresh()
    if self.RefreshSettings then self:RefreshSettings() end
end

function Addon:AddBuff(text)
    if not config then return false, "Settings are not ready." end
    text = type(text) == "string" and text:match("^%s*(.-)%s*$") or ""
    if text == "" then return false, "Enter a learned spell name or ID." end
    local id = tonumber(text)
    if id then
        if id < 1 or id ~= math.floor(id) then return false, "Enter a valid spell ID." end
        id = ResolveKnownSpell(id)
    else
        local wanted = BuffName(text)
        EachKnownSpell(function(candidate)
            local name = SpellInfo(candidate)
            if name and BuffName(name) == wanted then id = candidate end
        end)
    end
    if not id then return false, "Choose a learned buff spell." end
    local helpful = IsHelpfulSpell or (C_Spell and C_Spell.IsSpellHelpful)
    if helpful then
        local ok, result = pcall(helpful, id)
        if ok and result == false then return false, "Choose a helpful buff spell." end
    end
    local name = SpellInfo(id)
    if not name then return false, "Spell data is unavailable." end
    local key = BuffName(name)
    for index = 1, #config.monitored do
        local existing = self:GetEntry(index)
        if existing and BuffName(existing) == key then return false, "That buff is already monitored." end
    end
    config.monitored[#config.monitored + 1] = {id = id}
    BuildGroups()
    Refresh()
    return true
end

function Addon:RemoveBuff(index)
    if not config or not config.monitored[index] then return end
    table.remove(config.monitored, index)
    BuildGroups()
    Refresh()
end

local lastAuraInfo = "none"
local lastPayloadDetail = ""
-- Short ring buffer of aura/cast events for the diagnostic report.
local eventLog = {}
local function Log(text)
    eventLog[#eventLog + 1] = string.format("%.1f %s", GetTime and GetTime() or 0, text)
    if #eventLog > 30 then table.remove(eventLog, 1) end
end
local function Describe(value)
    if value == nil then return "nil" end
    if issecretvalue and issecretvalue(value) then return "SECRET(" .. type(value) .. ")" end
    if type(value) == "table" then return "table" end
    return tostring(value)
end
local function Public(value) return not (issecretvalue and issecretvalue(value)) end

local function AuraRestricted(group)
    local secrets = C_Secrets
    if not secrets then return false end
    if secrets.ShouldAurasBeSecret then
        local ok, secret = pcall(secrets.ShouldAurasBeSecret)
        if ok and Public(secret) and secret == true then return true end
    end
    if secrets.ShouldSpellAuraBeSecret and group.id then
        local ok, secret = pcall(secrets.ShouldSpellAuraBeSecret, group.id)
        if ok and Public(secret) and type(secret) == "boolean" then return secret end
    end
    return InCombat()
end

-- true/false, or nil when combat restrictions hide the aura data.
local function AuraMatches(group, aura)
    if type(aura) ~= "table" then return false end
    local id = aura.spellId or aura.spellID
    if id ~= nil and not Public(id) then return nil end
    if id and group.ids[id] then return true end
    local auraName = aura.name
    if auraName ~= nil and not Public(auraName) then return nil end
    if auraName and group.names[BuffName(auraName)] then return true end
    local name = id and SpellInfo(id)
    return name and group.names[BuffName(name)] or false
end

-- Remember the matched aura so its removal or expiry can be noticed in combat,
-- when the aura list itself cannot be trusted.
local function RememberAura(group, aura)
    local instance = aura.auraInstanceID
    group.auraID = type(instance) == "number" and Public(instance) and instance or nil
    local expires = aura.expirationTime
    group.expires = type(expires) == "number" and Public(expires) and expires > 0 and expires or nil
end

local function ForgetAura(group)
    group.auraID, group.expires, group.carried, group.castAt, group.auraSeen = nil, nil, nil, nil, nil
end

local function RemovedAura(group)
    ForgetAura(group)
    group.removed = true
end

-- Returns true/false, or nil when combat restrictions hide the aura data.
local function HasBuff(group)
    local unreadable = false
    local restricted = AuraRestricted(group)
    local function Matches(aura)
        local result = AuraMatches(group, aura)
        if result == nil then unreadable = true; return false end
        if result then RememberAura(group, aura) end
        return result
    end
    -- Forever can expose weapon buffs as player auras instead of temporary
    -- item enchants. Prefer its batch API, but retain indexed/legacy fallbacks.
    if C_UnitAuras and C_UnitAuras.GetUnitAuras then
        local ok, auras = pcall(C_UnitAuras.GetUnitAuras, "player", "HELPFUL")
        if not ok or not Public(auras) or
            (issecrettable and type(auras) == "table" and issecrettable(auras)) then
            unreadable = true
        elseif type(auras) == "table" then
            local scanned, found, nonempty = pcall(function()
                for _, aura in ipairs(auras) do
                    if Matches(aura) then return true end
                end
                return false, #auras > 0
            end)
            if not scanned then unreadable = true
            elseif found then return true
            elseif nonempty and not unreadable and not restricted then return false end
        else
            unreadable = true
        end
    end
    for i = 1, 255 do
        local name
        if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
            local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, "player", i, "HELPFUL")
            if ok and not Public(aura) then
                unreadable = true
            elseif ok and aura and not (issecrettable and type(aura) == "table" and issecrettable(aura)) then
                if Matches(aura) then return true end
                name = aura.name
            elseif not ok then
                unreadable = true
            elseif aura then
                unreadable = true
            end
        end
        if not Public(name) then unreadable = true; name = nil end
        if not name and (UnitBuff or UnitAura) then
            local ok, legacyName, _, _, _, _, expiration = pcall(UnitBuff or UnitAura, "player", i, "HELPFUL")
            if ok and Public(legacyName) then
                name = legacyName
                if name and group.names[BuffName(name)] and Public(expiration) and
                    type(expiration) == "number" and expiration > 0 then
                    group.expires = expiration
                end
            else unreadable = true end
        end
        if not name then break end
        if not Public(name) then unreadable = true
        elseif group.names[BuffName(name)] then return true end
    end
    if unreadable or restricted then return nil end
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
        weaponTooltip = CreateFrame("GameTooltip", "LH_BuffRemindersWeaponTooltip", UIParent, "GameTooltipTemplate")
    end
    weaponTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    weaponTooltip:ClearLines()
    local ok = pcall(weaponTooltip.SetInventoryItem, weaponTooltip, "player", slot)
    local found = false
    if ok then
        for i = 1, weaponTooltip:NumLines() do
            local left = _G["LH_BuffRemindersWeaponTooltipTextLeft" .. i]
            local right = _G["LH_BuffRemindersWeaponTooltipTextRight" .. i]
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
        config.x, config.y = x - cx, y - cy
        anchor:ClearAllPoints()
        anchor:SetPoint("CENTER", UIParent, "CENTER", config.x, config.y)
    end
end

local PULSE_TIME, PULSE_PERIOD = 3, 1

-- Grows and shrinks the icon of a newly shown reminder once per period.
local GLOW_SIZE = 64

-- grow is the extra distance per side; the glow border scales by the same ratio.
local function SetIconGrowth(button, grow)
    local icon = button.icon
    local iconSize = SIZE + 2 * grow
    icon:ClearAllPoints()
    icon:SetPoint("CENTER", button, "CENTER", 0, 0)
    icon:SetSize(iconSize, iconSize)
    local glowSize = GLOW_SIZE * iconSize / SIZE
    button.glow:SetSize(glowSize, glowSize)
end

local function PulseStop(self)
    self:SetScript("OnUpdate", nil)
    SetIconGrowth(self, 0)
end

local function PulseUpdate(self)
    local elapsed = GetTime() - self.pulseStart
    if elapsed >= PULSE_TIME then return PulseStop(self) end
    local wave = (1 - math.cos(elapsed / PULSE_PERIOD * 2 * math.pi)) / 2
    SetIconGrowth(self, SIZE * 0.1 * wave)
end

local function SetReminderShown(button, show)
    local wasShown = button:GetAlpha() > 0
    button:SetAlpha(show and 1 or 0)
    if show and not wasShown and button.example ~= true then
        button.pulseStart = GetTime()
        button:SetScript("OnUpdate", PulseUpdate)
    elseif not show and button:GetScript("OnUpdate") then
        PulseStop(button)
    end
end

local function GetButton(index)
    if buttons[index] then return buttons[index] end
    local button = CreateFrame("Frame", nil, anchor)
    button:SetSize(SIZE, SIZE)
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetPoint("CENTER", button, "CENTER", 0, 0)
    button.icon:SetSize(SIZE, SIZE)
    button.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    button.glow = button:CreateTexture(nil, "OVERLAY")
    button.glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    button.glow:SetBlendMode("ADD")
    button.glow:SetVertexColor(1, 0.8, 0.15, 1)
    button.glow:SetSize(GLOW_SIZE, GLOW_SIZE)
    button.glow:SetPoint("CENTER")
    button:RegisterForDrag("LeftButton")
    button:SetScript("OnDragStart", function()
        if unlocked and not InCombat() then anchor:StartMoving() end
    end)
    button:SetScript("OnDragStop", SavePosition)
    button:SetScript("OnEnter", function(self)
        if self:GetAlpha() == 0 then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if self.example then
            GameTooltip:SetText("LH_BuffReminders: Position")
            GameTooltip:AddLine("Left-drag to move. /lh_buffreminders lock", 1, 1, 1, true)
        else
            if self.group and self.group.kind == "food" then
                GameTooltip:SetText("Food buff")
                GameTooltip:AddLine("No Well Fed buff active", 1, 0.8, 0.15)
            else
                GameTooltip:SetSpellByID(self.spellID)
                GameTooltip:AddLine("Missing buff", 1, 0.8, 0.15)
            end
        end
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    button:SetMouseClickEnabled(false)
    buttons[index] = button
    return button
end

local function Watched(group, inCombat)
    local entry = group.entry
    if not entry then return true end
    if inCombat then return entry.combat ~= false end
    return entry.ooc ~= false
end

-- Combat can make the aura list incomplete. A successful cast of a group's own spell, or
-- a buff seen before combat (group.carried), therefore stays authoritative for the fight
-- until an aura read has confirmed the buff once (group.auraSeen); only then does a
-- missing aura mean the buff was lost. A fresh cast also counts for a short grace period.
local CAST_GRACE = 1.5

-- Aura instance IDs of auras whose fields were unreadable when they were added; a cast
-- of a watched buff claims the matching one (the aura event and the cast event can
-- arrive in either order).
local pendingAdds = {}
local ATTRIBUTION_WINDOW = 1.0

local function ClaimAura(group, instance)
    Log("CLAIM " .. tostring(group.name) .. " <- aura " .. tostring(instance))
    group.auraID, group.expires, group.carried = instance, nil, true
    group.removed = nil
end

-- Use the public UNIT_AURA details when available; restricted auras may hide them.
local function TrackAuras(info)
    if type(info) ~= "table" or not Public(info) then return end
    lastAuraInfo = string.format("added=%d updated=%d removed=%d", #(info.addedAuras or {}),
        #(info.updatedAuraInstanceIDs or {}), #(info.removedAuraInstanceIDs or {}))
    local detail = {}
    for _, aura in ipairs(info.addedAuras or {}) do
        detail[#detail + 1] = type(aura) == "table" and ("add id=" .. Describe(aura.auraInstanceID)
            .. " spell=" .. Describe(aura.spellId) .. " name=" .. Describe(aura.name)) or "add ?"
    end
    for _, id in ipairs(info.removedAuraInstanceIDs or {}) do detail[#detail + 1] = "removed id=" .. Describe(id) end
    for _, id in ipairs(info.updatedAuraInstanceIDs or {}) do detail[#detail + 1] = "updated id=" .. Describe(id) end
    lastPayloadDetail = table.concat(detail, "; ")
    Log("AURA " .. lastAuraInfo .. " [" .. lastPayloadDetail .. "]")
    for _, instance in ipairs(info.removedAuraInstanceIDs or {}) do
        for _, group in ipairs(groups) do
            if group.auraID and group.auraID == instance then
                Log("FORGET " .. tostring(group.name) .. " (aura " .. tostring(instance) .. " removed)")
                RemovedAura(group)
            end
        end
    end
    for _, instance in ipairs(info.updatedAuraInstanceIDs or {}) do
        for _, group in ipairs(groups) do
            if group.auraID and group.auraID == instance then
                local fetch = C_UnitAuras and C_UnitAuras.GetAuraDataByAuraInstanceID
                local ok, aura = false, nil
                if fetch then ok, aura = pcall(fetch, "player", instance) end
                if ok and type(aura) == "table" then RememberAura(group, aura) else group.expires = nil end
            end
        end
    end
    for _, aura in ipairs(info.addedAuras or {}) do
        local instance = type(aura) == "table" and aura.auraInstanceID
        local claimed = false
        for _, group in ipairs(groups) do
            local match = AuraMatches(group, aura)
            if match == true then RememberAura(group, aura); group.carried = true; group.removed = nil; claimed = true
            elseif match == nil and type(instance) == "number" and Public(instance) then
                if group.castAt and GetTime() - group.castAt < ATTRIBUTION_WINDOW then
                    ClaimAura(group, instance); claimed = true
                end
            end
        end
        if not claimed and type(instance) == "number" and Public(instance) then
            local now = GetTime()
            pendingAdds[#pendingAdds + 1] = {id = instance, at = now}
            while #pendingAdds > 10 do table.remove(pendingAdds, 1) end
        end
    end
end

-- Presence probes may also hide an aura in combat. Returns true/false, or nil when unknown.
-- A missing spell-ID result only proves absence once the same probe has found the buff
-- during combat (per buff name), because combat restrictions may hide the aura instead.
local probeProven = {}
local function AuraPresent(group)
    if AuraRestricted(group) then return nil end
    local instance, spell
    local byInstance = C_UnitAuras and C_UnitAuras.GetAuraDataByAuraInstanceID
    if group.auraID and byInstance then
        local ok, data = pcall(byInstance, "player", group.auraID)
        if ok then instance = data ~= nil end
    end
    if instance then return true end
    local bySpell = C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID
    if bySpell then
        for id in pairs(group.ids) do
            local ok, data = pcall(bySpell, id)
            if ok then
                spell = false
                if data ~= nil then
                    if type(data) == "table" then pcall(RememberAura, group, data) end
                    if InCombat() then probeProven[BuffName(group.name)] = true end
                    return true
                end
            end
        end
    end
    -- A vanished known instance is conclusive; a missing spell ID alone is not,
    -- because the aura may use a different ID than the cast spell.
    if instance == false then return false end
    if spell == false and probeProven[BuffName(group.name)] then return false end
    return nil
end

local function IsActive(group)
    if group.kind == "weapon" then
        local main, _, _, _, off = GetWeaponEnchantInfo()
        local mainLink = GetInventoryItemLink("player", 16)
        local offLink = GetInventoryItemLink("player", 17)
        local active = main or off or HasBuff(group) or not (mainLink or offLink)
        if not active then
            active = (mainLink and WeaponTooltipHasBuff(group, 16))
                or (offLink and WeaponTooltipHasBuff(group, 17))
        end
        return active
    end
    return HasBuff(group)
end

-- Check the cast spell rather than the aura: some short buffs can end while
-- their triggering spell (for example Elune's Light) is still cooling down.
local function CooldownActive(group)
    local id = group.id
    if type(id) ~= "number" then return false end
    -- Cooldown APIs can still report the old ready state in the cast event.
    if group.castAt and GetTime() - group.castAt < 0.5 then return true end
    local charges = C_Spell and C_Spell.GetSpellCharges
    if charges then
        local ok, info = pcall(charges, id)
        if ok and Public(info) and type(info) == "table"
            and not (issecrettable and issecrettable(info))
            and Public(info.currentCharges) and type(info.currentCharges) == "number"
            and info.currentCharges > 0 then
            group.cooldownBlocked = false
            return false
        end
    end
    local modern = C_Spell and C_Spell.GetSpellCooldown
    local legacy = not modern and GetSpellCooldown
    if modern or legacy then
        local ok, info, duration, enabled, rate = pcall(modern or legacy, id)
        if ok then
            local start
            if modern and Public(info) and type(info) == "table"
                and not (issecrettable and issecrettable(info)) then
                start, duration, enabled, rate = info.startTime, info.duration, info.isEnabled, info.modRate
            elseif legacy then start = info end
            if Public(enabled) and (enabled == false or enabled == 0) then
                group.cooldownBlocked = true
                return true
            end
            if Public(start) and Public(duration) and type(start) == "number"
                and type(duration) == "number" then
                local speed = Public(rate) and type(rate) == "number" and rate > 0 and rate or 1
                local cooling = start > 0 and duration > 0 and start + duration / speed > GetTime() + 0.05
                group.cooldownBlocked = cooling
                return cooling
            end
            -- Since 12.0.1 this flag remains readable when cooldown times are
            -- secret. In particular, it clears a stale blocked state on expiry.
            if modern and Public(info) and type(info) == "table"
                and not (issecrettable and issecrettable(info))
                and Public(info.isActive) and type(info.isActive) == "boolean" then
                group.cooldownBlocked = info.isActive
                return info.isActive
            end
        end
    end
    -- Modern clients can expose an opaque duration even when numeric cooldown
    -- fields are restricted in combat.
    local durationQuery = C_Spell and C_Spell.GetSpellCooldownDuration
    if durationQuery then
        local ok, object = pcall(durationQuery, id, false)
        if ok and Public(object) and object then
            local okMethod, method = pcall(function() return object.GetRemainingDuration end)
            if okMethod and type(method) == "function" then
                local okRemaining, remaining = pcall(method, object)
                if okRemaining and Public(remaining) and type(remaining) == "number" then
                    local cooling = remaining > 0.05
                    group.cooldownBlocked = cooling
                    return cooling
                end
            end
        end
    end
    return group.cooldownBlocked == true
end

-- Spell usability includes form/stance, resources and other cast requirements.
-- A secret or unavailable answer cannot establish that the reminder is usable.
local function SpellUsable(group)
    local query = C_Spell and C_Spell.IsSpellUsable or IsUsableSpell
    if not query or type(group.id) ~= "number" then return false end
    local ok, usable = pcall(query, group.id)
    return ok and Public(usable) and (usable == true or usable == 1)
end

-- These are display-only frames, so the visible reminders can be packed and
-- centered again whenever their number changes, including during combat.
local function LayoutReminders(missing)
    for i = #missing + 1, #buttons do
        SetReminderShown(buttons[i], false)
        buttons[i]:Hide()
        buttons[i].group = nil
    end
    for i, group in ipairs(missing) do
        local button = GetButton(i)
        if button.group ~= group then button:SetAlpha(0) end
        button.group = group
        button.spellID, button.example = group.id, group.example
        button.icon:SetTexture(group.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        local offset = (i - (#missing + 1) / 2) * (SIZE + GAP)
        if button.offset ~= offset then
            button:ClearAllPoints()
            button:SetPoint("CENTER", anchor, "CENTER", offset, 0)
            button.offset = offset
        end
        local draggable = unlocked and not InCombat()
        if button.draggable ~= draggable then
            button:SetMouseClickEnabled(draggable)
            button.draggable = draggable
        end
        button:Show()
        SetReminderShown(button, true)
    end
end

local function CombatRefresh()
    local dead = UnitIsDeadOrGhost("player")
    local missing = {}
    local wasVisible = {}
    for _, button in ipairs(buttons) do
        if button.group and button:IsShown() and button:GetAlpha() > 0 then
            wasVisible[button.group] = true
        end
    end
    if not config.enabled then return LayoutReminders(missing) end
    if unlocked then
        missing[1] = { id = 8017, icon = select(2, SpellInfo(8017)), example = true }
        return LayoutReminders(missing)
    end
    for _, group in ipairs(groups) do
        local show = false
        if not dead and Watched(group, true)
            and not config.exceptions[BuffName(group.name)] then
            local restricted = AuraRestricted(group)
            -- A public expiry can become stale after a refresh whose aura data
            -- is secret. Only use it when the aura remains readable.
            if not restricted and group.expires and GetTime() > group.expires + 0.5 then RemovedAura(group) end
            local ok, active = pcall(IsActive, group)
            if not ok then active = nil end
            local okPresent, present = pcall(AuraPresent, group)
            if not okPresent then present = nil end
            local recent = group.castAt and GetTime() - group.castAt < CAST_GRACE
            if active == true or present == true then
                group.auraSeen, group.carried, group.removed = true, true, nil
            elseif not recent then
                -- Unknown aura state must never become a missing-buff alert.
                show = group.removed == true or present == false or active == false
                    or group.precombatMissing == true
            end
            -- Keep an already visible missing-buff reminder through a temporary
            -- form restriction. A newly missing buff still needs a usable spell.
            if show and group.kind ~= "food"
                and ((not wasVisible[group] and not SpellUsable(group)) or CooldownActive(group)) then show = false end
        end
        if show then missing[#missing + 1] = group end
    end
    LayoutReminders(missing)
end

Refresh = function()
    if not initialized then return end
    if Fighting() then return CombatRefresh() end
    local missing = {}
    if not config.enabled then
        -- No preview remains visible while disabled.
    elseif unlocked then
        missing[1] = { id = 8017, icon = select(2, SpellInfo(8017)), example = true }
    elseif not UnitIsDeadOrGhost("player") then
        local fight = Fighting()
        for _, group in ipairs(groups) do
            ForgetAura(group)
            group.removed = nil
            if not config.exceptions[BuffName(group.name)] then
                local active = IsActive(group)
                -- Remembered for combat, when the aura list can omit buffs that are present.
                group.carried = active and true or nil
                group.precombatMissing = active == false
                if Watched(group, fight) and active == false
                    and (group.kind == "food" or (SpellUsable(group) and not CooldownActive(group))) then
                    missing[#missing + 1] = group
                end
            end
        end
    end
    LayoutReminders(missing)
end

-- Diagnostic reports open in a selectable text box (Ctrl+A, Ctrl+C) instead of the chat.
local reportLines, reportFrame = {}, nil
local function Out(text) reportLines[#reportLines + 1] = text end
local function ShowReport()
    if not reportFrame then
        reportFrame = CreateFrame("Frame", "LH_BuffRemindersReport", UIParent, "BackdropTemplate")
        reportFrame:SetSize(620, 360)
        reportFrame:SetPoint("CENTER")
        reportFrame:SetFrameStrata("DIALOG")
        reportFrame:SetMovable(true)
        reportFrame:EnableMouse(true)
        reportFrame:RegisterForDrag("LeftButton")
        reportFrame:SetScript("OnDragStart", reportFrame.StartMoving)
        reportFrame:SetScript("OnDragStop", reportFrame.StopMovingOrSizing)
        reportFrame:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 8, insets = {left = 2, right = 2, top = 2, bottom = 2}})
        reportFrame:SetBackdropColor(0, 0, 0, 0.95)
        local hint = reportFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        hint:SetPoint("TOPLEFT", 12, -10)
        hint:SetText("LH_BuffReminders report - Ctrl+A, Ctrl+C to copy, Esc to close")
        local scroll = CreateFrame("ScrollFrame", nil, reportFrame, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 12, -30)
        scroll:SetPoint("BOTTOMRIGHT", -32, 12)
        local edit = CreateFrame("EditBox", nil, scroll)
        edit:SetMultiLine(true)
        edit:SetFontObject(ChatFontNormal or GameFontHighlight)
        edit:SetWidth(560)
        edit:SetAutoFocus(false)
        edit:SetScript("OnEscapePressed", function() reportFrame:Hide() end)
        scroll:SetScrollChild(edit)
        reportFrame.edit = edit
        local close = CreateFrame("Button", nil, reportFrame, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", -2, -2)
    end
    reportFrame.edit:SetText(table.concat(reportLines, "\n"))
    reportLines = {}
    reportFrame:Show()
    reportFrame.edit:HighlightText()
    reportFrame.edit:SetFocus()
end

SLASH_LH_BUFFREMINDERS1 = "/lh_buffreminders"
SlashCmdList.LH_BUFFREMINDERS = function(message)
    local input = (message or ""):match("^%s*(.-)%s*$")
    local command, argument = input:match("^(%S+)%s*(.-)$")
    command = (command or ""):lower()
    if command == "except" or command == "allow" then
        local first, last = argument:sub(1, 1), argument:sub(-1)
        if first == '"' or first == "'" then
            if last ~= first or #argument < 2 then
                print('LH_BuffReminders: /lh_buffreminders ' .. command .. ' "Spell name"')
                return
            end
            argument = argument:sub(2, -2)
        end
        local name = BuffName(argument)
        if not name or name == "" or argument:find('["\']') then
            print('LH_BuffReminders: /lh_buffreminders ' .. command .. ' "Spell name"')
            return
        end
        if not initialized then return end
        config.exceptions[name] = command == "except" and true or nil
        print("LH_BuffReminders: " .. argument .. (command == "except" and " disabled." or " enabled.")
            .. (InCombat() and " The display will update after combat." or ""))
        Refresh()
        return
    end
    if command == "probe" then
        local function Try(label, fn, ...)
            local ok, a, b, c = pcall(fn, ...)
            Out("  " .. label .. ": " .. (ok and (Describe(a) .. " " .. Describe(b) .. " " .. Describe(c)) or ("ERROR " .. tostring(a))))
            return ok, a
        end
        for _, entry in ipairs(eventLog) do Out("  log " .. entry) end
        for _, group in ipairs(groups) do
            Out("  group " .. tostring(group.name) .. ": auraID=" .. tostring(group.auraID)
                .. " carried=" .. tostring(group.carried) .. " castAt=" .. tostring(group.castAt))
        end
        Out("LH_BuffReminders probe: lockdown=" .. tostring(InCombat()) .. " lastPayload=[" .. lastPayloadDetail .. "]")
        if UnitBuff then Try("UnitBuff(1)", UnitBuff, "player", 1) end
        if UnitAura then Try("UnitAura(1)", UnitAura, "player", 1, "HELPFUL") end
        local A = C_UnitAuras
        if A and A.GetAuraDataByIndex then
            local ok, data = Try("GetAuraDataByIndex(1)", A.GetAuraDataByIndex, "player", 1, "HELPFUL")
            if ok and type(data) == "table" then
                Out("    fields: name=" .. Describe(data.name) .. " spellId=" .. Describe(data.spellId)
                    .. " id=" .. Describe(data.auraInstanceID) .. " expires=" .. Describe(data.expirationTime))
            end
        end
        if A and A.GetUnitAuras then Try("GetUnitAuras", A.GetUnitAuras, "player", "HELPFUL") end
        if A and A.GetUnitAuraInstanceIDs then
            local ok, ids = Try("GetUnitAuraInstanceIDs", A.GetUnitAuraInstanceIDs, "player", "HELPFUL")
            if ok and type(ids) == "table" then
                local parts = {}
                for _, id in ipairs(ids) do parts[#parts + 1] = Describe(id) end
                Out("    ids: " .. table.concat(parts, ","))
            end
        end
        for _, group in ipairs(groups) do
            if AuraUtil and AuraUtil.FindAuraByName then Try(group.name .. " FindAuraByName", AuraUtil.FindAuraByName, group.name, "player", "HELPFUL") end
            if A and A.GetAuraDataBySpellName then Try(group.name .. " GetAuraDataBySpellName", A.GetAuraDataBySpellName, "player", group.name, "HELPFUL") end
            if A and A.GetPlayerAuraBySpellID and group.id then Try(group.name .. " GetPlayerAuraBySpellID", A.GetPlayerAuraBySpellID, group.id) end
        end
        ShowReport()
        return
    end
    if command == "debug" then
        Out("LH_BuffReminders: lockdown=" .. tostring(InCombat()) .. " fighting=" .. tostring(fighting)
            .. " enabled=" .. tostring(config and config.enabled))
        local visible = 0
        for _, button in ipairs(buttons) do
            if button:IsShown() and button:GetAlpha() > 0 then visible = visible + 1 end
        end
        Out("  visible icons=" .. visible)
        Out("  last UNIT_AURA payload: " .. lastAuraInfo .. " [" .. lastPayloadDetail .. "]"
            .. " | GetPlayerAuraBySpellID=" .. tostring(C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID ~= nil)
            .. " GetAuraDataByAuraInstanceID=" .. tostring(C_UnitAuras and C_UnitAuras.GetAuraDataByAuraInstanceID ~= nil)
            .. " secrets=" .. tostring(issecretvalue ~= nil))
        for _, group in ipairs(groups) do
            local okP, present = pcall(AuraPresent, group)
            Out("  " .. tostring(group.name) .. " spell probe proven in combat=" .. tostring(probeProven[BuffName(group.name)] == true))
            Out("  " .. tostring(group.name) .. " presence probe=" .. (okP and tostring(present) or ("error: " .. tostring(present))))
            if C_UnitAuras and group.auraID and C_UnitAuras.GetAuraDataByAuraInstanceID then
                local okI, data = pcall(C_UnitAuras.GetAuraDataByAuraInstanceID, "player", group.auraID)
                Out("    byInstance(" .. group.auraID .. "): ok=" .. tostring(okI) .. " result=" .. (okI and type(data) or tostring(data)))
            end
            if C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
                for id in pairs(group.ids) do
                    local okS, data = pcall(C_UnitAuras.GetPlayerAuraBySpellID, id)
                    Out("    bySpell(" .. tostring(id) .. "): ok=" .. tostring(okS) .. " result=" .. (okS and type(data) or tostring(data)))
                end
            end
            if C_UnitAuras and C_UnitAuras.GetUnitAuras then
                local okL, auras = pcall(C_UnitAuras.GetUnitAuras, "player", "HELPFUL")
                local count = okL and type(auras) == "table" and #auras or -1
                Out("    aura list: ok=" .. tostring(okL) .. " entries=" .. count)
            end
            for _, button in ipairs(buttons) do
                if button.group == group then
                    Out("    button alpha=" .. tostring(button:GetAlpha()) .. " shown="
                        .. tostring(button:IsShown() and true or false) .. " offset=" .. tostring(button.offset))
                end
            end
            local ok, active = pcall(IsActive, group)
            Out(string.format("  %s: active=%s%s restricted=%s missingBeforeCombat=%s auraID=%s expiresIn=%s castAge=%s watched ooc=%s combat=%s",
                tostring(group.name), tostring(active), ok and "" or " (error)",
                tostring(AuraRestricted(group)), tostring(group.precombatMissing), tostring(group.auraID),
                group.expires and string.format("%.0f", group.expires - GetTime()) or "-",
                group.castAt and string.format("%.1f", GetTime() - group.castAt) or "-",
                tostring(Watched(group, false)), tostring(Watched(group, true))))
        end
        ShowReport()
        return
    end
    if argument ~= "" then command = "" end
    if command == "" and input == "" and Addon.category and Settings and Settings.OpenToCategory then
        Settings.OpenToCategory(Addon.category:GetID())
        return
    end
    if (command == "unlock" or command == "lock") and InCombat() then
        print("LH_BuffReminders: Edit the position after combat.")
        return
    end
    if command == "unlock" then
        unlocked = true
        if config then config.locked = false end
    elseif command == "lock" then
        if initialized then SavePosition() end
        unlocked = false
        if config then config.locked = true end
    else
        print('LH_BuffReminders: /lh_buffreminders unlock | lock | debug | except "Spell name" | allow "Spell name"')
        return
    end
    Refresh()
    if Addon.RefreshSettings then Addon:RefreshSettings() end
end

function Addon:SetEnabled(enabled)
    if not config then return end
    config.enabled = not not enabled
    Refresh()
end

function Addon:SetFoodEnabled(enabled)
    if not config then return end
    config.foodEnabled = not not enabled
    BuildGroups()
    Refresh()
end

anchor:SetScript("OnEvent", function(_, event, unit, extra, spellID)
    if event == "ADDON_LOADED" then
        if unit ~= addonName then return end
        LH_BuffRemindersDB = type(LH_BuffRemindersDB) == "table" and LH_BuffRemindersDB or {}
        SelectConfig()
        initialized = true
        fighting = UnitAffectingCombat and UnitAffectingCombat("player") or false
        BuildGroups()
    elseif event == "PLAYER_REGEN_DISABLED" then
        fighting = true
    elseif event == "PLAYER_REGEN_ENABLED" then
        fighting = false
        if groupsDirty then
            groupsDirty = false
            BuildGroups()
        end
    elseif event == "UNIT_AURA" and unit ~= "player" then
        return
    elseif event == "UNIT_AURA" then
        lastAuraInfo = type(extra) == "table" and "payload" or tostring(extra)
        lastPayloadDetail = ""
        if type(extra) ~= "table" or not Public(extra) then Log("AURA payload " .. Describe(extra)) end
        local ok = pcall(TrackAuras, extra)
        if not ok then
            lastAuraInfo = "unreadable payload"
            Log("AURA payload unreadable")
        end
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        if unit ~= "player" then return end
        if not Public(spellID) then Log("CAST with SECRET spell id"); return end
        for _, group in ipairs(groups) do
            if group.ids[spellID] then
                local now = GetTime()
                Log("CAST " .. tostring(group.name) .. " pending=" .. #pendingAdds)
                group.castAt, group.auraSeen, group.expires, group.removed, group.precombatMissing = now, nil, nil, nil, nil
                group.cooldownBlocked = true
                for i = #pendingAdds, 1, -1 do
                    local pending = pendingAdds[i]
                    if now - pending.at < ATTRIBUTION_WINDOW then
                        ClaimAura(group, pending.id)
                        table.remove(pendingAdds, i)
                        break
                    end
                end
            end
        end
    elseif event == "SPELLS_CHANGED" or event == "PLAYER_ENTERING_WORLD" then
        if Fighting() then groupsDirty = true else BuildGroups() end
    end
    Refresh()
end)
for _, event in ipairs({ "ADDON_LOADED", "PLAYER_ENTERING_WORLD", "SPELLS_CHANGED", "SPELL_UPDATE_COOLDOWN", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED", "PLAYER_ALIVE", "PLAYER_DEAD", "PLAYER_UNGHOST", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "UNIT_SPELLCAST_SUCCEEDED", "UNIT_INVENTORY_CHANGED" }) do
    anchor:RegisterEvent(event)
end
-- Temporary weapon enchantments can expire without UNIT_AURA firing.
local elapsed = 0
anchor:SetScript("OnUpdate", function(_, delta)
    elapsed = elapsed + delta
    if elapsed >= 0.5 then elapsed = 0; Refresh() end
end)

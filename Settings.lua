local addonName = ...
local Addon = LH_BuffReminders
local variables = {}

function Addon:RefreshSettings()
    if not self.notifying and Settings and Settings.NotifyUpdate then
        self.notifying = true
        for _, variable in ipairs(variables) do Settings.NotifyUpdate(variable) end
        self.notifying = false
    end
    for _, panel in ipairs(self.listPanels or {}) do
        if panel.RefreshList then panel:RefreshList() end
    end
end

local function Proxy(category, key, label, default, get, set)
    local variable = "LH_BuffReminders_" .. key
    variables[#variables + 1] = variable
    return Settings.RegisterProxySetting(category, variable, "boolean", label, default, get, set)
end

LHBuffRemindersBuffListMixin = {}

function LHBuffRemindersBuffListMixin:OnLoad()
    Addon.listPanels = Addon.listPanels or {}
    Addon.listPanels[#Addon.listPanels + 1] = self
    local note = self:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    note:SetPoint("TOPLEFT", 8, -4)
    note:SetText("Enter a learned buff name or ID. Shared by your class.")
    note:SetWidth(430)
    note:SetJustifyH("LEFT")

    local scroll = CreateFrame("ScrollFrame", nil, self, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 8, -43)
    for _, column in ipairs({{"Out of combat", 238}, {"In combat", 320}}) do
        local header = self:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        header:SetPoint("TOP", self, "TOPLEFT", column[2], -27)
        header:SetText(column[1])
    end
    scroll:SetSize(420, 188)
    self.scroll = scroll
    self.content = CreateFrame("Frame", nil, scroll)
    self.content:SetSize(392, 188)
    scroll:SetScrollChild(self.content)
    self.rows = {}

    local edit = CreateFrame("EditBox", nil, self, "InputBoxTemplate")
    edit:SetSize(315, 25)
    edit:SetPoint("TOPLEFT", scroll, "BOTTOMLEFT", 8, -12)
    edit:SetAutoFocus(false)
    edit:SetMaxLetters(120)
    self.edit = edit
    local add = CreateFrame("Button", nil, self, "UIPanelButtonTemplate")
    add:SetSize(45, 25)
    add:SetPoint("LEFT", edit, "RIGHT", 12, 0)
    add:SetText("+")
    self.add = add
    self.message = self:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    self.message:SetPoint("TOPLEFT", edit, "BOTTOMLEFT", -3, -7)
    self.message:SetWidth(415)
    self.message:SetJustifyH("LEFT")
    local function AddBuff()
        local ok, message = Addon:AddBuff(edit:GetText())
        if ok then edit:SetText(""); edit:ClearFocus(); self.message:SetText("")
        else self.message:SetText(message or "Unable to add buff.") end
    end
    add:SetScript("OnClick", AddBuff)
    edit:SetScript("OnEnterPressed", AddBuff)
    edit:SetScript("OnEscapePressed", function(box) box:ClearFocus() end)
end

function LHBuffRemindersBuffListMixin:Init(initializer)
    self:RefreshList()
end

function LHBuffRemindersBuffListMixin:Release()
    if self.edit then self.edit:ClearFocus() end
end

function LHBuffRemindersBuffListMixin:OnShow()
    self:RefreshList()
end

function LHBuffRemindersBuffListMixin:RefreshList()
    if not self.rows then return end
    local monitored = Addon:GetMonitored()
    for index, entry in ipairs(monitored) do
        local row = self.rows[index]
        if not row then
            row = CreateFrame("Frame", nil, self.content)
            row:SetSize(385, 31)
            row.icon = row:CreateTexture(nil, "ARTWORK")
            row.icon:SetSize(25, 25)
            row.icon:SetPoint("LEFT", 4, 0)
            row.name = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
            row.name:SetPoint("LEFT", row.icon, "RIGHT", 9, 0)
            row.name:SetWidth(160)
            row.name:SetJustifyH("LEFT")
            for _, mode in ipairs({{"ooc", 218, "Watch this buff outside combat."},
                {"combat", 300, "Watch this buff during combat."}}) do
                local check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
                check:SetSize(24, 24)
                check:SetPoint("LEFT", mode[2], 0)
                check.mode = mode[1]
                check:SetScript("OnClick", function(box)
                    Addon:SetWatch(box:GetParent().index, box.mode, box:GetChecked())
                end)
                check:SetScript("OnEnter", function(box)
                    GameTooltip:SetOwner(box, "ANCHOR_RIGHT")
                    GameTooltip:SetText(mode[3], 1, 1, 1, 1, true)
                end)
                check:SetScript("OnLeave", function() GameTooltip:Hide() end)
                row[mode[1]] = check
            end
            row.remove = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
            row.remove:SetSize(26, 24)
            row.remove:SetPoint("RIGHT", -4, 0)
            row.remove:SetText("x")
            row.remove:SetScript("OnClick", function(button) Addon:RemoveBuff(button:GetParent().index) end)
            self.rows[index] = row
        end
        local name, icon = Addon:GetEntry(index)
        row.index = index
        row.ooc:SetChecked(Addon:GetWatch(index, "ooc"))
        row.combat:SetChecked(Addon:GetWatch(index, "combat"))
        row.name:SetText(name or "Unknown buff")
        row.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", self.content, "TOPLEFT", 0, -(index - 1) * 31)
        row:Show()
    end
    for index = #monitored + 1, #self.rows do self.rows[index]:Hide() end
    self.content:SetHeight(math.max(188, #monitored * 31))
end

local function Build(category, layout)
    Addon.category = category
    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Reminders"))
    local enabled = Proxy(category, "enabled", "Enable reminders", true,
        function() local db = Addon:GetConfig(); return db and db.enabled end,
        function(value) Addon:SetEnabled(value) end)
    local enabledRow = Settings.CreateCheckbox(category, enabled,
        "Show reminders for missing selected buffs. Saved for all characters of this class.")
    local unlocked = Proxy(category, "unlocked", "Unlock and preview", false,
        function() local db = Addon:GetConfig(); return db and not db.locked end,
        function(value) SlashCmdList.LH_BUFFREMINDERS(value and "unlock" or "lock") end)
    local unlockRow = Settings.CreateCheckbox(category, unlocked,
        "Show a draggable preview icon. Position is shared by all characters of this class.")
    unlockRow:SetParentInitializer(enabledRow)
    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Buffs for " .. (select(1, UnitClass("player")) or "your class")))
    layout:AddInitializer(Settings.CreatePanelInitializer("LHBuffRemindersBuffListTemplate", {name = "Monitored buffs"}))
end

LH_Tweaks:RegisterModule(addonName, "LH BuffReminders", Build)

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
    note:SetText("Enter a learned buff name/ID or choose from the list.")
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
    edit:SetSize(267, 25)
    edit:SetPoint("TOPLEFT", scroll, "BOTTOMLEFT", 8, -12)
    edit:SetAutoFocus(false)
    edit:SetMaxLetters(120)
    self.edit = edit
    local choose = CreateFrame("Button", nil, self, "UIPanelButtonTemplate")
    choose:SetSize(35, 25)
    choose:SetPoint("LEFT", edit, "RIGHT", 8, 0)
    choose:SetText("v")
    self.choose = choose
    choose:SetScript("OnEnter", function(button)
        GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
        GameTooltip:SetText("Choose a learned class buff.", 1, 1, 1, 1, true)
    end)
    choose:SetScript("OnLeave", function() GameTooltip:Hide() end)
    local add = CreateFrame("Button", nil, self, "UIPanelButtonTemplate")
    add:SetSize(45, 25)
    add:SetPoint("LEFT", choose, "RIGHT", 8, 0)
    add:SetText("+")
    self.add = add
    self.message = self:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    self.message:SetPoint("TOPLEFT", edit, "BOTTOMLEFT", -3, -7)
    self.message:SetWidth(415)
    self.message:SetJustifyH("LEFT")
    local choices = CreateFrame("Frame", nil, self, "BackdropTemplate")
    choices:SetSize(315, 188)
    choices:SetPoint("BOTTOMLEFT", edit, "TOPLEFT", -4, 3)
    choices:SetFrameStrata("DIALOG")
    choices:SetClampedToScreen(true)
    if choices.SetBackdrop then
        choices:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 16,
            insets = {left = 4, right = 4, top = 4, bottom = 4},
        })
        choices:SetBackdropColor(0, 0, 0, 0.95)
    end
    local choiceScroll = CreateFrame("ScrollFrame", nil, choices, "UIPanelScrollFrameTemplate")
    choiceScroll:SetPoint("TOPLEFT", 6, -6)
    choiceScroll:SetPoint("BOTTOMRIGHT", -26, 6)
    local choiceContent = CreateFrame("Frame", nil, choiceScroll)
    choiceContent:SetSize(280, 1)
    choiceScroll:SetScrollChild(choiceContent)
    self.choices, self.choiceContent, self.choiceRows = choices, choiceContent, {}
    choices:Hide()

    choose:SetScript("OnClick", function()
        if choices:IsShown() then choices:Hide(); return end
        local available = Addon:GetAvailableBuffs()
        if #available == 0 then
            self.message:SetText("No unmonitored learned class buffs are available.")
            return
        end
        self.message:SetText("")
        for index, option in ipairs(available) do
            local row = self.choiceRows[index]
            if not row then
                row = CreateFrame("Button", nil, choiceContent)
                row:SetSize(278, 27)
                row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
                row.icon = row:CreateTexture(nil, "ARTWORK")
                row.icon:SetSize(20, 20)
                row.icon:SetPoint("LEFT", 4, 0)
                row.name = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
                row.name:SetPoint("LEFT", row.icon, "RIGHT", 7, 0)
                row.name:SetWidth(245)
                row.name:SetJustifyH("LEFT")
                self.choiceRows[index] = row
            end
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", choiceContent, "TOPLEFT", 0, -(index - 1) * 27)
            row.icon:SetTexture(option.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
            row.name:SetText(option.name)
            row:SetScript("OnClick", function()
                edit:SetText(option.name)
                choices:Hide()
            end)
            row:Show()
        end
        for index = #available + 1, #self.choiceRows do self.choiceRows[index]:Hide() end
        choiceContent:SetHeight(#available * 27)
        choices:SetHeight(math.min(188, #available * 27 + 12))
        choiceScroll:SetVerticalScroll(0)
        choices:Show()
    end)
    local function AddBuff()
        local ok, message = Addon:AddBuff(edit:GetText())
        if ok then edit:SetText(""); edit:ClearFocus(); self.message:SetText(""); choices:Hide()
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
    if self.choices then self.choices:Hide() end
end

function LHBuffRemindersBuffListMixin:OnShow()
    if self.choices then self.choices:Hide() end
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
    LH_LayoutProfiles:AddSetting(category, layout, addonName)
    Addon.category = category
    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Positioning"))
    local locked = Proxy(category, "locked", "Lock reminder icon", true,
        function() local db = Addon:GetConfig(); return not db or db.locked ~= false end,
        function(value) SlashCmdList.LH_BUFFREMINDERS(value and "lock" or "unlock") end)
    Settings.CreateCheckbox(category, locked,
        "Disable to show and drag the preview icon. Position and lock state can follow a settings source.")

    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Reminders"))
    local enabled = Proxy(category, "enabled", "Enable reminders", true,
        function() local db = Addon:GetConfig(); return db and db.enabled end,
        function(value) Addon:SetEnabled(value) end)
    Settings.CreateCheckbox(category, enabled,
        "Show reminders for missing selected buffs. This switch is saved for this character.")
    local food = Proxy(category, "foodEnabled", "Remind me to eat buff food", false,
        function() local db = Addon:GetConfig(); return db and db.foodEnabled == true end,
        function(value) Addon:SetFoodEnabled(value) end)
    Settings.CreateCheckbox(category, food,
        "Show the Cooking icon when no Well Fed food buff is active. Saved for this character.")
    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Buffs for " .. (select(1, UnitClass("player")) or "your class")))
    layout:AddInitializer(Settings.CreatePanelInitializer("LHBuffRemindersBuffListTemplate", {name = "Monitored buffs"}))
end

LH_Tweaks:RegisterModule(addonName, "LH BuffReminders", Build)

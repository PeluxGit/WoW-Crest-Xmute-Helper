-- ui/action_button.lua
-- Single secure button that always fires the CrestX-Open macro
local ADDON_NAME, Addon = ...

local MACRO_NAME = "CrestX-Open"
local UI = Addon.UI or {}

local function HideDefaultHighlights(button)
    if button.NewActionTexture then
        button.NewActionTexture:SetAlpha(0)
        button.NewActionTexture:Hide()
    end
    if button.SpellHighlightTexture then
        button.SpellHighlightTexture:SetAlpha(0)
        button.SpellHighlightTexture:Hide()
    end
    if button.HighlightTexture then
        button.HighlightTexture:SetAlpha(0)
        button.HighlightTexture:Hide()
    end
    if button.SpellHighlightAnim then
        button.SpellHighlightAnim:Stop()
    end
    if button.Flash then
        button.Flash:Hide()
    end
end

local function ApplyMacro(button)
    if not button or InCombatLockdown() then
        return
    end

    local macroIndex = GetMacroIndexByName(MACRO_NAME)
    if macroIndex and macroIndex > 0 then
        local name, icon = GetMacroInfo(macroIndex)
        button.macroIndex = macroIndex
        button.macroName = name
        button:SetAttribute("type", "macro")
        button:SetAttribute("macro", name)

        if icon and button.icon then
            button.icon:SetTexture(icon)
            button.icon:Show()
        end
        if button.NormalTexture then
            button.NormalTexture:Show()
        end
        if button.SlotBackground then
            button.SlotBackground:Hide()
        end
    else
        button.macroIndex = nil
        button.macroName = nil
        button:SetAttribute("type", nil)
        button:SetAttribute("macro", nil)
        if button.icon then
            button.icon:SetTexture(nil)
            button.icon:Hide()
        end
        if button.NormalTexture then
            button.NormalTexture:Hide()
        end
        if button.SlotBackground then
            button.SlotBackground:Show()
        end
    end

    HideDefaultHighlights(button)
end

---Create the macro action button
function Addon:CreateMacroActionButton(parent)
    local anchorParent = parent or UIParent

    local button = CreateFrame("CheckButton", "CrestXmuteMacroActionButton", anchorParent,
        "ActionButtonTemplate, SecureActionButtonTemplate")
    if UI.SetScaledSize then
        UI.SetScaledSize(button, UI.ACTIONBUTTON_SCALE)
    end
    button:ClearAllPoints()
    button:SetPoint("TOPLEFT", anchorParent, "TOPRIGHT", 0, 0)
    button:SetFrameStrata("HIGH")
    button:RegisterForClicks("AnyUp", "AnyDown")
    button:EnableMouse(true)
    button:SetAttribute("checkselfcast", true)
    button:SetAttribute("checkfocuscast", true)
    button:SetAttribute("checkmouseovercast", true)
    button:SetAttribute("pressAndHoldAction", true)
    button:SetHitRectInsets(0, 0, 0, 0)

    button:UnregisterAllEvents()
    button:SetScript("OnEvent", nil)
    button:SetScript("OnUpdate", nil)

    button.icon = button.icon or _G[button:GetName() .. "Icon"]
    button.NormalTexture = button.NormalTexture or _G[button:GetName() .. "NormalTexture"]
    button.SlotBackground = button.SlotBackground or _G[button:GetName() .. "SlotBackground"]
    HideDefaultHighlights(button)

    local highlightTex = button:GetHighlightTexture()
    if highlightTex then
        highlightTex:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
        highlightTex:SetBlendMode("ADD")
        highlightTex:SetAllPoints(button) -- shrink to match button size
    end

    local pushedTex = button:GetPushedTexture()
    if pushedTex then
        pushedTex:SetTexture("Interface\\Buttons\\UI-Quickslot-Depress")
        pushedTex:SetAllPoints(button)
    end

    local checkedTex = button:GetCheckedTexture()
    if checkedTex then
        checkedTex:SetTexture("Interface\\Buttons\\CheckButtonHilight")
        checkedTex:SetBlendMode("ADD")
        checkedTex:SetAlpha(0.25)
        checkedTex:SetAllPoints(button)
    end

    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if self.macroIndex then
            local name = self.macroName or MACRO_NAME
            GameTooltip:SetText(name, 1, 1, 1)
            GameTooltip:AddLine("Click or keybind to run the CrestX-Open macro.", 0.7, 0.7, 0.7, true)
        else
            GameTooltip:SetText("CrestX-Open Macro", 1, 1, 1)
            GameTooltip:AddLine("Create the macro via a Crest Xmute vendor to enable this button.", 0.7, 0.7, 0.7, true)
        end
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    button:SetScript("OnEvent", function(self, event)
        if event == "PLAYER_ENTERING_WORLD" or event == "UPDATE_MACROS" then
            ApplyMacro(self)
        end
    end)

    button:SetScript("PreClick", function()
        if InCombatLockdown() then
            return
        end
        local macroIndex = GetMacroIndexByName(MACRO_NAME)
        if macroIndex and macroIndex > 0 then
            button:SetAttribute("type", "macro")
            button:SetAttribute("macro", MACRO_NAME)
        else
            button:SetAttribute("type", nil)
            button:SetAttribute("macro", nil)
            UIErrorsFrame:AddMessage("|cffff6600CrestXmute: Macro 'CrestX-Open' not found.|r")
        end
    end)
    button:RegisterEvent("PLAYER_ENTERING_WORLD")
    button:RegisterEvent("UPDATE_MACROS")

    ApplyMacro(button)
    self.MacroActionButton = button
    return button
end

function Addon:ShowMacroActionButton()
    if self.MacroActionButton then
        self.MacroActionButton:Show()
    end
end

function Addon:HideMacroActionButton()
    if self.MacroActionButton then
        self.MacroActionButton:Hide()
    end
end

local ADDON_NAME, Addon = ...

Addon.UI                = Addon.UI or {}
local UI                = Addon.UI

-- Layout defaults
UI.CONTENT_PAD          = UI.CONTENT_PAD or 8
UI.LEFT_PAD             = UI.LEFT_PAD or 10
UI.ICON_W               = UI.ICON_W or 24
UI.ICON_PAD             = UI.ICON_PAD or 8
UI.NAME_COL_W           = UI.NAME_COL_W or 236
UI.ROW_H                = UI.ROW_H or 32
UI.MAX_H                = UI.MAX_H or 560
UI.COL_W                = UI.COL_W or 22
UI.COL_SP               = UI.COL_SP or 12

local function MakeMovable(frame)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame._moving = false
    frame:SetScript("OnMouseDown", function(self, btn)
        if btn ~= "LeftButton" then return end
        if not self.Scroll then
            self:StartMoving(); self._moving = true; return
        end
        local x, y = GetCursorPosition()
        local s = self:GetEffectiveScale()
        x, y = x / s, y / s
        local l = self.Scroll:GetLeft() or 0
        local r = self.Scroll:GetRight() or 0
        local b = self.Scroll:GetBottom() or 0
        local t = self.Scroll:GetTop() or 0
        local inScroll = (x >= l and x <= r and y >= b and y <= t)
        if not inScroll then
            self:StartMoving(); self._moving = true
        end
    end)
    frame:SetScript("OnMouseUp", function(self)
        if not self._moving then return end
        self:StopMovingOrSizing(); self._moving = false
        local p, rel, rp, x, y = self:GetPoint(1)
        CrestXmuteDB = CrestXmuteDB or {}
        CrestXmuteDB.framePos = { p, rel and rel:GetName() or "MerchantFrame", rp, x, y }
    end)
end

local function ApplySavedPosition(f)
    local pos = CrestXmuteDB and CrestXmuteDB.framePos
    if not pos or not pos[1] then return false end
    local rel = pos[2] and _G[pos[2]] or MerchantFrame or UIParent
    f:ClearAllPoints()
    f:SetPoint(pos[1], rel, pos[3], pos[4], pos[5])
    return true
end

local function DockOutsideMerchant(f)
    f:ClearAllPoints()
    if MerchantFrame and MerchantFrame:IsShown() then
        f:SetPoint("LEFT", MerchantFrame, "RIGHT", 8, 0)
    else
        f:SetPoint("CENTER", UIParent, "CENTER")
    end
end

-- merchant hooks for Add Mode
local function GetMerchantItemButton(i) return _G["MerchantItem" .. i .. "ItemButton"] end

function Addon:_HookMerchantButtonsForAddMode()
    if self._merchantHooks then return end
    self._merchantHooks = {}
    for i = 1, 12 do
        local btn = GetMerchantItemButton(i)
        if btn then
            local orig = btn:GetScript("OnClick")
            self._merchantHooks[i] = orig
            btn:SetScript("OnClick", function(b, mouseButton)
                if not self._addMode then
                    if orig then orig(b, mouseButton) end
                    return
                end
                local idx    = b:GetID()
                local link   = GetMerchantItemLink(idx)
                local itemID = link and select(1, GetItemInfoInstant(link)) or nil
                if itemID and self.AddTracked and self:AddTracked(itemID) then
                    local name = GetItemInfo(itemID) or ("item:" .. itemID)
                    UIErrorsFrame:AddMessage("|cff33ff99CrestXmute: Added|r " .. name)
                    if self.TrackedChanged then self:TrackedChanged() end
                    if self.Container and self.Container:IsShown() and self.RefreshList then
                        self:RefreshList()
                    end
                else
                    UIErrorsFrame:AddMessage("|cffff6600CrestXmute: Offer has no item (currency-only).|r")
                end
            end)
        end
    end
    if MerchantFrame and not self._merchantHideHooked then
        self._merchantHideHooked = true
        MerchantFrame:HookScript("OnHide", function()
            if Addon._addMode then Addon:SetAddMode(false) end
            Addon:HideUI()
        end)
    end
end

function Addon:_UnhookMerchantButtonsForAddMode()
    if not self._merchantHooks then return end
    for i = 1, 12 do
        local btn = GetMerchantItemButton(i)
        if btn then btn:SetScript("OnClick", self._merchantHooks[i]) end
    end
    self._merchantHooks = nil
end

function Addon:SetAddMode(flag)
    flag = not not flag
    self._addMode = flag
    if self.Container and self.Container.AddModeBtn then
        self.Container.AddModeBtn:SetChecked(flag)
        self.Container.AddModeBtn.Label:SetText(flag and "Add Mode: ON" or "Add Mode: OFF")
    end
    if flag then self:_HookMerchantButtonsForAddMode() else self:_UnhookMerchantButtonsForAddMode() end
end

function Addon:UpdateClickerMacroText(body)
    if not self.Container or not self.Container.Clicker or InCombatLockdown() then return end
    self.Container.Clicker:SetAttribute("type", "macro")
    self.Container.Clicker:SetAttribute("macrotext", body or "")
end

function Addon:EnsureUI()
    if self.Container then return end

    local baseW = UI.CONTENT_PAD + UI.LEFT_PAD + UI.ICON_W + UI.ICON_PAD + UI.NAME_COL_W
        + 24 + (UI.COL_W * 3) + (UI.COL_SP * 2) + 32 + UI.CONTENT_PAD + 12
    local container = CreateFrame("Frame", "CrestXmutePanel", UIParent, "InsetFrameTemplate3")
    container:SetSize(baseW, 340)
    container:SetFrameStrata("HIGH")
    container:SetClampedToScreen(true)
    MakeMovable(container)

    local bg = container:CreateTexture(nil, "BACKGROUND", nil, -7)
    bg:SetColorTexture(0, 0, 0, 0.42)
    bg:SetPoint("TOPLEFT", 3, -3)
    bg:SetPoint("BOTTOMRIGHT", -3, 3)

    if not ApplySavedPosition(container) then DockOutsideMerchant(container) end

    local title = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 10, -8)
    title:SetText("Crest Xmute Helper")

    local addMode = CreateFrame("CheckButton", nil, container, "UICheckButtonTemplate")
    addMode:SetPoint("TOPRIGHT", -10, -6)
    addMode:SetScale(0.9)
    addMode:SetScript("OnClick", function(self) Addon:SetAddMode(self:GetChecked()) end)
    local lbl = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lbl:SetPoint("RIGHT", addMode, "LEFT", -4, 0)
    lbl:SetText("Add Mode: OFF")
    addMode.Label = lbl
    container.AddModeBtn = addMode

    local scroll = CreateFrame("ScrollFrame", "CrestXmuteScroll", container, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 8, -52)
    scroll:SetPoint("BOTTOMRIGHT", -28, 40)
    scroll:EnableMouse(true)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(1, 1)
    scroll:SetScrollChild(content)

    container.Scroll   = scroll
    container.Content  = content
    container.HeadersY = 52

    local nameStartX   = UI.CONTENT_PAD + UI.LEFT_PAD + UI.ICON_W + UI.ICON_PAD
    local buyX         = nameStartX + UI.NAME_COL_W + 28
    local openX        = buyX + UI.COL_W + UI.COL_SP
    local confX        = openX + UI.COL_W + UI.COL_SP
    container._colsX   = { buyX, openX, confX }

    local function placeHeader(fs, x)
        fs:SetWidth(UI.COL_W); fs:SetJustifyH("CENTER")
        fs:ClearAllPoints()
        fs:SetPoint("TOPLEFT", container, "TOPLEFT", 8 + (x - UI.CONTENT_PAD), -32)
    end
    local hdrBuy = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); hdrBuy:SetText("Buy"); placeHeader(
        hdrBuy, buyX)
    local hdrOpen = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); hdrOpen:SetText("Open"); placeHeader(
        hdrOpen, openX)
    local hdrConf = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); hdrConf:SetText("Conf"); placeHeader(
        hdrConf, confX)

    local head = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    head:SetPoint("TOPLEFT", 10, -32)
    head:SetText("Vendor Items")

    local empty = container:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    empty:SetPoint("TOPLEFT", 16, -70)
    empty:SetWidth(360); empty:SetJustifyH("LEFT")
    empty:SetText("No tracked items found on this vendor.\nUse /crestx add <linkOrID> or enable Add Mode.")
    container.EmptyState = empty; empty:Hide()

    local clicker = CreateFrame("Button", "CrestXmuteClicker", container,
        "SecureActionButtonTemplate, UIPanelButtonTemplate")
    clicker:SetSize(140, 22)
    clicker:SetPoint("BOTTOMRIGHT", -10, 12)
    clicker:SetText("Buy + Open")
    clicker:RegisterForDrag("LeftButton")
    clicker:SetScript("OnDragStart", function(self)
        if InCombatLockdown() then return end
        local idx = GetMacroIndexByName("CrestX-Open")
        if idx and idx > 0 then PickupMacro(idx) end
    end)
    container.Clicker = clicker

    self.Container = container
end

function Addon:ShowUIForMerchant()
    self:EnsureUI()
    if not (CrestXmuteDB and CrestXmuteDB.framePos) then DockOutsideMerchant(self.Container) end
    self.Container:Show()
    self:RefreshList()
    -- one more refresh shortly after to catch icons/names resolving
    C_Timer.After(0.06, function() if self.Container and self.Container:IsShown() then self:RefreshList() end end)
end

function Addon:HideUI()
    if self.Container then self.Container:Hide() end
end

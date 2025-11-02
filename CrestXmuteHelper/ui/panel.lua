-- ui/panel.lua
-- Builds the main UI container, headers, and Add Mode; handles window positioning and visibility
local ADDON_NAME, Addon = ...

Addon.UI                = Addon.UI or {}
local UI                = Addon.UI

-- Calculate column positions from left edge using constants (simpler, no dynamic recalc needed)
-- Stores both left edges and centers in the container for use by list rows
local function ComputeColumns(container)
    -- InsetFrameTemplate3 has ~50px left inset; account for it
    local frameInset = container._insetLeft or 0

    -- Start from the left: frame inset + content padding + icon/name section
    local afterName = frameInset + UI.CONTENT_PAD + UI.LEFT_PAD + UI.ICON_W + UI.ICON_PAD + UI.NAME_COL_W

    -- Column left edges, spaced from the name
    local buyX = afterName + UI.COL_SP
    local openX = buyX + UI.COL_W + UI.COL_SP
    local confX = openX + UI.COL_W + UI.COL_SP
    local removeX = confX + UI.COL_W + UI.REMOVE_PAD

    -- Store left edges and centers (from container's left edge including inset)
    container._colsX = { buyX, openX, confX, removeX }
    container._colCenters = {
        buyX + UI.COL_W / 2,
        openX + UI.COL_W / 2,
        confX + UI.COL_W / 2,
        removeX + UI.COL_W / 2,
    }

    -- DEBUG: Log header calculation
    Addon:DebugPrint("[HEADER] frameInset=%d, CONTENT_PAD=%d, LEFT_PAD=%d, ICON_W=%d, ICON_PAD=%d, NAME_COL_W=%d",
        frameInset, UI.CONTENT_PAD, UI.LEFT_PAD, UI.ICON_W, UI.ICON_PAD, UI.NAME_COL_W)
    Addon:DebugPrint("[HEADER] afterName=%d, COL_SP=%d, COL_W=%d, REMOVE_PAD=%d",
        afterName, UI.COL_SP, UI.COL_W, UI.REMOVE_PAD)
    Addon:DebugPrint("[HEADER] colsX: buy=%d, open=%d, conf=%d, remove=%d",
        buyX, openX, confX, removeX)
    Addon:DebugPrint("[HEADER] colCenters: buy=%d, open=%d, conf=%d, remove=%d",
        container._colCenters[1], container._colCenters[2],
        container._colCenters[3], container._colCenters[4])
end

-- Make the container movable without stealing drags from the scroll area
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
        -- Save relative frame name, fallback to "UIParent" if no name
        local relName = "UIParent"
        if rel then
            relName = rel:GetName() or "UIParent"
        end
        CrestXmuteDB.framePos = { p, relName, rp, x, y }
        Addon:DebugPrint("[SavePosition] Saved position: %s, %s, %s, %.1f, %.1f", p or "?", relName, rp or "?", x or 0,
            y or 0)
    end)
end

-- Restore a previously saved position, returns true if applied
local function ApplySavedPosition(f)
    local pos = CrestXmuteDB and CrestXmuteDB.framePos
    if not pos or not pos[1] then
        Addon:DebugPrint("[LoadPosition] No saved position found")
        return false
    end

    -- Try to get the relative frame by name, fallback to UIParent
    local relName = pos[2] or "UIParent"
    local rel = _G[relName]
    if not rel then
        Addon:DebugPrint("[LoadPosition] Relative frame '%s' not found, using UIParent", relName)
        rel = UIParent
    end

    f:ClearAllPoints()
    f:SetPoint(pos[1], rel, pos[3], pos[4], pos[5])
    Addon:DebugPrint("[LoadPosition] Restored position: %s, %s, %s, %.1f, %.1f", pos[1], relName, pos[3], pos[4], pos[5])
    return true
end

-- Default docking to the right of MerchantFrame if visible, else center on UIParent
local function DockOutsideMerchant(f)
    f:ClearAllPoints()
    if MerchantFrame and MerchantFrame:IsShown() then
        f:SetPoint("LEFT", MerchantFrame, "RIGHT", 8, 0)
    else
        f:SetPoint("CENTER", UIParent, "CENTER")
    end
end

-- Add Mode: hook merchant item buttons to add items to tracking on click
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
                    UIErrorsFrame:AddMessage("|cffff6600CrestXmute: Could not add that item.|r")
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

function Addon:EnsureUI()
    if self.Container then return end

    -- Calculate total width based on layout constants.
    -- Use a fixed column section X (from layout) plus column widths so the
    -- name column can flex to fill the remaining left space.
    local columnsWidth = (UI.COL_W * 3) + (UI.COL_SP * 2) + UI.REMOVE_PAD + UI.COL_W
    local baseW = (UI.COL_SECTION_X or 300) + columnsWidth + UI.CONTENT_PAD

    local container = CreateFrame("Frame", "CrestXmutePanel", UIParent, "InsetFrameTemplate3")
    container:SetSize(baseW, 340)
    container:SetFrameStrata("HIGH")
    container:SetClampedToScreen(true)
    MakeMovable(container)

    -- InsetFrameTemplate3 has built-in insets - get them for proper positioning
    local insets = container.Inset or container
    local insetLeft, insetRight, insetTop, insetBottom = 0, 0, 0, 0
    if insets.GetBackdrop then
        local backdrop = insets:GetBackdrop()
        if backdrop and backdrop.insets then
            insetLeft = backdrop.insets.left or 0
            insetTop = backdrop.insets.top or 0
        end
    end
    -- Store inset for use in positioning calculations
    container._insetLeft = insetLeft
    container._insetTop = insetTop

    local bg = container:CreateTexture(nil, "BACKGROUND", nil, -7)
    bg:SetColorTexture(0, 0, 0, 0.46)
    bg:SetPoint("TOPLEFT", 3, -3)
    bg:SetPoint("BOTTOMRIGHT", -3, 3)

    if not ApplySavedPosition(container) then
        DockOutsideMerchant(container)
    end

    local title = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 10, -8)
    title:SetText("Crest Xmute Helper")

    -- Create a button that picks up the macro when clicked
    local macroBtn = CreateFrame("Button", nil, container)
    macroBtn:SetSize(36, 36)
    macroBtn:SetPoint("TOPRIGHT", container, "TOPRIGHT", -10, -6)
    macroBtn:SetNormalTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    macroBtn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    macroBtn:SetScript("OnClick", function()
        local macroIndex = GetMacroIndexByName("CrestX-Open")
        if macroIndex and macroIndex > 0 then
            PickupMacro(macroIndex)
        else
            UIErrorsFrame:AddMessage(
                "|cffff6600CrestXmute: Macro 'CrestX-Open' not found. Visit a merchant to create it.|r")
        end
    end)
    macroBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("CrestX-Open Macro", 1, 1, 1)
        GameTooltip:AddLine("Click to pick up the macro, then drag it to your action bar.", nil, nil, nil, true)
        GameTooltip:Show()
    end)
    macroBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    container.MacroBtn = macroBtn

    local addMode = CreateFrame("CheckButton", nil, container, "UICheckButtonTemplate")
    addMode:SetScale(0.9)
    addMode:SetPoint("RIGHT", macroBtn, "LEFT", -8, 0)
    addMode:SetScript("OnClick", function(self) Addon:SetAddMode(self:GetChecked()) end)
    local lbl = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lbl:SetPoint("RIGHT", addMode, "LEFT", -4, 0)
    lbl:SetText("Add Mode: OFF")
    addMode.Label = lbl
    container.AddModeBtn = addMode

    -- Scroll area now uses almost all available vertical space (button moved to title row).
    local scroll = CreateFrame("ScrollFrame", "CrestXmuteScroll", container, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 8, -52)
    scroll:SetPoint("BOTTOMRIGHT", -28, 14)
    scroll:EnableMouse(true)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(1, 1)
    scroll:SetScrollChild(content)

    container.Scroll   = scroll
    container.Content  = content
    container.HeadersY = 52

    -- Compute columns now (fixed layout, no need to recalc on resize)
    ComputeColumns(container)
    container:SetScript("OnSizeChanged", function(self)
        -- Future: re-enable if panel becomes resizable
        -- ComputeColumns(self)
        if Addon.RefreshList then Addon:RefreshList() end
    end)

    -- Column headers placed at absolute X positions from ComputeColumns
    local function placeHeader(fs, absX, name)
        fs:SetWidth(UI.COL_W)
        fs:SetJustifyH("CENTER")
        fs:ClearAllPoints()
        fs:SetPoint("TOPLEFT", container, "TOPLEFT", absX, -32)

        -- DEBUG: Log header placement AND actual measured positions
        if Addon and Addon.IsDebug and Addon:IsDebug() then
            C_Timer.After(0.02, function()
                if fs.GetCenter and fs.GetLeft then
                    local centerX = fs:GetCenter()
                    local leftX = fs:GetLeft()
                    local containerLeft = container and container.GetLeft and container:GetLeft() or 0
                    local uiScale = container:GetEffectiveScale()
                    local screenCenterX = centerX * uiScale
                    Addon:DebugPrint(
                        "[HEADER] %s: absX=%d, width=%d, actualCenter=%.1f, actualLeft=%.1f, containerLeft=%.1f, uiScale=%.2f, screenX=%.1f",
                        name or "?", absX, UI.COL_W, centerX or -1, leftX or -1, containerLeft, uiScale, screenCenterX)
                end
            end)
        end
    end

    -- Create and position column headers
    local hdrBuy = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    local hdrOpen = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    local hdrConf = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")

    hdrBuy:SetText("Buy")
    hdrOpen:SetText("Open")
    hdrConf:SetText("Confirm")

    placeHeader(hdrBuy, container._colsX[1], "Buy")
    placeHeader(hdrOpen, container._colsX[2], "Open")
    placeHeader(hdrConf, container._colsX[3], "Confirm")

    -- Store header references so we can measure their actual positions later
    container._hdrBuy = hdrBuy
    container._hdrOpen = hdrOpen
    container._hdrConf = hdrConf

    -- Main header at the left
    local head = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    head:SetPoint("TOPLEFT", UI.LEFT_PAD, -32)
    head:SetText("Vendor Items")

    local empty = container:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    empty:SetPoint("TOPLEFT", 16, -70)
    empty:SetWidth(360); empty:SetJustifyH("LEFT")
    empty:SetText("No tracked items found on this vendor.\nUse /cxh add <linkOrID> or enable Add Mode.")
    container.EmptyState = empty; empty:Hide()

    -- Color legend at the bottom
    local legend = CreateFrame("Frame", nil, container)
    legend:SetPoint("BOTTOMLEFT", 8, 4)
    legend:SetPoint("BOTTOMRIGHT", -8, 4)
    legend:SetHeight(16)

    local function makeLegendItem(parent, prevItem, color, text)
        local item = CreateFrame("Frame", nil, parent)
        item:SetSize(12, 12)
        if prevItem then
            item:SetPoint("LEFT", prevItem, "RIGHT", 8, 0)
        else
            item:SetPoint("LEFT", 0, 0)
        end

        local box = item:CreateTexture(nil, "BACKGROUND")
        box:SetAllPoints()
        box:SetColorTexture(color[1], color[2], color[3], color[4])

        local label = item:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        label:SetPoint("LEFT", item, "RIGHT", 4, 0)
        label:SetText(text)
        label:SetTextColor(0.8, 0.8, 0.8)

        return item
    end

    local buy = makeLegendItem(legend, nil, { 0.2, 0.4, 0.8, 0.15 }, "Will Buy")
    local use = makeLegendItem(legend, buy, { 0.8, 0.6, 0.2, 0.15 }, "Will Open")
    local both = makeLegendItem(legend, use, { 0.5, 0.7, 0.6, 0.20 }, "Both")

    container.Legend = legend

    self.Container = container
end

function Addon:ShowUIForMerchant()
    self:EnsureUI()
    if not (CrestXmuteDB and CrestXmuteDB.framePos) then
        DockOutsideMerchant(self.Container)
    end
    self.Container:Show()
    -- Columns already computed in EnsureUI; no need to recalc for fixed-width panel
    if self.RefreshList then
        -- Wait a frame to ensure merchant data is loaded
        C_Timer.After(0.03, function()
            if self.Container and self.Container:IsShown() then
                if self.RefreshList then
                    self:RefreshList()
                end
                -- Sync macro when first showing UI so it reflects current merchant state
                if self.SyncOpenMacro then
                    self:SyncOpenMacro(true)
                end
            end
        end)
    end
end

function Addon:HideUI()
    if self.Container then self.Container:Hide() end
end

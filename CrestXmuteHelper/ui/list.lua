-- ui/list.lua
-- Renders tracked item rows with icons, toggles, and controls; handles scroll layout and row interactions
local ADDON_NAME, Addon = ...

Addon.UI                = Addon.UI or {}
local UI                = Addon.UI

-- Bind item tooltip to widget on hover (local helper, only used in this file)
local function BindItemTooltip(widget, itemID)
    widget:EnableMouse(true)
    widget:SetScript("OnEnter", function(self)
        if not itemID then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetItemByID(itemID)
        GameTooltip:Show()
    end)
    widget:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-- Pick the top candidate per currency key (highest priority + affordable + buy enabled)
-- Used to highlight which items will actually be purchased by the macro
local function ComputeTopCandidatesByGroup()
    local entries = Addon:CollectTrackedMerchantEntries_All()
    local groupsByKey = {}
    for _, entry in ipairs(entries) do
        local costKey = "misc"
        if Addon.GetPrimaryCostKey then
            costKey = Addon:GetPrimaryCostKey(entry.idx) or "misc"
        end
        groupsByKey[costKey] = groupsByKey[costKey] or {}
        table.insert(groupsByKey[costKey], entry)
    end
    local winners = {}
    for costKey, rows in pairs(groupsByKey) do
        table.sort(rows, function(a, b)
            local rankA = Addon.GetRank and Addon:GetRank(a.itemID) or 9999
            local rankB = Addon.GetRank and Addon:GetRank(b.itemID) or 9999
            if rankA ~= rankB then return rankA < rankB end
            return a.idx < b.idx
        end)
        for _, entry in ipairs(rows) do
            local toggles = Addon:GetItemToggles(entry.itemID)
            if toggles.buy and entry.affordable then
                winners[entry.itemID] = true
                break
            end
        end
    end
    return winners
end

-- Build a flat list of header+row nodes grouped by currency/item cost
local function BuildGroupedEntries()
    local entries = Addon:CollectTrackedMerchantEntries_All()
    local groups = {}
    for _, entry in ipairs(entries) do
        local costKey = "misc"
        if Addon.GetPrimaryCostKey then
            costKey = Addon:GetPrimaryCostKey(entry.idx) or "misc"
        end
        groups[costKey] = groups[costKey] or { header = costKey, rows = {} }
        table.insert(groups[costKey].rows, entry)
    end
    for _, group in pairs(groups) do
        table.sort(group.rows, function(a, b)
            local rankA = Addon.GetRank and Addon:GetRank(a.itemID) or 9999
            local rankB = Addon.GetRank and Addon:GetRank(b.itemID) or 9999
            if rankA ~= rankB then return rankA < rankB end
            return a.idx < b.idx
        end)
    end
    local orderedKeys, flatList = {}, {}
    for key in pairs(groups) do
        orderedKeys[#orderedKeys + 1] = key
    end
    table.sort(orderedKeys)
    for _, key in ipairs(orderedKeys) do
        flatList[#flatList + 1] = { kind = "header", key = key }
        for _, row in ipairs(groups[key].rows) do
            flatList[#flatList + 1] = { kind = "row", data = row }
        end
    end
    return flatList
end

-- Clear all entries from a table (reuses the table reference instead of creating a new one)
local function Wipe(t) for k in pairs(t) do t[k] = nil end end

function Addon:TrackedChanged()
    if self.Container and self.Container:IsShown() then
        if self.RefreshList then self:RefreshList() end
        if self.SyncOpenMacro then self:SyncOpenMacro(true) end
    end
end

function Addon:RefreshList()
    if not self.Container or not self.Container:IsVisible() then return end
    local container, content, scroll = self.Container, self.Container.Content, self.Container.Scroll

    -- (width handled after scrollbar visibility is determined)

    content.cells                    = content.cells or {}
    for _, f in ipairs(content.cells) do if f.Hide then f:Hide() end end
    Wipe(content.cells)

    local flat = BuildGroupedEntries()
    local y = 0
    local rows = {}
    local candidateSet = ComputeTopCandidatesByGroup()
    local rowDebugCount = 0 -- Counter for debug logging

    -- Get the item that will actually be purchased (the top affordable with buy enabled)
    local nextPurchaseID = Addon:GetTopAffordableSingle()

    -- Get the next item that will be used (first item in bags with Open enabled)
    local nextUseID = nil
    if Addon.CollectTrackedIDsInBags then
        local openIDs = Addon:CollectTrackedIDsInBags(1) -- Only need the first one
        if openIDs and #openIDs > 0 then
            local tog = Addon:GetItemToggles(openIDs[1])
            if tog and tog.open then
                nextUseID = openIDs[1]
            end
        end
    end
    if Addon.DEBUG then
        print("[DEBUG] nextPurchaseID:", nextPurchaseID, "nextUseID:", nextUseID)
    end

    local function makeRow(parent, yTop)
        rowDebugCount = rowDebugCount + 1
        -- Rows anchor to both edges of content and follow its width (content width accounts for scrollbar reserve)
        local f = CreateFrame("Frame", nil, parent)
        f:SetHeight(UI.ROW_H)
        f:SetPoint("TOPLEFT", 0, -yTop)
        f:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, -yTop)
        f:SetMovable(true); f:SetClampedToScreen(true); f:EnableMouse(true)

        -- Background highlight texture (for next-purchase/use indicator)
        f.highlight = f:CreateTexture(nil, "BACKGROUND")
        f.highlight:SetAllPoints()
        f.highlight:SetDrawLayer("BACKGROUND", 1) -- Ensure it's above other background elements
        f.highlight:Hide()

        -- Icon (at the far left)
        f.icon = f:CreateTexture(nil, "ARTWORK")
        f.icon:SetSize(UI.ICON_W, UI.ICON_W)
        f.icon:SetPoint("LEFT", UI.LEFT_PAD, 0)

        -- Name (to the right of icon, fixed width)
        f.name = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        f.name:SetPoint("LEFT", f.icon, "RIGHT", UI.ICON_PAD, 0)
        f.name:SetWidth(UI.NAME_COL_W)
        f.name:SetJustifyH("LEFT")
        f.name:SetWordWrap(true)

        -- Create checkboxes - anchor each to the previous element, just like icon→name
        local CHECKBOX_SCALE = UI.CHECKBOX_SCALE or 0.7
        f.buy = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
        f.open = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
        f.conf = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")

        f.buy:SetScale(CHECKBOX_SCALE)
        f.open:SetScale(CHECKBOX_SCALE)
        f.conf:SetScale(CHECKBOX_SCALE)

        -- Set frame level to ensure they're visible above the background
        local baseLevel = f:GetFrameLevel()
        f.buy:SetFrameLevel(baseLevel + 2)
        f.open:SetFrameLevel(baseLevel + 2)
        f.conf:SetFrameLevel(baseLevel + 2)

        -- Programmatic, scale-aware X positions derived from header centers.
        -- Convert header centers to content/row space, then optionally apply scale correction and bias.
        local contentLeft   = (content and content.GetLeft and content:GetLeft()) or 0
        local containerLeft = (container and container.GetLeft and container:GetLeft()) or 0
        local buyCX         = container._hdrBuy and select(1, container._hdrBuy:GetCenter()) or nil
        local openCX        = container._hdrOpen and select(1, container._hdrOpen:GetCenter()) or nil
        local confCX        = container._hdrConf and select(1, container._hdrConf:GetCenter()) or nil
        local baseBuyX      = buyCX and (buyCX - contentLeft) or nil
        local baseOpenX     = openCX and (openCX - contentLeft) or nil
        local baseConfX     = confCX and (confCX - contentLeft) or nil
        local centers       = container and container._colCenters
        local baseRemX      = centers and ((centers[4] + containerLeft) - contentLeft) or nil

        local childScale    = f.buy:GetScale() or 1
        -- Always apply a scale-aware correction so visual spacing remains consistent
        local scaleCorr     = 1 / (childScale ~= 0 and childScale or 1)

        local function applyCheckbox(x)
            return x and (scaleCorr * x) or nil
        end

        -- Checkboxes: scale-aware; Remove: derive from Confirm delta, also scale-aware
        local X_BUY    = applyCheckbox(baseBuyX) or (UI.X_BUY or 460)
        local X_OPEN   = applyCheckbox(baseOpenX) or (UI.X_OPEN or 530)
        local X_CONF   = applyCheckbox(baseConfX) or (UI.X_CONF or 600)

        -- Remove: scale-aware + shift left by scrollbar reserve to stay visible when scrollbar appears
        local X_REMOVE = applyCheckbox(baseRemX) or (UI.X_REMOVE or 765)
        X_REMOVE       = X_REMOVE - (UI.SCROLLBAR_RESERVE or 24)

        if rowDebugCount == 1 then
            Addon:DebugPrint(
                "[X-FORMULA] (always scale-aware) childScale=%.3f, scaleCorr=%.3f, base(b/o/c/r)=%.1f/%.1f/%.1f/%.1f -> X=%.1f/%.1f/%.1f/%.1f",
                childScale, scaleCorr, baseBuyX or -1, baseOpenX or -1, baseConfX or -1,
                (centers and ((centers[4] + containerLeft) - contentLeft)) or -1,
                X_BUY, X_OPEN, X_CONF, X_REMOVE)
        end

        f.buy:SetPoint("CENTER", f, "LEFT", X_BUY, 0)
        f.open:SetPoint("CENTER", f, "LEFT", X_OPEN, 0)
        f.conf:SetPoint("CENTER", f, "LEFT", X_CONF, 0)

        -- Remove button
        f.remove = CreateFrame("Button", nil, f, "UIPanelCloseButtonNoScripts")
        f.remove:SetScale(UI.REMOVE_SCALE or UI.CHECKBOX_SCALE or 0.7)
        f.remove:SetPoint("CENTER", f, "LEFT", X_REMOVE, 0)
        f.remove:SetFrameLevel((f:GetFrameLevel() or 1) + 20)

        -- Transparent drag zone (only covers icon + name area)
        f.dragZone = CreateFrame("Frame", nil, f)
        f.dragZone:SetPoint("LEFT", UI.LEFT_PAD, 0)
        f.dragZone:SetSize(UI.ICON_W + UI.ICON_PAD + UI.NAME_COL_W, UI.ROW_H)
        f.dragZone:EnableMouse(true)

        -- Bind tooltip to dragZone so it shows when mousing over the drag area
        -- (tooltip will be set later when itemID is assigned to the row)
        f.dragZone.itemID = nil -- Will be set when row is populated

        -- Use OnMouseDown/Up for immediate drag response (no threshold delay)
        f.dragZone:SetScript("OnMouseDown", function(self, button)
            if button ~= "LeftButton" or not f.itemID then return end
            f.isDragging = true
            f:SetAlpha(0.9)
            f:StartMoving()
        end)

        f.dragZone:SetScript("OnMouseUp", function(self, button)
            if button ~= "LeftButton" or not f.isDragging then return end
            f.isDragging = false
            f:StopMovingOrSizing()
            f:SetAlpha(1)

            local myMid = (f:GetTop() + f:GetBottom()) / 2
            local siblings = {}
            for _, rf in ipairs(rows) do
                if rf ~= f and rf:IsShown() and rf.itemID then
                    table.insert(siblings, rf)
                end
            end
            table.sort(siblings, function(a, b) return (a:GetTop() or 0) > (b:GetTop() or 0) end)

            local target = #siblings + 1
            for i, rf in ipairs(siblings) do
                local mid = (rf:GetTop() + rf:GetBottom()) / 2
                if myMid > mid then
                    target = i; break
                end
            end

            local newOrder = {}
            for i, rf in ipairs(siblings) do
                if i == target then table.insert(newOrder, f.itemID) end
                table.insert(newOrder, rf.itemID)
            end
            if target == #siblings + 1 then table.insert(newOrder, f.itemID) end

            if Addon.SetRankOrder then Addon:SetRankOrder(newOrder) end
            Addon:RefreshList()
            if Addon.SyncOpenMacro then Addon:SyncOpenMacro(true) end
        end)

        return f
    end

    if #flat == 0 then
        if container.EmptyState then container.EmptyState:Show() end
        content:SetHeight(40); container:SetHeight(math.min(UI.MAX_H, 110))
        if scroll and scroll.ScrollBar then
            scroll.ScrollBar:Hide()
            scroll:ClearAllPoints(); scroll:SetPoint("TOPLEFT", 8, -52); scroll:SetPoint("BOTTOMRIGHT", -8, 14)
        end
        return
    else
        if container.EmptyState then container.EmptyState:Hide() end
    end

    for _, node in ipairs(flat) do
        if node.kind == "header" then
            local h = CreateFrame("Frame", nil, content)
            h:SetSize(1, UI.ROW_H - 6); h:SetPoint("TOPLEFT", 0, -y) -- Anchor at content edge
            local fs = h:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            fs:SetPoint("LEFT", UI.LEFT_PAD, 0)
            local key, text = node.key, nil
            if key:find("^currency:") then
                local curID = tonumber(key:match("currency:(%d+)"))
                local info = curID and C_CurrencyInfo.GetCurrencyInfo(curID)
                text = (info and info.name or ("currency:" .. (curID or ""))) ..
                    (info and ("  (" .. info.quantity .. ")") or "")
            elseif key:find("^item:") then
                local itemID = tonumber(key:match("item:(%d+)"))
                local name = GetItemInfo(itemID) or ("item:" .. (itemID or 0))
                local have = GetItemCount(itemID, true) or 0
                text = name .. "  (" .. have .. ")"
            else
                text = "Misc"
            end
            fs:SetText(text)
            y = y + (UI.ROW_H - 6)
            content.cells[#content.cells + 1] = h
        else
            local e = node.data
            local row = makeRow(content, y)
            row.itemID = e.itemID
            row.icon:SetTexture(Addon:GetItemIcon(e.itemID))
            UI.SetTwoLineTruncate(row.name, e.name or ("item:" .. e.itemID), UI.NAME_COL_W, 2)

            -- Bind tooltip only to icon, name, and dragZone (not the entire row)
            BindItemTooltip(row.icon, e.itemID)
            BindItemTooltip(row.name, e.itemID)
            BindItemTooltip(row.dragZone, e.itemID)

            local tog = Addon:GetItemToggles(e.itemID)
            row.buy:SetChecked(tog.buy); row.open:SetChecked(tog.open); row.conf:SetChecked(tog.confirm)

            -- Highlight this row based on what action will happen next
            local willBuy = (nextPurchaseID and e.itemID == nextPurchaseID)
            local willUse = (nextUseID and e.itemID == nextUseID)

            if willBuy and willUse then
                -- Both buy and use: Blend of blue + gold (additive)
                -- Blue (0.2, 0.4, 0.8) + Gold (0.8, 0.6, 0.2) = (1.0, 1.0, 1.0) normalized to (0.5, 0.5, 0.5)
                -- Using a teal/cyan blend: combines cool blue with warm gold
                row.highlight:SetColorTexture(0.5, 0.7, 0.6, 0.35)
                row.highlight:Show()
            elseif willBuy then
                -- Will be purchased: Blue
                row.highlight:SetColorTexture(0.2, 0.4, 0.8, 0.30)
                row.highlight:Show()
            elseif willUse then
                -- Will be used/opened: Gold/Orange
                row.highlight:SetColorTexture(0.8, 0.6, 0.2, 0.30)
                row.highlight:Show()
            else
                row.highlight:Hide()
            end

            row.buy:SetScript("OnClick", function(self)
                local t = Addon:GetItemToggles(e.itemID); t.buy = self:GetChecked() or false
                Addon:RefreshList()
                if Addon.SyncOpenMacro then Addon:SyncOpenMacro(true) end
            end)
            row.open:SetScript("OnClick", function(self)
                local t = Addon:GetItemToggles(e.itemID); t.open = self:GetChecked() or false
                if Addon.SyncOpenMacro then Addon:SyncOpenMacro(true) end
            end)
            row.conf:SetScript("OnClick", function(self)
                local t = Addon:GetItemToggles(e.itemID); t.confirm = self:GetChecked() or false
                if Addon.SyncOpenMacro then Addon:SyncOpenMacro(true) end
            end)

            local isSeed = Addon.IsSeedItem and Addon:IsSeedItem(e.itemID)
            if isSeed then
                row.remove:Disable(); row.remove:SetAlpha(0.35)
                row.remove:SetScript("OnClick", nil)
            else
                row.remove:Enable(); row.remove:SetAlpha(1)
                row.remove:SetScript("OnClick", function()
                    if Addon.RemoveTracked and Addon:RemoveTracked(e.itemID) then
                        local name = GetItemInfo(e.itemID) or ("item:" .. e.itemID)
                        UIErrorsFrame:AddMessage("|cffff9900CrestXmute: Removed|r " .. name)
                        Addon:TrackedChanged()
                    end
                end)
            end

            local isCandidate   = candidateSet[e.itemID] and true or false
            local isUnavailable = (not e.affordable) or (not tog.buy)
            local grey          = (not isCandidate) or isUnavailable
            if grey then
                row.icon:SetDesaturated(true); row.name:SetTextColor(0.6, 0.6, 0.6)
            else
                row.icon:SetDesaturated(false); row.name:SetTextColor(1, 0.82, 0)
            end
            y = y + UI.ROW_H; rows[#rows + 1] = row
            -- ensure the row and its interactive widgets are tracked so they get hidden/cleared
            content.cells[#content.cells + 1] = row
            content.cells[#content.cells + 1] = row.buy
            content.cells[#content.cells + 1] = row.open
            content.cells[#content.cells + 1] = row.conf
            content.cells[#content.cells + 1] = row.remove
        end
    end

    -- Dynamic height + scrollbar (button moved to title row -> more space)
    local needed = y + 10

    -- Always reserve right margin for scrollbar space (prevents shifting when scrollbar appears/disappears)
    local scrollWidth = scroll:GetWidth() or 1
    local reserve = UI.SCROLLBAR_RESERVE or 24
    content:SetWidth(math.max(1, scrollWidth - reserve))

    local headers = container.HeadersY or 52
    local chrome  = 6
    local totalH  = headers + needed + chrome
    local finalH  = math.min(UI.MAX_H or 560, math.max(220, totalH))
    container:SetHeight(finalH)

    -- Recompute to get actual viewport height after container resize
    scroll:UpdateScrollChildRect()
    local atMaxHeight = (totalH >= (UI.MAX_H or 560))
    local viewport = (scroll:GetHeight() or 0)
    local needScroll = atMaxHeight and (needed > viewport + 0.5)

    -- Set content height: when below max height, match viewport to prevent premature scrolling
    -- When at max height and scrolling is needed, use full needed height
    if needScroll then
        content:SetHeight(needed)
    else
        content:SetHeight(math.min(needed, viewport))
    end
    scroll:UpdateScrollChildRect()
    if needScroll then
        scroll.ScrollBar:Show()
    else
        scroll.ScrollBar:Hide()
    end
    -- Keep scroll frame anchors consistent (always account for scrollbar space)
    scroll:ClearAllPoints()
    scroll:SetPoint("TOPLEFT", 8, -52)
    scroll:SetPoint("BOTTOMRIGHT", -28, 14)
end

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

function Addon:RefreshList()
    if not self.Container or not self.Container:IsVisible() then return end
    if self._isRefreshing then return end
    self._isRefreshing               = true
    local container, content, scroll = self.Container, self.Container.Content, self.Container.Scroll

    -- (width handled after scrollbar visibility is determined)

    content.cells                    = content.cells or {}
    for _, f in ipairs(content.cells) do if f.Hide then f:Hide() end end
    Wipe(content.cells)
    content.rows                     = content.rows or {}
    for _, row in ipairs(content.rows) do
        row:Hide()
        row._inUse = false
    end

    local flat = BuildGroupedEntries()
    local y = 0
    local rows = {}
    local candidateSet = ComputeTopCandidatesByGroup()

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
    if Addon.DebugPrintCategory then
        Addon:DebugPrintCategory("positioning", "[NEXT] willBuy=%s, willUse=%s",
            tostring(nextPurchaseID or "nil"), tostring(nextUseID or "nil"))
    end

    local function acquireRow(parent, index)
        content.rows[index] = content.rows[index] or CreateFrame("Frame", nil, parent)
        local f = content.rows[index]
        if not f._initialized then
            f:SetHeight(UI.ROW_H)
            f:SetPoint("TOPLEFT", 0, 0)
            f:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
            f:SetMovable(true); f:SetClampedToScreen(true); f:EnableMouse(true)

            local parentLevel = parent:GetFrameLevel() or 1
            f:SetFrameLevel(parentLevel + 1)

            f.highlight = f:CreateTexture(nil, "BACKGROUND")
            f.highlight:SetPoint("TOPLEFT", 1, -1)
            f.highlight:SetPoint("BOTTOMRIGHT", -1, 1)
            f.highlight:SetDrawLayer("BACKGROUND", 0)
            f.highlight:SetVertexColor(1, 1, 1, 1)
            f.highlight:Hide()

            f.icon = f:CreateTexture(nil, "ARTWORK")
            f.icon:SetSize(UI.ICON_W, UI.ICON_W)
            f.icon:SetPoint("LEFT", UI.LEFT_PAD, 0)

            f.name = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            f.name:SetPoint("LEFT", f.icon, "RIGHT", UI.ICON_PAD, 0)
            f.name:SetWidth(UI.NAME_COL_W)
            f.name:SetJustifyH("LEFT")
            f.name:SetWordWrap(true)

            f.buy = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
            f.open = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
            f.conf = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")

            f.remove = CreateFrame("Button", nil, f, "UIPanelCloseButtonNoScripts")
            f.remove:SetFrameLevel((f:GetFrameLevel() or 1) + 20)

            f.dragZone = CreateFrame("Frame", nil, f)
            f.dragZone:SetPoint("LEFT", UI.LEFT_PAD, 0)
            f.dragZone:SetSize(UI.ICON_W + UI.ICON_PAD + UI.NAME_COL_W, UI.ROW_H)
            f.dragZone:EnableMouse(true)

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

            f._initialized = true
        end

        local CHECKBOX_SCALE = container._effectiveCheckboxScale or UI.CHECKBOX_SCALE
        if UI.SetScaledSize then
            UI.SetScaledSize(f.buy, CHECKBOX_SCALE)
            UI.SetScaledSize(f.open, CHECKBOX_SCALE)
            UI.SetScaledSize(f.conf, CHECKBOX_SCALE)
            UI.SetScaledSize(f.remove, UI.REMOVE_SCALE)
        end

        local baseLevel = f:GetFrameLevel()
        f.buy:SetFrameLevel(baseLevel + 2)
        f.open:SetFrameLevel(baseLevel + 2)
        f.conf:SetFrameLevel(baseLevel + 2)

        f._needsPosition = true
        f.buy:Show(); f.open:Show(); f.conf:Show(); f.remove:Show()
        f.highlight:Hide()
        f.dragZone.itemID = nil
        f._inUse = true
        f:Show()
        return f
    end


    if #flat == 0 then
        if container.EmptyState then container.EmptyState:Show() end
        content:SetHeight(40); container:SetHeight(math.min(UI.MAX_H, 110))
        if scroll and scroll.ScrollBar then
            scroll.ScrollBar:Hide()
            scroll:ClearAllPoints(); scroll:SetPoint("TOPLEFT", 8, -(container.HeadersY or 52)); scroll:SetPoint("BOTTOMRIGHT", -8, 14)
        end
        self._isRefreshing = false
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
                if itemID then
                    local name = GetItemInfo(itemID) or ("item:" .. itemID)
                    local have = GetItemCount(itemID, true) or 0
                    text = name .. "  (" .. have .. ")"
                else
                    text = key .. "  (invalid)"
                end
            else
                text = "Misc"
            end
            fs:SetText(text)
            y = y + (UI.ROW_H - 6)
            content.cells[#content.cells + 1] = h
        else
            local e = node.data
            local rowIndex = #rows + 1
            local row = acquireRow(content, rowIndex)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", 0, -y)
            row:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -y)
            row.itemID = e.itemID
            row.icon:SetTexture(Addon:GetItemIcon(e.itemID))
            UI.SetTwoLineTruncate(row.name, e.name or ("item:" .. e.itemID), UI.NAME_COL_W, 2)

            -- Bind tooltip only to icon, name, and dragZone (not the entire row)
            BindItemTooltip(row.icon, e.itemID)
            BindItemTooltip(row.name, e.itemID)
            BindItemTooltip(row.dragZone, e.itemID)

            local tog = Addon:GetItemToggles(e.itemID)
            row.buy:SetChecked(tog.buy); row.open:SetChecked(tog.open); row.conf:SetChecked(tog.confirm)

            -- Force checkbox visual update on next frame (fixes invisible checkboxes on first show)
            C_Timer.After(0, function()
                if row.buy then row.buy:SetChecked(tog.buy) end
                if row.open then row.open:SetChecked(tog.open) end
                if row.conf then row.conf:SetChecked(tog.confirm) end
            end)

            -- Highlight this row based on what action will happen next
            local willBuy = (nextPurchaseID and e.itemID == nextPurchaseID)
            local willUse = (nextUseID and e.itemID == nextUseID)

            if willBuy and willUse then
                -- Both buy and use: combined highlight
                local c = UI.HIGHLIGHT_BOTH
                row.highlight:SetColorTexture(c[1], c[2], c[3], c[4])
                row.highlight:Show()
                -- Force visual update on next frame
                C_Timer.After(0, function()
                    if row.highlight then row.highlight:Show() end
                end)
            elseif willBuy then
                -- Will be purchased next
                local c = UI.HIGHLIGHT_BUY
                row.highlight:SetColorTexture(c[1], c[2], c[3], c[4])
                row.highlight:Show()
                -- Force visual update on next frame
                C_Timer.After(0, function()
                    if row.highlight then row.highlight:Show() end
                end)
            elseif willUse then
                -- Will be used/opened next
                local c = UI.HIGHLIGHT_USE
                row.highlight:SetColorTexture(c[1], c[2], c[3], c[4])
                row.highlight:Show()
                -- Force visual update on next frame
                C_Timer.After(0, function()
                    if row.highlight then row.highlight:Show() end
                end)
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
                local c = UI.TEXT_DISABLED
                row.icon:SetDesaturated(true); row.name:SetTextColor(c[1], c[2], c[3])
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
    scroll:SetPoint("TOPLEFT", 8, -(container.HeadersY or 52))
    scroll:SetPoint("BOTTOMRIGHT", -28, 14)

    -- Finalize checkbox/remove positions now that layout is settled
    local centers       = container._colCenters or {}
    local contentLeft   = content:GetLeft() or 0
    local containerLeft = container:GetLeft() or 0
    local offsetActual  = contentLeft - containerLeft
    local offsetStatic  = (container._insetLeft or 0) + (UI.CONTENT_PAD or 0)
    local offset        = (math.abs(offsetActual) > 0.0001) and offsetActual or offsetStatic

    local function positionRow(f, isFirst)
        if not f or not f._needsPosition then return end
        local RAW_BUY  = (centers[1] and (centers[1] - offset)) or (UI.COL_SECTION_X + UI.COL_SP + UI.COL_W * 0.5)
        local RAW_OPEN = (centers[2] and (centers[2] - offset)) or (RAW_BUY + UI.COL_W + UI.COL_SP)
        local RAW_CONF = (centers[3] and (centers[3] - offset)) or (RAW_OPEN + UI.COL_W + UI.COL_SP)
        local RAW_REM  = (centers[4] and (centers[4] - offset)) or (RAW_CONF + UI.COL_W + UI.REMOVE_PAD)

        local cbScale  = f.buy and f.buy._crestSizeScale or UI.CHECKBOX_SCALE
        local rmScale  = (f.remove and f.remove._crestSizeScale) or UI.REMOVE_SCALE

        local X_BUY    = RAW_BUY
        local X_OPEN   = RAW_OPEN
        local X_CONF   = RAW_CONF
        local X_REMOVE = RAW_REM - (UI.SCROLLBAR_RESERVE or 30)

        f.buy:ClearAllPoints(); f.buy:SetPoint("CENTER", f, "LEFT", X_BUY, 0)
        f.open:ClearAllPoints(); f.open:SetPoint("CENTER", f, "LEFT", X_OPEN, 0)
        f.conf:ClearAllPoints(); f.conf:SetPoint("CENTER", f, "LEFT", X_CONF, 0)
        if f.remove then
            f.remove:ClearAllPoints(); f.remove:SetPoint("CENTER", f, "LEFT", X_REMOVE, 0)
        end
        f._needsPosition = false

        if isFirst and Addon.DebugPrintCategory then
            Addon:DebugPrintCategory("positioning",
                "[X-COLUMNS] offset=%.1f (actual=%.1f, static=%.1f) cbScale=%.3f rmScale=%.3f RAW=%.1f/%.1f/%.1f/%.1f X=%.1f/%.1f/%.1f/%.1f",
                offset, offsetActual, offsetStatic, cbScale, rmScale, RAW_BUY, RAW_OPEN, RAW_CONF, RAW_REM,
                X_BUY, X_OPEN, X_CONF, X_REMOVE)
            C_Timer.After(0, function()
                if not (f.buy and f.open and f.conf and container and container._hdrBuy) then return end
                local bcx = select(1, f.buy:GetCenter()) or -1
                local ocx = select(1, f.open:GetCenter()) or -1
                local ccx = select(1, f.conf:GetCenter()) or -1
                local rmx = (f.remove and select(1, f.remove:GetCenter())) or -1
                local hbx = select(1, container._hdrBuy:GetCenter()) or -1
                local hox = select(1, container._hdrOpen:GetCenter()) or -1
                local hcx = select(1, container._hdrConf:GetCenter()) or -1
                Addon:DebugPrintCategory("positioning",
                    "[MEASURE] row(b/o/c)=%.1f/%.1f/%.1f vs hdr=%.1f/%.1f/%.1f | delta=%.1f/%.1f/%.1f | remove row=%.1f",
                    bcx, ocx, ccx, hbx, hox, hcx, (bcx - hbx), (ocx - hox), (ccx - hcx), rmx)
            end)
        end
    end

    for i, row in ipairs(rows) do
        positionRow(row, i == 1)
    end

    self._isRefreshing = false
end

local ADDON_NAME, Addon = ...

Addon.UI                = Addon.UI or {}
local UI                = Addon.UI

-- Fallback layout constants
UI.CONTENT_PAD          = UI.CONTENT_PAD or 8
UI.LEFT_PAD             = UI.LEFT_PAD or 10
UI.ICON_W               = UI.ICON_W or 24
UI.ICON_PAD             = UI.ICON_PAD or 8
UI.NAME_COL_W           = UI.NAME_COL_W or 220
UI.ROW_H                = UI.ROW_H or 32
UI.MAX_H                = UI.MAX_H or 460
UI.COL_W                = UI.COL_W or 22
UI.COL_SP               = UI.COL_SP or 10

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

local function SetTwoLineTruncate(fs, text, width, maxLines)
    maxLines = maxLines or 2
    fs:SetWidth(width); fs:SetWordWrap(true); fs:SetText(text or "")
    local _, fh = fs:GetFont(); local maxH = (fh or 12) * maxLines + 2
    if fs:GetStringHeight() <= maxH then return end
    local s = text or ""; local lo, hi, best = 1, #s, ""
    while lo <= hi do
        local mid = math.floor((lo + hi) / 2)
        fs:SetText(s:sub(1, mid) .. "…")
        if fs:GetStringHeight() <= maxH and fs:GetStringWidth() <= width * 1.02 then
            best = s:sub(1, mid) .. "…"; lo = mid + 1
        else
            hi = mid - 1
        end
    end
    fs:SetText(best ~= "" and best or (s:sub(1, math.max(0, #s - 1)) .. "…"))
end

-- Build grouped entries from tracked union
local function BuildGroupedEntries()
    local entries = Addon:CollectTrackedMerchantEntries_All()
    local groups = {}
    for _, e in ipairs(entries) do
        local key = Addon.GetPrimaryCostKey and Addon:GetPrimaryCostKey(e.idx) or "misc"
        local gk = key or "misc"
        groups[gk] = groups[gk] or { header = gk, rows = {} }
        table.insert(groups[gk].rows, e)
    end
    for _, g in pairs(groups) do
        table.sort(g.rows, function(a, b)
            local ra = Addon.GetRank and Addon:GetRank(a.itemID) or 9999
            local rb = Addon.GetRank and Addon:GetRank(b.itemID) or 9999
            if ra ~= rb then return ra < rb end
            return a.idx < b.idx
        end)
    end
    local orderKeys, flat = {}, {}
    for k in pairs(groups) do orderKeys[#orderKeys + 1] = k end
    table.sort(orderKeys)
    for _, k in ipairs(orderKeys) do
        flat[#flat + 1] = { kind = "header", key = k }
        for _, row in ipairs(groups[k].rows) do
            flat[#flat + 1] = { kind = "row", data = row }
        end
    end
    return flat
end

local function Wipe(t) for k in pairs(t) do t[k] = nil end end

function Addon:TrackedChanged()
    if self.Container and self.Container:IsShown() then
        if self.RefreshList then self:RefreshList() end
        if self.SyncOpenMacro then self:SyncOpenMacro(false) end
    end
end

function Addon:RefreshList()
    if not self.Container then return end
    local container, content, scroll = self.Container, self.Container.Content, self.Container.Scroll
    local colsX = container._colsX

    content.cells = content.cells or {}
    for _, f in ipairs(content.cells) do if f.Hide then f:Hide() end end
    Wipe(content.cells)

    local flat = BuildGroupedEntries()
    local y = 0
    local rows = {}
    local topBuyID = Addon.GetTopAffordableSingle and select(1, Addon:GetTopAffordableSingle()) or nil

    local function makeRow(parent)
        local f = CreateFrame("Frame", nil, parent)
        f:SetSize(1, UI.ROW_H)

        -- Icon
        f.icon = f:CreateTexture(nil, "ARTWORK")
        f.icon:SetSize(UI.ICON_W, UI.ICON_W)
        f.icon:SetPoint("LEFT", UI.LEFT_PAD, 0)

        -- Name
        f.name = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        f.name:SetPoint("LEFT", f.icon, "RIGHT", UI.ICON_PAD, 0)
        f.name:SetWidth(UI.NAME_COL_W)
        f.name:SetJustifyH("LEFT"); f.name:SetWordWrap(true)

        -- Checkbox columns (use same math as headers)
        local relBuyX  = colsX[1] - UI.CONTENT_PAD
        local relOpenX = colsX[2] - UI.CONTENT_PAD
        local relConfX = colsX[3] - UI.CONTENT_PAD

        f.buy          = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate"); f.buy:SetScale(0.7)
        f.open = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate"); f.open:SetScale(0.7)
        f.conf = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate"); f.conf:SetScale(0.7)

        f.buy:SetPoint("CENTER", f, "LEFT", relBuyX + UI.COL_W / 2, 0)
        f.open:SetPoint("CENTER", f, "LEFT", relOpenX + UI.COL_W / 2, 0)
        f.conf:SetPoint("CENTER", f, "LEFT", relConfX + UI.COL_W / 2, 0)

        -- Remove (×) just after Confirm column
        local relRemoveX = relConfX + UI.COL_W + 10
        f.remove = CreateFrame("Button", nil, f, "UIPanelCloseButtonNoScripts")
        f.remove:SetScale(0.6)
        f.remove:SetPoint("CENTER", f, "LEFT", relRemoveX, 0)
        f.remove:SetFrameLevel((f:GetFrameLevel() or 1) + 20)
        f.remove:SetHitRectInsets(2, 2, 2, 2)

        -- Drag only when mouse down in icon+name region
        f:RegisterForDrag("LeftButton"); f:SetMovable(true); f:EnableMouse(true)
        f:SetScript("OnMouseDown", function(self, btn)
            if btn ~= "LeftButton" then return end
            local mx = GetCursorPosition(); local s = self:GetEffectiveScale()
            local left = self:GetLeft() or 0; mx = mx / s
            local nameEnd = left + UI.LEFT_PAD + UI.ICON_W + UI.ICON_PAD + UI.NAME_COL_W
            self._allowDrag = (mx <= nameEnd + 2)
        end)
        f:SetScript("OnDragStart", function(self)
            if not self.itemID or not self._allowDrag then return end
            self.isDragging = true; self:SetAlpha(0.9); self:StartMoving()
        end)
        f:SetScript("OnDragStop", function(self)
            if not self.isDragging then return end
            self.isDragging = false; self:StopMovingOrSizing(); self:SetAlpha(1)
            local myTop = self:GetTop()
            local siblings = {}
            for _, rf in ipairs(rows) do
                if rf ~= self and rf:IsShown() and rf.itemID then table.insert(siblings, rf) end
            end
            table.sort(siblings, function(a, b) return (a:GetTop() or 0) > (b:GetTop() or 0) end)
            local target = #siblings + 1
            for i, rf in ipairs(siblings) do
                local top = rf:GetTop() or -math.huge
                if myTop and top and myTop > top then
                    target = i; break
                end
            end
            local newOrder = {}
            for i, rf in ipairs(siblings) do
                if i == target then table.insert(newOrder, self.itemID) end
                table.insert(newOrder, rf.itemID)
            end
            if target == #siblings + 1 then table.insert(newOrder, self.itemID) end
            if Addon.SetRankOrder then Addon:SetRankOrder(newOrder) end
            Addon:RefreshList()
            if Addon.SyncOpenMacro then Addon:SyncOpenMacro(false) end
        end)

        return f
    end

    if #flat == 0 then
        if container.EmptyState then container.EmptyState:Show() end
        content:SetHeight(40); container:SetHeight(math.min(UI.MAX_H, 110))
        if scroll and scroll.ScrollBar then
            scroll.ScrollBar:Hide()
            scroll:ClearAllPoints(); scroll:SetPoint("TOPLEFT", 8, -52); scroll:SetPoint("BOTTOMRIGHT", -8, 10)
        end
        return
    else
        if container.EmptyState then container.EmptyState:Hide() end
    end

    for _, node in ipairs(flat) do
        if node.kind == "header" then
            local h = CreateFrame("Frame", nil, content)
            h:SetSize(1, UI.ROW_H - 6); h:SetPoint("TOPLEFT", UI.CONTENT_PAD, -y)
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
            local row = makeRow(content)
            row:SetPoint("TOPLEFT", UI.CONTENT_PAD, -y); row:SetPoint("RIGHT", -UI.CONTENT_PAD, 0)
            row.icon:SetTexture(e.icon or 134400)
            row.itemID = e.itemID

            SetTwoLineTruncate(row.name, e.name or ("item:" .. e.itemID), UI.NAME_COL_W, 2)
            BindItemTooltip(row, e.itemID); BindItemTooltip(row.name, e.itemID)

            local tog = Addon:GetItemToggles(e.itemID)
            row.buy:SetChecked(tog.buy); row.open:SetChecked(tog.open); row.conf:SetChecked(tog.confirm)

            row.buy:SetScript("OnClick", function(self)
                local t = Addon:GetItemToggles(e.itemID); t.buy = self:GetChecked() or false
                if Addon.SyncOpenMacro then Addon:SyncOpenMacro(false) end; Addon:RefreshList()
            end)
            row.open:SetScript("OnClick", function(self)
                local t = Addon:GetItemToggles(e.itemID); t.open = self:GetChecked() or false
                if Addon.SyncOpenMacro then Addon:SyncOpenMacro(false) end
            end)
            row.conf:SetScript("OnClick", function(self)
                local t = Addon:GetItemToggles(e.itemID); t.confirm = self:GetChecked() or false
                if Addon.SyncOpenMacro then Addon:SyncOpenMacro(false) end
            end)

            -- Remove (×) action (blocked for seed)
            local isSeed = Addon.IsSeedItem and Addon:IsSeedItem(e.itemID)
            if isSeed then
                row.remove:Disable(); row.remove:SetAlpha(0.35)
                row.remove:SetScript("OnClick", nil)
                row.remove:SetScript("OnEnter", function(self)
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:AddLine("Default seasonal item", 1, 1, 1)
                    GameTooltip:AddLine("Cannot remove from seed.", 0.9, 0.9, 0.9)
                    GameTooltip:Show()
                end)
                row.remove:SetScript("OnLeave", function() GameTooltip:Hide() end)
            else
                row.remove:Enable(); row.remove:SetAlpha(1)
                row.remove:SetScript("OnEnter", function(self)
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:AddLine("Remove from tracked", 1, 1, 1)
                    GameTooltip:Show()
                end)
                row.remove:SetScript("OnLeave", function() GameTooltip:Hide() end)
                row.remove:SetScript("OnClick", function()
                    if Addon.RemoveTracked and Addon:RemoveTracked(e.itemID) then
                        Addon:TrackedChanged()
                    end
                end)
            end

            -- Grey only icon+name when not candidate or not affordable / buy off
            local isCandidate = (topBuyID and e.itemID == topBuyID) or false
            local isUnavailable = (not e.affordable) or (not tog.buy)
            local grey = (not isCandidate) or isUnavailable
            if grey then
                row.icon:SetDesaturated(true); row.name:SetTextColor(0.6, 0.6, 0.6)
            else
                row.icon:SetDesaturated(false); row.name:SetTextColor(1, 0.82, 0)
            end

            y = y + UI.ROW_H; rows[#rows + 1] = row; content.cells[#content.cells + 1] = row
        end
    end

    -- Dynamic height + scrollbar (always inside the panel)
    local needed = y + 10
    content:SetHeight(needed)
    local headers = container.HeadersY or 52
    local chrome  = 10
    local totalH  = headers + needed + chrome
    local finalH  = math.min(UI.MAX_H, math.max(180, totalH))
    container:SetHeight(finalH)

    if scroll and scroll.ScrollBar then
        local viewport = finalH - headers - chrome
        scroll.ScrollBar:ClearAllPoints()
        scroll.ScrollBar:SetPoint("TOPRIGHT", scroll, "TOPRIGHT", 0, -16)
        scroll.ScrollBar:SetPoint("BOTTOMRIGHT", scroll, "BOTTOMRIGHT", 0, 16)

        if needed > viewport + 0.5 then
            scroll.ScrollBar:Show()
            scroll:ClearAllPoints()
            scroll:SetPoint("TOPLEFT", 8, -52)
            scroll:SetPoint("BOTTOMRIGHT", -28, 40)
        else
            scroll.ScrollBar:Hide()
            scroll:ClearAllPoints()
            scroll:SetPoint("TOPLEFT", 8, -52)
            scroll:SetPoint("BOTTOMRIGHT", -8, 40)
        end
    end
end

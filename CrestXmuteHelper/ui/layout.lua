local ADDON_NAME, Addon = ...
Addon.UI                = Addon.UI or {}
local UI                = Addon.UI

-- ===== Layout constants =====
UI.CONTENT_PAD          = 8
UI.LEFT_PAD             = 10
UI.ICON_W               = 24
UI.ICON_PAD             = 8
UI.NAME_COL_W           = 210 -- wider, as requested
UI.ROW_H                = 32
UI.MAX_H                = 360
UI.COL_W                = 26
UI.COL_SP               = 12

-- ===== Small helpers =====
function UI.MakeMovable(frame)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetClampedToScreen(true)
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local p, rel, rp, x, y = self:GetPoint(1)
        CrestXmuteDB.framePos = { p, rel and rel:GetName() or "MerchantFrame", rp, x, y }
    end)
end

function UI.ApplySavedPosition(f)
    local pos = CrestXmuteDB.framePos
    if not pos or not pos[1] then return false end
    local rel = pos[2] and _G[pos[2]] or MerchantFrame or UIParent
    f:ClearAllPoints()
    f:SetPoint(pos[1], rel, pos[3], pos[4], pos[5])
    return true
end

function UI.DockOutsideMerchant(f)
    f:ClearAllPoints()
    if MerchantFrame and MerchantFrame:IsShown() then
        f:SetPoint("LEFT", MerchantFrame, "RIGHT", 8, 0)
    else
        f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
end

-- Real item tooltip on widget hover
function UI.BindItemTooltip(widget, itemID)
    widget:EnableMouse(true)
    widget:SetScript("OnEnter", function(self)
        if not itemID then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetItemByID(itemID)
        GameTooltip:Show()
    end)
    widget:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-- Wrap to maxLines (default 2); if still too tall, truncate with ellipsis.
function UI.SetTwoLineTruncate(fs, text, width, maxLines)
    maxLines = maxLines or 2
    fs:SetWidth(width)
    fs:SetWordWrap(true)
    fs:SetText(text or "")

    local _, fontHeight = fs:GetFont()
    local maxH = (fontHeight or 12) * maxLines + 2

    if fs:GetStringHeight() <= maxH then
        return
    end

    -- Manual truncate with ellipsis (binary search)
    local s = text or ""
    local lo, hi = 1, #s
    local best = ""
    while lo <= hi do
        local mid = math.floor((lo + hi) / 2)
        fs:SetText(s:sub(1, mid) .. "…")
        if fs:GetStringHeight() <= maxH and fs:GetStringWidth() <= width * 1.02 then
            best = s:sub(1, mid) .. "…"
            lo = mid + 1
        else
            hi = mid - 1
        end
    end
    -- Lua has no ?: operator; use and/or idiom
    fs:SetText(best ~= "" and best or (s:sub(1, math.max(0, #s - 1)) .. "…"))
end

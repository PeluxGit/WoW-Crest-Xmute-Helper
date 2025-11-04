-- ui/layout.lua
-- Shared UI constants and small layout helpers for consistent sizing and positioning
local ADDON_NAME, Addon = ...

Addon.UI                = Addon.UI or {}
local UI                = Addon.UI

UI.CONTENT_PAD          = 8  -- Padding around the content area
UI.LEFT_PAD             = 10 -- Left margin before items
UI.ICON_W               = 24 -- Item icon width

-- Highlight colors for row states
UI.HIGHLIGHT_BUY        = { 0.2, 0.4, 0.8, 0.30 } -- Blue for items with Buy enabled
UI.HIGHLIGHT_USE        = { 0.8, 0.6, 0.2, 0.30 } -- Gold for items with Use/Open enabled
UI.HIGHLIGHT_BOTH       = { 0.5, 0.7, 0.6, 0.35 } -- Green-cyan for items with both enabled

-- Text colors
UI.TEXT_DISABLED        = { 0.6, 0.6, 0.6 } -- Grey for unavailable items

UI.ICON_PAD             = 8                 -- Space between icon and name
UI.NAME_COL_W           = 250               -- Item name column width
UI.COL_SECTION_X        = 300               -- Start X position for the column section
UI.ROW_H                = 32                -- Row height
UI.MAX_H                = 360               -- Maximum panel height
UI.COL_W                = 39                -- Width of checkbox columns (wide enough for "Confirm")
UI.COL_SP               = 10                -- Space between columns (more breathing room between boxes)
UI.REMOVE_PAD           = 20                -- Space before remove button (extra gap from Confirm)
UI.SCROLLBAR_RESERVE    = 30                -- Dummy padding after Remove so scrollbar overlaps this space, not the button

UI.CHECKBOX_SCALE       = 0.7
UI.ADDMODE_SCALE        = 0.9
UI.REMOVE_SCALE         = 0.7

-- Fallback absolute X positions in row space (CENTER-to-LEFT anchor)
-- These reproduce the empirically tuned look if measurement/scaling is unavailable
UI.X_BUY                = 320
UI.X_OPEN               = 370
UI.X_CONF               = 420
UI.X_REMOVE             = 480

-- ===== Small helpers (used by list.lua) =====

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
    fs:SetText(best ~= "" and best or (s:sub(1, math.max(0, #s - 1)) .. "…"))
end

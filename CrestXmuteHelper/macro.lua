-- macro.lua
-- Builds and syncs the Buy+Open macro and the docked clicker text
local ADDON_NAME, Addon = ...

local MACRO_NAME = "CrestX-Open"
local MACRO_ICON = "INV_Misc_Bag_10_Black"
local MAX_BAG_ITEMS = 30 -- Max distinct item IDs to collect from bags for /use lines

Addon.MACRO_NAME = MACRO_NAME

-- Build a compact /run line that buys the target item ID from the merchant
local function BuildBuySnippet(itemID)
    if not itemID then return nil end
    return string.format(
        "/run for i=1,GetMerchantNumItems()do l=GetMerchantItemLink(i)if l and GetItemInfoInstant(l)==%d then BuyMerchantItem(i)break end end",
        itemID)
end

-- Compose the macro body (<= 255 chars) from:
-- - ONE /use item:<id> line for the first tracked+enabled item in bags (only one can be used per click)
-- - Buy one top-priority affordable item with Buy enabled (optional confirm click)
function Addon:BuildMacroBody()
    local parts = {}

    -- Add #showtooltip at the top (will show tooltip of the /use command on action bar)
    parts[#parts + 1] = "#showtooltip"

    -- Add ONE /use item:<id> for the first item present in bags with Open enabled
    -- (Only one item can be used per macro execution anyway)
    local openIDs = Addon:CollectTrackedIDsInBags(MAX_BAG_ITEMS)
    for _, itemID in ipairs(openIDs) do
        local tog = Addon:GetItemToggles(itemID)
        if tog.open then
            parts[#parts + 1] = "/use item:" .. itemID
            break -- Only one /use line needed
        end
    end

    -- Then: Buy one top-priority affordable item with Buy enabled
    local topId = Addon:GetTopAffordableSingle()
    local buyLine = BuildBuySnippet(topId)
    if buyLine then
        parts[#parts + 1] = buyLine
    end

    -- Optional /click confirm — per-item only
    if topId then
        local tog = Addon:GetItemToggles(topId)
        if tog and tog.confirm then
            parts[#parts + 1] = "/click StaticPopup1Button1"
        end
    end

    if #parts <= 1 then return nil end -- Only #showtooltip, nothing to do
    return table.concat(parts, "\n")
end

-- Create or update the character macro and docked clicker with the same text
-- Skips in combat, sets a friendly message if nothing to do
function Addon:SyncOpenMacro(force)
    if InCombatLockdown() then
        UIErrorsFrame:AddMessage("|cffffd100CrestXmute: Can't update macro in combat.|r")
        return
    end
    local body = Addon:BuildMacroBody()

    -- If nothing to do, set a friendly default message
    if not body then
        body = "/run UIErrorsFrame:AddMessage(\"|cff33ff99CrestXmute:|r Nothing to buy or open right now!\")"
    end

    local idx = GetMacroIndexByName(MACRO_NAME)
    if not idx or idx == 0 then
        local globalCount = GetNumMacros()
        local globalLimit = rawget(_G, "MAX_ACCOUNT_MACROS") or rawget(_G, "MAX_GLOBAL_MACROS") or 36
        if globalCount >= globalLimit then
            UIErrorsFrame:AddMessage("|cffff5555CrestXmute: No free general macro slots.|r")
            return
        end
        CreateMacro(MACRO_NAME, MACRO_ICON, body, nil) -- nil = general/account macro
    else
        local name, icon, isChar, oldBody = GetMacroInfo(idx)
        if oldBody ~= body or force then
            EditMacro(idx, MACRO_NAME, icon, body)
        end
    end
end

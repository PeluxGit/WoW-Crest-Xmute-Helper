-- macro.lua
-- Builds and syncs the Buy+Open macro and the docked clicker text
local ADDON_NAME, Addon = ...

local MACRO_NAME = "CrestX-Open"
local MACRO_ICON = "INV_Misc_Bag_10_Black"
local MAX_BODY = 255
local MAX_BAG_ITEMS = 30 -- Max distinct item IDs to collect from bags for /use lines

-- Build a compact /run line that buys the first matching item ID from the merchant list
local function BuildBuySnippet_one(ids)
    if #ids == 0 then return nil end
    local id = ids[1]
    return string.format(
        "/run g=GetMerchantNumItems m=GetMerchantItemLink I=GetItemInfoInstant B=BuyMerchantItem T={[%d]=1}for i=1,g()do l=m(i)if l and T[I(l)]then B(i)break end end",
        id)
end

-- Compose the macro body (<= 255 chars) from:
-- - Buy one top-priority affordable item with Buy enabled (optional confirm click)
-- - /use item:<id> lines for tracked+enabled items present in bags
function Addon:BuildMacroBody()
    local parts, length = {}, 0

    -- Always buy one: top-priority affordable with Buy enabled
    local buyIds = {}
    local topId = Addon:GetTopAffordableSingle()
    if topId then buyIds[1] = topId end

    local buyLine = BuildBuySnippet_one(buyIds)
    if buyLine then
        if (length + #buyLine + 1) <= MAX_BODY then
            parts[#parts + 1] = buyLine; length = length + #buyLine + 1
        else
            return nil
        end
    end

    -- Optional /click confirm — per-item only
    local needConfirm = false
    if buyIds and #buyIds > 0 then
        local tog = Addon:GetItemToggles(buyIds[1])
        needConfirm = tog and tog.confirm
    end
    if needConfirm then
        local line = "/click StaticPopup1Button1"
        if (length + #line + 1) <= MAX_BODY then
            parts[#parts + 1] = line; length = length + #line + 1
        end
    end

    -- Fill remaining with /use item:<id> for items present in bags and Open enabled
    local openIDs = Addon:CollectTrackedIDsInBags(MAX_BAG_ITEMS)
    for _, itemID in ipairs(openIDs) do
        local tog = Addon:GetItemToggles(itemID)
        if tog.open then
            local line = "/use item:" .. itemID
            if (length + #line + 1) <= MAX_BODY then
                parts[#parts + 1] = line; length = length + #line + 1
            else
                break
            end
        end
    end

    if #parts == 0 then return nil end
    return table.concat(parts, "\n")
end

-- Create or update the character macro and docked clicker with the same text
-- Skips in combat, and no-ops if the body would be empty
function Addon:SyncOpenMacro(force)
    if InCombatLockdown() then
        UIErrorsFrame:AddMessage("|cffffd100CrestXmute: Can't update macro in combat.|r")
        return
    end
    local body = Addon:BuildMacroBody()
    if not body then
        -- Also clear clicker text so it doesn't do stale work
        Addon:UpdateClickerMacroText("")
        return
    end

    -- Keep the docked clicker in sync with the very same macro text
    Addon:UpdateClickerMacroText(body)

    local idx = GetMacroIndexByName(MACRO_NAME)
    if not idx or idx == 0 then
        local _, charCount = GetNumMacros()
        local charLimit = MAX_CHARACTER_MACROS or 18
        if charCount >= charLimit then
            UIErrorsFrame:AddMessage("|cffff5555CrestXmute: No free character macro slots.|r")
            return
        end
        CreateMacro(MACRO_NAME, MACRO_ICON, body, true)
    else
        local name, icon, isChar, oldBody = GetMacroInfo(idx)
        if oldBody ~= body or force then
            EditMacro(idx, MACRO_NAME, icon, body, 1, isChar)
        end
    end
end

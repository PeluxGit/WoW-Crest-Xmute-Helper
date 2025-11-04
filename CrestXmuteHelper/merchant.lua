-- merchant.lua
-- Affordability and merchant-side helpers
local ADDON_NAME, Addon = ...

-- Robust affordability check for a merchant line index.
-- Considers:
-- - isPurchasable: vendor says it's purchasable (filters one-time/locked purchases)
-- - isUsable: vendor says player can use/buy it
-- - numAvailable: limited stock availability
-- - All cost lines: currencies, currency-links, or item costs vs player amounts
local function PlayerCanAfford(idx)
    local _, _, _, _, numAvailable, isPurchasable, isUsable = GetMerchantItemInfo(idx)
    -- Validate that we got valid data from GetMerchantItemInfo
    if isPurchasable == nil and isUsable == nil then
        -- No valid merchant data
        return false
    end
    -- Check if item is purchasable (not locked/already bought one-time items)
    if isPurchasable == false then return false end
    if isUsable == false then return false end
    if numAvailable and numAvailable ~= -1 and numAvailable <= 0 then return false end

    local costCount = GetMerchantItemCostInfo(idx) or 0
    for c = 1, costCount do
        local _, costQty, itemLink, _, currencyQty, _, currencyId = GetMerchantItemCostItem(idx, c)
        if currencyId and currencyId > 0 then
            local info = C_CurrencyInfo.GetCurrencyInfo(currencyId)
            local have = info and info.quantity or 0
            if have < (currencyQty or 0) then return false end
        elseif type(itemLink) == "string" then
            local curID = itemLink:match("Hcurrency:(%d+)")
            if curID then
                curID = tonumber(curID)
                local info = C_CurrencyInfo.GetCurrencyInfo(curID)
                local have = info and info.quantity or 0
                if have < (costQty or 0) then return false end
            else
                local itemID = select(1, GetItemInfoInstant(itemLink))
                if itemID then
                    local have = GetItemCount(itemID, true) or 0
                    if have < (costQty or 0) then return false end
                else
                    return false
                end
            end
        end
    end
    return true
end
Addon.PlayerCanAfford = PlayerCanAfford

-- For Buy 1: pick the single highest-priority affordable item with Buy enabled
function Addon:GetTopAffordableSingle()
    local bestId, bestIdx, bestRank
    local n = GetMerchantNumItems()
    if not n or n == 0 then return nil, nil end
    for i = 1, n do
        local link = GetMerchantItemLink(i)
        if link then
            local id = select(1, GetItemInfoInstant(link))
            if id and self:IsTracked(id) and self:IsAllowed(id) then
                local tog = self:GetItemToggles(id)
                if tog.buy and Addon.PlayerCanAfford(i) then
                    local r = Addon:GetRank(id)
                    if not bestRank or r < bestRank then
                        bestId, bestIdx, bestRank = id, i, r
                    end
                end
            end
        end
    end
    return bestId, bestIdx
end

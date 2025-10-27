local ADDON_NAME, Addon = ...

-- Robust affordability check (currencyId, currency link, or item costs)
local function PlayerCanAfford(idx)
    local _, _, _, _, numAvailable, isUsable = GetMerchantItemInfo(idx)
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

-- Enumerate vendor items that are tracked (all pages)
function Addon:CollectTrackedMerchantEntries_All()
    local out = {}
    local n = GetMerchantNumItems()
    for i = 1, n do
        local link = GetMerchantItemLink(i)
        if link then
            local id, _, _, _, icon = GetItemInfoInstant(link)
            if id and self:IsTracked(id) and self:IsAllowed(id) then
                local name, _, _, _, numAvailable, isUsable = GetMerchantItemInfo(i)
                out[#out + 1] = {
                    idx = i,
                    itemID = id,
                    icon = icon,
                    name = name or ("item:" .. id),
                    numAvailable = numAvailable,
                    isUsable = isUsable,
                    affordable = PlayerCanAfford(i),
                }
            end
        end
    end
    return out
end

function Addon:VendorHasAnyTracked()
    local n = GetMerchantNumItems()
    for i = 1, n do
        local link = GetMerchantItemLink(i)
        if link then
            local id = select(1, GetItemInfoInstant(link))
            if self:IsTracked(id) then return true end
        end
    end
    return false
end

-- Primary cost key (for grouping in UI)
function Addon:GetPrimaryCostKey(idx)
    local costCount = GetMerchantItemCostInfo(idx) or 0
    for c = 1, costCount do
        local _, costQty, itemLink, _, currencyQty, _, currencyId = GetMerchantItemCostItem(idx, c)
        if currencyId and currencyId > 0 then
            return ("currency:%d"):format(currencyId), currencyId, nil
        elseif type(itemLink) == "string" then
            local curID = itemLink:match("Hcurrency:(%d+)")
            if curID then
                return ("currency:%d"):format(tonumber(curID)), tonumber(curID), nil
            else
                local itemID = select(1, GetItemInfoInstant(itemLink))
                if itemID then
                    return ("item:%d"):format(itemID), nil, itemID
                end
            end
        end
    end
    return "misc", nil, nil
end

-- For Buy 1: pick the single highest-priority affordable item with Buy enabled
function Addon:GetTopAffordableSingle()
    local bestId, bestIdx, bestRank
    local n = GetMerchantNumItems()
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

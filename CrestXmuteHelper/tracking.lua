-- tracking.lua
-- Track set management (seed + user), per-item toggles, and merchant entry collection
local ADDON_NAME, Addon = ...

-- SavedVariables schema:
-- CrestXmuteDB.user.tracked[itemID] = true
-- CrestXmuteDB.user.toggles[itemID] = { buy=true, open=true, confirm=true }
-- CrestXmuteDB.user.row[itemID] = rank (lower = higher priority for drag-to-reorder)
-- CrestXmuteDB.framePos = { point, relName, relPoint, x, y }

-- True if the item is part of the season seed list (always tracked)
function Addon:IsSeedItem(itemID)
    if not itemID or not self.DEFAULT_SEED then return false end
    for _, seedID in ipairs(self.DEFAULT_SEED) do
        if seedID == itemID then return true end
    end
    return false
end

-- Return the user-tracked set (SavedVariables)
function Addon:GetTrackedSet()
    if not CrestXmuteDB or not CrestXmuteDB.user then
        return {}
    end
    return CrestXmuteDB.user.tracked or {}
end

-- union of seed + user
function Addon:GetTrackedUnion()
    local union = {}
    -- Always include seed items, regardless of DB state
    if self.DEFAULT_SEED then
        for _, itemID in ipairs(self.DEFAULT_SEED) do
            union[itemID] = true
        end
    end
    -- Add user-tracked items if DB is initialized
    if CrestXmuteDB and CrestXmuteDB.user and CrestXmuteDB.user.tracked then
        for itemID in pairs(CrestXmuteDB.user.tracked) do
            union[itemID] = true
        end
    end
    return union
end

-- Fire whenever tracked items change so UI + macro stay in sync.
function Addon:TrackedChanged()
    -- Refresh the list UI if it's shown
    if self.Container and self.Container:IsShown() and self.RefreshList then
        self:RefreshList()
    end
    -- Always rebuild the macro so Buy+Open reflects the latest set
    if self.SyncOpenMacro then
        self:SyncOpenMacro(true)
    end
end

-- unified way to get an icon; requests load and lets UI refresh via GET_ITEM_INFO_RECEIVED
function Addon:GetItemIcon(itemID)
    if not itemID then return 134400 end
    local tex = GetItemIcon and GetItemIcon(itemID)
    if not tex then
        local _, _, _, _, _, _, _, _, _, fileID = GetItemInfo(itemID)
        tex = fileID
    end
    if not tex and C_Item and C_Item.RequestLoadItemDataByID then
        C_Item.RequestLoadItemDataByID(itemID)
    end
    return tex or 134400
end

function Addon:GetItemToggles(itemID)
    -- Return per-item toggles; creates defaults if missing
    if not CrestXmuteDB or not CrestXmuteDB.user or not CrestXmuteDB.user.toggles then
        -- Return defaults if DB not initialized yet
        return { buy = true, open = true, confirm = true }
    end
    local t = CrestXmuteDB.user.toggles[itemID]
    if not t then
        t = { buy = true, open = true, confirm = true }
        CrestXmuteDB.user.toggles[itemID] = t
    end
    return t
end

function Addon:AddTracked(itemID)
    -- Add an item ID to the user-tracked set; initializes toggles
    if not itemID then return false end

    -- DB must be initialized by ADDON_LOADED before we can add custom items
    -- Do NOT call EnsureDB here - let ADDON_LOADED do it
    if not CrestXmuteDB or not CrestXmuteDB.user or not CrestXmuteDB.user.tracked then
        return false
    end

    -- Don't re-add if already tracked
    if CrestXmuteDB.user.tracked[itemID] then return false end

    -- Add to tracked set and initialize toggles
    CrestXmuteDB.user.tracked[itemID] = true
    CrestXmuteDB.user.toggles[itemID] = CrestXmuteDB.user.toggles[itemID] or { buy = true, open = true, confirm = true }

    -- Request item data load
    if C_Item and C_Item.RequestLoadItemDataByID then
        C_Item.RequestLoadItemDataByID(itemID)
    end

    -- Rebuild cache if available
    if self.RebuildTrackedCache then
        self:RebuildTrackedCache()
    end

    -- Trigger refresh
    self:TrackedChanged()
    return true
end

function Addon:RemoveTracked(itemID)
    -- Remove an item ID from the user-tracked set and its toggles
    if self:IsSeedItem(itemID) then return false end

    if not CrestXmuteDB or not CrestXmuteDB.user then
        return false
    end

    CrestXmuteDB.user.tracked[itemID] = nil
    CrestXmuteDB.user.toggles[itemID] = nil

    if self.RebuildTrackedCache then
        self:RebuildTrackedCache()
    end

    self:TrackedChanged()
    return true
end

-- helper: can the index be afforded?
function Addon:IsAffordable(idx)
    -- Prefer the merchant-specific affordability logic when available.
    if self.PlayerCanAfford then
        return self.PlayerCanAfford(idx)
    end
    local count = GetMerchantItemCostInfo(idx) or 0
    if count == 0 then return true end
    for c = 1, count do
        local t, id, qty = GetMerchantItemCostItem(idx, c)
        if t == "item" then
            if (GetItemCount(id, true) or 0) < (qty or 1) then return false end
        elseif t == "currency" then
            local info = id and C_CurrencyInfo.GetCurrencyInfo(id)
            if not info or (info.quantity or 0) < (qty or 1) then return false end
        end
    end
    return true
end

-- Build entries for the currently-open merchant from tracked union.
-- Includes affordability and availability flags for UI
function Addon:CollectTrackedMerchantEntries_All()
    local out, tracked = {}, self:GetTrackedUnion()
    local n = GetMerchantNumItems() or 0
    for idx = 1, n do
        local name, _, _, numAvailable, isPurchasable, isUsable = GetMerchantItemInfo(idx)
        if not name then
            -- Invalid merchant item data at this index
            if Addon.Debug and Addon.Debug.DebugPrintCategory then
                Addon.Debug.DebugPrintCategory("merchant", "GetMerchantItemInfo(%d) returned nil name", idx)
            end
        else
            local link = GetMerchantItemLink(idx)
            local itemID
            if link then itemID = select(1, GetItemInfoInstant(link)) end
            if itemID and tracked[itemID] then
                local affordable = (self.PlayerCanAfford and self.PlayerCanAfford(idx)) or self:IsAffordable(idx)
                table.insert(out, {
                    idx = idx,
                    itemID = itemID,
                    name = name or ("item:" .. itemID),
                    icon = Addon:GetItemIcon(itemID),
                    numAvailable = numAvailable,
                    isPurchasable = isPurchasable,
                    isUsable = isUsable,
                    affordable = affordable,
                })
            end
        end
    end
    return out
end

function Addon:DumpTracked()
    -- Print the set of tracked items (seed + user) for debugging
    local u = self:GetTrackedUnion()
    print("|cffffd200CrestXmute tracked items (seed + user):|r")
    local count = 0
    for id in pairs(u) do
        local name = GetItemInfo(id) or ("item:" .. id)
        local isSeed = self:IsSeedItem(id)
        print(string.format("  [%d] %s%s", id, name, isSeed and " (seed)" or ""))
        count = count + 1
    end
    if count == 0 then
        print("  (none)")
    end
end

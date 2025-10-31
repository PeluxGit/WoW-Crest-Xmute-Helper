-- tracking.lua
-- Track set management (seed + user), per-item toggles, and merchant entry collection
local ADDON_NAME, Addon = ...

-- SavedVariables schema:
-- CrestXmuteDB.user.tracked[itemID] = true
-- CrestXmuteDB.user.toggles[itemID] = { buy=true, open=true, confirm=true }
-- CrestXmuteDB.user.row[itemID] = rank (lower = higher priority for drag-to-reorder)
-- CrestXmuteDB.framePos = { point, relName, relPoint, x, y }

-- Ensure DB structure exists (safety check for direct SavedVariables access)
local function ensureDB()
    CrestXmuteDB = CrestXmuteDB or {}
    CrestXmuteDB.user = CrestXmuteDB.user or {}
    CrestXmuteDB.user.tracked = CrestXmuteDB.user.tracked or {}
    CrestXmuteDB.user.toggles = CrestXmuteDB.user.toggles or {}
end

-- True if the item is part of the season seed list (always tracked)
function Addon:IsSeedItem(itemID)
    return self.DEFAULT_SEED and self.DEFAULT_SEED[itemID] or false
end

-- Return the user-tracked set (SavedVariables)
function Addon:GetTrackedSet()
    ensureDB()
    return CrestXmuteDB.user.tracked
end

-- union of seed + user
function Addon:GetTrackedUnion()
    ensureDB()
    local union = {}
    if self.DEFAULT_SEED then
        for itemID in pairs(self.DEFAULT_SEED) do
            union[itemID] = true
        end
    end
    for itemID in pairs(CrestXmuteDB.user.tracked) do
        union[itemID] = true
    end
    return union
end

-- Fire whenever tracked items change so UI + macro stay in sync.
function Addon:TrackedChanged()
    -- Refresh the list UI if it’s visible
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
    ensureDB()
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
    ensureDB()
    if CrestXmuteDB.user.tracked[itemID] then return false end
    CrestXmuteDB.user.tracked[itemID] = true
    CrestXmuteDB.user.toggles[itemID] = CrestXmuteDB.user.toggles[itemID] or { buy = true, open = true, confirm = true }
    if C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(itemID) end
    if self.RebuildTrackedCache then self:RebuildTrackedCache() end
    self:TrackedChanged()
    return true
end

function Addon:RemoveTracked(itemID)
    -- Remove an item ID from the user-tracked set and its toggles
    ensureDB()
    if self:IsSeedItem(itemID) then return false end
    CrestXmuteDB.user.tracked[itemID] = nil
    CrestXmuteDB.user.toggles[itemID] = nil
    if self.RebuildTrackedCache then self:RebuildTrackedCache() end
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
    return out
end

function Addon:DumpTracked()
    -- Print the set of tracked items (seed + user) for debugging
    local u = self:GetTrackedUnion()
    print("|cffffd200CrestXmute tracked items (seed + user):|r")
    local count = 0
    for id in pairs(u) do
        local name = GetItemInfo(id) or ("item:" .. id)
        local isSeed = self.DEFAULT_SEED and self.DEFAULT_SEED[id]
        print(("  - %s (%d)%s"):format(name, id, isSeed and "  |cff8888ff[seed]|r" or ""))
        count = count + 1
    end
    if count == 0 then
        print("  (none)")
    end
end

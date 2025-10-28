local ADDON_NAME, Addon = ...

-- SavedVariables layout:
-- CrestXmuteDB.user.tracked[itemID] = true
-- CrestXmuteDB.user.toggles[itemID] = { buy=true, open=true, confirm=true }

local function ensureDB()
    CrestXmuteDB = CrestXmuteDB or {}
    CrestXmuteDB.user = CrestXmuteDB.user or {}
    CrestXmuteDB.user.tracked = CrestXmuteDB.user.tracked or {}
    CrestXmuteDB.user.toggles = CrestXmuteDB.user.toggles or {}
end

function Addon:IsSeedItem(itemID)
    return self.DEFAULT_SEED and self.DEFAULT_SEED[itemID] or false
end

function Addon:GetTrackedSet()
    ensureDB()
    return CrestXmuteDB.user.tracked
end

-- Union of DEFAULT_SEED and user.tracked (used by UI/vendor scan)
function Addon:GetTrackedUnion()
    ensureDB()
    local u = {}
    if self.DEFAULT_SEED then
        for id in pairs(self.DEFAULT_SEED) do u[id] = true end
    end
    for id in pairs(CrestXmuteDB.user.tracked) do u[id] = true end
    return u
end

function Addon:GetItemToggles(itemID)
    ensureDB()
    local t = CrestXmuteDB.user.toggles[itemID]
    if not t then
        t = { buy = true, open = true, confirm = true }
        CrestXmuteDB.user.toggles[itemID] = t
    end
    return t
end

function Addon:AddTracked(itemID)
    if not itemID then return false end
    ensureDB()
    local set = CrestXmuteDB.user.tracked
    if set[itemID] then return false end
    set[itemID] = true
    CrestXmuteDB.user.toggles[itemID] = CrestXmuteDB.user.toggles[itemID] or { buy = true, open = true, confirm = true }
    if self.RebuildTrackedCache then self:RebuildTrackedCache() end
    return true
end

function Addon:RemoveTracked(itemID)
    ensureDB()
    if self:IsSeedItem(itemID) then return false end
    CrestXmuteDB.user.tracked[itemID] = nil
    CrestXmuteDB.user.toggles[itemID] = nil
    if self.RebuildTrackedCache then self:RebuildTrackedCache() end
    return true
end

-- Build vendor entries for *currently open* merchant using the tracked union.
function Addon:CollectTrackedMerchantEntries_All()
    local out, tracked = {}, self:GetTrackedUnion()
    local n = GetMerchantNumItems()
    for idx = 1, n do
        local name, _, _, numAvailable, isUsable = GetMerchantItemInfo(idx)
        local link = GetMerchantItemLink(idx)
        local itemID, icon
        if link then
            -- safe multi-assign
            local i, _, _, _, _, _, _, _, _, ic = GetItemInfoInstant(link)
            itemID, icon = i, ic
        end
        if itemID and tracked[itemID] then
            table.insert(out, {
                idx = idx,
                itemID = itemID,
                name = name or ("item:" .. itemID),
                icon = icon,
                numAvailable = numAvailable,
                isUsable = isUsable,
                affordable = Addon.IsAffordable and Addon:IsAffordable(idx) or true,
            })
        end
    end
    return out
end

function Addon:DumpTracked()
    local u = self:GetTrackedUnion()
    print("|cffffd200CrestXmute tracked items (seed + user):|r")
    local any = false
    for id in pairs(u) do
        any = true
        local name = GetItemInfo(id) or ("item:" .. id)
        local isSeed = self.DEFAULT_SEED and self.DEFAULT_SEED[id]
        print(("  - %s (%d)%s"):format(name, id, isSeed and "  |cff8888ff[seed]|r" or ""))
    end
    if not any then
        print("  (none)")
    end
end

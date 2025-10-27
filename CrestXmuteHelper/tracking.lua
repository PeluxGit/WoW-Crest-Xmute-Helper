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
    -- default toggles for new entries
    CrestXmuteDB.user.toggles[itemID] = CrestXmuteDB.user.toggles[itemID] or { buy = true, open = true, confirm = true }
    if self.RebuildTrackedCache then self:RebuildTrackedCache() end
    return true
end

function Addon:RemoveTracked(itemID)
    ensureDB()
    if self:IsSeedItem(itemID) then return false end
    local set = CrestXmuteDB.user.tracked
    set[itemID] = nil
    CrestXmuteDB.user.toggles[itemID] = nil
    if self.RebuildTrackedCache then self:RebuildTrackedCache() end
    return true
end

function Addon:DumpTracked()
    ensureDB()
    print("|cffffd200CrestXmute tracked items:|r")
    for id in pairs(CrestXmuteDB.user.tracked) do
        local name = GetItemInfo(id) or ("item:" .. id)
        print(("  - %s (%d)"):format(name, id))
    end
end

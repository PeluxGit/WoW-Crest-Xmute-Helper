-- core.lua
-- Core addon namespace, DB schema, defaults, and shared helpers
local ADDON_NAME, Addon = ...
if not Addon then
    Addon = {}; _G[ADDON_NAME] = Addon
end

-- SavedVariables (CrestXmuteDB will be initialized by WoW before ADDON_LOADED fires)
-- Do NOT reference it here or it may interfere with WoW's loading mechanism

-- Initialize debug system from saved state
function Addon:EnsureDebug()
    if self.InitDebug then
        self:InitDebug()
    end
end

-- ==== Season seed ====
-- Replace these IDs when a new season starts (crest pack/container IDs)
Addon.DEFAULT_SEED = {
    240931,
    240930,
    240929,
}

-- Defaults + schema (all user data under .user)
function Addon:EnsureDB()
    -- Initialize CrestXmuteDB if it doesn't exist (first run)
    CrestXmuteDB = CrestXmuteDB or {}
    CrestXmuteDB.user = CrestXmuteDB.user or {}
    local u = CrestXmuteDB.user
    u.tracked = u.tracked or {}   -- user tracked set [itemID]=true
    u.selected = u.selected or {} -- per-item enable (nil/true=enabled, false=disabled)
    u.row = u.row or {}           -- row order: [itemID]=rank (lower = higher)
    u.toggles = u.toggles or {}   -- per-item toggles: [itemID] = {buy=true, open=true, confirm=true}

    -- Settings
    CrestXmuteDB.framePos = CrestXmuteDB.framePos or nil -- window position
end

function Addon:IsSeeded(id)
    if not id or not self.DEFAULT_SEED then return false end
    for _, seedID in ipairs(self.DEFAULT_SEED) do
        if seedID == id then return true end
    end
    return false
end

function Addon:IsUser(id)
    if not CrestXmuteDB or not CrestXmuteDB.user or not CrestXmuteDB.user.tracked then
        return false
    end
    return CrestXmuteDB.user.tracked[id] == true
end

-- Tracked if seeded or user-added
function Addon:IsTracked(id) return id and (self:IsSeeded(id) or self:IsUser(id)) or false end

-- Enabled if not explicitly disabled
function Addon:IsAllowed(id)
    if not CrestXmuteDB or not CrestXmuteDB.user or not CrestXmuteDB.user.selected then
        return true -- Default to enabled if DB not initialized
    end
    local v = CrestXmuteDB.user.selected[id]
    return (v == nil) or (v == true)
end

-- Priority rank: lower value = higher priority. Default large to push to bottom.
function Addon:GetRank(id)
    if not CrestXmuteDB or not CrestXmuteDB.user or not CrestXmuteDB.user.row then
        return 1e9 -- Default rank if DB not initialized
    end
    local r = CrestXmuteDB.user.row[id]
    return (r ~= nil) and r or 1e9
end

-- Set rank and normalize ranks to 1..N compactly
function Addon:SetRankOrder(orderList)
    -- orderList: array of itemIDs in desired top->bottom order
    for i, id in ipairs(orderList) do
        CrestXmuteDB.user.row[id] = i
    end
end

-- Utility: parse ID from link or numeric string
function Addon:ItemIDFromLinkOrID(s)
    if not s or s == "" then return nil end
    s = s:gsub("^%s+", ""):gsub("%s+$", "")
    local n = tonumber(s); if n then return n end
    return select(1, GetItemInfoInstant(s))
end

-- Utility: get 1st currencyId (or itemID if item-cost) for grouping key; also returns currency/item link icon & name
-- NOTE: This groups by the first cost line only for UI; affordability always checks all cost lines.
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

-- Public init
function Addon:Init()
    self:EnsureDB()
end

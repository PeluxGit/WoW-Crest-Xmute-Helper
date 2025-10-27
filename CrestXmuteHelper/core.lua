local ADDON_NAME, Addon = ...
if not Addon then Addon = {}; _G[ADDON_NAME] = Addon end

-- SavedVariables
CrestXmuteDB = CrestXmuteDB or {}

-- ==== Season seed ====
-- Replace these IDs when a new season starts (crest pack/container IDs)
Addon.DEFAULT_SEED = {
    [240931] = true, -- Example: Aspect’s Crest Pack
    [240930] = true, -- Example: Wyrm’s Crest Pack
    [240929] = true, -- Example: Drake’s Crest Pack
}

-- Defaults + schema
function Addon:EnsureDB()
    local db = CrestXmuteDB
    db.items = db.items or {}           -- user tracked set [itemID]=true
    db.selected = db.selected or {}     -- per-item enable (nil/true=enabled, false=disabled)
    db.row = db.row or {}               -- row order: [itemID]=rank (lower = higher)
    db.toggles = db.toggles or {}       -- per-item toggles: [itemID] = {buy=true, open=true, confirm=true}
    db.buyMode = db.buyMode or "one"    -- "one" or "all"
    if db.autoConfirm == nil then db.autoConfirm = true end
    if db.openEnabled == nil then db.openEnabled = true end
    db.framePos = db.framePos or nil
end

function Addon:IsSeeded(id) return self.DEFAULT_SEED[id] == true end
function Addon:IsUser(id)   return CrestXmuteDB.items[id] == true end

-- Tracked if seeded or user-added
function Addon:IsTracked(id) return id and (self:IsSeeded(id) or self:IsUser(id)) or false end

-- Enabled if not explicitly disabled
function Addon:IsAllowed(id)
    local v = CrestXmuteDB.selected[id]
    return (v == nil) or (v == true)
end

-- Get per-item toggles with defaults
function Addon:GetItemToggles(id)
    local t = CrestXmuteDB.toggles[id]
    if not t then
        t = { buy = true, open = true, confirm = true }
        CrestXmuteDB.toggles[id] = t
    end
    return t
end

-- Priority rank: lower value = higher priority. Default large to push to bottom.
function Addon:GetRank(id)
    local r = CrestXmuteDB.row[id]
    return (r ~= nil) and r or 1e9
end

-- Set rank and normalize ranks to 1..N compactly
function Addon:SetRankOrder(orderList)
    -- orderList: array of itemIDs in desired top->bottom order
    for i, id in ipairs(orderList) do
        CrestXmuteDB.row[id] = i
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

function Addon:DebugPrint(...)
    if self.DEBUG then print("|cff88ccffCrestXmute:", ...) end
end

-- Public init
function Addon:Init()
    self:EnsureDB()
end

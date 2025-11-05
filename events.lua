-- events.lua
-- Central event hub for showing/hiding UI and refreshing data
local ADDON_NAME, Addon = ...

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("MERCHANT_SHOW")
f:RegisterEvent("MERCHANT_UPDATE")
f:RegisterEvent("MERCHANT_CLOSED")
f:RegisterEvent("GET_ITEM_INFO_RECEIVED")
f:RegisterEvent("BAG_UPDATE_DELAYED")

-- simple throttle so we don't spam refreshes
local nextRefreshAt = 0
local function ThrottledRefresh()
    if not Addon.Container or not Addon.Container:IsShown() then return end
    local now = GetTime()
    if now < nextRefreshAt then return end
    nextRefreshAt = now + 0.05
    Addon:RefreshList()
end

-- Debounce timer for BAG_UPDATE_DELAYED to prevent race conditions
local bagUpdateTimer = nil
local function DebouncedBagUpdate()
    if bagUpdateTimer then
        bagUpdateTimer:Cancel()
    end
    bagUpdateTimer = C_Timer.NewTimer(0.1, function()
        if Addon.Container and Addon.Container:IsShown() then
            -- Sync macro to reflect current bag state
            if Addon.SyncOpenMacro then
                Addon:SyncOpenMacro(true)
            end
            -- Refresh the UI to update affordability/counts
            ThrottledRefresh()
        end
        bagUpdateTimer = nil
    end)
end

local function IsTrackedItemID(itemID)
    if not itemID then return false end
    local u = Addon.GetTrackedUnion and Addon:GetTrackedUnion() or {}
    return u[itemID] and true or false
end

-- Request item data for all visible merchant entries to avoid nil icons/names
function Addon:PreloadMerchantItemData()
    local n = GetMerchantNumItems() or 0
    for i = 1, n do
        local link = GetMerchantItemLink(i)
        local itemID = link and select(1, GetItemInfoInstant(link)) or nil
        if itemID and C_Item and C_Item.RequestLoadItemDataByID then
            C_Item.RequestLoadItemDataByID(itemID)
        end
    end
end

-- true if current merchant sells any tracked item (seed + user)
function Addon:MerchantHasTracked()
    if not MerchantFrame or not MerchantFrame:IsShown() then return false end
    local tracked = Addon.GetTrackedUnion and Addon:GetTrackedUnion() or {}
    local n = GetMerchantNumItems() or 0
    for i = 1, n do
        local link = GetMerchantItemLink(i)
        if link then
            local itemID = select(1, GetItemInfoInstant(link))
            if itemID and tracked[itemID] then
                return true
            end
        end
    end
    return false
end

-- Main event dispatch: controls when UI appears and when we refresh
f:SetScript("OnEvent", function(self, event, arg1, arg2)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        if Addon.Init then Addon:Init() end
        if Addon.EnsureDebug then Addon:EnsureDebug() end
        self:UnregisterEvent("ADDON_LOADED")
        return
    end

    if event == "MERCHANT_SHOW" then
        -- Small delay (30ms) to let item data populate from server before scanning
        C_Timer.After(0.03, function()
            Addon:PreloadMerchantItemData()
            if Addon:MerchantHasTracked() then
                Addon:ShowUIForMerchant()
            else
                Addon:HideUI()
            end
        end)
        return
    end

    if event == "MERCHANT_UPDATE" then
        -- show/hide depending on tracked availability
        Addon:PreloadMerchantItemData()
        if Addon:MerchantHasTracked() then
            if not (Addon.Container and Addon.Container:IsShown()) then
                Addon:ShowUIForMerchant()
                return
            end
            ThrottledRefresh()
            -- Sync macro after merchant update (e.g., after buying an item)
            if Addon.SyncOpenMacro then
                Addon:SyncOpenMacro(true)
            end
        else
            Addon:HideUI()
        end
        return
    end

    if event == "MERCHANT_CLOSED" then
        Addon:HideUI()
        return
    end

    if event == "GET_ITEM_INFO_RECEIVED" then
        -- when an icon/name resolves, refresh once
        local itemID = arg1
        if Addon.Container and Addon.Container:IsShown() and IsTrackedItemID(itemID) then
            ThrottledRefresh()
        end
        return
    end

    if event == "BAG_UPDATE_DELAYED" then
        -- Bag contents changed (items added/removed/used)
        -- Only sync macro and refresh UI if window is open
        -- Use debounce to prevent race conditions from rapid bag updates
        DebouncedBagUpdate()
        return
    end
end)

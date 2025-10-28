local ADDON_NAME, Addon = ...

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("MERCHANT_SHOW")
f:RegisterEvent("MERCHANT_UPDATE")
f:RegisterEvent("MERCHANT_CLOSED")
f:RegisterEvent("GET_ITEM_INFO_RECEIVED")

-- simple throttle so we don't spam refreshes
local nextRefreshAt = 0
local function ThrottledRefresh()
    if not Addon.Container or not Addon.Container:IsShown() then return end
    local now = GetTime()
    if now < nextRefreshAt then return end
    nextRefreshAt = now + 0.05
    Addon:RefreshList()
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

f:SetScript("OnEvent", function(self, event, arg1, arg2)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        if Addon.Init then Addon:Init() end
        self:UnregisterEvent("ADDON_LOADED")
        return
    end

    if event == "MERCHANT_SHOW" then
        -- tiny delay to let item data populate
        C_Timer.After(0.03, function()
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
        if Addon:MerchantHasTracked() then
            if not (Addon.Container and Addon.Container:IsShown()) then
                Addon:ShowUIForMerchant()
                return
            end
            ThrottledRefresh()
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
        ThrottledRefresh()
        return
    end
end)

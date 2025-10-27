local ADDON_NAME, Addon = ...

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("MERCHANT_SHOW")
f:RegisterEvent("MERCHANT_UPDATE")
f:RegisterEvent("MERCHANT_CLOSED")
f:RegisterEvent("BAG_UPDATE_DELAYED")
f:RegisterEvent("GET_ITEM_INFO_RECEIVED")

local function SafeSync()
    if Addon and Addon.SyncOpenMacro then
        Addon:SyncOpenMacro(false)
    end
end

f:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        if Addon.Init then Addon:Init() end
    elseif event == "MERCHANT_SHOW" then
        if Addon:VendorHasAnyTracked() then
            Addon:ShowUIForMerchant()
            SafeSync()
        else
            Addon:HideUI()
        end
    elseif event == "MERCHANT_UPDATE" then
        if Addon:VendorHasAnyTracked() then
            Addon:ShowUIForMerchant()
            SafeSync()
        else
            Addon:HideUI()
        end
    elseif event == "MERCHANT_CLOSED" then
        Addon:HideUI()
    elseif event == "BAG_UPDATE_DELAYED" then
        if Addon.Container and Addon.Container:IsShown() then
            SafeSync()
            Addon:RefreshList()
        end
    elseif event == "GET_ITEM_INFO_RECEIVED" then
        if Addon.Container and Addon.Container:IsShown() then
            C_Timer.After(0, function() Addon:RefreshList() end)
        end
    end
end)

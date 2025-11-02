-- slash.lua
-- Slash command handlers (/cxh)
local ADDON_NAME, Addon = ...

SLASH_CRESTXMUTE1 = "/cxh"
SlashCmdList.CRESTXMUTE = function(msg)
    local cmd, rest = msg:match("^(%S+)%s*(.-)$")
    cmd = cmd and cmd:lower() or ""

    if cmd == "add" and rest and rest ~= "" then
        local itemID = select(1, GetItemInfoInstant(rest)) or tonumber(rest)
        if itemID and Addon.AddTracked and Addon:AddTracked(itemID) then
            local name = GetItemInfo(itemID) or ("item:" .. itemID)
            print("|cff33ff99CrestXmute: Added|r " .. name)
            if Addon.TrackedChanged then Addon:TrackedChanged() end
        else
            print("|cffff6600CrestXmute: Could not add that item.|r")
        end
    elseif cmd == "list" then
        if Addon.DumpTracked then Addon:DumpTracked() end
    elseif cmd == "debug" then
        local arg = (rest or ""):lower()
        if arg == "on" then
            if Addon.SetDebug then Addon:SetDebug(true) end
        elseif arg == "off" then
            if Addon.SetDebug then Addon:SetDebug(false) end
        elseif arg == "status" then
            local state = (Addon and Addon:IsDebug() and "enabled") or "disabled"
            print("|cffffd200CrestXmute: Debug " .. state .. "|r")
        elseif arg == "" then
            -- No argument = toggle
            if Addon.SetDebug and Addon.IsDebug then Addon:SetDebug(not Addon:IsDebug()) end
        else
            print("|cffffd200CrestXmute|r usage: /cxh debug [on|off|status]")
        end
    elseif cmd == "show" or cmd == "open" then
        if Addon.ShowUIForMerchant then
            Addon:ShowUIForMerchant()
        end
    elseif cmd == "reset" then
        -- Reset window position
        CrestXmuteDB = CrestXmuteDB or {}
        CrestXmuteDB.framePos = nil
        print("|cff33ff99CrestXmute:|r Window position reset. It will reposition next time you open a merchant.")
        -- If the window is currently open, reposition it now
        if Addon.Container and Addon.Container:IsShown() then
            Addon.Container:ClearAllPoints()
            if MerchantFrame and MerchantFrame:IsShown() then
                Addon.Container:SetPoint("LEFT", MerchantFrame, "RIGHT", 8, 0)
            else
                Addon.Container:SetPoint("CENTER", UIParent, "CENTER")
            end
            print("|cff33ff99CrestXmute:|r Window repositioned.")
        end
    else
        print("|cffffd200CrestXmute|r commands:")
        print("  /cxh add <itemLink|itemID>")
        print("  /cxh list")
        print("  /cxh debug [on|off|status]  (no arg = toggle)")
        print("  /cxh show")
        print("  /cxh reset - Reset window position")
    end
end

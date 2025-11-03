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
            CrestXmuteDB = CrestXmuteDB or {}; CrestXmuteDB.debug = CrestXmuteDB.debug or {}
            CrestXmuteDB.debug.enabled = true
            if Addon.PrintDebugStatus then Addon:PrintDebugStatus() else print("|cffffd200CrestXmute: Debug enabled|r") end
        elseif arg == "off" then
            CrestXmuteDB = CrestXmuteDB or {}; CrestXmuteDB.debug = CrestXmuteDB.debug or {}
            CrestXmuteDB.debug.enabled = false
            if Addon.PrintDebugStatus then Addon:PrintDebugStatus() else print("|cffffd200CrestXmute: Debug disabled|r") end
        elseif arg == "status" then
            if Addon.PrintDebugStatus then
                Addon:PrintDebugStatus()
            else
                local state = (Addon and Addon:IsDebug() and "enabled") or "disabled"
                print("|cffffd200CrestXmute: Debug " .. state .. "|r")
            end
        elseif arg == "help" then
            if Addon.PrintDebugHelp then
                Addon:PrintDebugHelp()
            else
                print("|cffffd200CrestXmute|r usage: /cxh debug [on|off|status|help|<category>]")
            end
        elseif arg == "" then
            -- No argument = toggle master debug
            if Addon.ToggleDebug then
                Addon:ToggleDebug()
            elseif Addon.SetDebug and Addon.IsDebug then
                Addon:SetDebug(not Addon:IsDebug())
            end
        else
            -- Category-specific toggle
            if Addon.ToggleDebug then
                Addon:ToggleDebug(arg)
            else
                print("|cffffd200CrestXmute|r usage: /cxh debug [on|off|status|help|<category>]")
            end
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
        print("  /cxh debug [on|off|status|help|<category>]")
        print("  /cxh show")
        print("  /cxh reset - Reset window position")
    end
end

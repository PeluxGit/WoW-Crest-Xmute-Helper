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
    else
        print("|cffffd200CrestXmute|r commands:")
        print("  /cxh add <itemLink|itemID>")
        print("  /cxh list")
        print("  /cxh debug [on|off|status]  (no arg = toggle)")
        print("  /cxh show")
    end
end

local ADDON_NAME, Addon = ...

SLASH_CRESTXMUTE1 = "/crestx"
SlashCmdList.CRESTXMUTE = function(msg)
    local cmd, rest = msg:match("^(%S+)%s*(.-)$")
    cmd = cmd and cmd:lower() or ""

    if cmd == "add" and rest and rest ~= "" then
        local itemID = select(1, GetItemInfoInstant(rest)) or tonumber(rest)
        if itemID and Addon.AddTracked and Addon:AddTracked(itemID) then
            print("|cff33ff99CrestXmute: added|r", GetItemInfo(itemID) or ("item:" .. itemID))
            if Addon.TrackedChanged then Addon:TrackedChanged() end
        else
            print("|cffff6600CrestXmute: could not add that item.|r")
        end
    elseif cmd == "list" then
        if Addon.DumpTracked then Addon:DumpTracked() end
    else
        print("|cffffd200CrestXmute|r commands:")
        print("  /crestx add <itemLink|itemID>")
        print("  /crestx list")
    end
end

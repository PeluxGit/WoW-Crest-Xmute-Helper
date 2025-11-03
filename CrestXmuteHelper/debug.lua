-- debug.lua
-- Debug system with per-feature toggles and persistent state
local ADDON_NAME, Addon = ...

-- Default debug flags (can be overridden by saved variables)
local DEFAULT_DEBUG = {
    enabled = false,     -- Master debug toggle
    positioning = false, -- Log positioning calculations
    events = false,      -- Log event handling
    merchant = false,    -- Log merchant interactions
    bags = false,        -- Log bag scanning
    macro = false,       -- Log macro updates
    tracking = false,    -- Log item tracking changes
    ui = false,          -- Log UI operations
    skin = false,        -- Force default skin (disable custom skins like ElvUI)
}

-- Initialize debug state (called after SavedVariables are loaded)
function Addon:InitDebug()
    -- Merge saved debug state with defaults
    CrestXmuteDB = CrestXmuteDB or {}
    CrestXmuteDB.debug = CrestXmuteDB.debug or {}

    -- Apply defaults for any missing keys
    for key, value in pairs(DEFAULT_DEBUG) do
        if CrestXmuteDB.debug[key] == nil then
            CrestXmuteDB.debug[key] = value
        end
    end

    self.DEBUG = CrestXmuteDB.debug.enabled
end

-- Check if a specific debug category is enabled
function Addon:IsDebugEnabled(category)
    if not CrestXmuteDB or not CrestXmuteDB.debug then return false end
    if not CrestXmuteDB.debug.enabled then return false end
    if category then
        return CrestXmuteDB.debug[category] == true
    end
    return true
end

-- Print debug message for a specific category
function Addon:DebugPrint(...)
    if not self:IsDebugEnabled() then return end
    print("|cff00ff00[CrestXmute]|r", ...)
end

function Addon:DebugPrintCategory(category, ...)
    if not self:IsDebugEnabled(category) then return end
    print("|cff00ff00[CrestXmute:" .. category .. "]|r", ...)
end

-- Toggle debug for a category
function Addon:ToggleDebug(category)
    CrestXmuteDB = CrestXmuteDB or {}
    CrestXmuteDB.debug = CrestXmuteDB.debug or {}

    if category == "all" or not category then
        CrestXmuteDB.debug.enabled = not CrestXmuteDB.debug.enabled
        self.DEBUG = CrestXmuteDB.debug.enabled
        print("|cff00ff00[CrestXmute]|r Debug mode:",
            CrestXmuteDB.debug.enabled and "|cff00ff00ENABLED|r" or "|cffff0000DISABLED|r")
    elseif DEFAULT_DEBUG[category] ~= nil then
        CrestXmuteDB.debug[category] = not CrestXmuteDB.debug[category]
        print("|cff00ff00[CrestXmute]|r Debug category '" .. category .. "':",
            CrestXmuteDB.debug[category] and "|cff00ff00ENABLED|r" or "|cffff0000DISABLED|r")
    else
        print("|cffff0000[CrestXmute]|r Unknown debug category:", category)
        self:PrintDebugHelp()
    end
end

-- Print debug status
function Addon:PrintDebugStatus()
    if not CrestXmuteDB or not CrestXmuteDB.debug then
        print("|cff00ff00[CrestXmute]|r Debug not initialized")
        return
    end

    print("|cff00ff00[CrestXmute]|r Debug Status:")
    print("  Master:", CrestXmuteDB.debug.enabled and "|cff00ff00ON|r" or "|cffff0000OFF|r")

    if CrestXmuteDB.debug.enabled then
        for key, value in pairs(CrestXmuteDB.debug) do
            if key ~= "enabled" then
                print("  " .. key .. ":", value and "|cff00ff00ON|r" or "|cffff0000OFF|r")
            end
        end
    end
end

-- Print debug help
function Addon:PrintDebugHelp()
    print("|cff00ff00[CrestXmute]|r Debug Commands:")
    print("  /cxh debug - Toggle master debug")
    print("  /cxh debug <category> - Toggle specific category")
    print("  /cxh debug status - Show current debug state")
    print("")
    print("Available categories:")
    for key in pairs(DEFAULT_DEBUG) do
        if key ~= "enabled" then
            print("  " .. key)
        end
    end
end

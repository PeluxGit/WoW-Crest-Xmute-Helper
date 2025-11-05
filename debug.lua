-- debug.lua
-- Debug system with per-feature toggles and persistent state
local ADDON_NAME, Addon = ...

-- Default debug flags (can be overridden by saved variables)
local DEFAULT_DEBUG = {
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
end

-- Check if a specific debug category is enabled
function Addon:IsDebugEnabled(category)
    if not CrestXmuteDB or not CrestXmuteDB.debug then return false end
    if not category then return false end
    return CrestXmuteDB.debug[category] == true
end

-- Print debug message for a specific category
-- Internal helper to safely format messages; falls back to concatenation on format errors
local function SafeFormat(fmt, ...)
    if type(fmt) ~= "string" then
        return tostring(fmt)
    end
    local argc = select('#', ...)
    if argc == 0 then
        return fmt
    end
    local ok, msg = pcall(string.format, fmt, ...)
    if ok then return msg end
    -- Fallback: concatenate args space-separated
    local parts = { fmt }
    for i = 1, argc do
        parts[#parts + 1] = tostring(select(i, ...))
    end
    return table.concat(parts, " ")
end

function Addon:DebugPrintCategory(category, fmt, ...)
    if not self:IsDebugEnabled(category) then return end
    print("|cff00ff00[CrestXmute:" .. category .. "]|r", SafeFormat(fmt, ...))
end

-- Toggle debug for a category
function Addon:ToggleDebug(category)
    CrestXmuteDB = CrestXmuteDB or {}
    CrestXmuteDB.debug = CrestXmuteDB.debug or {}

    if not category or category == "" then
        -- No category = show help
        self:PrintDebugHelp()
        return
    end

    if DEFAULT_DEBUG[category] ~= nil then
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
    local hasEnabled = false
    for key, value in pairs(CrestXmuteDB.debug) do
        if value then
            print("  " .. key .. ": |cff00ff00ON|r")
            hasEnabled = true
        end
    end

    if not hasEnabled then
        print("  All categories: |cffff0000OFF|r")
    end
end

-- Print debug help
function Addon:PrintDebugHelp()
    print("|cff00ff00[CrestXmute]|r Debug Commands:")
    print("  |cffffd200/cxh debug|r - Show this help")
    print("  |cffffd200/cxh debug <category>|r - Toggle specific category")
    print("  |cffffd200/cxh debug status|r - Show current debug state")
    print("")
    print("Available categories:")
    for key in pairs(DEFAULT_DEBUG) do
        local desc = ""
        if key == "positioning" then
            desc = " - Log positioning calculations"
        elseif key == "events" then
            desc = " - Log event handling"
        elseif key == "merchant" then
            desc = " - Log merchant interactions"
        elseif key == "bags" then
            desc = " - Log bag scanning"
        elseif key == "macro" then
            desc = " - Log macro updates"
        elseif key == "tracking" then
            desc = " - Log item tracking changes"
        elseif key == "ui" then
            desc = " - Log UI operations"
        elseif key == "skin" then
            desc = " - Force default skin (disable ElvUI)"
        end
        print("  |cffffd200" .. key .. "|r" .. desc)
    end
end

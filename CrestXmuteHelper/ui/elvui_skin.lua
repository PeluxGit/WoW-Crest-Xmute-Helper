-- ui/elvui_skin.lua
-- ElvUI skin integration for Crest Xmute Helper
local ADDON_NAME, Addon = ...

-- ElvUI-specific scale multipliers (relative to base UI constants)
local ELVUI_ADDMODE_SCALE_MULT = 0.83  -- Add Mode checkbox: 0.75 / 0.9 base
local ELVUI_CHECKBOX_SCALE_MULT = 0.86 -- Row checkboxes: 0.6 / 0.7 base

local function ApplyElvUISkin()
    -- Check if ElvUI is available
    if not ElvUI then return end

    -- Check if custom skinning is disabled via debug flag (forces default skin)
    if Addon.IsDebugEnabled and Addon:IsDebugEnabled("skin") then
        if Addon.DebugPrintCategory then
            Addon:DebugPrintCategory("ui", "Custom skinning disabled via debug flag - using default skin")
        end
        return
    end

    local E, L, V, P, G = unpack(ElvUI)
    if not E then return end

    local S = E:GetModule("Skins")
    if not S then return end

    local UI = Addon.UI or {}

    local function SkinContainer()
        local container = Addon.Container
        if not container then return end
        if container._elvuiSkinned then return end

        -- Skin the main frame
        if S.HandleFrame then
            S:HandleFrame(container, false, true)
        end

        -- Skin the scroll frame and scrollbar
        if container.Scroll then
            if S.HandleScrollBar then
                S:HandleScrollBar(container.Scroll.ScrollBar)
            end
        end

        -- Skin the macro button and restore its icon texture
        if container.MacroBtn then
            if S.HandleButton then
                S:HandleButton(container.MacroBtn)
            end
            -- ElvUI's HandleButton may strip the icon, so reapply it
            local iconTexture = container.MacroBtn:GetNormalTexture()
            if iconTexture then
                iconTexture:SetTexture("Interface\\Icons\\INV_Misc_Bag_10_Black")
                iconTexture:SetTexCoord(0.08, 0.92, 0.08, 0.92) -- Crop edges for cleaner look
                iconTexture:ClearAllPoints()
                iconTexture:SetPoint("TOPLEFT", 2, -2)
                iconTexture:SetPoint("BOTTOMRIGHT", -2, 2)
            end
        end

        -- Skin the Add Mode checkbox and make it smaller
        if container.AddModeBtn then
            if S.HandleCheckBox then
                S:HandleCheckBox(container.AddModeBtn)
            end
            -- Scale down for ElvUI relative to base ADDMODE_SCALE
            local baseScale = UI.ADDMODE_SCALE or 0.9
            container.AddModeBtn:SetScale(baseScale * ELVUI_ADDMODE_SCALE_MULT)
        end

        -- Store the effective checkbox scale for positioning calculations
        local baseCheckboxScale = UI.CHECKBOX_SCALE or 0.7
        container._effectiveCheckboxScale = baseCheckboxScale * ELVUI_CHECKBOX_SCALE_MULT

        container._elvuiSkinned = true
    end

    local function SkinRows()
        local container = Addon.Container
        if not container or not container.Content or not container.Content.cells then return end

        -- Skin checkboxes in rows (checkboxes are recreated each refresh, so always skin)
        for _, cell in ipairs(container.Content.cells) do
            -- Check if this is a row with checkboxes (not a header)
            if cell.buy then
                if S.HandleCheckBox and not cell.buy._elvuiSkinned then
                    S:HandleCheckBox(cell.buy)
                    -- Scale down row checkboxes for ElvUI relative to base CHECKBOX_SCALE
                    local baseScale = UI.CHECKBOX_SCALE or 0.7
                    cell.buy:SetScale(baseScale * ELVUI_CHECKBOX_SCALE_MULT)
                    cell.buy._elvuiSkinned = true
                end
            end
            if cell.open then
                if S.HandleCheckBox and not cell.open._elvuiSkinned then
                    S:HandleCheckBox(cell.open)
                    -- Scale down row checkboxes for ElvUI relative to base CHECKBOX_SCALE
                    local baseScale = UI.CHECKBOX_SCALE or 0.7
                    cell.open:SetScale(baseScale * ELVUI_CHECKBOX_SCALE_MULT)
                    cell.open._elvuiSkinned = true
                end
            end
            if cell.conf then
                if S.HandleCheckBox and not cell.conf._elvuiSkinned then
                    S:HandleCheckBox(cell.conf)
                    -- Scale down row checkboxes for ElvUI relative to base CHECKBOX_SCALE
                    local baseScale = UI.CHECKBOX_SCALE or 0.7
                    cell.conf:SetScale(baseScale * ELVUI_CHECKBOX_SCALE_MULT)
                    cell.conf._elvuiSkinned = true
                end
            end
            if cell.remove then
                if S.HandleCloseButton and not cell.remove._elvuiSkinned then
                    S:HandleCloseButton(cell.remove)
                    cell.remove._elvuiSkinned = true
                end
            end
        end
    end

    -- Hook EnsureUI to skin when the container is created
    if type(Addon.EnsureUI) == "function" then
        hooksecurefunc(Addon, "EnsureUI", function()
            SkinContainer()
        end)
    end

    -- Hook RefreshList to skin new rows (wrap in timer to ensure rows exist)
    if type(Addon.RefreshList) == "function" then
        hooksecurefunc(Addon, "RefreshList", function()
            -- Small delay to ensure rows are fully created before skinning
            C_Timer.After(0.01, function()
                SkinRows()
            end)
        end)
    end

    -- Skin if container already exists
    if Addon.Container then
        SkinContainer()
        SkinRows()
    end
end

-- Wait for ElvUI to be fully loaded
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self, event)
    -- Give ElvUI a moment to initialize
    C_Timer.After(0.5, ApplyElvUISkin)
    self:UnregisterEvent("PLAYER_LOGIN")
end)

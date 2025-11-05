-- ui/elvui_skin.lua
-- ElvUI skin integration for Crest Xmute Helper
local ADDON_NAME, Addon = ...
-- WoW API globals referenced in this module (accessed via _G for static analysis friendliness)
local _G = _G
local hooksecurefunc = _G.hooksecurefunc
---@diagnostic disable-next-line: undefined-field
local ElvUI = _G.ElvUI
local unpack = _G.unpack

-- ElvUI-specific scale multipliers (relative to base UI constants)
local ELVUI_ADDMODE_SCALE_MULT = 0.83  -- Add Mode checkbox: 0.75 / 0.9 base
local ELVUI_CHECKBOX_SCALE_MULT = 0.86 -- Row checkboxes: 0.6 / 0.7 base

-- ElvUI styling constants
local ELVUI_ICON_CROP = { 0.08, 0.92, 0.08, 0.92 } -- Icon crop coords for square appearance
local ELVUI_HOVER_COLOR = { 0.2, 0.2, 0.2 }        -- Lighter color for checkbox hover
local ELVUI_BACKDROP_FALLBACK = { 0.1, 0.1, 0.1 }  -- Fallback if E.media.backdropcolor unavailable

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

    local function AddCheckboxHoverEffect(checkbox)
        if not checkbox or not checkbox.backdrop then return end

        -- Store original colors
        local backdropColor = E.media.backdropcolor or ELVUI_BACKDROP_FALLBACK
        local hoverColor = ELVUI_HOVER_COLOR -- Lighter on hover

        checkbox:HookScript("OnEnter", function(self)
            if self.backdrop and not self:GetChecked() then
                self.backdrop:SetBackdropColor(hoverColor[1], hoverColor[2], hoverColor[3], 1)
            end
        end)

        checkbox:HookScript("OnLeave", function(self)
            if self.backdrop and not self:GetChecked() then
                self.backdrop:SetBackdropColor(backdropColor[1], backdropColor[2], backdropColor[3],
                    backdropColor[4] or 1)
            end
        end)
    end

    local function SkinContainer()
        local container = Addon.Container
        if not container then return end
        if container._elvuiSkinned then return end

        -- Skin the main frame (with error handling)
        if S and S.HandleFrame then
            local success, err = pcall(S.HandleFrame, S, container, false, true)
            if not success then
                print("|cffff0000[CrestXmute]|r ElvUI HandleFrame failed:", err)
            end
        end
        -- Apply ElvUI's Transparent template to match their style (reduced opacity backdrop)
        if container.SetTemplate then
            local success, err = pcall(container.SetTemplate, container, "Transparent")
            if not success then
                print("|cffff0000[CrestXmute]|r ElvUI SetTemplate failed:", err)
            end
        end
        -- Ensure we use ElvUI's configured fade/backdrop colors (less opaque than Default)
        if E and E.media then
            local fade = E.media.backdropfadecolor or { 0.06, 0.06, 0.06, 0.8 }
            local brdr = E.media.bordercolor or { 0, 0, 0 }
            if container.SetBackdropColor then
                container:SetBackdropColor(fade[1], fade[2], fade[3], fade[4] or 0.8)
            end
            if container.SetBackdropBorderColor then
                container:SetBackdropBorderColor(brdr[1], brdr[2], brdr[3], 1)
            end
            if container.backdrop then
                if container.backdrop.SetBackdropColor then
                    container.backdrop:SetBackdropColor(fade[1], fade[2], fade[3], fade[4] or 0.8)
                end
                if container.backdrop.SetBackdropBorderColor then
                    container.backdrop:SetBackdropBorderColor(brdr[1], brdr[2], brdr[3], 1)
                end
            end
        end

        -- Skin the scroll frame and scrollbar
        if container.Scroll then
            if S and S.HandleScrollBar and container.Scroll.ScrollBar then
                local success, err = pcall(S.HandleScrollBar, S, container.Scroll.ScrollBar)
                if not success then
                    print("|cffff0000[CrestXmute]|r ElvUI HandleScrollBar failed:", err)
                end
            end
            -- If ElvUI template helpers exist, apply Transparent to scroll container too
            if container.Scroll.SetTemplate then
                local success, err = pcall(container.Scroll.SetTemplate, container.Scroll, "Transparent")
                if not success then
                    print("|cffff0000[CrestXmute]|r ElvUI SetTemplate on scroll failed:", err)
                end
            end
        end

        -- Skin the macro button and restore its icon texture
        if container.MacroBtn then
            if S and S.HandleButton then
                local success, err = pcall(S.HandleButton, S, container.MacroBtn)
                if not success then
                    print("|cffff0000[CrestXmute]|r ElvUI HandleButton failed:", err)
                end
            end
            -- ElvUI's HandleButton may strip the icon, so reapply it
            local iconTexture = container.MacroBtn:GetNormalTexture()
            if iconTexture then
                iconTexture:SetTexture("Interface\\Icons\\INV_Misc_Bag_10_Black")
                iconTexture:SetTexCoord(ELVUI_ICON_CROP[1], ELVUI_ICON_CROP[2], ELVUI_ICON_CROP[3], ELVUI_ICON_CROP[4]) -- Crop edges for cleaner look
                iconTexture:ClearAllPoints()
                iconTexture:SetPoint("TOPLEFT", 2, -2)
                iconTexture:SetPoint("BOTTOMRIGHT", -2, 2)
            end
        end

        -- Skin the Add Mode checkbox and make it smaller
        if container.AddModeBtn then
            if S and S.HandleCheckBox then
                local success, err = pcall(S.HandleCheckBox, S, container.AddModeBtn)
                if not success then
                    print("|cffff0000[CrestXmute]|r ElvUI HandleCheckBox (AddMode) failed:", err)
                end
            end
            -- Scale down for ElvUI relative to base ADDMODE_SCALE
            local baseScale = UI.ADDMODE_SCALE or 0.9
            container.AddModeBtn:SetScale(baseScale * ELVUI_ADDMODE_SCALE_MULT)
            -- Only set background color for unchecked state
            if container.AddModeBtn.backdrop then
                local backdropColor = E.media.backdropcolor or ELVUI_BACKDROP_FALLBACK
                container.AddModeBtn.backdrop:SetBackdropColor(backdropColor[1], backdropColor[2], backdropColor[3],
                    backdropColor[4] or 1)
            end
            -- Add hover effect
            AddCheckboxHoverEffect(container.AddModeBtn)
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
            -- Apply perfect square cropping to item icons (ElvUI style)
            if cell.icon and not cell.icon._elvuiCropped then
                cell.icon:SetTexCoord(ELVUI_ICON_CROP[1], ELVUI_ICON_CROP[2], ELVUI_ICON_CROP[3], ELVUI_ICON_CROP[4])
                cell.icon._elvuiCropped = true
            end

            -- Check if this is a row with checkboxes (not a header)
            if cell.buy then
                if S and S.HandleCheckBox and not cell.buy._elvuiSkinned then
                    local success, err = pcall(S.HandleCheckBox, S, cell.buy)
                    if not success then
                        print("|cffff0000[CrestXmute]|r ElvUI HandleCheckBox (buy) failed:", err)
                    else
                        -- Scale down row checkboxes for ElvUI relative to base CHECKBOX_SCALE
                        local baseScale = UI.CHECKBOX_SCALE or 0.7
                        cell.buy:SetScale(baseScale * ELVUI_CHECKBOX_SCALE_MULT)
                        -- Only set background color for unchecked state
                        if cell.buy.backdrop then
                            local backdropColor = E.media.backdropcolor or ELVUI_BACKDROP_FALLBACK
                            cell.buy.backdrop:SetBackdropColor(backdropColor[1], backdropColor[2], backdropColor[3],
                                backdropColor[4] or 1)
                        end
                        -- Add hover effect
                        AddCheckboxHoverEffect(cell.buy)
                        cell.buy._elvuiSkinned = true
                    end
                end
            end
            if cell.open then
                if S and S.HandleCheckBox and not cell.open._elvuiSkinned then
                    local success, err = pcall(S.HandleCheckBox, S, cell.open)
                    if not success then
                        print("|cffff0000[CrestXmute]|r ElvUI HandleCheckBox (open) failed:", err)
                    else
                        -- Scale down row checkboxes for ElvUI relative to base CHECKBOX_SCALE
                        local baseScale = UI.CHECKBOX_SCALE or 0.7
                        cell.open:SetScale(baseScale * ELVUI_CHECKBOX_SCALE_MULT)
                        -- Only set background color for unchecked state
                        if cell.open.backdrop then
                            local backdropColor = E.media.backdropcolor or ELVUI_BACKDROP_FALLBACK
                            cell.open.backdrop:SetBackdropColor(backdropColor[1], backdropColor[2], backdropColor[3],
                                backdropColor[4] or 1)
                        end
                        -- Add hover effect
                        AddCheckboxHoverEffect(cell.open)
                        cell.open._elvuiSkinned = true
                    end
                end
            end
            if cell.conf then
                if S and S.HandleCheckBox and not cell.conf._elvuiSkinned then
                    local success, err = pcall(S.HandleCheckBox, S, cell.conf)
                    if not success then
                        print("|cffff0000[CrestXmute]|r ElvUI HandleCheckBox (conf) failed:", err)
                    else
                        -- Scale down row checkboxes for ElvUI relative to base CHECKBOX_SCALE
                        local baseScale = UI.CHECKBOX_SCALE or 0.7
                        cell.conf:SetScale(baseScale * ELVUI_CHECKBOX_SCALE_MULT)
                        -- Only set background color for unchecked state
                        if cell.conf.backdrop then
                            local backdropColor = E.media.backdropcolor or ELVUI_BACKDROP_FALLBACK
                            cell.conf.backdrop:SetBackdropColor(backdropColor[1], backdropColor[2], backdropColor[3],
                                backdropColor[4] or 1)
                        end
                        -- Add hover effect
                        AddCheckboxHoverEffect(cell.conf)
                        cell.conf._elvuiSkinned = true
                    end
                end
            end
            if cell.remove then
                if S and S.HandleCloseButton and not cell.remove._elvuiSkinned then
                    local success, err = pcall(S.HandleCloseButton, S, cell.remove)
                    if not success then
                        print("|cffff0000[CrestXmute]|r ElvUI HandleCloseButton (remove) failed:", err)
                    else
                        cell.remove._elvuiSkinned = true
                    end
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

    -- Hook RefreshList to skin new rows
    if type(Addon.RefreshList) == "function" then
        hooksecurefunc(Addon, "RefreshList", function()
            SkinRows()
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

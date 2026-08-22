-- ui/ellesmere_skin.lua
-- EllesmereUI skin integration for Crest Xmute Helper
local ADDON_NAME, Addon = ...
-- WoW API globals referenced in this module (accessed via _G for static analysis friendliness)
local _G = _G
local hooksecurefunc = _G.hooksecurefunc
---@diagnostic disable-next-line: undefined-field
local PixelUtil = _G.PixelUtil
---@diagnostic disable-next-line: undefined-field
local EllesmereUI = _G.EllesmereUI

-- Nothing to do if EllesmereUI isn't installed or predates the skinning API
if not (EllesmereUI and EllesmereUI.RegisterSkin) then return end

local UI = Addon.UI or {}

-- Multipliers on top of the base UI scale constants
local EUI_CHECKBOX_SCALE_MULT = 0.7
local EUI_ADDMODE_SCALE_MULT = 0.7

-- Gap (px) between the checked-state accent fill and the checkbox border
local EUI_CHECK_INSET = 2.5

-- Translucent border, matching EllesmereUI's own checkbox style
local EUI_BORDER_COLOR = { 1, 1, 1, 0.35 }

-- Translucent fill, same technique, paler than S.GetPanelColor()
local EUI_CHECKBOX_BG = { 1, 1, 1, 0.1 }

-- Set when EllesmereUI's skin callback fires
local S

-- Static labels only; forces white
local function FontWhite(fs)
    if not S or not fs then return end
    if S.Font then S.Font(fs) end
    if S.White then S.White(fs) end
end

-- Leaves dynamically-set colors alone (row names, hints)
local function FontOnly(fs)
    if not S or not fs then return end
    if S.Font then S.Font(fs) end
end

-- 1px pixel-snapped hairline along one edge (top or bottom)
local function AnchorHorizontalHairline(tex, checkbox, corner1, corner2)
    if PixelUtil and PixelUtil.SetPoint then
        PixelUtil.SetPoint(tex, corner1, checkbox, corner1, 0, 0)
        PixelUtil.SetPoint(tex, corner2, checkbox, corner2, 0, 0)
        PixelUtil.SetHeight(tex, 1)
    else
        tex:SetPoint(corner1, checkbox, corner1, 0, 0)
        tex:SetPoint(corner2, checkbox, corner2, 0, 0)
        tex:SetHeight(1)
    end
end

-- Inset 1px so corners don't double-overlap the horizontal hairlines
local function AnchorVerticalHairline(tex, checkbox, topCorner, bottomCorner)
    if PixelUtil and PixelUtil.SetPoint then
        PixelUtil.SetPoint(tex, topCorner, checkbox, topCorner, 0, -1)
        PixelUtil.SetPoint(tex, bottomCorner, checkbox, bottomCorner, 0, 1)
        PixelUtil.SetWidth(tex, 1)
    else
        tex:SetPoint(topCorner, checkbox, topCorner, 0, -1)
        tex:SetPoint(bottomCorner, checkbox, bottomCorner, 0, 1)
        tex:SetWidth(tex, 1)
    end
end

-- Draws box/border manually; S.Checkbox()'s own border is opaque and too thick here
local function FlattenCheckbox(checkbox)
    if not S or not checkbox then return end

    for _, getter in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture", "GetDisabledTexture" }) do
        local tex = checkbox[getter] and checkbox[getter](checkbox)
        if tex then tex:SetTexture(nil) end
    end

    if not checkbox._cxhBg then
        checkbox._cxhBg = checkbox:CreateTexture(nil, "BACKGROUND")
        checkbox._cxhBg:SetAllPoints(checkbox)
    end
    checkbox._cxhBg:SetColorTexture(EUI_CHECKBOX_BG[1], EUI_CHECKBOX_BG[2], EUI_CHECKBOX_BG[3], EUI_CHECKBOX_BG[4])

    if not checkbox._cxhBorder then
        checkbox._cxhBorder = {
            top = checkbox:CreateTexture(nil, "ARTWORK"),
            bottom = checkbox:CreateTexture(nil, "ARTWORK"),
            left = checkbox:CreateTexture(nil, "ARTWORK"),
            right = checkbox:CreateTexture(nil, "ARTWORK"),
        }
        local edges = checkbox._cxhBorder
        AnchorHorizontalHairline(edges.top, checkbox, "TOPLEFT", "TOPRIGHT")
        AnchorHorizontalHairline(edges.bottom, checkbox, "BOTTOMLEFT", "BOTTOMRIGHT")
        AnchorVerticalHairline(edges.left, checkbox, "TOPLEFT", "BOTTOMLEFT")
        AnchorVerticalHairline(edges.right, checkbox, "TOPRIGHT", "BOTTOMRIGHT")
    end
    for _, edge in pairs(checkbox._cxhBorder) do
        edge:SetColorTexture(EUI_BORDER_COLOR[1], EUI_BORDER_COLOR[2], EUI_BORDER_COLOR[3], EUI_BORDER_COLOR[4])
    end

    local checked = checkbox.GetCheckedTexture and checkbox:GetCheckedTexture()
    if not checked then return end

    local r, g, b = 1, 1, 1
    if S.GetAccentColor then
        r, g, b = S.GetAccentColor()
    end
    checked:SetTexture(nil)
    checked:SetColorTexture(r, g, b, 1)
    checked:ClearAllPoints()
    if PixelUtil and PixelUtil.SetPoint then
        PixelUtil.SetPoint(checked, "TOPLEFT", checkbox, "TOPLEFT", EUI_CHECK_INSET, -EUI_CHECK_INSET)
        PixelUtil.SetPoint(checked, "BOTTOMRIGHT", checkbox, "BOTTOMRIGHT", -EUI_CHECK_INSET, EUI_CHECK_INSET)
    else
        checked:SetPoint("TOPLEFT", checkbox, "TOPLEFT", EUI_CHECK_INSET, -EUI_CHECK_INSET)
        checked:SetPoint("BOTTOMRIGHT", checkbox, "BOTTOMRIGHT", -EUI_CHECK_INSET, EUI_CHECK_INSET)
    end
end

local function SkinContainer()
    local container = Addon.Container
    if not S or not container then return end

    -- We render our own title/Add Mode row, so skip EUI's title strip
    S.Shell(container, { noTopBar = true })

    if container.AddModeBtn then
        FlattenCheckbox(container.AddModeBtn)
        FontWhite(container.AddModeBtn.Label)
        if UI.SetScaledSize then
            UI.SetScaledSize(container.AddModeBtn, (UI.ADDMODE_SCALE or 1) * EUI_ADDMODE_SCALE_MULT)
        end
    end

    -- Read by list.lua's acquireRow when (re)sizing row checkboxes
    container._effectiveCheckboxScale = (UI.CHECKBOX_SCALE or 1) * EUI_CHECKBOX_SCALE_MULT

    if container.Scroll and container.Scroll.ScrollBar then
        S.ScrollBar(container.Scroll.ScrollBar)
    end

    FontWhite(container.Title)
    FontWhite(container.Header)
    FontWhite(container._hdrBuy)
    FontWhite(container._hdrOpen)
    FontWhite(container._hdrConf)
    FontOnly(container.EmptyState)
end

local function SkinMacroActionButton()
    local button = Addon.MacroActionButton
    if not S or not button then return end

    S.Button(button, { "icon", "NormalTexture", "SlotBackground" })
    if button.icon then
        S.SquareIcon(button.icon)
    end
end

local function SkinRows()
    local container = Addon.Container
    if not S or not container or not container.Content or not container.Content.cells then return end

    for _, cell in ipairs(container.Content.cells) do
        if cell.icon then S.SquareIcon(cell.icon) end
        if cell.buy then FlattenCheckbox(cell.buy) end
        if cell.open then FlattenCheckbox(cell.open) end
        if cell.conf then FlattenCheckbox(cell.conf) end
        if cell.remove then S.CloseButton(cell.remove) end
        if cell.name then FontOnly(cell.name) end
        if cell.text then FontWhite(cell.text) end
    end
end

EllesmereUI.RegisterSkin(ADDON_NAME, function(skin)
    if Addon.IsDebugEnabled and Addon:IsDebugEnabled("skin") then
        if Addon.DebugPrintCategory then
            Addon:DebugPrintCategory("ui", "Custom skinning disabled via debug flag - using default skin")
        end
        return
    end

    S = skin

    if type(Addon.EnsureUI) == "function" then
        hooksecurefunc(Addon, "EnsureUI", SkinContainer)
    end
    if type(Addon.RefreshList) == "function" then
        hooksecurefunc(Addon, "RefreshList", SkinRows)
    end
    if type(Addon.CreateMacroActionButton) == "function" then
        hooksecurefunc(Addon, "CreateMacroActionButton", SkinMacroActionButton)
    end

    -- Not primitive-driven; needs a manual re-skin on live accent/theme changes
    if S.OnLooksChanged then
        S.OnLooksChanged(function()
            SkinContainer()
            SkinRows()
        end)
    end

    SkinContainer()
    SkinRows()
    SkinMacroActionButton()
end)

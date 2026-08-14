-- ui/ellesmere_skin.lua
-- EllesmereUI skin integration for Crest Xmute Helper
local ADDON_NAME, Addon = ...
-- WoW API globals referenced in this module (accessed via _G for static analysis friendliness)
local _G = _G
local hooksecurefunc = _G.hooksecurefunc
---@diagnostic disable-next-line: undefined-field
local EllesmereUI = _G.EllesmereUI

-- Nothing to do if EllesmereUI isn't installed or predates the skinning API
if not (EllesmereUI and EllesmereUI.RegisterSkin) then return end

local UI = Addon.UI or {}

-- EllesmereUI-specific scale multipliers (relative to base UI constants) --
-- the flat filled-square toggle style reads visually larger than Blizzard's
-- thin-bordered checkbox at the same pixel size, so shrink it down.
local EUI_CHECKBOX_SCALE_MULT = 0.7
local EUI_ADDMODE_SCALE_MULT = 0.7

-- Gap (px) between the checked-state accent fill and the checkbox border
local EUI_CHECK_INSET = 3

-- Set once EllesmereUI invokes our registered callback; primitives are idempotent
-- so it's safe to call them again from refresh hooks once this is populated.
local S

-- Re-font to the user's chosen EUI font, forcing white (used for static
-- header/label text where we don't manage a custom color ourselves).
local function FontWhite(fs)
    if not S or not fs then return end
    if S.Font then S.Font(fs) end
    if S.White then S.White(fs) end
end

-- Re-font only, leaving color alone (used where we set the color dynamically,
-- e.g. row names that shift between gold/grey, or dimmed hint text).
local function FontOnly(fs)
    if not S or not fs then return end
    if S.Font then S.Font(fs) end
end

-- S.Checkbox() only skins the box/border and leaves Blizzard's own gold
-- checkmark glyph alone, and its default box fill renders solid black
-- rather than EUI's actual grey panel fill. We want the flat "hollow
-- square / solid-filled square" toggle style used elsewhere in EUI's QoL
-- addons instead of a checkmark glyph, so:
--   - draw our own BACKGROUND-layer fill using the house panel color,
--     flush with the border (this sits under S.Checkbox's border art
--     since it's created after, on the same draw layer)
--   - replace the checked-texture with a plain accent-color fill, inset
--     further than the panel fill so the border stays visible when on
-- stockCheck=true tells EUI not to touch the check texture itself, since
-- we're fully replacing it. Re-read colors every call (rather than caching
-- them) so S.OnLooksChanged-driven re-skins stay live.
local function FlattenCheckbox(checkbox)
    if not S or not checkbox then return end
    S.Checkbox(checkbox, { stockCheck = true })

    -- Blizzard's own unchecked-state art (UICheckButtonTemplate's
    -- NormalTexture: a silver-framed, black-inset square) draws above our
    -- background fill and was still showing through, which is the "black
    -- box" that persisted after the panel-color fix. Clear it.
    if checkbox.SetNormalTexture then
        checkbox:SetNormalTexture(nil)
    end

    if not checkbox._cxhBg then
        checkbox._cxhBg = checkbox:CreateTexture(nil, "BACKGROUND")
        checkbox._cxhBg:SetAllPoints(checkbox)
    end
    local pr, pg, pb, pa = 0.16, 0.16, 0.16, 1
    if S.GetPanelColor then
        pr, pg, pb, pa = S.GetPanelColor()
    end
    checkbox._cxhBg:SetColorTexture(pr, pg, pb, pa or 1)

    local checked = checkbox.GetCheckedTexture and checkbox:GetCheckedTexture()
    if not checked then return end

    local r, g, b = 1, 1, 1
    if S.GetAccentColor then
        r, g, b = S.GetAccentColor()
    end
    checked:SetTexture(nil)
    checked:SetColorTexture(r, g, b, 1)
    checked:ClearAllPoints()
    checked:SetPoint("TOPLEFT", EUI_CHECK_INSET, -EUI_CHECK_INSET)
    checked:SetPoint("BOTTOMRIGHT", -EUI_CHECK_INSET, EUI_CHECK_INSET)
end

local function SkinContainer()
    local container = Addon.Container
    if not S or not container then return end

    -- We already render our own title/Add Mode/macro button row up top, so
    -- skip EUI's own title strip to avoid it overlapping that row.
    S.Shell(container, { noTopBar = true })

    if container.AddModeBtn then
        FlattenCheckbox(container.AddModeBtn)
        FontWhite(container.AddModeBtn.Label)
        if UI.SetScaledSize then
            UI.SetScaledSize(container.AddModeBtn, (UI.ADDMODE_SCALE or 1) * EUI_ADDMODE_SCALE_MULT)
        end
    end

    -- Row checkboxes read this when they're (re)sized in list.lua's acquireRow
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
        if cell.name then FontOnly(cell.name) end   -- row item name (color set dynamically elsewhere)
        if cell.text then FontWhite(cell.text) end  -- currency/item group divider label
    end
end

EllesmereUI.RegisterSkin(ADDON_NAME, function(skin)
    -- Check if custom skinning is disabled via debug flag (forces default skin)
    if Addon.IsDebugEnabled and Addon:IsDebugEnabled("skin") then
        if Addon.DebugPrintCategory then
            Addon:DebugPrintCategory("ui", "Custom skinning disabled via debug flag - using default skin")
        end
        return
    end

    S = skin

    -- Hook EnsureUI to skin the container when it's created
    if type(Addon.EnsureUI) == "function" then
        hooksecurefunc(Addon, "EnsureUI", SkinContainer)
    end

    -- Hook RefreshList to skin rows as they're (re)built
    if type(Addon.RefreshList) == "function" then
        hooksecurefunc(Addon, "RefreshList", SkinRows)
    end

    if type(Addon.CreateMacroActionButton) == "function" then
        hooksecurefunc(Addon, "CreateMacroActionButton", SkinMacroActionButton)
    end

    -- Re-flatten checkboxes (our own S.GetAccentColor() fill, not a
    -- primitive) if the user changes their EUI accent color live.
    if S.OnLooksChanged then
        S.OnLooksChanged(function()
            SkinContainer()
            SkinRows()
        end)
    end

    -- Skin anything that already exists
    SkinContainer()
    SkinRows()
    SkinMacroActionButton()
end)

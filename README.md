# Crest Xmute Helper

A World of Warcraft retail addon that streamlines crest transmutation by automating vendor purchases and container opening through a unified macro.

![Version](https://img.shields.io/badge/version-1.0-blue)
![WoW](https://img.shields.io/badge/WoW-Retail-orange)
![License](https://img.shields.io/badge/license-MIT-green)

## Features

- **One-Click Automation**: Single macro to buy vendor items and open crest containers
- **Smart Priority System**: Drag-to-reorder items to control purchase priority
- **Multi-Currency Groups**: Automatically groups items by currency type and buys one from each group
- **Flexible Toggles**: Per-item control for Buy, Open, and Confirm actions
- **Add Mode**: Click merchant items directly to track them
- **Scroll-Optimized UI**: Always-visible buttons with intelligent scrollbar handling
- **Drag & Drop**: Create your character macro by dragging the action button to your action bar

## Installation

1. Download or clone this repository
2. Copy the `CrestXmuteHelper` folder into your WoW AddOns directory:
   - **Windows**: `World of Warcraft\_retail_\Interface\AddOns\`
   - **Mac**: `World of Warcraft\_retail_/Interface/AddOns/`
3. Restart WoW or type `/reload` in-game

## Usage

### Basic Workflow

1. **Open a vendor** that sells crest items (e.g., transmutation vendors)
2. **The panel appears** automatically if the vendor sells any tracked items
3. **Configure your items**:
   - **Buy** - Include in vendor purchase snippet
   - **Open** - Include in bag opening `/use` commands
   - **Confirm** - Auto-click the purchase confirmation popup
4. **Use the macro**:
   - Drag the "Buy / Open" button from the panel to your action bar
   - Or use the character macro named `CrestX-Open`
   - Press repeatedly to buy and open items

### Slash Commands

```
/cxh add <itemLink|itemID>  - Add an item to tracking
/cxh list                    - Print all tracked items
/cxh show                    - Show the panel (if hidden)
/cxh debug [on|off|status]   - Toggle debug logging (or set explicitly)
```

### Priority & Ordering

**Drag items** to reorder them. Higher items have higher priority:

- When multiple items use the same currency, only the top affordable item is purchased
- Items in your bags are opened in the displayed order

### Add Mode

Toggle **Add Mode** in the panel header to click merchant items directly to add them to your tracked list. Useful for discovering new items quickly.

## How It Works

### Macro Composition

The addon builds a macro (max 255 characters) with:

1. **Buy snippet**: Compact Lua to purchase the top-priority affordable item(s)
2. **Confirm click** (optional): Auto-accept the purchase dialog
3. **Open commands**: `/use item:<id>` lines for tracked containers in your bags

### Smart Grouping

Items are grouped by their **primary cost currency** (e.g., Resonance Crystals, Valorstones):

- One item per group is highlighted as the "top candidate"
- Ensures you don't blow all your currency on a single item type

### UI Layout

- **Always-reserved scrollbar space**: Buttons never shift when scrolling appears
- **Scale-aware positioning**: Works with any UI scale setting
- **Immediate drag response**: No delay when reordering items
- **Tooltips everywhere**: Hover icons, names, or drag handles to see item info

## Configuration

All settings are saved per-character in `CrestXmuteDB`:

- Tracked items (user additions + season seed)
- Per-item toggles (buy/open/confirm)
- Row ordering (priority ranks)
- Window position

### Season Updates

Edit `core.lua` to update the seed list when a new season starts:

```lua
Addon.DEFAULT_SEED = {
    [240931] = true, -- New season crest pack ID
    [240930] = true, -- Another crest pack
}
```

## Known Limitations

- **Macro length**: Game limit is 255 characters. If you track many items, some `/use` lines may be truncated.
- **Combat lockdown**: Macro and UI updates are blocked during combat.
- **Retail only**: Uses retail API functions (C_Container, C_CurrencyInfo). Not compatible with Classic.

## Troubleshooting

### Panel doesn't appear at vendor

- Try `/cxh show` to force it open
- Ensure the vendor sells at least one tracked item
- Check if you accidentally closed the merchant frame

### Macro doesn't work as expected

- Open the Macro UI (`/macro`) and check the `CrestX-Open` macro body
- Enable debug logging with `/cxh debug on` and watch chat for errors
- Verify items are affordable and toggles are enabled

### Items not showing in list

- Use `/cxh list` to see all tracked items
- Add items manually with `/cxh add <itemID>`
- Check if the vendor is actually selling the item (not all vendors carry everything)

## Development

### Project Structure

```
CrestXmuteHelper/
├── core.lua           - Addon namespace, DB schema, helpers
├── events.lua         - Event handling and UI visibility gating
├── tracking.lua       - Tracked set management and toggles
├── merchant.lua       - Affordability checks and merchant scanning
├── bags.lua           - Bag scanning for owned items
├── macro.lua          - Macro building and syncing
├── slash.lua          - Slash command handlers
└── ui/
    ├── layout.lua     - Shared UI constants and helpers
    ├── panel.lua      - Main container and window management
    └── list.lua       - Row rendering and scroll layout
```

### Key Concepts

- **Tracked Union**: Seed items (always tracked) + user-added items
- **Rank System**: Lower rank = higher priority (set via drag-to-reorder)
- **Top Candidate**: One item per currency group that will be purchased
- **Scrollbar Reserve**: Always reserve space for scrollbar to prevent layout shift

### Running Tests

No automated tests currently. Manual testing workflow:

1. Install addon in `_retail_/Interface/AddOns/`
2. Run `/reload` to pick up changes
3. Visit transmutation vendor to test UI
4. Enable debug mode: `/cxh debug on`

### Making Changes

- **UI constants**: Edit `ui/layout.lua`
- **Event timing**: Adjust delays in `events.lua` (0.03s for item data loading)
- **Macro body limit**: Modify `MAX_BODY` in `macro.lua` (game enforces 255)
- **Debug output**: Use `Addon:DebugPrint(...)` for conditional logging

## Contributing

Contributions are welcome! Please:

1. Test changes in-game before submitting
2. Follow existing code style (2-space indents, descriptive names)
3. Add comments for complex logic
4. Update this README if adding features

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Credits

Created for World of Warcraft retail (Dragonflight/The War Within era).

---

**Tip**: Bind the macro to a convenient key and spam it while talking to your vendor for maximum efficiency! ⚡

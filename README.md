# CrestXmute Helper

WoW addon that automates crest transmutation with a single macro.

## What It Does

Dynamically updates a macro with your next action (buy or open), so you can spam one button to automate crest transmutation. Can be expanded with custom items from any vendor.

## Installation

1. Extract to `World of Warcraft\_retail_\Interface\AddOns\`
2. `/reload` in-game

## Usage - Crest Transmutation

**Basic workflow for transmutation vendors:**

1. Visit a transmutation vendor (panel appears automatically)
2. Click macro button (top-right) to pick up the macro
3. Place macro on action bar
4. Spam the macro

The addon tracks crest containers automatically. Configure Buy/Open/Confirm toggles if needed (all on by default).

## Add Your Own Items

**To track custom items from other vendors:**

1. Visit any vendor
2. Use `/cxh show` to open the panel
3. Enable "Add Mode" toggle in panel
4. Click items at vendor to add them to tracking
5. Disable "Add Mode"
6. Configure Buy/Open/Confirm toggles and drag to reorder priority
7. Spam the macro as normal

Works with any vendor items, not just crests.

> **⚠️ Warning:** The "Open" feature uses items immediately without confirmation. It is intended for containers that most users will want to open immediately (ex.: Crest transmutation packs or Delver's Pouches).

## How It Works

Generates a macro (`CrestX-Open` in General tab) that performs one action per click:

1. **Opens one container** - If you have a tracked container in bags with "Open" enabled, uses it
2. **OR buys one item** - If at a vendor, buys the highest priority affordable item with "Buy" enabled
3. **Confirms purchase** - Dismisses confirmation dialog if "Confirm" is enabled

**One Action Per Click:**

- The macro can only execute one action (open OR buy) per click due to WoW limitations
- **Color coding shows what will happen next:**
  - **Blue highlight** = Next click will buy this item
  - **Gold highlight** = Next click will open this item
  - **Teal highlight** = Next click could do either (both actions available)
- This is why you spam the macro - each click processes the next available action

**Priority-Based Purchases:**

- The macro buys the highest priority item you can afford from the current vendor
- **Drag items to reorder** within each currency group to set priority
- **Currency-aware grouping** - Items are grouped by their purchase currency; priority only matters within the same currency
- If multiple currencies are available at a vendor, only items from one currency group will be purchased per click
- Example: If tracking both Weathered and Carved crests at a transmutation vendor, the macro will only buy from whichever currency group has the highest priority item you can afford

## Commands

Edit `core.lua` to update tracked items:

```lua
Addon.DEFAULT_SEED = {
    240931, -- Item ID
    240930, -- Item ID
}
```

## License

MIT

# CrestXmute Helper

WoW addon that automates crest transmutation with a single macro.

## What It Does

Dynamically updates a macro with your next action (buy and/or open), so you can spam one button to automate crest transmutation. Can be expanded with custom items from any vendor.

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

The addon creates a macro (`CrestX-Open` in the General tab) that you can place on your action bar. Click the macro pickup button (top-right of the panel) to grab it.

The macro can do up to two things per click:

1. **Open one container** – If you have a tracked container in bags with "Open" enabled, it uses it first
2. **Then buy one item** – If you're at a vendor, it buys the highest priority affordable item with "Buy" enabled
3. **Confirm purchase** – Dismisses the confirmation dialog if "Confirm" is enabled

**Per-click behavior:**

- On each click, the macro attempts to open one tracked container first, then buy one item if possible
- **Row highlighting shows what will happen on the next click:**
  - **Blue highlight** = Will buy (no container to open)
  - **Gold highlight** = Will open (no affordable/eligible buy)
  - **Teal highlight** = Will open and then buy (both actions available)
- Spam the macro to process multiple opens/buys over successive clicks

**Priority-Based Purchases:**

- The macro buys the highest priority item you can afford from the current vendor
- **Drag items to reorder** within each currency group to set priority
- **Currency-aware grouping** - Items are grouped by their purchase currency; priority only matters within the same currency
- If multiple currencies are available at a vendor, only one currency group will be purchased from per click
- Example: Tracking both Weathered and Carved crests at a transmutation vendor will only buy from one currency group at a time (whichever has the highest priority affordable item)

## Commands

```
/cxh add <itemLink|itemID>  - Track an item
/cxh list                   - Show tracked items
/cxh show                   - Force show panel
/cxh reset                  - Reset window position
/cxh debug [on|off]         - Toggle debug mode
```

## License

MIT

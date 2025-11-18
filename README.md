# CrestXmute Helper

WoW addon that automates crest transmutation with a single macro.

## What It Does

- Dynamically updates a macro (`CrestX-Open`) with your next buy/use action so you can spam one button to automate crest transmutation.
- Lets you add any other vendor items (ex.: Delver's Pouches) with Buy/Open/Confirm toggles and drag-to-reorder priority.

## Installation

1. Extract to `World of Warcraft\_retail_\Interface\AddOns\`
2. `/reload` in-game

## Usage - Crest Transmutation

**Basic workflow for transmutation vendors:**

1. Visit a crest transmutation vendor (panel appears automatically).
2. Click the button in the top-right of the panel (or drag the `CrestX-Open` macro to your normal action bar, if you want a keybind outside the panel).
3. Spam the button/macro. The addon tracks crest containers automatically. Configure Buy/Open/Confirm toggles if needed (all on by default).

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

The panel now includes its own button that always references the `CrestX-Open` macro. You can click it directly or ignore it and use the macro from your regular action bars, the macro is still created/updated under the General tab so it stays in sync with whichever control you prefer.

The macro can do up to two things per click:

1. **Open one container** – If you have a tracked container in bags with "Open" enabled, it uses it first
2. **Then buy one item** – If you're at a vendor, it buys the highest priority affordable item with "Buy" enabled
3. **Confirm purchase** – Dismisses the confirmation dialog if "Confirm" is enabled

**Per-click behavior:**

- On each click, the macro attempts to open (/use) one tracked item first, then buy one item if possible
- **Row highlighting shows what will happen on the next click:**
  - **Blue highlight** = Will buy
  - **Gold highlight** = Will open
  - **Teal highlight** = Will open and then buy
- Spam the macro to process multiple opens/buys over successive clicks

**Priority-Based Purchases:**

- The macro buys the highest priority item you can afford from the current vendor
- **Drag items to reorder** within each currency group to set priority
- **Currency-aware grouping** - Items are grouped by their purchase currency; priority only matters within the same currency
- If multiple currencies are available at a vendor, only one currency group will be purchased from per click
- Example: Tracking both Weathered and Carved crest packs at a transmutation vendor will only buy from one currency group at a time (whichever has the highest priority affordable item)

## Commands

```
/cxh add <itemLink|itemID>     - Track an item (works while panel closed)
/cxh remove <itemLink|itemID>  - Stop tracking an item (non-seed items)
/cxh list                      - Print tracked items (seed + user)
/cxh show                      - Force show panel next to current vendor
/cxh reset                     - Reset window position
/cxh debug help                - Show debug categories
/cxh debug <category>          - Toggle a specific debug category
/cxh debug status              - Print current debug configuration
```

## License

MIT

# Changelog

## [2026-08-30]

### Changed

- Misc. improvements and fixes

## [2026-08-22]

### Added

- Collapsible panel: collapse to a small pinned tab next to the vendor window, or pull it back out. Now shows on every vendor, not just ones with tracked items.
- The buy/open button's icon and tooltip now reflect what the next click will actually do.

### Fixed

- Fixed EllesmereUI skin.

## [2026-08-13]

### Added

- EllesmereUI skin support.

## [2026-08-12]

### Changed

- Updated default item IDs for the Midnight Season 2

## [2026-04-07]

### Changed

- Updated default item IDs for the new season (4 crest pack types)

## [2026-02-13]

### Changed

- Update interface version to 120001 and adjust category in .toc file

## [2026-01-21]

### Changed

- Updated interface version to 120000 and migrated merchant item info to `C_MerchantFrame.GetItemInfo`.

### Fixed

- Default skin column header spacing so "Confirm" no longer truncates.
- Macro action button border sizing now matches the icon in the default skin.

## [2025-11-17]

### Added

- Dedicated CrestX action button embedded in the panel; auto-fires the `CrestX-Open` macro.

### Fixed

- Action button and checkbox borders now render all four sides in ElvUI skins (no more 1px gaps when scaling).

## [1.0.0] - 2025-11-04

### Initial Release

- Automated crest transmutation with single-button macro
- Tracks default season crest containers automatically
- Add Mode for tracking custom vendor items
- Per-item Buy/Open/Confirm toggles
- Drag-to-reorder priority within currency groups
- Currency-aware grouping and purchasing
- Slash commands for item management (`/cxh add`, `/cxh remove`, `/cxh list`)
- Window position saving
- ElvUI skin integration
- Debug system with per-category toggles
- Macro auto-updates when adding/removing items
- Macro clears vendor buy commands when closing merchant

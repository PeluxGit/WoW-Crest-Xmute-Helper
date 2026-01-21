# Changelog

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

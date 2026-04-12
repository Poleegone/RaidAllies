---
name: RaidAllies Changelog
description: Quick summary of recent changes to the addon.
type: changelog
---

## 2026-04-12
- Made X close button visible by setting its frame level higher than parent UI elements.
- Ensured filter and options panels close automatically when the main window hides (via ESC or X).
- Refactored `RA:ApplyFontSize()` to clear and rebuild row pools and update static UI fonts, preventing overlapping fonts.
- Updated font selection to rebuild UI after changing the font, fixing overlapping font issues.
- Implemented font dropdown preview: each font name rendered in its own typeface.
- Replaced font selector with a button that opens a scrollable dropdown list of fonts.
- Added sliders for window opacity and font size in the Options panel.
- Adjusted full‑clear badge positioning to sit left of the kill‑count label in the session list.
- Added online‑status indicator (green dot) on player rows, shown when a player is online during hover.
- Moved "Own realm only" checkbox from Options panel to Filters panel for better UI organization.

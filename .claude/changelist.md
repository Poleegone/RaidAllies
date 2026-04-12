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
- Set up GitHub repository at https://github.com/Poleegone/RaidAllies.git for version control.
- Redesigned player list with card-based grid layout: players now displayed as visual cards (175×72px) grouped by role (Tanks, Healers, DPS) with section headers and dynamic column reflow. Cards show larger class icons (36×36), guild tags, achievement badges (AOTC/CE), and kill count pills.
- Implemented spec icon capture and display: added spec field to player records, updated logger to capture `GetInspectSpecialization()` for each raider, display spec icons on player cards with fallback to class icons for records without spec data.
- Fixed "Invite to Group" functionality: replaced legacy `InviteUnit` global with modern `C_PartyInfo.InviteUnit` API, added live unit token resolution via `FindUnitToken()` for players currently in raid, and sanitised realm names to handle connected-realm spacing issues.

---
name: RaidAllies Bugs
description: List of bugs that were identified and fixed in the addon.
type: bug
---

## Unresolved bugs

(none currently)

## Resolved bugs

- [X] **X button not visible** – Added `SetFrameLevel` to the close button (and other title‑bar buttons) so it renders above other UI elements.
- [X] **Filter/Options panels not closing with main window** – Main frame’s `OnHide` now hides any open filter or options frames, ensuring they close when ESC or the X button is used.
- [X] **Font size changes created overlapping fonts** – Refactored `RA:ApplyFontSize()` to clear row pools, update static UI fonts, and rebuild the active view, preventing duplicate rows.
- [X] **Font selection caused overlapping fonts** – Updated font selection handling to rebuild fonts via `ApplyFontSize()` after changing the font, removing overlap.
- [X] **Font dropdown did not preview fonts** – Implemented a preview dropdown where each font name is rendered in its own typeface.
- [X] **Opacity and font size were not sliders** – Added themed horizontal sliders for window opacity and font size in the Options panel.
- [X] **Font selection button was not a dropdown** – Replaced the previous selector with a button that opens a scrollable dropdown of available fonts.
- [X] **Full‑clear badge positioned incorrectly** – Anchored the badge to the left of the kill‑count label in the session list.
- [X] **Online status not shown on hover** – Added a small green dot indicator that appears when a player is online and the row is hovered.

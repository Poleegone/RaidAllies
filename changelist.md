# RaidAllies Changelog

## v0.9.1 — 2026-04-13

### New Features
- **Allies tab** — new tab bar at the top of the main window with "Raids" and "Allies" views. Click "Allies" to split the window: browse raids on the left, see all your pinned allies on the right.
- **Pinned Allies panel** — dedicated list showing every player you've starred, sorted alphabetically. Displays class icon, name, realm, guild, total kill count, and achievement badges (AOTC/CE). Right-click for quick actions (invite, whisper, unpin).
- **Pin state now persists** — starred players are saved to your RaidAllies data, so pins survive /reload and logouts.
- **Pin star always visible** — the star icon on player cards no longer requires the Recent Allies system to be active.

---

## v0.9.0— 2026-04-13

### New Features
- **Exclude yourself from roster** — new option under Settings to hide your own character from player lists (off by default, so you appear in your own logs).
- **Historical self-injection** — your character is now automatically added to all existing boss kill records on first load, so your history is complete from day one.
- **RaiderIO raid progression** — player cards now display current raid progression (e.g. "9/9M") when RaiderIO is installed, instead of the M+ score.
- **Pin to Recent Allies** — clickable ★ star icon on the bottom-left of each player card. Click to pin/unpin players as your Recent Allies. Star shows gold when pinned, grey when not pinned.

### Bug Fixes
- Fixed RaiderIO data not loading correctly on addon startup.

---

## v0.8.9 — 2026-04-12

### New Features
- **Player card layout** — the player list now shows visual cards grouped by role (Tanks, Healers, DPS), with class/spec icons, guild tag, achievement badges (AOTC/CE), and kill count.
- **Spec icons** — player cards show your groupmates' specialization icons where available, falling back to class icons for older records.
- **Raid frame overlay** — kill count (×N) and achievement badges (AOTC/CE) are shown directly on Blizzard raid/party frames so you can see history at a glance.
- **RaiderIO integration** — player cards show RaiderIO data when the addon is installed. Gracefully hidden when RaiderIO is absent.
- **Online status indicator** — a green dot appears on player cards when a groupmate is currently online.
- **Font & opacity options** — new sliders in the Options panel to adjust font size and window transparency. Font selector previews each font in its own typeface.
- **Filters panel improvement** — "Own realm only" filter moved to the Filters panel for easier access.

### Bug Fixes
- Fixed "Invite to Group" for players on connected realms.
- Fixed difficulty color display for Normal and Heroic.
- Fixed role icons not displaying on player cards.
- Fixed guild names overflowing card boundaries (long names now truncate cleanly).
- Fixed font not updating correctly when changed in settings.
- Fixed main window close button being obscured by other UI elements.

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
- Optimized window resize performance: implemented debounce timer on `_OnResized()` to defer full refresh 0.1s after resize completes, added `_LayoutPlayerCards()` for fast live repositioning during drag (no repopulation), reduces per-frame API calls from ~480 to ~N×2.
- Implemented raid/party frame overlay badges: new `UI/RaidFrameOverlay.lua` hooks `CompactUnitFrame_UpdateAll` to display kill-count badges (×N) and achievement icons (★ AOTC, ◆ CE) on Blizzard compact unit frames; fully customizable position offsets (X/Y) and transparency via new Options panel sliders.
- Enhanced player cards with RaiderIO M+ scores: expanded card height from 72px to 90px, added new row displaying player's RaiderIO score in tier-appropriate colour (grey/green/blue/purple/orange/gold) when RaiderIO addon is installed; gracefully hidden if addon absent or player has no M+ data.
- Fixed window opacity: changed BG_MAIN alpha from 0.96 to 1.0 so addon is fully opaque at 100% slider setting; BG_ROW_ALT increased from 0.55 to 0.80 for more solid backgrounds.
- Redesigned player cards with modern visual enhancements: replaced flat background with subtle vertical gradient (lighter top → darker bottom), added 3px class-color accent strip on left edge at 70% alpha (brightens to 100% on hover), improved hover state with gradient brightening + accent strip brightening + border accent highlight.
- Fixed difficulty color inconsistency: aligned `RA.DIFFICULTY_COLORS.Normal` green value from 0.45 to 0.48 to match Theme.lua definition, ensuring consistent blue display for Normal difficulty and purple for Heroic across all UI elements (filter buttons, encounter labels).
- Fixed Heroic difficulty color display: standardized difficulty category keys to uppercase (LFR, NORMAL, HEROIC, MYTHIC) in both `RA.DIFFICULTY_CATEGORY` and `RA.DIFFICULTY_COLORS` to ensure correct color lookups in `T:DiffColor()`, resolving issue where Heroic was displaying as blue instead of purple. Updated filter button definitions in `FilterFrame.lua` to use uppercase keys and updated documentation comments in `Database.lua`.
- Enhanced player card visuals: made gradients more subtle with reduced color contrast, added CARD_SHADOW color constant to Theme.lua, added 2px subtle shadows on right and bottom edges of cards for depth effect.
- Simplified realm display: removed "-" prefix from realm labels on player cards and tooltips, now displays as "Player Realm" instead of "Player-Realm".
- Fixed guild name overflow: added right anchors to `realmLabel`, `guildLabel`, and `rioLabel` FontStrings to prevent overflow past card boundaries; guild names now truncate to 20 characters with ellipsis (`…`), removed angle bracket wrapping for cleaner appearance; full guild name remains visible in hover tooltip.
- Fixed role icon display: replaced broken manual TexCoord system with modern atlas-based API. `T:SetRoleIcon()` now uses `GetIconForRole()` Blizzard global (if available) with fallback to hardcoded atlas names (`"UI-LFG-RoleIcon-Tank"`, `"UI-LFG-RoleIcon-Healer"`, `"UI-LFG-RoleIcon-DPS"`). Uses `SetAtlas(name, true)` which automatically handles texture sheet and UV coordinates, fixing the issue where icons were not displaying at all.
- Adjusted role icon size: reduced `ROLE_ICON_SZ` from 14px to 8px, and fixed `T:SetRoleIcon()` to pass `false` to `SetAtlas()` so that `SetSize()` controls the dimensions instead of auto-resizing to atlas native size.

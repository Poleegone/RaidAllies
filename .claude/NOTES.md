# RaidAllies — Project Notes

## What This Addon Does
Tracks other players in your raid group on successful boss kills. Lets you look back on previously played-with players filtered by various criteria. CurseForge target, no Ace3 dependency, pure Blizzard API, WoW:Midnight API 120001.

---

## Current State (as of 2026-04-12)

### ✅ Complete & Working
- **Core/Database.lua** — DB v2 schema, InitDB, MigrateDB, PruneDB, key helpers
- **Core/Utils.lua** — Difficulty maps/colors, TimeAgo, unit helpers, FindUnitToken
- **Core/Logger.lua** — ENCOUNTER_END, ACHIEVEMENT_EARNED (AOTC/CE), SnapshotRoster, UpsertPlayerKill, UpsertSession, CheckFullClear
- **Core/DataProvider.lua** — GetSessionList, GetBossesForSession, GetPlayersForSessionBoss, GetAllRaidNames, filter-aware queries
- **UI/Theme.lua** — Colors, fonts, role icons (texture+texcoord), class icons, border/bg helpers
- **UI/MainWindow.lua** — Main frame (DIALOG strata), draggable, resizable (400-1400 × 300-1000), ESC, X button (atlas), filter/options title buttons, footer, content area, 3-view switching, geometry persistence, ApplyOpacity/ApplyFontSize
- **UI/EncounterList.lua** — Session list view: instance + difficulty + date/time + full clear badge, AOTC/CE backgrounds
- **UI/BossList.lua** — Boss list view within a session: boss name, time, player count
- **UI/PlayerList.lua** — Player list: role+class icons, name-realm (class coloured), kill badge, tooltip (WoW + time ago), right-click menu
- **UI/FilterFrame.lua** — Right-anchored filter panel: difficulty buttons, raid checkboxes, achievement/full clear/guild clear toggles, min players
- **UI/OptionsFrame.lua** — Right-anchored options panel: opacity stepper, font size stepper, font selector, own-realm toggle

### 🔧 Known Limitations / Future Work
- Nameplate icons above players in game (future feature, noted in fulldoc.md)
- RaiderIO right-click integration is passive (tooltip note only — RaiderIO has no public "show profile" API)
- Font size changes rebuild row pools but don't hot-reload the header/footer fonts

---

## UI Hierarchy (3-level drill-down)
```
Main window
  └── Session List       [UI/EncounterList.lua]
        └── Boss List    [UI/BossList.lua]
              └── Player List  [UI/PlayerList.lua]
```

- Session = one raid lockout (same group, same instance, same reset week)
- Multiple LFR lockouts of the same raid appear as SEPARATE session rows
- Click session → see bosses killed in that session
- Click boss → see players who were with you for that kill
- Back buttons navigate up the chain

---

## DB Schema Summary
```
RaidAlliesDB v2
 ├─ players[playerKey]
 │    ├─ name, realm, class, classID, role, guild, firstSeen, lastSeen, totalKills
 │    └─ encounters[encounterID-difficultyID]
 │         └─ count, firstKill, lastKill, wasAOTC, wasCE, ...
 ├─ sessions[instanceID-difficultyID-lockoutID]
 │    ├─ instanceName, difficultyID, startedAt, isFullClear, ...
 │    └─ bosses[encounterID]
 │         └─ name, killedAt, players{playerKey: true}
 └─ settings
      ├─ opacity, fontSize, fontName, filterRealm, autoPrune
      └─ filters{ difficulty, raids{}, achievementOnly, minKills, fullClearOnly, guildClearOnly }
```

## DB Pruning
- Sessions: max 200 per (instanceID × difficultyID) — keeps ~4 years of weekly clears
- Players: stale records (not seen 2+ years, totalKills ≤ 1) auto-pruned if autoPrune = true
- Run manually: `/ra prune` reports counts

---

## Slash Commands
- `/ra` or `/raidallies` — toggle window
- `/ra debug` — toggle debug output
- `/ra reset confirm` — wipe all data
- `/ra prune` — manually run DB pruning
- `/ra help` — show command list

---

## Design Rules (don't break these)
1. Never duplicate player records — always go through `UpsertPlayerKill`
2. Self is excluded from all roster snapshots
3. Only log when `IsInRaid()` is true (no 5-man dungeons)
4. AOTC/CE detected via `ACHIEVEMENT_EARNED` one-shot pending flags consumed by next `ENCOUNTER_END`
5. All new UI frames: `SetFrameStrata("DIALOG")`
6. All UI attaches to `RA` global table via `local _, RA = ...` pattern
7. Filter/Options frames are mutually exclusive (opening one closes the other)

---

## File Load Order (RaidAllies.toc)
```
Core\Database.lua
Core\Utils.lua
Core\Logger.lua
Core\DataProvider.lua
UI\Theme.lua
UI\MainWindow.lua
UI\FilterFrame.lua
UI\OptionsFrame.lua
UI\EncounterList.lua
UI\BossList.lua
UI\PlayerList.lua
RaidAllies.lua
```

---

## Next / Future Steps
- [ ] Nameplate icons above players in game world
- [ ] More granular filter: date range picker
- [ ] Per-boss AOTC/CE badge in boss list rows
- [ ] Localization framework (L[] table) for future locale support
- [ ] Search bar / player name search in player list


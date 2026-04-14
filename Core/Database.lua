-- RaidAllies: Database schema, defaults, initialisation, migration, and pruning.
-- All persistent state lives in RaidAlliesDB (SavedVariables).

local ADDON_NAME, RA = ...

RA.DB_VERSION = 3

-------------------------------------------------------------------------------
-- Schema documentation
-------------------------------------------------------------------------------
--[[
RaidAlliesDB = {
    version      = number,
    players      = { [playerKey] = PlayerRecord },
    sessions     = { [sessionKey] = SessionRecord },
    settings     = SettingsRecord,
    selfInjected = boolean,  -- one-shot flag: true if current player injected into historical kills
    pinnedPlayers = { [playerKey] = true },  -- players pinned as recent allies in RaidAllies
}

PlayerKey    = "CharacterName-RealmName"
SessionKey   = "instanceID-difficultyID-lockoutID"
EncounterKey = "encounterID-difficultyID"

PlayerRecord = {
    name       = string,          -- "Thrall"
    realm      = string,          -- "Silvermoon"
    class      = string,          -- class token, e.g. "SHAMAN"
    classID    = number,          -- numeric class ID (for icon lookups)
    spec       = number|nil,      -- spec ID at last seen, or nil if unavailable
    role       = string,          -- "TANK" | "HEALER" | "DAMAGER"
    guild      = string|nil,      -- guild name at last seen, or nil
    note       = string|nil,      -- user-authored note about this player, or nil
    firstSeen  = number,          -- Unix timestamp of first kill together
    lastSeen   = number,          -- Unix timestamp of most recent kill together
    totalKills = number,          -- running total of boss kills with this player
    encounters = {
        [EncounterKey] = EncounterRecord
    },
}

EncounterRecord = {
    encounterID    = number,
    encounterName  = string,
    instanceID     = number,
    instanceName   = string,
    difficultyID   = number,
    difficultyName = string,      -- normalised: "LFR" | "NORMAL" | "HEROIC" | "MYTHIC"
    count          = number,      -- times killed this specific boss/difficulty with this player
    firstKill      = number,      -- timestamp
    lastKill       = number,      -- timestamp
    wasAOTC        = boolean,     -- at least one kill was an AOTC
    wasCE          = boolean,     -- at least one kill was a CE
}

SessionRecord = {
    instanceID         = number,
    instanceName       = string,
    difficultyID       = number,
    lockoutID          = string,
    startedAt          = number,
    isFullClear        = boolean,
    clearedAt          = number|nil,
    fullClearPlayers   = { [playerKey] = true } | nil,
    bosses = {
        [encounterID] = {
            name      = string,
            killedAt  = number,
            players   = { [playerKey] = true },
        },
    },
}

SettingsRecord = {
    opacity      = number,   -- 0.0 – 1.0
    fontSize     = number,   -- 10 – 18
    fontName     = string,
    filterRealm  = boolean,  -- show only players from the player's own realm
    excludeSelf  = boolean,  -- exclude current player from roster logging
    autoPrune    = boolean,  -- automatically prune stale records on load
    filters      = FiltersRecord,
    -- Raid frame overlay badge settings
    showOverlay  = boolean,  -- show badges on raid/party frames
    overlayAlpha = number,   -- 0.0 – 1.0, opacity of overlay elements
    overlayKillOffX = number,  -- pixel offset for kill count badge X
    overlayKillOffY = number,  -- pixel offset for kill count badge Y
    overlayAchOffX = number,   -- pixel offset for achievement icon X
    overlayAchOffY = number,   -- pixel offset for achievement icon Y
    -- Window geometry (saved on move/resize, restored on open)
    windowX      = number|nil,
    windowY      = number|nil,
    windowW      = number|nil,
    windowH      = number|nil,
}

FiltersRecord = {
    difficulty      = string|nil,  -- nil = Any, or "LFR"/"NORMAL"/"HEROIC"/"MYTHIC"
    raids           = table,       -- { [instanceName] = true } — empty = all raids shown
    achievementOnly = boolean,
    minKills        = number,      -- minimum unique players in session
    fullClearOnly   = boolean,
    guildClearOnly  = boolean,
}
]]

-------------------------------------------------------------------------------
-- Defaults
-------------------------------------------------------------------------------

RA.DB_DEFAULTS = {
    version       = RA.DB_VERSION,
    players       = {},
    sessions      = {},
    pinnedPlayers = {},
    settings = {
        opacity     = 1.0,
        fontSize    = 13,
        fontName    = "Friz Quadrata TT",
        filterRealm = false,
        excludeSelf = false,
        autoPrune   = true,
        filters = {
            difficulty      = nil,
            raids           = {},
            achievementOnly = false,
            minKills        = 0,
            fullClearOnly   = false,
            guildClearOnly  = false,
        },
        -- Raid frame overlay badges
        showOverlay      = true,
        overlayAlpha     = 1.0,
        overlayKillOffX  = 0,
        overlayKillOffY  = 0,
        overlayAchOffX   = 0,
        overlayAchOffY   = 0,
        -- windowX/Y/W/H intentionally absent: nil = use default centred position
    },
}

-------------------------------------------------------------------------------
-- Public API
-------------------------------------------------------------------------------

--- Initialise or upgrade the SavedVariables database.
--- Called once from RaidAllies.lua during ADDON_LOADED.
function RA:InitDB()
    if type(RaidAlliesDB) ~= "table" then
        RaidAlliesDB = CopyTable(RA.DB_DEFAULTS)
    end

    local db = RaidAlliesDB

    -- Version migration
    if not db.version or db.version < RA.DB_VERSION then
        RA:MigrateDB(db)
    end

    -- Ensure all top-level keys exist (handles partial saves / future keys)
    if type(db.players)       ~= "table" then db.players       = {} end
    if type(db.sessions)      ~= "table" then db.sessions      = {} end
    if type(db.pinnedPlayers) ~= "table" then db.pinnedPlayers = {} end
    if type(db.settings)      ~= "table" then db.settings      = {} end

    -- Backfill any missing settings with defaults
    local def = RA.DB_DEFAULTS.settings
    for k, v in pairs(def) do
        if db.settings[k] == nil then
            db.settings[k] = (type(v) == "table") and CopyTable(v) or v
        end
    end

    -- Ensure filters sub-table is complete
    if type(db.settings.filters) ~= "table" then
        db.settings.filters = CopyTable(RA.DB_DEFAULTS.settings.filters)
    else
        local defF = RA.DB_DEFAULTS.settings.filters
        for k, v in pairs(defF) do
            if db.settings.filters[k] == nil then
                db.settings.filters[k] = (type(v) == "table") and CopyTable(v) or v
            end
        end
    end

    RA.db = db

    -- Expose filter state as a live reference (UI reads/writes this directly)
    RA.activeFilters = db.settings.filters

    -- Run automatic pruning to keep SavedVariables lean
    if db.settings.autoPrune then
        RA:PruneDB()
    end
end

--- Apply incremental migrations between DB versions.
--- @param db table
function RA:MigrateDB(db)
    -- v0/v1 → v2: add autoPrune and filters to settings
    if not db.version or db.version < 2 then
        if type(db.settings) ~= "table" then db.settings = {} end
        if db.settings.autoPrune == nil then
            db.settings.autoPrune = true
        end
        if type(db.settings.filters) ~= "table" then
            db.settings.filters = CopyTable(RA.DB_DEFAULTS.settings.filters)
        end
    end
    -- v2 → v3: add pinnedPlayers table
    if db.version < 3 then
        if type(db.pinnedPlayers) ~= "table" then db.pinnedPlayers = {} end
    end
    db.version = RA.DB_VERSION
end

-------------------------------------------------------------------------------
-- DB Pruning
-- Prevents unbounded SavedVariables growth over years of use.
-------------------------------------------------------------------------------

-- Maximum sessions kept per (instanceID × difficultyID) pair.
-- 200 ≈ 4 years of weekly clears before the oldest sessions are dropped.
local MAX_SESSIONS_PER_RAID = 200

-- Player records not seen in this many days with only 1 total kill are pruned.
local STALE_PLAYER_DAYS = 730  -- 2 years

--- Prunes stale sessions and one-time players from the database.
--- Safe to call multiple times; always returns a counts table.
--- @return table  { sessions = number, players = number }
function RA:PruneDB()
    local pruned = { sessions = 0, players = 0 }
    local now    = RA:Now()

    -- ── Session pruning ───────────────────────────────────────────────────────
    -- Group session keys by "instanceID-difficultyID"
    local groups = {}
    for sessionKey, session in pairs(RA.db.sessions) do
        local gk = session.instanceID .. "-" .. session.difficultyID
        if not groups[gk] then groups[gk] = {} end
        local entry = { key = sessionKey, startedAt = session.startedAt or 0 }
        groups[gk][#groups[gk] + 1] = entry
    end

    for _, list in pairs(groups) do
        if #list > MAX_SESSIONS_PER_RAID then
            -- Sort newest first and delete the tail
            table.sort(list, function(a, b) return a.startedAt > b.startedAt end)
            for i = MAX_SESSIONS_PER_RAID + 1, #list do
                RA.db.sessions[list[i].key] = nil
                pruned.sessions = pruned.sessions + 1
            end
        end
    end

    -- ── Player pruning ────────────────────────────────────────────────────────
    local staleThreshold = now - (STALE_PLAYER_DAYS * 86400)
    for playerKey, player in pairs(RA.db.players) do
        if (player.lastSeen or 0) < staleThreshold and (player.totalKills or 0) <= 1 then
            RA.db.players[playerKey] = nil
            pruned.players = pruned.players + 1
        end
    end

    RA:DebugPrint(string.format("PruneDB: removed %d sessions, %d players",
        pruned.sessions, pruned.players))

    return pruned
end

-------------------------------------------------------------------------------
-- Key helpers  (shared across all modules)
-------------------------------------------------------------------------------

--- Canonical key for a player record.
--- @param name  string
--- @param realm string
--- @return string  "Name-Realm"
function RA:PlayerKey(name, realm)
    return name .. "-" .. realm
end

--- Canonical key for an encounter record within a player.
--- @param encounterID  number
--- @param difficultyID number
--- @return string  "encounterID-difficultyID"
function RA:EncounterKey(encounterID, difficultyID)
    return encounterID .. "-" .. difficultyID
end

--- Canonical key for a raid session / lockout.
--- @param instanceID   number
--- @param difficultyID number
--- @param lockoutID    string
--- @return string
function RA:SessionKey(instanceID, difficultyID, lockoutID)
    return instanceID .. "-" .. difficultyID .. "-" .. lockoutID
end

-- RaidAllies: DataProvider
-- Aggregation queries that transform the raw SavedVariables DB into
-- display-ready data structures.  No UI code lives here.
--
-- Data hierarchy:
--   GetSessionList()              → list of sessions (1 per lockout)
--   GetBossesForSession(key)      → bosses killed in a session
--   GetPlayersForSessionBoss(...) → players present for a specific boss kill

local _, RA = ...

local ROLE_ORDER = { TANK = 1, HEALER = 2, DAMAGER = 3 }

-------------------------------------------------------------------------------
-- Session list  (main view)
-------------------------------------------------------------------------------

--- Returns a sorted list of session records, newest first.
--- Applies RA.activeFilters if set.
---
--- @return table[]
---   Fields: sessionKey, instanceName, instanceID, difficultyID, difficultyName,
---           startedAt, isFullClear, playerCount, bossCount, wasAOTC, wasCE
function RA:GetSessionList()
    local sessions = {}
    local f        = RA.activeFilters or {}

    for sessionKey, session in pairs(RA.db.sessions) do
        local skip = false

        -- ── Difficulty filter ─────────────────────────────────────────────────
        if f.difficulty and f.difficulty ~= "" then
            local cat = RA:GetDifficultyCategory(session.difficultyID)
            if cat ~= f.difficulty then skip = true end
        end

        -- ── Raid (instance name) filter ───────────────────────────────────────
        if not skip and f.raids and next(f.raids) then
            if not f.raids[session.instanceName] then skip = true end
        end

        -- ── Full-clear filter ─────────────────────────────────────────────────
        if not skip and f.fullClearOnly and not session.isFullClear then
            skip = true
        end

        if not skip then
            -- Gather all unique players and check achievement flags
            local playerSet = {}
            local wasAOTC   = false
            local wasCE     = false

            for encID, bossData in pairs(session.bosses) do
                local encKey = RA:EncounterKey(encID, session.difficultyID)
                for playerKey in pairs(bossData.players) do
                    playerSet[playerKey] = true
                    local player = RA.db.players[playerKey]
                    if player then
                        local enc = player.encounters[encKey]
                        if enc then
                            if enc.wasAOTC then wasAOTC = true end
                            if enc.wasCE   then wasCE   = true end
                        end
                    end
                end
            end

            -- ── Achievement filter ────────────────────────────────────────────
            if f.achievementOnly and not wasAOTC and not wasCE then
                skip = true
            end

            if not skip then
                -- ── Guild-clear filter ────────────────────────────────────────
                if f.guildClearOnly then
                    local myGuild = RA:GetUnitGuild("player")
                    if not myGuild then
                        skip = true
                    else
                        local hasGuild = false
                        for playerKey in pairs(playerSet) do
                            local player = RA.db.players[playerKey]
                            if player and player.guild == myGuild then
                                hasGuild = true
                                break
                            end
                        end
                        if not hasGuild then skip = true end
                    end
                end
            end

            if not skip then
                -- Count unique players
                local playerCount = 0
                for _ in pairs(playerSet) do playerCount = playerCount + 1 end

                -- ── Min-players filter ────────────────────────────────────────
                if f.minKills and f.minKills > 0 and playerCount < f.minKills then
                    skip = true
                end
            end

            if not skip then
                -- Count bosses
                local bossCount = 0
                for _ in pairs(session.bosses) do bossCount = bossCount + 1 end

                -- Collect wasAOTC/wasCE again (needed after skip checks)
                local aotc2, ce2 = false, false
                local pc2 = 0
                local ps2 = {}
                for encID, bossData in pairs(session.bosses) do
                    local encKey = RA:EncounterKey(encID, session.difficultyID)
                    for playerKey in pairs(bossData.players) do
                        ps2[playerKey] = true
                        local player = RA.db.players[playerKey]
                        if player then
                            local enc = player.encounters[encKey]
                            if enc then
                                if enc.wasAOTC then aotc2 = true end
                                if enc.wasCE   then ce2   = true end
                            end
                        end
                    end
                end
                for _ in pairs(ps2) do pc2 = pc2 + 1 end

                sessions[#sessions + 1] = {
                    sessionKey    = sessionKey,
                    instanceName  = session.instanceName  or "Unknown Raid",
                    instanceID    = session.instanceID    or 0,
                    difficultyID  = session.difficultyID  or 1,
                    difficultyName = RA:GetDifficultyName(session.difficultyID or 1),
                    startedAt     = session.startedAt     or 0,
                    isFullClear   = session.isFullClear   or false,
                    playerCount   = pc2,
                    bossCount     = bossCount,
                    wasAOTC       = aotc2,
                    wasCE         = ce2,
                }
            end
        end
    end

    -- Apply own-realm filter at the session level (no-op — realm filters apply to PlayerList)

    table.sort(sessions, function(a, b)
        return a.startedAt > b.startedAt
    end)

    return sessions
end

-------------------------------------------------------------------------------
-- Boss list  (detail view — level 2)
-------------------------------------------------------------------------------

--- Returns the bosses killed in a specific session, sorted by kill time.
---
--- @param  sessionKey  string
--- @return table[]
---   Fields: encounterID, encounterName, killedAt, playerCount
function RA:GetBossesForSession(sessionKey)
    local session = RA.db.sessions[sessionKey]
    if not session then return {} end

    local bosses = {}
    for encID, bossData in pairs(session.bosses) do
        local count = 0
        for _ in pairs(bossData.players) do count = count + 1 end

        bosses[#bosses + 1] = {
            encounterID   = encID,
            encounterName = bossData.name     or "Unknown Boss",
            killedAt      = bossData.killedAt or 0,
            playerCount   = count,
        }
    end

    table.sort(bosses, function(a, b)
        return a.killedAt < b.killedAt  -- chronological order within a session
    end)

    return bosses
end

-------------------------------------------------------------------------------
-- Player list  (detail view — level 3)
-------------------------------------------------------------------------------

--- Returns all players present for a specific boss kill in a specific session.
--- Cross-references session.bosses[encounterID].players with RA.db.players.
--- Applies filterRealm if enabled.
---
--- @param  sessionKey   string
--- @param  encounterID  number
--- @return table[]
---   Fields: name, realm, class, classID, role, guild, count, wasAOTC, wasCE, lastKill
function RA:GetPlayersForSessionBoss(sessionKey, encounterID)
    local session = RA.db.sessions[sessionKey]
    if not session then return {} end

    local bossData = session.bosses[encounterID]
    if not bossData then return {} end

    local difficultyID = session.difficultyID
    local encKey       = RA:EncounterKey(encounterID, difficultyID)
    local myRealm      = RA.db.settings.filterRealm and RA:GetPlayerRealm() or nil
    local selfKey      = RA.db.settings.excludeSelf and RA:GetPlayerKey() or nil

    local players = {}
    for playerKey in pairs(bossData.players) do
        local player = RA.db.players[playerKey]
        if player then
            -- Skip self if excludeSelf is enabled
            if not (selfKey and playerKey == selfKey) then
                -- Apply own-realm filter if enabled
                if not myRealm or player.realm == myRealm then
                    local enc = player.encounters[encKey]
                    players[#players + 1] = {
                        name     = player.name,
                        realm    = player.realm,
                        class    = player.class    or "WARRIOR",
                        classID  = player.classID  or 1,
                        spec     = player.spec,
                        role     = player.role     or "DAMAGER",
                        guild    = player.guild,
                        count    = enc and enc.count   or 1,
                        wasAOTC  = enc and enc.wasAOTC  or false,
                        wasCE    = enc and enc.wasCE    or false,
                        lastKill = enc and enc.lastKill or (bossData.killedAt or 0),
                    }
                end
            end
        end
    end

    table.sort(players, function(a, b)
        local ra = ROLE_ORDER[a.role] or 3
        local rb = ROLE_ORDER[b.role] or 3
        if ra ~= rb then return ra < rb end
        return a.name < b.name
    end)

    return players
end

-------------------------------------------------------------------------------
-- Raid name helper  (used by FilterFrame to build the raid checkbox list)
-------------------------------------------------------------------------------

--- Returns a sorted list of unique instance names recorded in the DB.
--- @return string[]
function RA:GetAllRaidNames()
    local seen = {}
    local names = {}

    for _, session in pairs(RA.db.sessions) do
        local n = session.instanceName
        if n and n ~= "" and not seen[n] then
            seen[n]          = true
            names[#names + 1] = n
        end
    end

    table.sort(names)
    return names
end

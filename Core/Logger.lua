-- RaidAllies: Core logging engine.
-- Handles ENCOUNTER_END, roster snapshotting, player upsert/tally logic,
-- AOTC/CE detection, and session-level full-clear tracking.

local _, RA = ...

-- Blizzard global — declared locally so linters and missing-global checks pass.
local UNKNOWNOBJECT = UNKNOWNOBJECT or "Unknown"

-------------------------------------------------------------------------------
-- AOTC / CE detection
-- We listen to ACHIEVEMENT_EARNED and set a one-shot pending flag.
-- The flag is consumed by the next ENCOUNTER_END handler in the same session.
-- Achievement title matching is locale-independent via English prefix patterns;
-- additional locale strings can be added below as the game releases them.
-------------------------------------------------------------------------------

local AOTC_PREFIX = "Ahead of the Curve:"
local CE_PREFIX   = "Cutting Edge:"

-- Known achievement IDs for AOTC/CE (filled per tier; extend here each patch).
-- Maps achievementID → true.  Used as a fast-path before name scanning.
RA.AOTC_ACHIEVEMENT_IDS = {}
RA.CE_ACHIEVEMENT_IDS   = {}

--- Called when the player earns any achievement.
--- Sets a pending flag consumed by the next boss kill event.
function RA:ACHIEVEMENT_EARNED(_, achievementID)
    -- Fast path: known IDs
    if RA.CE_ACHIEVEMENT_IDS[achievementID] then
        RA._pendingCE   = true
        RA._pendingAOTC = true   -- CE implies AOTC
        return
    end
    if RA.AOTC_ACHIEVEMENT_IDS[achievementID] then
        RA._pendingAOTC = true
        return
    end

    -- Fallback: scan achievement name (handles future tiers automatically)
    local _, name = GetAchievementInfo(achievementID)
    if not name then return end

    if name:find(CE_PREFIX, 1, true) then
        RA._pendingCE   = true
        RA._pendingAOTC = true
    elseif name:find(AOTC_PREFIX, 1, true) then
        RA._pendingAOTC = true
    end
end

--- Clears pending achievement flags and returns their values.
--- @return boolean wasAOTC, boolean wasCE
local function ConsumePendingFlags()
    local aotc = RA._pendingAOTC or false
    local ce   = RA._pendingCE   or false
    RA._pendingAOTC = false
    RA._pendingCE   = false
    return aotc, ce
end

-------------------------------------------------------------------------------
-- Boss kill handler
-------------------------------------------------------------------------------

--- Fired by the game client when a boss encounter ends.
--- Signature: ENCOUNTER_END(encounterID, encounterName, difficultyID, groupSize, success)
--- success == 1 means kill; 0 means wipe.
function RA:ENCOUNTER_END(_, encounterID, encounterName, difficultyID, _, success)
    -- Only record successful kills
    if success ~= 1 then return end

    -- Only track raid groups (avoids logging 5-man dungeon clears)
    if not IsInRaid() then return end

    -- Capture instance context at the moment of kill
    local instanceName, _, _, _, _, _, _, instanceID = GetInstanceInfo()
    if not instanceID or instanceID == 0 then
        RA:DebugPrint("ENCOUNTER_END: invalid instanceID, skipping.")
        return
    end

    local now          = RA:Now()
    local diffName     = RA:GetDifficultyName(difficultyID)
    local wasAOTC, wasCE = ConsumePendingFlags()

    -- Snapshot the roster *before* any async yields (stays on same frame tick)
    local raidPlayers  = RA:SnapshotRoster()

    if #raidPlayers == 0 then
        RA:DebugPrint("ENCOUNTER_END: roster snapshot empty, skipping.")
        return
    end

    -- Resolve lockout for session grouping
    local lockoutID  = RA:ResolveLockoutID(instanceName, difficultyID)
    local sessionKey = RA:SessionKey(instanceID, difficultyID, lockoutID)

    -- Update or create session record
    local session = RA:UpsertSession(sessionKey, instanceID, instanceName, difficultyID, now)

    -- Record this boss kill in the session (for full-clear detection later)
    local playerSet = {}
    for _, p in ipairs(raidPlayers) do
        playerSet[p.key] = true
    end
    session.bosses[encounterID] = {
        name     = encounterName,
        killedAt = now,
        players  = playerSet,
    }

    -- Check whether all bosses in this lockout are now cleared
    RA:CheckFullClear(session, instanceName, difficultyID)

    -- Upsert every raider's player record
    for _, playerData in ipairs(raidPlayers) do
        RA:UpsertPlayerKill(
            playerData,
            encounterID, encounterName,
            instanceID,  instanceName,
            difficultyID, diffName,
            now, wasAOTC, wasCE
        )
    end

    RA:DebugPrint(string.format(
        "Logged: %s · %s [%s] · %d raiders%s%s",
        instanceName, encounterName, diffName, #raidPlayers,
        wasAOTC and " [AOTC]" or "",
        wasCE   and " [CE]"   or ""
    ))
end

-------------------------------------------------------------------------------
-- Roster snapshot
-------------------------------------------------------------------------------

--- Returns a table of PlayerData for every raider currently in the group.
--- Excludes the player themselves if excludeSelf setting is enabled.
--- @return table[]  Each entry: { key, name, realm, class, classID, spec, role, guild }
function RA:SnapshotRoster()
    local players   = {}
    local selfKey   = RA:GetPlayerKey()
    local excludeSelf = RA.db.settings.excludeSelf or false
    local numMembers = GetNumGroupMembers()

    for i = 1, numMembers do
        local unit = "raid" .. i

        -- UnitExists guard — slot may be empty during loading
        if UnitExists(unit) then
            local name, realm = UnitName(unit)

            if name and name ~= UNKNOWNOBJECT and name ~= "" then
                -- UnitName returns nil realm when same-realm as player
                if not realm or realm == "" then
                    realm = GetRealmName()
                else
                    realm = RA:SanitiseRealm(realm)
                end

                local key = RA:PlayerKey(name, realm)

                -- Skip self if excludeSelf is enabled
                if not excludeSelf or key ~= selfKey then
                    local classToken, classID = RA:GetUnitClass(unit)
                    local spec  = RA:GetUnitSpec(unit)
                    local role  = RA:GetUnitRole(unit)
                    local guild = RA:GetUnitGuild(unit)

                    players[#players + 1] = {
                        key     = key,
                        name    = name,
                        realm   = realm,
                        class   = classToken or "WARRIOR",
                        classID = classID    or 1,
                        spec    = spec,
                        role    = role,
                        guild   = guild,
                    }
                end
            end
        end
    end

    return players
end

-------------------------------------------------------------------------------
-- Player record upsert
-- Core rule: one PlayerRecord per player, one EncounterRecord per
-- (encounterID, difficultyID) pair.  Repeated kills increment count only.
-------------------------------------------------------------------------------

--- Creates or updates the DB record for one player on one boss kill.
function RA:UpsertPlayerKill(
    playerData,
    encounterID, encounterName,
    instanceID,  instanceName,
    difficultyID, difficultyName,
    now, wasAOTC, wasCE
)
    local db  = RA.db
    local key = playerData.key

    -- Initialise player record on first encounter
    if not db.players[key] then
        db.players[key] = {
            name       = playerData.name,
            realm      = playerData.realm,
            class      = playerData.class,
            classID    = playerData.classID,
            spec       = playerData.spec,
            role       = playerData.role,
            guild      = playerData.guild,
            firstSeen  = now,
            lastSeen   = now,
            totalKills = 0,
            encounters = {},
        }
    end

    local player = db.players[key]

    -- Refresh mutable metadata (role/guild/spec can change between sessions)
    player.lastSeen = now
    player.spec     = playerData.spec
    player.role     = playerData.role
    player.guild    = playerData.guild
    -- class/classID/name/realm are immutable — never overwrite

    -- Upsert encounter record
    local encKey = RA:EncounterKey(encounterID, difficultyID)

    if not player.encounters[encKey] then
        player.encounters[encKey] = {
            encounterID    = encounterID,
            encounterName  = encounterName,
            instanceID     = instanceID,
            instanceName   = instanceName,
            difficultyID   = difficultyID,
            difficultyName = difficultyName,
            count          = 0,
            firstKill      = now,
            lastKill       = now,
            wasAOTC        = false,
            wasCE          = false,
        }
    end

    local enc = player.encounters[encKey]

    -- Tally the kill
    enc.count    = enc.count + 1
    enc.lastKill = now
    if wasAOTC then enc.wasAOTC = true end
    if wasCE   then enc.wasCE   = true end

    player.totalKills = player.totalKills + 1
end

-------------------------------------------------------------------------------
-- Session management
-------------------------------------------------------------------------------

--- Returns the existing session record or creates a new one.
--- @param sessionKey  string
--- @param instanceID  number
--- @param instanceName string
--- @param difficultyID number
--- @param now         number  timestamp
--- @return table  SessionRecord
function RA:UpsertSession(sessionKey, instanceID, instanceName, difficultyID, now)
    local sessions = RA.db.sessions

    if not sessions[sessionKey] then
        sessions[sessionKey] = {
            instanceID   = instanceID,
            instanceName = instanceName,
            difficultyID = difficultyID,
            lockoutID    = tostring(instanceID) .. "-" .. tostring(difficultyID),
            startedAt    = now,
            isFullClear  = false,
            clearedAt    = nil,
            fullClearPlayers = nil,
            bosses       = {},
        }
    end

    return sessions[sessionKey]
end

--- Determines a stable lockout identifier for the current instance so that
--- kills across multiple play sessions are grouped under the same SessionRecord.
--- Uses GetSavedInstanceInfo() to find the reset ID; falls back to current
--- ISO week string ("YYYY-WW") for instances that aren't in the saved list yet.
--- @param instanceName string
--- @param difficultyID number
--- @return string
function RA:ResolveLockoutID(instanceName, difficultyID)
    for i = 1, GetNumSavedInstances() do
        local siName, siID, _, siDiff = GetSavedInstanceInfo(i)
        if siName == instanceName and siDiff == difficultyID then
            -- siID is the unique reset identifier Blizzard assigns each lockout
            return tostring(siID)
        end
    end
    -- Fallback: group by ISO year-week (one session per reset week)
    return tostring(date("%Y-%W"))
end

-------------------------------------------------------------------------------
-- Full-clear detection
-- A full clear = every boss in the lockout was killed, AND at least one player
-- was present for every kill.  We use GetSavedInstanceInfo()'s encounterProgress
-- vs. numEncounters to know "all bosses down" without needing the Encounter Journal.
-------------------------------------------------------------------------------

--- Checks whether the session represents a full clear and marks it if so.
--- Safe to call repeatedly — once marked it will not be re-computed.
--- @param session      table   SessionRecord
--- @param instanceName string
--- @param difficultyID number
function RA:CheckFullClear(session, instanceName, difficultyID)
    if session.isFullClear then return end  -- already confirmed

    -- Find expected boss count from the saved instance list
    local totalBosses = 0
    for i = 1, GetNumSavedInstances() do
        local siName, _, _, siDiff, _, _, _, _, _, _, numEncounters, encounterProgress = GetSavedInstanceInfo(i)
        if siName == instanceName and siDiff == difficultyID then
            totalBosses = numEncounters
            -- encounterProgress == numEncounters means all bosses are down
            if encounterProgress < numEncounters then
                return  -- still bosses remaining
            end
            break
        end
    end

    if totalBosses == 0 then return end  -- instance not in saved list yet

    -- Verify our session also has that many boss records (sanity check)
    local killedInSession = 0
    for _ in pairs(session.bosses) do
        killedInSession = killedInSession + 1
    end
    if killedInSession < totalBosses then return end

    -- Find the intersection of players present for every boss
    local commonPlayers = nil
    for _, bossData in pairs(session.bosses) do
        if commonPlayers == nil then
            -- Seed with the first boss's player set
            commonPlayers = {}
            for playerKey in pairs(bossData.players) do
                commonPlayers[playerKey] = true
            end
        else
            -- Intersect: remove any player not in this boss kill
            for playerKey in pairs(commonPlayers) do
                if not bossData.players[playerKey] then
                    commonPlayers[playerKey] = nil
                end
            end
        end
    end

    -- At least one shared player = valid full clear
    if commonPlayers and next(commonPlayers) then
        session.isFullClear      = true
        session.clearedAt        = RA:Now()
        session.fullClearPlayers = commonPlayers
        RA:DebugPrint("Full clear detected for: " .. instanceName)
    end
end

-------------------------------------------------------------------------------
-- Historical self-injection migration
-- One-shot migration to add the current player to all historical boss kills.
-- This allows historical data to show the addon owner's stats via Details!.
-------------------------------------------------------------------------------

--- Injects the current player into all existing boss kill snapshots.
--- Runs once on addon load via a one-shot flag (selfInjected).
function RA:InjectSelfIntoHistory()
    if RA.db.selfInjected then return end

    local selfKey = RA:GetPlayerKey()
    local db = RA.db

    -- Build current player metadata
    local name, realm = UnitName("player")
    if not realm or realm == "" then
        realm = GetRealmName()
    else
        realm = RA:SanitiseRealm(realm)
    end

    local classToken, classID = RA:GetUnitClass("player")
    local spec  = RA:GetUnitSpec("player")
    local role  = RA:GetUnitRole("player")
    local guild = RA:GetUnitGuild("player")

    -- Create self player record if not already present
    if not db.players[selfKey] then
        db.players[selfKey] = {
            name       = name,
            realm      = realm,
            class      = classToken or "WARRIOR",
            classID    = classID    or 1,
            spec       = spec,
            role       = role,
            guild      = guild,
            firstSeen  = RA:Now(),
            lastSeen   = RA:Now(),
            totalKills = 0,
            encounters = {},
        }
    end

    local selfRecord = db.players[selfKey]

    -- Iterate all sessions and inject self into boss snapshots
    for _, session in pairs(db.sessions) do
        for encounterID, bossData in pairs(session.bosses) do
            -- Inject self into the snapshot
            bossData.players[selfKey] = true

            -- Upsert encounter record for self
            local encKey = RA:EncounterKey(encounterID, session.difficultyID)
            if not selfRecord.encounters[encKey] then
                selfRecord.encounters[encKey] = {
                    encounterID    = encounterID,
                    encounterName  = bossData.name,
                    instanceID     = session.instanceID,
                    instanceName   = session.instanceName,
                    difficultyID   = session.difficultyID,
                    difficultyName = RA:GetDifficultyName(session.difficultyID),
                    count          = 0,
                    firstKill      = bossData.killedAt or RA:Now(),
                    lastKill       = bossData.killedAt or RA:Now(),
                    wasAOTC        = false,
                    wasCE          = false,
                }
            end

            -- Increment kill count
            selfRecord.encounters[encKey].count = selfRecord.encounters[encKey].count + 1
            selfRecord.encounters[encKey].lastKill = bossData.killedAt or RA:Now()
        end
    end

    -- Recount total kills for self
    local totalCount = 0
    for _ in pairs(selfRecord.encounters) do
        totalCount = totalCount + 1
    end
    selfRecord.totalKills = totalCount

    -- Mark migration as complete
    RA.db.selfInjected = true

    RA:DebugPrint("Historical self-injection migration complete.")
end

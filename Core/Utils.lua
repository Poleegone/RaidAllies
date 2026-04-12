-- RaidAllies: Shared utility functions.
-- Difficulty maps, human-readable time formatting, unit info helpers.

local ADDON_NAME, RA = ...

-------------------------------------------------------------------------------
-- Difficulty mappings
-- difficultyID values as returned by GetInstanceInfo() and ENCOUNTER_END.
-------------------------------------------------------------------------------

-- Maps difficultyID → normalised category used for colouring / filtering.
RA.DIFFICULTY_CATEGORY = {
    -- LFR
    [7]  = "LFR",
    [17] = "LFR",
    -- Normal (5-man and raid)
    [1]  = "NORMAL",
    [3]  = "NORMAL",
    [4]  = "NORMAL",
    [9]  = "NORMAL",
    [14] = "NORMAL",
    -- Heroic (5-man and raid)
    [2]  = "HEROIC",
    [5]  = "HEROIC",
    [6]  = "HEROIC",
    [15] = "HEROIC",
    -- Mythic (5-man and raid)
    [8]  = "MYTHIC",
    [16] = "MYTHIC",
    [23] = "MYTHIC",
    -- Timewalking
    [24] = "NORMAL",
    [33] = "NORMAL",
}

-- Difficulty category → display colour (RGB, 0-1 range, for use with texture colours).
RA.DIFFICULTY_COLORS = {
    LFR    = { r = 0.13, g = 0.73, b = 0.20 },   -- green
    NORMAL = { r = 0.20, g = 0.48, b = 0.90 },   -- blue
    HEROIC = { r = 0.64, g = 0.21, b = 0.93 },   -- purple
    MYTHIC = { r = 1.00, g = 0.50, b = 0.00 },   -- orange
}

--- Returns the normalised difficulty category string for a difficultyID.
--- Falls back to "Normal" for unknown IDs.
--- @param difficultyID number
--- @return string  "LFR" | "Normal" | "Heroic" | "Mythic"
function RA:GetDifficultyCategory(difficultyID)
    return RA.DIFFICULTY_CATEGORY[difficultyID] or "Normal"
end

--- Returns the colour table { r, g, b } for a difficultyID.
--- @param difficultyID number
--- @return table
function RA:GetDifficultyColor(difficultyID)
    local cat = RA:GetDifficultyCategory(difficultyID)
    return RA.DIFFICULTY_COLORS[cat] or RA.DIFFICULTY_COLORS.NORMAL
end

--- Returns a human-readable difficulty name for display.
--- Prefers the game's own string (via GetDifficultyInfo) and falls back to category.
--- @param difficultyID number
--- @return string
function RA:GetDifficultyName(difficultyID)
    if GetDifficultyInfo then
        local name = GetDifficultyInfo(difficultyID)
        if name and name ~= "" then
            return name
        end
    end
    return RA:GetDifficultyCategory(difficultyID)
end

-------------------------------------------------------------------------------
-- Time helpers
-------------------------------------------------------------------------------

--- Returns the current Unix timestamp.
--- @return number
function RA:Now()
    return time()
end

--- Formats a past timestamp as a human-readable "X ago" string.
--- @param timestamp number  Unix timestamp of the past event
--- @return string           e.g. "2 days ago", "4 years, 2 months ago"
function RA:TimeAgo(timestamp)
    local delta = RA:Now() - timestamp
    if delta < 0 then delta = 0 end

    if delta < 60 then
        return delta .. " second" .. (delta == 1 and "" or "s") .. " ago"
    elseif delta < 3600 then
        local m = math.floor(delta / 60)
        return m .. " minute" .. (m == 1 and "" or "s") .. " ago"
    elseif delta < 86400 then
        local h = math.floor(delta / 3600)
        return h .. " hour" .. (h == 1 and "" or "s") .. " ago"
    elseif delta < 86400 * 30 then
        local d = math.floor(delta / 86400)
        return d .. " day" .. (d == 1 and "" or "s") .. " ago"
    elseif delta < 86400 * 365 then
        local mo = math.floor(delta / (86400 * 30))
        return mo .. " month" .. (mo == 1 and "" or "s") .. " ago"
    else
        local y  = math.floor(delta / (86400 * 365))
        local mo = math.floor((delta % (86400 * 365)) / (86400 * 30))
        local s  = y .. " year" .. (y == 1 and "" or "s")
        if mo > 0 then
            s = s .. ", " .. mo .. " month" .. (mo == 1 and "" or "s")
        end
        return s .. " ago"
    end
end

-------------------------------------------------------------------------------
-- Unit / roster helpers
-------------------------------------------------------------------------------

--- Returns the class token and numeric class ID for a unit.
--- @param unit string  e.g. "raid1", "party2"
--- @return string|nil classToken, number|nil classID
function RA:GetUnitClass(unit)
    local _, classToken, classID = UnitClass(unit)
    return classToken, classID
end

--- Returns the assigned group role for a unit.
--- @param unit string
--- @return string  "TANK" | "HEALER" | "DAMAGER"
function RA:GetUnitRole(unit)
    local role = UnitGroupRolesAssigned(unit)
    -- Fall back to DAMAGER if the role is not set (e.g. very old content)
    if not role or role == "NONE" or role == "" then
        return "DAMAGER"
    end
    return role
end

--- Returns the guild name for a unit, or nil if unguilded / unavailable.
--- @param unit string
--- @return string|nil
function RA:GetUnitGuild(unit)
    local guild = GetGuildInfo(unit)
    return (guild and guild ~= "") and guild or nil
end

--- Returns the specialization ID for a unit, or nil if unavailable.
--- @param unit string
--- @return number|nil  specID
function RA:GetUnitSpec(unit)
    local specID = GetInspectSpecialization(unit)
    return specID and specID > 0 and specID or nil
end

--- Returns the player's own realm name.
--- @return string
function RA:GetPlayerRealm()
    return GetRealmName()
end

--- Returns the PlayerKey for the logged-in character.
--- @return string
function RA:GetPlayerKey()
    local name  = UnitName("player")
    local realm = GetRealmName()
    return RA:PlayerKey(name, realm)
end

--- Sanitises a realm string returned by UnitName() — strips leading/trailing
--- whitespace and normalises connected-realm separator formatting.
--- @param realm string
--- @return string
function RA:SanitiseRealm(realm)
    -- Connected realm names can come back as "Realm1 - Realm2"; normalise to "Realm1-Realm2"
    realm = realm:gsub("%s*%-%s*", "-")
    realm = realm:match("^%s*(.-)%s*$")  -- trim
    return realm
end

--- Searches the current raid group for a unit token matching the given name+realm.
--- Returns the unit token (e.g. "raid3") or nil if not found / not in group.
--- @param name  string
--- @param realm string
--- @return string|nil
function RA:FindUnitToken(name, realm)
    if not IsInRaid() then return nil end
    local numMembers = GetNumGroupMembers()
    for i = 1, numMembers do
        local unit = "raid" .. i
        if UnitExists(unit) then
            local uName, uRealm = UnitName(unit)
            if uName == name then
                if not uRealm or uRealm == "" then
                    uRealm = GetRealmName()
                else
                    uRealm = RA:SanitiseRealm(uRealm)
                end
                if uRealm == realm then
                    return unit
                end
            end
        end
    end
    return nil
end

-------------------------------------------------------------------------------
-- Debug output
-------------------------------------------------------------------------------

--- Prints a debug-level message when RA.DEBUG is true.
--- @param msg string
function RA:DebugPrint(msg)
    if RA.DEBUG then
        print("|cff888888[RaidAllies Debug]|r " .. tostring(msg))
    end
end

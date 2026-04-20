local addonName, RaidAllies = ...

local Session = {
    active = false,
    startTime = 0,
    players = {},
    bosses = 0,
    isTest = false,
    raidName = nil,
    bestDiff = nil,
}
RaidAllies.Session = Session

function Session:IsActive()
    return self.active
end

function Session:Start()
    if self.active then return end
    self.active = true
    self.startTime = time()
    self.players = {}
    self.bosses = 0
    self.isTest = false
    self.raidName = nil
    self.bestDiff = nil
    self.isMythicPlus = false
    self.mplusLevel = nil
    self.mplusDungeon = nil
end

function Session:RecordContext(raidName, difficultyID)
    if raidName and raidName ~= "" then
        self.raidName = raidName
    end
    local diff = RaidAllies.Data:DiffFromID(difficultyID)
    if diff and RaidAllies.Data:DiffRank(diff) > RaidAllies.Data:DiffRank(self.bestDiff) then
        self.bestDiff = diff
    end
end

function Session:AddPlayer(name, unit)
    if not name then return end
    local selfName = RaidAllies:GetUnitFullName("player")
    if selfName and name == selfName then return end
    if not self.players[name] then
        self.players[name] = {
            kills = 0,
            joinedAt = time(),
        }
    end
    if unit and UnitExists(unit) then
        local _, classToken = UnitClass(unit)
        if classToken then
            self.players[name].class = classToken
        end
        local role = UnitGroupRolesAssigned and UnitGroupRolesAssigned(unit)
        if role and role ~= "NONE" then
            self.players[name].role = role
        end
    end
end

-- Populate the session player cache from the live group roster without
-- incrementing kill counts. Keeps sessionPlayers warm so snapshots remain
-- valid even if the group disbands immediately after completion.
function Session:SyncRosterFromGroup()
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local unit = "raid" .. i
            local fullName = RaidAllies:GetUnitFullName(unit)
            if fullName then
                self:AddPlayer(fullName, unit)
            end
        end
    elseif IsInGroup() then
        local playerName = RaidAllies:GetUnitFullName("player")
        if playerName then
            self:AddPlayer(playerName, "player")
        end
        for i = 1, GetNumGroupMembers() - 1 do
            local unit = "party" .. i
            local fullName = RaidAllies:GetUnitFullName(unit)
            if fullName then
                self:AddPlayer(fullName, unit)
            end
        end
    end
end

function Session:RecordBossKill()
    self.bosses = self.bosses + 1

    -- Snapshot current raid roster
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local unit = "raid" .. i
            local fullName = RaidAllies:GetUnitFullName(unit)
            if fullName then
                self:AddPlayer(fullName, unit)
                self.players[fullName].kills = self.players[fullName].kills + 1
            end
        end
    elseif IsInGroup() then
        local playerName = RaidAllies:GetUnitFullName("player")
        if playerName then
            self:AddPlayer(playerName, "player")
            self.players[playerName].kills = self.players[playerName].kills + 1
        end
        for i = 1, GetNumGroupMembers() - 1 do
            local unit = "party" .. i
            local fullName = RaidAllies:GetUnitFullName(unit)
            if fullName then
                self:AddPlayer(fullName, unit)
                self.players[fullName].kills = self.players[fullName].kills + 1
            end
        end
    end
end

function Session:BuildEndSnapshot()
    local list = {}
    local bosses = self.bosses
    for name, info in pairs(self.players) do
        list[#list + 1] = {
            name = name,
            kills = info.kills,
            class = info.class,
            role = info.role,
            fullClear = (bosses > 0 and info.kills == bosses),
        }
    end
    table.sort(list, function(a, b)
        if a.kills == b.kills then return a.name < b.name end
        return a.kills > b.kills
    end)
    return {
        bosses = bosses,
        duration = time() - self.startTime,
        players = list,
    }
end

-- Capture a snapshot for a Mythic+ / Challenge Mode completion using the
-- session player cache directly. Runs synchronously at completion time so
-- the group roster can disband immediately afterwards without data loss.
function Session:CaptureChallengeCompletion(raidName, difficulty)
    if not self.active then return end

    local mplus = RaidAllies.MythicPlus
    if mplus then
        self.mplusLevel = mplus:GetLevel()
        self.mplusDungeon = mplus:GetDungeonName()
    end
    if raidName and raidName ~= "" then self.raidName = raidName end

    -- Credit each session player with one interaction. M+ runs don't fire
    -- ENCOUNTER_END, so without this bump Session:End() would commit
    -- kills=0 and these players would never accrue trust.
    for _, info in pairs(self.players) do
        info.kills = (info.kills or 0) + 1
    end

    -- Read directly from the session player cache. The cache is kept warm
    -- via GROUP_ROSTER_UPDATE during the run, so it stays valid even if
    -- the group disbands before this event fires.
    local snapshot = self:BuildEndSnapshot()
    if not snapshot.players or #snapshot.players == 0 then
        if RaidAllies.Print then
            RaidAllies:Print("Snapshot skipped: no session players recorded.")
        end
        return
    end

    local sessionId = tostring(self.startTime) .. "-mplus-" .. tostring(time())
    if RaidAllies.Snapshots and RaidAllies.Snapshots.Capture then
        RaidAllies.Snapshots:Capture(snapshot, {
            sessionId = sessionId,
            raidName = raidName,
            difficulty = difficulty,
            outcome = "Timed",
        })
    end
end

-- Test helpers: populate/advance a fake session without requiring a real raid roster.
local TEST_POOL = {
    "Playerone-TarrenMill",
    "Playertwo-Kazzak",
    "Playerthree-Draenor",
    "Playerfour-Silvermoon",
    "Playerfive-Ravencrest",
    "Playersix-TwistingNether",
    "Playerseven-Stormscale",
    "Playereight-Argent",
    "Playernine-Outland",
    "Playerten-Sylvanas",
}

local TEST_CLASSES = {
    "WARRIOR","PALADIN","HUNTER","ROGUE","PRIEST",
    "SHAMAN","MAGE","WARLOCK","MONK","DRUID",
}

local TEST_ROLES = {
    "TANK","TANK","DAMAGER","DAMAGER","HEALER",
    "HEALER","DAMAGER","DAMAGER","DAMAGER","HEALER",
}

function Session:TestStart()
    self:Start()
    self.isTest = true
    self.raidName = "Test Raid"
    self.bestDiff = "Heroic"
    for i, name in ipairs(TEST_POOL) do
        self:AddPlayer(name)
        self.players[name].class = TEST_CLASSES[((i - 1) % #TEST_CLASSES) + 1]
        self.players[name].role = TEST_ROLES[((i - 1) % #TEST_ROLES) + 1]
    end
end

function Session:TestKill()
    if not self.active then self:TestStart() end
    self.bosses = self.bosses + 1
    for _, info in pairs(self.players) do
        info.kills = info.kills + 1
    end
end

function Session:End()
    if not self.active then return end

    local snapshot = self:BuildEndSnapshot()
    local wasTest = self.isTest
    local now = time()

    local mplus = RaidAllies.MythicPlus
    local mplusLevel = self.mplusLevel or ((mplus and mplus:IsActive()) and mplus:GetLevel() or nil)
    local mplusDungeon = self.mplusDungeon or ((mplus and mplus:IsActive()) and mplus:GetDungeonName() or nil)

    for _, entry in ipairs(snapshot.players) do
        RaidAllies.Data:CommitSessionPlayer(entry.name, entry.kills, entry.fullClear, now, wasTest, self.raidName, self.bestDiff, mplusDungeon, mplusLevel)
        if entry.class then
            RaidAllies.Data:SetClass(entry.name, entry.class)
        end
        if entry.role then
            RaidAllies.Data:SetRole(entry.name, entry.role)
        end
    end

    RaidAllies.Data:Prune()

    RaidAllies.lastSession = snapshot

    -- Capture group snapshot (once per session).
    local sessionId = tostring(self.startTime) .. "-" .. tostring(now)
    RaidAllies.lastSessionId = sessionId
    if RaidAllies.Snapshots and RaidAllies.Snapshots.Capture then
        RaidAllies.Snapshots:Capture(snapshot, { sessionId = sessionId })
    end

    -- Destroy session object
    self.active = false
    self.startTime = 0
    self.players = {}
    self.bosses = 0
    self.isTest = false

    -- Defer summary display until after loading screen clears.
    RaidAllies.pendingSummary = snapshot
    if wasTest then
        -- Test sessions end outside a real instance transition; show immediately.
        RaidAllies.pendingSummary = nil
        if RaidAllies.UI_Summary and RaidAllies.UI_Summary.Show then
            RaidAllies.UI_Summary:Show(snapshot)
        end
    end
end

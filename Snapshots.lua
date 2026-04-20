local addonName, RaidAllies = ...

local Snapshots = {}
RaidAllies.Snapshots = Snapshots

function Snapshots:Init()
    if type(RaidAlliesDB) ~= "table" then RaidAlliesDB = {} end
    if type(RaidAlliesDB.snapshots) ~= "table" then
        RaidAlliesDB.snapshots = {}
    end
end

local function GetInstanceContext()
    if not GetInstanceInfo then return "Unknown", "" end
    local name, instanceType, difficultyID, difficultyName = GetInstanceInfo()
    if instanceType ~= "raid" and instanceType ~= "party" then
        return name or "Unknown", difficultyName or ""
    end
    return name or "Unknown", difficultyName or ""
end

-- Build a snapshot record from a session summary (from Session:BuildEndSnapshot).
-- Returns the snapshot key on success, or nil if skipped.
function Snapshots:Capture(sessionSnap, opts)
    if not sessionSnap or not sessionSnap.players then return nil end
    self:Init()

    opts = opts or {}

    if opts.sessionId and self._lastSessionId == opts.sessionId then
        -- Already captured for this session.
        return nil
    end

    local raidName, difficulty = GetInstanceContext()
    if opts.raidName then raidName = opts.raidName end
    if opts.difficulty then difficulty = opts.difficulty end

    local bosses = sessionSnap.bosses or 0
    local outcome
    if opts.outcome then
        outcome = opts.outcome
    elseif bosses <= 0 then
        outcome = "None"
    else
        local fullClearCount = 0
        for _, e in ipairs(sessionSnap.players) do
            if e.fullClear then fullClearCount = fullClearCount + 1 end
        end
        outcome = (fullClearCount > 0) and "Full Clear" or "Partial"
    end

    local players = {}
    for _, e in ipairs(sessionSnap.players) do
        local rec = RaidAllies.Data:Get(e.name)
        local trust = rec and select(1, RaidAllies.Data:TrustLevel(rec)) or "Unknown"
        local note = rec and rec.note or nil
        players[e.name] = {
            role = e.role or (rec and rec.role) or nil,
            class = e.class or (rec and rec.class) or nil,
            trust = trust,
            note = note,
            kills = e.kills or 0,
        }
    end

    local key = tostring(time()) .. "-" .. tostring(math.random(1000, 9999))
    RaidAlliesDB.snapshots[key] = {
        raidName = raidName,
        difficulty = difficulty,
        date = time(),
        players = players,
        outcome = outcome,
        bosses = bosses,
        duration = sessionSnap.duration or 0,
    }

    if opts.sessionId then self._lastSessionId = opts.sessionId end
    self._lastCapturedKey = key
    return key
end

function Snapshots:GetAll()
    self:Init()
    local list = {}
    for key, snap in pairs(RaidAlliesDB.snapshots) do
        list[#list + 1] = { key = key, snap = snap }
    end
    table.sort(list, function(a, b) return (a.snap.date or 0) > (b.snap.date or 0) end)
    return list
end

function Snapshots:Get(key)
    self:Init()
    return RaidAlliesDB.snapshots[key]
end

function Snapshots:IsLastCaptured(sessionId)
    return sessionId and self._lastSessionId == sessionId
end

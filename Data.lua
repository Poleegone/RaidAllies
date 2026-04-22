local addonName, RaidAllies = ...

local Data = {}
RaidAllies.Data = Data

function Data:Init()
    if type(RaidAlliesDB) ~= "table" then
        RaidAlliesDB = {}
    end
    if type(RaidAlliesDB.players) ~= "table" then
        RaidAlliesDB.players = {}
    end
    if type(RaidAlliesDB.enableMythicPlus) ~= "boolean" then
        RaidAlliesDB.enableMythicPlus = true
    end
    if RaidAllies.MythicPlus then
        RaidAllies.MythicPlus:SetEnabled(RaidAlliesDB.enableMythicPlus)
    end
    -- Ensure each player record has required fields
    for key, rec in pairs(RaidAlliesDB.players) do
        if type(rec) ~= "table" then
            RaidAlliesDB.players[key] = nil
        else
            rec.k = rec.k or 0
            rec.fc = rec.fc or 0
            rec.ls = rec.ls or 0
            rec.isTest = rec.isTest or false
            rec.hidden = rec.hidden or false
            rec.class = rec.class or nil
            rec.role = rec.role or nil
            rec.lastRaid = rec.lastRaid or nil
            rec.bestDiff = rec.bestDiff or nil
            if type(rec.flags) ~= "table" then
                rec.flags = { p = false, like = false, avoid = false }
            else
                rec.flags.p = rec.flags.p or false
                rec.flags.like = rec.flags.like or false
                rec.flags.avoid = rec.flags.avoid or false
            end
        end
    end
end

function Data:Get(name)
    if not name then return nil end
    return RaidAlliesDB.players[name]
end

function Data:GetOrCreate(name, isTest)
    if not name then return nil end
    local p = RaidAlliesDB.players[name]
    if not p then
        p = {
            k = 0,
            fc = 0,
            ls = 0,
            isTest = isTest and true or false,
            flags = { p = false, like = false, avoid = false },
        }
        RaidAlliesDB.players[name] = p
    end
    return p
end

function Data:SetClass(name, class)
    if not name or not class then return end
    local p = self:Get(name)
    if p then p.class = class end
end

function Data:SetRole(name, role)
    if not name or not role or role == "NONE" then return end
    local p = self:Get(name)
    if p then p.role = role end
end

function Data:ClearTestPlayers()
    local removed = 0
    for key, rec in pairs(RaidAlliesDB.players) do
        if rec.isTest then
            RaidAlliesDB.players[key] = nil
            removed = removed + 1
        end
    end
    return removed
end

function Data:SetPinned(name, value)
    local p = self:GetOrCreate(name)
    if p then p.flags.p = value and true or false end
end

function Data:SetLike(name, value)
    local p = self:GetOrCreate(name)
    if p then
        p.flags.like = value and true or false
        if p.flags.like then p.flags.avoid = false end
    end
end

function Data:SetAvoid(name, value)
    local p = self:GetOrCreate(name)
    if p then
        p.flags.avoid = value and true or false
        if p.flags.avoid then p.flags.like = false end
    end
end

function Data:SetHidden(name, value)
    local p = self:Get(name)
    if not p then return end
    p.hidden = value and true or false
end

function Data:IsHidden(name)
    local p = self:Get(name)
    return p and p.hidden or false
end

function Data:SetNote(name, note)
    local p = self:GetOrCreate(name)
    if not p then return end
    if type(note) ~= "string" then note = "" end
    note = note:gsub("^%s+", ""):gsub("%s+$", "")
    if note == "" then
        p.note = nil
    else
        p.note = note
    end
end

function Data:Prune()
    local players = RaidAlliesDB.players
    local now = time()
    local maxAge = RaidAllies.MAX_AGE
    local maxPlayers = RaidAllies.MAX_PLAYERS

    -- Age-based removal (skip pinned and test players)
    for key, rec in pairs(players) do
        if not rec.isTest and (not rec.flags or not rec.flags.p) then
            if rec.ls and (now - rec.ls) > maxAge then
                players[key] = nil
            end
        end
    end

    -- Count (test players don't count toward limits)
    local count = 0
    local list = {}
    for key, rec in pairs(players) do
        if not rec.isTest then
            count = count + 1
            if not rec.flags or not rec.flags.p then
                list[#list + 1] = { key = key, ls = rec.ls or 0 }
            end
        end
    end

    if count <= maxPlayers then return end

    table.sort(list, function(a, b) return a.ls < b.ls end)

    local toRemove = count - maxPlayers
    for i = 1, toRemove do
        local entry = list[i]
        if not entry then break end
        players[entry.key] = nil
    end
end

function Data:TrustScore(rec)
    if not rec then return 0 end
    local flags = rec.flags or {}
    return (rec.k or 0) * 2
        + (rec.fc or 0) * 5
        + (flags.p and 3 or 0)
        + (flags.like and 2 or 0)
        - (flags.avoid and 10 or 0)
end

function Data:TrustLevel(rec)
    if not rec then return "Unknown", 0 end
    if rec.flags and rec.flags.avoid then return "Avoid", self:TrustScore(rec) end
    local s = self:TrustScore(rec)
    if s >= 15 then return "Trusted", s end
    if s >= 5 then return "Neutral", s end
    return "Unknown", s
end

-- Difficulty helpers. Mapped from Blizzard difficulty IDs to a compact enum.
-- Ranks: Mythic > Heroic > Normal > LFR.
local DIFF_ENUM = {
    [17] = "LFR", [14] = "Normal", [15] = "Heroic", [16] = "Mythic",
    -- legacy raid difficulties
    [7]  = "LFR", [3]  = "Normal", [4]  = "Normal", [5]  = "Heroic", [6]  = "Heroic",
    [9]  = "Mythic",
}
local DIFF_RANK = { LFR = 1, Normal = 2, Heroic = 3, Mythic = 4 }
local DIFF_TAG  = { LFR = "LFR", Normal = "NM", Heroic = "HC", Mythic = "M" }

function Data:DiffFromID(difficultyID)
    if not difficultyID then return nil end
    return DIFF_ENUM[difficultyID]
end

function Data:DiffRank(diff)
    return diff and DIFF_RANK[diff] or 0
end

function Data:DiffTag(diff)
    return diff and DIFF_TAG[diff] or nil
end

function Data:CommitSessionPlayer(name, sessionKills, wasFullClear, timestamp, isTest, raidName, diff, mplusDungeon, mplusLevel)
    local p = self:GetOrCreate(name, isTest)
    if not p then return end
    if isTest then p.isTest = true end
    p.k = (p.k or 0) + (sessionKills or 0)
    p.ls = timestamp or time()
    if wasFullClear then
        p.fc = (p.fc or 0) + 1
    end
    if raidName and raidName ~= "" then
        p.lastRaid = raidName
    end
    if diff and self:DiffRank(diff) > self:DiffRank(p.bestDiff) then
        p.bestDiff = diff
    end
    if mplusDungeon and mplusDungeon ~= "" then
        p.lastDungeon = mplusDungeon
    end
    if mplusLevel and type(mplusLevel) == "number" and mplusLevel > 0 then
        if not p.bestMythicPlusLevel or mplusLevel > p.bestMythicPlusLevel then
            p.bestMythicPlusLevel = mplusLevel
        end
    end
end

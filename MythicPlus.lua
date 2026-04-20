local addonName, RaidAllies = ...

-- Isolated Mythic+ tracking layer.
-- Reuses the existing Session lifecycle; does not introduce a parallel
-- session system. Remove this file + its .toc entry + the 3 guarded call
-- sites in Events.lua / Session.lua to fully uninstall the feature.

local MythicPlus = {
    enabled = false,   -- feature flag (enableMythicPlusTracking)
    active = false,    -- inside a tracked keystone run right now
    mapId = nil,
    level = nil,
    dungeonName = nil,
}
RaidAllies.MythicPlus = MythicPlus

function MythicPlus:IsEnabled()
    return self.enabled == true
end

function MythicPlus:SetEnabled(v)
    self.enabled = v and true or false
    if not self.enabled then
        self.active = false
        self.mapId, self.level, self.dungeonName = nil, nil, nil
    end
end

function MythicPlus:IsActive()
    return self.enabled and self.active
end

-- Validate we are in a Mythic Keystone run (not Normal/Heroic/Mythic0/Timewalking).
local function IsKeystoneRun()
    if not C_ChallengeMode then return false end
    local inInstance, instanceType = IsInInstance()
    if not inInstance or instanceType ~= "party" then return false end
    local activeMap = C_ChallengeMode.GetActiveKeystoneInfo
        and select(1, C_ChallengeMode.GetActiveKeystoneInfo())
    if not activeMap or activeMap == 0 then
        -- Fallback: GetActiveChallengeMapID
        local mapId = C_ChallengeMode.GetActiveChallengeMapID
            and C_ChallengeMode.GetActiveChallengeMapID()
        return mapId and mapId ~= 0
    end
    return true
end

function MythicPlus:OnChallengeModeStart()
    if not self.enabled then return false end
    if not IsKeystoneRun() then return false end

    self.active = true
    self.mapId = C_ChallengeMode and C_ChallengeMode.GetActiveChallengeMapID
        and C_ChallengeMode.GetActiveChallengeMapID() or nil
    if C_ChallengeMode and C_ChallengeMode.GetActiveKeystoneInfo then
        local _, keyLevel = C_ChallengeMode.GetActiveKeystoneInfo()
        self.level = keyLevel
    end
    if self.mapId and C_ChallengeMode.GetMapUIInfo then
        self.dungeonName = C_ChallengeMode.GetMapUIInfo(self.mapId)
    end
    if not self.dungeonName and GetInstanceInfo then
        self.dungeonName = GetInstanceInfo()
    end
    return true
end

function MythicPlus:OnChallengeModeCompleted()
    if not self.enabled or not self.active then return false end

    -- Pull completion info for the concrete key level if available.
    if C_ChallengeMode and C_ChallengeMode.GetCompletionInfo then
        local mapId, level = C_ChallengeMode.GetCompletionInfo()
        if mapId and mapId ~= 0 then self.mapId = mapId end
        if level and level > 0 then self.level = level end
    end
    if self.mapId and C_ChallengeMode and C_ChallengeMode.GetMapUIInfo then
        local name = C_ChallengeMode.GetMapUIInfo(self.mapId)
        if name then self.dungeonName = name end
    end
    return true
end

-- Build the dungeon context string used in snapshot difficulty / summary.
-- e.g. "+12 Halls of Valor".
function MythicPlus:GetContextString()
    if not self.active then return nil end
    local lvl = self.level and ("+" .. tostring(self.level)) or "M+"
    if self.dungeonName and self.dungeonName ~= "" then
        return lvl .. " " .. self.dungeonName
    end
    return lvl
end

function MythicPlus:GetDungeonName()
    return self.dungeonName
end

function MythicPlus:GetLevel()
    return self.level
end

function MythicPlus:Reset()
    self.active = false
    self.mapId, self.level, self.dungeonName = nil, nil, nil
end

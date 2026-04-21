local addonName, RaidAllies = ...

local Presence = {}
RaidAllies.Presence = Presence

local cache = {}
local dirty = true

local function NormalizeKey(name, realm)
    if not name or name == "" then return nil end
    if not realm or realm == "" then
        if name:find("-") then return name end
        realm = GetNormalizedRealmName() or GetRealmName()
    end
    if not realm or realm == "" then return nil end
    realm = realm:gsub("%s+", "")
    if name:find("-") then return name end
    return name .. "-" .. realm
end

local function ScanRecentAllies()
    if not C_RecentAllies or not C_RecentAllies.GetRecentAllies then return end
    local list = C_RecentAllies.GetRecentAllies()
    if not list then return end
    for _, ally in ipairs(list) do
        local stateData = ally.stateData
        if stateData and stateData.isOnline then
            local key = NormalizeKey(ally.playerName or ally.name, ally.realmName or ally.realm)
            if key then cache[key] = true end
        end
    end
end

local function AddOnline(full)
    if full then cache[full] = true end
end

local function ScanGroup()
    local prefix = IsInRaid() and "raid" or "party"
    local n = GetNumGroupMembers() or 0
    for i = 1, n do
        local unit = prefix .. i
        if UnitExists(unit) and UnitIsConnected(unit) then
            local name, realm = UnitNameUnmodified(unit)
            if name and name ~= "" then
                AddOnline(RaidAllies:NormalizeName(name, realm))
            end
        end
    end
    if UnitIsConnected("player") then
        AddOnline(RaidAllies:GetUnitFullName("player"))
    end
end

local function ScanFriends()
    if not C_FriendList or not C_FriendList.GetNumFriends then return end
    local n = C_FriendList.GetNumFriends() or 0
    for i = 1, n do
        local info = C_FriendList.GetFriendInfoByIndex(i)
        if info and info.connected and info.name then
            AddOnline(NormalizeKey(info.name))
        end
    end
end

local function ScanGuild()
    if not IsInGuild or not IsInGuild() then return end
    if not GetNumGuildMembers then return end
    local n = GetNumGuildMembers() or 0
    for i = 1, n do
        local fullName, _, _, _, _, _, _, _, online = GetGuildRosterInfo(i)
        if online and fullName and fullName ~= "" then
            -- Guild roster names already include realm
            AddOnline(fullName)
        end
    end
end

function Presence:Rebuild()
    wipe(cache)
    ScanRecentAllies()
    ScanGroup()
    ScanFriends()
    ScanGuild()
    dirty = false
end

function Presence:Invalidate()
    dirty = true
end

function Presence:IsOnline(fullName)
    if not fullName then return false end
    if dirty then self:Rebuild() end
    return cache[fullName] == true
end

local ef = CreateFrame("Frame")
ef:RegisterEvent("FRIENDLIST_UPDATE")
ef:RegisterEvent("GUILD_ROSTER_UPDATE")
ef:RegisterEvent("GROUP_ROSTER_UPDATE")
ef:RegisterEvent("PLAYER_ENTERING_WORLD")
ef:SetScript("OnEvent", function(_, event)
    Presence:Invalidate()
    if event == "PLAYER_ENTERING_WORLD" then
        if C_FriendList and C_FriendList.ShowFriends then C_FriendList.ShowFriends() end
        if C_GuildInfo and C_GuildInfo.GuildRoster then
            C_GuildInfo.GuildRoster()
        elseif GuildRoster then
            GuildRoster()
        end
    end
    if RaidAllies.UI_Main and RaidAllies.UI_Main.frame and RaidAllies.UI_Main.frame:IsShown() then
        if RaidAllies.UI_Main.RefreshPresence then
            RaidAllies.UI_Main:RefreshPresence()
        end
    end
end)

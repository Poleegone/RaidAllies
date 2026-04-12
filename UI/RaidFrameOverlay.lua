-- RaidAllies: Raid/Party Frame Overlay
-- Displays kill-count badges and achievement icons (AOTC/CE) on default Blizzard compact unit frames
-- during raids and parties, showing historical data for players you've previously raided with.

local _, RA = ...
local T = RA.Theme

-- Cache of overlays, keyed by frame object
local overlays = {}

-- Cache of player data, keyed by playerKey
local playerDataCache = {}
local cacheNeedsClear = false

-------------------------------------------------------------------------------
-- Data helpers
-------------------------------------------------------------------------------

--- Clears the player data cache when new kills are recorded.
function RA:_InvalidateOverlayCache()
    cacheNeedsClear = true
end

--- Returns overlay data for a player, or nil if not found.
--- Caches the result to avoid repeated encounter table iteration.
local function GetOverlayData(playerKey)
    if cacheNeedsClear then
        playerDataCache = {}
        cacheNeedsClear = false
    end

    if playerDataCache[playerKey] then
        return playerDataCache[playerKey]
    end

    if not RA.db or not RA.db.players then return nil end

    local record = RA.db.players[playerKey]
    if not record then return nil end

    -- Derive AOTC/CE status from encounters
    local everAOTC, everCE = false, false
    if record.encounters then
        for _, enc in pairs(record.encounters) do
            if enc.wasAOTC then everAOTC = true end
            if enc.wasCE   then everCE   = true end
        end
    end

    local data = {
        totalKills = record.totalKills or 0,
        everAOTC   = everAOTC,
        everCE     = everCE,
    }
    playerDataCache[playerKey] = data
    return data
end

-------------------------------------------------------------------------------
-- Overlay creation and management
-------------------------------------------------------------------------------

--- Gets or creates the overlay frame for a compact unit frame.
local function GetOrCreateOverlay(frame)
    if overlays[frame] then
        return overlays[frame]
    end

    local o = CreateFrame("Frame", nil, frame)
    o:SetFrameLevel(frame:GetFrameLevel() + 5)

    -- Kill count badge (bottom-right corner)
    o.killText = o:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    T:ApplyFont(o.killText, 9)
    o.killText:SetJustifyH("CENTER")

    -- Achievement icon (top-right corner)
    o.achText = o:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    T:ApplyFont(o.achText, 10)
    o.achText:SetJustifyH("CENTER")

    overlays[frame] = o
    return o
end

--- Updates the overlay for a compact unit frame.
local function UpdateOverlay(frame)
    if not RA.db or not RA.db.settings.showOverlay then
        local o = overlays[frame]
        if o then o:Hide() end
        return
    end

    if not frame.unit or not UnitExists(frame.unit) then
        local o = overlays[frame]
        if o then o:Hide() end
        return
    end

    -- Skip self
    if UnitIsUnit(frame.unit, "player") then
        local o = overlays[frame]
        if o then o:Hide() end
        return
    end

    -- Resolve playerKey from unit
    local name, realm = UnitName(frame.unit)
    if not name then
        local o = overlays[frame]
        if o then o:Hide() end
        return
    end

    if not realm or realm == "" then
        realm = GetRealmName()
    else
        realm = RA:SanitiseRealm(realm)
    end

    local playerKey = RA:PlayerKey(name, realm)
    local data = GetOverlayData(playerKey)

    local o = GetOrCreateOverlay(frame)
    o:SetAlpha(RA.db.settings.overlayAlpha or 1.0)

    if not data then
        o.killText:SetText("")
        o.achText:SetText("")
        o:Show()
        return
    end

    -- Show kill count (if > 0)
    if data.totalKills > 0 then
        o.killText:SetText("×" .. data.totalKills)
        o.killText:SetTextColor(T.COLOR.TEXT_ACCENT[1], T.COLOR.TEXT_ACCENT[2], T.COLOR.TEXT_ACCENT[3])
        -- Re-anchor with offsets every update
        o.killText:ClearAllPoints()
        o.killText:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT",
            -(2 - (RA.db.settings.overlayKillOffX or 0)),
            2 + (RA.db.settings.overlayKillOffY or 0))
    else
        o.killText:SetText("")
    end

    -- Show achievement icon
    if data.everCE then
        o.achText:SetText("◆")
        o.achText:SetTextColor(1.0, 0.2, 0.2)  -- red
        o.achText:ClearAllPoints()
        o.achText:SetPoint("TOPRIGHT", frame, "TOPRIGHT",
            -(2 - (RA.db.settings.overlayAchOffX or 0)),
            -(2 + (RA.db.settings.overlayAchOffY or 0)))
    elseif data.everAOTC then
        o.achText:SetText("★")
        o.achText:SetTextColor(1.0, 0.82, 0.0)  -- gold
        o.achText:ClearAllPoints()
        o.achText:SetPoint("TOPRIGHT", frame, "TOPRIGHT",
            -(2 - (RA.db.settings.overlayAchOffX or 0)),
            -(2 + (RA.db.settings.overlayAchOffY or 0)))
    else
        o.achText:SetText("")
    end

    o:Show()
end

--- Refresh all visible compact unit frames.
function RA:RefreshRaidOverlays()
    if not CompactRaidFrameContainer then return end

    local container = CompactRaidFrameContainer
    for i = 1, container:GetNumChildren() do
        local frame = select(i, container:GetChildren())
        if frame and frame.unit then
            UpdateOverlay(frame)
        end
    end

    -- Also check party frames if in a party
    if CompactPartyFrame then
        for i = 1, CompactPartyFrame:GetNumChildren() do
            local frame = select(i, CompactPartyFrame:GetChildren())
            if frame and frame.unit then
                UpdateOverlay(frame)
            end
        end
    end
end

-------------------------------------------------------------------------------
-- Hook and event handling
-------------------------------------------------------------------------------

-- Hook into the compact frame update cycle (taint-safe)
hooksecurefunc("CompactUnitFrame_UpdateAll", function(frame)
    if frame and frame.unit then
        UpdateOverlay(frame)
    end
end)

-- Refresh overlays when roster changes or player enters world
local overlayManager = CreateFrame("Frame")
overlayManager:RegisterEvent("GROUP_ROSTER_UPDATE")
overlayManager:RegisterEvent("PLAYER_ENTERING_WORLD")
overlayManager:SetScript("OnEvent", function()
    RA:RefreshRaidOverlays()
end)

-- Hook into UpsertPlayerKill so overlay cache is invalidated on new kills
local originalUpsertPlayerKill = RA.UpsertPlayerKill
function RA:UpsertPlayerKill(...)
    originalUpsertPlayerKill(self, ...)
    RA:_InvalidateOverlayCache()
end

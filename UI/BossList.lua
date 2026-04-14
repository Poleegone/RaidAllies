-- RaidAllies: BossList view
-- Shows bosses killed in a specific session (raid lockout).
-- Accessed by clicking a session row in the session list.
-- "← Back" returns to the session list.
-- Clicking a boss row opens the PlayerList for that kill.

local _, RA = ...
local T = RA.Theme

local ROW_H = 36

-------------------------------------------------------------------------------
-- View creation  (called once from MainWindow._BuildContentArea)
-------------------------------------------------------------------------------

function RA:CreateBossListView(parent)
    local view = CreateFrame("Frame", nil, parent)
    view:SetAllPoints(parent)
    view:Hide()
    RA.bossListView = view

    -- ── Header bar ────────────────────────────────────────────────────────────
    local header = CreateFrame("Frame", nil, view)
    header:SetPoint("TOPLEFT",  view, "TOPLEFT",  0, 0)
    header:SetPoint("TOPRIGHT", view, "TOPRIGHT", 0, 0)
    header:SetHeight(28)
    RA._blHeader = header

    local backBtn = RA:_MakeTextButton(header, "\226\134\144 Back", function()
        RA:ShowEncounterList()
    end)
    backBtn:SetPoint("LEFT", header, "LEFT", 0, 0)

    local sessTitle = header:CreateFontString(nil, "OVERLAY")
    T:ApplyFont(sessTitle, T:GetFontSize())
    sessTitle:SetTextColor(T.COLOR.TEXT_PRIMARY[1], T.COLOR.TEXT_PRIMARY[2], T.COLOR.TEXT_PRIMARY[3])
    sessTitle:SetPoint("LEFT",  backBtn, "RIGHT", 8, 0)
    sessTitle:SetPoint("RIGHT", header,  "RIGHT", -4, 0)
    sessTitle:SetJustifyH("LEFT")
    sessTitle:SetWordWrap(false)
    RA._blSessTitle = sessTitle

    -- Separator
    local sep = header:CreateTexture(nil, "BORDER")
    sep:SetColorTexture(T.COLOR.BORDER[1], T.COLOR.BORDER[2], T.COLOR.BORDER[3], 1)
    sep:SetPoint("BOTTOMLEFT",  header, "BOTTOMLEFT")
    sep:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT")
    sep:SetHeight(1)

    -- ── Scroll area ───────────────────────────────────────────────────────────
    local scrollParent = CreateFrame("Frame", nil, view)
    scrollParent:SetPoint("TOPLEFT",     header, "BOTTOMLEFT",  0, -4)
    scrollParent:SetPoint("BOTTOMRIGHT", view,   "BOTTOMRIGHT", 0,  0)
    RA._blScrollParent = scrollParent

    local scroll, content = RA:CreateScrollArea(scrollParent, ROW_H)
    RA._blScroll  = scroll
    RA._blContent = content

    -- Row pool
    RA._bossRowPool = {}

    -- Empty-state label
    local empty = content:CreateFontString(nil, "OVERLAY")
    T:ApplyFont(empty, 13)
    empty:SetTextColor(T.COLOR.TEXT_MUTED[1], T.COLOR.TEXT_MUTED[2], T.COLOR.TEXT_MUTED[3])
    empty:SetPoint("CENTER", content, "CENTER")
    empty:SetJustifyH("CENTER")
    empty:SetText("No bosses recorded for this session.")
    empty:Hide()
    RA._blEmptyLabel = empty
end

-------------------------------------------------------------------------------
-- Refresh
-------------------------------------------------------------------------------

function RA:RefreshBossList()
    local content    = RA._blContent
    local sessionKey = RA._currentSessionKey
    local sessData   = RA._currentSessionData
    if not content then return end

    content:SetWidth(math.max(1, RA._blScroll:GetWidth()))

    -- Hide pooled rows
    for _, row in ipairs(RA._bossRowPool) do
        row:Hide()
    end

    -- Update header title
    if RA._blSessTitle and sessData then
        local dc = T:DiffColor(sessData.difficultyID)
        RA._blSessTitle:SetText(string.format(
            "%s  |cff%02x%02x%02x[%s]|r",
            sessData.instanceName,
            dc[1] * 255, dc[2] * 255, dc[3] * 255,
            sessData.difficultyName
        ))
    end

    local bosses = sessionKey and RA:GetBossesForSession(sessionKey) or {}
    local y = 0

    for i, boss in ipairs(bosses) do
        local row = RA:_GetBossRow(i)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT",  content, "TOPLEFT",  0, -y)
        row:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -y)
        row:SetHeight(ROW_H)
        RA:_PopulateBossRow(row, boss, i, sessionKey, sessData)
        row:Show()
        y = y + ROW_H
    end

    content:SetHeight(math.max(y, RA._blScroll:GetHeight()))

    if #bosses == 0 then
        RA._blEmptyLabel:Show()
    else
        RA._blEmptyLabel:Hide()
    end
end

-------------------------------------------------------------------------------
-- Row pool
-------------------------------------------------------------------------------

function RA:_GetBossRow(i)
    local row = RA._bossRowPool[i]
    if not row then
        row = RA:_NewBossRow(RA._blContent)
        RA._bossRowPool[i] = row
    end
    return row
end

function RA:_NewBossRow(parent)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(ROW_H)

    -- ── Backgrounds ──────────────────────────────────────────────────────────
    local altBg = row:CreateTexture(nil, "BACKGROUND")
    altBg:SetAllPoints()
    altBg:SetColorTexture(0, 0, 0, 0)
    row._altBg = altBg

    -- ── Boss name (primary, left) ─────────────────────────────────────────────
    local bossLbl = row:CreateFontString(nil, "OVERLAY")
    T:ApplyFont(bossLbl, T:GetFontSize())
    bossLbl:SetTextColor(T.COLOR.TEXT_PRIMARY[1], T.COLOR.TEXT_PRIMARY[2], T.COLOR.TEXT_PRIMARY[3])
    bossLbl:SetPoint("LEFT",  row, "LEFT",  10, 2)
    bossLbl:SetPoint("RIGHT", row, "RIGHT", -130, 0)
    bossLbl:SetJustifyH("LEFT")
    bossLbl:SetWordWrap(false)
    row._bossLbl = bossLbl

    -- ── Kill time (left of player count) ───────────────────────────────────────────
    local timeLbl = row:CreateFontString(nil, "OVERLAY")
    T:ApplyFont(timeLbl, T:GetFontSize() - 2)
    timeLbl:SetTextColor(T.COLOR.TEXT_MUTED[1], T.COLOR.TEXT_MUTED[2], T.COLOR.TEXT_MUTED[3])
    timeLbl:SetPoint("LEFT", row, "LEFT", 220, 0)
    timeLbl:SetWordWrap(false)
    row._timeLbl = timeLbl

    -- ── Player count badge (right) ────────────────────────────────────────────
    local badge = CreateFrame("Frame", nil, row)
    badge:SetSize(20, 20)
    badge:SetPoint("RIGHT", row, "RIGHT", -8, 0)
    row._badge = badge

    local badgeBg = badge:CreateTexture(nil, "BACKGROUND")
    badgeBg:SetAllPoints()
    local bc = T.COLOR.BADGE_BG
    badgeBg:SetColorTexture(bc[1], bc[2], bc[3], bc[4] or 0.95)
    T:AddBorder(badge, T.COLOR.BADGE_BORDER)

    local badgeLbl = badge:CreateFontString(nil, "OVERLAY")
    T:ApplyFont(badgeLbl, T:GetFontSize() - 1)
    badgeLbl:SetTextColor(T.COLOR.TEXT_ACCENT[1], T.COLOR.TEXT_ACCENT[2], T.COLOR.TEXT_ACCENT[3])
    badgeLbl:SetAllPoints()
    badgeLbl:SetJustifyH("CENTER")
    row._badgeLbl = badgeLbl

    -- ── Hover ─────────────────────────────────────────────────────────────────
    row:SetScript("OnEnter", function(r)
        r._altBg:SetColorTexture(
            T.COLOR.BG_ROW_HOVER[1], T.COLOR.BG_ROW_HOVER[2],
            T.COLOR.BG_ROW_HOVER[3], T.COLOR.BG_ROW_HOVER[4] or 0.8
        )
    end)
    row:SetScript("OnLeave", function(r)
        local c = r._altColor
        if c then
            r._altBg:SetColorTexture(c[1], c[2], c[3], c[4])
        else
            r._altBg:SetColorTexture(0, 0, 0, 0)
        end
    end)

    -- ── Bottom separator ──────────────────────────────────────────────────────
    local sep = row:CreateTexture(nil, "BORDER")
    sep:SetColorTexture(T.COLOR.BORDER[1], T.COLOR.BORDER[2], T.COLOR.BORDER[3], 0.35)
    sep:SetPoint("BOTTOMLEFT",  row, "BOTTOMLEFT",  4, 0)
    sep:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -4, 0)
    sep:SetHeight(1)

    return row
end

-------------------------------------------------------------------------------
-- Row population
-------------------------------------------------------------------------------

function RA:_PopulateBossRow(row, boss, index, sessionKey, sessData)
    -- Alternating background
    local altColor
    if index % 2 == 0 then
        local c = T.COLOR.BG_ROW_ALT
        altColor = { c[1], c[2], c[3], c[4] or 0.55 }
    else
        altColor = { 0, 0, 0, 0 }
    end
    row._altColor = altColor
    row._altBg:SetColorTexture(altColor[1], altColor[2], altColor[3], altColor[4])

    -- Boss name
    row._bossLbl:SetText(boss.encounterName)

--[[ --Removed Kill time because pointless- 
    -- Kill time
    local timeStr = "Unknown time"
    if boss.killedAt and boss.killedAt > 0 then
        timeStr = tostring(date("%H:%M:%S", boss.killedAt))
    end
    row._timeLbl:SetText(timeStr)

]]


    -- Player count badge
    row._badgeLbl:SetText(boss.playerCount)

    -- Click → player list
    row:SetScript("OnClick", function()
        RA:ShowPlayerList(sessionKey, boss.encounterID, boss)
    end)
end

-- RaidAllies: Session List view  (file kept as EncounterList.lua for load-order compatibility)
-- Displays a scrollable history of raid sessions (one row per lockout).
-- Each row shows: instance name, difficulty, date/time, full clear badge, AOTC/CE tint.
-- Clicking a row opens the BossList view for that session.
-- Rows are pooled — created once, reused across refreshes.

local _, RA = ...
local T = RA.Theme

local ROW_H = 44   -- taller rows to accommodate two lines of text

-------------------------------------------------------------------------------
-- View creation  (called once from MainWindow._BuildContentArea)
-------------------------------------------------------------------------------

function RA:CreateEncounterListView(parent)
    local view = CreateFrame("Frame", nil, parent)
    view:SetAllPoints(parent)
    view:Hide()
    RA.encounterListView = view

    local scroll, content = RA:CreateScrollArea(view, ROW_H)
    RA._encScroll  = scroll
    RA._encContent = content

    -- Row pool
    RA._encRowPool = {}

    -- Empty-state label
    local empty = content:CreateFontString(nil, "OVERLAY")
    T:ApplyFont(empty, 13)
    empty:SetTextColor(T.COLOR.TEXT_MUTED[1], T.COLOR.TEXT_MUTED[2], T.COLOR.TEXT_MUTED[3])
    empty:SetPoint("CENTER", content, "CENTER", 0, 0)
    empty:SetJustifyH("CENTER")
    empty:SetText("No raid kills logged yet.\nKill a boss in a raid to start tracking.")
    empty:Hide()
    RA._encEmptyLabel = empty
end

-------------------------------------------------------------------------------
-- Refresh
-------------------------------------------------------------------------------

function RA:RefreshEncounterList()
    local content = RA._encContent
    if not content then return end

    content:SetWidth(math.max(1, RA._encScroll:GetWidth()))

    -- Hide all pooled rows
    for _, row in ipairs(RA._encRowPool) do
        row:Hide()
    end

    local sessions = RA:GetSessionList()
    local y = 0

    for i, sess in ipairs(sessions) do
        local row = RA:_GetEncounterRow(i)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT",  content, "TOPLEFT",  0, -y)
        row:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -y)
        row:SetHeight(ROW_H)
        RA:_PopulateEncounterRow(row, sess, i)
        row:Show()
        y = y + ROW_H
    end

    content:SetHeight(math.max(y, RA._encScroll:GetHeight()))

    if #sessions == 0 then
        RA._encEmptyLabel:Show()
    else
        RA._encEmptyLabel:Hide()
    end
end

-------------------------------------------------------------------------------
-- Row pool
-------------------------------------------------------------------------------

function RA:_GetEncounterRow(i)
    local row = RA._encRowPool[i]
    if not row then
        row = RA:_NewEncounterRow(RA._encContent)
        RA._encRowPool[i] = row
    end
    return row
end

function RA:_NewEncounterRow(parent)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(ROW_H)

    -- ── Backgrounds ──────────────────────────────────────────────────────────
    local altBg = row:CreateTexture(nil, "BACKGROUND")
    altBg:SetAllPoints()
    altBg:SetColorTexture(0, 0, 0, 0)
    row._altBg = altBg

    local achBg = row:CreateTexture(nil, "BACKGROUND")
    achBg:SetColorTexture(0, 0, 0, 0)
    achBg:SetAllPoints()
    row._achBg = achBg

    -- ── Difficulty colour stripe (left edge, 3 px) ───────────────────────────
    local stripe = row:CreateTexture(nil, "ARTWORK")
    stripe:SetWidth(3)
    stripe:SetPoint("TOPLEFT",    row, "TOPLEFT",    0, 0)
    stripe:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
    row._stripe = stripe

    -- ── Instance name (top line) ──────────────────────────────────────────────
    local instLbl = row:CreateFontString(nil, "OVERLAY")
    T:ApplyFont(instLbl, T:GetFontSize())
    instLbl:SetTextColor(T.COLOR.TEXT_PRIMARY[1], T.COLOR.TEXT_PRIMARY[2], T.COLOR.TEXT_PRIMARY[3])
    instLbl:SetPoint("TOPLEFT", row, "TOPLEFT", 10, -5)
    -- Right edge leaves room for difficulty label + full-clear badge
    instLbl:SetPoint("RIGHT", row, "RIGHT", -120, 0)
    instLbl:SetJustifyH("LEFT")
    instLbl:SetWordWrap(false)
    row._instLbl = instLbl

    -- ── Date/time (bottom line, below instance name) ──────────────────────────
    local dateLbl = row:CreateFontString(nil, "OVERLAY")
    T:ApplyFont(dateLbl, T:GetFontSize() - 2)
    dateLbl:SetTextColor(T.COLOR.TEXT_MUTED[1], T.COLOR.TEXT_MUTED[2], T.COLOR.TEXT_MUTED[3])
    dateLbl:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 10, 5)
    dateLbl:SetWordWrap(false)
    row._dateLbl = dateLbl

    -- ── Difficulty label (top right) ──────────────────────────────────────────
    local diffLbl = row:CreateFontString(nil, "OVERLAY")
    T:ApplyFont(diffLbl, T:GetFontSize() - 1)
    diffLbl:SetPoint("TOPRIGHT", row, "TOPRIGHT", -6, -5)
    diffLbl:SetJustifyH("RIGHT")
    row._diffLbl = diffLbl

    -- ── Boss/player count (bottom right) ─────────────────────────────────────
    local countLbl = row:CreateFontString(nil, "OVERLAY")
    T:ApplyFont(countLbl, T:GetFontSize() - 2)
    countLbl:SetTextColor(T.COLOR.TEXT_MUTED[1], T.COLOR.TEXT_MUTED[2], T.COLOR.TEXT_MUTED[3])
    countLbl:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -6, 5)
    countLbl:SetJustifyH("RIGHT")
    row._countLbl = countLbl

    -- ── Full clear badge ─────────────────────────────────────────────────────
    local badge = CreateFrame("Frame", nil, row)
    badge:SetSize(60, 16)
    badge:Hide()
    row._fcBadge = badge
    -- Position badge to the left of the count label
    badge:SetPoint("RIGHT", row._countLbl, "LEFT", -8, 0)
    row._fcBadge = badge

    local badgeBg = badge:CreateTexture(nil, "BACKGROUND")
    badgeBg:SetAllPoints()
    local bc = T.COLOR.FULL_CLEAR_BG
    badgeBg:SetColorTexture(bc[1], bc[2], bc[3], bc[4] or 0.70)

    T:AddBorder(badge, { bc[1] * 1.5, bc[2] * 1.5, bc[3] * 1.5, 0.60 })

    local badgeLbl = badge:CreateFontString(nil, "OVERLAY")
    T:ApplyFont(badgeLbl, 9)
    local ftc = T.COLOR.FULL_CLEAR_TEXT
    badgeLbl:SetTextColor(ftc[1], ftc[2], ftc[3])
    badgeLbl:SetAllPoints()
    badgeLbl:SetJustifyH("CENTER")
    badgeLbl:SetText("Full Clear")
    row._fcBadgeLbl = badgeLbl

    -- ── Hover highlight ───────────────────────────────────────────────────────
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

    -- ── Bottom separator ─────────────────────────────────────────────────────
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

function RA:_PopulateEncounterRow(row, sess, index)
    -- ── Alternating background ────────────────────────────────────────────────
    local altColor
    if index % 2 == 0 then
        local c = T.COLOR.BG_ROW_ALT
        altColor = { c[1], c[2], c[3], c[4] or 0.55 }
    else
        altColor = { 0, 0, 0, 0 }
    end
    row._altColor = altColor
    row._altBg:SetColorTexture(altColor[1], altColor[2], altColor[3], altColor[4])

    -- ── Achievement highlight (CE takes priority) ─────────────────────────────
    if sess.wasCE then
        local c = T.COLOR.CE_BG
        row._achBg:SetColorTexture(c[1], c[2], c[3], c[4] or 0.24)
    elseif sess.wasAOTC then
        local c = T.COLOR.AOTC_BG
        row._achBg:SetColorTexture(c[1], c[2], c[3], c[4] or 0.20)
    else
        row._achBg:SetColorTexture(0, 0, 0, 0)
    end

    -- ── Difficulty stripe ─────────────────────────────────────────────────────
    local dc = T:DiffColor(sess.difficultyID)
    row._stripe:SetColorTexture(dc[1], dc[2], dc[3], 1)

    -- ── Instance label ────────────────────────────────────────────────────────
    row._instLbl:SetText(sess.instanceName)

    -- ── Date/time label ───────────────────────────────────────────────────────
    local dateStr = "Unknown date"
    if sess.startedAt and sess.startedAt > 0 then
        dateStr = tostring(date("%d/%m %H:%M", sess.startedAt))
    end
    row._dateLbl:SetText(dateStr)

    -- ── Difficulty label ──────────────────────────────────────────────────────
    row._diffLbl:SetText(sess.difficultyName)
    row._diffLbl:SetTextColor(dc[1], dc[2], dc[3])

    -- ── Boss/player count ─────────────────────────────────────────────────────
    local countText = sess.bossCount .. " boss" .. (sess.bossCount == 1 and "" or "es")
    row._countLbl:SetText(countText)

    -- ── Full clear badge ─────────────────────────────────────────────────────
    if sess.isFullClear then
        -- Position badge between difficulty label and count
        row._fcBadge:ClearAllPoints()
        row._fcBadge:SetPoint("RIGHT", row._countLbl, "LEFT", -8, 0)
        row._fcBadge:Show()
    else
        row._fcBadge:Hide()
    end

    -- ── Click → boss list ─────────────────────────────────────────────────────
    row:SetScript("OnClick", function()
        RA:ShowBossList(sess.sessionKey, sess)
    end)
end

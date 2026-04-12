-- RaidAllies: PlayerList view
-- Shows all raiders logged for a specific boss kill within a session.
-- Accessed by clicking a row in BossList; "← Back" returns to it.
-- Rows are pooled and reused between refreshes.
-- Features: class icon, role icon, name-realm (class coloured), kill-count badge,
--           hover tooltip (WoW unit or manual + time ago), right-click context menu.

local _, RA = ...
local T = RA.Theme

-- Blizzard globals declared locally so static analysers don't warn.
local InviteUnit        = InviteUnit         ---@diagnostic disable-line: undefined-global
local ChatFrame_OpenChat = ChatFrame_OpenChat ---@diagnostic disable-line: undefined-global
local AddIgnore         = AddIgnore          ---@diagnostic disable-line: undefined-global
local EasyMenu          = EasyMenu           ---@diagnostic disable-line: undefined-global
local MenuUtil          = MenuUtil           ---@diagnostic disable-line: undefined-global
local RaiderIO          = RaiderIO           ---@diagnostic disable-line: undefined-global

local ROW_H         = 32
local ROLE_ICON_SZ  = 16
local CLASS_ICON_SZ = 20
local BADGE_W       = 44
local BADGE_H       = 18

-------------------------------------------------------------------------------
-- View creation  (called once from MainWindow._BuildContentArea)
-------------------------------------------------------------------------------

function RA:CreatePlayerListView(parent)
    local view = CreateFrame("Frame", nil, parent)
    view:SetAllPoints(parent)
    view:Hide()
    RA.playerListView = view

    -- ── Header bar ────────────────────────────────────────────────────────────
    local header = CreateFrame("Frame", nil, view)
    header:SetPoint("TOPLEFT",  view, "TOPLEFT",  0, 0)
    header:SetPoint("TOPRIGHT", view, "TOPRIGHT", 0, 0)
    header:SetHeight(28)
    RA._plHeader = header

    local backBtn = RA:_MakeTextButton(header, "\226\134\144 Back", function()
        -- Return to boss list, restoring the session context
        RA:ShowBossList(RA._currentSessionKey, RA._currentSessionData)
    end)
    backBtn:SetPoint("LEFT", header, "LEFT", 0, 0)

    local encTitle = header:CreateFontString(nil, "OVERLAY")
    T:ApplyFont(encTitle, T:GetFontSize())
    encTitle:SetTextColor(T.COLOR.TEXT_PRIMARY[1], T.COLOR.TEXT_PRIMARY[2], T.COLOR.TEXT_PRIMARY[3])
    encTitle:SetPoint("LEFT",  backBtn, "RIGHT", 8, 0)
    encTitle:SetPoint("RIGHT", header,  "RIGHT", -4, 0)
    encTitle:SetJustifyH("LEFT")
    encTitle:SetWordWrap(false)
    RA._plEncTitle = encTitle

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
    RA._plScrollParent = scrollParent

    local scroll, content = RA:CreateScrollArea(scrollParent, ROW_H)
    RA._plScroll  = scroll
    RA._plContent = content

    -- Row pool
    RA._plRowPool = {}

    -- Hidden frame for right-click context menu (EasyMenu / MenuUtil target)
    local ctxFrame = CreateFrame("Frame", "RaidAlliesContextMenu", UIParent, "UIDropDownMenuTemplate")
    ctxFrame:SetPoint("CENTER")
    ctxFrame:Hide()
    RA._contextMenuFrame = ctxFrame

    -- Empty-state label
    local empty = content:CreateFontString(nil, "OVERLAY")
    T:ApplyFont(empty, 13)
    empty:SetTextColor(T.COLOR.TEXT_MUTED[1], T.COLOR.TEXT_MUTED[2], T.COLOR.TEXT_MUTED[3])
    empty:SetPoint("CENTER", content, "CENTER")
    empty:SetJustifyH("CENTER")
    empty:SetText("No players found for this boss kill.")
    empty:Hide()
    RA._plEmptyLabel = empty
end

-------------------------------------------------------------------------------
-- Refresh
-------------------------------------------------------------------------------

function RA:RefreshPlayerList()
    local content    = RA._plContent
    local sessionKey = RA._currentSessionKey
    local encID      = RA._currentEncounterID
    local bossData   = RA._currentBossData
    if not content then return end

    content:SetWidth(math.max(1, RA._plScroll:GetWidth()))

    -- Hide pooled rows
    for _, row in ipairs(RA._plRowPool) do
        row:Hide()
    end

    -- Update title
    if RA._plEncTitle and bossData then
        RA._plEncTitle:SetText(bossData.encounterName or bossData.name or "Boss")
    end

    local players = (sessionKey and encID)
        and RA:GetPlayersForSessionBoss(sessionKey, encID)
        or {}

    local y = 0
    for i, p in ipairs(players) do
        local row = RA:_GetPlayerRow(i)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT",  content, "TOPLEFT",  0, -y)
        row:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -y)
        row:SetHeight(ROW_H)
        RA:_PopulatePlayerRow(row, p, i)
        row:Show()
        y = y + ROW_H
    end

    content:SetHeight(math.max(y, RA._plScroll:GetHeight()))

    if #players == 0 then
        RA._plEmptyLabel:Show()
    else
        RA._plEmptyLabel:Hide()
    end
end

-------------------------------------------------------------------------------
-- Row pool
-------------------------------------------------------------------------------

function RA:_GetPlayerRow(i)
    local row = RA._plRowPool[i]
    if not row then
        row = RA:_NewPlayerRow(RA._plContent)
        RA._plRowPool[i] = row
    end
    return row
end

function RA:_NewPlayerRow(parent)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(ROW_H)
    -- Online status indicator (small dot) – will be shown on hover if player is online
    local onlineIcon = row:CreateTexture(nil, "OVERLAY")
    onlineIcon:SetSize(8, 8)
    onlineIcon:SetPoint("LEFT", row._badge, "RIGHT", 6, 0) -- place after badge
    onlineIcon:SetColorTexture(0, 0.8, 0, 0.8) -- green dot
    onlineIcon:Hide()
    row._onlineIcon = onlineIcon

    -- ── Backgrounds ──────────────────────────────────────────────────────────
    local altBg = row:CreateTexture(nil, "BACKGROUND")
    altBg:SetAllPoints()
    altBg:SetColorTexture(0, 0, 0, 0)
    row._altBg = altBg

    local achBg = row:CreateTexture(nil, "BACKGROUND")
    achBg:SetAllPoints()
    achBg:SetColorTexture(0, 0, 0, 0)
    row._achBg = achBg

    -- ── Role icon ─────────────────────────────────────────────────────────────
    local roleIcon = row:CreateTexture(nil, "ARTWORK")
    roleIcon:SetSize(ROLE_ICON_SZ, ROLE_ICON_SZ)
    roleIcon:SetPoint("LEFT", row, "LEFT", 8, 0)
    row._roleIcon = roleIcon

    -- ── Class icon ────────────────────────────────────────────────────────────
    local classIcon = row:CreateTexture(nil, "ARTWORK")
    classIcon:SetSize(CLASS_ICON_SZ, CLASS_ICON_SZ)
    classIcon:SetPoint("LEFT", roleIcon, "RIGHT", 5, 0)
    row._classIcon = classIcon

    -- ── Name-Realm label ──────────────────────────────────────────────────────
    local nameLabel = row:CreateFontString(nil, "OVERLAY")
    T:ApplyFont(nameLabel, T:GetFontSize())
    nameLabel:SetPoint("LEFT",  classIcon, "RIGHT", 7, 0)
    nameLabel:SetPoint("RIGHT", row, "RIGHT", -(BADGE_W + 14), 0)
    nameLabel:SetJustifyH("LEFT")
    nameLabel:SetWordWrap(false)
    row._nameLabel = nameLabel

    -- ── Kill-count badge ──────────────────────────────────────────────────────
    local badge = CreateFrame("Frame", nil, row)
    badge:SetSize(BADGE_W, BADGE_H)
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

    -- ── Hover & tooltip ───────────────────────────────────────────────────────
    row:SetScript("OnEnter", function(r)
        r._altBg:SetColorTexture(
            T.COLOR.BG_ROW_HOVER[1], T.COLOR.BG_ROW_HOVER[2],
            T.COLOR.BG_ROW_HOVER[3], T.COLOR.BG_ROW_HOVER[4] or 0.8
        )

        local p = r._player
        if not p then return end

        GameTooltip:SetOwner(r, "ANCHOR_RIGHT")

        -- Try to use a live unit token if the player is currently in our group
        local unitToken = RA:FindUnitToken(p.name, p.realm)
        if unitToken then
            GameTooltip:SetUnit(unitToken)
            -- Show online status icon if player is connected
            if UnitIsConnected(unitToken) then
                if r._onlineIcon then r._onlineIcon:Show() end
            else
                if r._onlineIcon then r._onlineIcon:Hide() end
            end
        else
            -- Manual tooltip: coloured name line + class
            local cr, cg, cb = T:ClassColor(p.class)
            GameTooltip:AddLine(p.name .. "-" .. p.realm, cr, cg, cb)
            local classDisplay = p.class:sub(1, 1) .. p.class:sub(2):lower()
            GameTooltip:AddLine(classDisplay, 0.70, 0.70, 0.70)
            if p.guild then
                GameTooltip:AddLine("<" .. p.guild .. ">", 0.40, 0.80, 0.40)
            end
            if r._onlineIcon then r._onlineIcon:Hide() end
        end

        -- Always append time-since info
        if p.lastKill and p.lastKill > 0 then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Last kill together: " .. RA:TimeAgo(p.lastKill), 0.55, 0.55, 0.65)
        end

        GameTooltip:Show()
    end)

    row:SetScript("OnLeave", function(r)
        local c = r._altColor
        if c then
            r._altBg:SetColorTexture(c[1], c[2], c[3], c[4])
        else
            r._altBg:SetColorTexture(0, 0, 0, 0)
        end
        -- hide online status icon when no longer hovered
        if r._onlineIcon then r._onlineIcon:Hide() end
        GameTooltip:Hide()
    end)

    -- ── Right-click context menu ──────────────────────────────────────────────
    row:SetScript("OnMouseUp", function(r, btn)
        if btn ~= "RightButton" then return end
        local p = r._player
        if not p then return end

        local name  = p.name
        local realm = p.realm
        local nameRealm = name .. "-" .. realm

        -- Modern API (Dragonflight / TWW / Midnight)
        if MenuUtil and MenuUtil.CreateContextMenu then
            MenuUtil.CreateContextMenu(r, function(_, rootDescription)
                rootDescription:CreateTitle(nameRealm)
                rootDescription:CreateButton("Invite to Group", function()
                    InviteUnit(nameRealm)
                end)
                rootDescription:CreateButton("Whisper", function()
                    ChatFrame_OpenChat("/w " .. nameRealm .. " ")
                end)
                rootDescription:CreateButton("Ignore", function()
                    AddIgnore(nameRealm)
                end)
                -- RaiderIO: passive note (no direct "open profile" API exposed)
                if RaiderIO then
                    rootDescription:CreateButton("RaiderIO (hover for data)", function() end)
                end
            end)
        elseif EasyMenu then
            -- Legacy fallback
            local menuList = {
                { text = nameRealm, isTitle = true, notCheckable = true },
                { text = "Invite to Group", notCheckable = true,
                  func = function() InviteUnit(nameRealm) end },
                { text = "Whisper", notCheckable = true,
                  func = function() ChatFrame_OpenChat("/w " .. nameRealm .. " ") end },
                { text = "Ignore", notCheckable = true,
                  func = function() AddIgnore(nameRealm) end },
            }
            if RaiderIO then
                menuList[#menuList + 1] = {
                    text = "RaiderIO (hover for data)", notCheckable = true,
                    func = function() end,
                }
            end
            EasyMenu(menuList, RA._contextMenuFrame, "cursor", 0, 0, "MENU")
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

function RA:_PopulatePlayerRow(row, p, index)
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

    -- Achievement tint
    if p.wasCE then
        local c = T.COLOR.CE_BG
        row._achBg:SetColorTexture(c[1], c[2], c[3], c[4] or 0.24)
    elseif p.wasAOTC then
        local c = T.COLOR.AOTC_BG
        row._achBg:SetColorTexture(c[1], c[2], c[3], c[4] or 0.20)
    else
        row._achBg:SetColorTexture(0, 0, 0, 0)
    end

    -- Icons
    T:SetRoleIcon(row._roleIcon, p.role)
    T:SetClassIcon(row._classIcon, p.class)

    -- Name: class-coloured name + muted realm
    local cr, cg, cb = T:ClassColor(p.class)
    local mr, mg, mb = T.COLOR.TEXT_MUTED[1], T.COLOR.TEXT_MUTED[2], T.COLOR.TEXT_MUTED[3]
    row._nameLabel:SetText(string.format(
        "|cff%02x%02x%02x%s|r|cff%02x%02x%02x-%s|r",
        cr * 255, cg * 255, cb * 255, p.name,
        mr * 255, mg * 255, mb * 255, p.realm
    ))

    -- Kill-count badge (total kills with this player on this boss/difficulty)
    row._badgeLbl:SetText("\195\151" .. p.count)   -- UTF-8 × (U+00D7)

    -- Store reference for tooltip/menu handlers
    row._player = p
end

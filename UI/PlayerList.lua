-- RaidAllies: PlayerList view
-- Shows all raiders logged for a specific boss kill within a session.
-- Accessed by clicking a row in BossList; "← Back" returns to it.
-- Cards are pooled and reused between refreshes.
-- Features: card-based grid layout grouped by role, spec icon (or class icon fallback), role icon, name-realm (class coloured),
--           kill-count badge, achievement badges, guild tag, hover tooltip, right-click context menu.

local _, RA = ...
local T = RA.Theme

-- Blizzard globals declared locally so static analysers don't warn.
local ChatFrame_OpenChat = ChatFrame_OpenChat ---@diagnostic disable-line: undefined-global
local AddIgnore         = AddIgnore          ---@diagnostic disable-line: undefined-global
local EasyMenu          = EasyMenu           ---@diagnostic disable-line: undefined-global
local MenuUtil          = MenuUtil           ---@diagnostic disable-line: undefined-global
local RaiderIO          = RaiderIO           ---@diagnostic disable-line: undefined-global

-- Card and grid constants
local CARD_W        = 175
local CARD_H        = 72
local CARD_GAP      = 6
local CARD_PAD      = 6
local CLASS_ICON_SZ = 36
local ROLE_ICON_SZ  = 14
local SECTION_H     = 22
local ICON_GAP      = 4

-- Role section styling
local ROLE_COLORS = {
    TANK    = { 0.10, 0.20, 0.45, 0.50 },
    HEALER  = { 0.08, 0.35, 0.15, 0.50 },
    DAMAGER = { 0.35, 0.12, 0.08, 0.50 },
}

local ROLE_LABELS = {
    TANK    = "Tanks",
    HEALER  = "Healers",
    DAMAGER = "DPS",
}

local ROLE_ORDER = { "TANK", "HEALER", "DAMAGER" }

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

    local scroll, content = RA:CreateScrollArea(scrollParent, CARD_H)
    RA._plScroll  = scroll
    RA._plContent = content

    -- Card pool
    RA._plCardPool = {}

    -- Section headers (one per role)
    RA._plSectionHeaders = {}
    for _, role in ipairs(ROLE_ORDER) do
        local header = CreateFrame("Frame", nil, content)
        header:SetHeight(SECTION_H)
        header:Hide()

        local bg = header:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        local rc = ROLE_COLORS[role]
        bg:SetColorTexture(rc[1], rc[2], rc[3], rc[4])

        local roleIcon = header:CreateTexture(nil, "ARTWORK")
        roleIcon:SetSize(16, 16)
        roleIcon:SetPoint("LEFT", header, "LEFT", 6, 0)
        T:SetRoleIcon(roleIcon, role)

        local label = header:CreateFontString(nil, "OVERLAY")
        T:ApplyFont(label, 10)
        label:SetTextColor(T.COLOR.TEXT_MUTED[1], T.COLOR.TEXT_MUTED[2], T.COLOR.TEXT_MUTED[3])
        label:SetPoint("LEFT", roleIcon, "RIGHT", 6, 0)
        label:SetText(ROLE_LABELS[role])

        local count = header:CreateFontString(nil, "OVERLAY")
        T:ApplyFont(count, 10)
        count:SetTextColor(T.COLOR.TEXT_ACCENT[1], T.COLOR.TEXT_ACCENT[2], T.COLOR.TEXT_ACCENT[3])
        count:SetPoint("LEFT", label, "RIGHT", 4, 0)
        count:SetText("(0)")

        local sep = header:CreateTexture(nil, "BORDER")
        sep:SetColorTexture(T.COLOR.BORDER[1], T.COLOR.BORDER[2], T.COLOR.BORDER[3], 0.5)
        sep:SetPoint("BOTTOMLEFT",  header, "BOTTOMLEFT")
        sep:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT")
        sep:SetHeight(1)

        RA._plSectionHeaders[role] = {
            frame = header,
            label = label,
            count = count,
        }
    end

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

    -- Hide all pooled cards
    for _, card in ipairs(RA._plCardPool) do
        card:Hide()
    end

    -- Hide all section headers
    for _, sectionData in pairs(RA._plSectionHeaders) do
        sectionData.frame:Hide()
    end

    -- Update title
    if RA._plEncTitle and bossData then
        RA._plEncTitle:SetText(bossData.encounterName or bossData.name or "Boss")
    end

    local players = (sessionKey and encID)
        and RA:GetPlayersForSessionBoss(sessionKey, encID)
        or {}

    if #players == 0 then
        RA._plEmptyLabel:Show()
        content:SetHeight(RA._plScroll:GetHeight())
        return
    else
        RA._plEmptyLabel:Hide()
    end

    -- Group players by role (already sorted TANK → HEALER → DAMAGER by DataProvider)
    local roleGroups = {
        TANK    = {},
        HEALER  = {},
        DAMAGER = {},
    }
    for _, p in ipairs(players) do
        table.insert(roleGroups[p.role] or roleGroups.DAMAGER, p)
    end

    -- Compute grid columns
    local cardCols = math.max(1, math.floor((content:GetWidth() - CARD_GAP) / (CARD_W + CARD_GAP)))
    local cardIndex = 1  -- global card pool index
    local curY = 0       -- absolute Y position within content

    -- Iterate roles in order
    for _, role in ipairs(ROLE_ORDER) do
        local group = roleGroups[role]
        if #group > 0 then
            -- Show and position section header
            local sectionData = RA._plSectionHeaders[role]
            sectionData.frame:ClearAllPoints()
            sectionData.frame:SetPoint("TOPLEFT",  content, "TOPLEFT",  0, -curY)
            sectionData.frame:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -curY)
            sectionData.count:SetText("(" .. #group .. ")")
            sectionData.frame:Show()
            curY = curY + SECTION_H + CARD_GAP

            -- Place cards in a grid
            local cardRow = 0
            local cardCol = 0
            for _, p in ipairs(group) do
                local card = RA:_GetCard(cardIndex)

                -- Compute card position
                local cardX = CARD_GAP + cardCol * (CARD_W + CARD_GAP)
                local cardY = curY + cardRow * (CARD_H + CARD_GAP)

                card:ClearAllPoints()
                card:SetPoint("TOPLEFT", content, "TOPLEFT", cardX, -cardY)
                card:SetHeight(CARD_H)
                card:SetWidth(CARD_W)

                RA:_PopulateCard(card, p)
                card:Show()

                cardIndex = cardIndex + 1
                cardCol = cardCol + 1

                if cardCol >= cardCols then
                    cardCol = 0
                    cardRow = cardRow + 1
                end
            end

            -- Advance Y past this role's cards
            local rowsInGroup = math.ceil(#group / cardCols)
            curY = curY + (rowsInGroup * (CARD_H + CARD_GAP)) + CARD_GAP
        end
    end

    content:SetHeight(math.max(curY, RA._plScroll:GetHeight()))
end

-------------------------------------------------------------------------------
-- Card pool
-------------------------------------------------------------------------------

function RA:_GetCard(i)
    local card = RA._plCardPool[i]
    if not card then
        card = RA:_NewPlayerCard(RA._plContent)
        RA._plCardPool[i] = card
    end
    return card
end

function RA:_NewPlayerCard(parent)
    local card = CreateFrame("Button", nil, parent)

    -- ── Achievement background tint ───────────────────────────────────────────
    local achBg = card:CreateTexture(nil, "BACKGROUND")
    achBg:SetAllPoints()
    achBg:SetColorTexture(0, 0, 0, 0)
    card._achBg = achBg

    -- ── Card background and border ───────────────────────────────────────────
    T:AddBackground(card, T.COLOR.BG_ROW_ALT)

    -- Store border textures for hover color changes
    local borderLeft = card:CreateTexture(nil, "BORDER")
    borderLeft:SetColorTexture(T.COLOR.BORDER[1], T.COLOR.BORDER[2], T.COLOR.BORDER[3], 1)
    borderLeft:SetPoint("TOPLEFT", card, "TOPLEFT", 0, 0)
    borderLeft:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 0, 0)
    borderLeft:SetWidth(1)

    local borderTop = card:CreateTexture(nil, "BORDER")
    borderTop:SetColorTexture(T.COLOR.BORDER[1], T.COLOR.BORDER[2], T.COLOR.BORDER[3], 1)
    borderTop:SetPoint("TOPLEFT", card, "TOPLEFT", 0, 0)
    borderTop:SetPoint("TOPRIGHT", card, "TOPRIGHT", 0, 0)
    borderTop:SetHeight(1)

    local borderRight = card:CreateTexture(nil, "BORDER")
    borderRight:SetColorTexture(T.COLOR.BORDER[1], T.COLOR.BORDER[2], T.COLOR.BORDER[3], 1)
    borderRight:SetPoint("TOPRIGHT", card, "TOPRIGHT", 0, 0)
    borderRight:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", 0, 0)
    borderRight:SetWidth(1)

    local borderBottom = card:CreateTexture(nil, "BORDER")
    borderBottom:SetColorTexture(T.COLOR.BORDER[1], T.COLOR.BORDER[2], T.COLOR.BORDER[3], 1)
    borderBottom:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 0, 0)
    borderBottom:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", 0, 0)
    borderBottom:SetHeight(1)

    card._borders = { borderLeft, borderTop, borderRight, borderBottom }

    -- ── Class icon (36×36, top-left) ─────────────────────────────────────────
    local classIcon = card:CreateTexture(nil, "ARTWORK")
    classIcon:SetSize(CLASS_ICON_SZ, CLASS_ICON_SZ)
    classIcon:SetPoint("TOPLEFT", card, "TOPLEFT", CARD_PAD, -CARD_PAD)
    card._classIcon = classIcon

    -- ── Role icon (14×14, bottom-right of class icon) ──────────────────────
    local roleIcon = card:CreateTexture(nil, "OVERLAY")
    roleIcon:SetSize(ROLE_ICON_SZ, ROLE_ICON_SZ)
    roleIcon:SetPoint("BOTTOMRIGHT", classIcon, "BOTTOMRIGHT", 2, -2)
    card._roleIcon = roleIcon

    -- ── Name label (class-colored) ────────────────────────────────────────────
    local nameLabel = card:CreateFontString(nil, "OVERLAY")
    T:ApplyFont(nameLabel, T:GetFontSize())
    nameLabel:SetPoint("TOPLEFT", classIcon, "TOPRIGHT", ICON_GAP, 0)
    nameLabel:SetPoint("TOPRIGHT", card, "TOPRIGHT", -CARD_PAD, -CARD_PAD)
    nameLabel:SetJustifyH("LEFT")
    nameLabel:SetWordWrap(false)
    card._nameLabel = nameLabel

    -- ── Realm label (muted, smaller) ──────────────────────────────────────────
    local realmLabel = card:CreateFontString(nil, "OVERLAY")
    T:ApplyFont(realmLabel, T:GetFontSize() - 2)
    realmLabel:SetTextColor(T.COLOR.TEXT_MUTED[1], T.COLOR.TEXT_MUTED[2], T.COLOR.TEXT_MUTED[3])
    realmLabel:SetPoint("TOPLEFT", nameLabel, "BOTTOMLEFT", 0, -2)
    realmLabel:SetJustifyH("LEFT")
    realmLabel:SetWordWrap(false)
    card._realmLabel = realmLabel

    -- ── Guild label (green, if present) ───────────────────────────────────────
    local guildLabel = card:CreateFontString(nil, "OVERLAY")
    T:ApplyFont(guildLabel, T:GetFontSize() - 2)
    guildLabel:SetTextColor(T.COLOR.FULL_CLEAR_TEXT[1], T.COLOR.FULL_CLEAR_TEXT[2], T.COLOR.FULL_CLEAR_TEXT[3])
    guildLabel:SetPoint("TOPLEFT", realmLabel, "BOTTOMLEFT", 0, -2)
    guildLabel:SetJustifyH("LEFT")
    guildLabel:SetWordWrap(false)
    guildLabel:Hide()
    card._guildLabel = guildLabel

    -- ── Kill-count badge (bottom-right) ───────────────────────────────────────
    local killBadge = CreateFrame("Frame", nil, card)
    killBadge:SetSize(44, 18)
    killBadge:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -CARD_PAD, CARD_PAD)
    T:AddBackground(killBadge, T.COLOR.BADGE_BG)
    T:AddBorder(killBadge, T.COLOR.BADGE_BORDER)

    local killLbl = killBadge:CreateFontString(nil, "OVERLAY")
    T:ApplyFont(killLbl, T:GetFontSize() - 1)
    killLbl:SetTextColor(T.COLOR.TEXT_ACCENT[1], T.COLOR.TEXT_ACCENT[2], T.COLOR.TEXT_ACCENT[3])
    killLbl:SetAllPoints()
    killLbl:SetJustifyH("CENTER")
    card._killBadgeLbl = killLbl

    -- ── Achievement badge (AOTC/CE, bottom-right above kill badge) ──────────────
    local achBadge = CreateFrame("Frame", nil, card)
    achBadge:SetSize(44, 18)
    achBadge:SetPoint("BOTTOMRIGHT", killBadge, "TOPRIGHT", 0, 2)
    achBadge:Hide()
    T:AddBorder(achBadge, T.COLOR.BADGE_BORDER)

    local achLbl = achBadge:CreateFontString(nil, "OVERLAY")
    T:ApplyFont(achLbl, T:GetFontSize() - 2)
    achLbl:SetAllPoints()
    achLbl:SetJustifyH("CENTER")
    card._achBadge = achBadge
    card._achBadgeLbl = achLbl

    -- ── Hover & tooltip ──────────────────────────────────────────────────────
    card:SetScript("OnEnter", function(c)
        -- Highlight borders
        for _, border in ipairs(c._borders) do
            border:SetColorTexture(
                T.COLOR.BORDER_ACCENT[1], T.COLOR.BORDER_ACCENT[2],
                T.COLOR.BORDER_ACCENT[3], T.COLOR.BORDER_ACCENT[4] or 1.0
            )
        end

        local p = c._player
        if not p then return end

        GameTooltip:SetOwner(c, "ANCHOR_RIGHT")

        -- Try to use a live unit token if the player is currently in our group
        local unitToken = RA:FindUnitToken(p.name, p.realm)
        if unitToken then
            GameTooltip:SetUnit(unitToken)
        else
            -- Manual tooltip: coloured name line + class
            local cr, cg, cb = T:ClassColor(p.class)
            GameTooltip:AddLine(p.name .. "-" .. p.realm, cr, cg, cb)
            local classDisplay = p.class:sub(1, 1) .. p.class:sub(2):lower()
            GameTooltip:AddLine(classDisplay, 0.70, 0.70, 0.70)
            if p.guild then
                GameTooltip:AddLine("<" .. p.guild .. ">", 0.40, 0.80, 0.40)
            end
        end

        -- Always append time-since info
        if p.lastKill and p.lastKill > 0 then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Last kill together: " .. RA:TimeAgo(p.lastKill), 0.55, 0.55, 0.65)
        end

        GameTooltip:Show()
    end)

    card:SetScript("OnLeave", function(c)
        -- Restore normal borders
        for _, border in ipairs(c._borders) do
            border:SetColorTexture(
                T.COLOR.BORDER[1], T.COLOR.BORDER[2],
                T.COLOR.BORDER[3], T.COLOR.BORDER[4] or 1.0
            )
        end
        GameTooltip:Hide()
    end)

    -- ── Right-click context menu ──────────────────────────────────────────────
    card:SetScript("OnMouseUp", function(c, btn)
        if btn ~= "RightButton" then return end
        local p = c._player
        if not p then return end

        local name  = p.name
        local realm = p.realm
        local nameRealm = name .. "-" .. realm

        -- Modern API (Dragonflight / TWW / Midnight)
        if MenuUtil and MenuUtil.CreateContextMenu then
            MenuUtil.CreateContextMenu(c, function(_, rootDescription)
                rootDescription:CreateTitle(nameRealm)
                rootDescription:CreateButton("Invite to Group", function()
                    local unitToken = RA:FindUnitToken(name, realm)
                    if unitToken then
                        C_PartyInfo.InviteUnit(unitToken)
                    else
                        C_PartyInfo.InviteUnit(name .. "-" .. RA:SanitiseRealm(realm))
                    end
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
                  func = function()
                      local unitToken = RA:FindUnitToken(name, realm)
                      if unitToken then
                          C_PartyInfo.InviteUnit(unitToken)
                      else
                          C_PartyInfo.InviteUnit(name .. "-" .. RA:SanitiseRealm(realm))
                      end
                  end },
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

    return card
end

-------------------------------------------------------------------------------
-- Card population
-------------------------------------------------------------------------------

function RA:_PopulateCard(card, p)
    -- Achievement background tint
    if p.wasCE then
        local c = T.COLOR.CE_BG
        card._achBg:SetColorTexture(c[1], c[2], c[3], c[4] or 0.24)
    elseif p.wasAOTC then
        local c = T.COLOR.AOTC_BG
        card._achBg:SetColorTexture(c[1], c[2], c[3], c[4] or 0.20)
    else
        card._achBg:SetColorTexture(0, 0, 0, 0)
    end

    -- Icons
    T:SetRoleIcon(card._roleIcon, p.role)
    if p.spec then
        T:SetSpecIcon(card._classIcon, p.spec)
    else
        T:SetClassIcon(card._classIcon, p.class)
    end

    -- Name: class-coloured
    local cr, cg, cb = T:ClassColor(p.class)
    card._nameLabel:SetTextColor(cr, cg, cb)
    card._nameLabel:SetText(p.name)

    -- Realm
    card._realmLabel:SetText("-" .. p.realm)

    -- Guild (if present)
    if p.guild then
        card._guildLabel:SetText("<" .. p.guild .. ">")
        card._guildLabel:Show()
    else
        card._guildLabel:Hide()
    end

    -- Kill-count badge
    card._killBadgeLbl:SetText("\195\151" .. p.count)   -- UTF-8 × (U+00D7)

    -- Achievement badge (AOTC/CE)
    if p.wasCE then
        card._achBadgeLbl:SetTextColor(1.0, 0.2, 0.2)
        card._achBadgeLbl:SetText("CE")
        card._achBadge:Show()
    elseif p.wasAOTC then
        card._achBadgeLbl:SetTextColor(1.0, 0.8, 0.2)
        card._achBadgeLbl:SetText("AOTC")
        card._achBadge:Show()
    else
        card._achBadge:Hide()
    end

    -- Store reference for tooltip/menu handlers
    card._player = p
end

-------------------------------------------------------------------------------
-- Fast layout-only pass (called during live resize)
-------------------------------------------------------------------------------

--- Reposition existing cards without repopulating text/icons.
--- Called every frame during resize for smooth reflow without expense.
--- The full RefreshPlayerList will fire on debounce completion with full repopulation.
function RA:_LayoutPlayerCards()
    local content = RA._plContent
    if not content then return end

    content:SetWidth(math.max(1, RA._plScroll:GetWidth()))

    local players = (RA._currentSessionKey and RA._currentEncounterID)
        and RA:GetPlayersForSessionBoss(RA._currentSessionKey, RA._currentEncounterID)
        or {}
    if #players == 0 then return end

    -- Group players by role
    local roleGroups = {
        TANK    = {},
        HEALER  = {},
        DAMAGER = {},
    }
    for _, p in ipairs(players) do
        table.insert(roleGroups[p.role] or roleGroups.DAMAGER, p)
    end

    -- Compute grid columns and reposition all visible cards
    local cardCols  = math.max(1, math.floor((content:GetWidth() - CARD_GAP) / (CARD_W + CARD_GAP)))
    local cardIndex = 1
    local curY      = 0

    for _, role in ipairs(ROLE_ORDER) do
        local group = roleGroups[role]
        if #group > 0 then
            local sectionData = RA._plSectionHeaders[role]
            if sectionData.frame:IsShown() then
                sectionData.frame:ClearAllPoints()
                sectionData.frame:SetPoint("TOPLEFT",  content, "TOPLEFT",  0, -curY)
                sectionData.frame:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -curY)
            end
            curY = curY + SECTION_H + CARD_GAP

            local cardRow = 0
            local cardCol = 0
            for _ in ipairs(group) do
                local card = RA._plCardPool[cardIndex]
                if card and card:IsShown() then
                    local cardX = CARD_GAP + cardCol * (CARD_W + CARD_GAP)
                    local cardY = curY + cardRow * (CARD_H + CARD_GAP)
                    card:ClearAllPoints()
                    card:SetPoint("TOPLEFT", content, "TOPLEFT", cardX, -cardY)
                end
                cardIndex = cardIndex + 1
                cardCol = cardCol + 1
                if cardCol >= cardCols then
                    cardCol = 0
                    cardRow = cardRow + 1
                end
            end

            local rowsInGroup = math.ceil(#group / cardCols)
            curY = curY + (rowsInGroup * (CARD_H + CARD_GAP)) + CARD_GAP
        end
    end

    content:SetHeight(math.max(curY, RA._plScroll:GetHeight()))
end

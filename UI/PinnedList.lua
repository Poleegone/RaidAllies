-- RaidAllies: PinnedList panel
-- Shows a scrollable list of players the user has starred/pinned.
-- Displayed in the right-hand split when the "Allies" tab is active.

local _, RA = ...
local T = RA.Theme

-- Blizzard globals declared locally so static analysers don't warn.
local ChatFrame_OpenChat = ChatFrame_OpenChat ---@diagnostic disable-line: undefined-global
local AddIgnore         = AddIgnore          ---@diagnostic disable-line: undefined-global
local MenuUtil          = MenuUtil           ---@diagnostic disable-line: undefined-global
local EasyMenu          = EasyMenu           ---@diagnostic disable-line: undefined-global
local RaiderIO          = RaiderIO           ---@diagnostic disable-line: undefined-global

local ROW_H       = 62
local ROW_GAP     = 2
local ROW_PAD     = 6
local ICON_SZ     = 32
local HEADER_H    = 28

-------------------------------------------------------------------------------
-- Panel creation
-------------------------------------------------------------------------------

function RA:CreatePinnedListPanel(parent)
    -- ── Header ───────────────────────────────────────────────────────────────
    local hdr = CreateFrame("Frame", nil, parent)
    hdr:SetPoint("TOPLEFT",  parent, "TOPLEFT",  0, 0)
    hdr:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    hdr:SetHeight(HEADER_H)

    T:AddBackground(hdr, T.COLOR.BG_TITLE)

    -- Bottom separator
    local sep = hdr:CreateTexture(nil, "BORDER")
    sep:SetColorTexture(T.COLOR.BORDER[1], T.COLOR.BORDER[2], T.COLOR.BORDER[3], 1)
    sep:SetPoint("BOTTOMLEFT",  hdr, "BOTTOMLEFT")
    sep:SetPoint("BOTTOMRIGHT", hdr, "BOTTOMRIGHT")
    sep:SetHeight(1)

    -- Title
    local title = hdr:CreateFontString(nil, "OVERLAY")
    T:ApplyFont(title, 12)
    title:SetTextColor(T.COLOR.TEXT_PRIMARY[1], T.COLOR.TEXT_PRIMARY[2], T.COLOR.TEXT_PRIMARY[3])
    title:SetPoint("LEFT", hdr, "LEFT", 8, 0)
    title:SetText("Pinned Allies")

    -- Count badge
    local countBg = hdr:CreateTexture(nil, "ARTWORK")
    countBg:SetSize(22, 16)
    countBg:SetColorTexture(T.COLOR.BADGE_BG[1], T.COLOR.BADGE_BG[2], T.COLOR.BADGE_BG[3], T.COLOR.BADGE_BG[4])

    local countLbl = hdr:CreateFontString(nil, "OVERLAY")
    T:ApplyFont(countLbl, 10)
    countLbl:SetTextColor(T.COLOR.TEXT_SECONDARY[1], T.COLOR.TEXT_SECONDARY[2], T.COLOR.TEXT_SECONDARY[3])
    countLbl:SetText("0")
    countLbl:SetPoint("LEFT", title, "RIGHT", 6, 0)
    countBg:SetPoint("CENTER", countLbl, "CENTER", 0, 0)

    RA._pinnedHdr      = hdr
    RA._pinnedCountLbl = countLbl

    -- ── Scroll area ──────────────────────────────────────────────────────────
    local scrollParent = CreateFrame("Frame", nil, parent)
    scrollParent:SetPoint("TOPLEFT",     hdr,    "BOTTOMLEFT",  0, -2)
    scrollParent:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0,  0)

    local scroll, content = RA:CreateScrollArea(scrollParent, ROW_H)
    RA._pinnedScroll  = scroll
    RA._pinnedContent = content

    -- ── Empty state ──────────────────────────────────────────────────────────
    local empty = content:CreateFontString(nil, "OVERLAY")
    T:ApplyFont(empty, T:GetFontSize())
    empty:SetTextColor(T.COLOR.TEXT_MUTED[1], T.COLOR.TEXT_MUTED[2], T.COLOR.TEXT_MUTED[3])
    empty:SetText("No pinned allies.\nStar a player to pin them.")
    empty:SetJustifyH("CENTER")
    empty:SetPoint("TOP", content, "TOP", 0, -30)
    empty:Hide()
    RA._pinnedEmpty = empty

    -- Row pool
    RA._pinnedRowPool = {}

    -- Context menu frame (shared for all rows)
    if not RA._pinnedContextMenu then
        RA._pinnedContextMenu = CreateFrame("Frame", "RaidAlliesPinnedContextMenu", UIParent, "UIDropDownMenuTemplate")
    end
end

-------------------------------------------------------------------------------
-- Refresh
-------------------------------------------------------------------------------

function RA:RefreshPinnedList()
    if not RA._pinnedContent then return end

    -- Hide all pooled rows
    for _, row in ipairs(RA._pinnedRowPool) do row:Hide() end

    -- Collect pinned player data
    local rows = {}
    for key, _ in pairs(RA.db.pinnedPlayers) do
        local p = RA.db.players[key]
        if p then
            rows[#rows + 1] = p
        end
    end
    table.sort(rows, function(a, b) return a.name < b.name end)

    -- Empty state
    RA._pinnedEmpty:SetShown(#rows == 0)

    -- Populate rows
    local y = 0
    for i, p in ipairs(rows) do
        local row = RA._pinnedRowPool[i]
        if not row then
            row = RA:_NewPinnedRow(RA._pinnedContent)
            RA._pinnedRowPool[i] = row
        end
        RA:_PopulatePinnedRow(row, p)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT",  RA._pinnedContent, "TOPLEFT",  0, -y)
        row:SetPoint("TOPRIGHT", RA._pinnedContent, "TOPRIGHT", 0, -y)
        row:SetHeight(ROW_H)
        row:Show()
        y = y + ROW_H + ROW_GAP
    end

    RA._pinnedContent:SetHeight(math.max(y, RA._pinnedScroll:GetHeight()))
    RA._pinnedCountLbl:SetText(tostring(#rows))
end

-------------------------------------------------------------------------------
-- Row creation
-------------------------------------------------------------------------------

function RA:_NewPinnedRow(parent)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(ROW_H)

    -- Background gradient (same style as player cards)
    local bg = row:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    local top    = T.COLOR.CARD_BG_TOP
    local bottom = T.COLOR.CARD_BG_BOTTOM
    bg:SetGradient("VERTICAL",
        CreateColor(top[1],    top[2],    top[3],    top[4]),
        CreateColor(bottom[1], bottom[2], bottom[3], bottom[4]))
    row._bg = bg

    -- Left class-colour strip (3px)
    local strip = row:CreateTexture(nil, "ARTWORK")
    strip:SetWidth(3)
    strip:SetPoint("TOPLEFT",    row, "TOPLEFT")
    strip:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT")
    row._classStrip = strip

    -- 1px borders (all four sides)
    local borders = {}
    local bc = T.COLOR.BORDER
    local topBorder = row:CreateTexture(nil, "BORDER")
    topBorder:SetColorTexture(bc[1], bc[2], bc[3], bc[4] or 1)
    topBorder:SetPoint("TOPLEFT",  row, "TOPLEFT")
    topBorder:SetPoint("TOPRIGHT", row, "TOPRIGHT")
    topBorder:SetHeight(1)
    borders[#borders + 1] = topBorder

    local botBorder = row:CreateTexture(nil, "BORDER")
    botBorder:SetColorTexture(bc[1], bc[2], bc[3], bc[4] or 1)
    botBorder:SetPoint("BOTTOMLEFT",  row, "BOTTOMLEFT")
    botBorder:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT")
    botBorder:SetHeight(1)
    borders[#borders + 1] = botBorder

    local lftBorder = row:CreateTexture(nil, "BORDER")
    lftBorder:SetColorTexture(bc[1], bc[2], bc[3], bc[4] or 1)
    lftBorder:SetPoint("TOPLEFT",    row, "TOPLEFT")
    lftBorder:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT")
    lftBorder:SetWidth(1)
    borders[#borders + 1] = lftBorder

    local rgtBorder = row:CreateTexture(nil, "BORDER")
    rgtBorder:SetColorTexture(bc[1], bc[2], bc[3], bc[4] or 1)
    rgtBorder:SetPoint("TOPRIGHT",    row, "TOPRIGHT")
    rgtBorder:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT")
    rgtBorder:SetWidth(1)
    borders[#borders + 1] = rgtBorder
    row._borders = borders

    -- Class/spec icon
    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(ICON_SZ, ICON_SZ)
    icon:SetPoint("TOPLEFT", row, "TOPLEFT", ROW_PAD + 3, -ROW_PAD)
    row._classIcon = icon

    -- Name label (class-coloured)
    local name = row:CreateFontString(nil, "OVERLAY")
    T:ApplyFont(name, T:GetFontSize())
    name:SetPoint("TOPLEFT", icon, "TOPRIGHT", 4, 0)
    name:SetPoint("RIGHT", row, "RIGHT", -ROW_PAD, 0)
    name:SetJustifyH("LEFT")
    name:SetWordWrap(false)
    row._nameLabel = name

    -- Realm label
    local realm = row:CreateFontString(nil, "OVERLAY")
    T:ApplyFont(realm, T:GetFontSize() - 2)
    realm:SetTextColor(T.COLOR.TEXT_MUTED[1], T.COLOR.TEXT_MUTED[2], T.COLOR.TEXT_MUTED[3])
    realm:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -1)
    realm:SetPoint("RIGHT", row, "RIGHT", -ROW_PAD, 0)
    realm:SetJustifyH("LEFT")
    realm:SetWordWrap(false)
    row._realmLabel = realm

    -- Guild label
    local guild = row:CreateFontString(nil, "OVERLAY")
    T:ApplyFont(guild, T:GetFontSize() - 2)
    guild:SetTextColor(0.40, 0.80, 0.40)
    guild:SetPoint("TOPLEFT", realm, "BOTTOMLEFT", 0, -1)
    guild:SetPoint("RIGHT", row, "RIGHT", -ROW_PAD, 0)
    guild:SetJustifyH("LEFT")
    guild:SetWordWrap(false)
    guild:Hide()
    row._guildLabel = guild

    -- Kill-count badge (bottom-right)
    local killBadge = CreateFrame("Frame", nil, row)
    killBadge:SetSize(40, 16)
    killBadge:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -ROW_PAD, ROW_PAD)
    killBadge:SetFrameLevel(row:GetFrameLevel() - 1)
    local killBg = killBadge:CreateTexture(nil, "BACKGROUND")
    killBg:SetAllPoints()
    killBg:SetColorTexture(T.COLOR.BADGE_BG[1], T.COLOR.BADGE_BG[2], T.COLOR.BADGE_BG[3], T.COLOR.BADGE_BG[4])
    local killLbl = killBadge:CreateFontString(nil, "OVERLAY")
    T:ApplyFont(killLbl, T:GetFontSize() - 2)
    killLbl:SetAllPoints()
    killLbl:SetJustifyH("CENTER")
    killLbl:SetTextColor(T.COLOR.TEXT_PRIMARY[1], T.COLOR.TEXT_PRIMARY[2], T.COLOR.TEXT_PRIMARY[3])
    row._killBadge    = killBadge
    row._killBadgeLbl = killLbl

    -- Achievement badge (above kill badge)
    local achBadge = CreateFrame("Frame", nil, row)
    achBadge:SetSize(40, 16)
    achBadge:SetPoint("BOTTOM", killBadge, "TOP", 0, 2)
    local achBg = achBadge:CreateTexture(nil, "BACKGROUND")
    achBg:SetAllPoints()
    achBg:SetColorTexture(T.COLOR.BADGE_BG[1], T.COLOR.BADGE_BG[2], T.COLOR.BADGE_BG[3], T.COLOR.BADGE_BG[4])
    local achLbl = achBadge:CreateFontString(nil, "OVERLAY")
    T:ApplyFont(achLbl, T:GetFontSize() - 2)
    achLbl:SetAllPoints()
    achLbl:SetJustifyH("CENTER")
    achBadge:Hide()
    row._achBadge    = achBadge
    row._achBadgeLbl = achLbl

    -- Unpin button (topright)
    local pinBtn = CreateFrame("Button", nil, row)
    pinBtn:SetSize(14, 14)
    pinBtn:SetPoint("TOPRIGHT", row, "TOPRIGHT", - 4 - ROW_PAD, - 4 - ROW_PAD)
    pinBtn:SetFrameLevel(row:GetFrameLevel() + 3)
    pinBtn:SetPropagateMouseClicks(false)

    local pinTex = pinBtn:CreateTexture(nil, "OVERLAY")
    pinTex:SetScale(.5)
    pinTex:SetPoint("CENTER")
    pcall(function() pinTex:SetAtlas("runecarving-icon-reagent-empty-error", true) end)
    if not pinTex:GetAtlas() then
        pinTex:SetColorTexture(1, 0.82, 0, 0.3)
    end

    pinBtn:SetScript("OnClick", function()
        local p = row._player
        if not p then return end
        -- Unpin
        local key = RA:PlayerKey(p.name, p.realm)
        RA.db.pinnedPlayers[key] = nil
        RA:RefreshPinnedList()
        -- If PlayerList view is also showing, refresh its pin stars
        if RA.playerListView and RA.playerListView:IsShown() then
            RA:RefreshPlayerList()
        end
    end)
    row._pinBtn = pinBtn
    row._pinTex = pinTex

    -- ── Note icon (texture, top-right) ───────────────────────
    local noteIcon = row:CreateTexture(nil, "OVERLAY")
    noteIcon:SetSize(14, 14)
    noteIcon:SetPoint("TOPRIGHT", row, "TOPRIGHT", - ROW_PAD - 20, - ROW_PAD)
    noteIcon:SetAlpha(0.3)
    -- Try various note-like atlases; fall back to colored dot
    local atlasFound = false
    for _, atlas in ipairs({ "poi-workorders" }) do
        if pcall(function() noteIcon:SetAtlas(atlas, true) end) and noteIcon:GetAtlas() then
            atlasFound = true
            break
        end
    end
    if not atlasFound then
        noteIcon:SetColorTexture(1, 0.82, 0, 0.7)  -- fallback: soft gold dot
    end
    noteIcon:Hide()
    row._noteIcon = noteIcon

    -- ── Hover ────────────────────────────────────────────────────────────────
    row:SetScript("OnEnter", function(r)
        local ht = T.COLOR.CARD_HOVER_TOP
        local hb = T.COLOR.CARD_HOVER_BOTTOM
        r._bg:SetGradient("VERTICAL",
            CreateColor(ht[1], ht[2], ht[3], ht[4]),
            CreateColor(hb[1], hb[2], hb[3], hb[4]))
        for _, border in ipairs(r._borders) do
            border:SetColorTexture(
                T.COLOR.BORDER_ACCENT[1], T.COLOR.BORDER_ACCENT[2],
                T.COLOR.BORDER_ACCENT[3], T.COLOR.BORDER_ACCENT[4] or 1.0)
        end
        local p = r._player
        if p then
            r._classStrip:SetColorTexture(T:ClassColor(p.class))
        end

        -- Tooltip
        if p then
            GameTooltip:SetOwner(r, "ANCHOR_RIGHT")
            local unitToken = RA:FindUnitToken(p.name, p.realm)
            if unitToken then
                GameTooltip:SetUnit(unitToken)
            else
                local cr, cg, cb = T:ClassColor(p.class)
                GameTooltip:AddLine(p.name .. " " .. p.realm, cr, cg, cb)
                local classDisplay = p.class:sub(1, 1) .. p.class:sub(2):lower()
                GameTooltip:AddLine(classDisplay, 0.70, 0.70, 0.70)
                if p.guild then
                    GameTooltip:AddLine("<" .. p.guild .. ">", 0.40, 0.80, 0.40)
                end
            end
            if p.lastSeen and p.lastSeen > 0 then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("Last seen: " .. RA:TimeAgo(p.lastSeen), 0.55, 0.55, 0.65)
            end
            -- Show user note if it exists
            local rawP = RA.db.players[RA:PlayerKey(p.name, p.realm)]
            if rawP and rawP.note and rawP.note ~= "" then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("Note: " .. rawP.note, 1.0, 1.0, 0.55)
            end
            GameTooltip:Show()
        end
    end)

    row:SetScript("OnLeave", function(r)
        local top    = T.COLOR.CARD_BG_TOP
        local bottom = T.COLOR.CARD_BG_BOTTOM
        r._bg:SetGradient("VERTICAL",
            CreateColor(top[1],    top[2],    top[3],    top[4]),
            CreateColor(bottom[1], bottom[2], bottom[3], bottom[4]))
        for _, border in ipairs(r._borders) do
            border:SetColorTexture(
                T.COLOR.BORDER[1], T.COLOR.BORDER[2],
                T.COLOR.BORDER[3], T.COLOR.BORDER[4] or 1.0)
        end
        local p = r._player
        if p then
            local cr, cg, cb = T:ClassColor(p.class)
            r._classStrip:SetColorTexture(cr, cg, cb, 0.70)
        end
        GameTooltip:Hide()
    end)

    -- ── Right-click context menu ─────────────────────────────────────────────
    row:SetScript("OnMouseUp", function(r, btn)
        if btn ~= "RightButton" then return end
        local p = r._player
        if not p then return end

        local name  = p.name
        local realm = p.realm
        local nameRealm = name .. "-" .. realm
        local playerKey = RA:PlayerKey(name, realm)

        -- Determine note button label (context-sensitive)
        local rawRec = RA.db.players[playerKey]
        local noteLabel = (rawRec and rawRec.note and rawRec.note ~= "") and "Edit Note" or "Add Note"

        if MenuUtil and MenuUtil.CreateContextMenu then
            MenuUtil.CreateContextMenu(r, function(_, rootDescription)
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
                rootDescription:CreateButton("Unpin", function()
                    local key = RA:PlayerKey(name, realm)
                    RA.db.pinnedPlayers[key] = nil
                    RA:RefreshPinnedList()
                    if RA.playerListView and RA.playerListView:IsShown() then
                        RA:RefreshPlayerList()
                    end
                end)
                rootDescription:CreateButton(noteLabel, function()
                    RA:ShowNoteDialog(name, realm)
                end)
                rootDescription:CreateButton("Ignore", function()
                    AddIgnore(nameRealm)
                end)
            end)
        elseif EasyMenu then
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
                { text = "Unpin", notCheckable = true,
                  func = function()
                      local key = RA:PlayerKey(name, realm)
                      RA.db.pinnedPlayers[key] = nil
                      RA:RefreshPinnedList()
                      if RA.playerListView and RA.playerListView:IsShown() then
                          RA:RefreshPlayerList()
                      end
                  end },
                { text = noteLabel, notCheckable = true,
                  func = function() RA:ShowNoteDialog(name, realm) end },
                { text = "Ignore", notCheckable = true,
                  func = function() AddIgnore(nameRealm) end },
            }
            EasyMenu(menuList, RA._pinnedContextMenu, "cursor", 0, 0, "MENU")
        end
    end)

    return row
end

-------------------------------------------------------------------------------
-- Row population
-------------------------------------------------------------------------------

function RA:_PopulatePinnedRow(row, p)
    -- Class strip colour
    local cr, cg, cb = T:ClassColor(p.class)
    row._classStrip:SetColorTexture(cr, cg, cb, 0.70)

    -- Icon: prefer spec, fall back to class
    if p.spec then
        T:SetSpecIcon(row._classIcon, p.spec)
    else
        T:SetClassIcon(row._classIcon, p.class)
    end

    -- Name (class-coloured)
    row._nameLabel:SetTextColor(cr, cg, cb)
    row._nameLabel:SetText(p.name)

    -- Realm
    row._realmLabel:SetText(p.realm)

    -- Guild
    if p.guild then
        row._guildLabel:SetText("<" .. p.guild .. ">")
        row._guildLabel:Show()
    else
        row._guildLabel:Hide()
    end

    -- Kill-count badge (total kills across all encounters)
    row._killBadgeLbl:SetText("\195\151" .. (p.totalKills or 0))

    -- Achievement badge — check across all encounters for best achievement
    local hasCE, hasAOTC = false, false
    if p.encounters then
        for _, enc in pairs(p.encounters) do
            if enc.wasCE then hasCE = true end
            if enc.wasAOTC then hasAOTC = true end
        end
    end

    if hasCE then
        row._achBadgeLbl:SetTextColor(1.0, 0.2, 0.2)
        row._achBadgeLbl:SetText("CE")
        row._achBadge:Show()
    elseif hasAOTC then
        row._achBadgeLbl:SetTextColor(1.0, 0.8, 0.2)
        row._achBadgeLbl:SetText("AOTC")
        row._achBadge:Show()
    else
        row._achBadge:Hide()
    end

    -- Note icon
    local rawP = RA.db.players[RA:PlayerKey(p.name, p.realm)]
    row._noteIcon:SetShown(rawP and rawP.note and rawP.note ~= "" or false)

    -- Store reference for tooltip and context menu
    row._player = p
end

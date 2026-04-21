local addonName, RaidAllies = ...

local UI = {}
RaidAllies.UI_Summary = UI

local FRAME_WIDTH = 460
local FRAME_HEIGHT = 480
local ROW_HEIGHT = 22
local PAD = 12

local BTN_PIN_W = 44
local BTN_LIKE_W = 26
local BTN_AVOID_W = 26
local BTN_GAP = 4

local COL_AVOID_RIGHT = -4
local COL_LIKE_RIGHT = COL_AVOID_RIGHT - BTN_AVOID_W - BTN_GAP
local COL_PIN_RIGHT = COL_LIKE_RIGHT - BTN_LIKE_W - BTN_GAP
local COL_KILLS_WIDTH = 40
local COL_KILLS_RIGHT = COL_PIN_RIGHT - BTN_PIN_W - 8
local NAME_RIGHT_OFFSET = COL_KILLS_RIGHT - COL_KILLS_WIDTH - 8

local FOOTER_H = 40
local HEADER_H = 20
local COL_HEADER_H = 20

local function FormatDuration(seconds)
    seconds = seconds or 0
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local s = seconds % 60
    if h > 0 then
        return string.format("%dh %dm", h, m)
    end
    return string.format("%dm %ds", m, s)
end

local function CreateFrameOnce()
    if UI.frame then return UI.frame end

    local T = RaidAllies.Theme
    local FONT = RaidAllies:GetFont()

    local f = RaidAllies:MakeWindow("RaidAlliesSummaryFrame", "RaidAllies - Session Summary", FRAME_WIDTH, FRAME_HEIGHT)
    f:SetFrameStrata("DIALOG")
    f:SetFrameLevel(110)
    f.titleBar:SetFrameLevel(f:GetFrameLevel() + 2)
    f.body:SetFrameLevel(f:GetFrameLevel() + 1)

    -- Info header
    f.header = f.body:CreateFontString(nil, "OVERLAY")
    f.header:SetFont(FONT, 12, "")
    f.header:SetPoint("TOPLEFT", f.body, "TOPLEFT", PAD, -PAD)
    f.header:SetPoint("TOPRIGHT", f.body, "TOPRIGHT", -PAD, -PAD)
    f.header:SetJustifyH("LEFT")
    f.header:SetHeight(HEADER_H)
    f.header:SetTextColor(T.text[1], T.text[2], T.text[3])

    -- Column header strip
    f.colHeader = RaidAllies:MakePanel(f.body)
    f.colHeader:SetPoint("TOPLEFT", f.header, "BOTTOMLEFT", 0, -6)
    f.colHeader:SetPoint("TOPRIGHT", f.header, "BOTTOMRIGHT", 0, -6)
    f.colHeader:SetHeight(COL_HEADER_H)

    f.hName = f.colHeader:CreateFontString(nil, "OVERLAY")
    f.hName:SetFont(FONT, 11, "")
    f.hName:SetPoint("LEFT", f.colHeader, "LEFT", 8, 0)
    f.hName:SetTextColor(T.header[1], T.header[2], T.header[3])
    f.hName:SetText("Name")

    f.hKills = f.colHeader:CreateFontString(nil, "OVERLAY")
    f.hKills:SetFont(FONT, 11, "")
    f.hKills:SetPoint("RIGHT", f.colHeader, "RIGHT", COL_KILLS_RIGHT - 22, 0)
    f.hKills:SetWidth(COL_KILLS_WIDTH)
    f.hKills:SetJustifyH("RIGHT")
    f.hKills:SetTextColor(T.header[1], T.header[2], T.header[3])
    f.hKills:SetText("Kills")

    -- List panel
    f.listBg = RaidAllies:MakePanel(f.body)
    f.listBg:SetPoint("TOPLEFT", f.colHeader, "BOTTOMLEFT", 0, -4)
    f.listBg:SetPoint("BOTTOMRIGHT", f.body, "BOTTOMRIGHT", -PAD, PAD + FOOTER_H)

    f.scrollWrap, f.scroll, f.content = RaidAllies:MakeScroll(f.listBg)
    f.scrollWrap:SetPoint("TOPLEFT", f.listBg, "TOPLEFT", 4, -4)
    f.scrollWrap:SetPoint("BOTTOMRIGHT", f.listBg, "BOTTOMRIGHT", -4, 4)

    f.rows = {}

    -- Footer buttons
    f.snapshotBtn = RaidAllies:MakeButton(f.body, "Save Group Snapshot", 160, 22)
    f.snapshotBtn:SetPoint("BOTTOMLEFT", f.body, "BOTTOMLEFT", PAD, PAD)
    f.snapshotBtn:SetScript("OnClick", function()
        if not UI.current then return end
        local key = RaidAllies.Snapshots and RaidAllies.Snapshots:Capture(UI.current, {
            sessionId = "manual-" .. tostring(time()),
        })
        if key then
            f.snapshotStatus:SetText("|cff8ad18aSnapshot saved|r")
        else
            f.snapshotStatus:SetText("|cffaaaaaaAlready saved|r")
        end
    end)

    f.snapshotStatus = f.body:CreateFontString(nil, "OVERLAY")
    f.snapshotStatus:SetFont(FONT, 10, "")
    f.snapshotStatus:SetPoint("LEFT", f.snapshotBtn, "RIGHT", 8, 0)
    f.snapshotStatus:SetJustifyH("LEFT")
    f.snapshotStatus:SetWordWrap(false)
    f.snapshotStatus:SetTextColor(T.textDim[1], T.textDim[2], T.textDim[3])
    f.snapshotStatus:SetText("")

    f.pinBtn = RaidAllies:MakeButton(f.body, "Pin Top Players", 140, 22)
    f.pinBtn:SetPoint("BOTTOMRIGHT", f.body, "BOTTOMRIGHT", -PAD, PAD)
    f.pinBtn:SetScript("OnClick", function()
        if not UI.current or not UI.current.players then return end
        local count = 0
        for _, entry in ipairs(UI.current.players) do
            if count >= 5 then break end
            RaidAllies.Data:SetPinned(entry.name, true)
            count = count + 1
        end
        RaidAllies:Print("Pinned top " .. count .. " players.")
        UI:Refresh()
    end)

    UI.frame = f
    return f
end

local function GetRow(parent, index)
    local f = UI.frame
    local row = f.rows[index]
    if row then return row end

    local T = RaidAllies.Theme
    local FONT = RaidAllies:GetFont()

    row = CreateFrame("Button", nil, parent)
    row:SetHeight(ROW_HEIGHT)
    row:EnableMouse(true)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    row.hover = row:CreateTexture(nil, "BACKGROUND", nil, 0)
    row.hover:SetAllPoints(row)
    row.hover:SetColorTexture(T.hover[1], T.hover[2], T.hover[3], T.hover[4])
    row.hover:Hide()

    row.pinTint = row:CreateTexture(nil, "BACKGROUND", nil, 1)
    row.pinTint:SetAllPoints(row)
    row.pinTint:SetColorTexture(T.pinTint[1], T.pinTint[2], T.pinTint[3], T.pinTint[4])
    row.pinTint:Hide()

    row.name = row:CreateFontString(nil, "OVERLAY")
    row.name:SetFont(FONT, 12, "")
    row.name:SetPoint("LEFT", row, "LEFT", 8, 0)
    row.name:SetPoint("RIGHT", row, "RIGHT", NAME_RIGHT_OFFSET, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    row.name:SetTextColor(T.text[1], T.text[2], T.text[3])

    row.kills = row:CreateFontString(nil, "OVERLAY")
    row.kills:SetFont(FONT, 12, "")
    row.kills:SetPoint("RIGHT", row, "RIGHT", COL_KILLS_RIGHT, 0)
    row.kills:SetWidth(COL_KILLS_WIDTH)
    row.kills:SetJustifyH("RIGHT")
    row.kills:SetTextColor(T.text[1], T.text[2], T.text[3])

    row.pin = RaidAllies:MakeButton(row, "Pin", BTN_PIN_W, 18)
    row.pin:SetPoint("RIGHT", row, "RIGHT", COL_PIN_RIGHT, 0)
    row.pin:SetScript("OnClick", function(self)
        local n = self:GetParent().playerName
        if not n then return end
        local p = RaidAllies.Data:Get(n)
        local cur = p and p.flags and p.flags.p
        RaidAllies.Data:SetPinned(n, not cur)
        UI:Refresh()
    end)

    row.like = RaidAllies:MakeButton(row, "+", BTN_LIKE_W, 18)
    row.like:SetPoint("RIGHT", row, "RIGHT", COL_LIKE_RIGHT, 0)
    row.like:SetScript("OnClick", function(self)
        local n = self:GetParent().playerName
        if not n then return end
        local p = RaidAllies.Data:Get(n)
        local cur = p and p.flags and p.flags.like
        RaidAllies.Data:SetLike(n, not cur)
        UI:Refresh()
    end)

    row.avoid = RaidAllies:MakeButton(row, "-", BTN_AVOID_W, 18)
    row.avoid:SetPoint("RIGHT", row, "RIGHT", COL_AVOID_RIGHT, 0)
    row.avoid:SetScript("OnClick", function(self)
        local n = self:GetParent().playerName
        if not n then return end
        local p = RaidAllies.Data:Get(n)
        local cur = p and p.flags and p.flags.avoid
        RaidAllies.Data:SetAvoid(n, not cur)
        UI:Refresh()
    end)

    row:SetScript("OnEnter", function(self) self.hover:Show() end)
    row:SetScript("OnLeave", function(self) self.hover:Hide() end)
    row:SetScript("OnClick", function(self, button)
        if button == "RightButton" and self.playerName then
            RaidAllies:ShowPlayerContextMenu(self.playerName)
        end
    end)

    f.rows[index] = row
    return row
end

function UI:Refresh()
    local f = self.frame
    local snap = self.current
    if not f or not snap then return end

    local visible = {}
    for _, entry in ipairs(snap.players) do
        if not RaidAllies.Data:IsHidden(entry.name) then
            visible[#visible + 1] = entry
        end
    end

    f.header:SetText(string.format(
        "Bosses: |cffffffff%d|r    Duration: |cffffffff%s|r    Players: |cffffffff%d|r",
        snap.bosses or 0, FormatDuration(snap.duration), #visible
    ))

    local T = RaidAllies.Theme

    table.sort(visible, function(a, b)
        local ra = RaidAllies.Data:Get(a.name)
        local rb = RaidAllies.Data:Get(b.name)
        local sa = RaidAllies.Data:TrustScore(ra)
        local sb = RaidAllies.Data:TrustScore(rb)
        if sa == sb then return (a.kills or 0) > (b.kills or 0) end
        return sa > sb
    end)

    local contentW = f.scroll:GetWidth()
    if not contentW or contentW <= 0 then
        contentW = FRAME_WIDTH - (PAD * 2) - 18
    end
    f.content:SetWidth(contentW)

    local prev
    for i, entry in ipairs(visible) do
        local row = GetRow(f.content, i)
        row:ClearAllPoints()
        row:SetWidth(contentW)
        if prev then
            row:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, 0)
            row:SetPoint("TOPRIGHT", prev, "BOTTOMRIGHT", 0, 0)
        else
            row:SetPoint("TOPLEFT", f.content, "TOPLEFT", 0, 0)
            row:SetPoint("TOPRIGHT", f.content, "TOPRIGHT", 0, 0)
        end

        row.playerName = entry.name
        local rec = RaidAllies.Data:Get(entry.name)
        local pinned = rec and rec.flags and rec.flags.p
        local liked = rec and rec.flags and rec.flags.like
        local avoided = rec and rec.flags and rec.flags.avoid

        local level = RaidAllies.Data:TrustLevel(rec)
        local levelColor = "|cffaaaaaa"
        if level == "Trusted" then levelColor = "|cff00ff88"
        elseif level == "Neutral" then levelColor = "|cffe6c870"
        elseif level == "Avoid" then levelColor = "|cffff4040" end
        local suffix = "  " .. levelColor .. "(" .. level .. ")|r"

        if pinned then
            row.pinTint:Show()
            row.name:SetText(T.pinGold .. entry.name .. "|r" .. suffix)
        else
            row.pinTint:Hide()
            row.name:SetText(RaidAllies:ColorName(entry.name) .. suffix)
        end
        row.kills:SetText(tostring(entry.kills))

        row.pin:SetText(pinned and "Unpin" or "Pin")
        row.like.label:SetTextColor(
            liked and T.accentOk[1] or T.text[1],
            liked and T.accentOk[2] or T.text[2],
            liked and T.accentOk[3] or T.text[3]
        )
        row.avoid.label:SetTextColor(
            avoided and T.accentBad[1] or T.text[1],
            avoided and T.accentBad[2] or T.text[2],
            avoided and T.accentBad[3] or T.text[3]
        )

        row:Show()
        prev = row
    end

    for i = #visible + 1, #f.rows do
        f.rows[i]:Hide()
    end

    f.content:SetHeight(math.max(1, #visible * ROW_HEIGHT))
    RaidAllies:UpdateScroll(f.scrollWrap)
end

function UI:Show(snapshot)
    local f = CreateFrameOnce()
    self.current = snapshot
    if f.snapshotStatus then
        if RaidAllies.Snapshots and RaidAllies.Snapshots._lastCapturedKey
            and RaidAllies.lastSessionId
            and RaidAllies.Snapshots._lastSessionId == RaidAllies.lastSessionId then
            f.snapshotStatus:SetText("|cff8ad18aSnapshot saved|r")
        else
            f.snapshotStatus:SetText("")
        end
    end
    f:Show()
    self:Refresh()
end

function UI:Hide()
    if self.frame then self.frame:Hide() end
end

local addonName, RaidAllies = ...

local UI = {}
RaidAllies.UI_SessionPlayers = UI

local FRAME_WIDTH = 340
local FRAME_HEIGHT = 420
local ROW_HEIGHT = 20
local PAD = 12

local BTN_INVITE_W = 60
local COL_INVITE_RIGHT = -4
local COL_KILLS_WIDTH = 36
local COL_KILLS_RIGHT = COL_INVITE_RIGHT - BTN_INVITE_W - 8
local NAME_RIGHT_OFFSET = COL_KILLS_RIGHT - COL_KILLS_WIDTH - 8

local COL_HEADER_H = 20

local function CreateFrameOnce()
    if UI.frame then return UI.frame end

    local T = RaidAllies.Theme
    local FONT = RaidAllies:GetFont()

    local f = RaidAllies:MakeWindow("RaidAlliesSessionPlayersFrame", "RaidAllies - Session Players", FRAME_WIDTH, FRAME_HEIGHT)
    f:ClearAllPoints()
    f:SetPoint("CENTER", UIParent, "CENTER", 200, 0)
    f:SetFrameStrata("DIALOG")
    f:SetFrameLevel(110)
    f.titleBar:SetFrameLevel(f:GetFrameLevel() + 2)
    f.body:SetFrameLevel(f:GetFrameLevel() + 1)

    -- Column header
    f.colHeader = RaidAllies:MakePanel(f.body)
    f.colHeader:SetPoint("TOPLEFT", f.body, "TOPLEFT", PAD, -PAD)
    f.colHeader:SetPoint("TOPRIGHT", f.body, "TOPRIGHT", -PAD, -PAD)
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

    f.snapshotHint = f.body:CreateFontString(nil, "OVERLAY")
    f.snapshotHint:SetFont(FONT, 10, "")
    f.snapshotHint:SetPoint("BOTTOMLEFT", f.body, "BOTTOMLEFT", PAD, 4)
    f.snapshotHint:SetJustifyH("LEFT")
    f.snapshotHint:SetTextColor(T.textDim[1], T.textDim[2], T.textDim[3])
    f.snapshotHint:SetText("")

    -- List panel
    f.listBg = RaidAllies:MakePanel(f.body)
    f.listBg:SetPoint("TOPLEFT", f.colHeader, "BOTTOMLEFT", 0, -4)
    f.listBg:SetPoint("BOTTOMRIGHT", f.body, "BOTTOMRIGHT", -PAD, PAD + 14)

    f.scrollWrap, f.scroll, f.content = RaidAllies:MakeScroll(f.listBg)
    f.scrollWrap:SetPoint("TOPLEFT", f.listBg, "TOPLEFT", 4, -4)
    f.scrollWrap:SetPoint("BOTTOMRIGHT", f.listBg, "BOTTOMRIGHT", -4, 4)

    f.rows = {}

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

    row.invite = RaidAllies:MakeButton(row, "Invite", BTN_INVITE_W, 18)
    row.invite:SetPoint("RIGHT", row, "RIGHT", COL_INVITE_RIGHT, 0)
    row.invite:SetScript("OnClick", function(self)
        local n = self:GetParent().playerName
        if not n then return end
        if C_PartyInfo and C_PartyInfo.InviteUnit then
            C_PartyInfo.InviteUnit(n)
        else
            InviteUnit(n)
        end
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
    if not f then return end

    local snap = RaidAllies.lastSession
    local players = snap and snap.players or {}

    if f.snapshotHint then
        if RaidAllies.Session and RaidAllies.Session:IsActive() then
            f.snapshotHint:SetText("|cffaaaaaaSnapshot available at session end|r")
        elseif snap and RaidAllies.Snapshots and RaidAllies.Snapshots._lastCapturedKey then
            f.snapshotHint:SetText("|cff8ad18aSnapshot saved|r")
        else
            f.snapshotHint:SetText("")
        end
    end

    local prev
    for i, entry in ipairs(players) do
        local row = GetRow(f.content, i)
        row:ClearAllPoints()
        row:SetWidth(f.content:GetWidth())
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
        local level = RaidAllies.Data:TrustLevel(rec)
        local levelColor = "|cffaaaaaa"
        if level == "Trusted" then levelColor = "|cff00ff88"
        elseif level == "Neutral" then levelColor = "|cffe6c870"
        elseif level == "Avoid" then levelColor = "|cffff4040" end
        local suffix = "  " .. levelColor .. "(" .. level .. ")|r"

        if pinned then
            row.pinTint:Show()
            row.name:SetText(RaidAllies.Theme.pinGold .. entry.name .. "|r" .. suffix)
        else
            row.pinTint:Hide()
            row.name:SetText(RaidAllies:ColorName(entry.name) .. suffix)
        end
        row.kills:SetText(tostring(entry.kills))
        if level == "Trusted" then
            row.invite:SetText("* Invite")
        else
            row.invite:SetText("Invite")
        end
        row:Show()
        prev = row
    end

    for i = #players + 1, #f.rows do
        f.rows[i]:Hide()
    end

    f.content:SetHeight(math.max(1, #players * ROW_HEIGHT))
    f.content:SetWidth(f.scroll:GetWidth())
    RaidAllies:UpdateScroll(f.scrollWrap)
end

function UI:Show()
    local f = CreateFrameOnce()
    self:Refresh()
    f:Show()
end

function UI:Hide()
    if self.frame then self.frame:Hide() end
end

function UI:Toggle()
    local f = CreateFrameOnce()
    if f:IsShown() then
        f:Hide()
    else
        self:Show()
    end
end

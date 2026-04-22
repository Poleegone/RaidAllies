local addonName, RaidAllies = ...

local UI = {}
RaidAllies.UI_Main = UI

local FRAME_WIDTH = 550
local FRAME_HEIGHT = 500
local ROW_HEIGHT = 40
local ROW_GAP = 2
local ROLE_GROUP_GAP = 10
local PAD = 12

local BTN_INVITE_W = 64
local BTN_INVITE_H = 22
local COL_INVITE_RIGHT = -8
local TRUST_W = 64
local TRUST_GAP = 10
local DIFF_W = 28
local DIFF_GAP = 6
local ROLE_ICON_SIZE = 14
local ROLE_ICON_LEFT = 10
local NAME_LEFT = ROLE_ICON_LEFT + ROLE_ICON_SIZE + 8
local TRUST_RIGHT_OFFSET = COL_INVITE_RIGHT - BTN_INVITE_W - TRUST_GAP
local TRUST_LEFT_OFFSET = TRUST_RIGHT_OFFSET - TRUST_W
local DIFF_RIGHT_OFFSET = TRUST_LEFT_OFFSET - DIFF_GAP
local DIFF_LEFT_OFFSET = DIFF_RIGHT_OFFSET - DIFF_W
local NAME_RIGHT_OFFSET = DIFF_LEFT_OFFSET - 8

local TRUST_RANK = { Trusted = 1, Neutral = 2, Unknown = 3, Avoid = 4 }

local ROLE_ATLAS = {
    TANK    = "roleicon-tiny-tank",
    HEALER  = "roleicon-tiny-healer",
    DAMAGER = "roleicon-tiny-dps",
}

local TRUST_COLOR = {
    Trusted = "|cff00ff88",
    Neutral = "|cffe6c870",
    Unknown = "|cffaaaaaa",
    Avoid   = "|cffff4040",
}

local DIFF_COLOR = {
    Mythic = "|cffff6a3d",
    Heroic = "|cff8a5cff",
    Normal = "|cff88a8c8",
    LFR    = "|cff888888",
}

local function CreateFrameOnce()
    if UI.frame then return UI.frame end

    local T = RaidAllies.Theme
    local FONT = RaidAllies:GetFont()

    local f = RaidAllies:MakeWindow("RaidAlliesMainFrame", "RaidAllies", FRAME_WIDTH, FRAME_HEIGHT)

    f:SetFrameStrata("DIALOG")
    f:SetFrameLevel(100)
    if f.titleBar then f.titleBar:SetFrameLevel(f:GetFrameLevel() + 2) end
    if f.body then f.body:SetFrameLevel(f:GetFrameLevel() + 1) end

    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetClampedToScreen(true)
    f:ClearAllPoints()
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

    if f.titleBar then
        f.titleBar:EnableMouse(true)
        f.titleBar:RegisterForDrag("LeftButton")
        f.titleBar:SetScript("OnDragStart", function() f:StartMoving() end)
        f.titleBar:SetScript("OnDragStop", function() f:StopMovingOrSizing() end)
    end

    f.header = f.body:CreateFontString(nil, "OVERLAY")
    f.header:SetFont(FONT, 11, "")
    f.header:SetPoint("TOPLEFT", f.body, "TOPLEFT", PAD, -PAD)
    f.header:SetPoint("TOPRIGHT", f.body, "TOPRIGHT", -(PAD + 90), -PAD)
    f.header:SetJustifyH("LEFT")
    f.header:SetHeight(16)
    f.header:SetTextColor(T.header[1], T.header[2], T.header[3])
    f.header:SetText("Who to invite next")

    f.snapshotsBtn = RaidAllies:MakeButton(f.body, "Snapshots", 80, 18)
    f.snapshotsBtn:SetPoint("TOPRIGHT", f.body, "TOPRIGHT", -PAD, -PAD + 2)
    f.snapshotsBtn:SetScript("OnClick", function()
        if RaidAllies.UI_Snapshots then RaidAllies.UI_Snapshots:Toggle() end
    end)

    f.mplusToggleBtn = RaidAllies:MakeButton(f.body, "", 120, 18)
    f.mplusToggleBtn:SetPoint("RIGHT", f.snapshotsBtn, "LEFT", -6, 0)
    f.mplusToggleBtn:SetScript("OnClick", function()
        local current = RaidAlliesDB and RaidAlliesDB.enableMythicPlus
        RaidAllies:SetMythicPlusEnabled(not current)
    end)
    UI.mplusToggleBtn = f.mplusToggleBtn
    UI:RefreshMPlusToggle()

    f.listBg = RaidAllies:MakePanel(f.body)
    f.listBg:SetPoint("TOPLEFT", f.header, "BOTTOMLEFT", 0, -6)
    f.listBg:SetPoint("BOTTOMRIGHT", f.body, "BOTTOMRIGHT", -PAD, PAD)

    f.scrollWrap, f.scroll, f.content = RaidAllies:MakeScroll(f.listBg)
    f.scrollWrap:SetPoint("TOPLEFT", f.listBg, "TOPLEFT", 4, -4)
    f.scrollWrap:SetPoint("BOTTOMRIGHT", f.listBg, "BOTTOMRIGHT", -4, 4)

    f.rows = {}

    f:SetScript("OnShow", function() UI:Refresh() end)

    UI.frame = f
    return f
end

local function OnRowClick(self, button)
    local n = self.playerName
    if not n then return end
    if button == "RightButton" then
        RaidAllies:ShowPlayerContextMenu(n)
        return
    end
    if self.selectedTint then
        if UI._selectedRow and UI._selectedRow ~= self and UI._selectedRow.selectedTint then
            UI._selectedRow.selectedTint:Hide()
        end
        UI._selectedRow = self
        self.selectedTint:Show()
    end
end

local function OnRowEnter(self)
    self.hover:Show()
    local n = self.playerName
    if not n then return end
    local rec = RaidAllies.Data:Get(n)
    if not rec then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    local level = RaidAllies.Data:TrustLevel(rec)
    local trustColor = TRUST_COLOR[level] or "|cffffffff"
    GameTooltip:AddDoubleLine("|cff66ccffRaidAllies|r", trustColor .. level .. "|r")
    GameTooltip:AddDoubleLine("Total Kills", "|cffffffff" .. (rec.k or 0) .. "|r")
    GameTooltip:AddDoubleLine("Full Clears", "|cffffffff" .. (rec.fc or 0) .. "|r")
    GameTooltip:AddDoubleLine("Last seen", "|cffffffff" .. RaidAllies:FormatTimeAgo(rec.ls) .. "|r")
    if rec.bestDiff then
        GameTooltip:AddDoubleLine("Highest Difficulty", (DIFF_COLOR[rec.bestDiff] or "|cffffffff") .. rec.bestDiff .. "|r")
    end
    if rec.lastRaid and rec.lastRaid ~= "" then
        GameTooltip:AddDoubleLine("Last Raid", "|cffffffff" .. rec.lastRaid .. "|r")
    end
    if rec.flags and rec.flags.p then
        GameTooltip:AddLine("|cffe6c870Pinned|r")
    end
    if rec.note and rec.note ~= "" then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("|cffaaaaaaNote|r", 1, 1, 1)
        GameTooltip:AddLine("|cffddddcc" .. rec.note .. "|r", 1, 1, 1, true)
    end
    GameTooltip:Show()
end

local function OnRowLeave(self)
    self.hover:Hide()
    GameTooltip:Hide()
end

local function OnInviteClick(self)
    local n = self:GetParent().playerName
    if not n then return end
    if C_PartyInfo and C_PartyInfo.InviteUnit then
        C_PartyInfo.InviteUnit(n)
    else
        InviteUnit(n)
    end
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

    row.altBg = row:CreateTexture(nil, "BACKGROUND", nil, -1)
    row.altBg:SetAllPoints(row)
    row.altBg:SetColorTexture(0, 0, 0, 0.18)
    row.altBg:Hide()

    row.hover = row:CreateTexture(nil, "BACKGROUND", nil, 0)
    row.hover:SetAllPoints(row)
    row.hover:SetColorTexture(T.hover[1], T.hover[2], T.hover[3], T.hover[4])
    row.hover:Hide()

    row.divider = row:CreateTexture(nil, "OVERLAY", nil, 1)
    row.divider:SetColorTexture(1, 1, 1, 0.08)
    row.divider:SetHeight(1)
    row.divider:SetPoint("TOPLEFT", row, "TOPLEFT", 8, 2)
    row.divider:SetPoint("TOPRIGHT", row, "TOPRIGHT", -8, 2)
    row.divider:Hide()

    row.pinTint = row:CreateTexture(nil, "BACKGROUND", nil, 1)
    row.pinTint:SetAllPoints(row)
    row.pinTint:SetColorTexture(T.pinTint[1], T.pinTint[2], T.pinTint[3], T.pinTint[4])
    row.pinTint:Hide()

    row.selectedTint = row:CreateTexture(nil, "BACKGROUND", nil, 2)
    row.selectedTint:SetAllPoints(row)
    row.selectedTint:SetColorTexture(0.4, 0.6, 0.9, 0.10)
    row.selectedTint:Hide()

    row.roleIcon = row:CreateTexture(nil, "ARTWORK")
    row.roleIcon:SetSize(ROLE_ICON_SIZE, ROLE_ICON_SIZE)
    row.roleIcon:SetPoint("TOPLEFT", row, "TOPLEFT", ROLE_ICON_LEFT, -7)
    row.roleIcon:Hide()

    row.name = row:CreateFontString(nil, "OVERLAY")
    row.name:SetFont(FONT, 13, "")
    row.name:SetPoint("TOPLEFT", row, "TOPLEFT", NAME_LEFT, -5)
    row.name:SetPoint("TOPRIGHT", row, "TOPRIGHT", NAME_RIGHT_OFFSET, -5)
    row.name:SetHeight(16)
    row.name:SetJustifyH("LEFT")
    row.name:SetJustifyV("MIDDLE")
    row.name:SetWordWrap(false)
    row.name:SetTextColor(T.text[1], T.text[2], T.text[3])

    row.diff = row:CreateFontString(nil, "OVERLAY")
    row.diff:SetFont(FONT, 10, "")
    row.diff:SetPoint("TOPRIGHT", row, "TOPRIGHT", DIFF_RIGHT_OFFSET, -5)
    row.diff:SetWidth(DIFF_W)
    row.diff:SetHeight(16)
    row.diff:SetJustifyH("RIGHT")
    row.diff:SetJustifyV("MIDDLE")
    row.diff:SetWordWrap(false)

    row.trust = row:CreateFontString(nil, "OVERLAY")
    row.trust:SetFont(FONT, 11, "")
    row.trust:SetPoint("TOPRIGHT", row, "TOPRIGHT", TRUST_RIGHT_OFFSET, -5)
    row.trust:SetWidth(TRUST_W)
    row.trust:SetHeight(16)
    row.trust:SetJustifyH("RIGHT")
    row.trust:SetJustifyV("MIDDLE")
    row.trust:SetWordWrap(false)

    row.stats = row:CreateFontString(nil, "OVERLAY")
    row.stats:SetFont(FONT, 10, "")
    row.stats:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", NAME_LEFT, 6)
    row.stats:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", NAME_RIGHT_OFFSET, 6)
    row.stats:SetHeight(14)
    row.stats:SetJustifyH("LEFT")
    row.stats:SetJustifyV("MIDDLE")
    row.stats:SetWordWrap(false)
    row.stats:SetTextColor(T.textDim[1], T.textDim[2], T.textDim[3])

    row.invite = RaidAllies:MakeButton(row, "Invite", BTN_INVITE_W, BTN_INVITE_H)
    row.invite:SetPoint("RIGHT", row, "RIGHT", COL_INVITE_RIGHT, 0)
    row.invite:SetScript("OnClick", OnInviteClick)

    row:SetScript("OnEnter", OnRowEnter)
    row:SetScript("OnLeave", OnRowLeave)
    row:SetScript("OnClick", OnRowClick)

    f.rows[index] = row
    return row
end

local function BuildSortedList()
    local list = {}
    if not RaidAlliesDB or not RaidAlliesDB.players then return list end
    local selfName = RaidAllies:GetUnitFullName("player")
    for key, rec in pairs(RaidAlliesDB.players) do
        if (not selfName or key ~= selfName) and (not rec.isTest or rec.isTest) and not rec.hidden then
            local level = RaidAllies.Data:TrustLevel(rec)
            local score = RaidAllies.Data:TrustScore(rec)
            list[#list + 1] = {
                name = key,
                rec = rec,
                level = level,
                score = score,
            }
        end
    end
    local ROLE_RANK = { TANK = 1, HEALER = 2, DAMAGER = 3 }
    table.sort(list, function(a, b)
        local roleA = ROLE_RANK[a.rec.role] or 4
        local roleB = ROLE_RANK[b.rec.role] or 4
        if roleA ~= roleB then return roleA < roleB end
        local ra = TRUST_RANK[a.level] or 99
        local rb = TRUST_RANK[b.level] or 99
        if ra ~= rb then return ra < rb end
        if a.score ~= b.score then return a.score > b.score end
        return a.name < b.name
    end)
    return list
end

function UI:Refresh()
    local f = self.frame
    if not f or not f:IsShown() then return end

    local T = RaidAllies.Theme
    local list = BuildSortedList()
    local prev
    local prevRole
    local totalHeight = 0
    for i, entry in ipairs(list) do
        local row = GetRow(f.content, i)
        row:ClearAllPoints()
        row:SetWidth(f.content:GetWidth())
        local isGroupStart = (prevRole ~= nil and entry.rec.role ~= prevRole)
        local gap = ROW_GAP
        if isGroupStart then gap = ROLE_GROUP_GAP end
        if prev then
            row:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -gap)
            row:SetPoint("TOPRIGHT", prev, "BOTTOMRIGHT", 0, -gap)
            totalHeight = totalHeight + gap + ROW_HEIGHT
        else
            row:SetPoint("TOPLEFT", f.content, "TOPLEFT", 0, 0)
            row:SetPoint("TOPRIGHT", f.content, "TOPRIGHT", 0, 0)
            totalHeight = ROW_HEIGHT
        end
        if isGroupStart then row.divider:Show() else row.divider:Hide() end
        if (i % 2) == 0 then row.altBg:Show() else row.altBg:Hide() end
        prevRole = entry.rec.role

        row.playerName = entry.name
        local rec = entry.rec
        local pinned = rec.flags and rec.flags.p
        local dim = (entry.level == "Avoid")

        local colouredName
        if pinned then
            row.pinTint:Show()
            colouredName = T.pinGold .. entry.name .. "|r"
        else
            row.pinTint:Hide()
            colouredName = RaidAllies:ColorName(entry.name)
        end
        if dim then
            colouredName = "|cff777777" .. entry.name .. "|r"
        end

        local atlas = rec.role and ROLE_ATLAS[rec.role]
        if atlas then
            row.roleIcon:SetAtlas(atlas)
            row.roleIcon:Show()
        else
            row.roleIcon:Hide()
        end

        row.name:SetText(colouredName)
        row.trust:SetText((TRUST_COLOR[entry.level] or "|cffaaaaaa") .. entry.level .. "|r")

        local diffTag = RaidAllies.Data:DiffTag(rec.bestDiff)
        if diffTag then
            row.diff:SetText((DIFF_COLOR[rec.bestDiff] or "|cffaaaaaa") .. diffTag .. "|r")
        else
            row.diff:SetText("")
        end

        local lastSeen = RaidAllies:FormatTimeAgo(rec.ls)
        local statsText = string.format("%d Kills  \194\183  %d Full Clears  \194\183  %s",
            rec.k or 0, rec.fc or 0, lastSeen)
        if rec.lastRaid and rec.lastRaid ~= "" then
            statsText = statsText .. "  \194\183  " .. rec.lastRaid
        end
        local note = rec.note
        if note and note ~= "" then
            local preview = note:gsub("[\r\n]+", " ")
            if #preview > 40 then
                preview = preview:sub(1, 37) .. "..."
            end
            statsText = statsText .. "  \194\183  \"" .. preview .. "\""
        end
        row.stats:SetText(statsText)

        if dim then
            row.stats:SetTextColor(0.45, 0.45, 0.45)
        else
            row.stats:SetTextColor(T.textDim[1], T.textDim[2], T.textDim[3])
        end

        if entry.level == "Trusted" then
            row.invite:SetText("* Invite")
        else
            row.invite:SetText("Invite")
        end

        row:Show()
        prev = row
    end

    for i = #list + 1, #f.rows do
        f.rows[i]:Hide()
    end

    f.header:SetText(string.format("Who to invite next  |cff888888(%d known)|r", #list))
    f.content:SetHeight(math.max(1, totalHeight))
    f.content:SetWidth(f.scroll:GetWidth())
    RaidAllies:UpdateScroll(f.scrollWrap)
end

function UI:RefreshMPlusToggle()
    local btn = self.mplusToggleBtn
    if not btn then return end
    local enabled = RaidAlliesDB and RaidAlliesDB.enableMythicPlus
    btn:SetText(enabled and "M+ Tracking: ON" or "M+ Tracking: OFF")
end

function UI:Show()
    local f = CreateFrameOnce()
    f:Show()
    f:Raise()
end

function UI:Hide()
    if self.frame then self.frame:Hide() end
end

function UI:Toggle()
    local f = CreateFrameOnce()
    if f:IsShown() then f:Hide() else f:Show() end
end

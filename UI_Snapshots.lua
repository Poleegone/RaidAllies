local addonName, RaidAllies = ...

local UI = {}
RaidAllies.UI_Snapshots = UI

local FRAME_WIDTH = 460
local FRAME_HEIGHT = 460
local ROW_HEIGHT = 34
local ROW_GAP = 2
local PAD = 12

local DETAIL_WIDTH = 400
local DETAIL_HEIGHT = 440
local DETAIL_ROW_H = 22
local ROLE_ICON_SIZE = 12

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

local function FormatDate(ts)
    if not ts or ts == 0 then return "?" end
    return date("%Y-%m-%d %H:%M", ts)
end

-- ===== Detail window =====

local function CreateDetailOnce()
    if UI.detail then return UI.detail end
    local T = RaidAllies.Theme
    local FONT = RaidAllies:GetFont()

    local f = RaidAllies:MakeWindow("RaidAlliesSnapshotDetail", "Snapshot Details", DETAIL_WIDTH, DETAIL_HEIGHT)
    f:SetFrameStrata("DIALOG")
    f:SetFrameLevel(120)
    f.titleBar:SetFrameLevel(f:GetFrameLevel() + 2)
    f.body:SetFrameLevel(f:GetFrameLevel() + 1)

    f.header = f.body:CreateFontString(nil, "OVERLAY")
    f.header:SetFont(FONT, 12, "")
    f.header:SetPoint("TOPLEFT", f.body, "TOPLEFT", PAD, -PAD)
    f.header:SetPoint("TOPRIGHT", f.body, "TOPRIGHT", -PAD, -PAD)
    f.header:SetJustifyH("LEFT")
    f.header:SetHeight(16)
    f.header:SetTextColor(T.text[1], T.text[2], T.text[3])

    f.sub = f.body:CreateFontString(nil, "OVERLAY")
    f.sub:SetFont(FONT, 10, "")
    f.sub:SetPoint("TOPLEFT", f.header, "BOTTOMLEFT", 0, -4)
    f.sub:SetPoint("TOPRIGHT", f.header, "BOTTOMRIGHT", 0, -4)
    f.sub:SetJustifyH("LEFT")
    f.sub:SetTextColor(T.textDim[1], T.textDim[2], T.textDim[3])

    f.listBg = RaidAllies:MakePanel(f.body)
    f.listBg:SetPoint("TOPLEFT", f.sub, "BOTTOMLEFT", 0, -8)
    f.listBg:SetPoint("BOTTOMRIGHT", f.body, "BOTTOMRIGHT", -PAD, PAD)

    f.scrollWrap, f.scroll, f.content = RaidAllies:MakeScroll(f.listBg)
    f.scrollWrap:SetPoint("TOPLEFT", f.listBg, "TOPLEFT", 4, -4)
    f.scrollWrap:SetPoint("BOTTOMRIGHT", f.listBg, "BOTTOMRIGHT", -4, 4)

    f.rows = {}

    UI.detail = f
    return f
end

local function GetDetailRow(parent, index)
    local f = UI.detail
    local row = f.rows[index]
    if row then return row end

    local T = RaidAllies.Theme
    local FONT = RaidAllies:GetFont()

    row = CreateFrame("Frame", nil, parent)
    row:SetHeight(DETAIL_ROW_H)
    row:EnableMouse(true)

    row.hover = row:CreateTexture(nil, "BACKGROUND", nil, 0)
    row.hover:SetAllPoints(row)
    row.hover:SetColorTexture(T.hover[1], T.hover[2], T.hover[3], T.hover[4])
    row.hover:Hide()

    row.roleIcon = row:CreateTexture(nil, "ARTWORK")
    row.roleIcon:SetSize(ROLE_ICON_SIZE, ROLE_ICON_SIZE)
    row.roleIcon:SetPoint("LEFT", row, "LEFT", 8, 0)
    row.roleIcon:Hide()

    row.name = row:CreateFontString(nil, "OVERLAY")
    row.name:SetFont(FONT, 12, "")
    row.name:SetPoint("LEFT", row, "LEFT", 8 + ROLE_ICON_SIZE + 6, 0)
    row.name:SetPoint("RIGHT", row, "RIGHT", -150, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    row.name:SetTextColor(T.text[1], T.text[2], T.text[3])

    row.trust = row:CreateFontString(nil, "OVERLAY")
    row.trust:SetFont(FONT, 11, "")
    row.trust:SetPoint("RIGHT", row, "RIGHT", -8, 0)
    row.trust:SetWidth(140)
    row.trust:SetJustifyH("RIGHT")
    row.trust:SetWordWrap(false)

    row:SetScript("OnEnter", function(self)
        self.hover:Show()
        if self.tooltipNote and self.tooltipNote ~= "" then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine("|cffaaaaaaNote|r")
            GameTooltip:AddLine("|cffddddcc" .. self.tooltipNote .. "|r", 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    row:SetScript("OnLeave", function(self)
        self.hover:Hide()
        GameTooltip:Hide()
    end)

    f.rows[index] = row
    return row
end

function UI:ShowDetail(key)
    local snap = RaidAllies.Snapshots:Get(key)
    if not snap then return end
    local f = CreateDetailOnce()

    f.titleText:SetText("Snapshot - " .. (snap.raidName or "Unknown"))

    local count = 0
    for _ in pairs(snap.players) do count = count + 1 end

    f.header:SetText(string.format("%s  |cff888888(%s)|r", snap.raidName or "Unknown", snap.difficulty or ""))
    f.sub:SetText(string.format("%s   Outcome: |cffffffff%s|r   Players: |cffffffff%d|r",
        FormatDate(snap.date), snap.outcome or "-", count))

    local list = {}
    for name, p in pairs(snap.players) do
        list[#list + 1] = { name = name, p = p }
    end
    local ROLE_RANK = { TANK = 1, HEALER = 2, DAMAGER = 3 }
    local TRUST_RANK = { Trusted = 1, Neutral = 2, Unknown = 3, Avoid = 4 }
    table.sort(list, function(a, b)
        local rA = ROLE_RANK[a.p.role] or 4
        local rB = ROLE_RANK[b.p.role] or 4
        if rA ~= rB then return rA < rB end
        local tA = TRUST_RANK[a.p.trust] or 99
        local tB = TRUST_RANK[b.p.trust] or 99
        if tA ~= tB then return tA < tB end
        return a.name < b.name
    end)

    local prev
    for i, entry in ipairs(list) do
        local row = GetDetailRow(f.content, i)
        row:ClearAllPoints()
        row:SetWidth(f.content:GetWidth())
        if prev then
            row:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, 0)
            row:SetPoint("TOPRIGHT", prev, "BOTTOMRIGHT", 0, 0)
        else
            row:SetPoint("TOPLEFT", f.content, "TOPLEFT", 0, 0)
            row:SetPoint("TOPRIGHT", f.content, "TOPRIGHT", 0, 0)
        end

        local atlas = entry.p.role and ROLE_ATLAS[entry.p.role]
        if atlas then
            row.roleIcon:SetAtlas(atlas)
            row.roleIcon:Show()
        else
            row.roleIcon:Hide()
        end

        local classCode
        if entry.p.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[entry.p.class] then
            local c = RAID_CLASS_COLORS[entry.p.class]
            classCode = c.colorStr and ("|c" .. c.colorStr) or nil
        end
        local nameText = classCode and (classCode .. entry.name .. "|r") or entry.name

        local note = entry.p.note
        if note and note ~= "" then
            local preview = note:gsub("[\r\n]+", " ")
            if #preview > 30 then preview = preview:sub(1, 27) .. "..." end
            nameText = nameText .. " |cff777777\"" .. preview .. "\"|r"
        end
        row.name:SetText(nameText)
        row.tooltipNote = note

        local tc = TRUST_COLOR[entry.p.trust] or "|cffaaaaaa"
        row.trust:SetText(tc .. (entry.p.trust or "Unknown") .. "|r")

        row:Show()
        prev = row
    end

    for i = #list + 1, #f.rows do
        f.rows[i]:Hide()
    end

    f.content:SetHeight(math.max(1, #list * DETAIL_ROW_H))
    f.content:SetWidth(f.scroll:GetWidth())
    RaidAllies:UpdateScroll(f.scrollWrap)

    f:Show()
end

-- ===== List window =====

local function CreateListOnce()
    if UI.frame then return UI.frame end
    local T = RaidAllies.Theme
    local FONT = RaidAllies:GetFont()

    local f = RaidAllies:MakeWindow("RaidAlliesSnapshotsFrame", "RaidAllies - Snapshots", FRAME_WIDTH, FRAME_HEIGHT)
    f:SetFrameStrata("DIALOG")
    f:SetFrameLevel(110)
    f.titleBar:SetFrameLevel(f:GetFrameLevel() + 2)
    f.body:SetFrameLevel(f:GetFrameLevel() + 1)

    f.header = f.body:CreateFontString(nil, "OVERLAY")
    f.header:SetFont(FONT, 11, "")
    f.header:SetPoint("TOPLEFT", f.body, "TOPLEFT", PAD, -PAD)
    f.header:SetPoint("TOPRIGHT", f.body, "TOPRIGHT", -PAD, -PAD)
    f.header:SetJustifyH("LEFT")
    f.header:SetHeight(16)
    f.header:SetTextColor(T.header[1], T.header[2], T.header[3])
    f.header:SetText("Saved group snapshots")

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

local function GetListRow(parent, index)
    local f = UI.frame
    local row = f.rows[index]
    if row then return row end

    local T = RaidAllies.Theme
    local FONT = RaidAllies:GetFont()

    row = CreateFrame("Button", nil, parent)
    row:SetHeight(ROW_HEIGHT)
    row:EnableMouse(true)
    row:RegisterForClicks("LeftButtonUp")

    row.hover = row:CreateTexture(nil, "BACKGROUND", nil, 0)
    row.hover:SetAllPoints(row)
    row.hover:SetColorTexture(T.hover[1], T.hover[2], T.hover[3], T.hover[4])
    row.hover:Hide()

    row.title = row:CreateFontString(nil, "OVERLAY")
    row.title:SetFont(FONT, 12, "")
    row.title:SetPoint("TOPLEFT", row, "TOPLEFT", 8, -4)
    row.title:SetPoint("TOPRIGHT", row, "TOPRIGHT", -8, -4)
    row.title:SetHeight(14)
    row.title:SetJustifyH("LEFT")
    row.title:SetWordWrap(false)
    row.title:SetTextColor(T.text[1], T.text[2], T.text[3])

    row.sub = row:CreateFontString(nil, "OVERLAY")
    row.sub:SetFont(FONT, 10, "")
    row.sub:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 8, 4)
    row.sub:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -8, 4)
    row.sub:SetHeight(12)
    row.sub:SetJustifyH("LEFT")
    row.sub:SetWordWrap(false)
    row.sub:SetTextColor(T.textDim[1], T.textDim[2], T.textDim[3])

    row:SetScript("OnEnter", function(self) self.hover:Show() end)
    row:SetScript("OnLeave", function(self) self.hover:Hide() end)
    row:SetScript("OnClick", function(self)
        if self.snapKey then UI:ShowDetail(self.snapKey) end
    end)

    f.rows[index] = row
    return row
end

function UI:Refresh()
    local f = self.frame
    if not f or not f:IsShown() then return end

    local list = RaidAllies.Snapshots and RaidAllies.Snapshots:GetAll() or {}

    f.header:SetText(string.format("Saved group snapshots  |cff888888(%d)|r", #list))

    local prev
    for i, item in ipairs(list) do
        local row = GetListRow(f.content, i)
        row:ClearAllPoints()
        row:SetWidth(f.content:GetWidth())
        if prev then
            row:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -ROW_GAP)
            row:SetPoint("TOPRIGHT", prev, "BOTTOMRIGHT", 0, -ROW_GAP)
        else
            row:SetPoint("TOPLEFT", f.content, "TOPLEFT", 0, 0)
            row:SetPoint("TOPRIGHT", f.content, "TOPRIGHT", 0, 0)
        end
        row.snapKey = item.key
        local snap = item.snap
        local playerCount = 0
        for _ in pairs(snap.players) do playerCount = playerCount + 1 end

        row.title:SetText(string.format("%s  |cff888888%s|r",
            snap.raidName or "Unknown",
            snap.difficulty and snap.difficulty ~= "" and ("(" .. snap.difficulty .. ")") or ""))
        row.sub:SetText(string.format("%s   %s   |cffaaaaaa%d players|r",
            FormatDate(snap.date), snap.outcome or "-", playerCount))

        row:Show()
        prev = row
    end

    for i = #list + 1, #f.rows do
        f.rows[i]:Hide()
    end

    f.content:SetHeight(math.max(1, #list * (ROW_HEIGHT + ROW_GAP)))
    f.content:SetWidth(f.scroll:GetWidth())
    RaidAllies:UpdateScroll(f.scrollWrap)
end

function UI:Show()
    local f = CreateListOnce()
    f:Show()
end

function UI:Hide()
    if self.frame then self.frame:Hide() end
end

function UI:Toggle()
    local f = CreateListOnce()
    if f:IsShown() then f:Hide() else f:Show() end
end

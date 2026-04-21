local addonName, RaidAllies = ...

RaidAllies.name = addonName
RaidAllies.MAX_PLAYERS = 300
RaidAllies.MAX_AGE = 60 * 24 * 60 * 60 -- 60 days in seconds

function RaidAllies:NormalizeName(name, realm)
    if not name or name == "" then return nil end
    if name:find("-") then
        return name
    end
    if not realm or realm == "" then
        realm = GetNormalizedRealmName() or GetRealmName()
        if realm then realm = realm:gsub("%s+", "") end
    else
        realm = realm:gsub("%s+", "")
    end
    if not realm or realm == "" then return nil end
    return name .. "-" .. realm
end

function RaidAllies:GetUnitFullName(unit)
    if not UnitExists(unit) then return nil end
    local name, realm = UnitNameUnmodified(unit)
    if not name or name == "" or name == UNKNOWN then return nil end
    return self:NormalizeName(name, realm)
end

function RaidAllies:FormatTimeAgo(ts)
    if not ts or ts == 0 then return "never" end
    local diff = time() - ts
    if diff < 60 then return diff .. "s ago" end
    if diff < 3600 then return math.floor(diff / 60) .. "m ago" end
    if diff < 86400 then return math.floor(diff / 3600) .. "h ago" end
    return math.floor(diff / 86400) .. "d ago"
end

function RaidAllies:Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffRaidAllies|r: " .. tostring(msg))
end

-- Dark slate theme
RaidAllies.Theme = {
    bg        = { 0.08, 0.09, 0.11, 0.90 },
    bg2       = { 0.12, 0.13, 0.16, 1.00 },
    border    = { 0.25, 0.27, 0.32, 1.00 },
    text      = { 0.90, 0.90, 0.90 },
    textDim   = { 0.60, 0.65, 0.70 },
    hover     = { 1.00, 1.00, 1.00, 0.05 },
    btnBg     = { 0.18, 0.19, 0.22, 1.00 },
    btnBgHov  = { 0.24, 0.26, 0.30, 1.00 },
    btnBgDown = { 0.14, 0.15, 0.18, 1.00 },
    pinTint   = { 1.00, 0.82, 0.00, 0.06 },
    pinGold   = "|cffe6c870",
    header    = { 0.85, 0.80, 0.55 },
    accentOk  = { 0.45, 0.85, 0.45 },
    accentBad = { 0.90, 0.35, 0.35 },
    PAD       = 12,
}

local FONT_PATH = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"

function RaidAllies:GetFont()
    return FONT_PATH
end

-- Paint a flat rect: bg texture + 4 thin border textures on top.
local function PaintRect(frame, bg, border)
    if not frame._bgTex then
        frame._bgTex = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
        frame._bgTex:SetAllPoints(frame)
    end
    frame._bgTex:SetColorTexture(bg[1], bg[2], bg[3], bg[4] or 1)

    if not frame._borderT then
        frame._borderT = frame:CreateTexture(nil, "BORDER")
        frame._borderB = frame:CreateTexture(nil, "BORDER")
        frame._borderL = frame:CreateTexture(nil, "BORDER")
        frame._borderR = frame:CreateTexture(nil, "BORDER")
        frame._borderT:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
        frame._borderT:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
        frame._borderT:SetHeight(1)
        frame._borderB:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
        frame._borderB:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
        frame._borderB:SetHeight(1)
        frame._borderL:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
        frame._borderL:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
        frame._borderL:SetWidth(1)
        frame._borderR:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
        frame._borderR:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
        frame._borderR:SetWidth(1)
    end
    for _, t in ipairs({ frame._borderT, frame._borderB, frame._borderL, frame._borderR }) do
        t:SetColorTexture(border[1], border[2], border[3], border[4] or 1)
    end
end

RaidAllies._PaintRect = PaintRect

function RaidAllies:MakePanel(parent)
    local T = self.Theme
    local p = CreateFrame("Frame", nil, parent)
    PaintRect(p, T.bg2, T.border)
    return p
end

-- Create a fully custom window: dark slate bg, thin border, draggable title bar, close button.
-- Registers in UISpecialFrames (escape closes). Returns the outer frame; content goes inside `frame.body`.
function RaidAllies:MakeWindow(globalName, title, width, height)
    local T = self.Theme
    local f = CreateFrame("Frame", globalName, UIParent)
    f:SetSize(width, height)
    f:SetPoint("CENTER")
    f:SetFrameStrata("MEDIUM")
    f:SetFrameLevel(10)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:Hide()

    PaintRect(f, T.bg, T.border)

    -- Title bar
    local TITLE_H = 24
    f.titleBar = CreateFrame("Frame", nil, f)
    f.titleBar:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    f.titleBar:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
    f.titleBar:SetHeight(TITLE_H)
    f.titleBar:SetFrameLevel(f:GetFrameLevel() + 2)
    f.titleBar:EnableMouse(true)
    f.titleBar:RegisterForDrag("LeftButton")
    f.titleBar:SetScript("OnDragStart", function() f:StartMoving() end)
    f.titleBar:SetScript("OnDragStop", function() f:StopMovingOrSizing() end)

    local titleBg = f.titleBar:CreateTexture(nil, "BACKGROUND", nil, -6)
    titleBg:SetAllPoints(f.titleBar)
    titleBg:SetColorTexture(T.bg2[1], T.bg2[2], T.bg2[3], 1)

    local sep = f.titleBar:CreateTexture(nil, "BORDER")
    sep:SetPoint("BOTTOMLEFT", f.titleBar, "BOTTOMLEFT", 0, 0)
    sep:SetPoint("BOTTOMRIGHT", f.titleBar, "BOTTOMRIGHT", 0, 0)
    sep:SetHeight(1)
    sep:SetColorTexture(T.border[1], T.border[2], T.border[3], 1)

    f.titleText = f.titleBar:CreateFontString(nil, "OVERLAY")
    f.titleText:SetFont(FONT_PATH, 12, "")
    f.titleText:SetPoint("LEFT", f.titleBar, "LEFT", 10, 0)
    f.titleText:SetTextColor(T.text[1], T.text[2], T.text[3])
    f.titleText:SetText(title or "")

    -- Close button (custom)
    f.closeX = self:MakeButton(f.titleBar, "X", 20, 18)
    f.closeX:ClearAllPoints()
    f.closeX:SetPoint("RIGHT", f.titleBar, "RIGHT", -4, 0)
    f.closeX:SetScript("OnClick", function() f:Hide() end)

    -- Body container (everything below title bar)
    f.body = CreateFrame("Frame", nil, f)
    f.body:SetPoint("TOPLEFT", f.titleBar, "BOTTOMLEFT", 0, 0)
    f.body:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
    f.body:SetFrameLevel(f:GetFrameLevel() + 1)

    if globalName then
        tinsert(UISpecialFrames, globalName)
    end

    return f
end

-- Custom button: flat rect, thin border, hover/down tints, centered label.
function RaidAllies:MakeButton(parent, label, w, h)
    local T = self.Theme
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(w or 60, h or 18)
    b:EnableMouse(true)

    PaintRect(b, T.btnBg, T.border)

    b.label = b:CreateFontString(nil, "OVERLAY")
    b.label:SetFont(FONT_PATH, 11, "")
    b.label:SetPoint("CENTER", b, "CENTER", 0, 0)
    b.label:SetTextColor(T.text[1], T.text[2], T.text[3])
    b.label:SetText(label or "")

    b.SetText = function(self, txt) self.label:SetText(txt or "") end
    b.GetText = function(self) return self.label:GetText() end

    b:SetScript("OnEnter", function(self)
        self._bgTex:SetColorTexture(T.btnBgHov[1], T.btnBgHov[2], T.btnBgHov[3], T.btnBgHov[4])
    end)
    b:SetScript("OnLeave", function(self)
        self._bgTex:SetColorTexture(T.btnBg[1], T.btnBg[2], T.btnBg[3], T.btnBg[4])
    end)
    b:SetScript("OnMouseDown", function(self)
        self._bgTex:SetColorTexture(T.btnBgDown[1], T.btnBgDown[2], T.btnBgDown[3], T.btnBgDown[4])
        self.label:SetPoint("CENTER", self, "CENTER", 0, -1)
    end)
    b:SetScript("OnMouseUp", function(self)
        self._bgTex:SetColorTexture(T.btnBg[1], T.btnBg[2], T.btnBg[3], T.btnBg[4])
        self.label:SetPoint("CENTER", self, "CENTER", 0, 0)
    end)

    return b
end

-- Custom scroll frame: pure CreateFrame("ScrollFrame") with a tiny vertical scrollbar we draw ourselves.
-- Returns scroll, content. Attach rows to `content`; call RaidAllies:UpdateScrollRange(scroll) after sizing content.
function RaidAllies:MakeScroll(parent)
    local T = self.Theme

    local wrapper = CreateFrame("Frame", nil, parent)

    local scroll = CreateFrame("ScrollFrame", nil, wrapper)
    scroll:SetPoint("TOPLEFT", wrapper, "TOPLEFT", 0, 0)
    scroll:SetPoint("BOTTOMRIGHT", wrapper, "BOTTOMRIGHT", -10, 0)
    scroll:EnableMouseWheel(true)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(1, 1)
    scroll:SetScrollChild(content)

    -- Scrollbar track
    local track = CreateFrame("Frame", nil, wrapper)
    track:SetPoint("TOPRIGHT", wrapper, "TOPRIGHT", 0, 0)
    track:SetPoint("BOTTOMRIGHT", wrapper, "BOTTOMRIGHT", 0, 0)
    track:SetWidth(8)
    local trackTex = track:CreateTexture(nil, "BACKGROUND")
    trackTex:SetAllPoints(track)
    trackTex:SetColorTexture(T.bg2[1], T.bg2[2], T.bg2[3], 0.6)

    -- Scrollbar thumb
    local thumb = CreateFrame("Frame", nil, track)
    thumb:SetPoint("TOP", track, "TOP", 0, 0)
    thumb:SetWidth(8)
    thumb:SetHeight(20)
    thumb:EnableMouse(true)
    local thumbTex = thumb:CreateTexture(nil, "ARTWORK")
    thumbTex:SetAllPoints(thumb)
    thumbTex:SetColorTexture(T.border[1], T.border[2], T.border[3], 1)

    local function getMax()
        local ch = content:GetHeight() or 0
        local sh = scroll:GetHeight() or 0
        local m = ch - sh
        if m < 0 then m = 0 end
        return m
    end

    local function updateThumb()
        local trackH = track:GetHeight() or 0
        local ch = content:GetHeight() or 1
        local sh = scroll:GetHeight() or 1
        if ch <= sh or trackH <= 0 then
            thumb:Hide()
            return
        end
        thumb:Show()
        local ratio = sh / ch
        local thumbH = math.max(16, trackH * ratio)
        thumb:SetHeight(thumbH)
        local maxScroll = getMax()
        local cur = scroll:GetVerticalScroll() or 0
        local pct = (maxScroll > 0) and (cur / maxScroll) or 0
        thumb:ClearAllPoints()
        thumb:SetPoint("TOP", track, "TOP", 0, -pct * (trackH - thumbH))
    end

    scroll:SetScript("OnMouseWheel", function(self, delta)
        local cur = self:GetVerticalScroll() or 0
        local step = 24
        local new = cur - delta * step
        if new < 0 then new = 0 end
        local m = getMax()
        if new > m then new = m end
        self:SetVerticalScroll(new)
        updateThumb()
    end)

    -- Drag thumb
    thumb:RegisterForDrag("LeftButton")
    thumb:SetScript("OnDragStart", function(self)
        self.isDragging = true
        self.dragStartY = select(2, GetCursorPosition()) / UIParent:GetEffectiveScale()
        self.dragStartScroll = scroll:GetVerticalScroll() or 0
    end)
    thumb:SetScript("OnDragStop", function(self) self.isDragging = false end)
    thumb:SetScript("OnUpdate", function(self)
        if not self.isDragging then return end
        local y = select(2, GetCursorPosition()) / UIParent:GetEffectiveScale()
        local dy = self.dragStartY - y
        local trackH = track:GetHeight() or 1
        local thumbH = self:GetHeight() or 1
        local travel = trackH - thumbH
        if travel <= 0 then return end
        local m = getMax()
        local new = self.dragStartScroll + (dy / travel) * m
        if new < 0 then new = 0 end
        if new > m then new = m end
        scroll:SetVerticalScroll(new)
        updateThumb()
    end)

    wrapper._updateThumb = updateThumb
    wrapper.scroll = scroll
    wrapper.content = content
    return wrapper, scroll, content
end

function RaidAllies:UpdateScroll(wrapper)
    if wrapper and wrapper._updateThumb then wrapper._updateThumb() end
end

-- Class colour lookup: returns "|cffRRGGBB" or nil for a "Name-Realm" string.
function RaidAllies:GetClassColorCode(fullName)
    if not fullName or not RaidAlliesDB or not RaidAlliesDB.players then return nil end
    local rec = RaidAlliesDB.players[fullName]
    if not rec or not rec.class then return nil end
    local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[rec.class]
    if not c then return nil end
    return c.colorStr and ("|c" .. c.colorStr) or string.format("|cff%02x%02x%02x", c.r*255, c.g*255, c.b*255)
end

function RaidAllies:ColorName(fullName)
    local code = self:GetClassColorCode(fullName)
    if code then return code .. fullName .. "|r" end
    return fullName
end

-- Deprecated shim: old files may still call ApplyFrameTheme — it's a no-op on our custom windows.
function RaidAllies:ApplyFrameTheme(_) end

local _noteDlg
local function BuildNoteDialog()
    if _noteDlg then return _noteDlg end
    local T = RaidAllies.Theme
    local FONT = RaidAllies:GetFont()

    local dlg = RaidAllies:MakeWindow("RaidAlliesNoteDialog", "Edit Note", 360, 180)
    dlg:SetFrameStrata("DIALOG")
    dlg:SetFrameLevel(130)
    if dlg.titleBar then dlg.titleBar:SetFrameLevel(dlg:GetFrameLevel() + 2) end
    if dlg.body then dlg.body:SetFrameLevel(dlg:GetFrameLevel() + 1) end

    dlg.subject = dlg.body:CreateFontString(nil, "OVERLAY")
    dlg.subject:SetFont(FONT, 12, "")
    dlg.subject:SetPoint("TOPLEFT", dlg.body, "TOPLEFT", 12, -10)
    dlg.subject:SetPoint("TOPRIGHT", dlg.body, "TOPRIGHT", -12, -10)
    dlg.subject:SetJustifyH("LEFT")
    dlg.subject:SetTextColor(T.text[1], T.text[2], T.text[3])

    dlg.editBg = RaidAllies:MakePanel(dlg.body)
    dlg.editBg:SetPoint("TOPLEFT", dlg.subject, "BOTTOMLEFT", 0, -8)
    dlg.editBg:SetPoint("TOPRIGHT", dlg.subject, "BOTTOMRIGHT", 0, -8)
    dlg.editBg:SetHeight(70)

    dlg.edit = CreateFrame("EditBox", nil, dlg.editBg)
    dlg.edit:SetPoint("TOPLEFT", dlg.editBg, "TOPLEFT", 6, -6)
    dlg.edit:SetPoint("BOTTOMRIGHT", dlg.editBg, "BOTTOMRIGHT", -6, 6)
    dlg.edit:SetFont(FONT, 12, "")
    dlg.edit:SetTextColor(T.text[1], T.text[2], T.text[3])
    dlg.edit:SetAutoFocus(false)
    dlg.edit:SetMultiLine(true)
    dlg.edit:SetMaxLetters(240)
    dlg.edit:EnableMouse(true)
    dlg.edit:SetScript("OnEscapePressed", function(self) self:ClearFocus(); dlg:Hide() end)

    dlg.saveBtn = RaidAllies:MakeButton(dlg.body, "Save", 70, 22)
    dlg.saveBtn:SetPoint("BOTTOMRIGHT", dlg.body, "BOTTOMRIGHT", -12, 12)

    dlg.cancelBtn = RaidAllies:MakeButton(dlg.body, "Cancel", 70, 22)
    dlg.cancelBtn:SetPoint("RIGHT", dlg.saveBtn, "LEFT", -6, 0)

    dlg.clearBtn = RaidAllies:MakeButton(dlg.body, "Clear", 70, 22)
    dlg.clearBtn:SetPoint("BOTTOMLEFT", dlg.body, "BOTTOMLEFT", 12, 12)

    dlg.saveBtn:SetScript("OnClick", function()
        local name = dlg._playerName
        if name then
            RaidAllies.Data:SetNote(name, dlg.edit:GetText() or "")
        end
        local cb = dlg._onSaved
        dlg:Hide()
        if cb then cb() end
    end)
    dlg.cancelBtn:SetScript("OnClick", function() dlg:Hide() end)
    dlg.clearBtn:SetScript("OnClick", function() dlg.edit:SetText("") end)

    dlg.edit:SetScript("OnEnterPressed", function(self)
        if IsShiftKeyDown() then
            self:Insert("\n")
        else
            dlg.saveBtn:GetScript("OnClick")()
        end
    end)

    _noteDlg = dlg
    return dlg
end

local _confirmDlg
local function BuildConfirmDialog()
    if _confirmDlg then return _confirmDlg end
    local T = RaidAllies.Theme
    local FONT = RaidAllies:GetFont()

    local dlg = RaidAllies:MakeWindow("RaidAlliesConfirmDialog", "Confirm", 360, 160)
    dlg:SetFrameStrata("DIALOG")
    dlg:SetFrameLevel(140)
    if dlg.titleBar then dlg.titleBar:SetFrameLevel(dlg:GetFrameLevel() + 2) end
    if dlg.body then dlg.body:SetFrameLevel(dlg:GetFrameLevel() + 1) end

    dlg.message = dlg.body:CreateFontString(nil, "OVERLAY")
    dlg.message:SetFont(FONT, 12, "")
    dlg.message:SetPoint("TOPLEFT", dlg.body, "TOPLEFT", 14, -14)
    dlg.message:SetPoint("TOPRIGHT", dlg.body, "TOPRIGHT", -14, -14)
    dlg.message:SetJustifyH("LEFT")
    dlg.message:SetJustifyV("TOP")
    dlg.message:SetTextColor(T.text[1], T.text[2], T.text[3])
    dlg.message:SetWordWrap(true)

    dlg.confirmBtn = RaidAllies:MakeButton(dlg.body, "OK", 80, 22)
    dlg.confirmBtn:SetPoint("BOTTOMRIGHT", dlg.body, "BOTTOMRIGHT", -12, 12)

    dlg.cancelBtn = RaidAllies:MakeButton(dlg.body, "Cancel", 80, 22)
    dlg.cancelBtn:SetPoint("RIGHT", dlg.confirmBtn, "LEFT", -6, 0)

    dlg.confirmBtn:SetScript("OnClick", function()
        local cb = dlg._onConfirm
        dlg:Hide()
        if cb then cb() end
    end)
    dlg.cancelBtn:SetScript("OnClick", function() dlg:Hide() end)

    _confirmDlg = dlg
    return dlg
end

function RaidAllies:ShowConfirmDialog(opts)
    opts = opts or {}
    local dlg = BuildConfirmDialog()
    dlg.message:SetText(opts.message or "")
    dlg.confirmBtn:SetText(opts.confirmText or "OK")
    dlg.cancelBtn:SetText(opts.cancelText or "Cancel")
    dlg._onConfirm = opts.onConfirm
    dlg:Show()
    dlg:Raise()
    dlg:SetFrameLevel(140)
    if dlg.titleBar then dlg.titleBar:SetFrameLevel(dlg:GetFrameLevel() + 2) end
    if dlg.body then dlg.body:SetFrameLevel(dlg:GetFrameLevel() + 1) end
end

function RaidAllies:ShowNoteDialog(playerName, onSaved)
    if not playerName then return end
    local dlg = BuildNoteDialog()
    local rec = RaidAllies.Data:Get(playerName)
    local existing = (rec and rec.note) or ""
    dlg._playerName = playerName
    dlg._onSaved = onSaved
    dlg.subject:SetText("Note for " .. RaidAllies:ColorName(playerName))
    dlg.edit:SetText(existing)
    dlg:Show()
    dlg:Raise()
    dlg:SetFrameLevel(130)
    if dlg.titleBar then dlg.titleBar:SetFrameLevel(dlg:GetFrameLevel() + 2) end
    if dlg.body then dlg.body:SetFrameLevel(dlg:GetFrameLevel() + 1) end
    dlg.edit:SetFocus()
    dlg.edit:HighlightText()
end

-- Lightweight context menu. Call RaidAllies:ShowContextMenu(items, anchor) where
-- items = { { text = "...", disabled = bool, onClick = fn }, ... } and anchor is
-- an optional frame (falls back to cursor). `false` as an item inserts a separator.
local _ctxMenu
local ITEM_H = 20
local MENU_PAD_V = 4
local MENU_PAD_H = 6
local MENU_MIN_W = 140
local SEP_H = 5

local function HideContextMenu()
    if _ctxMenu then _ctxMenu:Hide() end
end
RaidAllies.HideContextMenu = HideContextMenu

local function BuildContextMenu()
    if _ctxMenu then return _ctxMenu end
    local T = RaidAllies.Theme

    local m = CreateFrame("Frame", "RaidAlliesContextMenu", UIParent)
    m:SetFrameStrata("FULLSCREEN_DIALOG")
    m:SetFrameLevel(200)
    m:SetClampedToScreen(true)
    m:EnableMouse(true)
    m:Hide()
    PaintRect(m, T.bg2, T.border)

    m.items = {}

    -- Outside-click catcher
    local catcher = CreateFrame("Frame", nil, UIParent)
    catcher:SetAllPoints(UIParent)
    catcher:SetFrameStrata("FULLSCREEN_DIALOG")
    catcher:SetFrameLevel(199)
    catcher:EnableMouse(true)
    catcher:Hide()
    catcher:SetScript("OnMouseDown", function() m:Hide() end)
    m._catcher = catcher

    m:SetScript("OnShow", function() catcher:Show() end)
    m:SetScript("OnHide", function() catcher:Hide() end)

    tinsert(UISpecialFrames, "RaidAlliesContextMenu")
    _ctxMenu = m
    return m
end

local function GetMenuItem(menu, index)
    local it = menu.items[index]
    if it then return it end
    local T = RaidAllies.Theme
    local FONT = RaidAllies:GetFont()

    it = CreateFrame("Button", nil, menu)
    it:SetHeight(ITEM_H)
    it:EnableMouse(true)

    it.hover = it:CreateTexture(nil, "BACKGROUND", nil, 0)
    it.hover:SetAllPoints(it)
    it.hover:SetColorTexture(T.btnBgHov[1], T.btnBgHov[2], T.btnBgHov[3], T.btnBgHov[4])
    it.hover:Hide()

    it.label = it:CreateFontString(nil, "OVERLAY")
    it.label:SetFont(FONT, 11, "")
    it.label:SetPoint("LEFT", it, "LEFT", 8, 0)
    it.label:SetPoint("RIGHT", it, "RIGHT", -8, 0)
    it.label:SetJustifyH("LEFT")
    it.label:SetTextColor(T.text[1], T.text[2], T.text[3])

    it.sep = it:CreateTexture(nil, "OVERLAY")
    it.sep:SetPoint("LEFT", it, "LEFT", 4, 0)
    it.sep:SetPoint("RIGHT", it, "RIGHT", -4, 0)
    it.sep:SetHeight(1)
    it.sep:SetColorTexture(T.border[1], T.border[2], T.border[3], 1)
    it.sep:Hide()

    it:SetScript("OnEnter", function(self)
        if not self._disabled and not self._isSep then self.hover:Show() end
    end)
    it:SetScript("OnLeave", function(self) self.hover:Hide() end)
    it:SetScript("OnClick", function(self)
        if self._disabled or self._isSep then return end
        local fn = self._onClick
        HideContextMenu()
        if fn then fn() end
    end)

    menu.items[index] = it
    return it
end

function RaidAllies:ShowContextMenu(items, anchor)
    local T = self.Theme
    local FONT = self:GetFont()
    local m = BuildContextMenu()

    -- Measure max label width
    local probe = m._probe
    if not probe then
        probe = m:CreateFontString(nil, "OVERLAY")
        probe:SetFont(FONT, 11, "")
        probe:Hide()
        m._probe = probe
    end

    local maxW = MENU_MIN_W
    local totalH = MENU_PAD_V * 2
    local count = 0
    for i, entry in ipairs(items) do
        if entry == false then
            totalH = totalH + SEP_H
        else
            probe:SetText(entry.text or "")
            local w = (probe:GetStringWidth() or 0) + 20
            if w > maxW then maxW = w end
            totalH = totalH + ITEM_H
        end
        count = i
    end

    local prev
    for i = 1, count do
        local entry = items[i]
        local it = GetMenuItem(m, i)
        it:ClearAllPoints()
        if prev then
            it:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, 0)
            it:SetPoint("TOPRIGHT", prev, "BOTTOMRIGHT", 0, 0)
        else
            it:SetPoint("TOPLEFT", m, "TOPLEFT", MENU_PAD_H, -MENU_PAD_V)
            it:SetPoint("TOPRIGHT", m, "TOPRIGHT", -MENU_PAD_H, -MENU_PAD_V)
        end

        if entry == false then
            it:SetHeight(SEP_H)
            it.label:Hide()
            it.sep:Show()
            it._isSep = true
            it._disabled = true
            it._onClick = nil
        else
            it:SetHeight(ITEM_H)
            it.sep:Hide()
            it.label:Show()
            it.label:SetText(entry.text or "")
            it._isSep = false
            it._disabled = entry.disabled and true or false
            it._onClick = entry.onClick
            if it._disabled then
                it.label:SetTextColor(T.textDim[1], T.textDim[2], T.textDim[3])
            else
                it.label:SetTextColor(T.text[1], T.text[2], T.text[3])
            end
        end
        it:Show()
        prev = it
    end

    for i = count + 1, #m.items do
        m.items[i]:Hide()
    end

    m:SetSize(maxW + MENU_PAD_H * 2, totalH)

    m:ClearAllPoints()
    if anchor then
        m:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
    else
        local scale = UIParent:GetEffectiveScale()
        local x, y = GetCursorPosition()
        m:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / scale, y / scale)
    end

    m:Show()
    m:Raise()
end

local function RefreshAllPlayerUIs()
    if RaidAllies.UI_Main and RaidAllies.UI_Main.frame and RaidAllies.UI_Main.frame:IsShown() then
        RaidAllies.UI_Main:Refresh()
    end
    if RaidAllies.UI_Summary and RaidAllies.UI_Summary.frame and RaidAllies.UI_Summary.frame:IsShown() then
        RaidAllies.UI_Summary:Refresh()
    end
    if RaidAllies.UI_SessionPlayers and RaidAllies.UI_SessionPlayers.frame and RaidAllies.UI_SessionPlayers.frame:IsShown() then
        RaidAllies.UI_SessionPlayers:Refresh()
    end
end

function RaidAllies:BuildPlayerMenuItems(playerName)
    local rec = self.Data:Get(playerName)
    local pinned = rec and rec.flags and rec.flags.p
    local shortName = playerName:match("^(.-)%-") or playerName

    return {
        {
            text = pinned and "Unfavourite" or "Favourite",
            onClick = function()
                RaidAllies.Data:SetPinned(playerName, not pinned)
                RefreshAllPlayerUIs()
            end,
        },
        {
            text = (rec and rec.note and rec.note ~= "") and "Edit Note" or "Add Note",
            onClick = function()
                RaidAllies:ShowNoteDialog(playerName, RefreshAllPlayerUIs)
            end,
        },
        false,
        {
            text = "Invite Player",
            onClick = function()
                if C_PartyInfo and C_PartyInfo.InviteUnit then
                    C_PartyInfo.InviteUnit(playerName)
                else
                    InviteUnit(playerName)
                end
            end,
        },
        {
            text = "Whisper Player",
            onClick = function()
                ChatFrame_SendTell(playerName)
            end,
        },
        {
            text = "Ignore Player",
            onClick = function()
                if C_FriendList and C_FriendList.AddIgnore then
                    C_FriendList.AddIgnore(playerName)
                elseif AddIgnore then
                    AddIgnore(playerName)
                end
                RaidAllies:Print("Ignored " .. shortName)
            end,
        },
        false,
        {
            text = "Remove from list",
            onClick = function()
                if RaidAllies.Data:IsHidden(playerName) then
                    RefreshAllPlayerUIs()
                    return
                end
                RaidAllies:ShowConfirmDialog({
                    message = "Remove " .. RaidAllies:ColorName(playerName) .. " from your list?\n\nThey will be hidden but not deleted.\nYou can restore them later.",
                    confirmText = "Remove",
                    cancelText = "Cancel",
                    onConfirm = function()
                        RaidAllies.Data:SetHidden(playerName, true)
                        RefreshAllPlayerUIs()
                    end,
                })
            end,
        },
    }
end

function RaidAllies:ShowPlayerContextMenu(playerName, anchor)
    if not playerName then return end
    self:ShowContextMenu(self:BuildPlayerMenuItems(playerName), anchor)
end

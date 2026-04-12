-- RaidAllies: OptionsFrame
-- Right-side panel anchored to the main frame (same position as FilterFrame).
-- Opening this frame closes FilterFrame if it is open.
-- Controls: opacity slider, font size slider, font dropdown (previews each font),
--           own-realm toggle.

local _, RA = ...
local T = RA.Theme

local OPTIONS_W   = 220
local SECTION_GAP = 10
local LABEL_H     = 16
local ITEM_H      = 26
local SLIDER_H    = 20   -- height of the slider interactive area
local TRACK_H     = 4    -- thickness of the visual track bar

-------------------------------------------------------------------------------
-- MakeSlider — themed horizontal slider with title + live value display
-------------------------------------------------------------------------------

--- @param parent    Frame
--- @param title     string
--- @param minVal    number
--- @param maxVal    number
--- @param step      number
--- @param current   number
--- @param fmt       string   format string for display, e.g. "%d%%" or "%d"
--- @param onChange  function(newValue)
--- @return Frame, function getVal, function setVal
local function MakeSlider(parent, title, minVal, maxVal, step, current, fmt, onChange)
    local container = CreateFrame("Frame", nil, parent)
    container:SetHeight(LABEL_H + SLIDER_H + 8)

    -- Section title (left)
    local lbl = container:CreateFontString(nil, "OVERLAY")
    T:ApplyFont(lbl, 10)
    lbl:SetTextColor(T.COLOR.TEXT_MUTED[1], T.COLOR.TEXT_MUTED[2], T.COLOR.TEXT_MUTED[3])
    lbl:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
    lbl:SetText(title:upper())

    -- Current value (right, in accent colour)
    local valLbl = container:CreateFontString(nil, "OVERLAY")
    T:ApplyFont(valLbl, 10)
    valLbl:SetTextColor(T.COLOR.TEXT_ACCENT[1], T.COLOR.TEXT_ACCENT[2], T.COLOR.TEXT_ACCENT[3])
    valLbl:SetPoint("TOPRIGHT", container, "TOPRIGHT", 0, 0)
    valLbl:SetJustifyH("RIGHT")

    -- Native Slider frame (handles all mouse/drag logic)
    local slider = CreateFrame("Slider", nil, container)
    slider:SetOrientation("HORIZONTAL")
    slider:SetMinMaxValues(minVal, maxVal)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)
    slider:SetPoint("TOPLEFT",  container, "TOPLEFT",  0, -(LABEL_H + 6))
    slider:SetPoint("TOPRIGHT", container, "TOPRIGHT", 0, -(LABEL_H + 6))
    slider:SetHeight(SLIDER_H)
    slider:EnableMouseWheel(true)

    -- Visual track bar (centred vertically in the slider area)
    local trackTex = slider:CreateTexture(nil, "BACKGROUND")
    trackTex:SetHeight(TRACK_H)
    trackTex:SetPoint("TOPLEFT",  slider, "TOPLEFT",  0, -(SLIDER_H / 2 - TRACK_H / 2))
    trackTex:SetPoint("TOPRIGHT", slider, "TOPRIGHT", 0, -(SLIDER_H / 2 - TRACK_H / 2))
    trackTex:SetColorTexture(T.COLOR.BORDER[1], T.COLOR.BORDER[2], T.COLOR.BORDER[3], 0.90)

    -- Thumb handle
    local thumbTex = slider:CreateTexture(nil, "OVERLAY")
    thumbTex:SetSize(10, SLIDER_H - 2)
    thumbTex:SetColorTexture(
        T.COLOR.BORDER_ACCENT[1], T.COLOR.BORDER_ACCENT[2], T.COLOR.BORDER_ACCENT[3], 1.0
    )
    slider:SetThumbTexture(thumbTex)

    local function UpdateDisplay(v)
        valLbl:SetText(string.format(fmt, v))
    end

    -- Set initial value before attaching OnValueChanged to avoid a spurious onChange call
    slider:SetValue(current)
    UpdateDisplay(current)

    slider:SetScript("OnValueChanged", function(_, v)
        UpdateDisplay(v)
        onChange(v)
    end)

    slider:SetScript("OnMouseWheel", function(_, delta)
        local cur = slider:GetValue()
        slider:SetValue(math.max(minVal, math.min(maxVal, cur + delta * step)))
    end)

    return container,
           function() return slider:GetValue() end,
           function(v) slider:SetValue(v) end
end

-------------------------------------------------------------------------------
-- MakeFontDropdown — button that opens a popup listing all fonts in their
-- own typeface so the user can preview before selecting.
-------------------------------------------------------------------------------

local function MakeFontDropdown(parent, title, currentIdx, onChange)
    local container = CreateFrame("Frame", nil, parent)
    container:SetHeight(LABEL_H + ITEM_H + 4)

    -- Section title
    local titleLbl = container:CreateFontString(nil, "OVERLAY")
    T:ApplyFont(titleLbl, 10)
    titleLbl:SetTextColor(T.COLOR.TEXT_MUTED[1], T.COLOR.TEXT_MUTED[2], T.COLOR.TEXT_MUTED[3])
    titleLbl:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
    titleLbl:SetText(title:upper())

    -- Selector button
    local btn = CreateFrame("Button", nil, container)
    btn:SetPoint("TOPLEFT",  container, "TOPLEFT",  0, -(LABEL_H + 2))
    btn:SetPoint("TOPRIGHT", container, "TOPRIGHT", 0, -(LABEL_H + 2))
    btn:SetHeight(22)
    T:AddBackground(btn, { 0.12, 0.12, 0.16, 0.95 })
    T:AddBorder(btn, T.COLOR.BORDER)

    -- Label that renders in the selected font
    local selLbl = btn:CreateFontString(nil, "OVERLAY")
    selLbl:SetPoint("LEFT",  btn, "LEFT",  6,   0)
    selLbl:SetPoint("RIGHT", btn, "RIGHT", -18, 0)
    selLbl:SetJustifyH("LEFT")
    selLbl:SetWordWrap(false)

    -- Down-arrow indicator (▼ U+25BC, Arial Narrow has this glyph)
    local arrowLbl = btn:CreateFontString(nil, "OVERLAY")
    T:ApplySymbolFont(arrowLbl, 10)
    arrowLbl:SetPoint("RIGHT", btn, "RIGHT", -4, 0)
    arrowLbl:SetJustifyH("RIGHT")
    arrowLbl:SetTextColor(T.COLOR.TEXT_MUTED[1], T.COLOR.TEXT_MUTED[2], T.COLOR.TEXT_MUTED[3])
    arrowLbl:SetText("\226\150\188")   -- UTF-8 ▼

    local idx   = currentIdx or 1
    local popup  -- created lazily on first click

    local function UpdateButton()
        local fname = T.FONT_NAMES[idx] or T.FONT_NAMES[1]
        local fpath = T.FONT_MAP[fname]  or "Fonts\\FRIZQT__.TTF"
        selLbl:SetFont(fpath, T:GetFontSize())
        selLbl:SetText(fname)
        selLbl:SetTextColor(T.COLOR.TEXT_PRIMARY[1], T.COLOR.TEXT_PRIMARY[2], T.COLOR.TEXT_PRIMARY[3])
    end

    local function ClosePopup()
        if popup then popup:Hide() end
    end

    local ROW_H_POPUP = 26

    local function CreatePopup()
        local n    = #T.FONT_NAMES
        local popH = n * ROW_H_POPUP + 4

        popup = CreateFrame("Frame", "RaidAlliesFontDropdown", UIParent)
        popup:SetFrameStrata("TOOLTIP")
        popup:SetClampedToScreen(true)
        popup:SetHeight(popH)
        T:AddBackground(popup, { 0.09, 0.09, 0.12, 0.98 })
        T:AddBorder(popup, T.COLOR.BORDER)

        for i, fname in ipairs(T.FONT_NAMES) do
            local fpath = T.FONT_MAP[fname] or "Fonts\\FRIZQT__.TTF"
            local row   = CreateFrame("Button", nil, popup)
            row:SetPoint("TOPLEFT",  popup, "TOPLEFT",  2, -(2 + (i - 1) * ROW_H_POPUP))
            row:SetPoint("TOPRIGHT", popup, "TOPRIGHT", -2, -(2 + (i - 1) * ROW_H_POPUP))
            row:SetHeight(ROW_H_POPUP)

            local hoverTex = row:CreateTexture(nil, "BACKGROUND")
            hoverTex:SetAllPoints()
            hoverTex:SetColorTexture(0, 0, 0, 0)

            -- Each font name is rendered in its own typeface for preview
            local rowLbl = row:CreateFontString(nil, "OVERLAY")
            rowLbl:SetFont(fpath, T:GetFontSize())
            rowLbl:SetPoint("LEFT",  row, "LEFT",  6, 0)
            rowLbl:SetPoint("RIGHT", row, "RIGHT", -6, 0)
            rowLbl:SetJustifyH("LEFT")
            rowLbl:SetWordWrap(false)
            rowLbl:SetText(fname)
            rowLbl:SetTextColor(T.COLOR.TEXT_SECONDARY[1], T.COLOR.TEXT_SECONDARY[2], T.COLOR.TEXT_SECONDARY[3])

            row:SetScript("OnEnter", function()
                hoverTex:SetColorTexture(
                    T.COLOR.BORDER_ACCENT[1], T.COLOR.BORDER_ACCENT[2], T.COLOR.BORDER_ACCENT[3], 0.18
                )
                rowLbl:SetTextColor(T.COLOR.TEXT_ACCENT[1], T.COLOR.TEXT_ACCENT[2], T.COLOR.TEXT_ACCENT[3])
            end)
            row:SetScript("OnLeave", function()
                hoverTex:SetColorTexture(0, 0, 0, 0)
                rowLbl:SetTextColor(T.COLOR.TEXT_SECONDARY[1], T.COLOR.TEXT_SECONDARY[2], T.COLOR.TEXT_SECONDARY[3])
            end)

            -- Capture loop vars
            local capturedI    = i
            local capturedName = fname
            row:SetScript("OnClick", function()
                idx = capturedI
                UpdateButton()
                onChange(capturedI, capturedName)
                ClosePopup()
            end)
        end

        tinsert(UISpecialFrames, "RaidAlliesFontDropdown")
    end

    btn:SetScript("OnClick", function()
        if popup and popup:IsShown() then
            ClosePopup()
            return
        end
        if not popup then CreatePopup() end
        popup:ClearAllPoints()
        popup:SetWidth(btn:GetWidth())
        popup:SetPoint("TOPLEFT", btn, "BOTTOMLEFT", 0, -2)
        popup:Show()
    end)

    btn:SetScript("OnEnter", function()
        arrowLbl:SetTextColor(T.COLOR.TEXT_ACCENT[1], T.COLOR.TEXT_ACCENT[2], T.COLOR.TEXT_ACCENT[3])
    end)
    btn:SetScript("OnLeave", function()
        arrowLbl:SetTextColor(T.COLOR.TEXT_MUTED[1], T.COLOR.TEXT_MUTED[2], T.COLOR.TEXT_MUTED[3])
    end)

    UpdateButton()

    return container,
           function() return idx, T.FONT_NAMES[idx] end,
           function(i) idx = i; UpdateButton() end
end

-------------------------------------------------------------------------------
-- MakeCheckbox — custom checkbox (same approach as FilterFrame, kept local)
-------------------------------------------------------------------------------

local function MakeCheckbox(parent, label)
    local container = CreateFrame("Button", nil, parent)
    container:SetHeight(ITEM_H)

    local boxFrame = CreateFrame("Frame", nil, container)
    boxFrame:SetSize(13, 13)
    boxFrame:SetPoint("LEFT", container, "LEFT", 0, 0)
    T:AddBackground(boxFrame, { 0.12, 0.12, 0.16, 0.95 })
    T:AddBorder(boxFrame, T.COLOR.BORDER)

    local checkTex = boxFrame:CreateTexture(nil, "OVERLAY")
    checkTex:SetSize(9, 9)
    checkTex:SetPoint("CENTER", boxFrame, "CENTER", 0, 0)
    checkTex:SetColorTexture(T.COLOR.BORDER_ACCENT[1], T.COLOR.BORDER_ACCENT[2], T.COLOR.BORDER_ACCENT[3], 0.90)
    checkTex:Hide()

    local lbl = container:CreateFontString(nil, "OVERLAY")
    T:ApplyFont(lbl, T:GetFontSize() - 1)
    lbl:SetTextColor(T.COLOR.TEXT_SECONDARY[1], T.COLOR.TEXT_SECONDARY[2], T.COLOR.TEXT_SECONDARY[3])
    lbl:SetPoint("LEFT", boxFrame, "RIGHT", 6, 0)
    lbl:SetPoint("RIGHT", container, "RIGHT", 0, 0)
    lbl:SetJustifyH("LEFT")
    lbl:SetText(label)

    local checked = false
    local function SetChecked(v)
        checked = v
        if v then checkTex:Show() else checkTex:Hide() end
        lbl:SetTextColor(
            v and T.COLOR.TEXT_PRIMARY[1]   or T.COLOR.TEXT_SECONDARY[1],
            v and T.COLOR.TEXT_PRIMARY[2]   or T.COLOR.TEXT_SECONDARY[2],
            v and T.COLOR.TEXT_PRIMARY[3]   or T.COLOR.TEXT_SECONDARY[3]
        )
    end

    container:SetScript("OnEnter", function()
        lbl:SetTextColor(T.COLOR.TEXT_ACCENT[1], T.COLOR.TEXT_ACCENT[2], T.COLOR.TEXT_ACCENT[3])
    end)
    container:SetScript("OnLeave", function()
        lbl:SetTextColor(
            checked and T.COLOR.TEXT_PRIMARY[1]   or T.COLOR.TEXT_SECONDARY[1],
            checked and T.COLOR.TEXT_PRIMARY[2]   or T.COLOR.TEXT_SECONDARY[2],
            checked and T.COLOR.TEXT_PRIMARY[3]   or T.COLOR.TEXT_SECONDARY[3]
        )
    end)

    return container, function() return checked end, SetChecked
end

-------------------------------------------------------------------------------
-- Frame creation
-------------------------------------------------------------------------------

function RA:CreateOptionsFrame()
    local f = CreateFrame("Frame", "RaidAlliesOptionsFrame", UIParent)
    f:SetWidth(OPTIONS_W)
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    f:Hide()
    RA.optionsFrame = f

    T:AddBackground(f, T.COLOR.BG_MAIN)
    T:AddBorder(f, T.COLOR.BORDER)

    -- Anchor dynamically to stay right of the main frame
    f:SetScript("OnShow", function(self)
        self:ClearAllPoints()
        self:SetPoint("TOPLEFT",    RA.mainFrame, "TOPRIGHT",    4, 0)
        self:SetPoint("BOTTOMLEFT", RA.mainFrame, "BOTTOMRIGHT", 4, 0)
    end)

    -- ── Title bar ──────────────────────────────────────────────────────────
    local titleBar = CreateFrame("Frame", nil, f)
    titleBar:SetPoint("TOPLEFT",  f, "TOPLEFT",  0, 0)
    titleBar:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
    titleBar:SetHeight(TITLE_H)
    T:AddBackground(titleBar, T.COLOR.BG_TITLE)

    local sep = titleBar:CreateTexture(nil, "BORDER")
    sep:SetColorTexture(T.COLOR.BORDER[1], T.COLOR.BORDER[2], T.COLOR.BORDER[3], 1)
    sep:SetPoint("BOTTOMLEFT",  titleBar, "BOTTOMLEFT")
    sep:SetPoint("BOTTOMRIGHT", titleBar, "BOTTOMRIGHT")
    sep:SetHeight(1)

    local titleLbl = titleBar:CreateFontString(nil, "OVERLAY")
    T:ApplyFont(titleLbl, 12)
    titleLbl:SetTextColor(T.COLOR.TEXT_PRIMARY[1], T.COLOR.TEXT_PRIMARY[2], T.COLOR.TEXT_PRIMARY[3])
    titleLbl:SetPoint("LEFT", titleBar, "LEFT", 10, 0)
    titleLbl:SetText("Options")

    -- ── Content area ───────────────────────────────────────────────────────
    local content = CreateFrame("Frame", nil, f)
    content:SetPoint("TOPLEFT",     titleBar, "BOTTOMLEFT",  10,  -12)
    content:SetPoint("BOTTOMRIGHT", f,         "BOTTOMRIGHT", -10,  10)

    local curY = 0   -- tracks downward position within content

    -- ── Opacity slider ─────────────────────────────────────────────────────
    local initOpacity = math.floor((RA.db.settings.opacity or 1.0) * 100)
    local opacitySlider, _, opacitySet = MakeSlider(content,
        "Window Opacity",
        20, 100, 5, initOpacity, "%d%%",
        function(v)
            RA.db.settings.opacity = v / 100
            RA:ApplyOpacity()
        end
    )
    opacitySlider:SetPoint("TOPLEFT",  content, "TOPLEFT",  0, curY)
    opacitySlider:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, curY)
    RA._optOpacitySet = opacitySet
    curY = curY - (LABEL_H + SLIDER_H + 8 + SECTION_GAP)

    -- ── Font size slider ───────────────────────────────────────────────────
    local initFontSize = RA.db.settings.fontSize or 13
    local fontSizeSlider, _, fontSizeSet = MakeSlider(content,
        "Font Size",
        10, 18, 1, initFontSize, "%d",
        function(v)
            RA.db.settings.fontSize = v
            RA:ApplyFontSize()
        end
    )
    fontSizeSlider:SetPoint("TOPLEFT",  content, "TOPLEFT",  0, curY)
    fontSizeSlider:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, curY)
    RA._optFontSizeSet = fontSizeSet
    curY = curY - (LABEL_H + SLIDER_H + 8 + SECTION_GAP)

    -- ── Font dropdown ──────────────────────────────────────────────────────
    local currentFontIdx = 1
    for i, name in ipairs(T.FONT_NAMES) do
        if name == (RA.db.settings.fontName or "Friz Quadrata TT") then
            currentFontIdx = i
            break
        end
    end

    local fontDropdown, _, fontIdxSet = MakeFontDropdown(content,
        "Font",
        currentFontIdx,
        function(_, fontName)
            RA.db.settings.fontName = fontName
            RA:ApplyFontSize()   -- clears row pools so next refresh uses new font
        end
    )
    fontDropdown:SetPoint("TOPLEFT",  content, "TOPLEFT",  0, curY)
    fontDropdown:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, curY)
    RA._optFontIdxSet = fontIdxSet
end

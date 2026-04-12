-- RaidAllies: FilterFrame
-- Right-side panel anchored to the main frame.
-- Provides difficulty buttons, raid checkboxes, achievement/full-clear/guild-clear
-- toggles, and a minimum-players input.
-- Opening this frame closes the OptionsFrame if it is open.

local _, RA = ...
local T = RA.Theme

-- Panel dimensions
local FILTER_W     = 220
local SECTION_GAP  = 8    -- gap between sections
local ITEM_H       = 22   -- height per checkbox / radio row
local LABEL_H      = 16   -- section title height, (16) default

-------------------------------------------------------------------------------
-- Internal widget helpers
-------------------------------------------------------------------------------

--- Creates a slim section label.
local function MakeSectionLabel(parent, text, yOffset)
    local lbl = parent:CreateFontString(nil, "OVERLAY")
    T:ApplyFont(lbl, 10)
    lbl:SetTextColor(T.COLOR.TEXT_MUTED[1], T.COLOR.TEXT_MUTED[2], T.COLOR.TEXT_MUTED[3])
    lbl:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, yOffset)
    lbl:SetText(text:upper())
    return lbl
end

--- Creates a custom checkbox: small square + label text.
--- Returns: container frame, getter fn, setter fn
local function MakeCheckbox(parent, label, yAnchor, xOffset)
    xOffset = xOffset or 10
    local container = CreateFrame("Button", nil, parent)
    container:SetHeight(ITEM_H)
    container:SetPoint("TOPLEFT",  parent, "TOPLEFT", xOffset, yAnchor)
    container:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -xOffset, yAnchor)

    -- Box
    local box = container:CreateTexture(nil, "ARTWORK")
    box:SetSize(13, 13)
    box:SetPoint("LEFT", container, "LEFT", 0, 0)
    box:SetColorTexture(0.12, 0.12, 0.16, 0.95)

    local boxBorder = container:CreateTexture(nil, "BORDER")
    boxBorder:SetSize(13, 13)
    boxBorder:SetPoint("CENTER", box, "CENTER", 0, 0)
    -- 1px border via slightly larger transparent layer is not trivial; use T:AddBorder on a sub-frame
    local boxFrame = CreateFrame("Frame", nil, container)
    boxFrame:SetSize(13, 13)
    boxFrame:SetPoint("LEFT", container, "LEFT", 0, 0)
    T:AddBackground(boxFrame, { 0.12, 0.12, 0.16, 0.95 })
    T:AddBorder(boxFrame, T.COLOR.BORDER)

    -- Check mark (accent colour fill)
    local checkTex = boxFrame:CreateTexture(nil, "OVERLAY")
    checkTex:SetSize(9, 9)
    checkTex:SetPoint("CENTER", boxFrame, "CENTER", 0, 0)
    checkTex:SetColorTexture(T.COLOR.BORDER_ACCENT[1], T.COLOR.BORDER_ACCENT[2], T.COLOR.BORDER_ACCENT[3], 0.90)
    checkTex:Hide()

    -- Label
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

--- Creates a difficulty radio button pill.
--- @param parent  Frame
--- @param label   string   e.g. "Any", "Heroic"
--- @param diffKey string|nil  nil = Any
--- @param isFirst boolean
--- @return Button
local function MakeDiffButton(parent, label, diffKey, isFirst, prevBtn)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetHeight(20)

    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.12, 0.12, 0.16, 0.90)
    btn._bg = bg

    T:AddBorder(btn, T.COLOR.BORDER)

    local lbl = btn:CreateFontString(nil, "OVERLAY")
    T:ApplyFont(lbl, 9)
    lbl:SetAllPoints()
    lbl:SetJustifyH("CENTER")
    lbl:SetText(label)
    btn._lbl = lbl

    if diffKey and RA.DIFFICULTY_COLORS[diffKey] then
        local dc = RA.DIFFICULTY_COLORS[diffKey]
        lbl:SetTextColor(dc.r, dc.g, dc.b)
    else
        lbl:SetTextColor(T.COLOR.TEXT_SECONDARY[1], T.COLOR.TEXT_SECONDARY[2], T.COLOR.TEXT_SECONDARY[3])
    end

    btn._diffKey = diffKey

    local function SetActive(v)
        if v then
            bg:SetColorTexture(T.COLOR.BORDER_ACCENT[1], T.COLOR.BORDER_ACCENT[2], T.COLOR.BORDER_ACCENT[3], 0.22)
            lbl:SetTextColor(T.COLOR.TEXT_PRIMARY[1], T.COLOR.TEXT_PRIMARY[2], T.COLOR.TEXT_PRIMARY[3])
        else
            bg:SetColorTexture(0.12, 0.12, 0.16, 0.90)
            if diffKey and RA.DIFFICULTY_COLORS[diffKey] then
                local dc = RA.DIFFICULTY_COLORS[diffKey]
                lbl:SetTextColor(dc.r, dc.g, dc.b)
            else
                lbl:SetTextColor(T.COLOR.TEXT_SECONDARY[1], T.COLOR.TEXT_SECONDARY[2], T.COLOR.TEXT_SECONDARY[3])
            end
        end
    end
    btn._SetActive = SetActive

    btn:SetScript("OnClick", function()
        -- Deactivate all siblings, activate self
        for _, sibling in ipairs(btn._siblings or {}) do
            sibling._SetActive(false)
        end
        SetActive(true)
        RA.activeFilters.difficulty = diffKey
        RA:RefreshEncounterList()
    end)

    return btn
end

-------------------------------------------------------------------------------
-- Frame creation
-------------------------------------------------------------------------------

function RA:CreateFilterFrame()
    local f = CreateFrame("Frame", "RaidAlliesFilterFrame", UIParent)
    f:SetWidth(FILTER_W)
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    f:Hide()
    RA.filterFrame = f

    T:AddBackground(f, T.COLOR.BG_MAIN)
    T:AddBorder(f, T.COLOR.BORDER)

    -- Keep anchored to the right of the main frame whenever shown
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
    titleLbl:SetText("Filters")

    -- ── Scrollable content area ────────────────────────────────────────────
    local scrollParent = CreateFrame("Frame", nil, f)
    scrollParent:SetPoint("TOPLEFT",     titleBar, "BOTTOMLEFT",  0,  -4)
    scrollParent:SetPoint("BOTTOMRIGHT", f,         "BOTTOMRIGHT", 0,  44)  -- leave room for reset btn

    local scroll = CreateFrame("ScrollFrame", nil, scrollParent)
    scroll:SetAllPoints(scrollParent)
    scroll:EnableMouseWheel(true)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetWidth(FILTER_W - 14)
    scroll:SetScrollChild(content)
    scroll:SetScript("OnMouseWheel", function(sf, delta)
        local cur = sf:GetVerticalScroll()
        local rng = sf:GetVerticalScrollRange()
        sf:SetVerticalScroll(math.max(0, math.min(rng, cur - delta * 20)))
    end)

    -- Track content height as we build
    local curY = -6

    -- ── DIFFICULTY ─────────────────────────────────────────────────────────
    MakeSectionLabel(content, "Raid Difficulty", curY)
    curY = curY - LABEL_H - 2

    -- 5 buttons in one row: Any / LFR / Normal / Heroic / Mythic
    local diffDefs = {
        { label = "Any",    key = nil      },
        { label = "LFR",    key = "LFR"    },
        { label = "Normal", key = "Normal" },
        { label = "Heroic", key = "Heroic" },
        { label = "Mythic", key = "Mythic" },
    }
    local diffButtons = {}
    local btnW = math.floor((FILTER_W - 20) / #diffDefs) - 2

    for i, def in ipairs(diffDefs) do
        local btn = MakeDiffButton(content, def.label, def.key, i == 1, nil)
        btn:SetWidth(btnW)
        btn:SetPoint("TOPLEFT", content, "TOPLEFT", 10 + (i - 1) * (btnW + 2), curY)
        diffButtons[i] = btn
    end
    -- Give every button a reference to its siblings for mutual exclusion
    for _, btn in ipairs(diffButtons) do
        btn._siblings = diffButtons
    end
    -- Initialise "Any" as active
    diffButtons[1]._SetActive(true)

    curY = curY - 30 - SECTION_GAP

    -- ── RAIDS ──────────────────────────────────────────────────────────────
    MakeSectionLabel(content, "Raids", curY)
    curY = curY - LABEL_H - 2

    -- Raid checkboxes are created dynamically when the frame is shown (RefreshFilterFrame)
    local raidContainer = CreateFrame("Frame", nil, content)
    raidContainer:SetPoint("TOPLEFT",  content, "TOPLEFT",  0, curY)
    raidContainer:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, curY)
    raidContainer:SetHeight(1)  -- resized in RefreshFilterFrame
    RA._filterRaidContainer = raidContainer
    RA._filterRaidCheckboxes = {}

    curY = curY - 1  -- will be adjusted after RefreshFilterFrame fills it

    -- Store the curY *after* raid container so we can place items below it
    RA._filterAfterRaidY = curY
    RA._filterRaidStartY = curY  -- will be updated

    -- ── ACHIEVEMENT ────────────────────────────────────────────────────────
    -- These are placed relative to the raid container bottom in RefreshFilterFrame
    local achCheck, achGet, achSet = MakeCheckbox(content, "AOTC / CE kills only", -4, 10)
    achCheck:ClearAllPoints()  -- will be repositioned in Refresh
    RA._filterAchCheck   = achCheck
    RA._filterAchGet     = achGet
    RA._filterAchSet     = achSet

    -- ── FULL CLEAR ─────────────────────────────────────────────────────────
    local fcCheck, fcGet, fcSet = MakeCheckbox(content, "Full Clear only", -4, 10)
    fcCheck:ClearAllPoints()
    RA._filterFcCheck    = fcCheck
    RA._filterFcGet      = fcGet
    RA._filterFcSet      = fcSet

    -- ── GUILD CLEAR ────────────────────────────────────────────────────────
    local gcCheck, gcGet, gcSet = MakeCheckbox(content, "Guild Clear", -4, 10)
    gcCheck:ClearAllPoints()
    RA._filterGcCheck    = gcCheck
    RA._filterGcGet      = gcGet
    RA._filterGcSet      = gcSet

    -- ── OWN REALM ONLY ──────────────────────────────────────────────────────
    local realmCheck, realmGet, realmSet = MakeCheckbox(content, "Own realm only", -4, 10)
    realmCheck:ClearAllPoints()
    RA._filterRealmCheck = realmCheck
    RA._filterRealmGet   = realmGet
    RA._filterRealmSet   = realmSet

--[=[ -- Removed because useless?
    -- Min-players label + edit box
    local minLabel = content:CreateFontString(nil, "OVERLAY")
    T:ApplyFont(minLabel, 10)
    minLabel:SetTextColor(T.COLOR.TEXT_MUTED[1], T.COLOR.TEXT_MUTED[2], T.COLOR.TEXT_MUTED[3])
    minLabel:SetText("MIN PLAYERS WITH YOU")
    RA._filterMinLabel = minLabel

    local minBox = CreateFrame("EditBox", nil, content)
    minBox:SetSize(44, 20)
    minBox:SetAutoFocus(false)
    minBox:SetNumeric(true)
    minBox:SetMaxLetters(3)
    T:ApplyFont(minBox, T:GetFontSize() - 1)
    minBox:SetTextColor(T.COLOR.TEXT_PRIMARY[1], T.COLOR.TEXT_PRIMARY[2], T.COLOR.TEXT_PRIMARY[3])
    T:AddBackground(minBox, { 0.10, 0.10, 0.14, 0.95 })
    T:AddBorder(minBox, T.COLOR.BORDER)
    minBox:SetText("0")
    minBox:SetJustifyH("CENTER")
    minBox:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        local v = tonumber(self:GetText()) or 0
        v = math.max(0, math.min(999, v))
        self:SetText(tostring(v))
        RA.activeFilters.minKills = v
        RA:RefreshEncounterList()
    end)
    minBox:SetScript("OnEditFocusLost", function(self)
        local v = tonumber(self:GetText()) or 0
        v = math.max(0, math.min(999, v))
        self:SetText(tostring(v))
        RA.activeFilters.minKills = v
        RA:RefreshEncounterList()
    end)
    RA._filterMinBox = minBox

]=]


    -- Wire up checkbox callbacks after all widgets exist
    local function WireCallbacks()
        achCheck:SetScript("OnClick", function()
            local v = not achGet()
            achSet(v)
            RA.activeFilters.achievementOnly = v
            RA:RefreshEncounterList()
        end)
        fcCheck:SetScript("OnClick", function()
            local v = not fcGet()
            fcSet(v)
            RA.activeFilters.fullClearOnly = v
            RA:RefreshEncounterList()
        end)
        gcCheck:SetScript("OnClick", function()
            local v = not gcGet()
            gcSet(v)
            RA.activeFilters.guildClearOnly = v
            RA:RefreshEncounterList()
        end)
        realmCheck:SetScript("OnClick", function()
            local v = not realmGet()
            realmSet(v)
            RA.db.settings.filterRealm = v
            RA:RefreshEncounterList()
        end)
    end
    WireCallbacks()

    -- ── Reset button ───────────────────────────────────────────────────────
    local resetBtn = RA:_MakeTextButton(f, "Reset Filters", function()
        RA:ResetFilters()
    end)
    resetBtn:SetPoint("BOTTOM", f, "BOTTOM", 0, 10)

    RA._filterContent = content
    RA._filterScroll  = scroll
    RA._filterDiffButtons = diffButtons
end

-------------------------------------------------------------------------------
-- Refresh  (called each time the frame is shown)
-- Rebuilds the raid checkbox list from the live DB and repositions all widgets.
-------------------------------------------------------------------------------

function RA:RefreshFilterFrame()
    local content = RA._filterContent
    if not content then return end

    local f   = RA.activeFilters
    local curY = -(28 + 6)  -- below title bar gap

    -- ── Difficulty buttons ─────────────────────────────────────────────────
    -- Just sync active state; the buttons are already placed at fixed positions
    -- which we set in CreateFilterFrame at a fixed curY.  Reposition them now.
    local diffDefs = { nil, "LFR", "Normal", "Heroic", "Mythic" }
    local btnW = math.floor((FILTER_W - 20) / 5) - 2
    for i, btn in ipairs(RA._filterDiffButtons) do
        btn:ClearAllPoints()
        btn:SetPoint("TOPLEFT", content, "TOPLEFT", 10 + (i - 1) * (btnW + 2), curY + 8)
    end
    curY = curY - LABEL_H - 2 - SECTION_GAP

    -- Sync difficulty active state
    for _, btn in ipairs(RA._filterDiffButtons) do
        btn._SetActive(btn._diffKey == f.difficulty)
    end

    -- ── Raid checkboxes ────────────────────────────────────────────────────
    -- Position section label
    local raidLabelY = curY
    curY = curY - LABEL_H - 2

    local raids = RA:GetAllRaidNames()
    local raidContainer = RA._filterRaidContainer

    -- Hide all existing checkboxes
    for _, cb in ipairs(RA._filterRaidCheckboxes) do
        cb.container:Hide()
    end
    RA._filterRaidCheckboxes = {}

    local raidY = 0
    for _, raidName in ipairs(raids) do
        local isActive = f.raids[raidName] == true

        local cbContainer, cbGet, cbSet = MakeCheckbox(raidContainer, raidName, -raidY, 10)
        cbSet(isActive)
        cbContainer:SetScript("OnClick", function()
            local v = not cbGet()
            cbSet(v)
            if v then
                f.raids[raidName] = true
            else
                f.raids[raidName] = nil
            end
            RA:RefreshEncounterList()
        end)

        RA._filterRaidCheckboxes[#RA._filterRaidCheckboxes + 1] = {
            container = cbContainer,
            name      = raidName,
            get       = cbGet,
            set       = cbSet,
        }
        raidY = raidY + ITEM_H
    end

    -- Resize the raid container to fit its children
    raidContainer:ClearAllPoints()
    raidContainer:SetPoint("TOPLEFT",  content, "TOPLEFT",  0, curY)
    raidContainer:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, curY)
    raidContainer:SetHeight(math.max(1, raidY))

    curY = curY - raidY - SECTION_GAP

    -- ── Achievement / Full Clear / Guild Clear ─────────────────────────────
    MakeSectionLabel(content, "Filters", curY)
    curY = curY - LABEL_H - 2

    RA._filterAchCheck:ClearAllPoints()
    RA._filterAchCheck:SetPoint("TOPLEFT",  content, "TOPLEFT",  10, curY)
    RA._filterAchCheck:SetPoint("TOPRIGHT", content, "TOPRIGHT", -10, curY)
    RA._filterAchSet(f.achievementOnly)
    curY = curY - ITEM_H

    RA._filterFcCheck:ClearAllPoints()
    RA._filterFcCheck:SetPoint("TOPLEFT",  content, "TOPLEFT",  10, curY)
    RA._filterFcCheck:SetPoint("TOPRIGHT", content, "TOPRIGHT", -10, curY)
    RA._filterFcSet(f.fullClearOnly)
    curY = curY - ITEM_H

    RA._filterGcCheck:ClearAllPoints()
    RA._filterGcCheck:SetPoint("TOPLEFT",  content, "TOPLEFT",  10, curY)
    RA._filterGcCheck:SetPoint("TOPRIGHT", content, "TOPRIGHT", -10, curY)
    RA._filterGcSet(f.guildClearOnly)
    curY = curY - ITEM_H

    RA._filterRealmCheck:ClearAllPoints()
    RA._filterRealmCheck:SetPoint("TOPLEFT",  content, "TOPLEFT",  10, curY)
    RA._filterRealmCheck:SetPoint("TOPRIGHT", content, "TOPRIGHT", -10, curY)
    RA._filterRealmSet(RA.db.settings.filterRealm or false)
    curY = curY - ITEM_H - SECTION_GAP

--[=[ -- Removed because useless?
    -- ── Min players ────────────────────────────────────────────────────────
    RA._filterMinLabel:ClearAllPoints()
    RA._filterMinLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 10, curY)
    curY = curY - LABEL_H - 2

    RA._filterMinBox:ClearAllPoints()
    RA._filterMinBox:SetPoint("TOPLEFT", content, "TOPLEFT", 10, curY)
    RA._filterMinBox:SetText(tostring(f.minKills or 0))
    curY = curY - 22

]=]


    -- Resize content to fit everything
    content:SetHeight(math.abs(curY) + 10)
end

-------------------------------------------------------------------------------
-- Reset
-------------------------------------------------------------------------------

function RA:ResetFilters()
    local f = RA.activeFilters
    f.difficulty      = nil
    f.raids           = {}
    f.achievementOnly = false
    f.minKills        = 0
    f.fullClearOnly   = false
    f.guildClearOnly  = false

    if RA.filterFrame and RA.filterFrame:IsShown() then
        RA:RefreshFilterFrame()
    end
    RA:RefreshEncounterList()
end
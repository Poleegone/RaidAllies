-- RaidAllies: MainWindow
-- Builds and manages the primary addon frame:
--   • Dark/slate chrome with accent title stripe
--   • Draggable title bar, corner-drag resize, clamped to screen
--   • ESC key support (UISpecialFrames)
--   • X close button (Blizzard atlas texture), Filter and Options buttons
--   • Footer with Support and credit text
--   • 3-level view switching: SessionList ↔ BossList ↔ PlayerList
--   • Shared CreateScrollArea() helper used by all list views
--   • Persistent window geometry (position + size saved in db.settings)
--   • DIALOG frame strata so window sits above HUD elements

local _, RA = ...
local T = RA.Theme

-- Blizzard globals — declared locally so static analysers don't warn.
local StaticPopupDialogs = StaticPopupDialogs  ---@diagnostic disable-line: undefined-global
local StaticPopup_Show   = StaticPopup_Show    ---@diagnostic disable-line: undefined-global
local UISpecialFrames    = UISpecialFrames     ---@diagnostic disable-line: undefined-global

-- ─── Layout constants ────────────────────────────────────────────────────────

local WIN_DEFAULT_W = 540
local WIN_DEFAULT_H = 500
local WIN_MIN_W     = 400
local WIN_MIN_H     = 300
local WIN_MAX_W     = 1400
local WIN_MAX_H     = 1000

TITLE_H     = 34
local FOOTER_H    = 30
local CONTENT_PAD = 6   -- inset from frame edge to content area
local TAB_H       = 28  -- height of the tab bar strip
local SPLIT_W     = 260 -- fixed width of the pinned allies panel (right side)

-- ─── StaticPopup for "Support me" ────────────────────────────────────────────

StaticPopupDialogs["RAIDALLIES_SUPPORT"] = {
    text          = "https://ko-fi.com/nosebug",
    button1       = "Okay",
    timeout       = 0,
    whileDead     = true,
    hideOnEscape  = true,
    preferredIndex = 3,
}

-- ─── Custom note dialog ──────────────────────────────────────────────────────

--- Shows the note-editing dialog for a player. Lazily creates the frame on first call.
function RA:ShowNoteDialog(name, realm)
    if not RA._noteDialog then
        RA:_BuildNoteDialog()
    end
    local dlg = RA._noteDialog
    dlg._playerKey = RA:PlayerKey(name, realm)
    dlg._titleText:SetText("Note for " .. name)
    local rec = RA.db.players[dlg._playerKey]
    dlg._editBox:SetText(rec and rec.note or "")
    dlg._editBox:HighlightText()
    dlg:Show()
    dlg._editBox:SetFocus()
end

function RA:_BuildNoteDialog()
    local dlg = CreateFrame("Frame", "RaidAlliesNoteDialog", UIParent)
    dlg:SetSize(300, 120)
    dlg:SetPoint("CENTER")
    dlg:SetFrameStrata("FULLSCREEN_DIALOG")
    dlg:SetClampedToScreen(true)
    dlg:Hide()
    RA._noteDialog = dlg

    T:AddBackground(dlg, T.COLOR.BG_MAIN)
    T:AddBorder(dlg, T.COLOR.BORDER)

    -- Title strip
    local titleBar = CreateFrame("Frame", nil, dlg)
    titleBar:SetPoint("TOPLEFT",  dlg, "TOPLEFT",  0, 0)
    titleBar:SetPoint("TOPRIGHT", dlg, "TOPRIGHT", 0, 0)
    titleBar:SetHeight(28)
    T:AddBackground(titleBar, T.COLOR.BG_TITLE)
    local sep = titleBar:CreateTexture(nil, "BORDER")
    sep:SetColorTexture(T.COLOR.BORDER[1], T.COLOR.BORDER[2], T.COLOR.BORDER[3], 1)
    sep:SetPoint("BOTTOMLEFT",  titleBar, "BOTTOMLEFT")
    sep:SetPoint("BOTTOMRIGHT", titleBar, "BOTTOMRIGHT")
    sep:SetHeight(1)
    local titleText = titleBar:CreateFontString(nil, "OVERLAY")
    T:ApplyFont(titleText, 11)
    titleText:SetTextColor(T.COLOR.TEXT_PRIMARY[1], T.COLOR.TEXT_PRIMARY[2], T.COLOR.TEXT_PRIMARY[3])
    titleText:SetPoint("LEFT", titleBar, "LEFT", 10, 0)
    dlg._titleText = titleText

    -- EditBox container
    local ebBg = CreateFrame("Frame", nil, dlg)
    ebBg:SetPoint("TOPLEFT",     dlg, "TOPLEFT",     10, -36)
    ebBg:SetPoint("TOPRIGHT",    dlg, "TOPRIGHT",    -10, -36)
    ebBg:SetHeight(26)
    T:AddBackground(ebBg, { 0.05, 0.05, 0.07, 1.0 })
    T:AddBorder(ebBg, T.COLOR.BORDER)

    local eb = CreateFrame("EditBox", nil, ebBg)
    eb:SetPoint("TOPLEFT",     ebBg, "TOPLEFT",     5,  -3)
    eb:SetPoint("BOTTOMRIGHT", ebBg, "BOTTOMRIGHT", -5,  3)
    T:ApplyFont(eb, T:GetFontSize())
    eb:SetTextColor(T.COLOR.TEXT_PRIMARY[1], T.COLOR.TEXT_PRIMARY[2], T.COLOR.TEXT_PRIMARY[3])
    eb:SetAutoFocus(false)
    eb:SetMaxLetters(200)
    dlg._editBox = eb

    -- Buttons (reuse the title-bar pill style)
    local cancelBtn = RA:_MakeTitleIconButton(dlg, "Cancel", function() dlg:Hide() end)
    cancelBtn:SetPoint("BOTTOMRIGHT", dlg, "BOTTOMRIGHT", -10, 10)

    local saveBtn = RA:_MakeTitleIconButton(dlg, "Save", function()
        local key  = dlg._playerKey
        local note = eb:GetText():match("^%s*(.-)%s*$")
        if key and RA.db.players[key] then
            RA.db.players[key].note = (note ~= "" and note or nil)
        end
        dlg:Hide()
        RA:RefreshCurrentView()
    end)
    saveBtn:SetPoint("RIGHT", cancelBtn, "LEFT", -6, 0)

    -- Enter confirms, Escape cancels
    eb:SetScript("OnEnterPressed", function() saveBtn:Click() end)
    eb:SetScript("OnEscapePressed", function() dlg:Hide() end)

    tinsert(UISpecialFrames, "RaidAlliesNoteDialog")
end

-- ─── Public entry points ──────────────────────────────────────────────────────

--- Creates all UI frames on first call; idempotent thereafter.
function RA:InitUI()
    if RA._uiInitialised then return end
    RA._uiInitialised = true
    RA:CreateMainFrame()
end

--- Toggles the main window (called by slash commands).
function RA:ToggleMainWindow()
    RA:InitUI()
    if RA.mainFrame:IsShown() then
        RA:CloseAllFrames()
    else
        RA.mainFrame:Show()
        RA:ShowEncounterList()
    end
end

--- Hides every frame this addon owns.
function RA:CloseAllFrames()
    if RA.mainFrame    and RA.mainFrame:IsShown()    then RA.mainFrame:Hide()    end
    if RA.filterFrame  and RA.filterFrame:IsShown()  then RA.filterFrame:Hide()  end
    if RA.optionsFrame and RA.optionsFrame:IsShown() then RA.optionsFrame:Hide() end
end

--- Refreshes the currently visible view (player list and/or pinned list if allies tab is active).
function RA:RefreshCurrentView()
    if RA.playerListView and RA.playerListView:IsShown() then
        RA:RefreshPlayerList()
    end
    if RA._activeTab == "allies" then
        RA:RefreshPinnedList()
    end
end

-- ─── Main frame creation ──────────────────────────────────────────────────────

function RA:CreateMainFrame()
    local f = CreateFrame("Frame", "RaidAlliesFrame", UIParent)
    f:SetSize(WIN_DEFAULT_W, WIN_DEFAULT_H)
    f:SetPoint("CENTER")
    f:SetMovable(true)
    f:SetResizable(true)
    f:SetResizeBounds(WIN_MIN_W, WIN_MIN_H, WIN_MAX_W, WIN_MAX_H)
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    f:Hide()
    RA.mainFrame = f

    -- Window background
    T:AddBackground(f, T.COLOR.BG_MAIN)
    T:AddBorder(f, T.COLOR.BORDER)

    -- Restore saved position / size before adding children
    RA:RestoreWindowGeometry()

    -- Chrome
    RA:_BuildTitleBar(f)
    RA:_BuildTabBar(f)
    RA:_BuildFooter(f)
    RA:_BuildContentArea(f)
    RA:_BuildResizeHandle(f)

    -- ESC closes the window (UISpecialFrames uses the frame name)
    tinsert(UISpecialFrames, "RaidAlliesFrame")

    -- When the main frame hides (ESC or X click), also hide any open side panels
    f:HookScript("OnHide", function()
        if RA.filterFrame  and RA.filterFrame:IsShown()  then RA.filterFrame:Hide()  end
        if RA.optionsFrame and RA.optionsFrame:IsShown() then RA.optionsFrame:Hide() end
    end)

    -- Reflow content on resize
    f:SetScript("OnSizeChanged", function()
        RA:_OnResized()
    end)

    -- Apply saved opacity immediately
    f:SetAlpha(RA.db.settings.opacity or 1.0)
end

-- ─── Title bar ────────────────────────────────────────────────────────────────

function RA:_BuildTitleBar(parent)
    local bar = CreateFrame("Frame", nil, parent)
    bar:SetPoint("TOPLEFT",  parent, "TOPLEFT",  0, 0)
    bar:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    bar:SetHeight(TITLE_H)
    bar:EnableMouse(true)
    RA.titleBar = bar

    T:AddBackground(bar, T.COLOR.BG_TITLE)

    -- Bottom separator
    local sep = bar:CreateTexture(nil, "BORDER")
    sep:SetColorTexture(T.COLOR.BORDER[1], T.COLOR.BORDER[2], T.COLOR.BORDER[3], 1)
    sep:SetPoint("BOTTOMLEFT",  bar, "BOTTOMLEFT")
    sep:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT")
    sep:SetHeight(1)

    -- Left accent stripe
    local stripe = bar:CreateTexture(nil, "OVERLAY")
    stripe:SetWidth(3)
    stripe:SetPoint("TOPLEFT",    bar, "TOPLEFT")
    stripe:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT")
    stripe:SetColorTexture(
        T.COLOR.BORDER_ACCENT[1], T.COLOR.BORDER_ACCENT[2],
        T.COLOR.BORDER_ACCENT[3], T.COLOR.BORDER_ACCENT[4] or 1
    )

    -- Title text
    local title = bar:CreateFontString(nil, "OVERLAY")
    T:ApplyFont(title, 14)
    title:SetTextColor(T.COLOR.TEXT_PRIMARY[1], T.COLOR.TEXT_PRIMARY[2], T.COLOR.TEXT_PRIMARY[3])
    title:SetPoint("LEFT", bar, "LEFT", 12, 0)
    title:SetText("RaidAllies")
    RA.titleText = title

    -- Right-to-left: [X close] [Options ⚙] [Filters ≡]
    local closeBtn = RA:_MakeCloseButton(bar)
    closeBtn:SetPoint("RIGHT", bar, "RIGHT", -6, 0)

    local optBtn = RA:_MakeTitleIconButton(bar, "Options", function()
        RA:ToggleOptionsFrame()
    end)
    optBtn:SetPoint("RIGHT", closeBtn, "LEFT", -4, 0)
    RA.optionsBtn = optBtn

    local filterBtn = RA:_MakeTitleIconButton(bar, "Filters", function()
        RA:ToggleFilterFrame()
    end)
    filterBtn:SetPoint("RIGHT", optBtn, "LEFT", -4, 0)
    RA.filterBtn = filterBtn

    -- Drag the window via the title bar
    bar:SetScript("OnMouseDown", function(_, btn)
        if btn == "LeftButton" then parent:StartMoving() end
    end)
    bar:SetScript("OnMouseUp", function()
        parent:StopMovingOrSizing()
        RA:SaveWindowGeometry()
    end)
end

--- Creates the X close button using a reliably-visible styled text approach.
--- (Atlas-based buttons silently fail to render on some client configurations.)
function RA:_MakeCloseButton(parent)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(22, 22)
    -- Ensure button appears above other UI elements
    btn:SetFrameLevel(parent:GetFrameLevel() + 10)

    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0)

    local lbl = btn:CreateFontString(nil, "OVERLAY")
    T:ApplySymbolFont(lbl, 14)
    lbl:SetAllPoints()
    lbl:SetJustifyH("CENTER")
    lbl:SetText("X")
    lbl:SetTextColor(T.COLOR.TEXT_SECONDARY[1], T.COLOR.TEXT_SECONDARY[2], T.COLOR.TEXT_SECONDARY[3])

    btn:SetScript("OnEnter", function()
        lbl:SetTextColor(1, 0.85, 0.85)
        bg:SetColorTexture(0.65, 0.08, 0.08, 0.55)
    end)
    btn:SetScript("OnLeave", function()
        lbl:SetTextColor(T.COLOR.TEXT_SECONDARY[1], T.COLOR.TEXT_SECONDARY[2], T.COLOR.TEXT_SECONDARY[3])
        bg:SetColorTexture(0, 0, 0, 0)
    end)

    btn:SetScript("OnClick", function() RA:CloseAllFrames() end)
    return btn
end

--- Creates a small labelled icon button for the title bar (Filters / Options).
--- @param parent  Frame
--- @param label   string  short text label
--- @param onClick function
--- @return Button
function RA:_MakeTitleIconButton(parent, label, onClick)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetHeight(22)

    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0)

    -- Rounded pill border
    T:AddBorder(btn, { T.COLOR.BORDER[1], T.COLOR.BORDER[2], T.COLOR.BORDER[3], 0.60 })

    local lbl = btn:CreateFontString(nil, "OVERLAY")
    T:ApplyFont(lbl, 10)
    lbl:SetTextColor(T.COLOR.TEXT_SECONDARY[1], T.COLOR.TEXT_SECONDARY[2], T.COLOR.TEXT_SECONDARY[3])
    lbl:SetPoint("LEFT",  btn, "LEFT",  5, 0)
    lbl:SetPoint("RIGHT", btn, "RIGHT", -5, 0)
    lbl:SetJustifyH("CENTER")
    lbl:SetText(label)
    btn:SetWidth(lbl:GetStringWidth() + 14)

    btn:SetScript("OnEnter", function()
        bg:SetColorTexture(T.COLOR.BORDER_ACCENT[1], T.COLOR.BORDER_ACCENT[2], T.COLOR.BORDER_ACCENT[3], 0.20)
        lbl:SetTextColor(T.COLOR.TEXT_ACCENT[1], T.COLOR.TEXT_ACCENT[2], T.COLOR.TEXT_ACCENT[3])
    end)
    btn:SetScript("OnLeave", function()
        bg:SetColorTexture(0, 0, 0, 0)
        lbl:SetTextColor(T.COLOR.TEXT_SECONDARY[1], T.COLOR.TEXT_SECONDARY[2], T.COLOR.TEXT_SECONDARY[3])
    end)
    btn:SetScript("OnClick", onClick)

    return btn
end

-- ─── Footer ───────────────────────────────────────────────────────────────────

function RA:_BuildFooter(parent)
    local foot = CreateFrame("Frame", nil, parent)
    foot:SetPoint("BOTTOMLEFT",  parent, "BOTTOMLEFT",  0, 0)
    foot:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    foot:SetHeight(FOOTER_H)
    RA.footer = foot

    T:AddBackground(foot, T.COLOR.BG_FOOTER)

    -- Top separator
    local sep = foot:CreateTexture(nil, "BORDER")
    sep:SetColorTexture(T.COLOR.BORDER[1], T.COLOR.BORDER[2], T.COLOR.BORDER[3], 1)
    sep:SetPoint("TOPLEFT",  foot, "TOPLEFT")
    sep:SetPoint("TOPRIGHT", foot, "TOPRIGHT")
    sep:SetHeight(1)

    -- "Support me" link-style button (heart via Arial Narrow)
    local support = CreateFrame("Button", nil, foot)
    support:SetHeight(20)

    local supLbl = support:CreateFontString(nil, "OVERLAY")
    T:ApplySymbolFont(supLbl, 11)
    supLbl:SetPoint("LEFT",  support, "LEFT",  2, 0)
    supLbl:SetPoint("RIGHT", support, "RIGHT", -2, 0)
    supLbl:SetJustifyH("LEFT")
    supLbl:SetText("Support me \226\153\165")   -- UTF-8 for ♥
    support:SetWidth(supLbl:GetStringWidth() + 10)

    local function ColourSupport(hover)
        if hover then
            supLbl:SetTextColor(T.COLOR.TEXT_ACCENT[1], T.COLOR.TEXT_ACCENT[2], T.COLOR.TEXT_ACCENT[3])
        else
            supLbl:SetTextColor(T.COLOR.TEXT_SECONDARY[1], T.COLOR.TEXT_SECONDARY[2], T.COLOR.TEXT_SECONDARY[3])
        end
    end
    ColourSupport(false)

    support:SetScript("OnEnter", function() ColourSupport(true)  end)
    support:SetScript("OnLeave", function() ColourSupport(false) end)
    support:SetScript("OnClick", function() StaticPopup_Show("RAIDALLIES_SUPPORT") end)
    support:SetPoint("LEFT", foot, "LEFT", 8, 0)

    -- Credit text
    local credit = foot:CreateFontString(nil, "OVERLAY")
    T:ApplyFont(credit, 10)
    credit:SetTextColor(T.COLOR.TEXT_MUTED[1], T.COLOR.TEXT_MUTED[2], T.COLOR.TEXT_MUTED[3])
    credit:SetPoint("RIGHT", foot, "RIGHT", -22, 0)
    credit:SetText("Created by nosebug")
end

--- Creates a lightweight link-style text button (no border/bg, hover colour).
--- @param parent  Frame
--- @param text    string
--- @param onClick function
--- @return Button
function RA:_MakeTextButton(parent, text, onClick)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetHeight(20)

    local lbl = btn:CreateFontString(nil, "OVERLAY")
    T:ApplyFont(lbl, 11)
    lbl:SetPoint("LEFT",  btn, "LEFT",  2, 0)
    lbl:SetPoint("RIGHT", btn, "RIGHT", -2, 0)
    lbl:SetJustifyH("LEFT")
    lbl:SetText(text)
    btn:SetWidth(lbl:GetStringWidth() + 8)

    local function Colour(hover)
        if hover then
            lbl:SetTextColor(T.COLOR.TEXT_ACCENT[1], T.COLOR.TEXT_ACCENT[2], T.COLOR.TEXT_ACCENT[3])
        else
            lbl:SetTextColor(T.COLOR.TEXT_SECONDARY[1], T.COLOR.TEXT_SECONDARY[2], T.COLOR.TEXT_SECONDARY[3])
        end
    end
    Colour(false)

    btn:SetScript("OnEnter", function() Colour(true)  end)
    btn:SetScript("OnLeave", function() Colour(false) end)
    btn:SetScript("OnClick", onClick)
    return btn
end

-- ─── Tab bar ──────────────────────────────────────────────────────────────────

function RA:_BuildTabBar(parent)
    local bar = CreateFrame("Frame", nil, parent)
    bar:SetPoint("TOPLEFT",  parent, "TOPLEFT",  0, -TITLE_H)
    bar:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, -TITLE_H)
    bar:SetHeight(TAB_H)
    RA._tabBar = bar

    T:AddBackground(bar, T.COLOR.BG_TITLE)

    -- Bottom separator
    local sep = bar:CreateTexture(nil, "BORDER")
    sep:SetColorTexture(T.COLOR.BORDER[1], T.COLOR.BORDER[2], T.COLOR.BORDER[3], 1)
    sep:SetPoint("BOTTOMLEFT",  bar, "BOTTOMLEFT")
    sep:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT")
    sep:SetHeight(1)

    -- Helper to build a tab button
    local function MakeTab(label, anchorTo, anchorPoint, xOff)
        local tab = CreateFrame("Button", nil, bar)
        tab:SetHeight(TAB_H)

        local lbl = tab:CreateFontString(nil, "OVERLAY")
        T:ApplyFont(lbl, 11)
        lbl:SetPoint("CENTER", tab, "CENTER", 0, 1)
        lbl:SetText(label)
        tab:SetWidth(lbl:GetStringWidth() + 20)
        tab._label = lbl

        -- Active underline accent (2px, bottom of tab)
        local underline = tab:CreateTexture(nil, "OVERLAY")
        underline:SetHeight(2)
        underline:SetPoint("BOTTOMLEFT",  tab, "BOTTOMLEFT",  4, 0)
        underline:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -4, 0)
        underline:SetColorTexture(
            T.COLOR.BORDER_ACCENT[1], T.COLOR.BORDER_ACCENT[2],
            T.COLOR.BORDER_ACCENT[3], T.COLOR.BORDER_ACCENT[4] or 1)
        underline:Hide()
        tab._underline = underline

        -- Hover effect
        tab:SetScript("OnEnter", function()
            if not tab._active then
                lbl:SetTextColor(T.COLOR.TEXT_ACCENT[1], T.COLOR.TEXT_ACCENT[2], T.COLOR.TEXT_ACCENT[3])
            end
        end)
        tab:SetScript("OnLeave", function()
            if not tab._active then
                lbl:SetTextColor(T.COLOR.TEXT_SECONDARY[1], T.COLOR.TEXT_SECONDARY[2], T.COLOR.TEXT_SECONDARY[3])
            end
        end)

        tab:SetPoint(anchorPoint, anchorTo, anchorPoint == "LEFT" and "LEFT" or "RIGHT", xOff, 0)
        return tab
    end

    local raidsTab  = MakeTab("Raids",  bar, "LEFT", 8)
    local alliesTab = MakeTab("Allies", bar, "RIGHT", 2)

    raidsTab:SetScript("OnClick",  function() RA:ActivateRaidsTab()  end)
    alliesTab:SetScript("OnClick", function() RA:ActivateAlliesTab() end)

    RA._tabRaids  = raidsTab
    RA._tabAllies = alliesTab
end

--- Updates the visual state of a tab button.
function RA:_SetTabActive(tab, active)
    tab._active = active
    tab._underline:SetShown(active)
    if active then
        tab._label:SetTextColor(T.COLOR.TEXT_PRIMARY[1], T.COLOR.TEXT_PRIMARY[2], T.COLOR.TEXT_PRIMARY[3])
    else
        tab._label:SetTextColor(T.COLOR.TEXT_SECONDARY[1], T.COLOR.TEXT_SECONDARY[2], T.COLOR.TEXT_SECONDARY[3])
    end
end

--- Activates the "Raids" tab — full-width raid browser.
function RA:ActivateRaidsTab()
    RA._activeTab = "raids"
    -- Content area fills the full width (pinned panel hidden)
    RA.contentArea:ClearAllPoints()
    RA.contentArea:SetPoint("TOPLEFT",     RA.mainFrame, "TOPLEFT",     CONTENT_PAD, -(TITLE_H + TAB_H + CONTENT_PAD))
    RA.contentArea:SetPoint("BOTTOMRIGHT", RA.mainFrame, "BOTTOMRIGHT", -CONTENT_PAD, (FOOTER_H + CONTENT_PAD))
    RA.raidsPanel:ClearAllPoints()
    RA.raidsPanel:SetAllPoints(RA.contentArea)
    RA.pinnedPanel:Hide()
    RA._splitDivider:Hide()
    RA:_SetTabActive(RA._tabRaids,  true)
    RA:_SetTabActive(RA._tabAllies, false)
    -- Defer PlayerList refresh until anchors are processed
    C_Timer.After(0, function()
        if RA.playerListView and RA.playerListView:IsShown() then
            RA:RefreshPlayerList()
        end
    end)
end

--- Activates the "Allies" tab — split view with pinned list on the right.
--- Toggles: if already showing allies, collapses back to full-width raids.
function RA:ActivateAlliesTab()
    if RA._activeTab == "allies" then
        RA:ActivateRaidsTab()
        return
    end
    RA._activeTab = "allies"
    RA.pinnedPanel:Show()
    RA._splitDivider:Show()
    -- Shrink content area to make room for pinned panel on the right
    RA.contentArea:ClearAllPoints()
    RA.contentArea:SetPoint("TOPLEFT",     RA.mainFrame, "TOPLEFT",     CONTENT_PAD, -(TITLE_H + TAB_H + CONTENT_PAD))
    RA.contentArea:SetPoint("BOTTOMRIGHT", RA.pinnedPanel, "BOTTOMLEFT", -1, 0)
    RA.raidsPanel:ClearAllPoints()
    RA.raidsPanel:SetAllPoints(RA.contentArea)
    RA:_SetTabActive(RA._tabRaids,  false)
    RA:_SetTabActive(RA._tabAllies, true)
    RA:RefreshPinnedList()
    -- Defer PlayerList refresh until anchors are processed
    C_Timer.After(0, function()
        if RA.playerListView and RA.playerListView:IsShown() then
            RA:RefreshPlayerList()
        end
    end)
end

-- ─── Content area ─────────────────────────────────────────────────────────────

function RA:_BuildContentArea(parent)
    local area = CreateFrame("Frame", nil, parent)
    area:SetPoint("TOPLEFT",     parent, "TOPLEFT",     CONTENT_PAD,  -(TITLE_H + TAB_H + CONTENT_PAD))
    area:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -CONTENT_PAD,  (FOOTER_H + CONTENT_PAD))
    RA.contentArea = area

    -- Raids panel (left / full-width depending on active tab)
    local rp = CreateFrame("Frame", nil, area)
    rp:SetAllPoints(area)
    RA.raidsPanel = rp

    -- Pinned panel (right side of main frame, hidden by default)
    -- Parented to the main frame so it spans from title bar to footer.
    local pp = CreateFrame("Frame", nil, parent)
    pp:SetPoint("TOPRIGHT",    parent, "TOPRIGHT",    -CONTENT_PAD, -(TITLE_H + TAB_H + CONTENT_PAD))
    pp:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -CONTENT_PAD,  (FOOTER_H + CONTENT_PAD))
    pp:SetWidth(SPLIT_W)
    pp:Hide()
    RA.pinnedPanel = pp

    -- Vertical divider between panels (hidden by default)
    local div = parent:CreateTexture(nil, "ARTWORK")
    div:SetColorTexture(T.COLOR.BORDER[1], T.COLOR.BORDER[2], T.COLOR.BORDER[3], T.COLOR.BORDER[4] or 1)
    div:SetWidth(1)
    div:SetPoint("TOP",    pp, "TOPLEFT",    0, 0)
    div:SetPoint("BOTTOM", pp, "BOTTOMLEFT", 0, 0)
    div:Hide()
    RA._splitDivider = div

    -- Create list views — parented to raidsPanel
    RA:CreateEncounterListView(rp)
    RA:CreateBossListView(rp)
    RA:CreatePlayerListView(rp)
    RA:CreatePinnedListPanel(pp)

    -- Start on the Raids tab
    RA:ActivateRaidsTab()
    RA:ShowEncounterList()
end

-- ─── Resize handle ────────────────────────────────────────────────────────────

function RA:_BuildResizeHandle(parent)
    local handle = CreateFrame("Frame", nil, parent)
    handle:SetSize(18, 18)
    handle:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    handle:EnableMouse(true)
    handle:SetFrameLevel(parent:GetFrameLevel() + 10)

    -- Subtle grip dot
    local grip = handle:CreateTexture(nil, "OVERLAY")
    grip:SetSize(10, 10)
    grip:SetPoint("BOTTOMRIGHT", handle, "BOTTOMRIGHT", -2, 2)
    grip:SetColorTexture(T.COLOR.BORDER[1], T.COLOR.BORDER[2], T.COLOR.BORDER[3], 0.60)

    handle:SetScript("OnMouseDown", function(_, btn)
        if btn == "LeftButton" then parent:StartSizing("BOTTOMRIGHT") end
    end)
    handle:SetScript("OnMouseUp", function()
        parent:StopMovingOrSizing()
        RA:SaveWindowGeometry()
        -- _OnResized will fire via the debounce timer, no need to call explicitly
    end)
    handle:SetScript("OnEnter", function() SetCursor("Interface\\Cursor\\ui-cursor-sizeright") end)
    handle:SetScript("OnLeave", function() SetCursor(nil) end)
end

function RA:_OnResized()
    -- Cancel any previously scheduled refresh
    if RA._resizeTimer then
        RA._resizeTimer:Cancel()
        RA._resizeTimer = nil
    end

    -- Throttled live pass: reposition cards at most ~20 times/sec during drag.
    -- Avoids per-frame layout work (table alloc + N SetPoint calls) at 60+ fps.
    if RA.playerListView and RA.playerListView:IsShown() then
        local now = GetTime()
        if not RA._lastLayoutTime or (now - RA._lastLayoutTime) >= 0.05 then
            RA._lastLayoutTime = now
            RA:_LayoutPlayerCards()
        end
    end

    -- Debounced full refresh: fires 0.1s after the last resize event
    RA._resizeTimer = C_Timer.NewTimer(0.1, function()
        RA._resizeTimer    = nil
        RA._lastLayoutTime = nil
        if RA.encounterListView and RA.encounterListView:IsShown() then
            RA:RefreshEncounterList()
        elseif RA.bossListView and RA.bossListView:IsShown() then
            RA:RefreshBossList()
        elseif RA.playerListView and RA.playerListView:IsShown() then
            RA:RefreshPlayerList()
        end
        if RA._activeTab == "allies" then
            RA:RefreshPinnedList()
        end
    end)
end

-- ─── View switching ───────────────────────────────────────────────────────────

--- Shows the session list (top-level view).
function RA:ShowEncounterList()
    if RA.bossListView   then RA.bossListView:Hide()   end
    if RA.playerListView then RA.playerListView:Hide() end
    if RA.encounterListView then
        RA.encounterListView:Show()
        RA:RefreshEncounterList()
    end
end

--- Shows the boss list for a specific session.
--- @param sessionKey  string
--- @param sessionData table
function RA:ShowBossList(sessionKey, sessionData)
    RA._currentSessionKey  = sessionKey
    RA._currentSessionData = sessionData
    if RA.encounterListView then RA.encounterListView:Hide() end
    if RA.playerListView    then RA.playerListView:Hide()   end
    if RA.bossListView then
        RA.bossListView:Show()
        RA:RefreshBossList()
    end
end

--- Shows the player list for a specific boss within a session.
--- @param sessionKey   string
--- @param encounterID  number
--- @param bossData     table
function RA:ShowPlayerList(sessionKey, encounterID, bossData)
    RA._currentSessionKey  = sessionKey
    RA._currentEncounterID = encounterID
    RA._currentBossData    = bossData
    if RA.encounterListView then RA.encounterListView:Hide() end
    if RA.bossListView      then RA.bossListView:Hide()     end
    if RA.playerListView then
        RA.playerListView:Show()
        RA:RefreshPlayerList()
    end
end

-- ─── Filter / Options panel toggles ─────────────────────────────────────────

function RA:ToggleFilterFrame()
    RA:InitUI()
    -- Lazily create on first use
    if not RA.filterFrame then
        RA:CreateFilterFrame()
    end
    if RA.filterFrame:IsShown() then
        RA.filterFrame:Hide()
    else
        if RA.optionsFrame and RA.optionsFrame:IsShown() then
            RA.optionsFrame:Hide()
        end
        RA.filterFrame:Show()
        RA:RefreshFilterFrame()
    end
end

function RA:ToggleOptionsFrame()
    RA:InitUI()
    if not RA.optionsFrame then
        RA:CreateOptionsFrame()
    end
    if RA.optionsFrame:IsShown() then
        RA.optionsFrame:Hide()
    else
        if RA.filterFrame and RA.filterFrame:IsShown() then
            RA.filterFrame:Hide()
        end
        RA.optionsFrame:Show()
    end
end

-- ─── Settings live-apply ──────────────────────────────────────────────────────

--- Applies the current opacity setting to all addon frames.
function RA:ApplyOpacity()
    local a = RA.db.settings.opacity or 1.0
    local frames = { RA.mainFrame, RA.filterFrame, RA.optionsFrame }
    for _, f in ipairs(frames) do
        if f then f:SetAlpha(a) end
    end
end

--- Rebuilds row pools and refreshes the current view at the new font size.
--- Existing pool rows are explicitly hidden before the pool is cleared so that
--- orphaned row frames (which remain parented to the content child) don't
--- overlap the freshly-created rows at the new size.
function RA:ApplyFontSize()
    -- Hide and clear existing row pools to avoid overlapping rows with old fonts
    for _, row  in ipairs(RA._encRowPool    or {}) do row:Hide()  end
    for _, row  in ipairs(RA._bossRowPool   or {}) do row:Hide()  end
    for _, row  in ipairs(RA._plRowPool     or {}) do row:Hide()  end
    for _, card in ipairs(RA._plCardPool    or {}) do card:Hide() end
    for _, row  in ipairs(RA._pinnedRowPool or {}) do row:Hide()  end
    RA._encRowPool    = {}
    RA._bossRowPool   = {}
    RA._plRowPool     = {}
    RA._plCardPool    = {}
    RA._pinnedRowPool = {}

    -- Update fonts on static UI elements (title, footer, filter/options button labels)
    if RA.titleText then T:ApplyFont(RA.titleText, 14) end
    if RA.footer then
        -- credit and support texts are children of footer; update them if needed
        for _, child in ipairs({RA.footer:GetChildren()}) do
            if child.SetFont then T:ApplyFont(child) end
        end
    end
    if RA.filterBtn and RA.filterBtn._lbl then T:ApplyFont(RA.filterBtn._lbl, 10) end
    if RA.optionsBtn and RA.optionsBtn._lbl then T:ApplyFont(RA.optionsBtn._lbl, 10) end

    -- Refresh whichever view is active
    if RA.encounterListView and RA.encounterListView:IsShown() then
        RA:RefreshEncounterList()
    elseif RA.bossListView and RA.bossListView:IsShown() then
        RA:RefreshBossList()
    elseif RA.playerListView and RA.playerListView:IsShown() then
        RA:RefreshPlayerList()
    end
    if RA._activeTab == "allies" then
        RA:RefreshPinnedList()
    end
end

-- ─── Geometry persistence ─────────────────────────────────────────────────────

function RA:SaveWindowGeometry()
    local f = RA.mainFrame
    if not f then return end
    local s = RA.db.settings
    s.windowX = f:GetLeft()
    s.windowY = f:GetTop() - UIParent:GetHeight()
    s.windowW = f:GetWidth()
    s.windowH = f:GetHeight()
end

function RA:RestoreWindowGeometry()
    local f = RA.mainFrame
    local s = RA.db.settings
    if s.windowW and s.windowH then
        f:SetSize(
            math.max(WIN_MIN_W, math.min(WIN_MAX_W, s.windowW)),
            math.max(WIN_MIN_H, math.min(WIN_MAX_H, s.windowH))
        )
    end
    if s.windowX and s.windowY then
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", s.windowX, s.windowY + UIParent:GetHeight())
    end
end

-- ─── Shared scroll area constructor ──────────────────────────────────────────
-- Used by EncounterList, BossList, and PlayerList views.

--- Creates a ScrollFrame + content child + custom slim scrollbar.
--- @param parent     Frame
--- @param rowHeight  number
--- @return ScrollFrame, Frame
function RA:CreateScrollArea(parent, rowHeight)
    rowHeight = rowHeight or 32

    local track  ---@type Frame
    local thumb  ---@type Texture

    local function UpdateScrollbar(sf)
        local range  = sf:GetVerticalScrollRange()
        local cur    = sf:GetVerticalScroll()
        local trackH = track:GetHeight()

        if range <= 0 or trackH <= 0 then
            track:Hide()
            return
        end
        track:Show()
        local viewH  = sf:GetHeight()
        local totalH = viewH + range
        local tH     = math.max(20, (viewH / totalH) * trackH)
        local tY     = -(cur / range) * (trackH - tH)
        thumb:SetHeight(tH)
        thumb:SetPoint("TOP", track, "TOP", 0, tY)
    end

    -- Scroll frame (leaves 7 px on right for the scrollbar)
    local scroll = CreateFrame("ScrollFrame", nil, parent)
    scroll:SetPoint("TOPLEFT",     parent, "TOPLEFT",     0,  0)
    scroll:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -7, 0)

    -- Content child
    local content = CreateFrame("Frame", nil, scroll)
    content:SetHeight(1)
    scroll:SetScrollChild(content)
    content:SetWidth(math.max(1, scroll:GetWidth()))

    scroll:SetScript("OnSizeChanged", function(sf)
        content:SetWidth(math.max(1, sf:GetWidth()))
        UpdateScrollbar(sf)
    end)

    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(sf, delta)
        local cur = sf:GetVerticalScroll()
        local rng = sf:GetVerticalScrollRange()
        sf:SetVerticalScroll(math.max(0, math.min(rng, cur - delta * rowHeight * 1.5)))
    end)

    scroll:SetScript("OnVerticalScroll", function(sf)
        UpdateScrollbar(sf)
    end)

    -- Scrollbar track (5 px wide, on the right of parent)
    track = CreateFrame("Frame", nil, parent)
    track:SetWidth(5)
    track:SetPoint("TOPRIGHT",    parent, "TOPRIGHT",    0, 0)
    track:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    T:AddBackground(track, T.COLOR.SCROLLBAR_TRACK)

    -- Scrollbar thumb
    thumb = track:CreateTexture(nil, "OVERLAY")
    thumb:SetColorTexture(
        T.COLOR.SCROLLBAR_THUMB[1], T.COLOR.SCROLLBAR_THUMB[2],
        T.COLOR.SCROLLBAR_THUMB[3], T.COLOR.SCROLLBAR_THUMB[4] or 0.9
    )
    thumb:SetWidth(5)
    thumb:SetPoint("TOP", track, "TOP")
    thumb:SetHeight(20)

    return scroll, content
end

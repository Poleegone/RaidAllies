-- RaidAllies: Theme
-- Visual constants (colours, fonts, sizes) and stateless helper functions
-- for constructing textures, borders, and icons.
-- No frame creation or game-state logic lives here.

local _, RA = ...

RA.Theme = {}
local T = RA.Theme

-------------------------------------------------------------------------------
-- Colour palette
-- All entries are { r, g, b } or { r, g, b, a } in the 0–1 range.
-------------------------------------------------------------------------------

T.COLOR = {
    -- Window chrome
    BG_MAIN     = { 0.07, 0.07, 0.09, 1.00 },
    BG_TITLE    = { 0.10, 0.10, 0.13, 1.00 },
    BG_FOOTER   = { 0.08, 0.08, 0.10, 1.00 },

    -- List rows
    BG_ROW_ALT   = { 0.11, 0.11, 0.15, 0.80 },
    BG_ROW_HOVER = { 0.18, 0.20, 0.28, 0.80 },

    -- Player card gradients (subtle)
    CARD_BG_TOP      = { 0.13, 0.14, 0.18, 0.95 },
    CARD_BG_BOTTOM   = { 0.11, 0.12, 0.15, 0.95 },
    CARD_HOVER_TOP   = { 0.16, 0.17, 0.22, 1.00 },
    CARD_HOVER_BOTTOM = { 0.13, 0.14, 0.18, 1.00 },
    CARD_SHADOW      = { 0.00, 0.00, 0.00, 0.40 },

    -- Borders / separators
    BORDER        = { 0.20, 0.20, 0.26, 1.00 },
    BORDER_ACCENT = { 0.27, 0.55, 0.90, 1.00 },  -- title stripe

    -- Text
    TEXT_PRIMARY   = { 0.90, 0.90, 0.92 },
    TEXT_SECONDARY = { 0.55, 0.57, 0.63 },
    TEXT_MUTED     = { 0.36, 0.37, 0.42 },
    TEXT_ACCENT    = { 0.38, 0.72, 1.00 },  -- blue accent

    -- Scrollbar
    SCROLLBAR_TRACK = { 0.09, 0.09, 0.12, 0.80 },
    SCROLLBAR_THUMB = { 0.28, 0.30, 0.40, 0.90 },

    -- Achievement backgrounds  (kept subtle so text stays readable)
    AOTC_BG = { 0.72, 0.55, 0.00, 0.20 },   -- muted gold
    CE_BG   = { 0.72, 0.08, 0.08, 0.24 },   -- muted red

    -- Difficulty
    ["DIFF_LFR"]    = { 0.13, 0.73, 0.20 },
    ["DIFF_NORMAL"] = { 0.20, 0.48, 0.90 },
    ["DIFF_HEROIC"] = { 0.64, 0.21, 0.93 },
    ["DIFF_MYTHIC"] = { 1.00, 0.50, 0.00 },

    -- Badge / pill
    BADGE_BG     = { 0.12, 0.13, 0.18, 0.95 },
    BADGE_BORDER = { 0.25, 0.27, 0.35, 0.80 },

    -- Full clear badge
    FULL_CLEAR_BG   = { 0.10, 0.45, 0.20, 0.70 },
    FULL_CLEAR_TEXT = { 0.50, 1.00, 0.55 },
}

-------------------------------------------------------------------------------
-- Font registry
-------------------------------------------------------------------------------

-- Map from user-visible name → font file path (relative to WoW root)
T.FONT_MAP = {
    ["Friz Quadrata TT"] = "Fonts\\FRIZQT__.TTF",
    ["Arial Narrow"]     = "Fonts\\ARIALN.TTF",
    ["Morpheus"]         = "Fonts\\MORPHEUS.TTF",
    ["Skurri"]           = "Fonts\\SKURRI.TTF",
}

-- Ordered list for the options dropdown
T.FONT_NAMES = { "Friz Quadrata TT", "Arial Narrow", "Morpheus", "Skurri" }

--- Returns the font file path for the currently-selected font in settings.
--- @return string
function T:GetFontPath()
    local name = RA.db and RA.db.settings.fontName or "Friz Quadrata TT"
    return T.FONT_MAP[name] or "Fonts\\FRIZQT__.TTF"
end

--- Returns the current font size from settings, clamped to valid range.
--- @return number
function T:GetFontSize()
    local sz = RA.db and RA.db.settings.fontSize or 13
    return math.max(10, math.min(18, sz))
end

--- Applies the current addon font + size to a FontString.
--- @param fs    FontString
--- @param size  number|nil   override font size; nil uses settings value
--- @param flags string|nil   e.g. "OUTLINE"
function T:ApplyFont(fs, size, flags)
    fs:SetFont(T:GetFontPath(), size or T:GetFontSize(), flags or "")
end

--- Applies Arial Narrow font — used for UI symbol characters (guaranteed glyph coverage).
--- @param fs    FontString
--- @param size  number|nil
--- @param flags string|nil
function T:ApplySymbolFont(fs, size, flags)
    fs:SetFont("Fonts\\ARIALN.TTF", size or T:GetFontSize(), flags or "")
end

-------------------------------------------------------------------------------
-- Difficulty helpers
-------------------------------------------------------------------------------

--- Returns { r, g, b } for a difficulty ID.
--- @param difficultyID number
--- @return table
function T:DiffColor(difficultyID)
    local cat = RA:GetDifficultyCategory(difficultyID)
    return T.COLOR["DIFF_" .. cat] or T.COLOR.DIFF_NORMAL
end

-------------------------------------------------------------------------------
-- Class colour
-------------------------------------------------------------------------------

--- Returns r, g, b for a class token (e.g. "WARRIOR").
--- Falls back to near-white for unknown tokens.
--- @param classToken string
--- @return number r, number g, number b
function T:ClassColor(classToken)
    if RAID_CLASS_COLORS and classToken and RAID_CLASS_COLORS[classToken] then
        local c = RAID_CLASS_COLORS[classToken]
        return c.r, c.g, c.b
    end
    return 0.80, 0.80, 0.80
end

-------------------------------------------------------------------------------
-- Texture / chrome helpers
-------------------------------------------------------------------------------

--- Adds a solid-colour background texture to a frame.
--- @param frame   Frame
--- @param c       table   { r, g, b [, a] }
--- @param layer   string|nil  defaults to "BACKGROUND"
--- @return Texture
function T:AddBackground(frame, c, layer)
    local tex = frame:CreateTexture(nil, layer or "BACKGROUND")
    tex:SetAllPoints(frame)
    tex:SetColorTexture(c[1], c[2], c[3], c[4] or 1)
    return tex
end

--- Adds 1-px border lines on all four sides of a frame.
--- @param frame Frame
--- @param c     table  { r, g, b [, a] }
function T:AddBorder(frame, c)
    local r, g, b, a = c[1], c[2], c[3], c[4] or 1

    local top = frame:CreateTexture(nil, "BORDER")
    top:SetColorTexture(r, g, b, a)
    top:SetPoint("TOPLEFT",  frame, "TOPLEFT")
    top:SetPoint("TOPRIGHT", frame, "TOPRIGHT")
    top:SetHeight(1)

    local bot = frame:CreateTexture(nil, "BORDER")
    bot:SetColorTexture(r, g, b, a)
    bot:SetPoint("BOTTOMLEFT",  frame, "BOTTOMLEFT")
    bot:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT")
    bot:SetHeight(1)

    local lft = frame:CreateTexture(nil, "BORDER")
    lft:SetColorTexture(r, g, b, a)
    lft:SetPoint("TOPLEFT",    frame, "TOPLEFT")
    lft:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT")
    lft:SetWidth(1)

    local rgt = frame:CreateTexture(nil, "BORDER")
    rgt:SetColorTexture(r, g, b, a)
    rgt:SetPoint("TOPRIGHT",    frame, "TOPRIGHT")
    rgt:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT")
    rgt:SetWidth(1)
end

-------------------------------------------------------------------------------
-- Icon helpers
-- Use Blizzard-provided textures for class and role icons.
-------------------------------------------------------------------------------

--- Sets a class icon on a Texture widget using the official class atlas.
--- Falls back to the individual icon file if the atlas is unavailable.
--- @param tex        Texture
--- @param classToken string  e.g. "WARRIOR"
function T:SetClassIcon(tex, classToken)
    if not classToken then return end

    -- C_Texture.GetClassAtlas is the preferred API for class icon atlases
    if C_Texture and C_Texture.GetClassAtlas then
        local atlas = C_Texture.GetClassAtlas(classToken)
        if atlas then
            tex:SetAtlas(atlas, true)
            return
        end
    end

    -- Fallback: individual icon files shipped with the client
    tex:SetTexture("Interface\\Icons\\ClassIcon_" .. classToken)
    tex:SetTexCoord(0, 1, 0, 1)
end

--- Sets the texture to show a specialization icon by spec ID.
--- @param tex Texture
--- @param specID number|nil  Specialization ID, or nil to clear
function T:SetSpecIcon(tex, specID)
    if not specID then
        tex:SetTexture(nil)
        return
    end

    local _, _, _, icon = GetSpecializationInfoByID(specID)
    if icon then
        tex:SetTexture(icon)
        tex:SetTexCoord(0, 1, 0, 1)
    else
        -- Fallback to blank if spec not found
        tex:SetTexture(nil)
    end
end

-------------------------------------------------------------------------------
-- Role icon — uses named atlases (modern Midnight/retail API).
-- GetIconForRole is a Blizzard global; falls back to hardcoded atlas names.
-------------------------------------------------------------------------------

local ROLE_ATLAS = {
    TANK    = "UI-LFG-RoleIcon-Tank",
    HEALER  = "UI-LFG-RoleIcon-Healer",
    DAMAGER = "UI-LFG-RoleIcon-DPS",
}

--- Sets a role icon on a Texture widget using the modern atlas API.
--- @param tex  Texture
--- @param role string  "TANK" | "HEALER" | "DAMAGER"
function T:SetRoleIcon(tex, role)
    -- Use GetIconForRole if available (future-proof)
    -- Pass false as second arg to SetAtlas so SetSize() controls dimensions
    if GetIconForRole then
        tex:SetAtlas(GetIconForRole(role, false), false)
        return
    end
    -- Fallback to known atlas names
    local atlas = ROLE_ATLAS[role] or ROLE_ATLAS.DAMAGER
    tex:SetAtlas(atlas, false)
end

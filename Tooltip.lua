local addonName, RaidAllies = ...

local HEADER = "|cff66ccffRaidAllies|r"
local LABEL = "|cff888888"
local VALUE = "|cffffffff"

local trustColors = {
    Trusted = "|cff00ff88",
    Neutral = "|cffe6c870",
    Avoid   = "|cffff4040",
    Unknown = "|cffaaaaaa",
}

local function AddPlayerInfo(tooltip, unit)
    if not unit or not UnitExists(unit) or not UnitIsPlayer(unit) then return end

    local fullName = RaidAllies:GetUnitFullName(unit)
    if not fullName then return end

    local rec = RaidAllies.Data and RaidAllies.Data:Get(fullName)
    if not rec then return end

    local level = RaidAllies.Data:TrustLevel(rec)
    if level == "Unknown" and (not rec.note or rec.note == "") and (rec.k or 0) == 0 and (rec.fc or 0) == 0 then
        return
    end

    local trustColor = trustColors[level] or trustColors.Unknown

    tooltip:AddLine(" ")
    tooltip:AddDoubleLine(HEADER, trustColor .. level .. "|r")

    local k = rec.k or 0
    local fc = rec.fc or 0
    if k > 0 or fc > 0 then
        local parts = {}
        if k > 0 then parts[#parts + 1] = k .. " kills" end
        if fc > 0 then parts[#parts + 1] = fc .. " clears" end
        tooltip:AddDoubleLine(LABEL .. "Seen|r", VALUE .. table.concat(parts, ", ") .. "|r")
    end

    if rec.ls and rec.ls > 0 then
        tooltip:AddDoubleLine(LABEL .. "Last Seen|r", VALUE .. RaidAllies:FormatTimeAgo(rec.ls) .. "|r")
    end

    if rec.note and rec.note ~= "" then
        tooltip:AddLine(LABEL .. "Note:|r " .. VALUE .. rec.note .. "|r", 1, 1, 1, true)
    end

    tooltip:Show()
end

local function OnTooltipSetUnit(tooltip, data)
    if tooltip ~= GameTooltip then return end
    local _, unit = tooltip:GetUnit()
    if not unit then return end
    AddPlayerInfo(tooltip, unit)
end

if TooltipDataProcessor and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Unit then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, OnTooltipSetUnit)
else
    GameTooltip:HookScript("OnTooltipSetUnit", function(self)
        local _, unit = self:GetUnit()
        if not unit then return end
        AddPlayerInfo(self, unit)
    end)
end

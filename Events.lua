local addonName, RaidAllies = ...

local frame = CreateFrame("Frame", "RaidAlliesEventFrame")
RaidAllies.EventFrame = frame

frame:RegisterEvent("ENCOUNTER_END")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("CHALLENGE_MODE_START")
frame:RegisterEvent("CHALLENGE_MODE_COMPLETED")

local function OnEncounterEnd(encounterID, encounterName, difficultyID, groupSize, success)
    if success ~= 1 and success ~= true then return end
    local session = RaidAllies.Session
    if not session:IsActive() then
        if not session:ShouldTrackContent() then return end
        session:Start()
    end
    session:RecordBossKill()
    local raidName
    if GetInstanceInfo then
        raidName = GetInstanceInfo()
    end
    session:RecordContext(raidName, difficultyID)
end

local function OnRosterUpdate()
    if not RaidAllies.Session:IsActive() then return end
    if not IsInGroup() and not IsInRaid() then
        RaidAllies.Session:End()
        return
    end
    -- Keep the session player cache warm while the group exists, so a
    -- snapshot taken at completion time is never empty.
    RaidAllies.Session:SyncRosterFromGroup()
end

local function OnChallengeModeStart()
    local mplus = RaidAllies.MythicPlus
    if not (mplus and mplus:IsEnabled()) then return end
    if not mplus:OnChallengeModeStart() then return end

    local session = RaidAllies.Session
    if not session:IsActive() then
        if not session:ShouldTrackContent() then return end
        session:Start()
    end
    session.isMythicPlus = true
    local raidName = mplus:GetDungeonName()
    if (not raidName) and GetInstanceInfo then raidName = GetInstanceInfo() end
    session:RecordContext(raidName, nil)
    session:SyncRosterFromGroup()
end

local function OnChallengeModeCompleted()
    local mplus = RaidAllies.MythicPlus
    if not (mplus and mplus:IsActive()) then return end
    local session = RaidAllies.Session
    if not session:IsActive() then return end

    mplus:OnChallengeModeCompleted()
    local raidName = mplus:GetDungeonName()
    local difficulty = mplus:GetContextString()
    session:CaptureChallengeCompletion(raidName, difficulty)
    mplus:Reset()
    session.isMythicPlus = false
end

local function OnEnteringWorld(isInitialLogin, isReloadingUi)
    RaidAllies.Data:Init()
    if RaidAllies.Snapshots and RaidAllies.Snapshots.Init then
        RaidAllies.Snapshots:Init()
    end

    if RaidAllies.Session:IsActive() then
        local inInstance, instanceType = IsInInstance()
        local mplus = RaidAllies.MythicPlus
        local inTrackedMplus = mplus and mplus:IsActive() and instanceType == "party"
        if not (inInstance and (instanceType == "raid" or inTrackedMplus)) then
            RaidAllies.Session:End()
        end
    end

    -- Show deferred summary after loading screen clears
    if RaidAllies.pendingSummary and C_Timer and C_Timer.After then
        C_Timer.After(1, function()
            local snap = RaidAllies.pendingSummary
            if snap and RaidAllies.UI_Summary and RaidAllies.UI_Summary.Show then
                RaidAllies.UI_Summary:Show(snap)
            end
            RaidAllies.pendingSummary = nil
        end)
    end
end

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ENCOUNTER_END" then
        OnEncounterEnd(...)
    elseif event == "GROUP_ROSTER_UPDATE" then
        OnRosterUpdate()
    elseif event == "PLAYER_ENTERING_WORLD" then
        OnEnteringWorld(...)
    elseif event == "CHALLENGE_MODE_START" then
        OnChallengeModeStart()
    elseif event == "CHALLENGE_MODE_COMPLETED" then
        OnChallengeModeCompleted()
    end
end)

-- Slash commands
SLASH_RAIDALLIES1 = "/ra"
SLASH_RAIDALLIES2 = "/raidallies"
SlashCmdList["RAIDALLIES"] = function(msg)
    msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if msg == "" then
        RaidAllies.UI_Main:Toggle()
    elseif msg == "summary" then
        if RaidAllies.lastSession then
            RaidAllies.UI_Summary:Show(RaidAllies.lastSession)
        else
            RaidAllies:Print("No session data yet.")
        end
    elseif msg == "players" or msg == "invite" then
        RaidAllies.UI_SessionPlayers:Toggle()
    elseif msg == "snapshots" or msg == "snaps" then
        RaidAllies.UI_Snapshots:Toggle()
    elseif msg == "reset" then
        RaidAlliesDB = { players = {}, snapshots = {} }
        RaidAllies.Data:Init()
        if RaidAllies.UI_Main and RaidAllies.UI_Main.Refresh then
            RaidAllies.UI_Main:Refresh()
        end
        RaidAllies:Print("Database reset.")
    elseif msg == "teststart" then
        RaidAllies.Session:TestStart()
        RaidAllies:Print("Test session started with " .. (function()
            local c = 0
            for _ in pairs(RaidAllies.Session.players) do c = c + 1 end
            return c
        end)() .. " players.")
    elseif msg == "testkill" then
        RaidAllies.Session:TestKill()
        RaidAllies:Print("Test boss kill recorded. Bosses: " .. RaidAllies.Session.bosses)
    elseif msg == "testend" then
        if not RaidAllies.Session:IsActive() then
            RaidAllies:Print("No active test session.")
        else
            RaidAllies.Session:End()
            RaidAllies:Print("Test session ended.")
        end
    elseif msg == "cleartest" then
        local n = RaidAllies.Data:ClearTestPlayers()
        if RaidAllies.UI_Main and RaidAllies.UI_Main.Refresh then
            RaidAllies.UI_Main:Refresh()
        end
        RaidAllies:Print("Removed " .. n .. " test player(s).")
    elseif msg == "resetdb" then
        if RaidAllies.Session:IsActive() then
            RaidAllies.Session.active = false
            RaidAllies.Session.startTime = 0
            RaidAllies.Session.players = {}
            RaidAllies.Session.bosses = 0
        end
        RaidAlliesDB = { players = {}, snapshots = {} }
        RaidAllies.Data:Init()
        RaidAllies.lastSession = nil
        if RaidAllies.UI_Main and RaidAllies.UI_Main.Refresh then
            RaidAllies.UI_Main:Refresh()
        end
        RaidAllies:Print("Test data + database reset.")
    elseif msg == "mplus" or msg == "mplus on" or msg == "mplus off" or msg:match("^mplus%s") then
        local mplus = RaidAllies.MythicPlus
        if not mplus then
            RaidAllies:Print("Mythic+ module not loaded.")
        elseif msg == "mplus on" then
            RaidAllies:SetMythicPlusEnabled(true)
            RaidAllies:Print("Mythic+ tracking enabled.")
        elseif msg == "mplus off" then
            RaidAllies:SetMythicPlusEnabled(false)
            RaidAllies:Print("Mythic+ tracking disabled.")
        else
            RaidAllies:Print("Mythic+ tracking: " .. (mplus:IsEnabled() and "on" or "off") .. ". Use /ra mplus on|off")
        end
    else
        RaidAllies:Print("Commands: /ra (toggle) | summary | players | snapshots | mplus [on|off] | reset | cleartest | teststart | testkill | testend | resetdb")
    end
end

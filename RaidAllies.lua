-- RaidAllies: Entry point
-- Bootstraps the addon, registers runtime events, and wires up slash commands.
-- UI is initialised lazily on the first /ra invocation to keep load-time minimal.

local ADDON_NAME, RA = ...

RA.DEBUG = false   -- toggle with /ra debug

-------------------------------------------------------------------------------
-- Bootstrap: fires once when this addon's SavedVariables are available.
-------------------------------------------------------------------------------

local bootstrapFrame = CreateFrame("Frame")
bootstrapFrame:RegisterEvent("ADDON_LOADED")
bootstrapFrame:SetScript("OnEvent", function(self, _, name)
    if name ~= ADDON_NAME then return end
    self:UnregisterEvent("ADDON_LOADED")

    RA:InitDB()
    RA:InitErrorLog()
    RA:InjectSelfIntoHistory()  -- one-shot migration to add current player to historical kills
    RA:RegisterEvents()
    RA:RegisterSlashCommands()
end)

-------------------------------------------------------------------------------
-- Runtime event registration
-- Maps event name → RA method of the same name.
-------------------------------------------------------------------------------

function RA:RegisterEvents()
    local f = CreateFrame("Frame")

    f:RegisterEvent("ENCOUNTER_END")
    f:RegisterEvent("ACHIEVEMENT_EARNED")
    f:RegisterEvent("PLAYER_LOGOUT")

    f:SetScript("OnEvent", function(_, event, ...)
        if RA[event] then
            RA[event](RA, event, ...)
        end
    end)

    RA._eventFrame = f
end

--- Flush transient state on logout so stale flags are never persisted.
function RA:PLAYER_LOGOUT()
    RA._pendingAOTC = false
    RA._pendingCE   = false
end

-------------------------------------------------------------------------------
-- Slash commands: /raidallies and /ra
-------------------------------------------------------------------------------

function RA:RegisterSlashCommands()
    SLASH_RAIDALLIES1 = "/raidallies"
    SLASH_RAIDALLIES2 = "/ra"
    SlashCmdList["RAIDALLIES"] = function(input)
        RA:HandleSlashCommand(input or "")
    end
end

--- Dispatch slash command input.
--- @param input string  everything typed after the command keyword
function RA:HandleSlashCommand(input)
    local cmd = input:match("^%s*(%S*)"):lower()

    if cmd == "debug" then
        RA.DEBUG = not RA.DEBUG
        print("|cff00aeefRaidAllies|r Debug " ..
              (RA.DEBUG and "|cff00ff00ON|r" or "|cffff4444OFF|r"))

    elseif cmd == "reset" then
        if input:lower():find("confirm") then
            RaidAlliesDB = CopyTable(RA.DB_DEFAULTS)
            RA.db        = RaidAlliesDB
            RA.activeFilters = RA.db.settings.filters
            print("|cff00aeefRaidAllies|r All saved data has been wiped.")
        else
            print("|cff00aeefRaidAllies|r Type |cffff4444/ra reset confirm|r to wipe all data.")
        end

    elseif cmd == "prune" then
        local result = RA:PruneDB()
        print(string.format(
            "|cff00aeefRaidAllies|r Pruned |cffff9900%d|r session(s) and |cffff9900%d|r player(s).",
            result.sessions, result.players
        ))

    elseif cmd == "errors" then
        RA:PrintErrorLog()

    elseif cmd == "clearerrors" then
        RA:ClearErrorLog()

    elseif cmd == "help" then
        RA:_PrintHelp()

    else
        -- Default action: toggle the main window
        RA:ToggleMainWindow()
    end
end

    print("|cff458CE6[RaidAllies]|r loaded with v0.9.1 - |cff458CE6/ra|r - |cff458CE6/ra help|r for commands.")

function RA:_PrintHelp()
    local c, r = "|cff00aeef", "|r"
    print(c .. "── RaidAllies ──" .. r)
    print("  " .. c .. "/ra" .. r .. " or " .. c .. "/raidallies" .. r .. "  — toggle window")
    print("  " .. c .. "/ra debug" .. r .. "            — toggle debug output")
    print("  " .. c .. "/ra prune" .. r .. "            — manually prune old DB records")
    print("  " .. c .. "/ra errors" .. r .. "           — show error log")
    print("  " .. c .. "/ra clearerrors" .. r .. "      — clear error log")
    print("  " .. c .. "/ra reset confirm" .. r .. "   — wipe all saved data")
    print("  " .. c .. "/ra help" .. r .. "             — show this message")
end

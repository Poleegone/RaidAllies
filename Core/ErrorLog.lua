-- RaidAllies: ErrorLog
-- Hooks the global Lua error handler to capture and persist addon errors.

local ADDON_NAME, RA = ...

local MAX_ERRORS = 50
local PATH_MARKER = "RaidAllies"   -- filters by addon path in stack trace

function RA:InitErrorLog()
    if not RaidAlliesErrorsDB then
        RaidAlliesErrorsDB = { errors = {} }
    end
    if not RaidAlliesErrorsDB.errors then
        RaidAlliesErrorsDB.errors = {}
    end
    RA.errorLog = RaidAlliesErrorsDB.errors

    -- Hook global error handler: capture RaidAllies errors, pass all errors upstream
    local prev = geterrorhandler()
    seterrorhandler(function(msg, ...)
        if type(msg) == "string" and msg:find(PATH_MARKER, 1, true) then
            local entry = { time = time(), msg = msg }
            local log = RaidAlliesErrorsDB.errors
            table.insert(log, entry)
            -- Cap at MAX_ERRORS (remove oldest)
            while #log > MAX_ERRORS do
                table.remove(log, 1)
            end
        end
        if prev then return prev(msg, ...) end
    end)
end

function RA:PrintErrorLog()
    local log = RaidAlliesErrorsDB and RaidAlliesErrorsDB.errors
    if not log or #log == 0 then
        print("|cff88aaff[RaidAllies]|r No errors logged.")
        return
    end
    print("|cff88aaff[RaidAllies]|r Error log (" .. #log .. " entries):")
    for i, entry in ipairs(log) do
        local t = date("%H:%M:%S", entry.time)
        print(string.format("|cffff6666[%d] %s|r %s", i, t, entry.msg))
    end
end

function RA:ClearErrorLog()
    if RaidAlliesErrorsDB then
        RaidAlliesErrorsDB.errors = {}
        RA.errorLog = RaidAlliesErrorsDB.errors
    end
    print("|cff88aaff[RaidAllies]|r Error log cleared.")
end

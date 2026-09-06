-- Homebody console helpers and consumer sample. Reach it from the CET
-- console as GetMod("HomebodyBridge").
local Homebody = {}
local SYSTEM = "Homebody.HomebodySystem"

local function say(msg) print("[Homebody] " .. msg) end

-- Fetched fresh on every call: a handle held across a save reload goes stale.
local function system()
    local ok, sys = pcall(function()
        return Game.GetScriptableSystemsContainer():Get(SYSTEM)
    end)
    if ok and sys then return sys end
    return nil
end

-- Lists every furniture spot within radius metres of the player in CET's
-- gamelog.log, which flushes late. Default radius 15.
function Homebody.Probe(radius)
    local sys = system()
    if not sys then say("system not available"); return end
    say(sys:ProbeSpots(tonumber(radius) or 15.0))
end

-- Spawns one NPC beside the player and sends it to spot number index from
-- the last Probe listing (the first line is 0) with the engine's own
-- use-workspot command. Default record Character.NurseFemale.
function Homebody.Use(index, record)
    local sys = system()
    if not sys then say("system not available"); return end
    say(sys:ProbeUse(record or "Character.NurseFemale", tonumber(index) or 0))
end

-- Removes every NPC the probe spawned.
function Homebody.Cleanup()
    local sys = system()
    if not sys then say("system not available"); return end
    say(sys:ProbeCleanup())
end

-- Lists the homes the registry loaded from r6/storages/Homebody.
function Homebody.Homes()
    local sys = system()
    if not sys then say("system not available"); return end
    say("
" .. sys:ListHomes())
end

registerForEvent("onInit", function()
    local ok, err = pcall(function() say("bridge loaded") end)
    if not ok then say("onInit failed: " .. tostring(err)) end
end)

return Homebody

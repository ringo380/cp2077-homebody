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

-- Lists every furniture spot within radius metres of the player. Progress
-- prints to this console every few seconds while discovery runs, and the
-- full listing prints when it is done; gamelog.log gets the same lines,
-- minutes later. Default radius 15.
local probe = { running = false, elapsed = 0, last = "" }

function Homebody.Probe(radius)
    local sys = system()
    if not sys then say("system not available"); return end
    say(sys:ProbeSpots(tonumber(radius) or 15.0))
    probe.running = true
    probe.elapsed = 3
    probe.last = ""
end

local function probePoll(dt)
    if not probe.running then return end
    probe.elapsed = probe.elapsed + dt
    if probe.elapsed < 3 then return end
    probe.elapsed = 0
    local sys = system()
    if not sys then probe.running = false; say("system went away"); return end
    local status = tostring(sys:ProbeStatus())
    if status ~= probe.last then say("probe " .. status) end
    probe.last = status
    if status:find("^done") then
        for line in tostring(sys:ProbeListing()):gmatch("[^\n]+") do say(line) end
        probe.running = false
    elseif status:find("^failed") or status:find("^idle") or status:find("^no probe") then
        probe.running = false
    end
end

-- Prints where the last Probe is right now.
function Homebody.ProbeStatus()
    local sys = system()
    if not sys then say("system not available"); return end
    say("probe " .. tostring(sys:ProbeStatus()))
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
    say("\n" .. sys:ListHomes())
end

-- Spawns one NPC beside the player and attaches it to a home from the
-- registry (default "example"), so the roaming loop can be watched
-- without a consumer mod. Cleanup() removes it.
function Homebody.AttachProbe(homeId, record)
    local sys = system()
    if not sys then say("system not available"); return end
    say(sys:AttachProbe(record or "Character.NurseFemale", homeId or "example"))
end

-- Lists every attached NPC with its state and what it is doing.
function Homebody.Status()
    local sys = system()
    if not sys then say("system not available"); return end
    say("\n" .. sys:ListControllers())
end

-- Consumer API. entity is a game object handle (for example an NPC
-- spawned by another mod) or an EntityID; homeId names a
-- r6/storages/Homebody/home.<id>.json file.
local function idOf(entity)
    if type(entity) == "userdata" and entity.GetEntityID then return entity:GetEntityID() end
    return entity
end

function Homebody.Attach(entity, homeId, rulesName)
    local sys = system(); if not sys then return false end
    return sys:Attach(idOf(entity), homeId, rulesName or "")
end
function Homebody.Detach(entity) local sys = system(); if sys then sys:Detach(idOf(entity)) end end
function Homebody.Pause(entity, why) local sys = system(); return sys ~= nil and sys:Pause(idOf(entity), why or "api") end
function Homebody.Resume(entity) local sys = system(); return sys ~= nil and sys:Resume(idOf(entity)) end
function Homebody.IsAttached(entity) local sys = system(); return sys ~= nil and sys:IsAttached(idOf(entity)) end
function Homebody.State(entity) local sys = system(); if not sys then return "Detached" end; return tostring(sys:GetState(idOf(entity))) end
function Homebody.SetRules(entity, rulesName) local sys = system(); return sys ~= nil and sys:SetRules(idOf(entity), rulesName) end
function Homebody.Dump(homeId) local sys = system(); if sys then say(sys:DumpSpots(homeId or "example")) end end
function Homebody.Rule(match, activity) local sys = system(); if sys then sys:AddClassifierRule(match, activity) end end
function Homebody.Rescan(homeId) local sys = system(); return sys ~= nil and sys:Rescan(homeId or "example") end

registerForEvent("onInit", function()
    local ok, err = pcall(function() say("bridge loaded") end)
    if not ok then say("onInit failed: " .. tostring(err)) end
end)

registerForEvent("onUpdate", function(dt)
    local ok, err = pcall(probePoll, dt)
    if not ok then probe.running = false; say("probe poll failed: " .. tostring(err)) end
end)

return Homebody

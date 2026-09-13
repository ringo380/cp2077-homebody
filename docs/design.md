# Homebody design

Homebody is a Cyberpunk 2077 framework mod. It gives a chosen NPC a life
inside one bounded place, typically an apartment: the NPC walks between the
furniture that is actually there, sits, cooks, smokes, watches TV, takes a
call at the window, showers, and so on, for as long as the player is around.
Other mods use it by dropping a JSON file in a folder, or by attaching an NPC
they already spawned.

Status: design approved 2026-09-05; implemented as version 0.1.0 on
2026-09-08. The sections below are the design as approved. What was built
differs in the places listed under "Deviations and findings" at the end,
which is the part to read first when the code and this document disagree.

## Goals

- A modder can give a custom character a home with no code: one JSON file.
- A modder who already spawns NPCs (AMM, entSpawner, their own Codeware
  spawn) can attach one to a home from redscript or from CET Lua.
- The NPC uses the furniture that exists in the game world at that place,
  discovered at runtime, not a list someone had to type in.
- Activity follows a routine: what the NPC prefers changes with the hour.
- The NPC stays inside its home boundary.
- Nothing silent: every path that can fail writes a log line naming the
  home, the entity, and the reason.

## Non-goals for version 1

- Taking over vanilla community NPCs that already run a game routine. The
  rules shape anticipates it (phase names), but attaching to a community
  member is phase 2.
- Conversation, reactions to the player, or any behaviour beyond moving and
  using spots.
- Saving runtime state into the game save.
- A native RED4ext plugin. Everything needed is reachable from redscript on
  Codeware.

## How the engine exposes what we need

These facts were read from the game install on 2026-09-05 (patch 2.31) and
drive every decision below.

- Furniture is world data. Each usable piece of furniture is a
  `worldAISpotNode` inside a streaming sector. The node carries a
  `spot` of type `AIActionSpot` whose `resource` is the workspot animation
  resource, plus `isWorkspotInfinite`, `isWorkspotStatic`, a `markings`
  tag list, and crowd whitelist/blacklist tags. The sector's node setup
  gives the node's transform and its `NodeRef`.
- Street citizens sitting on benches are crowd members whose behaviour
  tree reserves these same nodes (`AISpotUsageToken`,
  `AIbehaviorPrepareReservedCrowdWorkspotNode`).
- A scripted NPC can be sent to one. `AIUseWorkspotCommand` extends
  `AIBaseUseWorkspotCommand` and has `workspotNode: NodeRef`,
  `moveToWorkspot: Bool`, `movementType`, `forceEntryAnimName`,
  `idleOnlyMode`, `jumpToEntry`, `entryId`, `entryTag`,
  `continueInCombat`. It is sent through
  `puppet.GetAIControllerComponent().SendCommand(cmd)`, the same call AMM
  and NightCityPizza use for `AIMoveToCommand`. The vanilla command tree
  (`UseWorkspotCommandHandler`, `UseWorkspotCommandDelegate`) handles
  walking, reservation, entry, and exit. `AIActionHelper` checks
  `aiComponent.IsCommandActive('AIUseWorkspotCommand')`. No installed mod
  issues this command from script, so it is the one unproven link.
- Runtime discovery is possible with Codeware alone.
  `GameInstance.GetWorldStateSystem().GetStreamingWorld()` returns the
  `worldStreamingWorld` resource with `blockRefs`. Each
  `worldStreamingBlock` has `descriptors`, each with a `streamingBox` and
  an async ref to its `worldStreamingSector`. Codeware adds to
  `worldStreamingSector` the natives `GetNodeCount`, `GetNodeSetup(i)`
  (transform, `GetNodeRef`, `GetNode`), and `GetNodeRefs`. Resources load
  through `GameInstance.GetResourceDepot().LoadResource(path)` returning a
  `ResourceToken` with `IsFinished`, `IsLoaded`, `IsFailed`,
  `RegisterCallback`. A node ref only resolves (`ResolveNodeRef`,
  `GlobalNodeRef.IsDefined`) while its sector is streamed in, which holds
  when the player is at the home.
- The proven manual path. AMM and entSpawner spawn an invisible device
  entity that carries a workspot component, set that component's
  `workspotResource`, and call
  `WorkspotGameSystem.PlayInDeviceSimple(device, npc, false, "workspot", ...)`,
  polling `IsActorInWorkspot` and `GetExtendedInfo(npc).exiting`, and
  ending with `SendFastExitSignal` or `StopInDevice`. Movement is
  `AIMoveToCommand` with an `AIPositionSpec`, `movementType` Walk,
  `finishWhenDestinationReached`. Neither device entity is vanilla:
  entSpawner ships `base\spawner\workspot_device.ent` (component
  `workspot`) in its `baseEntity.archive`, and AMM ships
  `base\amm_workspots\entity\workspot_anim.ent` (component
  `amm_workspot_base`) in its props archive, verified against the install's
  archives on 2026-09-05. Homebody therefore treats the manual path as
  optional: the device entity path and component name are settings in
  `config.json`, defaulting to entSpawner's, checked with
  `ResourceDepot.ResourceExists` at load. When the entity is missing the
  manual path is disabled with a log line and only discovered spots are
  used. Shipping a Homebody-owned device archive is a later phase.
- RedFileSystem lists files with `FileSystemStorage.GetFiles()`, which
  returns the files of the storage root. Homes and rules are therefore
  flat files in the storage root, `home.<id>.json` and
  `rules.<name>.json`, not subfolders.
- Spawning. Codeware's `DynamicEntitySystem.CreateEntity(DynamicEntitySpec)`
  with `recordID`, `position`, `orientation`, and `alwaysSpawned`;
  `DeleteEntity(id)` to remove; entity re-fetched by id each tick.
- RedHotTools, when installed, exposes nearby world nodes directly
  (entSpawner's `rhtPlugin.lua` reads `node.nodeInstance:GetNode().spot`).
  It is not installed on the development box and is not a dependency.

## Architecture

Redscript on Codeware. One `ScriptableSystem`, `Homebody.HomebodySystem`,
is the core. A small CET Lua file shows consumers how to reach it through
`Game.GetScriptableSystemsContainer():Get("Homebody.HomebodySystem")`.
Homes and rules are JSON files read through RedFileSystem. Mod Settings
provides a global page and is optional (`@if(ModuleExists(...))`).

Every component is one file with one job and no game handles unless the
job is talking to the game.

### HomeRegistry

Loads every `home.*.json` and `rules.*.json` in the storage root (Codeware `ScriptableService`
`OnLoad`, where storage is granted once per process). Validates each file
field by field. A bad file is logged with its name and the offending field
and skipped; the other homes still load. Holds `Home` records in memory.

### SpotDiscovery

Input: a home boundary. Walks the streaming world: for each block, for
each descriptor whose `streamingBox` intersects the boundary, load the
sector, iterate node setups, keep `worldAISpotNode` entries whose position
lies inside the boundary. Emits `Spot` records: `nodeRef`, `position`,
`yaw`, `workspotPath`, `markings`, `activity` (from the classifier),
`source` = discovered, `available`. Applies the home's `exclude` and
`retag` overrides, then appends the home's `extraSpots` as `source` =
manual. Caches the result per home for the session; a `Rescan` entry point
exists for the authoring dump. Loading is asynchronous: discovery is a
small state machine driven by resource callbacks, and the controller waits
for it.

### ActivityClassifier

Pure function `(markings, workspotPath) -> activity`. Table driven: a list
of rules, each a substring to look for in a marking or in the path and the
activity it maps to. First match wins; no match yields `idle`. Activities
in version 1: `sit`, `lean`, `stand`, `smoke`, `cook`, `drink`, `phone`,
`tv`, `radio`, `dance`, `shower`, `toilet`, `sleep`, `idle`. The table is
a redscript array so a consuming mod can append rules through the API.

### Scheduler

Pure decision logic with no game handles. Input: the spot list, the game
hour, the character's `Rules`, and per-spot `lastUsedAt`. Output: a
`Decision`: use spot S for D seconds, or wander to point P, or idle for D
seconds. Picks the current phase by hour, multiplies each spot's activity
weight by an availability factor (zero if used within `cooldownSeconds`,
zero if marked unreachable or native-failed this session), then draws
weighted random. If every weight is zero, wander or idle. Durations come
from the rules' per-activity ranges. Infinite-loop workspots get the
duration; finite ones run to their natural end.

### Driver

Executes one `Decision` on one puppet and reports a `DriverResult`
(`Done`, `Failed` with a reason, `Interrupted`).

Native path, for discovered spots: build `AIUseWorkspotCommand` with
`workspotNode` = the spot's `nodeRef`, `moveToWorkspot` = true,
`movementType` = Walk, send it, then poll `IsCommandActive` and
`WorkspotGameSystem.IsActorInWorkspot`. If the NPC is not in a workspot
within `nativeTimeoutSeconds`, cancel and return `Failed(nativeTimeout)`.
When the duration elapses, send the exit (fast exit signal) and wait for
`IsActorInWorkspot` to go false.

Manual path, for manual spots and as the fallback: send `AIMoveToCommand`
to the spot position; when the destination is reached (or after
`moveTimeoutSeconds`, which returns `Failed(unreachable)`), spawn the
invisible workspot device at the spot with the spot's `workspotPath`,
`PlayInDeviceSimple`, wait the duration, `StopInDevice`, delete the device.

Wander: `AIMoveToCommand` to a random point within `wanderRadius` of the
home center, clamped to the boundary.

### RoamController

One per attached NPC. A state machine driven by a delay callback tick
(about 0.5 s): `Discovering`, `Idle`, `Moving`, `InSpot`, `Paused`,
`Lost`. Each tick re-fetches the entity by id under a null check. Runs the
interruption checks (below). Asks the scheduler on `Idle`, hands the
decision to the driver, and acts on the result: `Done` returns to `Idle`;
`Failed(nativeTimeout)` marks the spot native-failed and retries it once
on the manual path; `Failed(unreachable)` marks the spot unreachable;
`Interrupted` goes to `Paused`. Keeps the NPC inside the boundary: if its
position leaves the boundary by more than a margin, the next decision is a
wander back to center.

### Spawner

For homes with a `spawn` block. Watches the player's distance to the home
center. Inside `spawnRadius`: creates the entity through
`DynamicEntitySystem` and, on attach, registers a controller. Outside
`despawnRadius` (larger, to avoid flapping): detaches and deletes.
Homes without `spawn` do nothing here and wait for `Attach`.

### Api

The public surface on `HomebodySystem`:

- `Attach(entityId, homeId, opt rulesName) -> Bool`
- `Detach(entityId)`
- `Pause(entityId)` / `Resume(entityId)`
- `SetRules(entityId, rulesName)`
- `GetSpots(homeId) -> array<Spot>`
- `DumpSpots(homeId)` writes every discovered spot with its node ref hash,
  position, path, markings, and activity to the log, for authoring
  `exclude`, `retag`, and `extraSpots`.
- `AddClassifierRule(match, activity)`
- `IsAttached(entityId) -> Bool`, `GetState(entityId) -> CName`

The Lua bridge is a sample `init.lua` calling these through the scriptable
systems container, pcall guarded and re-fetched per call.

## Data

### Home file, `r6/storages/Homebody/home.<id>.json`

```json
{
  "id": "judy_apartment",
  "bounds": { "center": [x, y, z], "radius": 12.0 },
  "spawn": { "record": "Character.Judy_Stub", "appearance": "" },
  "exclude": ["<nodeRefHash>"],
  "retag": { "<nodeRefHash>": "tv" },
  "extraSpots": [
    { "position": [x, y, z], "yaw": 90.0,
      "workspot": "base\\...\\sit_couch.workspot", "activity": "sit" }
  ],
  "rules": "default"
}
```

- `id`: required, unique, used in every log line.
- `bounds`: required. Either `center` + `radius`, or `min` + `max` for a
  box. Positions are world coordinates as three floats.
- `spawn`: optional. `record` is a TweakDB character record; `appearance`
  may be empty; `position` is an optional `[x, y, z]` spawn point that
  defaults to the boundary center, which in an apartment is often inside a
  table. Absent means attach-only.
- `exclude`: optional list of node ref hashes (as decimal strings, since
  Int64 does not survive JSON reliably) to drop from discovery.
- `retag`: optional map of node ref hash to activity, overriding the
  classifier.
- `extraSpots`: optional list of manual spots. `workspot` is a game
  resource path; `activity` is required because there are no markings to
  classify.
- `rules`: optional rules name, default `default`.

### Rules file, `r6/storages/Homebody/rules.<name>.json`

```json
{
  "phases": [
    { "from": 6,  "to": 10, "weights": { "cook": 3, "sit": 1, "phone": 1 } },
    { "from": 10, "to": 18, "weights": { "sit": 2, "tv": 2, "wander": 1 } },
    { "from": 18, "to": 23, "weights": { "dance": 1, "smoke": 1, "sit": 2 } },
    { "from": 23, "to": 6,  "weights": { "sleep": 5, "toilet": 1 } }
  ],
  "duration": { "sit": [40, 120], "smoke": [30, 60], "default": [20, 60] },
  "cooldownSeconds": 90,
  "wanderRadius": 4.0
}
```

- `phases`: hour ranges in game time, wrapping past midnight allowed. The
  first phase containing the current hour wins. If none matches, all
  activities weigh 1.
- `weights`: activity to weight. `wander` and `idle` are pseudo activities.
  An activity with no spot in the home contributes nothing.
- `duration`: seconds, `[min, max]`, per activity with a `default`.
- `cooldownSeconds`: a spot used within this window weighs zero.
- `wanderRadius`: metres around the home center for wander targets.

A `rules.default.json` ships with the mod.

### Runtime records, in memory only

- `Home`: the parsed file plus a `spots` cache and a discovery state.
- `Spot`: `nodeRef`, `nodeRefHash`, `position`, `yaw`, `workspotPath`,
  `markings`, `activity`, `source`, `isInfinite`, `lastUsedAt`,
  `unreachable`, `nativeFailed`.
- `Rules`: the parsed rules file.
- `ControllerState` per entity: `entityId`, `homeId`, `state`,
  `current` decision, `stateEnteredAt`, `pauseReason`.

## Interruption and boundaries

Checked every controller tick. Any of these puts the controller in
`Paused` with the reason logged once:

- The puppet is in combat or has a hostile target.
- A scene or dialogue holds the puppet (scene tier, or the player is in a
  conversation with it).
- The puppet is in a workspot the framework did not start.
- The game is in a menu or not in gameplay.
- The puppet is dead or defeated: `Detach` instead of pause.

On resume the controller abandons the current decision, waits one tick,
and reschedules. If the entity handle stays null for `lostGraceSeconds`,
the controller goes to `Lost`, logs it, and unregisters.

Boundary: the controller never issues a target outside the boundary; if
the puppet is found outside it by more than `boundaryMargin`, the next
decision is a wander to center.

## Failure handling

Every failure logs `[Homebody] <home> <entity> <what> <reason>` through
`FTLogWarning` or `FTLogError`.

- Native command not observed within timeout: fall back to manual for
  that spot, mark it native-failed for the session.
- Move never completes: mark the spot unreachable, skip it. Setting
  `allowOffNavmeshHops` (default off) lets the manual path retry with
  `ignoreNavigation` for short distances.
- Sector fails to load or zero spots found: log once per home; the home
  runs on manual spots only.
- Malformed JSON: log file and field, skip the file.
- Storage revoked: acquired once in the service `OnLoad`, so a save
  reload cannot revoke it; if storage is null anyway, log and disable the
  registry rather than crash.
- Any returned array is bound to a local before use; no inline indexing of
  call results (a known game crash).

## Settings

Mod Settings page `Homebody`, optional at compile time:

- Enabled (Bool)
- Debug logging (Bool)
- Native workspot timeout (Float, seconds)
- Move timeout (Float, seconds)
- Allow off-navmesh hops (Bool)
- Run self tests at load (Bool, debug)

## Testing

- Scheduler and classifier are pure and covered by an assertion suite in
  `HomebodyTests.reds`, run at script load when the debug flag is on,
  logging pass and fail counts. Includes: phase selection across midnight,
  zero-weight fallbacks, cooldown exclusion, classifier table order,
  duration ranges.
- Type check on every change with the tooling repo's `check-reds.ps1`,
  run twice, with and without `mod_settings` in `-PluginScripts`.
- `ACCEPTANCE.md`, ordered, each step naming the log line that proves it:
  1. Registry loads the example home and rules.
  2. Discovery lists spots for the example home (`DumpSpots`).
  3. One spawned NPC uses one couch through the native command.
  4. Forced fallback (native timeout set to 0) uses the manual path.
  5. Talking to the NPC pauses it; ending the talk resumes it.
  6. Leaving the area despawns; returning respawns.
  7. A Lua consumer attaches an AMM-spawned NPC.

## Build order

1. Walking skeleton: hardcoded home, one spawned NPC, one native workspot
   command by node ref, success proven by log lines. This retires the only
   unproven link before anything is built on it.
2. HomeRegistry and JSON loading.
3. SpotDiscovery and ActivityClassifier, with `DumpSpots`.
4. Scheduler with its test suite.
5. Driver manual path and fallback.
6. RoamController with interruption and boundary.
7. Spawner.
8. Api and Lua bridge sample.
9. Settings, README, ACCEPTANCE, packaging.

## Repository layout

```
r6/scripts/Homebody/
  Homebody.reds            the system: tick, homes, controllers, the API
  Storage.reds             the service that holds storage, classifier, furniture rules
  Log.reds                 FTLog wrappers
  Types.reds               Spot, Bounds, Decision, DriverResult
  HomeRegistry.reds        config, homes, rules
  SpotDiscovery.reds       sectors, AI spots, census, device and furniture spots
  ActivityClassifier.reds
  Furniture.reds           entity template rules and their workspots
  Occupancy.reds
  Scheduler.reds
  Driver.reds
  RoamController.reds
  Spawner.reds
  Probe.reds               console probe: discovery around the player, one native use
  HomebodySettings.reds
  TestKit.reds  HomebodyTests.reds
r6/storages/Homebody/home.example.json
r6/storages/Homebody/rules.default.json
r6/storages/Homebody/config.json
bin/x64/plugins/cyber_engine_tweaks/mods/HomebodyBridge/init.lua
docs/design.md
README.md  ACCEPTANCE.md  LICENSE
```

Dependencies: Codeware, RedFileSystem, RedData; optional Mod Settings and
entSpawner (manual path). Packaged with the tooling repo's `stage-mod.ps1`
and imported through Vortex.

## Deviations and findings

Recorded while building 0.0.1 to 0.0.18 between 2026-09-05 and
2026-09-13; the log lines behind each are in `ACCEPTANCE.md`.

Discovery. The streaming world object the running game hands back lists
no block refs, and so does the same resource loaded again by path, so
discovery loads `blocks\all.streamingblock` directly (24132 sectors).
Loading is polled through resource tokens on the tick, not driven by
callbacks. Only exterior and interior sectors are read: quest sectors are
thousands and carry world-sized boxes, navigation sectors hold navmesh.
Neither the streaming level nor the box size can filter further: the five
spots outside the example apartment live in a level 1 exterior sector with
a 679 m box. Eight sectors are read per tick; 327 sectors take about
23 s. Discovery also counts every node class inside the boundary, names
the entity templates there, and lists the workspot components of live
entities, skipping the ones under `base\gameplay\` (the player's own
personal link, computer and camera interactions).

Furniture. A player apartment's couch, bed and shower carry no NPC
workspot at all, and the apartment floor has no `worldAISpotNode`; the
game's own AI spots for that building are in the corridor. So
`Furniture.reds` (not in the approved design) matches a word in the
file name of each entity template and each static or destructible mesh
inside the boundary to an activity and a set of vanilla workspots from
the common library, and makes a manual spot at the node. A player
apartment's sofas and beds are meshes, not entities. Mesh nodes carry no
global node id, so a furniture spot is keyed by a hash of its position
at 0.1 m; two pieces within 0.5 m make one spot and the rule listed
first wins, so a bed beats the mattress on it. A rule carries a seat
offset, since a chair's pivot is its seat but a sofa's is its centre and
under the floor: the seat is placed forward of the pivot along the
node's facing (sofas 0.45 m) and at the height of the floor the NPC
walked in on. The chair sit is proven in game; the sofa offset is a
default the user tunes with the bridge's `Furniture` call. The device
path the design's "Task 8b" census was meant to clear was dropped.

Spot record. The node key is the decimal string of the global node id
hash (a Uint64 does not survive JSON). Added fields: `nativeFailures`,
`busyUntil`, `seatUp`, and for device spots `deviceId` and
`componentName`. Furniture spots carry the mesh or template file name as
a marking.

Native path. Proven: the engine walks the NPC to the spot and seats her
in 2 to 13 s. Two engine behaviours changed the driver. A use-workspot
command that fails in the same tick it was sent, with an empty command
queue and the NPC relaxed, is the engine refusing a spot another NPC
holds; the driver marks the spot busy for 120 s and the scheduler picks
again. It does not fall back to the manual path there, because that
seated her on top of the occupant. And the engine ends these finite
workspots after 30 to 40 s with the command in Success, so the driver
sends the same command again while more than 15 s of the scheduled
duration remain, three times at most; the re-send is proven (she sat
back down 6 s after leaving). The manual path (entSpawner's device,
`PlayInDeviceSimple`) is proven and its animation is visible. Its move
command can report success a second after it is sent, metres from the
spot, and the play then slides the NPC onto the device; the driver sends
the move once more before accepting that.

Occupancy. There is no reservation query for world spots. The check
looks for other puppets in a workspot within a metre of a spot, using a
targeting query. Run from the roaming NPC that query returned no puppets
at all; it now runs from the player and does see the corridor's
residents (26 puppets, 19 in workspots, the held chairs flagged).

Scheduler. Manual and furniture spots weigh nothing when the manual path
is unavailable; a busy spot weighs nothing until its time passes.

Controller. Interruptions: the API pause, death, combat
(`NPCPuppet.IsInCombat`), a scene holding the puppet, and a workspot the
driver did not start (ignored while the driver expects one, since the
native command seats the NPC before the next tick sees it). The "game in
a menu" check in the design is not implemented. `OnPlayerAttach` fires on every save load,
so the tick chain carries a generation number and old chains retire.

Settings. The Mod Settings page has Enabled, Debug logging, and the two
timeouts. Off-navmesh hops, the self-test switch, the spawn ranges, the
furniture switch and the device entity path live in `config.json`.

API. `Pause` takes a reason. Added: `Rescan`, `ListHomes`,
`ListControllers`, `AttachProbe`, the `Probe*` entry points with a status
and listing for the console, `AddFurnitureRule` and `FurnitureRulesText`.
`GetSpots` from the design is `DumpSpots` plus `SpotsFor`.

Testing. The self tests run at script load when `runSelfTest` is true in
`config.json` (not the debug flag) and cover the classifier, registry,
bounds, scheduler, occupancy filter and furniture rules; the in-game
counts are in `ACCEPTANCE.md`.
The acceptance list grew to twelve steps. Two lessons from the runs:
measure a returned array only after binding it to a local (two self
tests read 0 and 3 from an inline `ArraySize`), and load the Lua bridge
with LuaJIT's `loadfile` before each zip (a line break inside a string
kept the whole bridge from loading for three versions).

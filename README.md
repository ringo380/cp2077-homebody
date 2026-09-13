# Homebody

Homebody is a framework mod for Cyberpunk 2077. It gives a chosen NPC a life
inside one bounded place, typically an apartment: the NPC walks between the
furniture that is actually there, sits, cooks, smokes, watches TV, takes a
call at the window, showers, and so on, for as long as the player is around.
Other mods use it by dropping a JSON file in a folder, or by attaching an NPC
they already spawned.

The furniture is not typed in by hand. Homebody reads the streamed world
sectors around the home and finds the AI spots the game itself placed on the
bench, the barstool, the chair by the window, and the rest, then sends the
NPC to them with the engine's own use-workspot command, the same one crowd
citizens use to take a seat.

## Requirements

- Cyberpunk 2077 2.31 or later
- RED4ext, redscript, Cyber Engine Tweaks (for the console helpers)
- Codeware
- RedFileSystem
- RedData
- Optional: Mod Settings, for the settings page
- Optional: entSpawner (Object Spawner), whose invisible workspot device makes
  the manual fallback path and authored extra spots available

## Install

Import the release zip through Vortex. Two homes ship: `example`, the
corridor outside the Downtown apartment, whose resident spawns when the
player comes within 40 m; and `apartment`, the apartment floor itself,
attach-only, for `AttachProbe("apartment")` from the console.
`ACCEPTANCE.md` lists the log lines that prove each part works.

## For modders

### Files

Everything lives in `r6/storages/Homebody/`. Homebody reads the folder once
per game session.

`home.<id>.json`, one per home:

```json
{
  "id": "judy_apartment",
  "bounds": { "center": [x, y, z], "radius": 12.0 },
  "spawn": { "record": "Character.Judy_Stub", "appearance": "", "position": [x, y, z] },
  "exclude": ["4491241521636031788"],
  "retag": { "7185338493199956015": "tv" },
  "extraSpots": [
    { "position": [x, y, z], "yaw": 90.0,
      "workspot": "base\\workspots\\common\\chair\\generic__sit_chair_tablet__read__01.workspot",
      "activity": "sit" }
  ],
  "rules": "default"
}
```

- `id`: required, unique, used in every log line.
- `bounds`: required. Either `center` + `radius`, or `min` + `max` for a
  box. World coordinates, three numbers each. Keep it inside the walls: a
  sphere that reaches the corridor will send the NPC to the corridor.
- `spawn`: optional. `record` is a TweakDB character record. `appearance`
  may be empty. `position` defaults to the boundary centre, which in an
  apartment is often inside a table, so set it. Without `spawn` the home is
  attach-only.
- `exclude`: node keys to drop. A node key is the decimal string the log
  prints for each spot; `Dump` below lists them.
- `retag`: node key to activity, overriding the classifier.
- `extraSpots`: authored spots for furniture the game placed no AI spot on.
  `workspot` is a game resource path and `activity` is required. These need
  entSpawner's workspot device entity to be installed.
- `rules`: a rules name, default `default`.

`rules.<name>.json`:

```json
{
  "phases": [
    { "from": 6,  "to": 10, "weights": { "cook": 3, "sit": 1, "phone": 1, "wander": 1 } },
    { "from": 23, "to": 6,  "weights": { "sleep": 5, "toilet": 1, "idle": 1 } }
  ],
  "duration": { "sit": [40, 120], "smoke": [30, 60], "default": [20, 60] },
  "cooldownSeconds": 90,
  "wanderRadius": 4.0
}
```

- `phases`: game hours, `from` inclusive, `to` exclusive, wrapping past
  midnight allowed; equal values mean all day. The first phase containing
  the current hour wins; if none does, everything weighs 1.
- `weights`: activity to weight. `wander` and `idle` are pseudo activities.
  An activity with no spot in the home contributes nothing.
- `duration`: seconds as `[min, max]` per activity, plus `default`.
- `cooldownSeconds`: a spot used within this window weighs zero.
- `wanderRadius`: metres around the home centre for wander targets.

Activities the classifier produces: `sit`, `lean`, `stand`, `smoke`,
`cook`, `drink`, `tv`, `radio`, `dance`, `phone`, `sleep`, `toilet`,
`shower`, and `idle` for anything it cannot name. Add your own rule with
`Rule` below when the log shows a spot as idle.

`config.json` holds timeouts, the spawn ranges, the debug flag and the
workspot device entity path; the shipped file documents every key by
example.

### Calls

From redscript:

```
let hb: ref<HomebodySystem> = HomebodySystem.Get(gi);
hb.Attach(npc.GetEntityID(), "judy_apartment", "");   // rules name optional
hb.Pause(id, "conversation");
hb.Resume(id);
hb.GetState(id);        // Discovering, Idle, Moving, InSpot, Paused, Lost, Detached
hb.Detach(id);
```

From Cyber Engine Tweaks Lua, through the shipped bridge:

```lua
local hb = GetMod("HomebodyBridge")
hb.Attach(handle, "judy_apartment")   -- a game object or an EntityID
hb.State(handle)
hb.Pause(handle, "why"); hb.Resume(handle)
hb.Detach(handle)
hb.Dump("judy_apartment")             -- every spot with its node key, to the log
hb.Rule("hookah", "smoke")            -- classifier rule, then hb.Rescan(homeId)
hb.Furniture("stove", "cook", "base\\workspots\\market\\bar\\generic__stand_wok__cook__01.workspot")
hb.Furniture("couch", "sit", "", 0.6, 0.0)   -- seat offset: forward m, up m
```

Console helpers for a look without a consumer mod: `hb.Homes()`,
`hb.Status()`, `hb.AttachProbe(homeId)`, `hb.Probe(radius)`,
`hb.Use(index)`, `hb.Cleanup()`.

### Furniture without AI spots

Player apartments carry no NPC workspots on their couches and beds, and
that furniture is mostly static meshes rather than entities, so discovery
also reads every entity and mesh node inside the boundary and matches a
word in its file name (`couch`, `sofa`, `armchair`, `chair`, `stool`,
`bed`, `mattress`, `sink`) to an activity and a set of vanilla workspots.
The spot sits at the node's own position and facing, plays through the
manual path (entSpawner required), and shows in `Dump` and the log as
`furniture-<hash>` with the file name in its markings. `Probe` lists the
mesh and template names it saw, which is where to find the word for a
rule of your own. Words such as
`lamp`, `pillow`, `duvet`, `table` and `shelf` are skipped so a bedside lamp is
not a bed. `Furniture(match, activity, workspot)` adds a rule and
`Furniture()` prints the rules in force; `Rescan` applies them. The
seat is placed forward of the mesh pivot along its facing and at the
height of the floor the NPC walked in on, by the rule's offsets: a
chair's pivot is its seat (no offset), a sofa's is its centre (0.45 m
forward by default). `Furniture(match, activity, "", forward, up)`
changes a rule's offsets. A
furniture spot that sits the NPC wrong can be excluded by its key and
replaced with an `extraSpots` entry, and `furnitureSpots: false` in
`config.json` turns the whole thing off.

### Behaviour worth knowing

- Discovery reads the world sectors that intersect the boundary and keeps
  the AI spot nodes inside it, then classifies each from its markings and
  workspot path. It runs once per home per session and takes a few seconds
  in an interior, longer in a dense exterior.
- A spot another NPC is already using (any puppet in a workspot within a
  metre of it) is left alone.
- The NPC pauses on its own during scenes, combat, and any workspot the
  driver did not start, and resumes afterwards. Dead or missing entities
  drop their controller.
- Homes without AI spots inside them (player apartments are like this) get
  furniture spots from the template matching above, plus `extraSpots` for
  anything it misses; both need entSpawner. The workspots a player apartment's
  devices carry (personal link, computer, camera) are the player's own
  interactions and are never offered to an NPC; the couch and bed carry
  none at all.
- `GetMod("HomebodyBridge").Probe(15)` in the CET console prints, as it
  runs, what discovery finds around the player: spots, device workspots,
  and the entity templates inside the radius, which is how to learn the
  furniture's names before writing `extraSpots`.

## Logs

Everything Homebody says is prefixed `[Homebody]` in Cyber Engine Tweaks'
`bin/x64/plugins/cyber_engine_tweaks/gamelog.log`, which flushes late.
Crash breadcrumbs named `trace-*` land in `red4ext/logs/redfilesystem-*.log`
at once.

## License

MIT, see `LICENSE`.

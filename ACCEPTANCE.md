# Homebody acceptance

Run these in order after importing the staged zip through Vortex and
launching the game. Each step names the log line that proves it. Homebody's
own lines go to CET's game log,
`bin/x64/plugins/cyber_engine_tweaks/gamelog.log` in the game install, which
flushes minutes late: wait, or quit the game, before reading it. The
RedFileSystem log is `red4ext/logs/redfilesystem-<timestamp>.log` and
flushes at once. `r6/logs/redscript_rCURRENT.log` only shows whether the
scripts compiled.

1. Launch, load a save. In `gamelog.log` expect
   `[Homebody] attached (gen 1)` then `[Homebody] player attached; tick
   chain starts` then `[Homebody] tick 1`. In `redfilesystem-*.log` expect
   `trace-svc-00-storage` and `trace-sys-00-attach`.

2. Stand inside V's apartment (or any furnished apartment interior). Open
   the CET console and run `GetMod("HomebodyBridge").Probe(15)`. Expect in
   `gamelog.log`: `[Homebody] probe discovery: N streaming
   blocks`, then `M of T sectors intersect the boundary`, then one
   `probe spot <key> at (...) ...` line per spot, then `probe: K spots
   listed`. K must be above 0 in a furnished apartment. Record N, M, K and
   one full spot line under Findings at the bottom of this file. If
   `sector failed to load` appears, record the path.

3. After step 2 has listed spots, pick the index of a sit spot near you
   (the first `probe spot` line is index 0). Console:
   `GetMod("HomebodyBridge").Use(0)`. Expect in `gamelog.log`:
   `probe use: spawning Character.NurseFemale ...`, then
   `SendCommand(AIUseWorkspotCommand) returned true`, then `command state`
   lines, then `NPC is in the workspot after X s`, then after 20 s `sent
   fast exit`, then `NPC left the workspot ...; native path proven`. Watch
   the NPC: she should walk to the furniture and use it. If `not in a
   workspot after 40 s` appears, record the command state sequence under
   Findings; the manual path then leads and the native path becomes the
   optional one. Finish with `GetMod("HomebodyBridge").Cleanup()`.

4. Launch. Expect `[Homebody] registry: 1 homes, 1 rules`. If the device
   entity warning appears, entSpawner is not installed; the manual path is
   off, which is fine for the remaining steps. Console:
   `GetMod("HomebodyBridge").Homes()` prints
   `example rules=default spawn=Character.NurseFemale`.

5. Same launch. Expect `[Homebody] self-test` followed by PASS lines and
   `passed=N failed=0`. Any FAIL line is a defect in the classifier, the
   registry parser, or the JSON number handling; fix before continuing.
   Re-run `Probe(15)`: each spot line now shows an activity other than
   idle for recognisable furniture, and the sector line shows how many
   sectors were skipped by category. Record under Findings any furniture
   the classifier calls idle, with its path, and the new sector counts.

6. Load a save inside the Downtown apartment. The example home is its
   corridor, centre (-1607, 367, 49.2), radius 6, with a spawn point inside
   the apartment, so the resident spawns on her own as soon as you are
   within 40 m: expect `example: spawned Character.NurseFemale`,
   `attached ... to example`, `example discovery ...`, `example/... has K
   spots`, then `outside the home boundary; walking back`, then a stream of
   `native use <activity> <key> for N s`, `in spot ... after X s`, and the
   next decision after the duration. With `debug` on, `skips N occupied
   spots` appears whenever a resident is on the bench. Watch for five
   minutes: the NPC should use at least two different pieces of furniture,
   never sit on a resident, and never leave the corridor. Console
   `GetMod("HomebodyBridge").Status()` prints the controller's state.
   Record the sequence under Findings.

7. Draw a weapon near the NPC, or start a conversation with any NPC
   nearby. Expect `paused (combat)` or `paused (scene)`, then `resumed
   after ...` when it ends.

8. Walk away from the corridor beyond 70 m: expect `example: despawned
   (range)`. Walk back within 40 m: she spawns again and the routine
   restarts. Reload a save inside the apartment: she spawns again within a
   few seconds and no `revoked` line appears in `redfilesystem-*.log`.
   `GetMod("HomebodyBridge").AttachProbe()` adds a second NPC to the same
   home on demand; `Cleanup()` removes it and its controller reports
   `entity gone for 10 s; controller lost`.

9. Attach an NPC another mod spawned. With Appearance Menu Mod, spawn any
   NPC inside the corridor, find its handle in AMM's spawned list, then in
   the console `GetMod("HomebodyBridge").Attach(handle, "example")`. Expect
   `attached ... to example` and the routine on that NPC;
   `GetMod("HomebodyBridge").State(handle)` prints Moving or InSpot.

10. Settings > Mods shows Homebody. Turning Enabled off logs `paused
    (disabled)` for each attached NPC; on again logs `resumed after
    disabled`.

11. From 0.0.8 the discovery-done line is followed by `discovery census
    inside the boundary: <class> <count>, ...` and `discovery entities: N
    entity or device nodes, A live by hash, B live by node ref, W with a
    workspot component, D device spots`, then one `device spot` line per
    workspot component found. Record all of it under Findings; it decides
    whether device furniture (the couch, bed and shower of a player
    apartment) can be driven. Run it once in the corridor and once with a
    home whose bounds cover the apartment interior.

12. Furniture (0.0.12). Stand on the apartment floor and run
    `GetMod("HomebodyBridge").Probe(15)`. Expect `furniture spot
    furniture-<hash> at (...) sleep ... [bed_...] base\workspots\common\bed\...`
    lines for the bed and couch in the console listing, and `discovery
    furniture: N spots from entity templates` in the log. With a home whose
    bounds cover the apartment floor, expect `manual walk to sit
    furniture-...` and the NPC sitting on the couch.

## Findings

2026-09-05, 0.0.2, step 2: the probe ran but the streaming world object
the game hands back listed zero block refs, so discovery found 0 of 0
sectors. 0.0.3 loads the streaming world resource from the depot by path
instead and falls back to the all-blocks resource; step 2 is to be run
again on 0.0.3.

2026-09-05, 0.0.2. Step 1 passed: `attached (gen 1)`, `player attached;
tick chain starts`, `tick 1`, `tick 120` in gamelog.log; storage granted and
both breadcrumbs in redfilesystem-2026-09-05-21-37-34.log. Step 2: the
console returned `probing 15 m around (-1608.2, 354.9, 49.2)`; the probe's
log lines are recorded below once flushed.

2026-09-06, 0.0.3, step 2 passed. Standing at (-1608.2, 354.9, 49.2) in the
Downtown apartment with radius 15: `probe discovery: 1 streaming blocks (0
from the world resource)` (the by-path world copy also lists no block refs,
so the all-blocks fallback carried it), `2764 of 24132 sectors intersect the
boundary`, `probe discovery done: 5 spots in 2764 sectors, 387237 nodes
seen`, `probe: 5 spots listed`. It took three minutes from Probe to the
listing, almost all of it loading the 2764 sectors. Spot line:
`probe spot 4491241521636031788 at (-1606.9, 368.5, 49.2) yaw 180 idle
infinite [dlc6_apart_cct_dtn_ws_corridor_night ]
base\workspots\archetype\corpo\corpo__sit_chair__sit_around_devastated__01.workspot`.
Two things the listing shows: markings carry the apartment's own name and a
time of day (`_morning`, `_evening`, `_night`), and one chair appears as
several spots at the same position, one per time-of-day marking. 0.0.4 skips
quest and navigation sectors and logs the intersecting sectors by category
and level so the load can be cut to the handful that matter.

2026-09-06, 0.0.3, step 3 passed: native path proven. `SendCommand
(AIUseWorkspotCommand) returned true`, command state 1 then 2, `NPC is in
the workspot after 13.2 s`. The nurse walked from the apartment to the
corridor bench and sat. Two selection problems showed at the same time:
the bench already had a resident sitting on it (she sat on top of him), and
the bench is outside the apartment. So spot choice needs an occupancy check
(any puppet in a workspot within about a metre of the spot; the workspot
system has no reservation query for world spots) and a home boundary that
stops at the apartment walls. Also worth recording: within 15 m of the
apartment's own floor no worldAISpotNode was found at all; every spot was
in the corridor. Player apartments may carry no ambient AI spots, which is
what extraSpots and the manual path are for.
The exit half of step 3 is not proven: the command reached state 5
(Success) with the NPC already out of the workspot before the probe's 20 s
of engine time had passed (the game was paused for the screenshot), so the
fast-exit signal was sent to an NPC who had left on her own, or was pushed
off by the resident. The driver's exit path still needs a run where the
NPC is alone in the spot.

2026-09-06, 0.0.7, steps 4 to 6. Step 4 passed: `registry: 1 homes, 1
rules`, no device entity warning, so the manual path is available. Step 5:
`passed=76 failed=2`; both failures were `occ/none-taken` and
`occ/tolerance-edge`, which measured a returned array inline, and are
rewritten in 0.0.8 to bind it first. Step 6 passed: `example: spawned
Character.NurseFemale dynamic: '10324959'`, `attached ... to example`,
`327 of 24132 sectors intersect the boundary (2417 skipped by category,
2732 with a box over 400 m)`, by category Exterior 294 Interior 33 Quest
2404 Navigation 10 AlwaysLoaded 3, by level 2493 63 51 47 45 19 26.
`discovery done: 5 spots in 327 sectors, 207720 nodes seen` came four
minutes after the attach, so the load is still too slow; 0.0.8 keeps
level 0 sectors only. Then `outside the home boundary; walking back`,
`wanders 12.2 m`, `native use sit 4491241521636031788 for 99 s (sent
true)`, `in spot ... after 5.6 s`. The whole loop runs.
Later in the same run: she stood up by herself after 32 s and 35 s in the
two bench spots (`left spot ... on its own`), with nobody near her, so the
scheduled durations of 99 s and 85 s were never reached; the bench
workspots seem to end on their own. The third and fourth native commands
then failed instantly (`state 6, 0 s`) and the manual path took over
(`manual walk`, `manual play <path>` one second later, full duration, no
exit line yet). Whether the manual animations were visible is not known.
0.0.8 writes a spot off for the native path only on its second failure,
and logs the manual exit. Open questions for the 0.0.8 run: why the native
command fails instantly after a self-ended workspot, and whether re-sending
it after a short idle recovers.

2026-09-06, 0.0.8. Step 5 passed: `passed=79 failed=0` on both loads.
Step 6 regressed: `86 of 24132 sectors intersect the boundary` and
`discovery done: 0 spots in 86 sectors, 55237 nodes seen`, 22 s after the
attach. The level 0 filter dropped the sector that holds the five corridor
spots, so the nurse `idles 10 s (nothing weighs)` for the rest of the run.
The timing also shows what the four minutes on 0.0.7 were: 86 sectors in
22 s is exactly two sectors per 0.5 s tick, so the tick cadence set the
pace, not the node scan. 0.0.9 drops the level filter, reads eight
sectors per tick, and logs the level and box size of every sector that
yields a spot, so the levels that matter can be read off a real home.
Step 11 (census) ran: inside the corridor boundary `worldEntityNode 3` and
`worldStaticMeshNode 11` among lights, decals and particles; `3 entity or
device nodes, 2 live by hash, 2 live by node ref, 0 with a workspot
component, 0 device spots`. Both resolution routes work on live entities.
The corridor holds no device furniture, so the census has to be run again
with the boundary over the apartment floor before it says anything about
the couch, bed or shower. Steps 7 to 10 were not exercised (no spots).

2026-09-06, 0.0.9. Step 6 passed again and the load is solved: `327 of
24132 sectors intersect the boundary`, `5 spots in sector
base\worlds\03_night_city\_compiled\default\exterior_-13_2_0_1.streamingsector
(level 1, box 679 m)`, `discovery done: 5 spots in 327 sectors, 207720
nodes seen` 23 s after the attach (four minutes on 0.0.7). So the corridor
spots live in a level 1 exterior sector with a 679 m box; neither the
level nor the box size can filter it, and the category filter is the only
one kept. Step 11 with the corridor boundary: `worldAISpotNode 5`,
`worldEntityNode 4`, `4 entity or device nodes, 1 live by hash, 1 live by
node ref, 0 with a workspot component`.
Every console command from 0.0.7 to 0.0.9 failed: HomebodyBridge.log
shows `init.lua:45: unfinished string near '"'` on every load since
18:12, a real line break inside a Lua string in Homes() where `\n` was
meant, so CET never loaded the bridge and `GetMod("HomebodyBridge")` was
nil. Fixed in 0.0.10; the file is now loaded with LuaJIT's loadfile by
hand before each zip. Steps 2, 7 and 11 over the apartment floor need the
bridge, so they wait for 0.0.10.

2026-09-06, 0.0.10. The bridge loads again and `Probe(15)` on the apartment
floor answered step 11 for the apartment: `worldEntityNode 43,
worldDeviceNode 2`, `45 entity or device nodes, 30 live by hash, 30 live
by node ref, 14 with a workspot component, 22 device spots`, and every one
of the 22 is a player interaction (`device_personal_link_connect`,
`computerws`, `camera_zoom_generic`, `player_engineering`, all under
`base\gameplay\`). The couch, bed and shower carry no NPC workspot. So the
device path is not the route to apartment furniture; 0.0.11 skips
`base\gameplay\` workspots and logs the entity templates inside the
boundary so the furniture can be named and matched instead. The probe
also found one more corridor spot at radius 15 from the apartment floor
(`phone` at (-1599.0, 366.0, 49.2)).
Native path: the very first command of the session (`drink
7185339592711584226`) failed at once, `NPC Relaxed behaviour 0 reaction
Ignore/Ignore`, and the re-send after 3 s failed the same way; so did
every later native command, including the `sit 4491241521636031788` that
seated her on the first try in 0.0.7 and 0.0.9. The NPC's own state is
clean at that moment, so the cause is in the command queue, the
behaviour tree, or the engine's own reservation of a spot another NPC
holds; it is not a reaction. The reservation reading fits too: the two
first-try successes were on a bench that was free, and in this round she
was sent to seats the user could see were occupied. 0.0.11 logs the active command count and
the workspot and move command flags at the failure and does a hard cancel
(by class, by id, and the workspot system's stop) before the re-send. The
manual path carried every activity after that (`manual play` then `leaves`
or `was out of` after 17 to 52 s).
Observed in the world: she left the first seat, which was occupied, and
took the second one, which was occupied too, by the second half of a
hand-holding couple whose position overlaps that seat. The log says the
move was the scheduler picking the next spot after the first ended, not
the occupancy filter: that filter has never skipped a spot in any run,
so it is not seeing those residents. 0.0.11 logs how many puppets the
query returns before and after the workspot filter and how far the
nearest seated one is from each spot. Since every seated interval in this
round was the manual path, her sitting at all here means the manual
animation is visible; to be confirmed with the user.
Console: the user asked for progress while the probe runs, since it is
hard to tell whether it is still going. 0.0.11 prints a status line to
the console every three seconds and the full listing when it finishes.
Confirmed by the user afterwards: the seat next to the couple was taken
in this 0.0.10 round, where only the manual path seated her. So the manual
path's animation is visible in the world; the oldest open question is
closed.

2026-09-06, 0.0.11. Occupancy: `occupancy: 0 puppets nearby, 0 in
workspots, 0 spots taken` before every decision, with residents in view.
The targeting query run from the roaming NPC returns nothing at all, so
the filter was blind, not too tight. 0.0.13 runs it from the player.
Native path: every instant failure logged `commands 0` and the hard cancel
found `nothing to cancel`, and the 3 s re-send failed the same way every
time (0 of 6), so the queue is clean and the engine is refusing the spot
itself. The one bench that seated her on the first try in every run
(`7185338493199956015`) did so again, `in spot ... after 5.6 s`, while the
chairs the couple and the other residents sit on were refused at once.
That is the engine's own reservation of a held spot, and the manual
fallback was what sat her on the occupant. 0.0.13 treats an instant
refusal as occupied: the spot weighs nothing for 120 s and the scheduler
picks again, no manual play. The self-exit came with `command state 5`
(Success) at 37 and 41 s, so the engine ends these finite workspots on
its own; 0.0.13 sends the same command again while more than 15 s of the
scheduled duration remain, three times at most. The corridor boundary's
entity templates are drink tokens and a billboard, as expected.

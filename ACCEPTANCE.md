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
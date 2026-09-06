# Homebody acceptance

Run these in order after importing the staged zip through Vortex and
launching the game. Each step names the log line that proves it. The
redscript log is `r6/logs/redscript_rCURRENT.log` in the game install; the
RedFileSystem log is `red4ext/logs/redfilesystem-<timestamp>.log`.

1. Launch, load a save. In `redscript_rCURRENT.log` expect
   `[Homebody] attached (gen 1)` then `[Homebody] player attached; tick
   chain starts` then `[Homebody] tick 1`. In `redfilesystem-*.log` expect
   `trace-svc-00-storage` and `trace-sys-00-attach`.

2. Stand inside V's apartment (or any furnished apartment interior). Open
   the CET console and run `GetMod("HomebodyBridge").Probe(15)`. Expect in
   `redscript_rCURRENT.log`: `[Homebody] probe discovery: N streaming
   blocks`, then `M of T sectors intersect the boundary`, then one
   `probe spot <key> at (...) ...` line per spot, then `probe: K spots
   listed`. K must be above 0 in a furnished apartment. Record N, M, K and
   one full spot line under Findings at the bottom of this file. If
   `sector failed to load` appears, record the path.

## Findings

(Recorded outcomes go here, newest first.)

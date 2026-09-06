# Homebody acceptance

Run these in order after importing the staged zip through Vortex and
launching the game. Each step names the log line that proves it. The
redscript log is `r6/logs/redscript_rCURRENT.log` in the game install; the
RedFileSystem log is `red4ext/logs/redfilesystem-<timestamp>.log`.

1. Launch, load a save. In `redscript_rCURRENT.log` expect
   `[Homebody] attached (gen 1)` then `[Homebody] player attached; tick
   chain starts` then `[Homebody] tick 1`. In `redfilesystem-*.log` expect
   `trace-svc-00-storage` and `trace-sys-00-attach`.

# Homebody

Homebody is a framework mod for Cyberpunk 2077. It gives a chosen NPC a life
inside one bounded place, typically an apartment: the NPC walks between the
furniture that is actually there, sits, cooks, smokes, watches TV, takes a
call at the window, showers, and so on, for as long as the player is around.
Other mods use it by dropping a JSON file in a folder, or by attaching an NPC
they already spawned.

The furniture is not typed in by hand. Homebody reads the streamed world
sector around the home and finds the AI spots the game itself placed on the
couch, the barstool, the stove, and the rest, then sends the NPC to them with
the engine's own use-workspot command.

## Requirements

- Cyberpunk 2077 2.31 or later
- RED4ext, redscript
- Codeware
- RedFileSystem
- RedData
- Optional: Mod Settings, for the settings page
- Optional: entSpawner (Object Spawner), whose invisible workspot device makes
  the manual fallback path and authored extra spots available

## Install

Import the release zip through Vortex. Nothing needs to be configured for
the example home; see the log lines in `ACCEPTANCE.md` to confirm it loaded.

## For modders

Filled in with the public API in a later version. The design document in
`docs/design.md` describes the home file, the rules file, and the attach
calls.

## Logs

Everything Homebody says is prefixed `[Homebody]` in
`r6/logs/redscript_rCURRENT.log`. Crash breadcrumbs named `trace-*` land in
`red4ext/logs/redfilesystem-*.log`.

## License

MIT, see `LICENSE`.

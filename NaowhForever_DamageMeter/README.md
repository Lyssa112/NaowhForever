# Damage Meter

Damage, healing and more for your group, one bar each, in your theme. It reads the game's own
`C_DamageMeter` data and draws its own window, and turns the game's meter off while it is on. Its
settings page is Damage Meter/Settings. Its on/off switch and default come from
`ns.FEATURES.damageMeter`.

## Layout

```
NaowhForever_DamageMeter/
  NaowhForever_DamageMeter.toc   the addon; lists only DamageMeter.xml
  DamageMeter.xml                every file, in load order
  DamageMeter.lua                the settings (ns.DamageMeterSettings) and the module table (ns.DamageMeter, DM)
  Constants.lua                  the sizes, the lists and the sessions (DM.C)
  Data/
    Samples.lua                  the sample group the preview and Unlock Mode show (DM.SAMPLE)
  Source.lua                     reading the game's session (DM.Session), nothing drawn
  View/
    Meter.lua                    the window's look and layout (DM.Look)
  UI/
    Meter.lua                    the window: drag, resize, scroll, pickers, updates (ns.PreviewDamageMeter)
    SettingsPage.lua             its settings page, declared as cards
  README.md                      this file
```

## Why

- Amounts and names are secret in combat. Nothing in `Source.lua` or `View/Meter.lua` compares or
  adds them: they go straight to `StatusBar:SetValue`, `SetMinMaxValues` and `SetText`, through the
  client's own `AbbreviateLargeNumbers`, which takes a secret. That is also why there is no percent
  column. The class, the spec icon and `isLocalPlayer` are never secret, so those are read.
- The game returns its sources already sorted, so the window draws them in order and ranks by position.
- The API call goes through `pcall`: an error reads as no data and the window says so, not a Lua error.
- Updates are coalesced, 0.25 seconds after the first event of a burst, since the game fires one per
  source per update.
- The game's meter is the `damageMeterEnabled` setting. It is turned off while this one is on and put
  back as it was after, kept on the account so it survives a reload. It is left alone in combat and
  done again when combat ends.
- Interrupts, Dispels and Deaths have no per-second figure, so Show Per Second skips them.

## Checking

- `lua Tools/regression/test-damage-meter.lua`: the API read, the rows, the pickers, where it shows,
  the game's meter, updates and the settings page, with amounts that fail on any arithmetic.

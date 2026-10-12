# Damage Meter

Damage, healing and more for your group, one bar each, in your theme. It reads the game's own
`C_DamageMeter` data and draws its own windows, and turns the game's meter off while it is on. Up to
three windows, each with its own list, session and size. Hover a row for its spells, report to chat
from the window's menu, and reset from the menu or a key binding. Its settings page is Damage
Meter/Settings. Its on/off switch and default come from `ns.FEATURES.damageMeter`.

## Layout

```
NaowhForever_DamageMeter/
  NaowhForever_DamageMeter.toc   the addon; lists only DamageMeter.xml
  DamageMeter.xml                every file, in load order
  DamageMeter.lua                the settings (ns.DamageMeterSettings) and the module table (ns.DamageMeter, DM)
  Constants.lua                  the sizes, the lists and the sessions (DM.C)
  Data/
    Samples.lua                  the sample group the preview and Unlock Mode show (DM.SAMPLE)
  Source.lua                     reading the game's sessions, fights and spells (DM.Session, DM.Fights, DM.SourceSpells)
  Names.lua                      a player's name as written: first, last, initials (DM.DisplayName, DM.ScanRoster)
  Report.lua                     the lines a report sends, and where it can go (DM.Report, DM.Channels)
  View/
    Meter.lua                    a window's look and layout (DM.Look)
    Breakdown.lua                the spells panel beside a hovered row (DM.Breakdown)
  UI/
    Menus.lua                    a window's list, session and window menus (DM.Menus)
    Meter.lua                    the windows: drag, resize, scroll, hover, updates (ns.PreviewDamageMeter)
    SettingsPage.lua             its settings page, declared as cards
  README.md                      this file
```

## Why

- Amounts and names are secret in combat. Nothing in `Source.lua` or `View/` compares or adds them
  without asking `DM.IsSecret`: they go straight to `StatusBar:SetValue`, `SetMinMaxValues` and
  `SetText`, through the client's own `AbbreviateLargeNumbers`, which takes a secret. The class, the
  spec icon and `isLocalPlayer` are never secret, so those are read.
- The game returns its sources and spells already sorted, so the window draws them in order and ranks
  by position.
- The API calls go through `pcall`: an error reads as no data and the window says so, not a Lua error.
- Updates are coalesced, 0.25 seconds after the first event of a burst, since the game fires one per
  source per update. All open windows redraw together.
- The game's meter is the `damageMeterEnabled` setting. It is turned off while this one is on and put
  back as it was after, kept on the account so it survives a reload. It is left alone in combat and
  done again when combat ends.
- Every part of a window has its own color setting (`DM.C.COLORS`): the bars' custom color and your
  row's edge, the names, amounts, ranks, column titles, title, fight time and summary line, and the
  window, the title bar and the border. A row has no background of its own: the window's shows behind
  the bars. Each is `false` until a color is picked and then follows the theme's token
  it stands in for, so a theme switch restyles what was not picked. `Look.Color(key)` is the one place
  that resolves it.
- Class Colors can be changed class by class (`classColors`, class to color), kept apart from the
  theme tokens since the game gives every class its own. A background image is a name from the shared
  media's `background` list, drawn above the window's color and below the rows, stretched or tiled.
- The windows are plain frames, so they move and resize in combat; only Lock Window stops that. The
  sizing flag lives on the frame (`frame.sizing`), which is what the layout reads while the client
  resizes it.
- A row has two value columns, the total and the per-second figure, each its own text with a title
  above it. The DPS and HPS lists are the game's own, sorted by the per-second figure, so they lead
  with it and the bars still show the total, as the game's meter does.
- Number formats go through the client's `AbbreviateNumbers` with a config of breakpoints (`DM.Format`),
  which takes a secret and returns a string made from it, so K / M / B, a chosen number of decimals,
  ten-thousands (by the client's locale) and full numbers all work in combat. A client without it
  falls back to `AbbreviateLargeNumbers`.
- A name is written by cutting its words at spaces and the client's surname separator, and its realm is
  dropped. In combat a source's name is secret and cannot be cut, but its class is not: the group is
  read from unit tokens, which stay plain, and a row is matched to the one member of its class. Your
  own row always comes from your unit. A class two members share, or one not in the group, shows the
  name whole, as the game gives it.
- Interrupts, Dispels and Deaths have no per-second figure, so Show Per Second skips them. Deaths has
  no spells either.
- Windows 2 and 3 use the first window's keys with their number added (`mode2`, `width3`,
  `meterPos2`), so the window code takes an index and reads `DM.Key(base, index)`.
- A past fight is a field of the window (`fight`), not a setting: the game's fight ids do not outlive
  a reset or a reload, so the saved session stays Current or Overall and a reset puts every window
  back on it.
- A spell panel asks the game for a source by guid, and in combat the game takes a plain guid only:
  your own row's (`UnitGUID("player")`) or one whose guid is not secret. Any other row says its spells
  show after combat. The share is shown only when the amount and the total are plain numbers.
- A spell's icon and name come from `C_Spell` through `pcall` and are tested with `type()`, never by
  truthiness, since a secret id gives a secret answer. They go to the texture and the text as they are.
- A report is made of plain numbers, so it is sent outside combat only, and a source whose name or
  amount is still secret is left out. It goes to chat with `SendChatMessage` from a menu click, which
  is a hardware event, so Say works too.
- The summary line under the title bar is made with one `SetFormattedText`: the session's name, its
  total (a secret string in combat), the raid's per-second figure and your rank. The raid figure is
  the total over the session's length, so it only appears once both are plain numbers, after the
  fight; your rank is your row's position in the game's order, which is never secret.
- The fight time in the title bar is the shown session's own length from the game
  (`GetSessionDurationSeconds`, or a past fight's from `GetAvailableCombatSessions`), read through
  `DM.Duration` and shown only as a plain number and only when the bar has room beside the title.
- Avoidable Damage is the game's own list of damage taken from avoidable abilities.
- There is no combat timer or cast history here: the QoL module already has a Combat Timer and a GCD
  Tracker.
- The reset key is `NaowhForever_ResetDamageMeter`, declared in `Bindings.xml`. Core defines a stub
  that says the module is off; this module replaces it.

## Checking

- `lua Tools/regression/test-damage-meter.lua`: the API reads, the windows, the menus, the report,
  the spell panel, where it shows, the game's meter, updates and the settings page, with amounts that
  fail on any arithmetic.
- `lua Tools/regression/test-nf-commands.lua`: the reset binding and its stub.

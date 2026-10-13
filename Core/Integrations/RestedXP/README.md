# RestedXP themes and guide window

Naowh's theme, the eight theme presets and the player's current theme in RestedXP Guides, and the
hooks that style its arrow, title bar, quest list and scroll bar. Off unless Settings > RESTEDXP
turns it on (`ns.FEATURES.account.rxpThemes`), and only with RestedXP Guides installed. Loads
through `RestedXP.xml`, after `Core/Core.xml`.

The Naowh guide window (`ns.FEATURES.account.rxpWindow`, also off by default) draws RestedXP's guide
in one Naowh window: the guide and its progress, the active step and the steps after it.

## Layout

```
Core/Integrations/RestedXP/
  RestedXP.xml                what loads
  Themes.lua     the themes, the settings behind the RESTEDXP card, and the hooks
  Window.lua     the Naowh guide window, its settings and what it reads from RestedXP
  Media/         the themes' arrow, frame and grip art (rxp_*.tga), drawn by Tools/media/make_media.py
```

## Why

- RestedXP imports the global theme list (`RXPGuides_Themes`) as it starts, so the themes go in
  while our addon loads. If RestedXP is up already they go in through its own `RegisterTheme`, and
  a saved theme of ours it fell back from is reloaded at login.
- The hooks need RestedXP's frames, so they wait for PLAYER_LOGIN. Each checks what it needs and
  does nothing without it.
- Nothing here raises through RestedXP, whose frames and functions change with its releases and
  whose own code calls our hooks. Every hook, every installer and every call into RestedXP's
  functions runs under `pcall` (`Quiet` and `Guarded`), so one that fails neither breaks RestedXP's
  call nor keeps the others from being made. What failed is kept, the last of each by name, in
  `ns.RXPFailures` (`/dump NaowhForever.RXPFailures`) and nothing is printed. Rows are remembered
  only when a pass got to the end, so one that failed is tried again.
- RestedXP's UI v2 hides its legacy window (`DisableLegacyGuideWindow`) but leaves the cog showing,
  as the cog hangs from the window and not from the footer. The banners, cog, grip, scroll bar and
  rules are therefore painted only while their part is visible (`Visible`), and again when it is
  shown: an OnShow hook on the window and on each part (`HookShown`), so a window that was closed
  and opened keeps no stale look. The look is not adapted to UI v2 yet; its windows get the colors
  through RestedXP's own conversion of the themes (`RXP.v2.themes`, from the fields in `Theme`).
- RestedXP's theme reload scales its protected target frame, so in combat it waits for the end.
- Naowh (current) is read from `ns.THEME`, the colors the addon itself is drawn in, not from the
  theme picked: the Classic+ skin overrides that pick (`ThemeSource` in Core.lua). The fixed themes
  come from `ns.ThemePalette`, which never carries the player's own colors.
- The font and text color are part of the themes, which RestedXP reads as it starts: they take a
  reload. The font is `ns.AddonFontPath`, not `UIFontPath`, which remembers what it finds and this
  runs before every addon has loaded.
- `dividerColor` and `chromeColor` are ours, not RestedXP's fields. The bars need a white fill to
  show the theme's color.
- Naowh's arrow image is drawn at a percent of RestedXP's arrow frame. With a glow the kite fills
  only 76% of the image (`GLOW_FILL`, see Tools/media/make_media.py), so that image is drawn larger to
  keep the kite the same size. RestedXP's Arrow Size setting resizes the frame silently, so its
  OnSizeChanged is watched.
- The colored layer over RestedXP's arrow is lighter at the top, deeper at the bottom and not full
  strength, so the dark arrow still shades it. It follows the arrow's rotation through a post-hook
  on its SetRotation.
- RestedXP only sets the distance text, never shows or hides it, so hiding it is ours to undo.
  Moving it needs the anchor RestedXP gave it; a text with none has nothing to move or to give
  back, so it is left alone.
- The title bar and footer banners are plain black in DarkMode, so they are faded with SetAlpha to
  let the fill show; RestedXP sets them again whenever it draws its theme, so SetTexture is
  watched.
- The cog, corner grip and scroll bar have no theme field: the cog and grip get Naowh's images and
  the scroll bar a thin thumb without arrows, in Secondary Text. RestedXP never sets the grip
  again, so its original is kept to put back.
- Quest rows are 3 apart and the rule sits at the far edge of that gap. Rows are made when a guide
  loads, which ends in SetStep, so that is watched; rules are redrawn only when the theme or the
  row count changes.
- The guide window only reads RestedXP's data and never writes it, and RestedXP's own two v2 windows
  (the guide window and the active steps) are kept alive and out of sight: their rows are what
  RestedXP's step handlers write to (`BindActiveStepElement` sets `element.frame`, and the handlers
  set its text, icon and checkbox), so a second set of rows would not be updated. They are made
  see-through with `SetAlpha(0)`, held there by a post-hook on `SetAlpha`, and they and every frame
  in them take no clicks (`EnableMouse(false)`), the alpha and mouse kept to give back when the
  window is turned off. They are not hidden, as RestedXP shows and lays them out itself.
- A row shows the text RestedXP has in its own row now (`element.frame.text`), so counters such as
  "5/5" follow it; a post-hook on that text asks for a redraw. A click on a row is a click on
  RestedXP's own checkbox, so what it does for a skipped step is RestedXP's.
- Everything that changes asks for a redraw, and the redraw is one per frame (`C_Timer.After(0)`):
  `SetStep`, `UpdateGuideWindow`, `UpdateActiveStepsFrame`, `UpdatePlayerActiveStepItem` and the
  rows' text. The window needs RestedXP's V2 interface (`v2:IsGuideWindowEnabled()`): the active
  step rows and the guide's rows are built for it.
- Steps after the active one come from `v2:BuildGuideStepsSnapshot`, which is what RestedXP's own
  v2 guide window lists, so a step it hides or has done is not listed here either.
- The window has no panel of its own, as RestedXP's coming layout has none: a header with a rule under
  it, the active step in a box (the only thing with a background), and the steps after it as plain
  shadowed lines over the world, so every text carries a shadow (`SHADOW`) to be read on any ground.
  The lines after the active step are plain text (`Plain`: no icons, colors or links), as the active
  step's rows are what carries them. The small button below the list opens RestedXP's menu, as a right
  click on a window with no panel is hard to find.
- The window's size is one scale (`SetScale`) for the whole of it, text included, and the width is the
  room the text has inside it. Changing the scale keeps the window in the same place on the screen:
  its anchor is kept in the scaled units, so it is multiplied by the old scale over the new one, in the
  saved place too when the window is off.
- The arrow's text is RestedXP's step title and its distance, set again every time the distance
  changes. With Arrow Shows Objective the text is put again after RestedXP's own (a post-hook on its
  `SetText`, which `composing` keeps from calling itself): the distance, then the words of the
  objective the waypoint belongs to, as RestedXP shows them in its own row when it has one, as plain
  words (`Plain`: no texture or atlas, which RestedXP puts in a row of its own and in the text of
  some lines). A guide often writes the place first and what to do there after it, so the waypoint has no
  `element.parent` (the line above it, `addon.lastObjective`): its own words come next, then the
  lines of its step after it, then the ones before it, leaving out one that is done or has no tooltip. A waypoint with no words says only the distance, and RestedXP's "~" on the
  wrong continent is left. It does not wait for one of the Naowh themes to be picked in RestedXP, as the
  words are not part of how the arrow is drawn. Turning it off makes RestedXP say its own text again by clearing
  `arrow.distance`, which RestedXP compares before it sets the text.
- The arrow's font is set by RestedXP's `SetupArrow` and by its Arrow Text Size setting, from
  the font of the theme picked, which is ours only when one of ours is picked. With Use Addon
  Font on, a post-hook on its `SetFont` puts it in the Addon Font, and in Naowh's size for it (13 to
  start, RestedXP's own is 9, Arrow Text Size), with the outline RestedXP gave it, so it is in the Addon
  Font at that size whichever theme is picked and whatever RestedXP sets next. A path the client
  hands back spelled differently would make the font chase itself, so a flag (`keeping`) holds the
  hook while it sets one. With the switch off RestedXP's own font (`RXP.font`) is given back. The
  window uses `ns.AddonFontPath`, which is read live, and not `ns.UIFontPath`, which keeps the first
  path it found.

# RestedXP themes

Naowh's theme, the eight theme presets and the player's current theme in RestedXP Guides, and the
hooks that style its arrow, title bar, quest list and scroll bar. Off unless Settings > RESTEDXP
turns it on (`ns.FEATURES.account.rxpThemes`), and only with RestedXP Guides installed. Loads
through `RestedXP.xml`, after `Core/Core.xml`.

## Layout

```
Core/Integrations/RestedXP/
  RestedXP.xml                what loads
  Themes.lua     the themes, the settings behind the RESTEDXP card, and the hooks
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

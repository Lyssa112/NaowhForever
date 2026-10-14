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
  step's rows are what carries them. RestedXP's menu is a right click, on the window and on a row and the
  box of the current step too (they take the mouse, so each is given the right button), and not on a
  line of the list: those are for going to a step. A button for it was taken out as it was the same menu,
  and the tooltip of the first line says where it is. A locked window has no grip.
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
- What the window can be changed in is two lists in `Window.lua` (`OPTIONS` and `COLORS`), each with its
  kind, default, range and tip, and the settings page draws its rows from them (`WindowOptionCell`,
  `WindowColorCell`), so a new option is one entry. A value is kept only when it is not the default, and
  a color whole (r, g, b, a) or not at all, so the theme's stays the default and follows it. Every text
  is made with `Text` and set again with `Face` each time the window is drawn, which is what lets the face,
  the outline and the three sizes change at once.
- The progress bar is a `StatusBar`: the guide's under the title (the step over the number of steps, so
  36 of 66) and one in the active step (the rows done over its rows). Its texture is a SharedMedia
  statusbar picked in the page and flat to start, its track is the Line color and its fill the Bar color.
- The window is resized from its corner (`StartSizing`). Its height is what it draws, so the height does
  not set a height: it sets how many steps are listed. Draw keeps the height the window has without the
  list (`chrome`) and the height of a line, and letting go of the grip turns the width and
  `(height - chrome) / line` into the width and steps settings and draws again at the size that fits.
  Its bounds are the smallest (no steps) and the tallest (all of them). Lock Window stops moving and
  sizing, and a folded window has nothing to size.
- The window follows the drag as it happens (`OnSizeChanged` while the grip is held): what the list can
  show is read once when the grip is pressed, with every step it could list, and each size drawn from
  that, so nothing is read again per frame; the window does not set its own width or height while it is
  dragged, as the drag does, and what is kept is set when the grip is let go. The width is kept to the
  pixel.
- The guide's progress under the title is the only bar of the window besides the ones of a row that
  counts: a bar of the objectives done under the active step was tried and taken out, as it read as one
  thing counted twice beside the guide's. The box's own opacity is a setting (`rxpWindowBoxOpacity`) and
  not a part of its color. The bars are in the Naowh Gradient to start (`GRADIENT`, which is `ns.MEDIA`'s,
  so a texture of SharedMedia is only needed when another is wanted).
- RestedXP's logo (`Textures/rxp_logo-64`, the one its own window and quest log use) is drawn from
  RestedXP's files in the top right corner of the current step's box (the first, when there are more),
  untinted, at a size of its own (24 to start); Show RestedXP Logo turns it off. It is a texture of the
  box, so it is above the box's background, and the rows start below it, or below the label when it is
  smaller. The window hides RestedXP's own and so would otherwise show nothing of it anywhere.
- The rows after the first of a step are set in (Row Indent, 12 to start), and narrower by as much, so a
  Buy under a Talk to reads as a part of it.
- A click skips or goes to a step and never ticks an objective: a sub task completes itself as RestedXP
  sees it done, and skipping one by hand is not offered. On the whole of an active step (its rows and the
  box round them, which each know their step: `step` on a row, on the box) a click goes to the step after
  the guide's progress, unless the step is not the guide's progress (a trainer to see, which stays active
  beside it, `sticky`): then its objectives are skipped as RestedXP's checkbox does (`element.skip`,
  `OnComplete` once, `updateSteps`) and RestedXP lets it go, as going to the next step would leave it
  where it is. On a line of the list it goes to that line's step. Both need Shift by default (Skipping
  Steps), as a plain click is also where a window is grabbed to be moved and a step skipped by it is not
  given back; Click and Off are the other two. The tooltip is the box's wherever the mouse is in the step,
  and Show Tooltips turns it off. A right click is RestedXP's menu on the window and on a step, and not on
  a line of the list, those being for going to a step. The list's lines are a transparent button each
  (pooled as `hit`) over the text, so they are also where the window is dragged from, and with Off they
  are not lit.
- A row that counts has a bar under its text: a buy by the items in the bags against `qty` (RestedXP shows
  no counter for it, so `GetItemCount(id)` is read, and the window listens to `BAG_UPDATE_DELAYED` only
  while such a row is drawn), and any other row by the `3/8` in its text, which RestedXP rewrites as the
  count changes and so redraws the window. A count of one is a tick box and not a bar, a row that is done
  is full, and a count past its total is full. Only `buy` tags are counted from the bags, as another tag's
  `id` or `qty` can mean something else.
- The Active Targets and Active Items windows (`RXPTargetFrame`, `RXPItemFrame`) take the look of the
  active step's box: the colors of their v2 background and border textures are set in place after
  `UpdateVisuals` (and after the targets' `RenderTargetFrameBackground`, which settings call alone), and
  their title's text takes the window's face and color, kept at RestedXP's size so nothing is laid out
  again. Each is hooked once (`watched`); a frame RestedXP makes later is taken at the next draw. The
  border follows the background, so a background RestedXP hides keeps its border hidden. Turned off
  (the window, or Style Targets and Items), RestedXP's own `UpdateVisuals` paints them again, and the
  border is shown where the background is, as the title's is not set by it.
- The icon at the start of a row has a size of its own (Icon Size, 18 to start, over the text's 13): the
  icon's font string is faced at it, so RestedXP's own icons (`|T...:0|t`, as tall as the text they are in)
  grow with it, and the column and the row are as big. The text is dropped to the middle of an icon that
  is taller than it, and not when it is smaller.
- The first line of a step is bigger than its sub tasks (First Line Bonus, 2 over the text size to start).
  `Refaced` sets every row's text to the text size at the start of a draw, and `DrawRow` sets the first
  row's again with the bonus, so a pooled row that was the first and is not is back at the text size at
  the next draw. The title has no bar at its side (the sub tasks keep theirs, which say open or done), and
  its icon is bigger by the bonus twice, as its text is bigger by it once; the column, the drop of the text
  and the row follow the icon's size of that row.
- RestedXP keeps its settings by profile, which is a character's own unless the player shares one, so a
  character it has not met has its defaults: the V2 interface off, which the window needs, and its own
  theme. Set Up New Characters (off to start, shown once themes or the window are wished for) sets, the
  first login of a character, `enableBetaFeatures`, `enableV2Interface` and the Naowh current theme in its
  profile for what is wished for, and asks for a reload as the interface is read when RestedXP loads; what
  the player changes after is theirs, as the characters done are kept (`rxpSetUp`, by GUID). The button
  does it for the character played, seen or not.
- The old theme (Add Themes to RestedXP), the arrow (Style RestedXP's Arrow) and the Naowh guide window are
  each a switch and a section of their own, and none reads another's rows. The theme and the window are
  never both on: turning one on turns the other off (`SetRXPThemes`, `SetRXPWindow`), and a saved pair is
  read as the window's (`RXPThemesEnabled` is false while the window is wished for). The arrow is its own
  module (`RXPArrowEnabled`): it is hooked at login when it is on, with the theme or the window or neither,
  in the live Naowh accent when the active theme is not one of ours, and with a font of its own (Arrow
  Addon Font, `rxpArrowFont`). An account from before follows the theme it had on until the arrow is
  set once, and the theme or the window being switched sets it as it was, so that taking the theme away
  does not take the arrow with it.

# pfUI Octo

Fork of shagu/pfUI 5.5.4 on the `octo` branch (upstream stays on `master`), for the OctoWoW
1.12.1 build 5875 client. Goal: one all-in-one UI with ElvUI-style looks, layout mode, install
wizard, profile strings and options window, plus built-in meters (damage, healing, threat and more,
Details!/Recount depth) and combat text moved over from OctoBG. Roadmap and decisions:
see "Roadmap" below.

## Rules
- The folder, the `pfUI` table and the saved variables keep their names: pfQuest, Clickcast,
  EFocus, Bagforlife, Atlas, HoryUI and OctoBG all hook pfUI by name.
- `## Version` in pfUI.toc stays the upstream base (5.5.4). updatenotify broadcasts it to other
  pfUI users, and a higher number would make everyone's pfUI say "new version at shagu.org". The
  Octo version is `## X-Octo-Version`, read into `pfUI.version.octo` (pfUI.lua) and shown in the
  options title and the About page.
- Lua 5.0: no `#`, `%`, `...` as an expression, string.gfind not gmatch, table.getn. Write Lua with
  Edit/Write, never a shell heredoc (apostrophes and backslashes get mangled).
- Modules are `pfUI:RegisterModule(name, "vanilla:tbc", fn)` listed in init/modules.xml; they run
  in pfUI's environment (`C` = config, `T` = translations, pfUI.api functions as globals).
  Defaults go in api/config.lua (`pfUI:UpdateConfig(group, sub, key, default)`), options in
  modules/gui.lua (`CreateConfig`, `CreateGUIEntry`).

## Testing
- `powershell -ExecutionPolicy Bypass -File tests\run.ps1`: loads every file in the toc (following
  the init\*.xml includes) on DmorphOcto's LuaHost (LuaJIT, Lua 5.0 shims), fires ADDON_LOADED and
  starts every module and skin one by one. Unknown CamelCase globals become stand-in widgets, ALL_CAPS
  constants become strings or small counts (tests\run.lua). 61 of 71 modules start offline; the
  rest need client parts the mock lacks (Blizzard child regions). Then it builds every options
  page (27 of 52 build; unit frame / action bar pages need more mock). Octo modules go in
  `MUST_LOAD` and fail the run if they error. `PFUI_TEST_VERBOSE=1` lists module and page errors.
- Unknown widget fields return a no-op function only when named like a method (Set*, Get*, Is*...,
  `IsMethodName` in mock.lua): pfUI stores data under CamelCase keys (gui.frames["General"]).
- `..\OctoBG\tools\LuaCheck.ps1 -Files @(<full paths>) -Globals` on every changed Lua file.
- tests\mock.lua is a copy of OctoBG's, changed so pfUI can run: absent 1.12 methods look up as nil
  (pfUI tests `if not frame.HookScript`), GetNumPoints / GetPoint / SetGradientAlpha exist (pfUI
  uses them on 1.12, so OctoBG's mock is wrong to refuse them), font sizes may be numeric strings.

## Verified vs unverified
- Unverified: `GetAddOnMetadata(name, "X-Octo-Version")` on this client (falls back to "0").

## Roadmap (approved 19 Oct 2026)
0. Foundation: branch, toc, this file, tests. DONE.
1. Look and feel. DONE 19 Oct (not seen in game): env/octo.lua - `pfUI.octo.look` (1px black
   borders, 0.06 backdrops, PT Sans Narrow Bold text, Expressway numbers/unit/cooldown/combat,
   img\bar_elvui on unit frames, castbar, nameplates, tooltip, xp bar), `pfUI_profiles["Octo"]` =
   Slim + look (fresh installs and both resets use it; first-run wizard has an Octo button),
   `pfUI.octo.ApplyLook()` = button "Apply Octo Look" at the top of Settings > Appearance (changes
   only look keys, never sizes/positions). Accent colour: `appearance.accent.mode` class|custom +
   `.color`, `pfUI.api.GetAccentColor()` used by SetHighlight / SkinButton / rotate / dropdown
   highlight in api/ui-widgets.lua. Still teal (pfUI's |cff33ffcc / .2,1,.8): options window tree,
   scrollbar thumbs - phase 4 moves those to the accent.
2. Layout mode. DONE 19 Oct (not seen in game), modules/unlock.lua. pfUI already had drag, grid,
   middle-click reset and a right-click box (anchor, X/Y, arrows, Configure). Added: snapping while
   dragging (`GetSnap`: other movers' edges/centres and screen edges/centre first, grid lines
   second, 8 px, accent guide lines live, Alt or the Snap box = off), grid drawn from the centre
   with exact accent centre lines, top bar (Snap, grid -/+ 32/64/128/256 cells, ?, Reset All,
   Done), Shift on the arrows = 10 px, `/moveui` and `/pfmove`, options window only reopens when
   layout mode was started from it, help box only on first use (`unlock.helpseen`). Config group
   `unlock`: snap, gridsize, helpseen.
3. Install wizard (ElvUI flow, /pfui install) and profile export/import strings.
4. Options window restyle (ElvUI): headers, group boxes, top bar, Meters + Combat Text pages.
5. Meters, Details!/Recount depth (the user asked "they should tell you everything, all
   interrupts, all casts"): damage / healing / overhealing / absorbs, damage taken, per-spell and
   per-target breakdowns with hits, crits, misses, max/min/avg, interrupts (who kicked what), dispels
   and purges, crowd control and CC breaks, deaths with a log of the last hits and heals, every cast
   per player, buff/debuff uptime, activity time, segments (current / overall / per fight / boss),
   reports to chat. Threat from the server protocol (TWThreat's `TWT_UDTSv4`, unverified on this
   server) with pull-aggro line and tank view. Sources: nampower events (casts, GUIDs, interrupts)
   where present, combat-log strings as fallback. Credit ShaguDPS for the parser; TWThreat code is
   not copied (no licence).
6. Combat text: move OctoBG's SCT.lua / SCTEvents.lua / SCTOptions.lua into pfUI; OctoBG defers.

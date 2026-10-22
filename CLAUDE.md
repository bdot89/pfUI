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
- Never assign a client global like `this`, `event` or `arg1` from pfUI code: modules run in
  pfUI's environment, so `this = f` creates a pfUI-only `this` that hides the real one from every
  pfUI script afterwards. Use `_G.this` (22 Oct 2026: broke every pfUI script and blanked the
  options page).
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
  page (all 52 must build). Octo modules go in
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
   dragging (`SnapBox`: other movers' outer edges (frame + border, so boxes sit flush) and
   centres and the screen edges/centre first, grid lines second, 10 px, accent guide lines, Alt
   or the Snap box = off). Seen in game 19 Oct: the first version (snap on release after the
   client's StartMoving) did not snap - the client reports a moved frame's edges late. Now the
   drag is done by hand: DragOnUpdate moves the selection from the cursor and pulls it onto the
   snap live; the drop saves from those numbers (AnchorFor = screen third, AnchorOffsets) and
   never reads edges back. Reparents to UIParent at drag start, as pfUI did on drop. Grid drawn from the centre
   with exact accent centre lines, top bar (Snap, grid -/+ 32/64/128/256 cells, ?, Reset All,
   Done), Shift on the arrows = 10 px, `/moveui` and `/pfmove`, options window only reopens when
   layout mode was started from it, help box only on first use (`unlock.helpseen`). Config group
   `unlock`: snap, gridsize, helpseen.
3. Installer + profile strings. DONE 19 Oct (not seen in game).
   modules/firstrun.lua rewritten as one ElvUI-style window (step list left, Previous / Next /
   Skip, close X = ask again next login). Steps: init, profile (Octo recommended + stock profiles,
   UI scale; picking one sets pfUI_init.profile before the reload so it does not ask again),
   layout (Tank/DPS vs Healer: `pfUI.firstrun.SetRaidLayout` moves `pfRaidCluster` to bottom centre,
   width from raidlayout columns), cvars, chat_right, chat_position, chat_channels, finalize.
   AddStep(name, func, title) keeps the old two-argument form. `/pfui install` =
   `pfUI.firstrun:Restart()`; `/pfui move`, `/pfui export` also work. Meter / combat text steps
   come with phases 5 and 6.
   modules/share.lua (/export, /import, /share - pfUI's own) fixed: import no longer runs the
   pasted text with loadstring (`parse` reads only `["k"] = "v",` / number / `{` / `}` lines),
   Import shows a per-section change preview, strings without positions/disabled keep the
   importer's own (pfUI used to reset them), Import accepts the encoded string directly. Two
   upstream bugs: enc() cut a real character when the text ended on a 92-char line break, dec()
   used a pattern find (errors on "(" or "["). `pfUI.share` exposes serialize/parse/preview/import.
4. Options window, ElvUI layout. modules/gui.lua. Window 940x600; title bar: accent "pfUI Octo" +
   version, search, Move Frames / Keybinds (hoverbind) / Install / Profiles (share).
   First version (one control per row, zebra) seen in game 19 Oct: the user called it "messy"
   and asked to copy ElvUI. Second version (not seen in game yet):
   - Tree: ONE column 170 wide (`RelayoutTree`); a category's pages are its `children`, listed
     indented under it only while it is open (+/- marker); they used to open a second column.
     Page areas fill the category area (no inner column). Clicking a page opens its category.
   - Pages: title "Category > Page"; every "header" is a titled group box; CreateConfig only
     collects cells (`Place`), `Finish(page)` (called after the page's populate func) lays each
     group out: warnings, then tick boxes / colour swatches / buttons in a 2-column grid, then
     dropdowns / text fields (label above), then lists; same kinds keep their order; a spacer
     CreateConfig(nil) starts a new block. Tick box labels are clickable. Cells record
     `frame.cell` {x,y,w,h} and `frame.cellkind`.
   - Tests check no cells overlap and all sit inside their page and group. PFUI_PREVIEW_DIR=<dir>
     makes tests\run.lua write options-preview.html (a drawing of every page from those numbers;
     serve it over http to view it in the browser pane, which will not screenshot file://).
   Every teal in gui.lua / api/ui-widgets.lua uses GetAccentColor (About logo left teal).
5. Meters, Details!/Recount depth (the user asked "they should tell you everything, all
   interrupts, all casts"): damage / healing / overhealing / absorbs, damage taken, per-spell and
   per-target breakdowns with hits, crits, misses, max/min/avg, interrupts (who kicked what), dispels
   and purges, crowd control and CC breaks, deaths with a log of the last hits and heals, every cast
   per player, buff/debuff uptime, activity time, segments (current / overall / per fight / boss),
   reports to chat. Threat from the server protocol (TWThreat's `TWT_UDTSv4`, unverified on this
   server) with pull-aggro line and tank view. Sources: nampower events (casts, GUIDs, interrupts)
   where present, combat-log strings as fallback. Credit ShaguDPS for the parser; TWThreat code is
   not copied (no licence).
   RELEASE 1 DONE 19 Oct (not seen in game): combat-log strings only (no nampower yet, so no
   in-game probes were needed). modules/meters.lua: SPECS = GlobalStrings template name + kind
   (dmg heal miss interrupt cast start dispel death) + capture roles; templates sorted by fixed
   text length (longest first - "Your %s hits %s..." before "%s hits %s..."), anchored ^$,
   trailers (absorbed/resisted/blocked/vulnerability/glancing/crushing) stripped first. Event name
   picks the kinds tried (KindsFor). Segments: pfUI.meters.current / history (C.meters.history) /
   overall; a fight starts on the first tracked action while the group is in combat, ends 1 s after
   the group leaves combat, named after the enemy that took most damage. Effective heal = min(amount,
   missing HP of the target's unit). Interrupt "with" = the kicker's last spell within 1.5 s.
   Dispels = "X's Y is removed." credited to the last dispel-spell cast on X within 2 s (English
   dispel names via T[]). Casts = cast/perform lines + "begins to cast" + direct hits without a start.
   Deaths keep the last 15 hits/heals (15 s) with HP %. modules/meters-threat.lua: server protocol,
   warn at C.meters.threatwarn % of the pull point (110 melee / 130 range). modules/meters-window.lua:
   2 windows docked in the right chat via pfUI.thirdparty.meters:RegisterMeter (C.thirdparty.pfmeter /
   pfthreat .dock); first load sets C.thirdparty.showmeter = "1" once (C.meters.shown). Options:
   Meters > General / Threat. Offers to DisableAddOn ShaguDPS + TWThreat once (C.meters.asked).
   tests/globalstrings.lua = the client's combat templates (patch-5) for the offline tests.
   Not yet: nampower events, CC / buff uptime, saved fights across reload, multiple-window snapping.
6. Combat text. DONE 19 Oct (not seen in game). OctoBG's SCT.lua / SCTEvents.lua copied as
   modules/sct-engine.lua / sct-events.lua (headers, frame names and the area movers changed, the
   rest as in OctoBG - fix bugs in both or note it), running on modules/sct-core.lua = a stand-in
   for OctoBG's core (`pfUI.sctB`: B:On / B:Fire / B:Every / B:Print, B.db.sct, U.GuidOf, U.Panel,
   SpyData.Font). modules/sct.lua (module "sct"): settings `pfUI_config.sct` in REAL Lua values
   (booleans, numbers), copied once from OctoBGDB.sct (`fromOctoBG`), defaults filled; fires
   OBG_LOADED at load, OBG_INIT at PLAYER_LOGIN, OBG_ZONE on zone change; B.test while /moveui is
   open (sample text per area); `/pfui sct test|on|off`; options "Combat Text" > General, Scroll
   Areas, Nameplates, Crits & Sounds, Messages: Combat, Messages: Alerts, Text & Filters, built
   with `pfUI.gui.Native(get, onchange)` (true/false <-> "1"/"0", numbers, virtual key "rgb") and
   the new "slider" widget (values = { min, max, step }). Areas are pfUI movers
   pfCombatTextIncoming / Outgoing / Healing / Notes / Extra; a drop's x / y come from
   C.position (anchor + offsets), then C.position is cleared (x / y are the truth).
   Media: img\sct (burst.tga, Spy's four wavs, sounds\custom for the user's own).
   Profile strings now carry booleans (share.lua serialize / parse); strings without "sct" keep
   the importer's combat text. Same day, user: "totally moved over out of OBG" - OctoBG's SCT
   files and menu are deleted (OctoBG 2.2.0, not git): OctoBG\modules\SCTLink.lua forwards its
   alerts to pfUI.sct.CT:Notify and keeps the threat label's plate lookup and sounds; its threat
   page is Setup > Threat label. OctoBG's 94 combat text tests moved here as tests\sct.lua
   (events / clock go only to pfSCTCore + pfCombatTextContainer: Fire / Tick in that file);
   tests\globalstrings.lua also has the reward templates (honor, rep, skill, loot, money, extra
   attacks). /sctdisplay is pfUI's now (when SCT itself is not loaded).
7. Map styles (SexyMap). DONE 19 Oct (not seen in game), modules/minimap-style.lua on pfUI's
   minimap, settings C.mapstyle, options Minimap > Map Style / Buttons & Extras. Shapes: square
   (pfUI's img\minimap), round (the game's textures\MinimapMask), and img\minimap\mask-*.tga +
   outline-*.tga made by tools\MakeMinimapMasks.ps1 (rounded, rounder, squircle, octagon, diamond,
   corner-tl/tr/bl/br; white inside, clear outside, 4x4 samples). Border: pfUI frame (square only)
   / shape outline (colour or accent) / none. Three art layers from the game's spell textures
   (names checked against every MPQ's (listfile): AuraRune256/_A-D, Holy/Ice/Fire/Nature/InnerFire
   runes, DemonRune6/7, rings, glows...), size %, colour, ADD/BLEND, above (frame above Minimap) or
   below (level 0 child of the map), spin via 8-value SetTexCoord. Buttons tracking / mail /
   battlefield / addon-button toggle / clock: show | hover (fade while the mouse is over the map)
   | hide (alpha 0 + no mouse). Clock (local/server, 24 h per C.global.twentyfour), ping name
   (MINIMAP_PING arg1), auto zoom-out, opacity in / out of combat, 10 presets
   (`pfUI.minimap.ApplyPreset`). `pfUI.gui.RefreshPage(page)` re-reads a built page's controls.
   Not verified in game: the spell textures' look as minimap art, SetMaskTexture with a 32-bit
   TGA mask, MINIMAP_PING args, art layer stacking under pfUI's backdrop.
8. The user will add more addons "like this" into pfUI Octo.
   22 Oct 2026, action bars (Bartender4 as the model; Bartender4 is All Rights Reserved - the
   user's Bartender4-4.18.3.1.zip was read for its option list only, nothing copied):
   modules/actionbar-octo.lua (`pfUI.barsOcto`) hooks pfUI.bars.UpdateConfig and adds per bar
   scale / alpha / fadeto / vis_combat / vis_pet / vis_target / vis_stealth (C.bars.barN), button
   skins + icon zoom (C.bars.skin / zoom) and 6 looks. api.lua EnableAutohide fades to
   frame.fadeTo and back to frame.octoAlpha. modules/actionbar-options.lua: section "Action Bars"
   (General, Bars with a tab per bar, Buttons and text, Paging, Gryphons), pfUI's Actionbar
   category hidden; pinned preview = real bars on a mini screen (click = its tab, Shift + wheel =
   button size) + a sample button. Not seen in game. tests stub GetNumShapeshiftForms (the
   actionbar module now starts in the mock).
   22 Oct, effects (EllesmereUI's feature list as the model; its licence reserves all rights and
   much of its art is other artists', so nothing copied): page "Effects" (abeffects). In
   actionbar-octo.lua: hover / press looks (AB.STYLES, AB.Layer / AB.Paint; hover rides on pfUI's
   f.highlight, press on OnMouseDown/Up + keystate in OnClick, 3 s safety), proc glows (AB.GLOWS
   ants / pulse / shine / border + start burst; AB.REACTIVE icons while IsUsableAction, AB.PROCS
   buff icon -> spell icon; 5 Hz watcher), cooldown swipe (AB.CDSTYLES; hooks
   CooldownFrame_SetTimer via cd.octoButton; non-clock styles set cd.pfCooldownStyleAnimation = 0),
   empty slot fill (AB.SLOTS, on f.backdrop), equipped quality border (AB.Quality = scanning
   tooltip's name colour). Art from tools\MakePlateArt.ps1 -> img\bars. The preview's sample
   plays a 13 s loop of all of them; the note under it opens what it shows. Not seen in game;
   unverified: Model SetAlpha(0) hiding the clock, keystate on key presses, tooltip quality colour.
9. OctoBG's look for the whole options window (20 Oct, not seen in game). User (ElvUI screenshots +
   OctoBG's options): "copy Octo BGS style of UI and update PFUI into being my own addon", and
   "PLEASE GET SCROLLING COMBAT TEXT OPTION PANEL IT WAS IN OCTO BG" (the CreateConfig pages
   were not what they knew). Also: tree categories did not visibly fold/unfold for them.
   - modules/octo-widgets.lua (plain file, `pfUI.octoui.W`) = OctoBG's core\Widgets.lua: pages of
     folding cards, switches, sliders, dropdowns, Find index. Wider (body 700, card 668, half 326).
     Folded cards + Background in `pfUI_cache.octoui` (per account, not in profile strings).
     Fonts/textures copied from OctoBG into pfUI\fonts and img\octo (Roboto, Fira, Share, ...).
   - modules/octo-options.lua (module, right after gui) turns `pfUI.gui` itself into OctoBG's
     shell (so every pfUI.gui:Show / Hide / Reload keeps working): title row, quick bar (Move
     Frames, Keybinds, Install, Profiles, Background, Find a setting), topic list 196 wide (Octo
     sections first, then one folding section per pfUI category; one open at a time; wheel
     scrolls), page panel. pfUI's category areas are re-anchored onto the page panel, the old
     tree buttons reparented to a hidden frame (gui.lua still drives them; O:ShowLegacy shows
     areas directly, never via Click). Keys: "o:<page>" (Octo) / "l:<Category>[/<Page>]".
     `O:AddPage(group, key, label, build)`, `O:Open(key | category, page)`. Find searches W.index
     and gui.lua's searchDB (now `pfUI.gui.searchDB`). gui.lua calls `pfUI.gui.OnPageBuilt(page)`
     after Finish: O.SkinPage restyles pfUI's pages (cards, blue tick boxes, disc sliders with fill).
   - modules/sct-options.lua = OctoBG's SCTOptions.lua pages (ctgeneral, ctareas, ctplates,
     ctcrits, ctevents, ctfilters) almost verbatim; threat page stays in OctoBG. /sct opens them.
     The CreateConfig "Combat Text" category is gone from sct.lua.
   - Layout mode (unlock.lua): ElvUI boxes (`Paint`: see-through fill, blue edge + label; gold =
     Alt-click source), labels in words (`NiceLabel`). Clicks as ElvUI: left = nudge box, right =
     the frame's options (OpenConfigDialog -> O:Open; frame_configs gained RaidCluster, Meter%d,
     CombatText%a+ -> "ctareas"), middle = reset. Alt-click two boxes: `MatchSize` (unit frame /
     castbar width settings, height too between the same kind; meters width/height; else scale).
     `this.justDragged` (set on drop, cleared on mouse down) keeps the drop from counting as a click.
   - Raid frames: only pfRaidCluster is a mover, sized to the whole grid (raid.lua); individual
     pfRaidN movers are removed (old per-frame positions no longer apply). Healer layout centres
     the cluster with xpos 0. Not verified: a cluster saved with a TOP anchor shifts the grid down
     by its new height once.
   - Tests: tests\mock.lua keeps its own bookkeeping in `_parent` / `_kids` (pfUI uses .parent and
     .children on frames) and has a real SetParent.
   - Seen in game 20 Oct ("looking better"). Then: right-click on a box only closed layout mode
     and showed the window (frame_configs pointed at a "Group Frames" category upstream pfUI no
     longer has; gui OnShow also ended layout mode). Now `O:FindLegacy(cat, page)` matches names
     loosely (case, colour codes, punctuation; a page found in any category; a category's first
     page) and `pfUI.gui.keepLayout` keeps the boxes up while the page opens. User also: "use
     actual picture and logos of spells", "get rid of so much text", "sliders ... and numbers
     for accuracy": section icons (`O.ICONS`, every name checked in the MPQ listfile, scratchpad
     icons.txt), card / heading explanations moved into tooltips (W.Card text, W.Heading text ->
     "How it works"), `W.NumberBox` on every Octo slider (typed "40%" -> 0.4 for 0-1 values) and
     on pfUI's sliders, `O.NumberSlider` adds a slider beside every pfUI number field
     (`frame.numtype`, range guessed from the key name / value, typing past the end widens it).
   - Key Map (modules/keymap.lua, `pfUI.keymap`, /keymap /km; quick bar Keybinds = menu: original
     hover binding or Key Map). User's model: a retail "KeyMap" addon screenshot. A keyboard (UK /
     US / QWERTZ / AZERTY rows, F-keys, mouse 3-5 and wheel), layers base / SHIFT- / CTRL- / ALT-
     (click a modifier or layer button to lock, hold one to peek). Keys show the action button's
     icon (binding ACTIONBUTTONn / MULTIACTIONBARmBUTTONn -> slot as actionbar.lua: bar 1 = 0,
     MULTI1 = 60, MULTI2 = 48, MULTI3 = 24, MULTI4 = 36), or "SPELL x" / "MACRO x" bindings' icons,
     or the binding's name. Drop: action key -> PlaceAction(slot); else ClassicAPI GetCursorInfo +
     SetBindingSpell / Item / Macro (found as "Usage:" strings in ClassicAPI.dll - returns assumed
     retail-like, NOT verified); else a free action slot + SetBinding. Left-click pick up / move /
     swap, right-click unbind, Unbound abilities = bar slots with an action and no key. Layout and
     panel choice in pfUI_cache.octoui.keymap. Not verified in game at all.
   - Seen in game 20 Oct: Key Map works (icons on keys, Alt layer, unbound list). Slider fill
     did not follow the knob on stretched sliders (width from GetWidth); now `W.FillToThumb`
     anchors the fill's right edge to the thumb texture (all Octo, pfUI-page and number sliders).
   - Key Bindings (modules/keybinds.lua, `pfUI.keybinds`, /keybinds /kb; third entry of the
     Keybinds menu, "All bindings" on the Key Map). User asked for Blizzard's key binding list
     in our look, folding categories, a right-hand panel explaining things, pictures everywhere.
     GetNumBindings / GetBinding (HEADER_x rows start categories, name BINDING_HEADER_x; BLANK
     joins the previous one; headers from patch-4 Bindings.xml: MOVEMENT CHAT ACTIONBAR
     MULTIACTIONBAR TARGETING INTERFACE MISC CAMERA RAID_TARGET ITUNES_REMOTE), category icons +
     one-line explanations, action button rows show their spell (pfUI.keymap.Describe), raid mark
     rows the mark (UI-RaidTargetingIcons quarters). Key boxes: click then press (modifiers,
     BUTTON3-5, wheel); right-click clears; saved at once. Character specific = SaveBindings(2) /
     LoadBindings(1); Reset = LoadBindings(0). Fold state in pfUI_cache.octoui.kbFold.
     Seen in game 20 Oct: BLANK2 / BLANK3 headers showed as categories (now any HEADER_BLANK*
     joins the one before); categories now start folded (kbFold[id] == false = open).
   - Key Map side panel (user: "move the All bindings next to Unbound abilities ... make them
     both drag drops"): two tabs with icons (Unbound INV_Misc_Key_01 / All bindings
     INV_Misc_Book_09), the All tab = pfUI.keybinds.Read() categories folded in a scroll list
     (open state keymap.open). Our own drag (not the game cursor): a picture follows the mouse,
     on release `KM.KeyUnderMouse` (MouseIsOver over the key cells) -> `KM.Give` = SetBinding.
     Click a list item then a key works too (KM.ability / KM.command). The toolbar's All
     bindings button went; "Unbound" is now "Lists" (show / hide the panel). Not verified in game.
   - Not verified in game: the whole window, Roboto in it, disc slider thumbs on pfUI's pages,
     menus of pfUI dropdowns (parented to pfUI.gui) over the new panels, OnSizeChanged on sliders.
10. Plater-style nameplates (user 20 Oct: "our own version of this name plate addon ... with all
   features and art work"). Spec and phases: docs\plates-spec.md. Plater is All Rights Reserved:
   no code or texture of it is copied; the user's Plater v661 zip was read for setting names only.
   PHASE 1 DONE 21 Oct (not seen in game): modules/plates.lua wraps pfUI.nameplates (OnConfigChange
   / OnDataChanged / OnUpdate / UpdateConfig; nameplates.lua untouched), parts in `plate.octo`.
   Settings C.plates. Art: tools\MakePlateArt.ps1 -> img\plates (bars, arrow, chevron, corner,
   underglow, spark, star, skull, tick). modules/plates-options.lua = Octo section "Nameplates"
   (7 pages, all of pfUI's nameplate settings too); `O.replaced[name]` hides pfUI's own category
   from the topic list and Find. Plater look applied once at first load. Next: phase 2 auras.
   Seen in game 21 Oct, then: looks switched plates off (pfUI's UpdateConfig re-applies
   showhostile; the V key does not change it) - P.Refresh now skips SetGameVariables, only the
   Show tick boxes call it (P.ApplyShow). 8 looks (Plater, Slim, ElvUI, Big and bold, Neon,
   Classic, PvP, pfUI) incl. border skins (C.plates.skin: pfui shadow thick accent neon gold),
   the matching one lit (P.CurrentLook). Preview card (OctoBG's "Icons on nameplates" box) on
   most pages: P.AttachPreview runs pfUI's real OnCreate on 4 fake game plates (`game.preview`
   overrides state / target / combat / mark; own OnUpdate, levels raised above the box);
   "Test on real nameplates" = P.Test(60): pretend threat states + casts on every plate.
   SuperWoW check = P.SuperWoW() (SUPERWOW_VERSION): pfUI's superwow_active is only set at the
   first cast event. Mock: frame level kept in `_level` (pfUI plates have a .level text).
   Seen in game 21 Oct: preview and looks work. PHASE 2 auras DONE 21 Oct (not seen in game):
   modules/plates-auras.lua, see docs\plates-spec.md section 4; options page "Auras" (was
   Debuffs). Mock gained UnitBuff / UnitDebuff (Mock.units[guid].buffs / .debuffs) and
   Get/SetStatusBarColor; run.lua stubs GetDifficultyColor. Note: the map style test leaves a
   global UnitName that only knows party1 - later tests must answer GUIDs themselves.
   Seen in game 21 Oct: auras work. PHASE 3 DONE 21 Oct (not seen in game): modules/plates-lists.lua
   (NPC / cast colours and names, quest marks from pfQuest or the quest log, class / pet icons,
   auto toggles, tank "taking"), pages "Colours and names" and "Quests, icons and auto" (9 pages
   now). Spec section 5. tests\globalstrings.lua gained QUEST_MONSTERS_KILLED. Next: phase 4.
   22 Oct: combat text preview, modules/sct-preview.lua (`CT.Mini(box, onPick)`): a scaled copy of
   the screen, each area box at its x / y, a mock enemy plate, sample texts moved by CT.MOVE with the
   area's anim / dir / size / crit style / time / speed. Area boxes: click = its tab on Scroll areas
   (sct-options `AREA.cur`), drag = moves the real area (CT:PlaceArea), Shift + wheel = text size,
   right-click = default place. On Basics, Scroll areas, Nameplates, Crits.
   22 Oct: combat text pages regrouped: General (looks: CT.LOOKS / ApplyLook / CurrentLook, lit
   button; preview; look of all text with new db.scale / fade / maxLive in sct-engine; where your
   damage goes; game numbers), Scroll areas, Nameplates, Crits, Messages and sounds (grid, then
   warnings and sounds), Text and filters.
   tests\mock.lua: SetVertexColor / SetTextColor take numeric strings (as the client does).

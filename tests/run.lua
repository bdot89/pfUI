-- Offline run of pfUI Octo through the mock client: pfUI.lua, env, compat,
-- api and libs load, the saved config is built, and every module and skin is
-- started one by one; a module that errors is reported (most need far more
-- of the client than the mock has, so only those in MUST_LOAD fail the run).
--   powershell -ExecutionPolicy Bypass -File tests\run.ps1

local DIR = "."
dofile(DIR .. "/tests/mock.lua")
dofile(DIR .. "/tests/globalstrings.lua")

-- (OctoBG loads after pfUI in the user's game: its saved settings arrive later, see phase 6)

local fails, checks = 0, 0
local function ok(cond, what)
  checks = checks + 1
  if not cond then
    fails = fails + 1
    print("FAIL: " .. what)
  end
end

-- ---------------------------------------------------------------- pfUI stubs

-- 1.12's global aliases of the string / table / math libraries
strfind, strlower, strupper, strsub, strlen, strrep = string.find, string.lower, string.upper, string.sub, string.len, string.rep
format, gsub, strbyte, strchar = string.format, string.gsub, string.byte, string.char
tinsert, tremove, getn, sort = table.insert, table.remove, table.getn, table.sort
floor, ceil, abs, min, max, mod, sqrt = math.floor, math.ceil, math.abs, math.min, math.max, math.mod, math.sqrt
function strtrim(s) return (string.gsub(s or "", "^%s*(.-)%s*$", "%1")) end
MAX_PARTY_MEMBERS, MAX_RAID_MEMBERS, NUM_CHAT_WINDOWS = 4, 40, 7
NUM_ACTIONBAR_BUTTONS, NUM_SHAPESHIFT_SLOTS, NUM_PET_ACTION_SLOTS = 12, 10, 10

function GetAddOnInfo(name)
  if name == "pfUI" then return "pfUI", "|cff33ffccpf|cffffffffUI |cff8888ccOcto", "", 1, 1 end
  return nil
end
function GetAddOnMetadata(name, field)
  if name ~= "pfUI" then return nil end
  for line in io.lines(DIR .. "/pfUI.toc") do
    local _, _, k, v = string.find(line, "^## ([%w%-]+): (.*)$")
    if k == field then return v end
  end
end
function GetBuildInfo() return "1.12.1", "5875", "Sep 19 2006", 11200 end
function GetLocale() return "enUS" end
local mockUnitName = UnitName
function UnitName(u) if u == "player" then return "Tester" end return mockUnitName(u) end
function GetRealmName() return "OctoWoW" end
function GetCVar(n) return Mock.cvars and Mock.cvars[n] or "0" end
Mock.cvars = { gxResolution = "1920x1080", uiScale = "1", useUiScale = "1" }
function setglobal(k, v) _G[k] = v end
function GetScreenWidth() return 1920 end
function GetScreenHeight() return 1080 end
function GetNumAddOns() return 1 end
function debugstack() return "" end
function GetGameTime() return 13, 37 end
-- template children the client creates with "$parent" names
local TEMPLATE_CHILDREN = {
  UIDropDownMenuTemplate = { "Button", "Text", "Left", "Middle", "Right" },
  UICheckButtonTemplate = { "Text" },
}
local createFrame = CreateFrame
function CreateFrame(kind, name, parent, template)
  local f = createFrame(kind, name, parent, template)
  if name and template and TEMPLATE_CHILDREN[template] then
    for _, child in ipairs(TEMPLATE_CHILDREN[template]) do
      Mock.New(child == "Button" and "Button" or "FontString", name .. child, f)
    end
  end
  if template == "OptionsSliderTemplate" then f:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal") end
  return f
end
-- the client's cooldown animation script (nameplate debuff icons use it)
function CooldownFrame_OnUpdateModel() end
-- shapeshift forms (the action bars' stance bar asks)
function GetNumShapeshiftForms() return 0 end
-- the client's level colour (unit frames with level colours)
function GetDifficultyColor() return { r = 1, g = .82, b = 0 } end
-- the client's colour tables (FrameXML)
ManaBarColor = { [0] = { r = 0, g = 0, b = 1 }, [1] = { r = 1, g = 0, b = 0 }, [2] = { r = 1, g = .5, b = .25 },
  [3] = { r = 1, g = 1, b = 0 }, [4] = { r = 0, g = 1, b = 1 } }
-- (1.12 has no class icon table: pfUI's env/tables.lua makes one, unless
-- the mock's ALL_CAPS stand-in is there first)
CLASS_ICON_TCOORDS = { WARRIOR = { 0, .25, 0, .25 }, MAGE = { .25, .49609375, 0, .25 }, ROGUE = { .49609375, .7421875, 0, .25 },
  DRUID = { .7421875, .98828125, 0, .25 }, HUNTER = { 0, .25, .25, .5 }, SHAMAN = { .25, .49609375, .25, .5 },
  PRIEST = { .49609375, .7421875, .25, .5 }, WARLOCK = { .7421875, .98828125, .25, .5 }, PALADIN = { 0, .25, .5, .75 } }
-- unit state the unit frame extras read
function UnitIsConnected(u) return 1 end
function UnitIsDead(u) return UnitIsDeadOrGhost(u) end
function UnitIsFriend(a, u) return not UnitIsEnemy(a, u) end
function UnitClassification(u) local e = Mock.units[u] return e and e.classification or "normal" end
UnitReactionColor = {}
for i = 1, 8 do UnitReactionColor[i] = { r = i < 4 and 1 or 0, g = i > 3 and 1 or 0, b = 0 } end
-- the client's debuff type colours (unit frame debuff borders)
DebuffTypeColor = { none = { r = .8, g = 0, b = 0 }, Magic = { r = .2, g = .6, b = 1 }, Curse = { r = .6, g = 0, b = 1 },
  Disease = { r = .6, g = .4, b = 0 }, Poison = { r = 0, g = .6, b = 0 } }
-- the minimap's border parts are textures in the client (no GetScale on 1.12)
for _, n in ipairs({ "MinimapBorderTop", "MiniMapMailBorder", "MiniMapBattlefieldBorder" }) do Mock.New("Texture", n) end
function UIDropDownMenu_SetWidth() end
function UIDropDownMenu_SetButtonWidth() end
function UIDropDownMenu_JustifyText() end
function UIDropDownMenu_SetSelectedID() end
function UIDropDownMenu_SetText() end
function UIDropDownMenu_Initialize() end
function UIDropDownMenu_AddButton() end
ITEM_QUALITY_COLORS = {}
for i = 0, 6 do ITEM_QUALITY_COLORS[i] = { r = 1, g = 1, b = 1, hex = "|cffffffff" } end
table.setn(ITEM_QUALITY_COLORS, 7)
FONT_COLOR_CODE_CLOSE = "|r"

-- modules that must start cleanly (the octo ones, as they are added)
local MUST_LOAD = { "unlock", "gui", "firstrun", "share", "meters", "meters-threat", "meters-window", "sct", "octo-options", "sct-options", "keymap", "keybinds",
  "nameplates", "plates", "plates-options", "sct-preview", "actionbar", "actionbar-octo", "actionbar-options",
  "unitframes-options", "unitframes-octo", "castbar-options", "meters-options", "meters-breakdown", "meters-test", "plates-fx", "chat-options", "chat-plus", "chat-whispers", "swing", "swing-options",
  "minimap", "minimap-style", "minimap-options", "buffs-options", "gear", "gear-sheet", "gear-slots", "gear-options", "gear-events" }

-- ---------------------------------------------------------------- load

local files = Mock.Files(DIR, "pfUI.toc")
ok(table.getn(files) > 100, "toc lists pfUI's files (got " .. table.getn(files) .. ")")
-- Lua 5.0 reads an unknown escape like "\+" as "+"; LuaJIT refuses it
local function load50(path)
  local h = io.open(path, "rb")
  local src = h:read("*a")
  h:close()
  src = string.gsub(src, "\\(.)", function(c)
    if string.find(c, "^[abfnrtv\\\"'%d\r\n%[%]]$") then return "\\" .. c end
    return c
  end)
  return loadstring(src, "@" .. path)
end

-- pfUI.lua swaps the global error() for a chat printer; keep the real one
local realError = error
function seterrorhandler(fn) Mock.errorhandler = fn end

-- Any other CamelCase global the client would have (SystemFont, ActionButton1,
-- ClearTutorials...) becomes a stand-in widget that can also be called.
-- Names pfUI tests to detect an API or client build stay nil.
local NOT_IN_CLIENT = {
  UnitCastingInfo = 1, UnitChannelInfo = 1, GetUnitGUID = 0, SUPERWOW_VERSION = 1, SpellInfo = 0,
  UnitBuff = 0, GetNampowerVersion = 0, C_Timer = 1, GetItemStats = 1, CombatLogGetCurrentEventInfo = 1,
  GetSpecialization = 1, InCombatLockdown = 1, UnitXP = 0, QueueSpellByName = 1, Bagnon = 1,
  -- Blizzard_CombatText (LoadOnDemand) and SuperAPI exist only once loaded
  CombatText = 1, CombatText_AddMessage = 1, CombatText_UpdateDisplayedMessages = 1, SuperAPI = 1,
}
setmetatable(_G, { __index = function(t, k)
  if type(k) ~= "string" or NOT_IN_CLIENT[k] then return nil end
  -- FrameXML constants: counts (loop limits) are small numbers, the rest are
  -- global strings such as ERR_* / LOOT_* patterns
  if string.find(k, "^[A-Z][A-Z0-9_]+$") then
    if string.find(k, "VERSION") then return nil end
    local v = k
    if string.find(k, "NUM") or string.find(k, "MAX") or string.find(k, "DISPLAY") or string.find(k, "PER_")
      or string.find(k, "COUNT") or string.find(k, "SHOWN") then v = 2 end
    rawset(t, k, v)
    return v
  end
  if not string.find(k, "^[A-Z][a-z]") then return nil end
  if string.find(k, "^pf") then return nil end
  local w = Mock.New("Frame", k)
  rawset(t, k, w)
  return w
end })
getmetatable(Mock.New("Frame")).__call = function() return nil end
function geterrorhandler() return Mock.errorhandler or print end

for _, f in ipairs(files) do
  local fn, err = load50(DIR .. "/" .. f)
  ok(fn, "parses: " .. f .. " " .. tostring(err))
  if fn then
    local good, e = pcall(fn)
    ok(good, "runs: " .. f .. " " .. tostring(e))
  end
end
error = realError

ok(pfUI and pfUI.version, "pfUI table exists")

-- pfUI's loader (pfUI.lua Start) reports a module that fails through the
-- error handler and goes on with the rest: note which module it was
local failedModules = {}
local LoadModule, LoadSkin = pfUI.LoadModule, pfUI.LoadSkin
local starting
local pfErrorHandler = Mock.errorhandler
seterrorhandler(function(msg)
  if starting then failedModules[starting] = msg end
end)
function pfUI:LoadModule(m)
  starting = m
  LoadModule(self, m)
  starting = nil
end
function pfUI:LoadSkin(s)
  starting = "skin_" .. s
  LoadSkin(self, s)
  starting = nil
end

Mock.Fire("ADDON_LOADED", "pfUI")
seterrorhandler(pfErrorHandler)
ok(Mock.errorhandler == pfErrorHandler, "pfUI's error handler back")
ok(pfUI.bootup == nil, "bootup finished")
ok(pfUI.version.string == "5.5.4", "upstream version read from the toc (" .. tostring(pfUI.version.string) .. ")")
ok(pfUI.version.octo == "1.0.0", "octo version read from X-Octo-Version (" .. tostring(pfUI.version.octo) .. ")")
ok(pfUI_config and pfUI_config.appearance, "config built")

-- (every colour picker the Octo pages make, for the colour check near the end)
if pfUI.octoui and pfUI.octoui.W then
  OCTO_COLOR_GETS = {}
  local W0 = pfUI.octoui.W
  local made = W0.Color
  W0.Color = function(p, label, desc, get, set)
    table.insert(OCTO_COLOR_GETS, { get = get, label = label })
    return made(p, label, desc, get, set)
  end
end

-- ---------------------------------------------------------------- phase 1: Octo look
local look = pfUI.octo.look
ok(pfUI_profiles["Octo"], "Octo profile registered")
ok(pfUI_config.appearance.border.default == "1", "fresh install uses the Octo profile (1px border)")
ok(pfUI_config.unitframes.player.bartexture == "Interface\\AddOns\\pfUI\\img\\bar_elvui", "fresh install: ElvUI bar texture")
ok(pfUI_config.appearance.accent.mode == "class", "accent default is class colour")
ok(pfUI_config.unitframes.player.width ~= nil, "Octo profile keeps a full config (defaults filled)")

-- the look only touches appearance keys: an existing layout keeps its positions/sizes
local old = { unitframes = { player = { width = "300", bartexture = "x" } }, appearance = { border = { default = "3" } },
              position = { pfPlayer = { xpos = 10, ypos = 20 } } }
pfUI.octo.ApplyLook(old)
ok(old.unitframes.player.width == "300", "ApplyLook keeps sizes")
ok(old.position.pfPlayer.xpos == 10, "ApplyLook keeps positions")
ok(old.unitframes.player.bartexture == "Interface\\AddOns\\pfUI\\img\\bar_elvui", "ApplyLook sets the bar texture")
ok(old.appearance.border.default == "1", "ApplyLook sets 1px borders")
for _, path in pairs({ look.global.font_default, look.global.font_unit, look.unitframes.player.bartexture }) do
  local file = string.gsub(string.gsub(path, "^Interface\\AddOns\\pfUI\\", ""), "\\", "/")
  local h = io.open(DIR .. "/" .. file, "rb") or io.open(DIR .. "/" .. file .. ".tga", "rb")
  ok(h, "look file exists: " .. file)
  if h then h:close() end
end

-- accent colour
local cr, cg, cb = pfUI.api.GetAccentColor()
ok(cr == RAID_CLASS_COLORS[select(2, UnitClass("player"))].r, "accent = class colour by default")
pfUI_config.appearance.accent.mode = "custom"
pfUI_config.appearance.accent.color = "0.1,0.2,0.3,1"
cr, cg, cb = pfUI.api.GetAccentColor()
ok(cr == 0.1 and cg == 0.2 and cb == 0.3, "custom accent colour")
pfUI_config.appearance.accent.mode = "class"

-- ---------------------------------------------------------------- phase 2: layout mode
ok(SlashCmdList.PFMOVEUI and SLASH_PFMOVEUI1 == "/moveui", "/moveui registered")
local U = pfUI.unlock
if U and U.bar then
  -- pfUI's own frames need more of the client than the mock has: use two plain ones
  local realMovables = pfUI.movables
  pfUI.movables = { pfTestOne = CreateFrame("Frame", "pfTestOne", UIParent), pfTestTwo = CreateFrame("Frame", "pfTestTwo", UIParent) }
  pfUI.gui:Hide()
  SlashCmdList.PFMOVEUI("")
  ok(U:IsShown(), "/moveui opens layout mode")
  ok(U.grids and U.grids[128], "grid drawn at the default size")
  ok(pfUI_config.unlock.helpseen == "1", "help shown once")
  ok(U.bar.snap:GetChecked(), "snap box ticked by default")
  U.bar.gridless:GetScript("OnClick")()
  ok(pfUI_config.unlock.gridsize == "64", "grid '-' makes bigger cells (" .. pfUI_config.unlock.gridsize .. ")")
  ok(U.grids[64] and U.grids[64]:IsShown() and not U.grids[128]:IsShown(), "only the new grid shows")
  U.bar.gridmore:GetScript("OnClick")()
  ok(pfUI_config.unlock.gridsize == "128", "grid '+' goes back")

  -- snapping: two frames with real geometry (UIParent units, scale 1)
  local function Box(name, l, b, w, h)
    local f = CreateFrame("Frame", name, UIParent)
    f.GetLeft = function() return l end
    f.GetRight = function() return l + w end
    f.GetBottom = function() return b end
    f.GetTop = function() return b + h end
    f.GetEffectiveScale = function() return 1 end
    return f
  end
  local saved = pfUI.movables
  local a = Box("pfTestA", 403, 300, 100, 40)   -- 3 px right of B's right edge
  local b = Box("pfTestB", 200, 500, 200, 40)
  pfUI.movables = { pfTestA = a, pfTestB = b }
  U.selection = { a }
  -- snapping uses the outer edges (frame + border) so the boxes sit flush
  local _, bd = pfUI.api.GetBorderSize()
  local function near(v, want) return v and abs(v - want) < .001 end
  local dx, dy, xline, yline = U.GetSnap(a)
  ok(near(dx, -3 + 2*bd) and near(xline, 400 + bd), "snaps A's outer left onto B's outer right (dx " .. tostring(dx) .. ")")
  -- centre: A centred 5 px off the screen's vertical centre line
  a = Box("pfTestA", 1920/2 - 50 + 5, 123, 100, 40)
  pfUI.movables = { pfTestA = a }
  U.selection = { a }
  dx, dy, xline = U.GetSnap(a)
  ok(dx == -5 and xline == 960, "snaps to the screen centre (dx " .. tostring(dx) .. ")")
  Mock.alt = true
  ok(U.GetSnap(a) == nil, "Alt turns snapping off")
  Mock.alt = nil
  pfUI_config.unlock.snap = "0"
  ok(U.GetSnap(a) == nil, "Snap box off turns snapping off")
  pfUI_config.unlock.snap = "1"
  -- a full drag and drop: the box's edges never change after SetPoint, as
  -- when the client reports positions only on the next screen update. The
  -- cursor moves 2 px left; the snap pulls A the rest of the way onto B.
  a = Box("pfTestA", 403, 300, 100, 40)
  b = Box("pfTestB", 200, 300, 200, 40)
  a:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 403, -740)
  pfUI.movables = { pfTestOne = pfTestOne, pfTestTwo = pfTestTwo }
  U:Hide()
  pfUI.movables = { pfTestA = a, pfTestB = b }
  U:Show()
  ok(a.drag, "drag box for the test frame")
  if a.drag then
    pfUI_config.position.pfTestA = nil
    Mock.cx, Mock.cy = 500, 500
    Mock.Run(a.drag, "OnDragStart")
    Mock.cx = 498
    Mock.Run(a.drag, "OnUpdate")
    -- while dragging: A is already placed on the snap (inner left = 400 + 2*border)
    local p, _, _, x, y = a:GetPoint()
    ok(p == "BOTTOMLEFT" and near(x, 400 + 2*bd) and near(y, 300), "pulled onto B while dragging (x " .. tostring(x) .. ")")
    ok(U.guides and U.guides.x:IsShown(), "guide line shows")
    Mock.Run(a.drag, "OnDragStop")
    ok(not U.guides.x:IsShown(), "guide line gone after the drop")
    local pos = pfUI_config.position.pfTestA
    ok(pos and pos.anchor == "BOTTOMLEFT", "anchor from the screen third (" .. tostring(pos and pos.anchor) .. ")")
    ok(pos and pos.xpos == pfUI.api.round(400 + 2*bd) and pos.ypos == 300, "saved where it snapped (" .. tostring(pos and pos.xpos) .. "," .. tostring(pos and pos.ypos) .. ")")
    -- Alt: no pull
    pfUI_config.position.pfTestA = nil
    Mock.cx = 500
    Mock.Run(a.drag, "OnDragStart")
    Mock.alt = true
    Mock.cx = 498
    Mock.Run(a.drag, "OnUpdate")
    Mock.Run(a.drag, "OnDragStop")
    Mock.alt = nil
    pos = pfUI_config.position.pfTestA
    ok(pos and pos.xpos == 401, "Alt drag lands where dropped (" .. tostring(pos and pos.xpos) .. ")")
  end
  U:Hide()
  U.selection = {}
  pfUI.movables = { pfTestOne = pfTestOne, pfTestTwo = pfTestTwo }
  U:Show()

  ok(pfTestOne.drag and pfTestOne.drag:IsShown(), "movers get a drag box")
  ok(pfTestOne.drag.text.text == "Test One", "box labels read as words (" .. tostring(pfTestOne.drag.text.text) .. ")")

  -- octo: left-click = nudge box, Alt-click two boxes = same size
  Mock.Run(pfTestOne.drag, "OnClick", "LeftButton")
  ok(U.dock:IsShown() and U.dock.parent == pfTestOne.drag, "left-click opens the nudge box")
  Mock.Run(pfTestOne.drag, "OnClick", "LeftButton")
  ok(not U.dock:IsShown(), "left-click again closes it")
  pfTestOne:SetWidth(240) pfTestOne:SetHeight(30) pfTestOne:SetScale(1)
  pfTestTwo:SetWidth(120) pfTestTwo:SetHeight(30) pfTestTwo:SetScale(1)
  Mock.alt = true
  Mock.Run(pfTestOne.drag, "OnClick", "LeftButton")
  Mock.Run(pfTestTwo.drag, "OnClick", "LeftButton")
  Mock.alt = nil
  local sc = pfUI_config.position.pfTestTwo and pfUI_config.position.pfTestTwo.scale
  ok(sc == 2, "Alt-click: the second box is scaled to the first one's width (" .. tostring(sc) .. ")")
  -- a unit frame and a castbar: the width goes into the castbar's setting
  local pl = CreateFrame("Frame", "pfPlayer", UIParent)
  local cb = CreateFrame("Frame", "pfPlayerCastbar", UIParent)
  pl:SetWidth(230) pl:SetHeight(46) cb:SetWidth(180) cb:SetHeight(16)
  pfUI.movables = { pfPlayer = pl, pfPlayerCastbar = cb }
  U:Hide() U:Show()
  local oldw = pfUI_config.castbar.player.width
  Mock.alt = true
  Mock.Run(pl.drag, "OnClick", "LeftButton")
  Mock.Run(cb.drag, "OnClick", "LeftButton")
  Mock.alt = nil
  ok(pfUI_config.castbar.player.width == "230" and cb:GetWidth() == 230, "Alt-click: player castbar gets the player frame's width (" .. tostring(pfUI_config.castbar.player.width) .. ")")
  pfUI_config.castbar.player.width = oldw
  -- right-click: the frame's options in the options window
  Mock.Run(pl.drag, "OnClick", "RightButton")
  local O = pfUI.octoui and pfUI.octoui.Options
  ok(pfUI.gui:IsShown() and O and O.current == "o:ufframes" and pfUI.ufOcto and pfUI.ufOcto.cur == "player",
    "right-click opens the frame's options on its tab (" .. tostring(O and O.current) .. ")")
  pfUI.gui:Hide()
  _G.pfPlayer, _G.pfPlayerCastbar = nil, nil
  pfUI.movables = { pfTestOne = pfTestOne, pfTestTwo = pfTestTwo }
  U:Show()
  U.bar.done:GetScript("OnClick")()
  ok(not U:IsShown(), "Done leaves layout mode")
  ok(not pfUI.gui:IsShown(), "options window stays closed after /moveui")
  pfUI.movables = realMovables
end

-- ---------------------------------------------------------------- phase 3: profile strings
local S = pfUI.share
ok(S and S.parse, "share module exposes its parser")
if S then
  local src = { appearance = { border = { color = "0,0,0,1", default = "1" } }, unitframes = { player = { width = "250" } },
                global = { font_size = "13", note = 'a "quoted" \\ path' }, numbers = { a = 1.5, b = -2 }, flags = { on = true, off = false } }
  local text = S.serialize(src, nil, "pfUI_config", {})
  local back, err = S.parse(text)
  ok(back, "parses its own export: " .. tostring(err))
  if back then
    ok(back.appearance.border.default == "1" and back.unitframes.player.width == "250", "round trip keeps values")
    ok(back.numbers.a == 1.5 and back.numbers.b == -2, "round trip keeps numbers")
    ok(back.flags and back.flags.on == true and back.flags.off == false, "round trip keeps true / false")
    ok(back.global.note == 'a "quoted" \\ path', "round trip keeps quotes and backslashes (" .. tostring(back.global.note) .. ")")
  end
  -- through compression and base64, as /export shows it
  local encoded = S.enc(S.compress(text))
  local decoded = S.decompress(S.dec(encoded))
  ok(S.decompress(S.compress(text)) == text, "compress round trip")
  ok(S.dec(S.enc("hello world, pfUI!")) == "hello world, pfUI!", "base64 round trip")
  ok(decoded == text, "compress + base64 round trip")
  if decoded ~= text and os.getenv("PFUI_TEST_VERBOSE") then
    local c = S.compress(text)
    local d = S.dec(S.enc(c))
    print("  compressed " .. string.len(c) .. " bytes, after base64 " .. string.len(d or "") .. ", equal: " .. tostring(c == d))
    for i = 1, string.len(c) do
      if string.sub(c, i, i) ~= string.sub(d or "", i, i) then
        print("  first difference at byte " .. i .. ": " .. string.byte(c, i) .. " vs " .. tostring(string.byte(d or "", i)))
        break
      end
    end
  end

  -- code is refused, never run
  _G.octo_pwned = nil
  local evil = 'pfUI_config = {\n  ["a"] = "1",\n}\nocto_pwned = true\n'
  ok(S.parse(evil) == nil, "refuses code after the table")
  ok(S.parse('pfUI_config = {\n  ["a"] = os.exit(),\n}') == nil, "refuses a function call as a value")
  ok(S.parse('pfUI_config = {\n  ["a"] = ("x"):rep(9),\n}') == nil, "refuses an expression")
  ok(S.parse('pfUI_config = {\n  ["a"] = {\n') == nil, "refuses an unfinished table")
  ok(_G.octo_pwned == nil, "nothing ran")

  -- preview counts changed values per section
  local list = S.preview({ appearance = { border = { color = "1,1,1,1", default = "1" } } },
                         { appearance = { border = { color = "0,0,0,1", default = "1" } } })
  ok(table.getn(list) == 1 and list[1][1] == "appearance" and list[1][2] == 1, "preview: 1 change in appearance")

  -- "Ignore Layout" strings keep the importer's positions
  local before = pfUI_config
  pfUI_config.position = { pfPlayer = { xpos = 1, ypos = 2 } }
  S.import({ appearance = { border = { color = "1,0,0,1" } } })
  ok(pfUI_config.position and pfUI_config.position.pfPlayer and pfUI_config.position.pfPlayer.xpos == 1, "import keeps positions when the string has none")
  ok(pfUI_config.appearance.border.color == "1,0,0,1", "import applies the string")
  ok(pfUI_config.unitframes and pfUI_config.unitframes.player, "import fills defaults")
  S.import({ appearance = {}, position = { pfTarget = { xpos = 5, ypos = 6 } } })
  ok(pfUI_config.position.pfTarget and not pfUI_config.position.pfPlayer, "import takes the string's positions when it has them")
  _G.pfUI_config = before
  pfUI:LoadConfig()

  -- the window: paste the encoded string, Import is enabled
  if pfShare then
    pfShare:Show()
    pfShare.scroll.text:SetText(encoded)
    local t, e = pfShare.GetImport()
    ok(t and t.unitframes.player.width == "250", "window reads a pasted encoded string: " .. tostring(e))
    pfShare.scroll.text:SetText("print('hi')")
    ok(pfShare.GetImport() == nil, "window refuses Lua code")
    pfShare:Hide()
  end
end

-- ---------------------------------------------------------------- phase 3: installer
local FR = pfUI.firstrun
ok(FR and FR.steps and table.getn(FR.steps) == 8, "installer has 8 steps (" .. (FR and table.getn(FR.steps) or 0) .. ")")
if FR then
  -- the steps' actions need the real client: count them instead
  local did = {}
  local realCVars = pfUI.SetupCVars
  pfUI.SetupCVars = function() did.cvars = true end
  pfUI.chat = pfUI.chat or {}
  pfUI.chat.SetupRightChat = function() did.right = true end
  pfUI.chat.SetupPositions = function() did.positions = true end
  pfUI.chat.SetupChannels = function() did.channels = true end
  _G.pfUI_init = {}
  local shown = {}
  for i = 1, 8 do
    FR:NextStep()
    -- the page on screen is the newest shown frame with a .next button
    local page
    for _, f in ipairs(Mock.frames) do
      if f.next and f.prev and f:IsShown() then page = f end
    end
    if not page then break end
    table.insert(shown, page.name)
    page.next:GetScript("OnClick")()
  end
  ok(table.getn(shown) == 8, "Next walks through every step (" .. table.concat(shown, ",") .. ")")
  ok(pfUI_init.finalize, "all steps marked done")
  ok(did.cvars and did.right and did.positions and did.channels, "ticked steps ran their setup")
  pfUI.SetupCVars = realCVars

  -- Previous goes back one step
  _G.pfUI_init = { init = true, profile = true }
  FR:NextStep()
  local page
  for _, f in ipairs(Mock.frames) do if f.next and f.prev and f:IsShown() then page = f end end
  ok(page and page.name == "layout", "resumes at the first unfinished step")
  if page then page.prev:GetScript("OnClick")() end
  page = nil
  for _, f in ipairs(Mock.frames) do if f.next and f.prev and f:IsShown() then page = f end end
  ok(page and page.name == "profile", "Previous goes back to the profile step")
  if page then page.skip:GetScript("OnClick")() end
  ok(pfUI_init.chat_channels and pfUI_init.finalize, "Skip marks every step done")

  -- healer layout centres the raid frames, DPS resets them
  FR.SetRaidLayout("HEALER")
  ok(pfUI_config.position.pfRaidCluster and pfUI_config.position.pfRaidCluster.anchor == "BOTTOM", "healer layout moves the raid frames to the middle")
  FR.SetRaidLayout("DPS")
  ok(pfUI_config.position.pfRaidCluster == nil, "tank/DPS layout resets them")

  -- /pfui install restarts it
  SlashCmdList.PFUI("install")
  ok(not pfUI_init.init, "/pfui install starts over")
  _G.pfUI_init = { init = true, profile = true, layout = true, cvars = true, chat_right = true, chat_position = true, chat_channels = true, finalize = true }
end

-- ---------------------------------------------------------------- phase 5: meters
local ME = pfUI.meters
ok(ME and ME.specs, "meters loaded")
if ME then
  ok(table.getn(ME.specs) >= 110, "combat log templates found (" .. table.getn(ME.specs) .. ")")

  -- reading single lines
  local function read(ev, msg)
    local r = ME.Read(ev, msg)
    if not r then return {} end
    local c = {}
    for k, v in pairs(r) do c[k] = v end
    return c
  end
  local r = read("CHAT_MSG_COMBAT_SELF_HITS", "You hit Hogger for 120.")
  ok(r.kind == "dmg" and r.src == "Tester" and r.tgt == "Hogger" and r.amt == 120 and not r.crit, "melee hit read")
  r = read("CHAT_MSG_COMBAT_SELF_HITS", "You crit Hogger for 240. (glancing)")
  ok(r.kind == "dmg" and r.crit and r.amt == 240 and r.glancing, "melee crit with a trailer read")
  r = read("CHAT_MSG_SPELL_SELF_DAMAGE", "Your Fireball hits Hogger for 300 Fire damage. (40 resisted)")
  ok(r.kind == "dmg" and r.spl == "Fireball" and r.amt == 300 and r.sch == "Fire", "spell hit read (" .. tostring(r.spl) .. ")")
  r = read("CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE", "Hogger suffers 50 Shadow damage from your Shadow Word: Pain.")
  ok(r.kind == "dmg" and r.dot and r.tgt == "Hogger" and r.spl == "Shadow Word: Pain", "damage over time read")
  r = read("CHAT_MSG_SPELL_SELF_DAMAGE", "You interrupt Kobold Geomancer's Fireball.")
  ok(r.kind == "interrupt" and r.tgt == "Kobold Geomancer" and r.spl == "Fireball", "interrupt read")
  r = read("CHAT_MSG_COMBAT_CREATURE_VS_SELF_MISSES", "Hogger attacks. You dodge.")
  ok(r.kind == "miss" and r.how == "dodge" and r.src == "Hogger" and r.tgt == "Tester", "dodge read")
  r = read("CHAT_MSG_SPELL_SELF_DAMAGE", "Your Frostbolt was resisted by Hogger.")
  ok(r.kind == "miss" and r.how == "resist" and r.spl == "Frostbolt", "spell resist read")
  r = read("CHAT_MSG_SPELL_PARTY_BUFF", "Healbot casts Dispel Magic on Tester.")
  ok(r.kind == "cast" and r.src == "Healbot" and r.spl == "Dispel Magic" and r.tgt == "Tester", "targeted cast read")
  r = read("CHAT_MSG_COMBAT_FRIENDLY_DEATH", "Healbot dies.")
  ok(r.kind == "death" and r.tgt == "Healbot", "death read")

  -- a fight: Tester (mage) and Healbot (priest) in a party
  local hp = { player = 3000, party1 = 2000 }
  local partyNames = { player = "Tester", party1 = "Healbot" }
  local realUnitName = UnitName
  local saved = { UnitIsPlayer = UnitIsPlayer, UnitClass = UnitClass, UnitHealth = UnitHealth, UnitHealthMax = UnitHealthMax,
                  UnitAffectingCombat = UnitAffectingCombat, UnitExists = UnitExists, UnitCanAttack = UnitCanAttack }
  UnitName = function(u) return partyNames[u] end
  UnitIsPlayer = function(u) return partyNames[u] ~= nil end
  UnitClass = function(u) if u == "player" then return "Mage", "MAGE" elseif u == "party1" then return "Priest", "PRIEST" end end
  UnitHealth = function(u) return hp[u] or 0 end
  -- pfUI's feigndeath module keeps its own UnitHealth in pfUI's environment
  local envUnitHealth = pfUI.env.UnitHealth
  pfUI.env.UnitHealth = UnitHealth
  UnitHealthMax = function(u) return u == "player" and 3000 or 2000 end
  local fighting = true
  UnitAffectingCombat = function(u) return fighting and partyNames[u] ~= nil end
  Mock.party, Mock.raid = 1, 0
  ME.who = {}

  local function log(ev, msg) Mock.Fire(ev, msg) end
  log("CHAT_MSG_COMBAT_SELF_HITS", "You hit Hogger for 120.")
  log("CHAT_MSG_COMBAT_SELF_HITS", "You crit Hogger for 240.")
  log("CHAT_MSG_SPELL_SELF_DAMAGE", "Your Fireball hits Hogger for 300 Fire damage.")
  log("CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE", "Hogger suffers 50 Shadow damage from your Shadow Word: Pain.")
  log("CHAT_MSG_SPELL_SELF_DAMAGE", "Your Frostbolt was resisted by Hogger.")
  log("CHAT_MSG_SPELL_SELF_DAMAGE", "Your Fire Blast hits Kobold Geomancer for 80 Fire damage.")
  log("CHAT_MSG_SPELL_SELF_DAMAGE", "You interrupt Kobold Geomancer's Fireball.")
  log("CHAT_MSG_COMBAT_CREATURE_VS_SELF_HITS", "Hogger hits you for 400.")
  log("CHAT_MSG_COMBAT_CREATURE_VS_SELF_MISSES", "Hogger attacks. You dodge.")
  hp.player = 2800
  log("CHAT_MSG_SPELL_PARTY_BUFF", "Healbot's Flash Heal heals you for 500.")
  log("CHAT_MSG_SPELL_PARTY_BUFF", "Healbot casts Dispel Magic on Tester.")
  log("CHAT_MSG_SPELL_AURA_GONE_SELF", "Your Shadow Word: Pain is removed.")
  log("CHAT_MSG_SPELL_CREATURE_VS_SELF_DAMAGE", "Hogger's Smash hits you for 2600 Physical damage.")
  log("CHAT_MSG_COMBAT_FRIENDLY_DEATH", "You die.")

  local seg = ME.current
  ok(seg, "a fight started")
  local me = seg and seg.actors.Tester
  local hb = seg and seg.actors.Healbot
  ok(me and me.damage == 790, "damage done (" .. tostring(me and me.damage) .. ")")
  ok(me and me.class == "MAGE", "class known")
  local melee = me and me.spells[pfUI.env.T["Melee"]]
  ok(melee and melee.hits == 2 and melee.crits == 1 and melee.max == 240 and melee.min == 120, "melee hits, crits, max, min")
  local swp = me and me.spells["Shadow Word: Pain"]
  ok(swp and swp.ticks == 1 and swp.hits == 0, "damage over time counted as ticks")
  local fb = me and me.spells["Frostbolt"]
  ok(fb and fb.misses == 1 and fb.how.resist == 1, "resist counted on the spell")
  ok(me and me.targets.Hogger == 710 and me.targets["Kobold Geomancer"] == 80, "damage per target")
  ok(me and me.interrupts == 1 and me.ilist[1].spell == "Fireball" and me.ilist[1].with == "Fire Blast", "interrupt with what and of what (" .. tostring(me and me.ilist[1] and me.ilist[1].with) .. ")")
  ok(me and me.taken == 3000 and me.avoid.dodge == 1, "damage taken and dodges")
  ok(hb and hb.heal == 200 and hb.overheal == 300, "effective healing and overhealing (" .. tostring(hb and hb.heal) .. "/" .. tostring(hb and hb.overheal) .. ")")
  ok(hb and hb.dispels == 1 and hb.dlist[1].aura == "Shadow Word: Pain" and hb.dlist[1].target == "Tester", "dispel: what and from whom")
  ok(hb and hb.casts["Dispel Magic"] == 1 and hb.casts["Flash Heal"] == 1, "casts counted")
  ok(me and me.deaths == 1 and me.deathlogs[1] and table.getn(me.deathlogs[1].log) >= 3, "death with a death log")
  ok(ME.overall.actors.Tester and ME.overall.actors.Tester.damage == 790, "overall has it too")

  -- phase 2 (Details' data): friendly fire, enemies, by spell, healing taken
  log("CHAT_MSG_COMBAT_PARTY_HITS", "Healbot hits you for 50.")
  log("CHAT_MSG_COMBAT_CREATURE_VS_PARTY_HITS", "Hogger hits Healbot for 30.")
  ok(hb and hb.ff == 50 and hb.damage == 0 and hb.fftargets.Tester == 50, "a hit on your own group is friendly fire, not damage done")
  ok(seg.foes.Hogger and seg.foes.Hogger.taken == 710 and seg.foes.Hogger.from.Tester == 710, "enemy damage taken, and from whom")
  ok(seg.foes.Hogger.done == 3030 and seg.foes.Hogger.to.Healbot == 30, "enemy damage done (" .. tostring(seg.foes.Hogger.done) .. ")")
  ok(seg.byspell.Smash and seg.byspell.Smash.total == 2600 and seg.byspell.Smash.targets.Tester == 2600, "damage taken by spell")
  ok(me and me.htaken == 200 and me.hsources.Healbot == 200, "healing taken, and from whom")
  -- resources
  log("CHAT_MSG_SPELL_PERIODIC_SELF_BUFFS", "You gain 25 Rage from Bloodrage.")
  log("CHAT_MSG_SPELL_PERIODIC_PARTY_BUFFS", "Healbot gains 300 Mana from Tester's Innervate.")
  ok(me and me.power.Rage == 25 and me.psources.Rage.Bloodrage == 25, "rage generated, from what")
  ok(hb and hb.power.Mana == 300 and hb.psources.Mana["Innervate (Tester)"] == 300, "mana restored, from whose spell")
  -- buff uptime and a cooldown seen as its buff
  log("CHAT_MSG_SPELL_PERIODIC_SELF_BUFFS", "You gain Arcane Power.")
  Mock.now = Mock.now + 10
  log("CHAT_MSG_SPELL_AURA_GONE_SELF", "Arcane Power fades from you.")
  ok(me and me.buffs["Arcane Power"] and math.abs(me.buffs["Arcane Power"] - 10) < .01, "buff uptime (" .. tostring(me and me.buffs["Arcane Power"]) .. ")")
  ok(me and me.cds == 1 and me.cdlist[1].spell == "Arcane Power", "a cooldown used")
  -- debuff uptime, credited to whoever used that spell
  log("CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE", "Hogger is afflicted by Shadow Word: Pain.")
  Mock.now = Mock.now + 6
  log("CHAT_MSG_SPELL_AURA_GONE_OTHER", "Shadow Word: Pain fades from Hogger.")
  ok(me and me.debuffs["Shadow Word: Pain"] and math.abs(me.debuffs["Shadow Word: Pain"] - 6) < .01, "debuff uptime, the caster's (" .. tostring(me and me.debuffs["Shadow Word: Pain"]) .. ")")
  -- a resurrection
  log("CHAT_MSG_SPELL_PARTY_BUFF", "Healbot casts Resurrection on Tester.")
  ok(hb and hb.ress == 1 and hb.resslist[1].target == "Tester", "a resurrection, and on whom")
  -- SuperWoW cast events: casts with their targets, counted once
  partyNames["0xA1"], partyNames["0xB2"] = "Tester", "Healbot"
  ME.CastEvent("0xA1", "0xB2", "CAST", 774)
  ME.Cast("Tester", "Spell774", nil)
  ok(me and me.casts.Spell774 == 1, "a SuperWoW cast event counts the cast once (" .. tostring(me and me.casts.Spell774) .. ")")
  partyNames["0xA1"], partyNames["0xB2"] = nil, nil
  -- an enemy dies: a frag for the last of your group to hit it (within 10 s)
  log("CHAT_MSG_COMBAT_SELF_HITS", "You hit Hogger for 10.")
  log("CHAT_MSG_COMBAT_HOSTILE_DEATH", "Hogger dies.")
  ok(me and me.frags == 1 and me.fraglist[1].target == "Hogger", "frags")
  -- the new displays
  local er = ME.Rows("enemytaken", "current")
  ok(er[1] and er[1].name == "Hogger" and er[1].foe, "enemy damage taken rows")
  local br = ME.Rows("byspell", "current")
  ok(br[1] and br[1].name == "Smash", "damage taken by spell rows")
  local ur = ME.Rows("buffs", "current")
  ok(ur[1] and ur[1].name == "Tester" and string.find(ur[1].text, ":"), "buff uptime rows show time (" .. tostring(ur[1] and ur[1].text) .. ")")
  local groups = {}
  for _, m in ipairs(ME.MODES) do groups[m.group or "?"] = true end
  ok(groups.Damage and groups.Healing and groups.Resources and groups.Misc, "displays in Details' four groups")
  -- damage on the boss, and without it (adds, trash)
  seg.boss = "Hogger"
  local brow = ME.Rows("bossdmg", "current")
  local nrow = ME.Rows("noboss", "current")
  ok(brow[1] and brow[1].name == "Tester" and brow[1].value == me.targets.Hogger, "boss damage: on Hogger only (" .. tostring(brow[1] and brow[1].value) .. ")")
  ok(nrow[1] and nrow[1].value == me.damage - me.targets.Hogger, "damage without the boss (" .. tostring(nrow[1] and nrow[1].value) .. ")")
  seg.boss = nil
  local all = ME.Rows("noboss", "current")
  ok(all[1] and all[1].value == me.damage, "no boss in the fight: all of it counts")

  -- rows, windows, details
  local rows = ME.Rows("damage", "current")
  ok(rows[1] and rows[1].name == "Tester" and rows[1].text == "800", "damage rows (790 + the 10 before the kill)")
  rows = ME.Rows("heal", "current")
  ok(rows[1] and rows[1].name == "Healbot", "healing rows")
  local w1 = pfMeter1
  ok(w1 and w1:IsShown(), "meter window 1 shown")
  if w1 then
    w1:SetHeight(160)
    w1.Refresh(w1)
    ok(w1.bars[1] and w1.bars[1]:IsShown() and string.find(w1.bars[1].left.text or "", "Tester"), "bar shows Tester")
    -- raised over the chat, the buttons must still sit above the window (it takes clicks)
    w1:SetFrameLevel(w1:GetFrameLevel() + 20)
    ME.Lift(w1)
    local lvl = w1:GetFrameLevel()
    ok(w1.menu:GetFrameLevel() > lvl and w1.reset:GetFrameLevel() > lvl and w1.titlebtn:GetFrameLevel() > lvl
      and w1.bars[1]:GetFrameLevel() > lvl, "header buttons and bars above a raised window")
    w1.bars[1]:Click()
    -- phase 3: the player breakdown
    local BD = ME.breakdown
    ok(pfMeterBreakdown and pfMeterBreakdown:IsShown() and BD.actor and BD.actor.name == "Tester", "click opens the player breakdown")
    local found
    for _, e in ipairs(BD.listShown or {}) do if e.name == "Fireball" then found = e end end
    ok(found, "Spells lists Fireball")
    -- a spell in detail: hits, normal and critical, its targets
    if found then found.onclick() end
    local lines = {}
    for _, l in ipairs(BD.linesShown or {}) do lines[l[1]] = l[2] end
    ok(BD.spell == "Fireball" and lines["Hits"] == 1 and lines["  Critical"] and lines["Targets"], "a spell in detail")
    BD.spell = pfUI.env.T["Melee"]
    BD.Draw()
    lines = {}
    for _, l in ipairs(BD.linesShown or {}) do lines[l[1]] = l[2] end
    ok(lines["Hits"] == 3 and string.find(lines["  Critical"] or "", "^1 ") and string.find(lines["  Critical"], "avg 240"),
      "melee: 3 hits, 1 crit averaging 240 (" .. tostring(lines["  Critical"]) .. ")")
    -- every tab draws
    for _, t in ipairs(BD.TABS) do
      BD.tab = t[1]
      local good, err = pcall(BD.Draw)
      ok(good, "breakdown tab " .. t[1] .. " draws: " .. tostring(err))
    end
    BD.tab = "targets"
    BD.Draw()
    ok(BD.listShown[1] and BD.listShown[1].name == "Hogger", "Targets: Hogger first")
    BD.tab = "compare"
    BD.Draw()
    ok(BD.other == "Healbot", "Compare picks another player (" .. tostring(BD.other) .. ")")
    -- the next player of the window (damage taken: both players are in it)
    BD.mode = "taken"
    BD.Step(1)
    ok(BD.actor and BD.actor.name ~= "Tester", "> shows the next player (" .. tostring(BD.actor and BD.actor.name) .. ")")
    BD.Step(-1)
    ok(BD.actor and BD.actor.name == "Tester", "< back")
    BD.mode = "damage"
    -- the chart: drawn from the fight's samples, one a second
    local cseg = ME.Segment("current")
    local tester = cseg.actors.Tester
    local d0 = tester.damage
    for i = 1, 6 do
      Mock.now = Mock.now + 1
      tester.damage = tester.damage + 100
      ME.Sample(cseg)
    end
    BD.tab = "chart"
    BD.Draw()
    ok(BD.chartPoints and BD.chartPoints >= 6 and pfMeterBreakdown.chart:IsShown(), "the Chart tab draws the fight (" .. tostring(BD.chartPoints) .. ")")
    local curve = ME.Curve(cseg, "Tester", false, 1)
    ok(curve[table.getn(curve)] and math.abs(curve[table.getn(curve)] - 100) < .01, "damage per second from the samples")
    tester.damage = d0
    -- custom displays: one spell's damage per player
    local cu = pfUI_config.meters.custom1
    cu.kind, cu.spell = "dmgspell", "Fireball"
    local crow = ME.Rows("custom1", "current")
    ok(crow[1] and crow[1].name == "Tester" and crow[1].value == 300, "a custom display: Fireball damage (" .. tostring(crow[1] and crow[1].value) .. ")")
    ME.CustomNames()
    local cm
    for _, m in ipairs(ME.MODES) do if m.key == "custom1" then cm = m end end
    ok(cm and cm.name == "Fireball" and cm.shown(), "named after its spell and in the menu")
    cu.spell = ""
    ok(not cm.shown(), "not in the menu without a spell")
    -- a window's look as text, taken by another window
    local mc2 = pfUI_config.meters
    local tex2 = mc2.win2.texture
    mc2.win1.texture = "Interface\\AddOns\\pfUI\\img\\bars\\bar-steel"
    local str = ME.ExportLook({ cfg = 1 })
    ok(string.find(str, "^OCTOMETER1:") and not string.find(str, "mode="), "look exported without what it shows")
    local took = ME.ImportLook({ cfg = 2 }, str)
    ok(took > 10 and mc2.win2.texture == mc2.win1.texture, "another window takes the look (" .. took .. " settings)")
    ok(ME.ImportLook({ cfg = 2 }, "hello") == 0, "not a look: nothing taken")
    mc2.win2.texture = tex2
    mc2.win1.texture = "Interface\\AddOns\\pfUI\\img\\bar_elvui"
    -- report the open tab
    BD.tab = "spells"
    BD.Draw()
    local rl = BD.ReportLines()
    ok(rl[1] and string.find(rl[1], "Tester") and rl[2] and string.find(rl[2], "^1%. "), "report the tab (" .. tostring(rl[2]) .. ")")
    pfMeterBreakdown:Hide()
    -- each mode and its breakdown builds
    for _, m in ipairs(ME.MODES) do
      w1.mode = m.key
      local good, e = pcall(w1.Refresh, w1)
      ok(good, "mode " .. m.key .. " draws: " .. tostring(e))
      if w1.bars[1] and w1.bars[1].row and w1.bars[1].row.actor then
        good, e = pcall(ME.ShowDetails, w1, w1.bars[1].row)
        ok(good, "mode " .. m.key .. " breakdown: " .. tostring(e))
      end
    end
    w1.mode = "damage"
    -- test mode: a made-up fight with everything in it, real fights kept aside
    local realHistory, realOverall = ME.history, ME.overall
    local realTesterDamage = ME.Segment("current").actors.Tester.damage
    ok(ME.TestMode and ME.TestMode(true), "test mode on")
    local ts = ME.testSeg
    ok(ts and ts.test and ME.Segment("current") == ts and ME.Segment("overall") == ts, "every window shows the test fight")
    ok(ME.history == realHistory and ME.overall == realOverall and realHistory[1].actors.Tester.damage == realTesterDamage
      and not realHistory[1].actors.Garrosh, "the real fights are untouched")
    local ga, an, rx, ja = ts.actors.Garrosh, ts.actors.Anduin, ts.actors.Rexxar, ts.actors.Jaina
    ok(ga and ga.damage > 0 and ga.taken > ga.damage / 3 and next(ga.avoid), "the tank hits, takes the most and avoids (" .. tostring(ga and ga.taken) .. ")")
    ok(an and an.heal > 0 and an.overheal > 0 and an.dispels == 1 and an.power[pfUI.env.MANA or "Mana"], "a healer heals, overheals, dispels, gets mana")
    ok(rx and rx.deaths == 1 and rx.deathlogs[1].killer == "Onyxia" and table.getn(rx.deathlogs[1].log) > 0, "a death with its log")
    ok(ts.actors.Malfurion.ress == 1 and ga.cds >= 2 and ja.interrupts == 1 and ja.ilist[1].with == "Counterspell", "res, cooldowns, interrupt with its spell")
    ok(ts.actors["Gul'dan"].ff > 0 and ga.buffs["Battle Shout"] and ts.actors["Gul'dan"].debuffs["Curse of Agony"], "friendly fire and uptime")
    ok(ts.foes.Onyxia and ts.foes["Onyxian Whelp"] and ts.byspell["Flame Breath"] and table.getn(ts.timeline) > 100 and ts.boss == "Onyxia",
      "enemies, spells on the group, a chart, the boss")
    local frags = 0
    for _, a in pairs(ts.actors) do frags = frags + a.frags end
    ok(frags >= 5, "whelp kills (" .. frags .. ")")
    -- every bar opens its breakdown; every tab of every view draws
    w1.Refresh(w1)
    ok(w1.bars[1].row and w1.bars[1].row.actor and ts.actors[w1.bars[1].row.name], "test bars are the test fight's players")
    w1.bars[1]:Click()
    ok(pfMeterBreakdown:IsShown() and BD.seg == ts, "a test bar opens its breakdown")
    for _, t in ipairs(BD.TABS) do
      for _, k in ipairs(BD.KINDS) do
        BD.tab, BD.kind = t[1], k[1]
        local good, err = pcall(BD.Draw)
        ok(good, "test breakdown " .. t[1] .. " / " .. k[1] .. ": " .. tostring(err))
      end
    end
    BD.kind = "damage"
    -- links: Targets -> Onyxia -> who hit her -> back
    BD.actor = ga
    BD.tab = "targets"
    BD.Draw()
    local link
    for _, l in ipairs(BD.linesShown) do if l[1] == "Open Onyxia" then link = l.go end end
    ok(BD.listShown[1].name == "Onyxia" and BD.listShown[1].link and link, "a target is a link")
    link()
    ok(BD.foe == "Onyxia" and not BD.actor and BD.tab == "fsummary", "it opens the enemy")
    for _, t in ipairs(BD.FOETABS) do
      BD.tab = t[1]
      local good, err = pcall(BD.Draw)
      ok(good, "enemy tab " .. t[1] .. ": " .. tostring(err))
    end
    BD.tab = "fhitby"
    BD.Draw()
    local who = BD.listShown[1]
    ok(who and who.onclick, "who hit her are links")
    who.onclick()
    ok(BD.actor and BD.actor.name == who.name, "and open the player (" .. tostring(BD.actor and BD.actor.name) .. ")")
    BD.Back()
    ok(BD.foe == "Onyxia", "Back returns to the enemy")
    BD.Back()
    ok(BD.actor == ga and BD.tab == "targets", "and to the player")
    -- Summary lines jump to their tab
    BD.tab = "summary"
    BD.Draw()
    for _, l in ipairs(BD.linesShown) do if l[1] == "Damage taken" then l.go() end end
    ok(BD.tab == "taken", "Summary: Damage taken opens Taken")
    -- an enemy bar and a spell bar open their own views
    w1.mode = "enemytaken"
    w1.Refresh(w1)
    w1.bars[1]:Click()
    ok(BD.foe and not BD.actor, "an enemy bar opens the enemy (" .. tostring(BD.foe) .. ")")
    w1.mode = "byspell"
    w1.Refresh(w1)
    w1.bars[1]:Click()
    ok(BD.bspell and pcall(BD.Draw), "a spell bar opens the spell (" .. tostring(BD.bspell) .. ")")
    w1.mode = "damage"
    -- menus of everyone / every enemy
    ok(pcall(BD.PeopleMenu, pfMeterBreakdown.who) and pcall(BD.FoeMenu, pfMeterBreakdown.foes), "people and enemy menus")
    -- the displays at the top: pick another one inside the breakdown
    ok(table.getn(BD.GROUPS) >= 4 and pfMeterBreakdown.groups[1], "a display picker per group (" .. table.getn(BD.GROUPS) .. ")")
    BD.actor, BD.foe, BD.bspell = ga, nil, nil
    BD.SetMode("heal")
    ok(BD.mode == "heal" and BD.kind == "heal" and BD.actor, "healing picked: healing spells")
    local litGroup
    for _, b in ipairs(pfMeterBreakdown.groups) do if b.lit then litGroup = b.group end end
    ok(litGroup == "Healing", "its group is lit (" .. tostring(litGroup) .. ")")
    BD.SetMode("interrupts")
    ok(BD.tab == "utility", "interrupts open Utility")
    BD.SetMode("enemytaken")
    ok(BD.foe and not BD.actor, "an enemy display opens its top enemy (" .. tostring(BD.foe) .. ")")
    BD.SetMode("damage")
    ok(BD.actor and not BD.foe, "back to a player for damage")
    ok(pcall(BD.ModeMenu, pfMeterBreakdown.groups[1], BD.GROUPS[1]), "a group's menu opens")
    if pfMeterMenu then pfMeterMenu:Hide() end
    if pfMeterMenu then pfMeterMenu:Hide() end
    ME.TestMode(false)
    ok(not ME.testOn and ME.Segment("current") == realHistory[1] and not pfMeterBreakdown:IsShown(), "test mode off: the real fight is back")
    w1.Refresh(w1)
    -- report to party
    Mock.chat = {}
    local envSend = pfUI.env.SendChatMessage
    pfUI.env.SendChatMessage = function(msg, ch) table.insert(Mock.chat, { msg, ch }) end
    w1.report:Click()
    pfMeterMenu.buttons[2]:Click()
    ok(Mock.chat[1] and string.find(Mock.chat[1][1], "Damage Done") and Mock.chat[1][2] == "PARTY", "report title to party")
    ok(Mock.chat[2] and string.find(Mock.chat[2][1], "1. Tester"), "report lines")
    pfUI.env.SendChatMessage = envSend
  end

  -- window settings menu (the three-line button)
  if w1 then
    w1.menu:Click()
    ok(pfMeterMenu:IsShown(), "window menu opens")
    local function find(label)
      for _, b in ipairs(pfMeterMenu.buttons) do
        if b:IsShown() and b.text.text and string.find(b.text.text, label, 1, true) then return b end
      end
    end
    ok(find("Docked in the chat panel") and find("Lock position") and find("Merge pets") and find("All meter options"), "menu has dock, lock, tracking and options")
    -- lock: hides the resize grip, stays open
    ok(w1.grip:IsShown(), "free window has a resize grip")
    find("Lock position"):Click()
    ok(pfUI_config.meters.win1.lock == "1" and not w1.grip:IsShown() and pfMeterMenu:IsShown(), "lock hides the grip, menu stays open")
    find("Lock position"):Click()
    -- bar height cycles
    local before = pfUI_config.meters.win1.barheight
    find("Bar height"):Click()
    ok(pfUI_config.meters.win1.barheight ~= before, "bar height changes (" .. before .. " -> " .. pfUI_config.meters.win1.barheight .. ")")
    pfUI_config.meters.win1.barheight = before
    -- rank numbers off
    find("Rank numbers"):Click()
    w1.Refresh(w1)
    ok(pfUI_config.meters.win1.rank == "0" and w1.bars[1].left.text == "Tester", "rank numbers off (" .. tostring(w1.bars[1].left.text) .. ")")
    find("Rank numbers"):Click()
    pfMeterMenu:Hide()

    -- resize with the grip: the new size is kept
    w1.GetWidth = function() return 333 end
    w1.GetHeight = function() return 222 end
    Mock.Run(w1.grip, "OnMouseDown")
    Mock.Run(w1.grip, "OnMouseUp")
    ok(pfUI_config.meters.win1.width == "333" and pfUI_config.meters.win1.height == "222", "resized window keeps its size")
    w1.GetWidth, w1.GetHeight = nil, nil

    -- dock and undock while playing (a stand-in right chat)
    local chat = CreateFrame("Frame", "pfTestChatRight", UIParent)
    chat.panelTop = CreateFrame("Frame", nil, chat)
    local oldChat = pfUI.chat
    pfUI.chat = { right = chat }
    pfUI_config.chat.right.enable = "1"
    pfUI.thirdparty.meters.state = nil
    ME.SetDocked(w1, true)
    ok(not w1.free and w1:IsShown() and pfUI.thirdparty.meters.damage, "dock: window goes into the chat panel")
    local p, rel = w1:GetPoint()
    ok(rel == chat, "docked window anchored to the chat")
    ok(pfUI.thirdparty.meters.state, "meters shown instead of the chat")
    ME.SetDocked(w1, false)
    ok(w1.free and w1:IsShown() and pfUI_config.thirdparty.pfmeter.dock == "0", "undock: free window")
    ok(not pfUI.thirdparty.meters.state, "nothing docked: chat back")
    pfUI.chat = oldChat
  end

  -- the fight ends a second after the group leaves combat; named after the enemy
  fighting = false
  Mock.now = Mock.now + 1.5
  pfMetersParser.tick, pfMetersParser.check = 0, 0
  Mock.Run(pfMetersParser, "OnUpdate")
  ok(ME.current == nil and ME.history[1] and ME.history[1].name == "Hogger", "fight ended, named Hogger (" .. tostring(ME.history[1] and ME.history[1].name) .. ")")
  ok(ME.history[1].trash, "no boss: a trash fight")

  -- time measure: per second over each player's active time, or the whole fight
  local hog = ME.history[1]
  local a1 = hog.actors.Tester
  local before = ME.Rows("dps", "current")[1].value
  pfUI_config.meters.timemeasure = "effective"
  local after = ME.Rows("dps", "current")[1].value
  ok(math.abs(after - a1.damage / ME.Duration(hog)) < .01 and after ~= before, "whole-fight DPS (" .. before .. " -> " .. after .. ")")
  pfUI_config.meters.timemeasure = "active"

  -- trash fights in a row merge into one
  local n0 = table.getn(ME.history)
  local s2 = ME.StartFight()
  ME.Actor(s2, "Tester", { class = "MAGE" }).damage = 100
  s2.enemies["Gnoll"] = 100
  ME.EndFight()
  ok(table.getn(ME.history) == n0 and ME.history[1] == hog and hog.actors.Tester.damage == a1.damage,
    "the next trash fight merged into the last (" .. tostring(hog.actors.Tester.damage) .. ")")
  ok(string.find(hog.name, "%(2%)"), "named as merged trash (" .. tostring(hog.name) .. ")")

  -- threat: parse, ask, warn
  local TH = ME.threat
  ok(TH, "threat module loaded")
  if TH then
    local list = TH.Parse("TWTv4=Tankguy:1:5000:100:1;Tester:0:4600:92:1;Healbot:0:1000:20:0#TMTv1=x")
    ok(list and table.getn(list) == 3 and list[1].name == "Tankguy" and list[1].tank, "threat answer parsed")
    -- asking: in a group, target a mob in combat
    fighting = true
    UnitExists = function(u) return u == "target" or partyNames[u] ~= nil end
    UnitCanAttack = function(a, b) return b == "target" end
    local oldIsPlayer = UnitIsPlayer
    UnitAffectingCombat = function(u) return u == "target" or (fighting and partyNames[u] ~= nil) end
    Mock.sent = {}
    TH.at = 0
    TH.Ask()
    ok(Mock.sent[1] and Mock.sent[1][1] == "TWT_UDTSv4" and Mock.sent[1][3] == "PARTY", "asks the server in a party")
    Mock.sounds = {}
    Mock.Fire("CHAT_MSG_ADDON", "TWT", "TWTv4=Tankguy:1:5000:100:1;Tester:0:4600:92:1;Healbot:0:1000:20:0")
    ok(TH.list and TH.list[2].name == "Tester", "answer stored")
    ok(table.getn(Mock.sounds) == 0, "no warning at 84% of the pull point")
    Mock.Fire("CHAT_MSG_ADDON", "TWT", "TWTv4=Tankguy:1:5000:100:1;Tester:0:5100:102:1")
    ok(table.getn(Mock.sounds) == 1, "warning past 90% of the pull point")
    local w2 = pfMeter2
    if w2 then
      w2.Refresh(w2)
      ok(w2.bars[1] and string.find(w2.bars[1].left.text or "", "Tester") and string.find(w2.bars[1].right.text or "", "102%%") and string.find(w2.bars[2].left.text or "", "Tankguy"), "threat window: most threat first")
    end
    -- moved from OctoBG: the cap against the pull point or the top players
    local mc = pfUI_config.meters
    local l2 = TH.Parse("TWTv4=Tankguy:1:5000:100:1;Tester:0:4600:92:1;Healbot:0:1000:20:0")
    mc.threatwarn, mc.threatref, mc.tnear = "90", "1", "80"
    local j = TH.Judge(l2)
    ok(math.abs(j.share - 92) < .01 and j.state == 3, "92% of the tank: past a 90% cap (" .. j.share .. ")")
    mc.threatref = "pull"
    j = TH.Judge(l2)
    ok(math.abs(j.share - 92 / 110 * 100) < .01 and j.state == 2, "of the pull point: near the cap")
    j = TH.Judge(TH.Parse("TWTv4=Tester:1:6000:100:1;Tankguy:0:5500:92:1"))
    ok(j.aggro and j.nextName == "Tankguy" and string.find(TH.Text(j), "next Tankguy 92%%"), "with aggro: the next player and their name")
    -- the label goes on your target's nameplate
    local Fx = pfUI.plates and pfUI.plates.Fx
    if Fx then
      local tplate = CreateFrame("Frame", nil, UIParent)
      tplate.istarget = true
      Fx.seen[tplate] = GetTime()
      TH.list, TH.at = l2, GetTime()
      mc.tlabel, mc.tlook, mc.twhere = "1", "words", "above"
      TH.Draw()
      local lp = TH.label.points and TH.label.points[1]
      ok(TH.label:IsShown() and lp and lp[2] == tplate and string.find(TH.label.text.text or "", "Threat"), "label above the target's plate")
      mc.twhere = "screen"
      TH.Draw()
      lp = TH.label.points and TH.label.points[1]
      ok(lp and lp[2] == pfThreatBox, "or in the box you place")
      mc.twhere = "above"
      Fx.seen[tplate] = nil
    end
    -- a popup when you pass your cap
    mc.threatflash = "1"
    TH.warned = nil
    TH.Popups({ share = 120, state = 3 })
    ok(pfThreatAlert:IsShown() and pfThreatAlert.text.text == mc.threatpopup, "the popup shouts your message")
    -- OctoBG's settings taken over once
    local oldDB, oldImp = OctoBGDB, mc.timported
    OctoBGDB = { threat = { enabled = true, look = "bar", where = "below", limit = 70, ref = 2, popupText = "Back off!" } }
    mc.timported = "0"
    ok(TH.ImportOctoBG() and mc.tlook == "bar" and mc.twhere == "below" and mc.threatwarn == "70" and mc.threatref == "2"
      and mc.threatpopup == "Back off!", "OctoBG's threat settings taken over")
    ok(not TH.ImportOctoBG(), "only once")
    OctoBGDB, mc.timported = oldDB, oldImp
    mc.tlook, mc.twhere, mc.threatwarn, mc.threatref, mc.threatpopup = "words", "above", "90", "pull", "THREAT - back off!"
  end

  UnitName = realUnitName
  pfUI.env.UnitHealth = envUnitHealth
  for k, f in pairs(saved) do _G[k] = f end
  Mock.party, Mock.raid = 0, 0
  fighting = false
  ME.Reset()
  ok(table.getn(ME.history) == 0 and not ME.current, "reset clears everything")
end

-- ---------------------------------------------------------------- phase 6: combat text
local SB = pfUI.sctB
ok(pfUI.sct and SB and SB.SCT and SB.db, "combat text loaded with its settings")
if pfUI.sct and SB and SB.db then
  local CTX = SB.SCT
  local s = pfUI_config.sct
  local tableBefore = SB.db.sct
  ok(s.speed == 1 and not s.fromOctoBG, "at pfUI's load: defaults (OctoBG not loaded yet)")
  -- OctoBG loads after pfUI; at login its settings are there (combat text was off in OctoBG)
  OctoBGDB = { sct = { speed = 1.5, enabled = false, areas = { inc = { x = -321, size = 24 } } } }
  pfUI.sct.ImportOctoBG()
  ok(s.speed == 1.5 and s.areas.inc.x == -321 and s.areas.inc.size == 24, "OctoBG's combat text settings copied at login")
  ok(s.fromOctoBG, "marked as copied from OctoBG")
  ok(s.enabled == true, "pfUI's on / off kept (OctoBG's was off)")
  ok(SB.db.sct == tableBefore, "the same settings table (live options keep working)")
  s.speed = 1.2
  pfUI.sct.ImportOctoBG()
  ok(s.speed == 1.2, "copied only once")
  s.speed = 1.5
  ok(s.areas.out and s.areas.out.anim and s.plates and s.events.outMelee, "missing settings filled from the defaults")
  ok(type(s.enabled) == "boolean" and type(s.speed) == "number", "settings keep real Lua values")
  ok(pfUI.sct:On(), "combat text on (OctoBG hands over to it)")

  -- login: the five areas are built as pfUI movers
  SB:Fire("OBG_INIT")
  local inc = pfCombatTextIncoming
  ok(inc and pfUI.movables["pfCombatTextIncoming"], "areas are pfUI movers (/moveui)")
  ok(pfCombatTextNotes and pfCombatTextOutgoing and pfCombatTextHealing and pfCombatTextExtra, "all five areas")
  local _, _, _, ax, ay = inc:GetPoint()
  ok(ax == -321, "area placed from its x (" .. tostring(ax) .. ")")

  -- a drop in layout mode: x / y come from pfUI's saved mover position
  pfUI_config.position.pfCombatTextIncoming = { anchor = "CENTER", xpos = -100, ypos = 50 }
  inc:OnMove()
  ok(s.areas.inc.x == -100 and s.areas.inc.y == 50, "moved area keeps its new x / y (" .. s.areas.inc.x .. "," .. s.areas.inc.y .. ")")
  ok(pfUI_config.position.pfCombatTextIncoming == nil, "mover position folded into x / y")

  -- texts show
  local before = CTX.nlive
  local good, e = pcall(CTX.Show, CTX, "-1234", 1, .2, .2, "inc", { crit = true })
  ok(good and CTX.nlive == before + 1, "a combat text shows: " .. tostring(e))
  good, e = pcall(CTX.TestMode, CTX, true)
  ok(good and CTX:Testing(), "test mode starts: " .. tostring(e))
  good, e = pcall(CTX.TestRound, CTX)
  ok(good and CTX.nlive > before + 1, "a test round shows texts: " .. tostring(e))
  CTX:TestMode(false)
  CTX:Clear()
  ok(CTX.nlive == 0, "cleared")

  -- layout mode shows samples in each area
  ok(pfUI.unlock and pfUI.unlock:GetScript("OnShow"), "layout mode hooked")

  -- options proxies write real values back
  local Nat = pfUI.gui.Native(function() return pfUI_config.sct end)
  Nat.shadow = "0"
  ok(pfUI_config.sct.shadow == false, "tick box writes false")
  Nat.shadow = "1"
  ok(pfUI_config.sct.shadow == true and Nat.shadow == "1", "and true")
  Nat.speed = "1.25"
  ok(pfUI_config.sct.speed == 1.25, "slider writes a number")
  local Ev = pfUI.gui.Native(function() return pfUI_config.sct.events.outMelee end)
  Ev.rgb = "0.5,0.25,1,1"
  ok(pfUI_config.sct.events.outMelee.r == .5 and pfUI_config.sct.events.outMelee.b == 1, "colour writes r, g, b")
  ok(Ev.rgb == "0.5,0.25,1,1", "colour reads back")

  -- /pfui sct test
  SlashCmdList.PFUI("sct test")
  ok(CTX:Testing(), "/pfui sct test starts the test")
  SlashCmdList.PFUI("sct test")
  ok(not CTX:Testing(), "and stops it")
  CTX:Clear()
end

-- the combat text's detailed tests (moved from OctoBG with the engine)
octo_ok = ok
if pfUI.sctB and pfUI.sctB.db then dofile(DIR .. "/tests/sct.lua") end

-- ---------------------------------------------------------------- map style (SexyMap)
local MAP = pfUI.minimap
ok(MAP and MAP.ApplyStyle and MAP.PRESETS, "map style loaded")
if MAP and MAP.ApplyStyle then
  local MS = pfUI_config.mapstyle
  local mask
  Minimap.SetMaskTexture = function(self, t) mask = t end
  Minimap.GetWidth = function() return 140 end

  MAP.ApplyStyle()
  ok(mask == pfUI.media["img:minimap"], "default: pfUI's square mask")
  ok(MAP.backdrop:IsShown() and not pfMinimapOutline:IsShown(), "default: pfUI's frame, no outline")

  -- every shape has its mask and outline files
  for _, sh in ipairs({ "rounded", "rounder", "squircle", "octagon", "diamond", "corner-tl", "corner-tr", "corner-bl", "corner-br" }) do
    local h = io.open(DIR .. "/img/minimap/mask-" .. sh .. ".tga", "rb")
    ok(h, "mask file " .. sh)
    if h then h:close() end
  end
  for _, sh in ipairs({ "round", "square", "rounded", "octagon" }) do
    local h = io.open(DIR .. "/img/minimap/outline-" .. sh .. ".tga", "rb")
    ok(h, "outline file " .. sh)
    if h then h:close() end
  end

  -- round + outline: the square frame goes, the outline follows the shape
  MS.shape, MS.border = "round", "outline"
  MAP.ApplyStyle()
  ok(mask == "Textures\\MinimapMask", "round uses the game's own mask")
  ok(not MAP.backdrop:IsShown() and pfMinimapOutline:IsShown(), "round: no square frame, outline shown")
  ok(string.find(pfMinimapOutline.tex.texture or "", "outline%-round"), "outline of the round shape")
  MS.shape = "octagon"
  MAP.ApplyStyle()
  ok(string.find(mask or "", "mask%-octagon") and string.find(pfMinimapOutline.tex.texture or "", "outline%-octagon"), "octagon mask and outline")

  -- presets: rune circle spins its art
  MAP.ApplyPreset("runes")
  ok(MS.shape == "round" and MS.art1 == "Spells\\AuraRune256", "preset sets the style")
  local spun
  local tex = pfMinimapArtAbove
  ok(tex, "art layer frame")
  local before = MS.art1speed
  Mock.Run(pfMinimapArtAbove, "OnUpdate", 1)
  ok(tonumber(before) ~= 0, "rune circle spins (" .. tostring(before) .. " degrees a second)")
  MAP.ApplyPreset("pfui")
  ok(MS.shape == "square" and MS.border == "pfui" and MS.art1 == "none", "back to pfUI's square")
  MAP.ApplyStyle()
  ok(MAP.backdrop:IsShown(), "pfUI frame back")

  -- buttons: never / mouse over
  MS.clock = "hide"
  MAP.ApplyStyle()
  ok(pfMinimapClock.alpha == 0, "clock hidden")
  MS.clock = "hover"
  MAP.ApplyStyle()
  Mock.over = nil
  ok(pfMinimapClock.alpha == 0, "clock waits for the mouse")
  MS.clock = "show"
  MAP.ApplyStyle()
  ok(pfMinimapClock.alpha == 1, "clock always shown")
  Mock.Run(pfMinimapClock, "OnUpdate")
  ok(pfMinimapClock.text.text and string.find(pfMinimapClock.text.text, "%d"), "clock shows the time (" .. tostring(pfMinimapClock.text.text) .. ")")

  -- who pinged
  UnitName = function(u) if u == "party1" then return "Healbot" end if u == "player" then return "Tester" end end
  Mock.Fire("MINIMAP_PING", "party1", 0.1, 0.2)
  ok(pfMinimapPing:IsShown() and string.find(pfMinimapPing.text.text or "", "Healbot"), "ping shows who")

  -- zoom back out
  local zoom = 3
  Minimap.GetZoom = function() return zoom end
  Minimap.SetZoom = function(self, z) zoom = z end
  MS.autozoom = "5"
  local hoverFrame
  for _, f in ipairs(Mock.frames) do if f._parent == MAP and f.alpha ~= nil and f.scripts.OnUpdate and f ~= pfMinimapPing and f ~= pfMinimapClock and f ~= pfMinimapArtAbove then hoverFrame = f end end
  ok(hoverFrame, "map hover / zoom timer found")
  if hoverFrame then
    Mock.now = Mock.now + 1
    Mock.Run(hoverFrame, "OnUpdate", .1)
    Mock.now = Mock.now + 6
    Mock.Run(hoverFrame, "OnUpdate", .1)
    ok(zoom == 0, "zoomed back out after 5 s")
  end
  MS.autozoom = "0"

  -- every part has a place of its own: move, size, put back
  ok(MAP.PARTS and table.getn(MAP.PARTS) == 10, "ten parts around the map")
  MAP.MovePart("mail", -20, -12)
  local mp = MiniMapMailFrame.point or {}
  ok(MS.mailx == "-20" and MS.maily == "-12" and MS.mailpt == "TOPRIGHT", "a moved part keeps its place")
  ok(mp[1] == "TOPRIGHT" and mp[2] == Minimap and mp[4] == -20 and mp[5] == -12, "and sits there (" .. tostring(mp[4]) .. ", " .. tostring(mp[5]) .. ")")
  MAP.SizePart("mail", 150)
  ok(MS.mailscale == "150" and MiniMapMailFrame:GetScale() == 1.5, "a part can be bigger")
  MAP.ResetPart("mail")
  ok(MS.mailx == "" and MS.mailscale == "100" and MiniMapMailFrame:GetScale() == 1, "right-click puts it back")
  -- the zone name always follows its setting; the coordinates' corner is live
  MAP.MovePart("zone", 0, -20)
  ok(pfMinimapZone.point and pfMinimapZone.point[5] == -20, "zone name moved")
  MAP.ResetPart("zone")
  pfUI_config.appearance.minimap.coordsloc = "topright"
  MAP.ApplyStyle()
  ok(pfMinimapCoord.point and pfMinimapCoord.point[1] == "TOPRIGHT" and pfMinimapCoord.point[4] == -3, "coordinates go to the picked corner")
  pfUI_config.appearance.minimap.coordsloc = "bottomleft"
  -- pfUI's addon buttons put their arrow back: ours wins after
  if pfUI.addonbuttons and pfMinimapButton then
    MAP.MovePart("abutton", 30, 6)
    pfUI.addonbuttons:ProcessButtons()
    ok(pfMinimapButton.point and pfMinimapButton.point[4] == 30, "the arrow stays where you put it")
    MAP.ResetPart("abutton")
  end
  MS.shape, MS.border = "square", "pfui"
  MAP.ApplyStyle()
end

-- ---------------------------------------------------------------- options pages
-- build every page of the options window (pages build on first show)
local pages, pageErrors, built = 0, {}, {}
-- the page width in game: window 940 - 2*7 margin - 170 tree - 2*2 scroll inset
local PAGE_WIDTH = 752
local function BuildPage(path, area)
  local content = area and area.scroll and area.scroll.content
  if not content then return end
  pages = pages + 1
  content.parent.GetLeft = function() return 0 end
  content.parent.GetRight = function() return PAGE_WIDTH end
  local good, e = pcall(Mock.Run, content, "OnShow")
  if not good then pageErrors[path] = e else built[path] = content end
end
ok(pfUI.gui and pfUI.gui.frames, "options window built")
if pfUI.gui and pfUI.gui.frames then
  for parent, pframe in pairs(pfUI.gui.frames) do
    if type(pframe) == "table" and type(parent) == "string" then
      BuildPage(parent, pframe.area)
      for title, tframe in pairs(pframe) do
        if type(tframe) == "table" and type(title) == "string" and tframe.area then
          BuildPage(parent .. " > " .. title, tframe.area)
        end
      end
    end
  end
end
ok(pages > 30, "options pages found (" .. pages .. ")")
ok(not pageErrors["Settings > Appearance"], "Settings > Appearance builds: " .. tostring(pageErrors["Settings > Appearance"]))
ok(not pageErrors["Settings > General"], "Settings > General builds: " .. tostring(pageErrors["Settings > General"]))
local broken = 0
for path, e in pairs(pageErrors) do
  broken = broken + 1
  if os.getenv("PFUI_TEST_VERBOSE") then print("  page " .. path .. ": " .. tostring(e)) end
end
print(string.format("options pages built in the mock: %d, need more of the client: %d", pages - broken, broken))
ok(broken == 0, "every options page builds (" .. broken .. " failed)")

-- Map Style: a preset button changes the style and the page's controls follow
do
  local page = built["Minimap > Map Style"]
  ok(page, "Map Style page built")
  if page then
    local arcane, shapeCell
    for _, c in ipairs(page._kids) do
      if c.button and c.button.text == "Arcane" then arcane = c.button end
      if c.config == "shape" then shapeCell = c end
    end
    ok(arcane and shapeCell, "preset button and shape control on the page")
    if arcane and shapeCell then
      local good, e = pcall(arcane:GetScript("OnClick"))
      ok(good, "preset button works: " .. tostring(e))
      ok(pfUI_config.mapstyle.shape == "round" and pfUI_config.mapstyle.art1 == "Spells\\AuraRune_A", "Arcane preset applied")
      ok(string.find(shapeCell.input.text.text or "", "Round"), "shape control shows the new shape (" .. tostring(shapeCell.input.text.text) .. ")")
      pfUI.minimap.ApplyPreset("pfui")
    end
  end
end

-- tree: one column; a category's pages show under it only while it is open
do
  local F = pfUI.gui.frames
  local uf = F["Unit Frames"]
  ok(uf and uf.children and table.getn(uf.children) > 5, "Unit Frames has its pages in the tree")
  ok(F.order and table.getn(F.order) >= 15, "categories in the tree (" .. (F.order and table.getn(F.order) or 0) .. ")")
  if os.getenv("PFUI_TREE") then for i, b in ipairs(F.order) do print("  tree " .. i .. " " .. tostring(b.text.text)) end end
  if uf and uf.children then
    F["Settings"]:Click()
    local hidden = true
    for _, c in ipairs(uf.children) do if c:IsShown() then hidden = false end end
    ok(hidden, "closed category hides its pages")
    -- open a page directly (as search does): its category opens with it
    local player = uf["Player"]

    player:Click()

    ok(uf.area:IsShown() and player.area:IsShown(), "clicking a page opens it and its category")
    local shown = 0
    for _, c in ipairs(uf.children) do if c:IsShown() then shown = shown + 1 end end
    ok(shown == table.getn(uf.children), "open category lists all its pages")
    ok(not F["Settings"].area:IsShown(), "the other category closed")
    local _, _, _, _, y = player:GetPoint()
    local _, _, _, _, yuf = uf:GetPoint()
    ok(y and yuf and y < yuf, "pages sit below their category")
    ok(uf.arrow.text == "-", "open category shows -")

    -- clicking the open category folds and unfolds its pages
    uf:Click()
    ok(not player:IsShown() and uf.arrow.text == "+", "click again folds the pages")
    uf:Click()
    ok(player:IsShown() and uf.arrow.text == "-", "and unfolds them")

    -- a short window: the tree scrolls, the opened category stays in view
    F.area.h = 400
    F["Settings"]:Click()
    uf:Click()
    local last = uf.children[table.getn(uf.children)]
    ok(last:IsShown(), "opening a long category scrolls its last page into view")
    local hiddenRoot = 0
    for _, b in ipairs(F.order) do if not b:IsShown() then hiddenRoot = hiddenRoot + 1 end end
    ok(hiddenRoot > 0, "rows beyond the column are hidden (" .. hiddenRoot .. ")")
    ok(F.area.moreUp:IsShown() or F.area.more:IsShown(), "more-rows mark shows")
    arg1 = 1
    for i = 1, 20 do pfUI.gui_TreeScroll() end
    ok(F.order[1]:IsShown() and not F.area.moreUp:IsShown(), "wheel up back to the top")
    arg1 = nil
    F.area.h = 0
    pfUI.gui_RelayoutTree()
  end
end

-- layout: cells of a page never overlap, stay inside the page and inside their group box
local overlaps, outside, cellsSeen = 0, 0, 0
local function Cells(content)
  local list = {}
  for _, c in ipairs(content._kids) do
    if c.cell and c.cell.h then table.insert(list, c) end
  end
  return list
end
for path, content in pairs(built) do
  local list = Cells(content)
  cellsSeen = cellsSeen + table.getn(list)
  for i = 1, table.getn(list) do
    local a = list[i].cell
    if a.x < 0 or a.x + a.w > PAGE_WIDTH - 16 + .01 then
      outside = outside + 1
      if os.getenv("PFUI_TEST_VERBOSE") then print("  outside: " .. path) end
    end
    for j = i + 1, table.getn(list) do
      local b = list[j].cell
      if a.x < b.x + b.w - .01 and b.x < a.x + a.w - .01 and a.y < b.y + b.h - .01 and b.y < a.y + a.h - .01 then
        overlaps = overlaps + 1
        if os.getenv("PFUI_TEST_VERBOSE") then print("  overlap on " .. path) end
      end
    end
  end
  -- every group box encloses the cells placed after it and before the next one
  for gi, g in ipairs(content.groups or {}) do
    local nextg = content.groups[gi + 1]
    for _, c in ipairs(list) do
      if c.cell.y >= g.cell.y and (not nextg or c.cell.y < nextg.cell.y) then
        if c.cell.y + c.cell.h > g.cell.y + (g.h or 0) + .01 then
          outside = outside + 1
          if os.getenv("PFUI_TEST_VERBOSE") then print("  cell below its group box: " .. path) end
        end
      end
    end
  end
end
ok(cellsSeen > 500, "settings laid out as cells (" .. cellsSeen .. ")")
ok(overlaps == 0, "no settings overlap (" .. overlaps .. ")")
ok(outside == 0, "every setting inside its page and group box (" .. outside .. ")")

-- PFUI_PREVIEW_DIR=<dir>: writes an HTML drawing of each page's layout
local previewDir = os.getenv("PFUI_PREVIEW_DIR")
if previewDir then
  local function esc(s)
    s = string.gsub(tostring(s or ""), "|c%x%x%x%x%x%x%x%x", "")
    s = string.gsub(s, "|r", "")
    s = string.gsub(s, "&", "&amp;")
    s = string.gsub(s, "<", "&lt;")
    return s
  end
  local ar, ag, ab = pfUI.api.GetAccentColor()
  local accent = string.format("rgb(%d,%d,%d)", ar * 255, ag * 255, ab * 255)
  local html = { "<!doctype html><meta charset=utf-8><title>pfUI Octo options preview</title><style>",
    "body{background:#0b0b0b;color:#eee;font:13px 'PT Sans Narrow',Arial Narrow,sans-serif;margin:16px}",
    ".page{position:relative;width:" .. PAGE_WIDTH .. "px;background:#161616;border:1px solid #000;margin:0 0 24px 0;overflow:hidden}",
    ".g{position:absolute;background:rgba(255,255,255,.03);border:1px solid #383838}",
    ".gt{position:absolute;left:10px;top:6px;color:" .. accent .. ";font-weight:bold;font-size:14px}",
    ".c{position:absolute;box-sizing:border-box;white-space:nowrap;overflow:hidden}",
    ".box{display:inline-block;width:12px;height:12px;border:1px solid #000;background:#222;margin:0 8px 0 6px;vertical-align:middle}",
    ".on{background:" .. accent .. "}",
    ".lbl{color:#ccc;font-size:12px;padding:2px 6px}",
    ".in{margin:1px 6px;height:18px;background:#0e0e0e;border:1px solid #000;padding:0 5px;color:" .. accent .. ";line-height:18px}",
    ".sw{display:inline-block;width:28px;height:12px;border:1px solid #000;margin:0 8px 0 6px;vertical-align:middle;background:#ddd}",
    ".bt{margin:3px 4px;height:18px;border:1px solid #000;background:#1a1a1a;text-align:center;line-height:18px}",
    "h2{font-size:18px;margin:4px 0}</style>" }
  local paths = {}
  for path in pairs(built) do table.insert(paths, path) end
  table.sort(paths)
  for _, path in ipairs(paths) do
    local content = built[path]
    local height = 60
    for _, c in ipairs(Cells(content)) do
      if c.cell.y + c.cell.h + 20 > height then height = c.cell.y + c.cell.h + 20 end
    end
    table.insert(html, "<h2>" .. esc(path) .. "</h2><div class=page style='height:" .. height .. "px'>")
    if content.title then
      table.insert(html, "<div class=c style='left:12px;top:10px;font-size:19px;font-weight:bold'>" .. esc(content.title.text) .. "</div>")
    end
    for _, g in ipairs(content.groups or {}) do
      table.insert(html, string.format("<div class=g style='left:%dpx;top:%dpx;width:%dpx;height:%dpx'>", g.cell.x, g.cell.y, g.cell.w, g.h or 0))
      if g.caption then table.insert(html, "<div class=gt>" .. esc(g.caption.text) .. "</div>") end
      table.insert(html, "</div>")
    end
    for _, c in ipairs(Cells(content)) do
      local k, inner = c.cellkind, ""
      local cap = c.caption and esc(c.caption.text) or ""
      if k == "checkbox" then
        inner = "<span class='box" .. (c.input and c.input.checked and " on" or "") .. "'></span>" .. cap
      elseif k == "color" then
        inner = "<span class=sw></span>" .. cap
      elseif k == "button" then
        inner = "<div class=bt>" .. esc(c.button and c.button.text) .. "</div>"
      elseif k == "dropdown" or k == "list" then
        inner = "<div class=lbl>" .. cap .. "</div><div class=in>" .. esc(c.input and c.input.text and c.input.text.text) .. " &#9662;</div>"
      elseif k == "text" then
        inner = "<div class=lbl>" .. cap .. "</div><div class=in>" .. esc(c.input and c.input.text) .. "</div>"
      else
        inner = cap
      end
      table.insert(html, string.format("<div class=c style='left:%dpx;top:%dpx;width:%dpx;height:%dpx;line-height:%dpx'>%s</div>",
        c.cell.x, c.cell.y, c.cell.w, c.cell.h, (k == "checkbox" or k == "color") and c.cell.h or 16, inner))
    end
    table.insert(html, "</div>")
  end
  local h = io.open(previewDir .. "/options-preview.html", "w")
  h:write(table.concat(html, "\n"))
  h:close()
  print("preview written to " .. previewDir .. "/options-preview.html")
end

-- ---------------------------------------------------------------- the OctoBG-style window

do
  local O = pfUI.octoui and pfUI.octoui.Options
  ok(O and O.frame == pfUI.gui, "pfUI's window has the Octo shell")
  if O and O.frame then
    pfUI.gui:Show()
    -- Combat Text first, with OctoBG's six pages
    local ct
    for _, s in ipairs(O.octo) do if s[1] == "Combat Text" then ct = s end end
    ok(ct and table.getn(ct[2]) == 6, "Combat Text section with its six pages")
    ok(O.first and string.sub(O.first, 1, 2) == "o:", "the window first opens on an Octo page: " .. tostring(O.first))
    -- Action Bars: five clean pages instead of pfUI's old Actionbar category
    local abs
    for _, s in ipairs(O.octo) do if s[1] == "Action Bars" then abs = s end end
    ok(abs and table.getn(abs[2]) == 5, "Action Bars section with its five pages")
    local oldab = 0
    for k in pairs(O.legacy) do if string.find(k, "^l:Actionbar") then oldab = oldab + 1 end end
    ok(oldab == 0, "pfUI's old Actionbar pages are gone from the list")
    for _, pg in ipairs(abs and abs[2] or {}) do
      local good, err = pcall(function() O:Select("o:" .. pg[1]) end)
      ok(good and O.pages[pg[1]] and O.pages[pg[1]].frame:IsShown(), "page " .. pg[1] .. " builds and shows: " .. tostring(err))
    end
    for _, pg in ipairs(ct and ct[2] or {}) do
      local okk, err = pcall(function() O:Select("o:" .. pg[1]) end)
      ok(okk and O.pages[pg[1]] and O.pages[pg[1]].frame:IsShown(), "page " .. pg[1] .. " builds and shows: " .. tostring(err))
      local p = O.pages[pg[1]]
      if p then
        local rok, rerr = pcall(function() pfUI.octoui.W.Refresh(p) end)
        ok(rok, "page " .. pg[1] .. " refreshes: " .. tostring(rerr))
      end
    end
    -- a switch on a page changes the setting
    local wasOn = pfUI_config.sct.enabled
    O:Select("o:ctgeneral")
    local ctg = O.pages.ctgeneral
    local cards = ctg and table.getn(ctg.cards) or 0
    ok(cards >= 3, "Basics has its cards: " .. cards)
    -- pfUI's pages: a section per category, shown in the page panel
    local lkey
    -- a fixed page with number fields (pairs order changes as the code grows)
    for _, k in ipairs({ "l:Minimap/Minimap", "l:XP Bar/Experience Bar", "l:Buffs/Player Buff Bar" }) do
      if not lkey and O.legacy[k] then lkey = k end
    end
    ok(lkey ~= nil, "pfUI's own pages are in the topic list (" .. tostring(lkey) .. ")")
    if lkey then
      O:Select(lkey)
      local l = O.legacy[lkey]
      ok(l.cat.area:IsShown() and l.page.area:IsShown() and not ctg.frame:IsShown(), "a pfUI page shows in place of the Octo page")
      ok(l.cat:GetParent() == O.hidden, "the old tree button is tucked away")
      local content = l.page.area.scroll and l.page.area.scroll.content
      ok(content and content.octoSkinned, "pfUI's page gets OctoBG's look")
      local sliders, skinned = 0, 0
      for _, c in ipairs(content and { content:GetChildren() } or {}) do
        if c.cellkind == "slider" then sliders = sliders + 1 if c.input.fill then skinned = skinned + 1 end end
      end
      ok(sliders == skinned, "every slider has the blue fill (" .. skinned .. "/" .. sliders .. ")")
      -- number boxes get a slider beside them; dragging it writes the setting
      local numc
      for _, c in ipairs(content and { content:GetChildren() } or {}) do
        if c.octoSlider and not numc then numc = c end
      end
      ok(numc ~= nil, "number fields get a slider")
      if numc then
        local was = numc.category[numc.config]
        local lo, hi = numc.octoSlider:GetMinMaxValues()
        numc.octoSlider:SetValue(hi)
        ok(tonumber(numc.category[numc.config]) == hi, "slider writes the number (" .. tostring(numc.category[numc.config]) .. ")")
        numc.input:SetText(tostring(hi * 3))
        local _, hi2 = numc.octoSlider:GetMinMaxValues()
        ok(hi2 >= hi * 3, "typing a bigger number widens the slider")
        numc.input:SetText(was)
      end
    end
    -- right-click lookups: a page in another category still found, any case
    ok(O:FindLegacy("Bars", "Experience Bar") == "l:XP Bar/Experience Bar", "page found outside its old category: " .. tostring(O:FindLegacy("Bars", "Experience Bar")))
    ok(O:FindLegacy("settings", "cooldown") == "l:Settings/Cooldown", "names match in any case")
    ok(O:FindLegacy("Loot") == "l:Loot", "a category without pages")
    -- an Octo slider takes a typed number (and percent for 0-1 values)
    local ar = O:Page("ctareas")
    if ar then
      local box
      for _, e in ipairs(pfUI.octoui.W.index) do
        if e.page == ar and e.label == "Opacity" then box = e.region end
      end
      local nb
      for _, k in ipairs(box and { box:GetChildren() } or {}) do if k.OnNumber then nb = k end end
      ok(nb ~= nil, "Octo sliders have a number box")
      if nb then
        local a = pfUI_config.sct.areas.inc.alpha
        nb.OnNumber("40%")
        ok(math.abs(pfUI_config.sct.areas.inc.alpha - .4) < .001, "typing 40% sets 0.4 (" .. tostring(pfUI_config.sct.areas.inc.alpha) .. ")")
        pfUI_config.sct.areas.inc.alpha = a
      end
    end
    -- O:Open by category name (meter window menu, mover right-click)
    O:Open("Meters")
    ok(O.current == "o:mtwindows", "Open(Meters) opens the new Meters pages: " .. tostring(O.current))
    -- the Find box finds Octo and pfUI settings
    O.quickFind:SetText("crit")
    local res = O.results or {}
    local octo, legacy = 0, 0
    for _, e in ipairs(res) do if e.legacy then legacy = legacy + 1 else octo = octo + 1 end end
    ok(octo > 0, "Find: combat text settings for crit (" .. octo .. ")")
    O.quickFind:SetText("castbar")
    legacy = 0
    for _, e in ipairs(O.results or {}) do if e.legacy then legacy = legacy + 1 end end
    ok(legacy > 0, "Find: pfUI settings for castbar (" .. legacy .. ")")
    local first = O.results and O.results[1]
    if first then
      local rok, rerr = pcall(function() O:Reveal(first) end)
      ok(rok, "a result opens its page: " .. tostring(rerr))
    end
    O.quickFind:SetText("")
    ok(not O.searching, "clearing Find goes back to the page")
    pfUI_config.sct.enabled = wasOn
    pfUI.gui:Hide()
  end
end

-- ---------------------------------------------------------------- action bars (Bartender)

do
  local AB = pfUI.barsOcto
  ok(AB and pfUI.bars and pfUI.bars[1], "action bars and their extras loaded")
  if AB and pfUI.bars[1] then
    local d = pfUI_config.bars.bar1
    -- scale, opacity, fade-to
    d.scale, d.alpha, d.fadeto = "1.25", ".8", ".3"
    pfUI.bars:UpdateConfig()
    ok(pfUI.bars[1].octoAlpha == .8 and pfUI.bars[1].fadeTo == .3 and pfUI.bars[1].alpha == .8, "bar opacity and fade-to applied")
    d.scale, d.alpha, d.fadeto = "1", "1", "0"
    -- visibility rules
    d.vis_combat = "combat"
    Mock.units.player = { combat = false }
    ok(not AB.Wanted(1), "a combat-only bar hides out of combat")
    Mock.units.player.combat = true
    ok(AB.Wanted(1), "and shows in combat")
    d.vis_combat = "any"
    d.vis_target = "target"
    local tgt = Mock.target
    Mock.target = nil
    ok(not AB.Wanted(1), "a target-only bar hides without a target")
    Mock.target = tgt
    d.vis_target = "any"
    Mock.units.player = nil
    -- button looks
    pfUI_config.bars.skin = "thick"
    pfUI.bars:UpdateConfig()
    local b = pfUI.bars[1][1]
    ok(b and b.octoSkin and b.octoSkin:IsShown(), "button border skin")
    for _, pr in ipairs(AB.PRESETS) do
      AB.ApplyPreset(pr[1])
      ok(AB.CurrentLook() == pr[1], "bar look " .. pr[1] .. " applies and is lit")
    end
    AB.ApplyPreset("pfui")
    -- effects (EllesmereUI's ideas): hover / press looks
    local cb = pfUI_config.bars
    cb.hover_style, cb.press_style = "inner", "border"
    pfUI.bars:UpdateConfig()
    ok(b.octoHover and b.octoHover.fill:IsShown(), "hover look painted on the highlight")
    ok(b.octoPress and b.octoPress.on and b.octoPress.edges[1]:IsShown(), "press look: border lines")
    _G.this = b
    Mock.Run(b, "OnMouseDown", "LeftButton")
    ok(b.octoPress:IsShown(), "pressing the button shows the press look")
    Mock.Run(b, "OnMouseUp", "LeftButton")
    ok(not b.octoPress:IsShown(), "letting go hides it")
    Mock.Run(b, "OnMouseDown", "LeftButton")
    Mock.now = Mock.now + 4
    _G.this = b.octoPress
    Mock.Run(b.octoPress, "OnUpdate", .1)
    ok(not b.octoPress:IsShown(), "a lost key-up never leaves the press look stuck")
    cb.hover_style, cb.press_style = "pfui", "pfui"
    -- proc glow on a reactive ability
    local usable = IsUsableAction
    IsUsableAction = function() return 1 end
    b.texture = "Interface\\Icons\\Ability_MeleeDamage"
    ok(AB.ShouldGlow(b), "Overpower glows while usable")
    IsUsableAction = function() return nil end
    ok(not AB.ShouldGlow(b), "and not when it is not")
    IsUsableAction = usable
    for _, g in ipairs(AB.GLOWS) do
      cb.glow_style = g.key
      AB.Glow(b, false)
      if b.octoGlow then b.octoGlow.lit = nil end
      AB.Glow(b, true)
      _G.this = b.octoGlow
      local good, err = pcall(Mock.Run, b.octoGlow, "OnUpdate", .1)
      ok(good and b.octoGlow:IsShown(), "glow " .. g.key .. " runs: " .. tostring(err or ""))
    end
    cb.glow_style = "ants"
    AB.Glow(b, false)
    ok(not b.octoGlow:IsShown(), "the glow goes when the reason does")
    -- "Test on my bars": every button with an action glows for a while
    b.texture = "Interface\\Icons\\Spell_Fire_FlameBolt"
    AB.Test(6)
    ok(AB.ShouldGlow(b) and b.octoGlow:IsShown(), "Test on my bars lights the buttons")
    Mock.now = Mock.now + 7
    ok(not AB.ShouldGlow(b), "and stops after its time")
    AB.Glow(b, false)
    -- cooldown swipe
    cb.cd_style = "drain"
    pfUI.bars:UpdateConfig()
    ok(b.cd.pfCooldownStyleAnimation == 0, "the game's clock hides under another swipe")
    AB.Drain(b, Mock.now, 10, 1)
    ok(b.octoDrain and b.octoDrain:IsShown() and b.octoDrain.edge:IsShown(), "drain swipe with its edge line")
    AB.Drain(b, Mock.now, 1, 1)
    ok(not b.octoDrain:IsShown(), "no swipe for the global cooldown")
    cb.cd_style = "clock"
    pfUI.bars:UpdateConfig()
    ok(b.cd.pfCooldownStyleAnimation == 1, "clock style keeps the game's clock")
    -- empty slot fill and the equipped border
    cb.slot_style = "stripes"
    pfUI.bars:UpdateConfig()
    ok(b.octoSlot and b.octoSlot:IsShown(), "empty slot fill")
    cb.slot_style = "pfui"
    pfUI.bars:UpdateConfig()
    ok(not b.octoSlot:IsShown(), "pfUI's slot again")
    if b.equipped then
      cb.eq_style = "border"
      b.equipped:Show()
      AB.Equipped(b)
      ok(b.octoEq and b.octoEq:IsShown(), "equipped items get a quality border")
      cb.eq_style = "fill"
      AB.Equipped(b)
      ok(not b.octoEq:IsShown(), "and only the tint in pfUI's style")
      b.equipped:Hide()
    end
  end
end

-- ---------------------------------------------------------------- meters phase 1: windows, looks, options

do
  local ME = pfUI.meters
  ok(ME and ME.S and ME.AddWindow, "meter windows have their own settings")
  if ME and ME.AddWindow then
    local mc = pfUI_config.meters
    ok(mc.win1 and mc.win6 and mc.win3.mode == "heal", "six windows' settings")
    -- a new window floats with its own settings
    local n0 = table.getn(ME.windows)
    local w = ME.AddWindow()
    ok(w and w.free and table.getn(ME.windows) == n0 + 1 and mc.windows == tostring(n0 + 1), "a new window (" .. tostring(mc.windows) .. ")")
    mc["win" .. w.id].rank = "0"
    mc["win" .. w.id].grow = "up"
    w.Refresh(w)
    local w1 = ME.windows[1]
    ok(ME.S(w).rank == "0" and ME.S(w1).rank ~= "0", "each window keeps its own settings")
    -- the right text in each order
    local row = { text = "48.2k", extra = "472", pct = 22 }
    local s = { showps = "1", showpct = "1", brackets = "1", order = "tps" }
    ok(string.find(ME.RightText(s, row), "^48.2k |cffaaaaaa%(472, 22%%%)"), "total (per second, percent)")
    s.order = "t"
    ok(ME.RightText(s, row) == "48.2k", "total only")
    s.order = "p"
    ok(ME.RightText(s, row) == "22%", "percent only")
    -- looks: applied and known
    ME.ApplyLook(w, "classic")
    ok(ME.CurrentLook(w) == "classic" and ME.S(w).border == "gold", "a look applies and is lit")
    -- hide out of combat
    ME.S(w).autohide = "outofcombat"
    Mock.units.player = { combat = false }
    ME.CombatLook()
    ok(w:GetAlpha() == 0, "hidden out of combat")
    ME.S(w).autohide = "never"
    ME.CombatLook()
    ok(w:GetAlpha() == 1, "shown again")
    Mock.units.player = nil
    -- phase 4: number formats
    mc.numformat = "comma"
    ok(ME.Num(1234567) == "1,234,567", "numbers with commas (" .. ME.Num(1234567) .. ")")
    mc.numformat = "full"
    ok(ME.Num(12345) == "12345", "numbers in full")
    mc.numformat = "short"
    ok(ME.Num(12345) == "12.3k", "short numbers")
    -- the status bar, with its slots
    ME.S(w).status, ME.S(w).statusleft, ME.S(w).statusright = "1", "time", "fps"
    ME.ApplyStyle(w)
    w.Refresh(w)
    ok(w.status:IsShown() and string.find(w.status.slots[1].text or "", ":") and string.find(w.status.slots[3].text or "", "fps"),
      "status bar: fight time and fps (" .. tostring(w.status.slots[1].text) .. ")")
    ME.S(w).status = "0"
    ME.ApplyStyle(w)
    ok(not w.status:IsShown(), "status bar off")
    -- test bars: the real windows show the made-up fight
    ME.TestBars(30)
    w.Refresh(w)
    local first = ME.SampleRows(w.mode)[1]
    ok(first and w.bars[1] and string.find(w.bars[1].left.text or "", first.name, 1, true),
      "test bars on a real window (" .. tostring(w.bars[1] and w.bars[1].left.text) .. ")")
    ME.testUntil = nil
    -- right-click the title: the displays used last
    local was = w.mode
    ME.SetMode(w, "interrupts")
    ok(ME.Recent()[1] == "interrupts" and w.mode == "interrupts", "a display picked goes first in the recent list")
    ME.SetMode(w, was)
    -- windows snap together
    local w2 = ME.windows[1]
    local function Box(f, l, t, r, b)
      f.GetLeft, f.GetTop, f.GetRight, f.GetBottom = function() return l end, function() return t end,
        function() return r end, function() return b end
    end
    Box(w2, 100, 500, 360, 340)
    Box(w, 368, 496, 628, 336)
    local snapped = ME.Snap(w)
    local p = w.points and w.points[1]
    ok(snapped and p and p[4] == 361 and p[5] == 500, "dropped near another window: flush, tops lined up (" ..
      tostring(p and p[4]) .. ", " .. tostring(p and p[5]) .. ")")
    w2.GetLeft, w2.GetTop, w2.GetRight, w2.GetBottom = nil, nil, nil, nil
    w.GetLeft, w.GetTop, w.GetRight, w.GetBottom = nil, nil, nil, nil
    -- layout mode closed (every mover set unmovable): the title still drags it
    -- (user, 23 Oct 2026: "Frame pfMeter3 is not movable")
    w:SetMovable(false)
    local good, err = pcall(Mock.Run, w.titlebtn, "OnDragStart")
    ok(good and w.moving, "a new window drags by its title after layout mode: " .. tostring(err))
    Mock.Run(w.titlebtn, "OnDragStop")
    -- remove it again
    ME.RemoveWindow(w.id)
    ok(table.getn(ME.windows) == n0 and mc.windows == tostring(n0), "the window is removed")

    -- the options: a preview of the window, every part opens its card
    local MO = pfUI.metersOcto
    local O = pfUI.octoui.Options
    pfUI.gui:Show()
    O:Select("o:mtwindows")
    ok(MO and MO.preview and MO.preview.preview, "the Windows page has a preview window")
    if MO and MO.preview then
      local pw = MO.preview
      ok(pw.bars[1] and pw.bars[1]:IsShown() and string.find(pw.bars[1].left.text or "", "Thrall"), "it shows the made-up fight")
      ok(pw:GetFrameStrata() == "FULLSCREEN", "above the options window")
      local missing = {}
      for part, title in pairs(MO.GO) do
        if not pfUI.plates.OpenSection("mtwindows", title) then table.insert(missing, title) end
      end
      ok(table.getn(missing) == 0, "every part opens its card (" .. table.concat(missing, ", ") .. ")")
      -- clicking the preview's title opens Title bar
      O:Select("o:mtwindows")
      pw.titlebtn:Click()
      ok(O.current == "o:mtwindows", "the preview's title opens its settings, not the mode menu")
      -- a setting reaches the preview
      local bh = mc.win1.barheight
      mc.win1.barheight = "24"
      MO.cur = 1
      MO.Apply()
      ok(pw.bars[1]:GetHeight() == 24, "bar height reaches the preview")
      mc.win1.barheight = bh
      MO.Apply()
      -- Shift + wheel: taller bars
      Mock.shift = true
      _G.arg1 = 1
      Mock.Run(pw, "OnMouseWheel", 1)
      Mock.shift = nil
      ok(mc.win1.barheight == tostring(tonumber(bh) + 1), "Shift + wheel: taller bars")
      mc.win1.barheight = bh
      MO.Apply()
    end
    -- the threat preview: drag the label, Shift + wheel its size, right-click back
    O:Select("o:mtthreat")
    local tp = MO and MO.threatPreview
    ok(tp and tp.label and tp.plate, "the Threat page has a preview with a label")
    if tp and tp.label then
      local l = tp.label
      mc.tlabel, mc.tlook, mc.twhere, mc.tx, mc.ty, mc.tsize = "1", "words", "above", "0", "2", "13"
      tp.holder.t = 0
      Mock.Run(tp.holder, "OnUpdate", .05)
      ok(l:IsShown() and l.point and l.point[2] == tp.plate, "label sits on the mock plate")
      Mock.cx, Mock.cy = 500, 500
      _G.arg1 = "LeftButton"
      Mock.Run(l, "OnMouseDown", "LeftButton")
      Mock.cx, Mock.cy = 540, 520
      Mock.Run(tp.holder, "OnUpdate", .05)
      _G.arg1 = "LeftButton"
      Mock.Run(l, "OnMouseUp", "LeftButton")
      local k = tp.holder:GetEffectiveScale() or 1
      ok(mc.tx == tostring(math.floor(40 / k + .5)) and mc.ty == tostring(math.floor(2 + 20 / k + .5)), "dragging the label moves it (" .. mc.tx .. ", " .. mc.ty .. ")")
      ok(O.current == "o:mtthreat", "a drag is not a click")
      Mock.shift = true
      _G.arg1 = 1
      Mock.Run(l, "OnMouseWheel", 1)
      Mock.shift = nil
      ok(mc.tsize == "14", "Shift + wheel: bigger text")
      _G.arg1 = "RightButton"
      Mock.Run(l, "OnMouseUp", "RightButton")
      ok(mc.tx == "0" and mc.ty == "2" and mc.tsize == "13", "right-click puts it back")
    end
    -- the chat pages: a preview with a line of every kind, cards for each part
    local CHO = pfUI.chatOcto
    if CHO then
      for _, k in ipairs({ "o:chwindows", "o:chmessages", "o:chinput", "o:chtools" }) do O:Select(k) end
      ok(O.pages.chwindows and O.pages.chmessages and O.pages.chinput, "Chat: Windows, Messages, Typing and bubbles")
      local tx = pfUI_config.chat.text
      local was = { tx.time, tx.timeformat, tx.channelnumonly, tx.classcolor }
      tx.time, tx.timeformat, tx.channelnumonly, tx.classcolor = "1", "%H:%M", "1", "1"
      local stamp, text = CHO.Format({ "CHANNEL", "Rexxar", "HUNTER", "LFM", channel = "2. Trade" })
      ok(stamp ~= "" and string.find(text, "[2]", 1, true) and not string.find(text, "Trade", 1, true), "a channel line: time, [2], no name of the channel")
      tx.channelnumonly = "0"
      stamp, text = CHO.Format({ "CHANNEL", "Rexxar", "HUNTER", "LFM", channel = "2. Trade" })
      ok(string.find(text, "2. Trade", 1, true), "and with the channel's name")
      tx.time = "0"
      stamp = CHO.Format({ "GUILD", "Thrall", "SHAMAN", "hi" })
      ok(stamp == "", "no time when timestamps are off")
      tx.time, tx.timeformat, tx.channelnumonly, tx.classcolor = was[1], was[2], was[3], was[4]
      -- every card a line or part opens exists
      local missing = {}
      for _, card in ipairs({ "Left window", "Loot & Spam window", "Tabs and dock", "Lines", "Timestamps", "Channel names",
                               "Names", "Links", "Whispers", "Text", "Typing box", "Chat bubbles" }) do
        CHO.Open(card)
        local found
        for _, pg in pairs({ O.pages.chwindows, O.pages.chmessages, O.pages.chinput }) do
          for _, c in ipairs(pg.cards or {}) do if c.title == card then found = true end end
        end
        if not found then table.insert(missing, card) end
      end
      ok(table.getn(missing) == 0, "every part of the chat preview opens a card (" .. table.concat(missing, ", ") .. ")")
      -- the switches: timestamps on and off from the preview
      local tsw
      for _, t in ipairs(CHO.TOGGLES) do if t.key == "time" then tsw = t end end
      local before = tx.time
      tsw.set(not tsw.on())
      ok(tx.time ~= before, "the Timestamps switch flips the real setting")
      tsw.set(before == "1")
      -- a look lights up when it is in use
      local gl = pfUI_config.chat.global
      local keep = { tx.time, tx.timeformat, tx.channelnumonly, tx.classcolor, gl.custombg, gl.background, gl.border, gl.tabdock, gl.frameshadow }
      CHO.ApplyLook("clean")
      ok(CHO.CurrentLook() == "clean", "a look picked is the look in use")
      tx.time, tx.timeformat, tx.channelnumonly, tx.classcolor, gl.custombg, gl.background, gl.border, gl.tabdock, gl.frameshadow =
        keep[1], keep[2], keep[3], keep[4], keep[5], keep[6], keep[7], keep[8], keep[9]
    end
    -- chat phase 2: tags, filters, highlights, levels, /find, sounds, invites
    local CP = pfUI.chatPlus
    ok(CP and O.pages.chtools, "chat features loaded, Tools page built")
    if CP then
      local pl = pfUI_config.chat.plus
      local keep = { pl.tags, pl.hide, pl.throttle, pl.words, pl.mention, pl.levels, pl.sound_guild, pl.autoinvite }
      pl.tags = "Trade=T, World=W"
      ok(CP.Pre("[2. Trade] |Hplayer:Bob|h[Bob]|h: wts") == "[T] |Hplayer:Bob|h[Bob]|h: wts", "own channel tag")
      ok(CP.Pre("[4. LookingForGroup] |Hplayer:Bob|h[Bob]|h: lfg") == "[4. LookingForGroup] |Hplayer:Bob|h[Bob]|h: lfg",
        "a channel without a tag stays as it was")
      pl.hide = "gold, cheap"
      ok(CP.Pre("|Hplayer:Spam|h[Spam]|h: CHEAP GOLD") == nil and CP.Pre("You receive gold.") == "You receive gold.",
        "hidden words drop player lines only")
      pl.hide, pl.throttle = "", "10"
      local line = "|Hplayer:Rex|h[Rex]|h: LFM MC"
      ok(CP.Pre(line) == line and CP.Pre(line) == nil, "the same line again too soon is dropped")
      pl.throttle, pl.words, pl.mention = "0", "onyxia", "1"
      local me = UnitName("player") or "Tester"
      local out = CP.Post(nil, "|Hplayer:Malf|h[Malf]|h: " .. me .. " are we doing onyxia?")
      ok(string.find(out, "|Hplayer:Malf|h[Malf]|h: ", 1, true) and string.find(out, "|r are we doing ", 1, true)
        and string.find(out, "onyxia|r", 1, true), "your name and words highlighted, the name link untouched")
      CP.levels.Malf = 60
      pl.levels = "1"
      ok(string.find(CP.Post(nil, "|Hplayer:Malf|h[Malf]|h: hi"), ":60", 1, true)
        and CP.Post(nil, "|Hplayer:Nobody|h[Nobody]|h: hi") == "|Hplayer:Nobody|h[Nobody]|h: hi", "levels next to known names only")
      CP.buffer = { [1] = { "|Hplayer:A|h[A]|h: hello world", "nothing here" } }
      ok(table.getn(CP.Find("WORLD")) == 1, "/find finds a word in any case")
      -- a sound for guild, a popup and invite on a keyword
      local played
      local playWas = CP.Play
      CP.Play = function(k) played = k end
      pl.sound_guild, pl.words, pl.mention = "RaidWarning", "", "0"
      CP.OnMessage("CHAT_MSG_GUILD", "hi all", "Thrall")
      ok(played == "RaidWarning", "a sound for guild messages")
      CP.Play = playWas
      local invited
      local invWas = _G.InviteByName
      _G.InviteByName = function(n) invited = n end
      pl.autoinvite, pl.inviteword = "1", "inv"
      local partyWas = Mock.party
      Mock.party = 0
      CP.OnMessage("CHAT_MSG_WHISPER", "INV", "Jaina")
      Mock.party = partyWas
      ok(invited == "Jaina", "a whispered invite word invites")
      _G.InviteByName = invWas
      pl.tags, pl.hide, pl.throttle, pl.words, pl.mention, pl.levels, pl.sound_guild, pl.autoinvite =
        keep[1], keep[2], keep[3], keep[4], keep[5], keep[6], keep[7], keep[8]
    end
    -- chat phase 3: whisper windows
    local WHm = pfUI.whispers
    ok(WHm and O:Select("o:chwhispers") == nil and O.pages.chwhispers, "whisper windows loaded, Whispers page built")
    if WHm then
      local ws = pfUI_config.chat.whisper
      local keepMode, keepCombat = ws.mode, ws.combat
      ws.mode = "window"
      WHm.OnEvent("CHAT_MSG_WHISPER", "hello there", "Jaina")
      local wf = WHm.windows.Jaina
      ok(wf and wf:IsShown() and wf.unread == 1, "a whisper opens a window, one unread")
      WHm.OnEvent("CHAT_MSG_WHISPER_INFORM", "hi!", "Jaina")
      local kept = pfUI_cache.whispers
      local n = 0
      for _, list in pairs(kept) do if list.Jaina then n = table.getn(list.Jaina) end end
      ok(n == 2, "both lines kept for next time (" .. n .. ")")
      WHm.Seen(wf)
      ok(wf.unread == 0, "looking at it clears the count")
      WHm.Fold(wf, true)
      ok(wf.folded and not wf.msg:IsShown(), "it folds")
      WHm.Fold(wf, false)
      WHm.Close("Jaina")
      ok(not wf:IsShown(), "and closes")
      -- in combat: waits until the fight ends
      ws.combat = "wait"
      local combatWas = UnitAffectingCombat
      _G.UnitAffectingCombat = function() return true end
      WHm.OnEvent("CHAT_MSG_WHISPER", "inc!", "Garrosh")
      ok(not WHm.windows.Garrosh and WHm.queue.Garrosh, "a whisper in a fight waits")
      _G.UnitAffectingCombat = combatWas
      WHm.OnEvent("PLAYER_REGEN_ENABLED")
      ok(WHm.windows.Garrosh and WHm.windows.Garrosh:IsShown(), "and opens when it ends")
      -- the test window talks only to itself
      local sent
      local sendWas = _G.SendChatMessage
      _G.SendChatMessage = function() sent = true end
      local tf = WHm.Test()
      WHm.Send(WHm.TEST, "testing")
      ok(tf and tf.test and not sent, "the test window sends nothing")
      _G.SendChatMessage = sendWas
      WHm.CloseAll()
      ws.mode, ws.combat = keepMode, keepCombat
    end
    -- the swing timer: its page and preview, then the engine
    local SW = pfUI.swing
    O:Select("o:stbars")
    ok(SW and O.pages.stbars and pfUI.swingOcto and pfUI.swingOcto.bars and pfUI.swingOcto.bars.player, "Swing Timer page with a preview")
    if SW then
      local st = SW.state
      local now0 = GetTime()
      -- SuperWoW tells the hand
      local _, pg = UnitExists("player")
      SW.OnEvent("UNIT_CASTEVENT", pg, nil, "OFFHAND", 0)
      ok(math.abs(st.ohStart - now0) < .01, "SuperWoW: an off hand swing restarts the off hand")
      st.sw = nil
      -- the combat log: the hand nearest its end takes the swing
      st.dual, st.mhSpeed, st.ohSpeed = true, 2, 2
      st.mhStart, st.ohStart = now0 - 1.9, now0 - .5
      SW.OnEvent("CHAT_MSG_COMBAT_SELF_HITS", "You hit Ogre for 120.")
      ok(math.abs(st.mhStart - now0) < .01 and st.ohStart < now0 - .4, "the combat log swing goes to the hand nearest its end")
      -- parry haste: you parry -> your swing comes sooner, but not under 20% left
      st.mhStart, st.mhSpeed = now0 - .2, 2
      SW.OnEvent("CHAT_MSG_COMBAT_CREATURE_VS_SELF_MISSES", "Ogre attacks. You parry.")
      local left = st.mhSpeed - (now0 - st.mhStart)
      ok(math.abs(left - 1.0) < .02, "a parry takes 40% of the swing off (" .. string.format("%.2f", left) .. " s left)")
      -- the target's swing, by its name
      local tnWas = UnitName
      _G.UnitName = function(u) if u == "target" then return "Ogre" end return tnWas(u) end
      st.tgStart = 0
      SW.OnEvent("CHAT_MSG_COMBAT_CREATURE_VS_SELF_HITS", "Ogre hits you for 50.")
      ok(math.abs(st.tgStart - now0) < .01, "the target's swing from the combat log")
      _G.UnitName = tnWas
      -- drawing: half way through = half the bar, the queued colour on it
      local f = SW.bars.player
      SW.ApplyLayout()
      st.mhStart, st.mhSpeed, st.queued = now0 - 1, 2, "queue"
      SW.Paint(f, "player", now0)
      ok(math.abs((f.main.fill:GetWidth() or 0) - 150) < 1, "half way: half the bar (" .. tostring(f.main.fill:GetWidth()) .. ")")
      st.queued = nil
      -- a wand: one bar over the whole shot time, full = ready (user, 24 Oct 2026)
      local rf = SW.bars.ranged
      st.wand = true
      SW.ApplyLayout()
      st.rgStart, st.rgSpeed = now0 - .75, 1.5
      SW.Paint(rf, "ranged", now0)
      ok(not rf.off:IsShown() and math.abs(rf.main.fill:GetWidth() - 150) < 1 and rf.main.left:GetText() == "Wand",
        "a wand is one bar, half full half way to the next shot (" .. tostring(rf.main.fill:GetWidth()) .. ")")
      -- SuperWoW tells the shot; the combat log line when it lands must not restart it
      local _, pg2 = UnitExists("player")
      SW.OnEvent("UNIT_CASTEVENT", pg2, nil, "CAST", 5019)
      local shotAt = st.rgStart
      Mock.now = Mock.now + .6
      SW.OnEvent("CHAT_MSG_SPELL_SELF_DAMAGE", "Your Shoot hits Ogre for 80 Shadow damage.")
      ok(st.rgStart == shotAt, "the shot's combat log line does not restart the wand bar")
      Mock.now = Mock.now - .6
      st.rsw = nil
      -- moving near the end does not hold a wand back (only a hunter's aim)
      st.rgStart, st.rgSpeed = GetTime() - 1.3, 1.5
      st.px, st.py = .1, .1
      local gpmp = GetPlayerMapPosition
      _G.GetPlayerMapPosition = function() return .2, .2 end
      Mock.Run(SW.ticker, "OnUpdate", .02)
      _G.GetPlayerMapPosition = gpmp
      ok(math.abs((GetTime() - st.rgStart) - 1.3) < .01, "moving does not restart a wand")
      -- ranged (hunters): reload, then the aim
      st.wand = false
      SW.ApplyLayout()
      st.rgStart, st.rgSpeed = now0 - 2.7, 3
      SW.Paint(rf, "ranged", now0)
      ok(rf.main.fill:GetWidth() >= 299 and rf.off.fill:GetWidth() > 100, "after the reload the aim fills")
      -- the clip zone: hunters' Auto Shot only (in game it covered half a wand bar)
      local ucWas = UnitClass
      _G.UnitClass = function(u) if u == "player" then return "Hunter", "HUNTER" end return ucWas(u) end
      st.wand = false
      SW.Paint(rf, "ranged", now0)
      ok(rf.main.clip:IsShown() and math.abs(rf.main.clip:GetWidth() - 60) < 1, "the Multi-Shot clip zone: the reload's last half second ("
        .. tostring(rf.main.clip:GetWidth()) .. ")")
      SW.Shot(true)
      st.rgStart = now0 - 2.7
      SW.Paint(rf, "ranged", now0)
      ok(not rf.main.clip:IsShown(), "no clip zone for a wand")
      st.wand = false
      _G.UnitClass = function(u) if u == "player" then return "Priest", "PRIEST" end return ucWas(u) end
      SW.Paint(rf, "ranged", now0)
      ok(not rf.main.clip:IsShown(), "no clip zone for other classes")
      _G.UnitClass = ucWas
      -- Cooldown Manager border: round ends at their own shape, a straight back
      pfUI_config.swing.look.border = "cdm"
      SW.ApplyLayout()
      local pb = SW.bars.player.main
      local h0 = tonumber(pfUI_config.swing.player.height) or 12
      ok(pb.border.capL:IsShown() and math.abs(pb.border.capL:GetWidth() - (h0 + 8) / 2) < .01 and pb.back:GetTexture() == "Interface\\Buttons\\WHITE8X8",
        "Cooldown Manager border: ends not stretched, straight back (" .. tostring(pb.border.capL:GetWidth()) .. ")")
      -- the round ends sit outside the bar (its square ends stay inside the straight part)
      local _, _, _, bx = pb.border:GetPoint(1)
      ok(math.abs((bx or 0) + (h0 + 8) / 2) < .01 and pb.backL:IsShown() and pb.backR:IsShown(),
        "round ends outside the bar, filled dark (frame starts " .. tostring(bx) .. " px left of the bar)")
      pfUI_config.swing.look.border = "pixel"
      SW.ApplyLayout()
      ok(not pb.border.capL:IsShown() and not pb.backL:IsShown(), "other borders have no end pieces")
      pfUI_config.swing.look.border = "cdm"
      SW.ApplyLayout()
      -- the texts sit over the border art
      ok(rf.main.text and rf.main.text:GetFrameLevel() > rf.main.border:GetFrameLevel() and rf.main.left:GetParent() == rf.main.text,
        "bar texts above the border")
      -- layout mode shows every bar, and leaving it ends the made-up fight
      for k in pairs(pfUI.movables) do if type(k) ~= "string" then pfUI.movables[k] = nil end end
      pfUI.unlock:Show()
      local tick = SW.ticker
      if tick then
        Mock.Run(tick, "OnUpdate", .02)
        ok(SW.bars.ranged:IsShown() and SW.bars.target:IsShown() and SW.bars.cast:IsShown(), "layout mode shows every swing bar to place")
        pfUI.unlock:Hide()
        Mock.Run(tick, "OnUpdate", .02)
        ok(not SW.bars.cast:IsShown() and not SW.testUnlock, "and they go when layout mode ends")
      end
      pfUI.unlock:Hide()
      -- the cast bar: Aimed Shot from SPELLCAST_START, pushed back, stopped
      local cf = SW.bars.cast
      SW.OnEvent("SPELLCAST_START", "Aimed Shot", 3000)
      ok(st.cast and st.cast.kind == "aimed" and math.abs(st.cast.dur - 3) < .01, "Aimed Shot starts the cast bar")
      SW.OnEvent("SPELLCAST_DELAYED", 500)
      ok(math.abs(st.cast.dur - 3.5) < .01, "a push back makes the cast longer")
      st.cast.start = now0 - 1.75
      pfUI_config.swing.cast.latency = "1"
      local gnsWas = _G.GetNetStats
      _G.GetNetStats = function() return 0, 0, 350 end
      SW.Paint(cf, "cast", now0)
      ok(math.abs(cf.main.fill:GetWidth() - 150) < 1, "the cast bar: half way, half the bar")
      ok(cf.main.lag:IsShown() and math.abs(cf.main.lag:GetWidth() - 30) < 1, "the latency part: 350 ms of 3.5 s ("
        .. tostring(cf.main.lag:GetWidth()) .. ")")
      _G.GetNetStats = gnsWas
      pfUI_config.swing.cast.latency = "0"
      SW.OnEvent("SPELLCAST_START", "Frostbolt", 3000)
      ok(st.cast and st.cast.kind == "aimed", "other spells leave the cast bar alone")
      SW.OnEvent("SPELLCAST_INTERRUPTED")
      ok(st.cast == nil, "an interrupt ends the cast bar")
      pfUI_config.swing.cast.multi = "0"
      SW.OnEvent("SPELLCAST_START", "Multi-Shot", 500)
      ok(not SW.CastWanted(st.cast and st.cast.kind), "Multi-Shot switched off: no cast bar")
      st.cast = nil
      pfUI_config.swing.cast.multi = "1"
      -- Slam and seal twisting marks (the preview state shows them for every class)
      local ps = pfUI.swingOcto.state
      ps.mhStart, ps.mhSpeed = now0 - 1, 3
      pfUI_config.swing.paladin.twist, pfUI_config.swing.paladin.gcd = "1", "1"
      local pf = pfUI.swingOcto.bars.player
      SW.ApplyLayout()
      pfUI.swingOcto.Layout()
      SW.Paint(pf, "player", now0, ps)
      ok(pf.main.slam:IsShown() and math.abs(pf.main.slam:GetWidth() - 10) < 1, "the Slam window: 0.1 s of a 3 s swing ("
        .. tostring(pf.main.slam:GetWidth()) .. ")")
      ok(pf.main.gcd:IsShown() and pf.main.mark1:IsShown() and pf.main.mark2:IsShown(), "the GCD spark and both paladin lines")
      pfUI_config.swing.paladin.twist, pfUI_config.swing.paladin.gcd = "0", "0"
      pfUI_config.swing.warrior.slam = "0"
      SW.Paint(pf, "player", now0, ps)
      ok(not pf.main.slam:IsShown() and not pf.main.mark1:IsShown(), "the marks go when switched off")
      pfUI_config.swing.warrior.slam = "1"
      local _, cls = UnitClass("player")
      ok(not SW.SlamShown(st) or cls == "WARRIOR", "no Slam marks on the real bar for other classes")
      -- every look draws
      for _, b in ipairs(SW.BORDERS) do
        pfUI_config.swing.look.border = b.key
        local good, err = pcall(SW.ApplyLayout)
        ok(good, "border " .. b.key .. ": " .. tostring(err))
      end
      pfUI_config.swing.look.border = "cdm"
      SW.Test(5)
      ok(SW.testUntil and SW.state.tgSeen, "Test on my bars starts a made-up fight")
      SW.testUntil = nil
      SW.ApplyLayout()
    end
    -- the minimap pages: a preview whose parts are picked, moved and sized
    local MMO = pfUI.minimapOcto
    O:Select("o:mmmap")
    O:Select("o:mmparts")
    ok(MMO and MMO.Current().hots and MMO.Current().hots.mail and MMO.Current().hots.map and MMO.Current().hots.bar, "the Minimap pages have a preview with every part")
    ok(O.pages.mmmap and O.pages.mmparts and not O.pages.mmart, "two Minimap pages: Map, Buttons and text")
    if MMO and MMO.Current().hots then
      local ms = pfUI_config.mapstyle
      -- clicking a part picks it: the Part card follows
      Mock.Run(MMO.Current().hots.mail, "OnClick", "LeftButton")
      ok(MMO.sel == "mail" and O.current == "o:mmparts", "clicking a part picks it")
      local h = MMO.Current().hots.tracking
      local x0, y0 = pfUI.minimap.PartOffset(pfUI.minimap.Part("tracking"))
      Mock.cx, Mock.cy = 300, 300
      _G.arg1 = "LeftButton"
      Mock.Run(h, "OnMouseDown", "LeftButton")
      Mock.cx, Mock.cy = 330, 300
      Mock.Run(h:GetParent(), "OnUpdate", .05)
      _G.arg1 = "LeftButton"
      Mock.Run(h, "OnMouseUp", "LeftButton")
      ok(tonumber(ms.trackingx) and tonumber(ms.trackingx) > x0 and tonumber(ms.trackingy) == y0, "dragging a part in the preview moves it (" .. tostring(ms.trackingx) .. ")")
      Mock.Run(h, "OnClick", "LeftButton")
      ok(MMO.sel == "mail", "a drag is not a click")
      Mock.shift = true
      _G.arg1 = 1
      Mock.Run(h, "OnMouseWheel", 1)
      Mock.shift = nil
      ok(ms.trackingscale == "110", "Shift + wheel makes it bigger")
      _G.arg1 = "RightButton"
      Mock.Run(h, "OnClick", "RightButton")
      ok(ms.trackingx == "" and ms.trackingscale == "100", "right-click puts it back")
      -- Never: left out of the preview (unless picked) and off in game
      MMO.SetMode("zone", "hide")
      MMO.Layout()
      ok(pfUI_config.appearance.minimap.zonetext == "off" and not MMO.Current().hots.zone:IsShown() and not pfMinimapZone:IsShown(), "zone name off: gone from the preview and the map")
      MMO.SetMode("bar", "hide")
      ok(pfUI_config.panel.other.minimap == "none" and pfPanelMinimap and not pfPanelMinimap:IsShown(), "the bar under the map hides at once")
      MMO.SetMode("bar", "show")
      ok(pfUI_config.panel.other.minimap ~= "none" and pfPanelMinimap:IsShown(), "and comes back with its words")
      MMO.SetMode("zone", "hover")
      -- the bar under the map moves like any part
      pfUI.minimap.MovePart("bar", 10, -20)
      ok(pfPanelMinimap.point and pfPanelMinimap.point[1] == "TOP" and pfPanelMinimap.point[3] == "BOTTOM", "the bar hangs under the map where you put it")
      pfUI.minimap.ResetPart("bar")
      -- the map itself: Shift + wheel = size, drag = move on screen
      local was = pfUI_config.appearance.minimap.size
      Mock.shift = true
      _G.arg1 = 1
      Mock.Run(MMO.Current().hots.map, "OnMouseWheel", 1)
      Mock.shift = nil
      ok(pfUI_config.appearance.minimap.size == tostring((tonumber(was) or 140) + 5), "Shift + wheel over the map: bigger map")
      pfUI_config.appearance.minimap.size = was
      pfUI.minimap:UpdateConfig()
      Mock.cx, Mock.cy = 300, 300
      _G.arg1 = "LeftButton"
      Mock.Run(MMO.Current().hots.map, "OnMouseDown", "LeftButton")
      Mock.cx, Mock.cy = 280, 290
      Mock.Run(MMO.Current().hots.map:GetParent(), "OnUpdate", .05)
      Mock.Run(MMO.Current().hots.map, "OnMouseUp", "LeftButton")
      ok(pfUI_config.position.pfMinimap and pfUI_config.position.pfMinimap.anchor == "TOPLEFT", "dragging the map moves it and saves its place")
      pfUI_config.position.pfMinimap = nil
    end
    -- addon buttons: each one in the panel, on the map or hidden
    if pfUI.addonbuttons and pfUI.addonbuttons.SetPlace then
      local fake = CreateFrame("Button", "OctoTestMinimapButton", Minimap)
      fake:SetWidth(20)
      fake:SetHeight(20)
      fake:SetScript("OnClick", function() end)
      fake:SetPoint("TOPLEFT", Minimap, "TOPLEFT", 0, 0)
      pfUI.addonbuttons:ProcessButtons()
      local found
      for _, n in ipairs(pfUI.addonbuttons:List()) do if n == "OctoTestMinimapButton" then found = true end end
      ok(found and pfUI.addonbuttons:GetPlace("OctoTestMinimapButton") == "panel", "a new addon button is gathered")
      pfUI.addonbuttons:SetPlace("OctoTestMinimapButton", "hide")
      ok(pfUI.addonbuttons:GetPlace("OctoTestMinimapButton") == "hide" and fake.alpha == 0, "and can be hidden")
      pfUI.addonbuttons:SetPlace("OctoTestMinimapButton", "map")
      ok(pfUI.addonbuttons:GetPlace("OctoTestMinimapButton") == "map" and fake.alpha == 1, "or left on the map")
      -- buttons made elsewhere and only anchored to the map are not looked for
      -- (that scan crashed the client at login; /abp add takes them by hand)
      if not MinimapCluster:GetParent() then MinimapCluster:SetParent(UIParent) end
      local loose = CreateFrame("Button", "OctoLooseMapButton", MinimapCluster)
      loose:SetWidth(24)
      loose:SetHeight(24)
      loose:SetPoint("BOTTOMLEFT", Minimap, "BOTTOMLEFT", 0, 0)
      loose:SetScript("OnClick", function() end)
      local foundLoose
      for _, n in ipairs(pfUI.addonbuttons:List()) do if n == "OctoLooseMapButton" then foundLoose = true end end
      ok(not foundLoose, "a button made elsewhere and anchored to the map is not searched for")
      loose:Hide()
      local ownSpot
      for _, n in ipairs(pfUI.addonbuttons:List()) do if string.find(n, "^pf") then ownSpot = n end end
      ok(not ownSpot, "pfUI's own parts are left alone (" .. tostring(ownSpot) .. ")")
      -- a lit button row: on while its check says so
      local litOn = false
      local litPage = { items = {}, cur = { parent = UIParent, x0 = 0, y0 = 0, lastX = 0, width = 600 } }
      local okRow, litRow = pcall(pfUI.octoui.W.Buttons, litPage, { { "Try", function() litOn = not litOn end, nil, nil, on = function() return litOn end } })
      local lb = okRow and litRow and ({ litRow:GetChildren() })[1]
      ok(lb and not lb.picked, "a toggle button starts off")
      if lb then
        Mock.Run(lb, "OnClick")
        ok(lb.picked, "and is lit once on")
      end
      pfUI.addonbuttons:SetPlace("OctoTestMinimapButton", "panel")
    end
    pfUI.gui:Hide()
  end
end

-- ---------------------------------------------------------------- unit frame extras (TPerl's ideas)

do
  local X = pfUI.ufExtras
  local f = pfUI.uf and pfUI.uf.player
  ok(X and f and f.octoClass and f.octoFlash and f.octoSkin, "unit frame extras built on the player frame")
  if X and f then
    local c = pfUI_config.unitframes.player
    -- border skin and the shade behind the bars
    c.o_skin, c.o_grad = "gold", "VERTICAL"
    f:UpdateConfig()
    ok(f.octoSkin:IsShown() and f.hp.bar.octoGrad and f.hp.bar.octoGrad:IsShown(), "border skin and bar shade")
    c.o_skin, c.o_grad = "pfui", "none"
    f:UpdateConfig()
    ok(not f.octoSkin:IsShown() and not f.hp.bar.octoGrad:IsShown(), "and off again")
    -- combat flash
    X.Flash(f, false)
    ok(f.octoFlash:IsShown(), "a hit flashes the frame")
    Mock.now = Mock.now + 1
    _G.this = X.watch
    Mock.Run(X.watch, "OnUpdate", .1)
    ok(not f.octoFlash:IsShown(), "the flash fades out")
    -- debuff highlight in the debuff's colour
    c.o_debuffhl, c.o_curable = "both", "0"
    Mock.units.player = { faction = Mock.faction, debuffs = { { "Interface\\Icons\\Spell_Shadow_ShadowWordPain", 1, "Magic" } } }
    X.Update(f)
    ok(f.octoDebuff:IsShown() and f.octoDebuffBg:IsShown(), "a magic debuff colours the border and background")
    Mock.units.player = nil
    X.Update(f)
    ok(not f.octoDebuff:IsShown(), "gone with the debuff")
    c.o_debuffhl = "none"
    -- elite / rare badge, status words
    c.o_elite = "graphic"
    f.octoForceElite = "rare"
    X.Update(f)
    ok(f.octoElite:IsShown() and string.find(f.octoElite.texture or "", "uf%-rare"), "rare badge")
    c.o_elite = "text"
    f.octoForceElite = "worldboss"
    X.Update(f)
    ok(f.octoEliteText:IsShown() and f.octoEliteText:GetText() == "Boss", "boss as a word")
    f.octoForceElite, c.o_elite = nil, "none"
    f.octoForceStatus = { nil, "Dead", Mock.now + 3 }
    X.Update(f)
    ok(f.octoStatusText:IsShown() and f.octoStatusText:GetText() == "Dead", "dead mark")
    f.octoForceStatus = nil
    X.Update(f)
    -- class icon
    c.o_classicon = "TOPLEFT"
    f:UpdateConfig()
    ok(f.octoClass:IsShown(), "class icon on a player")
    c.o_classicon = "none"
    -- fading bar: the lost health stays and shrinks away
    c.o_fade = "1"
    f:UpdateConfig()
    -- (the bar's value, as pfUI sets it from the unit)
    f.hp.bar:SetMinMaxValues(0, 100)
    f.hp.bar:SetValue(100)
    Mock.Run(X.watch, "OnUpdate", .1)
    f.hp.bar:SetValue(40)
    Mock.now = Mock.now + .05
    Mock.Run(X.watch, "OnUpdate", .05)
    ok(f.octoGhost:IsShown() and f.octoGhostFrac > .4, "the lost health shows a moment (" .. tostring(f.octoGhostFrac) .. ")")
    for i = 1, 40 do
      Mock.now = Mock.now + .05
      Mock.Run(X.watch, "OnUpdate", .05)
    end
    ok(not f.octoGhost:IsShown(), "and fades away")
    Mock.playerHp, c.o_fade = nil, "0"
    f:UpdateConfig()
    -- more bar textures in every texture menu
    local found = 0
    for _, e in ipairs(pfUI.gui.dropdowns.uf_bartexture) do if string.find(e, ":Octo ") then found = found + 1 end end
    ok(found == table.getn(X.BARS), "our bar textures in the texture menus (" .. found .. ")")
  end
end

-- ---------------------------------------------------------------- unit frames section

do
  local UF = pfUI.ufOcto
  local O = pfUI.octoui and pfUI.octoui.Options
  ok(UF and O, "unit frames section loaded")
  if UF and O then
    local sec
    for _, s in ipairs(O.octo) do if s[1] == "Unit Frames" then sec = s end end
    ok(sec and table.getn(sec[2]) == 3, "Unit Frames: three pages (Frames, Click casting, Cast bars) instead of fifteen")
    local old = 0
    for k in pairs(O.legacy) do if string.find(k, "^l:Unit Frames") then old = old + 1 end end
    ok(old == 0, "pfUI's own Unit Frames pages are gone from the list")
    pfUI.gui:Show()
    for _, pg in ipairs(sec and sec[2] or {}) do
      local good, err = pcall(function() O:Select("o:" .. pg[1]) end)
      ok(good and O.pages[pg[1]] and O.pages[pg[1]].frame:IsShown(), "page " .. pg[1] .. " builds and shows: " .. tostring(err))
    end
    O:Select("o:ufframes")
    local M = UF.mini
    ok(M and M.sets.player and table.getn(M.sets.player.frames) == 1, "the preview shows the player frame")
    -- a text's own colour, over its colour codes
    if M and M.sets.player then
      local pf = M.sets.player.frames[1]
      local pc = pfUI_config.unitframes.player
      pc.o_tc_hpleft, pc.o_tcc_hpleft = "custom", "1,0,0,1"
      local s = pfUI.uf:GetStatusValue(pf, "hpleft")
      ok(not s or s == "" or string.find(s, "^|cffff0000") and not string.find(string.sub(s, 11), "|c", 1, true), "one colour on a text (" .. tostring(s) .. ")")
      pc.o_tc_hpleft = ""
      UF.Open("hpright")
      ok(UF.text == "hpright", "clicking the right health text opens its own tab")
      UF.text = "hpleft"
    end
    if M and M.sets.player then
      local f = M.sets.player.frames[1]
      ok(f.octoPreview and f.label == "player" and f:GetParent() == M.sets.player, "a real pfUI frame, on your character, inside the box")
      ok(f:GetFrameStrata() == "FULLSCREEN" and f.hp:GetFrameStrata() == "FULLSCREEN", "drawn above the options window")
      ok(f:GetScript("OnClick") == nil and f:GetScript("OnUpdate") == nil, "the preview frame does nothing on its own")
      -- every part has a spot, and every spot opens its own card
      local kinds = {}
      for _, h in ipairs(M.sets.player.hots) do kinds[h.what] = true end
      local missing = {}
      for what in pairs(UF.GO) do
        if not kinds[what] then table.insert(missing, "no spot: " .. what) end
        if not pfUI.plates.OpenSection("ufframes", UF.GO[what]) then table.insert(missing, "no card: " .. UF.GO[what]) end
      end
      ok(table.getn(missing) == 0, "every part of the frame opens its own card (" .. table.concat(missing, ", ") .. ")")
      -- the cast bar under the frame opens the Cast bars page on its tab
      local cbh
      for _, h in ipairs(M.sets.player.hots) do if h.what == "castbar" then cbh = h end end
      ok(cbh and M.sets.player.castbar, "the player frame's preview has its cast bar")
      local pcb = M.sets.player.castbar
      M.CastTick(3000 + 1)
      local v1 = pcb.val or (pcb.GetValue and pcb:GetValue())
      M.CastTick(3000 + 1.05)
      local v2 = pcb.val or (pcb.GetValue and pcb:GetValue())
      ok(v1 and v2 and v2 > v1 and v2 - v1 < 5, "the sample cast fills in small steps (" .. tostring(v1) .. " -> " .. tostring(v2) .. ")")
      if cbh then
        _G.this = cbh
        Mock.Run(cbh, "OnClick", "LeftButton")
        ok(O.current == "o:ufcastbar" and pfUI.castbarOcto.cur == "player", "clicking it opens Cast bars on Player")
        O:Select("o:ufframes")
      end
      -- sample buffs and marks so they can be clicked
      local b1 = f.buffs and f.buffs[1]
      ok(b1 and b1:IsShown(), "sample buffs on the preview")
      ok(f.raidIcon:IsShown(), "sample raid mark on the preview")
      -- a setting changes the preview (and the real frame)
      local C = pfUI_config
      local h0 = C.unitframes.player.height
      C.unitframes.player.height = "30"
      UF.Apply("player")
      ok(f.hp:GetHeight() == 30, "a new height reaches the preview frame")
      C.unitframes.player.height = h0
      UF.Apply("player")
      -- Shift + wheel over the health bar: taller
      local hot
      for _, h in ipairs(M.sets.player.hots) do if h.what == "hp" then hot = h end end
      Mock.shift = true
      _G.this, _G.arg1 = hot, 1
      Mock.Run(hot, "OnMouseWheel", 1)
      Mock.shift = nil
      ok(C.unitframes.player.height == tostring(tonumber(h0) + 1), "Shift + wheel on the health bar makes it taller")
      C.unitframes.player.height = h0
      UF.Apply("player")
    end
    -- tabs: the raid tab shows a grid of raid frames
    UF.cur = "raid"
    M.Refresh()
    ok(M.sets.raid and table.getn(M.sets.raid.frames) == 10 and M.sets.raid:IsShown() and not M.sets.player:IsShown(),
      "the Raid tab shows ten raid frames instead")
    -- view controls: Alt + wheel zooms, dragging empty space moves the view,
    -- double-click fits it again
    UF.cur = "player"
    M.FitView()
    M.Refresh()
    local z0 = M.zoom
    Mock.alt = true
    _G.arg1 = 1
    Mock.Run(M.pan, "OnMouseWheel", 1)
    Mock.alt = nil
    ok(M.manual and M.zoom > z0, "Alt + wheel zooms in (" .. z0 .. " -> " .. M.zoom .. ")")
    local dx0 = M.dx
    Mock.cx, Mock.cy = 100, 100
    _G.arg1 = "LeftButton"
    Mock.Run(M.pan, "OnMouseDown", "LeftButton")
    Mock.cx = 160
    Mock.Run(M.pan, "OnUpdate", .05)
    Mock.Run(M.pan, "OnMouseUp", "LeftButton")
    ok(M.dx ~= dx0, "dragging empty space moves the view")
    Mock.Run(M.pan, "OnDoubleClick", "LeftButton")
    ok(not M.manual, "a double-click fits the view again")
    -- a part with a place of its own can be dragged; right-click puts it back
    local raidHot
    for _, h in ipairs(M.sets.player.hots) do if h.drag == UF.DRAG.raidIcon then raidHot = h end end
    ok(raidHot, "the raid mark can be dragged")
    if raidHot then
      local pc = pfUI_config.unitframes.player
      local x0 = pc.raidiconoffx
      Mock.cx, Mock.cy = 100, 100
      _G.this, _G.arg1 = raidHot, "LeftButton"
      Mock.Run(raidHot, "OnMouseDown", "LeftButton")
      Mock.cx = 140
      Mock.Run(raidHot, "OnUpdate", .05)
      Mock.Run(raidHot, "OnMouseUp", "LeftButton")
      ok(pc.raidiconoffx ~= x0, "dragging the raid mark moves it (" .. tostring(x0) .. " -> " .. tostring(pc.raidiconoffx) .. ")")
      Mock.Run(raidHot, "OnClick", "LeftButton")
      ok(O.current == "o:ufframes", "the drag was not taken as a click")
      _G.arg1 = "RightButton"
      Mock.Run(raidHot, "OnClick", "RightButton")
      ok(pc.raidiconoffx == "0" and pc.raidiconoffy == "20", "right-click puts it back")
    end
    -- buffs drag freely (their corner is a setting on the card);
    -- right-click puts them back
    local buffHot
    for _, h in ipairs(M.sets.player.hots) do if h.what == "buffs" and h.drag and not h.drag.pick then buffHot = h end end
    ok(buffHot, "the buffs can be dragged")
    if buffHot then
      local pc = pfUI_config.unitframes.player
      pc.o_buffx, pc.o_buffy = "0", "0"
      Mock.cx, Mock.cy = 150, 140
      _G.this, _G.arg1 = buffHot, "LeftButton"
      Mock.Run(buffHot, "OnMouseDown", "LeftButton")
      Mock.cx, Mock.cy = 190, 120
      Mock.Run(buffHot, "OnUpdate", .05)
      Mock.Run(buffHot, "OnMouseUp", "LeftButton")
      ok(tonumber(pc.o_buffx) > 0 and tonumber(pc.o_buffy) < 0, "dragging moves the buffs (" .. tostring(pc.o_buffx) .. ", " .. tostring(pc.o_buffy) .. ")")
      _G.arg1 = "RightButton"
      Mock.Run(buffHot, "OnClick", "RightButton")
      ok(pc.o_buffx == "0" and pc.o_buffy == "0", "right-click puts them back")
    end
    ok(UF.PLACES.portrait.pick(.1, .5) == "left" and UF.PLACES.portrait.pick(.9, .5) == "right" and UF.PLACES.portrait.pick(.5, .5) == "bar",
      "the portrait goes left, right or on the bar by where it is dropped")
    Mock.cx, Mock.cy = nil, nil
    -- the preview shows part health, so textures and shades can be seen
    local rf = M.sets.raid.frames[1]
    local function Frac(bar) return (bar.val - (bar.min or 0)) / (bar.max - (bar.min or 0)) end
    ok(Frac(rf.hp.bar) < 1 and math.abs(Frac(rf.power.bar) - .6) < .01, "the preview's bars are part full (" .. tostring(Frac(rf.hp.bar)) .. ")")
    -- a refresh keeps the bar's scale (no jump) and its value in the same phase
    local max0, val0 = rf.hp.bar.max, rf.hp.bar.val
    M.Refresh()
    ok(rf.hp.bar.max == max0 and rf.hp.bar.val == val0, "refreshing does not make the bars jump")
    -- the shared settings sit on the Frames page, the font under the preview
    local fp = O.pages.ufframes
    local titles = {}
    for i, card in ipairs(fp and fp.cards or {}) do titles[i] = card.title end
    ok(titles[1] == "All frames: text", "the font card comes first, under the preview (" .. tostring(titles[1]) .. ")")
    local hasBottom
    for _, t in ipairs(titles) do if t == "All frames: colours" then hasBottom = true end end
    ok(hasBottom, "the other shared cards are on the Frames page too")
    -- the font changes the frames at once
    local was = pfUI_config.global.font_unit
    pfUI_config.global.font_unit = "Interface\\AddOns\\pfUI\\fonts\\Myriad-Pro.ttf"
    UF.FontNow()
    ok(pfUI.font_unit == pfUI.media[pfUI_config.global.font_unit], "a new unit frame font applies without a reload")
    pfUI_config.global.font_unit = was
    UF.FontNow()
    UF.cur = "player"
    M.Refresh()
    -- the cast bar page: an animated sample, every part opens its card
    local CB = pfUI.castbarOcto
    O:Select("o:ufcastbar")
    ok(CB and CB.mini and CB.mini.cb, "the cast bar page has its preview")
    if CB and CB.mini then
      local cb = CB.mini.cb
      local sc = pfUI_config.castbar.player
      sc.showicon, sc.showlag = "1", "1"
      CB.mini.Refresh()
      Mock.now = 1000 * 4 * 4 + 1   -- the first sample (a cast), 1 s in
      CB.mini.Animate(Mock.now)
      ok(cb.bar:GetValue() > 0 and cb.bar:GetValue() < 2.5 and string.find(cb.bar.left:GetText() or "", "Frostbolt"), "it casts, filling")
      ok(string.find(cb.bar.right:GetText() or "", " / "), "with the timer")
      ok(cb.icon:IsShown() and cb.bar.lag:IsShown(), "icon and lag as set")
      Mock.now = 1000 * 4 * 4 + 4 + 1   -- the second (a channel), 1 s in
      CB.mini.Animate(Mock.now)
      ok(cb.bar:GetValue() > 1.5 and string.find(cb.bar.left:GetText() or "", "Arcane Missiles"), "then channels, emptying")
      local missing = {}
      for what, title in pairs(CB.GO) do
        if not CB.mini.hots[what] then table.insert(missing, "no spot: " .. what) end
        if not pfUI.plates.OpenSection("ufcastbar", title) then table.insert(missing, "no card: " .. title) end
      end
      ok(table.getn(missing) == 0, "every part of the cast bar opens its own card (" .. table.concat(missing, ", ") .. ")")
      -- Shift + wheel on the bar: taller
      local h0 = sc.height
      Mock.shift = true
      _G.this, _G.arg1 = CB.mini.hots.bar, 1
      Mock.Run(CB.mini.hots.bar, "OnMouseWheel", 1)
      Mock.shift = nil
      ok(tonumber(sc.height) and tonumber(sc.height) > 0, "Shift + wheel sets a height (" .. tostring(sc.height) .. ")")
      sc.height, sc.showicon, sc.showlag = h0, "0", "0"
      -- the spell name can be dragged; right-click puts it back
      local nh = CB.mini.hots.name
      local lx0 = sc.txtleftoffx
      Mock.cx, Mock.cy = 100, 100
      _G.this, _G.arg1 = nh, "LeftButton"
      Mock.Run(nh, "OnMouseDown", "LeftButton")
      Mock.cx = 130
      Mock.Run(nh, "OnUpdate", .05)
      Mock.Run(nh, "OnMouseUp", "LeftButton")
      ok(sc.txtleftoffx ~= lx0, "dragging the spell name moves it (" .. tostring(sc.txtleftoffx) .. ")")
      _G.arg1 = "RightButton"
      Mock.Run(nh, "OnClick", "RightButton")
      ok(sc.txtleftoffx == "0" and sc.txtleftoffy == "0", "right-click puts the name back")
      Mock.cx, Mock.cy = nil, nil
      -- tabs
      O.tabs.ufcastbar("target")
      ok(CB.cur == "target", "a cast bar's box opens its tab")
      CB.cur = "player"
    end
    pfUI.gui:Hide()
  end
end

-- ---------------------------------------------------------------- combat text preview

do
  local CT = pfUI.sctB and pfUI.sctB.SCT
  ok(CT and CT.Mini, "combat text preview loaded")
  if CT and CT.Mini then
    local box = CreateFrame("Frame", nil, UIParent)
    box:SetWidth(640)
    box:SetHeight(300)
    local picked
    local good, M = pcall(CT.Mini, box, function(k) picked = k end)
    ok(good and M and M.rects.inc and M.rects.note, "the mini screen has every area: " .. tostring(good and "" or M))
    if good and M then
      -- texts spawn and move
      for i = 1, 20 do
        Mock.now = Mock.now + .1
        Mock.Run(M.scr, "OnUpdate", .1)
      end
      ok(table.getn(M.live) > 0, "sample texts move in the areas (" .. table.getn(M.live) .. ")")
      local r = M.rects.out
      local A = pfUI.sctB.db.sct.areas.out
      -- click: its options
      Mock.Run(r, "OnClick", "LeftButton")
      ok(picked == "out", "a click on an area opens its options")
      -- drag: the real area moves
      local x0 = A.x
      Mock.cx, Mock.cy = 0, 0
      Mock.Run(r, "OnMouseDown", "LeftButton")
      Mock.cx, Mock.cy = 30, 0
      Mock.Run(r, "OnUpdate", .1)
      Mock.Run(r, "OnMouseUp")
      Mock.Run(r, "OnClick", "LeftButton")
      ok(A.x > x0, "dragging an area moves it (" .. x0 .. " -> " .. A.x .. ")")
      -- right-click: back where it started
      Mock.Run(r, "OnClick", "RightButton")
      ok(A.x == pfUI.sctB.DEFAULTS.sct.areas.out.x, "right-click puts the area back")
      -- Shift + wheel: text size
      local s0 = A.size
      Mock.shift = true
      Mock.Run(r, "OnMouseWheel", 1)
      Mock.shift = nil
      ok(A.size == s0 + 1, "Shift + wheel: bigger text")
      A.size = s0
      Mock.cx, Mock.cy = nil, nil
      -- one-click looks for all combat text, the picked one known
      local db = pfUI.sctB.db.sct
      if CT.ApplyLook then
        for _, l in ipairs(CT.LOOKS) do
          CT.ApplyLook(l[1])
          ok(CT.CurrentLook() == l[1], "combat text look " .. l[1] .. " applies and is lit")
        end
        CT.ApplyLook("msbt")
        ok(db.areas.inc.anim == "parabola" and db.plates.crit == "pow" and db.areas.note.anim == "static", "MSBT: arcs, pow crits, notes stand still")
        db.areas.out.anim = "spiral"
        ok(CT.CurrentLook() == nil, "a change = your own mix")
        CT.ApplyLook("octo")
      end
      -- the new settings have their defaults
      ok(db.scale == 1 and db.fade == .25 and db.maxLive == 90, "text size, fade and most on screen defaults")
    end
  end
end

-- ---------------------------------------------------------------- nameplates (Plater)

do
  local P, NP = pfUI.plates, pfUI.nameplates
  local S = pfUI_config.plates
  ok(P and NP and S, "Plater-style nameplates loaded")
  if P and NP and S then
    -- the first load gave Plater's look once; the presets switch looks
    ok(S.firstlook == "1" and pfUI_config.nameplates.heighthealth == "12" and S.castlayout == "plater", "first load: Plater's look")
    P.ApplyPreset("pfui")
    ok(pfUI_config.nameplates.heighthealth == "8" and S.indicator == "none" and S.castlayout == "pfui", "pfUI look preset")
    P.ApplyPreset("plater")
    ok(pfUI_config.nameplates.width == "130" and S.indicator == "arrows", "Plater look preset")

    -- our own art is there
    for _, n in ipairs({ "bar-soft", "bar-flat", "bar-gloss", "bar-glass", "bar-split", "arrow", "chevron", "corner",
                         "underglow", "spark", "star", "skull", "tick" }) do
      local h = io.open(DIR .. "/img/plates/" .. n .. ".tga", "rb")
      ok(h, "plate art " .. n)
      if h then h:close() end
    end

    -- a mob and who it attacks (GUID.."target")
    local MOB = "0xF13000ABCD000001"
    local saved = { UnitName = UnitName, UnitIsUnit = UnitIsUnit, UnitExists = UnitExists, superwow = superwow_active }
    local mobTarget = "player"
    Mock.Enemy(MOB, "Gnoll Shaman", "WARRIOR", 50, 0, { npc = true, combat = true })
    Mock.units.player = { combat = true }
    UnitName = function(u)
      if u == MOB .. "target" then return mobTarget == "player" and "Tester" or mobTarget end
      -- (the map style test leaves a UnitName that knows only party1)
      if Mock.units[u] and Mock.units[u].name then return Mock.units[u].name end
      return saved.UnitName(u)
    end
    UnitIsUnit = function(a, b)
      if a == MOB .. "target" and b == "player" then return mobTarget == "player" end
      return a == b
    end
    UnitExists = function(u)
      if u == MOB .. "target" then return 1 end
      return saved.UnitExists(u)
    end
    superwow_active = true

    -- threat states for damage dealers
    S.role = "dps"
    ok(P.ThreatState(MOB) == "aggro", "on you: aggro (" .. tostring(P.ThreatState(MOB)) .. ")")
    mobTarget = "Bob"
    ok(P.ThreatState(MOB) == "safe", "on someone else: safe")
    ok(P.ThreatColor("safe") == P.COL.c_safe, "safe has its own colour by default (red would look like aggro)")
    S.safenormal = "1"
    ok(P.ThreatColor("safe") == nil, "or keeps the normal colour")
    S.safenormal = "0"
    local TH = pfUI.meters and pfUI.meters.threat
    if TH then
      TH.list, TH.at = { { name = "Bob", tank = true, perc = 100 }, { name = "Tester", perc = 95 } }, GetTime()
      ok(P.ThreatState(MOB, true) == "pulling", "near the tank on your target: pulling")
      ok(P.ThreatState(MOB, false) == "safe", "the threat list is only about your target")
    end
    Mock.units.player.combat = false
    ok(P.ThreatState(MOB) == nil, "you out of combat: no threat colour")
    Mock.units.player.combat = true

    -- tanks
    S.role = "tank"
    mobTarget = "player"
    ok(P.ThreatState(MOB) == "aggro", "tank: on you")
    if TH then
      TH.list, TH.at = { { name = "Tester", tank = true, perc = 100 }, { name = "Rogue", perc = 96 } }, GetTime()
      ok(P.ThreatState(MOB, true) == "losing", "tank: someone near you = losing")
      TH.list = nil
    end
    pfUI_config.nameplates.combatofftanks = "Bob#Alice"
    NP.UpdateConfig()
    mobTarget = "Bob"
    ok(P.ThreatState(MOB) == "offtank", "tank: on another tank")
    mobTarget = "Mage"
    ok(P.ThreatState(MOB) == "lost", "tank: loose on someone else")
    ok(P.Alarming("lost") and not P.Alarming("offtank"), "tank: the glow is for lost mobs")
    pfUI_config.nameplates.combatofftanks = ""

    -- automatic role from the stance
    S.role = "auto"
    local forms = GetShapeshiftFormInfo
    GetNumShapeshiftForms = function() return 3 end
    GetShapeshiftFormInfo = function(i)
      if i == 2 then return "Interface\\Icons\\Ability_Warrior_DefensiveStance", "Defensive Stance", 1 end
      return "Interface\\Icons\\Ability_Warrior_OffensiveStance", "Battle Stance", nil
    end
    Mock.now = Mock.now + 2
    ok(P.Role() == "tank", "warrior in Defensive Stance counts as a tank")
    GetShapeshiftFormInfo = function(i) return "Interface\\Icons\\Ability_Warrior_OffensiveStance", "Battle Stance", i == 1 and 1 or nil end
    Mock.now = Mock.now + 2
    ok(P.Role() == "dps", "Battle Stance: damage")
    GetShapeshiftFormInfo = forms
    S.role = "dps"

    -- execute range
    ok(P.ExecutePct() == 20, "warriors get execute range (" .. tostring(P.ExecutePct()) .. ")")
    S.execute = "off"
    ok(P.ExecutePct() == nil, "execute range off")
    S.execute = "auto"

    -- who interrupted
    local v, by = P.ParseInterrupt("Bob interrupts Gnoll Shaman's Healing Wave.")
    ok(v == "Gnoll Shaman" and by == "Bob", "interrupt line: who and whom (" .. tostring(by) .. " -> " .. tostring(v) .. ")")
    v, by = P.ParseInterrupt("You interrupt Gnoll Shaman's Lightning Bolt.")
    ok(v == "Gnoll Shaman" and by == "You", "your own interrupt")
    ok(P.ParseInterrupt("Bob hits Gnoll Shaman for 50.") == nil, "other lines are not interrupts")

    -- a whole plate: the game's frame, pfUI's overlay, our parts
    local game = Mock.Plate(MOB)
    local hb = CreateFrame("StatusBar", nil, game)
    CreateFrame("StatusBar", nil, game)
    hb.GetStatusBarColor = function() return 1, 0, 0 end
    hb:SetMinMaxValues(0, 100)
    hb.value = 80
    local regions = {}
    for _, k in ipairs(pfUI.env.NAMEPLATE_OBJECTORDER) do
      local r
      if k == "name" or k == "level" then r = game:CreateFontString(nil, "OVERLAY") else r = game:CreateTexture(nil, "OVERLAY") end
      r.GetObjectType = function() return (k == "name" or k == "level") and "FontString" or "Texture" end
      r.GetTextColor = function() return 1, 1, 1 end
      if k == "levelicon" then r.shown = false end
      regions[table.getn(regions) + 1] = r
      if k == "name" then r.text = "Gnoll Shaman" end
      if k == "level" then r.text = "60" end
    end
    game.GetRegions = function() return unpack(regions) end
    local good, err = xpcall(function() NP.OnCreate(game) end, debug.traceback)
    ok(good, "pfUI makes its overlay on a game plate: " .. tostring(err))
    local plate = game.nameplate
    local o = plate and plate.octo
    ok(o ~= nil, "our parts are built on it")
    if o then
      ok(o.hl.texture and string.find(o.hl.texture, "plates\\bar%-soft"), "Octo soft bar texture (" .. tostring(o.hl.texture) .. ")")
      -- the mob on you, damage role: red bar and the aggro glow
      mobTarget = "player"
      hb.value = 80
      P.Update(plate)
      ok(o.state == "aggro" and plate.cache.r == P.COL.c_aggro[1], "aggro colour on the bar")
      ok(o.glow:IsShown(), "aggro glow")
      ok(o.tick:IsShown(), "execute marker above 20%")
      -- low health: execute colour wins
      plate.health:SetMinMaxValues(0, 100)
      plate.health.value = 15
      P.Update(plate)
      ok(plate.cache.r == P.COL.executecolor[1] and not o.tick:IsShown(), "execute colour under 20%")
      plate.health.value = 80
      -- your target: arrows and a bigger plate
      plate.istarget = true
      P.Update(plate)
      ok(o.left:IsShown() and o.right:IsShown(), "target arrows")
      S.indicator = "corners"
      P.Update(plate)
      ok(o.corners[1]:IsShown() and not o.left:IsShown(), "target corners")
      S.indicator = "arrows"
      o.scale = nil
      P.Tick(plate)
      ok(math.abs(o.scale - 1.1) < .001, "target in combat: 110% (" .. tostring(o.scale) .. ")")
      plate.istarget = nil
      Mock.units.player.combat = false
      Mock.now = Mock.now + .05
      P.Tick(plate)
      ok(o.scale < 1.1 and o.scale > .9, "eases toward the out-of-combat size (" .. tostring(o.scale) .. ")")
      Mock.now = Mock.now + 2
      P.Tick(plate)
      Mock.now = Mock.now + 2
      P.Tick(plate)
      ok(math.abs(o.scale - .9) < .01, "out of combat: 90% (" .. tostring(o.scale) .. ")")
      Mock.units.player.combat = true
      -- range: 50 yd away fades
      plate.alpha = 1
      o.rangeAt = 0
      P.Tick(plate)
      ok(o.far and math.abs(plate.alpha - .4) < .001, "50 yd away: faded to 40% (" .. tostring(plate.alpha) .. ")")
      -- cast bar: a stopped cast flashes red and says who did it
      local cb = plate.castbar
      cb:SetMinMaxValues(0, 2)
      cb.value = .8
      cb:Show()
      P.TickCast(plate, o, GetTime())
      ok(o.casting and o.spark:IsShown(), "casting: spark shown")
      cb:Hide()
      P.TickCast(plate, o, GetTime())
      ok(o.cend:IsShown() and not o.cendDone and o.cend.text.text == "Interrupted", "stopped: red flash")
      P.ParseInterrupt("Bob interrupts Gnoll Shaman's Healing Wave.")
      P.TickCast(plate, o, GetTime() + .1)
      ok(o.cend.text.text == "Interrupted by Bob", "then names the kicker (" .. tostring(o.cend.text.text) .. ")")
      P.TickCast(plate, o, GetTime() + 2)
      ok(not o.cend:IsShown(), "the flash fades away")
      cb.value = 1.9
      cb:Show()
      P.TickCast(plate, o, GetTime())
      cb:Hide()
      P.TickCast(plate, o, GetTime())
      ok(o.cend:IsShown() and o.cendDone, "a cast that went off flashes green")
      -- switched off: our parts go
      S.enable = "0"
      P.Configure(plate)
      ok(not o.glow:IsShown() and not o.left:IsShown() and not o.cend:IsShown(), "switched off: nothing of ours shows")
      S.enable = "1"
      P.Configure(plate)
      -- border skins
      S.skin = "shadow"
      P.Configure(plate)
      ok(o.skinH:IsShown() and o.skinC:IsShown(), "shadow skin around the bars")
      S.skin = "pfui"
      P.Configure(plate)
      ok(not o.skinH:IsShown(), "pfUI skin: only pfUI's own border")
      -- test mode: pretend threat states and casts on real plates
      P.Test(60)
      ok(P.Testing(), "test mode on")
      local seen = {}
      for i = 1, 6 do
        Mock.now = Mock.now + 3
        P.Update(plate)
        if o.state then seen[o.state] = true end
      end
      ok(seen.aggro and seen.pulling and seen.safe, "test mode cycles the threat colours")
      Mock.now = Mock.now + .5
      P.Tick(plate)
      P.Test(0)
      ok(not P.Testing(), "test stops")
    end

    -- phase 2: auras
    local A = P.Auras
    ok(A ~= nil, "plate auras loaded")
    if A then
      local list = {
        { name = "Shadow Word: Pain", kind = "debuff", dtype = "Magic" },
        { name = "Corruption", kind = "debuff", mine = true },
        { name = "Hammer of Justice", kind = "debuff", cc = true },
        { name = "Arcane Intellect", kind = "buff" },
        { name = "Evasion", kind = "buff", important = true },
        { name = "Polymorph", kind = "debuff", cc = true },
      }
      local specials = S.specialauras
      S.specialauras = "Polymorph"
      A.ReadLists()
      local row, big = A.Pick(list, true)
      ok(table.getn(row) == 3 and row[1].name == "Corruption" and row[2].name == "Hammer of Justice" and row[3].name == "Evasion",
        "row: yours, then crowd control, then important buffs (" .. table.getn(row) .. ")")
      ok(table.getn(big) == 1 and big[1].name == "Polymorph", "special auras go big")
      S.debuffshow = "all"
      row = A.Pick(list, true)
      ok(table.getn(row) == 4, "all debuffs (" .. table.getn(row) .. ")")
      S.debuffshow = "mine_cc"
      row = A.Pick(list, false)
      ok(table.getn(row) == 2, "no enemy buffs on a friend")
      pfUI_config.nameplates.debuffs.filter = "blacklist"
      pfUI_config.nameplates.debuffs.blacklist = "Corruption"
      A.ReadLists()
      row = A.Pick(list, true)
      ok(row[1].name == "Hammer of Justice", "black list hides a debuff")
      pfUI_config.nameplates.debuffs.filter, pfUI_config.nameplates.debuffs.blacklist = "none", ""
      S.specialauras = specials
      A.ReadLists()

      -- reading a GUID's auras: SuperWoW ids -> names, own timers from libdebuff
      local savedD, savedB, savedSI = UnitDebuff, UnitBuff, SpellInfo
      UnitDebuff = function(u, i)
        if i == 1 then return "Interface\\Icons\\Spell_Shadow_AbominationExplosion", 1, "Magic", 172 end
        if i == 2 then return "Interface\\Icons\\Spell_Holy_SealOfMight", 1, nil, 853 end
      end
      UnitBuff = function(u, i) if i == 1 then return "Interface\\Icons\\Spell_Frost_Frost", 1, 11958 end end
      SpellInfo = function(id)
        local names = { [172] = "Corruption", [853] = "Hammer of Justice", [11958] = "Ice Block" }
        return names[id], "", ""
      end
      local lib = pfUI.api.libdebuff
      lib.objects = lib.objects or {}
      lib.objects["Gnoll Shaman"] = { [60] = { Corruption = { duration = 18, start = GetTime() - 3, caster = "player" } } }
      local ao = {}
      local read = A.Read(ao, MOB)
      ok(table.getn(read) == 3 and read[1].name == "Corruption" and read[1].mine and read[1].ends and math.abs(read[1].ends - GetTime() - 15) < .01,
        "reads your Corruption with 15 s left (" .. table.getn(read) .. " auras, " .. tostring(read[1] and read[1].name) .. ", mine "
        .. tostring(read[1] and read[1].mine) .. ", ends " .. tostring(read[1] and read[1].ends and read[1].ends - GetTime()) .. ")")
      ok(read[2].cc and read[3].kind == "buff" and read[3].important, "crowd control and an important buff recognised")
      UnitDebuff, UnitBuff, SpellInfo = savedD, savedB, savedSI
      lib.objects["Gnoll Shaman"] = nil

      -- ghost auras: your spells missing from the mob
      S.ghostauras = "Execute#Revenge"
      A.ReadLists()
      local ghosts = A.Ghosts({ { name = "Execute", kind = "debuff" } })
      ok(table.getn(ghosts) == 1 and ghosts[1].name == "revenge" and ghosts[1].icon, "ghost: the missing one, with its spellbook icon")
      S.ghostauras = ""
      A.ReadLists()

      -- timers
      ok(A.Timer(125) == "3m" and A.Timer(42.4) == "42" and A.Timer(2.34) == "2.3", "timer text")

      -- on the plate: test auras show, pfUI's own row is skipped and its setting kept
      if o then
        pfUI_config.nameplates.showdebuffs = "1"
        P.Test(30)
        NP:OnDataChanged(plate)
        ok(pfUI_config.nameplates.showdebuffs == "1", "pfUI's debuff setting is left as it was")
        local shown = 0
        for _, f in ipairs(o.aicons or {}) do if f:IsShown() then shown = shown + 1 end end
        local bigs = 0
        for _, f in ipairs(o.bicons or {}) do if f:IsShown() then bigs = bigs + 1 end end
        ok(shown >= 3, "aura icons on the plate (" .. shown .. ")")
        ok(bigs >= 1, "special icons on the plate (" .. bigs .. ")")
        P.Tick(plate)
        ok(o.aicons[1].timer.text and o.aicons[1].timer.text ~= "", "icons count down (" .. tostring(o.aicons[1].timer.text) .. ")")
        S.auras = "0"
        P.Update(plate)
        local still = 0
        for _, f in ipairs(o.aicons) do if f:IsShown() then still = still + 1 end end
        ok(still == 0, "auras off: icons gone")
        S.auras = "1"
        local sp = o.aicons[1].stacks.point
        ok(sp and sp[1] == "TOPRIGHT", "stacks sit in the top right corner, clear of the timer")
        ok(S.specialsize == "32" and S.auraver == "2", "special icons 32 px (old 28 moved up once)")
        -- friendly plates get no pretend casts or auras
        local hbc = hb.GetStatusBarColor
        hb.GetStatusBarColor = function() return 0, 0, 1 end
        plate.castbar:Hide()
        o.casting = nil
        P.Update(plate)
        for i = 1, 5 do Mock.now = Mock.now + .3 P.Tick(plate) end
        local fshown = 0
        for _, f in ipairs(o.aicons) do if f:IsShown() then fshown = fshown + 1 end end
        ok(o.kind == "friendlyplayer" and fshown == 0 and not plate.castbar:IsShown(), "the test leaves friendly plates alone")
        hb.GetStatusBarColor = hbc
        P.Update(plate)
        P.Test(0)
        ok(P.COL.castbg and P.COL.castbg[1] > P.COL.bgcolor[1], "cast bar background lighter than the health bar's")
      end
    end

    -- phase 3: lists, quests, icons, auto
    local L = P.Lists
    ok(L ~= nil, "plate lists loaded")
    if L then
      local parsed = L.Parse("Defias Pillager|1.00,0.00,0.00|Pillager#Fireball||Big fire#Gnoll Shaman|0.20,0.40,1.00|")
      ok(parsed["defias pillager"].color[1] == 1 and parsed["defias pillager"].rename == "Pillager", "list: colour and new name")
      ok(parsed["fireball"].color == nil and parsed["fireball"].rename == "Big fire", "list: new name only")
      ok(L.Parse(L.Serialize(parsed))["gnoll shaman"].color[3] == 1, "list survives a round trip")
      S.npclist = ""
      L.Put("npclist", "Gnoll Shaman", { 0, 1, 0 }, "Shaman")
      ok(L.Npc("gnoll shaman") and L.Npc("Gnoll Shaman").rename == "Shaman", "Put adds an NPC")
      -- colour order on the plate: execute > threat > NPC > quest
      if o then
        mobTarget = "Bob"
        S.role = "dps"
        plate.health.value = 80
        P.Update(plate)
        ok(plate.cache.r == P.COL.c_safe[1], "threat colour wins over the NPC colour")
        ok(plate.name.text == "Shaman", "the NPC's new name shows (" .. tostring(plate.name.text) .. ")")
        S.npcoverthreat = "1"
        P.Update(plate)
        ok(plate.cache.r == 0 and plate.cache.g == 1, "or the NPC colour wins when set")
        S.npcoverthreat = "0"
        L.Remove("npclist", "Gnoll Shaman")
        ok(S.npclist == "", "Remove takes it off")
        -- cast colour by spell
        S.castlist = "Fireball|0.10,0.20,0.30|Big fire"
        L.Read()
        local cb = plate.castbar
        o.casting = nil
        cb:SetMinMaxValues(0, 3)
        cb.value = .5
        cb.spell.text = "Fireball"
        cb:Show()
        P.TickCast(plate, o, GetTime())
        local c = cb.barColor or {}
        ok(math.abs((c[1] or 0) - .1) < .001 and cb.spell.text == "Big fire", "cast colour and new spell name")
        cb:Hide()
        P.TickCast(plate, o, GetTime())
        S.castlist = ""
        L.Read()
        -- quest marks from pfQuest's map data
        pfMap = { tooltips = { ["Gnoll Shaman"] = { ["The Gnolls"] = { [40] = { QTYPE = "UNIT_OBJECTIVE" } } },
                               ["Marshal Dughan"] = { ["A Quest"] = { [40] = { QTYPE = "NPC_END" } } } } }
        ok(L.Quest("Gnoll Shaman") == "objective" and L.Quest("Marshal Dughan") == "end" and L.Quest("Nobody") == nil, "pfQuest: objective / hand in")
        P.Update(plate)
        ok(o.qmark:IsShown() and string.find(o.qmark.texture or "", "quest%-objective"), "quest mark on the plate")
        S.questbar = "1"
        mobTarget = nil
        Mock.units[MOB].combat = false
        P.Update(plate)
        ok(plate.cache.r == 1 and math.abs(plate.cache.g - .82) < .01, "quest mob coloured when out of a fight")
        Mock.units[MOB].combat = true
        S.questbar = "0"
        pfMap = nil
        mobTarget = "player"
      end
      -- the quest log fallback
      local qfn = { GetNumQuestLogEntries, GetNumQuestLeaderBoards, GetQuestLogLeaderBoard }
      GetNumQuestLogEntries = function() return 1 end
      GetNumQuestLeaderBoards = function() return 2 end
      GetQuestLogLeaderBoard = function(i)
        if i == 1 then return "Defias Pillager slain: 3/10", "monster", nil end
        return "Red Bandana: 2/6", "item", nil
      end
      L.ReadQuestLog()
      ok(L.Quest("Defias Pillager") == "objective" and L.Quest("Red Bandana") == nil, "quest log: mobs to kill (" .. L.SLAIN .. ")")
      GetNumQuestLogEntries, GetNumQuestLeaderBoards, GetQuestLogLeaderBoard = qfn[1], qfn[2], qfn[3]
      L.ReadQuestLog()
      -- auto toggles
      local calls = {}
      local saveAuto = { ShowNameplates, HideNameplates, ShowFriendNameplates, HideFriendNameplates, GetRealZoneText }
      ShowNameplates = function() table.insert(calls, "enemy on") end
      HideNameplates = function() table.insert(calls, "enemy off") end
      ShowFriendNameplates = function() table.insert(calls, "friend on") end
      HideFriendNameplates = function() table.insert(calls, "friend off") end
      GetRealZoneText = function() return "Orgrimmar" end
      S.autofriend_city, S.autoenemy_combat, S.autoenemy_ooc = "hide", "show", "hide"
      ok(L.Place() == "city", "Orgrimmar is a city")
      L.Auto(true)
      ok(calls[1] == "friend off" and calls[2] == "enemy on", "auto: friends off in a city, enemies on in combat")
      calls = {}
      L.Auto(false)
      ok(calls[2] == "enemy off", "auto: enemies off out of combat")
      S.autofriend_city, S.autoenemy_combat, S.autoenemy_ooc = "keep", "keep", "keep"
      calls = {}
      L.Auto(true)
      ok(table.getn(calls) == 0, "auto: Leave changes nothing")
      ShowNameplates, HideNameplates, ShowFriendNameplates, HideFriendNameplates, GetRealZoneText =
        saveAuto[1], saveAuto[2], saveAuto[3], saveAuto[4], saveAuto[5]
    end

    -- looks: picking one must not switch plates off (pfUI re-applied "show
    -- on enemies" from the config, which the V key does not change)
    local hid = 0
    local hide, hidef = HideNameplates, HideFriendNameplates
    HideNameplates = function() hid = hid + 1 end
    HideFriendNameplates = function() hid = hid + 1 end
    pfUI_config.nameplates.showhostile = "0"
    P.ApplyPreset("neon")
    ok(hid == 0, "a look leaves the plates on screen alone (" .. hid .. " hide calls)")
    pfUI_config.nameplates.showhostile = "1"
    HideNameplates, HideFriendNameplates = hide, hidef
    ok(P.CurrentLook() == "neon" and S.skin == "neon", "the picked look is known (" .. tostring(P.CurrentLook()) .. ")")
    S.indicator = "corners"
    ok(P.CurrentLook() == nil, "a changed setting = your own mix")
    for _, pr in ipairs(P.PRESETS) do
      P.ApplyPreset(pr[1])
      ok(P.CurrentLook() == pr[1], "look " .. pr[1] .. " applies and is lit")
    end
    P.ApplyPreset("plater")

    -- the preview: four sample plates drawn by the real code
    local box = CreateFrame("Frame", nil, UIParent)
    box:SetWidth(640)
    box:SetHeight(118)
    local pgood, samples = pcall(P.AttachPreview, box)
    ok(pgood and type(samples) == "table" and table.getn(samples) == 4, "preview builds four sample plates: " .. tostring(pgood and "" or samples))
    if pgood and type(samples) == "table" then
      local first = samples[1]
      for i = 1, 30 do
        Mock.now = Mock.now + .1
        for _, s in ipairs(samples) do Mock.Run(s, "OnUpdate", .1) end
      end
      local so = first.nameplate and first.nameplate.octo
      ok(so and so.left:IsShown(), "sample target shows its arrows")
      ok(so and (so.casting or so.cend:IsShown()), "sample target casts")
      local thug = samples[2].nameplate.octo
      ok(thug and thug.state ~= nil and samples[2].caption.text and string.find(samples[2].caption.text, "^mob "), "sample mob shows a threat state (" .. tostring(samples[2].caption.text) .. ")")
      local fp = first.nameplate
      ok(fp.health.backdrop and fp.health.backdrop:GetFrameLevel() < fp.health:GetFrameLevel()
        and fp.health:GetFrameLevel() > box:GetFrameLevel(),
        "sample bar: above its box, its dark backdrop still under the fill")
      pfUI_config.nameplates.cpdisplay = "1"
      local seen = {}
      for i = 1, 12 do
        Mock.now = Mock.now + .35
        Mock.Run(first, "OnUpdate", .35)
        local n, pf = 0, 0
        for c = 1, 5 do
          local f = fp.octo.cp and fp.octo.cp[c]
          if f and f:IsShown() and string.find(f.tex.texture or "", "cp%-orb") then n = n + 1 end
          if fp.combopoints[c]:IsShown() then pf = pf + 1 end
        end
        seen[n] = true
        if pf > 0 then seen.pfui = true end
      end
      ok(seen[0] and seen[3] and seen[5] and not seen.pfui, "our orbs roll on the sample target (pfUI's squares stay hidden)")
      pfUI_config.nameplates.cpdisplay = "0"
      -- every part is clickable; parts with a place can be dragged
      local hot = fp.castbar.hots and fp.castbar.hots[first]
      ok(hot and fp.name.hots and fp.level.hots and fp.health.hots, "cast bar, name, level and bar are clickable")
      local opened
      local was = P.OnPreviewClick
      -- (the mock puts every frame at the same place: no box limits here)
      local limits = P.Limits
      P.Limits = function() end
      P.OnPreviewClick = function(w) opened = w end
      fp.castbar:Show()
      if hot then Mock.Run(hot, "OnClick") end
      ok(opened == "cast", "a click on the cast bar opens the cast bar options")
      if hot then
        Mock.cx, Mock.cy = 100, 100
        Mock.Run(hot, "OnMouseDown")
        Mock.cx, Mock.cy = 120, 70
        Mock.now = Mock.now + 1
        Mock.Run(hot, "OnUpdate", .1)
        Mock.Run(hot, "OnMouseUp")
        opened = nil
        Mock.Run(hot, "OnClick")
        ok(S.castoffx == "20" and S.castoffy == "-30" and opened == nil, "dragging the cast bar moves it (" .. S.castoffx .. ", " .. S.castoffy .. "), not a click")
        -- it stops at the edge of the box: here 5 px of room to the right
        P.Limits = function() return { 0, 5, 0, 5 } end
        Mock.cx, Mock.cy = 100, 100
        Mock.Run(hot, "OnMouseDown")
        Mock.cx, Mock.cy = 400, 100
        Mock.now = Mock.now + 1
        Mock.Run(hot, "OnUpdate", .1)
        Mock.Run(hot, "OnMouseUp")
        Mock.Run(hot, "OnClick")
        P.Limits = function() end
        ok(S.castoffx == "25", "a drag stops at the edge of the preview box (" .. S.castoffx .. ")")
        S.castoffx, S.castoffy = "0", "0"
        Mock.cx, Mock.cy = nil, nil
      end
      -- the name drags too; the wheel resizes; right-click puts it back
      local nh = fp.name.hots and fp.name.hots[first]
      if nh then
        Mock.cx, Mock.cy = 0, 0
        Mock.Run(nh, "OnMouseDown")
        Mock.cx, Mock.cy = 10, 6
        Mock.now = Mock.now + 1
        Mock.Run(nh, "OnUpdate", .1)
        Mock.Run(nh, "OnMouseUp")
        Mock.Run(nh, "OnClick")   -- the client clicks after a drag; it is swallowed
        ok(S.nameoffx == "10" and S.nameoffy == "6", "the name drags (" .. S.nameoffx .. ", " .. S.nameoffy .. ")")
        local cast = fp.castbar.hots[first]
        local h0 = tonumber(S.castheight)
        Mock.Run(cast, "OnMouseWheel", 1)
        ok(tonumber(S.castheight) == h0, "the plain wheel leaves sizes alone (it scrolls the page)")
        ok(rawget(pfUI.env, "this") == nil, "passing the wheel on leaves no pfUI-only `this` behind")
        Mock.shift = true
        Mock.Run(cast, "OnMouseWheel", 1)
        Mock.shift = nil
        ok(tonumber(S.castheight) == h0 + 1, "Shift + wheel makes the cast bar taller")
        -- parts move on their own: the name's move leaves the auras and marks put
        local keepx, keepy = S.nameoffx, S.nameoffy
        S.nameoffx, S.nameoffy = "0", "0"
        P.Refresh()
        local before = { fp.octo.arow.point[4], fp.octo.arow.point[5] }
        S.nameoffx, S.nameoffy = "15", "4"
        P.Refresh()
        ok(fp.octo.arow.point[4] == before[1] - 15 and fp.octo.arow.point[5] == before[2] - 4,
          "moving the name does not move the auras (" .. tostring(before[1]) .. "," .. tostring(before[2]) .. " -> "
          .. tostring(fp.octo.arow.point[4]) .. "," .. tostring(fp.octo.arow.point[5]) .. ")")
        S.nameoffx, S.nameoffy = keepx, keepy
        P.Refresh()
        Mock.Run(nh, "OnClick", "RightButton")
        ok(S.nameoffx == "0" and S.nameoffy == "0", "right-click puts the name back")
        Mock.Run(cast, "OnClick", "RightButton")
        ok(S.castheight == "12", "right-click puts the cast bar's size back")
        Mock.cx, Mock.cy = nil, nil
      end
      -- every mark has its art
      S.markelite = "crown"
      P.Update(fp)
      ok(fp.octo.mark:IsShown() and string.find(fp.octo.mark.texture or "", "mark%-crown"), "elite mark as a crown")
      S.markelite = "none"
      P.Update(fp)
      ok(not fp.octo.mark:IsShown(), "elite mark None")
      S.markelite = "star"
      P.OnPreviewClick = was
      P.Limits = limits
      -- the grid behind the samples, with its tick box
      ok(box.grid and box.grid:IsShown() and table.getn(box.grid.lines) > 20, "preview grid with middle lines")
      S.previewgrid = "0"
      P.Refresh()
      ok(not box.grid:IsShown(), "grid off")
      S.previewgrid = "1"
      P.Refresh()
      -- a sample sticking out of its column shrinks; with room it grows back
      local col, ext = P.Column, P.Extent
      P.Column = function() return 0, 100, 100, 0 end
      P.Extent = function() return -20, 90, 90, 10 end
      first.fit = 1
      P.Fit(first)
      ok(first.fit < 1, "a sample sticking out shrinks (" .. first.fit .. ")")
      P.Extent = function() return 30, 70, 70, 30 end
      local f0 = first.fit
      P.Fit(first)
      ok(first.fit > f0, "with room to spare it grows back")
      P.Column, P.Extent = col, ext
      ok(fp.octo.cp and fp.octo.cp[1].hots, "combo points are clickable")
      S.skin = "thick"
      P.Refresh()
      ok(so.skinH:IsShown(), "a setting change redraws the samples")
      S.skin = "pfui"
      P.Refresh()
    end
    ok(P.SuperWoW(), "SuperWoW seen from its version (before any cast event)")

    UnitName, UnitIsUnit, UnitExists, superwow_active = saved.UnitName, saved.UnitIsUnit, saved.UnitExists, saved.superwow
    Mock.units.player = nil
    Mock.units[MOB] = nil
  end

  -- the Nameplates section replaces pfUI's own page
  local O = pfUI.octoui and pfUI.octoui.Options
  if O and O.frame then
    pfUI.gui:Show()
    local sec
    for _, s in ipairs(O.octo) do if s[1] == "Nameplates" then sec = s end end
    ok(sec and table.getn(sec[2]) == 8, "Nameplates section with its eight pages")
    -- the topic list: most used first, small categories grouped
    local heads = {}
    for _, grp in ipairs(O.groups) do table.insert(heads, grp.header.text.text) end
    ok(heads[1] == "Settings" and heads[2] == "Unit Frames" and heads[4] == "Swing Timer" and heads[5] == "Gear" and heads[6] == "Nameplates" and heads[table.getn(heads)] == "About",
      "topic list in order of importance (" .. table.concat(heads, ", ") .. ")")
    local castTopic
    for _, grp in ipairs(O.groups) do
      if grp.header.text.text == "Unit Frames" then
        for _, b in ipairs(grp.buttons) do if b.key == "o:ufcastbar" then castTopic = true end end
      end
    end
    ok(castTopic, "Cast bars is a topic under Unit Frames")
    -- the topic list uses the panel's real height: an open section pushes the
    -- rest down, nothing past the old 540 px guess is dropped
    local nav = O.navFrame
    local gh = nav.GetHeight
    nav.GetHeight = function() return 720 end
    O.openGroup = nil
    O:LayoutNav()
    local shown = 0
    for _, grp in ipairs(O.groups) do if grp.header:IsShown() then shown = shown + 1 end end
    ok(shown == table.getn(O.groups), "every section shows in a tall list (" .. shown .. "/" .. table.getn(O.groups) .. ")")
    nav.GetHeight = gh
    -- the corner grip scales the window, within limits, and remembers it
    ok(O.grip ~= nil, "the window has a resize grip")
    O:ApplyScale(3)
    ok(pfUI_cache.octoui.winscale == 1.6, "window size stops at 160%")
    O:ApplyScale(1)
    ok(pfUI_cache.octoui.winscale == 1, "back to normal size")
    -- no spacing slider any more (it rebuilt pages, which came out overlapped)
    ok(O.quickSpace == nil and O.RebuildPages == nil, "no spacing slider")
    for _, pg in ipairs(sec and sec[2] or {}) do
      local okk, err = pcall(function() O:Select("o:" .. pg[1]) end)
      ok(okk and O.pages[pg[1]] and O.pages[pg[1]].frame:IsShown(), "page " .. pg[1] .. " builds and shows: " .. tostring(err))
      local p = O.pages[pg[1]]
      if p then
        local rok, rerr = pcall(function() pfUI.octoui.W.Refresh(p) end)
        ok(rok, "page " .. pg[1] .. " refreshes: " .. tostring(rerr))
      end
    end
    -- menus show textures and fonts
    local textured, fonted = 0, 0
    for _, m in ipairs(pfUI.octoui.W.menus) do
      for _, e in ipairs({ m:GetChildren() }) do
        for _, r in ipairs(e._kids or {}) do
          if r.kind == "Texture" and r.texture and string.find(r.texture, "plates\\bar%-") then textured = textured + 1 end
          if r.kind == "FontString" and r.font and string.find(string.lower(r.font[1] or ""), "%.ttf$") then fonted = fonted + 1 end
        end
      end
    end
    ok(textured >= 5 and fonted >= 5, "menus picture the textures and fonts (" .. textured .. " / " .. fonted .. ")")
    local old = 0
    for k in pairs(O.legacy) do if string.find(k, "^l:Nameplates") then old = old + 1 end end
    ok(old == 0, "pfUI's own Nameplates page is gone from the list")
    O.quickFind:SetText("debuff")
    local octo, legacy = 0, 0
    for _, e in ipairs(O.results or {}) do
      if e.legacy and string.find(e.where, "^Nameplates") then legacy = legacy + 1 end
      if not e.legacy and e.page and string.sub(e.page.key or "", 1, 2) == "np" then octo = octo + 1 end
    end
    ok(octo > 0 and legacy == 0, "Find: nameplate settings on the new pages only (" .. octo .. " / " .. legacy .. ")")
    O.quickFind:SetText("")
    -- the preview is pinned above the page's scrolling part, and can fold
    O:Select("o:nplook")
    local pl = O.pages.nplook
    ok(pl and pl.pin and pl.pin.octoPinned and pl.pin:GetParent() == pl.frame, "the preview is pinned at the top of the page")
    local top = pl.frame.points and pl.frame.points[1]
    ok(top and top[1] == "TOPLEFT" and top[5] < -40, "the options scroll below it (" .. tostring(top and top[5]) .. ")")
    ok(pfUI.octoui.W.Viewport(pl.pin) == nil, "nothing cuts the pinned strip off")
    -- every part of the preview has its card (one card per part)
    local missing = {}
    for what, t in pairs(pfUI.plates.GO or {}) do
      if not pfUI.plates.OpenSection(t[1], t[2]) then table.insert(missing, what .. " -> " .. t[2]) end
    end
    ok(table.getn(missing) == 0, "every preview part opens its own card (" .. table.concat(missing, ", ") .. ")")
    -- a part's options card lights up itself (cut off by the page's scrolling)
    local c = pfUI.plates.OpenSection and pfUI.plates.OpenSection("nplook", "Raid mark")
    ok(c and c.card, "Raid mark card opened from the preview")
    if c then
      pfUI.octoui.W.Flash(c.card)
      ok(c.card.octoFlash and c.card.octoFlash:IsShown() and c.card.octoFlash:GetParent() == c.card, "the card itself lights up")
    end
    -- the looks live on Look and size, not General; sizes sit right under them
    ok(pfUI.plates.OpenSection("nplook", "Looks") and not pfUI.plates.OpenSection("npgeneral", "Looks"), "Looks card is on Look and size")
    local cp = pfUI_config.plates
    local was = { cp.size_enemynpc, cp.size_enemyplayer, cp.size_friendlynpc, cp.size_friendlyplayer, cp.sizematch }
    cp.size_friendlynpc = "125"
    pfUI.plates.lastSize = "size_friendlynpc"
    pfUI.plates.MatchSizes()
    ok(cp.size_enemynpc == "125" and cp.size_enemyplayer == "125" and cp.size_friendlyplayer == "125", "Match all sizes copies the one changed last")
    local sizeSlider
    for _, e in ipairs(pfUI.octoui.W.index) do
      if e.page == pl and e.label == "Enemy players" then sizeSlider = e end
    end
    ok(sizeSlider, "the size sliders are on Look and size")
    cp.size_enemynpc, cp.size_enemyplayer, cp.size_friendlynpc, cp.size_friendlyplayer, cp.sizematch = unpack(was)
    pfUI.plates.lastSize = nil
    pfUI.gui:Hide()
  end

  -- a text's spot is only as big as its words, so the bar under it can be picked
  if pfUI.plates and pfUI.plates.previews and pfUI.plates.previews[1] then
    local g = pfUI.plates.previews[1]
    local txt = g.nameplate.health.text
    local th = txt.hots and txt.hots[g]
    local bh = g.nameplate.health.hots and g.nameplate.health.hots[g]
    ok(th and bh and th.fit and th:GetWidth() < 60, "health text spot fits its words (" .. tostring(th and th:GetWidth()) .. " px)")
  end

  -- the cast bar's spot answers between casts
  local P = pfUI.plates
  if P and P.previews and P.previews[1] then
    local cb = P.previews[1].nameplate.castbar
    local hot = cb.hots and cb.hots[P.previews[1]]
    ok(hot and hot.always, "the cast bar can be clicked even between casts")
  end

  -- phase 4: animations and rules
  local Fx = P and P.Fx
  ok(Fx and Fx.Play and Fx.Rules, "nameplate animations and rules loaded")
  if Fx and P.previews and P.previews[1] then
    local plate = P.previews[1].nameplate
    local o = plate.octo
    local now = GetTime()
    pfUI_config.plates.animsize = "25"
    Fx.Play(o, "pop", now)
    ok(Fx.Scale(plate, o, now + .09) > 1.2, "pop: the plate grows (" .. Fx.Scale(plate, o, now + .09) .. ")")
    ok(Fx.Scale(plate, o, now + 1) == 1 and not o.anim, "and settles")
    -- your crit on it animates its plate
    local pname = plate.original.name:GetText()
    Fx.seen[plate] = GetTime()
    Fx.OnCrit(pname)
    ok(o.anim == pfUI_config.plates.animcrit, "your crit on " .. tostring(pname) .. " plays its animation")
    o.anim = nil
    ok(Fx.CritTarget("CHAT_MSG_SPELL_SELF_DAMAGE", "Your Fireball crits Hogger for 500 Fire damage.") == "Hogger",
      "a crit line names who was crit")
    -- a rule: names with that word grow and turn orange
    local r1, r2 = pfUI_config.plates.rule1, pfUI_config.plates.rule2
    r1.on, r1.when, r1.value, r1.effect, r1.size = "1", "name", string.sub(pname or "x", 1, 3), "bigger", "150"
    r2.on, r2.when, r2.value, r2.effect, r2.color = "1", "name", pname or "x", "color", "1,0.5,0,1"
    o.fxAt = 0
    Fx.Tick(plate, o, GetTime())
    ok(o.fx and o.fx.scale == 1.5 and o.fx.color, "rules match by name: bigger and coloured")
    local cr2, cg2 = plate.health:GetStatusBarColor()
    ok(math.abs((cr2 or 0) - 1) < .01 and math.abs((cg2 or 0) - .5) < .01, "the rule's colour is on the bar")
    r1.when, r1.value = "health", "200"
    o.fxAt = 0
    Fx.Rules(plate, o, GetTime())
    ok(o.fx and o.fx.scale == 1.5, "health below 200%: always true")
    r1.on, r2.on = "0", "0"
    o.fxAt = 0
    Fx.Tick(plate, o, GetTime())
    ok(not o.fx, "rules off: nothing")
  end

  -- everything back as it came
  if P and P.ResetAll then
    pfUI_config.plates.size_target = "150"
    pfUI_config.plates.castoffx = "40"
    pfUI_config.nameplates.width = "200"
    P.ResetAll()
    ok(pfUI_config.plates.size_target == "110" and pfUI_config.plates.castoffx == "0" and pfUI_config.nameplates.width == "130"
      and P.CurrentLook() == "plater", "Reset everything: as it came, with the Plater look")
  end
end

-- ---------------------------------------------------------------- Key Map

do
  local KM = pfUI.keymap
  ok(KM ~= nil, "Key Map module")
  if KM then
    ok(KM.SlotOf("ACTIONBUTTON5") == 5 and KM.SlotOf("MULTIACTIONBAR1BUTTON2") == 62
      and KM.SlotOf("MULTIACTIONBAR3BUTTON12") == 36 and KM.SlotOf("TOGGLEBACKPACK") == nil, "binding -> action slot")
    ok(KM.CommandOf(62) == "MULTIACTIONBAR1BUTTON2" and KM.CommandOf(7) == "ACTIONBUTTON7", "action slot -> binding")
    for _, l in ipairs(KM.LAYOUTS) do
      local rows = KM.Rows(l.key)
      ok(table.getn(rows) == 7, l.key .. " keyboard has its rows")
    end
    -- a pretend binding table
    local binds = { ["1"] = "ACTIONBUTTON1", ["2"] = "ACTIONBUTTON2", Q = "TOGGLEBACKPACK" }
    local saved = { SetBinding, GetBindingAction, GetBindingKey, SaveBindings, HasAction, GetActionTexture, PlaceAction }
    _G.SetBinding = function(k, a) binds[k] = a end
    _G.GetBindingAction = function(k) return binds[k] or "" end
    _G.GetBindingKey = function(a) for k, v in pairs(binds) do if v == a then return k end end end
    _G.SaveBindings = function() end
    local actions = { [1] = "Interface\\Icons\\Spell_Fire_FlameBolt", [3] = "Interface\\Icons\\INV_Misc_Gear_01" }
    _G.HasAction = function(s) return actions[s] ~= nil end
    _G.GetActionTexture = function(s) return actions[s] end
    local placed
    _G.PlaceAction = function(s) placed = s end
    KM:Toggle()
    ok(KM.frame and KM.frame:IsShown(), "/keymap opens the Key Map")
    local function Cell(key)
      for _, c in ipairs(KM.cells) do if c.key == key and c:IsShown() then return c end end
    end
    local one, two, q = Cell("1"), Cell("2"), Cell("Q")
    ok(one and one.icon:IsShown(), "a key on an action button shows the spell's icon")
    ok(q and q.what.text and q.what.text ~= "", "a key with another binding shows its name")
    -- pick up 1, put it on 2: they swap
    Mock.Run(one, "OnClick", "LeftButton")
    ok(KM.picked == "1", "left-click picks a binding up")
    Mock.Run(two, "OnClick", "LeftButton")
    ok(binds["2"] == "ACTIONBUTTON1" and binds["1"] == "ACTIONBUTTON2", "clicking another key swaps them")
    Mock.Run(q, "OnClick", "RightButton")
    ok(binds.Q == nil, "right-click unbinds")
    -- unbound abilities: slot 3 has a spell and no key
    local list = KM.Unbound()
    ok(table.getn(list) == 1 and list[1] == 3, "unbound ability found on the bars")
    KM.ability = 3
    Mock.Run(q, "OnClick", "LeftButton")
    ok(binds.Q == "ACTIONBUTTON3", "an unbound ability goes onto the clicked key")
    -- a spell dropped on an action button key goes onto its button
    ok(KM.Drop("1") and placed == 2, "dropping on an action button key places it there (" .. tostring(placed) .. ")")
    -- the Shift layer
    Mock.Run(Cell(nil) or KM.cells[1], "OnShow")
    for _, c in ipairs(KM.cells) do
      if c.modifier == "SHIFT" then Mock.Run(c, "OnClick", "LeftButton") break end
    end
    ok(KM.layer == "SHIFT-", "clicking Shift shows the Shift layer")
    KM.frame:Hide()
    _G.SetBinding, _G.GetBindingAction, _G.GetBindingKey, _G.SaveBindings, _G.HasAction, _G.GetActionTexture, _G.PlaceAction =
      saved[1], saved[2], saved[3], saved[4], saved[5], saved[6], saved[7]
  end
end

-- ---------------------------------------------------------------- Key Map: spell ranks

do
  local KM = pfUI.keymap
  if KM then
    local book = { { "Fireball", "Rank 1" }, { "Frostbolt", "Rank 1" }, { "Fireball", "Rank 2" }, { "Fireball", "Rank 3" } }
    local saved = { GetSpellName, KM.ActionSpell, PickupSpell, PlaceAction, ClearCursor }
    _G.GetSpellName = function(i) local s = book[i] if s then return s[1], s[2] end end
    KM.ActionSpell = function(slot) if slot == 5 then return "Fireball", "Rank 1" end end
    local ranks = KM.SpellRanks("Fireball")
    ok(table.getn(ranks) == 3 and ranks[3][1] == 4 and ranks[3][2] == "Rank 3", "every rank of a spell found in the spellbook")
    local picked, placed, done
    _G.PickupSpell = function(i) picked = i end
    _G.PlaceAction = function(s) placed = s end
    _G.ClearCursor = function() end
    local anchor = CreateFrame("Button", nil, UIParent)
    ok(KM.PickRank(5, anchor, function() done = true end) and KM.rankMenu and KM.rankMenu:IsShown(),
      "a spell with several ranks asks which one")
    -- the menu lists highest first, under a heading; pick Rank 2 (spellbook index 3)
    local entry
    for _, e in ipairs({ KM.rankMenu:GetChildren() }) do if e.key == 3 then entry = e end end
    ok(entry ~= nil, "each rank is in the menu")
    if entry then Mock.Run(entry, "OnClick", "LeftButton") end
    ok(picked == 3 and placed == 5 and done, "the chosen rank goes on the button, then it is picked")
    KM.ActionSpell = function() return "Frostbolt", "Rank 1" end
    done = nil
    ok(not KM.PickRank(6, anchor, function() done = true end) and done, "one rank: no question")
    _G.GetSpellName, KM.ActionSpell, _G.PickupSpell, _G.PlaceAction, _G.ClearCursor = saved[1], saved[2], saved[3], saved[4], saved[5]
  end
end

-- ---------------------------------------------------------------- Key Bindings

do
  local KB = pfUI.keybinds
  ok(KB ~= nil, "Key Bindings module")
  if KB then
    local list = { "HEADER_MOVEMENT", "MOVEFORWARD", "JUMP", "HEADER_BLANK2", "TOGGLEAUTORUN",
                   "HEADER_ACTIONBAR", "ACTIONBUTTON1", "HEADER_RAID_TARGET", "RAIDTARGET8" }
    local binds = { W = "MOVEFORWARD", SPACE = "JUMP", ["1"] = "ACTIONBUTTON1" }
    local saved = { GetNumBindings, GetBinding, GetBindingKey, GetBindingAction, SetBinding, SaveBindings }
    _G.GetNumBindings = function() return table.getn(list) end
    _G.GetBinding = function(i) return list[i] end
    _G.GetBindingKey = function(a)
      local ks = {}
      for k, v in pairs(binds) do if v == a then table.insert(ks, k) end end
      table.sort(ks)
      return ks[1], ks[2]
    end
    _G.GetBindingAction = function(k) return binds[k] or "" end
    _G.SetBinding = function(k, a) binds[k] = a end
    _G.SaveBindings = function() end
    _G.BINDING_HEADER_MOVEMENT = "Movement Keys"
    local secs = KB.Read()
    ok(table.getn(secs) == 3 and secs[1].name == "Movement Keys" and table.getn(secs[1].rows) == 3,
      "categories read from the game's list (BLANK joins the one before)")
    ok(secs[3].raid and KB.Icon(secs[3], "RAIDTARGET8") ~= nil, "raid mark rows show the mark")
    pfUI.octoui.Store().kbFold = {}
    KB:Toggle()
    local shown = 0
    for _, r in ipairs(KB.rows) do if r:IsShown() then shown = shown + 1 end end
    ok(KB.frame:IsShown() and table.getn(KB.heads) == 3 and shown == 0, "/keybinds opens with every category folded")
    KB.heads[1]:Click()
    shown = 0
    for _, r in ipairs(KB.rows) do if r:IsShown() then shown = shown + 1 end end
    ok(shown == 3, "opening Movement shows its commands (" .. shown .. ")")
    -- bind JUMP's second key
    local jump
    for _, r in ipairs(KB.rows) do if r.cmd == "JUMP" and r:IsShown() then jump = r end end
    ok(jump ~= nil, "a row per command")
    if jump then
      Mock.Run(jump.k2, "OnClick", "LeftButton")
      ok(KB.waiting and KB.waiting.cmd == "JUMP", "clicking a key box waits for a key")
      KB.Pressed("SHIFT")
      ok(KB.waiting ~= nil, "a modifier alone does not bind")
      KB.Pressed("NUMPAD0")
      ok(binds.NUMPAD0 == "JUMP" and binds.SPACE == "JUMP", "the key goes onto key 2, key 1 stays")
      Mock.Run(jump.k1, "OnClick", "LeftButton")
      KB.Pressed("W")
      ok(binds.W == "JUMP", "taking a key from another command")
      Mock.Run(jump.k1, "OnClick", "RightButton")
      local k1 = GetBindingKey("JUMP")
      ok(k1 ~= "NUMPAD0" or binds.NUMPAD0 == "JUMP", "right-click clears a box")
    end
    -- fold a category, search
    KB.heads[1]:Click()
    shown = 0
    for _, r in ipairs(KB.rows) do if r:IsShown() then shown = shown + 1 end end
    ok(shown == 0, "folding Movement hides its rows (" .. shown .. " left)")
    KB.find:SetText("autorun")
    shown = 0
    for _, r in ipairs(KB.rows) do if r:IsShown() then shown = shown + 1 end end
    ok(shown == 1, "search keeps the matching command (" .. shown .. ")")
    KB.find:SetText("")
    KB.frame:Hide()
    -- the Key Map's All bindings tab: the same categories, folded; drag a command onto a key
    local KM = pfUI.keymap
    if KM then
      KM.Store().tab = "all"
      KM.Store().open = {}
      KM.Store().hidePanel = nil
      KM.layer, KM.locked = "", ""
      KM:Toggle()
      ok(KM.listScroll:IsShown() and KM.listHeads[1] and KM.listHeads[1]:IsShown(), "All bindings tab lists the categories")
      local rowsShown = 0
      for _, r in ipairs(KM.listRows) do if r:IsShown() then rowsShown = rowsShown + 1 end end
      ok(rowsShown == 0, "categories start folded")
      KM.listHeads[1]:Click()
      local jumpRow
      for _, r in ipairs(KM.listRows) do if r:IsShown() and r.cmd == "JUMP" then jumpRow = r end end
      ok(jumpRow ~= nil, "opening one lists its commands")
      if jumpRow then
        -- drag JUMP onto F: picture follows, let go over the F key
        local fcell
        for _, c in ipairs(KM.cells) do if c.key == "F" then fcell = c end end
        local mo = MouseIsOver
        _G.MouseIsOver = function(fr) return fr == fcell end
        Mock.Run(jumpRow, "OnDragStart")
        ok(KM.ghost and KM.ghost:IsShown(), "dragging shows the picture")
        Mock.Run(jumpRow, "OnDragStop")
        _G.MouseIsOver = mo
        ok(binds.F == "JUMP" and not KM.ghost:IsShown(), "let go over a key: bound (" .. tostring(binds.F) .. ")")
        -- click, then click a key
        Mock.Run(jumpRow, "OnMouseDown")
        Mock.Run(jumpRow, "OnClick", "LeftButton")
        ok(KM.command == "JUMP", "clicking a command picks it")
        local qcell
        for _, c in ipairs(KM.cells) do if c.key == "Q" then qcell = c end end
        Mock.Run(qcell, "OnClick", "LeftButton")
        ok(binds.Q == "JUMP" and KM.command == nil, "then clicking a key binds it")
      end
      -- the Unbound tab
      KM.tabs[1]:Click()
      ok(not KM.listScroll:IsShown(), "Unbound tab hides the list")
      KM.frame:Hide()
    end
    _G.GetNumBindings, _G.GetBinding, _G.GetBindingKey, _G.GetBindingAction, _G.SetBinding, _G.SaveBindings =
      saved[1], saved[2], saved[3], saved[4], saved[5], saved[6]
  end
end

-- ---------------------------------------------------------------- pfUI Octo or Blizzard, per section

do
  local BZ = pfUI.blizz
  ok(BZ and BZ.S and BZ.snap[PlayerFrame], "the Blizzard switch noted Blizzard's frames before pfUI")
  ok(BZ and BZ.GROUPS and BZ.snap[MinimapBorderTop], "the switch module ran to the end (textures noted too)")
  if BZ then
    BZ.Ready()
    ok(BZ.ready and BZ.globals.ToggleBackpack.octo, "pfUI's own functions noted after every module ran")
    -- every section switches both ways without an error
    for id, s in pairs(BZ.S) do
      ok(BZ.Set(id, "blizz") and pfUI_config.blizz[id] == "1", id .. ": to Blizzard's")
      ok(BZ.Set(id, "octo") and pfUI_config.blizz[id] == "0", id .. ": back to pfUI Octo's")
    end
    -- unit frames: pfUI's out of sight, the game's player frame listening again
    local pf = pfUI.uf and pfUI.uf.player
    BZ.Set("unitframes", "blizz")
    ok(pf and pf:GetParent() == BZ.hider and PlayerFrame:IsShown(), "Blizzard unit frames: pfUI's player frame away, the game's shown")
    BZ.Set("unitframes", "octo")
    ok(pf:GetParent() ~= BZ.hider and not PlayerFrame:IsShown(), "and back")
    -- the minimap goes home and comes back
    BZ.Set("minimap", "blizz")
    ok(Minimap:GetParent() ~= pfUI.minimap and pfUI.minimap:GetParent() == BZ.hider, "Blizzard minimap: out of pfUI's frame")
    BZ.Set("minimap", "octo")
    ok(Minimap:GetParent() == pfUI.minimap and pfUI.minimap:GetParent() ~= BZ.hider, "and back in pfUI's")
    -- bags: the game's functions, then pfUI's
    BZ.Set("bags", "blizz")
    ok(_G.ToggleBackpack == BZ.globals.ToggleBackpack.blizz, "Blizzard bags: the game's ToggleBackpack")
    BZ.Set("bags", "octo")
    ok(_G.ToggleBackpack == BZ.globals.ToggleBackpack.octo, "and pfUI's again")
    -- chat: the game's windows and strings, then pfUI's panels again
    if pfUI.chat and pfUI.chat.left and ChatFrame1 then
      BZ.Set("chat", "blizz")
      ok(ChatFrame1:GetParent() ~= pfUI.chat.left and pfUI.chat.left:GetParent() == BZ.hider
        and _G.CHAT_GUILD_GET == BZ.globals.CHAT_GUILD_GET.blizz, "Blizzard chat: the game's windows and \"[Guild]\" names")
      ok(pfUI.chat.RefreshChat(pfUI.chat) == nil and ChatFrame1:GetParent() ~= pfUI.chat.left, "pfUI's chat refresh leaves Blizzard's windows alone")
      BZ.Set("chat", "octo")
      ok(pfUI.chat.left:GetParent() ~= BZ.hider and _G.CHAT_GUILD_GET == BZ.globals.CHAT_GUILD_GET.octo, "and pfUI's chat back")
    end
    -- tooltip: the game's anchor and backdrop
    BZ.Set("tooltip", "blizz")
    ok(_G.GameTooltip_SetDefaultAnchor == BZ.globals.GameTooltip_SetDefaultAnchor.blizz
      and (not pfUI.tooltip or pfUI.tooltip:GetParent() == BZ.hider), "Blizzard tooltip: the game's anchor")
    BZ.Set("tooltip", "octo")
    ok(_G.GameTooltip_SetDefaultAnchor == BZ.globals.GameTooltip_SetDefaultAnchor.octo, "and pfUI's again")
    -- panels hide and come back
    BZ.Set("panels", "blizz")
    ok(not pfUI.panel or not pfUI.panel.left or pfUI.panel.left:GetParent() == BZ.hider, "Blizzard: no info panels")
    BZ.Set("panels", "octo")
    -- raid frames: pfUI's away, back
    if pfRaidCluster then
      BZ.Set("raid", "blizz")
      ok(pfRaidCluster:GetParent() == BZ.hider, "Blizzard raid: pfUI's raid frames away")
      BZ.Set("raid", "octo")
      ok(pfRaidCluster:GetParent() ~= BZ.hider, "and back")
    end
    -- the world map: the game's toggle and art, then pfUI's again
    if pfUI.map and BZ.map.regions then
      local carto = rawget(_G, "Cartographer")
      _G.Cartographer = nil  -- (another test leaves one; pfUI leaves the map to it)
      local pfToggle = _G.ToggleWorldMap
      BZ.Set("worldmap", "blizz")
      ok(_G.ToggleWorldMap == BZ.map.toggle and (not WorldMapFrame.backdrop or not WorldMapFrame.backdrop:IsShown()),
        "Blizzard world map: the game's toggle, no pfUI frame")
      BZ.Set("worldmap", "octo")
      ok(_G.ToggleWorldMap == pfToggle, "and pfUI's map again")
      _G.Cartographer = carto
    end
    ok(BZ.GROUPS["Unit Frames"][3] == "raid" and BZ.GROUPS["Minimap & Buffs"][3] == "worldmap", "raid and world map switches on their topics")
    -- keep it or not: a pick goes back by itself unless kept
    BZ.Pick("panels", "blizz")
    ok(BZ.IsBlizz("panels") and pfOctoBlizzConfirm:IsShown() and BZ.confirm.id == "panels", "a switch to Blizzard's asks to be kept")
    Mock.now = Mock.now + 16
    Mock.Run(pfOctoBlizzConfirm, "OnUpdate", .1)
    ok(not BZ.IsBlizz("panels") and not pfOctoBlizzConfirm:IsShown(), "not kept in 15 s: pfUI Octo's again")
    BZ.Pick("panels", "blizz")
    Mock.Run(BZ.confirm.keep, "OnClick")
    Mock.now = Mock.now + 16
    Mock.Run(pfOctoBlizzConfirm, "OnUpdate", .1)
    ok(BZ.IsBlizz("panels"), "kept: it stays")
    -- one way back for everything, with no chat needed
    BZ.Set("tooltip", "blizz")
    BZ.AllOcto()
    ok(not BZ.IsBlizz("panels") and not BZ.IsBlizz("tooltip"), "undo Blizzard: every section back")
    ok(SlashCmdList.OCTOUNDO and GameMenuButtonOctoUndo, "/octoundo and an Esc menu button")
    -- a switch that goes wrong is undone at once
    local good = BZ.S.panels.blizz
    BZ.S.panels.blizz = function() error("boom") end
    BZ.Set("panels", "blizz")
    ok(not BZ.IsBlizz("panels") and BZ.state.panels == "octo", "a failed switch to Blizzard's is undone")
    BZ.S.panels.blizz = good
    -- the strip over the page: shown in a section that has a switch
    local O = pfUI.octoui and pfUI.octoui.Options
    if O and O.frame then
      pfUI.gui:Show()
      O:Select("o:ufframes")
      ok(O.swap:IsShown() and O.swap.parts[1].octo.id == "unitframes" and O.swap.parts[2].octo.id == "castbar",
        "Unit Frames pages: a pfUI Octo / Blizzard switch for frames and cast bar")
      ok(O.swap.parts[1].octo.picked and not O.swap.parts[1].blizz.picked, "pfUI Octo lit while in use")
      Mock.Run(O.swap.parts[1].blizz, "OnClick")
      ok(pfUI_config.blizz.unitframes == "1" and O.swap.parts[1].blizz.picked, "one click: Blizzard's, lit")
      Mock.Run(O.swap.parts[1].octo, "OnClick")
      ok(pfUI_config.blizz.unitframes == "0", "one click back")
      O:Select("o:ctgeneral")
      ok(O.swap:IsShown() and O.swap.parts[1].octo.id == "combattext" and not O.swap.parts[2].octo:IsShown(), "one switch where a section has one")
      local about
      for k in pairs(O.nav) do if string.find(k, "About") then about = k end end
      if about then
        O:Select(about)
        ok(not O.swap:IsShown(), "no switch where there is nothing of Blizzard's")
      end
      pfUI.gui:Hide()
    end
  end
end

-- layout mode: a bar sized with the wheel keeps that size after Esc and the
-- bars' next refresh (user, 24 Oct 2026: it went back)
do
  local bar = _G.pfActionBarMain
  if bar and pfUI.unlock and pfUI.bars then
    for k in pairs(pfUI.movables) do if type(k) ~= "string" then pfUI.movables[k] = nil end end
    pfUI.unlock:Show()
    local was = bar:GetScale()
    if bar.drag then
      _G.this, _G.arg1 = bar.drag, 2
      bar.drag:GetScript("OnMouseWheel")()
    end
    local sized = bar:GetScale()
    pfUI.unlock:Hide()
    pfUI.bars:UpdateConfig()
    ok(math.abs(sized - was) > .1 and math.abs(bar:GetScale() - sized) < .01,
      "a bar sized in layout mode keeps its size after Esc (" .. was .. " -> " .. sized .. " -> " .. bar:GetScale() .. ")")
    ok(pfUI_config.bars.bar1.scale == tostring(sized), "and the Bars page's Scale shows it (" .. tostring(pfUI_config.bars.bar1.scale) .. ")")
    -- the Scale setting changed on the page: layout mode's saved size follows
    pfUI_config.bars.bar1.scale = "1"
    pfUI.bars:UpdateConfig()
    pfUI.api.UpdateMovable(bar)
    ok(math.abs(bar:GetScale() - 1) < .01, "and a Scale picked on the page holds in layout mode too")
  end
end

-- the Buffs section: one page with a preview laid out as buff.lua does it
do
  local O = pfUI.octoui and pfUI.octoui.Options
  local BO = pfUI.buffsOcto
  ok(BO and O and O.BUILD.bfbuffs and O.replaced[pfUI.env.T["Buffs"]], "Buffs page in place of pfUI's Buffs category")
  if BO and O then
    pfUI.gui:Show()
    local good, err = pcall(function() O:Select("o:bfbuffs") end)
    ok(good and O.pages.bfbuffs and O.pages.bfbuffs.frame:IsShown(), "the Buffs page builds: " .. tostring(err))
    ok(BO.parts and BO.parts.buffs and BO.parts.debuffs and BO.parts.weapons and BO.parts.bar and BO.parts.totems,
      "its preview has buffs, debuffs, weapon buffs, a buff bar and totems")
    if BO.parts then
      local s = pfUI_config.buffs
      local was = { s.size, s.spacing, s.buffrowsize }
      s.size, s.spacing, s.buffrowsize = "30", "2", "4"
      BO.Layout()
      -- 10 sample buffs, 4 per row: 3 rows of (30 + 2 * 2) plus text under each
      local g = BO.parts.buffs
      ok(math.abs(g:GetWidth() - 4 * 34) < .5, "buffs per row and spacing as buff.lua (" .. tostring(g:GetWidth()) .. ")")
      -- Shift + wheel = icon size
      local isk = IsShiftKeyDown
      _G.IsShiftKeyDown = function() return true end
      _G.this, _G.arg1 = g, 1
      Mock.Run(g, "OnMouseWheel", 1)
      _G.IsShiftKeyDown = isk
      ok(s.size == "31", "Shift + wheel over the icons makes them bigger (" .. tostring(s.size) .. ")")
      s.size, s.spacing, s.buffrowsize = was[1], was[2], was[3]
      BO.Layout()
      -- the buff bar tab changes what the cards set
      BO.bar = "tdebuff"
      BO.Layout()
      ok(BO.parts.bar.name:GetText() == "Shadow Word: Pain", "the Target's debuffs tab shows a target debuff on the sample bar")
      BO.bar = "pbuff"
    end
    pfUI.gui:Hide()
  end
end

-- gear sets (gear.lua): a small made-up character with bags, swaps through
-- the client's pick-up / equip calls as 1.12 does them
do
  local GR = pfUI.gear
  ok(GR and GR.Equip and GR.Flyout and GR.trinkets and pfUI.gearOcto, "gear sets, item menu, trinket bar and the Gear page are there")
  if GR then
    local function Item(id, name, loc, ench)
      return { link = "|cffffffff|Hitem:" .. id .. ":" .. (ench or 0) .. ":0:0|h[" .. name .. "]|h|r", loc = loc,
               tex = "Interface\\Icons\\" .. name, ench = ench }
    end
    local sword, shield = Item(100, "Sword", "INV_WEAPON"), Item(101, "Shield", "INVTYPE_SHIELD")
    local axe, ring, ring2 = Item(200, "Axe", "INVTYPE_2HWEAPON"), Item(300, "Ring", "INVTYPE_FINGER"), Item(301, "Band", "INVTYPE_FINGER")
    local trink, trink2 = Item(400, "Idol", "INVTYPE_TRINKET"), Item(401, "Charm", "INVTYPE_TRINKET")
    local axeFiery = Item(200, "Axe", "INVTYPE_2HWEAPON", 803)
    sword.loc = "INVTYPE_WEAPON"
    local inv = { [16] = sword, [17] = shield, [11] = ring, [13] = trink }
    local bags = { [0] = { axe, ring2, trink2, axeFiery }, [1] = {} }
    local cursor
    local saved = {}
    local function Stub(name, fn) saved[name] = _G[name] _G[name] = fn end
    local combat = false
    Stub("GetContainerNumSlots", function(b) if b == 0 then return 8 elseif b == 1 then return 4 end return 0 end)
    Stub("GetContainerItemLink", function(b, s) return bags[b] and bags[b][s] and bags[b][s].link end)
    Stub("GetContainerItemInfo", function(b, s) local it = bags[b] and bags[b][s] return it and it.tex, 1, nil end)
    Stub("GetInventoryItemLink", function(u, i) return inv[i] and inv[i].link end)
    Stub("GetInventoryItemTexture", function(u, i) return inv[i] and inv[i].tex end)
    Stub("IsInventoryItemLocked", function() return nil end)
    Stub("CursorHasItem", function() return cursor ~= nil end)
    Stub("SpellIsTargeting", function() return nil end)
    Stub("UnitIsDeadOrGhost", function() return nil end)
    Stub("UnitAffectingCombat", function(u) return u == "player" and combat end)
    Stub("GetItemInfo", function(s)
      local _, _, id, ench = string.find(s, "item:(%d+):(%d*)")
      for _, it in ipairs({ sword, shield, axe, ring, ring2, trink, trink2, axeFiery }) do
        if string.find(it.link, "item:" .. id .. ":" .. ench .. ":", 1, true) then
          return "x", it.link, 1, 1, "Armor", "Misc", 1, it.loc, it.tex
        end
      end
    end)
    Stub("PickupContainerItem", function(b, s)
      local here = bags[b][s]
      if cursor then
        bags[b][s] = cursor.item
        cursor = here and { item = here, bag = b, slot = s } or nil
      else
        bags[b][s] = nil
        cursor = here and { item = here, bag = b, slot = s } or nil
      end
    end)
    -- (as the 1.12 client: a slot clicked with an item held puts it on and the
    -- one worn goes where the held one came from; there is no EquipCursorItem)
    Stub("EquipCursorItem", nil)
    Stub("PickupInventoryItem", function(i)
      local here = inv[i]
      if cursor then
        local held = cursor.item
        inv[i] = held
        if here and cursor.bag then bags[cursor.bag][cursor.slot] = here
        elseif here and cursor.inv then inv[cursor.inv] = here end
        cursor = nil
        -- (a two-hander takes the off hand off into the bags)
        if held.loc == "INVTYPE_2HWEAPON" and inv[17] then
          for s = 1, 8 do if not bags[0][s] then bags[0][s] = inv[17] inv[17] = nil break end end
        end
      else
        inv[i] = nil
        cursor = here and { item = here, inv = i } or nil
      end
    end)
    local function Run() for _ = 1, 40 do GR.Tick() end end
    local sets = pfUI_config.gear.sets
    local wasSets, wasCur, wasBefore = {}, pfUI_config.gear.current, pfUI_config.gear.before
    for k, v in pairs(sets) do wasSets[k] = v sets[k] = nil end

    GR.Save("Tank", GR.Snapshot())
    ok(sets.Tank and type(sets.Tank.slots.s16) == "table" and sets.Tank.slots.s16.id == "100:0:0" and sets.Tank.slots.s1 == "empty",
      "a set saved from what is worn (empty slots too)")
    ok(GR.IsEquipped("Tank") and GR.Current() == "Tank", "it counts as worn")
    -- a partial set: only the weapons
    GR.Save("Axe", { s16 = { id = "200:0:0", name = "Axe" }, s17 = "empty" })
    GR.Equip("Axe")
    Run()
    ok(inv[16] == axe and inv[17] == nil and GR.IsEquipped("Axe") and GR.Current() == "Axe", "a weapons-only set goes on (two-hander, off hand off)")
    ok(inv[11] == ring and inv[13] == trink, "slots outside the set stay as they are")
    -- back to what was worn before
    GR.Unequip()
    Run()
    ok(inv[16] == sword and inv[17] == shield, "taking a set off puts back the gear worn before")
    -- the same item with another enchant is another copy
    GR.Save("Fiery", { s16 = { id = "200:803:0", name = "Axe" } })
    GR.Equip("Fiery")
    Run()
    ok(inv[16] == axeFiery, "the copy with the saved enchant is picked, not another")
    GR.Equip("Tank")
    Run()
    ok(GR.IsEquipped("Tank"), "and back to the full set")
    -- in combat: weapons now, armour after
    GR.Save("Rings", { s11 = { id = "301:0:0", name = "Band" }, s16 = { id = "200:0:0", name = "Axe" }, s17 = "empty" })
    combat = true
    GR.Equip("Rings")
    Run()
    ok(inv[16] == axe and inv[11] == ring and GR.queue and GR.queue.waiting, "in combat: the weapon changes, the ring waits")
    combat = false
    Mock.Fire("PLAYER_REGEN_ENABLED")
    Run()
    ok(inv[11] == ring2 and not GR.queue, "the ring goes on when combat ends")
    -- a ring worn in the other slot is moved, not looked for in the bags
    GR.Save("Swap", { s12 = { id = "301:0:0", name = "Band" }, s11 = "empty" })
    GR.Equip("Swap")
    Run()
    ok(inv[12] == ring2 and inv[11] == nil, "an item worn in another slot moves across")
    -- what fits a slot, for the item menus and the trinket bar
    local trinkets = GR.ItemsFor(13)
    ok(table.getn(trinkets) == 1 and trinkets[1].id == "401:0:0", "the trinket menu lists the carried trinkets")
    GR.EquipItem(14, trinkets[1])
    Run()
    ok(inv[14] == trink2, "picking one from the menu puts it on")
    -- key bindings and /gear
    sets.Tank.key = "3"
    GR.Changed()
    ok(BINDING_NAME_PFGEAR3 == "Gear set 3: Tank", "key 3 is named after its set in Key Bindings")
    GR.KeyPress(3)
    Run()
    ok(GR.IsEquipped("Tank"), "the key puts the set on")
    SlashCmdList.PFGEAR("save Bank")
    ok(sets.Bank ~= nil, "/gear save")
    ok(GR.Rename("Bank", "Bank alt") and sets["Bank alt"] and not sets.Bank, "a set can be renamed")
    -- the Gear page: tiles for the sets, the slots of the one picked
    local O = pfUI.octoui and pfUI.octoui.Options
    local GO = pfUI.gearOcto
    -- phase 3: the queue waits while casting / dead, and says why
    do
      local uci = UnitCastingInfo
      local casting = true
      pfUI.env.UnitCastingInfo = function() if casting then return "Frostbolt" end end
      _G.UnitCastingInfo = pfUI.env.UnitCastingInfo
      ok(GR.Blocked() == "casting", "gear cannot change while casting")
      casting = nil
      ok(GR.Blocked() == nil, "and can once the cast ends")
      pfUI.env.UnitCastingInfo, _G.UnitCastingInfo = uci, uci
      ok(GR.WaitText({ name = "Tank", waiting = "dead" }) == "Tank: it goes on when you are alive again", "the wait is explained")
    end
    -- phase 3: automatic swaps
    local GE = GR.events
    ok(GE and GE.Check and pfUI.octoui.Options.BUILD.gearevents, "automatic swaps and their page are there")
    local pgood, perr = pcall(function() pfUI.octoui.Options:Page("gearevents") end)
    ok(pgood, "the Automatic swaps page builds: " .. tostring(perr))
    if GE then
      local equip, wear, worn = GR.Equip, GR.Wear, GR.IsEquipped
      local got, back
      GR.Equip = function(n) got = n end
      GR.Wear = function(n, slots) back = slots end
      GR.IsEquipped = function() return false end
      pfUI_config.gear.sets.Riding = { icon = "x", slots = { s8 = { id = "1:0:0", name = "Riding boots", tex = "" } } }
      GE.Cfg("mount").on, GE.Cfg("mount").set, GE.Cfg("mount").back = "1", "Riding", "1"
      local m = IsMounted
      local up = true
      _G.IsMounted = function() return up end
      pfUI.env.IsMounted = _G.IsMounted
      GE.Check()
      ok(got == "Riding" and GE.state.active == "mount", "mounting wears the riding set")
      up = false
      GE.Check()
      ok(back and back.s8 ~= nil and GE.state.active == nil, "getting off puts back what was worn in its slots")
      _G.IsMounted, pfUI.env.IsMounted = m, m
      GR.Equip, GR.Wear, GR.IsEquipped = equip, wear, worn
      pfUI_config.gear.events.mount, pfUI_config.gear.sets.Riding = nil, nil
    end
    -- slot buttons bindable by hovering (user, 24 Oct 2026)
    do
      local sb = GR.slotbar and GR.slotbar.buttons and GR.slotbar.buttons[16] or pfGearSlot16
      ok(sb and sb.pfBinding == "PFGEARSLOT16" and sb.pfHoverbind, "the main hand slot button has a key binding and a hover-bind overlay")
      ok(pfGearTrinket1 and pfGearTrinket1.pfBinding == "PFGEARSLOT13", "the trinket buttons too")
      if sb and sb.pfHoverbind then
        local binds, saved = {}, { SetBinding, GetMouseFocus, SaveBindings, GetBindingKey }
        _G.SetBinding = function(k, a) binds[k] = a return 1 end
        _G.SaveBindings = function() end
        _G.GetMouseFocus = function() return sb.pfHoverbind end
        _G.GetBindingKey = function(a) for k, v in pairs(binds) do if v == a then return k end end end
        Mock.Run(sb.pfHoverbind, "OnKeyUp", "F")
        ok(binds.F == "PFGEARSLOT16", "hovering it and pressing F binds F to it")
        GR.ShowKeys()
        ok(sb.hotkey.text == "F", "its key shows in the corner (" .. tostring(sb.hotkey.text) .. ")")
        _G.SetBinding, _G.GetMouseFocus, _G.SaveBindings, _G.GetBindingKey = saved[1], saved[2], saved[3], saved[4]
      end
      local KM = pfUI.keymap
      if KM then
        local t = GetInventoryItemTexture
        _G.GetInventoryItemTexture = function(_, inv) if inv == 16 then return "Interface\\Icons\\INV_Sword_04" end end
        ok(KM.Describe("PFGEARSLOT16") == "Interface\\Icons\\INV_Sword_04", "the Key Map shows the worn item's picture on that key")
        _G.GetInventoryItemTexture = t
      end
    end
    if GO and GO.TexOf then
      -- seen in game 24 Oct: a set saved with the game's placeholder picture
      -- (INV_Robe_02, missing on this client) drew blank; the picture now
      -- comes from the item itself, any enchant
      ok(not GR.GoodTex("Interface\\Icons\\INV_Robe_02") and GR.GoodTex("Interface\\Icons\\INV_Sword_04"), "the placeholder picture is refused")
      local w, t, b = GR.Worn, GetInventoryItemTexture, GR.Bags
      GR.Worn = function(inv) if inv == 7 then return "47204:999:0" end end
      _G.GetInventoryItemTexture = function(_, inv) if inv == 7 then return "Interface\\Icons\\INV_Pants_08" end end
      GR.Bags = function() return {} end
      ok(GO.TexOf("47204:3025:0", 7) == "Interface\\Icons\\INV_Pants_08", "the worn copy's picture, whatever its enchant")
      GR.Worn, _G.GetInventoryItemTexture, GR.Bags = w, t, b
    end
    if O and GO then
      pfUI.gui:Show()
      local good, err = pcall(function() GO.Open("Tank") end)
      ok(good and O.pages.gearsets and O.pages.gearsets.frame:IsShown() and GO.slots and table.getn(GO.slots) == 19,
        "the Gear page opens with all 19 slots: " .. tostring(err))
      local shown = 0
      for _, r in ipairs(GO.rows or {}) do if r:IsShown() then shown = shown + 1 end end
      ok(shown == table.getn(GR.Sets()), "the saved sets listed on the left (" .. shown .. ")")
      ok(GO.name and GO.name:GetText() == "Tank" and GO.model, "the set's name and the character beside its slots")
      -- the slots where the character sheet has them: head top left, main hand under the middle
      local slotOf = {}
      for _, s in ipairs(GO.slots) do slotOf[s.inv] = s end
      local _, _, _, hx = slotOf[1]:GetPoint(1)
      local _, _, _, gx = slotOf[10]:GetPoint(1)
      local _, _, _, mx, my = slotOf[16]:GetPoint(1)
      ok(hx < mx and mx < gx and my < -200, "head on the left, hands on the right, weapons underneath")
      -- the tick and right-click: in the set or not
      ok(slotOf[16].tick:GetChecked(), "a slot of the set is ticked")
      _G.this, _G.arg1 = slotOf[1], "RightButton"
      slotOf[1]:GetScript("OnClick")()
      ok(sets.Tank.slots.s1 == nil and not slotOf[1].tick:GetChecked(), "right-click leaves a slot out (tick off)")
      _G.this = slotOf[1].tick
      slotOf[1].tick:GetScript("OnClick")()
      ok(sets.Tank.slots.s1 ~= nil, "the tick puts it back in")
      -- a slot's menu: the item worn there, its pair's, the bags, "take it off"
      local picked
      local fl = GR.Flyout
      GR.Flyout = function(owner, inv, onPick, opts) picked = opts.items end
      local had12 = inv[12]
      inv[12] = ring2
      GO.PickFor(slotOf[11])
      inv[12] = had12
      GR.Flyout = fl
      local hasWorn12, hasEmpty
      for _, it in ipairs(picked or {}) do
        if it == "empty" then hasEmpty = true elseif it.id == "301:0:0" then hasWorn12 = true end
      end
      ok(hasWorn12 and hasEmpty, "a ring slot's menu has the ring worn in the other slot and \"take it off\"")
      -- the character window's menus: the other ring too, and picking it swaps it across
      local had11, had12b = inv[11], inv[12]
      inv[11], inv[12] = nil, ring2
      local menuItems = GR.MenuItems(11)
      ok(menuItems[1] and menuItems[1].worn == 12, "a ring slot's menu starts with the ring worn in the other slot")
      GR.EquipItem(11, menuItems[1])
      for _ = 1, 40 do GR.Tick() end
      ok(inv[11] == ring2 and inv[12] == nil, "and picking it moves it across")
      inv[11], inv[12] = had11, had12b
      -- a picture saved blank is filled in from the worn item (seen in game)
      sets.Tank.slots.s16 = { id = GR.Worn(16), name = "x", tex = "" }
      GO.Paint()
      ok(sets.Tank.slots.s16.tex ~= "" and slotOf[16].icon:GetTexture() == sets.Tank.slots.s16.tex,
        "a blank set picture is filled in (" .. tostring(sets.Tank.slots.s16.tex) .. ")")
      -- the character: a size of its own, one point
      -- the character: on the screen itself (a model in the scaled-down window
      -- drew off to the bottom-left in game), over its spot, gone with the page
      ok(GO.model:GetParent() == UIParent and GO.spot and GO.spot:GetWidth() > 100, "the character sits on the screen, over its spot in the editor")
      pfUI.gui:Hide()
      ok(not GO.model:IsShown(), "and goes with the options window")
      pfUI.gui:Show()
      GO.Open("Tank")
      -- the icon picker: the set's items first, then the macro icons, search
      local gnm, gmi = GetNumMacroIcons, GetMacroIconInfo
      _G.GetNumMacroIcons = function() return 30 end
      _G.GetMacroIconInfo = function(i) return i <= 20 and ("Interface\\Icons\\Spell_Fire_" .. i) or ("INV_Sword_" .. i) end
      local picked2
      local pk = GO.IconPicker(slotOf[1], nil, { "Interface\\Icons\\Own" }, function(path) picked2 = path end)
      ok(pk:IsShown() and pk.shown[1] == "Interface\\Icons\\Own" and table.getn(pk.shown) == 31, "the icon picker: the set's items first, then every macro icon")
      ok(pk.shown[31] == "Interface\\Icons\\INV_Sword_30", "a bare icon name gets its folder")
      pk.search:SetText("sword")
      pk:Fill()
      ok(table.getn(pk.shown) == 10, "searching narrows it (" .. table.getn(pk.shown) .. ")")
      _G.this = pk.buttons[1]
      pk.buttons[1]:GetScript("OnClick")()
      ok(picked2 == "Interface\\Icons\\INV_Sword_21" and not pk:IsShown(), "a click picks it and closes")
      _G.GetNumMacroIcons, _G.GetMacroIconInfo = gnm, gmi
      -- New set: what you wear, picked and named
      local before = table.getn(GR.Sets())
      GO.NewSet()
      ok(table.getn(GR.Sets()) == before + 1 and GO.edit and sets[GO.edit], "New set saves what you wear and picks it")
      GR.Delete(GO.edit)
      GO.edit = "Tank"
      pfUI.gui:Hide()
    end
    -- slot buttons (phase 2): the slots picked, laid out, a click uses the item
    if GR.slotbar then
      local wasList, wasBar = pfUI_config.gear.slotlist, pfUI_config.gear.slotbar
      pfUI_config.gear.slotbar, pfUI_config.gear.slotlist = "1", "16,13"
      GR.Changed()
      local sb = GR.slotbar
      ok(sb:IsShown() and sb.buttons[16]:IsShown() and sb.buttons[13]:IsShown() and not sb.buttons[1]:IsShown(),
        "the slot buttons show the slots picked")
      local _, _, _, x13 = sb.buttons[13]:GetPoint(1)
      ok(x13 == 40, "in the order picked, size + spacing apart (" .. tostring(x13) .. ")")
      ok(GR.ToggleSlot(1) and pfUI_config.gear.slotlist == "16,13,1" and sb.buttons[1]:IsShown(), "a slot put on the bar")
      ok(not GR.ToggleSlot(13) and pfUI_config.gear.slotlist == "16,1", "and one taken off")
      local used
      local uii = UseInventoryItem
      _G.UseInventoryItem = function(i) used = i end
      _G.this, _G.arg1 = sb.buttons[16], "LeftButton"
      sb.buttons[16]:GetScript("OnClick")()
      _G.UseInventoryItem = uii
      ok(used == 16, "a click uses the item in that slot")
      -- hidden items: Alt-click in a menu hides it, Alt held shows it again
      -- (a ring is in the bags by now)
      local ringList = GR.ItemsFor(11, true)
      local rings = table.getn(ringList)
      local rid = ringList[1] and ringList[1].id
      GR.SetHidden(rid, true)
      local alt = IsAltKeyDown
      _G.IsAltKeyDown = function() return false end
      local hiddenNow = table.getn(GR.ItemsFor(11, true))
      _G.IsAltKeyDown = function() return true end
      local withAlt = GR.ItemsFor(11, true)
      _G.IsAltKeyDown = alt
      GR.SetHidden(rid, false)
      ok(rings >= 1 and hiddenNow == rings - 1 and table.getn(withAlt) == rings and withAlt[1].hidden,
        "a hidden item is left out of the menus, and shown dimmed with Alt (" .. rings .. "/" .. hiddenNow .. "/" .. table.getn(withAlt) .. ")")
      -- the Slot buttons page: picks lit, the sample bar drawn
      local O2 = pfUI.octoui and pfUI.octoui.Options
      if O2 then
        pfUI.gui:Show()
        local good, err = pcall(function() O2:Select("o:gearslots") end)
        ok(good and O2.pages.gearslots and pfUI.gearOcto.picks and table.getn(pfUI.gearOcto.picks) == 19
          and pfUI.gearOcto.sampleButtons[16]:IsShown(), "the Slot buttons page with its preview: " .. tostring(err))
        pfUI.gui:Hide()
      end
      pfUI_config.gear.slotlist, pfUI_config.gear.slotbar = wasList, wasBar
      GR.Changed()
    end
    -- a cooldown that ends says so
    do
      local b = { inv = 13, cd = CreateFrame("Model"), num = UIParent:CreateFontString(nil, "OVERLAY"),
                  icon = UIParent:CreateTexture(nil, "ARTWORK") }
      local cdOn = true
      local gic = GetInventoryItemCooldown
      _G.GetInventoryItemCooldown = function() if cdOn then return GetTime() - 10, 120, 1 end return 0, 0, 1 end
      local said
      local nt = GR.Notify
      GR.Notify = function(link, what) said = what end
      GR.PaintCooldown(b)
      cdOn = false
      GR.PaintCooldown(b)
      GR.Notify = nt
      _G.GetInventoryItemCooldown = gic
      ok(said == " is ready", "an item's cooldown ending is announced")
    end
    -- the trinket bar and the character window panel follow their switches
    pfUI_config.gear.trinketbar = "0"
    GR.Changed()
    ok(not GR.trinkets:IsShown(), "the trinket bar can be switched off")
    pfUI_config.gear.trinketbar = "1"
    GR.Changed()
    ok(GR.trinkets:IsShown(), "and on")

    for k in pairs(sets) do sets[k] = nil end
    for k, v in pairs(wasSets) do sets[k] = v end
    pfUI_config.gear.current, pfUI_config.gear.before = wasCur, wasBefore
    GR.queue = nil
    for name, fn in pairs(saved) do _G[name] = fn end
  end
end

-- the bar end art: the game's dragons too, in their own shape, one side or both
do
  local GR = pfUI.gryphons
  ok(GR and GR.Art("Dragon2") and GR.Art("Elite") and table.getn(GR.art) >= 6, "end art: gryphon, lion and four dragons")
  if GR then
    local set = pfUI_config.bars.gryphons
    local was = { set.texture, set.size, set.sides }
    set.texture, set.size, set.sides = "Elite", "60", "left"
    local good, err = pcall(GR.UpdateConfig)
    ok(good, "end art draws: " .. tostring(err))
    local l, r = GR.frames.left, GR.frames.right
    ok(math.abs(l:GetWidth() - 60 * (.44 / .85)) < .5 and l:GetHeight() == 60, "a cropped picture keeps its shape (" .. tostring(l:GetWidth()) .. ")")
    ok(not r:IsShown(), "left end only: no right one")
    set.texture, set.size, set.sides = was[1], was[2], was[3]
    GR.UpdateConfig()
    local O = pfUI.octoui and pfUI.octoui.Options
    if O then
      pfUI.gui:Show()
      O:Select("o:abgryphons")
      local AB = pfUI.barsOcto
      ok(AB and AB.gryEnds and AB.PaintGry, "the Gryphons page has a preview of both ends")
      pfUI.gui:Hide()
    end
  end
end

-- every colour setting has a picker (user, 23 Oct 2026: "EVERYTHING that can
-- change colour can and has a clear and simple selector"): each colour in
-- pfUI_config is set to an odd value in turn, and some picker of an Octo page
-- (W.Color, wrapped before the pages were built) or a colour box on one of
-- pfUI's own pages still in the list must show it
do
  local O = pfUI.octoui and pfUI.octoui.Options
  if O and OCTO_COLOR_GETS then
    pfUI.gui:Show()
    for _, sec in ipairs(O.octo) do
      for _, pg in ipairs(sec[2]) do pcall(function() O:Select("o:" .. pg[1]) end) end
    end
    pfUI.gui:Hide()
    -- pfUI's own colour boxes, by the category they are in
    local legacy, cat = {}, nil
    local fh = io.open(DIR .. "/modules/gui.lua", "r")
    for line in fh:lines() do
      local _, _, c = string.find(line, 'CreateGUIEntry%(T%["([^"]+)"%]')
      if c then cat = c end
      local _, _, path, key = string.find(line, 'CreateConfig%([^,]*,[^,]*,%s*C%.([%w_%.]+),%s*"([%w_]+)",%s*"color"')
      if path and cat and not O.replaced[pfUI.env.T[cat]] then legacy[path .. "." .. key] = true end
    end
    fh:close()
    local function Shows(r0, g0)
      for _, c in ipairs(OCTO_COLOR_GETS) do
        local good, r, g = pcall(c.get)
        if good and math.abs((tonumber(r) or 0) - r0) < .003 and math.abs((tonumber(g) or 0) - g0) < .003 then return true end
      end
    end
    -- (a colour: three or four numbers, each 0 to 1 - "16,17,18" is a slot list)
    local function IsColor(v)
      if type(v) ~= "string" or not string.find(v, "^%s*[%d%.]+%s*,%s*[%d%.]+%s*,%s*[%d%.]+") then return false end
      for n in string.gfind(v, "[%d%.]+") do if (tonumber(n) or 2) > 1 then return false end end
      return true
    end
    local SKIP = { position = 1, disabled = 1, blizz = 1 }
    local list = {}
    for g, gt in pairs(pfUI_config) do
      if type(gt) == "table" and not SKIP[g] then
        for s, st in pairs(gt) do
          if IsColor(st) then table.insert(list, { gt, s, g .. "." .. s })
          elseif type(st) == "table" then
            for k, v in pairs(st) do if IsColor(v) then table.insert(list, { st, k, g .. "." .. s .. "." .. k, g, k }) end end
          end
        end
      end
    end
    -- one picker for what is picked on the page: the text (unit frames), the art layer (minimap)
    local PICKED = {
      { "^unitframes%..-%.o_tcc_(.+)$", function(x) if pfUI.ufOcto then pfUI.ufOcto.text = x end end },
      { "^mapstyle%.art(%d)color$", function(x) if pfUI.minimapOcto then pfUI.minimapOcto.layer = tonumber(x) end end },
    }
    -- copied once into each meter window (meters-window.lua, C.meters.migrated)
    local OLD = { ["meters.background"] = true }
    local missing = {}
    for _, e in ipairs(list) do
      local t, k, path = e[1], e[2], e[3]
      local found = legacy[path] or OLD[path]
      if not found then
        local was = t[k]
        t[k] = ".123,.456,.789,.5"
        for _, pk in ipairs(PICKED) do
          local _, _, x = string.find(path, pk[1])
          if x then pk[2](x) end
        end
        found = Shows(.123, .456)
        -- a tabbed page (one unit / window at a time): the same key on every tab
        if not found and e[4] then
          local olds = {}
          for s, st in pairs(pfUI_config[e[4]]) do
            if type(st) == "table" and IsColor(st[e[5]]) then olds[s] = st[e[5]] st[e[5]] = ".123,.456,.789,.5" end
          end
          found = Shows(.123, .456)
          for s, v in pairs(olds) do pfUI_config[e[4]][s][e[5]] = v end
        end
        t[k] = was
      end
      if not found then table.insert(missing, path) end
    end
    table.sort(missing)
    ok(table.getn(missing) == 0, "every colour has a picker; none for: " .. table.concat(missing, ", "))
  end
end

-- SuperWoW / ClassicAPI use across the modules (libs\libclient.lua)
octo_ok, octo_dir = ok, DIR
dofile(DIR .. "/tests/clientapi.lua")

local started, broken = 0, 0
for _, m in ipairs(pfUI.modules) do
  if failedModules[m] then broken = broken + 1 else started = started + 1 end
end
for _, m in ipairs(MUST_LOAD) do
  ok(not failedModules[m], "module " .. m .. " starts: " .. tostring(failedModules[m]))
end

if os and os.getenv and os.getenv("PFUI_TEST_VERBOSE") then
  for m, e in pairs(failedModules) do print("  module " .. m .. ": " .. tostring(e)) end
end
print(string.format("modules started in the mock: %d, need more of the client: %d", started, broken))
print(string.format("%d checks, %d failed", checks, fails))
if fails > 0 then os.exit(1) end

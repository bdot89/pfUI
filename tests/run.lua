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
-- the client's level colour (unit frames with level colours)
function GetDifficultyColor() return { r = 1, g = .82, b = 0 } end
-- the client's debuff type colours (unit frame debuff borders)
DebuffTypeColor = { none = { r = .8, g = 0, b = 0 }, Magic = { r = .2, g = .6, b = 1 }, Curse = { r = .6, g = 0, b = 1 },
  Disease = { r = .6, g = .4, b = 0 }, Poison = { r = 0, g = .6, b = 0 } }
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
  "nameplates", "plates", "plates-options" }

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
  ok(pfUI.gui:IsShown() and O and O.current and string.find(O.current, "Player"), "right-click opens the frame's options (" .. tostring(O and O.current) .. ")")
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

  -- rows, windows, details
  local rows = ME.Rows("damage", "current")
  ok(rows[1] and rows[1].name == "Tester" and rows[1].text == "790", "damage rows")
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
    ok(pfMeterDetails:IsShown(), "click opens the breakdown")
    local found
    for _, l in ipairs(pfMeterDetails.lines) do
      if l:IsShown() and l.cells[1].text == "Fireball" then found = true end
    end
    ok(found, "breakdown lists Fireball")
    pfMeterDetails:Hide()
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
    ok(pfUI_config.meters.lock1 == "1" and not w1.grip:IsShown() and pfMeterMenu:IsShown(), "lock hides the grip, menu stays open")
    find("Lock position"):Click()
    -- bar height cycles
    local before = pfUI_config.meters.barheight
    find("Bar height"):Click()
    ok(pfUI_config.meters.barheight ~= before, "bar height changes (" .. before .. " -> " .. pfUI_config.meters.barheight .. ")")
    pfUI_config.meters.barheight = before
    -- rank numbers off
    find("Rank numbers"):Click()
    w1.Refresh(w1)
    ok(pfUI_config.meters.showrank == "0" and w1.bars[1].left.text == "Tester", "rank numbers off (" .. tostring(w1.bars[1].left.text) .. ")")
    find("Rank numbers"):Click()
    pfMeterMenu:Hide()

    -- resize with the grip: the new size is kept
    w1.GetWidth = function() return 333 end
    w1.GetHeight = function() return 222 end
    Mock.Run(w1.grip, "OnMouseDown")
    Mock.Run(w1.grip, "OnMouseUp")
    ok(pfUI_config.meters.width1 == "333" and pfUI_config.meters.height1 == "222", "resized window keeps its size")
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
    local ct = O.octo[1]
    ok(ct and ct[1] == "Combat Text" and table.getn(ct[2]) == 6, "Combat Text section with its six pages")
    ok(O.first == "o:ctgeneral", "the window first opens on combat text's Basics: " .. tostring(O.first))
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
    if O.legacy["l:Unit Frames/Player"] then lkey = "l:Unit Frames/Player" end
    ok(lkey ~= nil, "pfUI's Unit Frames pages are in the topic list")
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
    ok(O:FindLegacy("Group Frames", "Raid") == "l:Unit Frames/Raid", "page found outside its old category: " .. tostring(O:FindLegacy("Group Frames", "Raid")))
    ok(O:FindLegacy("unit frames", "player") == "l:Unit Frames/Player", "names match in any case")
    ok(O:FindLegacy("Castbar") == "l:Castbar", "a category without pages")
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
    ok(O.current and string.find(O.current, "^l:" .. "Meters"), "Open(Meters) opens a Meters page: " .. tostring(O.current))
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
    ok(sec and table.getn(sec[2]) == 7, "Nameplates section with its seven pages")
    -- the topic list: most used first, small categories grouped
    local heads = {}
    for _, grp in ipairs(O.groups) do table.insert(heads, grp.header.text.text) end
    ok(heads[1] == "Settings" and heads[2] == "Unit Frames" and heads[4] == "Nameplates" and heads[table.getn(heads)] == "About",
      "topic list in order of importance (" .. table.concat(heads, ", ") .. ")")
    local castTopic
    for _, grp in ipairs(O.groups) do
      if grp.header.text.text == "Unit Frames" then
        for _, b in ipairs(grp.buttons) do if b.key == "l:Castbar" then castTopic = true end end
      end
    end
    ok(castTopic, "Castbar is a topic under Unit Frames")
    -- the corner grip scales the window, within limits, and remembers it
    ok(O.grip ~= nil, "the window has a resize grip")
    O:ApplyScale(3)
    ok(pfUI_cache.octoui.winscale == 1.6, "window size stops at 160%")
    O:ApplyScale(1)
    ok(pfUI_cache.octoui.winscale == 1, "back to normal size")
    -- the spacing slider rebuilds the pages
    pfUI_cache.octoui.space = 8
    O:Select("o:nplook")
    O:RebuildPages()
    ok(O.pages.nplook and O.pages.nplook.frame:IsShown(), "pages rebuilt at a new spacing")
    pfUI_cache.octoui.space = nil
    O:RebuildPages()
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
    pfUI.gui:Hide()
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

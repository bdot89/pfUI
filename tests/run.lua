-- Offline run of pfUI Octo through the mock client: pfUI.lua, env, compat,
-- api and libs load, the saved config is built, and every module and skin is
-- started one by one; a module that errors is reported (most need far more
-- of the client than the mock has, so only those in MUST_LOAD fail the run).
--   powershell -ExecutionPolicy Bypass -File tests\run.ps1

local DIR = "."
dofile(DIR .. "/tests/mock.lua")

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
function UnitName(u) if u == "player" then return "Tester" end end
function GetRealmName() return "OctoWoW" end
function GetCVar(n) return Mock.cvars and Mock.cvars[n] or "0" end
Mock.cvars = { gxResolution = "1920x1080", uiScale = "1", useUiScale = "1" }
function setglobal(k, v) _G[k] = v end
function GetScreenWidth() return 1920 end
function GetScreenHeight() return 1080 end
function GetNumAddOns() return 1 end
function debugstack() return "" end
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
local MUST_LOAD = { "unlock", "gui", "firstrun", "share" }

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

-- start modules one by one so one failure does not hide the rest
local failedModules = {}
local LoadModule, LoadSkin = pfUI.LoadModule, pfUI.LoadSkin
function pfUI:LoadModule(m)
  local good, e = pcall(LoadModule, self, m)
  if not good then failedModules[m] = e end
end
function pfUI:LoadSkin(s)
  local good, e = pcall(LoadSkin, self, s)
  if not good then failedModules["skin_" .. s] = e end
end

Mock.Fire("ADDON_LOADED", "pfUI")
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
  local dx, dy, xline, yline = U.GetSnap(a)
  ok(dx == -3 and xline == 400, "snaps A's left onto B's right edge (dx " .. tostring(dx) .. ")")
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
  -- when the client reports positions only on the next screen update; the
  -- saved position must still include the snap (3 px left onto B's edge)
  a = Box("pfTestA", 403, 300, 100, 40)
  b = Box("pfTestB", 200, 500, 200, 40)
  a:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 403, -740)
  pfUI.movables = { pfTestOne = pfTestOne, pfTestTwo = pfTestTwo }
  U:Hide()
  pfUI.movables = { pfTestA = a, pfTestB = b }
  U:Show()
  ok(a.drag, "drag box for the test frame")
  if a.drag then
    pfUI_config.position.pfTestA = nil
    Mock.Run(a.drag, "OnDragStart")
    Mock.Run(a.drag, "OnDragStop")
    local pos = pfUI_config.position.pfTestA
    ok(pos and pos.xpos, "drop saved a position")
    if pos and pos.xpos then
      local _, x = pfUI.api.ConvertFrameAnchor(a, pos.anchor)
      ok(pos.xpos == pfUI.api.round(x - 3), "saved position includes the snap (" .. tostring(pos.xpos) .. " vs " .. tostring(pfUI.api.round(x - 3)) .. ")")
    end
  end
  U:Hide()
  U.selection = {}
  pfUI.movables = { pfTestOne = pfTestOne, pfTestTwo = pfTestTwo }
  U:Show()

  ok(pfTestOne.drag and pfTestOne.drag:IsShown(), "movers get a drag box")
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
                global = { font_size = "13", note = 'a "quoted" \\ path' }, numbers = { a = 1.5, b = -2 } }
  local text = S.serialize(src, nil, "pfUI_config", {})
  local back, err = S.parse(text)
  ok(back, "parses its own export: " .. tostring(err))
  if back then
    ok(back.appearance.border.default == "1" and back.unitframes.player.width == "250", "round trip keeps values")
    ok(back.numbers.a == 1.5 and back.numbers.b == -2, "round trip keeps numbers")
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

-- ---------------------------------------------------------------- options pages
-- build every page of the options window (pages build on first show)
local pages, pageErrors = 0, {}
local function BuildPage(path, area)
  local content = area and area.scroll and area.scroll.content
  if not content then return end
  pages = pages + 1
  local good, e = pcall(Mock.Run, content, "OnShow")
  if not good then pageErrors[path] = e end
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

pfUI:RegisterModule("sct", "vanilla", function ()
  -- pfUI Octo combat text: start-up and the "Combat Text" options pages.
  -- The engine is sct-engine.lua / sct-events.lua (moved from OctoBG) on the
  -- stand-in core sct-core.lua. Settings: pfUI_config.sct, real Lua values
  -- (booleans, numbers) as the engine expects; on first run copied from
  -- OctoBG's (OctoBGDB.sct) when there are any, then OctoBG hands its combat
  -- text over to this one (OctoBG checks pfUI.sct:On()).
  local B = pfUI.sctB
  local CT = B and B.SCT
  if not CT then return end

  -- ---------------------------------------------------------------- settings

  local function Copy(src)
    if type(src) ~= "table" then return src end
    local t = {}
    for k, v in pairs(src) do t[k] = Copy(v) end
    return t
  end

  local function Fill(dst, src)
    for k, v in pairs(src) do
      if type(v) == "table" then
        if type(dst[k]) ~= "table" then dst[k] = {} end
        Fill(dst[k], v)
      elseif dst[k] == nil then
        dst[k] = v
      end
    end
  end

  if type(pfUI_config.sct) ~= "table" then pfUI_config.sct = {} end
  Fill(pfUI_config.sct, B.DEFAULTS.sct)
  B.db = { sct = pfUI_config.sct, pos = {}, locked = true }

  -- OctoBG's combat text settings, copied once. OctoBG may load after pfUI
  -- (seen in game 19 Oct: its saved settings were not there yet at pfUI's
  -- load), so this runs at login, when every addon is loaded. The settings
  -- table stays the same table (B.db.sct). pfUI's on / off is kept.
  local function ImportOctoBG()
    local s = pfUI_config.sct
    if s.fromOctoBG or s.octoChecked then return end
    s.octoChecked = true
    if type(OctoBGDB) ~= "table" or type(OctoBGDB.sct) ~= "table" then return end
    local on = s.enabled
    for k in pairs(s) do s[k] = nil end
    for k, v in pairs(Copy(OctoBGDB.sct)) do s[k] = v end
    Fill(s, B.DEFAULTS.sct)
    s.enabled = on
    s.fromOctoBG, s.octoChecked = true, true
    if CT.panels then for key in pairs(CT.panels) do CT:PlaceArea(key) end end
  end

  pfUI.sct = { B = B, CT = CT }
  function pfUI.sct:On() return B.db and B.db.sct.enabled and not (C.disabled and C.disabled["sct"] == "1") end

  -- each step on its own: an error says so in chat and the rest (above all
  -- the options pages) still happens
  local function Try(what, fn)
    local ok, err = pcall(fn)
    if not ok then B:Print("|cffff5555error|r (" .. what .. "): " .. tostring(err)) end
  end
  pfUI.sct.Try = Try
  pfUI.sct.ImportOctoBG = ImportOctoBG

  Try("start-up", function()
  B:Fire("OBG_LOADED")

  local f = CreateFrame("Frame")
  f:RegisterEvent("PLAYER_LOGIN")
  f:RegisterEvent("ZONE_CHANGED_NEW_AREA")
  f:SetScript("OnEvent", function()
    if event == "PLAYER_LOGIN" then
      Try("import from OctoBG", ImportOctoBG)
      B:Fire("OBG_INIT")
      if pfUI_config.sct.fromOctoBG and not pfUI_config.sct.toldMoved then
        pfUI_config.sct.toldMoved = true
        B:Print("your OctoBG combat text settings were copied here - OctoBG now hands its combat text to pfUI. Options: /pfui, Combat Text.")
      end
    else
      B:Fire("OBG_ZONE")
    end
  end)

  -- sample texts in every area while pfUI's layout mode (/moveui) is open
  if pfUI.unlock then
    local show, hide = pfUI.unlock:GetScript("OnShow"), pfUI.unlock:GetScript("OnHide")
    pfUI.unlock:SetScript("OnShow", function() if show then show() end B.test = true end)
    pfUI.unlock:SetScript("OnHide", function() if hide then hide() end B.test = nil end)
  end

  -- SCT's /sctdisplay 'message' [red green blue 0-10] (when SCT itself is not loaded)
  local function Display(msg)
    local _, _, text, r, g, b = string.find(msg or "", "^%s*'(.-)'%s*(%d*)%s*(%d*)%s*(%d*)")
    if not text then text = msg end
    r, g, b = tonumber(r), tonumber(g), tonumber(b)
    CT:Show(text, r and r / 10 or 1, g and g / 10 or 1, b and b / 10 or 1, "note", {})
  end
  if not (IsAddOnLoaded("sct") or IsAddOnLoaded("SCT")) then
    _G.SLASH_PFUISCTDISPLAY1 = "/sctdisplay"
    _G.SlashCmdList.PFUISCTDISPLAY = Display
  end

  -- /pfui sct test | on | off
  local slash = SlashCmdList.PFUI
  SlashCmdList.PFUI = function(msg, box)
    local _, _, sub = string.find(string.lower(msg or ""), "^sct%s*(%a*)")
    if sub then
      if sub == "test" then CT:TestMode(not CT:Testing())
      elseif sub == "on" then CT:SetEnabled(true)
      elseif sub == "off" then CT:SetEnabled(false)
      elseif sub == "status" then pfUI.sct.Status()
      else B:Print("/pfui sct test | on | off | status") end
      return
    end
    slash(msg, box)
  end
  end)

  -- /pfui sct status: what is running (for reports)
  function pfUI.sct.Status()
    local n = 0
    for _ in pairs(B.errors) do n = n + 1 end
    B:Print("on: " .. tostring(pfUI.sct:On()) .. ", areas: " .. tostring(CT.panels and CT.panels.inc ~= nil)
      .. ", options: " .. tostring(pfUI.gui and pfUI.gui.frames and pfUI.gui.frames[T["Combat Text"]] ~= nil)
      .. ", errors: " .. n)
    for err in pairs(B.errors) do B:Print("  " .. err) end
  end

  -- ---------------------------------------------------------------- options

  local function BuildOptions()
  if not pfUI.gui or not pfUI.gui.CreateGUIEntry then return end
  local CreateGUIEntry, CreateConfig, Native = pfUI.gui.CreateGUIEntry, pfUI.gui.CreateConfig, pfUI.gui.Native
  local NOOP = function() end   -- changes apply at once: no reload question

  -- { { key, label } } -> pfUI dropdown values "key:label"
  local function Values(list, extra)
    local out = {}
    if extra then for _, e in ipairs(extra) do table.insert(out, e) end end
    for _, e in ipairs(list) do
      if e.key and not e.group then table.insert(out, e.key .. ":" .. e.label) end
    end
    return out
  end

  local function Wheres(withPlate, withHide)
    local out = {}
    for _, k in ipairs(CT.AREA_ORDER) do table.insert(out, k .. ":" .. CT.AREA_LABEL[k]) end
    if withPlate then table.insert(out, "plate:" .. T["Nameplate"]) end
    if withHide then table.insert(out, "hide:" .. T["Nowhere (hide)"]) end
    return out
  end

  local FONTS = { ":" .. T["Same as all"] }
  for _, v in ipairs(pfUI.gui.dropdowns.fonts or {}) do table.insert(FONTS, v) end
  local FONTS_ALL = pfUI.gui.dropdowns.fonts or {}
  local SOUNDS = Values(CT.SOUNDS)
  local OUTLINES = Values(CT.OUTLINES)
  local CRIT_OUTLINES = { "same:" .. T["Same as the text"], ":" .. T["None"], "OUTLINE:" .. T["Outline"], "THICKOUTLINE:" .. T["Thick outline"] }

  local DB = Native(function() return B.db.sct end)
  local PL = Native(function() return B.db.sct.plates end)
  local TM = Native(function() return B.db.sct.team end, function() if CT.EV and CT.EV.Roster then CT.EV:Roster() end end)
  local CL = Native(function() return B.db.sct.critLook end, function() CT:Show("2468", 1, 1, 1, "out", { crit = true }) end)

  -- the master switch also swaps the game's own numbers (CT:SetEnabled)
  local MASTER = setmetatable({}, {
    __index = function() return B.db.sct.enabled and "1" or "0" end,
    __newindex = function(_, k, v) CT:SetEnabled(v == "1") end,
  })
  -- the game's own floating numbers, one by one
  local GAME = setmetatable({}, {
    __index = function(_, k) return CT:GameNumbersOn(k) and "1" or "0" end,
    __newindex = function(_, k, v) CT:GameNumbers(k, v == "1") end,
  })

  local function AllOut(where)
    for _, k in ipairs({ "outMelee", "outSpell", "outDot", "outPet", "outShield", "outMiss" }) do
      B.db.sct.events[k].area = where
    end
  end

  CreateGUIEntry(T["Combat Text"], T["General"], function()
    CreateConfig(nil, T["Combat Text"], nil, nil, "header")
    CreateConfig(NOOP, T["Enable Combat Text (scrolling numbers, nameplate damage, alerts)"], MASTER, "enabled", "checkbox")
    CreateConfig(nil, T["Test Combat Text (one minute)"], nil, nil, "button", function() CT:TestMode(not CT:Testing()) end)
    CreateConfig(nil, T["Your Damage On Nameplates"], nil, nil, "button", function() AllOut("plate") end)
    CreateConfig(nil, T["Your Damage On Screen"], nil, nil, "button", function() AllOut("out") end)

    CreateConfig(nil, T["Look"], nil, nil, "header")
    CreateConfig(NOOP, T["Shadow Behind The Letters"], DB, "shadow", "checkbox")
    CreateConfig(NOOP, T["Spell Icons"], DB, "icons", "checkbox")
    CreateConfig(NOOP, T["Style"], DB, "style", "dropdown", Values(CT.STYLES))
    CreateConfig(NOOP, T["Font"], DB, "font", "dropdown", FONTS_ALL)
    CreateConfig(NOOP, T["Outline"], DB, "outline", "dropdown", OUTLINES)
    CreateConfig(NOOP, T["Speed (below 1: longer on screen)"], DB, "speed", "slider", { .5, 2, .05 })
    CreateConfig(NOOP, T["Icon Size"], DB, "iconScale", "slider", { .5, 2, .1 })

    CreateConfig(nil, T["Warnings"], nil, nil, "header")
    CreateConfig(NOOP, T["Low Health Under %"], DB, "lowHp", "slider", { 5, 90, 5 })
    CreateConfig(NOOP, T["Low Mana Under %"], DB, "lowMana", "slider", { 5, 90, 5 })

    CreateConfig(nil, T["The Game's Own Numbers"], nil, nil, "header")
    CreateConfig(NOOP, T["Game Damage Numbers"], GAME, "dmg", "checkbox")
    CreateConfig(NOOP, T["Game Pet Damage Numbers"], GAME, "pet", "checkbox")
    CreateConfig(NOOP, T["Game Healing Numbers (SuperWoW)"], GAME, "heal", "checkbox")
    CreateConfig(NOOP, T["Game Scrolling Text Over You"], GAME, "fct", "checkbox")
  end)

  CreateGUIEntry(T["Combat Text"], T["Scroll Areas"], function()
    for _, key in ipairs(CT.AREA_ORDER) do
      local area = key
      local A = Native(function() return B.db.sct.areas[area] end, function() CT:PlaceArea(area) end)
      CreateConfig(nil, CT.AREA_LABEL[area], nil, nil, "header")
      CreateConfig(NOOP, T["Area On"], A, "enabled", "checkbox")
      CreateConfig(NOOP, T["Movement"], A, "anim", "dropdown", Values(CT.MOVES))
      CreateConfig(NOOP, T["Crits"], A, "crit", "dropdown", Values(CT.CRITS))
      CreateConfig(NOOP, T["Direction"], A, "dir", "dropdown", Values(CT.DIRS))
      CreateConfig(NOOP, T["Side"], A, "side", "dropdown", Values(CT.SIDES))
      CreateConfig(NOOP, T["Text Alignment"], A, "align", "dropdown", Values(CT.ALIGNS))
      CreateConfig(NOOP, T["Spell Icon"], A, "icon", "dropdown", Values(CT.ICONS))
      CreateConfig(NOOP, T["Font"], A, "font", "dropdown", FONTS)
      CreateConfig(NOOP, T["Outline"], A, "outline", "dropdown", { ":" .. T["Same as all"], "OUTLINE:" .. T["Outline"], "THICKOUTLINE:" .. T["Thick outline"] })
      CreateConfig(NOOP, T["Text Size"], A, "size", "slider", { 8, 48, 1 })
      CreateConfig(NOOP, T["Crit Size"], A, "critScale", "slider", { 1, 3, .05 })
      CreateConfig(NOOP, T["Opacity"], A, "alpha", "slider", { .1, 1, .05 })
      CreateConfig(NOOP, T["Time On Screen (s)"], A, "time", "slider", { .5, 8, .1 })
      CreateConfig(NOOP, T["Travel Height"], A, "height", "slider", { 40, 600, 10 })
      CreateConfig(NOOP, T["Travel Width"], A, "width", "slider", { 20, 600, 10 })
      CreateConfig(NOOP, T["X (from the screen middle)"], A, "x", "slider", { -900, 900, 5 })
      CreateConfig(NOOP, T["Y (from the screen middle)"], A, "y", "slider", { -600, 600, 5 })
    end
  end)

  CreateGUIEntry(T["Combat Text"], T["Nameplates"], function()
    CreateConfig(nil, T["Nameplates"], nil, nil, "header")
    CreateConfig(NOOP, T["Text On Other Enemies Too"], PL, "offTarget", "checkbox")
    CreateConfig(NOOP, T["Show Enemy Plates When I Log In"], PL, "autoShow", "checkbox")
    CreateConfig(NOOP, T["Stack Lines (never on top of each other)"], PL, "stack", "checkbox")
    CreateConfig(NOOP, T["Add Up The Same Attack"], PL, "merge", "checkbox")
    CreateConfig(NOOP, T["Keep Text On Screen"], PL, "clamp", "checkbox")
    CreateConfig(NOOP, T["No Plate Showing: Use"], PL, "fallback", "dropdown", Wheres(false, true))
    CreateConfig(NOOP, T["Hits Move"], PL, "hit", "dropdown", Values(CT.MOVES))
    CreateConfig(NOOP, T["Misses Move"], PL, "miss", "dropdown", Values(CT.MOVES))
    CreateConfig(NOOP, T["Heals Move"], PL, "heal", "dropdown", Values(CT.MOVES))
    CreateConfig(NOOP, T["Crits Move (Flash, Normal)"], PL, "critMove", "dropdown", Values(CT.MOVES))
    CreateConfig(NOOP, T["Time On Screen (s)"], PL, "time", "slider", { .5, 5, .1 })
    CreateConfig(NOOP, T["Travel Height"], PL, "height", "slider", { 20, 300, 5 })
    CreateConfig(NOOP, T["Travel Width"], PL, "width", "slider", { 20, 300, 5 })
    CreateConfig(NOOP, T["Random Spread"], PL, "xVariance", "slider", { 0, 60, 1 })
    CreateConfig(NOOP, T["Text Size"], PL, "size", "slider", { 8, 40, 1 })
    CreateConfig(NOOP, T["Height Above The Plate"], PL, "yOffset", "slider", { -40, 120, 1 })
    CreateConfig(NOOP, T["Your Target Bigger By"], PL, "targetScale", "slider", { 1, 2, .05 })
    CreateConfig(NOOP, T["Other Enemies' Size"], PL, "offScale", "slider", { .4, 1, .05 })
    CreateConfig(NOOP, T["Other Enemies' Opacity"], PL, "offAlpha", "slider", { .1, 1, .05 })
    CreateConfig(NOOP, T["Most Texts Per Plate"], PL, "max", "slider", { 1, 20, 1 })

    CreateConfig(nil, T["Teammates' Damage"], nil, nil, "header")
    CreateConfig(NOOP, T["Show Teammates' Damage On Plates"], TM, "on", "checkbox")
    CreateConfig(NOOP, T["Their Pets Too"], TM, "pets", "checkbox")
    CreateConfig(NOOP, T["Only On My Target"], TM, "onlyTarget", "checkbox")
    CreateConfig(NOOP, T["Their Misses"], TM, "misses", "checkbox")
    CreateConfig(NOOP, T["Their Damage Over Time"], TM, "dots", "checkbox")
    CreateConfig(NOOP, T["Class Colours"], TM, "classColor", "checkbox")
    CreateConfig(NOOP, T["Name Of Who Hit"], TM, "sourceName", "checkbox")
    CreateConfig(NOOP, T["Colour (class colours off)"], TM, "rgb", "color")
    CreateConfig(NOOP, T["Whose Damage"], TM, "who", "dropdown", { "party:" .. T["My party (and its pets)"], "raid:" .. T["My whole raid"] })
    CreateConfig(NOOP, T["Also These Players (comma separated)"], TM, "names", "text", nil, nil, nil, "string")
    CreateConfig(NOOP, T["Size"], TM, "scale", "slider", { .4, 1.2, .05 })
    CreateConfig(NOOP, T["Opacity"], TM, "alpha", "slider", { .2, 1, .05 })
    CreateConfig(NOOP, T["Beside Yours By"], TM, "x", "slider", { -120, 120, 2 })
  end)

  CreateGUIEntry(T["Combat Text"], T["Crits & Sounds"], function()
    CreateConfig(nil, T["Crit Look"], nil, nil, "header")
    CreateConfig(NOOP, T["Crits In Their Own Colour"], CL, "tint", "checkbox")
    CreateConfig(NOOP, T["Crit Colour"], CL, "rgb", "color")
    CreateConfig(NOOP, T["Flash Behind Crits"], CL, "glow", "checkbox")
    CreateConfig(NOOP, T["Only The Number"], CL, "numberOnly", "checkbox")
    CreateConfig(NOOP, T["Crit Font"], CL, "font", "dropdown", FONTS)
    CreateConfig(NOOP, T["Crit Outline"], CL, "outline", "dropdown", CRIT_OUTLINES)
    CreateConfig(NOOP, T["Mark Crits"], CL, "mark", "dropdown", Values(CT.MARKS))
    CreateConfig(NOOP, T["Flash Size"], CL, "glowSize", "slider", { .5, 2, .1 })
    CreateConfig(NOOP, T["Crits Stay Longer"], CL, "hold", "slider", { 1, 2.5, .05 })

    CreateConfig(nil, T["Nameplate Crits"], nil, nil, "header")
    CreateConfig(NOOP, T["How They Appear"], PL, "crit", "dropdown", Values(CT.CRITS))
    CreateConfig(NOOP, T["Crit Size"], PL, "critScale", "slider", { 1, 3, .05 })

    CreateConfig(nil, T["Big Messages"], nil, nil, "header")
    CreateConfig(NOOP, T["Flash Behind Big Ones"], DB, "bigGlow", "checkbox")
    CreateConfig(NOOP, T["Big Size"], DB, "bigScale", "slider", { 1, 2.5, .05 })

    CreateConfig(nil, T["Sounds"], nil, nil, "header")
    CreateConfig(NOOP, T["Killing Blow"], DB, "killSound", "dropdown", SOUNDS)
    CreateConfig(NOOP, T["Crit Sound"], DB, "critSoundKey", "dropdown", SOUNDS)
    CreateConfig(NOOP, T["...For Crits From (0 = off)"], DB, "critSound", "slider", { 0, 10000, 100 })
    CreateConfig(NOOP, T["Huge Crit Sound"], DB, "hugeCritKey", "dropdown", SOUNDS)
    CreateConfig(NOOP, T["...For Huge Crits From (0 = off)"], DB, "hugeCrit", "slider", { 0, 20000, 100 })

    CreateConfig(nil, T["Your Own Sounds (files in pfUI\\img\\sct\\sounds\\custom)"], nil, nil, "header")
    local MY = Native(function() return B.db.sct.mySounds end)
    for n = 1, 4 do CreateConfig(NOOP, T["Your Sound"] .. " " .. n, MY, n, "text", nil, nil, nil, "string") end
  end)

  -- every message type: on, colour, always crit, big, where, sound
  local function Messages(groups)
    return function()
      for _, g in ipairs(CT.GROUPS) do
        -- OctoBG's alerts only matter while OctoBG is installed and sends them
        if groups[g[1]] and (g[1] ~= "obg" or IsAddOnLoaded("OctoBG")) then
          CreateConfig(nil, g[2], nil, nil, "header")
          for _, e in ipairs(CT.EVENTS) do
            if e.group == g[1] then
              local key = e.key
              local S = Native(function() return B.db.sct.events[key] end)
              CreateConfig(NOOP, e.label, S, "on", "checkbox")
              CreateConfig(NOOP, T["Colour"], S, "rgb", "color")
              CreateConfig(NOOP, T["Always Crit"], S, "crit", "checkbox")
              CreateConfig(NOOP, T["Big, With A Flash"], S, "big", "checkbox")
              CreateConfig(NOOP, T["Where"], S, "area", "dropdown", Wheres(true, false))
              CreateConfig(NOOP, T["Sound"], S, "sound", "dropdown", SOUNDS)
              CreateConfig(nil) -- next message: a new block
            end
          end
        end
      end
    end
  end
  CreateGUIEntry(T["Combat Text"], T["Messages: Combat"], Messages({ ["in"] = true, heal = true, out = true, outheal = true }))
  CreateGUIEntry(T["Combat Text"], T["Messages: Alerts"], Messages({ warn = true, reward = true, obg = true }))

  CreateGUIEntry(T["Combat Text"], T["Text & Filters"], function()
    CreateConfig(nil, T["What The Texts Say"], nil, nil, "header")
    CreateConfig(NOOP, T["Spell Names"], DB, "spellNames", "checkbox")
    CreateConfig(NOOP, T["Damage School <Fire>"], DB, "schoolNames", "checkbox")
    CreateConfig(NOOP, T["Colour Spells By School"], DB, "schoolColors", "checkbox")
    CreateConfig(NOOP, T["Who Hit You / You Hit"], DB, "names", "checkbox")
    CreateConfig(NOOP, T["Healer Names"], DB, "healerNames", "checkbox")
    CreateConfig(NOOP, T["Resisted, Blocked, Absorbed"], DB, "showResist", "checkbox")
    CreateConfig(NOOP, T["Glancing ~ And Crushing ^"], DB, "showGlance", "checkbox")
    CreateConfig(NOOP, T["Overheal (estimated)"], DB, "overheal", "checkbox")
    CreateConfig(NOOP, T["Your Heals On Yourself"], DB, "selfHeals", "checkbox")
    CreateConfig(NOOP, T["Short Numbers (12.3k)"], DB, "abbreviate", "checkbox")
    CreateConfig(NOOP, T["Thousands Separators"], DB, "commas", "checkbox")
    CreateConfig(NOOP, T["Long Spell Names"], DB, "truncate", "dropdown", { "off:" .. T["In full"], "cut:" .. T["Cut after N letters"], "initials:" .. T["Initials (SB)"] })
    CreateConfig(NOOP, T["Letters Kept"], DB, "truncateLen", "slider", { 6, 30, 1 })

    CreateConfig(nil, T["Less Clutter"], nil, nil, "header")
    CreateConfig(NOOP, T["Only Damage On My Target"], DB, "targetOnly", "checkbox")
    CreateConfig(NOOP, T["Merge Hits"], DB, "merge", "checkbox")
    CreateConfig(NOOP, T["Hide Small Hits (instead of shrinking)"], DB, "smallHide", "checkbox")
    CreateConfig(NOOP, T["Regeneration Ticks"], DB, "regen", "checkbox")
    CreateConfig(NOOP, T["Power Gains When Full"], DB, "fullPower", "checkbox")
    CreateConfig(NOOP, T["Merge Window (s)"], DB, "mergeTime", "slider", { .1, 1.5, .1 })
    CreateConfig(NOOP, T["Power Gains Every (s, 0 = each)"], DB, "throttlePower", "slider", { 0, 10, .5 })
    CreateConfig(NOOP, T["Smallest Damage Shown"], DB, "minDamage", "slider", { 0, 2000, 10 })
    CreateConfig(NOOP, T["Smallest Heal Shown"], DB, "minHeal", "slider", { 0, 2000, 10 })
    CreateConfig(NOOP, T["Smallest Power Gain"], DB, "minPower", "slider", { 0, 200, 1 })
    CreateConfig(NOOP, T["Small Hits Below"], DB, "smallBelow", "slider", { 0, 2000, 10 })
    CreateConfig(NOOP, T["Small Hit Size"], DB, "smallScale", "slider", { .4, 1, .05 })

    CreateConfig(nil, T["Buffs, Procs And Cooldowns"], nil, nil, "header")
    CreateConfig(NOOP, T["Proc Buffs (comma separated)"], DB, "procs", "text", nil, nil, nil, "string")
    CreateConfig(NOOP, T["Hidden Auras"], DB, "hideAuras", "text", nil, nil, nil, "string")
    CreateConfig(NOOP, T["Never Say Ready"], DB, "cdExclude", "text", nil, nil, nil, "string")
    CreateConfig(NOOP, T["Ready: Cooldowns From (s)"], DB, "cdReadyMin", "slider", { 2, 120, 1 })

    CreateConfig(nil, T["Formats (%a amount, %s spell, %n name, %t school)"], nil, nil, "header")
    for _, e in ipairs(CT.EVENTS) do
      local key = e.key
      CreateConfig(NOOP, e.label, Native(function() return B.db.sct.events[key] end), "fmt", "text", nil, nil, nil, "string")
    end
  end)
  end

  Try("options", BuildOptions)
end)

pfUI:RegisterModule("plates-options", "vanilla:tbc", function ()
  -- pfUI Octo :: the Nameplates section in OctoBG's look. Every setting of
  -- pfUI's own Nameplates page (that page is hidden from the topic list and
  -- Find) plus the Plater-style ones of plates.lua: General, Look and size,
  -- Threat and colours, Target, Cast bar, Debuffs, Range and execute.
  local P = pfUI.plates
  local OU = pfUI.octoui
  local W = OU and OU.W
  local O = OU and OU.Options
  if not P or not W or not O or not O.AddPage then return end
  local BUILD = {}
  local PfChk, PfSld = O.PfChk, O.PfSld

  local function S() return C.plates end
  local function N() return C.nameplates end
  local function ND() return C.nameplates.debuffs end
  local function NN() return C.nameplates.name end
  local function NH() return C.nameplates.health end
  local function U() P.Refresh() end
  local function Pct(v) return math.floor(v + 0.5) .. "%" end
  local function Px(v) return v .. " px" end
  local function Yd(v) return v .. " yd" end
  local function Alpha(v) return math.floor(v * 100 + 0.5) .. "%" end

  -- a pfUI-style string setting as a dropdown / colour / text field
  local function Drop(p, label, desc, options, group, key)
    return W.Dropdown(p, label, desc, options, function() return group()[key] end, function(v)
      group()[key] = v
      U()
    end)
  end
  local function Color(p, label, desc, group, key)
    return W.Color(p, label, desc, function()
      local r, g, b, a = GetStringColor(group()[key] or "1,1,1,1")
      return tonumber(r) or 1, tonumber(g) or 1, tonumber(b) or 1, tonumber(a) or 1
    end, function(r, g, b, a)
      group()[key] = string.format("%.2f,%.2f,%.2f,%.2f", r, g, b, a or 1)
      U()
    end)
  end
  local function Edit(p, label, desc, group, key)
    return W.Edit(p, label, desc, function() return group()[key] end, function(v)
      group()[key] = v or ""
      U()
    end, 300)
  end
  local function Chk(p, label, desc, group, key) return PfChk(p, label, desc, group, key, U) end
  local function Sld(p, label, desc, min, max, step, group, key, fmt) return PfSld(p, label, desc, min, max, step, group, key, U, fmt) end

  -- pfUI's "key:label" dropdown lists as Octo options
  local function PfList(list)
    local out = {}
    for _, e in ipairs(list or {}) do
      local _, _, k, l = string.find(e, "^(.-):(.*)$")
      if k then table.insert(out, { key = k, label = l }) end
    end
    return out
  end
  local function DD(name) return PfList(pfUI.gui and pfUI.gui.dropdowns and pfUI.gui.dropdowns[name]) end

  local BARS = {
    { key = "Interface\\AddOns\\pfUI\\img\\plates\\bar-soft", label = "Octo soft" },
    { key = "Interface\\AddOns\\pfUI\\img\\plates\\bar-flat", label = "Octo flat" },
    { key = "Interface\\AddOns\\pfUI\\img\\plates\\bar-gloss", label = "Octo gloss" },
    { key = "Interface\\AddOns\\pfUI\\img\\plates\\bar-glass", label = "Octo glass" },
    { key = "Interface\\AddOns\\pfUI\\img\\plates\\bar-split", label = "Octo split" },
  }
  local function Bars()
    local out = {}
    for _, b in ipairs(BARS) do table.insert(out, b) end
    for _, b in ipairs(DD("uf_bartexture")) do table.insert(out, b) end
    -- each shows as a strip of itself in the menu
    for _, b in ipairs(out) do b.texture = pfUI.media[b.key] end
    return out
  end
  local function Fonts()
    local out = { { key = "", label = "pfUI's font", font = pfUI.font_default } }
    for _, f in ipairs(W.Fonts()) do table.insert(out, { key = f.key, label = f.label, font = f.key }) end
    return out
  end

  local function Count()
    local n = 0
    local kids = { WorldFrame:GetChildren() }
    for _, f in ipairs(kids) do
      if f.nameplate and f:IsVisible() then n = n + 1 end
    end
    return n
  end

  local ROLE = { auto = "Automatic", tank = "Tank", dps = "Damage / healer" }

  -- Sample nameplates drawn with every setting as it is now (OctoBG's
  -- "Icons on nameplates" box), and the test on the real ones.
  local function Preview(p, h)
    W.Card(p, "Preview", { tip = "Sample plates drawn by the real nameplate code with your settings: your target "
      .. "casting (every other cast is interrupted), a mob going through the threat colours, one at low health and "
      .. "a friendly player. Changes show here at once." })
    P.AttachPreview(W.Box(p, h or 212))
    W.Live(p, function()
      if P.Testing() then return "|cff55ff55Test running|r (" .. math.ceil(P.testUntil - GetTime()) .. " s) - press V to see enemy plates" end
      return "Test on real nameplates puts pretend threat colours and casts on every plate you can see for a minute."
    end)
    W.Buttons(p, {
      { "Test on real nameplates", function() P.Test(60) end, 180,
        "For a minute every nameplate you can see gets pretend threat colours and casts (every other one interrupted by Bob). V shows enemy plates, Shift-V friendly ones, e.g. in a city." },
      { "Stop test", function() P.Test(0) end, 90, "Ends the test." },
    })
  end

  -- the looks, four to a row; the picked one is lit (none = your own mix)
  local function Looks(p)
    local btns = {}
    local rows = {}
    local n = table.getn(P.PRESETS)
    for r = 1, math.ceil(n / 4) do rows[r] = W.Row(p, 24, 0, 6) end
    local mix = W.Live(p, function()
      local _, label = P.CurrentLook()
      return label and ("Look: |cffffffff" .. label .. "|r") or "Look: |cffffffffyour own mix|r (a setting was changed after picking a look)"
    end)
    local function Paint()
      local cur = P.CurrentLook()
      for _, b in ipairs(btns) do W.Pick(b, b.key == cur) end
    end
    for i, pr in ipairs(P.PRESETS) do
      local b = W.Button(rows[math.floor((i - 1) / 4) + 1], pr[2], 160, 22)
      b:SetPoint("LEFT", b:GetParent(), "LEFT", math.mod(i - 1, 4) * 166, 0)
      b.key = pr[1]
      b:SetScript("OnClick", function()
        P.ApplyPreset(this.key)
        Paint()
        W.Refresh(p)
      end)
      W.Tip(b, pr[2], "Sets the bar texture, border, size, text and target marker. Colours, lists and on / off switches stay as they are.")
      btns[i] = b
    end
    -- other pages change settings too: keep the lit button right
    rows[1]:SetScript("OnUpdate", function()
      if (this.tick or 0) > GetTime() then return end
      this.tick = GetTime() + .5
      Paint()
    end)
    Paint()
    return mix
  end

  -- ---------------------------------------------------------------- general

  BUILD.npgeneral = function(p)
    W.Heading(p, "Nameplates", {
      on = { function() return C.plates.enable == "1" end, function(v) C.plates.enable = v and "1" or "0"; U() end,
             "Plater-style nameplates on or off. Off: pfUI's own nameplates as they were." },
      about = "Plater's ideas on pfUI's nameplates: aggro colours that flip for tanks, sizes per kind of unit, "
        .. "target arrows, a Plater cast bar that says who interrupted, execute range, plates that fade out of "
        .. "range. The art is pfUI Octo's own." })
    W.Live(p, function()
      local s = {}
      local n = Count()
      table.insert(s, n .. " nameplate" .. ((n == 1) and "" or "s") .. " on screen" .. ((n == 0) and " - V shows enemy plates, Shift-V friendly" or ""))
      table.insert(s, "role: " .. (P.Role() == "tank" and "tank" or "damage / healer"))
      table.insert(s, P.SuperWoW() and "SuperWoW |cff55ff55found|r" or "SuperWoW |cffff5555missing|r (no threat colours on other plates)")
      table.insert(s, UnitXP and "UnitXP |cff55ff55found|r" or "UnitXP |cffff5555missing|r (no range fade)")
      return table.concat(s, "    ")
    end)
    W.Card(p, "Looks", { tip = "Ready-made styles: bar texture, border skin, sizes, text and target marker in one click." })
    Looks(p)
    Preview(p)
    W.Card(p, "Show")
    PfChk(p, "Enemies", "Nameplates on hostile units at login (V turns them on and off in game).", N, "showhostile", P.ApplyShow)
    PfChk(p, "Friends", "Nameplates on friendly units at login (Shift-V in game).", N, "showfriendly", P.ApplyShow)
    Chk(p, "Totems as icons", "A totem shows its icon instead of a bar.", N, "totemicons")
    Chk(p, "Guild names", "The guild under a player's name.", N, "showguildname")
    Chk(p, "Combo points", "Your combo points under the target's plate.", N, "cpdisplay")
    Chk(p, "Elite, rare and boss marks", "A star (gold elite, silver rare) or a skull (boss) by the name.", S, "eliteicon")
    W.Card(p, "Name only (no bar) on", { tip = "These show just their name and level." })
    Chk(p, "Enemy NPCs", nil, N, "enemynpc")
    Chk(p, "Enemy players", nil, N, "enemyplayer")
    Chk(p, "Neutral NPCs", nil, N, "neutralnpc")
    Chk(p, "Friendly NPCs", nil, N, "friendlynpc")
    Chk(p, "Friendly players", nil, N, "friendlyplayer")
    Chk(p, "Critters", nil, N, "critters")
    Chk(p, "Totems", nil, N, "totems")
    Chk(p, "Still a bar when hurt", "A unit that has lost health keeps its bar.", N, "fullhealth")
    Chk(p, "Still a bar on the target", nil, N, "target")
    if pfUI.client <= 11200 then
      W.Card(p, "Clicks", { folded = true })
      Chk(p, "Click through", "Plates ignore the mouse.", N, "clickthrough")
      Chk(p, "Overlap", "Plates may sit on top of each other instead of spreading out.", N, "overlap")
      Chk(p, "Right-click turns the camera", "Hold right-click on a plate to turn; a quick click targets and attacks.", N, "rightclick")
      Sld(p, "Quick click under", "How short a right-click must be to count as a click.", 0.1, 1, 0.05, N, "clickthreshold", function(v) return v .. " s" end)
      Sld(p, "Raise plates by", "Moves every plate up (or down) from where the game puts it.", -50, 50, 1, N, "vertical_offset", Px)
    end
  end

  -- ---------------------------------------------------------------- look and size

  BUILD.nplook = function(p)
    W.Heading(p, "Look and size", { about = "Bar texture, border skin, background, letters and how big each kind of plate is." })
    Preview(p)
    W.Card(p, "Bar")
    Drop(p, "Texture", "The fill of the health and cast bars. The Octo ones are pfUI Octo's own art.", Bars(), S, "bartexture")
    Drop(p, "Border skin", "The edge around the health and cast bars.", {
      { key = "pfui", label = "Thin black (pfUI)" }, { key = "shadow", label = "Soft shadow" }, { key = "thick", label = "Thick black" },
      { key = "accent", label = "Accent line" }, { key = "neon", label = "Neon glow (accent)" }, { key = "gold", label = "Gold line" },
    }, S, "skin")
    Color(p, "Background", "Behind the bars (the empty part).", S, "bgcolor")
    Sld(p, "Width", nil, 60, 250, 1, N, "width", Px)
    Sld(p, "Health height", nil, 2, 30, 1, N, "heighthealth", Px)
    Sld(p, "Gap under the name", "Space between the name and the bar.", -10, 10, 1, NH, "offset", Px)
    Chk(p, "Upright bar", "The health bar fills from the bottom up.", N, "verticalhealth")
    W.Card(p, "Text")
    Drop(p, "Font", "The letters of names and numbers on plates.", Fonts(), S, "font")
    Drop(p, "Outline", nil, DD("fontstyle"), NN, "fontstyle")
    Sld(p, "Name size", "0 = pfUI's font size.", 0, 24, 1, S, "namesize", function(v) return v == 0 and "pfUI's" or (v .. " px") end)
    Sld(p, "Health text size", "0 = a bit smaller than the name.", 0, 24, 1, S, "hpsize", function(v) return v == 0 and "auto" or (v .. " px") end)
    Chk(p, "Unit frame font", "Use pfUI's unit frame font when no font is picked above.", N, "use_unitfonts")
    Chk(p, "Health text", "Numbers on the health bar.", N, "showhp")
    Drop(p, "Health text place", nil, DD("textalign"), N, "hptextpos")
    Drop(p, "Health text shows", nil, DD("hpformat"), N, "hptextformat")
    W.Card(p, "Colours", { tip = "Click a swatch for the colour wheel. Tick the box beside a colour to use it instead of pfUI's." })
    Chk(p, "My own name colour", "Off: white, orange in a fight, class colours as set on Threat and colours.", S, "namecustom")
    Color(p, "Name", nil, S, "namecolor")
    Chk(p, "My own level colour", "Off: the game's difficulty colour.", S, "levelcustom")
    Color(p, "Level", nil, S, "levelcolor")
    Chk(p, "My own border colour", "Off: pfUI's black, or its target / combat state colours.", S, "bordercustom")
    Color(p, "Border", "The thin border round the health and cast bars.", S, "bordercolor")
    Chk(p, "My own skin colour", "Off: each border skin's own colour (black, accent, gold...).", S, "skincustom")
    Color(p, "Skin", "The border skin's edge (shadow, thick, accent, neon, gold).", S, "skincolor")
    Color(p, "Health text", nil, S, "hptextcolor")
    Color(p, "Cast bar text", "The spell name and time.", S, "casttextcolor")
    W.Card(p, "Combo points", { on = { function() return C.nameplates.cpdisplay == "1" end,
      function(v) C.nameplates.cpdisplay = v and "1" or "0"; U() end, "Your combo points on your target's plate." } })
    W.Dropdown(p, "Style", nil, { { key = "orbs", label = "Orbs" }, { key = "gems", label = "Gems" },
      { key = "squares", label = "Squares" }, { key = "segments", label = "Bar segments" }, { key = "pfui", label = "pfUI's small squares" } },
      function() return C.plates.cpstyle end, function(v) C.plates.cpstyle = v; U() end)
    W.Dropdown(p, "Place", nil, { { key = "below", label = "Under the bars" }, { key = "above", label = "Above the name" },
      { key = "inside", label = "On the health bar" } }, function() return C.plates.cpplace end, function(v) C.plates.cpplace = v; U() end)
    Sld(p, "Size", nil, 6, 30, 1, S, "cpsize", Px)
    Sld(p, "Gap", nil, 0, 12, 1, S, "cpgap", Px)
    W.Dropdown(p, "Colour", nil, { { key = "gradient", label = "Yellow to red by count" }, { key = "class", label = "Class colour" },
      { key = "custom", label = "One colour" } }, function() return C.plates.cpcolor end, function(v) C.plates.cpcolor = v; U() end)
    Color(p, "One colour", nil, S, "cpcustom")
    Chk(p, "Empty slots", "Show the points you do not have yet, dimmed.", S, "cpempty")
    Chk(p, "Glow at 5", "The points pulse when you have all five.", S, "cpglow")
    W.Card(p, "Size by kind", { tip = "% of the width and height above; plates grow and shrink smoothly." })
    Sld(p, "Enemy NPCs", nil, 40, 160, 5, S, "size_enemynpc", Pct)
    Sld(p, "Enemy players", nil, 40, 160, 5, S, "size_enemyplayer", Pct)
    Sld(p, "Friendly NPCs", nil, 40, 160, 5, S, "size_friendlynpc", Pct)
    Sld(p, "Friendly players", nil, 40, 160, 5, S, "size_friendlyplayer", Pct)
    Sld(p, "Out of combat", "Plates shrink to this while you are not fighting.", 40, 120, 5, S, "size_ooc", Pct)
    W.Card(p, "Raid mark", { folded = true })
    Drop(p, "Place", nil, DD("positions"), N, "raidiconpos")
    Sld(p, "Size", nil, 8, 48, 1, N, "raidiconsize", Px)
    Sld(p, "Left / right", nil, -60, 60, 1, N, "raidiconoffx", Px)
    Sld(p, "Up / down", nil, -60, 60, 1, N, "raidiconoffy", Px)
  end

  -- ---------------------------------------------------------------- threat

  BUILD.npthreat = function(p)
    W.Heading(p, "Threat and colours", {
      on = { function() return C.plates.threat == "1" end, function(v) C.plates.threat = v and "1" or "0"; U() end,
             "Aggro colours on the bars of mobs fighting you." },
      about = "Damage and healers: red = the mob is on you, orange = you are about to pull it off the tank (your "
        .. "target, from the server's threat numbers), purple = it is on someone else. Tanks: blue = it is on you, orange = someone is about to "
        .. "pull it, purple = another tank has it, red = it is loose on someone else. Needs SuperWoW for plates "
        .. "other than your target." })
    W.Live(p, function() return "You count as: " .. (P.Role() == "tank" and "|cff55aaffTank|r" or "|cffff7755Damage / healer|r") end)
    Preview(p)
    W.Card(p, "Role")
    W.Dropdown(p, "Role", "Automatic: tank in Defensive Stance, bear form, with Righteous Fury or marked a tank in pfUI's raid frames.",
      { { key = "auto", label = ROLE.auto }, { key = "tank", label = ROLE.tank }, { key = "dps", label = ROLE.dps } },
      function() return C.plates.role end, function(v) C.plates.role = v; U() end)
    Sld(p, "Pulling at", "% of the tank's threat that counts as about to pull.", 50, 130, 5, S, "pullat", Pct)
    Chk(p, "Aggro glow", "A glow around the plate when a mob is on you (or, for tanks, loose on someone else).", S, "aggroglow")
    W.Card(p, "Damage and healer colours")
    Color(p, "On you", nil, S, "c_aggro")
    Color(p, "Pulling", nil, S, "c_pulling")
    Color(p, "On someone else", nil, S, "c_safe")
    Chk(p, "Keep the normal colour", "On someone else: no colour of its own.", S, "safenormal")
    W.Card(p, "Tank colours")
    Color(p, "On you", nil, S, "c_tankaggro")
    Color(p, "Losing it", nil, S, "c_losing")
    Color(p, "On another tank", nil, S, "c_offtank")
    Color(p, "Lost", nil, S, "c_lost")
    Color(p, "Taking it from a tank", "On another tank, and you are near its threat (your target).", S, "c_taking")
    Edit(p, "Other tanks", "Names separated by #. pfUI's raid frame tank marks count too.", N, "combatofftanks")
    W.Card(p, "Class and name colours")
    Chk(p, "Class colours on enemies", nil, N, "enemyclassc")
    Chk(p, "Class colours on friends", nil, N, "friendclassc")
    Chk(p, "Class coloured friend names", nil, N, "friendclassnamec")
    Chk(p, "Orange name in a fight", "The name turns orange while the unit fights.", N, "namefightcolor")
    W.Card(p, "Border colours", { folded = true, tip = "pfUI's own colours on the bar's border." })
    Chk(p, "Friendly players blue", nil, N, "outfriendly")
    Chk(p, "Friendly NPCs green", nil, N, "outfriendlynpc")
    Chk(p, "Neutral yellow", nil, N, "outneutral")
    Chk(p, "Enemies red", nil, N, "outenemy")
    Chk(p, "Combat state on the border", "SuperWoW: the border shows who the mob attacks (colours below).", N, "outcombatstate")
    Chk(p, "Combat state on the bar", "pfUI's own bar colours by combat state (threat colours above win).", N, "barcombatstate")
    Chk(p, "Attacking you", nil, N, "ccombatthreat")
    Chk(p, "Attacking an off-tank", nil, N, "ccombatofftank")
    Chk(p, "Attacking others", nil, N, "ccombatnothreat")
    Chk(p, "Attacking no one", nil, N, "ccombatstun")
    Chk(p, "Casting", nil, N, "ccombatcasting")
    Color(p, "Attacking you", nil, N, "combatthreat")
    Color(p, "Attacking an off-tank", nil, N, "combatofftank")
    Color(p, "Attacking others", nil, N, "combatnothreat")
    Color(p, "Attacking no one", nil, N, "combatstun")
    Color(p, "Casting", nil, N, "combatcasting")
  end

  -- ---------------------------------------------------------------- target

  BUILD.nptarget = function(p)
    W.Heading(p, "Target, range and execute", { about = "How your target's plate stands out, plates that fade when far "
      .. "away or out of sight (needs UnitXP), and the colour of a mob low enough to execute." })
    Preview(p)
    W.Card(p, "Target")
    W.Dropdown(p, "Marker", "Beside or around your target's bar.",
      { { key = "arrows", label = "Arrows" }, { key = "chevrons", label = "Double arrows" }, { key = "corners", label = "Corners" },
        { key = "underglow", label = "Light under the bar" }, { key = "none", label = "None" } },
      function() return C.plates.indicator end, function(v) C.plates.indicator = v; U() end)
    Chk(p, "Accent colour", "The marker in pfUI Octo's accent colour.", S, "targetaccent")
    Color(p, "Marker colour", "When the accent colour is off.", S, "targetcolor")
    Sld(p, "Target size", "Your target's plate grows to this.", 80, 160, 5, S, "size_target", Pct)
    Sld(p, "Other plates", "How see-through the plates that are not your target are.", 0.1, 1, 0.05, N, "notargalpha", Alpha)
    Chk(p, "Mouse-over highlight", "The bar lights up under the mouse.", S, "mouseover")
    W.Card(p, "More target effects", { folded = true })
    Chk(p, "Glow", "pfUI's soft glow behind the target.", N, "targetglow")
    Color(p, "Glow colour", nil, N, "glowcolor")
    Chk(p, "Border", "A coloured border on the target's bar.", N, "targethighlight")
    Color(p, "Border colour", nil, N, "highlightcolor")
    Chk(p, "Zoom", "pfUI's zoom: the target's bar gets wider and taller.", N, "targetzoom")
    Sld(p, "Zoom by", nil, 0.05, 1, 0.05, N, "targetzoomval", Alpha)
  end

  -- ---------------------------------------------------------------- cast bar

  BUILD.npcast = function(p)
    W.Heading(p, "Cast bar", {
      on = { function() return C.nameplates.showcastbar == "1" end, function(v) C.nameplates.showcastbar = v and "1" or "0"; U() end,
             "Cast bars under nameplates." },
      about = "What a unit is casting, under its plate. When a cast ends it flashes green (done) or red (stopped), "
        .. "with who interrupted it when the combat log says." })
    Preview(p)
    W.Card(p, "Bar")
    W.Dropdown(p, "Layout", "Plater: the icon left of the bar, the spell's name in the bar, the time on the right. pfUI: as pfUI had it.",
      { { key = "plater", label = "Plater" }, { key = "pfui", label = "pfUI" } },
      function() return C.plates.castlayout end, function(v) C.plates.castlayout = v; U() end)
    W.Slider(p, "Height", nil, 4, 24, 1, function() return tonumber(C.plates.castheight) end, function(v)
      C.plates.castheight = tostring(v)
      C.nameplates.heightcast = tostring(v)
      U()
    end, Px)
    Chk(p, "Only your target", "Other units' casts are not shown.", N, "targetcastbar")
    Chk(p, "Spell name (pfUI layout)", "The Plater layout always shows it.", N, "spellname")
    Chk(p, "Spark", "A bright edge where the bar fills.", S, "spark")
    Chk(p, "Flash when it ends", "Green when the cast went off, red when it was stopped.", S, "castend")
    Chk(p, "Who interrupted", "\"Interrupted by NAME\" on the red flash.", S, "kicker")
    W.Card(p, "Colours")
    Color(p, "Casting", nil, S, "c_cast")
    Color(p, "Channelling", nil, S, "c_channel")
    Color(p, "Done", nil, S, "c_done")
    Color(p, "Stopped", nil, S, "c_stopped")
    Color(p, "Background", "The empty part of the cast bar (lighter than the health bar's, so a new cast shows).", S, "castbg")
  end

  -- ---------------------------------------------------------------- debuffs

  local function ListEdit(p, label, desc, key)
    return W.Edit(p, label, desc, function() return C.plates[key] end, function(v)
      C.plates[key] = v or ""
      U()
    end, 420)
  end

  BUILD.npauras = function(p)
    W.Heading(p, "Auras", {
      on = { function() return C.plates.auras == "1" end, function(v) C.plates.auras = v and "1" or "0"; U() end,
             "Plater-style buff and debuff icons. Off: pfUI's own debuff row (Old debuff row below)." },
      about = "Icons above the name: your debuffs and crowd control on the mob, then its important buffs (gold edge), "
        .. "with timers and stacks. Edges show the debuff type: blue Magic, purple Curse, brown Disease, green Poison. "
        .. "Special auras are big icons on top; ghost auras are your own debuffs missing from a mob you fight, faded. "
        .. "With SuperWoW every plate knows its auras; without it only your target does. Timers are known for your own "
        .. "debuffs (and others' when ClassicAPI tells)." })
    Preview(p)
    W.Card(p, "What shows")
    W.Dropdown(p, "Debuffs", nil, { { key = "mine_cc", label = "Yours and crowd control" }, { key = "mine", label = "Only yours" },
      { key = "all", label = "All" } }, function() return C.plates.debuffshow end, function(v) C.plates.debuffshow = v; U() end)
    W.Dropdown(p, "Enemy buffs", nil, { { key = "important", label = "Important ones" }, { key = "all", label = "All" },
      { key = "none", label = "None" } }, function() return C.plates.buffshow end, function(v) C.plates.buffshow = v; U() end)
    W.Dropdown(p, "Filter", "Applies to debuffs.",
      { { key = "none", label = "No list" }, { key = "blacklist", label = "Hide the black list" }, { key = "whitelist", label = "Only the white list" } },
      function() return C.nameplates.debuffs.filter end, function(v) C.nameplates.debuffs.filter = v; U() end)
    Edit(p, "Black list", "Debuff names separated by #.", ND, "blacklist")
    Edit(p, "White list", "Debuff names separated by #.", ND, "whitelist")
    W.Card(p, "Icons")
    Sld(p, "Width", nil, 10, 40, 1, S, "aurawidth", Px)
    Sld(p, "Height", nil, 10, 40, 1, S, "auraheight", Px)
    Sld(p, "Per row", nil, 1, 12, 1, S, "auraperrow")
    Sld(p, "Rows", nil, 1, 3, 1, S, "aurarows")
    W.Dropdown(p, "Grow", nil, { { key = "center", label = "From the middle" }, { key = "right", label = "To the right" },
      { key = "left", label = "To the left" } }, function() return C.plates.auragrow end, function(v) C.plates.auragrow = v; U() end)
    Sld(p, "Above the name by", nil, -10, 30, 1, S, "auraoffset", Px)
    Chk(p, "Timers", "Time left on the icon (red under 3 s).", S, "auratimer")
    Chk(p, "Stacks", nil, S, "aurastacks")
    Chk(p, "Edges by debuff type", nil, S, "auraborder")
    W.Card(p, "Special auras", { on = { function() return C.plates.specialon == "1" end, function(v) C.plates.specialon = v and "1" or "0"; U() end,
      "Big icons for the spells listed." } })
    Sld(p, "Size", nil, 16, 48, 1, S, "specialsize", Px)
    ListEdit(p, "Spells", "Names separated by #. Shown big, on top, edged in the accent colour.", "specialauras")
    W.Card(p, "Ghost auras", { on = { function() return C.plates.ghoston == "1" end, function(v) C.plates.ghoston = v and "1" or "0"; U() end,
      "Your own debuffs that are missing from a mob you are fighting, shown faded." } })
    ListEdit(p, "Spells", "Your debuffs to keep up, separated by #. Their icons come from your spellbook.", "ghostauras")
    Sld(p, "Faded to", nil, 0.1, 1, 0.05, S, "ghostalpha", Alpha)
    W.Buttons(p, { { "Fill with my class's usual", function()
      local _, class = UnitClass("player")
      C.plates.ghostauras = P.Auras and P.Auras.GHOSTS[class or ""] or ""
      U()
      W.Refresh(p)
    end, 200, "Warlock: Corruption, Curse of Agony, Immolate; priest: Shadow Word: Pain; and so on." } })
    W.Card(p, "Old debuff row", { folded = true, tip = "pfUI's own debuff icons, used while Auras is off." })
    Chk(p, "Show it", nil, N, "showdebuffs")
    W.Dropdown(p, "Place", nil, { { key = "TOP", label = "Above" }, { key = "BOTTOM", label = "Below" } },
      function() return C.nameplates.debuffs.position end, function(v) C.nameplates.debuffs.position = v; U() end)
    Sld(p, "Size", nil, 8, 40, 1, N, "debuffsize", Px)
    Sld(p, "Gap", "Space between the bar and the icons.", 0, 20, 1, N, "debuffoffset", Px)
    Chk(p, "Stacks", "The stack count on the icon.", ND, "showstacks")
    Chk(p, "Only yours", "Only the debuffs you put on.", N, "selfdebuff")
    Chk(p, "Estimate", "Remember debuffs seen on a unit for plates that cannot read them.", N, "guessdebuffs")
  end

  -- ---------------------------------------------------------------- colours and names

  local function Hex(c)
    if not c then return "" end
    return string.format("|cff%02x%02x%02x", math.floor(c[1] * 255), math.floor(c[2] * 255), math.floor(c[3] * 255))
  end

  -- An editor for one list (NPCs or spells): name, colour, new name, then
  -- Save / Remove, and the list below. Typing a name already listed loads it.
  local function ListEditor(p, key, what, fromTarget, targetTip)
    local ed = { name = "", color = nil, rename = "" }
    local L = P.Lists
    local function Load(name)
      ed.name = name or ""
      local e = L.Parse(C.plates[key])[string.lower(ed.name)]
      ed.color = e and e.color
      ed.rename = e and e.rename or ""
    end
    W.Edit(p, what, "Type the name and press Enter (an entry already listed is loaded).", function() return ed.name end,
      function(v) Load(v) W.Refresh(p) end, 300)
    W.Color(p, "Colour", "The bar colour for this name. No colour = only the new name.", function()
      local c = ed.color or { 1, 1, 1 }
      return c[1], c[2], c[3], 1
    end, function(r, g, b) ed.color = { r, g, b } end)
    W.Edit(p, "Show as", "A new name to show instead (empty = keep).", function() return ed.rename end, function(v) ed.rename = v or "" end, 300)
    W.Buttons(p, {
      { "Use my target", function() Load(fromTarget() or "") end, 130, targetTip },
      { "No colour", function() ed.color = nil end, 100, "Keeps the normal colour; only the new name is used." },
      { "Save", function()
        L.Put(key, ed.name, ed.color, ed.rename)
        P.Refresh()
      end, 90, "Adds or changes this entry." },
      { "Remove", function()
        L.Remove(key, ed.name)
        Load("")
        P.Refresh()
      end, 90, "Takes this name off the list." },
    })
    W.Live(p, function()
      local list = L.Parse(C.plates[key])
      local keys = {}
      for k in pairs(list) do table.insert(keys, k) end
      table.sort(keys)
      if table.getn(keys) == 0 then return "|cff999999Nothing listed yet.|r" end
      local lines = {}
      for _, k in ipairs(keys) do
        local e = list[k]
        table.insert(lines, (e.color and (Hex(e.color) .. "####|r ") or "") .. e.name .. (e.rename and ("  ->  " .. e.rename) or ""))
      end
      return table.concat(lines, "\n")
    end)
  end

  -- Plater's NPC Colors (on Threat and colours) and Cast Colors (on Cast bar)
  local function NpcCards(p)
    W.Card(p, "NPC colours and names", { tip = "An NPC's own bar colour or a shorter name. Threat colours win while you fight, unless ticked below." })
    ListEditor(p, "npclist", "NPC name", function() return UnitName("target") end, "Takes your target's name.")
    Chk(p, "NPC colour wins over threat", nil, S, "npcoverthreat")
  end
  local function SpellCards(p)
    W.Card(p, "Spell colours and names", { tip = "A spell's own cast bar colour or a new name for it." })
    ListEditor(p, "castlist", "Spell name", function()
      return UnitCastingInfo and UnitCastingInfo("target") or (UnitChannelInfo and UnitChannelInfo("target"))
    end, "Takes the spell your target is casting right now.")
  end

  BUILD.npquest = function(p)
    W.Heading(p, "Quests, icons and auto", { about = "Marks for quest units (from pfQuest when it is on, else your quest "
      .. "log), class icons on players and paws on pets, and nameplates that switch on and off by themselves." })
    Preview(p)
    W.Card(p, "Quests")
    W.Live(p, function()
      return (pfMap and pfMap.tooltips) and "pfQuest |cff55ff55found|r: kill and loot objectives, quests to take (!) and hand in (?)"
        or "pfQuest |cffff5555not on|r: only mobs to kill from your quest log"
    end)
    Chk(p, "Quest marks", "A mark right of the name: diamond = for your quest, ! = has a quest for you, ? = hand one in.", S, "questmark")
    Chk(p, "Colour quest mobs", "Quest mobs' bars in the colour below (threat and NPC colours win).", S, "questbar")
    Color(p, "Quest colour", nil, S, "questcolor")
    W.Card(p, "Icons")
    Chk(p, "Class icon on enemy players", nil, S, "classicon_enemy")
    Chk(p, "Class icon on friendly players", nil, S, "classicon_friend")
    Chk(p, "Paw on pets", nil, S, "peticon")
    Chk(p, "Elite, rare and boss marks", nil, S, "eliteicon")
    W.Card(p, "Auto", { tip = "Nameplates switch themselves on or off. Leave = as you set them with V / Shift-V." })
    local ACT = { { key = "keep", label = "Leave" }, { key = "show", label = "On" }, { key = "hide", label = "Off" } }
    local function A(label, k, list)
      W.Dropdown(p, label, nil, list or ACT, function() return C.plates[k] end, function(v)
        C.plates[k] = v
        if P.Lists then P.Lists.Auto(UnitAffectingCombat("player")) end
      end)
    end
    A("Enemies in combat", "autoenemy_combat", { { key = "keep", label = "Leave" }, { key = "show", label = "On" } })
    A("Enemies out of combat", "autoenemy_ooc")
    A("Friends in cities", "autofriend_city")
    A("Friends in dungeons and raids", "autofriend_instance")
    A("Friends in the open world", "autofriend_world")
  end

  -- ---------------------------------------------------------------- range and execute

  local function RangeCards(p)
    W.Card(p, "Range", { on = { function() return C.plates.range == "1" end, function(v) C.plates.range = v and "1" or "0"; U() end,
      "Fade plates of far units." } })
    Sld(p, "Further than", nil, 5, 100, 1, S, "rangeyards", Yd)
    Sld(p, "Fade to", nil, 0.05, 1, 0.05, S, "rangealpha", Alpha)
    Chk(p, "Out of sight too", "Also fade units behind walls.", S, "los")
    W.Card(p, "Execute")
    W.Dropdown(p, "Execute range", "Automatic: on for warriors (Execute) and paladins (Hammer of Wrath).",
      { { key = "auto", label = "Automatic" }, { key = "on", label = "Always" }, { key = "off", label = "Off" } },
      function() return C.plates.execute end, function(v) C.plates.execute = v; U() end)
    Sld(p, "Under", nil, 5, 50, 1, S, "executepct", Pct)
    Color(p, "Colour", "The bar's colour once the mob is in execute range.", S, "executecolor")
    Chk(p, "Marker", "A line on the bar where execute range starts.", S, "executemark")
  end

  -- seven pages, most used first (user, 22 Oct 2026: "group up some things
  -- into the same menus and reorder them in order of importance")
  local threat, target, cast = BUILD.npthreat, BUILD.nptarget, BUILD.npcast
  BUILD.npthreat = function(p) threat(p) NpcCards(p) end
  BUILD.nptarget = function(p) target(p) RangeCards(p) end
  BUILD.npcast = function(p) cast(p) SpellCards(p) end

  O.replaced[T["Nameplates"]] = true
  O:AddPage("Nameplates", "npgeneral", "General", BUILD.npgeneral)
  O:AddPage("Nameplates", "nplook", "Look and size", BUILD.nplook)
  O:AddPage("Nameplates", "npthreat", "Threat and colours", BUILD.npthreat)
  O:AddPage("Nameplates", "nptarget", "Target, range and execute", BUILD.nptarget)
  O:AddPage("Nameplates", "npcast", "Cast bar", BUILD.npcast)
  O:AddPage("Nameplates", "npauras", "Auras", BUILD.npauras)
  O:AddPage("Nameplates", "npquest", "Quests, icons and auto", BUILD.npquest)
end)

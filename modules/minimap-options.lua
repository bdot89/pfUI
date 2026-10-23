pfUI:RegisterModule("minimap-options", "vanilla:tbc", function ()
  -- pfUI Octo :: the Minimap section in OctoBG's look (23 Oct 2026). User:
  -- "Add a preview frame in minimap options make everything selectable
  -- changeable moveable ... every frame that we have and shape to be able
  -- to have stuff edited around it". Every setting of pfUI's Minimap pages
  -- (Minimap, Addon Buttons, Map Style, Buttons & Extras; hidden from the
  -- topic list and Find now) on three pages, each with the same pinned
  -- preview: a made-up map in your shape, border and art, with every part
  -- around it (minimap-style.lua's map.PARTS) where it really sits. Click a
  -- part for its card, drag it to move it, Shift + wheel to size it,
  -- right-click to put it back.
  local OU = pfUI.octoui
  local W = OU and OU.W
  local O = OU and OU.Options
  if not W or not O or not O.AddPage or not pfUI.minimap then return end
  local map = pfUI.minimap
  local MO = {}
  pfUI.minimapOcto = MO

  local function S() return C.mapstyle end
  local function MM() return C.appearance.minimap end
  local function AB() return C.abuttons end
  local function U() if map.ApplyStyle then map.ApplyStyle() end end
  local function Pct(v) return math.floor(v + .5) .. "%" end
  local function Px(v) return v .. " px" end
  local function Sec(v) return v == 0 and "never" or (v .. " s") end

  local function PfList(list)
    local out = {}
    for _, e in ipairs(list or {}) do
      local _, _, k, l = string.find(e, "^(.-):(.*)$")
      if k then table.insert(out, { key = k, label = l }) end
    end
    return out
  end
  local function DD(name) return PfList(pfUI.gui and pfUI.gui.dropdowns and pfUI.gui.dropdowns[name]) end

  local function Drop(p, label, desc, options, group, key, after)
    return W.Dropdown(p, label, desc, options, function() return group()[key] end, function(v)
      group()[key] = v
      if after then after(v) else U() end
    end)
  end
  local function Chk(p, label, desc, group, key, after) return O.PfChk(p, label, desc, group, key, after or U) end
  local function Sld(p, label, desc, min, max, step, group, key, fmt, after) return O.PfSld(p, label, desc, min, max, step, group, key, after or U, fmt) end
  local function Color(p, label, desc, group, key)
    return W.Color(p, label, desc, function()
      local r, g, b, a = GetStringColor(group()[key] or "1,1,1,1")
      return tonumber(r) or 1, tonumber(g) or 1, tonumber(b) or 1, tonumber(a) or 1
    end, function(r, g, b, a)
      group()[key] = string.format("%.2f,%.2f,%.2f,%.2f", r, g, b, a or 1)
      U()
    end)
  end

  local function MapSize() pfUI.minimap:UpdateConfig() end

  -- which card each part of the preview opens: { page, card }
  local GO = {
    map = { "mmmap", "Shape and border" }, art = { "mmart", "Art layer 1" },
    zone = { "mmparts", "Zone name" }, coords = { "mmparts", "Coordinates" }, clock = { "mmparts", "Clock" },
    ping = { "mmparts", "Who pinged" }, tracking = { "mmparts", "Tracking" }, mail = { "mmparts", "Mail" },
    battlefield = { "mmparts", "Battleground" }, pvp = { "mmparts", "PvP icon" }, abutton = { "mmparts", "Addon buttons" },
    bar = { "mmparts", "Bar under the map" },
  }
  MO.GO = GO
  function MO.Open(what)
    local g = GO[what]
    if not g then return end
    if pfUI.plates and pfUI.plates.OpenSection then pfUI.plates.OpenSection(g[1], g[2]) else O:Open(g[1]) end
  end

  -- shown always / on mouse-over / never, for every part
  local function Mode(key)
    if key == "zone" or key == "coords" then
      local v = (key == "zone") and MM().zonetext or MM().coordstext
      return (v == "on" and "show") or (v == "mouseover" and "hover") or "hide"
    elseif key == "ping" then
      return S().ping == "1" and "show" or "hide"
    elseif key == "pvp" then
      return C.unitframes.player.showPVPMinimap == "1" and "show" or "hide"
    elseif key == "bar" then
      return C.panel.other.minimap == "none" and "hide" or "show"
    end
    return S()[key] or "show"
  end
  local MODEWORD = { show = "always", hover = "while the mouse is over the map", hide = "hidden" }

  -- ---------------------------------------------------------------- preview

  local MAPPX = 150
  local SHAPES = {
    { key = "square", label = "Square" }, { key = "round", label = "Round" }, { key = "rounded", label = "Rounded square" },
    { key = "rounder", label = "Rounder square" }, { key = "squircle", label = "Squircle" }, { key = "octagon", label = "Octagon" },
    { key = "diamond", label = "Diamond" }, { key = "corner-tl", label = "Round, square top left" },
    { key = "corner-tr", label = "Round, square top right" }, { key = "corner-bl", label = "Round, square bottom left" },
    { key = "corner-br", label = "Round, square bottom right" },
  }
  local function ShapeArt(shape)
    if shape == "square" then return "Interface\\Buttons\\WHITE8X8" end
    return pfUI.media["img:minimap\\mask-" .. shape]
  end
  for _, s in ipairs(SHAPES) do s.icon, s.iconColor = ShapeArt(s.key), { .75, .65, .45 } end

  local function Turn(tex, angle)
    local c, s = math.cos(angle), math.sin(angle)
    local function P(x, y) return .5 + (x - .5) * c - (y - .5) * s, .5 + (x - .5) * s + (y - .5) * c end
    local ulx, uly = P(0, 0)
    local llx, lly = P(0, 1)
    local urx, ury = P(1, 0)
    local lrx, lry = P(1, 1)
    tex:SetTexCoord(ulx, uly, llx, lly, urx, ury, lrx, lry)
  end
  local function Col(str)
    local r, g, b, a = GetStringColor(str or "1,1,1,1")
    return tonumber(r) or 1, tonumber(g) or 1, tonumber(b) or 1, tonumber(a) or 1
  end
  local function Accent()
    if GetAccentColor then return GetAccentColor() end
    return .2, .55, .9
  end

  -- what each part looks like in the preview
  local function Sample(key)
    if key == "zone" then return "text", (GetMinimapZoneText and GetMinimapZoneText() ~= "" and GetMinimapZoneText()) or "The Barrens", 2
    elseif key == "coords" then return "text", "47.3, 52.1", 0
    elseif key == "clock" then return "text", date("%H:%M"), 0
    elseif key == "ping" then return "text", "|cffff7d0aJaina|r", 0
    elseif key == "tracking" then
      local t = GetTrackingTexture and GetTrackingTexture()
      return "icon", t or "Interface\\Icons\\Ability_Tracking", tonumber(MM().tracking_size) or 16
    elseif key == "mail" then return "icon", pfUI.media["img:mail"], 18
    elseif key == "battlefield" then
      local f = UnitFactionGroup and UnitFactionGroup("player")
      return "icon", "Interface\\BattlefieldFrame\\Battleground-" .. ((f == "Horde") and "Horde" or "Alliance"), 32
    elseif key == "pvp" then return "icon", pfUI.media["img:pvp"], 16
    elseif key == "abutton" then return "arrow", nil, 12
    end
  end

  local function Preview(p)
    W.Pin(p, "Preview", "A map in your shape, border and art, with every part around it where it sits in game. Click a part "
      .. "for its settings, drag it to move it, hold Shift and scroll the mouse wheel over it to make it bigger or smaller, "
      .. "right-click it to put it back. Click this bar to fold it away.", function(pp)
      local box = W.Box(pp, 236)
      local holder = CreateFrame("Frame", nil, box)
      holder:SetAllPoints(box)
      holder:SetFrameStrata("FULLSCREEN")
      local base = holder:GetFrameLevel()

      -- the map: art under it, the shape, its border, art above
      local mock = CreateFrame("Button", nil, holder)
      mock:SetWidth(MAPPX)
      mock:SetHeight(MAPPX)
      mock:SetPoint("CENTER", box, "CENTER", 0, 12)
      mock:SetFrameLevel(base + 2)
      local under = CreateFrame("Frame", nil, holder)
      under:SetAllPoints(mock)
      under:SetFrameLevel(base + 1)
      local over = CreateFrame("Frame", nil, holder)
      over:SetAllPoints(mock)
      over:SetFrameLevel(base + 4)
      mock.fill = mock:CreateTexture(nil, "BACKGROUND")
      mock.fill:SetAllPoints(mock)
      mock.shade = mock:CreateTexture(nil, "BORDER")
      mock.shade:SetPoint("CENTER", mock, "CENTER", 0, 0)
      mock.arrow = mock:CreateTexture(nil, "ARTWORK")
      mock.arrow:SetTexture("Interface\\Minimap\\MinimapArrow")
      mock.arrow:SetWidth(22)
      mock.arrow:SetHeight(22)
      mock.arrow:SetPoint("CENTER", mock, "CENTER", 0, 0)
      local frame = CreateFrame("Frame", nil, over)
      frame:SetAllPoints(mock)
      CreateBackdrop(frame)
      local outline = over:CreateTexture(nil, "OVERLAY")
      outline:SetAllPoints(mock)
      local art = {}
      for i = 1, 3 do
        art[i] = { up = over:CreateTexture(nil, "ARTWORK"), down = under:CreateTexture(nil, "BACKGROUND"), angle = 0 }
      end
      MO.mock = mock

      -- the bar under the map (pfUI's Minimap panel)
      local bar = CreateFrame("Button", nil, holder)
      bar:SetFrameLevel(base + 3)
      bar:SetPoint("TOPLEFT", mock, "BOTTOMLEFT", 0, -6)
      bar:SetPoint("TOPRIGHT", mock, "BOTTOMRIGHT", 0, -6)
      CreateBackdrop(bar)
      bar.text = bar:CreateFontString(nil, "OVERLAY")
      bar.text:SetFont(pfUI.font_default, C.global.font_size, "OUTLINE")
      bar.text:SetAllPoints(bar)

      -- one spot per part
      local hots = {}
      MO.hots = hots
      local ar, ag, ab = Accent()
      local function Spot(key, parent, level)
        local h = CreateFrame("Button", nil, parent or holder)
        h:SetFrameLevel(base + (level or 6))
        h.key = key
        h.hl = h:CreateTexture(nil, "HIGHLIGHT")
        h.hl:SetAllPoints(h)
        h.hl:SetTexture("Interface\\Buttons\\WHITE8X8")
        h.hl:SetVertexColor(ar, ag, ab, .3)
        h:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        h:EnableMouseWheel(true)
        hots[key] = h
        return h
      end
      for _, part in ipairs(map.PARTS or {}) do
        local h = Spot(part.key)
        h.part = part
        local kind = Sample(part.key)
        if kind == "text" then
          h.text = h:CreateFontString(nil, "OVERLAY")
          h.text:SetPoint("CENTER", h, "CENTER", 0, 0)
        elseif kind == "icon" then
          h.icon = h:CreateTexture(nil, "ARTWORK")
          h.icon:SetAllPoints(h)
        else
          h.icon = W.Arrow(h, 12, "down")
          h.icon:SetPoint("CENTER", h, "CENTER", 0, 0)
        end
      end
      hots.map, hots.bar = mock, bar
      mock.key, bar.key = "map", "bar"
      mock:RegisterForClicks("LeftButtonUp", "RightButtonUp")
      bar:RegisterForClicks("LeftButtonUp", "RightButtonUp")
      mock:EnableMouseWheel(true)

      local function Scale()
        local size = Minimap:GetWidth()
        if not size or size <= 0 then size = tonumber(MM().size) or 140 end
        return MAPPX / size
      end

      local function Layout()
        local s = S()
        local f = Scale()
        -- shape, border, art
        local shape = s.shape or "square"
        mock.fill:SetTexture(ShapeArt(shape))
        mock.fill:SetVertexColor(.42, .36, .23, 1)
        mock.shade:SetTexture(ShapeArt(shape))
        mock.shade:SetVertexColor(.5, .44, .3, 1)
        mock.shade:SetWidth(MAPPX * .7)
        mock.shade:SetHeight(MAPPX * .7)
        if s.border == "pfui" and shape == "square" then frame:Show() else frame:Hide() end
        if s.border == "outline" then
          outline:SetTexture(pfUI.media["img:minimap\\outline-" .. shape])
          local r, g, b, a = Col(s.outlinecolor)
          if s.outlineaccent == "1" then r, g, b = Accent() end
          outline:SetVertexColor(r, g, b, a)
          outline:Show()
        else
          outline:Hide()
        end
        for i = 1, 3 do
          local l = art[i]
          local tex = s["art" .. i]
          l.up:Hide()
          l.down:Hide()
          l.tex, l.speed = nil, 0
          if tex and tex ~= "none" then
            local t = s["art" .. i .. "above"] == "1" and l.up or l.down
            local px = MAPPX * (tonumber(s["art" .. i .. "size"]) or 130) / 100
            t:SetTexture(tex)
            t:ClearAllPoints()
            t:SetPoint("CENTER", mock, "CENTER", 0, 0)
            t:SetWidth(px)
            t:SetHeight(px)
            t:SetVertexColor(Col(s["art" .. i .. "color"]))
            t:SetBlendMode(s["art" .. i .. "blend"] == "BLEND" and "BLEND" or "ADD")
            Turn(t, math.rad(l.angle))
            t:Show()
            l.tex, l.speed = t, tonumber(s["art" .. i .. "speed"]) or 0
          end
        end
        -- the bar under the map
        bar:SetHeight(math.max(10, C.global.font_size * 1.5 * f))
        bar.text:SetText((GetMinimapZoneText and GetMinimapZoneText() ~= "" and GetMinimapZoneText()) or "The Barrens")
        bar:SetAlpha(Mode("bar") == "hide" and .35 or 1)
        -- every part where it sits, as big as it is
        for _, part in ipairs(map.PARTS or {}) do
          local h = hots[part.key]
          local kind, what, extra = Sample(part.key)
          local sc = map.PartScale(part) * f
          if kind == "text" then
            h.text:SetFont(pfUI.font_default, math.max(6, (C.global.font_size + (extra or 0)) * sc), "OUTLINE")
            h.text:SetText(what)
            h:SetWidth(math.max(12, (h.text:GetStringWidth() or 30) + 4))
            h:SetHeight(math.max(8, (C.global.font_size + (extra or 0)) * sc + 4))
          elseif kind == "icon" then
            local real = part.get()
            local w = real and real:GetWidth() or 0
            if not w or w <= 0 or w > 64 then w = extra end
            h.icon:SetTexture(what)
            h:SetWidth(math.max(6, w * sc))
            h:SetHeight(math.max(6, w * sc))
          else
            h:SetWidth(math.max(8, extra * sc))
            h:SetHeight(math.max(8, extra * sc))
            h.icon:SetWidth(math.max(6, 10 * sc))
            h.icon:SetHeight(math.max(6, 10 * sc))
          end
          local pt = map.PartPoint(part)
          local x, y = map.PartOffset(part)
          h:ClearAllPoints()
          h:SetPoint(pt, mock, pt, x * f, y * f)
          local mode = Mode(part.key)
          h:SetAlpha(mode == "hide" and .3 or (mode == "hover" and .7 or 1))
        end
      end
      MO.Layout = Layout

      -- mouse: click = card, drag = move, Shift + wheel = size, right-click = back
      local function Tip(h)
        GameTooltip:SetOwner(h, "ANCHOR_TOP")
        local key = h.key
        if key == "map" then
          GameTooltip:AddLine("The map")
          GameTooltip:AddLine("Click: shape and border", 1, 1, 1)
          GameTooltip:AddLine("Shift + mouse wheel: bigger / smaller", 1, 1, 1)
          GameTooltip:AddLine("Right-click: size back to 140 px", 1, 1, 1)
          GameTooltip:AddLine("Move the map itself with Move frames", .7, .7, .7)
        elseif key == "bar" then
          GameTooltip:AddLine("Bar under the map")
          GameTooltip:AddLine("Click: its settings", 1, 1, 1)
          GameTooltip:AddLine("Shows: " .. (Mode("bar") == "hide" and "hidden" or "always"), .7, .7, .7)
          GameTooltip:AddLine("Move it with Move frames", .7, .7, .7)
        else
          GameTooltip:AddLine(GO[key] and GO[key][2] or key)
          GameTooltip:AddLine("Click: its settings", 1, 1, 1)
          GameTooltip:AddLine("Drag: move it", 1, 1, 1)
          GameTooltip:AddLine("Shift + mouse wheel: bigger / smaller", 1, 1, 1)
          GameTooltip:AddLine("Right-click: put it back", 1, 1, 1)
          GameTooltip:AddLine("Shows: " .. (MODEWORD[Mode(key)] or "always"), .7, .7, .7)
        end
        GameTooltip:Show()
      end
      local function Wire(h)
        h:SetScript("OnEnter", function() Tip(this) end)
        h:SetScript("OnLeave", function() GameTooltip:Hide() end)
        h:SetScript("OnMouseDown", function()
          if arg1 == "RightButton" or not this.part then return end
          local cx, cy = GetCursorPosition()
          local x, y = map.PartOffset(this.part)
          this.down = { cx, cy, x, y }
          this.moved = nil
          MO.dragging = this
        end)
        h:SetScript("OnMouseUp", function()
          local moved = this.moved
          this.down, this.moved = nil, nil
          MO.dragging = nil
          if moved then O:Refresh() end
        end)
        h:SetScript("OnClick", function()
          if this.dragged then this.dragged = nil return end
          local key = this.key
          if arg1 == "RightButton" then
            if key == "map" then
              MM().size = "140"
              MapSize()
            elseif key ~= "bar" then
              map.ResetPart(key)
            end
            Layout()
            O:Refresh()
            return
          end
          MO.Open(key)
        end)
        h:SetScript("OnMouseWheel", function()
          local key = this.key
          if IsShiftKeyDown() and key ~= "bar" then
            if key == "map" then
              MM().size = tostring(math.max(80, math.min(400, (tonumber(MM().size) or 140) + 5 * (arg1 or 0))))
              MapSize()
            else
              map.SizePart(key, (tonumber(S()[key .. "scale"]) or 100) + 10 * (arg1 or 0))
            end
            Layout()
            O:Refresh()
          elseif pfUI.plates and pfUI.plates.PassWheel then
            pfUI.plates.PassWheel(this)
          end
        end)
      end
      for _, h in pairs(hots) do Wire(h) end

      holder:SetScript("OnUpdate", function()
        -- dragging: the part follows the mouse (in the map's units)
        local h = MO.dragging
        if h and h.down then
          local d = h.down
          local x, y = GetCursorPosition()
          local k = (holder:GetEffectiveScale() or 1) * Scale()
          local dx, dy = (x - d[1]) / k, (y - d[2]) / k
          if h.moved or math.abs(dx) + math.abs(dy) >= 3 / Scale() then
            h.moved, h.dragged = true, true
            map.MovePart(h.key, d[3] + dx, d[4] + dy)
            Layout()
          end
        end
        -- spin the art
        for i = 1, 3 do
          local l = art[i]
          if l.tex and l.speed ~= 0 then
            l.angle = math.mod(l.angle + l.speed * (arg1 or 0), 360)
            Turn(l.tex, math.rad(l.angle))
          end
        end
        if (this.tick or 0) > GetTime() then return end
        this.tick = GetTime() + .2
        Layout()
      end)
      Layout()

      -- what the mouse does, on screen
      local band = W.Row(pp, 20, 0, 3)
      local bg = band:CreateTexture(nil, "BACKGROUND")
      bg:SetAllPoints(band)
      bg:SetTexture("Interface\\Buttons\\WHITE8X8")
      bg:SetVertexColor(ar, ag, ab, .22)
      local how = band:CreateFontString(nil, "OVERLAY")
      how:SetFont(W.UIFont(), 11, "OUTLINE")
      how:SetPoint("LEFT", band, "LEFT", 12, 0)
      local k = string.format("|cff%02x%02x%02x", math.floor(ar * 255), math.floor(ag * 255), math.floor(ab * 255))
      how:SetText(k .. "Click|r a part  its settings     " .. k .. "Drag|r  move it     " .. k .. "Shift + wheel|r  bigger / smaller     "
        .. k .. "Right-click|r  put it back")
      W.Buttons(pp, {
        { "Put every part back", function()
          for _, part in ipairs(map.PARTS or {}) do map.ResetPart(part.key) end
          Layout()
          O:Refresh()
        end, 160, "Every button and text around the map goes back to pfUI's own place and size." },
        { "Move frames", function() if pfUI.unlock and pfUI.unlock.Show then pfUI.unlock:Show() end end, 120,
          "Move the map itself, the bar under it and the addon buttons panel." },
      })
    end)
  end

  -- ---------------------------------------------------------------- map

  -- the one-click looks; the one in use is lit
  local function Looks(p)
    local list = map.PRESETS or {}
    local btns = {}
    local rows = {}
    for r = 1, math.ceil(table.getn(list) / 4) do rows[r] = W.Row(p, 24, 0, 6) end
    local function Current()
      local s = S()
      for _, pr in ipairs(list) do
        local same = true
        for k, v in pairs(pr[3]) do if s[k] ~= v then same = false end end
        if same then return pr[1] end
      end
    end
    local function Paint()
      local cur = Current()
      for _, b in ipairs(btns) do W.Pick(b, b.key == cur) end
    end
    for i, pr in ipairs(list) do
      local b = W.Button(rows[math.floor((i - 1) / 4) + 1], pr[2], 160, 22)
      b:SetPoint("LEFT", b:GetParent(), "LEFT", math.mod(i - 1, 4) * 166, 0)
      b.key = pr[1]
      b:SetScript("OnClick", function()
        map.ApplyPreset(this.key)
        Paint()
        O:Refresh()
      end)
      W.Tip(b, pr[2], "Shape, border and art in one click. Buttons, sizes and places stay as they are.")
      btns[i] = b
    end
    if rows[1] then
      rows[1]:SetScript("OnUpdate", function()
        if (this.tick or 0) > GetTime() then return end
        this.tick = GetTime() + .5
        Paint()
      end)
    end
    Paint()
  end

  local function BuildMap(p)
    W.Heading(p, "Minimap", { about = "The map's shape, border, size and looks. Buttons and texts around it are on "
      .. "\"Buttons and text\", the spell art around it on \"Art\". Click any part of the preview to jump to its card." })
    Preview(p)
    W.Card(p, "Looks", { tip = "Ready-made styles: shape, border and art in one click." })
    Looks(p)
    W.Card(p, "Shape and border", { tip = "Any shape works with every part around the map: move them to fit it." })
    Drop(p, "Shape", "The map's outline. Round uses the game's own mask.", SHAPES, S, "shape")
    Drop(p, "Border", "pfUI's frame works on the square map only.", {
      { key = "pfui", label = "pfUI frame (square only)" }, { key = "outline", label = "Outline of the shape" }, { key = "none", label = "None" },
    }, S, "border")
    Color(p, "Outline colour", nil, S, "outlinecolor")
    Chk(p, "Accent colour outline", "The outline takes pfUI Octo's accent colour.", S, "outlineaccent")
    W.Card(p, "Size and arrow")
    Sld(p, "Map size", "Or Shift + wheel over the map in the preview.", 80, 400, 5, MM, "size", Px, MapSize)
    Sld(p, "Your arrow", "The size of your own arrow on the map.", .5, 3, .1, MM, "arrowscale", function(v) return math.floor(v * 100 + .5) .. "%" end, MapSize)
    W.Card(p, "Opacity and zoom")
    Sld(p, "Opacity", nil, .1, 1, .05, S, "alpha", function(v) return math.floor(v * 100 + .5) .. "%" end)
    Sld(p, "Opacity in combat", nil, .1, 1, .05, S, "combatalpha", function(v) return math.floor(v * 100 + .5) .. "%" end)
    Sld(p, "Zoom back out after", "The map zooms all the way out after this long (0 = never).", 0, 60, 1, S, "autozoom", Sec)
  end

  -- ---------------------------------------------------------------- art

  local ART = {
    { "none", "None" },
    { "Spells\\AuraRune256", "Rune circle" }, { "Spells\\AuraRune256b", "Rune circle 2" },
    { "Spells\\AuraRune_A", "Rune circle A" }, { "Spells\\AuraRune_B", "Rune circle B" },
    { "Spells\\AuraRune_C", "Rune circle C" }, { "Spells\\AuraRune_D", "Rune circle D" },
    { "Spells\\Holy_Rune_128", "Holy rune" }, { "Spells\\Holy_Rune1", "Holy rune 2" },
    { "Spells\\Ice_Rune_128", "Frost rune" }, { "Spells\\Fire_Rune_128", "Fire rune" },
    { "Spells\\Nature_Rune_128", "Nature rune" }, { "Spells\\InnerFire_Rune_128", "Inner Fire rune" },
    { "Spells\\DemonRune6", "Demon rune" }, { "Spells\\DemonRune7", "Demon rune 2" },
    { "Spells\\Death_Rune", "Death rune" }, { "Spells\\starrune", "Star rune" },
    { "Spells\\Circle", "Circle" }, { "Spells\\DoubleRing128", "Double ring" },
    { "Spells\\WhiteRingThin128", "Thin ring" }, { "Spells\\WhiteRingFat128", "Fat ring" },
    { "Spells\\FireRing128", "Fire ring" }, { "Spells\\T_VFX_Ring_Bow_A", "Bow ring" },
    { "Spells\\GENERICGLOW64", "Soft glow" }, { "Spells\\Blue_GlowB", "Blue glow" },
    { "Spells\\GREEN_GLOW2", "Green glow" }, { "Spells\\Shockwave_Ice1", "Frost wave" },
    { "Spells\\ShockwaveWater1", "Water wave" }, { "Spells\\STARBURSTS", "Starbursts" },
  }
  local function ArtList()
    local out = {}
    for _, a in ipairs(ART) do
      table.insert(out, { key = a[1], label = a[2], icon = a[1] ~= "none" and a[1] or nil })
    end
    return out
  end

  local function BuildArt(p)
    W.Heading(p, "Art", { about = "Up to three layers of the game's spell art around the map: rune circles, rings and "
      .. "glows, each with its own size, colour and spin, under or over the map." })
    Preview(p)
    for i = 1, 3 do
      local n = i
      W.Card(p, "Art layer " .. n, { tip = "Pick None to switch this layer off." })
      Drop(p, "Art", "Each choice shows its picture.", ArtList(), S, "art" .. n)
      Chk(p, "Over the map", "Off: under the map, showing only round its edge.", S, "art" .. n .. "above")
      Color(p, "Colour and opacity", nil, S, "art" .. n .. "color")
      Drop(p, "Blend", "Glow brightens what is under it; Normal paints over it.",
        { { key = "ADD", label = "Glow (add)" }, { key = "BLEND", label = "Normal" } }, S, "art" .. n .. "blend")
      Sld(p, "Size", "% of the map's size.", 50, 250, 5, S, "art" .. n .. "size", Pct)
      Sld(p, "Spin", "Degrees a second; minus turns the other way.", -90, 90, 1, S, "art" .. n .. "speed", function(v) return v .. " / s" end)
    end
  end

  -- ---------------------------------------------------------------- buttons and text

  local MODES = { { key = "show", label = "Always" }, { key = "hover", label = "Mouse over the map" }, { key = "hide", label = "Never" } }
  local TEXTMODES = { { key = "on", label = "Always" }, { key = "mouseover", label = "Mouse over the map" }, { key = "off", label = "Never" } }

  -- size and place, the same on every part's card
  local function Place(p, key)
    local part = map.Part and map.Part(key)
    if not part then return end
    W.Slider(p, "Size", "Or Shift + wheel over it in the preview.", 50, 250, 5,
      function() return tonumber(S()[key .. "scale"]) or 100 end, function(v) map.SizePart(key, v) end, Pct)
    W.Slider(p, "Left / right", "Or drag it in the preview.", -150, 150, 1,
      function() local x = map.PartOffset(part) return x end,
      function(v) local _, y = map.PartOffset(part) map.MovePart(key, v, y) end, Px)
    W.Slider(p, "Up / down", nil, -150, 150, 1,
      function() local _, y = map.PartOffset(part) return y end,
      function(v) local x = map.PartOffset(part) map.MovePart(key, x, v) end, Px)
    W.Buttons(p, { { "Put it back", function() map.ResetPart(key) O:Refresh() end, 110, "pfUI's own place and size." } })
  end

  local function BuildParts(p)
    W.Heading(p, "Buttons and text", { about = "Everything on and around the map, one card each: when it shows, how big "
      .. "it is and where it sits. Drag them in the preview to fit any shape." })
    Preview(p)
    W.Card(p, "Zone name", { tip = "The zone's name on the map, coloured by PvP status." })
    Drop(p, "Shows", nil, TEXTMODES, MM, "zonetext")
    Place(p, "zone")
    W.Card(p, "Coordinates", { tip = "Where you stand on the zone's map." })
    Drop(p, "Shows", nil, TEXTMODES, MM, "coordstext")
    Drop(p, "Corner", "Picking a corner puts the coordinates in it.", DD("minimap_cords_position"), MM, "coordsloc", function()
      map.ResetPart("coords")
      O:Refresh()
    end)
    Place(p, "coords")
    W.Card(p, "Clock", { tip = "Hover it in game for server and local time." })
    Drop(p, "Shows", nil, MODES, S, "clock")
    Drop(p, "Time", nil, { { key = "local", label = "Local time" }, { key = "server", label = "Server time" } }, S, "clocktime")
    Drop(p, "Edge", "Top or bottom of the map; drag it for anywhere else.", { { key = "bottom", label = "Bottom" }, { key = "top", label = "Top" } }, S, "clockpos", function()
      map.ResetPart("clock")
      map.ResetPart("ping")
      O:Refresh()
    end)
    Place(p, "clock")
    W.Card(p, "Who pinged", { on = { function() return S().ping == "1" end, function(v) S().ping = v and "1" or "0" U() end,
      "The name of whoever clicked the map, for three seconds." } })
    Place(p, "ping")
    W.Card(p, "Tracking", { tip = "Your tracking spell; click it in game to pick another." })
    Drop(p, "Shows", nil, MODES, S, "tracking")
    Chk(p, "Show when nothing is tracked", "Pulses when no tracking is on. After a reload.", MM, "tracking_pulse", function() end)
    Place(p, "tracking")
    W.Card(p, "Mail", { tip = "Shows when you have mail waiting." })
    Drop(p, "Shows", nil, MODES, S, "mail")
    Place(p, "mail")
    W.Card(p, "Battleground", { tip = "The battleground queue eye: click for the score, right-click for the menu." })
    Drop(p, "Shows", nil, MODES, S, "battlefield")
    Place(p, "battlefield")
    W.Card(p, "PvP icon", { on = { function() return C.unitframes.player.showPVPMinimap == "1" end,
      function(v) C.unitframes.player.showPVPMinimap = v and "1" or "0" U() end, "A PvP mark on the map while you are flagged." } })
    Place(p, "pvp")
    W.Card(p, "Addon buttons", { tip = "The little arrow on the map opens a panel holding every addon's minimap button." })
    Drop(p, "Arrow shows", nil, MODES, S, "abutton")
    Place(p, "abutton")
    local function ABU() if pfUI.addonbuttons and pfUI.addonbuttons.UpdateConfig then pfUI.addonbuttons:UpdateConfig() end U() end
    Chk(p, "Collect addon buttons", "Addon minimap buttons go into the panel. After a reload.", AB, "enable", function() end)
    Drop(p, "Panel side", "Where the panel opens; the arrow moves to that edge unless you dragged it.", DD("addonbuttons_position"), AB, "position", function()
      map.ResetPart("abutton")
      ABU()
      O:Refresh()
    end)
    Chk(p, "Open at login", nil, AB, "showdefault", ABU)
    Chk(p, "Close in combat", nil, AB, "hideincombat", ABU)
    Sld(p, "Buttons a row", nil, 1, 20, 1, AB, "rowsize", nil, ABU)
    Sld(p, "Gap", nil, 0, 10, 1, AB, "spacing", Px, ABU)
    W.Card(p, "Bar under the map", { tip = "pfUI's panel under the map. Move it with Move frames." })
    Drop(p, "Shows", "What the bar says. Disable hides it. After a reload.", DD("panel_values"), function() return C.panel.other end, "minimap", function() end)
  end

  -- (replaced first: AddPage rebuilds the topic list, which must not see
  -- pfUI's own Minimap category under the same name)
  O.replaced[T["Minimap"]] = true
  O:AddPage("Minimap", "mmmap", "Map", BuildMap)
  O:AddPage("Minimap", "mmart", "Art", BuildArt)
  O:AddPage("Minimap", "mmparts", "Buttons and text", BuildParts)
end)

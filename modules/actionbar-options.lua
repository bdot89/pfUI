pfUI:RegisterModule("actionbar-options", "vanilla:tbc", function ()
  -- pfUI Octo :: the Action Bars section (user, 22 Oct 2026: "the menu inside
  -- our addon should be SIMPLE and CLEAN and PROFESSIONAL"). Five pages:
  -- General (looks, behaviour, highlights), Bars (a tab per bar: layout,
  -- visibility, text), Buttons and text, Paging, Gryphons. Every setting of
  -- pfUI's old Actionbar pages is here (that category is hidden), plus the
  -- extras of actionbar-octo.lua. A pinned preview on General and Bars: your
  -- real bars on a small copy of the screen (click one for its tab, Shift +
  -- wheel for its button size) and a sample button with the look.
  local AB = pfUI.barsOcto
  local OU = pfUI.octoui
  local W = OU and OU.W
  local O = OU and OU.Options
  if not AB or not W or not O or not O.AddPage then return end
  local BUILD = {}
  local PfChk, PfSld = O.PfChk, O.PfSld

  local TAB = { cur = 1 }
  local function G() return C.bars end
  local function BAR() return C.bars["bar" .. TAB.cur] end
  local function GRY() return C.bars.gryphons end
  local function U() pfUI.bars:UpdateConfig() end
  local function UG() if pfUI.gryphons and pfUI.gryphons.UpdateConfig then pfUI.gryphons:UpdateConfig() end end
  local function Px(v) return v .. " px" end
  local function Pct(v) return math.floor(v * 100 + .5) .. "%" end
  local function Sec(v) return v .. " s" end

  local function Chk(p, label, desc, group, key, after) return PfChk(p, label, desc, group, key, after or U) end
  local function Sld(p, label, desc, min, max, step, group, key, fmt, after) return PfSld(p, label, desc, min, max, step, group, key, after or U, fmt) end
  local function Drop(p, label, desc, options, group, key, after)
    return W.Dropdown(p, label, desc, options, function() return group()[key] end, function(v)
      group()[key] = v
      ;(after or U)()
    end)
  end
  local function Color(p, label, desc, group, key, after)
    return W.Color(p, label, desc, function()
      local r, g, b, a = GetStringColor(group()[key] or "1,1,1,1")
      return tonumber(r) or 1, tonumber(g) or 1, tonumber(b) or 1, tonumber(a) or 1
    end, function(r, g, b, a)
      group()[key] = string.format("%.2f,%.2f,%.2f,%.2f", r, g, b, a or 1)
      ;(after or U)()
    end)
  end
  -- pfUI's "key:label" dropdown lists
  local function DD(name)
    local out = {}
    local list = pfUI.gui and pfUI.gui.dropdowns and pfUI.gui.dropdowns[name]
    if type(list) == "function" then list = list() end
    for _, e in ipairs(list or {}) do
      local _, _, k, l = string.find(e, "^(.-):(.*)$")
      if k then table.insert(out, { key = k, label = l }) end
    end
    return out
  end

  -- ---------------------------------------------------------------- preview

  -- A small copy of the screen with your real bars and their icons, and a
  -- sample button with the look (skin, zoom, letters).
  local function Mini(box)
    local M = { rects = {} }
    local BW, BH = box:GetWidth() or 640, box:GetHeight() or 190
    local sideW = 170
    -- the view: the part of the screen your bars are in, zoomed to fill the
    -- room left of the sample button (user, 22 Oct 2026: a whole-screen copy
    -- left the bars tiny). Worked out again on every refresh.
    local VW, VH = BW - sideW - 18, BH - 12
    local scr = CreateFrame("Frame", nil, box)
    scr:SetWidth(VW)
    scr:SetHeight(VH)
    scr:SetPoint("LEFT", box, "LEFT", 6, 0)
    local bg = scr:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(scr)
    bg:SetTexture("Interface\\Buttons\\WHITE8X8")
    bg:SetGradient("VERTICAL", .05, .07, .09, .12, .15, .19)
    local ui = UIParent:GetEffectiveScale() or 1
    local k, ox, oy = 1, 0, 0

    local function Rect(i)
      local r = M.rects[i]
      if r then return r end
      r = CreateFrame("Button", nil, scr)
      r.i = i
      r:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1,
                      insets = { left = 0, right = 0, top = 0, bottom = 0 } })
      r:SetBackdropColor(0, 0, 0, .3)
      r.icons = {}
      r.hl = r:CreateTexture(nil, "OVERLAY")
      r.hl:SetAllPoints(r)
      r.hl:SetTexture("Interface\\Buttons\\WHITE8X8")
      r.hl:SetVertexColor(1, 1, 1, .15)
      r.hl:Hide()
      r:SetScript("OnEnter", function()
        this.hl:Show()
        GameTooltip:SetOwner(this, "ANCHOR_TOP")
        GameTooltip:AddLine(AB.NAMES[this.i])
        GameTooltip:AddLine("Click: its settings", 1, 1, 1)
        GameTooltip:AddLine("Shift + mouse wheel: bigger / smaller buttons", 1, 1, 1)
        GameTooltip:Show()
      end)
      r:SetScript("OnLeave", function() this.hl:Hide() GameTooltip:Hide() end)
      r:SetScript("OnClick", function()
        TAB.cur = this.i
        O:Open("abbars")
        O:Refresh()
      end)
      r:EnableMouseWheel(true)
      r:SetScript("OnMouseWheel", function()
        if IsShiftKeyDown() then
          local d = C.bars["bar" .. this.i]
          d.icon_size = tostring(math.max(10, math.min(64, (tonumber(d.icon_size) or 20) + (arg1 or 0))))
          U()
        elseif pfUI.plates and pfUI.plates.PassWheel then
          pfUI.plates.PassWheel(this)
        end
      end)
      M.rects[i] = r
      return r
    end

    -- a frame's place on screen, in UIParent's units
    local function Box(region)
      local l, t, r, b = region:GetLeft(), region:GetTop(), region:GetRight(), region:GetBottom()
      if not (l and t and r and b) then return end
      local s = (region:GetEffectiveScale() or 1) / ui
      return l * s, t * s, r * s, b * s
    end

    -- where it sits in the view
    local function Place(f, region)
      local l, t, r, b = Box(region)
      if not l then return end
      f:ClearAllPoints()
      f:SetPoint("TOPLEFT", scr, "TOPLEFT", (l - ox) * k, (t - oy) * k)
      f:SetWidth(math.max(2, (r - l) * k))
      f:SetHeight(math.max(2, (t - b) * k))
      return true
    end

    -- the view frames every shown bar with a margin, centred
    local function Frame()
      local ul, ut, ur, ub
      for _, i in ipairs(AB.ORDER) do
        local bar = pfUI.bars[i]
        if bar and bar:IsShown() then
          local l, t, r, b = Box(bar)
          if l then
            ul, ur = math.min(ul or l, l), math.max(ur or r, r)
            ut, ub = math.max(ut or t, t), math.min(ub or b, b)
          end
        end
      end
      if not ul then return end
      local m = 16
      local w, h = (ur - ul) + 2 * m, (ut - ub) + 2 * m
      k = math.min(VW / w, VH / h, 1.6)
      -- centre what the bars cover in the view
      ox = ul - m - (VW / k - w) / 2
      oy = ut + m + (VH / k - h) / 2
    end

    function M.Refresh()
      Frame()
      local ar, ag, ab = .2, .55, .9
      if GetAccentColor then ar, ag, ab = GetAccentColor() end
      for _, i in ipairs(AB.ORDER) do
        local bar = pfUI.bars[i]
        local r = Rect(i)
        if bar and bar:IsShown() and Place(r, bar) then
          r:SetBackdropBorderColor(ar, ag, ab, (TAB.cur == i) and 1 or .45)
          for j = 1, 12 do
            local btn = bar[j]
            local ic = r.icons[j]
            if btn and btn:IsShown() then
              if not ic then
                ic = r:CreateTexture(nil, "ARTWORK")
                r.icons[j] = ic
              end
              local tex = btn.icon and btn.icon:GetTexture()
              if tex and tex ~= "" then ic:SetTexture(tex) ic:SetTexCoord(.08, .92, .08, .92) else ic:SetTexture(.15, .15, .15, .8) end
              if Place(ic, btn) then ic:Show() else ic:Hide() end
              -- (icons are placed against the screen: re-anchor inside the bar box)
            elseif ic then
              ic:Hide()
            end
          end
          r:Show()
        else
          r:Hide()
        end
      end
    end

    -- the sample button, with the look
    local side = CreateFrame("Frame", nil, box)
    side:SetWidth(sideW)
    side:SetHeight(BH - 10)
    side:SetPoint("RIGHT", box, "RIGHT", -6, 0)
    local cap = side:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    cap:SetPoint("TOP", side, "TOP", 0, -4)
    cap:SetText("Sample button")
    cap:SetTextColor(.6, .6, .6)
    local b = CreateFrame("Frame", nil, side)
    b:SetWidth(76)
    b:SetHeight(76)
    b:SetPoint("CENTER", side, "CENTER", 0, 2)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints(b)
    CreateBackdrop(b)
    -- each text in its own corner, as on a real button
    b.hotkey = b:CreateFontString(nil, "OVERLAY")
    b.hotkey:SetPoint("TOPRIGHT", b, "TOPRIGHT", -3, -3)
    b.macro = b:CreateFontString(nil, "OVERLAY")
    b.macro:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 3, 3)
    b.count = b:CreateFontString(nil, "OVERLAY")
    b.count:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -3, 3)
    b.cd = b:CreateFontString(nil, "OVERLAY")
    b.cd:SetPoint("CENTER", b, "CENTER", 0, 2)
    local note = side:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    note:SetPoint("BOTTOM", side, "BOTTOM", 0, 6)
    note:SetWidth(sideW - 6)
    note:SetText("key, macro, count and cooldown text")
    note:SetTextColor(.5, .5, .5)
    local function Text(fs, size, color, text)
      local font = pfUI.media[C.bars.font] or pfUI.font_default
      -- (the sample is about twice a real button: the texts grow with it)
      fs:SetFont(font, (tonumber(size) or 10) * 1.5, "OUTLINE")
      local r, g, bb = GetStringColor(color or "1,1,1,1")
      fs:SetTextColor(tonumber(r) or 1, tonumber(g) or 1, tonumber(bb) or 1)
      fs:SetText(text)
    end
    function M.Sample()
      local first = pfUI.bars[1] and pfUI.bars[1][1]
      local tex = first and first.icon and first.icon:GetTexture()
      b.icon:SetTexture((tex and tex ~= "") and tex or "Interface\\Icons\\Spell_Fire_FlameBolt")
      AB.Zoom(b)
      AB.Skin(b)
      Text(b.hotkey, C.bars.bind_size, C.bars.bind_color, "S1")
      Text(b.macro, C.bars.macro_size, C.bars.macro_color, "Mac")
      Text(b.count, C.bars.count_size, C.bars.count_color, "20")
      Text(b.cd, C.bars.cd_size, "1,1,1,1", "12")
    end

    box:SetScript("OnUpdate", function()
      if (this.tick or 0) > GetTime() then return end
      this.tick = GetTime() + .5
      M.Refresh()
      M.Sample()
    end)
    M.Refresh()
    M.Sample()
    return M
  end

  local function Preview(p)
    W.Pin(p, "Preview", "Your bars on a small copy of the screen, and a sample button with the look. Click a bar for its "
      .. "settings, hold Shift and scroll the mouse wheel over it for bigger or smaller buttons. Move frames (top) "
      .. "moves the bars themselves. Click this bar to fold it away.", function(p)
      local mini = Mini(W.Box(p, 150))
      table.insert(p.items, { Refresh = function() mini.Refresh() mini.Sample() end })
      local band = W.Row(p, 20, 0, 3)
      local bg = band:CreateTexture(nil, "BACKGROUND")
      bg:SetAllPoints(band)
      bg:SetTexture("Interface\\Buttons\\WHITE8X8")
      local ar, ag, ab = .2, .55, .9
      if GetAccentColor then ar, ag, ab = GetAccentColor() end
      bg:SetVertexColor(ar, ag, ab, .22)
      local how = band:CreateFontString(nil, "OVERLAY")
      how:SetFont(W.UIFont(), 11, "OUTLINE")
      how:SetPoint("LEFT", band, "LEFT", 12, 0)
      local key = string.format("|cff%02x%02x%02x", math.floor(ar * 255), math.floor(ag * 255), math.floor(ab * 255))
      how:SetText(key .. "Click|r a bar  its settings     " .. key .. "Shift + wheel|r  button size     " .. key .. "Move frames|r  move bars")
    end)
  end

  -- the looks, three to a row; the picked one is lit
  local function Looks(p)
    local btns, rows = {}, {}
    local n = table.getn(AB.PRESETS)
    for r = 1, math.ceil(n / 3) do rows[r] = W.Row(p, 24, 0, 6) end
    local function Paint()
      local cur = AB.CurrentLook()
      for _, b in ipairs(btns) do W.Pick(b, b.key == cur) end
    end
    for i, pr in ipairs(AB.PRESETS) do
      local b = W.Button(rows[math.floor((i - 1) / 3) + 1], pr[2], 200, 22)
      b:SetPoint("LEFT", b:GetParent(), "LEFT", math.mod(i - 1, 3) * 206, 0)
      b.key = pr[1]
      b:SetScript("OnClick", function()
        AB.ApplyPreset(this.key)
        Paint()
        O:Refresh()
      end)
      W.Tip(b, pr[2], "Button border, icon zoom, spacing, bar backgrounds and empty slots in one click.")
      btns[i] = b
    end
    W.Live(p, function()
      local _, label = AB.CurrentLook()
      return label and ("Look: |cffffffff" .. label .. "|r") or "Look: |cffffffffyour own mix|r"
    end)
    rows[1]:SetScript("OnUpdate", function()
      if (this.tick or 0) > GetTime() then return end
      this.tick = GetTime() + .5
      Paint()
    end)
    Paint()
  end

  -- ---------------------------------------------------------------- general

  BUILD.abgeneral = function(p)
    W.Heading(p, "Action bars", { about = "Your action bars: how they look, how buttons behave, and what lights up. "
      .. "Each bar's layout and when it shows are on Bars; letters and button borders on Buttons and text." })
    Preview(p)
    W.Card(p, "Looks", { tip = "Ready-made styles for every bar." })
    Looks(p)
    W.Card(p, "Behaviour")
    Chk(p, "Cast on key down", "Actions go off when the key goes down, not when it comes back up.", G, "keydown")
    Chk(p, "Lock the bars", "Buttons cannot be dragged off.", function() return _G end, "LOCK_ACTIONBAR")
    Chk(p, "Self-cast with Alt", nil, G, "altself")
    Chk(p, "Self-cast with right-click", nil, G, "rightself")
    Chk(p, "Shift-drag always", "Shift lets you drag a button even when the bars are locked.", G, "shiftdrag")
    Chk(p, "Read spells in macros", "Macros show the cooldown, range and icon of the spell they cast.", G, "macroscan")
    Chk(p, "Reagent count", "How many reagents you carry, on spells that use them.", G, "reagents")
    Chk(p, "Animate hidden bars", "The press animation shows even on bars that are faded out.", G, "animalways")
    Drop(p, "Press animation", nil, DD("actionbuttonanimations"), G, "animation")
    Drop(p, "Animate on", nil, DD("animationmode"), G, "animmode")
    W.Card(p, "Highlights", { tip = "Buttons change colour when the action cannot be used right now." })
    Chk(p, "Out of range", nil, G, "glowrange")
    Color(p, "Colour", nil, G, "rangecolor")
    Chk(p, "Out of mana", nil, G, "showoom")
    Color(p, "Colour", nil, G, "oomcolor")
    Chk(p, "Not usable", nil, G, "showna")
    Color(p, "Colour", nil, G, "nacolor")
    Chk(p, "Equipped items", nil, G, "showequipped")
    Color(p, "Colour", nil, G, "eqcolor")
  end

  -- ---------------------------------------------------------------- bars

  local VIS_COMBAT = { { key = "any", label = "Always" }, { key = "combat", label = "Only in combat" }, { key = "nocombat", label = "Only out of combat" } }
  local VIS_PET = { { key = "any", label = "Always" }, { key = "pet", label = "Only with a pet" }, { key = "nopet", label = "Only without a pet" } }
  local VIS_TARGET = { { key = "any", label = "Always" }, { key = "target", label = "Only with a target" } }
  local VIS_STEALTH = { { key = "any", label = "Always" }, { key = "hide", label = "Hide while stealthed" } }

  BUILD.abbars = function(p)
    W.Heading(p, "Bars", { about = "Pick a bar, then its layout, when it shows, and its text. Move frames (top) moves the bars." })
    Preview(p)
    -- the bars as tabs, two rows of six
    local rows = { W.Row(p, 24, 0, 6), W.Row(p, 24, 0, 4) }
    local tabs = {}
    for n, i in ipairs(AB.ORDER) do
      local b = W.Button(rows[(n <= 6) and 1 or 2], AB.NAMES[i], 124, 22)
      b:SetPoint("LEFT", b:GetParent(), "LEFT", math.mod(n - 1, 6) * 128, 0)
      b.i = i
      b:SetScript("OnClick", function()
        TAB.cur = this.i
        O:Refresh()
      end)
      tabs[n] = b
    end
    table.insert(p.items, { Refresh = function()
      for _, b in ipairs(tabs) do W.Pick(b, b.i == TAB.cur) end
    end })
    W.Card(p, "Layout", { on = { function() return BAR().enable == "1" end, function(v) BAR().enable = v and "1" or "0"; U() end,
      "This bar on or off." } })
    W.Dropdown(p, "Buttons", nil, (function()
      local o = {}
      for n = 1, 12 do table.insert(o, { key = tostring(n), label = tostring(n) }) end
      return o
    end)(), function() return BAR().buttons end, function(v) BAR().buttons = v; U() end)
    W.Dropdown(p, "Rows and columns", "How the buttons are laid out.", (function()
      local o = {}
      local opts = BarLayoutOptions and BarLayoutOptions(12) or {}
      for _, f in ipairs(opts) do table.insert(o, { key = f, label = f }) end
      return o
    end)(), function() return BAR().formfactor end, function(v) BAR().formfactor = v; U() end)
    Sld(p, "Button size", nil, 10, 64, 1, BAR, "icon_size", Px)
    Sld(p, "Spacing", "Space between the buttons.", 0, 20, 1, BAR, "spacing", Px)
    Sld(p, "Scale", "The whole bar bigger or smaller.", .5, 2, .05, BAR, "scale", Pct)
    Sld(p, "Opacity", nil, .1, 1, .05, BAR, "alpha", Pct)
    Chk(p, "Background", "A backdrop behind the bar.", BAR, "background")
    Chk(p, "Empty slots", "Show buttons with nothing on them.", BAR, "showempty")
    Chk(p, "Pageable", "This bar changes with the action bar page.", BAR, "pageable")
    W.Card(p, "Visibility", { tip = "When the bar shows. All the rules have to agree." })
    W.Dropdown(p, "Combat", nil, VIS_COMBAT, function() return BAR().vis_combat end, function(v) BAR().vis_combat = v; U() end)
    W.Dropdown(p, "Pet", nil, VIS_PET, function() return BAR().vis_pet end, function(v) BAR().vis_pet = v; U() end)
    W.Dropdown(p, "Target", nil, VIS_TARGET, function() return BAR().vis_target end, function(v) BAR().vis_target = v; U() end)
    W.Dropdown(p, "Stealth", nil, VIS_STEALTH, function() return BAR().vis_stealth end, function(v) BAR().vis_stealth = v; U() end)
    Chk(p, "Fade out on mouse-off", "The bar fades after a moment without the mouse over it.", BAR, "autohide")
    Chk(p, "Show in combat", "While fading out: full again as soon as you fight.", BAR, "hide_combat")
    Sld(p, "Fade after", nil, 0, 10, .5, BAR, "hide_time", Sec)
    Sld(p, "Fade to", "0 = gone. Higher keeps a faint bar.", 0, 1, .05, BAR, "fadeto", Pct)
    W.Card(p, "Text")
    Chk(p, "Key", "The key bound to each button.", BAR, "showkeybind")
    Chk(p, "Macro name", nil, BAR, "showmacro")
    Chk(p, "Count", "Items and charges left.", BAR, "showcount")
    Chk(p, "Autocast mark (pet bar)", nil, G, "showcastable")
  end

  -- ---------------------------------------------------------------- buttons and text

  BUILD.abbuttons = function(p)
    W.Heading(p, "Buttons and text", { about = "The border and icon of every button, and the letters on them." })
    Preview(p)
    W.Card(p, "Buttons")
    local skins = {}
    for _, s in ipairs(AB.SKINS) do table.insert(skins, { key = s.key, label = s.label }) end
    Drop(p, "Border", nil, skins, G, "skin")
    Sld(p, "Icon zoom", "Cuts the icon's edges: 0 = the whole picture.", 0, .25, .01, G, "zoom", Pct)
    W.Card(p, "Letters")
    local fonts = {}
    for _, f in ipairs(W.Fonts()) do table.insert(fonts, { key = f.key, label = f.label, font = f.key }) end
    Drop(p, "Font", nil, fonts, G, "font")
    Sld(p, "Text inset", "Moves the texts in from the button's edges.", -5, 10, 1, G, "font_offset", Px)
    Sld(p, "Key size", nil, 6, 20, 1, G, "bind_size", Px)
    Color(p, "Key colour", nil, G, "bind_color")
    Sld(p, "Macro size", nil, 6, 20, 1, G, "macro_size", Px)
    Color(p, "Macro colour", nil, G, "macro_color")
    Sld(p, "Count size", nil, 6, 20, 1, G, "count_size", Px)
    Color(p, "Count colour", nil, G, "count_color")
    Sld(p, "Cooldown size", nil, 6, 30, 1, G, "cd_size", Px)
  end

  -- ---------------------------------------------------------------- paging

  BUILD.abpaging = function(p)
    W.Heading(p, "Paging", { about = "Switch the main bar's page with a key held down, in druid stealth, or by range (hunters)." })
    W.Card(p, "Switch pages")
    Chk(p, "While Alt is held", nil, G, "pagemasteralt")
    Chk(p, "While Shift is held", nil, G, "pagemastershift")
    Chk(p, "While Ctrl is held", nil, G, "pagemasterctrl")
    Chk(p, "In druid stealth", "Prowling gives its own page.", G, "druidstealth")
    Chk(p, "Hunters: by range", "Melee and ranged pages swap by distance.", G, "hunterbar")
    W.Card(p, "Bars that page", { tip = "These bars change with the main bar's page." })
    for _, i in ipairs(AB.ORDER) do
      if i ~= 1 and i <= 10 then
        local id = i
        Chk(p, AB.NAMES[id], nil, function() return C.bars["bar" .. id] end, "pageable")
      end
    end
  end

  -- ---------------------------------------------------------------- gryphons

  BUILD.abgryphons = function(p)
    W.Heading(p, "Gryphons", { about = "The art at the ends of the main bar." })
    W.Card(p, "Gryphons")
    Drop(p, "Art", nil, DD("gryphons"), GRY, "texture", UG)
    Color(p, "Colour", nil, GRY, "color", UG)
    Sld(p, "Size", nil, 16, 160, 1, GRY, "size", Px, UG)
    Drop(p, "Left end at", nil, DD("xpanchors"), GRY, "anchor_left", UG)
    Drop(p, "Right end at", nil, DD("xpanchors"), GRY, "anchor_right", UG)
    Sld(p, "Left / right", nil, -200, 200, 1, GRY, "offset_h", Px, UG)
    Sld(p, "Up / down", nil, -100, 100, 1, GRY, "offset_v", Px, UG)
  end

  O.replaced[T["Actionbar"]] = true
  O:AddPage("Action Bars", "abgeneral", "General", BUILD.abgeneral)
  O:AddPage("Action Bars", "abbars", "Bars", BUILD.abbars)
  O:AddPage("Action Bars", "abbuttons", "Buttons and text", BUILD.abbuttons)
  O:AddPage("Action Bars", "abpaging", "Paging", BUILD.abpaging)
  O:AddPage("Action Bars", "abgryphons", "Gryphons", BUILD.abgryphons)
  AB.TAB = TAB
end)

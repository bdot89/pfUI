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
    -- the cooldown: a dark sweep down the button (as pfUI's on 1.12)
    b.sweep = b:CreateTexture(nil, "OVERLAY")
    b.sweep:SetTexture("Interface\\Buttons\\WHITE8X8")
    b.sweep:SetVertexColor(0, 0, 0, .65)
    b.sweep:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 0, 0)
    b.sweep:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 0, 0)
    b.sweep:Hide()
    -- the press animation, made as pfUI makes it for a real button
    b.animation = CreateFrame("Frame", nil, b)
    b.animation.parent = b
    b.animation:SetPoint("CENTER", b, "CENTER", 0, 0)
    b.animation:SetFrameLevel(b:GetFrameLevel() + 6)
    b.animation.tex = b.animation:CreateTexture(nil, "BACKGROUND")
    b.animation.tex:SetTexCoord(.08, .92, .08, .92)
    b.animation.tex:SetAllPoints(b.animation)
    b.animation:Hide()
    -- the effects (actionbar-octo.lua), as on a real button
    b.hover = AB.Layer(b, 2)
    b.press = AB.Layer(b, 3)
    -- pfUI's own hover glow
    b.pfhl = CreateFrame("Frame", nil, b)
    b.pfhl:SetAllPoints(b)
    b.pfhl:SetFrameLevel(b:GetFrameLevel() + 2)
    b.pfhl:SetBackdrop({ edgeFile = pfUI.media["img:glow"], edgeSize = 8 })
    b.pfhl:SetBackdropBorderColor(1, 1, 1, .8)
    b.pfhl:Hide()
    -- an empty slot (left) and an equipped item (right), small as on a bar
    local function Small(anchor, x)
      local s = CreateFrame("Frame", nil, side)
      s:SetWidth(30) s:SetHeight(30)
      s:SetPoint(anchor, b, anchor == "RIGHT" and "LEFT" or "RIGHT", x, -23)
      CreateBackdrop(s)
      return s
    end
    local empty = Small("RIGHT", -6)
    local worn = Small("LEFT", 6)
    worn.icon = worn:CreateTexture(nil, "ARTWORK")
    worn.icon:SetAllPoints(worn)
    worn.icon:SetTexture("Interface\\Icons\\INV_Jewelry_Talisman_07")
    worn.icon:SetTexCoord(.08, .92, .08, .92)
    worn.tint = worn:CreateTexture(nil, "OVERLAY")
    worn.tint:SetAllPoints(worn)
    worn.edge = AB.Layer(worn, 2)
    local note = side:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    note:SetPoint("BOTTOM", side, "BOTTOM", 0, 4)
    note:SetWidth(sideW - 6)
    note:SetTextColor(.6, .6, .6)
    b.note = note

    -- every part of the sample opens its setting (pfUI.plates.OpenSection
    -- opens a page at a card)
    local function Hot(region, title, card, page, level)
      local h = CreateFrame("Button", nil, side)
      h:SetFrameLevel(b:GetFrameLevel() + (level or 10))
      h:SetAllPoints(region)
      h.hl = h:CreateTexture(nil, "OVERLAY")
      h.hl:SetAllPoints(h)
      h.hl:SetTexture("Interface\\Buttons\\WHITE8X8")
      h.hl:SetVertexColor(1, 1, 1, .2)
      h.hl:Hide()
      h:SetScript("OnEnter", function()
        this.hl:Show()
        GameTooltip:SetOwner(this, "ANCHOR_TOP")
        GameTooltip:AddLine(title)
        GameTooltip:AddLine("Click to change it", 1, 1, 1)
        GameTooltip:Show()
      end)
      h:SetScript("OnLeave", function() this.hl:Hide() GameTooltip:Hide() end)
      h:SetScript("OnClick", function()
        -- (the note's target follows what the sample is showing)
        local pg, cd = page, card
        if this.follow then pg, cd = b.notePage or page, b.noteCard or card end
        if pfUI.plates and pfUI.plates.OpenSection then pfUI.plates.OpenSection(pg, cd) else O:Open(pg) end
      end)
      return h
    end
    Hot(empty, "Empty slot fill", "Empty slots", "abeffects")
    Hot(worn, "Equipped item mark", "Equipped items", "abeffects")
    Hot(b, "Button border and icon zoom", "Buttons", "abbuttons", 8)
    Hot(b.hotkey, "Key text", "Letters", "abbuttons")
    Hot(b.macro, "Macro text", "Letters", "abbuttons")
    Hot(b.count, "Count text", "Letters", "abbuttons")
    -- the cooldown number comes and goes, so its spot is a fixed square
    local cdSpot = CreateFrame("Frame", nil, b)
    cdSpot:SetWidth(34) cdSpot:SetHeight(28)
    cdSpot:SetPoint("CENTER", b, "CENTER", 0, 0)
    Hot(cdSpot, "Cooldown text", "Letters", "abbuttons")
    Hot(note, "What the sample shows now", "Highlights", "abgeneral").follow = true

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
      Text(b.cd, C.bars.cd_size, "1,1,1,1", "")
      b.animation:SetScript("OnUpdate", pfUI.bars.animations and pfUI.bars.animations[C.bars.animation] or nil)
      -- effects
      AB.Slot(empty, empty)
      local eq = C.bars.eq_style or "fill"
      local tr, tg, tb, ta = GetStringColor(C.bars.eqcolor or ".2,.8,.2,.2")
      worn.tint:SetTexture(tonumber(tr) or .2, tonumber(tg) or .8, tonumber(tb) or .2, tonumber(ta) or .2)
      if C.bars.showequipped == "1" and (eq == "fill" or eq == "both") then worn.tint:Show() else worn.tint:Hide() end
      worn.edge.fill:Hide()
      if C.bars.showequipped == "1" and (eq == "border" or eq == "both") then
        AB.Edges(worn.edge, tonumber(C.bars.eq_size) or 2, .64, .21, .93, 1)  -- an epic's purple
        worn.edge:Show()
      else
        worn.edge:Hide()
      end
      b.hoverPfui = not AB.Paint(b.hover, "hover")
      b.pressOn = AB.Paint(b.press, "press") and C.bars.press_style ~= "none"
      -- a changed glow setting repaints a lit glow
      local sig = (C.bars.glow_style or "") .. (C.bars.glow_color or "") .. (C.bars.glow_color_class or "")
        .. (C.bars.glow_thick or "") .. (C.bars.glow_burst or "")
      if sig ~= b.glowSig and b.octoGlow then b.octoGlow.lit = nil end
      b.glowSig = sig
    end

    -- The sample in use, on a 13 s loop: a 6 s cooldown with the chosen swipe
    -- and the counting number; a press (press look + animation); a hover; the
    -- highlight colours (out of range, out of mana, not usable); a proc glow.
    -- The note says what shows, and clicking it opens that setting.
    local LOOP = 13
    local STATES = {
      { 7.5, 8.3, "glowrange", "rangecolor", "out of range" },
      { 8.3, 9.1, "showoom", "oomcolor", "out of mana" },
      { 9.1, 9.9, "showna", "nacolor", "not usable" },
    }
    local function Note(text, page, card)
      b.note:SetText(text)
      b.notePage, b.noteCard = page, card
    end
    function M.Animate(now)
      local t = math.mod(now, LOOP)
      local size = b:GetHeight() or 76
      local style = C.bars.cd_style or "clock"
      -- cooldown
      if t < 6 then
        if style == "clock" then
          b.sweep:SetHeight(math.max(1, size * (6 - t) / 6))
          b.sweep:Show()
        else
          b.sweep:Hide()
          -- (the real swipe, started once per loop and on a style change)
          if not b.drainFor or b.drainFor ~= style .. math.floor(now / LOOP) then
            b.drainFor = style .. math.floor(now / LOOP)
            AB.Drain(b, now - t, 6, 1)
          end
        end
        -- pfUI's own cooldown text, so its colours and tenths show as in game
        b.cd:SetTextColor(1, 1, 1)
        b.cd:SetText(GetColoredTimeString(6 - t))
        Note("cooldown", "abeffects", "Cooldown")
      else
        b.sweep:Hide()
        if b.octoDrain then b.octoDrain:Hide() end
        b.drainFor = nil
        b.cd:SetText("")
        Note("ready", "abgeneral", "Behaviour")
      end
      -- the press: the press look held for a moment, and the press animation
      if t >= 6 and t < 6.35 then
        if b.pressOn then b.press:Show() else b.press:Hide() end
        Note("pressed", "abeffects", "Hover and press")
      else
        b.press:Hide()
      end
      if t >= 6 and not b.pressed then
        b.pressed = true
        if C.bars.animation ~= "none" then
          b.animation.active = 0
          b.animation:Show()
        end
      elseif t < 6 then
        b.pressed = nil
      end
      -- the hover
      if t >= 6.5 and t < 7.5 then
        if b.hoverPfui then b.pfhl:Show() b.hover:Hide() else b.pfhl:Hide() b.hover:Show() end
        Note("mouse over", "abeffects", "Hover and press")
      else
        b.pfhl:Hide()
        b.hover:Hide()
      end
      -- highlight colours
      local r, g, bl = 1, 1, 1
      for _, s in ipairs(STATES) do
        if t >= s[1] and t < s[2] and C.bars[s[3]] == "1" then
          r, g, bl = GetStringColor(C.bars[s[4]] or "1,1,1,1")
          Note(s[5], "abgeneral", "Highlights")
        end
      end
      b.icon:SetVertexColor(tonumber(r) or 1, tonumber(g) or 1, tonumber(bl) or 1)
      -- a proc
      local glow = t >= 10
      AB.Glow(b, glow)
      if glow then Note("proc glow", "abeffects", "Proc glow") end
      -- a button on the bars lights up now and then, as if pressed
      if (M.flashAt or 0) < now then
        M.flashAt = now + .7
        if M.lit then M.lit:SetVertexColor(1, 1, 1) end
        local all = {}
        for _, r2 in pairs(M.rects) do
          if r2:IsShown() then for _, ic in pairs(r2.icons) do if ic:IsShown() then table.insert(all, ic) end end end
        end
        local n = table.getn(all)
        if n > 0 then
          M.lit = all[math.random(1, n)]
          M.lit:SetVertexColor(1.6, 1.6, 1.6)
        end
      end
    end

    box:SetScript("OnUpdate", function()
      local now = GetTime()
      M.Animate(now)
      if (this.tick or 0) > now then return end
      this.tick = now + .5
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
    -- cooldown colours are pfUI's shared ones (every cooldown text uses them)
    local function CD() return C.appearance.cd end
    local function Re() if pfUI.api.ResetTimeColors then pfUI.api.ResetTimeColors() end end
    Color(p, "Cooldown colour", "Seconds left, on every cooldown.", CD, "normalcolor", Re)
    Color(p, "Last 5 seconds colour", "When it is nearly ready.", CD, "lowcolor", Re)
    Color(p, "Minutes colour", nil, CD, "minutecolor", Re)
    Color(p, "Hours colour", nil, CD, "hourcolor", Re)
    PfChk(p, "Tenths in the last 5 seconds", "Shows 4.2 instead of 4.", CD, "milliseconds", Re)
    Sld(p, "Hide cooldowns shorter than", "No number on short ones, like the global cooldown.", 0, 10, .5, CD, "threshold", Sec, Re)
  end

  -- ---------------------------------------------------------------- effects

  local function List(src)
    local out = {}
    for _, s in ipairs(src) do table.insert(out, { key = s.key, label = s.label, texture = s.tex and (AB.ART .. s.tex) or nil }) end
    return out
  end

  BUILD.abeffects = function(p)
    W.Heading(p, "Effects", { about = "What buttons do when you hover, press, wait on a cooldown or get a proc, "
      .. "and how empty slots and equipped items look. The sample button plays them all." })
    Preview(p)
    W.Card(p, "Hover and press", { tip = "Hover: the mouse is over a button. Press: it is held down, by mouse or key." })
    Drop(p, "Hover look", nil, List(AB.STYLES), G, "hover_style")
    Color(p, "Hover colour", nil, G, "hover_color")
    Chk(p, "Hover in class colour", nil, G, "hover_color_class")
    Sld(p, "Hover border", "Thickness for Border only.", 1, 6, 1, G, "hover_size", Px)
    Drop(p, "Press look", nil, List(AB.STYLES), G, "press_style")
    Color(p, "Press colour", nil, G, "press_color")
    Chk(p, "Press in class colour", nil, G, "press_color_class")
    Sld(p, "Press border", "Thickness for Border only.", 1, 6, 1, G, "press_size", Px)
    W.Card(p, "Proc glow", { tip = "Lights a button when it is worth pressing now." })
    Chk(p, "Reactive abilities", "Overpower, Revenge, Execute, Riposte, Counterattack, Mongoose Bite and Hammer of Wrath while usable.", G, "glow_reactive")
    Chk(p, "Procs", "Shadow Bolt during Shadow Trance (Nightfall).", G, "glow_procs")
    Drop(p, "Glow", nil, List(AB.GLOWS), G, "glow_style")
    Color(p, "Glow colour", nil, G, "glow_color")
    Chk(p, "Glow in class colour", nil, G, "glow_color_class")
    Chk(p, "Burst as it starts", "A ring grows out of the button when the glow begins.", G, "glow_burst")
    Sld(p, "Lines", "For Marching lines.", 2, 16, 1, G, "glow_lines")
    Sld(p, "Thickness", nil, 1, 6, 1, G, "glow_thick", Px)
    Sld(p, "Speed", nil, 1, 10, 1, G, "glow_speed")
    W.Card(p, "Cooldown", { tip = "How a button shows it is cooling down. The number is on Buttons and text." })
    Drop(p, "Swipe", nil, List(AB.CDSTYLES), G, "cd_style")
    Color(p, "Swipe colour", nil, G, "cd_color")
    Chk(p, "Edge line", "A bright line where the swipe ends.", G, "cd_edge")
    Color(p, "Edge colour", nil, G, "cd_edgecolor")
    Chk(p, "Edge in class colour", nil, G, "cd_edgecolor_class")
    W.Card(p, "Empty slots")
    Drop(p, "Slot fill", "Behind the icon: shows in empty slots.", List(AB.SLOTS), G, "slot_style")
    Color(p, "Slot colour", nil, G, "slot_color")
    Chk(p, "Slot in class colour", nil, G, "slot_color_class")
    W.Card(p, "Equipped items", { tip = "Items you wear, put on a bar (trinkets, weapons)." })
    Chk(p, "Mark equipped items", nil, G, "showequipped")
    Drop(p, "Mark", nil, List(AB.EQSTYLES), G, "eq_style")
    Color(p, "Tint colour", nil, G, "eqcolor")
    Sld(p, "Border", "In the item's quality colour.", 1, 4, 1, G, "eq_size", Px)
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
  O:AddPage("Action Bars", "abeffects", "Effects", BUILD.abeffects)
  O:AddPage("Action Bars", "abpaging", "Paging", BUILD.abpaging)
  O:AddPage("Action Bars", "abgryphons", "Gryphons", BUILD.abgryphons)
  AB.TAB = TAB
end)

pfUI:RegisterModule("octo-options", "vanilla:tbc", function ()
  -- pfUI Octo :: the options window in OctoBG's look.
  -- User, 20 Oct 2026 (screenshots of ElvUI and of OctoBG's options): "copy
  -- Octo BGS style of UI and update PFUI into being my own addon". pfUI's own
  -- window (pfUI.gui, so everything that opens, closes or reloads it keeps
  -- working) gets OctoBG's shell: the title row, a quick bar (Move frames,
  -- Keybinds, Install, Profiles, Background, Find a setting), a folding topic
  -- list on the left and the page on the right.
  --
  -- Two kinds of page live in it:
  --   * Octo pages - built with octo-widgets.lua (folding cards, switches,
  --     sliders), registered with O:AddPage(group, key, label, build).
  --     Combat text's pages (sct-options.lua) are these.
  --   * pfUI's own pages - every category and page made by CreateGUIEntry.
  --     Their areas are moved into the page panel and shown from here; the
  --     old tree buttons are kept (hidden) because gui.lua still drives them.
  -- The Find box searches both (pfUI's labels via pfUI.gui.searchDB).

  local B = pfUI.octoui
  local W = B and B.W
  local g = pfUI.gui
  if not W or not g or not g.frames then return end
  local K = W.C

  local O = B.Options or { pages = {}, groups = {}, BUILD = {} }
  B.Options = O
  O.pages, O.BUILD = O.pages or {}, O.BUILD or {}
  O.octo = O.octo or {}   -- { { name, { { key, label }, ... } }, ... } in order

  local WIDTH, HEIGHT, NAV_W, NAV_ROW = 980, 660, 196, 20
  local SEARCH = "[" .. T["Search"] .. "]"

  -- ---------------------------------------------------------------- helpers for pages

  -- Check / slider / dropdown bound to a key of a settings table (tbl is a
  -- function, so a reset table is picked up). As in OctoBG's Options.lua.
  function O.Chk(p, label, desc, tbl, key, after)
    return W.Check(p, label, desc, function() return tbl()[key] end, function(v)
      tbl()[key] = v
      if after then after(v) end
    end)
  end
  function O.Sld(p, label, desc, min, max, step, tbl, key, after, fmt)
    return W.Slider(p, label, desc, min, max, step, function() return tbl()[key] end, function(v)
      tbl()[key] = v
      if after then after(v) end
    end, fmt)
  end
  function O.Drop(p, label, desc, options, tbl, key, after)
    return W.Dropdown(p, label, desc, options, function() return tbl()[key] end, function(v)
      tbl()[key] = v
      if after then after(v) end
    end)
  end
  function O.On(tbl, key, after, tip)
    return { function() return tbl()[key] end, function(v)
      tbl()[key] = v
      if after then after(v) end
    end, tip }
  end
  function O.Pct(v) return math.floor(v * 100 + 0.5) .. "%" end
  function O.Px(v) return v .. " px" end
  function O.Sec(v) return v .. " s" end

  -- pfUI's string settings ("1" / "0", numbers as text) as Octo widgets
  function O.PfChk(p, label, desc, group, key, after)
    return W.Check(p, label, desc, function() return group()[key] == "1" end, function(v)
      group()[key] = v and "1" or "0"
      if after then after(v) end
    end)
  end
  function O.PfSld(p, label, desc, min, max, step, group, key, after, fmt)
    return W.Slider(p, label, desc, min, max, step, function() return tonumber(group()[key]) end, function(v)
      group()[key] = tostring(v)
      if after then after(v) end
    end, fmt)
  end

  -- a page of the Octo kind; group = the topic list section it goes under
  function O:AddPage(group, key, label, build)
    local sec
    for _, s in ipairs(self.octo) do if s[1] == group then sec = s end end
    if not sec then
      sec = { group, {} }
      table.insert(self.octo, sec)
    end
    table.insert(sec[2], { key, label })
    self.BUILD[key] = build
    if self.frame then self:BuildNav() end
  end

  -- ---------------------------------------------------------------- the shell

  local function QuickTip(frame, title, text)
    frame:SetScript("OnEnter", function()
      GameTooltip:SetOwner(this, "ANCHOR_BOTTOMRIGHT")
      GameTooltip:AddLine(title)
      GameTooltip:AddLine(text, 1, 1, 1, 1)
      GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
  end

  local hidden = CreateFrame("Frame", nil, g)
  hidden:Hide()
  O.hidden = hidden

  function O:Build()
    local f = g
    self.frame = f
    f:SetWidth(WIDTH)
    f:SetHeight(HEIGHT)
    f:SetClampedToScreen(true)

    -- flat backdrop (pfUI's backdrop frame takes OctoBG's colours)
    local bd = f.backdrop or f
    W.Flat(bd, K.bg, 1, K.lineHi)
    if f.backdrop_shadow then f.backdrop_shadow:Hide() end

    -- pfUI's title bar parts make way
    for _, k in ipairs({ "share", "install", "hoverbind", "unlock", "search", "close" }) do
      if f[k] then f[k]:Hide() end
    end
    f.title:ClearAllPoints()
    f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -10)
    W.Font(f.title, 15, K.text[1], K.text[2], K.text[3])
    f.title:SetText("|cff33ccffpfUI|r Octo")
    f.version:ClearAllPoints()
    f.version:SetPoint("LEFT", f.title, "RIGHT", 10, -1)
    W.Font(f.version, 11, K.dim[1], K.dim[2], K.dim[3])
    f.version:SetText("v" .. (pfUI.version.octo or "?") .. "  -  your whole interface: frames, bars, meters, map and combat text")
    local close = W.Button(f, "X", 22, 22)
    close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -6)
    close:SetScript("OnClick", function() g:Hide() end)
    W.Tip(close, "Close", "Escape closes it too.")

    self:BuildQuickBar(f)

    local nav = CreateFrame("Frame", nil, f)
    nav:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -74)
    nav:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 12, 12)
    nav:SetWidth(NAV_W)
    nav:EnableMouseWheel(true)
    nav:SetScript("OnMouseWheel", function()
      O.navOffset = (O.navOffset or 0) - arg1 * NAV_ROW * 3
      O:LayoutNav()
    end)
    W.Flat(nav, K.panel, 1, K.line)
    self.navFrame = nav
    nav.up = W.Arrow(nav, 9, "up")
    nav.up:SetPoint("TOP", nav, "TOP", 0, -2)
    nav.down = W.Arrow(nav, 9, "down")
    nav.down:SetPoint("BOTTOM", nav, "BOTTOM", 0, 2)

    local content = CreateFrame("Frame", nil, f)
    content:SetPoint("TOPLEFT", f, "TOPLEFT", NAV_W + 18, -74)
    content:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -12, 12)
    W.Flat(content, K.panel, 1, K.line)
    self.content = content

    -- pfUI's page area fills the page panel; its tree column is gone
    local root = g.frames
    root.area:ClearAllPoints()
    root.area:SetAllPoints(content)
    root.area:SetFrameLevel(content:GetFrameLevel() + 1)
    if root.area.backdrop then root.area.backdrop:Hide() end
    for _, k in ipairs({ "tree", "divider", "moreUp", "more", "wheel" }) do
      if root.area[k] then root.area[k]:Hide() end
    end
    if root.area.wheel then root.area.wheel:EnableMouseWheel(false) end

    self:ApplyAlpha()
    self:BuildNav()
  end

  -- The strip under the title, on every page.
  function O:BuildQuickBar(f)
    local bar = CreateFrame("Frame", nil, f)
    bar:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -36)
    bar:SetPoint("TOPRIGHT", f, "TOPRIGHT", -12, -36)
    bar:SetHeight(32)
    W.Flat(bar, K.panel, 1, K.line)
    self.quick = bar

    local x = 8
    local function Btn(text, width, tip, fn)
      local b = W.Button(bar, text, width, 22)
      b:SetPoint("LEFT", bar, "LEFT", x, 0)
      b:SetScript("OnClick", fn)
      QuickTip(b, text, tip)
      x = x + width + 6
      return b
    end
    Btn(T["Move Frames"], 100, "Every frame gets a box you can drag. Boxes snap to each other and to the grid. "
      .. "Alt-click two boxes to give the second the first one's size; right-click a box for its options.", function()
      if pfUI.unlock then
        -- layout mode closes this window and opens it again when done
        pfUI.unlock:Show()
      end
    end)
    -- Keybinds: pfUI's hover binding or the Key Map keyboard (user, 20 Oct 2026)
    local kb
    kb = Btn(T["Keybinds"], 80, "Pick how to bind keys: hover an action button and press a key, or a "
      .. "picture of your keyboard to drag spells onto (/keymap).", function()
      if not kb.menu then
        kb.menu = W.Menu(kb, {
          { key = "hover", label = "Original hover binding" },
          { key = "keymap", label = "Keyboard layout (Key Map)" },
          { key = "keybinds", label = "Every key binding (list)" },
        }, 200, function(k)
          if k == "keybinds" then
            if pfUI.keybinds then pfUI.keybinds:Toggle() end
          elseif k == "keymap" then
            if pfUI.keymap then pfUI.keymap:Toggle() end
          elseif pfUI.hoverbind then
            g:Hide()
            pfUI.hoverbind:Show()
          end
        end)
      end
      local open = kb.menu:IsShown()
      W.CloseMenus()
      if not open then kb.menu:Show() end
    end)
    Btn(T["Install"], 70, "Run the setup again: profile, layout, chat (/pfui install).", function()
      if pfUI.firstrun then
        g:Hide()
        pfUI.firstrun:Restart()
      end
    end)
    Btn(T["Profiles"], 80, "Export your settings as a text string, or import one (/export).", function()
      if pfShare then
        pfShare:Show()
        if pfShareExport then pfShareExport:Click() end
      end
    end)

    -- background opacity of this window
    local bl = W.Font(bar:CreateFontString(nil, "OVERLAY"), 12, K.text[1], K.text[2], K.text[3])
    bl:SetPoint("LEFT", bar, "LEFT", x + 10, 0)
    bl:SetText("Background")
    local s = W.SliderBar(bar, 90, "pfOctoQuickAlpha")
    s:SetPoint("LEFT", bl, "RIGHT", 10, 0)
    s:SetMinMaxValues(0.3, 1)
    s:SetValueStep(0.05)
    local sv = W.Font(bar:CreateFontString(nil, "OVERLAY"), 11, K.accent[1], K.accent[2], K.accent[3])
    sv:SetPoint("LEFT", s, "RIGHT", 8, 0)
    s:SetScript("OnValueChanged", function()
      if this.loading then return end
      B.Store().alpha = math.floor(this:GetValue() * 20 + 0.5) / 20
      sv:SetText(math.floor(B.Store().alpha * 100 + 0.5) .. "%")
      W.SliderPaint(this)
      O:ApplyAlpha()
    end)
    QuickTip(s, "Background", "How solid this window's background is: lower to see the game through it.")
    self.quickAlpha, self.quickAlphaText = s, sv

    -- find a setting
    local find = W.EditBox(bar, 190, "pfOctoQuickFind")
    find:SetPoint("RIGHT", bar, "RIGHT", -8, 0)
    local hint = W.Font(find:CreateFontString(nil, "OVERLAY"), 11, K.dim[1], K.dim[2], K.dim[3])
    hint:SetPoint("LEFT", find, "LEFT", 7, 0)
    hint:SetText("Find a setting")
    local function Hint() if find.typing or (find:GetText() or "") ~= "" then hint:Hide() else hint:Show() end end
    find.OnFocus = Hint
    find:SetScript("OnEscapePressed", function()
      this:SetText("")
      this:ClearFocus()
    end)
    find:SetScript("OnEnterPressed", function()
      this:ClearFocus()
      local r = O.results
      if r and r[1] then O:Reveal(r[1]) end
    end)
    find:SetScript("OnTextChanged", function()
      Hint()
      O:Search(this:GetText())
    end)
    QuickTip(find, "Find a setting", "Type a word (\"font\", \"crit\", \"castbar\"): every setting that mentions it is "
      .. "listed. Click one to go straight to it. Enter goes to the first.")
    self.quickFind = find
  end

  function O:RefreshQuick()
    if not self.quick then return end
    local a = B.Store().alpha or 0.95
    self.quickAlpha.loading = true
    self.quickAlpha:SetValue(a)
    self.quickAlpha.loading = nil
    W.SliderPaint(self.quickAlpha)
    self.quickAlphaText:SetText(math.floor(a * 100 + 0.5) .. "%")
  end

  -- The window's and its panels' backgrounds follow the Background slider.
  function O:ApplyAlpha()
    if not self.frame then return end
    local a = B.Store().alpha or 0.95
    local bd = self.frame.backdrop or self.frame
    bd:SetBackdropColor(K.bg[1], K.bg[2], K.bg[3], a)
    for _, p in ipairs({ self.quick, self.navFrame, self.content }) do
      p:SetBackdropColor(K.panel[1], K.panel[2], K.panel[3], a)
    end
  end

  -- ---------------------------------------------------------------- topic list

  -- One topic: a flat row; the picked one gets a blue wash and a blue edge.
  local function NavButton(label, indent)
    local b = CreateFrame("Button", nil, O.navFrame)
    b:SetHeight(NAV_ROW)
    b.sel = W.Fill(b, K.accent, 0.16, "BACKGROUND")
    b.sel:SetAllPoints(b)
    b.sel:Hide()
    b.bar = W.Fill(b, K.accent, 1, "BORDER")
    b.bar:SetWidth(2)
    b.bar:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
    b.bar:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 0, 0)
    b.bar:Hide()
    local hl = W.Fill(b, { 1, 1, 1 }, 0.05, "HIGHLIGHT")
    hl:SetAllPoints(b)
    b.text = W.Font(b:CreateFontString(nil, "OVERLAY"), 12, K.dim[1], K.dim[2], K.dim[3])
    b.text:SetPoint("LEFT", b, "LEFT", 10, 0)
    b.text:SetPoint("RIGHT", b, "RIGHT", -4, 0)
    b.text:SetJustifyH("LEFT")
    b.text:SetText(label)
    b.indent = indent
    b:EnableMouseWheel(true)
    b:SetScript("OnMouseWheel", O.navFrame:GetScript("OnMouseWheel"))
    return b
  end

  local function NavMark(b, on)
    if on then
      b.sel:Show()
      b.bar:Show()
      b.text:SetTextColor(1, 1, 1)
    else
      b.sel:Hide()
      b.bar:Hide()
      b.text:SetTextColor(K.dim[1], K.dim[2], K.dim[3])
    end
  end

  -- A picture for each section (user, 20 Oct 2026: "use actual picture and
  -- logos of spells"), from the game's icons; every name checked against
  -- the client's MPQ file lists. Keyed by the section name, lower case,
  -- letters only.
  local ICON = "Interface\\Icons\\"
  O.ICONS = {
    combattext = "Spell_Fire_FlameBolt", settings = "INV_Misc_Gear_01", unitframes = "INV_Misc_Head_Human_01",
    bagsbank = "INV_Misc_Bag_08", bags = "INV_Misc_Bag_08", loot = "INV_Misc_Coin_01", minimap = "INV_Misc_Map_01",
    buffs = "Spell_Holy_WordFortitude", actionbar = "Ability_DualWield", panel = "INV_Misc_Note_01",
    xpbar = "INV_Misc_Book_11", tooltip = "INV_Letter_15", castbar = "Spell_Nature_Lightning",
    chat = "INV_Scroll_03", nameplates = "Ability_Hunter_SniperShot", meters = "Ability_Marksmanship",
    thirdparty = "INV_Gizmo_01", components = "Trade_Engineering", about = "INV_Misc_QuestionMark",
    skins = "INV_Misc_Orb_01", threat = "Ability_Warrior_DefensiveStance",
  }
  function O.IconFor(name)
    local k = string.gsub(string.lower(name or ""), "[^%a]", "")
    return ICON .. (O.ICONS[k] or "INV_Misc_Rune_01")
  end

  -- A section header that folds its topics open or shut (one open at a time).
  -- A section without topics (a pfUI category with one page) opens its page.
  local function NavHeader(label, single)
    local h = CreateFrame("Button", nil, O.navFrame)
    h:SetHeight(24)
    h.icon = W.Arrow(h, 9, "right")
    h.icon:SetPoint("RIGHT", h, "RIGHT", -6, 0)
    if single then h.icon:Hide() end
    h.pic = h:CreateTexture(nil, "ARTWORK")
    h.pic:SetTexture(O.IconFor(label))
    h.pic:SetTexCoord(.08, .92, .08, .92)
    h.pic:SetWidth(18)
    h.pic:SetHeight(18)
    h.pic:SetPoint("LEFT", h, "LEFT", 4, 0)
    h.sel = W.Fill(h, K.accent, 0.16, "BACKGROUND")
    h.sel:SetAllPoints(h)
    h.sel:Hide()
    local hl = W.Fill(h, { 1, 1, 1 }, 0.04, "HIGHLIGHT")
    hl:SetAllPoints(h)
    h.text = W.Font(h:CreateFontString(nil, "OVERLAY"), 13, K.text[1], K.text[2], K.text[3])
    h.text:SetPoint("LEFT", h, "LEFT", 30, 0)
    h.text:SetPoint("RIGHT", h, "RIGHT", -18, 0)
    h.text:SetJustifyH("LEFT")
    h.text:SetText(label)
    h:EnableMouseWheel(true)
    h:SetScript("OnMouseWheel", O.navFrame:GetScript("OnMouseWheel"))
    return h
  end

  -- pfUI's categories and pages, in their order: key "l:<category>" or
  -- "l:<category>/<page>"; O.legacy[key] = { cat = button, page = button }
  local function LegacyList()
    local out = {}
    for _, cat in ipairs(g.frames.order or {}) do
      local name = cat.text and cat.text:GetText()
      if name and name ~= SEARCH then
        local entry = { name = name, cat = cat, pages = {} }
        for _, child in ipairs(cat.children or {}) do
          table.insert(entry.pages, { name = child.text:GetText(), btn = child })
        end
        table.insert(out, entry)
      end
    end
    return out
  end

  -- (re)builds the topic list: Octo sections first, then pfUI's categories
  function O:BuildNav()
    if not self.navFrame then return end
    self.navItems = self.navItems or {}
    for _, it in ipairs(self.navItems) do it:Hide() end
    self.navItems, self.groups, self.nav, self.groupOf, self.legacy = {}, {}, {}, {}, {}

    local function Group(name, single)
      local grp = { header = NavHeader(name, single), buttons = {} }
      grp.header.group = grp
      table.insert(self.navItems, grp.header)
      table.insert(self.groups, grp)
      return grp
    end
    local function Topic(grp, key, label)
      local b = NavButton(label, 12)
      b.key = key
      b:SetScript("OnClick", function() O:Select(this.key) end)
      table.insert(grp.buttons, b)
      table.insert(self.navItems, b)
      self.nav[key] = b
      self.groupOf[key] = grp
    end

    for _, sec in ipairs(self.octo) do
      local grp = Group(sec[1])
      for _, pg in ipairs(sec[2]) do Topic(grp, "o:" .. pg[1], pg[2]) end
      grp.header:SetScript("OnClick", function()
        O.openGroup = (O.openGroup ~= this.group) and this.group or nil
        O:LayoutNav()
      end)
    end

    for _, e in ipairs(LegacyList()) do
      -- pfUI's own children are hidden away; gui.lua keeps driving them
      e.cat:SetParent(hidden)
      if table.getn(e.pages) > 0 then
        local grp = Group(e.name)
        for _, pg in ipairs(e.pages) do
          pg.btn:SetParent(hidden)
          local key = "l:" .. e.name .. "/" .. pg.name
          self.legacy[key] = { cat = e.cat, page = pg.btn }
          Topic(grp, key, pg.name)
        end
        grp.header:SetScript("OnClick", function()
          O.openGroup = (O.openGroup ~= this.group) and this.group or nil
          -- opening a section shows its first page, as OctoBG's did once picked
          if O.openGroup == this.group and this.group.buttons[1] then
            O:Select(this.group.buttons[1].key)
          else
            O:LayoutNav()
          end
        end)
      else
        local grp = Group(e.name, true)
        local key = "l:" .. e.name
        self.legacy[key] = { cat = e.cat }
        self.nav[key] = grp.header
        self.groupOf[key] = grp
        grp.single = key
        grp.header.key = key
        grp.header:SetScript("OnClick", function() O:Select(this.key) end)
      end
    end
    self.navCount = self:CountLegacy()
    self:LayoutNav()
  end

  -- pfUI's categories and pages (the list is rebuilt when this changes)
  function O:CountLegacy()
    local n = 0
    for _, cat in ipairs(g.frames.order or {}) do
      n = n + 1 + table.getn(cat.children or {})
    end
    return n
  end

  -- Stacks the topic list (each header with its topics when open), scrolled
  -- by the mouse wheel when it is taller than the column.
  function O:LayoutNav()
    local nav = self.navFrame
    local rows, y = {}, 6
    for _, grp in ipairs(self.groups) do
      y = y + 2
      table.insert(rows, { grp.header, 0, y, 24 })
      y = y + 25
      local open = (self.openGroup == grp)
      if not grp.single then W.Turn(grp.header.icon, open and "down" or "right") end
      for _, b in ipairs(grp.buttons) do
        if open then
          table.insert(rows, { b, b.indent, y, NAV_ROW })
          y = y + NAV_ROW + 1
        else
          b:Hide()
        end
      end
    end
    local room = (nav:GetHeight() or 0) - 10
    if room < 100 then room = 540 end
    local most = math.max(0, y - room)
    -- keep the open section in view
    if self.reveal then
      for _, r in ipairs(rows) do
        if r[1] == self.reveal then
          if r[3] - (self.navOffset or 0) < 6 then self.navOffset = r[3] - 6 end
          if r[3] + r[4] - (self.navOffset or 0) > room then self.navOffset = r[3] + r[4] - room end
        end
      end
      self.reveal = nil
    end
    local off = math.max(0, math.min(most, self.navOffset or 0))
    self.navOffset = off
    for _, r in ipairs(rows) do
      local b, top = r[1], r[3] - off
      if top < 2 or top + r[4] > room + 6 then
        b:Hide()
      else
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", nav, "TOPLEFT", 6 + r[2], -top)
        b:SetWidth(NAV_W - 12 - r[2])
        b:Show()
      end
    end
    if off > 0 then nav.up:Show() else nav.up:Hide() end
    if off < most then nav.down:Show() else nav.down:Hide() end
  end

  -- ---------------------------------------------------------------- pages

  -- every pfUI category area fills the page panel (new ones too)
  local function AnchorLegacy()
    for _, cat in ipairs(g.frames.order or {}) do
      if cat.area and not cat.area.octoPlaced then
        cat.area:ClearAllPoints()
        cat.area:SetAllPoints(O.content)
        cat.area.octoPlaced = true
      end
    end
  end

  local function HideLegacy(except)
    for _, cat in ipairs(g.frames.order or {}) do
      if cat ~= except and cat.area then cat.area:Hide() end
    end
  end

  function O:Page(key)
    local p = self.pages[key]
    if p then return p end
    p = W.Page(self.content)
    p.key = key
    p.frame:SetFrameLevel(self.content:GetFrameLevel() + 2)
    for _, sec in ipairs(self.octo) do
      for _, pg in ipairs(sec[2]) do
        if pg[1] == key then p.icon = O.IconFor(sec[1]) end
      end
    end
    self.BUILD[key](p)
    W.Done(p)
    self.pages[key] = p
    return p
  end

  local function HideOcto(except)
    for _, q in pairs(O.pages) do
      if q ~= except then q.frame:Hide() end
    end
    if O.searchPage and O.searchPage ~= except then O.searchPage.frame:Hide() end
  end

  -- Shows one Octo page (or the search results), hides the rest.
  function O:Show(p)
    W.CloseMenus()
    HideLegacy()
    HideOcto(p)
    p.frame:Show()
    W.Refresh(p)
  end

  -- Shows one of pfUI's pages in the page panel.
  function O:ShowLegacy(key)
    local l = self.legacy[key]
    if not l then return end
    W.CloseMenus()
    HideOcto()
    AnchorLegacy()
    HideLegacy(l.cat)
    l.cat.area:Show()
    if l.page then
      for _, child in ipairs(l.cat.children or {}) do
        if child ~= l.page and child.area then child.area:Hide() end
      end
      l.page.area:Show()
    end
  end

  function O:Select(key)
    if not key or not (self.nav[key]) then key = self.first end
    if not key then return end
    self.current = key
    self.searching = nil
    for k, b in pairs(self.nav) do
      if b.sel and b.bar then NavMark(b, k == key) elseif b.sel then
        if k == key then b.sel:Show() else b.sel:Hide() end
      end
    end
    if self.groupOf[key] then
      self.openGroup = self.groupOf[key]
      self.reveal = self.groupOf[key].header
    end
    self:LayoutNav()
    if string.sub(key, 1, 2) == "o:" then
      self:Show(self:Page(string.sub(key, 3)))
    else
      self:ShowLegacy(key)
    end
  end

  -- The topic key of a pfUI category (and page) by their names, forgiving:
  -- colour codes, case and punctuation do not matter; a page that is not in
  -- that category is looked for in every category; a category alone gives
  -- its first page.
  local function Norm(s)
    s = string.gsub(s or "", "|c%x%x%x%x%x%x%x%x", "")
    s = string.gsub(s, "|r", "")
    s = string.gsub(string.lower(s), "[^%w]", "")
    return s
  end
  function O:FindLegacy(cat, page)
    local nc, np = Norm(cat), page and Norm(page)
    local catFirst, anyPage
    for _, grp in ipairs(self.groups or {}) do
      local gname = Norm(grp.header.text:GetText())
      if grp.single then
        if gname == nc and not catFirst then catFirst = grp.single end
      else
        for _, b in ipairs(grp.buttons) do
          local _, _, kc, kp = string.find(b.key or "", "^l:(.-)/(.*)$")
          if kc then
            local sameCat = Norm(kc) == nc
            if sameCat and np and Norm(kp) == np then return b.key end
            if sameCat and not catFirst then catFirst = b.key end
            if np and not anyPage and Norm(kp) == np then anyPage = b.key end
          end
        end
      end
    end
    return catFirst or anyPage
  end

  -- Opens the window on a page: an Octo page key ("ctgeneral"), or a pfUI
  -- category (and page) by their shown names.
  function O:Open(key, page)
    if not g:IsShown() then
      self.opening = true
      g:Show()
      self.opening = nil
    end
    if key and self.BUILD[key] then
      self:Select("o:" .. key)
    elseif key then
      self:Select(self:FindLegacy(key, page) or self.current)
    else
      self:Select(self.current)
    end
  end

  -- ---------------------------------------------------------------- find a setting

  local RESULT_ROWS = 22

  -- Every page built once (hidden), so the search knows every setting.
  function O:BuildAll()
    if self.allBuilt then return end
    for key in pairs(self.BUILD) do
      local p = self:Page(key)
      if self.current ~= "o:" .. key then p.frame:Hide() end
    end
    -- pfUI's pages fill searchDB when first shown
    for _, cat in ipairs(g.frames.order or {}) do
      if cat.area then
        local was = cat.area:IsShown()
        cat.area:Show()
        for _, child in ipairs(cat.children or {}) do
          if child.area and not child.area:IsShown() then
            child.area:Show()
            child.area:Hide()
          end
        end
        if not was then cat.area:Hide() end
      end
    end
    self.allBuilt = true
    if self.current and not self.searching then self:Select(self.current) end
  end

  function O:SearchPage()
    if self.searchPage then return self.searchPage end
    local p = W.Page(self.content)
    p.frame:SetFrameLevel(self.content:GetFrameLevel() + 2)
    W.Heading(p, "Find a setting")
    p.count = W.Live(p, function() return O.searchText or "" end)
    p.rows = {}
    for i = 1, RESULT_ROWS do
      local row = W.Row(p, 22, 0, 2)
      local b = CreateFrame("Button", nil, row)
      b:SetAllPoints(row)
      W.Flat(b, K.card, 1, K.line)
      local hl = W.Fill(b, K.accent, 0.2, "HIGHLIGHT")
      hl:SetPoint("TOPLEFT", b, "TOPLEFT", 1, -1)
      hl:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 1)
      b.text = W.Font(b:CreateFontString(nil, "OVERLAY"), 12, 1, 1, 1)
      b.text:SetPoint("LEFT", b, "LEFT", 10, 0)
      b.text:SetPoint("RIGHT", b, "RIGHT", -8, 0)
      b.text:SetJustifyH("LEFT")
      b:SetScript("OnClick", function() if this.entry then O:Reveal(this.entry) end end)
      row.b = b
      p.rows[i] = row
    end
    W.Done(p)
    self.searchPage = p
    return p
  end

  -- pfUI's own labels that hold the text: { label, where, frame, key }
  local function FindLegacy(text, out)
    local db = g.searchDB
    if not db then return end
    for _, obj in pairs(db) do
      local cap = obj[0]
      if cap and string.find(string.lower(cap), text, 1, true) then
        local n = table.getn(obj)
        local cat, page = obj[n], (n > 1) and obj[1] or nil
        local cname = cat and cat.text and cat.text:GetText()
        local pname = page and page.text and page.text:GetText()
        if cname then
          local key = "l:" .. cname .. (pname and ("/" .. pname) or "")
          table.insert(out, { legacy = true, label = cap, where = cname .. (pname and (" > " .. pname) or ""),
                              key = key, region = obj[-1] })
        end
      end
    end
  end

  function O:Search(text)
    if not self.frame then return end
    text = string.gsub(text or "", "^%s*(.-)%s*$", "%1")
    if string.len(text) < 2 then
      self.results = nil
      if self.searching then
        self.searching = nil
        self:Select(self.current)
      end
      return
    end
    self:BuildAll()
    local res = W.Find(text)
    FindLegacy(string.lower(text), res)
    self.results = res
    local p = self:SearchPage()
    local n = table.getn(res)
    if n == 0 then
      O.searchText = "Nothing matches \"" .. text .. "\"."
    else
      O.searchText = n .. " setting" .. ((n == 1) and "" or "s") .. " mention \"" .. text .. "\" - click one to go to it."
        .. ((n > RESULT_ROWS) and ("  |cff999999(first " .. RESULT_ROWS .. " shown - type more)|r") or "")
    end
    for i = 1, RESULT_ROWS do
      local row, e = p.rows[i], res[i]
      if e then
        row.b.entry = e
        local where
        if e.legacy then
          where = e.where
        else
          where = e.page.title or e.page.key
          if e.card then where = where .. " > " .. e.card.title end
        end
        row.b.text:SetText(e.label .. "   |cff999999" .. where .. "|r")
        row:Show()
      else
        row.b.entry = nil
        row:Hide()
      end
    end
    for _, b in pairs(self.nav) do if b.bar then NavMark(b, false) elseif b.sel then b.sel:Hide() end end
    self.searching = true
    self:Show(p)
  end

  -- Opens a search result's page (and card), scrolls to it and makes it glow.
  function O:Reveal(e)
    self.searching = nil
    if e.legacy then
      self:Select(e.key)
      local region = e.region
      local sf = region and region:GetParent() and region:GetParent().parent
      if sf and sf.SetVerticalScroll then
        local top, at = region:GetParent():GetTop(), region:GetTop()
        if top and at then sf:SetVerticalScroll(math.max(0, top - at - 40)) end
      end
      if region then W.Flash(region) end
      return
    end
    local p = e.page
    self:Select("o:" .. p.key)
    if e.card and not W.IsOpen(e.card) then W.SetOpen(e.card, true) end
    p.after = function()
      local top, at = p.body:GetTop(), e.region:GetTop()
      if top and at then
        local off = math.max(0, top - at - 40)
        local sb = getglobal(p.frame:GetName() .. "ScrollBar")
        if sb then sb:SetValue(off) else p.frame:SetVerticalScroll(off) end
      end
      W.Flash(e.region)
    end
    W.Measure(p)
  end

  -- Re-read the open page (after a setting changed somewhere).
  function O:Refresh()
    if not self.frame or not self.frame:IsShown() then return end
    self:RefreshQuick()
    local p = self.searching and self.searchPage
    if not p and self.current and string.sub(self.current, 1, 2) == "o:" then
      p = self.pages[string.sub(self.current, 3)]
    end
    if p then W.Refresh(p) end
  end

  -- ---------------------------------------------------------------- pfUI's pages, restyled

  -- pfUI's own pages get OctoBG's look once built: group boxes as cards with
  -- a title bar, square blue tick boxes, thin blue sliders with a round knob,
  -- flat text boxes, dropdowns and buttons, Roboto. Layout stays pfUI's.
  local function Field(f, col, line)
    local t = f and (f.backdrop or f)
    if t and t.SetBackdrop then W.Flat(t, col or K.field, 1, line or K.line) end
  end

  -- A pfUI number box ("200", "-12", "0.8") gets a slider beside it (user,
  -- 20 Oct 2026: "using sliders instead of numbers ... having the option to
  -- put numbers in also for accuracy"). The range is a guess from the
  -- setting's name and value; typing a bigger number widens it.
  local function Range(key, v)
    key = string.lower(key or "")
    local function Nice(n) return math.max(10, math.ceil(n / 10) * 10) end
    if (string.find(key, "alpha") or string.find(key, "opacity") or string.find(key, "transp")) and v <= 1 then
      return 0, 1, .05
    end
    if string.find(key, "scale") and v <= 5 then return .5, math.max(2, v), .05 end
    local dec = math.floor(v) ~= v
    if string.find(key, "off") or string.find(key, "pos") or string.find(key, "[xy]$") or v < 0 then
      local lim = Nice(math.max(50, math.abs(v) * 2))
      return -lim, lim, dec and .1 or 1
    end
    return 0, Nice(math.max(20, v * 2)), dec and .1 or 1
  end

  function O.NumberSlider(c)
    local v = tonumber(c.category and c.config and c.category[c.config])
    if not v or c.octoSlider then return end
    local lo, hi, step = Range(c.config, v)
    local inp = c.input
    inp:ClearAllPoints()
    inp:SetPoint("TOPRIGHT", c, "TOPRIGHT", -6, -19)
    inp:SetWidth(64)
    inp:SetHeight(20)
    inp:SetJustifyH("RIGHT")
    local s = W.SliderBar(c, 100, nil)
    s:SetPoint("TOPLEFT", c, "TOPLEFT", 6, -21)
    s:SetPoint("RIGHT", inp, "LEFT", -10, 0)
    s:SetMinMaxValues(lo, hi)
    s:SetValueStep(step)
    c.octoSlider = s
    local function Paint()
      local a, b = s:GetMinMaxValues()
      local w = (s:GetWidth() or 0) - 14
      local f = (b > a) and (s:GetValue() - a) / (b - a) or 0
      if not s.fillToThumb then s.fill:SetWidth(math.max(1, f * math.max(w, 1) + 4)) end
    end
    local function Fmt(n)
      if step >= 1 then return tostring(math.floor(n + .5)) end
      local t = string.format("%.2f", n)
      t = string.gsub(t, "0+$", "")
      return (string.gsub(t, "%.$", ""))
    end
    s.loading = true
    s:SetValue(math.max(lo, math.min(hi, v)))
    s.loading = nil
    s:SetScript("OnValueChanged", function()
      Paint()
      if this.loading then return end
      local n = math.floor(this:GetValue() / step + .5) * step
      -- the text box saves it (its OnTextChanged), as typing would
      inp:SetText(Fmt(n))
    end)
    s:SetScript("OnShow", Paint)
    s:SetScript("OnSizeChanged", Paint)
    local old = inp:GetScript("OnTextChanged")
    inp:SetScript("OnTextChanged", function()
      if old then old() end
      local n = tonumber(this:GetText())
      if n then
        local a, b = s:GetMinMaxValues()
        if n > b then
          local _, nb = Range(c.config, n)
          s:SetMinMaxValues(a, math.max(nb, n))
        end
        s.loading = true
        s:SetValue(n)
        s.loading = nil
        Paint()
      end
    end)
    W.Tip(s, c.caption and c.caption:GetText(), "Drag, or type an exact number in the box.")
    Paint()
  end

  local function SkinCell(c)
    local kind = c.cellkind
    if c.caption then W.Font(c.caption, 12, K.text[1], K.text[2], K.text[3]) end
    if c.tex then c.tex:SetTexture(1, 1, 1, .04) end
    if kind == "checkbox" and c.input and c.input.SetCheckedTexture then
      c.input:SetWidth(16)
      c.input:SetHeight(16)
      Field(c.input, K.field, K.lineHi)
      c.input:SetCheckedTexture(B.U.WHITE)
      local t = c.input:GetCheckedTexture()
      if t then
        t:ClearAllPoints()
        t:SetPoint("TOPLEFT", c.input, "TOPLEFT", 3, -3)
        t:SetPoint("BOTTOMRIGHT", c.input, "BOTTOMRIGHT", -3, 3)
        t:SetVertexColor(K.accent[1], K.accent[2], K.accent[3], 1)
      end
    elseif kind == "slider" and c.input and c.input.SetThumbTexture then
      local s = c.input
      if s.backdrop then s.backdrop:Hide() end
      if s.SetBackdrop then s:SetBackdrop(nil) end
      s:SetHeight(16)
      s:SetThumbTexture(W.ART.disc)
      local th = s:GetThumbTexture()
      if th then
        th:SetWidth(14)
        th:SetHeight(14)
        th:SetVertexColor(.95, .95, .96, 1)
      end
      local track = W.Fill(s, K.off, 1, "BACKGROUND")
      track:SetHeight(4)
      track:SetPoint("LEFT", s, "LEFT", 3, 0)
      track:SetPoint("RIGHT", s, "RIGHT", -3, 0)
      s.fill = W.Fill(s, K.accent, 1, "BORDER")
      s.fill:SetHeight(4)
      s.fill:SetPoint("LEFT", s, "LEFT", 3, 0)
      W.FillToThumb(s)
      local function Paint()
        local lo, hi = s:GetMinMaxValues()
        local w = (s:GetWidth() or 0) - 14
        local f = (hi and lo and hi > lo) and (s:GetValue() - lo) / (hi - lo) or 0
        if not s.fillToThumb then s.fill:SetWidth(math.max(1, f * math.max(w, 1) + 4)) end
      end
      -- the value: a box to type an exact number in
      local box
      if c.value then
        c.value:Hide()
        box = W.NumberBox(c, 64)
        box:SetPoint("TOPRIGHT", c, "TOPRIGHT", -6, -1)
        box.Restore = function() box:SetText(c.value:GetText() or "") end
        box.OnNumber = function(text)
          local n = W.ParseNumber(text)
          if n then s:SetValue(n) end
        end
        box.Restore()
        W.Tip(box, c.caption and c.caption:GetText(), "Click and type a number for an exact value, then press Enter.")
      end
      local old = s:GetScript("OnValueChanged")
      s:SetScript("OnValueChanged", function()
        if old then old() end
        Paint()
        if box and not box.typing then box.Restore() end
      end)
      s:SetScript("OnShow", Paint)
      s:SetScript("OnSizeChanged", Paint)
      Paint()
    elseif kind == "dropdown" and c.input then
      Field(c.input)
      if c.input.text then W.Font(c.input.text, 11, K.text[1], K.text[2], K.text[3]) end
      if c.input.button and c.input.button.icon then
        c.input.button.icon:SetVertexColor(K.dim[1], K.dim[2], K.dim[3], 1)
      end
      if c.input.menuframe then Field(c.input.menuframe, K.card, K.lineHi) end
    elseif (kind == "text" or kind == "list") and c.input then
      Field(c.input)
      if c.input.SetFont then c.input:SetFont(W.UIFont(), 12, "") end
      if kind == "text" and c.numtype == "number" then O.NumberSlider(c) end
    elseif kind == "button" and c.button then
      Field(c.button, K.btn, K.line)
      local fs = c.button.GetFontString and c.button:GetFontString()
      if fs then W.Font(fs, 11, K.text[1], K.text[2], K.text[3]) end
    elseif kind == "color" and c.color then
      Field(c.color, K.field, K.lineHi)
    end
  end

  local function SkinGroup(grp)
    W.Flat(grp, K.card, 1, K.line)
    if grp.caption then
      local bar = W.Fill(grp, K.head, 1, "BORDER")
      bar:SetPoint("TOPLEFT", grp, "TOPLEFT", 1, -1)
      bar:SetPoint("TOPRIGHT", grp, "TOPRIGHT", -1, -1)
      bar:SetHeight(22)
      W.Font(grp.caption, 12, K.text[1], K.text[2], K.text[3])
      grp.caption:ClearAllPoints()
      grp.caption:SetPoint("TOPLEFT", grp, "TOPLEFT", 12, -6)
    end
  end

  function O.SkinPage(page)
    if not page or page.octoSkinned then return end
    page.octoSkinned = true
    if page.title then
      W.Font(page.title, 17, K.text[1], K.text[2], K.text[3])
      -- the section's picture before the title
      local area = page.parent and page.parent.GetParent and page.parent:GetParent()
      local btn = area and area.button
      local cat = btn and (btn.isChild and btn.parent or btn)
      if cat and cat.text then
        local ic = page:CreateTexture(nil, "ARTWORK")
        ic:SetTexture(O.IconFor(cat.text:GetText()))
        ic:SetTexCoord(.08, .92, .08, .92)
        ic:SetWidth(22)
        ic:SetHeight(22)
        local p1, rel, p2, x, y = page.title:GetPoint()
        ic:SetPoint("TOPLEFT", page, "TOPLEFT", x or 12, (y or -12) + 3)
        page.title:ClearAllPoints()
        page.title:SetPoint("TOPLEFT", page, "TOPLEFT", (x or 12) + 30, y or -12)
      end
    end
    for _, grp in ipairs(page.groups or {}) do SkinGroup(grp) end
    for _, c in ipairs({ page:GetChildren() }) do
      if c.cellkind then SkinCell(c) end
    end
  end
  g.OnPageBuilt = O.SkinPage

  -- ---------------------------------------------------------------- open / close

  O:Build()

  local onShow = g:GetScript("OnShow")
  g:SetScript("OnShow", function()
    if onShow then onShow() end
    -- categories added since (late modules, the search page) join the list
    if O.navCount ~= O:CountLegacy() then O:BuildNav() end
    O.first = O.first or (O.octo[1] and O.octo[1][2][1] and ("o:" .. O.octo[1][2][1][1]))
    O:RefreshQuick()
    O:LayoutNav()
    if not O.opening then O:Select(O.current) end
  end)
  local onHide = g:GetScript("OnHide")
  g:SetScript("OnHide", function()
    W.CloseMenus()
    if onHide then onHide() end
  end)
end)

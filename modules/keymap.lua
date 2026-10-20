pfUI:RegisterModule("keymap", "vanilla", function ()
  -- pfUI Octo :: Key Map - a picture of your keyboard with what every key does.
  -- User, 20 Oct 2026 (screenshot of a retail "KeyMap" addon): the Keybinds
  -- button offers the original hover binding or this keyboard layout.
  --
  -- Every key shows its binding: the spell's icon when the key works an
  -- action button (or, with ClassicAPI, casts a spell / uses a macro), else
  -- the binding's name. Layers: base, Shift, Ctrl, Alt (click the modifier
  -- keys or the layer buttons; holding the modifier shows that layer too).
  --   drop a spell / item / macro on a key  -> bind it (an action button key
  --                                            gets it on its button)
  --   left-click a key                      -> pick its binding up; click
  --                                            another key to move / swap
  --   right-click                           -> unbind
  --   Unbound abilities                     -> action bar buttons with no key:
  --                                            click one, then a key
  -- Client facts (WoW.exe strings): SetBinding / GetBindingAction /
  -- GetBindingKey / SaveBindings / GetCurrentBindingSet / PickupAction /
  -- PlaceAction / CursorHasSpell / CursorHasItem / ClearCursor. ClassicAPI.dll
  -- adds GetCursorInfo, SetBindingSpell / Item / Macro ("Usage:" strings in the
  -- DLL); its returns follow retail's and are not verified on this client.

  local OU = pfUI.octoui
  local W = OU and OU.W
  if not W then return end
  local K = W.C

  local KM = { layer = "", keys = {}, cells = {} }
  pfUI.keymap = KM

  -- ---------------------------------------------------------------- what keys do

  -- action button binding commands -> action slot (Blizzard's bar layout,
  -- the same pfUI's bars use: actionbar.lua bar ids)
  local BARS = { ACTIONBUTTON = 0, MULTIACTIONBAR1BUTTON = 60, MULTIACTIONBAR2BUTTON = 48,
                 MULTIACTIONBAR3BUTTON = 24, MULTIACTIONBAR4BUTTON = 36 }
  function KM.SlotOf(action)
    if not action then return nil end
    local _, _, cmd, n = string.find(action, "^(%u+%d?%u+)(%d+)$")
    n = tonumber(n)
    if cmd and n and BARS[cmd] and n >= 1 and n <= 12 then return BARS[cmd] + n end
    return nil
  end
  function KM.CommandOf(slot)
    for cmd, base in pairs(BARS) do
      if slot > base and slot <= base + 12 then return cmd .. (slot - base) end
    end
    return nil
  end

  local function SpellTexture(name)
    if not name or not GetSpellName then return nil end
    local i = 1
    while true do
      local n = GetSpellName(i, BOOKTYPE_SPELL or "spell")
      if not n then return nil end
      if n == name then return GetSpellTexture(i, BOOKTYPE_SPELL or "spell") end
      i = i + 1
    end
  end

  -- icon and short name of a binding command
  function KM.Describe(action)
    if not action or action == "" then return nil, nil end
    local slot = KM.SlotOf(action)
    if slot then
      local tex = HasAction(slot) and GetActionTexture(slot)
      local text = GetActionText and GetActionText(slot)
      return tex, text or (GetBindingText and GetBindingText(action, "BINDING_NAME_")) or action
    end
    local _, _, kind, what = string.find(action, "^(%u+) (.+)$")
    if kind == "SPELL" then
      local name = string.gsub(what, "%(.-%)$", "")
      return SpellTexture(name), name
    elseif kind == "MACRO" then
      local idx = GetMacroIndexByName and GetMacroIndexByName(what)
      if idx and idx > 0 then
        local name, tex = GetMacroInfo(idx)
        return tex, name
      end
      return nil, what
    elseif kind == "ITEM" then
      return nil, what
    end
    return nil, (GetBindingText and GetBindingText(action, "BINDING_NAME_")) or action
  end

  local function Save()
    SaveBindings(GetCurrentBindingSet and GetCurrentBindingSet() or 1)
    KM:Refresh()
  end

  -- ---------------------------------------------------------------- layouts

  -- rows of { label, key name (nil = not bindable / a modifier), width in units }
  local function Row(list) return list end
  local LETTERS = {
    uk = { "QWERTYUIOP[]", "ASDFGHJKL;'#", "\\ZXCVBNM,./" },
    us = { "QWERTYUIOP[]\\", "ASDFGHJKL;'", "ZXCVBNM,./" },
    de = { "QWERTZUIOP[]", "ASDFGHJKL;'#", "<YXCVBNM,./" },
    fr = { "AZERTYUIOP[]", "QSDFGHJKLM'#", "<WXCVBN,;:!" },
  }
  KM.LAYOUTS = { { key = "uk", label = "English QWERTY (UK)" }, { key = "us", label = "English QWERTY (US)" },
                 { key = "de", label = "Deutsch QWERTZ" }, { key = "fr", label = "Français AZERTY" } }

  local function Chars(s)
    local out = {}
    for ch in string.gfind(s, ".") do table.insert(out, { ch, ch, 1 }) end
    return out
  end

  function KM.Rows(layout)
    local L = LETTERS[layout] or LETTERS.uk
    local rows = {}
    local f = { { "Esc", nil, 1 }, { "", nil, .5 } }
    for i = 1, 12 do
      table.insert(f, { "F" .. i, "F" .. i, 1 })
      if i == 4 or i == 8 then table.insert(f, { "", nil, .5 }) end
    end
    table.insert(rows, f)
    local num = { { "`", "`", 1 } }
    for _, d in ipairs({ "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "-", "=" }) do table.insert(num, { d, d, 1 }) end
    table.insert(num, { "Back", "BACKSPACE", 2 })
    table.insert(rows, num)
    local r1 = { { "Tab", "TAB", 1.5 } }
    for _, c in ipairs(Chars(L[1])) do table.insert(r1, c) end
    if layout ~= "us" then table.insert(r1, { "Enter", "ENTER", 1.5 }) end
    table.insert(rows, r1)
    local r2 = { { "Caps", "CAPSLOCK", 1.75 } }
    for _, c in ipairs(Chars(L[2])) do table.insert(r2, c) end
    if layout == "us" then table.insert(r2, { "Enter", "ENTER", 2.25 }) end
    table.insert(rows, r2)
    local r3 = { { "Shift", "*SHIFT", (layout == "us") and 2.25 or 1.25 } }
    for _, c in ipairs(Chars(L[3])) do table.insert(r3, c) end
    table.insert(r3, { "Shift", "*SHIFT", 2.75 })
    table.insert(rows, r3)
    table.insert(rows, { { "Ctrl", "*CTRL", 1.5 }, { "", nil, 1 }, { "Alt", "*ALT", 1.5 }, { "Space", "SPACE", 6.5 },
                         { "Alt", "*ALT", 1.5 }, { "", nil, 1 }, { "Ctrl", "*CTRL", 1.5 } })
    table.insert(rows, { { "Mouse 3", "BUTTON3", 2 }, { "Mouse 4", "BUTTON4", 2 }, { "Mouse 5", "BUTTON5", 2 },
                         { "Wheel Up", "MOUSEWHEELUP", 2 }, { "Wheel Down", "MOUSEWHEELDOWN", 2 } })
    return rows
  end

  -- ---------------------------------------------------------------- the window

  local UNIT, GAP, PAD = 50, 4, 14
  local PANEL_W = 210

  local function Full(key)
    if not key then return nil end
    return KM.layer .. key
  end

  local function Tip(b)
    local key = Full(b.key)
    local action = GetBindingAction(key)
    GameTooltip:SetOwner(b, "ANCHOR_TOP")
    local _, name = KM.Describe(action)
    GameTooltip:AddLine(name or "Not bound", 1, 1, 1)
    GameTooltip:AddDoubleLine("Key", key, .6, .6, .6, 1, 1, 1)
    if action and action ~= "" then GameTooltip:AddDoubleLine("Binding", action, .6, .6, .6, 1, 1, 1) end
    GameTooltip:AddLine("Drop a spell, item or macro to bind it. Left-click: pick up / move / swap. Right-click: unbind.",
      K.accent[1], K.accent[2], K.accent[3], 1)
    GameTooltip:Show()
  end

  local function CursorHasSomething()
    if CursorHasSpell and CursorHasSpell() then return true end
    if CursorHasItem and CursorHasItem() then return true end
    if GetCursorInfo and GetCursorInfo() then return true end
    return false
  end

  -- a free action slot on a bar (for a dropped spell on an unbound key)
  local function FreeSlot()
    for _, base in ipairs({ 0, 60, 48, 24, 36 }) do
      for n = 1, 12 do
        if not HasAction(base + n) then return base + n end
      end
    end
    return nil
  end

  -- whatever is on the cursor goes onto this key
  function KM.Drop(key)
    key = Full(key)
    local action = GetBindingAction(key)
    local slot = KM.SlotOf(action)
    if slot then
      -- an action button key: the spell goes on its button (what was there
      -- comes back onto the cursor, as dragging between buttons does)
      PlaceAction(slot)
      Save()
      return true
    end
    if GetCursorInfo then
      local kind, a, b = GetCursorInfo()
      local done
      if kind == "spell" and SetBindingSpell and GetSpellName then
        local name = GetSpellName(a, b or BOOKTYPE_SPELL or "spell")
        if name then SetBindingSpell(key, name) done = true end
      elseif kind == "item" and SetBindingItem then
        local _, _, name = string.find(tostring(b or ""), "%[(.-)%]")
        if not name and GetItemInfo then name = GetItemInfo(a) end
        if name then SetBindingItem(key, name) done = true end
      elseif kind == "macro" and SetBindingMacro then
        SetBindingMacro(key, a)
        done = true
      end
      if done then
        ClearCursor()
        Save()
        return true
      end
    end
    -- no ClassicAPI: put it on a free action button and bind the key to it
    local free = FreeSlot()
    if free then
      PlaceAction(free)
      SetBinding(key, KM.CommandOf(free))
      Save()
      return true
    end
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffpfUI|r: no free action button to put it on - free one up first.")
    return false
  end

  local function KeyClick()
    local b = this
    if b.modifier then
      KM.locked = (KM.layer == b.modifier .. "-") and "" or (b.modifier .. "-")
      KM.layer = KM.locked
      KM:Refresh()
      return
    end
    if not b.key then return end
    local key = Full(b.key)
    if arg1 == "RightButton" then
      SetBinding(key)
      KM.picked, KM.pickedAction = nil, nil
      Save()
      return
    end
    if CursorHasSomething() then
      KM.Drop(b.key)
      return
    end
    if KM.ability then
      -- an unbound ability picked on the right: this key works its button
      SetBinding(key, KM.CommandOf(KM.ability))
      KM.ability = nil
      Save()
      return
    end
    if KM.picked then
      if KM.picked ~= key then
        local mine = GetBindingAction(key)
        SetBinding(key, KM.pickedAction)
        if mine and mine ~= "" then SetBinding(KM.picked, mine) else SetBinding(KM.picked) end
      end
      KM.picked, KM.pickedAction = nil, nil
      Save()
      return
    end
    local action = GetBindingAction(key)
    if action and action ~= "" then
      KM.picked, KM.pickedAction = key, action
      KM:Refresh()
    end
  end

  local function MakeKey(parent)
    local b = CreateFrame("Button", nil, parent)
    W.Flat(b, K.field, 1, K.line)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    W.Hover(b, .08)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetTexCoord(.08, .92, .08, .92)
    b.icon:SetPoint("TOPLEFT", b, "TOPLEFT", 3, -3)
    b.icon:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -3, 3)
    b.icon:SetAlpha(.85)
    b.label = W.Font(b:CreateFontString(nil, "OVERLAY"), 11, 1, 1, 1)
    b.label:SetPoint("TOPLEFT", b, "TOPLEFT", 4, -3)
    b.what = W.Font(b:CreateFontString(nil, "OVERLAY"), 9, K.dim[1], K.dim[2], K.dim[3])
    b.what:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 3, 3)
    b.what:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -3, 3)
    b.what:SetJustifyH("CENTER")
    b.what:SetHeight(11)
    b:SetScript("OnClick", KeyClick)
    b:SetScript("OnReceiveDrag", function() if this.key then KM.Drop(this.key) end end)
    b:SetScript("OnEnter", function() if this.key then Tip(this) end end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
  end

  function KM:Build()
    local f = CreateFrame("Frame", "pfKeyMap", UIParent)
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetClampedToScreen(true)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
    W.Flat(f, K.bg, .97, K.lineHi)
    f:Hide()
    table.insert(UISpecialFrames, "pfKeyMap")
    f:SetScript("OnMouseDown", function() this:StartMoving() end)
    f:SetScript("OnMouseUp", function() this:StopMovingOrSizing() end)
    f:SetScript("OnShow", function() KM:Refresh() end)
    f:SetScript("OnHide", function()
      KM.picked, KM.ability = nil, nil
      W.CloseMenus()
    end)
    -- holding a modifier shows its layer (when no layer is clicked on)
    f:SetScript("OnUpdate", function()
      if KM.locked and KM.locked ~= "" then return end
      local l = (IsShiftKeyDown() and "SHIFT-") or (IsControlKeyDown() and "CTRL-") or (IsAltKeyDown() and "ALT-") or ""
      if l ~= KM.layer then
        KM.layer = l
        KM:Refresh()
      end
    end)
    self.frame = f

    local title = W.Font(f:CreateFontString(nil, "OVERLAY"), 15, K.text[1], K.text[2], K.text[3])
    title:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -10)
    title:SetText("|cff33ccffKey|r Map")
    self.layerText = W.Font(f:CreateFontString(nil, "OVERLAY"), 15, K.text[1], K.text[2], K.text[3])
    self.layerText:SetPoint("TOP", f, "TOP", -PANEL_W / 2, -10)
    local close = W.Button(f, "X", 22, 22)
    close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -6)
    close:SetScript("OnClick", function() f:Hide() end)

    -- tool bar: keyboard layout, layers, unbound list, hover binding
    local bar = CreateFrame("Frame", nil, f)
    bar:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -36)
    bar:SetHeight(24)
    bar:SetWidth(600)
    local lay, layRefresh = W.MiniDrop(bar, 170, KM.LAYOUTS, function() return KM.Store().layout or "uk" end,
      function(v) KM.Store().layout = v KM:Layout() end, 190)
    lay:SetPoint("LEFT", bar, "LEFT", 0, 0)
    self.layRefresh = layRefresh
    local x = 180
    self.layerButtons = {}
    for _, l in ipairs({ { "", "Base" }, { "SHIFT-", "Shift" }, { "CTRL-", "Ctrl" }, { "ALT-", "Alt" } }) do
      local b = W.Button(bar, l[2], 58, 22)
      b:SetPoint("LEFT", bar, "LEFT", x, 0)
      b.layer = l[1]
      b:SetScript("OnClick", function()
        KM.locked = this.layer
        KM.layer = this.layer
        KM:Refresh()
      end)
      table.insert(self.layerButtons, b)
      x = x + 62
    end
    local unb = W.Button(bar, "Unbound", 80, 22)
    unb:SetPoint("LEFT", bar, "LEFT", x + 10, 0)
    unb:SetScript("OnClick", function()
      KM.Store().hidePanel = not KM.Store().hidePanel
      KM:Layout()
    end)
    W.Tip(unb, "Unbound abilities", "Show or hide the list of action bar buttons that have no key.")
    local quick = W.Button(bar, "Quick Keybind", 110, 22)
    quick:SetPoint("LEFT", unb, "RIGHT", 6, 0)
    quick:SetScript("OnClick", function()
      f:Hide()
      if pfUI.hoverbind then pfUI.hoverbind:Show() end
    end)
    W.Tip(quick, "Quick Keybind", "pfUI's hover binding: hover an action button and press a key.")

    self.board = CreateFrame("Frame", nil, f)
    self.board:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -70)

    -- unbound abilities
    local panel = CreateFrame("Frame", nil, f)
    panel:SetWidth(PANEL_W)
    panel:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PAD, -70)
    panel:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -PAD, 30)
    W.Flat(panel, K.panel, 1, K.line)
    local pt = W.Font(panel:CreateFontString(nil, "OVERLAY"), 12, K.accent[1], K.accent[2], K.accent[3])
    pt:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -8)
    pt:SetText("Unbound abilities")
    local ps = W.Font(panel:CreateFontString(nil, "OVERLAY"), 10, K.dim[1], K.dim[2], K.dim[3])
    ps:SetPoint("TOPLEFT", pt, "BOTTOMLEFT", 0, -3)
    ps:SetText("Click one, then click a key to bind it.")
    self.panel = panel
    self.abilities = {}

    local help = W.Font(f:CreateFontString(nil, "OVERLAY"), 10, K.dim[1], K.dim[2], K.dim[3])
    help:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", PAD, 10)
    help:SetText("Drag spells, macros or items onto keys  |  Click a key to pick it up, click another to move / swap  |  "
      .. "Right-click unbinds  |  Hold or click Shift / Ctrl / Alt for their layers")
    self:Layout()
  end

  function KM.Store()
    local s = OU.Store()
    if type(s.keymap) ~= "table" then s.keymap = {} end
    return s.keymap
  end

  -- places the keys for the chosen keyboard and sizes the window
  function KM:Layout()
    if not self.frame then return end
    for _, c in ipairs(self.cells) do c:Hide() end
    local rows = KM.Rows(KM.Store().layout or "uk")
    local n, maxw, y = 0, 0, 0
    for r, row in ipairs(rows) do
      local x = 0
      if r == 2 or r == table.getn(rows) then y = y + 8 end
      for _, k in ipairs(row) do
        local w = k[3] * UNIT + (k[3] - 1) * GAP
        if k[2] or k[1] ~= "" then
          n = n + 1
          local b = self.cells[n] or MakeKey(self.board)
          self.cells[n] = b
          b:ClearAllPoints()
          b:SetPoint("TOPLEFT", self.board, "TOPLEFT", x, -y)
          b:SetWidth(w)
          b:SetHeight(UNIT - 6)
          b.text = k[1]
          b.label:SetText(k[1])
          b.modifier = nil
          b.key = nil
          if k[2] and string.sub(k[2], 1, 1) == "*" then
            b.modifier = string.sub(k[2], 2)
          else
            b.key = k[2]
          end
          b:Show()
        end
        x = x + w + GAP
      end
      if x > maxw then maxw = x end
      y = y + UNIT - 6 + GAP
    end
    self.board:SetWidth(maxw)
    self.board:SetHeight(y)
    local panel = not KM.Store().hidePanel
    if panel then self.panel:Show() else self.panel:Hide() end
    self.frame:SetWidth(PAD * 2 + maxw + (panel and (PANEL_W + 12) or 0))
    self.frame:SetHeight(70 + y + 34)
    if self.layRefresh then self.layRefresh() end
    self:Refresh()
  end

  local NAMES = { [""] = "Base layer", ["SHIFT-"] = "Shift layer", ["CTRL-"] = "Ctrl layer", ["ALT-"] = "Alt layer" }

  function KM:Refresh()
    if not self.frame or not self.frame:IsShown() then return end
    self.layerText:SetText(NAMES[self.layer] or "")
    for _, b in ipairs(self.layerButtons) do W.Pick(b, b.layer == self.layer) end
    for _, b in ipairs(self.cells) do
      if b:IsShown() then
        local key = b.key and Full(b.key)
        local action = key and GetBindingAction(key)
        local tex, name = KM.Describe(action)
        b.icon:SetTexture(tex)
        if tex then b.icon:Show() else b.icon:Hide() end
        b.what:SetText(b.key and (tex and "" or (name or "")) or "")
        local col, line = K.field, K.line
        if b.modifier then
          col = (self.layer == b.modifier .. "-") and K.head or K.btn
          line = (self.layer == b.modifier .. "-") and K.accent or K.line
        elseif not b.key then
          col = K.panel
        elseif action and action ~= "" then
          col, line = K.card, K.lineHi
        end
        if key and key == self.picked then line = { 1, .82, 0 } end
        b:SetBackdropColor(col[1], col[2], col[3], 1)
        b:SetBackdropBorderColor(line[1], line[2], line[3], 1)
        if b.key or b.modifier then b.label:SetTextColor(1, 1, 1) else b.label:SetTextColor(K.dim[1], K.dim[2], K.dim[3]) end
      end
    end
    self:RefreshAbilities()
  end

  -- action bar buttons with a spell / item / macro and no key
  function KM.Unbound()
    local out = {}
    for _, base in ipairs({ 0, 60, 48, 24, 36 }) do
      for n = 1, 12 do
        local slot = base + n
        if HasAction(slot) then
          local cmd = KM.CommandOf(slot)
          if cmd and not GetBindingKey(cmd) then table.insert(out, slot) end
        end
      end
    end
    return out
  end

  function KM:RefreshAbilities()
    if not self.panel:IsShown() then return end
    for _, a in ipairs(self.abilities) do a:Hide() end
    local per, size = 5, 34
    for i, slot in ipairs(KM.Unbound()) do
      local a = self.abilities[i]
      if not a then
        a = CreateFrame("Button", nil, self.panel)
        a:SetWidth(size)
        a:SetHeight(size)
        W.Flat(a, K.field, 1, K.line)
        a.icon = a:CreateTexture(nil, "ARTWORK")
        a.icon:SetTexCoord(.08, .92, .08, .92)
        a.icon:SetPoint("TOPLEFT", a, "TOPLEFT", 2, -2)
        a.icon:SetPoint("BOTTOMRIGHT", a, "BOTTOMRIGHT", -2, 2)
        W.Hover(a, .15)
        a:SetScript("OnClick", function()
          KM.ability = (KM.ability ~= this.slot) and this.slot or nil
          KM:Refresh()
        end)
        a:SetScript("OnEnter", function()
          GameTooltip:SetOwner(this, "ANCHOR_LEFT")
          GameTooltip:SetAction(this.slot)
          GameTooltip:Show()
        end)
        a:SetScript("OnLeave", function() GameTooltip:Hide() end)
        self.abilities[i] = a
      end
      a.slot = slot
      a.icon:SetTexture(GetActionTexture(slot))
      local row, col = math.floor((i - 1) / per), math.mod(i - 1, per)
      a:ClearAllPoints()
      a:SetPoint("TOPLEFT", self.panel, "TOPLEFT", 8 + col * (size + 6), -44 - row * (size + 6))
      local picked = KM.ability == slot
      local l = picked and K.accent or K.line
      a:SetBackdropBorderColor(l[1], l[2], l[3], 1)
      a:Show()
    end
  end

  function KM:Toggle()
    if not self.frame then self:Build() end
    if self.frame:IsShown() then self.frame:Hide() else
      if pfUI.gui and pfUI.gui:IsShown() then pfUI.gui:Hide() end
      self.frame:Show()
    end
  end

  local ev = CreateFrame("Frame")
  for _, e in ipairs({ "UPDATE_BINDINGS", "ACTIONBAR_SLOT_CHANGED", "SPELLS_CHANGED" }) do pcall(ev.RegisterEvent, ev, e) end
  ev:SetScript("OnEvent", function() if KM.frame and KM.frame:IsShown() then KM:Refresh() end end)

  _G.SLASH_PFKEYMAP1, _G.SLASH_PFKEYMAP2 = "/keymap", "/km"
  _G.SlashCmdList.PFKEYMAP = function() KM:Toggle() end
end)

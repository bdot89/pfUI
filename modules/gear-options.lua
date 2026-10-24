pfUI:RegisterModule("gear-options", "vanilla", function ()
  -- pfUI Octo :: the Gear section (24 Oct 2026, modules/gear.lua, gear-sheet.lua,
  -- gear-slots.lua). Gear sets: a set editor as ItemRack's / Outfitter's (saved sets
  -- on the left, the slots as on the character sheet with a tick each, the
  -- character wearing the set between them) and cards for the set, the buttons,
  -- swapping, the character window and the trinket bar. Slot buttons: its own page.
  local OU = pfUI.octoui
  local W = OU and OU.W
  local O = OU and OU.Options
  local GR = pfUI.gear
  if not W or not O or not O.AddPage or not GR then return end
  local GO = {}
  pfUI.gearOcto = GO

  local function G() return C.gear end
  local function U() GR.Changed() end
  local function Px(v) return v .. " px" end
  local function Chk(p, label, desc, key) return O.PfChk(p, label, desc, G, key, U) end
  local function Sld(p, label, desc, min, max, step, key, fmt) return O.PfSld(p, label, desc, min, max, step, G, key, U, fmt) end
  local function Accent()
    if GetAccentColor then return GetAccentColor() end
    return .2, .55, .9
  end
  local function Flat(f, a)
    f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    f:SetBackdropColor(.06, .06, .08, a or .95)
    f:SetBackdropBorderColor(.2, .2, .24, 1)
  end

  -- the set being changed on the page
  function GO.Set() return GO.edit and C.gear.sets[GO.edit] end
  local function PickSet()
    if GO.edit and C.gear.sets[GO.edit] then return end
    GO.edit = GR.Current() or GR.Sets()[1]
  end
  function GO.Open(name)
    if name then GO.edit = name end
    if pfUI.plates and pfUI.plates.OpenSection then pfUI.plates.OpenSection("gearsets") else O:Open("gearsets") end
  end
  function GO.NewSet()
    local n = 1
    while C.gear.sets["Set " .. n] do n = n + 1 end
    GR.Save("Set " .. n, GR.Snapshot())
    GO.edit = "Set " .. n
    GR.Changed()
    return GO.edit
  end

  -- ---------------------------------------------------------------- set editor

  -- the slot buttons page lays slots out in three rows
  GO.ROWS = { { 1, 2, 3, 15, 5, 4, 19, 9 }, { 10, 6, 7, 8, 11, 12, 13, 14 }, { 16, 17, 18 } }
  local EMPTY = {}
  for _, s in ipairs(GR.SLOTS) do
    local _, tex = GetInventorySlotInfo and GetInventorySlotInfo(s[2])
    EMPTY[s[1]] = tex
  end
  -- the set editor as ItemRack's / Outfitter's (user, 24 Oct 2026: the first
  -- version "makes no sense"): the slots where the character sheet has them,
  -- a tick on each for "in this set", the character wearing the set between
  -- them, the saved sets listed on the left
  GO.LEFT = { 1, 2, 3, 15, 5, 4, 19, 9 }
  GO.RIGHT = { 10, 6, 7, 8, 11, 12, 13, 14 }
  GO.BOTTOM = { 16, 17, 18 }
  -- rings, trinkets and one-hand weapons can come from the other slot of the pair
  local PAIR = { [11] = 12, [12] = 11, [13] = 14, [14] = 13, [16] = 17, [17] = 16 }


  local function Editor(p)
    local box = W.Box(p, 392)
    local holder = CreateFrame("Frame", nil, box)
    holder:SetAllPoints(box)
    GO.holder = holder
    local BW = box:GetWidth() or 668
    local SZ, GAP = 36, 4
    local ar, ag, ab = Accent()

    -- left: the saved sets
    local title = holder:CreateFontString(nil, "OVERLAY")
    title:SetFont(W.UIFont(), 12, "OUTLINE")
    title:SetPoint("TOPLEFT", box, "TOPLEFT", 12, -12)
    title:SetText("Saved sets")
    GO.rows = {}
    local function Row(i)
      local r = GO.rows[i]
      if r then return r end
      r = CreateFrame("Button", nil, holder)
      r:SetWidth(176)
      r:SetHeight(24)
      r:SetPoint("TOPLEFT", box, "TOPLEFT", 8, -32 - (i - 1) * 26)
      Flat(r, 1)
      r.icon = r:CreateTexture(nil, "ARTWORK")
      r.icon:SetWidth(20)
      r.icon:SetHeight(20)
      r.icon:SetPoint("LEFT", r, "LEFT", 2, 0)
      r.icon:SetTexCoord(.07, .93, .07, .93)
      r.text = r:CreateFontString(nil, "OVERLAY")
      r.text:SetFont(W.UIFont(), 11, "OUTLINE")
      r.text:SetPoint("LEFT", r.icon, "RIGHT", 6, 0)
      r.text:SetPoint("RIGHT", r, "RIGHT", -36, 0)
      r.text:SetJustifyH("LEFT")
      r.worn = r:CreateFontString(nil, "OVERLAY")
      r.worn:SetFont(W.UIFont(), 10, "OUTLINE")
      r.worn:SetPoint("RIGHT", r, "RIGHT", -5, 0)
      r.worn:SetTextColor(.3, 1, .4)
      r.worn:SetText("worn")
      r:SetScript("OnClick", function() GO.edit = this.set GR.Changed() O:Refresh() end)
      r:SetScript("OnDoubleClick", function() GR.Equip(this.set) end)
      r:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
        GameTooltip:AddLine(this.set)
        GameTooltip:AddLine("Click: change it here", 1, 1, 1)
        GameTooltip:AddLine("Double-click: wear it", 1, 1, 1)
        GameTooltip:Show()
      end)
      r:SetScript("OnLeave", function() GameTooltip:Hide() end)
      GO.rows[i] = r
      return r
    end
    local newBtn = W.Button(holder, "New set", 176, 22)
    newBtn:SetPoint("BOTTOMLEFT", box, "BOTTOMLEFT", 8, 30)
    newBtn:SetScript("OnClick", function()
      GO.NewSet()
      O:Refresh()
      if GO.name then GO.name:SetFocus() GO.name:HighlightText() end
    end)
    W.Tip(newBtn, "New set", "Everything you wear now, as a new set. Untick the slots it should leave alone.")

    -- the slots, as on the character sheet
    local midL = 196 + SZ + 10
    local midR = BW - 10 - SZ - 10
    GO.slots = {}
    local function Slot(inv, x, y)
      local s = CreateFrame("Button", nil, holder)
      s.inv = inv
      s:SetWidth(SZ)
      s:SetHeight(SZ)
      s:SetPoint("TOPLEFT", box, "TOPLEFT", x, y)
      Flat(s, 1)
      s.icon = s:CreateTexture(nil, "ARTWORK")
      s.icon:SetPoint("TOPLEFT", s, "TOPLEFT", 1, -1)
      s.icon:SetPoint("BOTTOMRIGHT", s, "BOTTOMRIGHT", -1, 1)
      s.icon:SetTexCoord(.07, .93, .07, .93)
      s.off = s:CreateTexture(nil, "OVERLAY")
      s.off:SetTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
      s.off:SetWidth(20)
      s.off:SetHeight(20)
      s.off:SetPoint("CENTER", s, "CENTER", 0, 0)
      -- the tick: in this set or not
      s.tick = CreateFrame("CheckButton", nil, s)
      s.tick:SetWidth(16)
      s.tick:SetHeight(16)
      s.tick:SetPoint("TOPLEFT", s, "TOPLEFT", -6, 6)
      s.tick:SetFrameLevel(s:GetFrameLevel() + 3)
      s.tick:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
      s.tick:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
      s.tick:SetScript("OnClick", function() GO.ToggleSlot(this:GetParent().inv) end)
      s.tick:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
        GameTooltip:AddLine(GR.NAME[this:GetParent().inv])
        GameTooltip:AddLine("Ticked: the set puts this slot on. Unticked: it leaves this slot as it is.", 1, 1, 1, 1)
        GameTooltip:Show()
      end)
      s.tick:SetScript("OnLeave", function() GameTooltip:Hide() end)
      s:RegisterForClicks("LeftButtonUp", "RightButtonUp")
      s:SetScript("OnClick", function()
        if arg1 == "RightButton" then GO.ToggleSlot(this.inv) return end
        GO.PickFor(this)
      end)
      s:SetScript("OnEnter", function()
        local set = GO.Set()
        local e = set and set.slots[GR.Key(this.inv)]
        GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
        if type(e) == "table" and e.id then
          -- (the item's own tooltip, when the client knows it)
          local okTip = pcall(GameTooltip.SetHyperlink, GameTooltip, "item:" .. e.id .. ":0")
          if not okTip or (GameTooltip:NumLines() or 0) == 0 then GameTooltip:AddLine(e.name or "") end
        else
          GameTooltip:AddLine(GR.NAME[this.inv])
          if e == "empty" then GameTooltip:AddLine("The set takes this off.", 1, .5, .5)
          elseif e == nil then GameTooltip:AddLine("Not in this set: it stays as it is.", .7, .7, .7, 1) end
        end
        GameTooltip:AddLine("Click: pick its item  -  Right-click: in the set or not", .6, .8, 1)
        GameTooltip:Show()
      end)
      s:SetScript("OnLeave", function() GameTooltip:Hide() end)
      table.insert(GO.slots, s)
      return s
    end
    for i, inv in ipairs(GO.LEFT) do Slot(inv, 196, -12 - (i - 1) * (SZ + GAP)) end
    for i, inv in ipairs(GO.RIGHT) do Slot(inv, BW - 10 - SZ, -12 - (i - 1) * (SZ + GAP)) end
    local mid = (midL + midR) / 2
    for i, inv in ipairs(GO.BOTTOM) do Slot(inv, mid - (3 * SZ + 2 * GAP) / 2 + (i - 1) * (SZ + GAP), -12 - 7 * (SZ + GAP)) end

    -- the middle: icon and name, the character, the buttons
    local icon = CreateFrame("Button", nil, holder)
    icon:SetWidth(30)
    icon:SetHeight(30)
    icon:SetPoint("TOPLEFT", box, "TOPLEFT", midL, -12)
    Flat(icon, 1)
    icon.tex = icon:CreateTexture(nil, "ARTWORK")
    icon.tex:SetPoint("TOPLEFT", icon, "TOPLEFT", 1, -1)
    icon.tex:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -1, 1)
    icon.tex:SetTexCoord(.07, .93, .07, .93)
    -- (click: the next picture from the set's own items)
    icon:SetScript("OnClick", function()
      local set = GO.Set()
      if not set then return end
      local list, at = {}, 0
      for _, s in ipairs(GR.SLOTS) do
        local e = set.slots[GR.Key(s[1])]
        if type(e) == "table" and e.tex and e.tex ~= "" then
          table.insert(list, e.tex)
          if e.tex == set.icon then at = table.getn(list) end
        end
      end
      if table.getn(list) > 0 then set.icon = list[math.mod(at, table.getn(list)) + 1] GR.Changed() end
    end)
    W.Tip(icon, "Icon", "Click for the next picture from the set's items (more on the This set card).")
    local name = W.EditBox(holder, midR - midL - 40)
    name:SetPoint("LEFT", icon, "RIGHT", 8, 0)
    name:SetScript("OnEnterPressed", function()
      local v = this:GetText()
      if GO.edit and v ~= "" and GR.Rename(GO.edit, v) then GO.edit = v end
      this:ClearFocus()
      O:Refresh()
    end)
    name:SetScript("OnEscapePressed", function() this:SetText(GO.edit or "") this:ClearFocus() end)
    name:SetScript("OnEditFocusGained", function() GO.typing = true end)
    name:SetScript("OnEditFocusLost", function() GO.typing = nil end)
    GO.name = name
    W.Tip(name, "Name", "Type a name and press Enter.")

    -- the character, wearing the set (drag to turn it)
    local model = CreateFrame("DressUpModel", nil, holder)
    model:SetPoint("TOPLEFT", box, "TOPLEFT", midL, -50)
    model:SetPoint("BOTTOMRIGHT", box, "TOPLEFT", midR, -12 - 7 * (SZ + GAP) + 4)
    model:EnableMouse(true)
    model:SetScript("OnMouseDown", function() this.turnX = GetCursorPosition() this.turnF = this.facing or 0 end)
    model:SetScript("OnMouseUp", function() this.turnX = nil end)
    model:SetScript("OnUpdate", function()
      if not this.turnX then return end
      local x = GetCursorPosition()
      this.facing = this.turnF + (x - this.turnX) / 80
      if this.SetFacing then this:SetFacing(this.facing) end
    end)
    GO.model = model
    local function Dress()
      if not model.SetUnit then return end
      pcall(model.SetUnit, model, "player")
      if model.SetFacing then model:SetFacing(model.facing or 0) end
      local set = GO.Set()
      for _, e in pairs(set and set.slots or {}) do
        if type(e) == "table" and e.id and model.TryOn then pcall(model.TryOn, model, "item:" .. e.id .. ":0") end
      end
    end
    GO.Dress = Dress

    -- the buttons under the character
    local function Btn(text, x, w, fn, tip)
      local b = W.Button(holder, text, w, 22)
      b:SetPoint("TOPLEFT", box, "TOPLEFT", x, -12 - 8 * (SZ + GAP) - 4)
      b:SetScript("OnClick", fn)
      W.Tip(b, text, tip)
      return b
    end
    local bw = math.floor((midR - midL - 12) / 4)
    GO.wear = Btn("Wear", midL, bw, function() if GO.edit then GR.Equip(GO.edit) end end,
      "Put this set on now (in combat: weapons now, the rest after).")
    Btn("Take off", midL + (bw + 4), bw, function() GR.Unequip(GO.edit) end, "Back to the gear worn before the set went on.")
    Btn("Save", midL + 2 * (bw + 4), bw, function()
      local set = GO.Set()
      if not set then GO.NewSet() O:Refresh() return end
      set.slots = GR.Snapshot(set.slots)
      GR.Changed()
    end, "The ticked slots take what you wear there now.")
    Btn("Delete", midL + 3 * (bw + 4), bw, function()
      if not GO.edit then return end
      if GO.sure ~= GO.edit or GetTime() > (GO.sureT or 0) then
        GO.sure, GO.sureT = GO.edit, GetTime() + 3
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffpfUI Octo|r gear: click Delete again within 3 s to delete \"" .. GO.edit .. "\".")
        return
      end
      GR.Delete(GO.edit)
      GO.edit, GO.sure = nil, nil
      GR.Changed()
      O:Refresh()
    end, "Click twice to delete this set.")

    local hint = holder:CreateFontString(nil, "OVERLAY")
    hint:SetFont(W.UIFont(), 11, "OUTLINE")
    hint:SetPoint("BOTTOMLEFT", box, "BOTTOMLEFT", 196, 10)
    hint:SetTextColor(.6, .6, .65)
    local k = string.format("|cff%02x%02x%02x", math.floor(ar * 255), math.floor(ag * 255), math.floor(ab * 255))
    hint:SetText(k .. "Tick|r = in this set     " .. k .. "Click|r a slot = pick its item     " .. k .. "Save|r = take what you wear     " .. k .. "Drag|r the character to turn it")

    local function Paint()
      PickSet()
      ar, ag, ab = Accent()
      local cur = GR.Current()
      local names = GR.Sets()
      local fit = math.floor((392 - 32 - 60) / 26)
      for i, n in ipairs(names) do
        if i <= fit then
          local r = Row(i)
          r.set = n
          r.icon:SetTexture(C.gear.sets[n].icon)
          r.text:SetText(n)
          if n == cur then r.worn:Show() else r.worn:Hide() end
          if n == GO.edit then
            r:SetBackdropBorderColor(ar, ag, ab, 1)
            r:SetBackdropColor(ar * .45, ag * .45, ab * .45, 1)
          else
            r:SetBackdropBorderColor(.2, .2, .24, 1)
            r:SetBackdropColor(.06, .06, .08, 1)
          end
          r:Show()
        end
      end
      for i = table.getn(names) + 1, table.getn(GO.rows) do GO.rows[i]:Hide() end
      local set = GO.Set()
      icon.tex:SetTexture(set and set.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
      if not GO.typing then name:SetText(GO.edit or "") end
      for _, s in ipairs(GO.slots) do
        local e = set and set.slots[GR.Key(s.inv)]
        s.off:Hide()
        s.icon:SetAlpha(1)
        s.tick:SetChecked(e ~= nil)
        if not set then s.tick:Hide() else s.tick:Show() end
        if type(e) == "table" then
          s.icon:SetTexture(e.tex)
        elseif e == "empty" then
          s.icon:SetTexture(EMPTY[s.inv])
          s.icon:SetAlpha(.6)
          s.off:Show()
        else
          -- (not in the set: what you wear there, faded)
          s.icon:SetTexture(GetInventoryItemTexture("player", s.inv) or EMPTY[s.inv])
          s.icon:SetAlpha(.3)
        end
        local worn = set and e ~= nil and ((e == "empty" and not GR.Worn(s.inv)) or (type(e) == "table" and GR.Worn(s.inv) == e.id))
        if worn then s:SetBackdropBorderColor(ar, ag, ab, 1) else s:SetBackdropBorderColor(.2, .2, .24, 1) end
      end
      W.Lit(GO.wear, set ~= nil and cur == GO.edit)
      Dress()
    end
    GO.Paint = Paint
    GR.listeners.options = function() if holder:IsVisible() then Paint() end end
    Paint()
    if p.items then table.insert(p.items, { Refresh = Paint }) end
  end

  -- in the set or not (in: what you wear there now)
  function GO.ToggleSlot(inv)
    local set = GO.Set()
    if not set then return end
    local key = GR.Key(inv)
    if set.slots[key] ~= nil then set.slots[key] = nil
    else set.slots[key] = GR.Snapshot({ [key] = true })[key] end
    GR.Changed()
  end

  -- a slot's item: what you wear there (and in its pair), what fits from the
  -- bags, or "take it off"
  function GO.PickFor(s)
    local set = GO.Set()
    if not set then return end
    local inv = s.inv
    local items, seen = {}, {}
    local function Add(it)
      if it and it.id and not seen[it.id] then seen[it.id] = true table.insert(items, it) end
    end
    for _, i in ipairs({ inv, PAIR[inv] }) do
      local id, link = GR.Worn(i)
      if id then
        local _, _, nm = string.find(link, "%[(.-)%]")
        local loc = GR.EquipLoc and GR.EquipLoc(link)
        local fits = (i == inv)
        for _, f in ipairs(loc and GR.FITS[loc] or {}) do if f == inv then fits = true end end
        if fits then Add({ id = id, name = nm or "", tex = GetInventoryItemTexture("player", i), link = link, worn = i }) end
      end
    end
    for _, it in ipairs(GR.ItemsFor(inv)) do Add(it) end
    table.insert(items, "empty")
    GR.Flyout(s, inv, function(item)
      local s2 = GO.Set()
      if not s2 then return end
      s2.slots[GR.Key(inv)] = (item == "empty") and "empty" or { id = item.id, name = item.name, tex = item.tex }
      GR.Changed()
    end, { items = items, empty = false, side = (s:GetLeft() or 0) > (GO.holder:GetLeft() or 0) + 300 and "LEFT" or "RIGHT",
           hint = "Puts it in this set (Wear puts the set on)." })
  end

  -- ---------------------------------------------------------------- page

  local function Build(p)
    W.Heading(p, "Gear sets", { about = "Gear sets as ItemRack and Outfitter make them: pick a set on the left, tick the slots "
      .. "it should change, click a slot to pick its item (or Save to take what you wear), then Wear. In combat your "
      .. "weapons change at once and the rest when combat ends. Also: the Gear sets list beside your character window, "
      .. "the set button, keys, /gear equip <set>." })
    Editor(p)

    W.Card(p, "This set", { tip = "The set picked on the left." })
    -- (a menu's choices are made once: the set's own items come through "auto")
    local icons = { { key = "auto", label = "Its chest or weapon", texture = "Interface\\Icons\\INV_Misc_QuestionMark" } }
    for _, t in ipairs({ { "INV_Chest_Plate06", "Plate" }, { "INV_Chest_Cloth_17", "Cloth" }, { "INV_Chest_Leather_09", "Leather" },
                         { "INV_Sword_04", "Sword" }, { "INV_Shield_06", "Shield" }, { "INV_Staff_08", "Staff" },
                         { "INV_Weapon_Bow_07", "Bow" }, { "Spell_Holy_Heal", "Healing" }, { "Spell_Fire_Fire", "Fire" },
                         { "Spell_Frost_FrostBolt02", "Frost" }, { "Spell_Shadow_ShadowBolt", "Shadow" },
                         { "Ability_Mount_RidingHorse", "Riding" }, { "Ability_Warrior_DefensiveStance", "Tanking" },
                         { "INV_Misc_Gear_01", "Gear" }, { "Ability_Rogue_Sprint", "Speed" }, { "INV_Fishingpole_02", "Fishing" } }) do
      table.insert(icons, { key = "Interface\\Icons\\" .. t[1], label = t[2], texture = "Interface\\Icons\\" .. t[1] })
    end
    W.Dropdown(p, "Icon", "Each choice shows its picture.", icons, function()
      local s = GO.Set()
      if not s then return end
      for _, e in ipairs(icons) do if e.key == s.icon then return s.icon end end
      return "auto"
    end, function(v)
      local s = GO.Set()
      if not s then return end
      s.icon = nil
      if v ~= "auto" then s.icon = v end
      -- (auto: GR.Save picks the chest, main hand, head... picture)
      GR.Save(GO.edit, s.slots, s.icon)
    end)
    local keys = { { key = "", label = "None" } }
    for i = 1, 10 do table.insert(keys, { key = tostring(i), label = "Gear set " .. i }) end
    W.Dropdown(p, "Key", "Then give \"Gear set N\" a key in Key Bindings (pfUI Octo: gear sets).", keys,
      function() local s = GO.Set() return s and s.key or "" end,
      function(v)
        local s = GO.Set()
        if not s then return end
        -- (one set per key)
        for _, other in pairs(C.gear.sets) do if other.key == v then other.key = nil end end
        s.key = v ~= "" and v or nil
        GR.Changed()
      end)

    W.Card(p, "Buttons", { tip = "The set button (click: your sets) and the minimap button." })
    Chk(p, "Set button", "Shows the set you wear; click for your sets, Shift-click to take it off.", "button")
    Sld(p, "Set button size", nil, 20, 64, 1, "size", Px)
    Chk(p, "Set name under it", nil, "showname")
    Chk(p, "Minimap button", nil, "minimap")

    W.Card(p, "Swapping")
    Chk(p, "Weapons change in combat", "1.12 lets weapons change in combat; the rest always waits for combat to end.", "combatweapons")
    Chk(p, "Say when gear waits for combat", nil, "tellwait")
    Chk(p, "A set's key takes it off again", "Off: the key only puts the set on.", "keytoggle")
    Chk(p, "\"Take it off\" in item menus", nil, "allowempty")
    Sld(p, "Item menu: items per row", nil, 1, 12, 1, "wrap")
    Sld(p, "Item menu size", nil, .5, 2, .05, "menuscale", function(v) return math.floor(v * 100 + .5) .. "%" end)

    W.Card(p, "Character window", { tip = "Where you change gear: the slots and a list of your sets." })
    Chk(p, "Item menu on the slots", "Hover a slot of your character for what can go in it.", "sheet")
    Chk(p, "Only with Shift held", nil, "sheetshift")
    Chk(p, "Sets beside the window", nil, "sheetpanel")
    W.Dropdown(p, "Which side", nil, { { key = "right", label = "Right" }, { key = "left", label = "Left" } },
      function() return C.gear.sheetside end, function(v) C.gear.sheetside = v U() end)

    W.Card(p, "Trinket bar", { tip = "Your two trinkets with their cooldowns, as TrinketMenu: click one to use it." })
    Chk(p, "Show the trinket bar", nil, "trinketbar")
    Sld(p, "Size", nil, 20, 64, 1, "trinketsize", Px)
    Chk(p, "Up and down", "Off: side by side.", "trinketvertical")
    Chk(p, "Trinket menu", "Your other trinkets: left-click puts one in the top slot, right-click in the bottom one.", "trinketmenu")
    Chk(p, "Menu on right-click", "Off: it opens when the mouse is over a trinket.", "trinketmenuclick")
    Chk(p, "Menu only with Shift held", nil, "trinketshift")
    Chk(p, "Cooldown numbers", nil, "cdnumbers")
  end

  -- ---------------------------------------------------------------- slot buttons page

  -- the slots to pick (lit = on the bar) and the bar as it will look
  local function SlotPreview(p)
    W.Pin(p, "Preview", "Left: every slot - click one to put it on your bar or take it off (or Alt-click it in your "
      .. "character window). Right: your bar as it will look; Shift + wheel over it for bigger or smaller buttons. "
      .. "Click this bar to fold it away.", function(pp)
      local box = W.Box(pp, 150)
      local holder = CreateFrame("Frame", nil, box)
      holder:SetAllPoints(box)
      holder:SetFrameStrata("FULLSCREEN")
      GO.picks = {}
      for r, row in ipairs(GO.ROWS) do
        for c, inv in ipairs(row) do
          local s = CreateFrame("Button", nil, holder)
          s.inv = inv
          s:SetWidth(30)
          s:SetHeight(30)
          Flat(s, 1)
          s.icon = s:CreateTexture(nil, "ARTWORK")
          s.icon:SetPoint("TOPLEFT", s, "TOPLEFT", 1, -1)
          s.icon:SetPoint("BOTTOMRIGHT", s, "BOTTOMRIGHT", -1, 1)
          s.icon:SetTexCoord(.07, .93, .07, .93)
          s:SetPoint("TOPLEFT", box, "TOPLEFT", 12 + (c - 1) * 33 + (table.getn(row) < 8 and (8 - table.getn(row)) * 16 or 0), -12 - (r - 1) * 34)
          s:SetScript("OnClick", function() GR.ToggleSlot(this.inv) O:Refresh() end)
          s:SetScript("OnEnter", function()
            GameTooltip:SetOwner(this, "ANCHOR_TOP")
            GameTooltip:AddLine(GR.NAME[this.inv])
            GameTooltip:AddLine(GR.HasSlot(this.inv) and "On your bar - click to take it off." or "Click to put it on your bar.", 1, 1, 1)
            GameTooltip:Show()
          end)
          s:SetScript("OnLeave", function() GameTooltip:Hide() end)
          table.insert(GO.picks, s)
        end
      end
      -- the bar, drawn by the same layout code
      local sample = CreateFrame("Frame", nil, holder)
      local sbtn = {}
      for _, s in ipairs(GR.SLOTS) do sbtn[s[1]] = GR.NewSlotButton(sample, s[1], nil, true) end
      GO.sample, GO.sampleButtons = sample, sbtn
      local hot = CreateFrame("Button", nil, holder)
      hot:SetAllPoints(sample)
      hot:SetFrameLevel(sample:GetFrameLevel() + 6)
      hot:EnableMouseWheel(true)
      hot:SetScript("OnMouseWheel", function()
        if IsShiftKeyDown() then
          C.gear.slotsize = tostring(math.max(20, math.min(64, (tonumber(C.gear.slotsize) or 36) + (arg1 or 0))))
          GR.Changed()
          O:Refresh()
        elseif pfUI.plates and pfUI.plates.PassWheel then
          pfUI.plates.PassWheel(this)
        end
      end)
      hot:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_TOP")
        GameTooltip:AddLine("Your slot buttons")
        GameTooltip:AddLine("Shift + mouse wheel: bigger / smaller", 1, 1, 1)
        GameTooltip:Show()
      end)
      hot:SetScript("OnLeave", function() GameTooltip:Hide() end)
      local function Paint()
        local ar, ag, ab = Accent()
        for _, s in ipairs(GO.picks) do
          s.icon:SetTexture(GetInventoryItemTexture("player", s.inv) or GR.EMPTYTEX[s.inv])
          if GR.HasSlot(s.inv) then
            s:SetBackdropBorderColor(ar, ag, ab, 1)
            s:SetBackdropColor(ar * .45, ag * .45, ab * .45, 1)
            s.icon:SetAlpha(1)
          else
            s:SetBackdropBorderColor(.2, .2, .24, 1)
            s:SetBackdropColor(.06, .06, .08, 1)
            s.icon:SetAlpha(.45)
          end
        end
        local n = GR.LayoutSlots(sample, sbtn, GR.SlotList())
        local room = (box:GetWidth() or 600) - 300
        local scale = math.min(1, room / math.max(1, sample:GetWidth()), 120 / math.max(1, sample:GetHeight()))
        sample:SetScale(scale)
        sample:ClearAllPoints()
        sample:SetPoint("CENTER", box, "LEFT", (290 + room / 2) / scale, 0)
        sample:SetAlpha(C.gear.slotbar == "1" and (tonumber(C.gear.slotalpha) or 1) or .3)
        if n == 0 then sample:Hide() else sample:Show() end
      end
      GO.PaintSlots = Paint
      GR.listeners.slotoptions = function() if holder:IsVisible() then Paint() end end
      Paint()
      if p.items then table.insert(p.items, { Refresh = Paint }) end
      W.Buttons(pp, {
        { "Move frames", function() if pfUI.unlock then pfUI.unlock:Show() end end, nil, "Drag the slot buttons where you want them." },
      })
    end)
  end

  local function BuildSlots(p)
    W.Heading(p, "Slot buttons", { about = "Buttons for the equipment slots you pick (as ItemRack's): each shows what you wear "
      .. "there with its cooldown. Click to use it; its menu swaps it for another item from your bags." })
    SlotPreview(p)

    W.Card(p, "Slot buttons")
    Chk(p, "Show the slot buttons", nil, "slotbar")
    Sld(p, "Size", "Or Shift + wheel over the bar in the preview.", 20, 64, 1, "slotsize", Px)
    Sld(p, "Spacing", nil, 0, 24, 1, "slotspace", Px)
    Sld(p, "Buttons per row", nil, 1, 19, 1, "slotper")
    Chk(p, "Up and down", "Off: side by side.", "slotvertical")
    Sld(p, "Opacity", nil, .1, 1, .05, "slotalpha", function(v) return math.floor(v * 100 + .5) .. "%" end)
    Chk(p, "Only in combat", nil, "slotcombat")
    Chk(p, "Alt-click in the character window", "Alt-click a slot there puts it on the bar or takes it off.", "altslots")

    W.Card(p, "Clicks and menus", { tip = "Left-click a slot button uses its item. Its menu lists what else can go in." })
    W.Dropdown(p, "Menu opens", nil, { { key = "hover", label = "When the mouse is over it" },
      { key = "right", label = "On right-click" }, { key = "off", label = "Never" } },
      function() return C.gear.slotmenu end, function(v) C.gear.slotmenu = v U() end)
    Chk(p, "Only with Shift held", nil, "slotshift")
    Chk(p, "Right-click uses the item", "When the menu does not open on right-click.", "slotrightuse")
    W.Dropdown(p, "Menu side", nil, { { key = "auto", label = "Towards the middle" }, { key = "TOP", label = "Above" },
      { key = "BOTTOM", label = "Below" }, { key = "LEFT", label = "Left" }, { key = "RIGHT", label = "Right" } },
      function() return C.gear.slotside end, function(v) C.gear.slotside = v U() end)
    Chk(p, "Alt-click hides an item", "Alt-click an item in a menu to hide it there; hold Alt while it opens to see hidden ones.", "allowhidden")
    Chk(p, "Only soulbound items", "Leave out gear you could still trade.", "boundonly")
    W.Buttons(p, { { "Show every hidden item again", function()
      for k in pairs(C.gear.hidden) do C.gear.hidden[k] = nil end
    end, nil, "Clears the items hidden with Alt-click." } })

    W.Card(p, "Cooldowns", { tip = "On the slot buttons and the trinket bar." })
    Chk(p, "Cooldown numbers", nil, "cdnumbers")
    Chk(p, "Seconds from 90 s", "Off: from 60 s.", "cd90")
    Chk(p, "Say when an item is ready", "On the screen, when an item used from a button is ready again.", "notify")
    Chk(p, "Also at 30 s", nil, "notify30")
    Chk(p, "Also in chat", nil, "notifychat")
  end

  O:AddPage("Gear", "gearsets", "Gear sets", Build)
  O:AddPage("Gear", "gearslots", "Slot buttons", BuildSlots)
end)

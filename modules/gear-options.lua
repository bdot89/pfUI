pfUI:RegisterModule("gear-options", "vanilla", function ()
  -- pfUI Octo :: the Gear section (24 Oct 2026, modules/gear.lua and
  -- gear-sheet.lua). One page: a pinned preview with your sets as tiles (click
  -- = change that one, the one worn marked) and the set's slots laid out as
  -- three rows; click a slot for what can go in it, right-click to leave it
  -- out of the set, Shift-click to have the set take it off. Cards under it
  -- for the set, the buttons, swapping, the character window and the trinket bar.
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

  -- ---------------------------------------------------------------- preview

  -- the slots as three rows: armour, then jewellery and the rest, then weapons
  GO.ROWS = { { 1, 2, 3, 15, 5, 4, 19, 9 }, { 10, 6, 7, 8, 11, 12, 13, 14 }, { 16, 17, 18 } }
  local EMPTY = {}
  for _, s in ipairs(GR.SLOTS) do
    local _, tex = GetInventorySlotInfo and GetInventorySlotInfo(s[2])
    EMPTY[s[1]] = tex
  end

  local function Preview(p)
    W.Pin(p, "Preview", "Your sets, then the slots of the one picked. Click a set to change it. Click a slot for what can "
      .. "go in it; right-click a slot to leave it out of the set (it stays as it is when the set goes on); Shift-click "
      .. "to have the set take it off. Click this bar to fold it away.", function(pp)
      local box = W.Box(pp, 196)
      local holder = CreateFrame("Frame", nil, box)
      holder:SetAllPoints(box)
      holder:SetFrameStrata("FULLSCREEN")
      GO.holder = holder

      -- the sets as tiles
      GO.tiles = {}
      local function Tile(i)
        local t = GO.tiles[i]
        if t then return t end
        t = CreateFrame("Button", nil, holder)
        t:SetHeight(24)
        Flat(t, 1)
        t.icon = t:CreateTexture(nil, "ARTWORK")
        t.icon:SetWidth(18)
        t.icon:SetHeight(18)
        t.icon:SetPoint("LEFT", t, "LEFT", 3, 0)
        t.icon:SetTexCoord(.07, .93, .07, .93)
        t.text = t:CreateFontString(nil, "OVERLAY")
        t.text:SetFont(W.UIFont(), 11, "OUTLINE")
        t.text:SetPoint("LEFT", t.icon, "RIGHT", 5, 0)
        t.worn = t:CreateTexture(nil, "OVERLAY")
        t.worn:SetTexture("Interface\\Buttons\\WHITE8X8")
        t.worn:SetWidth(6)
        t.worn:SetHeight(6)
        t.worn:SetPoint("TOPRIGHT", t, "TOPRIGHT", -3, -3)
        t.worn:SetVertexColor(.2, 1, .3, 1)
        t:RegisterForClicks("LeftButtonUp")
        t:SetScript("OnClick", function()
          if this.new then GO.NewSet() else GO.edit = this.set end
          GR.Changed()
          O:Refresh()
        end)
        t:SetScript("OnEnter", function()
          GameTooltip:SetOwner(this, "ANCHOR_TOP")
          if this.new then
            GameTooltip:AddLine("New set")
            GameTooltip:AddLine("Saves everything you wear now as a new set.", 1, 1, 1)
          else
            GameTooltip:AddLine(this.set)
            GameTooltip:AddLine(this.wearing and "You wear this set now." or "Click: change this set.", 1, 1, 1)
          end
          GameTooltip:Show()
        end)
        t:SetScript("OnLeave", function() GameTooltip:Hide() end)
        GO.tiles[i] = t
        return t
      end

      -- the slots
      GO.slots = {}
      for r, row in ipairs(GO.ROWS) do
        for c, inv in ipairs(row) do
          local s = CreateFrame("Button", nil, holder)
          s.inv = inv
          s:SetWidth(34)
          s:SetHeight(34)
          Flat(s, 1)
          s.icon = s:CreateTexture(nil, "ARTWORK")
          s.icon:SetPoint("TOPLEFT", s, "TOPLEFT", 1, -1)
          s.icon:SetPoint("BOTTOMRIGHT", s, "BOTTOMRIGHT", -1, 1)
          s.icon:SetTexCoord(.07, .93, .07, .93)
          s.off = s:CreateTexture(nil, "OVERLAY")
          s.off:SetTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
          s.off:SetWidth(18)
          s.off:SetHeight(18)
          s.off:SetPoint("CENTER", s, "CENTER", 0, 0)
          s.row, s.col = r, c
          s:RegisterForClicks("LeftButtonUp", "RightButtonUp")
          s:SetScript("OnClick", function()
            local set = GO.Set()
            if not set then return end
            local key = GR.Key(this.inv)
            if arg1 == "RightButton" then
              -- leave it out / put it back in with what is worn
              if set.slots[key] ~= nil then set.slots[key] = nil
              else set.slots[key] = GR.Snapshot({ [key] = true })[key] end
              GR.Changed()
            elseif IsShiftKeyDown() then
              set.slots[key] = "empty"
              GR.Changed()
            else
              -- what can go in: what is worn there and what fits from the bags
              local items = {}
              local id, link = GR.Worn(this.inv)
              if id then
                local _, _, nm = string.find(link, "%[(.-)%]")
                table.insert(items, { id = id, name = nm or "", tex = GetInventoryItemTexture("player", this.inv), link = link })
              end
              for _, it in ipairs(GR.ItemsFor(this.inv)) do table.insert(items, it) end
              local inv = this.inv
              GR.Flyout(this, inv, function(item)
                local s2 = GO.Set()
                if not s2 then return end
                s2.slots[GR.Key(inv)] = (item == "empty") and "empty" or { id = item.id, name = item.name, tex = item.tex }
                GR.Changed()
              end, { items = items, empty = false, side = "BOTTOM", hint = "Puts it in this set (wear the set to put it on)." })
            end
          end)
          s:SetScript("OnEnter", function()
            local set = GO.Set()
            local e = set and set.slots[GR.Key(this.inv)]
            GameTooltip:SetOwner(this, "ANCHOR_TOP")
            GameTooltip:AddLine(GR.NAME[this.inv])
            if e == nil then GameTooltip:AddLine("Left out: the set leaves this slot as it is.", .7, .7, .7, 1)
            elseif e == "empty" then GameTooltip:AddLine("The set takes this off.", 1, .5, .5)
            else GameTooltip:AddLine(e.name or "", 1, 1, 1) end
            GameTooltip:AddLine("Click: what can go in", .6, .8, 1)
            GameTooltip:AddLine("Right-click: leave out / put back in", .6, .8, 1)
            GameTooltip:AddLine("Shift-click: the set takes it off", .6, .8, 1)
            GameTooltip:Show()
          end)
          s:SetScript("OnLeave", function() GameTooltip:Hide() end)
          table.insert(GO.slots, s)
        end
      end

      local function Paint()
        PickSet()
        local ar, ag, ab = Accent()
        local cur = GR.Current()
        local names = GR.Sets()
        local x, y, w = 10, -10, (box:GetWidth() or 600) - 20
        local n = table.getn(names)
        for i = 1, n + 1 do
          local t = Tile(i)
          local name = names[i]
          t.new = name == nil
          t.set = name
          t.wearing = name ~= nil and name == cur
          t.icon:SetTexture(name and C.gear.sets[name].icon or "Interface\\Icons\\Spell_ChargePositive")
          t.text:SetText(name or "New set")
          t:SetWidth(math.min(160, (t.text:GetStringWidth() or 60) + 40))
          if x + t:GetWidth() > w then x, y = 10, y - 28 end
          t:ClearAllPoints()
          t:SetPoint("TOPLEFT", box, "TOPLEFT", x, y)
          x = x + t:GetWidth() + 6
          if name and name == GO.edit then
            t:SetBackdropBorderColor(ar, ag, ab, 1)
            t:SetBackdropColor(ar * .45, ag * .45, ab * .45, 1)
          else
            t:SetBackdropBorderColor(.2, .2, .24, 1)
            t:SetBackdropColor(.06, .06, .08, 1)
          end
          if t.wearing then t.worn:Show() else t.worn:Hide() end
          t:Show()
        end
        for i = n + 2, table.getn(GO.tiles) do GO.tiles[i]:Hide() end
        -- the slots, under the tiles
        local top = y - 34
        local set = GO.Set()
        for _, s in ipairs(GO.slots) do
          local rowLen = table.getn(GO.ROWS[s.row])
          local left = ((box:GetWidth() or 600) - (8 * 38 - 4)) / 2
          local xo = left + (s.col - 1) * 38 + (rowLen < 8 and (8 - rowLen) * 19 or 0)
          s:ClearAllPoints()
          s:SetPoint("TOPLEFT", box, "TOPLEFT", xo, top - (s.row - 1) * 40)
          local e = set and set.slots[GR.Key(s.inv)]
          s.off:Hide()
          s.icon:SetDesaturated(false)
          s.icon:SetAlpha(1)
          if not set then
            s.icon:SetTexture(EMPTY[s.inv])
            s.icon:SetAlpha(.4)
          elseif e == nil then
            s.icon:SetTexture(EMPTY[s.inv])
            s.icon:SetAlpha(.25)
          elseif e == "empty" then
            s.icon:SetTexture(EMPTY[s.inv])
            s.icon:SetAlpha(.6)
            s.off:Show()
          else
            s.icon:SetTexture(e.tex)
          end
          -- lit: this slot is worn as the set has it
          local ok = set and e ~= nil and ((e == "empty" and not GR.Worn(s.inv)) or (type(e) == "table" and GR.Worn(s.inv) == e.id))
          if ok then s:SetBackdropBorderColor(ar, ag, ab, 1) else s:SetBackdropBorderColor(.2, .2, .24, 1) end
        end
      end
      GO.Paint = Paint
      GR.listeners.options = function() if holder:IsVisible() then Paint() end end
      Paint()
      if p.items then table.insert(p.items, { Refresh = Paint }) end

      local ar, ag, ab = Accent()
      local band = W.Row(pp, 20, 0, 3)
      local bg = band:CreateTexture(nil, "BACKGROUND")
      bg:SetAllPoints(band)
      bg:SetTexture("Interface\\Buttons\\WHITE8X8")
      bg:SetVertexColor(ar, ag, ab, .22)
      local how = band:CreateFontString(nil, "OVERLAY")
      how:SetFont(W.UIFont(), 11, "OUTLINE")
      how:SetPoint("LEFT", band, "LEFT", 12, 0)
      local k = string.format("|cff%02x%02x%02x", math.floor(ar * 255), math.floor(ag * 255), math.floor(ab * 255))
      how:SetText(k .. "Click|r a slot  what goes in     " .. k .. "Right-click|r  leave out     " .. k .. "Shift-click|r  take it off")
      W.Buttons(pp, {
        { "Wear it", function() if GO.edit then GR.Equip(GO.edit) end end, nil, "Put this set on now (in combat: weapons now, the rest after).",
          on = function() return GO.edit ~= nil and GR.Current() == GO.edit end },
        { "Take it off", function() GR.Unequip(GO.edit) end, nil, "Back to the gear worn before the set went on." },
        { "Save what I wear", function()
          local set = GO.Set()
          if not set then return end
          -- (only its own slots; a new set has them all)
          set.slots = GR.Snapshot(set.slots)
          GR.Changed()
        end, nil, "Each slot of this set takes what you wear there now." },
        { "Delete", function()
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
        end, nil, "Click twice to delete this set." },
        { "Move frames", function() if pfUI.unlock then pfUI.unlock:Show() end end, nil, "Move the set button and the trinket bar." },
      })
    end)
  end

  -- ---------------------------------------------------------------- page

  local function Build(p)
    W.Heading(p, "Gear", { about = "Gear sets you put on with one click, a key or /gear equip <set>: full sets or only some "
      .. "slots. In combat your weapons change at once and the rest when combat ends. Also in the character window "
      .. "(hover a slot) and an optional trinket bar." })
    Preview(p)

    W.Card(p, "This set", { tip = "The set picked in the preview." })
    W.Edit(p, "Name", "Press Enter to rename it.", function() return GO.edit or "" end, function(v)
      if GO.edit and GR.Rename(GO.edit, v) then GO.edit = v O:Refresh() end
    end)
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

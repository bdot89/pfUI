pfUI:RegisterModule("gear-sheet", "vanilla", function ()
  -- pfUI Octo :: gear sets where you change gear (24 Oct 2026; user: "when you
  -- load up your character UI ingame as you would to change gear this should
  -- be active there. Also make a trinket bar that is optional like trinket
  -- menu addon that shows trinkets and the toggle menu if you choose it").
  --   item menu       the carried items that fit a slot (+ take it off); one
  --                   menu for the character window, the trinket bar and the
  --                   Gear page's preview
  --   character       hover an equipment slot: its item menu; a gear sets
  --                   panel beside the window (wear, new from what you wear)
  --   trinket bar     your two trinkets with cooldowns: click uses one; its
  --                   menu: left-click = top trinket, right-click = bottom
  -- (TrinketMenu / ItemRack read for the idea only; nothing copied.)
  local GR = pfUI.gear
  if not GR then return end
  local function Accent()
    if GetAccentColor then return GetAccentColor() end
    return .2, .55, .9
  end
  local function Flat(f, a)
    f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    f:SetBackdropColor(.06, .06, .08, a or .95)
    f:SetBackdropBorderColor(.2, .2, .24, 1)
  end

  -- ---------------------------------------------------------------- what fits

  -- an item's string for GetItemInfo (1.12 does not take a whole link)
  local function ItemString(link)
    if not link then return end
    local _, _, s = string.find(link, "(item:%d+:%d*:%d*:%d*)")
    return s
  end
  function GR.EquipLoc(link)
    local s = ItemString(link)
    -- (the game's own: pfUI's compat GetItemInfo returns the TBC order and drops
    -- the equip location and texture)
    local info = _G.GetItemInfo
    if not s or not info then return end
    local _, _, _, _, _, _, _, loc, tex = info(s)
    return loc, tex
  end

  -- soulbound? (the bag item's tooltip says so; for "only soulbound items")
  local scan = CreateFrame("GameTooltip", "pfGearScan", UIParent, "GameTooltipTemplate")
  scan:SetOwner(UIParent, "ANCHOR_NONE")
  function GR.Bound(bag, slot)
    scan:ClearLines()
    scan:SetOwner(UIParent, "ANCHOR_NONE")
    scan:SetBagItem(bag, slot)
    for i = 2, 4 do
      local fs = _G["pfGearScanTextLeft" .. i]
      local t = fs and fs:GetText()
      if t and (t == ITEM_SOULBOUND or t == ITEM_BIND_QUEST) then return true end
    end
    return false
  end
  -- hidden items (Alt-click in an item menu): by item id, shown while Alt is held
  C.gear.hidden = C.gear.hidden or {}
  function GR.IsHidden(id) return id and C.gear.hidden[string.gsub(id, ":.*$", "")] == "1" end
  function GR.SetHidden(id, on)
    if not id then return end
    C.gear.hidden[string.gsub(id, ":.*$", "")] = on and "1" or nil
  end

  -- the carried items that can go in slot inv (menu: an item menu's filters -
  -- hidden ones only while Alt is held, soulbound only if set so)
  function GR.ItemsFor(inv, menu)
    local out = {}
    for _, b in ipairs(GR.Bags()) do
      local loc = GR.EquipLoc(b.link)
      local fits = loc and GR.FITS[loc]
      if fits then
        for _, i in ipairs(fits) do
          if i == inv then
            local tex = GetContainerItemInfo(b.bag, b.slot)
            local _, _, name = string.find(b.link, "%[(.-)%]")
            local hidden = GR.IsHidden(b.id)
            local skip = menu and ((hidden and not IsAltKeyDown()) or (C.gear.boundonly == "1" and not GR.Bound(b.bag, b.slot)))
            if not skip then
              table.insert(out, { bag = b.bag, slot = b.slot, id = b.id, link = b.link, tex = tex, name = name or "", hidden = hidden })
            end
          end
        end
      end
    end
    return out
  end

  -- an item menu's items: the one worn in the slot's pair (the other ring,
  -- trinket or one-hand weapon: it swaps across), then the carried ones
  local PAIR = { [11] = 12, [12] = 11, [13] = 14, [14] = 13, [16] = 17, [17] = 16 }
  GR.PAIR = PAIR
  function GR.MenuItems(inv)
    local out = {}
    local other = PAIR[inv]
    -- (not "other and GR.Worn(other)": an "and" keeps only the first of two returns)
    local id, link
    if other then id, link = GR.Worn(other) end
    if id then
      local loc = GR.EquipLoc(link)
      for _, f in ipairs(loc and GR.FITS[loc] or {}) do
        if f == inv then
          local _, _, nm = string.find(link, "%[(.-)%]")
          table.insert(out, { id = id, link = link, name = nm or "", tex = GetInventoryItemTexture("player", other), worn = other })
        end
      end
    end
    for _, it in ipairs(GR.ItemsFor(inv, true)) do table.insert(out, it) end
    return out
  end

  -- one slot, one item (through the same queue as sets: in combat only weapons)
  function GR.EquipItem(inv, item)
    local want = item == "empty" and "empty" or { id = item.id, name = item.name, tex = item.tex }
    GR.Wear(GR.NAME[inv] or "Item", { [GR.Key(inv)] = want })
  end

  -- ---------------------------------------------------------------- item menu

  local fly = CreateFrame("Frame", "pfGearFlyout", UIParent)
  fly:SetFrameStrata("FULLSCREEN_DIALOG")
  fly:EnableMouse(true)
  Flat(fly)
  fly:Hide()
  fly.buttons = {}
  GR.flyout = fly
  local SIZE, GAP, PER = 32, 3, 6
  local function FlyButton(i)
    local b = fly.buttons[i]
    if b then return b end
    b = CreateFrame("Button", nil, fly)
    b:SetWidth(SIZE)
    b:SetHeight(SIZE)
    Flat(b, 1)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetPoint("TOPLEFT", b, "TOPLEFT", 1, -1)
    b.icon:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 1)
    b.icon:SetTexCoord(.07, .93, .07, .93)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:SetScript("OnClick", function()
      local pick = fly.onPick
      -- Alt-click: hide it from the menus (or show it again); the menu stays open
      if IsAltKeyDown() and this.item ~= "empty" and C.gear.allowhidden ~= "0" and not fly.noHide then
        GR.SetHidden(this.item.id, not this.item.hidden)
        local a = fly.args
        if a then GR.Flyout(a[1], a[2], a[3], a[4]) end
        return
      end
      if IsShiftKeyDown() and this.item ~= "empty" and ChatFrameEditBox and ChatFrameEditBox:IsVisible() then
        ChatFrameEditBox:Insert(this.item.link)
        return
      end
      fly:Hide()
      if pick then pick(this.item, arg1) end
    end)
    b:SetScript("OnEnter", function()
      local ar, ag, ab = Accent()
      this:SetBackdropBorderColor(ar, ag, ab, 1)
      GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
      if this.item == "empty" then
        GameTooltip:AddLine("Take it off")
      elseif this.item.worn then
        GameTooltip:SetInventoryItem("player", this.item.worn)
        GameTooltip:AddLine("Worn in your " .. string.lower(GR.NAME[this.item.worn] or "") .. " slot", .6, .8, 1)
      elseif this.item.bag then
        GameTooltip:SetBagItem(this.item.bag, this.item.slot)
      elseif this.item.id then
        pcall(GameTooltip.SetHyperlink, GameTooltip, "item:" .. this.item.id .. ":0")
      end
      if fly.hint then GameTooltip:AddLine(fly.hint, .6, .8, 1) end
      GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function()
      this:SetBackdropBorderColor(.2, .2, .24, 1)
      GameTooltip:Hide()
    end)
    fly.buttons[i] = b
    return b
  end

  -- open the item menu for slot inv beside owner; onPick(item | "empty", mouse button)
  function GR.Flyout(owner, inv, onPick, opts)
    opts = opts or {}
    local items = opts.items or GR.MenuItems(inv)
    if opts.empty ~= false and GR.Worn(inv) and C.gear.allowempty ~= "0" then table.insert(items, "empty") end
    if table.getn(items) == 0 then fly:Hide() return end
    fly.owner, fly.onPick, fly.hint = owner, onPick, opts.hint
    fly.args = { owner, inv, onPick, opts }
    -- (the Gear page lists its own items: no hiding there)
    fly.noHide = opts.items ~= nil
    local n = table.getn(items)
    local per = math.min(n, tonumber(C.gear.wrap) or PER)
    for i, item in ipairs(items) do
      local b = FlyButton(i)
      b.item = item
      b.icon:SetTexture(item == "empty" and "Interface\\Icons\\Spell_ChargeNegative" or item.tex)
      b.icon:SetAlpha((item ~= "empty" and item.hidden) and .4 or 1)
      local row = math.floor((i - 1) / per)
      local col = i - 1 - row * per
      b:ClearAllPoints()
      b:SetPoint("TOPLEFT", fly, "TOPLEFT", 4 + col * (SIZE + GAP), -4 - row * (SIZE + GAP))
      b:Show()
    end
    for i = n + 1, table.getn(fly.buttons) do fly.buttons[i]:Hide() end
    local rows = math.ceil(n / per)
    fly:SetWidth(8 + per * SIZE + (per - 1) * GAP)
    fly:SetHeight(8 + rows * SIZE + (rows - 1) * GAP)
    fly:SetScale(tonumber(C.gear.menuscale) or 1)
    fly:ClearAllPoints()
    local side = opts.side or "RIGHT"
    if side == "LEFT" then fly:SetPoint("TOPRIGHT", owner, "TOPLEFT", -4, 0)
    elseif side == "TOP" then fly:SetPoint("BOTTOMLEFT", owner, "TOPLEFT", 0, 4)
    elseif side == "BOTTOM" then fly:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", 0, -4)
    else fly:SetPoint("TOPLEFT", owner, "TOPRIGHT", 4, 0) end
    fly.away = 0
    fly:Show()
  end
  -- it closes a moment after the mouse leaves it and its slot
  fly:SetScript("OnUpdate", function()
    if MouseIsOver(this) or (this.owner and this.owner:IsVisible() and MouseIsOver(this.owner)) then
      this.away = 0
    else
      this.away = (this.away or 0) + arg1
      if this.away > .4 then this:Hide() end
    end
  end)

  -- ---------------------------------------------------------------- character window

  -- hovering an equipment slot opens its item menu (Shift held, if set so)
  local function HookSlots()
    for _, s in ipairs(GR.SLOTS) do
      local slotButton = _G["Character" .. s[2]]
      if slotButton and not slotButton.octoGear then
        slotButton.octoGear = true
        local inv = s[1]
        HookScript(slotButton, "OnEnter", function()
          if C.gear.sheet == "0" then return end
          if C.gear.sheetshift == "1" and not IsShiftKeyDown() then return end
          -- (right column: the menu opens towards the middle)
          local left = inv == 1 or inv == 2 or inv == 3 or inv == 15 or inv == 5 or inv == 4 or inv == 19 or inv == 9
          local side = (inv == 16 or inv == 17 or inv == 18) and "BOTTOM" or (left and "RIGHT" or "LEFT")
          GR.Flyout(this, inv, function(item) GR.EquipItem(inv, item) end, { side = side })
        end)
      end
    end
  end

  -- the gear sets panel beside the character window
  local panel = CreateFrame("Frame", "pfGearSheet", PaperDollFrame or UIParent)
  panel:SetWidth(170)
  Flat(panel, .92)
  panel:EnableMouse(true)
  panel.title = panel:CreateFontString(nil, "OVERLAY")
  panel.title:SetFont(pfUI.font_default, 13, "OUTLINE")
  panel.title:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -7)
  panel.title:SetText("Gear sets")
  panel.rows = {}
  GR.sheet = panel
  local function SheetButton(text, w, fn, tip)
    local b = CreateFrame("Button", nil, panel)
    b:SetWidth(w)
    b:SetHeight(20)
    Flat(b, 1)
    b.text = b:CreateFontString(nil, "OVERLAY")
    b.text:SetFont(pfUI.font_default, 11, "OUTLINE")
    b.text:SetPoint("CENTER", b, "CENTER", 0, 0)
    b.text:SetText(text)
    b:SetScript("OnClick", fn)
    b:SetScript("OnEnter", function()
      local ar, ag, ab = Accent()
      this:SetBackdropBorderColor(ar, ag, ab, 1)
      if tip then
        GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
        GameTooltip:AddLine(text)
        GameTooltip:AddLine(tip, 1, 1, 1, 1)
        GameTooltip:Show()
      end
    end)
    b:SetScript("OnLeave", function() this:SetBackdropBorderColor(.2, .2, .24, 1) GameTooltip:Hide() end)
    return b
  end
  panel.new = SheetButton("New from worn", 100, function()
    local n = 1
    while C.gear.sets["Set " .. n] do n = n + 1 end
    GR.Save("Set " .. n, GR.Snapshot())
    C.gear.current = "Set " .. n
    GR.Changed()
  end, "Save everything you wear as a new set. Rename it on the Gear page.")
  panel.opt = SheetButton("Options", 54, function()
    if pfUI.gearOcto and pfUI.gearOcto.Open then pfUI.gearOcto.Open() end
  end, "The Gear page: change sets, slot by slot.")
  local function SheetRow(i)
    local r = panel.rows[i]
    if r then return r end
    r = CreateFrame("Button", nil, panel)
    r:SetHeight(22)
    r.hl = r:CreateTexture(nil, "BACKGROUND")
    r.hl:SetAllPoints(r)
    r.hl:SetTexture("Interface\\Buttons\\WHITE8X8")
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetWidth(18)
    r.icon:SetHeight(18)
    r.icon:SetPoint("LEFT", r, "LEFT", 2, 0)
    r.icon:SetTexCoord(.07, .93, .07, .93)
    r.text = r:CreateFontString(nil, "OVERLAY")
    r.text:SetFont(pfUI.font_default, 11, "OUTLINE")
    r.text:SetPoint("LEFT", r.icon, "RIGHT", 5, 0)
    r.text:SetPoint("RIGHT", r, "RIGHT", -3, 0)
    r.text:SetJustifyH("LEFT")
    r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    r:SetScript("OnClick", function()
      if arg1 == "RightButton" then
        if pfUI.gearOcto and pfUI.gearOcto.Open then pfUI.gearOcto.Open(this.set) end
      elseif IsShiftKeyDown() then
        GR.Unequip(this.set)
      else
        GR.Equip(this.set)
      end
    end)
    r:SetScript("OnEnter", function()
      if not this.on then this.hl:SetVertexColor(1, 1, 1, .08) end
      GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
      GameTooltip:AddLine(this.set)
      GameTooltip:AddLine("Click: wear it", 1, 1, 1)
      GameTooltip:AddLine("Shift + click: back to the gear worn before", 1, 1, 1)
      GameTooltip:AddLine("Right-click: change it on the Gear page", 1, 1, 1)
      GameTooltip:Show()
    end)
    r:SetScript("OnLeave", function()
      if not this.on then this.hl:SetVertexColor(0, 0, 0, 0) end
      GameTooltip:Hide()
    end)
    panel.rows[i] = r
    return r
  end
  function GR.UpdateSheet()
    if C.gear.sheetpanel == "0" or not PaperDollFrame then panel:Hide() return end
    panel:ClearAllPoints()
    if C.gear.sheetside == "left" then
      panel:SetPoint("TOPRIGHT", CharacterFrame or PaperDollFrame, "TOPLEFT", 8, -12)
    else
      -- (pfUI's character window backdrop ends 30 px in from its right edge)
      panel:SetPoint("TOPLEFT", CharacterFrame or PaperDollFrame, "TOPRIGHT", -28, -12)
    end
    local ar, ag, ab = Accent()
    local cur = GR.Current()
    local names = GR.Sets()
    for i, name in ipairs(names) do
      local r = SheetRow(i)
      r.set = name
      r.icon:SetTexture(C.gear.sets[name].icon)
      r.text:SetText(name)
      r.on = name == cur
      if r.on then
        r.hl:SetVertexColor(ar, ag, ab, .35)
        r.text:SetTextColor(1, 1, 1)
      else
        r.hl:SetVertexColor(0, 0, 0, 0)
        r.text:SetTextColor(.85, .85, .85)
      end
      r:ClearAllPoints()
      r:SetPoint("TOPLEFT", panel, "TOPLEFT", 4, -26 - (i - 1) * 24)
      r:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -4, -26 - (i - 1) * 24)
      r:Show()
    end
    for i = table.getn(names) + 1, table.getn(panel.rows) do panel.rows[i]:Hide() end
    local y = -26 - table.getn(names) * 24 - 4
    if table.getn(names) == 0 then
      panel.empty = panel.empty or panel:CreateFontString(nil, "OVERLAY")
      panel.empty:SetFont(pfUI.font_default, 11, "OUTLINE")
      panel.empty:SetTextColor(.6, .6, .6)
      panel.empty:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -28)
      panel.empty:SetText("No sets yet.")
      panel.empty:Show()
      y = y - 18
    elseif panel.empty then
      panel.empty:Hide()
    end
    panel.new:ClearAllPoints()
    panel.new:SetPoint("TOPLEFT", panel, "TOPLEFT", 6, y)
    panel.opt:ClearAllPoints()
    panel.opt:SetPoint("LEFT", panel.new, "RIGHT", 4, 0)
    panel:SetHeight(-y + 26)
    panel:Show()
  end
  GR.listeners.sheet = GR.UpdateSheet

  -- ---------------------------------------------------------------- trinket bar

  local bar = CreateFrame("Frame", "pfGearTrinkets", UIParent)
  bar:SetFrameStrata("MEDIUM")
  bar:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 200)
  bar.slots = {}
  GR.trinkets = bar
  for i, inv in ipairs({ 13, 14 }) do
    local b = CreateFrame("Button", "pfGearTrinket" .. i, bar)
    b.inv = inv
    Flat(b, 1)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetPoint("TOPLEFT", b, "TOPLEFT", 1, -1)
    b.icon:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 1)
    b.icon:SetTexCoord(.07, .93, .07, .93)
    b.cd = CreateFrame("Model", "pfGearTrinket" .. i .. "Cooldown", b, "CooldownFrameTemplate")
    b.cd:SetAllPoints(b.icon)
    b.num = b:CreateFontString(nil, "OVERLAY")
    b.num:SetFont(pfUI.font_default, 12, "OUTLINE")
    b.num:SetPoint("CENTER", b, "CENTER", 0, 0)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:SetScript("OnClick", function()
      if IsShiftKeyDown() and ChatFrameEditBox and ChatFrameEditBox:IsVisible() then
        local link = GetInventoryItemLink("player", this.inv)
        if link then ChatFrameEditBox:Insert(link) end
        return
      end
      if C.gear.trinketmenu ~= "0" and C.gear.trinketmenuclick == "1" and arg1 == "RightButton" then
        GR.TrinketMenu(this)
      else
        UseInventoryItem(this.inv)
      end
    end)
    b:SetScript("OnEnter", function()
      GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
      GameTooltip:SetInventoryItem("player", this.inv)
      GameTooltip:Show()
      if C.gear.trinketmenu ~= "0" and C.gear.trinketmenuclick ~= "1" and (C.gear.trinketshift ~= "1" or IsShiftKeyDown()) then GR.TrinketMenu(this) end
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    bar.slots[i] = b
  end
  -- every carried trinket; left-click = top slot, right-click = bottom
  function GR.TrinketMenu(owner)
    local up = (owner:GetTop() or 0) < (GetScreenHeight() / 2)
    GR.Flyout(owner, 13, function(item, mouse)
      GR.EquipItem(mouse == "RightButton" and 14 or 13, item)
    end, { side = up and "TOP" or "BOTTOM", empty = false,
           hint = "Left-click: top trinket. Right-click: bottom trinket." })
  end
  local function Clock(left)
    if left >= (C.gear.cd90 == "1" and 90 or 60) then return math.ceil(left / 60) .. "m" end
    return tostring(math.ceil(left))
  end
  GR.Clock = Clock

  -- a slot button's cooldown: the game's swipe, numbers, and a notice when
  -- an item used from it is ready again (or 30 s before, if wanted)
  function GR.PaintCooldown(b)
    local start, dur, on = GetInventoryItemCooldown("player", b.inv)
    if start and dur and dur > 1.5 and on == 1 then
      if CooldownFrame_SetTimer and b.cdStart ~= start then CooldownFrame_SetTimer(b.cd, start, dur, 1) b.cdStart = start end
      local left = start + dur - GetTime()
      b.num:SetText((C.gear.cdnumbers ~= "0" and left > 0) and Clock(left) or "")
      b.icon:SetVertexColor(.6, .6, .6)
      -- (only cooldowns long enough to be worth a notice)
      if dur > 10 then b.watch = GetInventoryItemLink("player", b.inv) end
      if b.watch and C.gear.notify30 == "1" and left <= 30 and not b.told30 then
        b.told30 = true
        GR.Notify(b.watch, " ready in 30 s")
      end
    else
      if b.watch and b.watch == GetInventoryItemLink("player", b.inv) and C.gear.notify ~= "0" then
        GR.Notify(b.watch, " is ready")
      end
      b.watch, b.told30 = nil, nil
      b.cdStart = nil
      b.num:SetText("")
      b.icon:SetVertexColor(1, 1, 1)
    end
  end
  function GR.Notify(link, what)
    local _, _, name = string.find(link or "", "%[(.-)%]")
    local text = (name or "Item") .. what
    if UIErrorsFrame then UIErrorsFrame:AddMessage(text, .3, 1, .4, 1, 3) end
    if C.gear.notifychat == "1" then DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffpfUI Octo|r gear: " .. text) end
  end
  function GR.UpdateTrinkets()
    if C.gear.trinketbar ~= "1" then bar:Hide() return end
    local size = tonumber(C.gear.trinketsize) or 36
    local vertical = C.gear.trinketvertical == "1"
    for i, b in ipairs(bar.slots) do
      b:SetWidth(size)
      b:SetHeight(size)
      b:ClearAllPoints()
      if i == 1 then b:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
      elseif vertical then b:SetPoint("TOP", bar.slots[1], "BOTTOM", 0, -3)
      else b:SetPoint("LEFT", bar.slots[1], "RIGHT", 3, 0) end
      local tex = GetInventoryItemTexture("player", b.inv)
      b.icon:SetTexture(tex or "Interface\\PaperDoll\\UI-PaperDoll-Slot-Trinket")
      b.icon:SetDesaturated(tex == nil)
    end
    bar:SetWidth(vertical and size or size * 2 + 3)
    bar:SetHeight(vertical and size * 2 + 3 or size)
    bar:SetScale(1)
    bar:Show()
  end
  GR.listeners.trinkets = GR.UpdateTrinkets
  -- cooldowns: the game's swipe, and numbers if wanted
  bar:SetScript("OnUpdate", function()
    this.t = (this.t or 0) + arg1
    if this.t < .2 then return end
    this.t = 0
    for _, b in ipairs(this.slots) do GR.PaintCooldown(b) end
  end)
  if UpdateMovable then UpdateMovable(bar) end

  -- the character window's slots exist once the game made it
  HookSlots()
  local boot = CreateFrame("Frame")
  boot:RegisterEvent("PLAYER_ENTERING_WORLD")
  boot:SetScript("OnEvent", function()
    HookSlots()
    GR.Changed()
  end)
  if PaperDollFrame then HookScript(PaperDollFrame, "OnShow", function() GR.UpdateSheet() end) end
  GR.Changed()
end)

pfUI:RegisterModule("meters-window", "vanilla", function ()
  -- pfUI Octo meter windows, Details! style. Two windows by default, docked
  -- side by side in the right chat panel (the panel's toggle button swaps
  -- chat and meters): damage on the left, threat on the right. In each:
  --   click the title    -> pick what it shows (damage, DPS, healing, HPS,
  --                         overhealing, damage taken, interrupts, dispels,
  --                         deaths, casts, threat)
  --   click the segment  -> current fight, overall, or an earlier fight
  --   hover a bar        -> top spells; click a bar -> the full breakdown
  --   R / X              -> report to chat / reset all data
  -- Data: meters.lua (pfUI.meters) and meters-threat.lua (pfUI.meters.threat).
  if C.meters.enable ~= "1" or not pfUI.meters then return end

  local M = pfUI.meters
  local floor, max, min = math.floor, math.max, math.min
  local rawborder, border = GetBorderSize()

  -- ---------------------------------------------------------------- numbers

  local function Num(v)
    v = tonumber(v) or 0
    if v >= 1000000 then return string.format("%.2fm", v / 1000000) end
    if v >= 10000 then return string.format("%.1fk", v / 1000) end
    if v >= 1000 then return string.format("%.2fk", v / 1000) end
    if v >= 100 then return tostring(floor(v + .5)) end
    if v ~= floor(v) then return string.format("%.1f", v) end
    return tostring(v)
  end
  M.Num = Num

  local function Clock(t)
    t = max(0, floor(t or 0))
    return string.format("%d:%02d", floor(t / 60), math.mod(t, 60))
  end

  local function ActiveTime(a) return max(1, a.active or 0) end

  -- ---------------------------------------------------------------- modes

  local MODES = {
    { key = "damage", name = T["Damage Done"], value = function(a) return a.damage end,
      extra = function(a) return Num(a.damage / ActiveTime(a)) end },
    { key = "dps", name = T["DPS"], value = function(a) return a.damage > 0 and a.damage / ActiveTime(a) or 0 end,
      extra = function(a) return Num(a.damage) end },
    { key = "heal", name = T["Healing Done"], value = function(a) return a.heal end,
      extra = function(a) return Num(a.heal / ActiveTime(a)) end },
    { key = "hps", name = T["HPS"], value = function(a) return a.heal > 0 and a.heal / ActiveTime(a) or 0 end,
      extra = function(a) return Num(a.heal) end },
    { key = "overheal", name = T["Overhealing"], value = function(a) return a.overheal end,
      extra = function(a)
        local all = a.heal + a.overheal
        return all > 0 and floor(a.overheal / all * 100) .. "%" or "0%"
      end },
    { key = "taken", name = T["Damage Taken"], value = function(a) return a.taken end },
    { key = "interrupts", name = T["Interrupts"], value = function(a) return a.interrupts end },
    { key = "dispels", name = T["Dispels"], value = function(a) return a.dispels end },
    { key = "deaths", name = T["Deaths"], value = function(a) return a.deaths end },
    { key = "casts", name = T["Casts"], value = function(a) return a.ncasts end },
    { key = "threat", name = T["Threat"] },
  }
  local MODE = {}
  for _, m in ipairs(MODES) do MODE[m.key] = m end
  M.MODES = MODES

  -- the rows a window shows: { name, value, class, text, actor }
  function M.Rows(modekey, segkey)
    local rows = {}
    local mode = MODE[modekey] or MODE.damage

    if mode.key == "threat" then
      local TH = M.threat
      if not TH or not TH.list then return rows end
      local top = 1
      for _, e in ipairs(TH.list) do if e.perc > top then top = e.perc end end
      for _, e in ipairs(TH.list) do
        local w = M.Who(e.name)
        table.insert(rows, { name = e.name, value = e.perc, max = top, class = w and w.class,
                             text = floor(e.perc) .. "%", extra = Num(e.threat), tank = e.tank })
      end
      return rows
    end

    local seg = M.Segment(segkey)
    if not seg then return rows end
    for name, a in pairs(seg.actors) do
      local v = mode.value(a)
      if v and v > 0 then
        table.insert(rows, { name = name, value = v, class = a.class, actor = a,
                             extra = mode.extra and mode.extra(a) })
      end
    end
    table.sort(rows, function(x, y) return x.value > y.value end)
    local total = 0
    for _, r in ipairs(rows) do total = total + r.value end
    for _, r in ipairs(rows) do
      r.max = rows[1].value
      r.text = Num(r.value)
      r.pct = total > 0 and r.value / total * 100 or 0
    end
    return rows
  end

  local function SegmentName(key)
    if key == "overall" then return T["Overall"] end
    local seg = M.Segment(key)
    if not seg then return T["No fight yet"] end
    -- the time first, so a narrow window cuts the name, not the time
    local live = seg == M.current and "|cff66ff66" or "|cff888888"
    return live .. Clock(M.Duration(seg)) .. "|r  " .. (seg.name or T["Fight"])
  end

  -- ---------------------------------------------------------------- menu

  -- a small pfUI-style list under an anchor. items = { { text, func, ... } }:
  --   checked = true   the current choice (accent text)
  --   tick = true/false a tick box in front (an on/off setting)
  --   head = true      a grey section title, not clickable
  --   keep = true      the menu stays open after the click (redrawn by func)
  local menu = CreateFrame("Frame", "pfMeterMenu", UIParent)
  menu:SetFrameStrata("FULLSCREEN_DIALOG")
  menu:Hide()
  menu:EnableMouse(true)
  CreateBackdrop(menu, nil, true, .95)
  menu.buttons = {}
  menu:SetScript("OnUpdate", function()
    if not MouseIsOver(this) and not MouseIsOver(this.anchor) then
      this.away = (this.away or 0) + arg1
      if this.away > .6 then this:Hide() end
    else
      this.away = 0
    end
  end)

  local function ShowMenu(anchor, items)
    local width = 140
    for i, item in ipairs(items) do
      local b = menu.buttons[i]
      if not b then
        b = CreateFrame("Button", nil, menu)
        b:SetHeight(16)
        b.text = b:CreateFontString(nil, "OVERLAY", "GameFontWhite")
        b.text:SetFont(pfUI.font_default, C.global.font_size, "OUTLINE")
        b.text:SetPoint("LEFT", 8, 0)
        b.text:SetJustifyH("LEFT")
        b.hl = b:CreateTexture(nil, "BACKGROUND")
        b.hl:SetAllPoints()
        b.hl:SetTexture(1, 1, 1, .08)
        b.hl:Hide()
        b.box = b:CreateTexture(nil, "ARTWORK")
        b.box:SetWidth(9)
        b.box:SetHeight(9)
        b.box:SetPoint("LEFT", 8, 0)
        b.boxbg = b:CreateTexture(nil, "BORDER")
        b.boxbg:SetWidth(11)
        b.boxbg:SetHeight(11)
        b.boxbg:SetPoint("CENTER", b.box, "CENTER", 0, 0)
        b.boxbg:SetTexture(0, 0, 0, 1)
        b:SetScript("OnEnter", function() if not this.head then this.hl:Show() end end)
        b:SetScript("OnLeave", function() this.hl:Hide() end)
        b:SetScript("OnClick", function()
          if this.head then return end
          if not this.keep then menu:Hide() end
          if this.func then this.func() end
        end)
        menu.buttons[i] = b
      end
      b:ClearAllPoints()
      b:SetPoint("TOPLEFT", menu, "TOPLEFT", 2, -2 - (i - 1) * 16)
      b:SetPoint("RIGHT", menu, "RIGHT", -2, 0)
      local ar, ag, ab = GetAccentColor()
      b.head, b.keep = item.head, item.keep
      b.text:ClearAllPoints()
      b.text:SetPoint("LEFT", (item.tick ~= nil) and 24 or 8, 0)
      if item.head then
        b.text:SetTextColor(.55, .55, .55, 1)
      elseif item.checked then
        b.text:SetTextColor(ar, ag, ab, 1)
      else
        b.text:SetTextColor(1, 1, 1, 1)
      end
      if item.tick ~= nil then
        b.boxbg:Show()
        b.box:Show()
        if item.tick then b.box:SetTexture(ar, ag, ab, 1) else b.box:SetTexture(.15, .15, .15, 1) end
      else
        b.boxbg:Hide()
        b.box:Hide()
      end
      b.text:SetText(item[1])
      b.func = item[2]
      b:Show()
      local w = b.text:GetStringWidth() + ((item.tick ~= nil) and 40 or 24)
      if w > width then width = w end
    end
    for i = table.getn(items) + 1, table.getn(menu.buttons) do menu.buttons[i]:Hide() end
    menu.anchor = anchor
    menu.away = 0
    local height = table.getn(items) * 16 + 4
    menu:SetWidth(width)
    menu:SetHeight(height)
    menu:ClearAllPoints()
    -- open upwards / leftwards when there is no room (the meters sit at the bottom right)
    local s = anchor:GetEffectiveScale() / UIParent:GetEffectiveScale()
    local below = (anchor:GetBottom() or 500) * s
    local left = (anchor:GetLeft() or 0) * s
    local v = below < height + 10 and "BOTTOM" or "TOP"
    local h = left + width > GetScreenWidth() - 10 and "RIGHT" or "LEFT"
    menu:SetPoint(v .. h, anchor, (v == "TOP" and "BOTTOM" or "TOP") .. h, 0, v == "TOP" and -2 or 2)
    menu:Show()
  end
  M.ShowMenu = ShowMenu

  -- ---------------------------------------------------------------- report

  local function Report(win, channel, whisper)
    local rows = M.Rows(win.mode, win.segment)
    if table.getn(rows) == 0 then return end
    local mode = MODE[win.mode] or MODE.damage
    local title = "pfUI Octo - " .. mode.name
    if win.mode ~= "threat" then title = title .. " - " .. gsub(SegmentName(win.segment), "|c%x%x%x%x%x%x%x%x", "") end
    title = gsub(gsub(title, "|r", ""), "%*", "")
    SendChatMessage(title, channel, nil, whisper)
    for i = 1, min(table.getn(rows), 10) do
      local r = rows[i]
      local line = i .. ". " .. r.name .. "  " .. r.text
      if r.extra then line = line .. " (" .. r.extra .. ")" end
      if r.pct then line = line .. "  " .. string.format("%.1f%%", r.pct) end
      SendChatMessage(line, channel, nil, whisper)
    end
  end

  local function ReportMenu(win, anchor)
    local items = {
      { T["Say"], function() Report(win, "SAY") end },
      { T["Party"], function() Report(win, "PARTY") end },
      { T["Raid"], function() Report(win, "RAID") end },
      { T["Guild"], function() Report(win, "GUILD") end },
      { T["Officer"], function() Report(win, "OFFICER") end },
    }
    if UnitIsPlayer("target") and UnitIsFriend("player", "target") then
      local name = UnitName("target")
      table.insert(items, { T["Whisper"] .. " " .. name, function() Report(win, "WHISPER", name) end })
    end
    ShowMenu(anchor, items)
  end

  -- ---------------------------------------------------------------- details

  local details = CreateFrame("Frame", "pfMeterDetails", UIParent)
  details:SetWidth(520)
  details:SetHeight(380)
  details:SetPoint("CENTER", 0, 60)
  details:SetFrameStrata("DIALOG")
  details:SetMovable(true)
  details:EnableMouse(true)
  details:RegisterForDrag("LeftButton")
  details:SetScript("OnDragStart", function() this:StartMoving() end)
  details:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
  details:Hide()
  CreateBackdrop(details, nil, true, .92)
  CreateBackdropShadow(details)
  table.insert(UISpecialFrames, "pfMeterDetails")

  details.title = details:CreateFontString(nil, "OVERLAY", "GameFontWhite")
  details.title:SetFont(pfUI.font_default, C.global.font_size + 3, "OUTLINE")
  details.title:SetPoint("TOPLEFT", 10, -8)
  details.title:SetPoint("RIGHT", -30, 0)
  details.title:SetJustifyH("LEFT")

  details.close = CreateFrame("Button", nil, details)
  details.close:SetPoint("TOPRIGHT", -8, -8)
  details.close:SetWidth(12)
  details.close:SetHeight(12)
  details.close.texture = details.close:CreateTexture(nil, "OVERLAY")
  details.close.texture:SetTexture(pfUI.media["img:close"])
  details.close.texture:SetAllPoints()
  details.close.texture:SetVertexColor(1, .25, .25, 1)
  SkinButton(details.close, 1, .5, .5)
  details.close:SetScript("OnClick", function() details:Hide() end)

  details.scroll = CreateScrollFrame("pfMeterDetailsScroll", details)
  details.scroll:SetPoint("TOPLEFT", details, "TOPLEFT", 8, -30)
  details.scroll:SetPoint("BOTTOMRIGHT", details, "BOTTOMRIGHT", -8, 8)
  details.content = CreateScrollChild("pfMeterDetailsContent", details.scroll)
  details.content:SetWidth(490)
  details.lines = {}

  -- columns: x offset and width of each cell, first one left-aligned
  local COLS = { { 4, 170 }, { 178, 64 }, { 246, 46 }, { 296, 44 }, { 344, 46 }, { 394, 46 }, { 444, 44 } }

  local function Line(i)
    local l = details.lines[i]
    if l then return l end
    l = CreateFrame("Frame", nil, details.content)
    l:SetHeight(15)
    l:SetPoint("TOPLEFT", details.content, "TOPLEFT", 0, -(i - 1) * 15)
    l:SetPoint("RIGHT", details.content, "RIGHT", 0, 0)
    l.cells = {}
    for c, col in ipairs(COLS) do
      local s = l:CreateFontString(nil, "OVERLAY", "GameFontWhite")
      s:SetFont(pfUI.font_default, C.global.font_size, "OUTLINE")
      s:SetPoint("LEFT", l, "LEFT", col[1], 0)
      s:SetWidth(col[2])
      s:SetJustifyH(c == 1 and "LEFT" or "RIGHT")
      l.cells[c] = s
    end
    l.wide = l:CreateFontString(nil, "OVERLAY", "GameFontWhite")
    l.wide:SetFont(pfUI.font_default, C.global.font_size, "OUTLINE")
    l.wide:SetPoint("LEFT", l, "LEFT", 4, 0)
    l.wide:SetPoint("RIGHT", l, "RIGHT", -4, 0)
    l.wide:SetJustifyH("LEFT")
    details.lines[i] = l
    return l
  end

  -- rows: { cells = { ... } } or { wide = "text" }, color r,g,b
  local function FillDetails(title, rows)
    details.title:SetText(title)
    local ar, ag, ab = GetAccentColor()
    for i, row in ipairs(rows) do
      local l = Line(i)
      for c = 1, table.getn(COLS) do l.cells[c]:SetText(row.cells and row.cells[c] or "") end
      l.wide:SetText(row.wide or "")
      local r, g, b = 1, 1, 1
      if row.head then r, g, b = ar, ag, ab elseif row.color then r, g, b = row.color[1], row.color[2], row.color[3] end
      for c = 1, table.getn(COLS) do l.cells[c]:SetTextColor(r, g, b, 1) end
      l.wide:SetTextColor(r, g, b, 1)
      l:Show()
    end
    for i = table.getn(rows) + 1, table.getn(details.lines) do details.lines[i]:Hide() end
    details.content:SetHeight(max(1, table.getn(rows) * 15))
    details.scroll:SetVerticalScroll(0)
    details:Show()
  end

  local function Pct(part, all) return all > 0 and string.format("%.1f%%", part / all * 100) or "-" end

  local HOWS = { miss = T["miss"], dodge = T["dodge"], parry = T["parry"], block = T["block"], evade = T["evade"],
                 immune = T["immune"], absorb = T["absorbed"], resist = T["resisted"], reflect = T["reflected"],
                 glancing = T["glancing"], crushing = T["crushing"] }

  local function SpellRows(rows, list, total, heal)
    local sorted = {}
    for name, s in pairs(list) do table.insert(sorted, { name = name, s = s }) end
    table.sort(sorted, function(x, y) return x.s.total > y.s.total end)
    table.insert(rows, { head = true, cells = { T["Spell"], heal and T["Healed"] or T["Amount"], "%", T["Hits"], T["Crit"],
      heal and T["Over"] or T["Miss"], T["Max"] } })
    for _, e in ipairs(sorted) do
      local s = e.s
      local n = s.hits + s.ticks
      local fifth
      if heal then
        fifth = Pct(s.over, s.total + s.over)
      else
        fifth = (s.misses > 0) and Pct(s.misses, n + s.misses) or "-"
      end
      table.insert(rows, { cells = { e.name, Num(s.total), Pct(s.total, total), n, Pct(s.crits, max(1, n)), fifth, Num(s.max) } })
      -- how the misses went: 3 dodge, 1 parry...
      local hows = ""
      for how, count in pairs(s.how) do hows = hows .. count .. " " .. (HOWS[how] or how) .. "  " end
      if hows ~= "" then table.insert(rows, { wide = "      |cff888888" .. hows .. "|r" }) end
    end
  end

  local function TableRows(rows, title, list)
    local sorted, total = {}, 0
    for name, v in pairs(list) do table.insert(sorted, { name = name, v = v }) total = total + v end
    if table.getn(sorted) == 0 then return end
    table.sort(sorted, function(x, y) return x.v > y.v end)
    table.insert(rows, { wide = " " })
    table.insert(rows, { head = true, cells = { title, T["Amount"], "%" } })
    for _, e in ipairs(sorted) do
      table.insert(rows, { cells = { e.name, Num(e.v), Pct(e.v, total) } })
    end
  end

  function M.ShowDetails(win, row)
    local a = row.actor
    if not a then return end
    local seg = M.Segment(win.segment)
    local start = seg and seg.start or 0
    local mode = MODE[win.mode] or MODE.damage
    local rows = {}
    local title = a.name .. "  |cff888888" .. mode.name .. "  -  " .. SegmentName(win.segment) .. "|r"

    if win.mode == "damage" or win.mode == "dps" then
      table.insert(rows, { wide = T["Damage"] .. ": " .. Num(a.damage) .. "   " .. T["DPS"] .. ": " .. Num(a.damage / ActiveTime(a)) ..
        "   " .. T["Active"] .. ": " .. Clock(a.active) })
      SpellRows(rows, a.spells, a.damage)
      TableRows(rows, T["Targets"], a.targets)
    elseif win.mode == "heal" or win.mode == "hps" or win.mode == "overheal" then
      table.insert(rows, { wide = T["Healing"] .. ": " .. Num(a.heal) .. "   " .. T["Overhealing"] .. ": " .. Num(a.overheal) ..
        "   " .. T["HPS"] .. ": " .. Num(a.heal / ActiveTime(a)) })
      SpellRows(rows, a.hspells, a.heal, true)
      TableRows(rows, T["Healed"], a.htargets)
    elseif win.mode == "taken" then
      table.insert(rows, { wide = T["Damage Taken"] .. ": " .. Num(a.taken) })
      SpellRows(rows, a.tspells, a.taken)
      TableRows(rows, T["Sources"], a.sources)
      local av = ""
      for how, n in pairs(a.avoid) do av = av .. n .. " " .. (HOWS[how] or how) .. "   " end
      if av ~= "" then table.insert(rows, { wide = " " }) table.insert(rows, { wide = T["Avoided"] .. ": " .. av }) end
    elseif win.mode == "interrupts" then
      table.insert(rows, { head = true, cells = { T["Interrupted"], T["Time"] } })
      for _, e in ipairs(a.ilist) do
        table.insert(rows, { wide = Clock(e.t - start) .. "   " .. (e.with and (e.with .. "  >  ") or "") ..
          (e.target or "?") .. ":  |cffffcc66" .. (e.spell or "?") .. "|r" })
      end
    elseif win.mode == "dispels" then
      for _, e in ipairs(a.dlist) do
        table.insert(rows, { wide = Clock(e.t - start) .. "   " .. (e.with or "") .. "  >  " .. (e.target or "?") ..
          ":  |cff66ccff" .. (e.aura or "?") .. "|r" })
      end
    elseif win.mode == "deaths" then
      for i, d in ipairs(a.deathlogs) do
        table.insert(rows, { head = true, wide = string.format(T["Death %d at %s"], i, Clock(d.t - start)) ..
          (d.killer and ("  -  " .. T["killed by"] .. " " .. d.killer) or "") })
        for _, e in ipairs(d.log) do
          local sign = e.kind == "heal" and "+" or "-"
          local hp = e.hp and e.hpmax and e.hpmax > 0 and ("  |cff888888" .. floor(e.hp / e.hpmax * 100) .. "%|r") or ""
          table.insert(rows, { color = e.kind == "heal" and { .4, 1, .4 } or { 1, .45, .45 },
            wide = string.format("%5.1fs  ", e.t - d.t) .. sign .. Num(e.amount) .. (e.crit and "*" or "") ..
              "   " .. (e.spell or "") .. "  " .. (e.who or "") .. hp })
        end
        table.insert(rows, { wide = " " })
      end
    elseif win.mode == "casts" then
      local sorted = {}
      for name, n in pairs(a.casts) do table.insert(sorted, { name = name, n = n }) end
      table.sort(sorted, function(x, y) return x.n > y.n end)
      table.insert(rows, { head = true, cells = { T["Spell"], T["Casts"], "%" } })
      for _, e in ipairs(sorted) do table.insert(rows, { cells = { e.name, e.n, Pct(e.n, a.ncasts) } }) end
    end
    FillDetails(title, rows)
  end

  -- ---------------------------------------------------------------- windows

  local function Tooltip(bar)
    local row = bar.row
    if not row then return end
    GameTooltip:SetOwner(bar, "ANCHOR_LEFT")
    GameTooltip:AddLine(row.name, 1, 1, 1)
    local a = row.actor
    if a then
      local list, total
      local m = bar.win.mode
      if m == "damage" or m == "dps" then list, total = a.spells, a.damage
      elseif m == "heal" or m == "hps" or m == "overheal" then list, total = a.hspells, a.heal
      elseif m == "taken" then list, total = a.tspells, a.taken end
      if list then
        local sorted = {}
        for name, s in pairs(list) do table.insert(sorted, { name = name, v = s.total }) end
        table.sort(sorted, function(x, y) return x.v > y.v end)
        for i = 1, min(8, table.getn(sorted)) do
          local e = sorted[i]
          GameTooltip:AddDoubleLine(e.name, Num(e.v) .. "  " .. Pct(e.v, total), 1, 1, 1, .8, .8, .8)
        end
      end
      GameTooltip:AddLine(T["Click for the full breakdown"], .5, .5, .5)
    elseif row.tank then
      GameTooltip:AddLine(T["Tanking"], 1, .3, .3)
    end
    GameTooltip:Show()
  end

  local function Bar(win, i)
    local b = win.bars[i]
    if b then return b end
    b = CreateFrame("Button", nil, win)
    b.win = win
    b:SetFrameLevel(win:GetFrameLevel() + 2)
    b.lift = 2
    b.bar = CreateFrame("StatusBar", nil, b)
    b.bar:SetAllPoints()
    b.bar:SetStatusBarTexture(C.meters.texture)
    b.bar:SetMinMaxValues(0, 1)
    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetAllPoints()
    b.bg:SetTexture(1, 1, 1, .05)
    b.left = b.bar:CreateFontString(nil, "OVERLAY", "GameFontWhite")
    b.left:SetFont(pfUI.font_unit, C.global.font_unit_size, "OUTLINE")
    b.left:SetPoint("LEFT", 4, 0)
    b.left:SetJustifyH("LEFT")
    b.right = b.bar:CreateFontString(nil, "OVERLAY", "GameFontWhite")
    b.right:SetFont(pfUI.font_unit, C.global.font_unit_size, "OUTLINE")
    b.right:SetPoint("RIGHT", -4, 0)
    b.right:SetJustifyH("RIGHT")
    b.left:SetPoint("RIGHT", b.right, "LEFT", -6, 0)
    b:SetScript("OnEnter", function() Tooltip(this) end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:SetScript("OnClick", function() if this.row then M.ShowDetails(this.win, this.row) end end)
    win.bars[i] = b
    return b
  end

  local function Refresh(win)
    if not win:IsShown() then return end
    local mode = MODE[win.mode] or MODE.damage
    win.title:SetText(mode.name)
    win.titlebtn:SetWidth(win.title:GetStringWidth() + 10)
    if win.mode == "threat" then
      win.seg:SetText("")
    else
      win.seg:SetText(SegmentName(win.segment))
    end

    local rows = M.Rows(win.mode, win.segment)
    local height = tonumber(C.meters.barheight) or 16
    local room = win:GetHeight() - 22
    local visible = max(1, floor((room + 1) / (height + 1)))
    if win.offset > max(0, table.getn(rows) - visible) then win.offset = max(0, table.getn(rows) - visible) end

    local me = UnitName("player")
    for i = 1, visible do
      local row = rows[i + win.offset]
      local b = Bar(win, i)
      if row then
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", win, "TOPLEFT", 2, -20 - (i - 1) * (height + 1))
        b:SetPoint("TOPRIGHT", win, "TOPRIGHT", -2, -20 - (i - 1) * (height + 1))
        b:SetHeight(height)
        b.row = row
        b.bar:SetValue(row.max and row.max > 0 and row.value / row.max or 0)
        local color = row.class and RAID_CLASS_COLORS[row.class]
        local r, g, bb = .6, .6, .6
        if color and C.meters.classcolor == "1" then r, g, bb = color.r, color.g, color.b end
        if win.mode == "threat" then
          -- you: green -> yellow -> red towards the pull point; the tank: dark red
          local share = row.name == me and M.threat and M.threat.Mine()
          if row.tank then r, g, bb = .6, .15, .15
          elseif share then r, g, bb = min(1, share * 2), min(1, 2 - share * 2), .1 end
        end
        b.bar:SetStatusBarColor(r, g, bb, .85)
        b.left:SetText((C.meters.showrank ~= "0" and ((i + win.offset) .. ". ") or "") .. row.name)
        local parts = {}
        if row.extra and C.meters.showps ~= "0" then table.insert(parts, row.extra) end
        if row.pct and C.meters.showpct ~= "0" then table.insert(parts, string.format("%.0f%%", row.pct)) end
        local right = row.text or ""
        if table.getn(parts) > 0 then right = right .. " |cffaaaaaa(" .. table.concat(parts, ", ") .. ")|r" end
        b.right:SetText(right)
        b:Show()
      else
        b.row = nil
        b:Hide()
      end
    end
    for i = visible + 1, table.getn(win.bars) do win.bars[i]:Hide() end

    -- empty: say why
    if table.getn(rows) == 0 then
      local why = win.mode == "threat" and M.threat and M.threat.Status() or T["Nothing yet - go fight something"]
      if win.mode == "threat" and not M.threat then why = T["Threat is turned off"] end
      win.empty:SetText(why or "")
      win.empty:Show()
    else
      win.empty:Hide()
    end
  end

  -- a small title-bar button: a letter, or icon = "menu" (three lines)
  local function HeaderButton(win, text, tip, func, icon)
    local b = CreateFrame("Button", nil, win)
    b:SetWidth(16)
    b:SetHeight(16)
    b:SetFrameLevel(win:GetFrameLevel() + 3)
    local function Paint(r, g, bb)
      if b.lines then
        for _, l in ipairs(b.lines) do l:SetTexture(r, g, bb, 1) end
      else
        b.text:SetTextColor(r, g, bb, 1)
      end
    end
    if icon == "menu" then
      b.lines = {}
      for i = 1, 3 do
        local l = b:CreateTexture(nil, "OVERLAY")
        l:SetWidth(9)
        l:SetHeight(1)
        l:SetPoint("CENTER", b, "CENTER", 0, 4 - (i - 1) * 4)
        b.lines[i] = l
      end
    else
      b.text = b:CreateFontString(nil, "OVERLAY", "GameFontWhite")
      b.text:SetFont(pfUI.font_default, C.global.font_size, "OUTLINE")
      b.text:SetAllPoints()
      b.text:SetText(text)
    end
    Paint(.7, .7, .7)
    b:SetScript("OnEnter", function()
      Paint(GetAccentColor())
      GameTooltip:SetOwner(this, "ANCHOR_TOP")
      GameTooltip:SetText(tip, 1, 1, 1)
      GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() Paint(.7, .7, .7) GameTooltip:Hide() end)
    b:SetScript("OnClick", func)
    return b
  end

  local function RefreshAll()
    for _, w in ipairs(M.windows) do Refresh(w) end
  end

  -- ---------------------------------------------------------------- docking

  -- window 1 docks as "damage", window 2 as "threat" (pfUI's dock sides)
  local function KeyOf(win) return win.id == 1 and "pfmeter" or "pfthreat" end
  local function SideOf(win) return win.id == 1 and "damage" or "threat" end

  local function CanDock()
    return pfUI.thirdparty and pfUI.thirdparty.meters and pfUI.chat and pfUI.chat.right and C.chat.right.enable == "1"
  end

  -- 1.12 does not carry a parent's new frame level over to its children: after
  -- the window is raised (docked over the chat) its buttons would sit below
  -- the window itself, which takes every click. Put each child back on top.
  local function Lift(win, inner)
    local level, strata = win:GetFrameLevel(), win:GetFrameStrata()
    local kids = { win:GetChildren() }
    for _, kid in ipairs(kids) do
      kid:SetFrameStrata(strata)
      kid:SetFrameLevel(level + (inner and 1 or kid.lift or 3))
      Lift(kid, true)
    end
  end
  M.Lift = Lift

  -- fills the right chat, or its half when the other window is docked too
  local function Dock(win)
    if win.free or not CanDock() then return end
    local chat = pfUI.chat.right
    local bottom = pfUI.panel and pfUI.panel.right and pfUI.panel.right:GetHeight() or 0
    local other = M.windows[win.id == 1 and 2 or 1]
    local half = other and not other.free
    win:ClearAllPoints()
    if not half then
      win:SetPoint("TOPLEFT", chat, "TOPLEFT", 0, 0)
      win:SetPoint("BOTTOMRIGHT", chat, "BOTTOMRIGHT", 0, bottom)
    elseif win.id == 1 then
      win:SetPoint("TOPLEFT", chat, "TOPLEFT", 0, 0)
      win:SetPoint("BOTTOMRIGHT", chat, "BOTTOM", -border, bottom)
    else
      win:SetPoint("TOPLEFT", chat, "TOP", border, 0)
      win:SetPoint("BOTTOMRIGHT", chat, "BOTTOMRIGHT", 0, bottom)
    end
    win:SetFrameStrata(chat:GetFrameStrata())
    win:SetFrameLevel(chat:GetFrameLevel() + 5)
    win.grip:Hide()
    Refresh(win)
    Lift(win)
  end

  -- a free window: its own size and place, movable with the title bar, /moveui
  local function Float(win)
    local id = win.id
    win:ClearAllPoints()
    win:SetFrameStrata("MEDIUM")
    win:SetWidth(tonumber(C.meters["width" .. id] or C.meters.width) or 260)
    win:SetHeight(tonumber(C.meters["height" .. id] or C.meters.height) or 160)
    if not (C.position and C.position[win:GetName()]) then
      win:SetPoint("CENTER", UIParent, "CENTER", (id - 1.5) * 280, -120)
    end
    UpdateMovable(win)
    if C.meters["lock" .. id] == "1" then win.grip:Hide() else win.grip:Show() end
    win:Show()
    Refresh(win)
    Lift(win)
  end

  local function Register(win)
    pfUI.thirdparty.meters:RegisterMeter(SideOf(win), { KeyOf(win), "pfUI", win,
      function() Dock(win) end, function() Dock(win) end,
      function() if not win.free then win:Show() end end,
      function() if not win.free then win:Hide() end end })
  end

  -- dock / undock while playing
  function M.SetDocked(win, dock)
    local other = M.windows[win.id == 1 and 2 or 1]
    C.thirdparty[KeyOf(win)].dock = dock and "1" or "0"
    if dock and CanDock() then
      win.free = nil
      RemoveMovable(win)
      if pfUI.thirdparty.meters[SideOf(win)] ~= nil then Dock(win) else Register(win) end
      if other then Dock(other) end
      -- the meters show in place of the chat
      if not pfUI.thirdparty.meters.state then pfUI.thirdparty.meters:Toggle() end
      Dock(win)
      win:Show()
    else
      win.free = true
      Float(win)
      if other then Dock(other) end
      -- nothing docked any more: give the chat back
      local any = other and not other.free
      if not any and pfUI.thirdparty.meters and pfUI.thirdparty.meters.state then
        pfUI.thirdparty.meters:Toggle()
      end
    end
  end

  -- ---------------------------------------------------------------- the window menu

  local function OpenOptions()
    pfUI.gui:Show()
    if pfUI.gui.frames[T["Meters"]] then pfUI.gui.frames[T["Meters"]]:Click() end
  end

  local BAR_HEIGHTS = { "12", "14", "16", "18", "20", "24" }

  local function WindowMenu(win, anchor)
    local id = win.id
    local function Flip(key, after)
      return function()
        C.meters[key] = C.meters[key] == "1" and "0" or "1"
        if after then after() end
        RefreshAll()
        WindowMenu(win, anchor)
      end
    end
    local items = {
      { T["Window"], head = true },
      { T["Docked in the chat panel"], function()
          M.SetDocked(win, win.free and true or false)
          WindowMenu(win, anchor)
        end, tick = not win.free, keep = true },
    }
    if win.free then
      table.insert(items, { T["Lock position and size"], Flip("lock" .. id, function()
        if C.meters["lock" .. id] == "1" then win.grip:Hide() else win.grip:Show() end
      end), tick = C.meters["lock" .. id] == "1", keep = true })
    end
    table.insert(items, { string.format(T["Bar height: %s (click: bigger)"], C.meters.barheight), function()
      local nextv = BAR_HEIGHTS[1]
      for i, v in ipairs(BAR_HEIGHTS) do
        if v == C.meters.barheight and BAR_HEIGHTS[i + 1] then nextv = BAR_HEIGHTS[i + 1] end
      end
      C.meters.barheight = nextv
      RefreshAll()
      WindowMenu(win, anchor)
    end, keep = true })
    table.insert(items, { T["Show"], head = true })
    table.insert(items, { T["Rank numbers"], Flip("showrank"), tick = C.meters.showrank ~= "0", keep = true })
    table.insert(items, { T["Per second"], Flip("showps"), tick = C.meters.showps ~= "0", keep = true })
    table.insert(items, { T["Percent of the total"], Flip("showpct"), tick = C.meters.showpct ~= "0", keep = true })
    table.insert(items, { T["Class colors"], Flip("classcolor"), tick = C.meters.classcolor == "1", keep = true })
    table.insert(items, { T["Track"], head = true })
    table.insert(items, { T["Merge pets into their owner"], Flip("mergepets", function() M.who = {} end),
      tick = C.meters.mergepets == "1", keep = true })
    table.insert(items, { T["Everyone nearby (battlegrounds)"], Flip("trackall", function() M.who = {} end),
      tick = C.meters.trackall == "1", keep = true })
    table.insert(items, { T["Actions"], head = true })
    table.insert(items, { T["Report to chat..."], function() ReportMenu(win, anchor) end })
    table.insert(items, { T["Reset all data"], function()
      CreateQuestionDialog(T["Reset all meter data?"], function() M.Reset() end)
    end })
    table.insert(items, { T["All meter options..."], OpenOptions })
    ShowMenu(anchor, items)
  end
  M.WindowMenu = WindowMenu

  -- ---------------------------------------------------------------- windows

  local function CreateWindow(id)
    local win = CreateFrame("Frame", "pfMeter" .. id, UIParent)
    win.id = id
    win.mode = C.meters["mode" .. id] or "damage"
    win.segment = C.meters["segment" .. id] or "current"
    win.offset = 0
    win.bars = {}
    win:SetWidth(tonumber(C.meters["width" .. id] or C.meters.width) or 260)
    win:SetHeight(tonumber(C.meters["height" .. id] or C.meters.height) or 160)
    win:SetPoint("CENTER", UIParent, "CENTER", (id - 1.5) * 280, -120)
    win:SetFrameStrata("MEDIUM")
    win:SetMovable(true)
    win:SetResizable(true)
    win:SetMinResize(150, 60)
    win:SetClampedToScreen(true)
    win:EnableMouse(true)
    win:EnableMouseWheel(true)
    CreateBackdrop(win, nil, nil, .8)
    win.backdrop:SetBackdropColor(GetStringColor(C.meters.background))

    -- title bar: drag it to move a free window
    win.head = win:CreateTexture(nil, "ARTWORK")
    win.head:SetPoint("TOPLEFT", 0, 0)
    win.head:SetPoint("TOPRIGHT", 0, 0)
    win.head:SetHeight(18)
    win.head:SetTexture(0, 0, 0, .45)

    local function DragStart()
      if win.free and C.meters["lock" .. win.id] ~= "1" then win:StartMoving() win.moving = true end
    end
    local function DragStop()
      if win.moving then
        win:StopMovingOrSizing()
        win.moving = nil
        SaveMovable(win)
      end
    end

    win.titlebtn = CreateFrame("Button", nil, win)
    win.titlebtn:SetPoint("TOPLEFT", 2, -1)
    win.titlebtn:SetHeight(16)
    win.titlebtn:SetWidth(110)
    win.titlebtn:RegisterForDrag("LeftButton")
    win.titlebtn:SetScript("OnDragStart", DragStart)
    win.titlebtn:SetScript("OnDragStop", DragStop)
    win.title = win.titlebtn:CreateFontString(nil, "OVERLAY", "GameFontWhite")
    win.title:SetFont(pfUI.font_default, C.global.font_size, "OUTLINE")
    win.title:SetPoint("LEFT", 4, 0)
    local ar, ag, ab = GetAccentColor()
    win.title:SetTextColor(ar, ag, ab, 1)
    win.titlebtn:SetScript("OnEnter", function()
      GameTooltip:SetOwner(this, "ANCHOR_TOP")
      GameTooltip:SetText(T["Click: what this window shows"], 1, 1, 1)
      if win.free then GameTooltip:AddLine(T["Drag: move the window"], .7, .7, .7) end
      GameTooltip:Show()
    end)
    win.titlebtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    win.titlebtn:SetScript("OnClick", function()
      local items = { { T["Show"], head = true } }
      for _, m in ipairs(MODES) do
        local key = m.key
        table.insert(items, { m.name, function()
          win.mode = key
          C.meters["mode" .. win.id] = key
          win.offset = 0
          Refresh(win)
        end, checked = (key == win.mode) })
      end
      ShowMenu(this, items)
    end)

    win.segbtn = CreateFrame("Button", nil, win)
    win.segbtn:SetPoint("LEFT", win.titlebtn, "RIGHT", 2, 0)
    win.segbtn:SetPoint("RIGHT", win, "TOPRIGHT", -56, -9)
    win.segbtn:SetHeight(16)
    win.segbtn:RegisterForDrag("LeftButton")
    win.segbtn:SetScript("OnDragStart", DragStart)
    win.segbtn:SetScript("OnDragStop", DragStop)
    win.seg = win.segbtn:CreateFontString(nil, "OVERLAY", "GameFontWhite")
    win.seg:SetFont(pfUI.font_default, C.global.font_size - 1, "OUTLINE")
    win.seg:SetAllPoints()
    win.seg:SetJustifyH("LEFT")
    win.seg:SetTextColor(.8, .8, .8, 1)
    win.segbtn:SetScript("OnEnter", function()
      if win.mode == "threat" then return end
      GameTooltip:SetOwner(this, "ANCHOR_TOP")
      GameTooltip:SetText(T["Click: which fight"], 1, 1, 1)
      GameTooltip:Show()
    end)
    win.segbtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    win.segbtn:SetScript("OnClick", function()
      if win.mode == "threat" then return end
      local items = { { T["Fight"], head = true } }
      local function Pick(key)
        return function()
          win.segment = key
          C.meters["segment" .. win.id] = key
          Refresh(win)
        end
      end
      table.insert(items, { T["Current fight"], Pick("current"), checked = win.segment == "current" })
      table.insert(items, { T["Overall"], Pick("overall"), checked = win.segment == "overall" })
      for i, seg in ipairs(M.history) do
        table.insert(items, { Clock(M.Duration(seg)) .. "  " .. (seg.name or T["Fight"]), Pick(tostring(i)),
          checked = win.segment == tostring(i) })
      end
      ShowMenu(this, items)
    end)

    win.reset = HeaderButton(win, "X", T["Reset all meter data"], function()
      CreateQuestionDialog(T["Reset all meter data?"], function() M.Reset() end)
    end)
    win.reset:SetPoint("TOPRIGHT", -2, -1)
    win.report = HeaderButton(win, "R", T["Report to chat"], function() ReportMenu(win, this) end)
    win.report:SetPoint("RIGHT", win.reset, "LEFT", -1, 0)
    win.menu = HeaderButton(win, nil, T["Window settings: dock, lock, bars, what to track"], function()
      WindowMenu(win, this)
    end, "menu")
    win.menu:SetPoint("RIGHT", win.report, "LEFT", -1, 0)

    -- resize grip (free, unlocked windows)
    win.grip = CreateFrame("Button", nil, win)
    win.grip:SetWidth(12)
    win.grip:SetHeight(12)
    win.grip:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", 0, 0)
    win.grip:SetFrameLevel(win:GetFrameLevel() + 6)
    win.grip.lift = 6
    for i = 1, 3 do
      local dot = win.grip:CreateTexture(nil, "OVERLAY")
      dot:SetWidth(2)
      dot:SetHeight(2)
      dot:SetTexture(.7, .7, .7, .9)
      dot:SetPoint("BOTTOMRIGHT", win.grip, "BOTTOMRIGHT", -2 - (i - 1) * 3, 2)
      if i > 1 then
        local up = win.grip:CreateTexture(nil, "OVERLAY")
        up:SetWidth(2)
        up:SetHeight(2)
        up:SetTexture(.7, .7, .7, .9)
        up:SetPoint("BOTTOMRIGHT", win.grip, "BOTTOMRIGHT", -2, 2 + (i - 1) * 3)
      end
    end
    win.grip:SetScript("OnMouseDown", function()
      if win.free and C.meters["lock" .. win.id] ~= "1" then
        win:StartSizing("BOTTOMRIGHT")
        win.sizing = true
      end
    end)
    win.grip:SetScript("OnMouseUp", function()
      if not win.sizing then return end
      win:StopMovingOrSizing()
      win.sizing = nil
      C.meters["width" .. win.id] = tostring(floor(win:GetWidth()))
      C.meters["height" .. win.id] = tostring(floor(win:GetHeight()))
      SaveMovable(win)
      Refresh(win)
    end)
    win.grip:SetScript("OnUpdate", function()
      if not win.sizing or (this.tick or 0) > GetTime() then return end
      this.tick = GetTime() + .05
      Refresh(win)
    end)
    win.grip:Hide()

    win.empty = win:CreateFontString(nil, "OVERLAY", "GameFontWhite")
    win.empty:SetFont(pfUI.font_default, C.global.font_size, "OUTLINE")
    win.empty:SetPoint("TOPLEFT", 6, -26)
    win.empty:SetPoint("RIGHT", -6, 0)
    win.empty:SetJustifyH("LEFT")
    win.empty:SetTextColor(.6, .6, .6, 1)

    win:SetScript("OnMouseWheel", function()
      this.offset = max(0, this.offset - arg1)
      Refresh(this)
    end)
    win:SetScript("OnShow", function() Refresh(this) end)
    win.Refresh = Refresh
    return win
  end

  M.windows = {}
  local count = C.meters.windows == "1" and 1 or 2
  for id = 1, count do M.windows[id] = CreateWindow(id) end
  table.insert(M.callbacks, RefreshAll)

  -- docked windows go into the right chat, the others float
  if CanDock() and C.meters.shown ~= "1" then
    -- show the meters instead of the right chat the first time
    C.thirdparty.showmeter = "1"
    C.meters.shown = "1"
  end
  for _, win in ipairs(M.windows) do
    local key = KeyOf(win)
    win.free = not (CanDock() and C.thirdparty[key] and C.thirdparty[key].dock == "1") or nil
  end
  for _, win in ipairs(M.windows) do
    if win.free then Float(win) else Register(win) end
  end

  -- ---------------------------------------------------------------- old addons, instances

  local events = CreateFrame("Frame")
  events:RegisterEvent("PLAYER_ENTERING_WORLD")
  events:SetScript("OnEvent", function()
    -- offer to turn off the addons the meters replace
    local old = {}
    if IsAddOnLoaded("ShaguDPS") then table.insert(old, "ShaguDPS") end
    if IsAddOnLoaded("TWThreat") then table.insert(old, "TWThreat") end
    if table.getn(old) > 0 and C.meters.asked ~= "1" then
      C.meters.asked = "1"
      CreateQuestionDialog(string.format(T["pfUI Octo has its own damage and threat meters now (in the right chat panel).\n\nTurn off %s? The UI reloads."], table.concat(old, " + ")),
        function()
          for _, name in ipairs(old) do DisableAddOn(name) end
          ReloadUI()
        end)
    end

    -- entering an instance with old data: ask to reset (as Details! does)
    local inInstance = IsInInstance()
    local zone = GetRealZoneText()
    if inInstance and C.meters.resetask == "1" and zone ~= M.lastInstance and table.getn(M.history) > 0 then
      CreateQuestionDialog(string.format(T["Reset the meters for %s?"], zone or "?"), function() M.Reset() end)
    end
    if inInstance then M.lastInstance = zone end
  end)
end)

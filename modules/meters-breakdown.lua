pfUI:RegisterModule("meters-breakdown", "vanilla", function ()
  -- pfUI Octo :: the player breakdown (meters phase 3, Details!' "player
  -- details" as the model - Details! is All Rights Reserved, nothing of it is
  -- copied). Clicking a player's bar in a meter window opens it:
  --   header   class icon, name, what and which fight; < > the next player
  --            of that window; Report sends the open tab to chat
  --   Summary  everything about the player in that fight at a glance
  --   Spells   the spells as bars; click one for its detail: hits, normal
  --            and critical (count, average, min, max), ticks, misses by
  --            kind, glancing / crushing, overhealing, its targets
  --   Targets  who it hit or healed (or who hit it)
  --   Compare  side by side with another player: each spell and the gap
  --   Deaths   each death with its last hits and heals, health as a bar
  -- Enemy and spell rows (enemy damage, damage taken by spell) keep the
  -- simple breakdown of meters-window.lua.
  local M = pfUI.meters
  if not M or not M.ShowDetails or not M.MODES then return end

  local floor, max, min = math.floor, math.max, math.min
  local Num = M.Num
  local Clock = M.Clock or function(t) t = max(0, floor(t or 0)) return string.format("%d:%02d", floor(t / 60), math.mod(t, 60)) end
  local MODE = {}
  for _, m in ipairs(M.MODES) do MODE[m.key] = m end
  local function Pct(part, all) return (all and all > 0) and string.format("%.1f%%", part / all * 100) or "-" end
  local function Avg(total, n) return n > 0 and Num(total / n) or "-" end
  local HEALMODES = { heal = true, hps = true, overheal = true, htaken = true }

  local B = { tab = "spells" }
  M.breakdown = B

  -- ---------------------------------------------------------------- the frame

  local W, H = 720, 470
  local f = CreateFrame("Frame", "pfMeterBreakdown", UIParent)
  f:SetWidth(W)
  f:SetHeight(H)
  f:SetPoint("CENTER", 0, 40)
  f:SetFrameStrata("DIALOG")
  f:SetMovable(true)
  f:EnableMouse(true)
  f:SetClampedToScreen(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function() this:SetMovable(true) this:StartMoving() end)
  f:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
  f:Hide()
  CreateBackdrop(f, nil, true, .94)
  CreateBackdropShadow(f)
  table.insert(UISpecialFrames, "pfMeterBreakdown")
  B.frame = f

  local function Text(parent, size, justify)
    local t = parent:CreateFontString(nil, "OVERLAY", "GameFontWhite")
    t:SetFont(pfUI.font_default, size or C.global.font_size, "OUTLINE")
    t:SetJustifyH(justify or "LEFT")
    return t
  end

  f.icon = f:CreateTexture(nil, "OVERLAY")
  f.icon:SetWidth(22)
  f.icon:SetHeight(22)
  f.icon:SetPoint("TOPLEFT", 10, -8)
  f.name = Text(f, C.global.font_size + 4)
  f.name:SetPoint("LEFT", f.icon, "RIGHT", 6, 0)
  f.sub = Text(f, C.global.font_size)
  f.sub:SetPoint("LEFT", f.name, "RIGHT", 10, -1)
  f.sub:SetTextColor(.6, .6, .6)

  -- a small text button
  local function Button(parent, label, width, func, tip)
    local b = CreateFrame("Button", nil, parent)
    b:SetWidth(width)
    b:SetHeight(20)
    CreateBackdrop(b, nil, true, .8)
    b.text = Text(b, C.global.font_size, "CENTER")
    b.text:SetAllPoints(b)
    b.text:SetText(label)
    b:SetScript("OnClick", func)
    b:SetScript("OnEnter", function()
      local r, g, bb = GetAccentColor()
      if this.backdrop then this.backdrop:SetBackdropBorderColor(r, g, bb, 1) end
      if tip then
        GameTooltip:SetOwner(this, "ANCHOR_TOP")
        GameTooltip:SetText(tip, 1, 1, 1)
        GameTooltip:Show()
      end
    end)
    b:SetScript("OnLeave", function()
      if this.backdrop then this.backdrop:SetBackdropBorderColor(0, 0, 0, 1) end
      GameTooltip:Hide()
    end)
    return b
  end
  B.Button = Button

  f.close = Button(f, "X", 20, function() f:Hide() end)
  f.close:SetPoint("TOPRIGHT", -8, -8)
  f.report = Button(f, "Report", 64, function() B.ReportMenu(this) end, "Send this tab to chat")
  f.report:SetPoint("RIGHT", f.close, "LEFT", -4, 0)
  f.next = Button(f, ">", 22, function() B.Step(1) end, "Next player")
  f.next:SetPoint("RIGHT", f.report, "LEFT", -8, 0)
  f.prev = Button(f, "<", 22, function() B.Step(-1) end, "Previous player")
  f.prev:SetPoint("RIGHT", f.next, "LEFT", -2, 0)

  -- tabs
  B.TABS = { { "summary", "Summary" }, { "spells", "Spells" }, { "targets", "Targets" }, { "chart", "Chart" },
             { "compare", "Compare" }, { "deaths", "Deaths" } }
  f.tabs = {}
  for i, t in ipairs(B.TABS) do
    local key = t[1]
    local b = Button(f, t[2], 96, function()
      B.tab = key
      B.Draw()
    end)
    b:SetPoint("TOPLEFT", f, "TOPLEFT", 10 + (i - 1) * 100, -38)
    b.key = key
    f.tabs[i] = b
  end

  -- the body: a list of bars on the left, a panel of lines on the right
  local BODY_TOP, ROWH = -66, 18
  local LIST_W = 400
  f.list = CreateFrame("Frame", nil, f)
  f.list:SetPoint("TOPLEFT", f, "TOPLEFT", 10, BODY_TOP)
  f.list:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 10, 10)
  f.list:SetWidth(LIST_W)
  f.list:EnableMouseWheel(true)
  f.list:SetScript("OnMouseWheel", function()
    B.offset = max(0, (B.offset or 0) - (arg1 or 0) * 3)
    B.Draw()
  end)
  f.panel = CreateFrame("Frame", nil, f)
  f.panel:SetPoint("TOPLEFT", f.list, "TOPRIGHT", 10, 0)
  f.panel:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, 10)
  CreateBackdrop(f.panel, nil, true, .5)
  f.rows, f.lines = {}, {}
  local MAXROWS = floor((H + BODY_TOP - 10) / (ROWH + 2))
  B.MAXROWS = MAXROWS

  local function Row(i)
    local r = f.rows[i]
    if r then return r end
    r = CreateFrame("Button", nil, f.list)
    r:SetHeight(ROWH)
    r:SetPoint("TOPLEFT", f.list, "TOPLEFT", 0, -(i - 1) * (ROWH + 2))
    r:SetPoint("RIGHT", f.list, "RIGHT", 0, 0)
    r.bar = CreateFrame("StatusBar", nil, r)
    r.bar:SetAllPoints(r)
    r.bar:SetMinMaxValues(0, 1)
    r.bg = r:CreateTexture(nil, "BACKGROUND")
    r.bg:SetAllPoints(r)
    r.bg:SetTexture(1, 1, 1, .05)
    r.sel = r:CreateTexture(nil, "OVERLAY")
    r.sel:SetAllPoints(r)
    r.sel:SetTexture(1, 1, 1, .12)
    r.sel:Hide()
    r.left = Text(r.bar, C.global.font_size)
    r.left:SetPoint("LEFT", r, "LEFT", 4, 0)
    r.right = Text(r.bar, C.global.font_size, "RIGHT")
    r.right:SetPoint("RIGHT", r, "RIGHT", -4, 0)
    r.left:SetPoint("RIGHT", r.right, "LEFT", -6, 0)
    r:SetScript("OnClick", function() if this.onclick then this.onclick() end end)
    f.rows[i] = r
    return r
  end

  -- a line on the right panel: label and value
  local function Line(i)
    local l = f.lines[i]
    if l then return l end
    l = {}
    l.label = Text(f.panel, C.global.font_size)
    l.label:SetPoint("TOPLEFT", f.panel, "TOPLEFT", 8, -6 - (i - 1) * 16)
    l.value = Text(f.panel, C.global.font_size, "RIGHT")
    l.value:SetPoint("TOPRIGHT", f.panel, "TOPRIGHT", -8, -6 - (i - 1) * 16)
    f.lines[i] = l
    return l
  end

  -- ---------------------------------------------------------------- filling

  local texture = "Interface\\AddOns\\pfUI\\img\\bar_elvui"
  local cr, cg, cb = .6, .6, .6

  -- list: { { name, value, text, onclick, selected, color } }
  local function FillList(list, maxv)
    local off = B.offset or 0
    if off > max(0, table.getn(list) - MAXROWS) then off = max(0, table.getn(list) - MAXROWS) B.offset = off end
    for i = 1, MAXROWS do
      local e = list[i + off]
      local r = Row(i)
      if e then
        r.bar:SetStatusBarTexture(texture)
        local c = e.color
        r.bar:SetStatusBarColor(c and c[1] or cr, c and c[2] or cg, c and c[3] or cb, .8)
        r.bar:SetValue((maxv and maxv > 0 and e.value) and e.value / maxv or 0)
        r.left:SetText(e.name)
        r.right:SetText(e.text or "")
        r.onclick = e.onclick
        if e.selected then r.sel:Show() else r.sel:Hide() end
        r:Show()
      else
        r:Hide()
      end
    end
    B.listShown = list
  end

  -- lines: { { label, value, head } }
  local function FillLines(lines)
    local ar, ag, ab = GetAccentColor()
    for i = 1, max(table.getn(lines), table.getn(f.lines)) do
      local e = lines[i]
      local l = Line(i)
      if e then
        l.label:SetText(e[1] or "")
        l.value:SetText(e[2] or "")
        if e.head then l.label:SetTextColor(ar, ag, ab) else l.label:SetTextColor(.85, .85, .85) end
        l.label:Show()
        l.value:Show()
      else
        l.label:Hide()
        l.value:Hide()
      end
    end
    B.linesShown = lines
  end

  -- the spells of an actor for the window's mode: list, total, heal?
  local function SpellsOf(a, mode)
    if mode == "taken" then return a.tspells, a.taken end
    if mode == "ff" then return a.ffspells or {}, a.ff or 0 end
    if HEALMODES[mode] then return a.hspells, a.heal, true end
    return a.spells, a.damage
  end
  local function TargetsOf(a, mode)
    if mode == "taken" then return a.sources, a.taken, "Damaged by" end
    if mode == "htaken" then return a.hsources or {}, a.htaken or 0, "Healed by" end
    if mode == "ff" then return a.fftargets or {}, a.ff or 0, "Hit" end
    if HEALMODES[mode] then return a.htargets, a.heal, "Healed" end
    return a.targets, a.damage, "Targets"
  end
  B.SpellsOf, B.TargetsOf = SpellsOf, TargetsOf

  local function Sorted(tbl, field)
    local out = {}
    for name, v in pairs(tbl or {}) do
      table.insert(out, { name = name, v = field and v[field] or v, data = v })
    end
    table.sort(out, function(x, y) return x.v > y.v end)
    return out
  end

  -- one spell in detail (right panel)
  local function SpellLines(name, s, total, heal)
    local lines = { { name, "", head = true } }
    local n = s.hits + s.ticks
    table.insert(lines, { heal and "Healed" or "Damage", Num(s.total) .. "  (" .. Pct(s.total, total) .. ")" })
    if B.active and B.active > 0 then table.insert(lines, { heal and "HPS" or "DPS", Num(s.total / B.active) }) end
    if s.hits > 0 then
      local crits = s.crits or 0
      local ctotal = s.ctotal or 0
      local normal = s.hits - crits
      -- (ticks apart: they are not hits)
      local ntotal = s.total - ctotal - (s.ttotal or 0)
      table.insert(lines, { "Hits", s.hits })
      table.insert(lines, { "  Normal", normal .. "   avg " .. Avg(max(0, ntotal), normal) })
      table.insert(lines, { "  Critical", crits .. "  (" .. Pct(crits, s.hits) .. ")   avg " .. Avg(ctotal, crits) })
      if s.cmax then table.insert(lines, { "  Biggest crit", Num(s.cmax) }) end
      table.insert(lines, { "  Smallest / biggest", (s.min and Num(s.min) or "-") .. " / " .. Num(s.max) })
    end
    if s.ticks > 0 then table.insert(lines, { "Ticks", s.ticks .. "   avg " .. Avg(s.ttotal or s.total, s.ticks) }) end
    if heal then
      table.insert(lines, { "Overhealing", Num(s.over or 0) .. "  (" .. Pct(s.over or 0, s.total + (s.over or 0)) .. ")" })
    elseif s.misses > 0 then
      table.insert(lines, { "Missed", s.misses .. "  (" .. Pct(s.misses, n + s.misses) .. ")" })
      for how, count in pairs(s.how or {}) do
        if how ~= "glancing" and how ~= "crushing" then table.insert(lines, { "  " .. how, count }) end
      end
    end
    if s.how and s.how.glancing then table.insert(lines, { "Glancing", s.how.glancing }) end
    if s.how and s.how.crushing then table.insert(lines, { "Crushing", s.how.crushing }) end
    if s.targets then
      table.insert(lines, { " ", "" })
      table.insert(lines, { "Targets", "", head = true })
      local list = Sorted(s.targets)
      for i = 1, min(6, table.getn(list)) do
        table.insert(lines, { list[i].name, Num(list[i].v) .. "  (" .. Pct(list[i].v, s.total) .. ")" })
      end
    end
    return lines
  end
  B.SpellLines = SpellLines

  -- ---------------------------------------------------------------- tabs

  local function Summary(a, seg)
    local fight = seg and M.Duration(seg) or 1
    local act = max(1, a.active or 0)
    local lines = { { "Damage and healing", "", head = true },
      { "Damage done", Num(a.damage) .. "   (" .. Num(a.damage / act) .. " dps)" },
      { "Healing done", Num(a.heal) .. "   (" .. Num(a.heal / act) .. " hps)" },
      { "Overhealing", Num(a.overheal) .. "  (" .. Pct(a.overheal, a.heal + a.overheal) .. ")" },
      { "Damage taken", Num(a.taken) },
      { "Healing taken", Num(a.htaken or 0) },
      { "Friendly fire", Num(a.ff or 0) },
      { "Time", "", head = true },
      { "Fight", Clock(fight) },
      { "Active", Clock(act) .. "  (" .. Pct(min(act, fight), fight) .. ")" },
      { "Utility", "", head = true },
      { "Interrupts / dispels", (a.interrupts or 0) .. " / " .. (a.dispels or 0) },
      { "Cooldowns used", a.cds or 0 },
      { "Resurrects", a.ress or 0 },
      { "Kills / deaths", (a.frags or 0) .. " / " .. (a.deaths or 0) },
      { "Casts", a.ncasts or 0 },
    }
    -- resources gained
    for pow, v in pairs(a.power or {}) do table.insert(lines, { pow .. " gained", Num(v) }) end
    FillLines(lines)
    -- the left: top spells of what the window shows
    local spells, total, heal = SpellsOf(a, B.mode)
    local list = {}
    for _, e in ipairs(Sorted(spells, "total")) do
      table.insert(list, { name = e.name, value = e.v, text = Num(e.v) .. "  " .. Pct(e.v, total) })
    end
    FillList(list, list[1] and list[1].value)
  end

  local function Spells(a)
    local spells, total, heal = SpellsOf(a, B.mode)
    local sorted = Sorted(spells, "total")
    if not B.spell or not spells[B.spell] then B.spell = sorted[1] and sorted[1].name end
    local list = {}
    for _, e in ipairs(sorted) do
      local name = e.name
      local s = e.data
      table.insert(list, { name = name, value = e.v,
        text = Num(e.v) .. "  " .. Pct(e.v, total) .. "  |cff888888" .. (s.hits + s.ticks) .. "x|r",
        selected = name == B.spell, onclick = function() B.spell = name B.Draw() end })
    end
    FillList(list, sorted[1] and sorted[1].v)
    if B.spell and spells[B.spell] then FillLines(SpellLines(B.spell, spells[B.spell], total, heal)) else FillLines({}) end
  end

  local function Targets(a)
    local tbl, total, title = TargetsOf(a, B.mode)
    local list = {}
    for _, e in ipairs(Sorted(tbl)) do
      table.insert(list, { name = e.name, value = e.v, text = Num(e.v) .. "  " .. Pct(e.v, total) })
    end
    FillList(list, list[1] and list[1].value)
    local lines = { { title, "", head = true }, { "Total", Num(total) }, { "How many", table.getn(list) } }
    if list[1] then table.insert(lines, { "Most", list[1].name }) end
    FillLines(lines)
  end

  -- the other players of this fight, for Compare
  local function Others(seg, a)
    local out = {}
    for name, o in pairs(seg and seg.actors or {}) do
      if o ~= a then table.insert(out, o) end
    end
    table.sort(out, function(x, y) return (x.damage + x.heal) > (y.damage + y.heal) end)
    return out
  end

  local function Compare(a, seg)
    local others = Others(seg, a)
    -- the same class first, else the biggest
    if not B.other or not seg.actors[B.other] or B.other == a.name then
      B.other = nil
      for _, o in ipairs(others) do if o.class == a.class then B.other = o.name break end end
      if not B.other and others[1] then B.other = others[1].name end
    end
    local o = B.other and seg.actors[B.other]
    if not o then
      FillList({}, 1)
      FillLines({ { "Nobody else in this fight to compare with.", "" } })
      return
    end
    local mine, mtotal = SpellsOf(a, B.mode)
    local theirs, ttotal = SpellsOf(o, B.mode)
    local names = {}
    for n in pairs(mine) do names[n] = true end
    for n in pairs(theirs) do names[n] = true end
    local list, top = {}, 1
    for n in pairs(names) do
      local x = mine[n] and mine[n].total or 0
      local y = theirs[n] and theirs[n].total or 0
      top = max(top, x, y)
      local gap = y > 0 and string.format("%+.0f%%", (x - y) / y * 100) or "new"
      local color = x >= y and "|cff66ff66" or "|cffff6666"
      table.insert(list, { name = n, value = x, sort = max(x, y),
        text = Num(x) .. "  |cff888888vs|r " .. Num(y) .. "  " .. color .. gap .. "|r" })
    end
    table.sort(list, function(p, q) return p.sort > q.sort end)
    FillList(list, top)
    local lines = { { a.name .. "  vs  " .. o.name, "", head = true },
      { "Total", Num(mtotal) .. "  /  " .. Num(ttotal) },
      { "Per second", Num(mtotal / max(1, a.active or 0)) .. "  /  " .. Num(ttotal / max(1, o.active or 0)) },
      { "Active", Clock(a.active or 0) .. "  /  " .. Clock(o.active or 0) },
      { " ", "" }, { "Compare with", "", head = true } }
    FillLines(lines)
    -- a list of the others to pick from, under the lines
    B.compareChoices = others
  end

  -- Chart: the player's damage (or healing) per second through the fight,
  -- as columns, with the group's in grey behind (Details' charts)
  f.chart = CreateFrame("Frame", nil, f)
  f.chart:SetPoint("TOPLEFT", f, "TOPLEFT", 10, BODY_TOP)
  f.chart:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, 10)
  CreateBackdrop(f.chart, nil, true, .5)
  f.chart.cols, f.chart.back = {}, {}
  f.chart.top = Text(f.chart, C.global.font_size - 1)
  f.chart.top:SetPoint("TOPLEFT", f.chart, "TOPLEFT", 6, -4)
  f.chart.right = Text(f.chart, C.global.font_size - 1, "RIGHT")
  f.chart.right:SetPoint("TOPRIGHT", f.chart, "TOPRIGHT", -6, -4)
  f.chart.bottom = Text(f.chart, C.global.font_size - 1)
  f.chart.bottom:SetPoint("BOTTOMLEFT", f.chart, "BOTTOMLEFT", 6, 4)
  f.chart.endtime = Text(f.chart, C.global.font_size - 1, "RIGHT")
  f.chart.endtime:SetPoint("BOTTOMRIGHT", f.chart, "BOTTOMRIGHT", -6, 4)
  f.chart:Hide()
  local CHART_W, CHART_H = W - 20 - 16, H + BODY_TOP - 10 - 40

  local function Column(list, i, parent)
    local c = list[i]
    if c then return c end
    c = parent:CreateTexture(nil, "ARTWORK")
    c:SetTexture("Interface\\Buttons\\WHITE8X8")
    list[i] = c
    return c
  end

  local function Chart(a, seg)
    local heal = HEALMODES[B.mode]
    local mine = M.Curve and M.Curve(seg, a.name, heal) or {}
    local all = M.Curve and M.Curve(seg, nil, heal) or {}
    local n = table.getn(mine)
    local ch = f.chart
    for _, c in pairs(ch.cols) do c:Hide() end
    for _, c in pairs(ch.back) do c:Hide() end
    if n < 2 then
      ch.top:SetText("No chart for this fight yet (it is drawn from the fight's samples, one a second).")
      ch.right:SetText("")
      ch.bottom:SetText("")
      ch.endtime:SetText("")
      B.chartPoints = 0
      return
    end
    -- at most one column per 2 pixels: samples are bunched together
    local cols = min(n, floor(CHART_W / 2))
    local per = n / cols
    local top, peak, sum = 1, 0, 0
    local vm, va = {}, {}
    for i = 1, cols do
      local from, to = floor((i - 1) * per) + 1, max(floor((i - 1) * per) + 1, floor(i * per))
      local m, g = 0, 0
      for j = from, to do m, g = m + (mine[j] or 0), g + (all[j] or 0) end
      m, g = m / (to - from + 1), g / (to - from + 1)
      vm[i], va[i] = m, g
      top = max(top, m, g)
      peak = max(peak, m)
      sum = sum + m
    end
    local w = CHART_W / cols
    local r, g, b = cr, cg, cb
    for i = 1, cols do
      local bk = Column(ch.back, i, ch)
      bk:ClearAllPoints()
      bk:SetPoint("BOTTOMLEFT", ch, "BOTTOMLEFT", 8 + (i - 1) * w, 20)
      bk:SetWidth(max(1, w - 1))
      bk:SetHeight(max(1, va[i] / top * CHART_H))
      bk:SetVertexColor(1, 1, 1, .12)
      bk:Show()
      local col = Column(ch.cols, i, ch)
      col:ClearAllPoints()
      col:SetPoint("BOTTOMLEFT", ch, "BOTTOMLEFT", 8 + (i - 1) * w, 20)
      col:SetWidth(max(1, w - 1))
      col:SetHeight(max(1, vm[i] / top * CHART_H))
      col:SetVertexColor(r, g, b, .9)
      col:Show()
    end
    local what = heal and "healing" or "damage"
    ch.top:SetText(a.name .. ": " .. what .. " per second  (grey: the whole group)")
    ch.right:SetText("peak " .. Num(peak) .. "   average " .. Num(sum / cols) .. "   scale " .. Num(top))
    ch.bottom:SetText("0:00")
    ch.endtime:SetText(Clock(seg.timeline[n].t))
    B.chartPoints = cols
  end
  B.Chart = Chart

  local function Deaths(a, seg)
    local start = seg and seg.start or 0
    local deaths = a.deathlogs or {}
    if table.getn(deaths) == 0 then
      FillList({}, 1)
      FillLines({ { "No deaths in this fight.", "" } })
      return
    end
    B.death = min(B.death or 1, table.getn(deaths))
    local list = {}
    for i, d in ipairs(deaths) do
      local idx = i
      table.insert(list, { name = string.format("Death %d at %s", i, Clock(d.t - start)), value = 1,
        text = d.killer and ("by " .. d.killer) or "", color = { .6, .15, .15 },
        selected = i == B.death, onclick = function() B.death = idx B.Draw() end })
    end
    FillList(list, 1)
    -- the last hits and heals, newest last, with health
    local d = deaths[B.death]
    local lines = { { "Before death " .. B.death, "health", head = true } }
    for _, e in ipairs(d.log or {}) do
      local sign = e.kind == "heal" and "|cff66ff66+" or "|cffff6666-"
      local hp = (e.hp and e.hpmax and e.hpmax > 0) and floor(e.hp / e.hpmax * 100) .. "%" or ""
      table.insert(lines, { string.format("%4.1fs ", e.t - d.t) .. sign .. Num(e.amount) .. (e.crit and "*" or "") .. "|r " ..
        (e.spell or "") .. " |cff888888" .. (e.who or "") .. "|r", hp })
    end
    FillLines(lines)
  end

  -- ---------------------------------------------------------------- open / draw

  function B.Draw()
    local a = B.actor
    if not a then return end
    local seg = M.Segment(B.segment)
    local mode = MODE[B.mode] or MODE.damage
    B.active = max(1, a.active or 0)
    -- header
    local coords = a.class and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[a.class]
    if coords then
      f.icon:SetTexture(pfUI.media["img:classicons"])
      f.icon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
      f.icon:Show()
    else
      f.icon:Hide()
    end
    local c = a.class and RAID_CLASS_COLORS[a.class]
    f.name:SetText(a.name)
    if c then f.name:SetTextColor(c.r, c.g, c.b) cr, cg, cb = c.r, c.g, c.b else f.name:SetTextColor(1, 1, 1) cr, cg, cb = .6, .6, .6 end
    local segname = M.SegmentName and M.SegmentName(B.segment) or ""
    f.sub:SetText(mode.name .. "  -  " .. gsub(segname, "|c%x%x%x%x%x%x%x%x", ""))
    if B.win and M.S then texture = M.S(B.win).texture or texture end
    for _, t in ipairs(f.tabs) do
      local ar, ag, ab = GetAccentColor()
      if t.key == B.tab then t.text:SetTextColor(ar, ag, ab) else t.text:SetTextColor(1, 1, 1) end
    end
    -- the chart takes the whole body
    if B.tab == "chart" then
      f.list:Hide()
      f.panel:Hide()
      f.chart:Show()
    else
      f.chart:Hide()
      f.list:Show()
      f.panel:Show()
    end
    if B.tab == "summary" then Summary(a, seg)
    elseif B.tab == "chart" then Chart(a, seg)
    elseif B.tab == "targets" then Targets(a)
    elseif B.tab == "compare" then Compare(a, seg)
    elseif B.tab == "deaths" then Deaths(a, seg)
    else Spells(a) end
    f:Show()
  end

  -- a click on a player's bar opens it (enemies and spells: the old breakdown)
  local ShowSimple = M.ShowDetails
  M.ShowDetails = function(win, row)
    if not row or not row.actor then return ShowSimple(win, row) end
    B.win, B.row = win, row
    B.actor = row.actor
    B.mode = win.mode
    B.segment = win.segment
    B.offset, B.spell, B.death = 0, nil, nil
    -- the tab that fits what the window shows
    if win.mode == "deaths" then B.tab = "deaths"
    elseif B.tab == "deaths" then B.tab = "spells" end
    B.Draw()
  end

  -- < >: the next player of the window's list
  function B.Step(dir)
    if not B.win then return end
    local rows = M.Rows(B.mode, B.segment)
    for i, r in ipairs(rows) do
      if r.actor == B.actor then
        local n = rows[i + dir]
        if n and n.actor then
          B.actor = n.actor
          B.offset, B.spell = 0, nil
          B.Draw()
        end
        return
      end
    end
  end

  -- Compare: pick the other player (click the panel's head line)
  f.pick = Button(f.panel, "Pick player...", 120, function()
    local items = { { "Compare with", head = true } }
    for _, o in ipairs(B.compareChoices or {}) do
      local name = o.name
      table.insert(items, { name, function() B.other = name B.Draw() end, checked = name == B.other })
    end
    M.ShowMenu(this, items)
  end)
  f.pick:SetPoint("BOTTOMLEFT", f.panel, "BOTTOMLEFT", 8, 8)
  f.pick:Hide()
  local draw = B.Draw
  B.Draw = function()
    draw()
    if B.tab == "compare" and B.compareChoices and table.getn(B.compareChoices) > 0 then f.pick:Show() else f.pick:Hide() end
  end

  -- ---------------------------------------------------------------- report

  -- what the open tab shows, as chat lines (top 10)
  function B.ReportLines()
    local a = B.actor
    if not a then return {} end
    local mode = MODE[B.mode] or MODE.damage
    local out = { "pfUI Octo - " .. a.name .. " - " .. mode.name .. " (" .. B.tab .. ")" }
    if B.tab == "summary" or B.tab == "deaths" then
      for _, l in ipairs(B.linesShown or {}) do
        if not l.head and l[1] and l[1] ~= " " then
          table.insert(out, gsub(gsub(l[1] .. "  " .. tostring(l[2] or ""), "|c%x%x%x%x%x%x%x%x", ""), "|r", ""))
        end
        if table.getn(out) > 12 then break end
      end
    else
      for i, e in ipairs(B.listShown or {}) do
        if i > (tonumber(C.meters.reportlines) or 10) then break end
        table.insert(out, i .. ". " .. e.name .. "  " .. gsub(gsub(e.text or "", "|c%x%x%x%x%x%x%x%x", ""), "|r", ""))
      end
    end
    return out
  end

  function B.Report(channel, whisper)
    for _, line in ipairs(B.ReportLines()) do SendChatMessage(line, channel, nil, whisper) end
  end

  function B.ReportMenu(anchor)
    local items = { { "Report this tab", head = true },
      { "Say", function() B.Report("SAY") end },
      { "Party", function() B.Report("PARTY") end },
      { "Raid", function() B.Report("RAID") end },
      { "Guild", function() B.Report("GUILD") end },
      { "Officer", function() B.Report("OFFICER") end } }
    if UnitIsPlayer("target") and UnitIsFriend("player", "target") then
      local name = UnitName("target")
      table.insert(items, { "Whisper " .. name, function() B.Report("WHISPER", name) end })
    end
    M.ShowMenu(anchor, items)
  end
end)

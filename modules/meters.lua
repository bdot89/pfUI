pfUI:RegisterModule("meters", "vanilla", function ()
  -- pfUI Octo meters: who did what in a fight, Details!/Recount style.
  --
  -- The data comes from the combat log messages, matched against the
  -- client's own GlobalStrings templates (so it works in every language).
  -- The template matching (sanitize / captures / cfind) is ShaguDPS's, by
  -- Shagu, pfUI's author. Recorded per player (pets merged into the owner):
  -- damage done and taken, effective healing and overhealing, every spell
  -- with hits / crits / misses / max / min, interrupts (who, what, with
  -- what), dispels (what was removed, from whom), deaths with the last
  -- hits and heals, every cast, avoidance. Fights are segments: the running
  -- one, the last C.meters.history ones and "overall".
  -- Design and data sources: docs/meters-spec.md. The window is
  -- meters-window.lua, threat is meters-threat.lua.
  if C.meters.enable ~= "1" then return end

  local M = {}
  pfUI.meters = M
  M.callbacks = {}

  local floor, min, max = math.floor, math.min, math.max
  local player = UnitName("player")
  local MELEE = T["Melee"]

  -- ---------------------------------------------------------------- templates

  -- template -> pattern for string.find (escape magic characters, drop
  -- capture indexes like %1$s, %s -> (.+), %d -> (%d+), anchored)
  local sanitize_cache = {}
  local function sanitize(pattern)
    if not sanitize_cache[pattern] then
      local ret = pattern
      ret = gsub(ret, "([%+%-%*%(%)%?%[%]%^%.])", "%%%1")
      ret = gsub(ret, "%d%$", "")
      ret = gsub(ret, "(%%%a)", "%(%1+%)")
      ret = gsub(ret, "%%s%+", ".+")
      ret = gsub(ret, "%(.%+%)%(%%d%+%)", "%(.-%)%(%%d%+%)")
      sanitize_cache[pattern] = "^" .. ret .. "$"
    end
    return sanitize_cache[pattern]
  end

  -- the order of %1$s style captures in a template
  local capture_cache = {}
  local function captures(pat)
    local r = capture_cache
    if not r[pat] then
      r[pat] = { nil, nil, nil, nil, nil }
      for a, b, c, d, e in string.gfind(gsub(pat, "%((.+)%)", "%1"), gsub(pat, "%d%$", "%%(.-)$")) do
        r[pat][1], r[pat][2], r[pat][3], r[pat][4], r[pat][5] = tonumber(a), tonumber(b), tonumber(c), tonumber(d), tonumber(e)
      end
    end
    return r[pat][1], r[pat][2], r[pat][3], r[pat][4], r[pat][5]
  end

  -- string.find aware of up to 5 capture indexes
  local ra, rb, rc, rd, re, ca, cb, cc, cd, ce, match, num, va, vb, vc, vd, ve
  local function cfind(str, pat)
    ca, cb, cc, cd, ce = captures(pat)
    match, num, va, vb, vc, vd, ve = string.find(str, sanitize(pat))
    ra = ce == 1 and ve or cd == 1 and vd or cc == 1 and vc or cb == 1 and vb or va
    rb = ce == 2 and ve or cd == 2 and vd or cc == 2 and vc or ca == 2 and va or vb
    rc = ce == 3 and ve or cd == 3 and vd or ca == 3 and va or cb == 3 and vb or vc
    rd = ce == 4 and ve or ca == 4 and va or cc == 4 and vc or cb == 4 and vb or vd
    re = ca == 5 and va or cd == 5 and vd or cc == 5 and vc or cb == 5 and vb or ve
    return match, ra, rb, rc, rd, re
  end
  M.cfind = cfind

  -- Each spec: global string name, kind, the roles of its captures in
  -- order, and fixed values. src/tgt "self" = the player.
  --   kinds: dmg heal miss interrupt cast start dispel death
  local SPECS = {
    -- interrupts first: they also come in the spell damage events
    { "SPELLINTERRUPTSELFOTHER", "interrupt", "tgt spl", src = "self" },
    { "SPELLINTERRUPTOTHERSELF", "interrupt", "src spl", tgt = "self" },
    { "SPELLINTERRUPTOTHEROTHER", "interrupt", "src tgt spl" },

    -- deaths
    { "UNITDIESSELF", "death", "", tgt = "self" },
    { "PARTYKILLOTHER", "death", "tgt src" },
    { "SELFKILLOTHER", "death", "tgt", src = "self" },
    { "UNITDIESOTHER", "death", "tgt" },

    -- dispels: "X's Y is removed." (credited to the last dispel cast on X)
    { "AURADISPELSELF", "dispel", "aura", tgt = "self" },
    { "AURADISPELOTHER", "dispel", "tgt aura" },

    -- melee
    { "COMBATHITCRITSCHOOLSELFOTHER", "dmg", "tgt amt sch", src = "self", spl = MELEE, crit = true },
    { "COMBATHITSCHOOLSELFOTHER", "dmg", "tgt amt sch", src = "self", spl = MELEE },
    { "COMBATHITCRITSELFOTHER", "dmg", "tgt amt", src = "self", spl = MELEE, crit = true },
    { "COMBATHITSELFOTHER", "dmg", "tgt amt", src = "self", spl = MELEE },
    { "COMBATHITCRITSCHOOLOTHERSELF", "dmg", "src amt sch", tgt = "self", spl = MELEE, crit = true },
    { "COMBATHITSCHOOLOTHERSELF", "dmg", "src amt sch", tgt = "self", spl = MELEE },
    { "COMBATHITCRITOTHERSELF", "dmg", "src amt", tgt = "self", spl = MELEE, crit = true },
    { "COMBATHITOTHERSELF", "dmg", "src amt", tgt = "self", spl = MELEE },
    { "COMBATHITCRITSCHOOLOTHEROTHER", "dmg", "src tgt amt sch", spl = MELEE, crit = true },
    { "COMBATHITSCHOOLOTHEROTHER", "dmg", "src tgt amt sch", spl = MELEE },
    { "COMBATHITCRITOTHEROTHER", "dmg", "src tgt amt", spl = MELEE, crit = true },
    { "COMBATHITOTHEROTHER", "dmg", "src tgt amt", spl = MELEE },

    -- spells
    { "SPELLLOGCRITSCHOOLSELFSELF", "dmg", "spl amt sch", src = "self", tgt = "self", crit = true },
    { "SPELLLOGSCHOOLSELFSELF", "dmg", "spl amt sch", src = "self", tgt = "self" },
    { "SPELLLOGCRITSELFSELF", "dmg", "spl amt", src = "self", tgt = "self", crit = true },
    { "SPELLLOGSELFSELF", "dmg", "spl amt", src = "self", tgt = "self" },
    { "SPELLLOGCRITSCHOOLSELFOTHER", "dmg", "spl tgt amt sch", src = "self", crit = true },
    { "SPELLLOGSCHOOLSELFOTHER", "dmg", "spl tgt amt sch", src = "self" },
    { "SPELLLOGCRITSELFOTHER", "dmg", "spl tgt amt", src = "self", crit = true },
    { "SPELLLOGSELFOTHER", "dmg", "spl tgt amt", src = "self" },
    { "SPELLLOGCRITSCHOOLOTHERSELF", "dmg", "src spl amt sch", tgt = "self", crit = true },
    { "SPELLLOGSCHOOLOTHERSELF", "dmg", "src spl amt sch", tgt = "self" },
    { "SPELLLOGCRITOTHERSELF", "dmg", "src spl amt", tgt = "self", crit = true },
    { "SPELLLOGOTHERSELF", "dmg", "src spl amt", tgt = "self" },
    { "SPELLLOGCRITSCHOOLOTHEROTHER", "dmg", "src spl tgt amt sch", crit = true },
    { "SPELLLOGSCHOOLOTHEROTHER", "dmg", "src spl tgt amt sch" },
    { "SPELLLOGCRITOTHEROTHER", "dmg", "src spl tgt amt", crit = true },
    { "SPELLLOGOTHEROTHER", "dmg", "src spl tgt amt" },

    -- damage over time
    { "PERIODICAURADAMAGESELFSELF", "dmg", "amt sch spl", src = "self", tgt = "self", dot = true },
    { "PERIODICAURADAMAGESELFOTHER", "dmg", "tgt amt sch spl", src = "self", dot = true },
    { "PERIODICAURADAMAGEOTHERSELF", "dmg", "amt sch src spl", tgt = "self", dot = true },
    { "PERIODICAURADAMAGEOTHEROTHER", "dmg", "tgt amt sch src spl", dot = true },

    -- damage shields (Thorns, Retribution Aura, Fire Shield...)
    { "DAMAGESHIELDSELFOTHER", "dmg", "amt sch tgt", src = "self", spl = T["Damage Shield"] },
    { "DAMAGESHIELDOTHERSELF", "dmg", "src amt sch", tgt = "self", spl = T["Damage Shield"] },
    { "DAMAGESHIELDOTHEROTHER", "dmg", "src amt sch tgt", spl = T["Damage Shield"] },

    -- heals
    { "HEALEDCRITSELFSELF", "heal", "spl amt", src = "self", tgt = "self", crit = true },
    { "HEALEDSELFSELF", "heal", "spl amt", src = "self", tgt = "self" },
    { "HEALEDCRITSELFOTHER", "heal", "spl tgt amt", src = "self", crit = true },
    { "HEALEDSELFOTHER", "heal", "spl tgt amt", src = "self" },
    { "HEALEDCRITOTHERSELF", "heal", "src spl amt", tgt = "self", crit = true },
    { "HEALEDOTHERSELF", "heal", "src spl amt", tgt = "self" },
    { "HEALEDCRITOTHEROTHER", "heal", "src spl tgt amt", crit = true },
    { "HEALEDOTHEROTHER", "heal", "src spl tgt amt" },
    { "PERIODICAURAHEALSELFSELF", "heal", "amt spl", src = "self", tgt = "self", dot = true },
    { "PERIODICAURAHEALSELFOTHER", "heal", "tgt amt spl", src = "self", dot = true },
    { "PERIODICAURAHEALOTHERSELF", "heal", "amt src spl", tgt = "self", dot = true },
    { "PERIODICAURAHEALOTHEROTHER", "heal", "tgt amt src spl", dot = true },

    -- melee misses and avoidance
    { "MISSEDSELFOTHER", "miss", "tgt", src = "self", spl = MELEE, how = "miss" },
    { "MISSEDOTHERSELF", "miss", "src", tgt = "self", spl = MELEE, how = "miss" },
    { "MISSEDOTHEROTHER", "miss", "src tgt", spl = MELEE, how = "miss" },
  }

  -- melee avoidance: VS<HOW><SELF|OTHER><SELF|OTHER>
  for _, how in pairs({ "DODGE", "PARRY", "BLOCK", "EVADE", "IMMUNE", "ABSORB", "RESIST" }) do
    local h = strlower(how)
    table.insert(SPECS, { "VS" .. how .. "SELFOTHER", "miss", "tgt", src = "self", spl = MELEE, how = h })
    table.insert(SPECS, { "VS" .. how .. "OTHERSELF", "miss", "src", tgt = "self", spl = MELEE, how = h })
    table.insert(SPECS, { "VS" .. how .. "OTHEROTHER", "miss", "src tgt", spl = MELEE, how = h })
  end

  -- spell misses: SPELL<HOW>SELFOTHER "Your %s ... %s." etc.
  local SPELLHOW = { MISS = "miss", DODGED = "dodge", PARRIED = "parry", BLOCKED = "block", EVADED = "evade",
                     RESIST = "resist", LOGABSORB = "absorb", REFLECT = "reflect", IMMUNE = "immune" }
  for name, h in pairs(SPELLHOW) do
    table.insert(SPECS, { "SPELL" .. name .. "SELFOTHER", "miss", "spl tgt", src = "self", how = h })
    table.insert(SPECS, { "SPELL" .. name .. "OTHERSELF", "miss", "src spl", tgt = "self", how = h })
    table.insert(SPECS, { "SPELL" .. name .. "OTHEROTHER", "miss", "src spl tgt", how = h })
  end

  -- casts (targeted forms first: "You cast X." would also match "You cast X on Y.")
  for _, spec in pairs({
    { "SPELLCASTGOSELFTARGETTED", "cast", "spl tgt", src = "self" },
    { "SPELLPERFORMGOSELFTARGETTED", "cast", "spl tgt", src = "self" },
    { "SPELLCASTGOOTHERTARGETTED", "cast", "src spl tgt" },
    { "SPELLPERFORMGOOTHERTARGETTED", "cast", "src spl tgt" },
    { "SPELLCASTGOSELF", "cast", "spl", src = "self" },
    { "SPELLPERFORMGOSELF", "cast", "spl", src = "self" },
    { "SPELLCASTGOOTHER", "cast", "src spl" },
    { "SPELLPERFORMGOOTHER", "cast", "src spl" },
    { "SPELLCASTOTHERSTART", "start", "src spl" },
    { "SPELLPERFORMOTHERSTART", "start", "src spl" },
    { "SPELLPERFORMSELFSTART", "start", "spl", src = "self" },
  }) do table.insert(SPECS, spec) end

  -- keep the specs whose template this client has, split their roles
  local ACTIVE = {}
  for i, spec in ipairs(SPECS) do
    local template = _G[spec[1]]
    if type(template) == "string" then
      spec.template = template
      spec.roles = {}
      for role in string.gfind(spec[3], "%a+") do table.insert(spec.roles, role) end
      -- fixed text: "Your %s hits %s for %d %s damage." must be tried before
      -- "%s hits %s for %d %s damage." (which would read "Your Fireball" as a name)
      spec.fixed = string.len((gsub(gsub(template, "%%%d%$[sd]", ""), "%%[sd]", "")))
      spec.index = i
      sanitize(template)
      table.insert(ACTIVE, spec)
    end
  end
  table.sort(ACTIVE, function(a, b)
    if a.fixed ~= b.fixed then return a.fixed > b.fixed end
    return a.index < b.index
  end)
  M.specs = ACTIVE

  -- the kinds tried for each combat log event (by its name)
  local function KindsFor(event)
    if strfind(event, "DEATH") then return { death = true } end
    if strfind(event, "_HITS") then return { dmg = true } end
    if strfind(event, "_MISSES") then return { miss = true } end
    if strfind(event, "DAMAGESHIELDS") then return { dmg = true, miss = true } end
    if strfind(event, "AURA_GONE") or strfind(event, "BREAK_AURA") then return { dispel = true } end
    if strfind(event, "PERIODIC") then return { dmg = true, heal = true } end
    if strfind(event, "_BUFF") then return { heal = true, cast = true, start = true } end
    if strfind(event, "_DAMAGE") then return { interrupt = true, dmg = true, miss = true, cast = true, start = true } end
    return { dmg = true, heal = true, miss = true, interrupt = true, cast = true, start = true, dispel = true, death = true }
  end

  local EVENTS = {
    "CHAT_MSG_COMBAT_SELF_HITS", "CHAT_MSG_COMBAT_SELF_MISSES",
    "CHAT_MSG_COMBAT_PARTY_HITS", "CHAT_MSG_COMBAT_PARTY_MISSES",
    "CHAT_MSG_COMBAT_FRIENDLYPLAYER_HITS", "CHAT_MSG_COMBAT_FRIENDLYPLAYER_MISSES",
    "CHAT_MSG_COMBAT_HOSTILEPLAYER_HITS", "CHAT_MSG_COMBAT_HOSTILEPLAYER_MISSES",
    "CHAT_MSG_COMBAT_PET_HITS", "CHAT_MSG_COMBAT_PET_MISSES",
    "CHAT_MSG_COMBAT_CREATURE_VS_SELF_HITS", "CHAT_MSG_COMBAT_CREATURE_VS_SELF_MISSES",
    "CHAT_MSG_COMBAT_CREATURE_VS_PARTY_HITS", "CHAT_MSG_COMBAT_CREATURE_VS_PARTY_MISSES",
    "CHAT_MSG_COMBAT_CREATURE_VS_CREATURE_HITS", "CHAT_MSG_COMBAT_CREATURE_VS_CREATURE_MISSES",
    "CHAT_MSG_SPELL_SELF_DAMAGE", "CHAT_MSG_SPELL_SELF_BUFF",
    "CHAT_MSG_SPELL_PARTY_DAMAGE", "CHAT_MSG_SPELL_PARTY_BUFF",
    "CHAT_MSG_SPELL_FRIENDLYPLAYER_DAMAGE", "CHAT_MSG_SPELL_FRIENDLYPLAYER_BUFF",
    "CHAT_MSG_SPELL_HOSTILEPLAYER_DAMAGE", "CHAT_MSG_SPELL_HOSTILEPLAYER_BUFF",
    "CHAT_MSG_SPELL_PET_DAMAGE", "CHAT_MSG_SPELL_PET_BUFF",
    "CHAT_MSG_SPELL_CREATURE_VS_SELF_DAMAGE", "CHAT_MSG_SPELL_CREATURE_VS_PARTY_DAMAGE",
    "CHAT_MSG_SPELL_CREATURE_VS_CREATURE_DAMAGE",
    "CHAT_MSG_SPELL_DAMAGESHIELDS_ON_SELF", "CHAT_MSG_SPELL_DAMAGESHIELDS_ON_OTHERS",
    "CHAT_MSG_SPELL_PERIODIC_SELF_DAMAGE", "CHAT_MSG_SPELL_PERIODIC_SELF_BUFFS",
    "CHAT_MSG_SPELL_PERIODIC_PARTY_DAMAGE", "CHAT_MSG_SPELL_PERIODIC_PARTY_BUFFS",
    "CHAT_MSG_SPELL_PERIODIC_FRIENDLYPLAYER_DAMAGE", "CHAT_MSG_SPELL_PERIODIC_FRIENDLYPLAYER_BUFFS",
    "CHAT_MSG_SPELL_PERIODIC_HOSTILEPLAYER_DAMAGE", "CHAT_MSG_SPELL_PERIODIC_HOSTILEPLAYER_BUFFS",
    "CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE",
    "CHAT_MSG_SPELL_BREAK_AURA", "CHAT_MSG_SPELL_AURA_GONE_OTHER", "CHAT_MSG_SPELL_AURA_GONE_SELF",
    "CHAT_MSG_COMBAT_FRIENDLY_DEATH", "CHAT_MSG_COMBAT_HOSTILE_DEATH",
  }

  -- trailers: " (12 absorbed)", " (8 resisted)", " (30 blocked)", " (glancing)", " (crushing)"
  local TRAILERS = {}
  for _, name in pairs({ "ABSORB_TRAILER", "RESIST_TRAILER", "BLOCK_TRAILER", "VULNERABLE_TRAILER" }) do
    if type(_G[name]) == "string" then
      local p = sanitize(_G[name])
      table.insert(TRAILERS, string.sub(p, 2, -2) .. "$")
    end
  end
  local GLANCING = type(GLANCING_TRAILER) == "string" and GLANCING_TRAILER or " (glancing)"
  local CRUSHING = type(CRUSHING_TRAILER) == "string" and CRUSHING_TRAILER or " (crushing)"

  -- reads one combat log line: a record table or nil (reused table)
  local rec = {}
  function M.Read(event, msg)
    if type(msg) ~= "string" then return end

    local glancing, crushing
    if strfind(msg, GLANCING, 1, true) then glancing = true msg = gsub(msg, "%s?%(.-%)$", "") end
    if strfind(msg, CRUSHING, 1, true) then crushing = true msg = gsub(msg, "%s?%(.-%)$", "") end
    local n
    repeat
      n = 0
      for _, p in pairs(TRAILERS) do
        local before = msg
        msg = gsub(msg, p, "")
        if msg ~= before then n = n + 1 end
      end
    until n == 0

    local kinds = KindsFor(event or "")
    for _, spec in ipairs(ACTIVE) do
      if kinds[spec[2]] then
        local found, a1, a2, a3, a4, a5 = cfind(msg, spec.template)
        if found then
          rec.kind, rec.how, rec.crit, rec.dot = spec[2], spec.how, spec.crit, spec.dot
          rec.glancing, rec.crushing = glancing, crushing
          rec.src, rec.tgt, rec.spl, rec.amt, rec.sch, rec.aura = nil, nil, spec.spl, nil, nil, nil
          local values = { a1, a2, a3, a4, a5 }
          for i, role in ipairs(spec.roles) do rec[role] = values[i] end
          if spec.src == "self" then rec.src = player end
          if spec.tgt == "self" then rec.tgt = player end
          rec.amt = tonumber(rec.amt)
          return rec
        end
      end
    end
  end

  -- ---------------------------------------------------------------- who is tracked

  local units = { "player", "pet" }
  for i = 1, 4 do table.insert(units, "party" .. i) table.insert(units, "partypet" .. i) end
  for i = 1, 40 do table.insert(units, "raid" .. i) table.insert(units, "raidpet" .. i) end

  local unitcache = {}
  local function UnitByName(name)
    local u = unitcache[name]
    if u and UnitName(u) == name then return u end
    for _, unit in ipairs(units) do
      if UnitName(unit) == name then
        unitcache[name] = unit
        return unit
      end
    end
  end
  M.UnitByName = UnitByName

  -- name -> { kind = "PLAYER" | "PET" | "OTHER", class, owner }
  M.who = {}
  local function Who(name)
    if not name then return end
    local w = M.who[name]
    if w and w.checked and w.checked > GetTime() - 10 then return w.kind and w end

    w = { checked = GetTime() }
    M.who[name] = w
    local unit = UnitByName(name)
    if unit then
      if strfind(unit, "pet") then
        w.kind = "PET"
        local owner = unit == "pet" and "player" or gsub(unit, "pet", "")
        w.owner = UnitName(owner)
      elseif UnitIsPlayer(unit) then
        w.kind = "PLAYER"
        local _, class = UnitClass(unit)
        w.class = class
      end
    else
      -- SuperWoW names pets "Wolf (Owner)"
      local _, _, owner = strfind(name, "%((.+)%)$")
      if owner and UnitByName(owner) then
        w.kind, w.owner = "PET", owner
      elseif C.meters.trackall == "1" then
        w.kind = "OTHER"
      end
    end
    return w.kind and w
  end
  M.Who = Who

  -- ---------------------------------------------------------------- segments

  local function NewSegment(name)
    return { name = name, start = GetTime(), last = GetTime(), actors = {}, enemies = {} }
  end

  M.overall = NewSegment(T["Overall"])
  M.history = {}    -- finished and running fights, newest first
  M.current = nil   -- the running fight

  function M.Duration(seg)
    if not seg then return 1 end
    if seg == M.overall then
      local t = 0
      for _, s in ipairs(M.history) do t = t + max(1, (s.last or s.start) - s.start) end
      return max(1, t)
    end
    return max(1, (seg.last or seg.start) - seg.start)
  end

  local function Actor(seg, name, info)
    local a = seg.actors[name]
    if not a then
      a = { name = name, class = info and info.class, damage = 0, heal = 0, overheal = 0, taken = 0,
            interrupts = 0, interrupted = 0, dispels = 0, deaths = 0, ncasts = 0, active = 0,
            spells = {}, hspells = {}, tspells = {}, targets = {}, htargets = {}, sources = {},
            casts = {}, avoid = {}, ilist = {}, dlist = {}, deathlogs = {} }
      seg.actors[name] = a
    end
    if info and info.class and not a.class then a.class = info.class end
    return a
  end
  M.Actor = Actor

  -- activity time: gaps longer than 3.5 s count as 1.5 s
  local function Active(a, now)
    if a.lastact then
      local gap = now - a.lastact
      a.active = a.active + (gap > 3.5 and 1.5 or gap)
    end
    a.lastact = now
  end

  local function Spell(list, name)
    local s = list[name]
    if not s then
      s = { total = 0, hits = 0, crits = 0, ticks = 0, misses = 0, over = 0, max = 0, min = nil, how = {} }
      list[name] = s
    end
    return s
  end

  -- every fight starts when a tracked player acts while the group is in combat
  local function GroupInCombat()
    if UnitAffectingCombat("player") or UnitAffectingCombat("pet") then return true end
    local raid, party = GetNumRaidMembers(), GetNumPartyMembers()
    if raid > 0 then
      for i = 1, raid do
        if UnitAffectingCombat("raid" .. i) or UnitAffectingCombat("raidpet" .. i) then return true end
      end
    else
      for i = 1, party do
        if UnitAffectingCombat("party" .. i) or UnitAffectingCombat("partypet" .. i) then return true end
      end
    end
  end
  M.GroupInCombat = GroupInCombat

  function M.StartFight()
    local seg = NewSegment(T["Fight"])
    M.current = seg
    table.insert(M.history, 1, seg)
    local keep = tonumber(C.meters.history) or 10
    while table.getn(M.history) > keep do table.remove(M.history) end
    return seg
  end

  function M.EndFight()
    local seg = M.current
    if not seg then return end
    M.current = nil
    -- name it after the enemy that took the most damage
    local best, bestv = nil, 0
    for name, v in pairs(seg.enemies) do
      if v > bestv then best, bestv = name, v end
    end
    seg.name = best or T["Fight"]
    M.Changed()
  end

  function M.Reset()
    M.overall = NewSegment(T["Overall"])
    M.history = {}
    M.current = nil
    M.Changed()
  end

  -- the segments a window can show: "overall", "current" (running or
  -- last), or a history index
  function M.Segment(key)
    if key == "overall" then return M.overall end
    if key == "current" then return M.current or M.history[1] end
    return M.history[tonumber(key) or 1]
  end

  -- ---------------------------------------------------------------- death logs

  -- the last 15 things that happened to each player, for the death log
  M.recent = {}
  local function Remember(name, kind, amount, spell, other, crit)
    local ring = M.recent[name]
    if not ring then ring = { n = 0 } M.recent[name] = ring end
    ring.n = ring.n + 1
    ring[math.mod(ring.n - 1, 15) + 1] = { t = GetTime(), kind = kind, amount = amount, spell = spell, who = other,
                                           crit = crit, hp = nil }
    local unit = UnitByName(name)
    if unit then
      local entry = ring[math.mod(ring.n - 1, 15) + 1]
      entry.hp, entry.hpmax = UnitHealth(unit), UnitHealthMax(unit)
    end
  end

  local function DeathLog(name)
    local ring = M.recent[name]
    local log = {}
    if not ring then return log end
    local first = max(1, ring.n - 14)
    for i = first, ring.n do
      local e = ring[math.mod(i - 1, 15) + 1]
      if e and GetTime() - e.t < 15 then table.insert(log, e) end
    end
    M.recent[name] = nil
    return log
  end

  -- ---------------------------------------------------------------- recording

  local DISPELS = {}
  for _, s in pairs({ "Dispel Magic", "Cleanse", "Purify", "Remove Curse", "Remove Lesser Curse", "Cure Poison",
                      "Abolish Poison", "Cure Disease", "Abolish Disease", "Purge", "Devour Magic",
                      "Tranquilizing Shot", "Poison Cleansing Totem", "Disease Cleansing Totem" }) do
    DISPELS[T[s]] = true
  end
  local pendingDispel = {}  -- target -> { src, spell, t }
  local pendingStart = {}   -- src .. spell -> time a cast began
  local lastSpell = {}      -- src -> { spell, t } (what an interrupt was done with)

  -- the actor names a record belongs to: a player, or a pet's owner
  local function Owner(name)
    local w = Who(name)
    if not w then return end
    if w.kind == "PET" then
      if C.meters.mergepets == "1" and w.owner then return w.owner, name end
      return name
    end
    return name
  end

  local function Each(fn)
    fn(M.overall)
    if M.current then fn(M.current) end
  end

  function M.Record(r)
    if not r or not r.kind then return end
    local now = GetTime()
    local srcname, srcpet = Owner(r.src)
    local tgtname = Owner(r.tgt)

    -- a fight starts with the first tracked action in combat
    if not M.current and (srcname or tgtname) and (r.kind == "dmg" or r.kind == "heal" or r.kind == "miss") then
      if GroupInCombat() or M.forceCombat then M.StartFight() end
    end
    if M.current then M.current.last = now end

    local label = r.spl or MELEE
    if srcpet then label = label .. " (" .. srcpet .. ")" end
    -- what each unit last used (an interrupt names the spell it stopped, not the kick)
    local with = r.kind == "interrupt" and r.src and lastSpell[r.src] and now - lastSpell[r.src].t < 1.5 and lastSpell[r.src].spell
    if r.src and r.spl and r.kind ~= "interrupt" and r.kind ~= "start" then lastSpell[r.src] = { spell = r.spl, t = now } end

    if r.kind == "dmg" then
      if not r.amt or r.src == r.tgt then return end
      if srcname then
        Each(function(seg)
          local a = Actor(seg, srcname, Who(srcname))
          a.damage = a.damage + r.amt
          Active(a, now)
          local s = Spell(a.spells, label)
          s.total = s.total + r.amt
          if r.dot then s.ticks = s.ticks + 1 else s.hits = s.hits + 1 end
          if r.crit then s.crits = s.crits + 1 end
          if r.glancing then s.how.glancing = (s.how.glancing or 0) + 1 end
          if r.crushing then s.how.crushing = (s.how.crushing or 0) + 1 end
          if r.amt > s.max then s.max = r.amt end
          if not r.dot and (not s.min or r.amt < s.min) then s.min = r.amt end
          if r.tgt then a.targets[r.tgt] = (a.targets[r.tgt] or 0) + r.amt end
          if not tgtname and r.tgt then seg.enemies[r.tgt] = (seg.enemies[r.tgt] or 0) + r.amt end
        end)
        -- a direct hit of a spell that began casting counts as its cast
        if not r.dot and r.spl and r.spl ~= MELEE then
          local key = r.src .. "\031" .. r.spl
          if pendingStart[key] then pendingStart[key] = nil else M.Cast(srcname, r.spl, r.tgt, true) end
        end
      end
      if tgtname then
        Each(function(seg)
          local a = Actor(seg, tgtname, Who(tgtname))
          a.taken = a.taken + r.amt
          local who = r.src or "?"
          a.sources[who] = (a.sources[who] or 0) + r.amt
          local s = Spell(a.tspells, label .. " - " .. who)
          s.total = s.total + r.amt
          s.hits = s.hits + 1
          if r.amt > s.max then s.max = r.amt end
        end)
        Remember(tgtname, "dmg", r.amt, label, r.src, r.crit)
      end

    elseif r.kind == "heal" then
      if not r.amt then return end
      local effective = r.amt
      local unit = r.tgt and UnitByName(r.tgt)
      if unit then effective = min(r.amt, max(0, UnitHealthMax(unit) - UnitHealth(unit))) end
      if srcname then
        Each(function(seg)
          local a = Actor(seg, srcname, Who(srcname))
          a.heal = a.heal + effective
          a.overheal = a.overheal + (r.amt - effective)
          Active(a, now)
          local s = Spell(a.hspells, label)
          s.total = s.total + effective
          s.over = s.over + (r.amt - effective)
          if r.dot then s.ticks = s.ticks + 1 else s.hits = s.hits + 1 end
          if r.crit then s.crits = s.crits + 1 end
          if r.amt > s.max then s.max = r.amt end
          if not r.dot and (not s.min or r.amt < s.min) then s.min = r.amt end
          if r.tgt then a.htargets[r.tgt] = (a.htargets[r.tgt] or 0) + effective end
        end)
        if not r.dot and r.spl then
          local key = r.src .. "\031" .. r.spl
          if pendingStart[key] then pendingStart[key] = nil else M.Cast(srcname, r.spl, r.tgt, true) end
        end
      end
      if tgtname then Remember(tgtname, "heal", effective, label, r.src, r.crit) end

    elseif r.kind == "miss" then
      if srcname then
        Each(function(seg)
          local a = Actor(seg, srcname, Who(srcname))
          Active(a, now)
          local s = Spell(a.spells, label)
          s.misses = s.misses + 1
          s.how[r.how or "miss"] = (s.how[r.how or "miss"] or 0) + 1
        end)
      end
      if tgtname then
        Each(function(seg)
          local a = Actor(seg, tgtname, Who(tgtname))
          a.avoid[r.how or "miss"] = (a.avoid[r.how or "miss"] or 0) + 1
        end)
      end

    elseif r.kind == "interrupt" then
      if with == r.spl then with = nil end
      if srcname then
        Each(function(seg)
          local a = Actor(seg, srcname, Who(srcname))
          a.interrupts = a.interrupts + 1
          table.insert(a.ilist, { t = now, spell = r.spl, target = r.tgt, with = with })
        end)
      end
      if tgtname then
        Each(function(seg)
          local a = Actor(seg, tgtname, Who(tgtname))
          a.interrupted = a.interrupted + 1
        end)
      end

    elseif r.kind == "start" then
      if r.src and r.spl then pendingStart[r.src .. "\031" .. r.spl] = now end
      if srcname then M.Cast(srcname, r.spl, nil) end

    elseif r.kind == "cast" then
      if srcname then M.Cast(srcname, r.spl, r.tgt) end
      if r.spl and DISPELS[r.spl] and r.tgt then
        pendingDispel[r.tgt] = { src = srcname, spell = r.spl, t = now }
      end

    elseif r.kind == "dispel" then
      local p = r.tgt and pendingDispel[r.tgt]
      if p and p.src and now - p.t < 2 then
        Each(function(seg)
          local a = Actor(seg, p.src, Who(p.src))
          a.dispels = a.dispels + 1
          table.insert(a.dlist, { t = now, aura = r.aura, target = r.tgt, with = p.spell })
        end)
      end

    elseif r.kind == "death" then
      if tgtname then
        local w = Who(r.tgt)
        if w and w.kind ~= "PET" then
          local log = DeathLog(tgtname)
          Each(function(seg)
            local a = Actor(seg, tgtname, w)
            a.deaths = a.deaths + 1
            table.insert(a.deathlogs, { t = now, killer = r.src, log = log })
          end)
        end
      end
      if r.tgt and M.current then M.current.enemies[r.tgt] = M.current.enemies[r.tgt] or 0 end
    end

    M.Changed()
  end

  -- a cast by an actor; counted == true when it came from its hit
  function M.Cast(name, spell, target, counted)
    if not name or not spell then return end
    Each(function(seg)
      local a = Actor(seg, name, Who(name))
      a.casts[spell] = (a.casts[spell] or 0) + 1
      a.ncasts = a.ncasts + 1
    end)
  end

  -- windows refresh at most 5 times a second
  local dirty
  function M.Changed() dirty = true end

  local f = CreateFrame("Frame", "pfMetersParser", UIParent)
  for _, event in pairs(EVENTS) do f:RegisterEvent(event) end
  f:RegisterEvent("PLAYER_REGEN_DISABLED")
  f:RegisterEvent("PLAYER_REGEN_ENABLED")
  f:SetScript("OnEvent", function()
    if event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
      this.check = 0
      return
    end
    M.Record(M.Read(event, arg1))
  end)

  f:SetScript("OnUpdate", function()
    if (this.tick or 0) > GetTime() then return end
    this.tick = GetTime() + .2
    -- the fight ends a second after the whole group left combat
    if (this.check or 0) <= GetTime() then
      this.check = GetTime() + 1
      if M.current and not GroupInCombat() and not M.forceCombat then M.EndFight() end
    end
    -- forget stale cast starts / dispel casts / last spells
    if (this.clean or 0) <= GetTime() then
      this.clean = GetTime() + 10
      local old = GetTime() - 10
      for k, t in pairs(pendingStart) do if t < old then pendingStart[k] = nil end end
      for k, p in pairs(pendingDispel) do if p.t < old then pendingDispel[k] = nil end end
      for k, p in pairs(lastSpell) do if p.t < old then lastSpell[k] = nil end end
    end
    if dirty then
      dirty = nil
      for _, fn in pairs(M.callbacks) do fn() end
    end
  end)
  M.frame = f
end)

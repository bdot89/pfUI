pfUI:RegisterModule("plates-lists", "vanilla:tbc", function ()
  -- pfUI Octo nameplates, phase 3 (docs\plates-spec.md):
  --   npc colours   a bar colour and / or a new name per NPC name
  --   cast colours  a cast bar colour and / or a new spell name per spell
  --   quest marks   from pfQuest's map data (kill or loot objective, quest to
  --                 take, quest to hand in), else your quest log's "X slain"
  --   icons         class icon on players, a paw on pets
  --   auto          enemy plates by combat, friendly plates by city /
  --                 dungeon / open world
  -- Lists are strings so profile strings carry them:
  --   "Name|r,g,b|New name#Name2|...", colour or new name may be empty.
  local P = pfUI.plates
  if not P then return end
  local S = C.plates
  local L = {}
  P.Lists = L

  -- ---------------------------------------------------------------- the lists

  function L.Parse(str)
    local out = {}
    for _, item in pairs({ strsplit("#", str or "") }) do
      local _, _, name, col, new = string.find(item or "", "^([^|]+)|?([^|]*)|?(.*)$")
      if name and name ~= "" then
        local e = { name = name }
        if col and col ~= "" then
          local r, g, b = GetStringColor(col)
          if tonumber(r) then e.color = { tonumber(r), tonumber(g) or 1, tonumber(b) or 1 } end
        end
        if new and new ~= "" then e.rename = new end
        out[string.lower(name)] = e
      end
    end
    return out
  end

  function L.Serialize(list)
    local keys = {}
    for k in pairs(list) do table.insert(keys, k) end
    table.sort(keys)
    local parts = {}
    for _, k in ipairs(keys) do
      local e = list[k]
      local col = e.color and string.format("%.2f,%.2f,%.2f", e.color[1], e.color[2], e.color[3]) or ""
      table.insert(parts, e.name .. "|" .. col .. "|" .. (e.rename or ""))
    end
    return table.concat(parts, "#")
  end

  local npcs, casts = {}, {}
  function L.Read()
    npcs = L.Parse(S.npclist)
    casts = L.Parse(S.castlist)
  end
  function L.Npc(name) return name and npcs[string.lower(name)] end
  function L.CastEntry(name) return name and casts[string.lower(name)] end

  -- add / change / remove one entry of a list setting ("npclist" / "castlist")
  function L.Put(key, name, color, rename)
    if not name or name == "" then return end
    local list = L.Parse(S[key])
    list[string.lower(name)] = { name = name, color = color, rename = (rename and rename ~= "") and rename or nil }
    S[key] = L.Serialize(list)
    L.Read()
  end
  function L.Remove(key, name)
    local list = L.Parse(S[key])
    list[string.lower(name or "")] = nil
    S[key] = L.Serialize(list)
    L.Read()
  end

  -- the bar colour for a plate: NPC colour, unless a threat colour wins
  function L.BarColor(plate, state, col)
    local e = L.Npc(plate.original.name:GetText())
    if not e or not e.color then return col end
    if col and state and S.npcoverthreat ~= "1" then return col end
    return e.color
  end

  -- ---------------------------------------------------------------- quests

  -- names you need for a quest -> "objective" | "start" | "end"
  local questLog = {}
  local KIND = { UNIT_OBJECTIVE = "objective", UNIT_OBJECTIVE_ITEMREQ = "objective", ITEM_OBJECTIVE_LOOT = "objective",
    NPC_START = "start", NPC_END = "end" }
  function L.Quest(name)
    if not name then return end
    -- pfQuest's map data (every unit on the map it marks, by quest)
    local tips = pfMap and pfMap.tooltips and pfMap.tooltips[name]
    if tips then
      local best
      for _, maps in pairs(tips) do
        for _, node in pairs(maps) do
          local k = type(node) == "table" and KIND[node.QTYPE]
          if k == "objective" then return "objective" end
          if k == "end" then best = "end" elseif k and not best then best = k end
        end
      end
      if best then return best end
    end
    return questLog[name]
  end

  -- your quest log: "Defias Pillager slain: 3/10" not yet done
  local SLAIN = string.gsub(QUEST_MONSTERS_KILLED or "%s slain: %d/%d", "%%%d?%$?s", "(.+)")
  SLAIN = string.gsub(SLAIN, "%%%d?%$?d", "%%d+")
  function L.ReadQuestLog()
    questLog = {}
    if not GetNumQuestLogEntries then return end
    for q = 1, (GetNumQuestLogEntries() or 0) do
      for i = 1, (GetNumQuestLeaderBoards(q) or 0) do
        local text, kind, done = GetQuestLogLeaderBoard(i, q)
        if text and kind == "monster" and not done then
          local _, _, who = string.find(text, "^" .. SLAIN .. "$")
          if who then questLog[who] = "objective" end
        end
      end
    end
  end
  L.SLAIN = SLAIN

  local ql = CreateFrame("Frame")
  ql:RegisterEvent("QUEST_LOG_UPDATE")
  ql:RegisterEvent("PLAYER_ENTERING_WORLD")
  ql:SetScript("OnEvent", function()
    if (this.next or 0) > GetTime() then return end
    this.next = GetTime() + .5
    L.ReadQuestLog()
  end)

  -- ---------------------------------------------------------------- plate parts

  local QUESTART = { objective = "quest-objective", start = "quest-start", ["end"] = "quest-end" }

  function L.Build(plate, o)
    o.qmark = plate:CreateTexture(nil, "OVERLAY")
    o.qmark:Hide()
    o.cicon = plate:CreateTexture(nil, "OVERLAY")
    o.cicon:Hide()
  end

  function L.Configure(plate, o)
    if not o.qmark then L.Build(plate, o) end
    L.Read()
    local size = (tonumber(S.namesize) or 0) > 0 and tonumber(S.namesize) or (tonumber(C.global.font_size) or 12)
    o.qmark:SetWidth(size + 4)
    o.qmark:SetHeight(size + 4)
    o.qmark:ClearAllPoints()
    o.qmark:SetPoint("LEFT", plate.name, "RIGHT", 2, 0)
    o.cicon:SetWidth(size + 2)
    o.cicon:SetHeight(size + 2)
    o.cicon:ClearAllPoints()
    o.cicon:SetPoint("RIGHT", o.mark, "LEFT", -1, 0)
  end

  function L.Off(o)
    if o.qmark then o.qmark:Hide() o.cicon:Hide() end
  end

  -- after pfUI's update: new names, quest mark, class / pet icon
  function L.Update(plate, o, unit, enemy)
    if not o.qmark then L.Configure(plate, o) end
    local pv = plate.parent and plate.parent.preview
    local name = plate.original.name:GetText()
    local e = L.Npc(name)
    if e and e.rename then plate.name:SetText(e.rename) end

    -- quest mark
    local q = S.questmark == "1" and plate.name:IsShown() and o.quest
    if q and QUESTART[q] then
      o.qmark:SetTexture(P.ART(QUESTART[q]))
      local c = q == "objective" and { GetStringColor(S.questcolor) } or { 1, .82, 0 }
      o.qmark:SetVertexColor(tonumber(c[1]) or 1, tonumber(c[2]) or .82, tonumber(c[3]) or 0, 1)
      o.qmark:Show()
    else
      o.qmark:Hide()
    end

    -- class icon on players, paw on pets
    local icon, coords
    if unit and not pv and UnitExists(unit) then
      if UnitIsPlayer(unit) then
        local _, class = UnitClass(unit)
        local want = (enemy and S.classicon_enemy == "1") or (not enemy and S.classicon_friend == "1")
        if want and class and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class] then
          icon, coords = pfUI.media["img:classicons"], CLASS_ICON_TCOORDS[class]
        end
      elseif S.peticon == "1" and UnitPlayerControlled and UnitPlayerControlled(unit) then
        icon = P.ART("pet")
      end
    elseif pv and pv.class == "pet" then
      icon = P.ART("pet")
    end
    if icon and plate.name:IsShown() then
      o.cicon:SetTexture(icon)
      if coords then o.cicon:SetTexCoord(coords[1], coords[2], coords[3], coords[4]) else o.cicon:SetTexCoord(0, 1, 0, 1) end
      o.cicon:ClearAllPoints()
      if o.mark:IsShown() then o.cicon:SetPoint("RIGHT", o.mark, "LEFT", -1, 0) else o.cicon:SetPoint("RIGHT", plate.name, "LEFT", -2, 0) end
      o.cicon:Show()
    else
      o.cicon:Hide()
    end
  end

  -- what a plate's unit is to your quests (nil = nothing)
  function L.QuestFor(plate)
    if S.questmark ~= "1" and S.questbar ~= "1" then return end
    local pv = plate.parent and plate.parent.preview
    if pv then return pv.quest end
    return L.Quest(plate.original.name:GetText())
  end

  -- quest units' bar colour (when on): after threat / execute, before pfUI's
  function L.QuestColor(o, col)
    if col or S.questbar ~= "1" or o.quest ~= "objective" then return col end
    local r, g, b = GetStringColor(S.questcolor)
    return { tonumber(r) or 1, tonumber(g) or .82, tonumber(b) or 0, 1 }
  end

  -- ---------------------------------------------------------------- auto toggles

  L.CITIES = {}
  for _, z in ipairs({ "Stormwind City", "Ironforge", "Darnassus", "Orgrimmar", "Thunder Bluff", "Undercity",
                       "Alah'Thalas", "Booty Bay", "Gadgetzan", "Everlook", "Ratchet" }) do
    L.CITIES[z] = true
  end

  -- where you are: "city" | "instance" | "world"
  function L.Place()
    local inside, kind = IsInInstance()
    if inside and (kind == "party" or kind == "raid") then return "instance" end
    if L.CITIES[GetRealZoneText() or ""] then return "city" end
    return "world"
  end

  local function Enemy(on)
    if on then _G.NAMEPLATES_ON = true ShowNameplates() else _G.NAMEPLATES_ON = nil HideNameplates() end
  end
  local function Friend(on)
    if on then _G.FRIENDNAMEPLATES_ON = true ShowFriendNameplates() else _G.FRIENDNAMEPLATES_ON = nil HideFriendNameplates() end
  end

  -- applies the auto settings for now; fighting: you are in combat
  function L.Auto(fighting)
    if S.enable ~= "1" then return end
    local want = S["autofriend_" .. L.Place()]
    if want == "show" then Friend(true) elseif want == "hide" then Friend(false) end
    local enemy = fighting and S.autoenemy_combat or S.autoenemy_ooc
    if enemy == "show" then Enemy(true) elseif enemy == "hide" then Enemy(false) end
  end

  local auto = CreateFrame("Frame")
  for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }) do
    auto:RegisterEvent(e)
  end
  auto:SetScript("OnEvent", function()
    if event == "PLAYER_REGEN_DISABLED" then L.Auto(true)
    elseif event == "PLAYER_REGEN_ENABLED" then L.Auto(false)
    else L.Auto(UnitAffectingCombat("player")) end
  end)

  L.Read()
end)

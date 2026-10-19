pfUI:RegisterModule("meters-threat", "vanilla", function ()
  -- pfUI Octo threat meter data. The numbers come from the server, asked
  -- the way the TWThreat addon asks (written fresh here: TWThreat has no
  -- licence): every 0.5 s, while you are in a group and your target is a
  -- mob in combat, SendAddonMessage("TWT_UDTSv4", "limit=N", RAID|PARTY).
  -- The answer is CHAT_MSG_ADDON with "TWTv4=Name:tank:threat:perc:melee;..."
  -- (a tank-mode tail after "#" is skipped). perc is the % of the tank's
  -- threat; the server moves the mob at 110 % in melee range, 130 % at range.
  -- When anyone (TWThreat, OctoBG) got an answer in the last 0.45 s, we do
  -- not ask again. Unverified on this server: after GIVE_UP unanswered asks
  -- the window says so and asking stops until the next zone change.
  if C.meters.enable ~= "1" or C.meters.threat ~= "1" then return end
  if not pfUI.meters then return end

  local M = pfUI.meters
  local TH = { list = nil, at = 0, silent = 0, answers = 0, gaveUp = nil, warned = nil }
  M.threat = TH
  local GIVE_UP = 20

  -- "TWTv4=Name:tank:threat:perc:melee;..." -> sorted list or nil
  function TH.Parse(msg)
    if type(msg) ~= "string" then return end
    local _, e = string.find(msg, "TWTv4=", 1, true)
    if not e then return end
    local body = string.sub(msg, e + 1)
    local cut = string.find(body, "#", 1, true)
    if cut then body = string.sub(body, 1, cut - 1) end
    local out = {}
    for name, tank, threat, perc, melee in string.gfind(body, "([^:;]+):(%d+):(%-?%d+):([%-%d%.]+):(%d+)") do
      table.insert(out, { name = name, tank = (tank == "1"), threat = tonumber(threat) or 0,
                          perc = tonumber(perc) or 0, melee = (melee == "1") })
    end
    if table.getn(out) == 0 then return end
    table.sort(out, function(a, b) return a.threat > b.threat end)
    return out
  end

  local function InGroup() return GetNumRaidMembers() > 0 or GetNumPartyMembers() > 0 end

  -- in a group, the target a mob you can attack, in combat
  function TH.Wanted()
    if not InGroup() then return false end
    if not UnitExists("target") or UnitIsPlayer("target") or not UnitCanAttack("player", "target") then return false end
    return UnitAffectingCombat("target") and true or false
  end

  function TH.Ask()
    if not TH.Wanted() or TH.gaveUp then return end
    if GetTime() - TH.at < .45 then return end
    if pcall(SendAddonMessage, "TWT_UDTSv4", "limit=10", GetNumRaidMembers() > 0 and "RAID" or "PARTY") then
      TH.silent = TH.silent + 1
      if TH.silent >= GIVE_UP and TH.answers == 0 then TH.gaveUp = true end
    end
  end

  -- what the window shows when there are no numbers
  function TH.Status()
    if TH.gaveUp then return T["No threat data from this server"] end
    if not InGroup() then return T["Threat shows in a group"] end
    if not TH.Wanted() then return T["Target a mob in combat"] end
    if TH.answers == 0 then return T["Asking the server..."] end
  end

  -- your share of the pull point: 1.0 = you pull aggro
  function TH.Mine()
    if not TH.list then return end
    local me = UnitName("player")
    for _, e in ipairs(TH.list) do
      if e.name == me then
        if e.tank then return nil, e end
        local pull = e.melee and 110 or 130
        return e.perc / pull, e
      end
    end
  end

  local f = CreateFrame("Frame", "pfMetersThreat", UIParent)
  f:RegisterEvent("CHAT_MSG_ADDON")
  f:RegisterEvent("PLAYER_TARGET_CHANGED")
  f:RegisterEvent("PLAYER_REGEN_ENABLED")
  f:RegisterEvent("ZONE_CHANGED_NEW_AREA")
  f:SetScript("OnEvent", function()
    if event == "CHAT_MSG_ADDON" then
      if type(arg2) ~= "string" or not string.find(arg2, "TWTv4=", 1, true) then return end
      local list = TH.Parse(arg2)
      if not list then return end
      TH.list, TH.at, TH.silent, TH.answers = list, GetTime(), 0, TH.answers + 1
      TH.Warn()
      M.Changed()
    elseif event == "ZONE_CHANGED_NEW_AREA" then
      TH.gaveUp, TH.silent, TH.answers = nil, 0, 0
    else
      TH.list, TH.warned = nil, nil
      M.Changed()
    end
  end)

  f:SetScript("OnUpdate", function()
    if (this.tick or 0) > GetTime() then return end
    this.tick = GetTime() + .5
    TH.Ask()
    -- answers older than 3 s are stale
    if TH.list and GetTime() - TH.at > 3 then
      TH.list = nil
      M.Changed()
    end
  end)

  -- one warning when you pass C.meters.threatwarn % of the pull point
  function TH.Warn()
    local share = TH.Mine()
    local limit = (tonumber(C.meters.threatwarn) or 90) / 100
    if not share or share < limit then
      if share and share < limit - .1 then TH.warned = nil end
      return
    end
    if TH.warned then return end
    TH.warned = true
    if C.meters.threatsound == "1" then PlaySound("RaidWarning") end
    if C.meters.threatflash == "1" then
      UIErrorsFrame:AddMessage(string.format(T["Threat %d%% - slow down!"], floor(share * 100)), 1, .3, .2, 1, 2)
    end
  end
end)

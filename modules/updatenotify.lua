pfUI:RegisterModule("updatenotify", "vanilla:tbc", function ()
  local alreadyshown = false
  local localversion  = tonumber(pfUI.version.major*10000 + pfUI.version.minor*100 + pfUI.version.fix)
  local remoteversion = tonumber(pfUI_init.updateavailable) or 0
  local loginchannels = { "BATTLEGROUND", "RAID", "GUILD" }
  local groupchannels = { "BATTLEGROUND", "RAID" }

  -- octo (29 Oct 2026, user: the About screen "should also show if there is a
  -- new update of this fork"): pfUI Octo users tell each other their
  -- X-Octo-Version on the same channels (prefix "pfUIOcto", "V:1.2.3"); a
  -- higher one is kept in pfUI_init.octoupdate for the About page and its
  -- flashing NEW mark. pfUI's own "VERSION" message stays 5.5.4.
  local OCTO_PREFIX = "pfUIOcto"
  local function OctoNum(v)
    local _, _, a, b, c = string.find(tostring(v or ""), "^(%d+)%.?(%d*)%.?(%d*)")
    if not a then return 0 end
    return tonumber(a) * 1000000 + (tonumber(b) or 0) * 1000 + (tonumber(c) or 0)
  end
  pfUI.octoUpdate = {
    url = "https://github.com/bdot89/pfUI-Octo",
    Num = OctoNum,
    -- the newer version seen, or nil
    Newer = function()
      local seen = pfUI_init and pfUI_init.octoupdate
      if seen and OctoNum(seen) > OctoNum(pfUI.version.octo) then return seen end
    end,
  }
  local function OctoSend(chans)
    for _, chan in pairs(chans) do
      pcall(SendAddonMessage, OCTO_PREFIX, "V:" .. tostring(pfUI.version.octo), chan)
    end
  end

  pfUI.updater = CreateFrame("Frame")
  pfUI.updater:RegisterEvent("CHAT_MSG_ADDON")
  pfUI.updater:RegisterEvent("PLAYER_ENTERING_WORLD")
  pfUI.updater:RegisterEvent("PARTY_MEMBERS_CHANGED")
  pfUI.updater:SetScript("OnEvent", function()
    if event == "CHAT_MSG_ADDON" and arg1 == OCTO_PREFIX then
      local _, _, v = string.find(arg2 or "", "^V:(.+)$")
      if v and OctoNum(v) > OctoNum(pfUI.version.octo) and OctoNum(v) > OctoNum(pfUI_init.octoupdate) then
        pfUI_init.octoupdate = v
      end
      return
    end

    if event == "PARTY_MEMBERS_CHANGED" then
      local size = GetNumRaidMembers() > 0 and GetNumRaidMembers() or GetNumPartyMembers()
      if (this.octogroup or 0) < size then OctoSend(groupchannels) end
      this.octogroup = size
    end

    if event == "PLAYER_ENTERING_WORLD" then
      OctoSend(loginchannels)
      local newer = pfUI.octoUpdate.Newer()
      if newer and not this.octoshown then
        this.octoshown = true
        DEFAULT_CHAT_FRAME:AddMessage("|cff33b3ffpfUI Octo|r: " .. string.format(T["version %s is out (you have %s)."], newer, pfUI.version.octo)
          .. " " .. T["Open /pfui > About to copy the link for the OctoWoW launcher."])
      end
    end

    if event == "CHAT_MSG_ADDON" and arg1 == "pfUI" then
      local v, remoteversion = pfUI.api.strsplit(":", arg2)
      local remoteversion = tonumber(remoteversion)
      if v == "VERSION" and remoteversion then
        if remoteversion > localversion then
          pfUI_init.updateavailable = remoteversion
        end
      end
    end

    if event == "PARTY_MEMBERS_CHANGED" then
      local groupsize = GetNumRaidMembers() > 0 and GetNumRaidMembers() or GetNumPartyMembers() > 0 and GetNumPartyMembers() or 0
      if ( this.group or 0 ) < groupsize then
        for _, chan in pairs(groupchannels) do
          SendAddonMessage("pfUI", "VERSION:" .. localversion, chan)
        end
      end
      this.group = groupsize
    end

    if event == "PLAYER_ENTERING_WORLD" then
      if not alreadyshown and localversion < remoteversion then
        DEFAULT_CHAT_FRAME:AddMessage(T["|cff33ffccpf|rUI: New version available! Have a look at http://shagu.org !"])
        DEFAULT_CHAT_FRAME:AddMessage(T["|cffddddddIt's always safe to upgrade |cff33ffccpf|rUI. |cffddddddYou won't lose any of your configuration."])
        pfUI_init.updateavailable = localversion
        alreadyshown = true
      end

      for _, chan in pairs(loginchannels) do
        SendAddonMessage("pfUI", "VERSION:" .. localversion, chan)
      end
    end
  end)
end)

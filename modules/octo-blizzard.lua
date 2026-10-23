pfUI:RegisterModule("octo-blizzard", "vanilla", function ()
  -- pfUI Octo :: one switch per section between pfUI Octo's version and
  -- Blizzard's own, live, no reload (user, 23 Oct 2026: "turning on will put
  -- on the addons version of this turning off will put it back to your
  -- blizzard setup ... one press toggle on and off no reloads").
  -- This module loads FIRST (top of init\modules.xml): it notes how
  -- Blizzard's frames and functions are set up before pfUI's modules hide
  -- or replace them. A section switched to Blizzard puts those back and
  -- re-runs each frame's own setup (its FrameXML OnLoad: the events it
  -- listens to, read from the client's patch-4 FrameXML); pfUI's frames go
  -- under a hidden parent. Switching back undoes that the way pfUI's
  -- modules do it. Settings: C.blizz[id] = "1" -> Blizzard's.
  -- Sections: unit frames, cast bar, action bars, minimap, buffs,
  -- nameplates, bags, loot, combat text, meters.
  local BZ = { snap = {}, globals = {}, state = {} }
  pfUI.blizz = BZ
  C.blizz = C.blizz or {}

  local hider = CreateFrame("Frame", "pfOctoBlizzHider", UIParent)
  hider:Hide()
  BZ.hider = hider

  -- ---------------------------------------------------------------- snapshot (before pfUI)

  local function Snap(f)
    if not f or BZ.snap[f] then return end
    -- (textures such as MinimapBorderTop have no GetScale on 1.12: in game that
    -- stopped this module before BZ.GROUPS, and every options page errored)
    local s = { parent = f.GetParent and f:GetParent(), scale = f.GetScale and f:GetScale(), alpha = f:GetAlpha(),
                shown = f:IsShown(), w = f:GetWidth(), h = f:GetHeight(), points = {} }
    for i = 1, (f.GetNumPoints and f:GetNumPoints() or 0) do s.points[i] = { f:GetPoint(i) } end
    if f.GetScript then
      for _, sc in ipairs({ "OnShow", "OnEvent", "OnMouseWheel" }) do
        local ok, fn = pcall(f.GetScript, f, sc)
        if ok then s[sc] = fn or false end
      end
    end
    BZ.snap[f] = s
  end
  BZ.Snap = Snap

  local FRAMES = { "PlayerFrame", "TargetFrame", "PartyMemberFrame1", "PartyMemberFrame2", "PartyMemberFrame3",
    "PartyMemberFrame4", "CastingBarFrame", "BuffFrame", "TemporaryEnchantFrame", "ComboFrame", "MainMenuBar",
    "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarLeft", "MultiBarRight", "Minimap", "MiniMapMailFrame",
    "MiniMapBattlefieldFrame", "MiniMapTrackingFrame", "GameTimeFrame", "MinimapZoomIn", "MinimapZoomOut",
    "MinimapZoneTextButton", "MinimapBorderTop", "MiniMapWorldMapButton", "MinimapToggleButton", "LootFrame",
    "MiniMapMailBorder", "MiniMapBattlefieldBorder" }
  for _, n in ipairs(FRAMES) do Snap(_G[n]) end
  for _, n in ipairs(MICRO_BUTTONS or {}) do Snap(_G[n]) end
  BZ.borderTex = MinimapBorder and MinimapBorder:GetTexture()
  BZ.mailTex = MiniMapMailIcon and MiniMapMailIcon:GetTexture()
  BZ.multi = { SHOW_MULTI_ACTIONBAR_1, SHOW_MULTI_ACTIONBAR_2, SHOW_MULTI_ACTIONBAR_3, SHOW_MULTI_ACTIONBAR_4 }

  -- functions pfUI replaces: Blizzard's now, pfUI's once every module ran
  local GLOBALS = { bags = { "OpenAllBags", "CloseAllBags", "ToggleBackpack", "ToggleBag" },
    loot = { "GroupLootDropDown_GiveLoot" } }
  for _, list in pairs(GLOBALS) do
    for _, n in ipairs(list) do BZ.globals[n] = { blizz = _G[n] } end
  end

  -- ---------------------------------------------------------------- helpers

  -- run a FrameXML function with `this` set (the game's own global)
  local function Call(fn, frame, a1)
    if type(fn) ~= "function" then return end
    local old, olda = _G.this, _G.arg1
    _G.this, _G.arg1 = frame, a1
    pcall(fn, a1)
    _G.this, _G.arg1 = old, olda
  end

  -- a Blizzard frame as it was: parent, place, size, scale, scripts, Show
  local function Restore(f, show)
    if not f then return end
    local s = BZ.snap[f]
    f.Show = nil
    if s then
      if s.parent and f.SetParent then f:SetParent(s.parent) end
      if s.points[1] then
        f:ClearAllPoints()
        for _, p in ipairs(s.points) do
          if p[1] then f:SetPoint(p[1], p[2], p[3], p[4], p[5]) end
        end
      end
      if f.SetScale then f:SetScale(s.scale or 1) end
      f:SetAlpha(s.alpha or 1)
      if s.OnShow ~= nil then f:SetScript("OnShow", s.OnShow or nil) end
    end
    if show == true or (show == nil and s and s.shown) then f:Show() end
  end
  BZ.Restore = Restore

  -- pfUI's way: hidden, deaf, and (killshow) unable to show itself
  local function Kill(f, killshow)
    if not f then return end
    if f.UnregisterAllEvents then f:UnregisterAllEvents() end
    f:Hide()
    if killshow then f.Show = function() return end end
  end
  BZ.Kill = Kill

  -- pfUI's frames out of sight (a hidden parent) and back
  local function Away(f)
    if not f or f.octoAway then return end
    f.octoAway = f:GetParent() or UIParent
    f:SetParent(hider)
  end
  local function Back(f)
    if not f or not f.octoAway then return end
    f:SetParent(f.octoAway)
    f.octoAway = nil
  end
  BZ.Away, BZ.Back = Away, Back

  local function Reg(f, events)
    if not f then return end
    for _, e in ipairs(events) do f:RegisterEvent(e) end
  end

  -- ---------------------------------------------------------------- sections

  local S = {}
  BZ.S = S

  -- unit frames: player (with its pet), target, party, combo points
  S.unitframes = {
    label = "Unit frames",
    blizz = function()
      for _, f in ipairs(pfUI.uf and pfUI.uf.frames or {}) do
        if not f.octoPreview then Away(f) end
      end
      if pfUI.combopoints then for _, c in pairs(pfUI.combopoints) do if type(c) == "table" and c.SetParent then Away(c) end end end
      Restore(PlayerFrame, true)
      Call(PlayerFrame_OnLoad, PlayerFrame)
      Restore(TargetFrame, false)
      Call(TargetFrame_OnLoad, TargetFrame)
      Call(TargetFrame_Update, TargetFrame)
      for i = 1, 4 do
        local f = _G["PartyMemberFrame" .. i]
        if f then
          Restore(f, false)
          Call(PartyMemberFrame_OnLoad, f)
          Call(PartyMemberFrame_UpdateMember, f)
        end
      end
      if ComboFrame then
        Restore(ComboFrame, false)
        Reg(ComboFrame, { "PLAYER_TARGET_CHANGED", "PLAYER_COMBO_POINTS" })
        if ComboFrame_Update then pcall(ComboFrame_Update) end
      end
    end,
    octo = function()
      Kill(PlayerFrame)
      Kill(TargetFrame)
      for i = 1, 4 do Kill(_G["PartyMemberFrame" .. i], true) end
      Kill(ComboFrame)
      for _, f in ipairs(pfUI.uf and pfUI.uf.frames or {}) do Back(f) end
      if pfUI.combopoints then for _, c in pairs(pfUI.combopoints) do if type(c) == "table" and c.SetParent then Back(c) end end end
      if pfUI.uf then
        for _, f in ipairs(pfUI.uf.frames or {}) do
          if f.UpdateConfig and not f.octoPreview then pcall(f.UpdateConfig, f) end
        end
      end
    end,
  }

  S.castbar = {
    label = "Cast bar",
    blizz = function()
      if pfUI.castbar then for _, k in ipairs({ "player", "target", "focus" }) do Away(pfUI.castbar[k]) end end
      Restore(CastingBarFrame, false)
      Call(CastingBarFrame_OnLoad, CastingBarFrame)
    end,
    octo = function()
      if CastingBarFrame then
        CastingBarFrame:SetScript("OnShow", function() CastingBarFrame:Hide() end)
        Kill(CastingBarFrame)
      end
      if pfUI.castbar then for _, k in ipairs({ "player", "target", "focus" }) do Back(pfUI.castbar[k]) end end
    end,
  }

  S.buffs = {
    label = "Buffs",
    blizz = function()
      if pfUI.buff then for _, k in ipairs({ "buffs", "debuffs", "wepbuffs" }) do Away(pfUI.buff[k]) end end
      Restore(BuffFrame, true)
      Call(BuffFrame_OnLoad, BuffFrame)
      Restore(TemporaryEnchantFrame, true)
    end,
    octo = function()
      Kill(BuffFrame)
      Kill(TemporaryEnchantFrame)
      if pfUI.buff then for _, k in ipairs({ "buffs", "debuffs", "wepbuffs" }) do Back(pfUI.buff[k]) end end
    end,
  }

  -- the main bar, the four extra bars and the micro buttons
  local function PfBars()
    local out = {}
    for _, n in ipairs({ "pfActionBar", "pfActionBarPageSwitch" }) do if _G[n] then table.insert(out, _G[n]) end end
    for _, n in ipairs({ "Main", "Top", "Left", "Right", "Vertical", "Paging", "Stances", "Pet",
                          "StanceBar1", "StanceBar2", "StanceBar3", "StanceBar4" }) do
      if _G["pfActionBar" .. n] then table.insert(out, _G["pfActionBar" .. n]) end
    end
    return out
  end
  S.actionbars = {
    label = "Action bars",
    blizz = function()
      for _, f in ipairs(PfBars()) do Away(f) end
      if pfUI.panel and pfUI.panel.microbutton then Away(pfUI.panel.microbutton) end
      Restore(MainMenuBar, true)
      for i, n in ipairs({ "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarRight", "MultiBarLeft" }) do
        Restore(_G[n], false)
      end
      local m = BZ.multi
      SHOW_MULTI_ACTIONBAR_1, SHOW_MULTI_ACTIONBAR_2, SHOW_MULTI_ACTIONBAR_3, SHOW_MULTI_ACTIONBAR_4 = m[1], m[2], m[3], m[4]
      if SetActionBarToggles then SetActionBarToggles(m[1], m[2], m[3], m[4]) end
      if MultiActionBar_Update then pcall(MultiActionBar_Update) end
      for _, n in ipairs(MICRO_BUTTONS or {}) do
        local b = _G[n]
        if b then
          Restore(b, true)
          if b.frame then b.frame:Hide() end
        end
      end
      if UpdateMicroButtons then pcall(UpdateMicroButtons) end
    end,
    octo = function()
      Kill(MainMenuBar)
      for _, n in ipairs({ "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarLeft", "MultiBarRight" }) do Kill(_G[n], true) end
      if SetActionBarToggles then SetActionBarToggles(0, 0, 0, 0) end
      SHOW_MULTI_ACTIONBAR_1, SHOW_MULTI_ACTIONBAR_2, SHOW_MULTI_ACTIONBAR_3, SHOW_MULTI_ACTIONBAR_4 = nil, nil, nil, nil
      for _, f in ipairs(PfBars()) do Back(f) end
      local mb = pfUI.panel and pfUI.panel.microbutton
      if mb then
        Back(mb)
        for i = 1, table.getn(MICRO_BUTTONS or {}) do
          local button = _G[MICRO_BUTTONS[i]]
          local anchor = _G[MICRO_BUTTONS[i - 1]] or mb
          if button then
            button:ClearAllPoints()
            button:SetParent(mb)
            if i == 1 then button:SetPoint("LEFT", mb, "LEFT", 1, 10) else button:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 1, 0) end
            button:SetScale(.6)
            if button.frame then button.frame:Show() end
            button:Show()
          end
        end
      end
      if pfUI.bars and pfUI.bars.UpdateConfig then pcall(pfUI.bars.UpdateConfig, pfUI.bars) end
    end,
  }

  -- the minimap: back in Blizzard's cluster with its border, zoom, clock
  -- and buttons; the addon buttons go back round it
  S.minimap = {
    label = "Minimap",
    blizz = function()
      local m = pfUI.minimap
      if pfUI.addonbuttons and pfUI.addonbuttons.RestoreAll then pcall(pfUI.addonbuttons.RestoreAll, pfUI.addonbuttons) end
      Restore(Minimap, true)
      -- (never left inside pfUI's map, which is hidden next)
      if Minimap:GetParent() == m then
        Minimap:SetParent(MinimapCluster or UIParent)
        if not (BZ.snap[Minimap] and BZ.snap[Minimap].points[1]) then
          Minimap:ClearAllPoints()
          Minimap:SetPoint("CENTER", MinimapCluster or UIParent, "TOP", 9, -92)
        end
      end
      local s = BZ.snap[Minimap]
      if s and s.w and s.w > 0 then Minimap:SetWidth(s.w) Minimap:SetHeight(s.h) end
      Minimap:SetFrameLevel((MinimapCluster and MinimapCluster:GetFrameLevel() or 1) + 1)
      Minimap:SetMaskTexture("Textures\\MinimapMask")
      if s and s.OnMouseWheel ~= nil then Minimap:SetScript("OnMouseWheel", s.OnMouseWheel or nil) end
      if MinimapBorder then
        MinimapBorder:SetTexture(BZ.borderTex or "Interface\\Minimap\\UI-Minimap-Border")
        MinimapBorder:SetTexCoord(.25, 1, .125, .875)
      end
      for _, n in ipairs({ "MinimapBorderTop", "MinimapZoneTextButton", "MinimapZoomIn", "MinimapZoomOut", "GameTimeFrame",
                           "MiniMapWorldMapButton", "MinimapToggleButton", "MiniMapMailBorder", "MiniMapBattlefieldBorder" }) do
        Restore(_G[n], true)
      end
      Restore(MiniMapMailFrame, false)
      if MiniMapMailIcon and BZ.mailTex then MiniMapMailIcon:SetTexture(BZ.mailTex) end
      if MiniMapMailFrame then
        Reg(MiniMapMailFrame, { "UPDATE_PENDING_MAIL" })
        if HasNewMail and HasNewMail() then MiniMapMailFrame:Show() else MiniMapMailFrame:Hide() end
      end
      Restore(MiniMapBattlefieldFrame, false)
      if MiniMapTrackingFrame then
        Restore(MiniMapTrackingFrame, false)
        Reg(MiniMapTrackingFrame, { "PLAYER_AURAS_CHANGED" })
        if GetTrackingTexture and GetTrackingTexture() and MiniMapTrackingIcon then
          MiniMapTrackingIcon:SetTexture(GetTrackingTexture())
          MiniMapTrackingFrame:Show()
        end
      end
      if MinimapCluster then MinimapCluster:Show() end
      if Minimap_Update then pcall(Minimap_Update) end
      for _, f in ipairs({ m, pfUI.tracking, pfUI.panel and pfUI.panel.minimap, pfUI.addonbuttons }) do Away(f) end
    end,
    octo = function()
      local m = pfUI.minimap
      if not m then return end
      for _, f in ipairs({ m, pfUI.tracking, pfUI.panel and pfUI.panel.minimap, pfUI.addonbuttons }) do Back(f) end
      for _, n in ipairs({ "MinimapBorderTop", "MinimapZoneTextButton", "MinimapZoomIn", "MinimapZoomOut", "GameTimeFrame",
                           "MiniMapWorldMapButton", "MinimapToggleButton", "MiniMapMailBorder", "MiniMapBattlefieldBorder" }) do
        if _G[n] then _G[n]:Hide() end
      end
      if MiniMapTrackingFrame then Kill(MiniMapTrackingFrame) end
      if MinimapBorder then MinimapBorder:SetTexture(nil) end
      Minimap:SetParent(m)
      Minimap:ClearAllPoints()
      Minimap:SetPoint("CENTER", m, "CENTER", .5, -.5)
      Minimap:SetFrameLevel(1)
      Minimap:EnableMouseWheel(true)
      Minimap:SetScript("OnMouseWheel", function() if arg1 > 0 then Minimap_ZoomIn() else Minimap_ZoomOut() end end)
      if MiniMapMailFrame then
        MiniMapMailFrame:SetParent(MinimapBackdrop or Minimap)
        MiniMapMailFrame:ClearAllPoints()
        MiniMapMailFrame:SetPoint("TOPRIGHT", m, "TOPRIGHT", 0, 0)
        if MiniMapMailIcon then MiniMapMailIcon:SetTexture(pfUI.media["img:mail"]) end
      end
      if MiniMapBattlefieldFrame then
        MiniMapBattlefieldFrame:ClearAllPoints()
        MiniMapBattlefieldFrame:SetPoint("BOTTOMRIGHT", Minimap, 4, -4)
      end
      if m.UpdateConfig then pcall(m.UpdateConfig, m) end
      if pfUI.addonbuttons and pfUI.addonbuttons.ProcessButtons then pcall(pfUI.addonbuttons.ProcessButtons, pfUI.addonbuttons) end
    end,
  }

  -- nameplates: the game's own plate parts back, pfUI's drawing hidden
  -- (each plate's parts are noted before pfUI blanks them, see Wrap below)
  local function PlateParts(plate)
    local o = plate.octoBlizz
    if not o then return end
    for _, e in ipairs(o) do
      local obj = e.obj
      if e.kind == "Texture" then
        obj:SetTexture(e.tex)
        if e.tc then obj:SetTexCoord(e.tc[1], e.tc[2], e.tc[3], e.tc[4], e.tc[5], e.tc[6], e.tc[7], e.tc[8]) end
      elseif e.kind == "FontString" then
        if e.w then obj:SetWidth(e.w) end
      elseif e.kind == "StatusBar" then
        obj:SetStatusBarTexture(e.tex or "Interface\\TargetingFrame\\UI-TargetingFrame-BarFill")
      end
    end
  end
  local function Blank(obj)
    local t = obj.GetObjectType and obj:GetObjectType()
    if t == "Texture" then obj:SetTexture("") obj:SetTexCoord(0, 0, 0, 0)
    elseif t == "FontString" then obj:SetWidth(.001)
    elseif t == "StatusBar" then obj:SetStatusBarTexture("") end
  end
  local function Plates()
    local out = {}
    for _, f in ipairs({ WorldFrame:GetChildren() }) do if f.nameplate and f.octoBlizz then table.insert(out, f) end end
    return out
  end
  S.nameplates = {
    label = "Nameplates",
    blizz = function()
      for _, plate in ipairs(Plates()) do
        PlateParts(plate)
        Away(plate.nameplate)
      end
    end,
    octo = function()
      for _, plate in ipairs(Plates()) do
        for _, e in ipairs(plate.octoBlizz) do if not e.keep then Blank(e.obj) end end
        Back(plate.nameplate)
      end
    end,
  }
  -- note a plate's parts before pfUI blanks them, and keep new plates in
  -- the look picked
  local function WrapPlates()
    local NP = pfUI.nameplates
    if not NP or NP.octoBlizzWrapped or not NP.OnCreate then return end
    NP.octoBlizzWrapped = true
    local create = NP.OnCreate
    NP.OnCreate = function(frame)
      local parent = frame or _G.this
      if parent and not parent.octoBlizz then
        local list = {}
        local bars = { parent:GetChildren() }
        for i = 1, 2 do
          local b = bars[i]
          if b and b.GetStatusBarTexture then
            local tx = b:GetStatusBarTexture()
            table.insert(list, { obj = b, kind = "StatusBar", tex = tx and tx.GetTexture and tx:GetTexture() })
          end
        end
        for i, r in ipairs({ parent:GetRegions() }) do
          local kind = r.GetObjectType and r:GetObjectType()
          local keep = NAMEPLATE_OBJECTORDER and NAMEPLATE_OBJECTORDER[i] == "raidicon"
          if kind == "Texture" then
            table.insert(list, { obj = r, kind = kind, tex = r:GetTexture(), tc = { r:GetTexCoord() }, keep = keep })
          elseif kind == "FontString" then
            table.insert(list, { obj = r, kind = kind, w = r:GetWidth() })
          end
        end
        parent.octoBlizz = list
      end
      local out = create(frame)
      if C.blizz.nameplates == "1" and parent then
        PlateParts(parent)
        if parent.nameplate then Away(parent.nameplate) end
      end
      return out
    end
  end
  BZ.WrapPlates = WrapPlates

  S.bags = {
    label = "Bags",
    blizz = function()
      if CloseAllBags then pcall(CloseAllBags) end
      for _, n in ipairs(GLOBALS.bags) do
        local g = BZ.globals[n]
        if g.blizz then _G[n] = g.blizz end
      end
      if pfUI.bag then Away(pfUI.bag.right) Away(pfUI.bag.left) end
    end,
    octo = function()
      for i = 1, (NUM_CONTAINER_FRAMES or 12) do
        local cf = _G["ContainerFrame" .. i]
        if cf and cf:IsShown() then cf:Hide() end
      end
      for _, n in ipairs(GLOBALS.bags) do
        local g = BZ.globals[n]
        if g.octo then _G[n] = g.octo end
      end
      if pfUI.bag then Back(pfUI.bag.right) Back(pfUI.bag.left) end
    end,
  }

  S.loot = {
    label = "Loot",
    blizz = function()
      if pfUI.loot then
        pfUI.loot.octoEvent = pfUI.loot.octoEvent or pfUI.loot:GetScript("OnEvent")
        pfUI.loot:SetScript("OnEvent", nil)
        pfUI.loot:Hide()
      end
      for _, n in ipairs(GLOBALS.loot) do
        local g = BZ.globals[n]
        if g.blizz then _G[n] = g.blizz end
      end
      Restore(LootFrame, false)
      Call(LootFrame_OnLoad, LootFrame)
    end,
    octo = function()
      if LootFrame then LootFrame:UnregisterAllEvents() LootFrame:Hide() end
      for _, n in ipairs(GLOBALS.loot) do
        local g = BZ.globals[n]
        if g.octo then _G[n] = g.octo end
      end
      if pfUI.loot and pfUI.loot.octoEvent then pfUI.loot:SetScript("OnEvent", pfUI.loot.octoEvent) end
    end,
  }

  S.combattext = {
    label = "Combat text",
    blizz = function()
      local CT = pfUI.sct and pfUI.sct.CT
      if CT and CT.SetEnabled then pcall(CT.SetEnabled, CT, false) end
    end,
    octo = function()
      local CT = pfUI.sct and pfUI.sct.CT
      if CT and CT.SetEnabled then pcall(CT.SetEnabled, CT, true) end
    end,
  }

  -- (the game has no meters: off hides the windows)
  S.meters = {
    label = "Meters",
    blizz = function()
      local M = pfUI.meters
      for _, w in ipairs(M and M.windows or {}) do Away(w) end
    end,
    octo = function()
      local M = pfUI.meters
      for _, w in ipairs(M and M.windows or {}) do Back(w) end
    end,
  }

  -- which sections each topic of the options window has
  BZ.GROUPS = {
    ["Unit Frames"] = { "unitframes", "castbar" }, ["Action Bars"] = { "actionbars" }, ["Nameplates"] = { "nameplates" },
    ["Combat Text"] = { "combattext" }, ["Meters"] = { "meters" }, ["Minimap & Buffs"] = { "minimap", "buffs" },
    ["Bags & Loot"] = { "bags", "loot" },
  }

  -- ---------------------------------------------------------------- switching

  function BZ.IsBlizz(id) return C.blizz[id] == "1" end

  -- id's look: "blizz" (Blizzard's) or "octo" (pfUI Octo's)
  function BZ.Set(id, which)
    local s = S[id]
    if not s then return end
    if InCombatLockdown and InCombatLockdown() then return end
    C.blizz[id] = (which == "blizz") and "1" or "0"
    local ok, err = pcall(s[which == "blizz" and "blizz" or "octo"])
    BZ.state[id] = which
    if not ok then DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffpfUI Octo|r: " .. s.label .. ": " .. tostring(err)) end
    return ok
  end
  function BZ.Toggle(id) return BZ.Set(id, BZ.IsBlizz(id) and "octo" or "blizz") end

  -- after every module ran: pfUI's functions noted, saved choices applied
  function BZ.Ready()
    if BZ.ready then return end
    BZ.ready = true
    for _, list in pairs(GLOBALS) do
      for _, n in ipairs(list) do BZ.globals[n].octo = _G[n] end
    end
    WrapPlates()
  end
  local boot = CreateFrame("Frame")
  boot:RegisterEvent("PLAYER_ENTERING_WORLD")
  boot:SetScript("OnEvent", function()
    BZ.Ready()
    -- (once the game and pfUI have set everything up for this screen)
    this.wait = GetTime() + .5
    this:SetScript("OnUpdate", function()
      if GetTime() < this.wait then return end
      this:SetScript("OnUpdate", nil)
      for id in pairs(S) do
        if BZ.IsBlizz(id) and BZ.state[id] ~= "blizz" then BZ.Set(id, "blizz") end
      end
    end)
  end)
end)

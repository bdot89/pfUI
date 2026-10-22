pfUI:RegisterModule("actionbar-octo", "vanilla:tbc", function ()
  -- pfUI Octo action bars: Bartender4's ideas on pfUI's own bars (user, 22 Oct
  -- 2026: "rebuilding the Action bar module ... like Bartender, with as many
  -- options and looks"). Bartender4 is All Rights Reserved: nothing of it is
  -- copied, only its feature list was read. pfUI's actionbar.lua builds the
  -- bars as before; after each of its updates this adds:
  --   per bar   scale, opacity, fade to a chosen opacity on mouse-off (pfUI's
  --             autohide hid them fully), visibility rules: in / out of
  --             combat, with / without a pet, only with a target, hidden
  --             while stealthed
  --   buttons   border skins (as the nameplates'), icon zoom
  --   looks     one-click styles (pfUI.barsOcto.PRESETS)
  -- Settings: C.bars["barN"] (scale, alpha, fadeto, vis_*) and C.bars (skin,
  -- zoom, look). Options: Action Bars (actionbar-options.lua).
  if not pfUI.bars then return end
  local BARS = pfUI.bars
  local AB = {}
  pfUI.barsOcto = AB

  AB.NAMES = { [1] = "Main bar", [6] = "Top bar", [5] = "Left bar", [3] = "Right bar", [4] = "Vertical bar",
    [2] = "Paging bar", [7] = "Stance bar 1", [8] = "Stance bar 2", [9] = "Stance bar 3", [10] = "Stance bar 4",
    [11] = "Shapeshift bar", [12] = "Pet bar" }
  -- in the order the options list them
  AB.ORDER = { 1, 6, 5, 3, 4, 2, 7, 8, 9, 10, 11, 12 }

  local function DB(i) return C.bars["bar" .. i] end

  -- ---------------------------------------------------------------- button skins

  local WHITE = "Interface\\Buttons\\WHITE8X8"
  AB.SKINS = {
    { key = "pfui", label = "Thin black (pfUI)" },
    { key = "shadow", label = "Soft shadow", edge = pfUI.media["img:glow2"], size = 6, off = 4, color = { 0, 0, 0, .9 } },
    { key = "thick", label = "Thick black", edge = WHITE, size = 2, off = 2, color = { 0, 0, 0, 1 } },
    { key = "accent", label = "Accent line", edge = WHITE, size = 1, off = 1, color = { 1, 1, 1, 1 }, accent = true },
    { key = "neon", label = "Neon glow (accent)", edge = pfUI.media["img:glow"], size = 6, off = 5, color = { 1, 1, 1, .8 }, accent = true },
    { key = "gold", label = "Gold line", edge = WHITE, size = 1, off = 1, color = { .85, .68, .3, 1 } },
  }
  local SKINBY = {}
  for _, s in ipairs(AB.SKINS) do SKINBY[s.key] = s end

  local function Skin(f)
    local sk = SKINBY[C.bars.skin or "pfui"]
    if not sk or not sk.edge then
      if f.octoSkin then f.octoSkin:Hide() end
      return
    end
    if not f.octoSkin then f.octoSkin = CreateFrame("Frame", nil, f) end
    local s = f.octoSkin
    s:ClearAllPoints()
    s:SetPoint("TOPLEFT", f, "TOPLEFT", -sk.off - 1, sk.off + 1)
    s:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", sk.off + 1, -sk.off - 1)
    s:SetBackdrop({ edgeFile = sk.edge, edgeSize = sk.size, insets = { left = 0, right = 0, top = 0, bottom = 0 } })
    local c = sk.color
    if sk.accent and GetAccentColor then
      local r, g, b = GetAccentColor()
      c = { r, g, b, c[4] }
    end
    s:SetBackdropBorderColor(c[1], c[2], c[3], c[4])
    s:Show()
  end

  local function Zoom(f)
    if not f.icon then return end
    local z = tonumber(C.bars.zoom) or .08
    f.icon:SetTexCoord(z, 1 - z, z, 1 - z)
  end

  AB.Skin, AB.Zoom = Skin, Zoom

  -- ---------------------------------------------------------------- visibility

  -- stealth / prowl by the buff's icon
  local function Stealthed()
    for i = 1, 32 do
      local tex = UnitBuff("player", i)
      if not tex then break end
      if string.find(tex, "Ability_Stealth") or string.find(tex, "Ability_Ambush") then return true end
    end
  end
  AB.Stealthed = Stealthed

  -- should bar i show now, by its rules?
  function AB.Wanted(i)
    local d = DB(i)
    if not d or d.enable ~= "1" then return false end
    local fighting = UnitAffectingCombat("player")
    if d.vis_combat == "combat" and not fighting then return false end
    if d.vis_combat == "nocombat" and fighting then return false end
    local pet = UnitExists("pet")
    if d.vis_pet == "pet" and not pet then return false end
    if d.vis_pet == "nopet" and pet then return false end
    if d.vis_target == "target" and not UnitExists("target") then return false end
    if d.vis_stealth == "hide" and Stealthed() then return false end
    return true
  end

  -- bars 1 - 10 follow their rules (shapeshift and pet bars show and hide
  -- with your forms and pet already)
  function AB.Visibility()
    for i = 1, 10 do
      local bar = BARS[i]
      if bar and DB(i) and DB(i).enable == "1" then
        if AB.Wanted(i) then
          if not bar:IsShown() then bar:Show() end
        elseif bar:IsShown() then
          bar:Hide()
        end
      end
    end
  end

  local ev = CreateFrame("Frame")
  for _, e in ipairs({ "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "UNIT_PET", "PLAYER_TARGET_CHANGED",
                       "PLAYER_AURAS_CHANGED", "UPDATE_SHAPESHIFT_FORMS", "PLAYER_ENTERING_WORLD" }) do
    ev:RegisterEvent(e)
  end
  ev:SetScript("OnEvent", function() AB.Visibility() end)

  -- ---------------------------------------------------------------- apply

  function AB.Apply()
    for i = 1, 12 do
      local bar, d = BARS[i], DB(i)
      if bar and d then
        local scale = tonumber(d.scale) or 1
        if math.abs((bar:GetScale() or 1) - scale) > .001 then bar:SetScale(scale) end
        local alpha = tonumber(d.alpha) or 1
        bar.octoAlpha = alpha
        bar.fadeTo = math.min(alpha, tonumber(d.fadeto) or 0)
        -- (autohide moves the opacity itself; else it is the bar's own)
        if d.autohide ~= "1" then bar:SetAlpha(alpha) end
        for j = 1, 12 do
          local f = bar[j]
          if f then
            Skin(f)
            Zoom(f)
          end
        end
      end
    end
    AB.Visibility()
  end

  -- after every pfUI bar update
  local UpdateConfig = BARS.UpdateConfig
  BARS.UpdateConfig = function(self)
    UpdateConfig(self)
    AB.Apply()
  end

  -- ---------------------------------------------------------------- looks

  -- one-click looks: { key, label, global keys, every bar's keys }
  AB.PRESETS = {
    { "pfui", "pfUI", { skin = "pfui", zoom = ".08" }, { spacing = "1", background = "1", showempty = "1" } },
    { "clean", "Clean", { skin = "shadow", zoom = ".1" }, { spacing = "3", background = "0", showempty = "0" } },
    { "bold", "Bold", { skin = "thick", zoom = ".12" }, { spacing = "4", background = "0", showempty = "1" } },
    { "neon", "Neon", { skin = "neon", zoom = ".1" }, { spacing = "5", background = "0", showempty = "0" } },
    { "classic", "Classic", { skin = "gold", zoom = "0" }, { spacing = "2", background = "1", showempty = "1" } },
    { "minimal", "Minimal", { skin = "accent", zoom = ".15" }, { spacing = "2", background = "0", showempty = "0" } },
  }
  function AB.ApplyPreset(key)
    for _, p in ipairs(AB.PRESETS) do
      if p[1] == key then
        for k, v in pairs(p[3]) do C.bars[k] = v end
        for i = 1, 12 do
          for k, v in pairs(p[4]) do DB(i)[k] = v end
        end
      end
    end
    BARS:UpdateConfig()
  end
  function AB.CurrentLook()
    for _, p in ipairs(AB.PRESETS) do
      local same = true
      for k, v in pairs(p[3]) do if C.bars[k] ~= v then same = false end end
      for i = 1, 12 do
        for k, v in pairs(p[4]) do if DB(i)[k] ~= v then same = false end end
      end
      if same then return p[1], p[2] end
    end
  end

  AB.Apply()
end)

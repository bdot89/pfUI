pfUI:RegisterModule("octo-layouts", "vanilla", function ()
  -- pfUI Octo :: UI layouts (user, 24 Oct 2026: "setup different UIs for
  -- different things. RAID UI, NORMAL UI, PVPUI ... a toggle button on screen
  -- that you can quickly change between UIs, also could have it
  -- automatically change as you enter a BG ... make this optional").
  --
  -- A layout keeps where every frame is (pfUI's C.position: everything layout
  -- mode moves), whether the meters show, and a gear set to put on. What you
  -- arrange while in a layout is kept for it: switching away saves it first.
  -- A layout never used yet starts as a copy of the one you are in.
  -- The button on screen: click = next layout, right-click = pick one.
  -- Automatic: on entering a battleground, arena, raid or dungeon (and back
  -- in the open world) the layout picked for that place goes on.
  local L = {}
  pfUI.layouts = L
  L.NAMES = { "Normal", "Raid", "PvP" }
  L.ICON = { Normal = "Interface\\Icons\\INV_Misc_Map_01", Raid = "Interface\\Icons\\INV_Misc_Head_Dragon_01",
             PvP = "Interface\\Icons\\INV_BannerPVP_02" }

  local function Say(msg) DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffpfUI|r layouts: " .. msg) end
  local function Copy(t)
    if type(t) ~= "table" then return t end
    local o = {}
    for k, v in pairs(t) do o[k] = Copy(v) end
    return o
  end

  local function Store()
    if type(C.layouts) ~= "table" then C.layouts = {} end
    local s = C.layouts
    if type(s.saved) ~= "table" then s.saved = {} end
    if type(s.byzone) ~= "table" then
      s.byzone = { world = "Normal", dungeon = "Normal", raid = "Raid", bg = "PvP", arena = "PvP" }
    end
    s.current = s.current or "Normal"
    if s.auto == nil then s.auto = "0" end
    if s.button == nil then s.button = "1" end
    return s
  end
  L.Store = Store

  -- what the layout you are in looks like now
  local function Snapshot()
    local M = pfUI.meters
    return { pos = Copy(C.position or {}), meters = (C.meters and C.meters.hidden == "1") and "0" or "1",
             gear = Store().saved[Store().current] and Store().saved[Store().current].gear or "" }
  end
  function L.SaveCurrent()
    local s = Store()
    local keep = s.saved[s.current] or {}
    local snap = Snapshot()
    keep.pos, keep.meters = snap.pos, snap.meters
    keep.gear = keep.gear or ""
    s.saved[s.current] = keep
  end

  -- every frame layout mode knows goes where this layout has it
  local function Place()
    for name, frame in pairs(pfUI.movables or {}) do
      local f = frame or _G[name]
      if f then pcall(UpdateMovable, f) end
    end
    -- (meter windows and other frames that place themselves)
    if pfUI.meters and pfUI.meters.windows then
      for _, w in ipairs(pfUI.meters.windows) do
        if w.free and not (C.position and C.position[w:GetName()]) and pfUI.meters.ResetPosition then
          pfUI.meters.ResetPosition(w)
        end
      end
    end
  end

  function L.Switch(name, why)
    local s = Store()
    if not name or name == s.current then return end
    if UnitAffectingCombat("player") then
      -- (frames move fine in combat on 1.12, but a jump mid-fight helps nobody)
      L.pending = name
      Say(name .. " goes on when combat ends.")
      return
    end
    L.SaveCurrent()
    local target = s.saved[name]
    if not target then
      target = Snapshot()
      target.gear = ""
      s.saved[name] = target
    end
    C.position = Copy(target.pos or {})
    pfUI_config.position = C.position
    s.current = name
    Place()
    if pfUI.meters and pfUI.meters.ShowAll then pfUI.meters.ShowAll(target.meters ~= "0") end
    if target.gear and target.gear ~= "" and pfUI.gear and C.gear.sets[target.gear] then pfUI.gear.Equip(target.gear) end
    L.Paint()
    Say(name .. (why and (" (" .. why .. ")") or "") .. ".")
  end

  function L.Next()
    local s = Store()
    local i = 1
    for n, nm in ipairs(L.NAMES) do if nm == s.current then i = n end end
    L.Switch(L.NAMES[math.mod(i, table.getn(L.NAMES)) + 1])
  end

  -- ---------------------------------------------------------------- the button

  local b = CreateFrame("Button", "pfLayoutButton", UIParent)
  b:SetWidth(30)
  b:SetHeight(30)
  b:SetFrameStrata("MEDIUM")
  b:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -300, 40)
  b:SetMovable(true)
  b:SetClampedToScreen(true)
  CreateBackdrop(b, nil, nil, .9)
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetTexCoord(.08, .92, .08, .92)
  b.icon:SetPoint("TOPLEFT", b, "TOPLEFT", 2, -2)
  b.icon:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 2)
  b.label = b:CreateFontString(nil, "OVERLAY")
  b.label:SetFont(pfUI.font_default, 10, "OUTLINE")
  b.label:SetPoint("TOP", b, "BOTTOM", 0, -2)
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  b:RegisterForDrag("LeftButton")
  L.button = b

  local menu
  local function Menu(owner)
    local W = pfUI.octoui and pfUI.octoui.W
    if not W then return end
    if menu then menu:Hide() end
    local opts = { { label = "UI layout", group = true } }
    for _, n in ipairs(L.NAMES) do
      table.insert(opts, { key = n, label = n .. (n == Store().current and "  |cff33ccff(on)|r" or "") })
    end
    table.insert(opts, { key = "_opt", label = "Layout options..." })
    menu = W.Menu(owner, opts, 170, function(k)
      if k == "_opt" then
        local O = pfUI.octoui.Options
        if O and O.Open then O:Open("layouts") end
      else
        L.Switch(k)
      end
    end)
    menu:SetFrameStrata("TOOLTIP")
    menu:Show()
  end

  b:SetScript("OnClick", function()
    if arg1 == "RightButton" then Menu(this) else L.Next() end
  end)
  b:SetScript("OnDragStart", function() if IsShiftKeyDown() then this:StartMoving() this.moving = true end end)
  b:SetScript("OnDragStop", function()
    if this.moving then this:StopMovingOrSizing() this.moving = nil SaveMovable(this) end
  end)
  b:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_TOP")
    GameTooltip:AddLine("UI layout: " .. Store().current)
    GameTooltip:AddLine("Click: next layout (" .. table.concat(L.NAMES, ", ") .. ")", 1, 1, 1)
    GameTooltip:AddLine("Right-click: pick one, or the options", 1, 1, 1)
    GameTooltip:AddLine("Shift + drag: move this button", .7, .7, .7)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)

  function L.Paint()
    local s = Store()
    b.icon:SetTexture(L.ICON[s.current] or L.ICON.Normal)
    b.label:SetText(s.current)
    if s.button == "0" then b:Hide() else b:Show() end
  end
  if UpdateMovable then UpdateMovable(b) end
  L.Paint()

  -- ---------------------------------------------------------------- automatic

  if pfUI.context then
    pfUI.context.listeners.layouts = function(z, old)
      local s = Store()
      if s.auto ~= "1" then return end
      local want = s.byzone[z]
      if want and want ~= "" and want ~= s.current then L.Switch(want, pfUI.context.NAMES[z]) end
    end
  end
  local ev = CreateFrame("Frame")
  ev:RegisterEvent("PLAYER_REGEN_ENABLED")
  ev:SetScript("OnEvent", function()
    if L.pending then
      local n = L.pending
      L.pending = nil
      L.Switch(n)
    end
  end)

  -- /layout [name]
  _G.SLASH_PFLAYOUT1 = "/layout"
  _G.SlashCmdList.PFLAYOUT = function(msg)
    msg = string.gsub(msg or "", "^%s*(.-)%s*$", "%1")
    for _, n in ipairs(L.NAMES) do
      if string.lower(n) == string.lower(msg) then L.Switch(n) return end
    end
    if msg == "" then L.Next() else Say("/layout " .. table.concat(L.NAMES, " | ")) end
  end

  -- ---------------------------------------------------------------- options page

  local OU = pfUI.octoui
  local W = OU and OU.W
  local O = OU and OU.Options
  if not W or not O or not O.AddPage then return end

  local ZONES = { { "world", "Open world" }, { "dungeon", "Dungeons" }, { "raid", "Raids" }, { "bg", "Battlegrounds" }, { "arena", "Arenas" } }
  local function LayoutList()
    local out = { { key = "", label = "- stay as it is -" } }
    for _, n in ipairs(L.NAMES) do table.insert(out, { key = n, label = n }) end
    return out
  end
  local function SetList()
    local out = { { key = "", label = "- none -" } }
    if pfUI.gear then for _, n in ipairs(pfUI.gear.Sets()) do table.insert(out, { key = n, label = n }) end end
    return out
  end

  local function Build(p)
    W.Heading(p, "UI layouts", {
      on = { function() return Store().button ~= "0" end, function(v) Store().button = v and "1" or "0" L.Paint() end,
        "The layout button on your screen." },
      about = "Three layouts - Normal, Raid and PvP - each remembering where every frame is (everything you move in "
        .. "Move frames), whether the meters show, and a gear set. Switch with the button on your screen (click = "
        .. "next, right-click = pick) or /layout. Whatever you arrange while in a layout is kept for it. Turn on "
        .. "Automatic and the layout for a place goes on when you get there." })
    W.Live(p, function() return "Now: |cff33ccff" .. Store().current .. "|r" end)
    W.Card(p, "Switch")
    local list = {}
    for _, n in ipairs(L.NAMES) do
      local nm = n
      table.insert(list, { nm, function() L.Switch(nm) end, 110, "Switch to the " .. nm .. " layout now." })
    end
    W.Buttons(p, list)
    W.Buttons(p, {
      { "Move frames", function() if pfUI.unlock then pfUI.unlock:Show() end end, 120,
        "Arrange this layout: what you move is kept for the layout you are in." },
      { "Copy this layout to the others", function()
        L.SaveCurrent()
        local s = Store()
        for _, n in ipairs(L.NAMES) do
          if n ~= s.current then s.saved[n] = Copy(s.saved[s.current]) s.saved[n].gear = (s.saved[n] and s.saved[n].gear) or "" end
        end
        Say("every layout now has the " .. s.current .. " layout's places.")
      end, 210, "Start the other layouts from this one." },
    })
    W.Card(p, "Automatic", { on = { function() return Store().auto == "1" end, function(v) Store().auto = v and "1" or "0" end,
      "Change the layout by itself when you enter these places." } })
    for _, z in ipairs(ZONES) do
      local zone = z[1]
      W.Dropdown(p, z[2], "The layout that goes on here.", LayoutList,
        function() return Store().byzone[zone] or "" end, function(v) Store().byzone[zone] = v end)
    end
    W.Card(p, "Each layout", { tip = "What else each layout changes." })
    for _, n in ipairs(L.NAMES) do
      local nm = n
      W.Check(p, nm .. ": meters shown", nil, function()
        local t = Store().saved[nm]
        return not t or t.meters ~= "0"
      end, function(v)
        local t = Store().saved[nm] or Snapshot()
        t.meters = v and "1" or "0"
        Store().saved[nm] = t
      end)
      W.Dropdown(p, nm .. ": gear set", "Put on when this layout goes on.", SetList,
        function() local t = Store().saved[nm] return t and t.gear or "" end,
        function(v) local t = Store().saved[nm] or Snapshot() t.gear = v Store().saved[nm] = t end)
    end
  end
  O:AddPage("UI layouts", "layouts", "Layouts", Build)
end)

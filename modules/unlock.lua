pfUI:RegisterModule("unlock", "vanilla:tbc", function ()
  local rawborder, default_border = GetBorderSize()

  -- grouped frames
  local clusters = {
    -- Name            Shift  Ctrl
    { "pfCombo",          5       },
    -- (octo: the raid frames are one box, pfRaidCluster)
    { "pfGroup",          4       },
    { "pfLootRollFrame",  4       },
  }

  local anchors = {
    "TOPLEFT", "TOP", "TOPRIGHT", "RIGHT", "BOTTOMRIGHT", "BOTTOM", "BOTTOMLEFT", "LEFT", "CENTER"
  }


  local spanframe = CreateFrame("Frame", "pfUnlockSelector", UIParent)
  spanframe:Hide()

  -- frame labels and their config section relation
  local frame_configs = {
    -- unitframes
    ["Player"]             = { T["Unit Frames"], T["Player"] },
    ["Target"]             = { T["Unit Frames"], T["Target"] },
    ["TargetTarget"]       = { T["Unit Frames"], T["Target-Target"] },
    ["TargetTargetTarget"] = { T["Unit Frames"], T["Target-Target-Target"] },
    ["Pet"]                = { T["Unit Frames"], T["Pet"] },
    ["PetTarget"]          = { T["Unit Frames"], T["Pet-Target"] },
    ["Focus"]              = { T["Unit Frames"], T["Focus"] },
    ["FocusTarget"]        = { T["Unit Frames"], T["Focus-Target"] },

    -- octo: more boxes with a page of their own
    ["Totems"]             = { T["Buffs"], T["Totem Icons"] },
    ["TooltipAnchor"]      = { T["Tooltip"], nil },
    ["Group%dTarget"]      = { T["Unit Frames"], T["Group-Target"] },
    ["GroupPet%d"]         = { T["Unit Frames"], T["Group-Pet"] },

    -- combopoints
    ["Combo%d"]       = { T["Unit Frames"], T["General"] },

    -- groupframes
    ["Raid%d"]        = { T["Unit Frames"], T["Raid"] },
    ["Raid%d%d"]      = { T["Unit Frames"], T["Raid"] },
    ["RaidCluster"]   = { T["Unit Frames"], T["Raid"] },

    -- octo: meters and combat text (an Octo page key opens that page)
    ["Meter%d"]       = { T["Meters"], nil },
    ["CombatText%a+"] = { "ctareas", nil },
    ["Group%d"]       = { T["Unit Frames"], T["Group"] },
    ["Party%dTarget"] = { T["Unit Frames"], T["Group-Target"] },
    ["PartyPet%d"]    = { T["Unit Frames"], T["Group-Pet"] },

    -- chat
    ["ChatLeft"]      = { T["Chat"], nil },
    ["ChatRight"]     = { T["Chat"], nil },
    ["ChatInputBox"]  = { T["Chat"], nil },

    -- loot
    ["LootRollFrame%d"] = { T["Loot"], nil },

    -- panel
    ["PanelLeft"]        = { T["Panel"], T["General"] },
    ["PanelRight"]       = { T["Panel"], T["General"] },
    ["PanelMinimap"]     = { T["Panel"], T["General"] },
    ["PanelMicroButton"] = { T["Panel"], T["General"] },

    -- actionbar
    ["ActionBarMain"]        = { T["Actionbar"], T["Main Actionbar"]},
    ["ActionBarPaging"]      = { T["Actionbar"], T["Paging Actionbar"]},
    ["ActionBarRight"]       = { T["Actionbar"], T["Right Actionbar"]},
    ["ActionBarVertical"]    = { T["Actionbar"], T["Vertical Actionbar"]},
    ["ActionBarLeft"]        = { T["Actionbar"], T["Left Actionbar"]},
    ["ActionBarTop"]         = { T["Actionbar"], T["Top Actionbar"]},
    ["ActionBarStanceBar1"]  = { T["Actionbar"], T["Stance Bar 1"]},
    ["ActionBarStanceBar2"]  = { T["Actionbar"], T["Stance Bar 2"]},
    ["ActionBarStanceBar3"]  = { T["Actionbar"], T["Stance Bar 3"]},
    ["ActionBarStanceBar4"]  = { T["Actionbar"], T["Stance Bar 4"]},
    ["ActionBarStances"]     = { T["Actionbar"], T["Stance/Shapeshift Actionbar"]},
    ["ActionBarPet"]         = { T["Actionbar"], T["Pet Actionbar"]},

    -- castbar
    ["TargetCastbar"]  = { T["Castbar"], nil },
    ["PlayerCastbar"]  = { T["Castbar"], nil },
    ["FocusCastbar"]   = { T["Castbar"], nil },

    -- minimap
    ["Minimap"]        = { T["Minimap"], T["Minimap"] },
    ["UITracking"]     = { T["Minimap"], T["Minimap"] },

    -- buffs
    ["BuffFrame"]      = { T["Buffs"], T["Buff/Debuff Icons"] },
    ["DebuffFrame"]    = { T["Buffs"], T["Buff/Debuff Icons"] },

    -- buffbars
    ["PlayerBuffBar"]   = { T["Buffs"], T["Player Buff Bar"] },
    ["PlayerDebuffBar"] = { T["Buffs"], T["Player Debuff Bar"] },
    ["TargetDebuffBar"] = { T["Buffs"], T["Target Debuff Bar"] },
  }

  local function GetFrames()
    -- Return frames based on Ctrl and Shift state
    -- 'this'   [frame]       the base frame
    -- return   [list]        all frames that should be selected

    local frame = this.frame
    local frames = { frame }

    if IsShiftKeyDown() or IsControlKeyDown() then
      -- search and add clustered frames
      for id, cluster in pairs(clusters) do
        local len = strlen(cluster[1])
        if strsub(frame:GetName(),0,len) == cluster[1] then
          if IsShiftKeyDown() and cluster[2] then
            for i = 1, cluster[2] do
              if _G[cluster[1] .. i] ~= frame then
                table.insert(frames, _G[cluster[1] .. i])
              end
            end
          elseif IsControlKeyDown() and cluster[3] then
            local id = tonumber(strsub(frame:GetName(),len+1,len+2))

            local b = 1
            for i = cluster[3]+1, cluster[2], cluster[3] do
              b = ( id >= i ) and i or b
            end

            for i = b, b + cluster[3] - 1 do
              if _G[cluster[1] .. i] ~= frame then
                table.insert(frames, _G[cluster[1] .. i])
              end
            end
          end
        end
      end
    end

    return frames
  end

  -- octo: ElvUI-style boxes (user, 20 Oct 2026: "how the UI boxes are
  -- clearer"): see-through dark fill, a blue edge and a blue label; white
  -- edge under the mouse, bright when picked, gold for the Alt-click size
  -- source. d.backdrop comes from CreateBackdrop.
  local PAINT = {
    normal = { .02, .04, .06, .55,  .2, .7, 1, .9,     .55, .82, 1 },
    hover  = { .05, .12, .18, .75,  1, 1, 1, 1,        1, 1, 1 },
    picked = { .08, .22, .32, .75,  .35, .8, 1, 1,     1, 1, 1 },
    source = { .22, .17, .02, .7,   1, .82, 0, 1,      1, .9, .4 },
  }
  local matchFrom   -- the box Alt-clicked first: its size goes to the next one
  local function Paint(d, mode)
    if not d then return end
    if not d.backdrop then CreateBackdrop(d, nil, nil, .8) end
    if d == matchFrom and mode ~= "hover" then mode = "source" end
    local p = PAINT[mode] or PAINT.normal
    d.backdrop:SetBackdropColor(p[1], p[2], p[3], p[4])
    d.backdrop:SetBackdropBorderColor(p[5], p[6], p[7], p[8])
    if d.text then d.text:SetTextColor(p[9], p[10], p[11], 1) end
  end

  -- "pfPlayerCastbar" -> "Player Castbar", "pfRaidCluster" -> "Raid Frames"
  local NICE = { RaidCluster = "Raid Frames", Meter1 = "Meter 1", Meter2 = "Meter 2", UITracking = "Tracking",
                 ChatInputBox = "Chat Input", CombatTextIncoming = "Combat Text: Incoming",
                 CombatTextOutgoing = "Combat Text: Outgoing", CombatTextHealing = "Combat Text: Healing",
                 CombatTextNotes = "Combat Text: Notes", CombatTextExtra = "Combat Text: Extra" }
  local function NiceLabel(label)
    if NICE[label] then return NICE[label] end
    local s = string.gsub(label, "(%l)(%u)", "%1 %2")
    s = string.gsub(s, "(%a)(%d)", "%1 %2")
    s = string.gsub(s, "(%d)(%a)", "%1 %2")
    return s
  end

  local function DraggerOnUpdate()
    this.text:SetAlpha(this.text:GetAlpha() -0.05)
    if this.text:GetAlpha() < 0.1 then
      this.text:SetText(NiceLabel(strsub(this:GetParent():GetName(),3)))
      this.text:SetAlpha(1)
      this:SetScript("OnUpdate", function() return end)
    end
  end

  local function SaveScale(frame, scale)
    frame:SetScale(scale)

    if not C.position[frame:GetName()] then
      C.position[frame:GetName()] = {}
    end
    C.position[frame:GetName()]["scale"] = scale

    frame.drag.text:SetText(T["Scale"] .. ": " .. scale)
    frame.drag.text:SetAlpha(1)

    frame.drag:SetScript("OnUpdate", DraggerOnUpdate)
  end

  local function SavePosition(frame)
    SaveMovable(frame)
    UpdateMovable(frame)
  end

  -- [ grid ]
  -- Square cells, GetScreenWidth() / unlock.gridsize wide, counted out from
  -- the screen centre so the two accent-coloured centre lines are exact.
  -- One grid frame per size, kept for when the size is picked again.
  local function GridStep()
    return GetScreenWidth() / (tonumber(C.unlock.gridsize) or 128)
  end

  local function DrawGrid()
    local cells = tonumber(C.unlock.gridsize) or 128
    pfUI.unlock.grids = pfUI.unlock.grids or {}
    for size, grid in pairs(pfUI.unlock.grids) do grid:Hide() end
    if pfUI.unlock.grids[cells] then
      pfUI.unlock.grids[cells]:Show()
      return pfUI.unlock.grids[cells]
    end

    local grid = CreateFrame("Frame", "pfUnlockGrid" .. cells, pfUI.unlock)
    grid:SetAllPoints(pfUI.unlock)
    pfUI.unlock.grids[cells] = grid

    local size = 1
    local width, height = GetScreenWidth(), GetScreenHeight()
    local step = width / cells
    local cx, cy = width / 2, height / 2
    local ar, ag, ab = GetAccentColor()

    local function Line(center, vertical, pos)
      local line = grid:CreateTexture(nil, center and "BORDER" or "BACKGROUND")
      if center then
        line:SetTexture(ar, ag, ab, .8)
      else
        line:SetTexture(0, 0, 0, .5)
      end
      if vertical then
        line:SetPoint("TOPLEFT", grid, "TOPLEFT", pos - size/2, 0)
        line:SetPoint("BOTTOMRIGHT", grid, "BOTTOMLEFT", pos + size/2, 0)
      else
        line:SetPoint("TOPLEFT", grid, "BOTTOMLEFT", 0, pos + size/2)
        line:SetPoint("BOTTOMRIGHT", grid, "BOTTOMRIGHT", 0, pos - size/2)
      end
    end

    Line(true, true, cx)
    Line(true, false, cy)
    for i = 1, ceil(cx / step) do
      Line(false, true, cx - i*step)
      Line(false, true, cx + i*step)
    end
    for i = 1, ceil(cy / step) do
      Line(false, false, cy - i*step)
      Line(false, false, cy + i*step)
    end

    return grid
  end

  -- [ snapping ]
  -- While a frame is dragged the outer edges of its box (frame + border) and
  -- its centre are compared with the outer edges and centres of every other
  -- mover, the screen edges and centre, then the grid lines; within SNAP
  -- pixels the nearest one pulls the frame onto it (ElvUI's sticky frames)
  -- and an accent guide line shows it. Alt or the top bar's "Snap" box turns
  -- it off. All in UIParent units.
  local SNAP = 10

  local function UIScale(frame)
    return frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
  end

  -- outer left, right, centre-x, bottom, top, centre-y in UIParent units:
  -- the boxes draw their border outside the frame, so snapping the outer
  -- edges makes two boxes sit flush instead of overlapping by the border
  local function Edges(frame)
    local l, r, b, t = frame:GetLeft(), frame:GetRight(), frame:GetBottom(), frame:GetTop()
    if not l or not r or not b or not t then return end
    local s = UIScale(frame)
    local bd = (default_border or 0) * s
    l, r, b, t = l*s - bd, r*s + bd, b*s - bd, t*s + bd
    return l, r, (l+r)/2, b, t, (b+t)/2
  end

  local function InSelection(frame)
    for _, f in pairs(pfUI.unlock.selection) do
      if f == frame then return true end
    end
  end

  -- best move (delta) of one of the values in mine onto a target line;
  -- frame and screen lines win over grid lines (ElvUI's sticky frames)
  local function Nearest(mine, targets, gridpos, best, bestline)

    for _, v in pairs(mine) do
      for _, t in pairs(targets) do
        if abs(t - v) < abs(best) then best, bestline = t - v, t end
      end
    end
    if bestline or not gridpos then return best, bestline end
    for _, v in pairs(mine) do
      local t = gridpos(v)
      if abs(t - v) < abs(best) then best, bestline = t - v, t end
    end
    return best, bestline
  end

  -- snap for a box with these outer edges: dx, dy (UIParent units) and the
  -- guide lines, or nil when snapping is off
  local function SnapBox(frame, l, r, b, t)
    if C.unlock.snap ~= "1" or IsAltKeyDown() then return end
    local cx, cy = (l+r)/2, (b+t)/2

    local width, height = GetScreenWidth(), GetScreenHeight()
    local xs, ys = { 0, width, width/2 }, { 0, height, height/2 }
    for name, other in pairs(pfUI.movables) do
      other = other or _G[name]
      if other and other ~= frame and other:IsShown() and not InSelection(other) then
        local ol, or_, ocx, ob, ot, ocy = Edges(other)
        if ol then
          table.insert(xs, ol) table.insert(xs, or_) table.insert(xs, ocx)
          table.insert(ys, ob) table.insert(ys, ot) table.insert(ys, ocy)
        end
      end
    end

    local step = GridStep()
    local gridx = function(v) return width/2 + floor((v - width/2) / step + .5) * step end
    local gridy = function(v) return height/2 + floor((v - height/2) / step + .5) * step end

    local dx, xline = Nearest({ l, r, cx }, xs, gridx, SNAP + 1)
    local dy, yline = Nearest({ b, t, cy }, ys, gridy, SNAP + 1)
    if abs(dx) > SNAP then dx, xline = 0, nil end
    if abs(dy) > SNAP then dy, yline = 0, nil end
    return dx, dy, xline, yline
  end

  -- the snap of a frame where it is now
  local function GetSnap(frame)
    local l, r, _, b, t = Edges(frame)
    if not l then return end
    return SnapBox(frame, l, r, b, t)
  end

  local function ShowGuides(xline, yline)
    local g = pfUI.unlock.guides
    if not g then
      g = {}
      g.x = pfUI.unlock:CreateTexture(nil, "OVERLAY")
      g.y = pfUI.unlock:CreateTexture(nil, "OVERLAY")
      pfUI.unlock.guides = g
    end
    local ar, ag, ab = GetAccentColor()
    g.x:SetTexture(ar, ag, ab, 1)
    g.y:SetTexture(ar, ag, ab, 1)
    if xline then
      g.x:ClearAllPoints()
      g.x:SetPoint("TOPLEFT", pfUI.unlock, "TOPLEFT", xline - 1, 0)
      g.x:SetPoint("BOTTOMRIGHT", pfUI.unlock, "BOTTOMLEFT", xline + 1, 0)
      g.x:Show()
    else
      g.x:Hide()
    end
    if yline then
      g.y:ClearAllPoints()
      g.y:SetPoint("TOPLEFT", pfUI.unlock, "BOTTOMLEFT", 0, yline + 1)
      g.y:SetPoint("BOTTOMRIGHT", pfUI.unlock, "BOTTOMRIGHT", 0, yline - 1)
      g.y:Show()
    else
      g.y:Hide()
    end
  end

  -- [ dragging ]
  -- The selection is moved by hand from the cursor instead of the client's
  -- StartMoving, so the snap can pull it while dragging, and the saved
  -- position is worked out from these numbers: the client may report a
  -- moved frame's edges only on the next screen update.
  local drag = {}

  local function Cursor()
    local x, y = GetCursorPosition()
    local s = UIParent:GetEffectiveScale()
    return x / s, y / s
  end

  local function PlaceBoxes(dx, dy)
    for _, box in ipairs(drag.boxes) do
      box.frame:ClearAllPoints()
      box.frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", (box.il + dx) / box.s, (box.ib + dy) / box.s)
    end
  end

  local function DragOnUpdate()
    local cx, cy = Cursor()
    local dx, dy = cx - drag.cx, cy - drag.cy
    local lead = drag.boxes[1]
    local sx, sy, xline, yline = SnapBox(lead.frame, lead.l + dx, lead.r + dx, lead.b + dy, lead.t + dy)
    if sx then dx, dy = dx + sx, dy + sy end
    ShowGuides(xline, yline)
    if dx == drag.dx and dy == drag.dy then return end
    drag.dx, drag.dy = dx, dy
    PlaceBoxes(dx, dy)
  end

  -- the saved anchor follows the screen third the selection ends up in
  local function AnchorFor(l, r, b, t)
    local width, height = GetScreenWidth(), GetScreenHeight()
    local mx, my = (l + r) / 2, (b + t) / 2
    local h = mx < width/3 and "LEFT" or mx > width*2/3 and "RIGHT" or ""
    local v = my > height*2/3 and "TOP" or my < height/3 and "BOTTOM" or ""
    if v .. h == "" then return "CENTER" end
    return v .. h
  end

  -- offsets of a box (inner edges, UIParent units) for that anchor, in frame units
  local function AnchorOffsets(anchor, l, r, b, t, s)
    local width, height = GetScreenWidth(), GetScreenHeight()
    local x, y
    if strfind(anchor, "LEFT") then x = l elseif strfind(anchor, "RIGHT") then x = r - width else x = (l + r)/2 - width/2 end
    if strfind(anchor, "TOP") then y = t - height elseif strfind(anchor, "BOTTOM") then y = b else y = (b + t)/2 - height/2 end
    return x / s, y / s
  end

  local function GetConfigTable(dlabel)
    local cat, conf = nil, nil
    for label, config in pairs(frame_configs) do
      if string.gsub(dlabel, label, "") == "" then
        cat, conf = config[1], config[2]
      end
    end

    return cat, conf
  end

  local function OpenConfigDialog(category, view)
    -- octo: the OctoBG-style window opens the page itself
    local O = pfUI.octoui and pfUI.octoui.Options
    if O and O.Open and O.frame then
      pfUI.gui.keepLayout = true
      O:Open(category, view)
      pfUI.gui.keepLayout = nil
      return
    end

    pfUI.gui:Show()

    if not pfUI.gui.frames[category] then return end
    pfUI.gui.frames[category]:Click()

    if not view or not pfUI.gui.frames[category][view] then return end
    pfUI.gui.frames[category][view]:Click()
  end

  local function UpdateDockValues()
    if not pfUI.unlock.dock:IsShown() then return end

    local dock = pfUI.unlock.dock
    local drag = dock.parent
    local frame = drag.frame

    -- update dock position
    SetAutoPoint(dock, drag, default_border*2+2)

    -- update dock entries
    dock.title:SetText(drag.label)
    if pfUI_config["position"] and pfUI_config["position"][drag.fname] and pfUI_config["position"][drag.fname]["xpos"] then
      dock.xcoord:SetText(pfUI_config["position"][drag.fname]["xpos"])
      dock.ycoord:SetText(pfUI_config["position"][drag.fname]["ypos"])
      local anchor = pfUI_config["position"][drag.fname]["anchor"] or "TOPLEFT"

      for id, k in pairs(anchors) do
        -- get human readable
        local value, text = strsplit(":", k)
        text = text or value

        if value == anchor then
          UIDropDownMenu_SetSelectedID(pfUI.unlock.dock.anchor, id, 0)
          UIDropDownMenu_SetText(text, pfUI.unlock.dock.anchor)
        end
      end

      dock.reset:SetText(T["Reset"])

      dock.up:Enable()
      dock.down:Enable()
      dock.left:Enable()
      dock.right:Enable()

      dock.up.texture:SetVertexColor(1,.8,0)
      dock.down.texture:SetVertexColor(1,.8,0)
      dock.left.texture:SetVertexColor(1,.8,0)
      dock.right.texture:SetVertexColor(1,.8,0)
    else
      dock.reset:SetText(T["Unlock"])
      dock.xcoord:SetText(T["N/A"])
      dock.ycoord:SetText(T["N/A"])

      dock.up:Disable()
      dock.down:Disable()
      dock.left:Disable()
      dock.right:Disable()

      dock.up.texture:SetVertexColor(.4,.4,.4)
      dock.down.texture:SetVertexColor(.4,.4,.4)
      dock.left.texture:SetVertexColor(.4,.4,.4)
      dock.right.texture:SetVertexColor(.4,.4,.4)
    end

    -- update config button
    local cat, conf = GetConfigTable(drag.label)
    if cat then
      dock.config:Enable()
    else
      dock.config:Disable()
    end
  end

  local function SetDockToFrame(frame)
    if pfUI.unlock.dock.parent then
      -- reset previous border color
      Paint(pfUI.unlock.dock.parent, "normal")
    end

    -- add the new frame
    pfUI.unlock.dock.parent = frame

    if frame then
      Paint(pfUI.unlock.dock.parent, "picked")
      pfUI.unlock.dock:Show()
      UpdateDockValues()
    else
      pfUI.unlock.dock:Hide()
    end
  end

  local function DraggerOnMouseWheel()
    local frame = this.frame
    local scale = round(frame:GetScale() + arg1/10, 1)

    pfUI.unlock.selection = GetFrames()
    for id, frame in pairs(pfUI.unlock.selection) do
      SaveScale(frame, scale)
    end

    -- repaint hackfix for panels
    if pfUI.panel and pfUI.chat then
      pfUI.panel.left:SetScale(pfUI.chat.left:GetScale())
      pfUI.panel.right:SetScale(pfUI.chat.right:GetScale())
    end

    if frame.OnMove then frame:OnMove() end
    QueueFunction(UpdateDockValues)
  end

  local function DraggerOnDragStart()
    local frame = this.frame

    pfUI.unlock.selection = GetFrames()

    -- remember every selected box where it is now (dragged frame first)
    drag.boxes = {}
    local function Add(f)
      local l, r, _, b, t = Edges(f)
      if not l then return end
      local s = UIScale(f)
      local il, ir, ib, it = f:GetLeft() * s, f:GetRight() * s, f:GetBottom() * s, f:GetTop() * s
      -- saved positions are relative to UIParent (as pfUI did on drop)
      if f:GetParent() ~= UIParent then
        f:SetParent(UIParent)
        s = UIScale(f)
      end
      table.insert(drag.boxes, { frame = f, s = s, l = l, r = r, b = b, t = t, il = il, ir = ir, ib = ib, it = it })
      Paint(f.drag, "picked")
    end
    Add(frame)
    for _, f in pairs(pfUI.unlock.selection) do
      if f ~= frame then Add(f) end
    end
    if not drag.boxes[1] then return end

    drag.cx, drag.cy = Cursor()
    drag.dx, drag.dy = 0, 0
    PlaceBoxes(0, 0)
    this:SetScript("OnUpdate", DragOnUpdate)

    if frame.OnMove then frame:OnMove() end
  end

  local function DraggerOnDragStop()
    local frame = this.frame

    this:SetScript("OnUpdate", nil)
    ShowGuides(nil, nil)
    if not drag.boxes or not drag.boxes[1] then return end

    -- where the selection ended up (inner edges, UIParent units)
    local dx, dy = drag.dx or 0, drag.dy or 0
    local left, right, bottom, top
    for _, box in ipairs(drag.boxes) do
      local l, r, b, t = box.il + dx, box.ir + dx, box.ib + dy, box.it + dy
      left = left and min(left, l) or l
      right = right and max(right, r) or r
      bottom = bottom and min(bottom, b) or b
      top = top and max(top, t) or t
    end
    local anchor = AnchorFor(left, right, bottom, top)

    -- save all frame positions
    for _, box in ipairs(drag.boxes) do
      local f = box.frame
      local x, y = AnchorOffsets(anchor, box.il + dx, box.ir + dx, box.ib + dy, box.it + dy, box.s)
      Paint(f.drag, "normal")
      f:ClearAllPoints()
      f:SetPoint(anchor, UIParent, anchor, x, y)
      SavePosition(f)
      if f.OnMove then f:OnMove() end
    end
    drag.boxes = nil
    this.justDragged = true

    Paint(this, "hover")
    UpdateDockValues()
  end

  -- octo: Alt-click two boxes - the second gets the first one's size (user,
  -- 20 Oct 2026). Frames whose size is a setting get the setting (it stays
  -- after a reload): unit frames and castbars (width; height too between two
  -- of the same kind), the meter windows. Anything else is scaled to the
  -- same width.
  local SIZES = {
    pfPlayer = { "unitframes", "player" }, pfTarget = { "unitframes", "target" },
    pfTargetTarget = { "unitframes", "ttarget" }, pfTargetTargetTarget = { "unitframes", "tttarget" },
    pfPet = { "unitframes", "pet" }, pfPetTarget = { "unitframes", "ptarget" }, pfFocus = { "unitframes", "focus" },
    pfPlayerCastbar = { "castbar", "player" }, pfTargetCastbar = { "castbar", "target" }, pfFocusCastbar = { "castbar", "focus" },
  }

  local function ScreenSize(f)
    local s = f:GetEffectiveScale() / UIParent:GetEffectiveScale()
    return (f:GetWidth() or 0) * s, (f:GetHeight() or 0) * s, s
  end

  local function MatchSize(from, to)
    local fw, fh = ScreenSize(from)
    local _, _, ts = ScreenSize(to)
    if fw <= 0 or ts <= 0 then return end
    local w, h = round(fw / ts), round(fh / ts)
    local fk, tk = SIZES[from:GetName()], SIZES[to:GetName()]
    local _, _, meter = string.find(to:GetName() or "", "^pfMeter(%d)$")
    if tk then
      local cfg = C[tk[1]][tk[2]]
      cfg.width = tostring(w)
      to:SetWidth(w)
      if fk and fk[1] == tk[1] then
        -- the same kind: the bars' heights too
        local src = C[fk[1]][fk[2]]
        cfg.height = src.height
        if src.pheight then cfg.pheight = src.pheight end
        if tk[1] == "castbar" and tonumber(cfg.height) and tonumber(cfg.height) > 0 then to:SetHeight(tonumber(cfg.height)) end
      end
      if to.UpdateFrameSize then to:UpdateFrameSize() end
    elseif meter then
      C.meters["width" .. meter], C.meters["height" .. meter] = tostring(w), tostring(h)
      to:SetWidth(w)
      to:SetHeight(h)
      if to.OnMove then to:OnMove() end
    else
      local tw = (to:GetWidth() or 0) * to:GetScale()
      if tw <= 0 then return end
      SaveScale(to, round(to:GetScale() * (w * to:GetScale()) / tw, 2))
    end
    SavePosition(to)
    if to.OnMove then to:OnMove() end
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffpfUI|r: " .. NiceLabel(to.drag.label) .. " " .. T["now matches"] .. " "
      .. NiceLabel(from.drag.label) .. " (" .. w .. (tk and fk and fk[1] == tk[1] and "" or (" x " .. h)) .. ")")
  end

  local function DraggerOnClick()
    -- the mouse-up that ends a drag is not a click
    if arg1 == "LeftButton" and this.justDragged then this.justDragged = nil return end
    if IsAltKeyDown() and arg1 == "LeftButton" then
      -- first box: the size to copy; second box: gets it
      if not matchFrom or matchFrom == this then
        local was = matchFrom
        matchFrom = (was ~= this) and this or nil
        Paint(this, "hover")
        if matchFrom then
          DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffpfUI|r: " .. T["Alt-click the box that should get the size of"] .. " " .. NiceLabel(this.label))
        end
      else
        local from = matchFrom
        matchFrom = nil
        Paint(from, "normal")
        MatchSize(from.frame, this.frame)
        UpdateDockValues()
      end
      return
    elseif arg1 == "LeftButton" then
      -- ElvUI: left-click = the nudge box (arrows, X / Y, anchor)
      if pfUI.unlock.dock.parent == this and pfUI.unlock.dock:IsShown() then
        SetDockToFrame(nil)
      else
        SetDockToFrame(this)
      end
      return
    elseif arg1 == "RightButton" then
      -- ElvUI: right-click = this frame's options
      local cat, conf = GetConfigTable(this.label)
      if cat then
        OpenConfigDialog(cat, conf)
      else
        SetDockToFrame(this)
      end
      return
    elseif arg1 == "MiddleButton" then
      -- reset positions of dragger and all connected frames
      pfUI.unlock.selection = GetFrames()
      for id, frame in pairs(pfUI.unlock.selection) do
        pfUI_config["position"][frame:GetName()] = nil
        UpdateMovable(frame)

        if frame.OnMove then frame:OnMove() end
      end
      UpdateDockValues()
    end
  end

  local function DraggerOnEnter()
    if pfUI.unlock.dock.parent ~= this then
      Paint(this, "hover")
    end
  end

  local function DraggerOnLeave()
    if pfUI.unlock.dock.parent ~= this then
      Paint(this, "normal")
    end
  end

  local function CreateDragger(f)
    local fname = f:GetName()
    local label = string.sub(fname, 1, 2) == "pf" and strsub(fname,3) or fname

    local d = CreateFrame("Button", fname .. "Drag", f)
    d:RegisterForClicks("LeftButtonUp", "MiddleButtonUp", "RightButtonUp")
    d:RegisterForDrag("LeftButton")
    d:SetAllPoints(f)
    d:SetAlpha(1)
    d:EnableMouseWheel(1)

    d:SetFrameLevel(128)

    d.text = d:CreateFontString("Status", "LOW", "GameFontNormal")
    d.text:SetFont(pfUI.font_default, C.global.font_size, "OUTLINE")
    d.text:ClearAllPoints()
    d.text:SetAllPoints(d)
    d.text:SetPoint("CENTER", 0, 0)
    d.text:SetFontObject(GameFontWhite)

    d.frame = f
    d.fname = fname
    d.label = label

    label = NiceLabel(label)
    if d:GetHeight() > (2 * d:GetWidth()) then
      label = strvertical(label)
    end

    d.text:SetText(label)
    d.text:SetFont(pfUI.font_default, C.global.font_size + 1, "OUTLINE")

    d:SetScript("OnMouseWheel", DraggerOnMouseWheel)
    d:SetScript("OnDragStart", DraggerOnDragStart)
    d:SetScript("OnDragStop", DraggerOnDragStop)
    d:SetScript("OnClick", DraggerOnClick)
    d:SetScript("OnMouseDown", function() this.justDragged = nil end)
    d:SetScript("OnEnter", DraggerOnEnter)
    d:SetScript("OnLeave", DraggerOnLeave)

    CreateBackdrop(d, nil, nil, .8)
    Paint(d, "normal")
    return d
  end

  table.insert(UISpecialFrames, "pfUnlock")
  pfUI.unlock = CreateFrame("Button", "pfUnlock", UIParent)
  pfUI.unlock.selection = {}
  pfUI.unlock:Hide()
  pfUI.unlock:SetAllPoints(WorldFrame)
  pfUI.unlock:SetFrameStrata("BACKGROUND")
  pfUI.unlock:SetScript("OnClick", function()
    this:Hide()
  end)

  pfUI.unlock:SetScript("OnShow", function()
    if this.skip then this.skip = nil return end
    if InCombatLockdown and InCombatLockdown() then
      DEFAULT_CHAT_FRAME:AddMessage(ERR_NOT_IN_COMBAT, 1, .2, .2)
      this.skip = true
      this:Hide()
      return
    end

    this.grid = DrawGrid()
    this.bar:Update()

    for name, frame in pairs(pfUI.movables) do
      local frame = frame or _G[name]

      if not frame:IsShown() then frame.hideLater = true end
      frame.drag = frame.drag or CreateDragger(frame)
      frame:SetMovable(true)
      frame.drag:Show()
      frame:Show()
    end

    -- go back to the options window on exit only when it was opened from there
    this.fromGUI = pfUI.gui:IsShown()

    if C.unlock.helpseen ~= "1" then
      this.bar:ShowHelp()
      C.unlock.helpseen = "1"
    end
    pfUI.gui:Hide()
  end)

  pfUI.unlock:SetScript("OnHide", function()
    if this.skip then this.skip = nil return end
    if InCombatLockdown and InCombatLockdown() then
      this.skip = true
      this:Show()
      return
    end

    for name, frame in pairs(pfUI.movables) do
      local frame = frame or _G[name]

      if frame.hideLater == true then frame:Hide() end
      frame:StopMovingOrSizing()
      frame:SetMovable(false)
      if frame.drag then frame.drag:Hide() end
      UpdateMovable(frame)
    end

    SetDockToFrame(nil)
    ShowGuides(nil, nil)
    pfUI.unlock:Hide()
    if this.fromGUI then pfUI.gui:Show() end
  end)

  -- [ top bar ]
  -- ElvUI's layout-mode bar: snap on/off, grid size, help, reset all, done.
  local GRIDSIZES = { 32, 64, 128, 256 }

  local bar = CreateFrame("Frame", "pfUnlockBar", pfUI.unlock)
  bar:SetFrameStrata("FULLSCREEN_DIALOG")
  bar:SetPoint("TOP", pfUI.unlock, "TOP", 0, -20)
  bar:SetWidth(520)
  bar:SetHeight(28)
  bar:EnableMouse(true) -- clicks on the bar do not leave layout mode
  CreateBackdrop(bar)
  pfUI.unlock.bar = bar

  bar.title = bar:CreateFontString(nil, "OVERLAY")
  bar.title:SetFont(pfUI.font_default, C.global.font_size + 2, "OUTLINE")
  bar.title:SetPoint("LEFT", 8, 0)
  bar.title:SetText(T["Layout Mode"])

  local function BarButton(text, width, func)
    local b = CreateFrame("Button", nil, bar, "UIPanelButtonTemplate")
    b:SetWidth(width)
    b:SetHeight(18)
    b:SetText(text)
    b:SetScript("OnClick", func)
    SkinButton(b)
    return b
  end

  -- snap
  bar.snap = CreateFrame("CheckButton", "pfUnlockBarSnap", bar, "UICheckButtonTemplate")
  bar.snap:SetWidth(14)
  bar.snap:SetHeight(14)
  bar.snap:SetPoint("LEFT", 118, 0)
  SkinCheckbox(bar.snap, 14)
  bar.snap:SetScript("OnClick", function()
    C.unlock.snap = this:GetChecked() and "1" or "0"
  end)
  bar.snaptext = bar:CreateFontString(nil, "OVERLAY")
  bar.snaptext:SetFont(pfUI.font_default, C.global.font_size, "OUTLINE")
  bar.snaptext:SetPoint("LEFT", bar.snap, "RIGHT", 4, 0)
  bar.snaptext:SetText(T["Snap"])

  -- grid size = cells across the screen: "-" fewer, bigger squares
  local function SetGrid(dir)
    local cur = tonumber(C.unlock.gridsize) or 128
    local idx = 3
    for i, v in ipairs(GRIDSIZES) do if v == cur then idx = i end end
    idx = idx + dir
    if idx < 1 then idx = 1 elseif idx > table.getn(GRIDSIZES) then idx = table.getn(GRIDSIZES) end
    C.unlock.gridsize = tostring(GRIDSIZES[idx])
    pfUI.unlock.grid = DrawGrid()
    bar:Update()
  end
  bar.gridless = BarButton("-", 18, function() SetGrid(-1) end)
  bar.gridless:SetPoint("LEFT", 185, 0)
  bar.gridtext = bar:CreateFontString(nil, "OVERLAY")
  bar.gridtext:SetFont(pfUI.font_default, C.global.font_size, "OUTLINE")
  bar.gridtext:SetPoint("LEFT", bar.gridless, "RIGHT", 4, 0)
  bar.gridtext:SetWidth(60)
  bar.gridmore = BarButton("+", 18, function() SetGrid(1) end)
  bar.gridmore:SetPoint("LEFT", bar.gridtext, "RIGHT", 4, 0)

  function bar:ShowHelp()
    local a = rgbhex(GetAccentColor())
    -- octo: ElvUI's clicks (left = nudge box, right = the frame's options)
    -- and Alt-click to give one box another one's size
    local function L(key, text) return a .. key .. "|r " .. text .. "\n" end
    local txt = T["Layout mode: move, size and reset frames."] .. "\n\n"
      .. L(T["[Drag]"], T["move the frame - it snaps to other frames and the grid"])
      .. L(T["[Left-click]"], T["nudge box: arrows, X / Y, anchor"])
      .. L(T["[Right-click]"], T["open this frame's options"])
      .. L(T["[Alt-click] two boxes"], T["the second gets the first one's size"])
      .. L(T["[Middle-click]"], T["back to its default place"])
      .. L(T["[Mouse wheel]"], T["scale"])
      .. "\n"
      .. L(T["[Shift]"], T["select all frames of the same kind"])
      .. L(T["[Ctrl]"], T["select all frames of the same group"])
      .. L(T["[Alt] while dragging"], T["no snapping"])
      .. L(T["[Shift] on the arrows"], T["move 10 pixels"])
      .. "\n"
      .. L(T["[Esc]"], T["or a click on an empty spot: done"])
    CreateInfoBox(txt, 15, pfUI.unlock, 210)
  end
  bar.help = BarButton("?", 18, function() bar:ShowHelp() end)
  bar.help:SetPoint("LEFT", bar.gridmore, "RIGHT", 14, 0)

  bar.done = BarButton(T["Done"], 70, function() pfUI.unlock:Hide() end)
  bar.done:SetPoint("RIGHT", -6, 0)

  bar.reset = BarButton(T["Reset All"], 80, function()
    CreateQuestionDialog(T["Move every frame back to its default place?"], function()
      for name, frame in pairs(pfUI.movables) do
        frame = frame or _G[name]
        pfUI_config["position"][frame:GetName()] = nil
        frame:ClearAllPoints()
        UpdateMovable(frame)
        if frame.OnMove then frame:OnMove() end
      end
      SetDockToFrame(nil)
    end)
  end)
  bar.reset:SetPoint("RIGHT", bar.done, "LEFT", -6, 0)

  function bar:Update()
    local ar, ag, ab = GetAccentColor()
    bar.title:SetTextColor(ar, ag, ab, 1)
    bar.snap:SetChecked(C.unlock.snap == "1")
    bar.gridtext:SetText(T["Grid"] .. " " .. (C.unlock.gridsize or "128"))
  end

  -- for tests\run.lua
  pfUI.unlock.GetSnap = GetSnap

  -- /moveui (ElvUI's command), /pfmove
  _G.SLASH_PFMOVEUI1, _G.SLASH_PFMOVEUI2 = "/moveui", "/pfmove"
  _G.SlashCmdList.PFMOVEUI = function()
    if pfUI.unlock:IsShown() then pfUI.unlock:Hide() else pfUI.unlock:Show() end
  end

  -- dock frame
  pfUI.unlock.dock = CreateFrame("Button", "pfUnlockDock", pfUI.unlock)
  pfUI.unlock.dock:SetWidth(150)
  pfUI.unlock.dock:SetHeight(160)
  pfUI.unlock.dock:SetFrameStrata("FULLSCREEN_DIALOG")
  pfUI.unlock.dock:Hide()
  CreateBackdrop(pfUI.unlock.dock)

  -- title
  pfUI.unlock.dock.title = pfUI.unlock.dock:CreateFontString("Status", "DIALOG", "GameFontNormal")
  pfUI.unlock.dock.title:SetTextColor(1,1,1,1)
  pfUI.unlock.dock.title:SetFont(pfUI.font_default, C.global.font_size + 2, "OUTLINE")
  pfUI.unlock.dock.title:SetJustifyH("left")
  pfUI.unlock.dock.title:SetPoint("TOP", 0, -5)

  -- anchor
  pfUI.unlock.dock.anchor = CreateFrame("Frame", "pfUIUnlockAnchorDropDownMenu", pfUI.unlock.dock, "UIDropDownMenuTemplate")
  pfUI.unlock.dock.anchor:ClearAllPoints()
  pfUI.unlock.dock.anchor:SetPoint("TOP", 0, -25)

  UIDropDownMenu_SetWidth(120, pfUI.unlock.dock.anchor)
  UIDropDownMenu_SetButtonWidth(120, pfUI.unlock.dock.anchor)
  UIDropDownMenu_JustifyText("RIGHT", pfUI.unlock.dock.anchor)
  UIDropDownMenu_Initialize(pfUI.unlock.dock.anchor, function()
    local info = {}
    for id, k in pairs(anchors) do
      -- get human readable
      local value, text = strsplit(":", k)
      local id = id
      text = text or value

      info.text = text
      info.checked = false
      info.func = function()
        UIDropDownMenu_SetSelectedID(pfUI.unlock.dock.anchor, id, 0)
        UIDropDownMenu_SetText(text, pfUI.unlock.dock.anchor)

        local frame = pfUI.unlock.dock.parent.frame
        local anchor, x, y = ConvertFrameAnchor(frame, text)
        frame:ClearAllPoints()
        frame:SetPoint(anchor, UIParent, anchor, x, y)

        SavePosition(frame)
        UpdateDockValues()
      end

      UIDropDownMenu_AddButton(info)
    end
  end)

  SkinDropDown(pfUI.unlock.dock.anchor)

  -- x coordinates
  pfUI.unlock.dock.xcoordcap = pfUI.unlock.dock:CreateFontString("Status", "DIALOG", "GameFontNormal")
  pfUI.unlock.dock.xcoordcap:SetFont(pfUI.font_default, C.global.font_size, "OUTLINE")
  pfUI.unlock.dock.xcoordcap:SetJustifyH("LEFT")
  pfUI.unlock.dock.xcoordcap:SetPoint("TOPLEFT", 5, -63)
  pfUI.unlock.dock.xcoordcap:SetText("X:")
  pfUI.unlock.dock.xcoord = CreateFrame("EditBox", nil, pfUI.unlock.dock)
  pfUI.unlock.dock.xcoord:SetTextInsets(5, 5, 5, 5)
  pfUI.unlock.dock.xcoord:SetJustifyH("CENTER")
  pfUI.unlock.dock.xcoord:SetWidth(45)
  pfUI.unlock.dock.xcoord:SetHeight(18)
  pfUI.unlock.dock.xcoord:SetPoint("TOPLEFT", pfUI.unlock.dock, "TOPLEFT", 20, -60)
  pfUI.unlock.dock.xcoord:SetFontObject(GameFontNormal)
  pfUI.unlock.dock.xcoord:SetAutoFocus(false)

  pfUI.unlock.dock.xcoord:SetScript("OnEnterPressed", function(self)
    local newXPos = tonumber(this:GetText())
    if newXPos then
      local frame = pfUI.unlock.dock.parent.frame
      local anchor, _, _, xpos, ypos = frame:GetPoint()
      frame:SetPoint(anchor, newXPos, ypos)
      SavePosition(frame)
    else
      UpdateDockValues()
    end
    this:ClearFocus()
  end)

  pfUI.unlock.dock.xcoord:SetScript("OnTextChanged", function(self)
    if tonumber(this:GetText()) then
      this:SetTextColor(1,1,1,1)
    else
      this:SetTextColor(1,.3,.3,1)
    end
  end)

  CreateBackdrop(pfUI.unlock.dock.xcoord, nil, true)

  -- y coordinates
  pfUI.unlock.dock.ycoordcap = pfUI.unlock.dock:CreateFontString("Status", "DIALOG", "GameFontNormal")
  pfUI.unlock.dock.ycoordcap:SetFont(pfUI.font_default, C.global.font_size, "OUTLINE")
  pfUI.unlock.dock.ycoordcap:SetText("Y:")
  pfUI.unlock.dock.ycoordcap:SetJustifyH("LEFT")
  pfUI.unlock.dock.ycoordcap:SetPoint("TOPLEFT", 75, -63)
  pfUI.unlock.dock.ycoord = CreateFrame("EditBox", nil, pfUI.unlock.dock)
  pfUI.unlock.dock.ycoord:SetTextInsets(5, 5, 5, 5)
  pfUI.unlock.dock.ycoord:SetJustifyH("CENTER")
  pfUI.unlock.dock.ycoord:SetWidth(45)
  pfUI.unlock.dock.ycoord:SetHeight(18)
  pfUI.unlock.dock.ycoord:SetPoint("TOPLEFT", pfUI.unlock.dock, "TOPLEFT", 90, -60)
  pfUI.unlock.dock.ycoord:SetFontObject(GameFontNormal)
  pfUI.unlock.dock.ycoord:SetAutoFocus(false)

  pfUI.unlock.dock.ycoord:SetScript("OnEnterPressed", function(self)
    local newYPos = tonumber(this:GetText())
    if newYPos then
      local frame = pfUI.unlock.dock.parent.frame
      local anchor, _, _, xpos, ypos = frame:GetPoint()
      frame:SetPoint(anchor, xpos, newYPos)
      SavePosition(frame)
    else
      UpdateDockValues()
    end
    this:ClearFocus()
  end)

  pfUI.unlock.dock.ycoord:SetScript("OnTextChanged", function(self)
    if tonumber(this:GetText()) then
      this:SetTextColor(1,1,1,1)
    else
      this:SetTextColor(1,.3,.3,1)
    end
  end)

  CreateBackdrop(pfUI.unlock.dock.ycoord, nil, true)

  -- reset button
  pfUI.unlock.dock.reset = CreateFrame("Button", "pfDragDockReset", pfUI.unlock.dock, "UIPanelButtonTemplate")
  pfUI.unlock.dock.reset:SetHeight(18)
  pfUI.unlock.dock.reset:SetPoint("TOPLEFT", 5, -85)
  pfUI.unlock.dock.reset:SetPoint("TOPRIGHT", -5, -85)
  pfUI.unlock.dock.reset:SetScript("OnClick", function()
    local frame = pfUI.unlock.dock.parent.frame

    if this:GetText() == T["Reset"] then
      pfUI_config["position"][frame:GetName()] = nil
      frame:ClearAllPoints()
      UpdateMovable(frame)
    else
      frame:StartMoving()
      frame:StopMovingOrSizing()
      SavePosition(frame)
    end

    if frame.OnMove then frame:OnMove() end

    QueueFunction(SetDockToFrame, pfUI.unlock.dock.parent)
  end)
  SkinButton(pfUI.unlock.dock.reset)

  -- move left
  pfUI.unlock.dock.left = CreateFrame("Button", "pfDragDockPosUp", pfUI.unlock.dock, "UIPanelButtonTemplate")
  pfUI.unlock.dock.left:SetHeight(18)
  pfUI.unlock.dock.left:SetWidth(18)
  pfUI.unlock.dock.left:SetPoint("TOP", -50, -110)
  pfUI.unlock.dock.left.texture = pfUI.unlock.dock.left:CreateTexture("arrow")
  pfUI.unlock.dock.left.texture:SetTexture(pfUI.media["img:left"])
  pfUI.unlock.dock.left.texture:ClearAllPoints()
  pfUI.unlock.dock.left.texture:SetPoint("TOPLEFT", pfUI.unlock.dock.left, "TOPLEFT", 4, -2)
  pfUI.unlock.dock.left.texture:SetPoint("BOTTOMRIGHT", pfUI.unlock.dock.left, "BOTTOMRIGHT", -4, 2)
  pfUI.unlock.dock.left:SetScript("OnClick", function()
    local frame = pfUI.unlock.dock.parent.frame
    local anchor, _, _, xpos, ypos = frame:GetPoint()
    frame:SetPoint(anchor or "TOPLEFT", xpos - (IsShiftKeyDown() and 10 or 1), ypos)
    SavePosition(frame)
    UpdateDockValues()
  end)
  SkinButton(pfUI.unlock.dock.left)

  -- move right
  pfUI.unlock.dock.right = CreateFrame("Button", "pfDragDockPosUp", pfUI.unlock.dock, "UIPanelButtonTemplate")
  pfUI.unlock.dock.right:SetHeight(18)
  pfUI.unlock.dock.right:SetWidth(18)
  pfUI.unlock.dock.right:SetPoint("TOP", -25, -110)
  pfUI.unlock.dock.right.texture = pfUI.unlock.dock.right:CreateTexture("arrow")
  pfUI.unlock.dock.right.texture:SetTexture(pfUI.media["img:right"])
  pfUI.unlock.dock.right.texture:ClearAllPoints()
  pfUI.unlock.dock.right.texture:SetPoint("TOPLEFT", pfUI.unlock.dock.right, "TOPLEFT", 4, -2)
  pfUI.unlock.dock.right.texture:SetPoint("BOTTOMRIGHT", pfUI.unlock.dock.right, "BOTTOMRIGHT", -4, 2)
  pfUI.unlock.dock.right:SetScript("OnClick", function()
    local frame = pfUI.unlock.dock.parent.frame
    local anchor, _, _, xpos, ypos = frame:GetPoint()
    frame:SetPoint(anchor or "TOPLEFT", xpos + (IsShiftKeyDown() and 10 or 1), ypos)
    SavePosition(frame)
    UpdateDockValues()
  end)
  SkinButton(pfUI.unlock.dock.right)

  -- move up
  pfUI.unlock.dock.up = CreateFrame("Button", "pfDragDockPosUp", pfUI.unlock.dock, "UIPanelButtonTemplate")
  pfUI.unlock.dock.up:SetHeight(18)
  pfUI.unlock.dock.up:SetWidth(18)
  pfUI.unlock.dock.up:SetPoint("TOP", 25, -110)
  pfUI.unlock.dock.up.texture = pfUI.unlock.dock.up:CreateTexture("arrow")
  pfUI.unlock.dock.up.texture:SetTexture(pfUI.media["img:up"])
  pfUI.unlock.dock.up.texture:ClearAllPoints()
  pfUI.unlock.dock.up.texture:SetPoint("TOPLEFT", pfUI.unlock.dock.up, "TOPLEFT", 4, -2)
  pfUI.unlock.dock.up.texture:SetPoint("BOTTOMRIGHT", pfUI.unlock.dock.up, "BOTTOMRIGHT", -4, 2)
  pfUI.unlock.dock.up:SetScript("OnClick", function()
    local frame = pfUI.unlock.dock.parent.frame
    local anchor, _, _, xpos, ypos = frame:GetPoint()
    frame:SetPoint(anchor or "TOPLEFT", xpos, ypos + (IsShiftKeyDown() and 10 or 1))
    SavePosition(frame)
    UpdateDockValues()
  end)
  SkinButton(pfUI.unlock.dock.up)

  -- move down
  pfUI.unlock.dock.down = CreateFrame("Button", "pfDragDockPosUp", pfUI.unlock.dock, "UIPanelButtonTemplate")
  pfUI.unlock.dock.down:SetHeight(18)
  pfUI.unlock.dock.down:SetWidth(18)
  pfUI.unlock.dock.down:SetPoint("TOP", 50, -110)
  pfUI.unlock.dock.down.texture = pfUI.unlock.dock.down:CreateTexture("arrow")
  pfUI.unlock.dock.down.texture:SetTexture(pfUI.media["img:down"])
  pfUI.unlock.dock.down.texture:ClearAllPoints()
  pfUI.unlock.dock.down.texture:SetPoint("TOPLEFT", pfUI.unlock.dock.down, "TOPLEFT", 4, -2)
  pfUI.unlock.dock.down.texture:SetPoint("BOTTOMRIGHT", pfUI.unlock.dock.down, "BOTTOMRIGHT", -4, 2)
  pfUI.unlock.dock.down:SetScript("OnClick", function()
    local frame = pfUI.unlock.dock.parent.frame
    local anchor, _, _, xpos, ypos = frame:GetPoint()
    frame:SetPoint(anchor or "TOPLEFT", xpos, ypos - (IsShiftKeyDown() and 10 or 1))
    SavePosition(frame)
    UpdateDockValues()
  end)
  SkinButton(pfUI.unlock.dock.down)

  -- open config
  pfUI.unlock.dock.config = CreateFrame("Button", "pfDragDockConfigOpen", pfUI.unlock.dock, "UIPanelButtonTemplate")
  pfUI.unlock.dock.config:SetHeight(18)
  pfUI.unlock.dock.config:SetPoint("BOTTOMLEFT", 5, 5)
  pfUI.unlock.dock.config:SetPoint("BOTTOMRIGHT", -5, 5)
  pfUI.unlock.dock.config:SetText(T["Configure"])
  pfUI.unlock.dock.config:SetScript("OnClick", function()
    local cat, conf = GetConfigTable(pfUI.unlock.dock.parent.label)
    if cat then OpenConfigDialog(cat, conf) end
  end)
  SkinButton(pfUI.unlock.dock.config)
end)

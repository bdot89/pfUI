-- pfUI Octo: layout mode sizes (25 Oct 2026, user: "when resizing ... they jump in size ...
-- There should be match size buttons ... when ... making your raid frame bigger it messes up
-- the way the raid is laid out"), run by tests\run.lua. The wheel's notch, frames keeping
-- their place while they change size, Match between action bars, the raid grid sized by its
-- frames, and the Unit Frames page's sections.
local ok = octo_ok
local U = pfUI.unlock
local SZ = U and U.size
ok(SZ and U.KeepPlaces and U.MatchSize and U.Resize, "layout mode's size helpers (pfUI.unlock.size)")
if not SZ then return end
local C = pfUI_config
local function near(a, b, e) return a and b and math.abs(a - b) < (e or .001) end

-- ---------------------------------------------------------------- the notch
ok(SZ.Step() == .02 and SZ.Step(true) == .1 and SZ.Step(nil, true) == .005, "a notch: 2%, Shift 10%, Ctrl 0.5%")
ok(SZ.Next(1, 1, .02) == 1.02 and SZ.Next(1.02, -1, .02) == 1, "one notch up and back")
local v = 1
for i = 1, 25 do v = SZ.Next(v, 1, .02) end
for i = 1, 25 do v = SZ.Next(v, -1, .02) end
ok(v == 1, "25 notches up and 25 down end where they started (" .. v .. ")")
ok(SZ.Next(.31, -1, .1) == SZ.MIN and SZ.Next(2.95, 1, .1) == SZ.MAX, "the scale stays between 30% and 300%")

-- anchor point <-> offsets, every anchor, at a scale
local W, H = 1920, 1080
local all = true
for _, a in ipairs({ "TOPLEFT", "TOP", "TOPRIGHT", "LEFT", "CENTER", "RIGHT", "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT" }) do
  local px, py = SZ.Point(a, 37, -12, .8, W, H)
  local x, y = SZ.Offsets(a, px, py, .8, W, H)
  if not near(x, 37) or not near(y, -12) then all = false end
end
ok(all, "a frame's point on screen and its saved offsets turn into each other for every anchor")
local bx, by = SZ.Point("BOTTOM", 0, 50, 1.5, W, H)
ok(bx == 960 and by == 75, "BOTTOM 0 / 50 at 150% sits 75 px up the middle")

-- ---------------------------------------------------------------- keeping the place
do
  local f = CreateFrame("Frame", "pfTestSized", UIParent)
  f:SetWidth(400)
  f:SetHeight(40)
  f.GetEffectiveScale = function(self) return self:GetScale() end
  C.position.pfTestSized = { anchor = "BOTTOM", xpos = 0, ypos = 60 }
  f:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 60)
  local was = { SZ.Point("BOTTOM", 0, 60, 1, W, H) }
  -- ten notches bigger, one at a time: the bottom middle never moves
  local moved = 0
  for i = 1, 10 do
    U.KeepPlaces({ f }, function() f:SetScale(SZ.Next(f:GetScale(), 1, .02)) end)
    local pos = C.position.pfTestSized
    local qx, qy = SZ.Point(pos.anchor, tonumber(pos.xpos), tonumber(pos.ypos), f:GetScale(), W, H)
    moved = math.max(moved, math.abs(qx - was[1]), math.abs(qy - was[2]))
  end
  ok(near(f:GetScale(), 1.2) and moved < 1.3, "a bar at the bottom grows up from where it is (moved " .. moved .. " px at most)")
  ok(f.unlockFix and f.unlockFix.px == was[1] and f.unlockFix.py == was[2], "the exact point is kept between notches, not pfUI's rounded one")
  -- a frame on its default place is left there
  local g = CreateFrame("Frame", "pfTestDefault", UIParent)
  g:SetPoint("CENTER", UIParent, "CENTER", 5, 5)
  C.position.pfTestDefault = nil
  U.KeepPlaces({ g }, function() g:SetScale(1.1) end)
  ok(C.position.pfTestDefault == nil, "a frame on its default place stays on it (not saved)")
  C.position.pfTestSized = nil
end

-- ---------------------------------------------------------------- action bars
local AB = pfUI.barsOcto
local main, top = pfUI.bars and pfUI.bars[1], pfUI.bars and pfUI.bars[6]
ok(AB and AB.CopySize and AB.MatchAll and AB.BarIndex, "pfUI.barsOcto.CopySize / MatchAll / BarIndex")
if AB and main and top then
  ok(AB.BarIndex(main) == 1 and AB.BarIndex(top) == 6 and not AB.BarIndex(UIParent), "BarIndex finds a bar's number")
  local b1, b6 = C.bars.bar1, C.bars.bar6
  local keep = { b1.icon_size, b1.spacing, b1.scale, b6.icon_size, b6.spacing, b6.scale }
  b6.icon_size, b6.spacing, b6.scale = "30", "4", "1.2"
  b1.icon_size, b1.spacing, b1.scale = "20", "1", "1"
  for k in pairs(pfUI.movables) do if type(k) ~= "string" then pfUI.movables[k] = nil end end
  U:Show()
  U.MatchSize(top, main)
  ok(b1.icon_size == "30" and b1.spacing == "4" and b1.scale == "1.2", "Match: the main bar takes the top bar's button size, spacing and scale")
  ok(near(main:GetScale(), 1.2), "and is drawn at that scale (" .. main:GetScale() .. ")")
  -- the match menu: other bars, then "every other bar"
  local list = U.MatchChoices(main.drag)
  local onlyBars = table.getn(list) > 0
  for _, e in ipairs(list) do if not AB.BarIndex(e[2]) then onlyBars = false end end
  ok(onlyBars, "a bar's Match menu lists only other bars (" .. table.getn(list) .. ")")
  -- first page: what can be done; Match opens the list of bars
  U.OpenMatchMenu(main.drag)
  local menu = _G.pfUnlockMatchMenu
  local words = {}
  for _, r in ipairs(menu.rows) do if r:IsShown() then table.insert(words, r.text:GetText()) end end
  local said = table.concat(words, " | ")
  ok(string.find(said, "Match the size of") and string.find(said, "Lock to another box") and string.find(said, "Lock other boxes"),
    "the menu: match, lock to, lock others here (" .. said .. ")")
  Mock.Run(menu.rows[1], "OnClick", "LeftButton")
  ok(menu:IsShown() and menu.rows[1].role == "pick", "Match opens the bars to pick from, the menu stays up")
  U.OpenMatchMenu(main.drag)
  ok(menu.rows[2].role == "save" and string.find(menu.rows[2].text:GetText(), "Every other bar"), "then 'every other bar like this one' (gold)")
  U.OpenMatchMenu(main.drag, nil, "match")
  local first = menu.rows[1]
  local last
  for _, r in ipairs(menu.rows) do if r:IsShown() then last = r end end
  ok(first and first.role == "pick" and last.role == "back", "the bars to pick from are purple (pick one), Back at the end")
  if first then
    Mock.Run(first, "OnClick", "LeftButton")
    ok(not menu:IsShown(), "picking one closes the menu")
  end
  -- every enabled bar like the main one
  b1.icon_size, b1.spacing, b1.scale = "26", "2", "0.9"
  local n = AB.MatchAll(1)
  local same = true
  for i = 2, 10 do
    local d = C.bars["bar" .. i]
    if d.enable == "1" and (d.icon_size ~= "26" or d.spacing ~= "2" or d.scale ~= "0.9") then same = false end
  end
  ok(n > 0 and same, "Match all bars: every bar that is on takes the main bar's size (" .. n .. " bars)")
  -- the wheel over a bar: one 2% notch, and the readout under the box
  local s0 = main:GetScale()
  _G.this, _G.arg1 = main.drag, 1
  main.drag:GetScript("OnMouseWheel")()
  ok(near(main:GetScale(), s0 + .02), "one notch of the wheel = 2% (" .. s0 .. " -> " .. main:GetScale() .. ")")
  ok(main.drag.sizebox and main.drag.sizebox:IsShown() and string.find(main.drag.sizebox.text:GetText(), "buttons"), "the size shows under the box while it changes")
  Mock.shift = true
  _G.this, _G.arg1 = main.drag, -1
  main.drag:GetScript("OnMouseWheel")()
  Mock.shift = nil
  ok(near(main:GetScale(), s0 - .08), "Shift: 10% a notch (" .. main:GetScale() .. ")")
  U:Hide()
  b1.icon_size, b1.spacing, b1.scale, b6.icon_size, b6.spacing, b6.scale = keep[1], keep[2], keep[3], keep[4], keep[5], keep[6]
  for i = 2, 10 do C.bars["bar" .. i].scale = "1" end
  if C.position.pfActionBarMain then C.position.pfActionBarMain.scale = nil end
  pfUI.bars:UpdateConfig()
end

-- ---------------------------------------------------------------- locks
-- (user, 25 Oct 2026: the druid mana bar dragged off the player frame "wont lock back")
do
  local real = pfUI.movables
  local A = CreateFrame("Frame", "pfTestLockA", UIParent)
  local B = CreateFrame("Frame", "pfTestLockB", UIParent)
  local D = CreateFrame("Frame", "pfTestMana", UIParent)
  for _, f in ipairs({ A, B, D }) do f:SetWidth(100) f:SetHeight(20) end
  B:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  A:SetPoint("CENTER", UIParent, "CENTER", 0, 50)
  -- a bar docked under B by default, as pfDruidMana under pfPlayer
  D:SetPoint("TOPLEFT", B, "BOTTOMLEFT", 0, -2)
  pfUI.movables = { pfTestLockA = A, pfTestLockB = B, pfTestMana = D }
  C.position.pfTestLockA, C.position.pfTestLockB, C.position.pfTestMana = nil, nil, nil
  for _, f in ipairs({ A, B, D }) do pfUI.api.UpdateMovable(f, true) end
  U:Show()
  ok(U.Holder(D) == B, "a docked bar moves with the frame it hangs on")
  -- dragged off (saved on the screen), then locked back
  D:ClearAllPoints()
  D:SetPoint("CENTER", UIParent, "CENTER", 300, 0)
  pfUI.api.SaveMovable(D)
  ok(C.position.pfTestMana and not C.position.pfTestMana.attach and U.Holder(D) == nil, "dragged off: free")
  U.OpenMatchMenu(D.drag)
  local back
  for _, r in ipairs(_G.pfUnlockMatchMenu.rows) do
    if r:IsShown() and string.find(r.text:GetText() or "", "Lock back on") then back = r end
  end
  ok(back and back.role == "go", "the menu offers 'Lock back on' its frame (green)")
  if back then Mock.Run(back, "OnClick", "LeftButton") end
  local _, rel = D:GetPoint()
  ok(C.position.pfTestMana == nil and rel == B, "locked back on its frame, as it was")
  -- lock A to B: saved on B, loaded on B
  U.LockTo(A, B)
  local pa = C.position.pfTestLockA
  ok(pa and pa.attach == "pfTestLockB" and pa.relpoint == "BOTTOMLEFT", "Lock to: saved on the other box (" .. tostring(pa and pa.attach) .. ")")
  A:ClearAllPoints()
  pfUI.api.LoadMovable(A)
  _, rel = A:GetPoint()
  ok(rel == B, "and loaded on it after a reload")
  ok(U.Holder(A) == B, "it moves with B")
  -- no loops: B cannot lock to A now
  local loops
  for _, e in ipairs(U.LockChoices(B)) do if e[2] == A then loops = true end end
  ok(not loops, "B is not offered to lock to A (that would be a loop)")
  -- a nudge keeps the lock (the arrows set a point on the same frame)
  local an, r2, rp, x0, y0 = A:GetPoint()
  A:ClearAllPoints()
  A:SetPoint(an, r2, rp, x0 + 1, y0)
  pfUI.api.SaveMovable(A)
  ok(C.position.pfTestLockA.attach == "pfTestLockB", "nudging keeps it locked")
  -- unlock: free, where it is
  U.Unlock(A)
  ok(C.position.pfTestLockA and not C.position.pfTestLockA.attach and U.Holder(A) == nil, "Unlock: free again")
  -- lock others to this one (a group)
  U.OpenMatchMenu(B.drag, nil, "lockhere")
  local row
  for _, r in ipairs(_G.pfUnlockMatchMenu.rows) do if r:IsShown() and r.text:GetText() == "Test Lock A" then row = r end end
  if row then Mock.Run(row, "OnClick", "LeftButton") end
  ok(C.position.pfTestLockA.attach == "pfTestLockB", "Lock other boxes to this one: A joins B's group")
  U:Hide()
  C.position.pfTestLockA, C.position.pfTestLockB, C.position.pfTestMana = nil, nil, nil
  pfUI.movables = real
end

-- ---------------------------------------------------------------- the raid grid
-- raid.lua: cluster = cols * (frame + 2 borders + gap) - gap
ok(SZ.RaidFrameWidth(5 * (60 + 4 + 2) - 2, 5, 2, 2) == 60, "a raid frame's width from the whole raid's width")
local w1, h1 = SZ.RaidStep(60, .5, 1, 1)
local w2, h2 = SZ.RaidStep(w1, .5, 1, 1)
ok(w1 == 61 and h1 == 31 and w2 == 62 and h2 == 31, "a notch: a pixel wider, the height keeps the shape")
local cols, rows = SZ.RaidGrid("5x8")
ok(cols == 5 and rows == 8, "columns and rows from the layout")
local raid, cluster = pfUI.uf and pfUI.uf.raid, _G.pfRaidCluster
if raid and raid[1] and cluster and raid.UpdateConfig then
  local rc = C.unitframes.raid
  local keep = { rc.width, rc.height, rc.o_growy, rc.o_growx, rc.raidlayout }
  rc.width, rc.height, rc.raidlayout = "60", "30", "5x8"
  raid:UpdateConfig()
  local _, border = pfUI.api.GetBorderSize("unitframes")
  local gap = (tonumber(rc.raidpadding) or 0) * pfUI.api.GetPerfectPixel()
  local function GridW() return 5 * (raid[1]:GetWidth() + 2 * border + gap) - gap end
  cluster:SetScale(1.3)  -- a scale left from before
  for k in pairs(pfUI.movables) do if type(k) ~= "string" then pfUI.movables[k] = nil end end
  U:Show()
  _G.this, _G.arg1 = cluster.drag, 1
  if cluster.drag then cluster.drag:GetScript("OnMouseWheel")() end
  ok(rc.width == "79" and rc.height == "40", "the raid wheel turns the old scale into real sizes, then a pixel (" .. rc.width .. " x " .. rc.height .. ")")
  ok(cluster:GetScale() == 1, "and the raid box is not scaled any more")
  ok(near(cluster:GetWidth(), GridW()), "the box is the grid's size again (" .. cluster:GetWidth() .. " / " .. GridW() .. ")")
  local p1 = { raid[1]:GetPoint() }
  local p2 = { raid[2]:GetPoint() }
  -- (raidfill VERTICAL by default: the second frame is above the first)
  ok(p1[1] == "BOTTOMLEFT" and p2[5] and (p2[4] > p1[4] or p2[5] > p1[5]), "frames still in the grid")
  -- Match: the raid as wide as another box, by its frames' width
  local wide = CreateFrame("Frame", "pfTestWide", UIParent)
  wide:SetWidth(5 * (70 + 2 * border + gap) - gap)
  wide:SetHeight(20)
  wide.drag = { label = "TestWide" }
  U.MatchSize(wide, cluster)
  ok(rc.width == "70" and near(cluster:GetWidth(), wide:GetWidth(), .6), "Match: the raid as wide as another box, the grid kept (" .. rc.width .. ")")
  U:Hide()
  -- growth
  rc.o_growy, rc.o_growx = "DOWN", "LEFT"
  raid:UpdateConfig()
  local q = { raid[1]:GetPoint() }
  local q2 = { raid[2]:GetPoint() }
  ok(q[1] == "TOPRIGHT" and q2[5] and q2[5] < 0, "rows can grow down and columns left")
  rc.raidfill = "HORIZONTAL"
  raid:UpdateConfig()
  q2 = { raid[2]:GetPoint() }
  ok(q2[4] and q2[4] < 0, "a row at a time: the second frame to the left")
  rc.raidfill = "VERTICAL"
  rc.width, rc.height, rc.o_growy, rc.o_growx, rc.raidlayout = keep[1], keep[2], keep[3], keep[4], keep[5]
  if C.position.pfRaidCluster then C.position.pfRaidCluster = nil end
  raid:UpdateConfig()
else
  ok(true, "(the raid frames do not start in the mock)")
end

-- ---------------------------------------------------------------- unit frames sections
local UF = pfUI.ufOcto
local O = pfUI.octoui and pfUI.octoui.Options
if UF and O and UF.SECTIONS then
  pfUI.gui:Show()
  O:Select("o:ufframes")
  local p = O.pages.ufframes
  local lost, pics = {}, {}
  for _, c in ipairs(p.cards) do
    if not UF.SECTION_OF[c.title] then table.insert(lost, c.title) end
    if not UF.CARDICON[c.title] and c.title ~= "Try it on the preview" then table.insert(pics, c.title) end
  end
  ok(table.getn(lost) == 0, "every Unit Frames card is in a section (" .. table.concat(lost, ", ") .. ")")
  ok(table.getn(pics) == 0, "every Unit Frames card has a picture (" .. table.concat(pics, ", ") .. ")")
  local most = 0
  for _, s in ipairs(UF.SECTIONS) do most = math.max(most, table.getn(s[4])) end
  ok(table.getn(UF.SECTIONS) == 7 and most <= 4, "seven sections of at most four cards (was one list of " .. table.getn(p.cards) .. ")")
  local function Shown(title)
    for _, c in ipairs(p.cards) do if c.title == title then return c.card:IsShown() end end
  end
  UF.SetSection("size")
  ok(Shown("Health bar") and not Shown("Raid layout") and not Shown("Buffs"), "Size and bars shows only its cards")
  ok(p.last and p.last:IsShown(), "the page ends at the last card shown (its height)")
  UF.SetSection("raid")
  ok(Shown("Raid layout") and not Shown("Health bar") and UF.cur == "raid", "Raid layout: its own section, on the raid frames' preview")
  ok(UF.secTabs and UF.secTabs[6].picked and not UF.secTabs[1].picked, "the section tab is lit (purple)")
  -- a click on the preview's health bar goes to its section
  pfUI.plates.OpenSection("ufframes", "Health bar")
  ok(UF.sec == "size" and Shown("Health bar"), "a card of another section opens that section")
  -- layout mode's right-click on the raid box: the Raid layout card
  O.tabs.ufframes("raid")
  O:Select("o:ufframes")
  ok(UF.sec == "raid" and Shown("Raid layout"), "the raid box's options open on the raid layout")
  UF.cur = "player"
  UF.SetSection("size")
else
  ok(false, "unit frames sections (pfUI.ufOcto.SECTIONS)")
end

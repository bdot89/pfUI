-- load pfUI environment
setfenv(1, pfUI:GetEnvironment())

--[[ libclient ]]--
-- What this client's DLLs add over the plain 1.12 API, behind one set of calls.
-- Every call checks that the DLL function is there and falls back to the plain
-- 1.12 answer (or nil) when it is not, so nothing needs SuperWoW, ClassicAPI or
-- nampower to work - they only make the data better.
--
--  libclient.GUID(unit)
--    The unit's GUID ("0x..."): ClassicAPI UnitGUID, nampower GetUnitGUID or
--    SuperWoW's second UnitExists return. nil without any of them.
--
--  libclient.Aura(unit, index, harmful, texture)
--    ClassicAPI's data for UnitBuff / UnitDebuff(unit, index):
--    name, duration, timeleft, caster, spellId, dispelType, stacks.
--    timeleft / caster are nil when the client did not see the cast.
--    `texture` (the plain UnitBuff texture) guards against index drift: on
--    Turtle-style servers extra debuffs can sit in buff slots, which the plain
--    UnitBuff counts as buffs and ClassicAPI does not.
--
--  libclient.Cast(unit)
--    ClassicAPI's cast or channel of a unit token or GUID:
--    name, texture, startMs, endMs, channel, notInterruptible, delayMs.
--
--  libclient.Distance(unit)
--    Yards from the player (centre to centre): ClassicAPI UnitDistanceSquared,
--    SuperWoW UnitPosition, UnitXP_SP3. nil when none can tell.
--
--  libclient.InRange(unit, yards)
--    true / false when a DLL can tell, nil when not (yards defaults to 40;
--    40 uses ClassicAPI's reach-aware UnitInRange).
--
--  libclient.Stealthed()
--    ClassicAPI IsStealthed(), nil without it.
--
--  libclient.PlayerAura(spellId)
--    true when ClassicAPI finds that spell id among the player's auras.

-- return instantly when another libclient is already active
if pfUI.api.libclient then return end

local libclient = {}

-- names of real unit tokens (C_Spell / C_UnitAuras raise "Unknown unit" on names)
local function IsToken(unit)
  if type(unit) ~= "string" then return nil end
  if pfValidUnits and pfValidUnits[unit] then return true end
  if string.find(unit, "^0x") or string.find(unit, "^nameplate%d+$") then return true end
  return nil
end
libclient.IsToken = IsToken

function libclient.HasSuperWoW()
  return SUPERWOW_VERSION and true or nil
end

function libclient.HasClassicAPI()
  return (C_UnitAuras or C_Spell) and true or nil
end

function libclient.GUID(unit)
  if not unit then return end
  if C_UnitAuras and _G.UnitGUID then
    local ok, guid = pcall(_G.UnitGUID, unit)
    if ok and guid and guid ~= "" then return guid end
  end
  if _G.GetUnitGUID then
    local ok, guid = pcall(_G.GetUnitGUID, unit)
    if ok and guid and guid ~= "" then return guid end
  end
  if SUPERWOW_VERSION then
    local _, guid = UnitExists(unit)
    if guid and guid ~= "" then return guid end
  end
end

function libclient.Aura(unit, index, harmful, texture)
  if not (C_UnitAuras and C_UnitAuras.UnitAura) or not IsToken(unit) or not index then return end
  local ok, name, icon, stacks, dtype, duration, expires, source, _, _, spellId =
    pcall(C_UnitAuras.UnitAura, unit, index, harmful and "HARMFUL" or "HELPFUL")
  if not ok or not name then return end
  if texture and icon and string.lower(icon) ~= string.lower(texture) then return end

  local timeleft
  if expires and expires > 0 and duration and duration > 0 then
    timeleft = expires - GetTime()
    if timeleft < 0 then timeleft = 0 end
  end

  local caster = source
  if caster and caster ~= "player" and UnitIsUnit(caster, "player") then caster = "player" end

  return name, duration, timeleft, caster, spellId, dtype, stacks
end

function libclient.Cast(unit)
  if not C_Spell or not IsToken(unit) then return end
  if C_Spell.UnitCastingInfo then
    local ok, name, _, texture, startMs, endMs, _, _, noint, _, _, delay = pcall(C_Spell.UnitCastingInfo, unit)
    if ok and name and startMs and endMs then return name, texture, startMs, endMs, nil, noint, delay end
  end
  if C_Spell.UnitChannelInfo then
    local ok, name, _, texture, startMs, endMs, _, noint = pcall(C_Spell.UnitChannelInfo, unit)
    if ok and name and startMs and endMs then return name, texture, startMs, endMs, true, noint end
  end
end

function libclient.Distance(unit)
  if not unit then return end
  if C_UnitAuras and _G.UnitDistanceSquared then
    local ok, sq, checked = pcall(_G.UnitDistanceSquared, unit)
    if ok and checked and sq then return math.sqrt(sq) end
  end
  if SUPERWOW_VERSION and _G.UnitPosition then
    local x1, y1, z1 = _G.UnitPosition("player")
    local x2, y2, z2 = _G.UnitPosition(unit)
    if x1 and y1 and z1 and x2 and y2 and z2 then
      return ((x2 - x1)^2 + (y2 - y1)^2 + (z2 - z1)^2)^.5
    end
  end
  if _G.UnitXP then
    local ok, d = pcall(_G.UnitXP, "distanceBetween", "player", unit)
    if ok and type(d) == "number" and d >= 0 then return d end
  end
end

function libclient.InRange(unit, yards)
  yards = yards or 40
  if not unit or not UnitExists(unit) then return end
  if UnitIsUnit(unit, "player") then return true end
  if yards == 40 and C_UnitAuras and _G.UnitInRange then
    local ok, inrange, checked = pcall(_G.UnitInRange, unit)
    if ok and checked then return inrange and true or false end
  end
  local d = libclient.Distance(unit)
  if d then return d <= yards end
end

function libclient.Stealthed()
  if C_UnitAuras and _G.IsStealthed then
    local ok, s = pcall(_G.IsStealthed)
    if ok then return s and true or false end
  end
end

function libclient.PlayerAura(spellId)
  if not (C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID) or not spellId then return end
  local ok, data = pcall(C_UnitAuras.GetPlayerAuraBySpellID, spellId)
  return ok and data and true or nil
end

-- add libclient to pfUI API
pfUI.api.libclient = libclient

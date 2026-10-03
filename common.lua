-- Pure policy helpers. Engine adapters supply their own IDs and Egg rules.
local common = {}
function common.copy(source)
  local out = {}
  for key, value in pairs(source or {}) do out[key] = value end
  return out
end
function common.pack(...) return { n = select("#", ...), ... } end

-- Preserve nil results and restore the exact previous value on every exit.
function common.withValue(owner, key, value, fn, ...)
  local previous = owner[key]
  owner[key] = value
  local result = common.pack(pcall(fn, ...))
  owner[key] = previous
  if not result[1] then error(result[2], 0) end
  return unpack(result, 2, result.n)
end

local function egg(mon, rules)
  if rules and rules.isEgg then return rules.isEgg(mon) end
  return mon.egg
end
function common.knows(mon, move, rules)
  if not mon or egg(mon, rules) then return false end
  local target = rules and rules.moveId or move
  for _, entry in ipairs(mon.moves or {}) do
    local id
    if rules and rules.normalizeMove then id = rules.normalizeMove(entry)
    else id = type(entry) == "table" and entry.id or entry end
    if id == target then return true end
  end
  return false
end
function common.first(party, rules)
  for index, mon in ipairs(party or {}) do
    if not egg(mon, rules) then return mon, index - (rules and rules.slotBase == 0 and 1 or 0) end
  end
end
function common.known(party, move, rules)
  for index, mon in ipairs(party or {}) do
    if common.knows(mon, move, rules) then
      return mon, index - (rules and rules.slotBase == 0 and 1 or 0)
    end
  end
end
function common.actor(party, move, rules)
  local mon, index = common.known(party, move, rules)
  if mon then return mon, index end
  return common.first(party, rules)
end
return common

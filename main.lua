return function(mod)
  local compile = loadstring or load
  local function module(file)
    return assert(compile(assert(mod:read(file)), "@" .. mod.path .. "/" .. file))()
  end
  local version = require("src.core.GameVersion")
  local supported = {
    red = true, blue = true, yellow = true, gold = true, silver = true,
    crystal = true, firered = true, leafgreen = true,
    emerald = true, ruby = true, sapphire = true,
  }
  assert(supported[version.get()], "Modern Field Moves: unsupported game")
  local scope
  if version.generation() ~= 3 then
    local gameClass
    if version.generation() == 2 then gameClass = require("src.core.Game2")
    else gameClass = require("src.core.Game") end
    mod, scope = module("lifecycle.lua")(mod, gameClass)
  end
  local policy = module("field_user.lua")(mod)
  if version.generation() == 3 then return module("gen3.lua")(mod, policy) end
  local map = module("town_map.lua")(mod, module("map_cursor.lua")(mod))
  -- Crystal's scripted Flash wall is absent in Gold/Silver. Keep that edition
  -- capability separate from ordinary darkness and from the Gen3 adapter.
  local editions = { gold = {}, silver = {}, crystal = { flashPuzzle = true } }
  local edition = editions[version.get()] or {}
  return module(version.generation() == 2 and "gen2.lua" or "gen1.lua")(
    mod, policy, map, module("lighting.lua"), scope, edition)
end

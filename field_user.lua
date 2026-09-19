-- Shared options and presentation policy. Never write to party/save records.
return function(mod)
  mod.options:define({
    { key = "field_move_user", type = "choice", label = "FIELD MOVE USER",
      default = "generic", choices = {
        { "GENERIC", "generic" }, { "KNOWN MOVE", "known_move" },
        { "FIRST PARTY", "first_party" },
      } },
    { key = "hm_requirement", type = "choice", label = "HM REQUIREMENT",
      default = "hm_badge", choices = {
        { "HM + BADGE", "hm_badge" }, { "BADGE ONLY", "badge_only" },
      } },
    { key = "light_mode", type = "choice", label = "LIGHT MODE",
      default = "manual", choices = { { "MANUAL", "manual" }, { "AUTO", "auto" } } },
  })

  local policy = {}
  function policy.autoLight() return mod.options:get("light_mode") == "auto" end
  function policy.mode()
    local value = mod.options:get("field_move_user")
    if value == "known_move" or value == "first_party" then return value end
    return "generic"
  end

  function policy.badgeOnly()
    return mod.options:get("hm_requirement") == "badge_only"
  end

  function policy.first(party)
    for index, mon in ipairs(party or {}) do
      if not mon.egg then return mon, index end
    end
  end

  function policy.known(party, move)
    for index, mon in ipairs(party or {}) do
      if not mon.egg then
        for _, entry in ipairs(mon.moves or {}) do
          local id = type(entry) == "table" and entry.id or entry
          if id == move then return mon, index end
        end
      end
    end
  end

  -- GENERIC still supplies a real mon to the native animation code; it is
  -- never named in the text. Preserve native species-dependent rendering.
  function policy.user(party, move)
    if policy.mode() ~= "first_party" then
      local mon, index = policy.known(party, move)
      if mon then return mon, index end
    end
    return policy.first(party)
  end

  function policy.name(game, move)
    local party = game and game.save and game.save.party
    local mode = policy.mode()
    local mon
    if mode == "known_move" then mon = policy.known(party, move)
    elseif mode == "first_party" then mon = policy.first(party) end
    if not mon then return nil end
    local species = game.data and game.data.pokemon and game.data.pokemon[mon.species]
    return mon.nickname or mon.name or (species and species.name) or mon.species
  end

  function policy.message(game, move)
    local name = policy.name(game, move)
    if name then return name .. " used\n" .. move .. "!" end
    return move .. "\nwas used!"
  end

  function policy.boulders(game)
    local name = policy.name(game, "STRENGTH")
    return name and (name .. " can\nmove boulders.") or "Boulders may now\nbe moved!"
  end

  -- Gen 1 renders these ROM text keys inside its native field methods.
  -- Give that synchronous call a temporary catalog, retaining the original
  -- text terminator and restoring the catalog even if another mod throws.
  -- Delayed callbacks already hold their strings (including Strength's tail).
  local function pack(...) return { n = select("#", ...), ... } end
  function policy.withTexts(game, replacements, fn, ...)
    local original = game.data.text
    local catalog = {}
    for key, value in pairs(original or {}) do catalog[key] = value end
    for key, value in pairs(replacements) do
      local old = catalog[key]
      local ending = type(old) == "string" and old:match("({[A-Z]+})%s*$")
      if ending ~= "{DONE}" and ending ~= "{PROMPT}" then ending = "" end
      catalog[key] = value .. ending
    end
    game.data.text = catalog
    local result = pack(pcall(fn, ...))
    game.data.text = original
    if not result[1] then error(result[2], 0) end
    return unpack(result, 2, result.n)
  end

  return policy
end

-- Shared options and presentation policy. Only our own legacy option migrates;
-- party records and vanilla progression are never modified.
return function(mod)
  local compile = loadstring or load
  local common = assert(compile(assert(mod:read("common.lua")),
    "@" .. mod.path .. "/common.lua"))()
  mod.options:define(assert(compile(assert(mod:read("options_schema.lua")),
    "@" .. mod.path .. "/options_schema.lua"))())

  local policy = { common = common }
  -- The only legacy user mode is normalized here. Runtime policy sees the
  -- same two choices that the current options screen exposes.
  local function normalizeUserChoice(value)
    return value == "first_party" and "known_move" or value
  end
  function policy.unrestricted() return mod.options:get("hm_requirement") == "unrestricted" end
  function policy.confirmPrompts() return mod.options:get("confirm_prompts") ~= "off" end
  local contextualPrompts = {
    cut = true, surf = true, strength = true, rock_smash = true,
    whirlpool = true, waterfall = true, dive = true,
  }
  function policy.confirmContext(move)
    if type(move) == "string" then
      move = move:lower():gsub("[%s%-]+", "_")
      if move == "rocksmash" then move = "rock_smash" end
    end
    return not contextualPrompts[move] or policy.confirmPrompts()
  end
  function policy.autoLight() return mod.options:get("light_mode") == "auto" end
  function policy.crossRegionFly()
    return mod.options:get("cross_region_fly") == "enabled" and "enabled" or "vanilla"
  end
  -- Only our own option value changes. Never touch vanilla progression.
  -- Loader and the options file can own distinct buckets on older saves.
  function policy.migrateOptions(game)
    if not game then return end
    local changed = false
    local function migrate(options)
      local bucket = options and options[mod.id]
      if bucket and bucket.field_move_user ~= normalizeUserChoice(bucket.field_move_user) then
        bucket.field_move_user = normalizeUserChoice(bucket.field_move_user)
        changed = true
      end
    end
    migrate(game.mods and game.mods.modOptions)
    migrate(game.options and game.options.modOptions)
    migrate(game.save and game.save.options and game.save.options.modOptions)
    local function profiles(options)
      for _, profile in ipairs(options and options.modProfiles or {}) do migrate(profile.options) end
    end
    profiles(game.options)
    profiles(game.save and game.save.options)
    if changed and type(game.writeOptions) == "function" then game:writeOptions() end
  end
  policy.migrateOptions(mod.game)
  local game = mod.game
  local ready = mod.events:on("game.ready", function(ctx)
    game = ctx and ctx.game
    policy.migrateOptions(game)
  end)
  local changed = mod.events:on("mod.options_changed", function(ctx)
    if ctx and ctx.mod == mod.id then policy.migrateOptions(game) end
  end)
  function policy.dispose()
    if type(ready) == "function" then ready() end
    if type(changed) == "function" then changed() end
  end
  function policy.mode()
    local value = normalizeUserChoice(mod.options:get("field_move_user"))
    if value == "known_move" then return "known_move" end
    return "generic"
  end

  function policy.badgeOnly()
    return mod.options:get("hm_requirement") == "badge_only"
  end

  -- Requirement modes decide eligibility only; no HM, badge or event flag is
  -- granted to the real save. Each generation supplies its own ownership and
  -- badge lookup because their save formats differ.
  function policy.hmAllowed(hasHM, hasBadge)
    if policy.unrestricted() then return true end
    return hasBadge and (hasHM or policy.badgeOnly()) or false
  end

  policy.first = common.first
  policy.known = common.known
  -- A mechanical actor is retained even when presentation is anonymous.
  policy.user = common.actor

  function policy.name(game, move)
    local party = game and game.save and game.save.party
    local mode = policy.mode()
    local mon
    if mode == "known_move" then mon = policy.known(party, move) end
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
  function policy.withTexts(game, replacements, fn, ...)
    local catalog = common.copy(game.data.text)
    for key, value in pairs(replacements) do
      local old = catalog[key]
      local ending = type(old) == "string" and old:match("({[A-Z]+})%s*$")
      if ending ~= "{DONE}" and ending ~= "{PROMPT}" then ending = "" end
      catalog[key] = value .. ending
    end
    return common.withValue(game.data, "text", catalog, fn, ...)
  end

  return policy
end

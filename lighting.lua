return function(mod, policy, generation, unlocked)
  local light = {}
  local Palettes, UnownWords
  if generation == 2 then
    Palettes = require("src.world.gen2.Palettes")
    UnownWords = require("src.world.gen2.UnownWords")
  end
  local function worldOf(game)
    return game and (generation == 2 and game.world or game.overworld)
  end
  local function chamber(world)
    return generation == 2 and require("src.core.GameVersion").get() == "crystal" and world and world.map
      and world.map.id == UnownWords.CHAMBER_MAPS.AERODACTYL
  end
  function light.special(game)
    local world = worldOf(game)
    return chamber(world) and not UnownWords.wallOpened(world.events, "AERODACTYL")
  end
  function light.dark(game)
    local world = worldOf(game)
    if not world or not world.map or chamber(world) then return false end
    if generation == 1 then return world.dark == true end
    -- Pure palette lookup: never evaluate flashFromMenu/availableFieldActions,
    -- which can open the Aerodactyl wall just by checking availability.
    return Palettes.isDarkness(world.map.def, world:hour(), world.flashUsed)
  end
  local function eligible(game)
    return game and game.save and unlocked(game.save, "FLASH")
      and policy.first(game.save.party) ~= nil
  end
  function light.visible(game)
    return not policy.autoLight() and eligible(game) and light.dark(game)
  end
  local function ready(game, world)
    if not game.stack then return false end
    if generation == 2 then
      return game.phase == "play" and game.stack:top() == nil
        and not world.queuedFieldMove and not world.queuedScript
        and world:acceptsMenuInput()
    end
    -- Same readiness gates as the Gen 1 WorldAPI; the direct AUTO effect must
    -- not run in battle, during scripted movement, or underneath another UI.
    local runner, player = world.runner, world.player
    return game.stack:top() == world
      and not world.transitioning and not world.flyAnim and not world.teleportOut
      and not world.engaging and not world.emote and not world.pikaHop and not world.healAnim
      and not (player and (player.moving or player.inputLocked))
      and not (runner and runner.isRunning and runner:isRunning())
      and #(world.scriptMoves or {}) == 0
  end
  function light.manual(game)
    if not light.visible(game) then return false end
    if generation == 1 then return mod.world:useFieldAction("flash") end
    local world = worldOf(game)
    if not ready(game, world) then return false end
    -- Ordinary illumination queues the native Flash effect directly. The
    -- explicit puzzle-only FLASH command retains useFieldMove's chamber path.
    world.queuedFieldMove = { ok = true, action = "flash",
      mon = policy.user(game.save.party, "FLASH"),
      text = require("src.world.gen2.FieldMoves").TEXT.BLINDING_FLASH }
    return true
  end
  mod.hooks:wrap("input.step", function(next, game, dt)
    local result = next(game, dt)
    if not policy.autoLight() or not eligible(game) or not light.dark(game) then return result end
    local world = worldOf(game)
    if not ready(game, world) then return result end
    if generation == 1 then
      game.save.flashLit = true
      world:setDark(false)
    else
      -- BlindingFlash's state/palette effect, with no eligibility callback,
      -- cry, text box or puzzle invocation. Already-lit maps are idempotent.
      world.flashUsed = true
      if world:applyPalettes() then world:refreshMapImages() end
    end
    return result
  end)
  return light
end

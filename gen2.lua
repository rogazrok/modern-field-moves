-- Shared Gold/Silver/Crystal adapter. Native A-button interactions already
-- implement Cut, Surf, Strength, Whirlpool and Waterfall with their prompts.
return function(mod, policy, townMap, installLighting, scope, edition)
  local FieldMoves = require("src.world.gen2.FieldMoves")
  local StartMenu = require("src.ui.gen2.StartMenu")
  local items = {
    CUT = "HM_CUT", FLY = "HM_FLY", SURF = "HM_SURF",
    STRENGTH = "HM_STRENGTH", FLASH = "HM_FLASH",
    WHIRLPOOL = "HM_WHIRLPOOL", WATERFALL = "HM_WATERFALL",
  }

  local function owns(store, id)
    local n = store and store[id]
    return type(n) == "number" and n > 0
  end

  local function unlocked(save, move)
    if not save then return false end
    if policy.unrestricted() then return true end
    local id = items[move]
    -- HMs are reusable and cannot normally be tossed. Count both the bag
    -- and PC so depositing one does not remove the field ability.
    return policy.hmAllowed(owns(save.inventory, id) or owns(save.pcItems, id),
      FieldMoves.hasBadge(save, FieldMoves.BADGE[move]))
  end

  local light = installLighting(mod, policy, 2, unlocked, edition)

  mod.hooks:wrap("fieldmove.eligibility", function(next, moveId, ctx)
    local mon, slot = next(moveId, ctx)
    if not items[moveId] then return mon, slot end
    local save = (ctx and ctx.save) or (mod.game and mod.game.save)
    if not unlocked(save, moveId) then return nil end
    local party = (ctx and ctx.party) or (save and save.party)
    return policy.user(party, moveId)
  end)

  local World = require("src.world.gen2.World")
  -- Debug/cheat mode affects only HM decisions. Never grant actual badges:
  -- native story scripts, trainer cards and save records see the real state.
  local shallowCopy = policy.common.copy
  local function badgeContext(ctx, move)
    -- A copied save branch gives native eligibility its required badge. The
    -- synthetic badge never enters the real save, even if native code errors.
    local scoped = shallowCopy(ctx)
    scoped.save = shallowCopy(ctx and ctx.save)
    scoped.save.player = shallowCopy(scoped.save.player)
    scoped.save.player.badges = shallowCopy(scoped.save.player.badges)
    scoped.save.player.badges[FieldMoves.BADGE[move]] = true
    return scoped
  end
  for _, move in ipairs({ "CUT", "SURF", "STRENGTH", "FLASH", "FLY", "WHIRLPOOL", "WATERFALL" }) do
    local title = move:sub(1,1) .. move:sub(2):lower()
    for _, method in ipairs({ move:lower() .. "FromMenu", "try" .. title .. "OW" }) do
      local original = FieldMoves[method]
      if original then
        scope.wrap(FieldMoves, method, function(original)
          return function(ctx, ...)
            -- Gold/Silver only illuminate darkness; Crystal owns this puzzle.
            if move == "FLASH" and not edition.flashPuzzle then
              ctx = shallowCopy(ctx)
              ctx.openAerodactylWall = nil
            end
            if not policy.unrestricted() then return original(ctx, ...) end
            return original(badgeContext(ctx, move), ...)
          end
        end)
        if method == move:lower() .. "FromMenu" then
          scope.wrap(FieldMoves.FROM_MENU, move, function()
            return FieldMoves[method]
          end)
        end
      end
    end
  end
  scope.wrap(World, "runOverworldFieldMove", function(originalOverworld)
    return function(world, result)
      if result and result.ok and not policy.confirmContext(result.action) then
        result = shallowCopy(result)
        result.ask = nil
      end
      return originalOverworld(world, result)
    end
  end)
  -- The party menu queues successful *Function results directly; unlike the
  -- A-button Try*OW route, these results do not carry an `ask` field. Route
  -- only the contextual HMs through the native ask/yes-no flow before running
  -- them. Fly, Flash, and unrelated story prompts keep their existing paths.
  local menuPrompts = {
    cut = FieldMoves.TEXT.ASK_CUT,
    surf = FieldMoves.TEXT.ASK_SURF,
    strength = FieldMoves.TEXT.ASK_STRENGTH,
    whirlpool = FieldMoves.TEXT.ASK_WHIRLPOOL,
    waterfall = FieldMoves.TEXT.ASK_WATERFALL,
  }
  scope.wrap(World, "runQueuedFieldMove", function(originalQueued)
    return function(world, ...)
      local queued = world.queuedFieldMove
      local action = queued and queued.action
      local ask = action and menuPrompts[action]
      if queued and queued.ok and ask and not world:busy()
          and policy.confirmContext(action) then
        local confirmed = shallowCopy(queued)
        confirmed.ask = confirmed.ask or ask
        confirmed.took = true
        world.queuedFieldMove = nil
        return world:runOverworldFieldMove(confirmed)
      end
      return originalQueued(world, ...)
    end
  end)
  scope.wrap(World, "useFieldMove", function(originalUse)
    return function(world, move, mon)
      -- The party menu trusts learned moves and bypasses the eligibility hook.
      -- Apply the same selected requirement on that route.
      if items[move] and world.map and world.player and not world.battleActive
          and not world:busy() and not unlocked(world.game.save, move) then
        local text = not FieldMoves.hasBadge(world.game.save, FieldMoves.BADGE[move])
          and FieldMoves.TEXT.BADGE_REQUIRED or "An HM is required\nto use this."
        world:showText(text)
        return { ok = false, text = text }
      end
      return originalUse(world, move, mon)
    end
  end)
  scope.wrap(World, "runFieldMove", function(originalRun)
    return function(world, result)
      local move = result and type(result.action) == "string" and result.action:upper()
      if not items[move] or move == "FLY" then return originalRun(world, result) end
      -- Preserve native effect parameters and delayed callbacks. These effects
      -- use mon only for the nickname buffer and Strength cry. Suppress identity
      -- in GENERIC/fallback while keeping the native resolver's real actor.
      local presented = shallowCopy(result)
      presented.mon = policy.mode() == "known_move"
        and policy.known(world.game.save.party, move) or nil
      presented.text = policy.message(world.game, move)
      if move == "STRENGTH" then presented.after = policy.boulders(world.game) end
      return originalRun(world, presented)
    end
  end)

  local function useFromStart(game, move)
    -- Gen 2, unlike Gen 1, keeps START open before calling onSelect.
    -- Close only the menu we own; never pop a battle or another screen.
    local menu = game.stack and game.stack:top()
    if getmetatable(menu) ~= StartMenu then return end
    menu:close()
    local world = game.world
    if not world or not world:acceptsMenuInput() then return end
    if move == "LIGHT" then return light.manual(game) end
    if move == "FLY" then
      return townMap.gen2(game, world, policy.user(game.save.party, "FLY"), function()
        return unlocked(game.save, "FLY") and policy.first(game.save.party) ~= nil
      end)
    end
    if not unlocked(game.save, move) then return end
    local mon = FieldMoves.partyMoveUser(game.save.party, move,
      { save = game.save, data = game.data })
    if not mon then return end
    -- FLASH keeps the native party queue and Ruins of Alph wall logic.
    -- Do not probe availableFieldActions here: its Flash availability check
    -- can itself invoke the Aerodactyl-wall callback in this engine version.
    world:useFieldMove(move, mon)
  end

  mod.hooks:wrap("ui.start_menu.items", function(next, game, rows)
    local out = next(game, rows)
    if type(out) ~= "table" then return out end
    for _, move in ipairs({ "FLY", "LIGHT", "FLASH" }) do
      if (move == "FLY" and townMap.hasGen2Map(game))
          or (move == "LIGHT" and light.visible(game))
          or (move == "FLASH" and light.special(game) and unlocked(game.save, move) and policy.first(game.save.party)) then
        mod.ui.insertBefore(out, "SAVE", {
          -- Crystal allows seven label tiles and ten per description line.
          label = move == "FLY" and "MAP" or move,
          desc = move == "FLY" and { "View the", "map." }
            or (move == "LIGHT" and { "Light the", "cave." } or { "Use FLASH", "here." }),
          onSelect = function() useFromStart(game, move) end,
        })
      end
    end
    return out
  end)
end

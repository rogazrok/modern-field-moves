-- Crystal adapter. Native A-button interactions already
-- implement Cut, Surf, Strength, Whirlpool and Waterfall with their prompts.
return function(mod, policy, townMap)
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
    local id = items[move]
    -- HMs are reusable and cannot normally be tossed. Count both the bag
    -- and PC so depositing one does not remove the field ability.
    return (owns(save.inventory, id) or owns(save.pcItems, id) or policy.badgeOnly())
      and FieldMoves.hasBadge(save, FieldMoves.BADGE[move])
  end

  local function firstPokemon(party)
    for _, mon in ipairs(party or {}) do
      if not mon.egg then return mon end
    end
  end

  mod.hooks:wrap("fieldmove.eligibility", function(next, moveId, ctx)
    local mon, slot = next(moveId, ctx)
    if not items[moveId] then return mon, slot end
    local save = (ctx and ctx.save) or (mod.game and mod.game.save)
    if not unlocked(save, moveId) then return nil end
    local party = (ctx and ctx.party) or (save and save.party)
    return policy.user(party, moveId)
  end)

  local World = require("src.world.gen2.World")
  local originalUse = World.useFieldMove
  World.useFieldMove = function(world, move, mon)
    -- Crystal's party menu otherwise trusts a learned move and bypasses the
    -- eligibility hook. Apply the same selected requirement on that route.
    if items[move] and world.map and world.player and not world.battleActive
        and not world:busy() and not unlocked(world.game.save, move) then
      local text = not FieldMoves.hasBadge(world.game.save, FieldMoves.BADGE[move])
        and FieldMoves.TEXT.BADGE_REQUIRED or "An HM is required\nto use this."
      world:showText(text)
      return { ok = false, text = text }
    end
    return originalUse(world, move, mon)
  end
  local originalRun = World.runFieldMove
  World.runFieldMove = function(world, result)
    local move = result and type(result.action) == "string" and result.action:upper()
    if not items[move] or move == "FLY" then return originalRun(world, result) end
    -- Copy the action, not the Pokemon. Preserve every native effect parameter
    -- and delayed callback; only the presentation and chosen user change.
    local presented = {}
    for key, value in pairs(result) do presented[key] = value end
    presented.mon = policy.user(world.game.save.party, move)
    presented.text = policy.message(world.game, move)
    if move == "STRENGTH" then presented.after = policy.boulders(world.game) end
    return originalRun(world, presented)
  end

  local function useFromStart(game, move)
    -- Gen 2, unlike Gen 1, keeps START open before calling onSelect.
    -- Close only the menu we own; never pop a battle or another screen.
    local menu = game.stack and game.stack:top()
    if getmetatable(menu) ~= StartMenu then return end
    menu:close()
    local world = game.world
    if not world or not world:acceptsMenuInput() then return end
    if move == "FLY" then
      return townMap.crystal(game, world, policy.user(game.save.party, "FLY"), function()
        return unlocked(game.save, "FLY") and firstPokemon(game.save.party) ~= nil
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
    for _, move in ipairs({ "FLY", "FLASH" }) do
      if (move == "FLY" and townMap.hasCrystalMap(game))
          or (move == "FLASH" and unlocked(game.save, move) and firstPokemon(game.save.party)) then
        mod.ui.insertBefore(out, "SAVE", {
          -- Crystal allows seven label tiles and ten per description line.
          label = move == "FLY" and "MAP" or move,
          desc = move == "FLY" and { "View the", "map." }
            or { "Light a", "dark cave." },
          onSelect = function() useFromStart(game, move) end,
        })
      end
    end
    return out
  end)
end

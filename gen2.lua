-- Crystal adapter. Native A-button interactions already
-- implement Cut, Surf, Strength, Whirlpool and Waterfall with their prompts.
return function(mod)
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
    return (owns(save.inventory, id) or owns(save.pcItems, id))
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
    if mon and not mon.egg then return mon, slot end
    local party = (ctx and ctx.party) or (save and save.party)
    for index, candidate in ipairs(party or {}) do
      if not candidate.egg then return candidate, index end
    end
    return nil
  end)

  local function useFromStart(game, move)
    -- Gen 2, unlike Gen 1, keeps START open before calling onSelect.
    -- Close only the menu we own; never pop a battle or another screen.
    local menu = game.stack and game.stack:top()
    if getmetatable(menu) ~= StartMenu then return end
    menu:close()
    local world = game.world
    if not world or not world:acceptsMenuInput() then return end
    if not unlocked(game.save, move) then return end
    local mon = FieldMoves.partyMoveUser(game.save.party, move,
      { save = game.save, data = game.data })
    if not mon then return end
    if move == "FLY" and #world:flyPoints() == 0 then
      world:showText("No destination\nfor FLY yet.")
      return
    end
    -- The same queue as the native party menu: FLY opens the native
    -- Pokegear fly map and FLASH keeps Crystal's Ruins of Alph wall logic.
    -- Do not probe availableFieldActions here: its Flash availability check
    -- can itself invoke the Aerodactyl-wall callback in this engine version.
    world:useFieldMove(move, mon)
  end

  mod.hooks:wrap("ui.start_menu.items", function(next, game, rows)
    local out = next(game, rows)
    if type(out) ~= "table" then return out end
    for _, move in ipairs({ "FLY", "FLASH" }) do
      if unlocked(game.save, move) and firstPokemon(game.save.party) then
        mod.ui.insertBefore(out, "SAVE", {
          label = move,
          desc = move == "FLY" and { "Fly to a", "visited town." }
            or { "Light a", "dark cave." },
          onSelect = function() useFromStart(game, move) end,
        })
      end
    end
    return out
  end)
end

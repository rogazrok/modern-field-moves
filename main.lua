return function(mod)
  assert(mod.world and type(mod.world.useFieldAction) == "function"
      and type(mod.world.availableFieldActions) == "function"
      and type(mod.world.flyTo) == "function",
    "Field Moves Red requires gen1recomp's field-action and Fly APIs")

  local gates = {
    SURF = { badge = "SOULBADGE", item = "HM_SURF", flag = "EVENT_GOT_HM03" },
    FLY = { badge = "THUNDERBADGE", item = "HM_FLY", flag = "EVENT_GOT_HM02" },
  }
  local game
  mod.events:on("game.ready", function(ctx) game = ctx.game end)

  local function unlocked(save, move)
    if not save then return false end
    local gate = gates[move]
    local inventory = save.inventory or {}
    local badge = inventory[gate.badge]
    local hasBadge = badge == true or (type(badge) == "number" and badge > 0)
    local hm = inventory[gate.item]
    local hasHM = (save.flags or {})[gate.flag] == true
      or (type(hm) == "number" and hm > 0)
    return hasBadge and hasHM and (save.party or {})[1] ~= nil
  end

  mod.hooks:wrap("fieldmove.eligibility", function(next, moveId, ctx)
    local mon = next(moveId, ctx)
    if not gates[moveId] then return mon end
    -- Keep the requested progression gate even for an imported Surf knower.
    if not unlocked(ctx.save, moveId) then return nil end
    -- Native Surf needs a real party mon for its name, not a boolean.
    -- No species restriction, move edits, PP changes, or HP requirement.
    return mon or ctx.save.party[1]
  end)

  mod.events:on("world.interacted", function(ctx)
    if ctx.kind ~= "none" or not game or not unlocked(game.save, "SURF") then
      return
    end
    for _, action in ipairs(mod.world:availableFieldActions()) do
      -- LEAVE WATER is the same action id; only offer boarding here.
      if action.id == "surf" and action.label == "SURF" then
        game.stack:push(mod.ui.TextBox.new(game,
          "The water is calm.\nSURF across?", nil, {
            choice = function(yes)
              -- TextBox closes both prompt and choice before this callback.
              -- The API rechecks terrain, progress and busy state.
              if yes then mod.world:useFieldAction("surf") end
            end,
          }))
        return
      end
    end
  end)

  mod.hooks:wrap("ui.start_menu.items", function(next, game, items)
    local out = next(game, items)
    if type(out) ~= "table" or not unlocked(game.save, "FLY") then return out end
    return mod.ui.insertBefore(out, "SAVE", {
      label = "FLY",
      -- Menu closes itself before onSelect, so the world API is not busy.
      onSelect = function()
        if not mod.world:canFly() then
          game.stack:push(mod.ui.TextBox.new(game, "Can't FLY here!"))
          return
        end
        mod.ui.push(game, "TownMap", { fly = true, onFly = function(mapId)
          local ok = mod.world:flyTo(mapId)
          if not ok then
            game.stack:push(mod.ui.TextBox.new(game, "Can't FLY here!"))
          end
        end })
      end,
    })
  end)
end

return function(mod)
  assert(mod.world and type(mod.world.useFieldAction) == "function"
      and type(mod.world.availableFieldActions) == "function"
      and type(mod.world.flyTo) == "function",
    "Field Moves Red requires gen1recomp's field-action and Fly APIs")

  local gates = {
    CUT = { badge = "CASCADEBADGE", item = "HM_CUT", flag = "EVENT_GOT_HM01" },
    SURF = { badge = "SOULBADGE", item = "HM_SURF", flag = "EVENT_GOT_HM03" },
    FLY = { badge = "THUNDERBADGE", item = "HM_FLY", flag = "EVENT_GOT_HM02" },
    STRENGTH = { badge = "RAINBOWBADGE", item = "HM_STRENGTH", flag = "EVENT_GOT_HM04" },
    FLASH = { badge = "BOULDERBADGE", item = "HM_FLASH", flag = "EVENT_GOT_HM05",
      legacyFlag = "EVENT_GOT_HM_FLASH" },
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
      or (gate.legacyFlag and (save.flags or {})[gate.legacyFlag] == true)
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

  local function confirmAction(id, text)
    game.stack:push(mod.ui.TextBox.new(game, text, nil, {
      choice = function(yes)
        -- TextBox closes both boxes before the API rechecks the action.
        if yes then mod.world:useFieldAction(id) end
      end,
    }))
  end

  -- world.talk runs before the ordinary boulder text. Only claim a real
  -- pushable object when the native API currently offers Strength.
  -- This mirrors Red's Map.isPushable definition without a private require.
  mod.hooks:wrap("world.talk", function(next, ow, target)
    local def = target and target.def
    local pushable = def and (def.pushable == true
      or (def.pushable == nil and def.sprite == "SPRITE_BOULDER"))
    if game and pushable and unlocked(game.save, "STRENGTH") then
      for _, action in ipairs(mod.world:availableFieldActions()) do
        if action.id == "strength" then
          confirmAction("strength", "Use STRENGTH?")
          return
        end
      end
    end
    return next(ow, target)
  end)

  -- QoL 1.3.0 also listens here at priority 0, but does not check whether
  -- another listener has already opened a dialog. Let it act first.
  -- availableFieldActions then returns no actions while its UI is open.
  mod.events:on("world.interacted", function(ctx)
    if ctx.kind ~= "none" or not game then
      return
    end
    for _, action in ipairs(mod.world:availableFieldActions()) do
      if action.id == "cut" and unlocked(game.save, "CUT") then
        confirmAction("cut", "Use CUT?")
        return
      end
      -- LEAVE WATER is the same action id; only offer boarding here.
      if action.id == "surf" and action.label == "SURF"
          and unlocked(game.save, "SURF") then
        confirmAction("surf", "The water is calm.\nSURF across?")
        return
      end
    end
  end, -100)

  mod.hooks:wrap("ui.start_menu.items", function(next, game, items)
    local out = next(game, items)
    if type(out) ~= "table" then return out end
    if unlocked(game.save, "FLY") then
      mod.ui.insertBefore(out, "SAVE", {
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
    end
    -- Flash stays in START; Strength is an A-button boulder interaction.
    for _, move in ipairs({ "FLASH" }) do
      if unlocked(game.save, move) then
        local id = move:lower()
        mod.ui.insertBefore(out, "SAVE", {
          label = move,
          onSelect = function()
            local ok = mod.world:useFieldAction(id)
            if not ok then
              game.stack:push(mod.ui.TextBox.new(game,
                "Can't use " .. move .. "\nhere now!"))
            end
          end,
        })
      end
    end
    return out
  end)
end

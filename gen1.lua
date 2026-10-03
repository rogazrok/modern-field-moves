return function(mod, policy, townMap, installLighting, scope)
  assert(mod.world and type(mod.world.useFieldAction) == "function"
      and type(mod.world.availableFieldActions) == "function"
      and type(mod.world.flyTo) == "function",
    "Modern Field Moves requires gen1recomp's field-action and Fly APIs")

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
    if policy.unrestricted() then return policy.first(save.party) ~= nil end
    local gate = gates[move]
    local inventory = save.inventory or {}
    local badge = inventory[gate.badge]
    local hasBadge = badge == true or (type(badge) == "number" and badge > 0)
    local hm = inventory[gate.item]
    local hasHM = (save.flags or {})[gate.flag] == true
      or (gate.legacyFlag and (save.flags or {})[gate.legacyFlag] == true)
      or (type(hm) == "number" and hm > 0)
    return policy.hmAllowed(hasHM, hasBadge) and policy.first(save.party) ~= nil
  end

  local light = installLighting(mod, policy, 1, unlocked)

  mod.hooks:wrap("fieldmove.eligibility", function(next, moveId, ctx)
    local mon, slot = next(moveId, ctx)
    if not gates[moveId] then return mon, slot end
    -- Keep the requested progression gate even for an imported Surf knower.
    local save = ctx and ctx.save
    if not unlocked(save, moveId) then return nil end
    -- Native Surf needs a real party mon for its name, not a boolean.
    -- No species restriction, move edits, PP changes, or HP requirement.
    return policy.user(save.party, moveId)
  end)

  -- Only the native field entry points see these text replacements. Battle
  -- text, move learning, and the save's party are never modified.
  local Overworld = require("src.world.OverworldController")
  local textMethods = {
    tryCut = { move = "CUT", key = "_UsedCutText" },
    trySurf = { move = "SURF", key = "_SurfingGotOnText" },
    useStrengthFieldMove = { move = "STRENGTH", key = "_UsedStrengthText" },
    useFlashFieldMove = { move = "FLASH", key = "_FlashLightsAreaText" },
  }
  for method, info in pairs(textMethods) do
    scope.wrap(Overworld, method, function(original)
      return function(ow, ...)
        local activeGame = game or mod.game
        if not activeGame then return original(ow, ...) end
        local replacements = { [info.key] = policy.message(activeGame, info.move) }
        if info.move == "STRENGTH" then
          replacements._CanMoveBouldersText = policy.boulders(activeGame)
          local _, onClose = ...
          return policy.withTexts(activeGame, replacements, original, ow,
            policy.user(activeGame.save.party, "STRENGTH"), onClose)
        end
        return policy.withTexts(activeGame, replacements, original, ow, ...)
      end
    end)
  end

  -- The ordinary world interaction path already asks before calling the
  -- field-action API. Party-menu Cut/Surf bypass that path and call the native
  -- Overworld methods directly, so guard those entry points as well. The
  -- depth marker prevents the confirmed world action from asking twice.
  local confirmedActionDepth = 0
  local function runConfirmed(action)
    confirmedActionDepth = confirmedActionDepth + 1
    local ok, result = pcall(action)
    confirmedActionDepth = confirmedActionDepth - 1
    if not ok then error(result, 0) end
    return result
  end

  local function confirmAction(id, text, action)
    local activeGame = game or mod.game
    local perform = action or function() return mod.world:useFieldAction(id) end
    if not policy.confirmContext(id) or not (activeGame and activeGame.stack) then
      return runConfirmed(perform)
    end
    activeGame.stack:push(mod.ui.TextBox.new(activeGame, text, nil, {
      choice = function(yes)
        -- TextBox closes before the API rechecks the action or the native
        -- party-menu action continues.
        if yes then runConfirmed(perform) end
      end,
    }))
    return true
  end

  local menuPrompts = {
    tryCut = { id = "cut", eligibility = "useCutFieldMove", prompt = "Use CUT?" },
    trySurf = { id = "surf", eligibility = "useSurfFieldMove",
      prompt = "The water is calm.\nSURF across?" },
  }
  for method, info in pairs(menuPrompts) do
    scope.wrap(Overworld, method, function(original)
      return function(ow, fx, fy, onClose)
        local activeGame = game or mod.game
        if confirmedActionDepth == 0 and activeGame
            and policy.confirmContext(info.id)
            and type(ow[info.eligibility]) == "function"
            and ow[info.eligibility](ow) == "ok" then
          if method == "trySurf" then
            return confirmAction(info.id, info.prompt, function()
              return original(ow, fx, fy, onClose)
            end)
          end
          return confirmAction(info.id, info.prompt, function()
            return original(ow, fx, fy)
          end)
        end
        if method == "trySurf" then return original(ow, fx, fy, onClose) end
        return original(ow, fx, fy)
      end
    end)
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

  -- Run after other interaction listeners. An open dialogue makes the native
  -- field-action list empty, so the player receives only one prompt.
  local interactions = {
    cut = { move = "CUT", prompt = "Use CUT?" },
    -- LEAVE WATER shares this id; only offer the boarding action.
    surf = { move = "SURF", label = "SURF", prompt = "The water is calm.\nSURF across?" },
  }
  mod.events:on("world.interacted", function(ctx)
    if ctx.kind ~= "none" or not game then
      return
    end
    for _, action in ipairs(mod.world:availableFieldActions()) do
      local interaction = interactions[action.id]
      if interaction and (not interaction.label or action.label == interaction.label)
          and unlocked(game.save, interaction.move) then
        confirmAction(action.id, interaction.prompt)
        return
      end
    end
  end, -100)

  mod.hooks:wrap("ui.start_menu.items", function(next, game, items)
    local out = next(game, items)
    if type(out) ~= "table" then return out end
    if townMap.hasRedMap(game.save) then
      mod.ui.insertBefore(out, "SAVE", {
        label = "TOWN MAP",
        -- Menu closes itself before onSelect, so the world API is not busy.
        onSelect = function() townMap.red(game) end,
      })
    end
    if light.visible(game) then
      mod.ui.insertBefore(out, "SAVE", {
        label = "LIGHT",
        onSelect = function() light.manual(game) end,
      })
    end
    return out
  end)
end

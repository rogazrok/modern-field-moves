return function(mod)
  local compile = loadstring or load
  local function module(file)
    return assert(compile(assert(mod:read(file)), "@" .. mod.path .. "/" .. file))()
  end
  local policy = module("field_user.lua")(mod)
  local townMap = module("town_map.lua")(mod)
  -- Gen 2 owns A-button field interactions and uses a different save/menu
  -- model. Keep the tested Gen 1 implementation isolated from that adapter.
  if require("src.core.GameVersion").generation() == 2 then
    return module("gen2.lua")(mod, policy, townMap, module("lighting.lua"))
  end
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
    return hasBadge and (hasHM or policy.badgeOnly()) and policy.first(save.party) ~= nil
  end

  local light = module("lighting.lua")(mod, policy, 1, unlocked)

  mod.hooks:wrap("fieldmove.eligibility", function(next, moveId, ctx)
    local mon, slot = next(moveId, ctx)
    if not gates[moveId] then return mon, slot end
    -- Keep the requested progression gate even for an imported Surf knower.
    if not unlocked(ctx.save, moveId) then return nil end
    -- Native Surf needs a real party mon for its name, not a boolean.
    -- No species restriction, move edits, PP changes, or HP requirement.
    return policy.user(ctx.save.party, moveId)
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
    local original = Overworld[method]
    Overworld[method] = function(ow, ...)
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
  end

  local function confirmAction(id, text)
    if not policy.confirmPrompts() then return mod.world:useFieldAction(id) end
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
    if townMap.hasRedMap(game.save) then
      mod.ui.insertBefore(out, "SAVE", {
      label = "TOWN MAP",
      -- Menu closes itself before onSelect, so the world API is not busy.
      onSelect = function()
        townMap.red(game)
      end,
    })
    end
    if light.visible(game) then
        mod.ui.insertBefore(out, "SAVE", {
          label = "LIGHT",
          onSelect = function()
            light.manual(game)
          end,
        })
    end
    return out
  end)
end

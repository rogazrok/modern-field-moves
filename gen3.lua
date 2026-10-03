-- FireRed / LeafGreen adapter. Game3 still executes the native
-- world effects after the mod's field-move and map decisions.
return function(mod, policy)
  local GameVersion = require("src.core.GameVersion")
  local version = GameVersion.get()
  assert(version == "firered" or version == "leafgreen",
    "Modern Field Moves Gen 3 adapter requires FireRed or LeafGreen")

  local FieldMoves = require("src.core.game3.field_moves")
  local Field = require("src.core.game3.field")
  local Map = require("src.core.game3.map")
  local FieldView = require("src.core.game3.field_view")
  local Runtime = require("src.core.game3.runtime")
  local Space = require("src.core.game3.scripting.space")
  local Flags = require("src.core.game3.scripting.flags")
  local Items = require("src.core.game3.items_data")
  local Pokemon = require("src.core.game3.pokemon")
  local StartMenu = require("src.ui.game3.start_menu")
  local Message = require("src.ui.game3.message")
  local RegionMap = require("src.ui.game3.region_map")
  local Choice = require("src.ui.game3.choice")
  local Stack = require("src.ui.game3.stack")
  local RomText = require("src.core.game3.rom_text")
  local TextIR = require("src.core.game3.scripting.text_ir")
  local Game3 = require("src.core.Game3")
  local QuestLog = require("src.core.game3.quest_log_recorder")

  -- The native browse map calls dungeon preview "A GUIDE". In this mod's
  -- combined browse/Fly map, move that action to SELECT so A can remain the
  -- destination/Fly button. This is a private UI string; no ROM text is edited.
  local SELECT_GUIDE_TEXT = "mfm_SELECT_GUIDE"

  -- Game3 modules can survive a mod reload. Retire the previous generation
  -- before installing closures from this version.
  local state = FieldMoves._modernFieldMovesGen3 or FieldMoves._modernFieldMovesGen3Test
  if state and state.teardown then state.teardown() end
  if not state then
    state = {
      prompts = setmetatable({}, { __mode = "k" }),
      hookOwners = setmetatable({}, { __mode = "k" }),
    }
    FieldMoves._modernFieldMovesGen3 = state
  end
  FieldMoves._modernFieldMovesGen3 = state
  FieldMoves._modernFieldMovesGen3Test = nil
  -- 0.0.12 has no teardown contract. A normal soft restart evicts Game3/UI
  -- modules before loading this adapter. Refuse unsafe in-place replacement of
  -- an old module table instead of stacking over its opaque closures.
  assert(not state.directInstalled and not state.mapInputInstalled,
    "Modern Field Moves update requires APPLY & RESTART")
  local previousGuideText = RomText.overrides[SELECT_GUIDE_TEXT]
  local guideText = TextIR.fromAscii("SEL GUIDE")
  state.prompts = setmetatable({}, { __mode = "k" })
  state.hookOwners = setmetatable({}, { __mode = "k" })
  state.activeTownMap = nil
  state.flyPromptContext = nil
  state.policy = policy
  -- A hot reload must not retain a token from an interrupted Fly transition.
  state.skipFlyIntroMon = nil
  local originals = {}
  local generation = { active = true }
  -- Keep the native slot and our replacement together. A later mod's wrapper
  -- must not be overwritten when this generation is retired.
  local function installDirect(owner, key, wrapped)
    originals[#originals + 1] = { owner, key, owner[key], wrapped = wrapped }
    owner[key] = wrapped
  end
  local function currentPolicy() return state.policy end

  local CAPABILITIES = {
    CUT = { hm = 1, method = "tryCutOW" },
    FLY = { hm = 2 },
    SURF = { hm = 3, method = "trySurfOW" },
    STRENGTH = { hm = 4, method = "tryStrengthOW" },
    FLASH = { hm = 5 },
    ROCK_SMASH = { hm = 6, method = "tryRockSmashOW" },
    WATERFALL = { hm = 7, method = "tryWaterfallOW" },
  }
  local function session() return Runtime.getSession() end

  -- Read the real TM Case and PC slots without calling Bag.has(), whose
  -- migration/normalization can mutate the bag on a read.
  local function contains(slots, itemId)
    for _, slot in ipairs(slots or {}) do
      if Items.toNumericId(slot.id) == itemId and (tonumber(slot.qty) or 0) > 0 then
        return true
      end
    end
    return false
  end

  local function ownsHM(s, move)
    local capability = CAPABILITIES[move]
    if not (s and capability) then return false end
    local itemId = Items.FIRST_HM + capability.hm - 1
    return contains(s.bag and s.bag.pockets and s.bag.pockets.TM_CASE, itemId)
      or contains(s.storage and s.storage.items, itemId)
  end

  local function hasBadge(s, move)
    local id = FieldMoves.BADGE_FLAGS[move]
    local store = Space.store or { flags = (s and s.flags) or {} }
    return Flags.getFlag(store, nil, id)
  end

  local function unlocked(s, move)
    return s and currentPolicy().hmAllowed(ownsHM(s, move), hasBadge(s, move)) or false
  end

  -- Numeric IDs, native Egg detection and zero-based party slots remain
  -- engine-specific; selection and fallback use the shared policy.
  local function actorRules(move)
    return { isEgg = Pokemon.isEgg, normalizeMove = FieldMoves.normalizeMoveId,
      moveId = FieldMoves.MOVES[move], slotBase = 0 }
  end
  local function actor(party, move)
    return currentPolicy().user(party, move, actorRules(move))
  end
  local function knowsMove(mon, move)
    return policy.common.knows(mon, move, actorRules(move))
  end
  local function presentsKnownMove(move, mon)
    return currentPolicy().mode() == "known_move" and knowsMove(mon, move)
  end

  local function presentation(move, mon, knownUser)
    local label = move:gsub("_", " ")
    if not knownUser then return label .. " was used!" end
    return FieldMoves.getMonName(mon) .. " used " .. label .. "!"
  end

  local copy = policy.common.copy

  -- Native badge checks only read ctx.store.flags. An overlay answers that
  -- one lookup for UNRESTRICTED without touching any saved flag or event.
  local function nativeContext(ctx, move, mon)
    ctx = type(ctx) == "table" and ctx or {}
    local out = copy(ctx)
    out.mon = mon
    local s = ctx.session or session()
    if currentPolicy().unrestricted() and not hasBadge(s, move) then
      local originalStore = type(ctx.store) == "table" and ctx.store
        or type(Space.store) == "table" and Space.store
        or { flags = (s and s.flags) or {} }
      out.store = copy(originalStore)
      out.store.flags = setmetatable({ [FieldMoves.BADGE_FLAGS[move]] = true },
        { __index = type(originalStore.flags) == "table" and originalStore.flags or {} })
    end
    return out
  end

  -- The five native overworld resolvers call partyMoveUser synchronously.
  -- Restore its exact previous function even if a resolver raises an error.
  local function resolveWithActor(original, ctx, move, mon, slot)
    local previous = FieldMoves.partyMoveUser
    local resolver = function(party, requested)
      if FieldMoves.normalizeMoveId(requested) == FieldMoves.MOVES[move] then
        return mon, slot
      end
      return previous(party, requested)
    end
    return policy.common.withValue(FieldMoves, "partyMoveUser", resolver,
      original, nativeContext(ctx, move, mon))
  end

  local function presentResult(result, move, mon)
    if not (result and result.ok) then return result end
    result = copy(result)
    local knownUser = presentsKnownMove(move, mon)
    result.mon = mon
    result._mfmFieldMove = true
    result._mfmGeneric = not knownUser
    result._mfmShowIntro = knownUser
    -- Surf already asks for confirmation and shows the boarding animation.
    -- A separate "SURF was used!" box after boarding adds no information.
    if move == "SURF" then
      result.text = nil
    else
      result.text = presentation(move, mon, knownUser)
    end
    return result
  end

  local function hasTownMap(s)
    if not s then return false end
    local bag = s.bag and s.bag.pockets
    local townMapId = Items.toNumericId("TOWN_MAP")
    return townMapId ~= nil and (contains(bag and bag.KEY_ITEMS, townMapId)
      or contains(s.storage and s.storage.items, townMapId))
  end

  local function flyReady(s)
    return s and unlocked(s, "FLY") == true
  end

  local function regionGroup(region)
    return tonumber(region) == 0 and "kanto" or "sevii"
  end

  local function seviiReturnUnlocked(s)
    -- pokefirered OneIsland_PokemonCenter_1F: Bill's return scene sets this
    -- scene var to 3 immediately before sailing back to Cinnabar. The detour
    -- flag alone is set earlier and must not unlock an early escape.
    local store = Space.store or { flags = s and s.flags, vars = s and s.vars }
    return Flags.getFlag(store, nil, Flags.IDS.SEVII_DETOUR_FINISHED)
      and (tonumber(Flags.getVar(store, nil,
        Flags.VAR_IDS.MAP_SCENE_ONE_ISLAND_POKEMON_CENTER_1F)) or 0) >= 3
  end

  local function crossRegionAllowed(originRegion, targetRegion, s)
    if regionGroup(originRegion) == regionGroup(targetRegion) then return true end
    return currentPolicy().crossRegionFly() == "enabled" and seviiReturnUnlocked(s)
  end

  local function nativeCanFly(s, mon)
    if not (s and mon and Field.running) then return false end
    -- The current WorldAPI.canFly() passes mapDef.type to flyFromMenu, while
    -- the native map header/party menu use mapDef.mapType. Query the same
    -- native Fly resolver with that real header field and the chosen actor.
    local def = Map.currentDef()
    if not def then return false end
    local ctx = nativeContext({ session = s, store = Space.store,
      party = s.party, mapType = def.mapType }, "FLY", mon)
    local ok, result = pcall(FieldMoves.flyFromMenu, ctx)
    return ok and result and result.ok == true or false
  end

  -- These are the native switch/cancel button cells in region_map.lua. The
  -- Gen3 API does not export them; keep the source-backed coordinates local.
  local MAP_CANCEL_X, MAP_CANCEL_Y = 21, 13
  local MAP_SWITCH_X, MAP_SWITCH_Y = 21, 11

  local function flySelection(ctx, mapState)
    if not (ctx and ctx.flyEnabled and mapState and RegionMap.isOpen()
        and mapState.mainTask == "regionMap" and mapState.task == "regionMap"
        and RegionMap.inputReady()) then return nil end
    if RegionMap.cursorX == MAP_CANCEL_X and RegionMap.cursorY == MAP_CANCEL_Y then return nil end
    if RegionMap.cursorX == MAP_SWITCH_X and RegionMap.cursorY == MAP_SWITCH_Y
        and mapState.perms.switchButton then return nil end
    local section = RegionMap.currentMapSec()
    local locationName = RegionMap.currentLocationName()
    if not (section and locationName) then return nil end
    -- A town and its landmark can occupy the same cursor cell (for example,
    -- Lavender Town and Pokémon Tower). The native browse map prefers GUIDE
    -- for that overlap, but a real Fly destination must still be selectable.
    -- Non-destination dungeon cells remain browse/preview-only below.
    if RegionMap.selectedMapsecType() ~= RegionMap.MAPSECTYPE.VISITED then return nil end
    if not crossRegionAllowed(ctx.originRegion, mapState.selectedRegion, ctx.session) then return nil end
    local ok, destination = pcall(Field.flyDestination, section)
    if not ok or not destination then return nil end
    local areaOk, blocked = pcall(RegionMap.flyBlockedByMapType)
    if not areaOk or blocked or not nativeCanFly(ctx.session, ctx.mon) then return nil end
    return section, locationName
  end

  local function updateFlyOverlay(ctx, mapState)
    if not (ctx and mapState) then return end
    -- Keep native destination data and mapsec types, including the special
    -- Route 4 Pokémon Center, but leave the browse map free of Fly wings.
    -- Native tasks may reveal the icons again during opening/page switches.
    for _, icon in ipairs(mapState.icons and mapState.icons.fly or {}) do
      icon.visible = false
    end
    if not (ctx.flyEnabled and mapState.mainTask == "regionMap"
        and mapState.task == "regionMap") then return end
    if flySelection(ctx, mapState) then
      mapState.topBar.right = "gText_RegionMap_AButtonOK"
    end
  end

  local function returnToPartyFlyMenu(fromParty)
    if not fromParty then return end
    Field.locked = false
    local PartyMenu = require("src.ui.game3.party_menu")
    if PartyMenu.returnFromFlyMap then PartyMenu.returnFromFlyMap() end
  end

  local function flyAfterMapClose(section, mon, originRegion, targetRegion, s, fromParty, priorLock)
    local destination = Field.flyDestination(section)
    local visited = RegionMap.mapsecType(section) == RegionMap.MAPSECTYPE.VISITED
    if section == "MAPSEC_ROUTE_4_POKECENTER" then
      visited = RegionMap.isFlagSet("FLAG_WORLD_MAP_ROUTE4_POKEMON_CENTER_1F")
    end
    if not (destination and visited and crossRegionAllowed(originRegion, targetRegion, s)
        and flyReady(s) and nativeCanFly(s, mon)) then
      returnToPartyFlyMenu(fromParty)
      if not fromParty then Field.locked = false end
      return false
    end
    local previousLock = priorLock
    if previousLock == nil then previousLock = Field.locked end
    Field.locked = true
    -- Fly's ShowMon splash starts later inside a fade callback, after this
    -- call returns. Keep a one-use token for that exact actor only.
    state.skipFlyIntroMon = not presentsKnownMove("FLY", mon) and mon or nil
    local ok, result = pcall(Field.flyTo, section, mon)
    if not ok or not (love and love.graphics) then state.skipFlyIntroMon = nil end
    if not ok then
      Field.locked = previousLock
      state.activeTownMap, state.flyPromptContext = nil, nil
      error(result, 0)
    end
    return true
  end

  local FLY_PROMPT_ID = "mfm_fly_prompt"
  local function cancelInput()
    return {
      wasPressed = function(_, key) return key == "b" end,
      isDown = function() return false end,
    }
  end
  local function neutralInput()
    return {
      wasPressed = function() return false end,
      isDown = function() return false end,
    }
  end
  local function closeFlyPrompt(context)
    if state.flyPromptContext ~= context then return end
    state.flyPromptContext = nil
    if Choice.active then Choice.reset() end
    if Message.isOpen() then Message.close() end
    Stack.pop(FLY_PROMPT_ID)
  end
  local flyPromptLayer = {}
  function flyPromptLayer.update()
    if state.flyPromptContext and Message.isOpen() then Message.tick() end
  end
  function flyPromptLayer.draw()
    if not state.flyPromptContext then return end
    if Message.isOpen() then Message.draw() end
    if Choice.active then Choice.draw() end
  end
  function flyPromptLayer.handleInput(input)
    local context = state.flyPromptContext
    if not (context and input) then return end
    if Choice.active then
      if input:wasPressed("up") then Choice.move(-1, 0)
      elseif input:wasPressed("down") then Choice.move(1, 0)
      elseif input:wasPressed("a") then Choice.confirm()
      elseif input:wasPressed("b") then Choice.cancel() end
      return
    end
    if not Message.isOpen() then return end
    Message.setSpeedUp(input.isDown and (input:isDown("a") or input:isDown("b")))
    local aPress, bPress = input:wasPressed("a"), input:wasPressed("b")
    if not (aPress or bPress) then return end
    if not Message.isWaiting() then Message.advance(); return end
    if bPress then closeFlyPrompt(context); return end
    Choice.yesNo(function(yes)
      if not yes then closeFlyPrompt(context); return end
      local selected = context.promptSelection
      closeFlyPrompt(context)
      if not selected then return end
      context.pendingFly = selected.section
      context.targetRegion = selected.region
      context.previousFlyLock = Field.locked
      Field.locked = true
      -- The native close animation runs only after YES. NO keeps the map,
      -- region page and cursor exactly where they were.
      RegionMap.handleInput(cancelInput())
    end)
  end
  local function showFlyPrompt(context, section, name, region)
    context.promptSelection = { section = section, region = region }
    state.flyPromptContext = context
    Message.showStay("FLY TO " .. name .. "?")
    Stack.push(FLY_PROMPT_ID, flyPromptLayer,
      { drawUnder = true, hideBelow = false, fullscreen = true })
  end

  local function openTownMap(s, preferredFlyMon, fromParty)
    local canFly = flyReady(s)
    local flyMon = preferredFlyMon or (canFly and actor(s.party, "FLY") or nil)
    local context = { session = s, mon = flyMon, fromParty = fromParty == true,
      flyEnabled = false }
    state.activeTownMap = context
    RegionMap.show({
      session = s,
      mode = "normal",
      onClose = function()
        closeFlyPrompt(context)
        state.activeTownMap = nil
        if context.pendingFly then
          flyAfterMapClose(context.pendingFly, context.mon, context.originRegion,
            context.targetRegion, context.session, context.fromParty,
            context.previousFlyLock)
        elseif context.fromParty then
          returnToPartyFlyMenu(true)
        end
      end,
    })
    local mapState = RegionMap.state()
    context.originRegion = mapState and mapState.playersRegion
    context.flyEnabled = canFly and flyMon ~= nil and nativeCanFly(s, flyMon)
    if context.flyEnabled and mapState then
      -- Retain native visited-section classification without drawing wings.
      mapState.perms.flyDestinations = true
    end
    updateFlyOverlay(context, mapState)
  end

  -- Map input and field execution have separate ownership slots; teardown
  -- restores both before a fresh generation installs its closures.
  if not state.mapInputInstalled then
    local nativeHandleMapInput = RegionMap.handleInput
    local function guideInput(input, activateGuide, suppressGuide)
      if not (activateGuide or suppressGuide) then return input end
      return {
        wasPressed = function(_, key)
          if key == "a" then
            if activateGuide then return true end
            if suppressGuide then return false end
          end
          return input and input.wasPressed and input:wasPressed(key) or false
        end,
        isDown = function(_, key)
          return input and input.isDown and input:isDown(key) or false
        end,
      }
    end
    installDirect(RegionMap, "handleInput", function(input, ...)
      if not generation.active then return nativeHandleMapInput(input, ...) end
      local context = state.activeTownMap
      local mapState = RegionMap.state()
      local pressedA = input and input.wasPressed and input:wasPressed("a") or false
      if pressedA then
        local section, locationName = flySelection(context, mapState)
        if section then
          showFlyPrompt(context, section, locationName, mapState.selectedRegion)
          local result = nativeHandleMapInput(neutralInput(), ...)
          updateFlyOverlay(state.activeTownMap, RegionMap.state())
          return result
        end
      end
      local guideAvailable = context and mapState and mapState.mainTask == "regionMap"
        and mapState.task == "regionMap" and RegionMap.isOpen() and RegionMap.inputReady()
        and RegionMap.canGuideCursor and RegionMap.canGuideCursor()
      local pressedSelect = input and input.wasPressed
        and input:wasPressed("select") or false
      local activateGuide = guideAvailable and pressedSelect
      local suppressGuide = guideAvailable and pressedA
      local result = nativeHandleMapInput(guideInput(input, activateGuide, suppressGuide), ...)
      mapState = RegionMap.state()
      updateFlyOverlay(state.activeTownMap, mapState)
      if state.activeTownMap and mapState and mapState.topBar
          and mapState.topBar.right == "gText_RegionMap_AButtonGuide"
          and RegionMap.canGuideCursor and RegionMap.canGuideCursor() then
        mapState.topBar.right = SELECT_GUIDE_TEXT
      end
      return result
    end)
    state.mapInputInstalled = true
  end

  local function wrapContextual(original, move)
    return function(ctx)
      if not generation.active then return original(ctx) end
      local s = (ctx and ctx.session) or session()
      if not (s and unlocked(s, move)) then
        -- Keep all native context so special map behavior still runs.
        local unavailable = copy(ctx)
        unavailable.party = {}
        return original(unavailable)
      end
      local mon, slot = actor((ctx and ctx.party) or s.party, move)
      if not mon then
        local unavailable = copy(ctx)
        unavailable.party = {}
        return original(unavailable)
      end
      local result = presentResult(
        resolveWithActor(original, ctx, move, mon, slot), move, mon)
      if result and result.ok and result.ask
          and not currentPolicy().confirmContext(move) then
        local token = {}
        state.prompts[token] = result
        result.ask = token
      end
      return result
    end
  end

  if not state.directInstalled then
    -- Only marked field-move prompts take this path. Every other message,
    -- including story scripts, is delegated to the exact prior function.
    local originalShow = Message.show
    installDirect(Message, "show", function(text, ...)
      if not generation.active then return originalShow(text, ...) end
      local payload = type(text) == "table" and state.prompts[text]
      if payload then
        state.prompts[text] = nil
        return Field.executeFieldMove(payload)
      end
      return originalShow(text, ...)
    end)

    for _, spec in ipairs({ { "tryCutOW", "CUT" },
        { "tryRockSmashOW", "ROCK_SMASH" },
        { "tryStrengthOW", "STRENGTH" }, { "trySurfOW", "SURF" },
        { "tryWaterfallOW", "WATERFALL" } }) do
      local name, move = spec[1], spec[2]
      local original = FieldMoves[name]
      installDirect(FieldMoves, name, wrapContextual(original, move))
    end

    -- GENERIC and KNOWN MOVE fallback skip the Pokémon splash. A genuine
    -- KNOWN MOVE user retains it. The callback always starts the world effect.
    local ShowMon = require("src.core.game3.field_move_show_mon")
    local nativeShowMonStart = ShowMon.start
    installDirect(ShowMon, "start", function(mon, opts, onDone)
      if not generation.active then return nativeShowMonStart(mon, opts, onDone) end
      local skipFly = state.skipFlyIntroMon and state.skipFlyIntroMon == mon
      if skipFly then state.skipFlyIntroMon = nil end
      if (state.activeFieldMove and not state.showFieldMoveIntro) or skipFly then
        if type(onDone) == "function" then onDone() end
        return true
      end
      return nativeShowMonStart(mon, opts, onDone)
    end)

    -- The party-menu Fly map can still be used without a Town Map. Its
    -- destination callback calls Field.flyTo directly, so arm the same
    -- one-use intro bypass at the actual flight, not while browsing.
    local nativeFlyTo = Field.flyTo
    installDirect(Field, "flyTo", function(section, mon, ...)
      if not generation.active then return nativeFlyTo(section, mon, ...) end
      local previousLock = Field.locked
      state.skipFlyIntroMon = not presentsKnownMove("FLY", mon) and mon or nil
      -- Native flight needs the real actor for its animation. Only its
      -- synchronous Quest Log event receives the anonymous presentation.
      local originalEvent = QuestLog.event
      if not presentsKnownMove("FLY", mon) then
        QuestLog.event = function(recordSession, key, args)
          if key == "UsedFly" and type(args) == "table" then
            args = copy(args)
            args[1] = "POKéMON"
          end
          return originalEvent(recordSession, key, args)
        end
      end
      local result = policy.common.pack(pcall(nativeFlyTo, section, mon, ...))
      QuestLog.event = originalEvent
      if not result[1] or not (love and love.graphics) then
        state.skipFlyIntroMon = nil
      end
      if not result[1] then
        Field.locked = previousLock
        if state.flyPromptContext then closeFlyPrompt(state.flyPromptContext) end
        state.activeTownMap, state.flyPromptContext = nil, nil
        error(result[2], 0)
      end
      return unpack(result, 2, result.n)
    end)

    local nativeExecute = Field.executeFieldMove
    installDirect(Field, "executeFieldMove", function(payload, ...)
      if not generation.active then return nativeExecute(payload, ...) end
      -- New direct field action invalidates any abandoned Fly intro token.
      state.skipFlyIntroMon = nil
      -- If Fly was selected from the party menu, reuse the owned Town Map's
      -- browse-and-travel screen so the native Sevii page switch is available.
      -- Without a Town Map, leave the game's original Fly map untouched.
      if type(payload) == "table" and payload.action == "fly" then
        local s = session()
        local flyMon = payload.mon or (s and actor(s.party, "FLY"))
        if hasTownMap(s) and flyReady(s) and nativeCanFly(s, flyMon) then
          openTownMap(s, flyMon, true)
          Field.locked = true
          return
        end
      end
      if type(payload) ~= "table" or payload._mfmFieldMove ~= true then
        return nativeExecute(payload, ...)
      end
      local previousActive, previousIntro = state.activeFieldMove, state.showFieldMoveIntro
      state.activeFieldMove = true
      state.showFieldMoveIntro = payload._mfmShowIntro == true
      local executePayload = payload
      if payload._mfmGeneric then
        executePayload = copy(payload)
        -- The native executor only needs a Pokémon for its ShowMon/quest text;
        -- GENERIC skips ShowMon and the native log's neutral fallback is POKéMON.
        executePayload.mon = nil
      end
      local result = policy.common.pack(pcall(nativeExecute, executePayload, ...))
      state.activeFieldMove, state.showFieldMoveIntro = previousActive, previousIntro
      if not result[1] then error(result[2], 0) end
      return unpack(result, 2, result.n)
    end)

    -- The party menu already identifies a Pokémon by its highlighted row.
    -- Honor that explicit choice; FIELD MOVE USER controls contextual moves.
    local nativeFromMenu = FieldMoves.fromMenu
    installDirect(FieldMoves, "fromMenu", function(moveId, ctx)
      if not generation.active then return nativeFromMenu(moveId, ctx) end
      local move = FieldMoves.MOVE_NAME_BY_ID[FieldMoves.normalizeMoveId(moveId)]
      if not (CAPABILITIES[move] and (CAPABILITIES[move].method or move == "FLASH")) then
        return nativeFromMenu(moveId, ctx)
      end
      local s = (ctx and ctx.session) or session()
      if not (s and unlocked(s, move)) then
        return { ok = false, text = FieldMoves.TEXT.CANT_USE_HERE }
      end
      local mon = ctx and ctx.mon
      if not mon or Pokemon.isEgg(mon) then
        mon = actor((ctx and ctx.party) or s.party, move)
      end
      if not mon then return { ok = false, text = FieldMoves.TEXT.CANT_USE_HERE } end
      return presentResult(nativeFromMenu(moveId, nativeContext(ctx, move, mon)),
        move, mon)
    end)
    state.directInstalled = true
  end

  local function dark(s)
    return s and Field.running and (tonumber(FieldView.getFlashLevel()) or 0) > 0
      and not Flags.getFlag(Space.store or { flags = s.flags }, nil,
        FieldMoves.SYS_FLAGS.FLASH_ACTIVE)
  end

  local function lightResult(s)
    if not (dark(s) and unlocked(s, "FLASH")) then return nil end
    local mon = actor(s.party, "FLASH")
    if not mon then return nil end
    return FieldMoves.fromMenu("FLASH", {
      party = s.party, mon = mon, session = s, store = Space.store,
      isCave = true, isDarkCave = true,
    })
  end

  local function useLight(s, automatic)
    if Field.locked or not Runtime.isActive() then return false end
    local result = lightResult(s)
    if not (result and result.ok) then return false end
    if automatic then
      result = copy(result)
      result.text = nil
    end
    Field.executeFieldMove(result)
    return true
  end

  if state.hookOwners[mod.hooks] then return end
  state.hookOwners[mod.hooks] = true

  local hookRemovers = {}
  hookRemovers[#hookRemovers + 1] = mod.hooks:wrap("ui.start_menu.items", function(next, game, rows)
    if not generation.active then return next(game, rows) end
    local out = next(game, rows)
    local s = session()
    if type(out) ~= "table" then return out end
    if hasTownMap(s) then
      for index, row in ipairs(out) do
        if row.id == "save" then
          table.insert(out, index, {
            id = "mfm_town_map", label = "TOWN MAP",
            onSelect = function()
              StartMenu.close()
              openTownMap(session())
            end,
          })
          break
        end
      end
    end
    if currentPolicy().autoLight() or not lightResult(s) then return out end
    for index, row in ipairs(out) do
      if row.id == "save" then
        table.insert(out, index, {
          id = "mfm_light", label = "LIGHT",
          onSelect = function()
            StartMenu.close()
            useLight(session(), false)
          end,
        })
        break
      end
    end
    return out
  end)

  local autoMap
  hookRemovers[#hookRemovers + 1] = mod.hooks:wrap("input.step", function(next, game, dt)
    if not generation.active then return next(game, dt) end
    local result = next(game, dt)
    local s = session()
    if not currentPolicy().autoLight() or not dark(s) then
      autoMap = nil
      return result
    end
    if autoMap == s.map or game.phase ~= "field" or Field.locked then
      return result
    end
    local VM = Space.vm
    if (Stack.top and Stack.top()) or (VM and VM.isRunning and VM:isRunning()) then
      return result
    end
    if useLight(s, true) then autoMap = s.map end
    return result
  end)

  -- APPLY & RESTART and title exit call Game3:reset. Restore exact native
  -- function slots before the next loader decides whether this mod is enabled.
  local nativeReset, nativeReturnToTitle = Game3.reset, Game3.returnToTitle
  local resetWrapper, titleWrapper
  local function clearTransient()
    if state.flyPromptContext then closeFlyPrompt(state.flyPromptContext) end
    if state.activeTownMap then state.activeTownMap.pendingFly = nil end
    state.activeTownMap, state.flyPromptContext = nil, nil
    state.skipFlyIntroMon, state.activeFieldMove = nil, nil
    state.showFieldMoveIntro = nil
    state.prompts = setmetatable({}, { __mode = "k" })
  end
  local function teardown()
    generation.active = false
    clearTransient()
    if RomText.overrides[SELECT_GUIDE_TEXT] == guideText then
      RomText.overrides[SELECT_GUIDE_TEXT] = previousGuideText
    end
    policy.dispose()
    for _, remove in ipairs(hookRemovers) do
      if type(remove) == "function" then remove() end
    end
    for i = #originals, 1, -1 do
      local entry = originals[i]
      -- Never overwrite a later owner's replacement.
      if entry[1][entry[2]] == entry.wrapped then
        entry[1][entry[2]] = entry[3]
      end
    end
    state.directInstalled, state.mapInputInstalled = nil, nil
    state.teardown = nil
  end
  resetWrapper = function(self, ...)
    teardown()
    return nativeReset(self, ...)
  end
  titleWrapper = function(self, ...)
    clearTransient()
    return nativeReturnToTitle(self, ...)
  end
  installDirect(Game3, "reset", resetWrapper)
  installDirect(Game3, "returnToTitle", titleWrapper)
  state.teardown = teardown
  RomText.overrides[SELECT_GUIDE_TEXT] = guideText

  -- Native field execution owns CUT object removal, ROCK SMASH encounters,
  -- STRENGTH/FLASH system flags, SURF boarding, WATERFALL movement and the
  -- Fly transition. The map wrapper only layers policy over native map state.
end

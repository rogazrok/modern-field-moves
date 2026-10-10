-- RSE native script, Dive and PokéNav seams. Eligibility uses scratch results,
-- never saved badge/story flags. Effects and puzzle completion stay native.
return function(api)
  local Field = require("src.core.game3.field")
  local Moves = require("src.core.game3.field_moves")
  local Space = require("src.core.game3.scripting.space")
  local Flags = require("src.core.game3.scripting.flags")
  local Ctx = require("src.core.game3.scripting.ctx")
  local Opcodes = require("src.core.game3.scripting.opcodes")
  local TextIR = require("src.core.game3.scripting.text_ir")
  local Runtime = require("src.core.game3.runtime")
  local Player = require("src.core.game3.player")
  local Map = require("src.core.game3.map")
  local Dive = require("src.core.game3.dive")
  local Effects = require("src.core.game3.field_effects")
  local Task = require("src.core.game3.task")
  local Nav = require("src.ui.game3.rse.pokenav.init")
  local NavMap = require("src.ui.game3.rse.pokenav.region_map")
  local Region = require("src.ui.game3.rse.region_map")
  local Constants = require("src.core.game3.constants").of(require("src.core.GameVersion").get())
  local state, generation = api.state, api.generation
  local withValue = api.policy().common.withValue
  local pendingIntro, diveTask, navExit

  local function wrap(owner, key, build)
    local native = owner[key]
    assert(type(native) == "function", "RSE seam missing: " .. key)
    local fn = build(native)
    api.install(owner, key, function(...)
      if not generation.active then return native(...) end
      return fn(...)
    end)
  end
  local function session() return Runtime.getSession() end
  local function flag(name, s)
    return Flags.getFlag(Space.store or { flags = s and s.flags }, nil,
      assert(Constants:flag(name), "unknown RSE flag " .. name))
  end

  -- Scope to native ordinary field scripts by imported label, never to an
  -- arbitrary script containing a yes/no or a checkpartymove command.
  local scripts = {
    EventScript_CutTree = "CUT", EventScript_UseCut = "CUT",
    EventScript_RockSmash = "ROCK_SMASH", EventScript_UseRockSmash = "ROCK_SMASH",
    EventScript_StrengthBoulder = "STRENGTH", EventScript_UseStrength = "STRENGTH",
    EventScript_UseSurf = "SURF", EventScript_UseWaterfall = "WATERFALL",
    EventScript_UseDive = "DIVE", EventScript_UseDiveUnderwater = "DIVE",
    -- pokeruby field_move_scripts.inc and object_interactions_extract RS roots.
    S_CuttableTree = "CUT", S_BreakableRock = "ROCK_SMASH",
    S_UseRockSmash = "ROCK_SMASH", S_PushableBoulder = "STRENGTH",
    S_UseStrength = "STRENGTH", S_UseWaterfall = "WATERFALL",
    S_UseDiveUnderwater = "DIVE",
  }
  local function scriptMove(vm)
    if not vm or not vm._scriptKey then return nil end
    for label, move in pairs(scripts) do
      if vm._scriptKey == Space.scriptKey(label) then return move end
    end
  end

  -- Public command hook exposes the runner. Avoid replacing the interpreter;
  -- only recognized ordinary root scripts receive these policy answers.
  api.hooks[#api.hooks + 1] = api.mod.hooks:wrap("script.command", function(next, context, name, row)
      local vm = context and context.runner
      local function native(_, command) return next(context, command.op, command) end
      if not generation.active or not vm then return next(context, name, row) end
      local move = scriptMove(vm)
      if not move then return native(vm, row) end
      local s, ctx = session(), vm.ctx
      local mon, slot = api.actor(s and s.party, move)
      local allowed = mon and api.unlocked(s, move)
      if row.op == "checkflag" and (row.flag or row[1]) == Moves.badgeFlag(move) then
        -- Native comparison result is scratch state; the real badge stays read-only.
        ctx.comparisonResult = allowed and 1 or 0
        return false
      elseif row.op == "checkpartymove" and Moves.normalizeMoveId(row[1]) == Moves.MOVES[move] then
        Flags.setVar(vm.store, ctx, Ctx.VAR_RESULT, allowed and slot or 6)
        return false
      elseif row.op == "callstd" and (row.std or row[1]) == Opcodes.STD.MSGBOX_YESNO
          and allowed and not api.policy().confirmContext(move) then
        Flags.setVar(vm.store, ctx, Ctx.VAR_RESULT, 1)
        return false
      elseif row.op == "bufferpartymonnick" and allowed and api.generic(move, mon) then
        ctx.stringVars[(row.dest or row[1] or 0) + 1] = "POKéMON"
        return false
      elseif row.op == "message" and allowed and api.generic(move, mon) then
        local ptr = row.ptr or row[1]
        if ptr == nil or ptr == 0 then ptr = ctx.data[0] end
        local ir = vm:getText(type(ptr) == "number" and Opcodes.key(ptr) or ptr)
        local text = ir and TextIR.toTextBox(ir, {
          stringVars = { [1] = "MFM_ACTOR", [2] = move:gsub("_", " ") },
        })
        -- Only the native actor-bearing used-move text is replaced. Failure,
        -- already-active, ordinary confirmation and story text remain native.
        if text and text:find("MFM_ACTOR", 1, true) then
          local genericText = function() return TextIR.fromAscii(move:gsub("_", " ") .. " was used!") end
          return withValue(vm, "getText", genericText, native, vm, row)
        end
      end
      return native(vm, row)
  end)

  -- Preserve native water selection and its target/current/waterfall tests.
  -- The temporary answers are confined to this synchronous native query.
  wrap(Field, "rseWaterScript", function(native)
    return function(...)
      local badge, user = Moves.hasBadge, Moves.partyMoveUser
      Moves.hasBadge = function(ctx, move)
        if move == "SURF" or move == "WATERFALL" then return api.unlocked(session(), move) end
        return badge(ctx, move)
      end
      Moves.partyMoveUser = function(party, move)
        if move == "SURF" then
          if api.unlocked(session(), move) then return api.actor(party, move) end
          return nil
        end
        return user(party, move)
      end
      local result = api.policy().common.pack(pcall(native, ...))
      Moves.hasBadge, Moves.partyMoveUser = badge, user
      if not result[1] then error(result[2], 0) end
      return unpack(result, 2, result.n)
    end
  end)

  for _, name in ipairs({ "tryDiveDown", "tryEmerge" }) do
    local down = name == "tryDiveDown"
    wrap(Dive, name, function(native)
      return function(...)
        local s = session()
        if not (api.unlocked(s, "DIVE") and api.actor(s and s.party, "DIVE")) then return false end
        if down and (not Player.surfing or Player.underwater) then return false end
        if not down and not Dive.isUnderwaterMap(Map.currentDef()) then return false end
        local badge = Moves.hasBadge
        local diveBadge = function(ctx, move)
          if move == "DIVE" then return true end
          return badge(ctx, move)
        end
        return withValue(Moves, "hasBadge", diveBadge, native, ...)
      end
    end)
  end

  -- One-use presentation token at the native effect boundary; it survives
  -- deferred Surf/Waterfall/Dive tasks, without changing the real actor.
  local effectMoves = {
    FLDEFF_USE_CUT_ON_TREE = "CUT", FLDEFF_USE_CUT_ON_GRASS = "CUT",
    FLDEFF_USE_ROCK_SMASH = "ROCK_SMASH", FLDEFF_USE_STRENGTH = "STRENGTH",
    FLDEFF_USE_SURF = "SURF", FLDEFF_USE_WATERFALL = "WATERFALL", FLDEFF_USE_DIVE = "DIVE",
  }
  state.rseIntro = function(mon)
    if pendingIntro and pendingIntro.mon == mon then
      local skip = not api.intro(pendingIntro.move, mon)
      pendingIntro = nil
      return skip
    end
    return false
  end
  wrap(Effects, "doFieldEffect", function(native)
    return function(id, ...)
      local move = effectMoves[Effects.fldeffName(id)]
      if move then
        local s = session()
        local mon = s and s.party and s.party[Effects.fieldEffectArgument(0, 0) + 1]
        pendingIntro = { move = move, mon = mon }
      end
      local result = api.policy().common.pack(pcall(native, id, ...))
      if not result[1] then pendingIntro = nil; error(result[2], 0) end
      if move and result[2] == false then pendingIntro = nil end
      return unpack(result, 2, result.n)
    end
  end)

  local function cleanupDive(context, insideTask)
    pendingIntro = nil
    if not context then return end
    if Dive._task == context.nativeTask then Dive._task = nil end
    Field._locks = context.locks
    Field.holdInput(context.hold)
    -- Task.update removes its own failed/completed task. Removing it here
    -- while it is running would make that scheduler remove the next task too.
    if context.task and not insideTask then Task.cancel(context.task.id) end
    if diveTask == context then diveTask = nil end
  end
  wrap(Dive, "useDive", function(native)
    return function(slot, mon)
      local s = session()
      mon = mon or (s and s.party and s.party[(tonumber(slot) or 0) + 1])
      local previous = Task.spawn
      local context = { locks = api.copy(Field._locks), hold = Field._holdInput }
      pendingIntro = { move = "DIVE", mon = mon }
      Task.spawn = function(fn, opts)
        local task = previous(function(...)
          if not generation.active then cleanupDive(context, true); return true end
          local result = api.policy().common.pack(pcall(fn, ...))
          if not result[1] then cleanupDive(context, true); error(result[2], 0) end
          if result[2] == true and diveTask == context then diveTask = nil end
          return unpack(result, 2, result.n)
        end, opts)
        context.task = task
        return task
      end
      local result = api.policy().common.pack(pcall(native, slot, mon))
      Task.spawn = previous
      context.nativeTask = Dive._task
      if not result[1] then cleanupDive(context); error(result[2], 0) end
      if result[2] then diveTask = context else pendingIntro = nil end
      return unpack(result, 2, result.n)
    end
  end)

  local function flyTarget(s, rm)
    local mon = api.actor(s and s.party, "FLY")
    if not (mon and api.unlocked(s, "FLY") and api.nativeCanFly(s, mon)) then return nil end
    local sec, pos = rm.mapSecId, rm.posWithinMapSec
    local kind = Region.mapSecType({ session = s }, sec)
    if kind ~= Region.TYPE.CITY_CANFLY and kind ~= Region.TYPE.BATTLE_FRONTIER then return nil end
    local dest = Region.flyWarpDestination(s, sec, pos)
    if not dest then
      local ok, value = pcall(Field.flyDestination, sec)
      if ok then dest = value end
    end
    if not dest then return nil end
    return { section = sec, name = Region.mapName(sec), dest = dest, mon = mon, pos = pos }
  end

  wrap(NavMap, "callback", function(native)
    return function(self, inp)
      local s, shell = self.session, self.shell
      if (inp.new or {}).select and not self.zoomDisabled and not self.exitReady
          and flag("FLAG_SYS_POKENAV_GET", s) and shell.mode == Nav.MODE.NORMAL then
        local selected = flyTarget(s, self.rm)
        if selected then
          local context = {}
          context.onConfirmed = function()
            local again = flyTarget(s, self.rm)
            if not again or again.section ~= selected.section or again.pos ~= selected.pos then return end
            local previousClose, locks = shell.onClose, api.copy(Field._locks)
            navExit = { shell = shell, close = previousClose }
            shell.onClose = function(...)
              shell.onClose, navExit = previousClose, nil
              if previousClose then previousClose(...) end
              if not generation.active then return end
              local final = flyTarget(s, self.rm)
              if not final or final.section ~= selected.section or final.pos ~= selected.pos then return end
              -- PokéNav is opened above START, which stays open on normal exit.
              -- Confirmed travel must release that parent menu before takeoff.
              local StartMenu = require("src.ui.game3.start_menu")
              if StartMenu.open and StartMenu._session == s then StartMenu.close(true) end
              local ok, err = pcall(Field.flyTo, final.section, final.mon, { dest = final.dest })
              if not ok then Field._locks = locks; error(err, 0) end
            end
            shell:shutdown()
          end
          api.prompt(context, selected.section, selected.name)
          return NavMap.FUNC.NONE
        end
      end
      return native(self, inp)
    end
  end)

  -- Keep A zoom and B return. Extend the native help text only while a real
  -- destination is selected; native header geometry and rendering are reused.
  local Gfx = require("src.ui.game3.rse.pokenav.gfx")
  local RomText = require("src.core.game3.rom_text")
  local hint = "mfm_rse_map_fly_hint"
  wrap(Gfx, "drawHelpBar", function(native)
    return function(key, y)
      local shell = Nav.active()
      if shell and shell.menuId == Nav.MENU.REGION_MAP and shell.screen
          and flag("FLAG_SYS_POKENAV_GET", shell.session)
          and flyTarget(shell.session, shell.screen.rm) then
        return withValue(RomText.overrides, hint,
          TextIR.fromAscii("A ZOOM  SEL FLY  B BACK"), native, hint, y)
      end
      return native(key, y)
    end
  end)

  -- The native party Fly screen is retained, with the same mandatory prompt.
  wrap(Region, "frame", function(native)
    return function(rm, inp)
      if rm.mode == "fly" and rm.state == 12 and (inp.new or {}).a then
        local selected = flyTarget(rm.session, rm)
        if selected then
          local context = { onConfirmed = function()
            if generation.active and Region.active() == rm and flyTarget(rm.session, rm) then
              native(rm, { new = { a = true }, held = {} })
            end
          end }
          api.prompt(context, selected.section, selected.name)
          return native(rm, { new = {}, held = {} })
        end
        -- A native city marker alone is insufficient if HM/current-location
        -- policy changed while the map was open. Keep browsing in that case.
        return native(rm, { new = {}, held = {} })
      end
      return native(rm, inp)
    end
  end)

  return { clear = function()
    if navExit then navExit.shell.onClose = navExit.close; navExit = nil end
    cleanupDive(diveTask)
    pendingIntro = nil
    -- Title exit/error cleanup keeps this generation installed. Only teardown
    -- retires its presentation callback; otherwise Continue would leak intros.
    if not generation.active then state.rseIntro = nil end
  end }
end

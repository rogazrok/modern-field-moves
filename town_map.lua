-- Native regional maps plus a standard YES/NO prompt. No custom destinations.
return function(mod, installCursor)
  local maps = {}

  local function owns(store, item)
    local count = store and store[item]
    return type(count) == "number" and count > 0
  end

  function maps.hasRedMap(save)
    return save ~= nil and ((save.flags or {}).EVENT_GOT_TOWN_MAP == true
      or owns(save.inventory, "TOWN_MAP") or owns(save.pcItems, "TOWN_MAP"))
  end

  function maps.hasGen2Map(game)
    local save = game and game.save
    if not save then return false end
    local world = game.world
    local id = world and world.engineFlagId and world:engineFlagId("ENGINE_MAP_CARD", 1) or 1
    return (save.engineFlags or {})[id] == true
      or (save.pokegearFlags or {}).map == true
  end

  local function confirm(game, map, name, travel)
    if game.stack:top() ~= map then return end
    name = tostring(name):gsub("[\n\v\f]", " ")
    game.stack:push(mod.ui.TextBox.new(game, "FLY to\n" .. name .. "?", nil, {
      choice = function(yes)
        -- The native TextBox removes both prompt and choice before this call.
        -- NO (including B) leaves the same map and selection on the stack.
        if not yes or game.stack:top() ~= map then return end
        game.stack:pop()
        if not travel() then
          game.stack:push(map)
          game.stack:push(mod.ui.TextBox.new(game, "Can't FLY there\nright now!"))
        end
      end,
    }))
  end

  -- Both native viewers share the same input order. Keep each generation's
  -- destination lookup separate; only cursor movement and A/B handling belong
  -- here.
  local function wrapMapUpdate(game, map, selectTravel)
    local update = map.update
    map.update = function(self, dt)
      local input = game.input
      if self.freeCursor and not input:wasPressed("b") then
        if self:moveFreeCursor(input) then return end
      end
      if game.stack:top() == self and input:wasPressed("a") and not input:wasPressed("b") then
        if selectTravel(self) then return end
      end
      return update(self, dt)
    end
  end

  function maps.red(game)
    if not maps.hasRedMap(game.save) then return end
    local map = mod.ui.push(game, "TownMap", {})
    -- Keep the viewer's complete location list and native route-name banner.
    -- Ask the native picker for destinations, but never display that picker.
    local picker = mod.world:canFly()
      and require("src.ui.TownMap").new(game, { fly = true })
    map.travelPoints = picker and picker.flyMapIds or {}
    installCursor(map, 1)
    wrapMapUpdate(game, map, function(self)
      local loc = self.freeCursor and self.hoverLocation or self.locs[self.sel]
      for _, id in ipairs(self.travelPoints) do
        if loc and self.byMap[id] == loc then
          confirm(game, self, loc.name, function()
            -- API rechecks requirements, outdoor source and visited towns.
            return mod.world:flyTo(id)
          end)
          return true
        end
      end
    end)
    return map
  end

  function maps.gen2(game, world, mon, unlocked)
    if not maps.hasGen2Map(game) then return false end
    local FieldMoves = require("src.world.gen2.FieldMoves")
    local points = world:flyPoints()
    local canTravel = #points > 0 and unlocked() and mon ~= nil
      and world:acceptsMenuInput() and FieldMoves.flyFromMenu(world:fieldContext(mon)).ok
    local map
    map = mod.ui.push(game, "Gen2Pokegear", {
      save = game.save, currentLandmark = world:currentLandmarkId(),
      townMap = true,
      onFly = function(spawn)
        if not canTravel or not map or game.stack:top() ~= map then return end
        for _, row in ipairs(points) do
          if row.spawn == spawn then
            confirm(game, map, row.name or row.landmark, function()
              if not unlocked() or not world:acceptsMenuInput() then return false end
              local user = FieldMoves.partyMoveUser(game.save.party, "FLY",
                { save = game.save, data = game.data })
              if not user or not FieldMoves.flyFromMenu(world:fieldContext(user)).ok then
                return false
              end
              -- flyTo alone resolves a spawn; validate against the current
              -- native region/visited list again before starting its animation.
              for _, current in ipairs(world:flyPoints()) do
                if current.spawn == spawn then return world:flyTo(spawn, user) end
              end
              return false
            end)
            return
          end
        end
      end,
      onClose = function()
        if map and game.stack:top() == map then game.stack:pop() end
      end,
    })
    map.travelPoints = canTravel and points or {}
    installCursor(map, 2)
    wrapMapUpdate(game, map, function(self)
      local index = self:mapCursorIndex()
      for _, row in ipairs(self.travelPoints) do
        if row.index == index then
          self.onFly(row.spawn)
          return true
        end
      end
    end)
    return true
  end

  return maps
end

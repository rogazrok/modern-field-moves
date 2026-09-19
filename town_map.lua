-- Native regional maps plus a standard YES/NO prompt. No custom destinations.
return function(mod)
  local maps = {}

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

  function maps.red(game)
    if not mod.world:canFly() then
      game.stack:push(mod.ui.TextBox.new(game, "Can't FLY here!"))
      return
    end
    local parent = game.stack:top()
    local map
    map = mod.ui.push(game, "TownMap", { fly = true, onFly = function(id)
      -- Gen 1's native picker pops itself before onFly. Restore that same
      -- instance so the confirmation is over the map and NO keeps its cursor.
      if not map or game.stack:top() ~= parent then return end
      game.stack:push(map)
      for index, candidate in ipairs(map.flyMapIds or {}) do
        if candidate == id then
          local loc = map.locs and map.locs[index]
          confirm(game, map, (loc and loc.name) or id:gsub("_", " "), function()
            -- The API rechecks requirements, outdoor source and visited towns.
            return mod.world:flyTo(id)
          end)
          return
        end
      end
    end })
  end

  function maps.crystal(game, world, mon, unlocked)
    local FieldMoves = require("src.world.gen2.FieldMoves")
    local points = world:flyPoints()
    if #points == 0 or not unlocked() then return false end
    local map
    map = mod.ui.push(game, "Gen2Pokegear", {
      save = game.save, currentLandmark = world:currentLandmarkId(),
      fly = points, flyMon = mon,
      onFly = function(spawn)
        if not map or game.stack:top() ~= map then return end
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
    return true
  end

  return maps
end

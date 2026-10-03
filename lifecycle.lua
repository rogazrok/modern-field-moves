-- Gen 1/2 direct wrappers live on shared engine tables. Own every installed
-- slot/subscription, retire old closures on re-init, and restore on reset.
return function(mod, gameClass)
  local previous = gameClass._modernFieldMoves
  if previous then previous.teardown() end
  local scope = { active = true, slots = {}, removers = {} }
  local function track(remove)
    if type(remove) == "function" then scope.removers[#scope.removers + 1] = remove end
    return remove
  end
  local proxy = setmetatable({}, { __index = mod })
  proxy.events = setmetatable({ on = function(_, ...)
    return track(mod.events:on(...))
  end }, { __index = mod.events })
  proxy.hooks = setmetatable({ wrap = function(_, ...)
    return track(mod.hooks:wrap(...))
  end }, { __index = mod.hooks })
  function scope.wrap(owner, key, make)
    local native = owner[key]
    local wrapped = make(native)
    local guarded = function(...)
      if not scope.active then return native(...) end
      return wrapped(...)
    end
    scope.slots[#scope.slots + 1] = { owner, key, native, guarded }
    owner[key] = guarded
    return guarded
  end
  function scope.teardown()
    if not scope.active then return end
    scope.active = false
    for _, remove in ipairs(scope.removers) do remove() end
    for index = #scope.slots, 1, -1 do
      local entry = scope.slots[index]
      if entry[1][entry[2]] == entry[4] then entry[1][entry[2]] = entry[3] end
    end
    if gameClass._modernFieldMoves == scope then gameClass._modernFieldMoves = nil end
  end
  scope.wrap(gameClass, "reset", function(native)
    return function(self, ...)
      scope.teardown()
      return native(self, ...)
    end
  end)
  gameClass._modernFieldMoves = scope
  return proxy, scope
end

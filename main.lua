return function(mod)
  assert(mod.world and type(mod.world.useFieldAction) == "function",
    "Surf Without Teaching requires gen1recomp's contextual field-action API")

  local function unlocked(save)
    if not save then return false end
    local inventory = save.inventory or {}
    local badge = inventory.SOULBADGE
    local hasBadge = badge == true or (type(badge) == "number" and badge > 0)
    local hm = inventory.HM_SURF
    local hasHM = (save.flags or {}).EVENT_GOT_HM03 == true
      or (type(hm) == "number" and hm > 0)
    return hasBadge and hasHM and (save.party or {})[1] ~= nil
  end

  mod.hooks:wrap("fieldmove.eligibility", function(next, moveId, ctx)
    local mon = next(moveId, ctx)
    if moveId ~= "SURF" then return mon end
    -- Keep the requested progression gate even for an imported Surf knower.
    if not unlocked(ctx.save) then return nil end
    -- Native Surf needs a real party mon for its name, not a boolean.
    -- No species restriction, move edits, PP changes, or HP requirement.
    return mon or ctx.save.party[1]
  end)

  mod.hooks:wrap("ui.start_menu.items", function(next, game, items)
    local out = next(game, items)
    if type(out) ~= "table" or not unlocked(game.save) then return out end
    return mod.ui.insertBefore(out, "SAVE", {
      label = "SURF",
      -- Menu closes itself before onSelect, so the world API is not busy.
      onSelect = function()
        local ok, reason = mod.world:useFieldAction("surf")
        if not ok and reason == "field action unavailable" then
          game.stack:push(mod.ui.TextBox.new(game, "Can't SURF here!"))
        end
      end,
    })
  end)
end

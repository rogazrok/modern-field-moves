-- One options schema for the active game, used by both launcher and runtime.
-- These options can be configured from START > MODS in recent gen1recomp builds
-- or from the launcher's settings panel.
local schema = {
  { key = "field_move_user", type = "choice", label = "FIELD MOVE USER",
    default = "generic", choices = {
      { "GENERIC", "generic" }, { "KNOWN MOVE", "known_move" },
    } },
  { key = "hm_requirement", type = "choice", label = "HM REQUIREMENT",
    default = "hm_badge", choices = {
      { "HM + BADGE", "hm_badge" }, { "BADGE ONLY", "badge_only" },
      { "UNRESTRICTED", "unrestricted" },
    } },
  { key = "light_mode", type = "choice", label = "LIGHT MODE",
    default = "manual", choices = {
      { "MANUAL", "manual" }, { "AUTO", "auto" },
    } },
  { key = "confirm_prompts", type = "choice", label = "CONFIRM PROMPTS",
    default = "on", choices = {
      { "ON", "on" }, { "OFF", "off" },
    } },
}

-- The menu has no per-game visibility rule. Select the applicable row when
-- the active game's schema is loaded; stored values for other games remain.
if require("src.core.GameVersion").generation() == 3 then
  schema[#schema + 1] = { key = "cross_region_fly", type = "choice",
    label = "CROSS-REGION FLY", default = "vanilla", choices = {
      { "VANILLA", "vanilla" }, { "ENABLED", "enabled" },
    } }
else
  schema[#schema + 1] = { key = "map_cursor", type = "choice", label = "MAP CURSOR",
    default = "free", choices = { { "FREE", "free" }, { "CLASSIC", "classic" } } }
end

return schema

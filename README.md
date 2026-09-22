# Modern Field Moves v1.1.2

Modern Field Moves brings modern HM mechanics to Pokémon Red, Blue, Yellow,
Gold, Silver and Crystal on gen1recomp while keeping the games' classic feel.
Field moves work without teaching them to a Pokémon. The default requirement
remains the appropriate HM and badge.

## Installation and updates


## ⚠️ Compatibility & Testing Notice

Modern Field Moves modifies field-move logic and interacts with parts of the game's world and progression systems.

The mod has been tested in all supported games, including new and existing save files, but it has not been exhaustively tested across every story event or edge case.

Compatibility with other mods has also not been extensively tested. Mods that modify field moves, the START menu, Town Map / Pokégear map, Flash/lighting, world interactions, or related game logic may conflict with Modern Field Moves.

Keeping a backup of your save file is recommended when using mods.

If you encounter a bug, please report it through GitHub Issues and include:
- game/version;
- gen1recomp version;
- other installed mods;
- what happened and how to reproduce it.

## Install / update

Import `modern_field_moves-v1.1.2.zip` through **MODS → Import mod .zip**,
enable the mod for your game, and restart the game. To install manually,
place the `surf_without_hm_red` folder in gen1recomp's `mods` folder.
Keep this folder name and mod ID when updating: they preserve existing settings.
Existing game saves do not need to be restarted. The mod requires API 2 and
the `engine_internals` permission.
 (Release v1.1.2)

## Field moves and maps

Cut, Surf and Strength are contextual interactions. Gold, Silver and Crystal
also support Whirlpool and Waterfall. Fly is part of the map, not a separate
START item. RBY's TOWN MAP appears after obtaining Daisy's Town Map; G/S/C's
MAP appears after obtaining the Pokégear Map Card. Both maps can be browsed
before Fly is unlocked. Fly requires the selected HM requirement and still
uses the game's visited-destination restrictions and a YES/NO confirmation.

The MAP CURSOR setting offers FREE (four-direction cursor, default) and
CLASSIC (native location cycling). FREE names locations at their native
landmark anchors; empty map cells have no name. B exits the map.

LIGHT appears only in dark areas and disappears after illumination. AUTO
lights ordinary dark areas when available. Crystal's Aerodactyl wall remains
a separate, explicit FLASH interaction and is never triggered by AUTO.

## Settings

| Setting | Choices | Default |
| --- | --- | --- |
| FIELD MOVE USER | GENERIC, KNOWN MOVE, FIRST PARTY | GENERIC |
| HM REQUIREMENT | HM + BADGE, BADGE ONLY, UNRESTRICTED | HM + BADGE |
| LIGHT MODE | MANUAL, AUTO | MANUAL |
| CONFIRM PROMPTS | ON, OFF | ON |
| MAP CURSOR | FREE, CLASSIC | FREE |

GENERIC uses anonymous field-move messages. KNOWN MOVE names a Pokémon that
knows the move, falling back to GENERIC. FIRST PARTY names the first non-egg
party member. The native action still uses a real party member internally.

UNRESTRICTED bypasses HM and badge checks for field moves only. It does not
grant badges, items, maps or visited Fly destinations. CONFIRM PROMPTS OFF
skips only ordinary contextual Cut, Surf, Strength, Whirlpool and Waterfall
questions; Fly destination confirmation stays on.

## Validation and limits


4567 local assertions passed across all six game versions, using native engine
Lua code with synthetic data and graphics stubs. No full ROM gameplay/visual
playthrough was performed. Gold/Silver manual acceptance testing is pending.
The build is versioned 1.0.0; do not interpret this as completed in-game QA.
Tested against gen1recomp dev e2114f7c85795d52903ea98deab493a4f181bace.
Future internal engine changes may require an adapter update.

See README_RU.md, MANUAL_CHECKLIST_RU.md and RELEASE_REPORT_RU.md for details.

FREE uses native location anchors, not full route polygons. Names appear at the markers; blank cells have no label. Coordinate-less caches fall back to CLASSIC. The setting takes effect on next map open. No full ROM visual validation was performed.

1.1.1 fixes missing Kanto labels/Fly selection in FREE when HALL_OF_FAME is absent. Full-region hit-testing is independent from the native CLASSIC scroll range. Visited-flight restrictions are unchanged.

## Credits

**Author & Design:** rogazrok  
**Development assistance:** ChatGPT (OpenAI)

The release passed 5,107 applicable local assertions across all six games and
strict Modkit validation and lint. It was checked against gen1recomp source snapshot
`e2114f7c85795d52903ea98deab493a4f181bace` using automated tests with
synthetic save data and graphics stubs. Full ROM playthrough testing is still
recommended, especially for existing completed saves and third-party mod
combinations. See `CHANGELOG.md` for this version's maintenance changes.
(Release v1.1.2)

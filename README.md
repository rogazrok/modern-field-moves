# Modern Field Moves v1.2.0

**Modern Field Moves — modern HM mechanics with the classic Pokémon feel.**

HM and field-move QoL for Pokémon Red, Blue, Yellow, Gold, Silver, Crystal,
FireRed and LeafGreen on gen1recomp. Field moves do not need to occupy a
Pokémon's battle moveslot. The default progression requirement remains the
appropriate HM and badge.

## Install or update

Import `modern_field_moves-v1.2.0.zip` with **MODS → Import mod .zip**, enable
Modern Field Moves for your game, then use **APPLY & RESTART**. For manual
installation, replace the contents of `mods/surf_without_hm_red/` with the
files in the ZIP. Keep that folder name and mod ID: `surf_without_hm_red`.

Disable/remove the separate `modern_field_moves_gen3_test` prototype before
using this release. Do not enable both implementations together. Settings
from v1.1.x retain their existing namespace; the prototype's separate settings
are not imported automatically. Existing saves do not need a new game.

Use a current gen1recomp build with API 2 and native FRLG Game3 support.
The mod requires `engine_internals`. The source used for automated validation
is recorded below; this does not identify the version installed on your device.
After updating from an older build, restart the game completely if the launcher
cannot apply the update with **APPLY & RESTART**.

## Supported field moves

| Games | Moves |
| --- | --- |
| Red / Blue / Yellow | Cut, Fly, Surf, Strength, Flash |
| Gold / Silver / Crystal | Cut, Fly, Surf, Strength, Flash, Whirlpool, Waterfall |
| FireRed / LeafGreen | Cut, Fly, Surf, Strength, Flash, Rock Smash, Waterfall |

Cut, Surf, Strength, Whirlpool, Rock Smash and Waterfall use the original
world interactions where available. Their native effects, sounds, boarding,
movement and travel animations remain in the engine.

**LIGHT** appears only in an actual Flash-compatible dark area while Flash is
available. It disappears after illumination. AUTO lights eligible darkness
once; it does not repeatedly apply Flash each frame. Crystal's Aerodactyl wall
remains a separate explicit FLASH interaction and is never opened by AUTO.
Manual LIGHT still presents the action as FLASH.

## Settings and presentation

| Setting | Choices | Default | Applies to |
| --- | --- | --- | --- |
| FIELD MOVE USER | GENERIC / KNOWN MOVE | GENERIC | All games |
| HM REQUIREMENT | HM + BADGE / BADGE ONLY / UNRESTRICTED | HM + BADGE | All games |
| LIGHT MODE | MANUAL / AUTO | MANUAL | All games |
| CONFIRM PROMPTS | ON / OFF | ON | All games |
| MAP CURSOR | FREE / CLASSIC | FREE | Gen 1 / Gen 2 |
| CROSS-REGION FLY | VANILLA / ENABLED | VANILLA | FireRed / LeafGreen |

GENERIC does not present a Pokémon name or Pokémon intro. KNOWN MOVE uses a
Pokémon that actually knows the particular move and retains the game's native
presentation. If nobody knows it, the action falls back to GENERIC without an
intro. FRLG's Pokémon splash follows this rule for field moves and Fly. Gen 1/2
retain their original presentation rather than gaining a new FRLG-style splash.
Native world animations remain visible in both modes. FRLG Surf omits the
redundant extra "SURF was used!" dialog after boarding.

FIRST PARTY is no longer a selectable option in any game. A stored v1.1.x
`first_party` value is normalized to `known_move` in live and persistent
options, including stored profiles, when the mod initializes or receives the
old value again. Other preferences and vanilla save data are preserved.
There is no FIELD MOVE INTRO setting.

UNRESTRICTED bypasses only HM/badge requirements. It does not grant maps,
items, badges, visited destinations, tickets or story progression, and it
does not bypass location or destination restrictions.

CONFIRM PROMPTS OFF skips ordinary contextual Cut, Surf, Strength, Whirlpool,
Rock Smash and Waterfall questions as applicable. Fly destination confirmation
always stays enabled. Ferry choices, story prompts and NPC dialog are unaffected.
Manual LIGHT does not add another confirmation question.

The settings menu shows MAP CURSOR only in Gen 1/2 and CROSS-REGION FLY only
in FireRed/LeafGreen. Previously stored values remain untouched when their
setting is hidden in another game. FRLG always uses its native Gen3 cursor.

## Maps and Fly

Map ownership is independent of Fly requirements:

- RBY **TOWN MAP** appears after receiving Daisy's real Town Map. The receipt
  flag and Bag/PC ownership support old saves and deposited maps.
- G/S/C **MAP** appears after receiving the Pokégear Map Card.
- FRLG **TOWN MAP** requires the real key item in the Bag or PC.

These entries open ordinary browse maps before Fly is available. Unlocking Fly
adds travel to visited, native-valid destinations on the same map. Browsing a
route, cave or landmark does not make it a Fly destination. Every flight asks
YES/NO over the open map. NO or B retains the current map selection.

Gen 1/2 FREE is a four-direction cursor; CLASSIC retains native location
cycling. FREE uses native landmark anchors; empty cells have no label.

FRLG retains native labels, cities, routes, caves, landmarks, cursor and
Kanto/available Sevii pages. Fly wings are hidden. A selects an eligible Fly
destination; SELECT opens a native GUIDE preview where available. Where GUIDE
is unavailable, SELECT retains the native close action. B leaves the preview
or map. The right shoulder keeps its normal speed control. With a Town Map
owned, party-menu Fly also opens the combined browse/travel map, preserving
the explicitly selected Pokémon. Without it, the native Fly screen remains.

CROSS-REGION FLY VANILLA keeps the engine's regional restriction. ENABLED
permits Kanto ↔ Sevii travel only between visited native Fly destinations after
the first mandatory Sevii detour and Bill's return scene are complete. It never
opens islands or changes ferry/pass/story flags. Native map-page availability
and destination checks still apply. UNRESTRICTED does not bypass these gates.

## Validation and remaining manual coverage

Automated regression passed separately for all eight games against official
gen1recomp source revision `7cfd79d0e94e7cd32ccd721e9acae9a1c462c0ef`.
Strict Modkit validate, strict Gen3 checker and lint passed. The suite covers
requirements, presentation/fallback, prompts, lighting, maps, migration,
wrapper re-init/reset, logical flag differentials and native FRLG execution
with synchronous visual/movement fixtures.

These are source-based tests with synthetic save data, not a new eight-game
ROM playthrough or a comparison of real cartridge save bytes. Manual in-game
smoke testing was also completed for the merged release build, including the
main FRLG field-move, map, Fly and progression flows.

Automated and manual smoke tests cannot cover every possible save state or
third-party mod combination. Keeping a backup of your save is recommended.
No ROM, save, imported cache, test runner or test log is included in the
install package.

# Modern Field Moves v1.3.0

**Modern HM mechanics with the classic Pokémon feel.**

Use field moves without reserving battle moveslots for HMs. Modern Field Moves
supports Pokémon Red, Blue, Yellow, Gold, Silver, Crystal, FireRed, LeafGreen,
Emerald, Ruby and Sapphire in gen1recomp.

By default, you still need the appropriate HM and badge. The original field
animations, sounds, terrain requirements and story progression are preserved.

## New in v1.3.0

- Emerald, Ruby and Sapphire support, including Dive and surfacing.
- Fly directly from the PokéNav map in Hoenn while retaining normal map browsing
  and zoom.
- Fly directly from the Pokégear Map Card in Gold, Silver and Crystal, without
  a duplicate MAP entry in START.
- Pokégear tab browsing with explicit A-to-enter and B-to-return controls,
  including a four-direction FREE map cursor.
- Correct music restoration when leaving a silent Pokégear radio frequency.
- Confirmed PokéNav flights close START automatically, with no extra B press.
- AUTO LIGHT illuminates ordinary caves without solving the Regi puzzles.

## Supported field moves

| Games | Field moves |
| --- | --- |
| Red / Blue / Yellow | Cut, Fly, Surf, Strength, Flash |
| Gold / Silver / Crystal | Cut, Fly, Surf, Strength, Flash, Whirlpool, Waterfall |
| FireRed / LeafGreen | Cut, Fly, Surf, Strength, Flash, Rock Smash, Waterfall |
| Emerald / Ruby / Sapphire | Cut, Fly, Surf, Strength, Flash, Rock Smash, Waterfall, Dive |

Interact with the relevant tree, water, boulder or rock to use an available
field move. The Pokémon menu remains available for its usual field actions.

## Settings

| Setting | Choices | Default | Games |
| --- | --- | --- | --- |
| FIELD MOVE USER | GENERIC / KNOWN MOVE | GENERIC | All |
| HM REQUIREMENT | HM + BADGE / BADGE ONLY / UNRESTRICTED | HM + BADGE | All |
| LIGHT MODE | MANUAL / AUTO | MANUAL | All |
| CONFIRM PROMPTS | ON / OFF | ON | All |
| MAP CURSOR | FREE / CLASSIC | FREE | Red / Blue / Yellow / Gold / Silver / Crystal |
| CROSS-REGION FLY | VANILLA / ENABLED | VANILLA | FireRed / LeafGreen |

Only settings relevant to the current game appear in MOD OPTIONS.

### FIELD MOVE USER

**GENERIC** uses the action without showing a Pokémon name or Pokémon intro.

**KNOWN MOVE** shows the Pokémon's name and original presentation when it knows
the move being used. If nobody in the party knows that move, the action uses
GENERIC presentation. For example, a Pokémon that knows Cut can appear for Cut
while Surf remains anonymous if nobody knows Surf.

World effects and travel animations remain visible in both modes. Pokémon
intros follow each game's original presentation; older games do not gain a
newer game's splash animation.

### HM REQUIREMENT

- **HM + BADGE:** requires the appropriate HM and badge.
- **BADGE ONLY:** requires the badge, without requiring the HM.
- **UNRESTRICTED:** removes the HM and badge requirements.

These settings do not grant items, badges, maps, tickets or story progress.
Terrain restrictions still apply, and Fly remains limited to valid, visited
and available destinations from locations where flight is allowed.

### CONFIRM PROMPTS

**ON** keeps the usual confirmation questions for contextual field moves.
**OFF** skips them for Cut, Surf, Strength, Whirlpool, Rock Smash, Waterfall
and Dive/surfacing where applicable.

Fly always asks for confirmation. Story choices, NPC dialogue and ferry
questions are unaffected.

### LIGHT MODE

**MANUAL** adds LIGHT to START when you can use Flash in a dark area. LIGHT
disappears once the area is illuminated.

**AUTO** illuminates eligible dark areas automatically, without repeatedly
using Flash after the area is lit.

Puzzle actions remain deliberate: Crystal's Aerodactyl wall requires its
separate FLASH action. Emerald's Ancient Tomb puzzle requires Flash from the
Pokémon menu at the correct position. AUTO LIGHT does not solve either puzzle.
Ruby and Sapphire retain their original Regi puzzle requirements.

## Maps and Fly

Maps remain useful for browsing before Fly becomes available. Routes, caves
and landmarks keep their names; only eligible Fly destinations offer travel.
Flight confirmation appears over the open map. Choosing NO or cancelling the
question keeps your map selection so you can choose somewhere else.

### Red, Blue and Yellow

TOWN MAP appears in START after receiving the Town Map. Depositing it in the
PC does not remove access. Select an eligible visited destination and press
A to choose Fly.

**FREE** moves the cursor in four directions. **CLASSIC** cycles through map
locations. Empty FREE cursor positions do not select a nearby destination.

### Gold, Silver and Crystal

Use the map inside Pokégear after receiving the Map Card. There is no separate
MAP entry in START.

- Left/right on the upper tabs previews the available cards.
- A enters the selected card.
- On the map, FREE uses all four directions; CLASSIC cycles through locations
  with up/down and retains left/right card switching.
- A on an eligible visited destination opens the Fly question.
- B returns to the upper tabs. B again closes Pokégear.

Phone calls and submenus handle B before returning to tab selection. Clock,
phone and radio remain available. Leaving a silent radio frequency restores
map music; a tuned station can continue playing according to the game's usual
radio behavior.

### FireRed and LeafGreen

TOWN MAP appears in START when you own the Town Map. Browse Kanto and available
Sevii pages with the original map cursor, names and landmarks, without flashing
Fly wing markers.

A selects an eligible Fly destination. SELECT opens GUIDE details where
available; elsewhere it retains the map's normal SELECT action. B closes the
details or map. The right shoulder button keeps its normal speed control.

With a Town Map, selecting Fly from the Pokémon menu also opens this combined
map. Without one, the original Fly screen remains available.

**CROSS-REGION FLY = VANILLA** keeps the original travel restrictions.
**ENABLED** allows travel between Kanto and Sevii after the mandatory first
Sevii visit and Bill's return sequence are complete. Destinations must still
be visited and available. This option does not unlock islands or replace their
story requirements, even with UNRESTRICTED enabled.

### Emerald, Ruby and Sapphire

Use the map inside PokéNav once it becomes available in the story. No separate
TOWN MAP entry is added to START.

- A keeps the original zoom function.
- SELECT offers Fly over an eligible visited destination.
- B returns from the map.

The map's help bar shows when Fly is available. Confirming a flight closes
PokéNav and START before takeoff. The original Pokémon-menu Fly map also
remains available, with destination confirmation.

## Dive in Hoenn

Interact with a diveable tile while Surfing to descend. Underwater, use the
usual interaction to surface where permitted. Dive also remains available
from the Pokémon menu.

HM08 and the Mind Badge are required by default. BADGE ONLY and UNRESTRICTED
change those requirements, while valid diving locations, underwater routes
and surfacing restrictions remain the same.

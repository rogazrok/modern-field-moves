# Modern Field Moves v1.0.0

Modern Field Moves — modern HM mechanics with the classic Pokémon feel.

HM and field-move QoL for Pokémon Red, Blue, Yellow, Gold, Silver and Crystal
on gen1recomp (Mod API 2). All five Gen 1 and seven Gen 2 HMs are supported.

## Install / update

Import modern_field_moves-v1.0.0.zip through MODS → Import mod .zip, replacing
0.9.x. Enable Modern Field Moves for your game and restart the game completely.
The legacy internal ID/folder surf_without_hm_red is retained to preserve settings.
No new playthrough is required. engine_internals permission is required.

## Options

- FIELD MOVE USER: GENERIC (default), KNOWN MOVE, FIRST PARTY.
- HM REQUIREMENT: HM + BADGE (default), BADGE ONLY, UNRESTRICTED.
- LIGHT MODE: MANUAL (default), AUTO.
- CONFIRM PROMPTS: ON (default), OFF.

UNRESTRICTED is a debug/cheat option that bypasses only HM/badge requirements.
It does not grant map ownership, badges, items or visited destinations.
GENERIC uses anonymous messages; KNOWN MOVE uses a learned move's user or falls
back to GENERIC; FIRST PARTY names the first non-egg party member.
Native effects still require a real party member internally.

## Map, travel and light

TOWN MAP in RBY requires Daisy's Town Map, including when deposited in the PC.
MAP in G/S/C requires the Guide Gent's Pokégear Map Card. Maps work without Fly
and keep route/city browsing after Fly unlocks. Up/down browse, B closes, A on
a valid visited destination asks for flight confirmation. Fly always requires
YES/NO, even with confirmation OFF. Native travel restrictions remain in force.

LIGHT appears only in real darkness and disappears after illumination. AUTO
lights a dark area when the player is ready, without repeated activation.
Crystal's Aerodactyl wall uses a separate explicit FLASH action; AUTO never
triggers it. Gold/Silver do not receive this Crystal-only puzzle callback.

OFF skips ordinary Cut/Surf/Strength/Whirlpool/Waterfall questions only.
Messages, effects, unrelated story prompts and the QoL fishing menu remain.

## Validation status

4453 local assertions passed across all six game versions, using native engine
Lua code with synthetic data and graphics stubs. No full ROM gameplay/visual
playthrough was performed. Gold/Silver manual acceptance testing is pending.
The build is versioned 1.0.0; do not interpret this as completed in-game QA.
Tested against gen1recomp dev e2114f7c85795d52903ea98deab493a4f181bace.
Future internal engine changes may require an adapter update.

See README_RU.md, MANUAL_CHECKLIST_RU.md and RELEASE_REPORT_RU.md for details.

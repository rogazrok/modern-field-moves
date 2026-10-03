# Changelog

## 1.2.0

- Fixed CONFIRM PROMPTS = ON for Cut/Surf in the Gen 1 party menu and
  contextual HMs selected from the Gen 2 party menu; OFF still skips these
  ordinary field-move questions.
- Show MAP CURSOR only in Gen 1/2 and CROSS-REGION FLY only in FRLG MOD
  OPTIONS, preserving stored preferences for each game.
- Fixed FRLG Fly confirmation closing as its UI layer opened, which could
  leave TOWN MAP unresponsive after selecting a city.
- Merged the verified FRLG 0.0.13 implementation into the main mod with its
  original `surf_without_hm_red` ID. Added FireRed and LeafGreen support.
- Added Gen3 Field Moves including Rock Smash, contextual LIGHT, native
  TOWN MAP browsing and Fly, available Sevii pages, and CROSS-REGION FLY.
- Kept visited/native/current-location checks and the mandatory Sevii detour
  and Bill return gates. Regional travel never grants progression flags.
- Removed FIRST PARTY from settings across Gen1/Gen2/Gen3. Stored legacy
  values and profiles migrate to KNOWN MOVE; other settings remain intact.
- Unified anonymous/known-user fallback policy. Genuine FRLG learners keep
  native intros; GENERIC/fallback have no intro. No FIELD MOVE INTRO option.
- Shared actor/Egg selection, copying, temporary-value restoration and one
  options schema; isolated Gen1 execution from dispatch and added scoped
  Gen1/2 wrapper ownership and reset/re-init cleanup.
- Retained FRLG Fly Quest Log anonymity, teardown and error cleanup.
- Repeated eight-game regression and strict validate/gen3check/lint, followed
  by manual in-game smoke testing of the merged release build.

## 1.1.2

- Audited story and event flag interactions and added save-state regression
  checks for completed-game data. The reported reappearing items/trainers
  could not be reproduced in local tests; this release does not claim to fix
  that unconfirmed issue.
- Centralized HM/badge requirement decisions shared by Gen 1 and Gen 2.
- Reused the shared non-egg party selection in Gen 2, unified ordinary
  contextual confirmation policy, and removed duplicate Cut/Surf dispatch,
  map input, and temporary-result copying code. Native actions and
  generation-specific rules remain separate. No intended gameplay changes.
- Added the GitHub repository identifier to the manifest.
- Reduced the install folder to runtime files and English release documents.

## 1.1.1

- Fixed missing Kanto location labels and Fly selection with the FREE cursor
  in Crystal saves without the Hall of Fame flag.

## 1.1.0

- Added FREE and CLASSIC map cursor modes.

## 1.0.0

- Added Gold and Silver support alongside Red, Blue, Yellow and Crystal.

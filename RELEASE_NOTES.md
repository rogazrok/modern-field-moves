# Modern Field Moves v1.2.0

- Added FireRed and LeafGreen support alongside Red, Blue, Yellow, Gold,
  Silver and Crystal, retaining the `surf_without_hm_red` mod ID.
- Added native Gen3 Cut, Surf, Strength, Flash/LIGHT, Rock Smash and Waterfall.
- Integrated FRLG TOWN MAP and Fly: browse full native regional maps, retain
  map labels and available Sevii pages, and confirm travel over the open map.
  Fixed an issue where selecting a Fly city could close the confirmation and
  leave the map unresponsive.
- Preserved Sevii progression restrictions. CROSS-REGION FLY defaults to
  VANILLA; ENABLED permits travel between already available native points
  after the mandatory Sevii detour and Bill return scene, without granting
  tickets, destinations or story flags.
- Simplified FIELD MOVE USER to GENERIC / KNOWN MOVE in every supported game.
  Existing FIRST PARTY preferences migrate to KNOWN MOVE. Genuine learners
  retain native presentation; missing learners fall back to anonymous actions.
- MOD OPTIONS shows MAP CURSOR only in Gen 1/2 and CROSS-REGION FLY only in
  FireRed/LeafGreen; saved values are retained when hidden.
- Improved shared policy and temporary-state restoration, reduced duplicate
  selection helpers, and added owned Gen1/2 wrapper teardown/re-init handling.
  Retained FRLG lifecycle, anonymous Fly Quest Log and Fly error-cleanup fixes.

All eight source-based regression targets and strict Modkit checks passed.
Manual in-game smoke testing was also completed for the merged release build.
Automated and manual smoke testing cannot cover every possible save state or
third-party mod combination.

Update through MODS, disable the separate Gen3 test prototype, and apply a
restart. Existing main-mod settings remain under the same ID.

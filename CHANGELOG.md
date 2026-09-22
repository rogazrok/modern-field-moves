# Changelog

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

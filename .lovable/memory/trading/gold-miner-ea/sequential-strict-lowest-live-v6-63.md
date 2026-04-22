---
name: Strict Sequential Unlock v6.63
description: GetSequentialAllowedGeneration scans ALL live positions and returns lowest live gen; ManageOrphanGrid gates strict gen==allowed; DD hedge comment GM_HEDGE_D<n> supported
type: feature
---
v6.63 changes the sequential queue logic:
- Scans ALL system positions (not just hedge comments) and returns lowest live generation
- ManageOrphanGrid uses strict `gen != seqAllowed` (was `gen > seqAllowed`) so orphans only recover one generation at a time
- ParseGenerationFromComment recognizes GM_HEDGE_D<n> DD-triggered hedge comments (n→n-1)
- Dashboard label: "Allowed Gen: GenN (GM/GMn) | Strict one-by-one"
- Result: GM → GM1 → GM2 strict order; while any Gen0 order remains only Gen0 may run recovery

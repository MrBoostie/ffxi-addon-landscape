# FFXIAH Forum Addon Discovery Sweep (2026-04-28)

Source scanned: https://www.ffxiah.com/forum/forum/168/general/

Goal: identify likely addon candidates mentioned by players that may be missing or underrepresented in the current catalog.

## Likely New/Needs Verification Candidates

- LimbusHelper
- ZNMTracker
- Hivemind
- CastStill
- Chronicle
- AAEV (Auto Attacks Easily Visualized)
- TrueTargetLock
- Send'Oria (FFXI/Discord relay)
- Tourist
- SheolHelper
- JSE
- Wardrobe9
- LockIcon
- ATA (targeting addon)
- FastFeet
- tTracker
- Where Is NM
- FFXI Manager / FFXI Character Manager
- Sortie Addon (generic thread title, repo lookup needed)
- Checkparam fork (variant/fork investigation needed)

## Notes

- This is a **forum-title discovery pass**, not full thread parsing.
- Some entries may already exist under different naming in the normalized catalog.
- Next recommended step:
  1. Resolve each candidate to canonical repo URL(s)
  2. De-duplicate against existing addon_key/addon_name aliases
  3. Add confirmed entries to `ffxi_addons_index_raw.json`
  4. Regenerate normalized JSON/CSV

## Confidence

- Medium confidence for candidate discovery.
- Low confidence for canonical naming/repo mapping until thread-level extraction is completed.

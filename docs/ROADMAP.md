# Roadmap

## Phase 1 (done)
- [x] First-pass GitHub repo scan
- [x] Raw index JSON
- [x] Normalized catalog (JSON/CSV)
- [x] Initial gap analysis + opportunity shortlist

## Phase 2 (next)
- [ ] Expand repository coverage (50-150 repos)
- [ ] Improve addon detection beyond top-level directory names
- [ ] Add compatibility metadata: Windower/Ashita/Era/private server notes
- [ ] Add confidence score for inferred categories

## Phase 3 (productize)
- [x] Publish static searchable site
- [ ] Add tags and faceted filters (category, activity, popularity)
- [ ] Add "starter addon ideas" page with implementation complexity
- [x] Ship first addon concept spec (`AddonHealth`)
- [x] Build AddonHealth v0.1 addon

## Contribution guidelines (draft)
- Use PRs for repo additions/corrections
- Include source links for metadata edits
- Prefer reproducible scripts over manual edits


## Near-term implementation priorities

- Expand TravelRouter route explainability so route choice stays debuggable instead of magical.
- Make SessionConductor operator-facing status richer so ACK/retry state is visible in game.
- Keep AddonHealth lightweight, but improve signal quality with severity grading and short-session report history.
- Continue preferring bounded, inspectable automation over opaque one-shot scripts.

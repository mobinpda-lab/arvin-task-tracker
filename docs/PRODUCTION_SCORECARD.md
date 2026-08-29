# Arvin Production Scorecard

Updated: 2026-08-29

This scorecard records only repository evidence that is currently verifiable. It intentionally does not publish an overall completion percentage until weighted scoring criteria and evidence-backed Done definitions are present in the repository.

## Current production baseline

| Gate | Status | Evidence |
| --- | --- | --- |
| Repository / `main` accessible | PASS | Public repository `mobinpda-lab/arvin-task-tracker` |
| Build workflow present | PASS | `.github/workflows/build-apk.yml` |
| Pull-request validation | PASS | Workflow now triggers on pull requests to `main` |
| Pre-merge analyze | PASS | Run #56, commit `da68f8d4098e032108910c318fe379626c720410` |
| Pre-merge release APK build | PASS | Run #56 |
| Pre-merge APK verification | PASS | Run #56 |
| Pre-merge artifact upload | PASS | Run #56 |
| Recovery PR merged | PASS | PR #1, merge commit `14656f74e8c9c0c93d318039711aee2bc2101888` |
| Post-main analyze | PASS | Run #57 on merge commit `14656f74e8c9c0c93d318039711aee2bc2101888` |
| Post-main release APK build | PASS | Run #57 |
| Post-main APK verification | PASS | Run #57 |
| Post-main artifact upload | PASS | Run #57, artifact `arvin-apk-recovered`, id `9717652192`, size `25011688` bytes, digest `sha256:0ed68ffc68e893f7620a0bc8b571aec40c34e4bbd2a01196302a602324871f3a` |
| Device proof | NOT VERIFIED | No current device-proof evidence recorded in this repository |
| Five-minute Production Orchestrator | NOT VERIFIED | Current visible workflow is build/verify CI, not a verified 5-minute orchestrator |
| Projects | NOT VERIFIED | Not yet verified in the current release source of truth |
| Work Agenda | NOT VERIFIED | Not yet verified in the current release source of truth |
| Notebook | NOT VERIFIED | Not yet verified in the current release source of truth |
| Google / Samsung Calendar sync | NOT VERIFIED | Not yet verified in the current release source of truth |

## Source-of-truth note

The release workflow currently assembles `lib/main.dart`. The compressed `lib/arvin_final_v2.dart` remains in the repository but is intentionally outside the release path until it is repaired and revalidated separately.

## Scoring rule

Do not infer a single overall percentage from this file. A percentage may be added only after the repository contains explicit weighted dimensions, Done criteria, and evidence for every scored capability. Until then, status reporting must remain gate-based and feature-based.

## Next production priorities

1. Add device-proof evidence for the current APK.
2. Implement and verify the five-minute Production Orchestrator as a separate production-control layer without destabilizing the recovered build path.
3. Restore expansion features one independently verifiable lane at a time: Projects, Work Agenda, Notebook, and Calendar Sync.
4. Keep every merge exact-head validated and repeat post-main build verification after each production merge.

# Arvin Recovery Status

Date: 2026-08-28

## Purpose
Restore a green, reproducible APK build without modifying `main` while the v2 source is repaired.

## Current facts
- `main` fails during Dart analysis of `lib/arvin_final_v2.dart`.
- The recovery branch builds from the existing `lib/arvin_final.dart` stable source.
- APK verification remains mandatory before artifact upload.
- No force merge is permitted; recovery must prove green before promotion.

## Parallel tracks
1. Recovery build: establish a green APK baseline.
2. V2 repair: fix parser/type errors independently.
3. Reconciliation: compare recovered stable behavior with v2 features before merging.

## Promotion gate
A recovery change can move toward `main` only after Analyze + Release APK + APK Verify all pass.

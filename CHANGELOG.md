# Changelog

All notable changes to this project are documented in this file.

## [0.1.1] - 2026-02-18

### Fixed
- Fixed Whisper model persistence detection after app restart. Previously, downloaded models could be treated as missing and trigger unnecessary re-download behavior.
- Fixed startup auto-download logic to only trigger when no local Whisper models are available on disk.
- Fixed release DMG packaging script to export `BUILD_DIR` for the background image generation step.

### Changed
- Whisper model lookup now supports the current WhisperKit/Hugging Face cache layout as well as legacy model directory layouts.
- Whisper manager startup state now reflects on-disk model availability by initializing to `downloaded` when a selected model already exists locally.

### Technical Notes
- Updated model path resolution, download verification, deletion, and storage accounting to use consistent path discovery.
- Patch release only; no new permissions or user-facing workflow changes.

# Changelog

## 2.1.1

Changes since [2.1.0](https://github.com/dealnotedev/twitch_rewards_app/releases/tag/2.1.0).

### Added

- Two-pass loudness normalization for YouTube music requests, targeting
  **-16 LUFS** with a **-2 dBTP** true-peak ceiling before MP3 encoding. Tracks are
  encoded once from the downloaded source into stereo, 48 kHz MP3 audio.
- Separate download, loudness-analysis, and normalization progress in the music
  player and queue.
- A compact, audio-only **FFmpeg 9.0.2** build with the codecs and filters needed
  for YouTube audio. The bundled FFmpeg executable is approximately **3.84 MB**;
  FFprobe is not required or bundled.
- A Docker-based FFmpeg build script with pinned source checksums, build
  metadata, and bundled license notices. See [tool setup](tools/README.md).
- Automated coverage for normalization, cancellation, supported input formats,
  and playback of normalized audio.

### Changed

- Normalized tracks use a separate cache profile, so previously downloaded audio
  is prepared again with the current loudness settings when requested.
- Refined music-player seek-bar spacing and aligned the music-request test
  dialog with the shared application components.
- Synchronized Flutter and Windows application version metadata at **2.1.1**
  (build **1**).

### Fixed

- Cancellation now stops active download and encoding processes before cleaning
  up temporary files, preventing canceled tracks from entering the cache.
- Loudness normalization adapts its loudness-range setting to the measured
  source, preserving linear normalization for a wider range of music.

## 2.1.0

Changes since [2.0.4](https://github.com/dealnotedev/twitch_rewards_app/releases/tag/2.0.4).

### Added

- **Play YouTube Track** reward action. Viewers submit a YouTube link with their
  reward redemption, and the action adds one track to the shared music queue.
  The reaction chain continues immediately without waiting for the download or
  playback to finish.
- A global music player at the bottom of the window, available on every screen,
  including the reward editor. Shows track artwork, title, author, requester,
  playback position, and duration, with pause/resume, seek, and next-track controls.
- An expandable queue with a track counter, thumbnails, download status, and
  individual removal buttons. Tracks play in request order; new requests do not
  interrupt the current track or resume it when paused.
- A separate music volume control that is saved between launches and remains
  independent of reward sound-effect volumes.
- Background YouTube downloads and a local audio cache for repeated requests.
  Invalid links, unavailable tracks, and playback errors appear in a dismissible
  error panel, while subsequent requests continue to be processed.
- A YouTube-link prompt when manually testing a reward containing the new action.
- A Windows tool setup script with checksum verification for yt-dlp and Deno,
  plus build rules that include these tools in the application bundle.

### Changed

- Refreshed the Windows interface in both light and dark themes, including
  colors, text contrast, cards, borders, buttons, switches, dropdowns, input
  fields, and connection indicators.
- Improved reward and action cards with consistent spacing, rounded borders,
  and accent styling.
- Moved reward configuration storage to SQLite. Existing configurations are
  imported automatically on first launch, preserving their order; subsequent
  saves use database transactions.
- Expanded the English README with setup instructions, reaction-chain examples,
  troubleshooting guidance, build instructions, and current screenshots.
- Updated dependencies and added automated coverage for storage migration,
  music queues, playback controls, downloads, and responsive player layouts.
- Synchronized Flutter and Windows application version metadata at **2.1.0**
  (build **1**).

### Fixed

- Disabled rewards no longer execute when redeemed on Twitch. Disabled actions
  are skipped when a reaction chain runs.
- Preference-saving operations now wait for writes to finish before completing.
- On Windows and Linux, unreadable preference files are recreated instead of
  preventing startup. Login and connection settings may need to be entered
  again after this recovery.

### Music request setup and limits

- Enable text input for the Twitch reward so viewers can submit a YouTube link.
- The queue supports up to **10 requests**, including the active track, and
  recorded tracks up to **10 minutes** long. Live streams and standalone playlist
  links are not supported; a video link with playlist parameters adds only that
  video.
- Playback uses the existing **media_kit** audio backend and works independently
  of OBS. **yt-dlp** and **Deno** are needed for YouTube downloads; a separate
  FFmpeg executable is not required. See [tool setup](tools/README.md).
- The queue lasts for the current application session. Downloaded audio is cached
  locally, and the music volume is retained between sessions.
- Music requests do not automatically fulfill, cancel, or refund Twitch reward
  redemptions.

# YouTube music tools

Run `powershell -ExecutionPolicy Bypass -File tools/download_tools.ps1` from the
repository root. The script downloads Windows x64 builds of yt-dlp and Deno
from their official releases, verifying publisher SHA-256 checksums. It keeps
an existing verified minimal FFmpeg, or builds it locally if absent, changed,
or requested with `-RebuildFfmpeg`. **The first FFmpeg build requires Docker
Desktop running in Linux container mode.**

Windows builds copy only `yt-dlp.exe`, `deno.exe` and `ffmpeg.exe` into `tools/`
next to `twitch_listener.exe`, together with FFmpeg's build manifest and license
notices. Include this folder when distributing the app. Executables and generated
build metadata are ignored by Git. Bundled tools take precedence over PATH.
FFprobe is not needed; incremental Windows builds remove its former bundled copy.

## Minimal FFmpeg build

```powershell
powershell -ExecutionPolicy Bypass -File tools/build_ffmpeg.ps1
```

The recipe in `ffmpeg/Dockerfile` cross-compiles FFmpeg **9.0.2** and LAME
**3.100** to a standalone Windows x64 executable. The verified build is
**3,840,512 bytes** (about 3.84 MB), compared with 102,856,192 bytes for the
previous FFmpeg and another 102,652,416 bytes for FFprobe. It imports only
Windows system DLLs. Docker and the compiler are build-time dependencies.

Enabled audio decoders: AAC, Opus, Vorbis, MP3, float32 PCM and int16 PCM.
Input containers: MP4/M4A, Matroska/WebM, Ogg, MP3, WAV and raw AAC.
Output: MP3 through `libmp3lame`, plus PCM for the null analysis sink.
Processing: `loudnorm`, channel/sample-format conversion and resampling, plus
the FFmpeg command-line frontend's required helper filters. Only the `file`
and `pipe` protocols are enabled. Video decoding/encoding, GPU support, devices,
networking, FFplay and FFprobe are excluded. yt-dlp handles all network access.

The source versions, SHA-256 hashes and container base digest are pinned. The
FFmpeg archive hash was verified against its official release signature; LAME's
upstream archive is downloaded from Debian's mirror and checked against its
published source checksum. `build/ffmpeg-minimal/` retains the compiler package
list, configuration log and DLL import list. `tools/ffmpeg-build.json` records
the output hash and recipe hash; updating the downloader cannot silently replace
this binary with a full build. This is a repeatable build recipe, not a guarantee
of bit-for-bit identical output across different compiler package updates.

Source archives remain under `build/ffmpeg-sources/`; generated license notices
are included with the Windows bundle. The app's general audio player continues
to use media_kit; this reduced FFmpeg is specifically for preparing YouTube music.

## Audio preparation

yt-dlp downloads one original stream (`bestaudio/best`, `--fixup never`).
FFmpeg then measures the complete track with `loudnorm`, and performs a second
pass using those measurements to normalize and encode directly to MP3
(`libmp3lame`, quality 2, stereo, 48 kHz). Both passes use the same stereo
conversion so mono and multichannel inputs are measured consistently.

The profile targets **-16 LUFS integrated** and **-2 dBTP true peak**. The allowed
loudness range is the larger of 20 LU and the measured source range, capped at
FFmpeg's 50 LU limit. This preserves dynamics and avoids forcing dynamic mode
merely because a source slightly exceeds 20 LU. Linear gain is preferred;
loudnorm can fall back to dynamic processing for peak/range constraints.
The true-peak limit applies before MP3 encoding, which may slightly change
decoded peaks. These values normalize individual tracks; the player's volume
slider and any downstream mixer still determine the final broadcast level.

Only completed output is moved into the cache. Cache profiles include the
normalization settings and encoding recipe, so original files from the old
`youtube-native-audio-v1` profile are never reused as normalized tracks. Old
profiles are retained on disk; the current 2 GiB cache limit applies to the
active profile. Settings are currently constructor defaults in
`FfmpegAudioProcessor`, rather than user-facing controls.

The queue displays separate download, loudness-analysis and normalization
progress. Removing a pending request or closing the app cancels processing.
Each FFmpeg pass has a ten-minute timeout. Silent/unmeasurable input and
processing failures produce a queue error and advance to the next request.

## Checks

`flutter test test/music` includes real normalization checks when
`tools/ffmpeg.exe` exists (or `MUSIC_FFMPEG` names another executable). They
generate local quiet, loud, mono and dynamic signals in Dart and remeasure the decoded
MP3, checking integrated loudness within 0.5 LU of the target and true peak
with a 0.5 dB encoding tolerance. No YouTube connection is needed for these
tests. Small synthetic fixtures also exercise AAC/M4A, Opus/WebM, Vorbis/Ogg and
an MP4 with video and audio. They require no full FFmpeg build to run; fixture
regeneration commands are in `test/music/fixtures/README.md`.
Native playback can be checked separately using `MUSIC_SMOKE_FILE` and
`MUSIC_MPV_LIBRARY` as described in `test/music/native_music_smoke_test.dart`.

If YouTube extraction stops working, rerun the download script to update yt-dlp
and Deno, then rebuild the app. To update FFmpeg, update the pinned source version
and verified hash in both build files, rebuild, and run the audio tests. The app
never updates tools or uses browser cookies automatically.

References: [yt-dlp](https://github.com/yt-dlp/yt-dlp#dependencies),
[Deno releases](https://github.com/denoland/deno/releases),
[FFmpeg loudnorm](https://ffmpeg.org/ffmpeg-filters.html#loudnorm),
[FFmpeg source releases](https://ffmpeg.org/download.html),
[LAME](https://lame.sourceforge.io/).

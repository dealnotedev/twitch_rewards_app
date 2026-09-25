# YouTube music tools

Run `powershell -ExecutionPolicy Bypass -File tools/download_tools.ps1` from the
repository root to download the official Windows x64 builds of yt-dlp and Deno.
The script verifies the publishers' SHA-256 checksums. Executables are ignored by
Git. You can also place existing `yt-dlp.exe` and `deno.exe` here.

Windows builds copy these files into `tools/` next to `twitch_listener.exe`.
Include this folder when distributing the app. If bundled tools are absent,
yt-dlp and its default Deno runtime can also be found through PATH.

No separate `ffmpeg.exe` or `ffprobe.exe` is required. The downloader selects one
original audio stream (`bestaudio/best`, `--fixup never`) without extraction,
transcoding or merging. The existing media_kit audio backend decodes it directly.
Its native playback libraries are already included by Flutter's plugin build.

If YouTube extraction stops working, rerun the script and rebuild, or replace
the two binaries in the installed app's `tools/` directory with current official
releases. The app never updates tools or uses browser cookies automatically.

References: [yt-dlp](https://github.com/yt-dlp/yt-dlp#dependencies),
[Deno releases](https://github.com/denoland/deno/releases),
[media_kit](https://github.com/media-kit/media-kit).

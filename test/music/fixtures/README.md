# Audio decoder fixtures

These four-second synthetic tones contain no downloaded media. They exercise
the minimal FFmpeg's input decoders and demuxers, including the combined
video/audio fallback selected by yt-dlp when a separate audio stream is absent.

Generated with a full FFmpeg 9.0.1 build using:

```sh
ffmpeg -f lavfi -i 'sine=frequency=440:duration=4:sample_rate=48000' -c:a aac -b:a 64k aac.m4a
ffmpeg -f lavfi -i 'sine=frequency=440:duration=4:sample_rate=48000' -c:a libopus -b:a 32k opus.webm
ffmpeg -f lavfi -i 'sine=frequency=440:duration=4:sample_rate=48000' -c:a libvorbis -q:a 2 vorbis.ogg
ffmpeg -f lavfi -i 'sine=frequency=440:duration=4:sample_rate=48000' -f lavfi -i 'color=size=16x16:rate=1:duration=4' -c:a aac -b:a 64k -c:v libx264 -pix_fmt yuv420p -shortest video-with-aac.mp4
```

The full build is only needed to regenerate these fixtures, not to run tests
or the application. WAV signals for loudness tests are generated directly in
Dart by `audio_fixture.dart`.

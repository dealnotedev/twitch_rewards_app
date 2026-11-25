# Build a standalone Windows x64 audio processor, without a Windows SDK install.
FROM debian:bookworm-slim@sha256:3783cc01769c7b2b1b83a5c5ad96c815348e28ed7da68e2e3687004faa906251 AS builder

RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc libc6-dev gcc-mingw-w64-x86-64-win32 binutils-mingw-w64-x86-64 make nasm xz-utils \
    && rm -rf /var/lib/apt/lists/*

COPY ffmpeg-9.0.2.tar.xz lame-3.100.tar.gz /sources/
RUN cd /sources && \
    echo '8c3850283eb25fa026482078a04051e0be17347b09ef81a0849bec15a96e002e  ffmpeg-9.0.2.tar.xz' | sha256sum -c - && \
    echo 'ddfe36cab873794038ae2c1210557ad34857a4b6bdc515785d1da9e175b1da1e  lame-3.100.tar.gz' | sha256sum -c - && \
    tar -xf ffmpeg-9.0.2.tar.xz && tar -xf lame-3.100.tar.gz

ARG JOBS=4
WORKDIR /sources/lame-3.100
RUN ./configure --host=x86_64-w64-mingw32 --prefix=/opt/audio \
    --disable-shared --enable-static --disable-frontend --disable-decoder \
    CFLAGS='-Os -ffunction-sections -fdata-sections' \
    && make -j${JOBS} && make install

WORKDIR /sources/ffmpeg-9.0.2
# PCM/WAV are retained for deterministic tests and the null analysis output.
# Keep audio only: no networking, video, GPU libraries, devices or extra tools.
RUN ./configure --prefix=/opt/ffmpeg --target-os=mingw32 --arch=x86_64 \
    --enable-cross-compile --cross-prefix=x86_64-w64-mingw32- \
    --disable-everything --disable-autodetect --disable-network \
    --disable-doc --disable-debug --disable-shared --enable-static --enable-small \
    --disable-ffplay --disable-ffprobe --disable-avdevice --disable-swscale \
    --enable-libmp3lame \
    --enable-decoder=aac,opus,vorbis,mp3float,pcm_s16le,pcm_f32le \
    --enable-demuxer=mov,matroska,ogg,mp3,wav,aac \
    --enable-parser=aac,opus,vorbis,mpegaudio \
    --enable-encoder=libmp3lame,pcm_s16le \
    --enable-muxer=mp3,null --enable-protocol=file,pipe \
    --enable-filter=abuffer,abuffersink,aformat,aresample,anull,atrim,loudnorm \
    --extra-cflags='-I/opt/audio/include -Os -ffunction-sections -fdata-sections' \
    --extra-ldflags='-L/opt/audio/lib -static -Wl,--gc-sections -Wl,--no-insert-timestamp' \
    && make -j${JOBS} ffmpeg.exe \
    && x86_64-w64-mingw32-strip ffmpeg.exe

RUN mkdir -p /out/ffmpeg-notices && cp ffmpeg.exe /out/ && \
    cp COPYING.LGPLv2.1 /out/ffmpeg-notices/FFmpeg-LGPL-2.1.txt && \
    cp /sources/lame-3.100/COPYING /out/ffmpeg-notices/LAME-LGPL-2.0.txt && \
    cp ffbuild/config.log /out/ffmpeg-config.log && \
    x86_64-w64-mingw32-objdump -p ffmpeg.exe | grep 'DLL Name:' > /out/ffmpeg-imports.txt && \
    dpkg-query -W > /out/build-packages.txt

FROM scratch AS export
COPY --from=builder /out/ /

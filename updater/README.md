# Twitch Listener Updater

Standalone Flutter application for Windows, distributed in `updater/` next to
`twitch_listener.exe`. It has its own Flutter runtime and needs no installed SDK.

The main application checks for an update once per launch. A dismissible banner
between the Twitch/OBS settings and rewards opens the updater with the active
locale and the currently displayed light or dark theme. Parameters only travel
from Listener to the updater. Standalone launches use the system locale/theme.

```powershell
updater/listener_updater.exe --install-dir D:/Listener --locale en --theme dark
```

The UI and Listener share `packages/listener_ui` themes. English and Ukrainian
catalogs live in `lib/l10n/`. Release notes keep the author's language.

The updater downloads `update.zip` from the latest stable release of
`dealnotedev/twitch_rewards_app`, verifies its size and SHA-256 from GitHub asset
metadata, and extracts it on the installation volume. Listener keeps running
during download and verification. Before replacement, the updater terminates
processes whose full executable path matches this installation. Updates are
intended to be started while Listener is idle; no save or shutdown handshake is
performed. The updater never terminates another installation by executable name.

`listener-update.json` (schema 1, application `twitch_listener`) identifies the
installation version and managed top-level roots. Installed copies without this
manifest require the complete `Release.zip` once before using the updater.
Managed roots include `data`, DLLs and the bundled `tools` directory. Paths,
links, runtime files, tool binaries, versions and archive limits are checked.
AppData settings, the rewards database, music cache and YouTube session are not
part of the update package.

Files are staged in `.listener-update`. A flushed journal precedes replacement;
exceptions restore the previous files. After an interruption, reopening the
updater restores the installation before checking GitHub. A Windows mutex
prevents Listener from starting during replacement/recovery. Cancel/close is
available during download and blocked during installation. Same-version
reinstallation and installation of an older stable release are supported.
File rollback does not restore changes to AppData made by an application version.
The running updater folder is excluded from updates; updating the updater itself
requires the complete distribution. The installation folder must be writable.

From the repository root:

```powershell
./tools/build_release.ps1
# Publishing is opt-in, after incrementing pubspec.yaml and committing/pushing:
./tools/build_release.ps1 -Publish -NotesFile ./release-notes.md
```

The script checks both applications, builds them, validates bundled music tools,
and creates `build/releases/<version>-<timestamp>/Release.zip`, `update.zip` and
`SHA256SUMS.txt`. Keep version tags in `major.minor.patch` format. The manifest
and EXE additionally retain the Flutter `+build` suffix. The script retains the
main application's `NO_OPUS_OGG_LIBS=1` build setting and existing AppData identity.

For updater-only development:

```powershell
cd updater
flutter pub get
flutter test
flutter analyze --no-fatal-infos
flutter run -d windows -- --install-dir D:/Listener --locale uk --theme light
```

Tests use fake HTTP/native bridges and temporary installations. They do not stop
the user's Listener. UI tests cover both themes/languages and create PNG previews
under `build/previews/`.

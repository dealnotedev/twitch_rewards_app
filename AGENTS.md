# Release packaging

- Do not include `kernel_blob.bin` in release builds or distribution archives
  (`Release.zip` and `update.zip`). This applies to both Listener and its updater.
- Keep this exclusion when changing Windows build or release packaging scripts.

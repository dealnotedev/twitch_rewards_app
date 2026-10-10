import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:observable_state/observable_state.dart';
import 'package:listener_ui/themes.dart';

import 'core/update_failure.dart';
import 'l10n/failure_message.dart';

import 'update_view_model.dart';
import 'release_notes.dart';
import 'l10n/generated/updater_localizations.dart';

ThemeData updaterTheme([Brightness brightness = Brightness.dark]) =>
    brightness == Brightness.dark ? Themes.dark : Themes.light;

final class UpdatePresentation {
  const UpdatePresentation({
    required this.phase,
    required this.title,
    required this.detail,
    required this.action,
    this.current = '—',
    this.latest = '—',
    this.notes = '',
    this.progress,
    this.busy = false,
    this.critical = false,
  });
  factory UpdatePresentation.fromState(
    UpdateState state,
    UpdaterLocalizations strings,
  ) {
    String megabytes(int bytes) =>
        NumberFormat('0.0', strings.localeName).format(bytes / 1048576);
    final (title, detail) = switch (state.phase) {
      UpdatePhase.checking => (strings.checkingTitle, strings.checkingDetail),
      UpdatePhase.current => (strings.currentTitle, strings.currentDetail),
      UpdatePhase.available => (
        switch (state.releaseComparison) {
          > 0 => strings.availableTitle,
          0 => strings.reinstallTitle,
          _ => strings.downgradeTitle,
        },
        strings.packageSize(megabytes(state.release!.size)),
      ),
      UpdatePhase.downloading => (
        strings.downloadTitle,
        strings.downloadDetail,
      ),
      UpdatePhase.verifying => (strings.verifyTitle, strings.verifyDetail),
      UpdatePhase.stopping => (strings.stopTitle, strings.stopDetail),
      UpdatePhase.installing => (strings.installTitle, strings.installDetail),
      UpdatePhase.recovering => (strings.recoveryTitle, strings.recoveryDetail),
      UpdatePhase.done => (strings.doneTitle, strings.doneDetail),
      UpdatePhase.error => (
        strings.errorTitle,
        failureMessage(strings, state.error ?? UpdateIssue.unexpected),
      ),
    };
    final action = switch (state.phase) {
      UpdatePhase.error => strings.retry,
      UpdatePhase.current || UpdatePhase.done => strings.openListener,
      UpdatePhase.available => switch (state.releaseComparison) {
        > 0 => strings.updateListener,
        0 => strings.reinstallListener,
        _ => strings.downgradeListener(state.release!.version.toString()),
      },
      UpdatePhase.downloading => strings.downloadingAction,
      UpdatePhase.checking => strings.checkingAction,
      _ => strings.preparingAction,
    };
    return UpdatePresentation(
      phase: state.phase,
      title: title,
      detail: detail,
      action: action,
      current: state.installedVersion?.toString() ?? '—',
      latest:
          state.release?.version.toString() ??
          (state.phase == UpdatePhase.checking ? strings.checkingAction : '—'),
      notes: state.release?.notes ?? '',
      progress: state.progress,
      busy: state.busy,
      critical: state.critical,
    );
  }
  final UpdatePhase phase;
  final String current, latest, notes, title, detail, action;
  final double? progress;
  final bool busy, critical;
}

class UpdaterView extends StatelessWidget {
  const UpdaterView({
    required this.state,
    required this.onAction,
    required this.onCancel,
    this.download,
    super.key,
  });

  final UpdatePresentation state;
  final Observable<DownloadProgress>? download;
  final VoidCallback onAction, onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = UpdaterLocalizations.of(context);
    return Scaffold(
      backgroundColor: theme.surfacePrimary,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 840),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: theme.accentSubtle,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.system_update_alt_rounded,
                        color: theme.accentColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            strings.heading,
                            style: TextStyle(
                              color: theme.textColorPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Twitch Listener',
                            style: TextStyle(
                              color: theme.textColorSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: theme.cardDecoration,
                  child: Row(
                    children: [
                      Expanded(
                        child: _Version(
                          label: strings.installedLabel,
                          value: state.current,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Icon(
                          Icons.arrow_forward_rounded,
                          size: 18,
                          color: theme.textColorSecondary,
                        ),
                      ),
                      Expanded(
                        child: _Version(
                          label: strings.latestLabel,
                          value: state.latest,
                          accent: true,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(child: _NotesPanel(state: state)),
                const SizedBox(height: 16),
                if (download case final source?)
                  ObservableBuilder<DownloadProgress>(
                    source: source,
                    builder: (context, download, _) => _Status(
                      state: state,
                      download: download,
                      onCancel: onCancel,
                    ),
                  )
                else
                  _Status(state: state, onCancel: onCancel),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(
                      Icons.folder_outlined,
                      size: 16,
                      color: theme.textColorSecondary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        strings.settingsDetail,
                        style: TextStyle(
                          color: theme.textColorSecondary,
                          fontSize: 11,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    FilledButton(
                      onPressed: state.busy ? null : onAction,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(146, 36),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        backgroundColor: theme.buttonColorPrimary,
                        foregroundColor: theme.textColorPrimaryInverted,
                        disabledBackgroundColor: theme.buttonColorPrimary
                            .withValues(alpha: .56),
                        disabledForegroundColor: theme.textColorPrimaryInverted
                            .withValues(alpha: .75),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: Text(
                        state.action,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NotesPanel extends StatefulWidget {
  const _NotesPanel({required this.state});
  final UpdatePresentation state;
  @override
  State<_NotesPanel> createState() => _NotesPanelState();
}

class _NotesPanelState extends State<_NotesPanel> {
  final _scroll = ScrollController();
  @override
  void didUpdateWidget(covariant _NotesPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.notes != widget.state.notes && _scroll.hasClients) {
      _scroll.jumpTo(0);
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = UpdaterLocalizations.of(context);
    final state = widget.state;
    return Container(
      decoration: theme.cardDecoration,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: theme.surfaceTertiary,
              border: Border(
                bottom: BorderSide(color: theme.border, width: .5),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.description_outlined,
                  size: 16,
                  color: theme.textColorSecondary,
                ),
                const SizedBox(width: 8),
                Text(
                  strings.whatsNew,
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.textColorPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: theme.accentSubtle,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    strings.stableRelease,
                    style: TextStyle(
                      color: theme.accentColor,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Scrollbar(
              controller: _scroll,
              thumbVisibility: true,
              thickness: 4,
              radius: const Radius.circular(4),
              child: SingleChildScrollView(
                controller: _scroll,
                padding: const EdgeInsets.all(16),
                child: state.notes.trim().isEmpty
                    ? SelectableText(
                        state.phase == UpdatePhase.checking
                            ? strings.loadingNotes
                            : strings.noNotes,
                        style: TextStyle(
                          color: theme.textColorSecondary,
                          fontSize: 13,
                          height: 1.6,
                        ),
                      )
                    : ReleaseNotes(data: state.notes),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Version extends StatelessWidget {
  const _Version({
    required this.label,
    required this.value,
    this.accent = false,
  });
  final String label, value;
  final bool accent;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: theme.textColorSecondary,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: TextStyle(
            color: accent ? theme.accentColor : theme.textColorPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _Status extends StatelessWidget {
  const _Status({required this.state, required this.onCancel, this.download});
  final UpdatePresentation state;
  final DownloadProgress? download;
  final VoidCallback onCancel;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final error = state.phase == UpdatePhase.error;
    final downloading = state.phase == UpdatePhase.downloading;
    final strings = UpdaterLocalizations.of(context);
    final progress = downloading && download != null
        ? download!.fraction
        : state.progress;
    String megabytes(int bytes) =>
        NumberFormat('0.0', strings.localeName).format(bytes / 1048576);
    final detail = downloading && download != null && download!.received > 0
        ? strings.downloadProgress(
            megabytes(download!.received),
            megabytes(download!.total),
          )
        : state.detail;
    final statusColor = error ? theme.colorScheme.error : theme.accentColor;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: theme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                error
                    ? Icons.info_outline_rounded
                    : state.phase == UpdatePhase.done ||
                          state.phase == UpdatePhase.current
                    ? Icons.check_circle_outline_rounded
                    : Icons.downloading_rounded,
                size: 16,
                color: statusColor,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  state.title,
                  style: TextStyle(
                    color: theme.textColorPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (downloading && progress != null)
                Text(
                  '${(progress * 100).round()}%',
                  style: TextStyle(color: theme.accentColor, fontSize: 12),
                ),
              if (downloading && state.busy && !state.critical) ...[
                const SizedBox(width: 12),
                TextButton(
                  onPressed: onCancel,
                  style: TextButton.styleFrom(
                    foregroundColor: theme.accentColor,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    textStyle: const TextStyle(fontSize: 11),
                  ),
                  child: Text(strings.cancelDownload),
                ),
              ],
            ],
          ),
          const SizedBox(height: 5),
          Text(
            detail,
            style: TextStyle(
              color: theme.textColorSecondary,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          if (state.busy && !error) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 3,
                backgroundColor: theme.surfaceTertiary,
                color: theme.accentColor,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

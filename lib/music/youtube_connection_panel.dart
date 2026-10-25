import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:twitch_listener/core/extensions.dart';
import 'package:twitch_listener/music/music_requests.dart';
import 'package:twitch_listener/music/youtube_browser_session.dart';
import 'package:twitch_listener/music/youtube_connection_controller.dart';
import 'package:twitch_listener/ui/themes.dart';

/// Shared connection controls, presented inside each Play YouTube Track card.
class YoutubeConnectionPanel extends StatefulWidget {
  final YoutubeConnectionController connection;
  final MusicRequestManager requests;

  const YoutubeConnectionPanel({
    super.key,
    required this.connection,
    required this.requests,
  });

  @override
  State<YoutubeConnectionPanel> createState() => _YoutubeConnectionPanelState();
}

class _YoutubeConnectionPanelState extends State<YoutubeConnectionPanel> {
  bool _showYoutubeDetails = false;
  bool _confirmYoutubeDisconnect = false;

  TextStyle get _title => TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: Theme.of(context).textColorPrimary,
  );
  TextStyle get _secondary => TextStyle(
    fontSize: 12,
    height: 1.4,
    color: Theme.of(context).textColorSecondary,
  );
  TextStyle get _errorStyle =>
      _secondary.copyWith(color: Theme.of(context).colorScheme.error);

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.connection,
    builder: (context, _) => StreamBuilder<MusicQueueSnapshot>(
      stream: widget.requests.states,
      initialData: widget.requests.current,
      builder: (context, _) => _youtubePanel(),
    ),
  );

  Widget _youtubePanel() {
    final connection = widget.connection;
    final requests = widget.requests;
    final l = context.localizations;
    final status = connection.status;
    final waiting = status == YoutubeConnectionStatus.awaitingVerification;
    final checking = status == YoutubeConnectionStatus.checking;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l.music_youtube_title, style: _title),
        const Gap(6),
        Text(l.music_youtube_description, style: _secondary),
        if (requests.current.hold != null) ...[
          const Gap(12),
          _holdNotice(requests),
        ],
        // Without a session, the reason below replaces the general hint.
        if (switch (status) {
              YoutubeConnectionStatus.disconnected
                  when connection.issue != null =>
                null,
              YoutubeConnectionStatus.disconnected =>
                l.music_youtube_disconnected,
              YoutubeConnectionStatus.opening => l.music_youtube_opening,
              YoutubeConnectionStatus.awaitingVerification =>
                l.music_youtube_instructions,
              YoutubeConnectionStatus.checking => l.music_youtube_checking,
              YoutubeConnectionStatus.connected when connection.issue != null =>
                l.music_youtube_saved_attention,
              YoutubeConnectionStatus.connected =>
                connection.verifiedThisSession
                    ? l.music_youtube_connected
                    : l.music_youtube_saved,
            }
            case final statusText?) ...[
          const Gap(10),
          Text(
            statusText,
            key: const ValueKey('music_youtube_status'),
            style: _secondary,
          ),
        ],
        if (checking) ...[
          const Gap(8),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              key: const ValueKey('music_youtube_progress'),
              value: connection.checkProgress,
              minHeight: 3,
              color: Theme.of(context).accentColor,
              backgroundColor: Theme.of(context).accentColor
                  .withValues(alpha: 0.15),
            ),
          ),
        ],
        if (waiting) ...[
          const Gap(8),
          Text(
            l.music_youtube_account_warning,
            key: const ValueKey('music_youtube_account_warning'),
            style: _secondary,
          ),
        ],
        if (connection.issue case final issue?) ...[
          const Gap(8),
          Text(
            switch (issue) {
              YoutubeConnectionIssue.browserUnavailable =>
                l.music_youtube_no_browser,
              YoutubeConnectionIssue.browserClosed =>
                l.music_youtube_browser_closed,
              YoutubeConnectionIssue.verificationRequired =>
                l.music_youtube_verification_required,
              YoutubeConnectionIssue.downloadBlocked =>
                l.music_youtube_download_blocked,
              YoutubeConnectionIssue.rateLimited =>
                l.music_youtube_rate_limited,
              YoutubeConnectionIssue.chooseVideo =>
                l.music_youtube_choose_video,
              YoutubeConnectionIssue.videoUnavailable =>
                l.music_youtube_video_unavailable,
              YoutubeConnectionIssue.videoTooLongOrLive =>
                l.music_youtube_video_too_long,
              YoutubeConnectionIssue.networkUnavailable =>
                l.music_youtube_network_error,
              YoutubeConnectionIssue.toolsUnavailable =>
                l.music_youtube_tools_error,
              YoutubeConnectionIssue.storageUnavailable =>
                l.music_youtube_storage_error,
              YoutubeConnectionIssue.checkFailed => l.music_youtube_check_error,
            },
            key: const ValueKey('music_youtube_issue'),
            style: _errorStyle,
          ),
        ],
        if (connection.checkedVideoUrl case final url?) ...[
          const Gap(8),
          SelectableText(
            l.music_youtube_checked_video(url.toString()),
            style: _secondary,
          ),
        ],
        if (connection.diagnostic case final diagnostic?) ...[
          const Gap(8),
          _ConnectionButton(
            key: const ValueKey('music_youtube_diagnostic'),
            label: l.music_youtube_error_details,
            icon: _showYoutubeDetails ? Icons.expand_less : Icons.expand_more,
            selected: _showYoutubeDetails,
            onPressed: () =>
                setState(() => _showYoutubeDetails = !_showYoutubeDetails),
          ),
          if (_showYoutubeDetails) ...[
            const Gap(8),
            SelectableText(diagnostic, style: _secondary),
          ],
        ],
        const Gap(12),
        if (_confirmYoutubeDisconnect &&
            connection.hasSession &&
            !connection.busy)
          _youtubeDisconnectConfirmation(connection)
        else
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              if (!checking)
                _ConnectionButton(
                  key: const ValueKey('music_youtube_connect'),
                  label: waiting
                      ? l.music_youtube_reopen
                      : connection.hasSession
                      ? l.music_youtube_reconnect
                      : l.music_youtube_connect,
                  icon: Icons.open_in_new_rounded,
                  onPressed: connection.busy
                      ? null
                      : () => unawaited(connection.connect()),
                ),
              if (waiting)
                _ConnectionButton(
                  key: const ValueKey('music_youtube_verify'),
                  label: l.music_youtube_verify,
                  icon: Icons.check_circle_outline,
                  onPressed: () => unawaited(connection.verify()),
                ),
              // Cancelling only stops this attempt; the saved session stays.
              if (waiting || checking)
                _ConnectionButton(
                  key: const ValueKey('music_youtube_cancel'),
                  label: l.music_youtube_cancel,
                  icon: Icons.close_rounded,
                  onPressed: () => unawaited(connection.cancel()),
                )
              else if (connection.hasSession)
                _ConnectionButton(
                  key: const ValueKey('music_youtube_disconnect'),
                  label: l.music_youtube_disconnect,
                  icon: Icons.link_off_rounded,
                  onPressed: connection.busy
                      ? null
                      : () => setState(() => _confirmYoutubeDisconnect = true),
                ),
            ],
          ),
      ],
    );
  }

  Widget _holdNotice(MusicRequestManager requests) {
    final l = context.localizations;
    final waitingRequests = requests.current.queue
        .where((item) => item.phase == MusicQueueItemPhase.resolving)
        .length;
    return Container(
      key: const ValueKey('music_youtube_hold'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Theme.of(context).colorScheme.error.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.music_youtube_hold_title,
            style: _title.copyWith(color: Theme.of(context).colorScheme.error),
          ),
          const Gap(4),
          Text(l.music_youtube_hold_body(waitingRequests), style: _secondary),
          const Gap(10),
          _ConnectionButton(
            key: const ValueKey('music_youtube_resume'),
            label: l.music_youtube_resume,
            icon: Icons.play_arrow_rounded,
            onPressed: () => requests.resumePreparation(),
          ),
        ],
      ),
    );
  }

  Widget _youtubeDisconnectConfirmation(
    YoutubeConnectionController connection,
  ) {
    final l = context.localizations;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l.music_youtube_disconnect_confirm, style: _errorStyle),
        const Gap(8),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            _ConnectionButton(
              key: const ValueKey('music_youtube_disconnect_remove'),
              label: l.music_youtube_disconnect_remove,
              icon: Icons.delete_outline_rounded,
              onPressed: () {
                setState(() => _confirmYoutubeDisconnect = false);
                unawaited(connection.disconnect());
              },
            ),
            _ConnectionButton(
              key: const ValueKey('music_youtube_disconnect_keep'),
              label: l.music_youtube_disconnect_keep,
              icon: Icons.undo_rounded,
              onPressed: () =>
                  setState(() => _confirmYoutubeDisconnect = false),
            ),
          ],
        ),
      ],
    );
  }
}

/// A wrapping label lets the controls fit narrow cards and larger text scales.
class _ConnectionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool selected;

  const _ConnectionButton({
    super.key,
    required this.label,
    required this.icon,
    this.onPressed,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: selected ? theme.accentColor : theme.textColorPrimary,
        backgroundColor: selected
            ? theme.accentSubtle
            : theme.buttonColorSecondary,
        disabledForegroundColor: theme.textColorSecondary,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        minimumSize: const Size(0, 36),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: BorderSide(color: theme.border, width: .5),
        ),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const Gap(8),
          Flexible(child: Text(label)),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../actions/volume_slider.dart';
import '../extensions.dart';
import '../generated/assets.dart';
import '../observable_value.dart';
import '../ripple_icon.dart';
import '../themes.dart';
import 'music_requests.dart';

class MusicPlayerPanel extends StatefulWidget {
  final MusicRequestManager requests;

  const MusicPlayerPanel({super.key, required this.requests});

  @override
  State<MusicPlayerPanel> createState() => _MusicPlayerPanelState();
}

class _MusicPlayerPanelState extends State<MusicPlayerPanel> {
  bool _queueExpanded = false;
  bool _busy = false;
  double? _seekPreview;
  String? _seekItem;
  final _volume = ObservableValue<double>(current: 1);

  MusicRequestManager get requests => widget.requests;

  @override
  void dispose() {
    _volume.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<MusicQueueSnapshot>(
      stream: requests.states,
      initialData: requests.current,
      builder: (context, snapshot) {
        final state = snapshot.requireData;
        _volume.current = state.volume;
        if (state.nowPlaying == null &&
            state.queue.isEmpty &&
            state.lastError == null) {
          return const SizedBox.shrink();
        }
        final theme = Theme.of(context);
        return Material(
          color: theme.surfaceSecondary,
          child: DecoratedBox(
            decoration: BoxDecoration(
                border: Border(top: BorderSide(color: theme.border))),
            child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (state.lastError != null)
                      _error(context, state.lastError!),
                    if (state.nowPlaying != null || state.queue.isNotEmpty) ...[
                      Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _trackRow(context, state),
                              const Gap(8),
                              _timeline(context, state),
                            ],
                          )),
                      if (_queueExpanded) _queue(context, state),
                    ],
                  ],
                )),
          ),
        );
      },
    );
  }

  Widget _trackRow(BuildContext context, MusicQueueSnapshot state) {
    final theme = Theme.of(context);
    final item = state.nowPlaying?.item ?? state.queue.first;
    final subtitle = [item.author, item.requestedBy]
        .whereType<String>()
        .where((s) => s.isNotEmpty)
        .join(' · ');
    return Row(children: [
      _MusicTrackCover(
        key: const ValueKey('music-cover'),
        thumbnail: item.thumbnail,
        size: 44,
      ),
      const Gap(12),
      Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
            Text(item.title ?? context.localizations.music_resolving,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: theme.textColorPrimary)),
            const Gap(4),
            Text(state.nowPlaying == null ? _phase(context, item) : subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    TextStyle(fontSize: 12, color: theme.textColorSecondary)),
          ])),
      const Gap(12),
      _controls(context, state),
    ]);
  }

  Widget _controls(BuildContext context, MusicQueueSnapshot state) {
    final l = context.localizations;
    final theme = Theme.of(context);
    final active = state.nowPlaying;
    final enabled = active != null && !_busy;
    final color = enabled ? theme.textColorPrimary : theme.textColorDisabled;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Semantics(
        label: active?.paused == true ? l.music_resume : l.music_pause,
        button: true,
        enabled: enabled,
        child: Tooltip(
          message: active?.paused == true ? l.music_resume : l.music_pause,
          excludeFromSemantics: true,
          child: RippleIcon(
            key: const ValueKey('music-pause'),
            borderRadius: BorderRadius.circular(8),
            size: 16,
            color: color,
            icon: active?.paused == true ? Assets.assetsIcPlayWhite16dp : null,
            iconWidget: Icon(Icons.pause, size: 16, color: color),
            onTap: enabled
                ? () => _command(() => requests.setPaused(!active.paused))
                : null,
          ),
        ),
      ),
      Semantics(
        label: l.music_skip,
        button: true,
        enabled: enabled,
        child: Tooltip(
          message: l.music_skip,
          excludeFromSemantics: true,
          child: RippleIcon(
            key: const ValueKey('music-next'),
            borderRadius: BorderRadius.circular(8),
            icon: Assets.assetsIcNextWhite16dp,
            size: 16,
            color: color,
            onTap: enabled ? () => _command(requests.skip) : null,
          ),
        ),
      ),
      const Gap(8),
      Semantics(
        label: l.music_volume,
        child: VolumeSlider(
          theme: theme,
          volume: _volume,
          max: 1,
          divisions: 100,
          onChangeChange: (value) => requests.setVolume(value),
          onChangeEnd: (_) => requests.saveVolume(),
        ),
      ),
      const Gap(8),
      _MusicQueueButton(
        key: const ValueKey('music-queue'),
        count: state.queue.length,
        expanded: _queueExpanded,
        onTap: () => setState(() => _queueExpanded = !_queueExpanded),
      ),
    ]);
  }

  Future<void> _command(Future<bool> Function() command) async {
    setState(() => _busy = true);
    try {
      await command();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _timeline(BuildContext context, MusicQueueSnapshot state) {
    final active = state.nowPlaying;
    if (active == null) {
      return Padding(
          padding: const EdgeInsets.only(top: 4),
          child: LinearProgressIndicator(
              value: state.queue.first.downloadProgress, minHeight: 3));
    }
    final duration = active.item.duration ?? Duration.zero;
    final total = duration.inMilliseconds.toDouble();
    final position = (_seekItem == active.item.id ? _seekPreview : null) ??
        active.position.inMilliseconds.toDouble();
    return Row(children: [
      Text(_time(Duration(milliseconds: position.round())),
          style: const TextStyle(fontSize: 11)),
      Expanded(
          child: SliderTheme(
        data: SliderTheme.of(context).copyWith(
            trackHeight: 2,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5)),
        child: Slider(
          value: position.clamp(0, total),
          max: total > 0 ? total : 1,
          onChanged: total <= 0
              ? null
              : (value) => setState(() {
                    _seekItem = active.item.id;
                    _seekPreview = value;
                  }),
          onChangeEnd: (value) async {
            if (requests.current.nowPlaying?.item.id == active.item.id) {
              await requests.seek(Duration(milliseconds: value.round()));
            }
            if (mounted) setState(() => _seekPreview = null);
          },
        ),
      )),
      Text(_time(duration), style: const TextStyle(fontSize: 11)),
    ]);
  }

  Widget _queue(BuildContext context, MusicQueueSnapshot state) {
    final theme = Theme.of(context);
    final l = context.localizations;
    return Container(
      width: double.infinity,
      padding: state.queue.isEmpty
          ? const EdgeInsets.all(16)
          : const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
          color: theme.surfaceTertiary,
          border: Border(top: BorderSide(color: theme.border))),
      constraints:
          BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .22),
      child: state.queue.isEmpty
          ? Text(l.music_queue_empty,
              style: TextStyle(fontSize: 12, color: theme.textColorSecondary))
          : ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: state.queue.length,
              itemBuilder: (context, index) {
                final item = state.queue[index];
                return _MusicQueueRow(
                  key: ValueKey(item.id),
                  item: item,
                  position: index + 1,
                  phaseLabel: _phase(context, item),
                  onRemove: () => requests.remove(item.id),
                );
              }),
    );
  }

  Widget _error(BuildContext context, MusicQueueError error) {
    final l = context.localizations;
    final theme = Theme.of(context);
    final message = switch (error.type) {
      MusicQueueErrorType.missingYoutubeUrl => l.music_missing_url,
      MusicQueueErrorType.invalidYoutubeUrl => l.music_invalid_url,
      MusicQueueErrorType.queueFull =>
        l.music_queue_full(requests.maxQueueLength),
      MusicQueueErrorType.trackTooLongOrLive =>
        l.music_track_too_long(requests.maxDuration.inMinutes),
      MusicQueueErrorType.operationFailed => error.details ?? l.music_failed,
    };
    final text =
        error.requester.isEmpty ? message : '${error.requester}: $message';
    return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border:
              Border.all(color: theme.colorScheme.error.withValues(alpha: 0.5)),
        ),
        child: Row(children: [
          Icon(Icons.error_outline_rounded,
              size: 18, color: theme.colorScheme.error),
          const Gap(8),
          Expanded(
              child: Text(text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12))),
          Semantics(
            label: l.music_dismiss_error,
            button: true,
            child: RippleIcon(
              key: const ValueKey('music-dismiss-error'),
              borderRadius: BorderRadius.circular(8),
              icon: Assets.assetsIcCloseWhite16dp,
              size: 16,
              color: theme.textColorPrimary,
              onTap: requests.dismissError,
            ),
          ),
        ]));
  }

  String _phase(BuildContext context, MusicQueueItem item) {
    final l = context.localizations;
    switch (item.phase) {
      case MusicQueueItemPhase.resolving:
        return l.music_resolving;
      case MusicQueueItemPhase.downloading:
        final progress = item.downloadProgress;
        return progress == null
            ? l.music_downloading
            : '${l.music_downloading} ${(progress * 100).round()}%';
      case MusicQueueItemPhase.ready:
        return l.music_ready;
    }
  }

  static String _time(Duration value) {
    final seconds = value.inSeconds.clamp(0, 86400);
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }
}

class _MusicTrackCover extends StatelessWidget {
  final Uri? thumbnail;
  final double size;

  const _MusicTrackCover({
    super.key,
    required this.thumbnail,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final placeholder = ColoredBox(
      color: theme.accentSubtle,
      child: Center(
          child: Icon(Icons.music_note_rounded,
              size: size / 2, color: theme.accentColor)),
    );
    final url = thumbnail;
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox.square(
          dimension: size,
          child: url == null
              ? placeholder
              : Image.network(
                  url.toString(),
                  fit: BoxFit.cover,
                  frameBuilder: (_, child, frame, __) =>
                      frame == null ? placeholder : child,
                  errorBuilder: (_, __, ___) => placeholder,
                ),
        ),
      ),
    );
  }
}

class _MusicQueueRow extends StatelessWidget {
  final MusicQueueItem item;
  final int position;
  final String phaseLabel;
  final VoidCallback onRemove;

  const _MusicQueueRow({
    super.key,
    required this.item,
    required this.position,
    required this.phaseLabel,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = context.localizations;
    final subtitle = [item.requestedBy, phaseLabel]
        .where((text) => text.isNotEmpty)
        .join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        SizedBox(
          width: 24,
          child: Text('$position',
              style: TextStyle(fontSize: 13, color: theme.textColorSecondary)),
        ),
        const Gap(12),
        _MusicTrackCover(
          thumbnail: item.thumbnail,
          size: 36,
        ),
        const Gap(12),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.title ?? l.music_resolving,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 14,
                      height: 1.25,
                      fontWeight: FontWeight.w500,
                      color: theme.textColorPrimary)),
              const Gap(2),
              Text(subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 12,
                      height: 1.25,
                      color: theme.textColorSecondary)),
            ],
          ),
        ),
        const Gap(12),
        Semantics(
          label: l.music_remove,
          button: true,
          child: RippleIcon(
            key: ValueKey('music-remove-${item.id}'),
            borderRadius: BorderRadius.circular(8),
            icon: Assets.assetsIcDeleteWhite16dp,
            size: 16,
            color: theme.textColorPrimary,
            onTap: onRemove,
          ),
        ),
      ]),
    );
  }
}

class _MusicQueueButton extends StatelessWidget {
  final int count;
  final bool expanded;
  final VoidCallback onTap;

  const _MusicQueueButton({
    super.key,
    required this.count,
    required this.expanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = expanded ? theme.accentColor : theme.textColorPrimary;
    final radius = BorderRadius.circular(8);
    return Tooltip(
      message: context.localizations.music_queue,
      excludeFromSemantics: true,
      child: Semantics(
        label: context.localizations.music_queue,
        value: '$count',
        button: true,
        expanded: expanded,
        child: Material(
          color: expanded ? theme.accentSubtle : theme.buttonColorAlternative,
          borderRadius: radius,
          child: InkWell(
            borderRadius: radius,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.queue_music, size: 16, color: color),
                const Gap(4),
                Text('$count', style: TextStyle(fontSize: 12, color: color)),
                const Gap(4),
                Icon(expanded ? Icons.expand_more : Icons.expand_less,
                    size: 16, color: color),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

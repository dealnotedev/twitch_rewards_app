import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:open_url/open_url.dart';
import 'package:listener_ui/themes.dart';

import 'l10n/generated/updater_localizations.dart';

/// Selectable release notes, styled to match the updater.
class ReleaseNotes extends StatelessWidget {
  const ReleaseNotes({required this.data, this.openLink, super.key});

  final String data;
  final Future<void> Function(Uri)? openLink;

  static bool _webUrl(Uri uri) =>
      (uri.scheme == 'https' || uri.scheme == 'http') && uri.host.isNotEmpty;

  Future<void> _follow(BuildContext context, String? href) async {
    final uri = Uri.tryParse(href ?? '');
    if (uri == null || !_webUrl(uri)) return;
    try {
      if (openLink case final launch?) {
        await launch(uri);
      } else {
        final result = await openUrl(uri.toString());
        if (result.exitCode != 0) throw StateError('Browser launch failed');
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(UpdaterLocalizations.of(context).linkOpenFailed),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = TextStyle(
      color: theme.textColorPrimary,
      fontSize: 13,
      height: 1.65,
    );
    final heading = TextStyle(
      color: theme.textColorPrimary,
      fontWeight: FontWeight.w600,
      height: 1.35,
    );
    return MarkdownBody(
      data: data,
      selectable: true,
      fitContent: false,
      onTapLink: (_, href, _) => unawaited(_follow(context, href)),
      imageBuilder: (uri, title, alt) {
        final fallback = Text(alt ?? title ?? '', style: text);
        if (!_webUrl(uri)) return fallback;
        return ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 240),
          child: Image.network(
            uri.toString(),
            fit: BoxFit.contain,
            semanticLabel: alt,
            errorBuilder: (_, _, _) => fallback,
          ),
        );
      },
      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
        p: text,
        h1: heading.copyWith(fontSize: 22),
        h2: heading.copyWith(fontSize: 18),
        h3: heading.copyWith(fontSize: 15),
        h4: heading.copyWith(fontSize: 14),
        h5: heading.copyWith(fontSize: 13),
        h6: heading.copyWith(fontSize: 13),
        a: TextStyle(
          color: theme.accentColor,
          decoration: TextDecoration.underline,
        ),
        strong: TextStyle(
          color: theme.textColorPrimary,
          fontWeight: FontWeight.w600,
        ),
        listBullet: text.copyWith(color: theme.accentColor),
        blockSpacing: 12,
        listIndent: 22,
        blockquote: text,
        blockquotePadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 10,
        ),
        blockquoteDecoration: BoxDecoration(
          color: theme.accentSubtle,
          border: Border(left: BorderSide(color: theme.accentColor, width: 3)),
        ),
        code: TextStyle(
          fontFamily: 'Consolas',
          fontSize: 12,
          color: theme.accentColor,
          backgroundColor: theme.surfaceTertiary,
          height: 1.5,
        ),
        codeblockPadding: const EdgeInsets.all(12),
        codeblockDecoration: BoxDecoration(
          color: theme.surfaceTertiary,
          border: Border.all(color: theme.border),
          borderRadius: BorderRadius.circular(8),
        ),
        tableHead: text.copyWith(
          color: theme.textColorPrimary,
          fontWeight: FontWeight.w600,
        ),
        tableBody: text,
        tableBorder: TableBorder.all(color: theme.border),
        tableCellsPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 8,
        ),
        horizontalRuleDecoration: BoxDecoration(
          border: Border(top: BorderSide(color: theme.border)),
        ),
      ),
    );
  }
}

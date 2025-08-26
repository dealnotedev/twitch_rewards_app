import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:twitch_listener/extensions.dart';
import 'package:twitch_listener/generated/assets.dart';
import 'package:twitch_listener/simple_icon.dart';
import 'package:twitch_listener/themes.dart';

class ConnectionStatusWidget extends StatelessWidget {
  final ThemeData theme;
  final ConnectionStatus status;

  const ConnectionStatusWidget(
      {super.key, required this.theme, required this.status});

  @override
  Widget build(BuildContext context) {
    final Widget indicator;
    final Text text;
    final Color color;

    const style = TextStyle(fontSize: 12, fontWeight: FontWeight.w600);

    switch (status) {
      case ConnectionStatus.connected:
        indicator = SimpleIcon.simpleSquare(Assets.assetsIcConnectedWhite12dp,
            color: theme.textColorPrimaryInverted, size: 12);
        text = Text(context.localizations.status_connected,
            style: style.copyWith(color: theme.textColorPrimaryInverted));
        color = theme.buttonColorPrimary;
        break;

      case ConnectionStatus.connecting:
        indicator = Container(
          padding: const EdgeInsets.all(2),
          height: 16,
          width: 16,
          child: CircularProgressIndicator(
            strokeWidth: 1,
            color: theme.textColorPrimary,
          ),
        );
        text = Text(context.localizations.status_connecting,
            style: style.copyWith(color: theme.textColorPrimary));
        color = theme.buttonColorAlternative;
        break;

      case ConnectionStatus.disconnected:
        indicator = SimpleIcon.simpleSquare(
            color: theme.textColorPrimary,
            Assets.assetsIcDisconnectedWhite12dp,
            size: 12);
        text = Text(context.localizations.status_disconnected,
            style: style.copyWith(color: theme.textColorPrimary));
        color = theme.buttonColorAlternative;
        break;
    }

    return Container(
      padding: const EdgeInsets.only(left: 6, right: 8, top: 2, bottom: 2),
      decoration:
          BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [indicator, const Gap(4), text],
      ),
    );
  }
}

enum ConnectionStatus { connected, connecting, disconnected }

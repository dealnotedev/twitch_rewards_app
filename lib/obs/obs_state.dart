import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:twitch_listener/buttons.dart';
import 'package:twitch_listener/connection_status.dart';
import 'package:twitch_listener/extensions.dart';
import 'package:twitch_listener/generated/assets.dart';
import 'package:twitch_listener/obs/obs_connect.dart';
import 'package:twitch_listener/settings.dart';
import 'package:twitch_listener/simple_icon.dart';
import 'package:twitch_listener/text_field_decoration.dart';
import 'package:twitch_listener/themes.dart';

class ObsStateWidget extends StatefulWidget {
  final ObsConnect connect;
  final Settings settings;

  const ObsStateWidget(
      {super.key, required this.connect, required this.settings});

  @override
  State<StatefulWidget> createState() => _State();
}

class _State extends State<ObsStateWidget> {
  late final ObsConnect _connect;
  late final Settings _settings;

  late final TextEditingController _urlController;
  late final TextEditingController _passwordController;

  final _urlFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();

  @override
  void initState() {
    _connect = widget.connect;
    _settings = widget.settings;

    _urlController = TextEditingController(text: _settings.obsPrefs?.url);
    _passwordController =
        TextEditingController(text: _settings.obsPrefs?.password);
    super.initState();
  }

  @override
  void dispose() {
    _urlFocusNode.dispose();
    _passwordFocusNode.dispose();

    _urlController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  static Widget _createConnectionState(ThemeData theme,
      {required ObsState state}) {
    switch (state) {
      case ObsState.failed:
        return ConnectionStatusWidget(
            theme: theme, status: ConnectionStatus.disconnected);

      case ObsState.connecting:
        return ConnectionStatusWidget(
            theme: theme, status: ConnectionStatus.connecting);

      case ObsState.connected:
        return ConnectionStatusWidget(
            theme: theme, status: ConnectionStatus.connected);
    }
  }

  Widget _createButton(BuildContext context, ThemeData theme,
      {required ObsState state}) {
    switch (state) {
      case ObsState.failed:
        return CustomButton(
          text: context.localizations.button_apply,
          style: CustomButtonStyle.primary,
          theme: theme,
          onTap: () {},
        );

      case ObsState.connecting:
        return CustomButton(
          text: context.localizations.button_connecting,
          style: CustomButtonStyle.primary,
          theme: theme,
        );

      case ObsState.connected:
        return CustomButton(
          text: context.localizations.button_disconnect,
          style: CustomButtonStyle.secondary,
          theme: theme,
          onTap: () {},
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return StreamBuilder(
        stream: _connect.state.changes,
        initialData: _connect.state.current,
        builder: (context, snapshot) {
          final state = snapshot.requireData;
          return Container(
              width: double.infinity,
              decoration: BoxDecoration(
                  color: theme.surfaceSecondary,
                  border: Border.all(
                      color: theme.dividerColor,
                      width: 0.5,
                      strokeAlign: BorderSide.strokeAlignOutside),
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.all(16),
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        SimpleIcon.simpleSquare(Assets.assetsIcObsWhite16dp,
                            size: 16, color: theme.textColorPrimary),
                        const Gap(8),
                        Expanded(
                            child: Text(
                          context.localizations.obs_connect_title,
                          style: TextStyle(
                              fontSize: 14, color: theme.textColorPrimary),
                        ))
                      ],
                    ),
                    const Gap(16),
                    Row(
                      children: [
                        _createConnectionState(theme, state: state),
                        const Expanded(child: SizedBox.shrink()),
                        _createButton(context, theme, state: state)
                      ],
                    ),
                    const Gap(16),
                    Row(
                      children: [
                        Expanded(
                            child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.localizations.obs_websocket_url_title,
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: theme.textColorPrimary),
                            ),
                            const Gap(6),
                            TextFieldDecoration(
                                textStyle: TextStyle(
                                    fontSize: 12,
                                    color: theme.textColorPrimary),
                                clearable: false,
                                builder: (cntx, decoration, style) {
                                  return TextField(
                                    decoration: decoration,
                                    style: style,
                                    focusNode: _urlFocusNode,
                                    controller: _urlController,
                                  );
                                },
                                hint: context
                                    .localizations.obs_websocket_url_hint,
                                controller: _urlController,
                                focusNode: _urlFocusNode,
                                theme: theme)
                          ],
                        )),
                        const Gap(8),
                        Expanded(
                            child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context
                                  .localizations.obs_websocket_password_title,
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: theme.textColorPrimary),
                            ),
                            const Gap(6),
                            TextFieldDecoration(
                                textStyle: TextStyle(
                                    fontSize: 12,
                                    color: theme.textColorPrimary),
                                clearable: false,
                                builder: (cntx, decoration, style) {
                                  return TextField(
                                    decoration: decoration,
                                    style: style,
                                    focusNode: _passwordFocusNode,
                                    controller: _passwordController,
                                  );
                                },
                                hint: context
                                    .localizations.obs_websocket_password_hint,
                                controller: _passwordController,
                                focusNode: _passwordFocusNode,
                                theme: theme)
                          ],
                        )),
                      ],
                    )
                  ]));
        });
  }
}

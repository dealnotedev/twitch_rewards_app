import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:twitch_listener/generated/assets.dart';
import 'package:twitch_listener/obs/obs_connect.dart';
import 'package:twitch_listener/settings.dart';
import 'package:twitch_listener/themes.dart';

class ObsWidget extends StatefulWidget {
  final ObsConnect connect;
  final Settings settings;

  const ObsWidget({super.key, required this.settings, required this.connect});

  @override
  State<StatefulWidget> createState() => _State();
}

class _State extends State<ObsWidget> {
  late final Settings _settings;

  @override
  void initState() {
    _settings = widget.settings;

    _urlController = TextEditingController(text: _settings.obsPrefs?.url);
    _passwordController =
        TextEditingController(text: _settings.obsPrefs?.password);
    super.initState();
  }

  Widget _createIndicator({required ObsState state}) {
    final Color color;

    switch (state) {
      case ObsState.connected:
        color = Colors.green;
        break;

      case ObsState.failed:
      default:
        color = Colors.red;
        break;
    }

    return Container(
      width: 8,
      height: 8,
      decoration:
          BoxDecoration(borderRadius: BorderRadius.circular(4), color: color),
    );
  }

  @override
  void dispose() {
    _urlController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  late final TextEditingController _urlController;
  late final TextEditingController _passwordController;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: const Color(0xFF363A46),
          borderRadius: BorderRadius.circular(8)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Image.asset(
            Assets.assetsIcObs32dp,
            filterQuality: FilterQuality.medium,
            width: 32,
            height: 32,
          ),
          const Gap(16),
          Expanded(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  StreamBuilder(
                      stream: widget.connect.state.changes,
                      initialData: widget.connect.state.current,
                      builder: (_, snapshot) {
                        return _createIndicator(state: snapshot.requireData);
                      }),
                  const Gap(8),
                  const Text(
                    'OBS Connection',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
              const Gap(8),
              Row(
                children: [
                  Expanded(
                      child: _createTextInputWidget(context,
                          hint: 'Address', controller: _urlController)),
                  const Gap(16),
                  Expanded(
                      child: _createTextInputWidget(context,
                          hint: 'Password', controller: _passwordController))
                ],
              ),
              const Gap(8),
              Align(
                alignment: Alignment.centerRight,
                child: _createConnectButton(context),
              )
            ],
          ))
        ],
      ),
    );
  }

  Widget _createConnectButton(BuildContext context) {
    return StreamBuilder(
      stream: widget.connect.state.changes,
      initialData: widget.connect.state.current,
      builder: (cntx, snapshot) {
        final state = snapshot.requireData;
        final connecting = state == ObsState.connecting;
        final String text;

        switch (state) {
          case ObsState.failed:
            text = 'Connect';
            break;

          case ObsState.connecting:
            text = 'Connecting...';
            break;

          case ObsState.connected:
            text = 'Apply';
            break;
        }
        return ElevatedButton(
            onPressed: connecting ? null : _handleApplyClick,
            child: Text(text));
      },
    );
  }

  Widget _createTextInputWidget(BuildContext context,
      {required String hint, required TextEditingController controller}) {
    return TextField(
      maxLines: 1,
      controller: controller,
      style: const TextStyle(
        fontSize: 14,
      ),
      decoration: DefaultInputDecoration(hintText: hint),
    );
  }

  void _handleApplyClick() async {
    final url = _urlController.text.trim();
    final pass = _passwordController.text.trim();

    _settings.saveObsPrefs(url: url, password: pass);
  }
}

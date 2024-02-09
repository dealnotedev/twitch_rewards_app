import 'package:flutter/material.dart';
import 'package:obs_websocket/obs_websocket.dart';
import 'package:twitch_listener/generated/assets.dart';
import 'package:twitch_listener/obs/obs_connect.dart';
import 'package:twitch_listener/settings.dart';

class ObsWidget extends StatefulWidget {
  final ObsConnect connect;
  final Settings settings;

  const ObsWidget({super.key, required this.settings, required this.connect});

  @override
  State<StatefulWidget> createState() => _State();
}

class _State extends State<ObsWidget> {
  late final ObsConnect _connect;
  late final Settings _settings;

  @override
  void initState() {
    _connect = widget.connect;
    _settings = widget.settings;

    _urlController = TextEditingController(text: _settings.obsWsUrl);
    _passwordController = TextEditingController(text: _settings.obsWsPassword);
    super.initState();
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
          const SizedBox(
            width: 16,
          ),
          Expanded(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'OBS Connection',
                style: TextStyle(color: Colors.white),
              ),
              const SizedBox(
                height: 8,
              ),
              Row(
                children: [
                  Expanded(
                      child: _createTextInputWidget(context,
                          hint: 'Address', controller: _urlController)),
                  const SizedBox(
                    width: 16,
                  ),
                  Expanded(
                      child: _createTextInputWidget(context,
                          hint: 'Password', controller: _passwordController))
                ],
              ),
              const SizedBox(
                height: 8,
              ),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                    onPressed: _handleApplyClick,
                    child: Text(_connecting ? 'Connecting...' : 'Apply')),
              )
            ],
          ))
        ],
      ),
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
      decoration: InputDecoration(
          hintStyle: const TextStyle(fontSize: 14),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          fillColor: const Color(0xFF272E37),
          filled: true,
          isDense: true,
          hintText: hint),
    );
  }

  bool _connecting = false;

  void _handleApplyClick() async {
    if (_connecting) return;

    final url = _urlController.text.trim();
    final pass = _passwordController.text.trim();

    await _settings.saveObsPrefs(url: url, password: pass);
    await _connect.apply(null);

    if (url.isEmpty || pass.isEmpty) return;

    setState(() {
      _connecting = true;
    });

    try {
      final obs = await ObsWebSocket.connect(url, password: pass);
      await obs.stream.status;

      await _connect.apply(obs);
    } finally {
      setState(() {
        _connecting = false;
      });
    }
  }
}

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:listener_updater/platform/updater_host.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('updater/host');
  test('termination is requested before waiting for the exact installation to exit', () async {
    final calls = <MethodCall>[];
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      calls.add(call);
      return call.method == 'isListenerRunning' ? false : null;
    });
    addTearDown(
      () => binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    final host = WindowsUpdaterHost(title: 'Twitch Listener', dark: true);
    await host.initialize('D:/Listener');
    await host.stopListener();
    expect(calls.map((call) => call.method), [
      'initialize',
      'terminateListener',
      'isListenerRunning',
    ]);
    expect(calls.first.arguments, {
      'directory': 'D:/Listener',
      'title': 'Twitch Listener',
      'dark': true,
    });
  });
}

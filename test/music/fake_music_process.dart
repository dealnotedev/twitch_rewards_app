import 'dart:async';
import 'dart:convert';
import 'dart:io';

class TestAudioProcess implements Process {
  final _exit = Completer<int>();
  final _stdout = StreamController<List<int>>();
  final _stderr = StreamController<List<int>>();
  bool killed = false;

  TestAudioProcess();
  TestAudioProcess.completed(
      {String stdout = '', String stderr = '', int exitCode = 0}) {
    _stdout.add(utf8.encode(stdout));
    _stderr.add(utf8.encode(stderr));
    finish(exitCode);
  }
  void finish(int code) {
    if (_exit.isCompleted) return;
    _stdout.close();
    _stderr.close();
    _exit.complete(code);
  }

  @override
  Future<int> get exitCode => _exit.future;
  @override
  Stream<List<int>> get stdout => _stdout.stream;
  @override
  Stream<List<int>> get stderr => _stderr.stream;
  @override
  IOSink get stdin => throw UnsupportedError('stdin');
  @override
  int get pid => 1;
  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    killed = true;
    finish(-1);
    return true;
  }
}

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:twitch_listener/process_finder.dart';
import 'package:twitch_listener/reward.dart';
import 'package:twitch_listener/reward_widget.dart';
import 'package:twitch_listener/themes.dart';

class CrashProcessWidget extends StatefulWidget {
  final SaveHook saveHook;
  final RewardAction action;

  const CrashProcessWidget(
      {super.key, required this.saveHook, required this.action});

  @override
  State<StatefulWidget> createState() => _State();
}

class _State extends State<CrashProcessWidget> {
  @override
  void initState() {
    _processNameController = TextEditingController(text: widget.action.target);
    widget.saveHook.addHandler(_handleSave);
    super.initState();
  }

  @override
  void dispose() {
    _processNameController.dispose();
    widget.saveHook.removeHandler(_handleSave);
    super.dispose();
  }

  late final TextEditingController _processNameController;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Text(
          'Crash process',
          style: TextStyle(color: Colors.white),
        ),
        const Gap(16),
        Expanded(
          child: TextFormField(
            maxLines: 1,
            controller: _processNameController,
            style: const TextStyle(
              fontSize: 14,
            ),
            decoration: const DefaultInputDecoration(hintText: 'Process name'),
          ),
        ),
        const Gap(8),
        ElevatedButton(onPressed: _selectProcess, child: const Text('Select'))
      ])
    ]);
  }

  Future<void> _selectProcess() async {
    final processName = await showModalBottomSheet<String>(
        context: context,
        constraints: const BoxConstraints(maxWidth: 512),
        backgroundColor: const Color(0xFF404450),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
              topRight: Radius.circular(8), topLeft: Radius.circular(8)),
        ),
        builder: (context) {
          return _ProcessListWidget();
        });

    if (processName != null) {
      _processNameController.text = processName;
    }
  }

  @override
  void didUpdateWidget(covariant CrashProcessWidget oldWidget) {
    if (widget.saveHook != oldWidget.saveHook) {
      oldWidget.saveHook.removeHandler(_handleSave);
      widget.saveHook.addHandler(_handleSave);
    }
    super.didUpdateWidget(oldWidget);
  }

  void _handleSave() {
    widget.action.target = _processNameController.text.trim();
  }
}

class _ProcessListWidget extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => _ProcessListState();
}

class _ProcessListState extends State<_ProcessListWidget> {
  @override
  void initState() {
    _searchController.addListener(_handleSearchQuery);
    _runTickerLoop();
    super.initState();
  }

  bool _disposed = false;
  List<String> _processes = [];

  void _runTickerLoop() async {
    while (true) {
      if (_disposed) break;

      final processes = await compute(_getRunningProcesses, 8);
      if (_disposed) break;

      setState(() {
        _processes = processes.map((e) => e.name).toSet().toList();
        _processes.sort((a, b) => a.compareTo(b));
      });
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_handleSearchQuery);
    _searchController.dispose();
    _disposed = true;
    super.dispose();
  }

  static List<ProcessInfo> _getRunningProcesses(int priority) {
    ProcessFinder.initialize();

    final data = ProcessFinder.listRunningProcesses(priority: priority);
    ProcessFinder.uninitialize();

    return data;
  }

  final _searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final filtered = _processes
        .where((p) => _q.isEmpty || p.toLowerCase().contains(_q))
        .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16, left: 16, right: 16),
          child: TextField(
            maxLines: 1,
            controller: _searchController,
            style: const TextStyle(
              fontSize: 14,
            ),
            decoration:
                const DefaultInputDecoration(hintText: 'Type to search...'),
          ),
        ),
        Expanded(
            child: ListView.builder(
                padding: const EdgeInsets.only(top: 8),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final info = filtered[index];
                  return InkWell(
                    onTap: () => _selectProcess(context, info),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Text(
                        info,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  );
                }))
      ],
    );
  }

  String _q = '';

  void _handleSearchQuery() {
    setState(() {
      _q = _searchController.text.toLowerCase().trim();
    });
  }

  _selectProcess(BuildContext contex, String info) {
    Navigator.pop(context, info);
  }
}

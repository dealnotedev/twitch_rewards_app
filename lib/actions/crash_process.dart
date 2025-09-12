import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:twitch_listener/buttons.dart';
import 'package:twitch_listener/extensions.dart';
import 'package:twitch_listener/generated/assets.dart';
import 'package:twitch_listener/process_finder.dart';
import 'package:twitch_listener/reward.dart';
import 'package:twitch_listener/simple_icon.dart';
import 'package:twitch_listener/text_field_decoration.dart';
import 'package:twitch_listener/themes.dart';

class CrashProcessWidget extends StatefulWidget {
  final RewardAction action;

  const CrashProcessWidget({super.key, required this.action});

  @override
  State<StatefulWidget> createState() => _State();
}

class _State extends State<CrashProcessWidget> {
  late final RewardAction _action;

  late final TextEditingController _processNameController;

  final _processNameFocusNode = FocusNode();

  @override
  void initState() {
    _action = widget.action;
    _processNameController = TextEditingController(text: _action.target);
    _processNameController.addListener(_handleInputNameEdit);
    super.initState();
  }

  @override
  void dispose() {
    _processNameController.removeListener(_handleInputNameEdit);
    _processNameController.dispose();
    _processNameFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.localizations.reaction_crash_process_name_title,
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: theme.textColorPrimary),
        ),
        const Gap(6),
        Row(
          children: [
            Expanded(
                child: TextFieldDecoration(
                    clearable: false,
                    builder: (cntx, decoration, style) {
                      return TextField(
                        controller: _processNameController,
                        focusNode: _processNameFocusNode,
                        textInputAction: TextInputAction.done,
                        style: style,
                        decoration: decoration,
                      );
                    },
                    hint:
                        context.localizations.reaction_crash_process_name_hint,
                    controller: _processNameController,
                    focusNode: _processNameFocusNode,
                    theme: theme)),
            const Gap(8),
            CustomButton(
                prefixIcon: Assets.assetsIcSearchWhite16dp,
                onTap: () {
                  _selectProcess(context, theme);
                },
                text:
                    context.localizations.reaction_crash_process_button_select,
                style: CustomButtonStyle.secondary,
                theme: theme)
          ],
        )
      ],
    );
  }

  void _handleInputNameEdit() {
    _action.target = _processNameController.text.trim();
  }

  Future<void> _selectProcess(BuildContext context, ThemeData theme) async {
    final processName = await showModalBottomSheet<String>(
        context: context,
        constraints: const BoxConstraints(maxWidth: 512),
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
    _searchFocusNode.dispose();
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
  final _searchFocusNode = FocusNode();

  @override
  Widget build(BuildContext context) {
    final filtered = _processes
        .where((p) => _q.isEmpty || p.toLowerCase().contains(_q))
        .toList();

    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
          color: theme.surfacePrimary,
          borderRadius: const BorderRadius.only(
              topRight: Radius.circular(8), topLeft: Radius.circular(8))),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(
              top: 16,
              left: 16,
              right: 16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.localizations.reaction_crash_process_search_title,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: theme.textColorPrimary),
                ),
                const Gap(2),
                Text(
                  context.localizations.reaction_crash_process_search_summary,
                  style:
                      TextStyle(fontSize: 12, color: theme.textColorSecondary),
                ),
                const Gap(12),
                TextFieldDecoration(
                    clearable: true,
                    prefix: SimpleIcon.simpleSquare(
                        Assets.assetsIcSearchWhite16dp,
                        size: 16,
                        color: theme.textColorSecondary),
                    builder: (cntx, decoration, style) {
                      return TextField(
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        textInputAction: TextInputAction.search,
                        style: style,
                        decoration: decoration,
                      );
                    },
                    hint: context
                        .localizations.reaction_crash_process_search_hint,
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    theme: theme)
              ],
            ),
          ),
          Expanded(
              child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final info = filtered[index];
                    return Material(
                      type: MaterialType.transparency,
                      child: InkWell(
                        onTap: () {
                          Navigator.pop(context, info);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          child: Text(
                            info,
                            style: TextStyle(
                                color: theme.textColorPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w500),
                          ),
                        ),
                      ),
                    );
                  }))
        ],
      ),
    );
  }

  String _q = '';

  void _handleSearchQuery() {
    setState(() {
      _q = _searchController.text.toLowerCase().trim();
    });
  }
}

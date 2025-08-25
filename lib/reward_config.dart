import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:twitch_listener/dropdown/dropdown_menu.dart';
import 'package:twitch_listener/dropdown/dropdown_scope.dart';
import 'package:twitch_listener/extensions.dart';
import 'package:twitch_listener/generated/assets.dart';
import 'package:twitch_listener/simple_icon.dart';
import 'package:twitch_listener/themes.dart';

class RewardConfigWidget extends StatefulWidget {
  final DropdownManager dropdownManager;

  const RewardConfigWidget({super.key, required this.dropdownManager});

  @override
  State<StatefulWidget> createState() => _State();
}

class _State extends State<RewardConfigWidget> {
  late final DropdownManager _dropdownManager;

  @override
  void initState() {
    _dropdownManager = widget.dropdownManager;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => _dropdownManager.clear(),
      behavior: HitTestBehavior.opaque,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 812),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [_createDropDown(context, theme, key: _g), const Gap(256)],
        ),
      ),
    );
  }

  final _g = GlobalKey();

  Widget _createDropDown(BuildContext context, ThemeData theme,
      {required GlobalKey key}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Wait for Completion',
          style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: theme.textColorPrimary),
        ),
        const Gap(4),
        Material(
          borderRadius: BorderRadius.circular(8),
          color: theme.inputBackground,
          child: InkWell(
            onTap: () {
              _showDropdownPopup(context, key: key);
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              key: key,
              decoration: BoxDecoration(
                border: Border.all(color: theme.border, width: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                      child: Text(
                    'Yes',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: theme.textColorPrimary),
                  )),
                  SimpleIcon.simpleSquare(Assets.assetsIcArrowDownWhite12dp,
                      size: 12, color: theme.textColorDisabled)
                ],
              ),
            ),
          ),
        )
      ],
    );
  }

  void _showDropdownPopup(BuildContext context, {required GlobalKey key}) {
    _dropdownManager.show(context, builder: (cntx) {
      return DropdownPopupMenu<bool>(
        selected: true,
        items: [
          Item(id: true, title: context.localizations.yes),
          Item(id: false, title: context.localizations.no)
        ],
        onTap: (bool id) {
          _dropdownManager.dismiss(key);
        },
      );
    }, key: key);
  }
}

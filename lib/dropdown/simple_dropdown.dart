import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:twitch_listener/dropdown/dropdown_menu.dart';
import 'package:twitch_listener/dropdown/dropdown_scope.dart';
import 'package:twitch_listener/generated/assets.dart';
import 'package:twitch_listener/simple_icon.dart';
import 'package:twitch_listener/themes.dart';

class SimpleDropdown<T> extends StatelessWidget {
  final String title;
  final ThemeData theme;
  final List<Item<T>> available;
  final T? selected;
  final GlobalKey globalKey;

  final void Function(T id) onSelected;

  final EdgeInsets? padding;

  const SimpleDropdown(
      {super.key,
      required this.theme,
      required this.title,
      required this.available,
      this.padding,
      required this.globalKey,
      required this.selected,
      required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: theme.textColorPrimary),
        ),
        const Gap(6),
        Material(
          borderRadius: BorderRadius.circular(8),
          color: theme.inputBackground,
          child: InkWell(
            onTap: () {
              _showDropdownPopup(context);
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              key: globalKey,
              decoration: BoxDecoration(
                border: Border.all(color: theme.border, width: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              padding: padding ??
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                      child: Text(
                    available
                            .firstWhereOrNull((a) => a.id == selected)
                            ?.title ??
                        '',
                    style: TextStyle(
                        fontSize: 13,
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

  void _showDropdownPopup(BuildContext context) {
    final manager = DropdownScope.of(context);

    manager.show(context, builder: (cntx) {
      return DropdownPopupMenu<T>(
        selected: selected,
        items: available,
        onTap: (T id) {
          manager.dismiss(globalKey);
          onSelected.call(id);
        },
      );
    }, key: globalKey);
  }
}

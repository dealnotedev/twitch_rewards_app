import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:twitch_listener/generated/assets.dart';
import 'package:twitch_listener/simple_icon.dart';
import 'package:twitch_listener/themes.dart';

class Item<T> {
  final T id;
  final String title;
  final String? icon;

  Item({required this.id, required this.title, this.icon});
}

class DropdownPopupMenu<T> extends StatelessWidget {
  final List<Item<T>> items;
  final T? selected;

  final void Function(T id) onTap;

  const DropdownPopupMenu(
      {super.key, required this.items, this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.surfaceSecondary,
      borderRadius: BorderRadius.circular(8),
      elevation: 1,
      shadowColor: theme.dividerColor.withValues(alpha: 0.5),
      child: DecoratedBox(
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.dividerColor, width: 0.5)),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children:
                    items.map((i) => _createItemWidget(theme, i)).toList(),
              ),
            ),
          )),
    );
  }

  Widget _createItemWidget(ThemeData theme, Item<T> e) {
    final checked = e.id == selected;
    final icon = e.icon;
    return InkWell(
      onTap: () {
        onTap.call(e.id);
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            if (icon != null) ...[
              SimpleIcon.simpleSquare(icon,
                  size: 16, color: theme.textColorPrimary),
              const Gap(8)
            ],
            Expanded(
                child: Text(
              e.title,
              style: TextStyle(fontSize: 12, color: theme.textColorPrimary),
            )),
            if (checked) ...[
              const Gap(8),
              SimpleIcon.simpleSquare(Assets.assetsIcCheckWhite16dp,
                  size: 16, color: theme.textColorSecondary),
            ]
          ],
        ),
      ),
    );
  }
}

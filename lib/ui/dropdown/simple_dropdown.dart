import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:twitch_listener/ui/dropdown/dropdown_menu.dart';
import 'package:twitch_listener/ui/dropdown/dropdown_scope.dart';
import 'package:twitch_listener/generated/assets.dart';
import 'package:twitch_listener/ui/simple_icon.dart';
import 'package:twitch_listener/ui/themes.dart';

class SimpleDropdown<T> extends StatelessWidget {
  final String title;
  final ThemeData theme;
  final List<Item<T>> available;
  final T? selected;
  final GlobalKey globalKey;

  final void Function(T id) onSelected;

  final EdgeInsets? padding;
  final DropdownMenuWidth menuWidth;
  final AlignmentGeometry menuAlignment;
  final bool _compact;

  const SimpleDropdown({
    super.key,
    required this.theme,
    required this.title,
    required this.available,
    this.padding,
    this.menuWidth = DropdownMenuWidth.anchor,
    this.menuAlignment = AlignmentDirectional.topStart,
    required this.globalKey,
    required this.selected,
    required this.onSelected,
  }) : _compact = false;

  /// A label-free picker for a heading or toolbar. The button fits the current
  /// selection; the popup fits all options and aligns to the button's end edge.
  const SimpleDropdown.compact({
    super.key,
    required this.theme,
    required this.available,
    this.padding,
    this.menuWidth = DropdownMenuWidth.content,
    this.menuAlignment = AlignmentDirectional.topEnd,
    required this.globalKey,
    required this.selected,
    required this.onSelected,
  }) : title = '',
       _compact = true;

  @override
  Widget build(BuildContext context) {
    // Match TextFieldDecoration's frame and density-adjusted input padding.
    // Flutter removes 8 px from InputDecorator on compact desktop themes.
    final verticalPadding =
        6.0 +
        math.max(0.0, 4.0 + theme.visualDensity.baseSizeAdjustment.dy / 2);
    final item = available.firstWhereOrNull((a) => a.id == selected);
    final color = _compact ? theme.accentColor : theme.textColorPrimary;
    final label = Text(
      item?.title ?? '',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: _compact ? 12 : 13,
        fontWeight: _compact ? FontWeight.w500 : FontWeight.w400,
        color: color,
      ),
    );
    final control = Material(
      borderRadius: BorderRadius.circular(8),
      color: _compact ? theme.accentSubtle : theme.inputBackground,
      child: InkWell(
        onTap: () {
          _showDropdownPopup(context);
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          key: globalKey,
          decoration: BoxDecoration(
            border: Border.all(
              color: _compact ? Colors.transparent : theme.border,
              width: 0.5,
              strokeAlign: BorderSide.strokeAlignOutside,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          padding:
              padding ??
              EdgeInsets.symmetric(
                horizontal: _compact ? 8 : 12,
                vertical: _compact ? 5 : verticalPadding,
              ),
          child: Row(
            mainAxisSize: _compact ? MainAxisSize.min : MainAxisSize.max,
            children: [
              if (_compact && item?.icon != null) ...[
                SimpleIcon.simpleSquare(item!.icon!, size: 16, color: color),
                const Gap(6),
              ],
              if (_compact) Flexible(child: label) else Expanded(child: label),
              if (_compact) const Gap(8),
              SimpleIcon.simpleSquare(
                Assets.assetsIcArrowDownWhite12dp,
                size: 12,
                color: _compact ? color : theme.textColorDisabled,
              ),
            ],
          ),
        ),
      ),
    );
    if (_compact) return control;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: theme.textColorPrimary,
          ),
        ),
        const Gap(6),
        control,
      ],
    );
  }

  void _showDropdownPopup(BuildContext context) {
    final manager = DropdownScope.of(context);

    manager.show(
      context,
      builder: (cntx) {
        return DropdownPopupMenu<T>(
          selected: selected,
          items: available,
          onTap: (T id) {
            manager.dismiss(globalKey);
            onSelected.call(id);
          },
        );
      },
      key: globalKey,
      menuWidth: menuWidth,
      alignment: menuAlignment,
    );
  }
}

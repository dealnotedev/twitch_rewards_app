import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:twitch_listener/generated/assets.dart';
import 'package:twitch_listener/simple_icon.dart';
import 'package:twitch_listener/themes.dart';

class ViewersCounter extends StatelessWidget {
  final ThemeData theme;
  final int count;

  const ViewersCounter({super.key, required this.theme, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 6, right: 8, top: 3, bottom: 3),
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
              color: theme.dividerColor,
              strokeAlign: BorderSide.strokeAlignOutside,
              width: 0.5)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SimpleIcon.simpleSquare(Assets.assetsIcEyeWhite16dp,
              color: theme.textColorPrimary, size: 16),
          const Gap(4),
          Text(
            count.toString(),
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1,
                color: theme.textColorPrimary),
          )
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:twitch_listener/ui/back_button.dart';
import 'package:twitch_listener/ui/simple_widgets.dart';
import 'package:twitch_listener/ui/themes.dart';

/// Shared page header and content area within the application's navigator.
class AppPage extends StatelessWidget {
  final String title;
  final Widget child;
  final VoidCallback? onBack;
  final List<Widget> actions;
  final bool scrollable;

  const AppPage({
    super.key,
    required this.title,
    required this.child,
    required this.onBack,
    this.actions = const [],
    this.scrollable = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.surfacePrimary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final navigation = Row(
                  children: [
                    AppBackButton(theme: theme, onTap: onBack),
                    const Gap(8),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: theme.textColorPrimary,
                        ),
                      ),
                    ),
                  ],
                );
                if (actions.isEmpty) return navigation;
                final buttons = Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.end,
                  children: actions,
                );
                final scale = MediaQuery.textScalerOf(context).scale(1);
                if (constraints.maxWidth >= 520 * scale) {
                  return Row(
                    children: [
                      Expanded(child: navigation),
                      const Gap(8),
                      buttons,
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    navigation,
                    const Gap(8),
                    Align(alignment: Alignment.centerRight, child: buttons),
                  ],
                );
              },
            ),
          ),
          SimpleDivider(theme: theme),
          Expanded(
            child: scrollable
                ? SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: child,
                  )
                : Padding(padding: const EdgeInsets.all(16), child: child),
          ),
        ],
      ),
    );
  }
}

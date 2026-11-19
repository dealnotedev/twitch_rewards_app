import 'package:flutter/material.dart';
import 'package:twitch_listener/ui/themes.dart';

class KeyCombinationField extends StatelessWidget {
  final Iterable<String> keys;
  final String placeholder;

  const KeyCombinationField({
    super.key,
    required this.keys,
    required this.placeholder,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasKeys = keys.isNotEmpty;
    final keyDecoration = BoxDecoration(
      color: theme.dark ? theme.buttonColorAlternative : theme.surfaceSecondary,
      border: Border.all(color: theme.border, width: 0.5),
      borderRadius: BorderRadius.circular(4),
    );
    return Semantics(
      label: hasKeys ? keys.join(' + ') : placeholder,
      excludeSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: 34),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: theme.surfaceTertiary,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          heightFactor: 1,
          child: DefaultTextStyle.merge(
            style: TextStyle(fontSize: 12, color: theme.textColorSecondary),
            child: hasKeys
                ? Wrap(
                    spacing: 5,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      for (final (index, key) in keys.indexed) ...[
                        if (index > 0) const Text('+'),
                        DecoratedBox(
                          decoration: keyDecoration,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            child: Text(
                              key,
                              style: TextStyle(color: theme.textColorPrimary),
                            ),
                          ),
                        ),
                      ],
                    ],
                  )
                : Text(placeholder),
          ),
        ),
      ),
    );
  }
}

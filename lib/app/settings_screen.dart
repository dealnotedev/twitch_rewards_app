import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:twitch_listener/core/extensions.dart';
import 'package:twitch_listener/core/settings.dart';
import 'package:twitch_listener/generated/assets.dart';
import 'package:twitch_listener/music/music_hotkey_controller.dart';
import 'package:twitch_listener/music/player_shortcut_settings.dart';
import 'package:twitch_listener/ui/app_page.dart';
import 'package:twitch_listener/ui/buttons.dart';
import 'package:twitch_listener/ui/dropdown/dropdown_menu.dart';
import 'package:twitch_listener/ui/dropdown/dropdown_scope.dart';
import 'package:twitch_listener/ui/dropdown/simple_dropdown.dart';
import 'package:twitch_listener/ui/themes.dart';

enum _Section { player, appearance }

class SettingsScreen extends StatefulWidget {
  final Settings settings;
  final MusicHotkeyController hotkey;

  const SettingsScreen({
    super.key,
    required this.settings,
    required this.hotkey,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  var _section = _Section.player;
  final _themePicker = GlobalKey();
  final _languagePicker = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final strings = context.localizations;
    final theme = Theme.of(context);
    return AppPage(
      title: strings.app_settings_title,
      onBack: () => Navigator.of(context).pop(),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _sectionButton(
                    context,
                    _Section.player,
                    strings.app_settings_player,
                    Assets.assetsIcPlayWhite16dp,
                  ),
                  _sectionButton(
                    context,
                    _Section.appearance,
                    strings.app_settings_appearance,
                    Assets.assetsIcSunMoonWhite16dp,
                  ),
                ],
              ),
              const Gap(16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.surfaceSecondary,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.border),
                ),
                child: switch (_section) {
                  _Section.player => PlayerShortcutSettings(
                    hotkey: widget.hotkey,
                  ),
                  _Section.appearance => _appearanceSettings(context),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionButton(
    BuildContext context,
    _Section section,
    String title,
    String icon,
  ) {
    final selected = _section == section;
    return Semantics(
      selected: selected,
      child: CustomButton(
        prefixIcon: icon,
        text: title,
        theme: Theme.of(context),
        style: selected
            ? CustomButtonStyle.primary
            : CustomButtonStyle.secondary,
        onTap: () {
          if (selected) return;
          DropdownScope.of(context).clear();
          setState(() => _section = section);
        },
      ),
    );
  }

  Widget _appearanceSettings(BuildContext context) {
    final strings = context.localizations;
    final theme = Theme.of(context);
    final settings = widget.settings;
    return StreamBuilder<Appearance>(
      stream: settings.appearanceChanges,
      initialData: settings.appearance,
      builder: (context, snapshot) {
        final appearance = snapshot.requireData;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SimpleDropdown<AppBrightness>(
              title: strings.app_settings_theme,
              theme: theme,
              globalKey: _themePicker,
              selected: appearance.brightness,
              available: [
                Item(
                  id: AppBrightness.system,
                  title: strings.app_settings_theme_system,
                ),
                Item(
                  id: AppBrightness.light,
                  title: strings.app_settings_theme_light,
                ),
                Item(
                  id: AppBrightness.dark,
                  title: strings.app_settings_theme_dark,
                ),
              ],
              onSelected: (value) => unawaited(settings.setBrightness(value)),
            ),
            const Gap(16),
            SimpleDropdown<AppLanguage>(
              title: strings.app_settings_language,
              theme: theme,
              globalKey: _languagePicker,
              selected: appearance.language,
              available: [
                for (final language in AppLanguage.values)
                  Item(id: language, title: language.nativeName),
              ],
              onSelected: (value) => unawaited(settings.setLanguage(value)),
            ),
          ],
        );
      },
    );
  }
}

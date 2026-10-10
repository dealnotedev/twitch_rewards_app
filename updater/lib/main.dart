import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:observable_state/observable_state.dart';
import 'package:listener_ui/themes.dart';

import 'launch_options.dart';
import 'l10n/generated/updater_localizations.dart';
import 'platform/updater_host.dart';
import 'update_view_model.dart';
import 'updater_view.dart';

void main(List<String> arguments) {
  WidgetsFlutterBinding.ensureInitialized();
  final options = LaunchOptions.parse(
    arguments,
    executable: Platform.resolvedExecutable,
    systemLocale: PlatformDispatcher.instance.locale,
  );
  final strings = lookupUpdaterLocalizations(options.locale);
  runApp(
    UpdaterApp(
      locale: options.locale,
      themeMode: options.themeMode,
      createViewModel: () => UpdateViewModel(
        directory: options.directory,
        host: WindowsUpdaterHost(
          title: strings.windowTitle,
          dark:
              options.themeMode == ThemeMode.dark ||
              (options.themeMode == ThemeMode.system &&
                  PlatformDispatcher.instance.platformBrightness ==
                      Brightness.dark),
        ),
      ),
    ),
  );
}

class UpdaterApp extends StatefulWidget {
  const UpdaterApp({
    required this.createViewModel,
    this.locale = const Locale('en'),
    this.themeMode = ThemeMode.system,
    super.key,
  }) : viewModel = null;

  /// Uses an externally owned model; the caller remains responsible for disposal.
  const UpdaterApp.withViewModel({
    required UpdateViewModel this.viewModel,
    this.locale = const Locale('en'),
    this.themeMode = ThemeMode.system,
    super.key,
  }) : createViewModel = null;

  final UpdateViewModel Function()? createViewModel;
  final UpdateViewModel? viewModel;
  final Locale locale;
  final ThemeMode themeMode;
  @override
  State<UpdaterApp> createState() => _UpdaterAppState();
}

class _UpdaterAppState extends State<UpdaterApp> {
  late UpdateViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = widget.viewModel ?? widget.createViewModel!();
  }

  @override
  void didUpdateWidget(UpdaterApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.viewModel, widget.viewModel) ||
        identical(widget.viewModel, _viewModel)) {
      return;
    }
    if (oldWidget.viewModel == null) _viewModel.dispose();
    _viewModel = widget.viewModel ?? widget.createViewModel!();
  }

  @override
  void dispose() {
    if (widget.viewModel == null) _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    onGenerateTitle: (context) => UpdaterLocalizations.of(context).windowTitle,
    locale: widget.locale,
    supportedLocales: UpdaterLocalizations.supportedLocales,
    localizationsDelegates: UpdaterLocalizations.localizationsDelegates,
    theme: Themes.light,
    darkTheme: Themes.dark,
    themeMode: widget.themeMode,
    home: ObservableBuilder<UpdateState>(
      source: _viewModel.state,
      builder: (context, state, _) => UpdaterView(
        download: _viewModel.download,
        state: UpdatePresentation.fromState(
          state,
          UpdaterLocalizations.of(context),
        ),
        onAction: () => unawaited(_viewModel.activate()),
        onCancel: _viewModel.cancel,
      ),
    ),
  );
}

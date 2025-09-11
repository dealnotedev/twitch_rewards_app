import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @app_title.
  ///
  /// In en, this message translates to:
  /// **'Twitch Listener'**
  String get app_title;

  /// No description provided for @status_connected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get status_connected;

  /// No description provided for @status_disconnected.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get status_disconnected;

  /// No description provided for @status_connecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting...'**
  String get status_connecting;

  /// No description provided for @button_connect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get button_connect;

  /// No description provided for @button_disconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get button_disconnect;

  /// No description provided for @button_connecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting...'**
  String get button_connecting;

  /// No description provided for @twitch_connection_title.
  ///
  /// In en, this message translates to:
  /// **'Twitch Connection'**
  String get twitch_connection_title;

  /// No description provided for @twitch_connection_loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get twitch_connection_loading;

  /// No description provided for @twitch_connection_not_connected.
  ///
  /// In en, this message translates to:
  /// **'Not connected'**
  String get twitch_connection_not_connected;

  /// No description provided for @please_wait.
  ///
  /// In en, this message translates to:
  /// **'Please wait'**
  String get please_wait;

  /// No description provided for @twitch_connection_connected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get twitch_connection_connected;

  /// No description provided for @twitch_login_authorized.
  ///
  /// In en, this message translates to:
  /// **'Authorized'**
  String get twitch_login_authorized;

  /// No description provided for @twitch_login_click_to_connect.
  ///
  /// In en, this message translates to:
  /// **'Click to connect'**
  String get twitch_login_click_to_connect;

  /// No description provided for @button_logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get button_logout;

  /// No description provided for @button_login.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get button_login;

  /// No description provided for @reward_search_hint.
  ///
  /// In en, this message translates to:
  /// **'Search channel points by title...'**
  String get reward_search_hint;

  /// No description provided for @obs_connect_title.
  ///
  /// In en, this message translates to:
  /// **'OBS WebSocket'**
  String get obs_connect_title;

  /// No description provided for @obs_websocket_url_title.
  ///
  /// In en, this message translates to:
  /// **'WebSocket URL'**
  String get obs_websocket_url_title;

  /// No description provided for @obs_websocket_url_hint.
  ///
  /// In en, this message translates to:
  /// **'ws://localhost:4455'**
  String get obs_websocket_url_hint;

  /// No description provided for @obs_websocket_password_title.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get obs_websocket_password_title;

  /// No description provided for @obs_websocket_password_hint.
  ///
  /// In en, this message translates to:
  /// **'Enter password'**
  String get obs_websocket_password_hint;

  /// No description provided for @button_apply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get button_apply;

  /// No description provided for @channel_points_config_title.
  ///
  /// In en, this message translates to:
  /// **'Channel Points Configuration'**
  String get channel_points_config_title;

  /// No description provided for @x_total.
  ///
  /// In en, this message translates to:
  /// **'{count} total'**
  String x_total(int count);

  /// No description provided for @x_active.
  ///
  /// In en, this message translates to:
  /// **'{count} active'**
  String x_active(int count);

  /// No description provided for @x_actions.
  ///
  /// In en, this message translates to:
  /// **'{actions,plural, =1{{actions} action} other{{actions} actions}}'**
  String x_actions(int actions);

  /// No description provided for @x_points.
  ///
  /// In en, this message translates to:
  /// **'{points,plural, =1{{points} point} other{{points} points}}'**
  String x_points(int points);

  /// No description provided for @button_add_reward.
  ///
  /// In en, this message translates to:
  /// **'Add New Reward'**
  String get button_add_reward;

  /// No description provided for @channel_points_active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get channel_points_active;

  /// No description provided for @channel_points_inactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get channel_points_inactive;

  /// No description provided for @channel_points_reactions_info.
  ///
  /// In en, this message translates to:
  /// **'{reactions,plural, =1{{reactions} reaction} other{{reactions} reactions}} • {enabled} enabled'**
  String channel_points_reactions_info(int reactions, int enabled);

  /// No description provided for @button_configure.
  ///
  /// In en, this message translates to:
  /// **'Configure'**
  String get button_configure;

  /// No description provided for @reward_configure_title.
  ///
  /// In en, this message translates to:
  /// **'Reward Configurator'**
  String get reward_configure_title;

  /// No description provided for @reward_configure_title_with_name.
  ///
  /// In en, this message translates to:
  /// **'Configure: {reward}'**
  String reward_configure_title_with_name(String reward);

  /// No description provided for @reward_name_title.
  ///
  /// In en, this message translates to:
  /// **'Reward Name'**
  String get reward_name_title;

  /// No description provided for @button_add_reaction.
  ///
  /// In en, this message translates to:
  /// **'Add New Reaction'**
  String get button_add_reaction;

  /// No description provided for @reward_status_switch_title.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get reward_status_switch_title;

  /// No description provided for @reward_status_active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get reward_status_active;

  /// No description provided for @reward_status_inactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get reward_status_inactive;

  /// No description provided for @reward_name_hint.
  ///
  /// In en, this message translates to:
  /// **'Enter Twitch reward name'**
  String get reward_name_hint;

  /// No description provided for @reaction_chain_title.
  ///
  /// In en, this message translates to:
  /// **'Reaction Chain'**
  String get reaction_chain_title;

  /// No description provided for @reaction_chain_empty_text.
  ///
  /// In en, this message translates to:
  /// **'No reactions configured. Add a reaction to get started.'**
  String get reaction_chain_empty_text;

  /// No description provided for @reaction_enable_input.
  ///
  /// In en, this message translates to:
  /// **'Enable input'**
  String get reaction_enable_input;

  /// No description provided for @reaction_delay.
  ///
  /// In en, this message translates to:
  /// **'Delay'**
  String get reaction_delay;

  /// No description provided for @reaction_play_audio.
  ///
  /// In en, this message translates to:
  /// **'Play audio (legacy)'**
  String get reaction_play_audio;

  /// No description provided for @reaction_play_audios.
  ///
  /// In en, this message translates to:
  /// **'Play audio files'**
  String get reaction_play_audios;

  /// No description provided for @reaction_enable_filter.
  ///
  /// In en, this message translates to:
  /// **'Enable filter'**
  String get reaction_enable_filter;

  /// No description provided for @reaction_invert_filter.
  ///
  /// In en, this message translates to:
  /// **'Invert filter'**
  String get reaction_invert_filter;

  /// No description provided for @reaction_flip_source.
  ///
  /// In en, this message translates to:
  /// **'Flip source'**
  String get reaction_flip_source;

  /// No description provided for @reaction_enable_source.
  ///
  /// In en, this message translates to:
  /// **'Enable source'**
  String get reaction_enable_source;

  /// No description provided for @reaction_toggle_source.
  ///
  /// In en, this message translates to:
  /// **'Toggle source'**
  String get reaction_toggle_source;

  /// No description provided for @reaction_set_scene.
  ///
  /// In en, this message translates to:
  /// **'Set scene'**
  String get reaction_set_scene;

  /// No description provided for @reaction_crash_process.
  ///
  /// In en, this message translates to:
  /// **'Crash process'**
  String get reaction_crash_process;

  /// No description provided for @reaction_send_input.
  ///
  /// In en, this message translates to:
  /// **'Send input'**
  String get reaction_send_input;

  /// No description provided for @reward_no_name.
  ///
  /// In en, this message translates to:
  /// **'Unnamed'**
  String get reward_no_name;

  /// No description provided for @rewards_search_empty_text.
  ///
  /// In en, this message translates to:
  /// **'No channel points found matching \"{query}\".'**
  String rewards_search_empty_text(String query);

  /// No description provided for @button_clear_search.
  ///
  /// In en, this message translates to:
  /// **'Clear Search'**
  String get button_clear_search;

  /// No description provided for @reaction_play_audios_audio_files_title.
  ///
  /// In en, this message translates to:
  /// **'Audio Files'**
  String get reaction_play_audios_audio_files_title;

  /// No description provided for @reaction_play_audios_no_files.
  ///
  /// In en, this message translates to:
  /// **'No audio files configured. Click \"Add File\" to start.'**
  String get reaction_play_audios_no_files;

  /// No description provided for @reaction_play_audios_button_add_file.
  ///
  /// In en, this message translates to:
  /// **'Add File'**
  String get reaction_play_audios_button_add_file;

  /// No description provided for @reaction_play_audios_volume.
  ///
  /// In en, this message translates to:
  /// **'Volume'**
  String get reaction_play_audios_volume;

  /// No description provided for @reaction_play_audios_select_files_dialog.
  ///
  /// In en, this message translates to:
  /// **'Select audio files'**
  String get reaction_play_audios_select_files_dialog;

  /// No description provided for @reaction_play_audios_playback_settings.
  ///
  /// In en, this message translates to:
  /// **'Playback Settings'**
  String get reaction_play_audios_playback_settings;

  /// No description provided for @reaction_play_audios_wait_for_completion.
  ///
  /// In en, this message translates to:
  /// **'Wait for Completion'**
  String get reaction_play_audios_wait_for_completion;

  /// No description provided for @reaction_play_audios_shuffle.
  ///
  /// In en, this message translates to:
  /// **'Shuffle'**
  String get reaction_play_audios_shuffle;

  /// No description provided for @reaction_play_audios_count_title.
  ///
  /// In en, this message translates to:
  /// **'Number of Tracks'**
  String get reaction_play_audios_count_title;

  /// No description provided for @reaction_play_audios_count_all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get reaction_play_audios_count_all;

  /// No description provided for @reaction_play_audios_count_specific.
  ///
  /// In en, this message translates to:
  /// **'Specific'**
  String get reaction_play_audios_count_specific;

  /// No description provided for @button_save_changes.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get button_save_changes;

  /// No description provided for @button_back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get button_back;

  /// No description provided for @reward_configigure_basic_settings.
  ///
  /// In en, this message translates to:
  /// **'Basic Settings'**
  String get reward_configigure_basic_settings;

  /// No description provided for @reaction_play_audio_path_hint.
  ///
  /// In en, this message translates to:
  /// **'File path'**
  String get reaction_play_audio_path_hint;

  /// No description provided for @button_select_file.
  ///
  /// In en, this message translates to:
  /// **'Select File'**
  String get button_select_file;

  /// No description provided for @reaction_play_audio_select_file_dialog.
  ///
  /// In en, this message translates to:
  /// **'Select audio file'**
  String get reaction_play_audio_select_file_dialog;

  /// No description provided for @scene_name_title.
  ///
  /// In en, this message translates to:
  /// **'Scene name'**
  String get scene_name_title;

  /// No description provided for @scene_name_hint.
  ///
  /// In en, this message translates to:
  /// **'Scene Default'**
  String get scene_name_hint;

  /// No description provided for @source_name_title.
  ///
  /// In en, this message translates to:
  /// **'Source name'**
  String get source_name_title;

  /// No description provided for @source_name_hint.
  ///
  /// In en, this message translates to:
  /// **'Source 1'**
  String get source_name_hint;

  /// No description provided for @input_name_title.
  ///
  /// In en, this message translates to:
  /// **'Input name'**
  String get input_name_title;

  /// No description provided for @input_name_hint.
  ///
  /// In en, this message translates to:
  /// **'Mic/Aux'**
  String get input_name_hint;

  /// No description provided for @action_title.
  ///
  /// In en, this message translates to:
  /// **'Action'**
  String get action_title;

  /// No description provided for @action_enable.
  ///
  /// In en, this message translates to:
  /// **'Enable'**
  String get action_enable;

  /// No description provided for @action_disable.
  ///
  /// In en, this message translates to:
  /// **'Disable'**
  String get action_disable;

  /// No description provided for @reaction_delay_title.
  ///
  /// In en, this message translates to:
  /// **'Delay (seconds)'**
  String get reaction_delay_title;

  /// No description provided for @reaction_delay_seconds_hint.
  ///
  /// In en, this message translates to:
  /// **'Enter duration in seconds'**
  String get reaction_delay_seconds_hint;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}

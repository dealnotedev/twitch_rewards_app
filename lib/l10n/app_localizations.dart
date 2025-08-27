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

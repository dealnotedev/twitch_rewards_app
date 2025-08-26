// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get yes => 'Yes';

  @override
  String get no => 'No';

  @override
  String get app_title => 'Twitch Listener';

  @override
  String get status_connected => 'Connected';

  @override
  String get status_disconnected => 'Disconnected';

  @override
  String get status_connecting => 'Connecting...';

  @override
  String get button_connect => 'Connect';

  @override
  String get button_disconnect => 'Disconnect';

  @override
  String get button_connecting => 'Connecting...';

  @override
  String get twitch_connection_title => 'Twitch Connection';

  @override
  String get twitch_connection_loading => 'Loading...';

  @override
  String get twitch_connection_not_connected => 'Not connected';

  @override
  String get please_wait => 'Please wait';

  @override
  String get twitch_connection_connected => 'Connected';

  @override
  String get twitch_login_authorized => 'Authorized';

  @override
  String get twitch_login_click_to_connect => 'Click to connect';

  @override
  String get button_logout => 'Logout';

  @override
  String get button_login => 'Login';

  @override
  String get reward_search_hint => 'Search channel points by title...';

  @override
  String get obs_connect_title => 'OBS WebSocket';

  @override
  String get obs_websocket_url_title => 'WebSocket URL';

  @override
  String get obs_websocket_url_hint => 'ws://localhost:4455';

  @override
  String get obs_websocket_password_title => 'Password';

  @override
  String get obs_websocket_password_hint => 'Enter password';

  @override
  String get button_apply => 'Apply';

  @override
  String get channel_points_config_title => 'Channel Points Configuration';

  @override
  String x_total(int count) {
    return '$count total';
  }

  @override
  String x_active(int count) {
    return '$count active';
  }

  @override
  String x_actions(int actions) {
    String _temp0 = intl.Intl.pluralLogic(
      actions,
      locale: localeName,
      other: '$actions actions',
      one: '$actions action',
    );
    return '$_temp0';
  }

  @override
  String x_points(int points) {
    String _temp0 = intl.Intl.pluralLogic(
      points,
      locale: localeName,
      other: '$points points',
      one: '$points point',
    );
    return '$_temp0';
  }

  @override
  String get button_add_reward => 'Add New Reward';

  @override
  String get channel_points_active => 'Active';

  @override
  String get channel_points_inactive => 'Inactive';

  @override
  String channel_points_reactions_info(int reactions, int enabled) {
    String _temp0 = intl.Intl.pluralLogic(
      reactions,
      locale: localeName,
      other: '$reactions reactions',
      one: '$reactions reaction',
    );
    return '$_temp0 • $enabled enabled';
  }

  @override
  String get button_configure => 'Configure';

  @override
  String reward_configure_title(String reward) {
    return 'Configure: $reward';
  }

  @override
  String get reward_name_title => 'Reward Name';

  @override
  String get button_add_reaction => 'Add New Reaction';

  @override
  String get reward_status_switch_title => 'Status';

  @override
  String get reward_status_active => 'Active';

  @override
  String get reward_status_inactive => 'Inactive';

  @override
  String get reward_name_hint => 'Enter Twitch reward name';

  @override
  String get reaction_chain_title => 'Reaction Chain';

  @override
  String get reaction_chain_empty_text =>
      'No reactions configured. Add a reaction to get started.';

  @override
  String get reaction_enable_input => 'Enable input';

  @override
  String get reaction_delay => 'Delay';

  @override
  String get reaction_play_audio => 'Play audio (legacy)';
}

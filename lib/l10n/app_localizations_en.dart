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
  String get reward_configure_title => 'Reward Configurator';

  @override
  String reward_configure_title_with_name(String reward) {
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

  @override
  String get reaction_play_audios => 'Play audio files';

  @override
  String get reaction_enable_filter => 'Enable filter';

  @override
  String get reaction_invert_filter => 'Invert filter';

  @override
  String get reaction_flip_source => 'Flip source';

  @override
  String get reaction_enable_source => 'Enable source';

  @override
  String get reaction_toggle_source => 'Toggle source';

  @override
  String get reaction_set_scene => 'Set scene';

  @override
  String get reaction_crash_process => 'Crash process';

  @override
  String get reaction_send_input => 'Send input';

  @override
  String get reward_no_name => 'Unnamed';

  @override
  String rewards_search_empty_text(String query) {
    return 'No channel points found matching \"$query\".';
  }

  @override
  String get button_clear_search => 'Clear Search';

  @override
  String get reaction_play_audios_audio_files_title => 'Audio Files';

  @override
  String get reaction_play_audios_no_files =>
      'No audio files configured. Click \"Add File\" to start.';

  @override
  String get reaction_play_audios_button_add_file => 'Add File';

  @override
  String get reaction_play_audios_volume => 'Volume';

  @override
  String get reaction_play_audios_select_files_dialog => 'Select audio files';

  @override
  String get reaction_play_audios_playback_settings => 'Playback Settings';

  @override
  String get reaction_play_audios_wait_for_completion => 'Wait for Completion';

  @override
  String get reaction_play_audios_shuffle => 'Shuffle';

  @override
  String get reaction_play_audios_count_title => 'Number of Tracks';

  @override
  String get reaction_play_audios_count_all => 'All';

  @override
  String get reaction_play_audios_count_specific => 'Specific';

  @override
  String get button_save_changes => 'Save Changes';
}

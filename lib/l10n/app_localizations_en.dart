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
}

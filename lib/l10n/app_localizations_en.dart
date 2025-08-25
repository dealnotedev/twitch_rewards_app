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
}

// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Nalo';

  @override
  String get welcomeMessage => 'Nalo is ready';

  @override
  String get selectEnvironment => 'Select environment';

  @override
  String currentEnvironment(Object environment) {
    return 'Current environment: $environment';
  }

  @override
  String get testEnvironment => 'Test';

  @override
  String get productionEnvironment => 'Production';
}

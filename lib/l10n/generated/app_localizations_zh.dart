// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appName => 'Nalo';

  @override
  String get welcomeMessage => 'Nalo 已准备就绪';

  @override
  String get selectEnvironment => '选择环境';

  @override
  String currentEnvironment(Object environment) {
    return '当前环境：$environment';
  }

  @override
  String get testEnvironment => '测试环境';

  @override
  String get productionEnvironment => '生产环境';
}

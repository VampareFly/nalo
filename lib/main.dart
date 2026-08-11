import 'package:amplitude_flutter/amplitude.dart';
import 'package:amplitude_flutter/configuration.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:tester_kit/app/app.dart';
import 'package:tester_kit/core/analytics/analytics.dart';
import 'package:tester_kit/core/analytics/amplitude_config.dart';
import 'package:tester_kit/core/crash_reporting/crash_reporting_service.dart';

Future<void> main() async {
  /// 确保flutter framework与底层引擎的链接
  WidgetsFlutterBinding.ensureInitialized();

  await CrashReportingService.initialize();

  await Hive.initFlutter();

  final amplitude = Amplitude(
    Configuration(apiKey: AmplitudeConfig.apiKey),
  );
  await amplitude.isBuilt;

  runApp(
    ProviderScope(
      overrides: [amplitudeProvider.overrideWithValue(amplitude)],
      child: const TesterKitApp(),
    ),
  );
}
@HiveType(typeId: 0) // typeId must be unique for each class
class Test001 extends HiveObject {
  String? name;
  int? age;

  Test001({this.name, this.age});
}

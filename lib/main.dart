import 'package:amplitude_flutter/amplitude.dart';
import 'package:amplitude_flutter/configuration.dart';
import 'package:amplitude_flutter/constants.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:nalo/app/app.dart';
import 'package:nalo/core/analytics/analytics.dart';
import 'package:nalo/core/analytics/amplitude_config.dart';
import 'package:nalo/core/crash_reporting/crash_reporting_service.dart';
import 'package:nalo/core/network/provider_retry_policy.dart';

Future<void> main() async {
  /// 确保flutter framework与底层引擎的链接
  WidgetsFlutterBinding.ensureInitialized();

  await CrashReportingService.initialize();

  await Hive.initFlutter();

  final amplitude = Amplitude(
    Configuration(
      apiKey: AmplitudeConfig.apiKey,
      minIdLength: 1,
      logLevel: kDebugMode ? LogLevel.debug : LogLevel.warn,
    ),
  );
  await amplitude.isBuilt;

  runApp(
    ProviderScope(
      retry: appProviderRetry,
      overrides: [amplitudeProvider.overrideWithValue(amplitude)],
      child: const NaloApp(),
    ),
  );
}

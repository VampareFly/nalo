/// Analytics 使用说明：
///
/// 调用流转：Widget / ViewModel → AnalyticsService → Amplitude。
/// Widget 可使用 `ref.report(...)`，Notifier 使用
/// `ref.read(analyticsProvider)`，普通类通过构造方法注入 AnalyticsService。
///
/// 登录成功：identifyUser → setUserProperties → report 登录事件。
/// 退出登录：report 退出事件 → 业务退出成功 → resetIdentity。
/// 注销账号：report 注销请求 → 后端注销及数据删除成功 → resetIdentity。
/// 每次 report 都会自动添加 app_environment 和钥匙串 device_id。
import 'package:amplitude_flutter/amplitude.dart';
import 'package:amplitude_flutter/events/base_event.dart';
import 'package:amplitude_flutter/events/identify.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:tester_kit/app/config/app_environment.dart';
import 'package:tester_kit/core/device/device_id_provider.dart';
import 'package:tester_kit/core/device/device_id_service.dart';
import 'package:tester_kit/core/logging/logger_provider.dart';

/// 统一维护发送到 Amplitude 的事件名称。
enum AnalyticsEvent {
  getStartedClicked('get_started_clicked'),
  buttonClicked('button_clicked'),
  loginCompleted('login_completed'),
  logoutCompleted('logout_completed'),
  accountDeletionRequested('account_deletion_requested');

  const AnalyticsEvent(this.eventName);

  final String eventName;
}

/// 由分析服务自动添加，业务层无需传入。
enum AnalyticsCommonProperty {
  appEnvironment('app_environment'),
  deviceId('device_id');

  const AnalyticsCommonProperty(this.propertyName);

  final String propertyName;
}

/// 具体事件按需携带的业务属性。
enum AnalyticsEventProperty {
  buttonName('button_name'),
  screenName('screen_name'),
  loginMethod('login_method'),
  result('result');

  const AnalyticsEventProperty(this.propertyName);

  final String propertyName;
}

/// 描述用户当前状态的持久属性。
enum AnalyticsUserProperty {
  lastDeviceId('last_device_id'),
  accountType('account_type'),
  subscriptionStatus('subscription_status'),
  registrationMethod('registration_method'),
  onboardingCompleted('onboarding_completed');

  const AnalyticsUserProperty(this.propertyName);

  final String propertyName;
}

/// 业务层使用的统一分析接口，避免直接依赖 Amplitude SDK。
abstract interface class AnalyticsService {
  /// 上报事件，并自动附加环境和设备公共属性。
  Future<void> report(
    AnalyticsEvent event, {
    Map<AnalyticsEventProperty, Object> properties = const {},
  });

  /// 登录成功后绑定后端稳定的用户 ID。
  Future<void> identifyUser(String userId);

  /// 更新当前已登录用户的持久属性。
  Future<void> setUserProperties(
    Map<AnalyticsUserProperty, Object> properties,
  );

  /// 退登或注销成功后清除 Amplitude 身份并进入匿名状态。
  Future<void> resetIdentity();
}

/// 使用 Amplitude SDK 实现统一分析能力。
class AmplitudeAnalyticsService implements AnalyticsService {
  const AmplitudeAnalyticsService(
    this._amplitude,
    this._deviceIdService,
    this._logger,
  );

  final Amplitude _amplitude;
  final DeviceIdService _deviceIdService;
  final Logger _logger;

  @override
  Future<void> report(
    AnalyticsEvent event, {
    Map<AnalyticsEventProperty, Object> properties = const {},
  }) async {
    try {
      final eventProperties = <String, Object>{
        for (final property in properties.entries)
          property.key.propertyName: property.value,
        ...await _commonProperties(),
      };

      await _amplitude.track(
        BaseEvent(
          event.eventName,
          eventProperties: eventProperties,
        ),
      );
    } catch (error, stackTrace) {
      _logger.w(
        'Failed to report analytics event: ${event.eventName}',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<void> identifyUser(String userId) async {
    if (userId.trim().isEmpty) {
      _logger.w('Unable to identify analytics user with an empty user ID');
      return;
    }

    try {
      await _amplitude.setUserId(userId);
      final deviceId = await _deviceIdService.getDeviceId();
      await setUserProperties({
        AnalyticsUserProperty.lastDeviceId: deviceId,
      });
    } catch (error, stackTrace) {
      _logFailure('identify analytics user', error, stackTrace);
    }
  }

  @override
  Future<void> setUserProperties(
    Map<AnalyticsUserProperty, Object> properties,
  ) async {
    if (properties.isEmpty) return;

    try {
      final identify = Identify();
      for (final property in properties.entries) {
        identify.set(property.key.propertyName, property.value);
      }
      await _amplitude.identify(identify);
    } catch (error, stackTrace) {
      _logFailure('set analytics user properties', error, stackTrace);
    }
  }

  @override
  Future<void> resetIdentity() async {
    try {
      await _amplitude.reset();
    } catch (error, stackTrace) {
      _logFailure('reset analytics identity', error, stackTrace);
    }
  }

  Future<Map<String, Object>> _commonProperties() async {
    return {
      AnalyticsCommonProperty.appEnvironment.propertyName:
          currentEnvironment.name,
      AnalyticsCommonProperty.deviceId.propertyName:
          await _deviceIdService.getDeviceId(),
    };
  }

  void _logFailure(
    String operation,
    Object error,
    StackTrace stackTrace,
  ) {
    _logger.w(
      'Failed to $operation',
      error: error,
      stackTrace: stackTrace,
    );
  }
}

/// 提供已在应用入口初始化的 Amplitude 实例。
final amplitudeProvider = Provider<Amplitude>((ref) {
  throw StateError('Amplitude has not been initialized');
});

/// 提供统一的业务埋点服务。
final analyticsProvider = Provider<AnalyticsService>((ref) {
  return AmplitudeAnalyticsService(
    ref.watch(amplitudeProvider),
    ref.watch(deviceIdServiceProvider),
    ref.watch(loggerProvider),
  );
});

/// 为 WidgetRef 提供简洁的事件上报入口。
extension AnalyticsWidgetRef on WidgetRef {
  /// 上报事件，页面无需直接读取 AnalyticsService。
  Future<void> report(
    AnalyticsEvent event, {
    Map<AnalyticsEventProperty, Object> properties = const {},
  }) {
    return read(analyticsProvider).report(event, properties: properties);
  }

  /// 登录成功后绑定后端稳定的用户 ID。
  Future<void> identifyAnalyticsUser(String userId) {
    return read(analyticsProvider).identifyUser(userId);
  }

  /// 更新当前已登录用户的属性。
  Future<void> setAnalyticsUserProperties(
    Map<AnalyticsUserProperty, Object> properties,
  ) {
    return read(analyticsProvider).setUserProperties(properties);
  }

  /// 退登或注销成功后重置分析身份。
  Future<void> resetAnalyticsIdentity() {
    return read(analyticsProvider).resetIdentity();
  }
}

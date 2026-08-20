// 登录注册埋点统一入口。
// Widget 上报点击，ViewModel 上报请求结果，NavigatorObserver 上报页面曝光；
// AnalyticsService 自动补充公共属性并隔离 Amplitude SDK。

import 'dart:io';

import 'package:amplitude_flutter/amplitude.dart';
import 'package:amplitude_flutter/events/base_event.dart';
import 'package:amplitude_flutter/events/identify.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:nalo/core/device/device_id_provider.dart';
import 'package:nalo/core/device/device_id_service.dart';
import 'package:nalo/core/device/tracking_transparency_provider.dart';
import 'package:nalo/core/device/tracking_transparency_service.dart';
import 'package:nalo/core/logging/logger_provider.dart';
import 'package:nalo/features/notifications/services/notification_permission_service.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// 登录注册流程发送到 Amplitude 的事件名称。
enum AnalyticsEvent {
  pageView('page_view'),
  loginClick('login_click'),
  iNeedKitClick('i_need_kit_click'),
  loginRequestResult('login_request_result'),
  createAccountClick('create_account_click'),
  createAccountRequestResult('create_account_request_result'),
  under18AlertView('under_18_alert_view'),
  under18AlertGoBackClick('under_18_alert_goback_click'),
  notificationEnableClick('notification_enable_click'),
  startJourney('start_journey');

  const AnalyticsEvent(this.eventName);

  final String eventName;
}

/// `page_view` 使用的页面名称枚举。
enum AnalyticsPageName {
  loginSignIn('login_sign_in'),
  createAccount('create_account'),
  welcome('welcome');

  const AnalyticsPageName(this.value);

  final String value;

  /// 将路由名称转换为埋点页面枚举。
  static AnalyticsPageName? fromRouteName(String? routeName) {
    for (final pageName in values) {
      if (pageName.value == routeName) return pageName;
    }
    return null;
  }
}

/// 由分析服务自动添加，业务层不能覆盖。
enum AnalyticsCommonProperty {
  notificationEnabled('notification_enabled'),
  platform('platform'),
  appVersion('app_version'),
  osVersion('os_version'),
  userId('user_id'),
  kcId('kc_id');

  const AnalyticsCommonProperty(this.propertyName);

  final String propertyName;
}

/// 登录注册事件按需传入的属性。
enum AnalyticsEventProperty {
  pageName('page_name'),
  previousPage('previous_page'),
  method('method'),
  loginMethod('login_method'),
  isSuccess('is_success'),
  failReason('fail_reason'),
  email('email'),
  name('name'),
  birth('birth'),
  gender('gender'),
  title('title'),
  description('desc');

  const AnalyticsEventProperty(this.propertyName);

  final String propertyName;
}

/// 当前用户在 Amplitude 中维护的属性。
enum AnalyticsUserProperty {
  userId('user_id'),
  loginStatus('login_status'),
  notificationPermission('notification_permission'),
  kcId('kc_id'),
  idfa('x-idfa');

  const AnalyticsUserProperty(this.propertyName);

  final String propertyName;
}

/// `login_click.method` 的文档枚举值。
enum AnalyticsLoginClickMethod {
  continueWithShopify('1'),
  signIn('2');

  const AnalyticsLoginClickMethod(this.value);

  final String value;
}

/// 实际登录方式的文档枚举值。
enum AnalyticsLoginMethod {
  shopify('1'),
  apple('2');

  const AnalyticsLoginMethod(this.value);

  final String value;
}

/// 创建账号时上报的 Gender 枚举值。
enum AnalyticsGender {
  female('1'),
  male('2');

  const AnalyticsGender(this.value);

  final String value;
}

/// 按用户资料接口格式构造创建账号事件属性。
Map<AnalyticsEventProperty, Object> createAccountAnalyticsProperties({
  required String email,
  required String name,
  required DateTime? birth,
  required AnalyticsGender? gender,
}) {
  final birthValue = birth == null
      ? ''
      : '${birth.year}-${birth.month.toString().padLeft(2, '0')}-'
            '${birth.day.toString().padLeft(2, '0')}';
  return {
    AnalyticsEventProperty.email: email.trim(),
    AnalyticsEventProperty.name: name.trim(),
    AnalyticsEventProperty.birth: birthValue,
    AnalyticsEventProperty.gender: gender?.value ?? '',
  };
}

/// 业务层使用的统一分析接口。
abstract interface class AnalyticsService {
  /// 上报事件，并自动附加公共事件属性。
  Future<void> report(
    AnalyticsEvent event, {
    Map<AnalyticsEventProperty, Object> properties = const {},
  });

  /// 登录成功后绑定后端用户 ID，并设置登录相关用户属性。
  Future<void> identifyUser(
    String userId, {
    required AnalyticsLoginMethod loginMethod,
  });

  /// 更新当前 Amplitude 用户属性。
  Future<void> setUserProperties(Map<AnalyticsUserProperty, Object> properties);

  /// 请求 iOS ATT，并设置设备、通知和 IDFA 用户属性。
  Future<void> prepareTrackingAuthorization();

  /// 退登、Token 失效或注销成功后清除 Amplitude 身份。
  Future<void> resetIdentity();
}

/// 使用 Amplitude SDK 实现统一分析能力。
class AmplitudeAnalyticsService implements AnalyticsService {
  AmplitudeAnalyticsService(
    this._amplitude,
    this._deviceIdService,
    this._notificationPermissionService,
    this._trackingTransparencyService,
    this._logger,
  ) : _packageInfo = PackageInfo.fromPlatform();

  final Amplitude _amplitude;
  final DeviceIdService _deviceIdService;
  final NotificationPermissionService _notificationPermissionService;
  final TrackingTransparencyService _trackingTransparencyService;
  final Logger _logger;
  final Future<PackageInfo> _packageInfo;

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
        BaseEvent(event.eventName, eventProperties: eventProperties),
      );
    } catch (error, stackTrace) {
      _logFailure('report ${event.eventName}', error, stackTrace);
    }
  }

  @override
  Future<void> identifyUser(
    String userId, {
    required AnalyticsLoginMethod loginMethod,
  }) async {
    if (userId.trim().isEmpty) {
      _logger.w('Unable to identify analytics user with an empty user ID');
      return;
    }

    try {
      await _amplitude.setUserId(userId);
      final properties = <AnalyticsUserProperty, Object>{
        AnalyticsUserProperty.userId: userId,
        AnalyticsUserProperty.loginStatus: loginMethod.value,
        AnalyticsUserProperty.notificationPermission:
            await _notificationEnabledValue(),
        AnalyticsUserProperty.kcId: await _deviceIdValue(),
      };
      final idfa = await _trackingTransparencyService.requestAdvertisingId();
      if (idfa != null) properties[AnalyticsUserProperty.idfa] = idfa;
      await setUserProperties(properties);
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
  Future<void> prepareTrackingAuthorization() async {
    try {
      final properties = <AnalyticsUserProperty, Object>{
        AnalyticsUserProperty.notificationPermission:
            await _notificationEnabledValue(),
        AnalyticsUserProperty.kcId: await _deviceIdValue(),
      };
      final idfa = await _trackingTransparencyService.requestAdvertisingId();
      if (idfa != null) properties[AnalyticsUserProperty.idfa] = idfa;
      await setUserProperties(properties);
    } catch (error, stackTrace) {
      _logFailure('prepare tracking authorization', error, stackTrace);
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
    final packageInfo = await _packageInfoValue();
    return {
      AnalyticsCommonProperty.notificationEnabled.propertyName:
          await _notificationEnabledValue(),
      AnalyticsCommonProperty.platform.propertyName: _platformValue(),
      AnalyticsCommonProperty.appVersion.propertyName:
          packageInfo?.version ?? '',
      AnalyticsCommonProperty.osVersion.propertyName: _osVersionValue(),
      AnalyticsCommonProperty.userId.propertyName:
          await _amplitude.getUserId() ?? '',
      AnalyticsCommonProperty.kcId.propertyName: await _deviceIdValue(),
    };
  }

  Future<String> _notificationEnabledValue() async {
    try {
      final isEnabled = await _notificationPermissionService
          .isNotificationPermissionEnabled();
      return isEnabled ? '1' : '0';
    } catch (_) {
      return '0';
    }
  }

  Future<String> _deviceIdValue() async {
    try {
      return await _deviceIdService.getDeviceId();
    } catch (_) {
      return '';
    }
  }

  Future<PackageInfo?> _packageInfoValue() async {
    try {
      return await _packageInfo;
    } catch (_) {
      return null;
    }
  }

  String _platformValue() => switch (defaultTargetPlatform) {
    TargetPlatform.iOS => '1',
    TargetPlatform.android => '2',
    _ => '',
  };

  String _osVersionValue() {
    if (kIsWeb) return '';
    return Platform.operatingSystemVersion;
  }

  void _logFailure(String operation, Object error, StackTrace stackTrace) {
    _logger.w('Failed to $operation', error: error, stackTrace: stackTrace);
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
    PlatformNotificationPermissionService(),
    ref.watch(trackingTransparencyServiceProvider),
    ref.watch(loggerProvider),
  );
});

/// 监听页面进入和返回，并统一上报 `page_view`。
class AnalyticsNavigatorObserver extends NavigatorObserver {
  AnalyticsNavigatorObserver(this._analytics);

  final AnalyticsService _analytics;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _reportPageView(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _reportPageView(previousRoute, route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _reportPageView(newRoute, oldRoute);
  }

  void _reportPageView(
    Route<dynamic>? currentRoute,
    Route<dynamic>? previousRoute,
  ) {
    final pageName = AnalyticsPageName.fromRouteName(
      currentRoute?.settings.name,
    );
    if (pageName == null) return;
    final previousPage = AnalyticsPageName.fromRouteName(
      previousRoute?.settings.name,
    );
    _analytics.report(
      AnalyticsEvent.pageView,
      properties: {
        AnalyticsEventProperty.pageName: pageName.value,
        AnalyticsEventProperty.previousPage: previousPage?.value ?? '',
      },
    );
  }
}

/// 注入登录注册页面使用的路由埋点观察器。
final analyticsNavigatorObserverProvider = Provider<NavigatorObserver>((ref) {
  return AnalyticsNavigatorObserver(ref.watch(analyticsProvider));
});

/// 为 WidgetRef 提供简洁的 Analytics 调用入口。
extension AnalyticsWidgetRef on WidgetRef {
  /// 上报事件，页面无需直接访问 Amplitude SDK。
  Future<void> report(
    AnalyticsEvent event, {
    Map<AnalyticsEventProperty, Object> properties = const {},
  }) {
    return read(analyticsProvider).report(event, properties: properties);
  }

  /// 登录成功后绑定用户和登录方式。
  Future<void> identifyAnalyticsUser(
    String userId, {
    required AnalyticsLoginMethod loginMethod,
  }) {
    return read(
      analyticsProvider,
    ).identifyUser(userId, loginMethod: loginMethod);
  }

  /// 更新当前 Amplitude 用户属性。
  Future<void> setAnalyticsUserProperties(
    Map<AnalyticsUserProperty, Object> properties,
  ) {
    return read(analyticsProvider).setUserProperties(properties);
  }

  /// 请求 iOS ATT 并准备设备相关用户属性。
  Future<void> prepareAnalyticsTrackingAuthorization() {
    return read(analyticsProvider).prepareTrackingAuthorization();
  }

  /// 退登、Token 失效或注销成功后重置分析身份。
  Future<void> resetAnalyticsIdentity() {
    return read(analyticsProvider).resetIdentity();
  }
}

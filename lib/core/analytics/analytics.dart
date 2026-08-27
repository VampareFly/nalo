// 客户端埋点统一入口。
// Widget 上报点击和曝光，ViewModel 上报请求结果，页面容器上报页面访问；
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

/// 客户端发送到 Amplitude 的事件名称。
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
  startJourney('start_journey'),
  testStartClick('test_start_click'),
  testResultSectionView('test_result_section_view'),
  testResultItemView('test_result_item_view'),
  testHistoryEntryView('test_history_entry_view'),
  testHistoryEntryClick('test_history_entry_click'),
  testHistoryFilterClick('test_history_filter_click'),
  notificationEnableView('notification_enable_view'),
  referralView('referral_view'),
  referralClick('referral_click'),
  appUpdateAlertView('app_update_alert_view'),
  appUpdateClick('app_update_click'),
  profileClick('profile_click'),
  skuView('sku_view'),
  skuClick('sku_click'),
  shopShopifyUrlRequest('shop_shopify_url_request');

  const AnalyticsEvent(this.eventName);

  final String eventName;
}

/// `page_view` 使用的页面名称枚举。
enum AnalyticsPageName {
  loginSignIn('login_sign_in'),
  createAccount('create_account'),
  welcome('welcome'),
  tabHome('tab_home'),
  tabShop('tab_shop'),
  testFlow('test_flow'),
  testHistory('test_history'),
  profile('profile');

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

/// 业务事件按需传入的属性。
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
  desc('desc'),
  description('description'),
  productId('product_id'),
  variantId('variant_id'),
  imageUrl('image_url'),
  price('price'),
  compareAtPrice('compare_at_price'),
  currency('currency'),
  url('url'),
  position('position'),
  totalTestCount('total_test_count'),
  detectionType('detection_type'),
  itemCount('item_count'),
  testId('test_id'),
  date('date'),
  timePeriod('time_period'),
  value('value'),
  unit('unit'),
  typicalRange('typical_range'),
  discountPercent('discount_percent'),
  currentVersion('current_version'),
  targetVersion('target_version'),
  updateType('update_type'),
  action('action');

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

/// `test_start_click.position` 的检测入口位置。
enum AnalyticsTestStartPosition {
  homeCard('1'),
  bottomScan('2');

  const AnalyticsTestStartPosition(this.value);

  final String value;
}

/// 检测结果事件使用的类型枚举。
enum AnalyticsDetectionType {
  cortisol('1'),
  testosterone('2'),
  unknown('');

  const AnalyticsDetectionType(this.value);

  final String value;
}

/// 版本更新弹窗的更新类型。
enum AnalyticsUpdateType {
  optional('1'),
  force('2');

  const AnalyticsUpdateType(this.value);

  final String value;
}

/// `app_update_click.action` 的用户操作。
enum AnalyticsUpdateAction {
  update('1'),
  later('2');

  const AnalyticsUpdateAction(this.value);

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

/// 按埋点文档构造 Shop 商品事件属性，并统一转换美分金额。
Map<AnalyticsEventProperty, Object> skuAnalyticsProperties({
  required int productId,
  required int variantId,
  required String? title,
  required String? description,
  required String? imageUrl,
  required String price,
  required String? compareAtPrice,
  required String? currency,
}) {
  return {
    AnalyticsEventProperty.pageName: AnalyticsPageName.tabShop.value,
    AnalyticsEventProperty.productId: productId.toString(),
    AnalyticsEventProperty.variantId: variantId.toString(),
    AnalyticsEventProperty.title: title?.trim() ?? '',
    AnalyticsEventProperty.description: description?.trim() ?? '',
    AnalyticsEventProperty.imageUrl: imageUrl?.trim() ?? '',
    AnalyticsEventProperty.price: _minorUnitValue(price),
    if (compareAtPrice != null)
      AnalyticsEventProperty.compareAtPrice: _minorUnitValue(compareAtPrice),
    AnalyticsEventProperty.currency: currency?.trim() ?? '',
  };
}

int _minorUnitValue(String value) {
  final amount = num.tryParse(value.trim());
  if (amount == null || !amount.isFinite) return -1;
  return (amount * 100).round();
}

/// 业务层使用的统一分析接口。
abstract interface class AnalyticsService {
  /// 上报事件，并自动附加公共事件属性。
  Future<void> report(
    AnalyticsEvent event, {
    Map<AnalyticsEventProperty, Object> properties = const {},
  });

  /// 页面实际可见时上报，并自动使用上一次 Page Name 作为来源。
  Future<void> reportPageView(AnalyticsPageName pageName);

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
  AnalyticsPageName? _currentPageName;

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
  Future<void> reportPageView(AnalyticsPageName pageName) {
    final previousPage = _currentPageName;
    _currentPageName = pageName;
    return report(
      AnalyticsEvent.pageView,
      properties: {
        AnalyticsEventProperty.pageName: pageName.value,
        AnalyticsEventProperty.previousPage: previousPage?.value ?? '',
      },
    );
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

/// 监听路由页面进入和返回，并统一上报 `page_view`。
class AnalyticsNavigatorObserver extends NavigatorObserver {
  AnalyticsNavigatorObserver(this._analytics);

  final AnalyticsService _analytics;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _reportPageView(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _reportPageView(previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _reportPageView(newRoute);
  }

  void _reportPageView(Route<dynamic>? currentRoute) {
    final pageName = AnalyticsPageName.fromRouteName(
      currentRoute?.settings.name,
    );
    if (pageName == null) return;
    _analytics.reportPageView(pageName);
  }
}

/// 注入已定义路由页面使用的埋点观察器。
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

  /// 页面或 Tab 实际可见时上报统一 Page View。
  Future<void> reportAnalyticsPageView(AnalyticsPageName pageName) {
    return read(analyticsProvider).reportPageView(pageName);
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

// 客户端埋点统一入口。
// Widget 上报点击和曝光，ViewModel 上报请求结果，页面容器上报页面访问；
// AnalyticsService 自动补充公共属性，并将同一次上报隔离分发到 Amplitude 与 GA4。

import 'dart:io';

import 'package:amplitude_flutter/amplitude.dart';
import 'package:amplitude_flutter/events/base_event.dart';
import 'package:amplitude_flutter/events/identify.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
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

/// 客户端发送到 Amplitude 与 GA4 的事件名称。
enum AnalyticsEvent {
  pageView('page_view'),
  loginClick('login_click'),
  iNeedKitClick('i_need_kit_click'),
  loginRequestResult('login_request_result'),
  createAccountClick('create_account_click'),
  createAccountRequestResult('create_account_request_result'),
  accountProfileGenderClick('account_profile_gender_click'),
  accountProfileBirthClick('account_profile_birth_click'),
  accountProfileOver65NoticeView('account_profile_over_65_notice_view'),
  under18AlertView('under_18_alert_view'),
  under18AlertGoBackClick('under_18_alert_goback_click'),
  notificationEnableClick('notification_enable_click'),
  startJourney('start_journey'),
  testStartEntryClick('test_start_entry_click'),
  testTypeClick('test_type_click'),
  testStartClick('test_start_click'),
  testFlowExitClick('test_flow_exit_click'),
  testFlowBackClick('test_flow_back_click'),
  testPreparationTipView('test_preparation_tip_view'),
  testReadyClick('test_ready_click'),
  testTimerView('test_timer_view'),
  testTimerClick('test_timer_click'),
  testTimerComplete('test_timer_complete'),
  testExitAlertView('test_exit_alert_view'),
  testExitAlertClick('test_exit_alert_click'),
  testTimerAlertView('test_timer_alert_view'),
  testTimerAlertClick('test_timer_alert_click'),
  testCameraPermissionResult('test_camera_permission_result'),
  testCameraPermissionClick('test_camera_permission_click'),
  testCameraInitResult('test_camera_init_result'),
  testCaptureGuideView('test_capture_guide_view'),
  testPhotoCaptureClick('test_photo_capture_click'),
  testPhotoCaptureResult('test_photo_capture_result'),
  testPhotoPreviewView('test_photo_preview_view'),
  testPhotoRetakeClick('test_photo_retake_click'),
  testPhotoUseClick('test_photo_use_click'),
  testPhotoAnalysisRequestResult('test_photo_analysis_request_result'),
  testResultConfirmView('test_result_confirm_view'),
  testResultLevelClick('test_result_level_click'),
  testResultDateClick('test_result_date_click'),
  testResultTimePeriodClick('test_result_time_period_click'),
  testResultSaveClick('test_result_save_click'),
  testResultConfirmRequestResult('test_result_confirm_request_result'),
  testCelebrationView('test_celebration_view'),
  testCelebrationClick('test_celebration_click'),
  testResultRequestResult('test_result_request_result'),
  testResultView('test_result_view'),
  testResultInfoView('test_result_info_view'),
  testAgainReminderView('test_again_reminder_view'),
  testResultBackHomeClick('test_result_back_home_click'),
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
  profileSectionView('profile_section_view'),
  profileActionClick('profile_action_click'),
  profileDeleteAccountAlertView('profile_delete_account_alert_view'),
  profileDeleteAccountAlertClick('profile_delete_account_alert_click'),
  profileDeleteAccountRequestResult('profile_delete_account_request_result'),
  profileEditBackClick('profile_edit_back_click'),
  profileEditSaveClick('profile_edit_save_click'),
  profileEditRequestResult('profile_edit_request_result'),
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
  shop('shop'),
  testAbout('test_about'),
  testBeforeStart('test_before_start'),
  testSwab('test_swab'),
  testDip('test_dip'),
  testDevelop('test_develop'),
  testCapture('test_capture'),
  testPhotoPreview('test_photo_preview'),
  testResultConfirm('test_result_confirm'),
  testCelebration('test_celebration'),
  testResult('test_result'),
  testHistory('test_history'),
  profile('profile'),
  profileEdit('profile_edit');

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
  bundleId('bundle_id'),
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
  formType('form_type'),
  sectionType('section_type'),
  actionType('action_type'),
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
  advocateRewardType('advocate_reward_type'),
  advocateRewardValue('advocate_reward_value'),
  advocateRewardUnit('advocate_reward_unit'),
  friendRewardType('friend_reward_type'),
  friendRewardValue('friend_reward_value'),
  friendRewardUnit('friend_reward_unit'),
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
  currentVersion('current_version'),
  targetVersion('target_version'),
  updateType('update_type'),
  action('action'),
  timerDurationSeconds('timer_duration_seconds'),
  remainingSeconds('remaining_seconds'),
  timerStatus('timer_status'),
  timerAction('timer_action'),
  permissionStatus('permission_status'),
  aiValue('ai_value'),
  aiValueResultLevel('ai_value_result_level'),
  detectionTimePeriods('detection_time_periods'),
  finalLevel('final_level'),
  sampledAt('sampled_at'),
  showPopup('show_popup'),
  testTime('test_time'),
  infoTitle('info_title'),
  infoContent('info_content');

  const AnalyticsEventProperty(this.propertyName);

  final String propertyName;
}

/// 当前用户在分析平台中维护的属性，各平台按自身规则筛选。
enum AnalyticsUserProperty {
  userId('user_id'),
  appUserId('app_user_id'),
  loginStatus('login_status'),
  notificationPermission('notification_permission'),
  bundleId('bundle_id'),
  kcId('kc_id'),
  idfa('x-idfa');

  const AnalyticsUserProperty(this.propertyName);

  final String propertyName;
}

/// `login_click.method` 的文档枚举值。
enum AnalyticsLoginClickMethod {
  continueWithShopify('1'),
  signIn('2'),
  continueWithApple('3');

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

/// 注册和编辑资料埋点共用的 Gender 枚举值。
enum AnalyticsGender {
  male('1'),
  female('2');

  const AnalyticsGender(this.value);

  final String value;
}

/// 注册与编辑资料共用事件的表单来源。
enum AnalyticsProfileFormType {
  register('register'),
  editProfile('edit_profile');

  const AnalyticsProfileFormType(this.value);

  final String value;
}

/// `profile_section_view.section_type` 的区域类型。
enum AnalyticsProfileSectionType {
  testsCompleted('tests_completed'),
  personalInformation('personal_information'),
  shopifyAccount('shopify_account'),
  settingsMenu('settings_menu'),
  accountActions('account_actions');

  const AnalyticsProfileSectionType(this.value);

  final String value;
}

/// `profile_action_click.action_type` 的个人中心操作。
enum AnalyticsProfileActionType {
  editProfile('edit_profile'),
  manageShopifyAccount('manage_shopify_account'),
  notificationSettings('notification_settings'),
  privacyPolicy('privacy_policy'),
  termsOfService('terms_of_service'),
  helpAndSupport('help_and_support'),
  signOut('sign_out'),
  deleteAccount('delete_account');

  const AnalyticsProfileActionType(this.value);

  final String value;
}

/// `test_start_entry_click.position` 的检测入口位置。
enum AnalyticsTestStartPosition {
  homeCard('1'),
  bottomScan('2'),
  testHistoryEmpty('3');

  const AnalyticsTestStartPosition(this.value);

  final String value;
}

/// 计时页面展示时的状态值。
enum AnalyticsTimerStatus {
  running('1'),
  paused('2'),
  complete('3');

  const AnalyticsTimerStatus(this.value);

  final String value;
}

/// `test_timer_click.action` 的计时操作。
enum AnalyticsTimerAction {
  pause('1'),
  resume('2'),
  skip('3'),
  next('4');

  const AnalyticsTimerAction(this.value);

  final String value;
}

/// Develop 风险弹窗对应的计时操作。
enum AnalyticsTimerAlertAction {
  pause('1'),
  skip('2');

  const AnalyticsTimerAlertAction(this.value);

  final String value;
}

/// 通用确认弹窗的用户选择。
enum AnalyticsConfirmationAction {
  confirm('1'),
  cancel('2');

  const AnalyticsConfirmationAction(this.value);

  final String value;
}

/// 退出检测弹窗的用户选择。
enum AnalyticsTestExitAction {
  exit('1'),
  keepTesting('2');

  const AnalyticsTestExitAction(this.value);

  final String value;
}

/// 相机权限检查完成后的状态。
enum AnalyticsCameraPermissionStatus {
  granted('1'),
  denied('2'),
  permanentlyDeniedOrRestricted('3'),
  failed('4');

  const AnalyticsCameraPermissionStatus(this.value);

  final String value;
}

/// 相机权限或不可用状态页的按钮操作。
enum AnalyticsCameraPermissionAction {
  allow('1'),
  openSettings('2'),
  retry('3');

  const AnalyticsCameraPermissionAction(this.value);

  final String value;
}

/// 照片预览页触发重新拍照的入口。
enum AnalyticsPhotoRetakeMethod {
  topBack('1'),
  retakeButton('2'),
  systemBack('3');

  const AnalyticsPhotoRetakeMethod(this.value);

  final String value;
}

/// `test_celebration_click.action` 的庆祝页操作。
enum AnalyticsCelebrationAction {
  keepTesting('1');

  const AnalyticsCelebrationAction(this.value);

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
  return {
    AnalyticsEventProperty.email: email.trim(),
    AnalyticsEventProperty.name: name.trim(),
    AnalyticsEventProperty.birth: analyticsBirthValue(birth),
    AnalyticsEventProperty.gender: gender?.value ?? '',
  };
}

/// 将生日统一转换为埋点要求的 yyyy-MM-dd，无值返回空字符串。
String analyticsBirthValue(DateTime? birth) {
  if (birth == null) return '';
  return '${birth.year}-${birth.month.toString().padLeft(2, '0')}-'
      '${birth.day.toString().padLeft(2, '0')}';
}

/// 构造所有页面统一使用的 Referral 事件属性。
Map<AnalyticsEventProperty, Object> referralAnalyticsProperties({
  required AnalyticsPageName pageName,
  required String url,
  required String? advocateRewardType,
  required num? advocateRewardValue,
  required String? advocateRewardUnit,
  required String? friendRewardType,
  required num? friendRewardValue,
  required String? friendRewardUnit,
}) {
  return {
    AnalyticsEventProperty.pageName: pageName.value,
    AnalyticsEventProperty.url: url,
    AnalyticsEventProperty.advocateRewardType: advocateRewardType ?? '',
    AnalyticsEventProperty.advocateRewardValue:
        advocateRewardValue?.toString() ?? '',
    AnalyticsEventProperty.advocateRewardUnit: advocateRewardUnit ?? '',
    AnalyticsEventProperty.friendRewardType: friendRewardType ?? '',
    AnalyticsEventProperty.friendRewardValue:
        friendRewardValue?.toString() ?? '',
    AnalyticsEventProperty.friendRewardUnit: friendRewardUnit ?? '',
  };
}

/// 按商品所在页面构造 Shop 事件属性，并统一转换美分金额。
Map<AnalyticsEventProperty, Object> skuAnalyticsProperties({
  required AnalyticsPageName pageName,
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
    AnalyticsEventProperty.pageName: pageName.value,
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

/// 同时保存 App 与 Shopify 身份，由不同分析平台选择自己的用户 ID。
class AnalyticsUserIdentity {
  const AnalyticsUserIdentity({
    required this.appUserId,
    required this.shopifyCustomerId,
  });

  final String appUserId;
  final String? shopifyCustomerId;

  /// 返回 App 与 Shopify Web 共用的 GA4 User-ID；无有效 Shopify ID 时为空。
  String? get ga4UserId {
    final value = shopifyCustomerId?.trim();
    if (value == null || value.isEmpty) return null;
    return value;
  }
}

/// 集中管理 GA4 参数边界，避免业务页面感知分析平台差异。
abstract final class Ga4ParameterPolicy {
  /// GA4 明确禁止接收的个人信息和广告标识字段。
  static const blockedParameterNames = <String>{
    'email',
    'name',
    'birth',
    'x-idfa',
  };

  /// 由 GA4 SDK 专用 API 管理，不作为普通事件参数重复发送。
  static const _systemManagedParameterNames = <String>{'user_id', 'kc_id'};

  /// 在发送到 GA4 前移除禁止字段；Amplitude 原始参数不受影响。
  static Map<String, Object> sanitizeEventParameters(
    Map<String, Object> parameters,
  ) {
    // TODO: <pf> 根据最终 GA4 数据规范启用业务参数白名单。
    // static const allowedParameterNames = <String>{};
    // TODO: <pf> 正式发布前复核健康相关业务参数，仅保留分析必需的枚举或分档值。
    // 当前除强制禁止字段和系统专用字段外，其他业务参数暂时全部放行。
    return Map.fromEntries(
      parameters.entries.where(
        (entry) =>
            !blockedParameterNames.contains(entry.key) &&
            !_systemManagedParameterNames.contains(entry.key),
      ),
    );
  }

  /// 判断现有用户属性是否允许同步到 GA4。
  static bool allowsUserProperty(String propertyName) {
    return propertyName == AnalyticsUserProperty.appUserId.propertyName ||
        propertyName == AnalyticsUserProperty.loginStatus.propertyName ||
        propertyName == AnalyticsUserProperty.bundleId.propertyName ||
        propertyName ==
            AnalyticsUserProperty.notificationPermission.propertyName;
  }
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

  /// 登录或冷启动恢复后，为不同分析平台绑定各自用户 ID。
  Future<void> identifyUser(
    AnalyticsUserIdentity identity, {
    required AnalyticsLoginMethod loginMethod,
  });

  /// 冷启动恢复已登录身份，不重复执行 ATT 等首次登录准备流程。
  Future<void> restoreUserIdentity(AnalyticsUserIdentity identity);

  /// 更新当前用户属性，各平台按自身规则筛选。
  Future<void> setUserProperties(Map<AnalyticsUserProperty, Object> properties);

  /// 请求 iOS ATT，并设置设备、通知和 IDFA 用户属性。
  Future<void> prepareTrackingAuthorization();

  /// 退登、Token 失效或注销成功后清除所有分析平台身份。
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
    AnalyticsUserIdentity identity, {
    required AnalyticsLoginMethod loginMethod,
  }) async {
    final userId = identity.appUserId;
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
        AnalyticsUserProperty.bundleId: await _bundleIdValue(),
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
  Future<void> restoreUserIdentity(AnalyticsUserIdentity identity) async {
    final userId = identity.appUserId.trim();
    if (userId.isEmpty) return;
    try {
      await _amplitude.setUserId(userId);
      await setUserProperties({
        AnalyticsUserProperty.bundleId: await _bundleIdValue(),
      });
    } catch (error, stackTrace) {
      _logFailure('restore analytics user', error, stackTrace);
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
        AnalyticsUserProperty.bundleId: await _bundleIdValue(),
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
      AnalyticsCommonProperty.bundleId.propertyName:
          packageInfo?.packageName ?? '',
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

  Future<String> _bundleIdValue() async {
    final packageInfo = await _packageInfoValue();
    return packageInfo?.packageName ?? '';
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

/// 使用 Firebase Analytics 镜像现有 App 事件并维护 GA4 用户身份。
class FirebaseAnalyticsService implements AnalyticsService {
  FirebaseAnalyticsService(
    this._analytics,
    this._notificationPermissionService,
    this._logger,
  ) : _packageInfo = PackageInfo.fromPlatform();

  final FirebaseAnalytics _analytics;
  final NotificationPermissionService _notificationPermissionService;
  final Logger _logger;
  final Future<PackageInfo> _packageInfo;
  AnalyticsPageName? _currentPageName;

  @override
  Future<void> report(
    AnalyticsEvent event, {
    Map<AnalyticsEventProperty, Object> properties = const {},
  }) async {
    try {
      final eventParameters = <String, Object>{
        for (final property in properties.entries)
          property.key.propertyName: property.value,
        ...await _commonProperties(),
      };
      await _analytics.logEvent(
        name: event.eventName,
        parameters: Ga4ParameterPolicy.sanitizeEventParameters(eventParameters),
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
    AnalyticsUserIdentity identity, {
    required AnalyticsLoginMethod loginMethod,
  }) async {
    try {
      final userId = identity.ga4UserId;
      await _analytics.setUserId(id: userId);
      if (userId == null) {
        _logger.w('Unable to identify GA4 user without a Shopify customer ID');
      }
      await setUserProperties({
        if (identity.appUserId.trim().isNotEmpty)
          AnalyticsUserProperty.appUserId: identity.appUserId.trim(),
        AnalyticsUserProperty.loginStatus: loginMethod.value,
        AnalyticsUserProperty.notificationPermission:
            await _notificationEnabledValue(),
        AnalyticsUserProperty.bundleId: await _bundleIdValue(),
      });
    } catch (error, stackTrace) {
      _logFailure('identify GA4 user', error, stackTrace);
    }
  }

  @override
  Future<void> restoreUserIdentity(AnalyticsUserIdentity identity) async {
    try {
      await _analytics.setUserId(id: identity.ga4UserId);
      final appUserId = identity.appUserId.trim();
      if (appUserId.isNotEmpty) {
        await setUserProperties({
          AnalyticsUserProperty.appUserId: appUserId,
          AnalyticsUserProperty.bundleId: await _bundleIdValue(),
        });
      }
    } catch (error, stackTrace) {
      _logFailure('restore GA4 user', error, stackTrace);
    }
  }

  @override
  Future<void> setUserProperties(
    Map<AnalyticsUserProperty, Object> properties,
  ) async {
    try {
      for (final property in properties.entries) {
        final propertyName = property.key.propertyName;
        if (!Ga4ParameterPolicy.allowsUserProperty(propertyName)) continue;
        await _analytics.setUserProperty(
          name: propertyName,
          value: property.value.toString(),
        );
      }
    } catch (error, stackTrace) {
      _logFailure('set GA4 user properties', error, stackTrace);
    }
  }

  @override
  Future<void> prepareTrackingAuthorization() async {
    await setUserProperties({
      AnalyticsUserProperty.notificationPermission:
          await _notificationEnabledValue(),
      AnalyticsUserProperty.bundleId: await _bundleIdValue(),
    });
  }

  @override
  Future<void> resetIdentity() async {
    try {
      await _analytics.setUserId(id: null);
      await _analytics.setUserProperty(
        name: AnalyticsUserProperty.loginStatus.propertyName,
        value: null,
      );
      await _analytics.setUserProperty(
        name: AnalyticsUserProperty.appUserId.propertyName,
        value: null,
      );
    } catch (error, stackTrace) {
      _logFailure('reset GA4 identity', error, stackTrace);
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
      AnalyticsCommonProperty.bundleId.propertyName:
          packageInfo?.packageName ?? '',
      AnalyticsCommonProperty.osVersion.propertyName: _osVersionValue(),
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

  Future<PackageInfo?> _packageInfoValue() async {
    try {
      return await _packageInfo;
    } catch (_) {
      return null;
    }
  }

  Future<String> _bundleIdValue() async {
    final packageInfo = await _packageInfoValue();
    return packageInfo?.packageName ?? '';
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

/// 将同一次业务埋点独立发送到多个分析平台。
class CompositeAnalyticsService implements AnalyticsService {
  const CompositeAnalyticsService(this._services);

  final List<AnalyticsService> _services;

  @override
  Future<void> report(
    AnalyticsEvent event, {
    Map<AnalyticsEventProperty, Object> properties = const {},
  }) async {
    await Future.wait(
      _services.map((service) => service.report(event, properties: properties)),
    );
  }

  @override
  Future<void> reportPageView(AnalyticsPageName pageName) async {
    await Future.wait(
      _services.map((service) => service.reportPageView(pageName)),
    );
  }

  @override
  Future<void> identifyUser(
    AnalyticsUserIdentity identity, {
    required AnalyticsLoginMethod loginMethod,
  }) async {
    await Future.wait(
      _services.map(
        (service) => service.identifyUser(identity, loginMethod: loginMethod),
      ),
    );
  }

  @override
  Future<void> restoreUserIdentity(AnalyticsUserIdentity identity) async {
    await Future.wait(
      _services.map((service) => service.restoreUserIdentity(identity)),
    );
  }

  @override
  Future<void> setUserProperties(
    Map<AnalyticsUserProperty, Object> properties,
  ) async {
    await Future.wait(
      _services.map((service) => service.setUserProperties(properties)),
    );
  }

  @override
  Future<void> prepareTrackingAuthorization() async {
    await Future.wait(
      _services.map((service) => service.prepareTrackingAuthorization()),
    );
  }

  @override
  Future<void> resetIdentity() async {
    await Future.wait(_services.map((service) => service.resetIdentity()));
  }
}

/// 提供已在应用入口按当前业务环境初始化的 Amplitude 实例。
final amplitudeProvider = Provider<Amplitude>((ref) {
  throw StateError('Amplitude has not been initialized');
});

/// 提供统一的业务埋点服务。
final analyticsProvider = Provider<AnalyticsService>((ref) {
  final notificationPermissionService = PlatformNotificationPermissionService();
  final logger = ref.watch(loggerProvider);
  return CompositeAnalyticsService([
    AmplitudeAnalyticsService(
      ref.watch(amplitudeProvider),
      ref.watch(deviceIdServiceProvider),
      notificationPermissionService,
      ref.watch(trackingTransparencyServiceProvider),
      logger,
    ),
    FirebaseAnalyticsService(
      FirebaseAnalytics.instance,
      notificationPermissionService,
      logger,
    ),
  ]);
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
    AnalyticsUserIdentity identity, {
    required AnalyticsLoginMethod loginMethod,
  }) {
    return read(
      analyticsProvider,
    ).identifyUser(identity, loginMethod: loginMethod);
  }

  /// 更新当前用户属性，各平台按自身规则筛选。
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

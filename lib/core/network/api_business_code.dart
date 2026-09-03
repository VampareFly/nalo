// 统一维护客户端需要执行专门业务分支的服务端 code。
// 通用网络异常仍由 ApiClient处理，功能模块只引用与自身交互相关的常量。

/// 服务端业务响应 code 常量。
abstract final class ApiBusinessCode {
  /// 请求成功。
  static const success = 0;

  /// Access Token已过期。
  static const accessTokenExpired = 1000001;

  /// Refresh Token已过期，仅由 Refresh接口返回。
  static const refreshTokenExpired = 1000002;

  /// 请求未携带有效授权。
  static const unauthorized = 1000010;

  /// 当前登录状态无效。
  static const invalidSession = 1000011;

  /// 邮箱或密码错误。
  static const invalidEmailOrPassword = 1000012;

  /// 账号不存在或已注销。
  static const accountUnavailable = 1000013;

  /// 缺少设备标识 Header。
  static const missingDeviceId = 1000014;

  /// 平台 Header取值不合法。
  static const invalidPlatform = 1000015;

  /// Refresh Token无效或已吊销，仅由 Refresh接口返回。
  static const invalidRefreshToken = 1000016;

  /// 邮箱已经注册。
  static const emailAlreadyRegistered = 1000017;

  /// 当前登录方式尚未开放。
  static const loginMethodUnavailable = 1000018;

  /// 验证码错误。
  static const invalidVerificationCode = 1000020;

  /// 验证码已经过期。
  static const verificationCodeExpired = 1000021;

  /// 验证码使用场景不匹配。
  static const verificationCodeScenarioMismatch = 1000022;

  /// 验证码发送过于频繁。
  static const verificationCodeRateLimited = 1000023;

  /// 服务端未知参数类错误。
  static const unknown = 4000001;

  /// 请求参数错误。
  static const invalidParameters = 4000002;

  /// 请求过于频繁。
  static const requestRateLimited = 4000003;

  /// 密码格式不正确。
  static const invalidPasswordFormat = 4000004;

  /// 邮箱格式不正确。
  static const invalidEmailFormat = 4000005;

  /// 用户年龄小于18岁，资料不允许提交。
  static const ageUnder18 = 4000105;

  /// 用户年龄大于65岁，需要明确确认后再次提交。
  static const ageOver65ConfirmationRequired = 4000106;

  /// 服务端内部错误。
  static const internalServerError = 5000001;

  /// 会触发全局 Session清理和登录失效弹窗的业务码。
  static const sessionExpiredCodes = <int>{
    accessTokenExpired,
    unauthorized,
    invalidSession,
    accountUnavailable,
  };
}

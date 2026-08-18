/// 应用运行环境，用于切换配置和第三方项目。
enum AppEnvironment { test, production }

/// 返回当前环境对应的自有业务 API 地址。
extension AppEnvironmentApiConfig on AppEnvironment {
  String get apiBaseUrl {
    return switch (this) {
      AppEnvironment.test => 'https://api-test.naloresults.com',
      AppEnvironment.production => 'https://api.naloresults.com',
    };
  }
}

/// 当前环境，后续接口环境也可复用此配置。
const currentEnvironment = AppEnvironment.test;

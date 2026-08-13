/// 应用运行环境，用于切换配置和第三方项目。
enum AppEnvironment { test, production }

/// 返回当前环境对应的自有业务 API 地址。
extension AppEnvironmentApiConfig on AppEnvironment {
  String get apiBaseUrl {
    // TODO: <pf> 后端部署地址确定后，替换自有业务 API 的 baseUrl。
    return switch (this) {
      AppEnvironment.test => 'https://api.example.com',
      AppEnvironment.production => 'https://api.example.com',
    };
  }
}

/// 当前环境，后续接口环境也可复用此配置。
const currentEnvironment = AppEnvironment.test;

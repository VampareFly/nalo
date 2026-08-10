/// 应用运行环境，用于切换配置和第三方项目。
enum AppEnvironment { test, production }

/// 当前环境，后续接口环境也可复用此配置。
const currentEnvironment = AppEnvironment.test;

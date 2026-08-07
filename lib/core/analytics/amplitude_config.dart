import 'package:tester_kit/app/config/app_environment.dart';

class AmplitudeConfig {
  const AmplitudeConfig._();

  static String get apiKey => switch (currentEnvironment) {
    /// 测试环境
    AppEnvironment.test => '69356ab428cc8ff66ec27555d15d6217',

    /// 生产环境
    AppEnvironment.production => 'f3df996f87b4cf5d7ffd40dbcff92aef',
  };
}

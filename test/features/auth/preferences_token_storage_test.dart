import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nalo/features/auth/auth_token.dart';
import 'package:nalo/features/auth/token_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('saves, reads and clears a complete token', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final storage = PreferencesTokenStorage(preferences);
    final token = AuthToken(
      accessToken: 'access',
      refreshToken: 'refresh',
      expiresAt: DateTime.utc(2027),
    );

    await storage.save(token);
    expect(await storage.read(), token);

    await storage.clear();
    expect(await storage.read(), isNull);
  });
}
